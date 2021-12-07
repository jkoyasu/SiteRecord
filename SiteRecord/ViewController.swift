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
                //Button.setTitle("録音終了", for: .normal)
            }else{
                //Button.setTitle("録音開始", for: .normal)
            }
        }
    }
    var recordStatus: Int = 0
    var stopStatus = 0
    var inputString: String = " "
    var talker = AVSpeechSynthesizer()
//    var speakText = SpeakText()
    @IBOutlet weak var Button: UIButton!
    @IBOutlet weak var displayText: UILabel!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var yesButton: UIButton!
    @IBOutlet weak var noButton: UIButton!
    

    override func viewDidLoad(){
        super.viewDidLoad()
        messageLabel.text = ""
        yesButton.isHidden = true
        noButton.isHidden = true
        Button.setTitle("録音開始", for: .normal)
        //delegateの読み込み
        self.talker.delegate = self
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
    
    private var audioEngine = AVAudioEngine()
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    //音声認識を終了する
    func stopRecording(){
        print("stopRecording")
        self.recognitionRequest?.endAudio()
        self.recognitionRequest = nil
        self.recognitionTask?.cancel()
        self.recognitionTask?.finish()
        self.recognitionTask = nil
        self.audioEngine.stop()
        self.audioEngine.inputNode.removeTap(onBus: 0)
//        recordStatus = 0
//        let audioSession = AVAudioSession.sharedInstance()
//        do {
//            try audioSession.setCategory(AVAudioSession.Category.playback)
//            try audioSession.setMode(AVAudioSession.Mode.default)
//        } catch{
//            print("AVAudioSession error")
//        }
    }
    
    //音声認識の開始
    func startRecording() throws {
        

        print("startRecording")
        self.displayText.text = ""
        self.inputString = ""
        self.recordStatus = 0
        print("recordStatus:\(self.recordStatus)")
        //既存のセッションが存在したら切る。
        if let recognitionTask = self.recognitionTask {
            print("既存のセッションを削除します")
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        if(self.recognitionTask == nil){
            print("recognitionTask == nil")
        }
        
        if(self.recognitionRequest == nil){
            print("recognitionRequest == nil")
        }
        
        
        //オーディオセッションの作成
        print("オーディオセッションを作成します")
        if stopStatus == 0 {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        stopStatus = 0 }
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        self.recognitionTask = SFSpeechRecognitionTask()
        print("オーディオセッションの作成に成功しました")
        
        //音声認識リクエストの作成
        print("音声認識リクエストを作成します")
        self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        if(self.recognitionTask == nil || self.recognitionRequest == nil){
            print("音声認識リクエストの作成に失敗しました")
            self.stopRecording()
            return
        }
        print("音声認識リクエストの作成に成功しました。")
        
        //オーディオデータをデバイスに保存する設定をON
        recognitionRequest?.shouldReportPartialResults = true
        //認識結果を都度返す設定をON
        recognitionRequest?.requiresOnDeviceRecognition = true

        
        //recognitionTask関数に音声リクエストオブジェクトを渡すと、音声認識タスクが実行される。
        
        self.recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest!) { [weak self] result, error in
            guard let `self` = self else { return }
            
            //エラーが発生したら録音終了※くり返すとここで落ちる。
            if(error != nil){
                print ("エラー発生:" + String(describing: error!))
                //self.stopRecording()
                //return
            }
            var isFinal = false //録音タイムリミットを検知する関数
            
            if let result = result {
                isFinal = result.isFinal
                self.inputString = result.bestTranscription.formattedString
                print("input:" + self.inputString)
                
                //recordstatus ==0 録音開始待ち
                if self.recordStatus == 0{
                    if self.inputString.contains("録音開始"){
                        print("音声「録音開始」を認識しました。録音を開始します。")
                        self.Button.setTitle("録音終了", for: .normal)
                        //self.buttonStatus.toggle()
                        self.recordStatus = 1
                    }
                }//recordStatus0
                
                //recordStatus = 1 録音中、終了待ち
                if self.recordStatus == 1 {
                    print("recordStatus:\(self.recordStatus)")
                    let range = self.inputString.range(of: "録音開始")
                    if let theRange = range {
                        self.inputString = String(self.inputString[theRange.upperBound...])
//                        print("編集完了",self.inputString)
                    }
                    self.displayText.text! = self.inputString
                    //「録音終了」を検知したときの動作
                    if self.inputString.contains("録音終了"){
                        print("音声「録音終了」を認識しました。")
                    //self.buttonStatus.toggle()
                        //録音データの変換
                        self.savedString = self.inputString.replacingOccurrences(of:"録音終了" , with: "")
                        self.displayText.text! = self.savedString
                        //画面表示の変換
                        self.Button.isHidden = true
                        self.messageLabel.text = "この内容で保存しますか？"
                        self.yesButton.isHidden = false
                        self.noButton.isHidden = false
                        
                        self.recordStatus = 2
                    }
                }//recordStatus ==1
                
                //recordStatus==2 音声を保存するかチェック
                if self.recordStatus == 2{
                    print("recordStatus:\(self.recordStatus)")
                    self.displayText.text! = self.savedString
                    //「はい」を検知したら保存し、初期状態に戻す
//                    if String(self.inputString[self.inputString.index(self.inputString.endIndex, offsetBy: -5)...]) == "保存します"{
                    if self.inputString.contains("保存します"){
                        print("音声「保存します」を認識しました")
                        print(self.savedString! + "を保存します")
                        try! self.stopRecording()
                        self.initialize()
                        try! self.startRecording()
                        return
                    //「いいえ」を検知したら保存せず、初期状態に戻す
//                    }else if String(self.inputString[self.inputString.index(self.inputString.endIndex, offsetBy: -6)...]) == "保存しません"{
                    }else if self.inputString.contains("破棄します"){
                        print("音声「破棄します」を認識しました")
                        print(self.savedString! + "は保存しません")
                        try! self.stopRecording()
                        self.initialize()
                        try! self.startRecording()
                        return
                    }
                }//recordStatus == 2
            }//result
            
            //録音タイムリミットに達した場合
//            if isFinal {
//                print("recording time limit")
//                self.stopRecording()
//                try! self.startRecording()
//                inputNode.removeTap(onBus: 0)
//            }
        }//recognitionTask
        
        //マイク入力の設定
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        self.audioEngine.prepare()
        try self.audioEngine.start()
    }
    

    //音声を発声する
//
//    internal func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance ) {
//        print("start")
//    }
//
//    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
//        print("finish")
//        try! AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: .duckOthers)
//    }

    //保存確認後、最初の状態に戻す。
    func initialize(){
        print("画面表記を初期化します")
        self.messageLabel.text = ""
        self.Button.isHidden = false
        self.Button.setTitle("録音開始", for:.normal)
        self.yesButton.isHidden = true
        self.noButton.isHidden = true
        print("画面表記を初期化しました")
    }
    
    //録音開始/録音終了ボタンの操作
    @IBAction func didTapButton(sender: UIButton){
        buttonStatus.toggle()
        
        if recordStatus == 0 {
            self.Button.setTitle("録音終了", for: .normal)
                //self.buttonStatus.toggle()
                self.recordStatus = 1
            
        }else if recordStatus ==  1 {
            self.buttonStatus.toggle()
            //録音データの変換、表示
            self.savedString = self.inputString.replacingOccurrences(of:"録音終了" , with: "")
            self.displayText.text! = self.savedString
            //画面の変換
            self.messageLabel.text = "この内容で保存しますか？"
            self.Button.isHidden = true
            self.yesButton.isHidden = false
            self.noButton.isHidden = false
            self.recordStatus = 2
        }
    }
    
    //「はい」ボタンの操作
    @IBAction func tappedYesButton(_ sender: Any) {
        print("「保存します」が押下されました。")
        print(self.savedString! + "を保存します")
        try! self.stopRecording()
        self.initialize()
        try! self.startRecording()
        return
    }
    
    //「いいえ」ボタンの操作
    @IBAction func tappedNoButton(_ sender: Any) {
        print("「保存しません」が押下されました。")
        print(self.savedString! + "は保存しません")
        try! self.stopRecording()
        self.initialize()
        try! self.startRecording()
        return
    }
}
