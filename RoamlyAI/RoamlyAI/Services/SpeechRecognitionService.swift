import Foundation
import Speech
import AVFoundation

protocol SpeechRecognitionDelegate: AnyObject {
    func speechRecognitionDidReceiveText(_ text: String)
    func speechRecognitionDidComplete(_ finalText: String)
    func speechRecognitionDidStart()
    func speechRecognitionDidStop()
}

class SpeechRecognitionService: ObservableObject {
    @Published var isListening = false
    @Published var recognizedText = ""
    @Published var hasPermission = false
    @Published var isContinuousListening = false
    
    weak var delegate: SpeechRecognitionDelegate?
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // Continuous listening properties
    private var silenceTimer: Timer?
    private var lastSpeechTime: Date?
    private let silenceThreshold: TimeInterval = 2.0 // 2 seconds of silence
    private var accumulatedText = ""
    
    init() {
        requestPermission()
    }
    
    func requestPermission() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self?.hasPermission = true
                case .denied, .restricted, .notDetermined:
                    self?.hasPermission = false
                @unknown default:
                    self?.hasPermission = false
                }
            }
        }
    }
    
    func startListening() throws {
        guard hasPermission else {
            throw SpeechRecognitionError.noPermission
        }
        
        try startSpeechRecognition()
        
        DispatchQueue.main.async {
            self.isListening = true
        }
        
        delegate?.speechRecognitionDidStart()
    }
    
    func startContinuousListening() throws {
        guard hasPermission else {
            throw SpeechRecognitionError.noPermission
        }
        
        try startSpeechRecognition()
        
        DispatchQueue.main.async {
            self.isListening = true
            self.isContinuousListening = true
        }
        
        delegate?.speechRecognitionDidStart()
    }
    
    private func startSpeechRecognition() throws {
        // Cancel any previous task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session for background operation
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechRecognitionError.failedToCreateRequest
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Configure audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            self?.handleRecognitionResult(result: result, error: error)
        }
    }
    
    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        var isFinal = false
        
        if let result = result {
            let newText = result.bestTranscription.formattedString
            
            DispatchQueue.main.async {
                self.recognizedText = newText
            }
            
            delegate?.speechRecognitionDidReceiveText(newText)
            
            if isContinuousListening {
                // Update last speech time
                lastSpeechTime = Date()
                
                // Reset silence timer
                silenceTimer?.invalidate()
                silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceThreshold, repeats: false) { [weak self] _ in
                    self?.handleSilenceTimeout(with: newText)
                }
                
                accumulatedText = newText
            }
            
            isFinal = result.isFinal
        }
        
        if error != nil || isFinal {
            if !isContinuousListening {
                stopListening()
                
                if let finalText = recognizedText, !finalText.isEmpty {
                    delegate?.speechRecognitionDidComplete(finalText)
                }
            } else if isFinal {
                // In continuous mode, restart recognition after a brief pause
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.restartContinuousRecognition()
                }
            }
        }
    }
    
    private func handleSilenceTimeout(with text: String) {
        guard isContinuousListening && !text.isEmpty else { return }
        
        // Process the accumulated text as a complete query
        delegate?.speechRecognitionDidComplete(text)
        
        // Clear accumulated text
        accumulatedText = ""
        lastSpeechTime = nil
        
        DispatchQueue.main.async {
            self.recognizedText = ""
        }
    }
    
    private func restartContinuousRecognition() {
        guard isContinuousListening else { return }
        
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        do {
            try startSpeechRecognition()
        } catch {
            print("Failed to restart continuous recognition: \(error)")
            stopContinuousListening()
        }
    }
    
    func stopListening() {
        cleanup()
        
        if !accumulatedText.isEmpty {
            delegate?.speechRecognitionDidComplete(accumulatedText)
        }
        
        DispatchQueue.main.async {
            self.isListening = false
            self.isContinuousListening = false
        }
        
        delegate?.speechRecognitionDidStop()
    }
    
    func stopContinuousListening() {
        stopListening()
    }
    
    private func cleanup() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        
        accumulatedText = ""
        lastSpeechTime = nil
    }
    
    deinit {
        cleanup()
    }
}

enum SpeechRecognitionError: Error {
    case noPermission
    case failedToCreateRequest
    
    var localizedDescription: String {
        switch self {
        case .noPermission:
            return "Speech recognition permission not granted"
        case .failedToCreateRequest:
            return "Failed to create recognition request"
        }
    }
}
