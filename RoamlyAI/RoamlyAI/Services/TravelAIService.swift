import Foundation
import Combine

@MainActor
class TravelAIService: ObservableObject {
    @Published var isProcessing = false
    @Published var isOfflineMode = true // Default to offline mode

    private let gemmaManager = GemmaModelManager()
    private let locationService = LocationService()
    private var cancellables = Set<AnyCancellable>()

    var locationManager: LocationService {
        return locationService
    }

    init() {
        // Forward nested ObservableObject changes so views observing
        // TravelAIService also re-render when gemmaManager/locationService change.
        gemmaManager.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        locationService.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // Initialize Gemma model on startup
        Task {
            await gemmaManager.loadLocalModel()
        }
    }
    
    func processQuery(_ query: String) async throws -> String {
        DispatchQueue.main.async {
            self.isProcessing = true
        }
        
        defer {
            DispatchQueue.main.async {
                self.isProcessing = false
            }
        }
        
        // Try offline processing first
        if gemmaManager.isModelLoaded {
            do {
                // Get current location info if needed
                let locationInfo = await locationService.getCurrentLocationInfo()
                let response = try await gemmaManager.generateResponse(for: query, locationInfo: locationInfo)
                return response
            } catch {
                print("Offline processing failed: \(error)")
                // Fall back to mock response if model fails
                return generateFallbackResponse(for: query)
            }
        } else {
            // Model not loaded, use fallback
            return generateFallbackResponse(for: query)
        }
    }
    
    var modelManager: GemmaModelManager {
        return gemmaManager
    }
    
    private func generateFallbackResponse(for query: String) -> String {
        let lowercaseQuery = query.lowercased()
        
        if lowercaseQuery.contains("weather") {
            return "🌤️ I'd recommend checking current weather conditions for your destination. Weather can change quickly, so it's best to check a reliable weather app for the most up-to-date forecast."
        } else if lowercaseQuery.contains("restaurant") || lowercaseQuery.contains("food") {
            return "🍽️ For great local dining, I suggest looking for restaurants with high ratings and recent reviews. Consider trying local specialties and asking locals for their favorite spots!"
        } else if lowercaseQuery.contains("hotel") || lowercaseQuery.contains("accommodation") {
            return "🏨 When choosing accommodations, consider location, amenities, and guest reviews. Book early for better rates and availability, especially during peak seasons."
        } else if lowercaseQuery.contains("attraction") || lowercaseQuery.contains("things to do") {
            return "🎯 Every destination has unique attractions! Research must-see landmarks, local experiences, and hidden gems. Consider purchasing city passes for multiple attractions."
        } else if lowercaseQuery.contains("transport") || lowercaseQuery.contains("getting around") {
            return "🚌 Research local transportation options like public transit, ride-sharing, or bike rentals. Download relevant transit apps and consider getting travel cards for savings."
        } else {
            return "✈️ I'm here to help with your travel planning! Ask me about destinations, accommodations, dining, attractions, or transportation. What would you like to know more about?"
        }
    }
}
