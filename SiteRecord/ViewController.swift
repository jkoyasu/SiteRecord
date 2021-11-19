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

    
    var inputString: String = " "
    var talker = AVSpeechSynthesizer()
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
        self.recognitionRequest?.endAudio()
        self.recognitionRequest = nil
        self.recognitionTask?.cancel()
        self.recognitionTask?.finish()
        self.recognitionTask = nil
        self.audioEngine.stop()
        self.audioEngine.inputNode.removeTap(onBus: 0)
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
        //既存のセッションが存在したら切る。
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        //オーディオセッションの作成
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        self.recognitionTask = SFSpeechRecognitionTask()

        //音声認識リクエストの作成
        self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        if(self.recognitionTask == nil || self.recognitionRequest == nil){
            self.stopRecording()
            return
        }
        self.displayText.text = ""
        
        //オーディオデータをデバイスに保存する設定をON
        recognitionRequest?.shouldReportPartialResults = true
        //認識結果を都度返す設定をON
        recognitionRequest?.requiresOnDeviceRecognition = true
        
        //recognitionTask関数に音声認識要求オブジェクトを渡すと、音声認識タスクが実行される。
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest!) { [weak self] result, error in
            guard let `self` = self else { return }
            
            //エラーが発生したら録音終了※クリ返すとここで落ちる。
            if(error != nil){
                print (String(describing: error!))
                self.stopRecording()
                return
            }
            
            //録音タイムリミットを検知する関数
            var isFinal = false
            if let result = result {
                isFinal = result.isFinal
                self.inputString = result.bestTranscription.formattedString
                print(self.recordStatus,self.inputString)
                
                //recordstatus ==0 録音開始待ち
                if self.recordStatus == 0{
                    if self.inputString.contains("録音開始"){
                        self.Button.setTitle("録音終了", for: .normal)
                        //self.buttonStatus.toggle()
                        self.recordStatus += 1
                    }
                }//recordStatus0
                
                //recordStatus = 1 録音中、終了待ち
                if self.recordStatus == 1 {
                    let range = self.inputString.range(of: "録音開始")
                    if let theRange = range {
                        self.inputString = String(self.inputString[theRange.upperBound...])
                        print("編集完了",self.inputString)
                    }
                    self.displayText.text! = self.inputString
                    //「録音終了」を検知したときの動作
                    if self.inputString.contains("録音終了"){
                        self.buttonStatus.toggle()
                        //録音データの変換、表示
                        self.savedString = self.inputString.replacingOccurrences(of:"録音終了" , with: "")
                        self.displayText.text! = self.savedString
                        //画面表示の変換
                        self.Button.isHidden = true
                        self.messageLabel.text = "この内容で保存しますか？"
                        self.yesButton.isHidden = false
                        self.noButton.isHidden = false
                        try! self.confirm()
                        self.recordStatus += 1
                        print(self.recordStatus)
                    }
                }//recordStatus ==1
                
                //recordStatus==2 音声を保存するかチェック
                if self.recordStatus == 2{
                    self.displayText.text! = self.savedString
                    //「はい」を検知したら元に戻す。
                    if String(self.inputString[self.inputString.index(self.inputString.endIndex, offsetBy: -2)...]) == "はい"{
                        print(self.inputString)
                        try! self.stopRecording()
                        self.recordStatus = 0
                        //ここに表示ジョブを流す
                        print(self.savedString!,"登録します")
                        self.initialize()
                        return
                    //「いいえ」を検知したら元に戻す。
                    }else if String(self.inputString[self.inputString.index(self.inputString.endIndex, offsetBy: -3)...]) == "いいえ"{
                        try! self.startRecording()
                        self.recordStatus = 0
                        print(self.savedString!,"登録しません")
                        self.initialize()
                        return
                    }
                }//recordStatus == 2
            }//result
            
            //録音タイムリミットに達した場合
            if isFinal {
                print("recording time limit")
                self.stopRecording()
                try! self.startRecording()
                inputNode.removeTap(onBus: 0)
            }
        }//recognitionTask
        
        //マイク入力の設定
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        self.audioEngine.prepare()
        try self.audioEngine.start()
    }
    
    //認識した音声を保存するか記録する。
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

    //保存確認後、最初の状態に戻す。
    func initialize(){
        print("初期化します")
        self.messageLabel.text = ""
        self.Button.isHidden = false
        self.Button.setTitle("録音開始", for:.normal)
        self.yesButton.isHidden = true
        self.noButton.isHidden = true
        if let recognitionTask = self.recognitionTask {
          recognitionTask.cancel()
          self.recognitionTask = nil
        try! self.startRecording()
        }
    }
    
    
    
    //録音開始/録音終了ボタンの操作
    @IBAction func didTapButton(sender: UIButton){
        buttonStatus.toggle()
        
        if recordStatus == 0 {
                self.Button.setTitle("録音終了", for: .normal)
                //self.buttonStatus.toggle()
                self.recordStatus += 1
            
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
            try! self.confirm()
            self.recordStatus += 1
        }
    }
    
    //「はい」ボタンの操作
    @IBAction func tappedYesButton(_ sender: Any) {
        print(self.inputString)
        try! self.stopRecording()
        try! self.startRecording()
        self.recordStatus = 0
        print(self.savedString!,"登録します")
        //表示を初期化
        self.initialize()
        return
    }
    
    //「いいえ」ボタンの操作
    @IBAction func tappedNoButton(_ sender: Any) {
        print(self.inputString)
        try! self.stopRecording()
        try! self.startRecording()
        self.recordStatus = 0
        print(self.savedString!,"登録しません")
        //表示を初期化
        self.initialize()
        return
    }
    
    
    
}


