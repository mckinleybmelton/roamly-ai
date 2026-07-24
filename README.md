# Roamly AI

**A voice-first travel companion that works without a network connection.**

Roamly AI is an iOS application that answers a traveler's questions — about their surroundings, nearby history, food, transport, and logistics — entirely on-device. There is no server in the request path and no per-query API cost: speech recognition, reasoning, and response generation all happen locally on the phone.

## Why offline matters here

Travel is precisely the situation where connectivity is least reliable and data privacy matters most: roaming charges, dead zones on transit or in older buildings, foreign SIMs that haven't activated yet, and a general reluctance to stream a live GPS feed and voice queries to a third-party server while abroad. A cloud-dependent assistant degrades exactly when a traveler needs it most.

Roamly is built around the opposite assumption: the assistant should work identically in a hotel with no Wi-Fi as it does at home. That constraint shapes every layer of the product, from how it downloads knowledge ahead of time to how it recovers from the model itself being unavailable.

## What it does

- **Push-to-talk and hands-free listening** — a single button starts a continuous listening session; the app detects natural pauses in speech and treats each one as a separate question, so a traveler can ask several things in a row without touching the screen again.
- **Location-aware answers** — "What am I looking at?", "Where am I?", and "What's nearby?" are answered using live GPS, reverse geocoding, and nearby points of interest, without any of it leaving the device.
- **Grounded local history** — ahead of a trip, a traveler downloads a city by name; Roamly then caches real historical and background information tied to specific coordinates around that city, so it can answer with actual facts about a landmark rather than a generic description.
- **On-device generation, with a safety net** — on supported hardware, responses are produced by Apple's on-device language model rather than canned text. Where that model isn't available (older devices, or the feature disabled in Settings), Roamly falls back to a deterministic rules-based response engine so the app never goes silent.
- **Resilient by design** — a phone call, Siri, or another app taking the microphone mid-conversation is treated as an expected event, not a crash: the app pauses cleanly and resumes automatically once the interruption ends.

## How it works, at a glance

```
Voice  ──▶  Speech-to-text  ──▶  Grounding lookup  ──▶  Response generation  ──▶  Spoken-style reply
(mic)       (on-device)          (cached local facts     (on-device LLM, with       (with source
                                   + live GPS/POI data)    rules-engine fallback)     attribution)
```

Before any of that runs, a separate, one-time pipeline does the legwork of building the local knowledge base:

```
City name  ──▶  Geocode  ──▶  Tiled search across the area  ──▶  Historical/background facts,
                                (real public reference data)      tagged to exact coordinates
                                                                          │
                                                                          ▼
                                                      Persisted locally, available offline forever after
```

Everything to the right of the first arrow in both diagrams runs without a network connection once the initial download is complete.

## Product principles

- **Privacy by construction, not by policy.** Voice audio, transcripts, and location data are processed on-device. There is nothing to opt out of, because there is no server collecting it in the first place.
- **Degrade gracefully, never silently.** Every layer of the system — the language model, the location service, the network fetch that builds the local knowledge base — has a defined fallback behavior. The app should always produce *some* honest answer, and should say plainly when it doesn't know something rather than inventing a plausible-sounding one.
- **Don't let the model make things up.** When Roamly answers a question about a specific landmark, it's constrained to only state what's actually in its cached, sourced knowledge base for that location, and it cites the source. If nothing is cached for where the traveler is standing, it says so instead of guessing.

## Technical architecture

The app follows an MVVM structure with a clear separation between UI, orchestration, and the underlying services each capability depends on.

**Presentation layer**
- `LandingView` — the primary voice interface: listening state, live transcription, response display, and status indicators.
- `DestinationSetupView` — city search, download, and management for the local knowledge base.

**Orchestration**
- `TravelAIService` — the single coordination point the UI talks to. It composes the language model, location service, and local knowledge store, and forwards their state changes so the UI stays reactive without needing to know about each dependency individually.

**Core services**
- `SpeechRecognitionService` — continuous speech-to-text via Apple's Speech framework, with pause detection to segment a hands-free session into discrete queries.
- `AudioRecorderViewModel` — manages the underlying audio session, including graceful recovery from interruptions (phone calls, Siri, other apps requesting the microphone).
- `LocationService` — GPS access, reverse geocoding, and nearby-place search via Core Location and MapKit, requested only when needed.
- `GemmaModelManager` — the response-generation layer. Attempts on-device LLM generation first; if that's unavailable, falls back to a topic-classification and template-response engine so the app remains fully functional on any supported device.
- `FoundationModelBridge` — a thin, availability-gated wrapper around Apple's Foundation Models framework, isolating the rest of the codebase from a platform API that's only present on newer OS versions and hardware.
- `WikipediaFactsService` / `GeoFactsStore` — the local knowledge pipeline: geocoding a city, tiling a search grid across it, pulling sourced background facts tied to coordinates, and persisting them for fast, fully offline, GPS-proximity lookup later — across every city a traveler has downloaded, not just the most recent one.

## Technology stack

| Layer | Technology |
|---|---|
| UI | SwiftUI |
| Speech-to-text | Apple Speech framework |
| Audio | AVFoundation |
| On-device generation | Apple Foundation Models (with a rules-based fallback engine) |
| Location & mapping | Core Location, MapKit |
| Local knowledge source | MediaWiki/Wikipedia public API |
| Persistence | Local file storage (Application Support, excluded from iCloud backup) |
| Reactive state | Combine |

## Project structure

```
RoamlyAI/
├── RoamlyAI/
│   ├── RoamlyAIApp.swift                # App entry point
│   ├── Views/
│   │   ├── LandingView.swift            # Primary voice interface
│   │   └── DestinationSetupView.swift   # City download & management
│   ├── ViewModels/
│   │   └── AudioRecorderViewModel.swift # Audio session management
│   ├── Models/
│   │   ├── AudioMessage.swift           # Audio/query data models
│   │   └── GeoFact.swift                # A single cached, geo-tagged fact
│   ├── Services/
│   │   ├── SpeechRecognitionService.swift
│   │   ├── TravelAIService.swift        # Orchestration layer
│   │   ├── GemmaModelManager.swift      # Response generation + fallback
│   │   ├── FoundationModelBridge.swift  # On-device LLM integration
│   │   ├── LocationService.swift        # GPS, geocoding, nearby places
│   │   ├── WikipediaFactsService.swift  # Local knowledge base builder
│   │   └── GeoFactsStore.swift          # Local persistence & proximity lookup
│   ├── Assets.xcassets/
│   └── Info.plist
└── RoamlyAI.xcodeproj/
```

## Requirements

- iOS 15.0+ (core experience); iOS 26.0+ and Apple Intelligence–eligible hardware for on-device LLM generation — the app runs on earlier devices via the fallback response engine
- Xcode 26+
- A physical device for microphone, speech recognition, and on-device model testing (the Simulator cannot fully exercise any of the three)

## Getting started

```bash
cd RoamlyAI
open RoamlyAI.xcodeproj
```

Select a development team under the target's signing settings, choose a physical device as the run destination, and build. On first launch, the app requests microphone, speech recognition, and location permissions — each is explained in-context via the descriptions declared in `Info.plist`.

To try the local knowledge base, open the destination picker from the map-pin icon, search for a city, and download it. Standing near a real location in that city and asking "What am I looking at?" will surface cached, sourced facts about it.

## What's next

- Broader per-city coverage and smarter storage management for downloaded areas
- Persisted conversation history across sessions
- Text-to-speech for fully hands-free round trips

## License

No license file is currently included in this repository.
