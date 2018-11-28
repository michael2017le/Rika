//
//  ViewController.swift
//  Rika
//
//  Created by Michael Le on 4/24/18.
//  Copyright © 2018 Michael Le. All rights reserved.
//

import UIKit
import Speech
import ApiAI
import Contacts
import AVFoundation
import Foundation

class ViewController: UIViewController, SFSpeechRecognizerDelegate {

	var number: String = ""
	

	@IBOutlet weak var tfInput: UITextField!
	@IBOutlet weak var micButton: UIButton!

	private let speechRecognizer = SFSpeechRecognizer()
	private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
	private var recognitionTask: SFSpeechRecognitionTask?
	private let audioEngine = AVAudioEngine()

	let speechSynthesizer = AVSpeechSynthesizer()

	func speak(text: String) {

		let speechUtterance = AVSpeechUtterance(string: text)
		speechSynthesizer.speak(speechUtterance)
	}

	@IBAction func micTapped(_ sender: Any) {
		if audioEngine.isRunning {
			audioEngine.stop()
			recognitionRequest?.endAudio()
			micButton.isEnabled = false
			micButton.setTitle("Start Recording", for: .normal)
		} else {
			startRecording()
			micButton.setTitle("Stop Recording", for: .normal)
		}
	}

	@IBAction func rikaTapped(_ sender: Any) {
		let request = ApiAI.shared().textRequest()

		if let text = self.tfInput.text, text != "" {
			request?.query = text
		} else {
			return
		}

		request?.setMappedCompletionBlockSuccess({ (request, response) in
			let response = response as! AIResponse

			if response.result.action == "call" {
				if let parameters = response.result.parameters as? [String: AIResponseParameter] {
					if let c = parameters["contact"]?.stringValue {
						let store = CNContactStore()
						var rawNumber: String = ""
						store.requestAccess(for: .contacts) { (auth, err) in
							if let err = err {
								print("Failed to request contacts: ", err)
								return
							}

							if auth {
								print("Access granted")

								let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey]
								let request = CNContactFetchRequest(keysToFetch: keys as [CNKeyDescriptor])

								do {
									try store.enumerateContacts(with: request, usingBlock: { (contact, stopPointerIfYouWantToStopEnumerating) in
										if contact.givenName.lowercased() == c.lowercased() {
											rawNumber = contact.phoneNumbers.first?.value.stringValue ?? ""
										}
									})
								}
								catch let err {
									print("Failed to enumerate contacts: ", err)
								}
								print(rawNumber)
								self.number = ""
								for char in rawNumber {
									if Int(String(char)) != nil {
										self.number.append(char)
									}
								}
								let url: NSURL = URL(string: "TEL://\(self.number)")! as NSURL
								UIApplication.shared.open(url as URL, options: [:], completionHandler: nil)
							}
							else {
								print("Access denied")
							}
						}
					}
				}
			}


			self.tfInput.text = response.result.fulfillment.speech
			self.speak(text: self.tfInput.text!)
		}, failure: { (request, error) in
			print (error!)
		})

		ApiAI.shared().enqueue(request)
		tfInput.text = ""

	}

	override func viewDidLoad() {
		super.viewDidLoad()

		micButton.isEnabled = false
		speechRecognizer?.delegate = self

		SFSpeechRecognizer.requestAuthorization {(auth) in
			var isButtonEnabled = false

			switch auth {
			case .authorized:
				isButtonEnabled = true
			case .denied:
				isButtonEnabled = false
				print("User denied access to speech recognition")
			case .restricted:
				isButtonEnabled = false
				print("Speech recognition restricted on this device")
			case .notDetermined:
				isButtonEnabled = false
				print("Speech recognition not yet authorized")
			}

			OperationQueue.main.addOperation {
				self.micButton.isEnabled = isButtonEnabled
			}
		}

		speak(text: "Hi, I'm Rica!")
	}




	func startRecording() {

		if recognitionTask != nil {
			recognitionTask?.cancel()
			recognitionTask = nil
		}

		let audioSession = AVAudioSession.sharedInstance()
		do {
			try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with: .defaultToSpeaker)
			try audioSession.setMode(AVAudioSessionModeSpokenAudio)
			try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
		} catch {
			print("audioSession properties weren't set because of an error.")
		}

		recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

		let inputNode = audioEngine.inputNode

		guard let recognitionRequest = recognitionRequest else {
			fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
		}

		recognitionRequest.shouldReportPartialResults = true

		recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in

			var isFinal = false

			if result != nil {

				self.tfInput.text = result?.bestTranscription.formattedString
				isFinal = (result?.isFinal)!
			}

			if error != nil || isFinal {
				self.audioEngine.stop()
				inputNode.removeTap(onBus: 0)

				self.recognitionRequest = nil
				self.recognitionTask = nil

				self.micButton.isEnabled = true
			}
		})

		let recordingFormat = inputNode.outputFormat(forBus: 0)
		inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
			self.recognitionRequest?.append(buffer)
		}

		audioEngine.prepare()

		do {
			try audioEngine.start()
		} catch {
			print("audioEngine couldn't start because of an error.")
		}

		tfInput.text = "Say something, I'm listening!"
	}

	func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
		if available {
			micButton.isEnabled = true
		} else {
			micButton.isEnabled = false
		}
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}


}

