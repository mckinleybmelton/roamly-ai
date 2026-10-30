# Roamly AI

A SwiftUI iOS prototype. Tap the microphone to start or stop continuous listening, and Roamly answers travel questions on the device.

Open `RoamlyAI/RoamlyAI.xcodeproj` and build the **RoamlyAI** target (bundle id `com.roamly.RoamlyAI`, iOS 15.0, Swift 5, iPhone and iPad). `RoamlyAI/RoamlyAI.xcworkspace` only wraps that project. There is no shared scheme checked in, so build the RoamlyAI target directly.

## What the app does

The landing screen is `LandingView`.

- Tap the white microphone to start continuous listening. Tap the red stop button to stop. Live transcription shows while you talk. An audio-session interruption (a phone call, for example) pauses listening and can resume it.
- A separate status row shows location permission: Location Available, Getting Location..., Location Ready, Location Disabled, Location Pending, or Location Error.
- Replies are keyword templates in `GemmaModelManager` for weather, food, stay, sights, transport, budget, safety, culture, and location-phrased questions. On iOS 26, when Apple Foundation Models are available, `FoundationModelBridge` answers with on-device generation grounded by cached Wikipedia `GeoFact`s.
- The map-pin sheet is `DestinationSetupView`. Search a city, download English Wikipedia geo extracts through `WikipediaFactsService`, cache them in `GeoFactsStore`, or delete a city. That download needs a network. Nearby place names come from MapKit local search. Cached facts keep working offline. If a download fails, the sheet shows the existing error caption and the spinner stops.
- Questions and replies stay on the landing screen for the rest of the launch, oldest first. Force-quit or relaunch clears them. They are not saved to disk.

## Status row

The model dot and caption show the reply engine before the first question:

| State | Dot | Caption |
| --- | --- | --- |
| Loading | Orange | Loading AI Model... |
| On-device generation available | Green | On-Device AI Ready |
| Keyword templates | Yellow | Basic Replies Ready |
| Both reply paths produced no text | Red | AI Unavailable |

"Basic Replies Ready" means keyword and template replies, including a launch with no `SentimentClassifier.mlmodelc` in the bundle. "Offline AI Ready" is not used. Airplane mode does not turn the row red: on-device replies still work offline. "AI Unavailable" is a question where Foundation Models and the keyword templates both returned no text. The footer then shows "Couldn't produce a reply".

## Speech

Speech recognition is on-device only (`requiresOnDeviceRecognition`), locale English (US). Online and offline use the same path. Audio is not sent to Apple's speech servers.

When on-device recognition is unavailable, or after three consecutive in-session recognition errors, the landing screen says "On-device speech isn’t available" and "Roamly won’t send your voice to Apple’s servers." The microphone does not start. A successful recognition result resets the failure count.

The microphone needs a physical device. Speech recognition does not run in the Simulator.

Denying microphone or speech permission keeps the previous landing behavior. It does not use the on-device-unavailable copy.

## Permissions

`Info.plist` asks for the microphone, speech recognition, and location when in use.

## Project layout

```
RoamlyAI/
├── RoamlyAI.xcodeproj
├── RoamlyAI/
│   ├── RoamlyAIApp.swift
│   ├── Views/
│   │   ├── LandingView.swift
│   │   └── DestinationSetupView.swift
│   ├── Models/
│   │   └── GeoFact.swift
│   └── Services/
│       ├── SpeechRecognitionService.swift
│       ├── TravelAIService.swift
│       ├── GemmaModelManager.swift
│       ├── ReplyEngineStatus.swift
│       ├── FoundationModelBridge.swift
│       ├── LocationService.swift
│       ├── WikipediaFactsService.swift
│       └── GeoFactsStore.swift
└── LinuxChecks/
    └── ReplyEngineStatusChecks.swift
```

`LinuxChecks/ReplyEngineStatusChecks.swift` is not part of the Xcode target. On a machine with Swift it checks the status decision:

```bash
swiftc LinuxChecks/ReplyEngineStatusChecks.swift RoamlyAI/RoamlyAI/Services/ReplyEngineStatus.swift -o /tmp/reply-engine-status-checks
/tmp/reply-engine-status-checks
```

A clean iOS Simulator build has to be run on a Mac. This repository does not include that CI job.
