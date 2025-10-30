import SwiftUI
import AVFoundation

class AudioRecorderViewModel: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isContinuousRecording = false
    @Published var hasPermission = false
    
    private var audioRecorder: AVAudioRecorder?
    private var continuousRecordingTimer: Timer?
    private var audioSession = AVAudioSession.sharedInstance()
    private var continuousRecordingTimer: Timer?
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    func requestPermission() {
        audioSession.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.hasPermission = granted
            }
        }
    }
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func setupBackgroundAudioSession() {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP, .mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup background audio session: \(error)")
        }
    }
    
    func startRecording() {
        guard hasPermission && !isRecording else { return }
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsDirectory.appendingPathComponent("recording-\(Date().timeIntervalSince1970).m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
            DispatchQueue.main.async {
                self.isRecording = true
            }
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    func startContinuousRecording() {
        guard hasPermission && !isContinuousRecording else { return }
        
        setupBackgroundAudioSession()
        
        DispatchQueue.main.async {
            self.isContinuousRecording = true
        }
        
        // Start a longer recording session
        startRecordingSession(duration: 3600) // 1 hour max session
        
        print("Started continuous recording session")
    }
    
    func stopContinuousRecording() {
        guard isContinuousRecording else { return }
        
        continuousRecordingTimer?.invalidate()
        continuousRecordingTimer = nil
        
        audioRecorder?.stop()
        audioRecorder = nil
        
        DispatchQueue.main.async {
            self.isContinuousRecording = false
            self.isRecording = false
        }
        
        print("Stopped continuous recording session")
    }
    
    private func startRecordingSession(duration: TimeInterval) {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsDirectory.appendingPathComponent("continuous-recording-\(Date().timeIntervalSince1970).m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            AVEncoderBitRateKey: 64000 // Lower bitrate for longer sessions
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            // Record for specified duration
            audioRecorder?.record(forDuration: duration)
            
            DispatchQueue.main.async {
                self.isRecording = true
            }
            
            // Set up timer to restart recording if needed (for very long sessions)
            continuousRecordingTimer = Timer.scheduledTimer(withTimeInterval: duration - 10, repeats: false) { [weak self] _ in
                if self?.isContinuousRecording == true {
                    self?.restartRecordingSession()
                }
            }
            
        } catch {
            print("Failed to start recording session: \(error)")
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        audioRecorder?.stop()
        audioRecorder = nil
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
    
    private func cleanup() {
        continuousRecordingTimer?.invalidate()
        continuousRecordingTimer = nil
        audioRecorder = nil
    }
    
    deinit {
        cleanup()
    }
}

extension AudioRecorderViewModel: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            print("Recording finished successfully")
            // Here you would typically process the audio file
            // For example, send it to a speech-to-text service
        } else {
            print("Recording failed")
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("Recording encode error: \(error)")
        }
    }
}
