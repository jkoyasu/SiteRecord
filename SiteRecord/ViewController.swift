//
//  ViewController.swift
//  SiteRecord
//
//  Created by koyasu on 2021/11/05.
//

import UIKit
import Foundation
import AVFoundation
import Speech

class ViewController: UIViewController, AVSpeechSynthesizerDelegate, SFSpeechRecognizerDelegate {
    var outputText: String = ""
    var displayString: String = ""
    var savedString: String!
    var buttonStatus: Bool = false{
        didSet{
            if buttonStatus{
                Button.setTitle("録音終了", for: .normal)
            }else{
                Button.setTitle("録音開始", for: .normal)
            }
        }
    }
    var recordStatus: Int = 0
    var inputString: String = " "
    var talker = AVSpeechSynthesizer()
    @IBOutlet weak var Button: UIButton!
    @IBOutlet weak var displayText: UILabel!
    
    
    override func viewDidLoad(){
        super.viewDidLoad()
        Button.setTitle("録音開始", for: .normal)
        //delegateの読み込み
        self.talker.delegate = self
        // Do any additional setup after loading the view.
        
        self.speechRecognizer.delegate = self
        self.requestRecognizerAuthorization()
    }
    
    private func requestRecognizerAuthorization() {
        // 認証処理
        SFSpeechRecognizer.requestAuthorization { authStatus in
            // メインスレッドで処理したい内容のため、OperationQueue.main.addOperationを使う
            OperationQueue.main.addOperation { [weak self] in
                guard let `self` = self else { return }
                switch authStatus {
                case .authorized:
                    print("許可")
                    try! self.startRecording()
                case .denied:
                    print("否認")
                case .restricted:
                    print("制限")
                case .notDetermined:
                    print("未決")
                @unknown default:
                    print("わからん")
                }
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
                super.didReceiveMemoryWarning()
    }
    
    @IBAction func didTapButton(sender: UIButton){
        buttonStatus.toggle()
        if recordStatus > 2{
            recordStatus += 1
        }
    }
    private var audioEngine = AVAudioEngine()
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    func stopRecording(){
        self.recognitionRequest?.endAudio()
        self.recognitionRequest = nil
        self.recognitionTask?.cancel()
        self.recognitionTask?.finish()
        self.recognitionTask = nil
        self.audioEngine.stop()
//        let audioSession = AVAudioSession.sharedInstance()
//        do {
//            try audioSession.setCategory(AVAudioSession.Category.playback)
//            try audioSession.setMode(AVAudioSession.Mode.default)
//        } catch{
//            print("AVAudioSession error")
//        }
    }

    func startRecording() throws {
        
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
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
        self.displayText.text = ""
        recognitionRequest?.shouldReportPartialResults = true
        recognitionRequest?.requiresOnDeviceRecognition = true
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest!) { [weak self] result, error in
            guard let `self` = self else { return }
            if(error != nil){
                print (String(describing: error))
                self.stopRecording()
                return
            }
            var isFinal = false
            if let result = result {
                isFinal = result.isFinal
                self.inputString = result.bestTranscription.formattedString
                print(self.recordStatus,self.inputString)
                
                if self.recordStatus == 0{
                    if self.inputString.contains("録音開始"){
                        self.buttonStatus.toggle()
                        self.recordStatus += 1
                    }
                }//recordStatus0
                
                if self.recordStatus == 1 {
                    let range = self.inputString.range(of: "録音開始")
                    if let theRange = range {
                        self.inputString = String(self.inputString[theRange.upperBound...])
                        print("編集完了",self.inputString)
                    }
                    self.displayText.text! = self.inputString
                    if self.inputString.contains("録音終了"){
                        self.buttonStatus.toggle()
                        self.savedString = self.inputString.replacingOccurrences(of:"録音終了" , with: "")
                        self.displayText.text! = self.savedString
                        try! self.confirm()
                        self.recordStatus += 1
                    }
                }
                if self.recordStatus == 2{
                    self.displayText.text! = self.savedString
                    if String(self.inputString[self.inputString.index(self.inputString.endIndex, offsetBy: -2)...]) == "はい"{
                        self.recordStatus = 0
                        print(self.savedString,"登録します")
                        try! self.startRecording()
                        return
                    }else if String(self.inputString[self.inputString.index(self.inputString.endIndex, offsetBy: -3)...]) == "いいえ"{
                        self.recordStatus = 0
                        self.stopRecording()
                        print(self.savedString,"登録しません")
                        return
                    }
                }
            }//result
            
            if isFinal { //録音タイムリミット
                print("recording time limit")
                self.stopRecording()
                try! self.startRecording()
                inputNode.removeTap(onBus: 0)
            }
        }//recognitionTask
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        self.audioEngine.prepare()
        try self.audioEngine.start()
    }
    
    func confirm() throws{
        // 話す内容をセット
        try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback)
        let utterance = AVSpeechUtterance(string: "次の内容で登録しますか？  "+self.savedString)
        // 言語を日本に設定
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        
        self.talker.speak(utterance)
    }
    
    internal func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance ) {
        print("start")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("finish")
        try! AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: .duckOthers)
    }
}


