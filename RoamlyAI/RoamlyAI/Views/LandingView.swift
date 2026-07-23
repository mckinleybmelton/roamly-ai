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
                        
                        // Model Status Indicator
                        HStack(spacing: 8) {
                            Circle()
                                .fill(travelAI.modelManager.isModelLoaded ? Color.green : (travelAI.modelManager.isLoadingModel ? Color.orange : Color.red))
                                .frame(width: 8, height: 8)
                            
                            Text(modelStatusText)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.top, 4)
                        
                        // Location Status Indicator
                        HStack(spacing: 8) {
                            Circle()
                                .fill(locationStatusColor)
                                .frame(width: 8, height: 8)
                            
                            Text(locationStatusText)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.top, 2)
                    }
                    .padding(.top, 60)
                    
                    Spacer()
                    
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
                                    
                                    Text(lastResponse)
                                        .font(.body)
                                        .foregroundColor(.white)
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
                        .padding(.bottom, 40)
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
                        .padding(.bottom, 40)
                    } else {
                        VStack(spacing: 20) {
                            Text("Tap to start continuous listening")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            
                            Text("Ask multiple questions hands-free!")
                                .font(.body)
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.bottom, 40)
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
                    
                    Spacer()
                    
                    // Instructions
                    VStack(spacing: 8) {
                        if travelAI.modelManager.isModelLoaded {
                            Text("🚀 Offline AI Ready • Tap to start/stop continuous listening")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        } else {
                            Text("Tap to start continuous listening")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Text(isListening ? "Tap again to stop listening" : "Keep talking freely - no need to hold button")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        if let error = travelAI.modelManager.modelError {
                            Text("Using fallback mode: \(error)")
                                .font(.caption2)
                                .foregroundColor(.orange.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 30)
            }
        }
        .onAppear {
            audioRecorder.requestPermission()
            speechRecognition.requestPermission()
            travelAI.locationManager.requestLocationPermission()
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
    
    private var modelStatusText: String {
        if travelAI.modelManager.isModelLoaded {
            return "Offline AI Ready"
        } else if travelAI.modelManager.isLoadingModel {
            return "Loading AI Model..."
        } else if let error = travelAI.modelManager.modelError {
            return "Fallback Mode"
        } else {
            return "Initializing..."
        }
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
    
    private var locationStatusText: String {
        switch travelAI.locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if travelAI.locationManager.currentLocation != nil {
                return "Location Available"
            } else if travelAI.locationManager.isLoadingLocation {
                return "Getting Location..."
            } else {
                return "Location Ready"
            }
        case .denied, .restricted:
            return "Location Disabled"
        case .notDetermined:
            return "Location Pending"
        @unknown default:
            return "Location Error"
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
    
    private func processCompletedSpeech(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
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
