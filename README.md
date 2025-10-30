# Roamly AI - iOS App

A SwiftUI-based iOS application that provides AI-powered travel assistance through voice interaction with **offline AI capabilities**.

## 🚀 Key Features

- **Push-to-Talk Interface**: Clean, modern landing page with a prominent round microphone button
- **Offline AI Processing**: Intelligent travel responses using local Natural Language Processing (no internet required)
- **Location-Aware Responses**: GPS-powered contextual answers about your current surroundings
- **Voice Recognition**: Real-time speech-to-text conversion using Apple's Speech framework
- **Smart Context Analysis**: Understands travel intent and provides contextual responses
- **"What Am I Looking At?" Feature**: Ask about your current location and get detailed information about nearby places
- **Responsive Design**: Optimized for both iPhone and iPad
- **Visual Feedback**: Real-time recording status with animated audio waves

## 🧠 Offline AI Technology

The app uses advanced local NLP (Natural Language Processing) to provide intelligent travel advice without requiring an internet connection:

- **Intent Recognition**: Analyzes user queries to understand travel-related intent
- **Location-Aware Processing**: Integrates GPS data to provide contextual responses about current surroundings
- **Contextual Responses**: Provides relevant advice based on detected topics (weather, food, hotels, etc.)
- **Keyword Analysis**: Extracts travel-specific terms to generate appropriate responses
- **Nearby Places Detection**: Identifies restaurants, attractions, hotels, and points of interest around you
- **Fallback Mode**: Graceful degradation if advanced features aren't available

## Architecture

The app follows the MVVM (Model-View-ViewModel) architecture pattern:

```
RoamlyAI/
├── RoamlyAI/
│   ├── RoamlyAIApp.swift           # Main app entry point
│   ├── Views/
│   │   └── LandingView.swift       # Main landing page with push-to-talk button
│   ├── ViewModels/
│   │   └── AudioRecorderViewModel.swift  # Handles audio recording logic
│   ├── Models/
│   │   └── AudioMessage.swift      # Data models for audio and travel queries
│   ├── Services/
│   │   ├── SpeechRecognitionService.swift  # Speech-to-text conversion
│   │   └── TravelAIService.swift   # AI service integration (placeholder)
│   ├── Assets.xcassets/            # App icons and assets
│   └── Info.plist                  # App configuration and permissions
├── RoamlyAI.xcodeproj/             # Xcode project file
└── RoamlyAI.xcworkspace/           # Xcode workspace
```

## Key Components

### LandingView
- Beautiful gradient background with status indicators
- Animated round push-to-talk button with state changes
- Real-time recording feedback with audio wave animation
- Live speech transcription display
- AI response display with conversation history
- Offline mode status indicator
- Haptic feedback for better user experience

### AudioRecorderViewModel
- Manages audio recording sessions
- Handles microphone permissions
- Records audio in high-quality M4A format
- Provides real-time recording state updates

### SpeechRecognitionService
- Converts speech to text using Apple's Speech framework
- Handles speech recognition permissions
- Provides real-time transcription updates
- Supports multiple languages (currently configured for English)

### GemmaModelManager (Offline AI Engine)
- Local Natural Language Processing using Core ML and NL framework
- Intent recognition for travel-related queries
- Contextual response generation based on detected topics
- Keyword analysis and sentiment understanding
- Graceful fallback modes for maximum compatibility

### LocationService
- GPS location access with permission handling
- Reverse geocoding to get address and place information
- Nearby places search using MapKit
- Real-time location updates with battery optimization
- Privacy-focused location handling (only when needed)

### TravelAIService
- Orchestrates offline AI processing
- Integrates speech recognition with local AI model and location data
- Provides intelligent travel advice without internet connection
- Handles error cases and fallback responses

## Requirements

- iOS 15.0+
- Xcode 15.0+
- Swift 5.0+
- Microphone access permission
- Speech recognition permission

## Setup Instructions

1. **Open the Project**:
   ```bash
   cd RoamlyAI
   open RoamlyAI.xcodeproj
   ```

2. **Configure Signing**:
   - Select your development team in the project settings
   - Update the bundle identifier if needed

3. **Run on Device**:
   - Connect your iOS device
   - Select your device as the target
   - Build and run (⌘+R)

   **Note**: Audio recording and speech recognition require a physical device and won't work in the simulator.

## Permissions

The app requires the following permissions, which are automatically requested:

- **Microphone Access**: For recording voice input
- **Speech Recognition**: For converting speech to text

These permissions are declared in `Info.plist` with user-friendly descriptions.

## 📱 Usage

1. **Launch the App**: Open Roamly AI on your device
2. **Grant Permissions**: Allow microphone and speech recognition access when prompted
3. **Check AI Status**: Look for the green indicator showing "Offline AI Ready"
4. **Start Recording**: Tap and hold the round microphone button
5. **Speak Your Query**: Ask any travel-related question (e.g., "Where should I eat in Tokyo?")
6. **View Live Transcription**: See your words appear in real-time
7. **Release to Process**: Release the button to get an AI-powered response
8. **Read Response**: View the intelligent travel advice generated offline

## 🎯 Example Queries

The offline AI understands various travel topics and can provide location-aware responses:

### Location-Based Queries
- **"What am I looking at?"** - Get detailed information about your current surroundings
- **"Where am I?"** - Learn about your current location and address
- **"What's around me?"** - Discover nearby restaurants, attractions, and points of interest
- **"What's nearby?"** - Find places of interest in your immediate area

### General Travel Topics
- **Weather**: "What should I know about weather in Paris?"
- **Food**: "Where can I find authentic local cuisine?"
- **Hotels**: "What should I consider when booking accommodation?"
- **Attractions**: "What are the must-see places to visit?"
- **Transportation**: "How should I get around the city?"
- **Budget**: "How can I save money while traveling?"
- **Safety**: "What safety precautions should I take?"
- **Culture**: "What cultural customs should I be aware of?"

## 🔧 Technical Features

### Offline Capabilities
- **No Internet Required**: Full AI functionality works without network connection
- **Local Processing**: Uses Apple's Core ML and Natural Language frameworks
- **Smart Intent Recognition**: Understands context and travel-related topics
- **Contextual Responses**: Provides relevant advice based on query analysis

### Performance Optimizations
- **Lightweight AI**: Efficient local processing optimized for mobile devices
- **Memory Management**: Smart loading and unloading of AI resources
- **Battery Efficient**: Minimal power consumption during AI processing
- **Real-time Feedback**: Immediate visual and haptic feedback

## Customization

### UI Styling
- Modify colors and gradients in `LandingView.swift`
- Adjust button size and animations
- Customize fonts and spacing

### AI Integration
- Replace the mock responses in `TravelAIService.swift`
- Add your preferred AI service API (OpenAI, Google AI, etc.)
- Update the `processQuery` method with real API calls

### Audio Settings
- Modify recording quality in `AudioRecorderViewModel.swift`
- Change audio format settings
- Adjust recording parameters

## Future Enhancements

- [ ] Add conversation history
- [ ] Implement text-to-speech for AI responses
- [ ] Add travel-specific features (maps, bookings, etc.)
- [ ] Support for multiple languages
- [ ] Offline mode capabilities
- [ ] Integration with travel APIs

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly on device
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For questions or support, please open an issue in the repository.
