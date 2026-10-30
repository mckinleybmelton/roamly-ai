import Foundation
import Speech
import AVFoundation

class SpeechRecognitionService: ObservableObject {
    @Published var isListening = false
    @Published var recognizedText = ""
    @Published var hasPermission = false
    @Published var isContinuousListening = false
    @Published private(set) var isOnDeviceSpeechAvailable: Bool

    var onReceiveText: ((String) -> Void)?
    var onComplete: ((String) -> Void)?
    var onStart: (() -> Void)?
    var onStop: (() -> Void)?
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // Continuous listening properties
    private var silenceTimer: Timer?
    private var lastSpeechTime: Date?
    private let silenceThreshold: TimeInterval = 2.0 // 2 seconds of silence
    private var accumulatedText = ""
    private var consecutiveRecognitionFailures = 0
    private var recognitionGeneration = 0
    private var inputTapInstalled = false
    private let recognitionFailureCap = 3

    init() {
        isOnDeviceSpeechAvailable = speechRecognizer?.supportsOnDeviceRecognition == true
        requestPermission()
    }
    
    func requestPermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { _ in
            // The mic prompt stays with speech permission. Denial still follows the
            // existing speech path: startListening throws noPermission and the
            // landing copy does not switch to the on-device-unavailable message.
        }
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
        consecutiveRecognitionFailures = 0

        try startSpeechRecognition()
        
        DispatchQueue.main.async {
            self.isListening = true
        }
        
        onStart?()
    }
    
    func startContinuousListening() throws {
        guard hasPermission else {
            throw SpeechRecognitionError.noPermission
        }
        consecutiveRecognitionFailures = 0

        try startSpeechRecognition()
        
        DispatchQueue.main.async {
            self.isListening = true
            self.isContinuousListening = true
        }
        
        onStart?()
    }
    
    private func startSpeechRecognition() throws {
        guard isOnDeviceSpeechAvailable,
              let speechRecognizer,
              speechRecognizer.supportsOnDeviceRecognition else {
            markOnDeviceSpeechUnavailable()
            throw SpeechRecognitionError.onDeviceUnavailable
        }

        if AVAudioSession.sharedInstance().recordPermission == .denied {
            throw SpeechRecognitionError.noPermission
        }

        recognitionGeneration += 1
        let generation = recognitionGeneration
        recognitionTask?.cancel()
        recognitionTask = nil
        stopAudioEngine()

        do {
            // Configure audio session for background operation. This epic does not
            // enable a background mode; listening stays in the foreground.
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest else {
                throw SpeechRecognitionError.failedToCreateRequest
            }
            recognitionRequest.shouldReportPartialResults = true
            recognitionRequest.requiresOnDeviceRecognition = true

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }
            inputTapInstalled = true

            audioEngine.prepare()
            try audioEngine.start()

            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                self?.handleRecognitionResult(result: result, error: error, generation: generation)
            }
            if recognitionTask == nil {
                throw SpeechRecognitionError.onDeviceUnavailable
            }
        } catch let error as SpeechRecognitionError {
            stopAudioEngine()
            recognitionRequest = nil
            recognitionTask = nil
            if case .noPermission = error {
                throw error
            }
            markOnDeviceSpeechUnavailable()
            throw error
        } catch {
            stopAudioEngine()
            recognitionRequest = nil
            recognitionTask = nil
            markOnDeviceSpeechUnavailable()
            throw SpeechRecognitionError.onDeviceUnavailable
        }
    }
    
    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?, generation: Int) {
        guard generation == recognitionGeneration else { return }
        var isFinal = false
        
        if let result = result {
            consecutiveRecognitionFailures = 0
            let newText = result.bestTranscription.formattedString
            
            DispatchQueue.main.async {
                self.recognizedText = newText
            }
            
            onReceiveText?(newText)
            
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

        if result == nil, error != nil {
            consecutiveRecognitionFailures += 1
            if consecutiveRecognitionFailures >= recognitionFailureCap {
                DispatchQueue.main.async {
                    self.markOnDeviceSpeechUnavailable()
                }
                return
            }
            if isContinuousListening {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.restartContinuousRecognition()
                }
            }
            return
        }
        
        if error != nil || isFinal {
            if !isContinuousListening {
                stopListening()
                
                let finalText = recognizedText
                if !finalText.isEmpty {
                    onComplete?(finalText)
                }
            } else if isFinal {
                // In continuous mode, restart recognition after a brief pause.
                // A final result is not a failure and does not count toward the cap.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.restartContinuousRecognition()
                }
            }
        }
    }
    
    private func handleSilenceTimeout(with text: String) {
        guard isContinuousListening && !text.isEmpty else { return }
        
        // Process the accumulated text as a complete query
        onComplete?(text)
        
        // Clear accumulated text
        accumulatedText = ""
        lastSpeechTime = nil
        
        DispatchQueue.main.async {
            self.recognizedText = ""
        }
    }
    
    private func restartContinuousRecognition() {
        guard isContinuousListening else { return }

        do {
            // startSpeechRecognition retires the current task before the new
            // request, so a cancel error from that task is not a recognition failure.
            try startSpeechRecognition()
        } catch {
            print("Failed to restart continuous recognition: \(error)")
            markOnDeviceSpeechUnavailable()
        }
    }

    private func markOnDeviceSpeechUnavailable() {
        recognitionGeneration += 1
        isOnDeviceSpeechAvailable = false
        isListening = false
        isContinuousListening = false
        stopAudioEngine()
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
    }

    private func stopAudioEngine() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if inputTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            inputTapInstalled = false
        }
    }
    
    func stopListening() {
        recognitionGeneration += 1
        cleanup()
        
        if !accumulatedText.isEmpty {
            onComplete?(accumulatedText)
        }
        
        DispatchQueue.main.async {
            self.isListening = false
            self.isContinuousListening = false
        }
        
        onStop?()
    }
    
    func stopContinuousListening() {
        stopListening()
    }
    
    private func cleanup() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        stopAudioEngine()
        
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
    case onDeviceUnavailable

    var localizedDescription: String {
        switch self {
        case .noPermission:
            return "Speech recognition permission not granted"
        case .failedToCreateRequest:
            return "Failed to create recognition request"
        case .onDeviceUnavailable:
            return "On-device speech isn't available"
        }
    }
}
