//
//  Recoder.swift
//  SiteRecord
//
//  Created by koyasu on 2021/11/09.
//

import Foundation
import AVFoundation
import Speech

class SpeechRecorder{
    
    var audioText: String = ""{
        didSet{
        
        }
    }
    private var audioEngine = AVAudioEngine()
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    func stopRecording(){
        self.recognitionTask?.cancel()
        self.recognitionTask?.finish()
        self.recognitionRequest?.endAudio()
        self.recognitionRequest = nil
        self.recognitionTask = nil
        self.audioEngine.stop()
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSession.Category.playback)
            try audioSession.setMode(AVAudioSession.Mode.default)
        } catch{
            print("AVAudioSession error")
        }
    }

    func startRecording() throws {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))!
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        self.recognitionTask = SFSpeechRecognitionTask()
        self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        if(self.recognitionTask == nil || self.recognitionRequest == nil){
            self.stopRecording()
            return
        }
        self.audioText = ""
        recognitionRequest?.shouldReportPartialResults = true
        if #available(iOS 13, *) {
            recognitionRequest?.requiresOnDeviceRecognition = false
        }
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest!) { result, error in
            if(error != nil){
                print (String(describing: error))
                self.stopRecording()
                return
            }
            var isFinal = false
            if let result = result {
                isFinal = result.isFinal
                self.audioText = result.bestTranscription.formattedString
                print(result.bestTranscription.formattedString)
            }
            if isFinal { //録音タイムリミット
                print("recording time limit")
                self.stopRecording()
                inputNode.removeTap(onBus: 0)
            }
        }
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        self.audioEngine.prepare()
        try self.audioEngine.start()
    }
}
