//
//  ViewController+SpeechDelegate.swift
//  ListenTranslateSpeak
//
//  Created by Ahmed Yasser on 15/02/2023.
//

import Speech
extension ViewController: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            recordButton.isEnabled = true
            recordButton.setTitle("Start Recording", for: [])
        } else {
            recordButton.isEnabled = false
            recordButton.setTitle("Recognition Not Available", for: .disabled)
        }
    }

}
