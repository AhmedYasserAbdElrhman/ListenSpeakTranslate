//
//  ViewController.swift
//  ListenTranslateSpeak
//
//  Created by Ahmed Yasser on 15/02/2023.
//

import UIKit
import Speech
import AVFoundation
import NaturalLanguage
import AWSTranslate
enum Usage {
    case fromArabic
    case toArabic
    mutating func toggle() {
        switch self {
        case .fromArabic:
            self = .toArabic
        case .toArabic:
            self = .fromArabic
        }
    }
    var localeIdentifier: String {
        switch self {
        case .fromArabic:
            return "ar-SA"
        case .toArabic:
            return "en"
        }
    }
}
class ViewController: UIViewController {
    // MARK: - IBOutlets
    @IBOutlet private weak var listenedTextView: UITextView!
    @IBOutlet private weak var translatedTextView: UITextView!
    @IBOutlet internal weak var recordButton: UIButton!
    // MARK: - Variables
    // Listening
    private var speechRecognizer: SFSpeechRecognizer!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private let audioEngine = AVAudioEngine()
    private var type = Usage.fromArabic {
        didSet {
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: type.localeIdentifier))!
        }
    }
    // Speaking
    let synthesizer = AVSpeechSynthesizer()
    // Get available downloaded voices on device
    // iOS 16 Bug
    lazy var availableARVoices: [AVSpeechSynthesisVoice] = {
        let availableVoices = AVSpeechSynthesisVoice.speechVoices()
        let filtered = availableVoices.filter({$0.language.contains("ar")})
        return filtered
    }()
    lazy var availableENVoices: [AVSpeechSynthesisVoice] = {
        let availableVoices = AVSpeechSynthesisVoice.speechVoices()
        let filtered = availableVoices.filter({$0.language.contains("en")})
        return filtered
    }()
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        // Disable the record buttons until authorization has been granted.
        recordButton.isEnabled = false
        synthesizer.delegate = self
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: type.localeIdentifier))!
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Configure the SFSpeechRecognizer object already
        // stored in a local member variable.
        speechRecognizer.delegate = self
        
        // Asynchronously make the authorization request.
        SFSpeechRecognizer.requestAuthorization { authStatus in

            // Divert to the app's main thread so that the UI
            // can be updated.
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    self.recordButton.isEnabled = true
                    
                case .denied:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("User denied access to speech recognition", for: .disabled)
                    
                case .restricted:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Speech recognition restricted on this device", for: .disabled)
                    
                case .notDetermined:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Speech recognition not yet authorized", for: .disabled)
                    
                default:
                    self.recordButton.isEnabled = false
                }
            }
        }
    }
    // MARK: - Functions
    private func startRecording() throws {
        
        // Cancel the previous task if it's running.
        recognitionTask?.cancel()
        self.recognitionTask = nil
        
        // Configure the audio session for the app.
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: .defaultToSpeaker)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        let inputNode = audioEngine.inputNode

        // Create and configure the speech recognition request.
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object") }
        recognitionRequest.shouldReportPartialResults = true
        
        // Keep speech recognition data on device
        if #available(iOS 13, *) {
            recognitionRequest.requiresOnDeviceRecognition = false
        }
        
        // Create a recognition task for the speech recognition session.
        // Keep a reference to the task so that it can be canceled.
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                // Update the text view with the results.
                self.listenedTextView.text = result.bestTranscription.formattedString
                isFinal = result.isFinal
                print("Text \(result.bestTranscription.formattedString)")
            }
            
            if error != nil || isFinal {
                // Stop recognizing speech if there is a problem.
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)

                self.recognitionRequest = nil
                self.recognitionTask = nil

                self.recordButton.isEnabled = true
                self.recordButton.setTitle("Start Recording", for: [])
            }
        }

        // Configure the microphone input.
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        // Let the user know to start talking.
        listenedTextView.text = "(Go ahead, I'm listening)"
    }
    // MARK: - IBActions
    @IBAction private func listenTapped(_ sender: UIButton) {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            recordButton.isEnabled = false
            recordButton.setTitle("Stopping", for: .disabled)
        } else {
            do {
                try startRecording()
                recordButton.setTitle("Stop Recording", for: [])
            } catch {
                recordButton.setTitle("Recording Not Available", for: [])
            }
        }
    }
    @IBAction private func translateTapped(_ sender: UIButton) {
        guard let text = listenedTextView.text,
        !text.isEmpty else { return }
        translate(text) { [weak self] result in
            guard let self else { return }
            self.translatedTextView.text = result
        }
        
    }
    @IBAction private func speakTapped(_ sender: UIButton) {
        defer { disableAVSession() }
        guard let text = translatedTextView.text,
        !text.isEmpty else { return }
        self.synthesizer.stopSpeaking(at: .immediate)
        let lang = type == .fromArabic ? NLLanguage.english : NLLanguage.arabic
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate;
        utterance.preUtteranceDelay = 0.25;
        utterance.postUtteranceDelay = 0.25;
        // iOS 16 Bug
        // I get random elmemnt of available current language voices
        let currentFilteredVoices = lang == .arabic ? availableARVoices : availableENVoices
        if let randomVoice = currentFilteredVoices.randomElement() {
            utterance.voice = randomVoice

            self.synthesizer.speak(utterance)
        }
        // Also you can init voice with Language identifier
        let voice = AVSpeechSynthesisVoice(language: lang.rawValue)
    }
    private func disableAVSession() {
        // Deactivates app’s audio session to avoid conflict with recording session
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("audioSession properties weren't disable.")
        }
    }

    @IBAction private func switchLanguageAction(_ sender: UIButton) {
        sender.isSelected.toggle()
        type.toggle()
    }
}
extension ViewController {
    func translate(_ text: String, completion: @escaping (String?) -> Void) {
        DispatchQueue.global().async {
            let translateClient = AWSTranslate.default()
            let translateRequest = AWSTranslateTranslateTextRequest()
            guard let translateRequest else { return }
            translateRequest.sourceLanguageCode = self.type == .fromArabic ? "ar" : "en"
            translateRequest.targetLanguageCode = self.type == .fromArabic ? "en" : "ar"
            translateRequest.text = text
                    
            let callback: (AWSTranslateTranslateTextResponse?, Error?) -> Void = { (response, error) in
               guard let response = response else {
                  print("Got error \(error)")
                  return
               }
                        
               if let translatedText = response.translatedText {
                   DispatchQueue.main.async {
                       completion(translatedText)
                   }
                  print(translatedText)
               }
            }
                    
            translateClient.translateText(translateRequest, completionHandler: callback)
        }

    }

}
extension ViewController: AVSpeechSynthesizerDelegate {
    
}
