import SwiftUI
import AVFoundation

struct ConversationItem: Identifiable {
    let id = UUID()
    let timestamp: Date
    let userQuery: String
    let aiResponse: String
    
    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

struct LandingView: View {
    @StateObject private var audioRecorder = AudioRecorderViewModel()
    @StateObject private var speechRecognition = SpeechRecognitionService()
    @StateObject private var travelAI = TravelAIService()
    @State private var showingDestinationSetup = false
    @State private var isListening = false // Changed from isRecording to isListening
    @State private var sessionDuration: TimeInterval = 0
    @State private var timer: Timer?
    @State private var currentTranscription = ""
    @State private var lastResponse = ""
    @State private var showResponse = false
    @State private var conversationHistory: [ConversationItem] = []
    @State private var isProcessingQuery = false
    @State private var isInterrupted = false
    @State private var wasListeningBeforeInterruption = false
    
    var body: some View {
        NavigationView {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.blue.opacity(0.8),
                        Color.purple.opacity(0.6)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    // App Title and Status
                    VStack(spacing: 10) {
                        Text("Roamly AI")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Your AI Travel Companion")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))

                        // Status dots — AI model, then location — glanceable, no labels
                        HStack(spacing: 6) {
                            Circle()
                                .fill(travelAI.modelManager.isModelLoaded ? Color.green : (travelAI.modelManager.isLoadingModel ? Color.orange : Color.red))
                                .frame(width: 8, height: 8)

                            Circle()
                                .fill(locationStatusColor)
                                .frame(width: 8, height: 8)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.top, 60)

                    // Capped, not a full flexible Spacer — an uncapped one would soak up all the
                    // leftover vertical space in this one gap between the title and the hero
                    // content below, reading as an accidental hole rather than a deliberate one.
                    Spacer()
                        .frame(maxHeight: 60)

                    // Response Display
                    if showResponse && !lastResponse.isEmpty {
                        ScrollView {
                            VStack(spacing: 15) {
                                if !currentTranscription.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("You asked:")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.7))
                                        
                                        Text(currentTranscription)
                                            .font(.body)
                                            .foregroundColor(.white)
                                            .padding()
                                            .background(Color.white.opacity(0.1))
                                            .cornerRadius(12)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Roamly AI:")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                    
                                    Text(LocalizedStringKey(lastResponse))
                                        .font(.body)
                                        .foregroundColor(.white)
                                        .tint(.white)
                                        .padding()
                                        .background(Color.blue.opacity(0.3))
                                        .cornerRadius(12)
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                    
                    // Processing Status
                    if travelAI.isProcessing {
                        VStack(spacing: 15) {
                            Text("Processing with AI...")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            // Processing animation
                            HStack(spacing: 4) {
                                ForEach(0..<3, id: \.self) { index in
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 8, height: 8)
                                        .scaleEffect(1.0)
                                        .animation(
                                            Animation.easeInOut(duration: 0.6)
                                                .repeatForever()
                                                .delay(Double(index) * 0.2),
                                            value: travelAI.isProcessing
                                        )
                                }
                            }
                        }
                        .padding(.bottom, 16)
                    }
                    // Interrupted Status (e.g. a phone call)
                    else if isInterrupted {
                        VStack(spacing: 15) {
                            Text("Paused")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)

                            Text("Listening will resume automatically when this ends")
                                .font(.body)
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.bottom, 16)
                    }
                    // Recording Status
                    else if isListening {
                        VStack(spacing: 15) {
                            Text("Listening Continuously...")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            Text(formatDuration(sessionDuration))
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.8))
                                .monospacedDigit()
                            
                            // Show live transcription if available
                            if !speechRecognition.recognizedText.isEmpty {
                                Text(speechRecognition.recognizedText)
                                    .font(.body)
                                    .foregroundColor(.white.opacity(0.9))
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(8)
                                    .multilineTextAlignment(.center)
                            }
                            
                            // Audio wave animation
                            HStack(spacing: 4) {
                                ForEach(0..<5, id: \.self) { index in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.white)
                                        .frame(width: 4, height: CGFloat.random(in: 10...40))
                                        .animation(
                                            Animation.easeInOut(duration: 0.5)
                                                .repeatForever()
                                                .delay(Double(index) * 0.1),
                                            value: isListening
                                        )
                                }
                            }
                        }
                        .padding(.bottom, 16)
                    } else {
                        VStack(spacing: 20) {
                            Text("Tap to start continuous listening")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                        .padding(.bottom, 16)
                    }
                    
                    // Push to Talk Button
                    Button(action: {
                        if isListening {
                            stopListening()
                        } else {
                            startListening()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(
                                    isListening ? 
                                    Color.red.opacity(0.8) : 
                                    Color.white.opacity(0.9)
                                )
                                .frame(width: 120, height: 120)
                                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                                .scaleEffect(isListening ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: isListening)
                            
                            Image(systemName: isListening ? "stop.fill" : "mic.fill")
                                .font(.system(size: 40, weight: .medium))
                                .foregroundColor(isListening ? .white : .blue)
                                .animation(.easeInOut(duration: 0.2), value: isListening)
                        }
                    }

                    // Uncapped — collects whatever vertical slack remains below the button
                    // instead of it pooling in the capped gap above, so extra space on taller
                    // screens reads as ordinary bottom margin rather than a mid-screen hole.
                    Spacer()
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            audioRecorder.requestPermission()
            speechRecognition.requestPermission()
            travelAI.locationManager.requestLocationPermission()
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { notification in
            handleAudioSessionInterruption(notification)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingDestinationSetup = true
                } label: {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $showingDestinationSetup) {
            DestinationSetupView(factsStore: travelAI.factsStore)
        }
        }
        .navigationViewStyle(.stack)
    }
    
    private var locationStatusColor: Color {
        switch travelAI.locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return travelAI.locationManager.currentLocation != nil ? .green : .orange
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .red
        }
    }
    
    private func startListening() {
        guard !isListening else { return }
        
        isListening = true
        sessionDuration = 0
        showResponse = false
        speechRecognition.recognizedText = ""
        conversationHistory.removeAll()
        
        // Wire up speech recognition callbacks
        speechRecognition.onComplete = { text in
            processCompletedSpeech(text)
        }
        
        // Start timer for session duration
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            sessionDuration += 0.1
        }
        
        // Start continuous audio recording
        audioRecorder.startContinuousRecording()
        
        // Start continuous speech recognition
        do {
            try speechRecognition.startContinuousListening()
        } catch {
            print("Failed to start speech recognition: \(error)")
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func stopListening() {
        guard isListening else { return }
        
        isListening = false
        timer?.invalidate()
        timer = nil
        
        // Stop continuous recording and speech recognition
        audioRecorder.stopContinuousRecording()
        speechRecognition.stopContinuousListening()
        
        // Process any final transcription
        if !speechRecognition.recognizedText.isEmpty {
            processCompletedSpeech(speechRecognition.recognizedText)
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }

    /// Handles AVAudioSession interruptions (phone calls, Siri, other apps taking the
    /// microphone, etc). AVAudioEngine in particular doesn't survive an interruption on its
    /// own — Apple's guidance is that the app must stop it on `.began` and, if appropriate,
    /// reconfigure and restart on `.ended`. A clean stop-then-restart via the existing
    /// stopListening()/startListening() pair is more robust here than trying to pause/resume
    /// the engine and recorder in place, which is fragile across a hard interruption boundary.
    private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            guard isListening else { return }
            wasListeningBeforeInterruption = true
            isInterrupted = true
            stopListening()

        case .ended:
            isInterrupted = false
            guard wasListeningBeforeInterruption else { return }
            wasListeningBeforeInterruption = false

            var shouldResume = false
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                shouldResume = AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume)
            }

            guard shouldResume else { return }
            // Give the system a moment to fully release the audio session before reclaiming it —
            // reactivating immediately as the interruption ends can occasionally fail.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                startListening()
            }

        @unknown default:
            break
        }
    }

    private func processCompletedSpeech(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        // Continuous listening can fire another completion (e.g. a second pause detected)
        // before the previous query's response finishes generating. Without this guard,
        // overlapping travelAI.processQuery calls could race on shared state like
        // GemmaModelManager.generationMode, and the UI has no way to represent two
        // simultaneous responses anyway — queries are handled one at a time.
        guard !isProcessingQuery else { return }

        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        currentTranscription = query
        
        Task {
            await MainActor.run {
                isProcessingQuery = true
            }
            
            do {
                let response = try await travelAI.processQuery(query)
                await MainActor.run {
                    let conversationItem = ConversationItem(
                        timestamp: Date(),
                        userQuery: query,
                        aiResponse: response
                    )
                    conversationHistory.append(conversationItem)
                    lastResponse = response
                    showResponse = true
                    isProcessingQuery = false
                    
                    // Clear the recognized text for next query
                    speechRecognition.recognizedText = ""
                }
            } catch {
                await MainActor.run {
                    let conversationItem = ConversationItem(
                        timestamp: Date(),
                        userQuery: query,
                        aiResponse: "Sorry, I couldn't process your request right now. Please try again."
                    )
                    conversationHistory.append(conversationItem)
                    lastResponse = conversationItem.aiResponse
                    showResponse = true
                    isProcessingQuery = false
                    speechRecognition.recognizedText = ""
                }
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }
}

#Preview {
    LandingView()
}
