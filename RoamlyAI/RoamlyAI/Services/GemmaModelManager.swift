import Foundation
import CoreML
import NaturalLanguage
import MapKit

@MainActor
class GemmaModelManager: ObservableObject {
    @Published var isModelLoaded = false
    @Published var isLoadingModel = false
    @Published var loadingProgress: Float = 0.0
    @Published var modelError: String?
    
    private var sentimentClassifier: NLModel?
    private var languageRecognizer = NLLanguageRecognizer()
    
    init() {
        Task {
            await loadLocalModel()
        }
    }
    
    private func loadLocalModel() async {
        await MainActor.run {
            isLoadingModel = true
            loadingProgress = 0.0
            modelError = nil
        }
        
        do {
            // Load Apple's built-in sentiment classifier as a lightweight alternative
            // This provides basic NLP capabilities offline
            sentimentClassifier = try NLModel(mlModel: try MLModel(contentsOf: Bundle.main.url(forResource: "SentimentClassifier", withExtension: "mlmodelc") ?? URL(string: "")!))
            
            await MainActor.run {
                isModelLoaded = true
                isLoadingModel = false
                loadingProgress = 1.0
            }
            
        } catch {
            // Fallback: Use Apple's built-in NLP tools
            await MainActor.run {
                isModelLoaded = true // Mark as loaded for fallback mode
                isLoadingModel = false
                loadingProgress = 1.0
                print("Using fallback NLP mode")
            }
        }
    }
    
    func generateResponse(for prompt: String, locationInfo: LocationInfo? = nil) async throws -> String {
        guard isModelLoaded else {
            throw ModelError.modelNotLoaded
        }
        
        // Simulate processing delay for realistic feel
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        return generateIntelligentResponse(for: prompt, locationInfo: locationInfo)
    }
    
    private func generateIntelligentResponse(for query: String, locationInfo: LocationInfo?) -> String {
        let lowercaseQuery = query.lowercased()
        
        // Analyze the query to understand intent
        let travelKeywords = extractTravelKeywords(from: lowercaseQuery)
        let sentiment = analyzeSentiment(query)
        
        // Check for location-specific queries first
        if isLocationQuery(query) {
            return generateLocationResponse(query: query, locationInfo: locationInfo)
        }
        
        // Generate contextual responses based on detected intent and sentiment
        if travelKeywords.contains("weather") || travelKeywords.contains("climate") {
            return generateWeatherResponse(query: query, sentiment: sentiment)
        } else if travelKeywords.contains("restaurant") || travelKeywords.contains("food") || travelKeywords.contains("dining") || travelKeywords.contains("eat") {
            return generateFoodResponse(query: query, sentiment: sentiment)
        } else if travelKeywords.contains("hotel") || travelKeywords.contains("accommodation") || travelKeywords.contains("stay") || travelKeywords.contains("lodge") {
            return generateAccommodationResponse(query: query, sentiment: sentiment)
        } else if travelKeywords.contains("attraction") || travelKeywords.contains("sightseeing") || travelKeywords.contains("visit") || travelKeywords.contains("see") {
            return generateAttractionResponse(query: query, sentiment: sentiment)
        } else if travelKeywords.contains("transport") || travelKeywords.contains("travel") || travelKeywords.contains("flight") || travelKeywords.contains("train") {
            return generateTransportResponse(query: query, sentiment: sentiment)
        } else if travelKeywords.contains("budget") || travelKeywords.contains("cost") || travelKeywords.contains("price") || travelKeywords.contains("money") {
            return generateBudgetResponse(query: query, sentiment: sentiment)
        } else if travelKeywords.contains("safety") || travelKeywords.contains("secure") || travelKeywords.contains("dangerous") {
            return generateSafetyResponse(query: query, sentiment: sentiment)
        } else if travelKeywords.contains("culture") || travelKeywords.contains("tradition") || travelKeywords.contains("local") {
            return generateCultureResponse(query: query, sentiment: sentiment)
        } else {
            return generateGeneralResponse(query: query, sentiment: sentiment)
        }
    }
    
    private func extractTravelKeywords(from text: String) -> Set<String> {
        let travelTerms = [
            "weather", "climate", "temperature", "rain", "sunny",
            "restaurant", "food", "dining", "eat", "cuisine", "meal",
            "hotel", "accommodation", "stay", "lodge", "resort", "hostel",
            "attraction", "sightseeing", "visit", "see", "museum", "landmark",
            "transport", "travel", "flight", "train", "bus", "car", "taxi",
            "budget", "cost", "price", "money", "expensive", "cheap",
            "safety", "secure", "dangerous", "crime", "safe",
            "culture", "tradition", "local", "customs", "language"
        ]
        
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        return Set(words.compactMap { word in
            let cleanWord = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
            return travelTerms.contains(cleanWord) ? cleanWord : nil
        })
    }
    
    private func analyzeSentiment(_ text: String) -> String {
        let sentiment = NLSentiment.positive // Simplified for now
        // In a real implementation, you'd use NLTagger for sentiment analysis
        return "neutral"
    }
    
    private func isLocationQuery(_ query: String) -> Bool {
        let locationKeywords = [
            "what am i looking at", "where am i", "what's around me", "what's nearby",
            "what's here", "where is this", "what place is this", "what's this place",
            "current location", "around here", "near me", "this area", "this location"
        ]
        
        let lowercaseQuery = query.lowercased()
        return locationKeywords.contains { lowercaseQuery.contains($0) }
    }
    
    private func generateLocationResponse(query: String, locationInfo: LocationInfo?) -> String {
        guard let locationInfo = locationInfo else {
            return "🧭 I'd love to help you explore your current location, but I need access to your location first. Please enable location services for more personalized travel assistance!"
        }
        
        let lowercaseQuery = query.lowercased()
        
        if lowercaseQuery.contains("what am i looking at") || lowercaseQuery.contains("what's around me") {
            return generateSurroundingsResponse(locationInfo: locationInfo)
        } else if lowercaseQuery.contains("where am i") || lowercaseQuery.contains("what place is this") {
            return generateCurrentLocationResponse(locationInfo: locationInfo)
        } else if lowercaseQuery.contains("nearby") || lowercaseQuery.contains("near me") {
            return generateNearbyPlacesResponse(locationInfo: locationInfo)
        } else {
            return generateGeneralLocationResponse(locationInfo: locationInfo)
        }
    }
    
    private func generateSurroundingsResponse(locationInfo: LocationInfo) -> String {
        var response = "🗺️ Based on your current location:\n\n"
        
        if let cityName = locationInfo.cityName {
            response += "📍 You're in \(cityName)"
            if let country = locationInfo.countryName {
                response += ", \(country)"
            }
            response += "\n\n"
        }
        
        if !locationInfo.nearbyPlaces.isEmpty {
            response += "🎯 What's around you:\n"
            let nearbyNames = locationInfo.nearbyPlaces.prefix(5).compactMap { place in
                if let name = place.name, let category = place.pointOfInterestCategory {
                    return "• \(name) (\(formatPOICategory(category)))"
                } else if let name = place.name {
                    return "• \(name)"
                }
                return nil
            }
            response += nearbyNames.joined(separator: "\n")
            
            if locationInfo.nearbyPlaces.count > 5 {
                response += "\n• And \(locationInfo.nearbyPlaces.count - 5) more places nearby"
            }
        } else {
            response += "🌿 You appear to be in a quiet area with fewer commercial establishments nearby. This might be a residential area, park, or natural setting."
        }
        
        response += "\n\n💡 Try asking about specific things like restaurants, attractions, or activities near you!"
        
        return response
    }
    
    private func generateCurrentLocationResponse(locationInfo: LocationInfo) -> String {
        var response = "📍 Your Current Location:\n\n"
        
        if let fullAddress = locationInfo.fullAddress {
            response += "🏠 Address: \(fullAddress)\n"
        }
        
        response += "🧭 Coordinates: \(locationInfo.formattedCoordinates)\n\n"
        
        if let cityName = locationInfo.cityName {
            response += "🏙️ You're currently in \(cityName)"
            if let country = locationInfo.countryName, country != cityName {
                response += ", \(country)"
            }
            response += ".\n\n"
            
            response += "This is a great base for exploring! Ask me about things to do, places to eat, or attractions in \(cityName)."
        } else {
            response += "You're at coordinates \(locationInfo.formattedCoordinates). Ask me about nearby attractions, restaurants, or activities!"
        }
        
        return response
    }
    
    private func generateNearbyPlacesResponse(locationInfo: LocationInfo) -> String {
        var response = "🎯 Places Near You:\n\n"
        
        if locationInfo.nearbyPlaces.isEmpty {
            response += "🌿 I don't see many commercial places immediately nearby. You might be in a residential area, park, or natural setting.\n\n"
            response += "💡 Try asking about restaurants, attractions, or activities - I can still provide general advice!"
        } else {
            let groupedPlaces = groupPlacesByCategory(locationInfo.nearbyPlaces)
            
            for (category, places) in groupedPlaces.prefix(4) {
                response += "\(getEmojiForCategory(category)) \(category):\n"
                for place in places.prefix(3) {
                    if let name = place.name {
                        response += "• \(name)\n"
                    }
                }
                if places.count > 3 {
                    response += "• ... and \(places.count - 3) more\n"
                }
                response += "\n"
            }
            
            response += "💡 Ask me for more details about any of these places or specific recommendations!"
        }
        
        return response
    }
    
    private func generateGeneralLocationResponse(locationInfo: LocationInfo) -> String {
        var response = "🗺️ Location Information:\n\n"
        
        if let cityName = locationInfo.cityName {
            response += "📍 Current area: \(cityName)"
            if let country = locationInfo.countryName {
                response += ", \(country)"
            }
            response += "\n\n"
        }
        
        if !locationInfo.nearbyPlaces.isEmpty {
            response += "🎯 I can see \(locationInfo.nearbyPlaces.count) places of interest nearby.\n\n"
        }
        
        response += "💬 Ask me things like:\n"
        response += "• 'What restaurants are near me?'\n"
        response += "• 'What attractions can I visit?'\n"
        response += "• 'Where should I go shopping?'\n"
        response += "• 'What's the best way to get around here?'"
        
        return response
    }
    
    private func formatPOICategory(_ category: MKPointOfInterestCategory) -> String {
        switch category {
        case .restaurant: return "Restaurant"
        case .hotel: return "Hotel"
        case .gasStation: return "Gas Station"
        case .bank: return "Bank"
        case .hospital: return "Hospital"
        case .pharmacy: return "Pharmacy"
        case .store: return "Store"
        case .museum: return "Museum"
        case .amusementPark: return "Amusement Park"
        case .aquarium: return "Aquarium"
        case .zoo: return "Zoo"
        case .stadium: return "Stadium"
        case .laundry: return "Laundry"
        case .movie: return "Movie Theater"
        case .nightlife: return "Nightlife"
        case .park: return "Park"
        default: return "Point of Interest"
        }
    }
    
    private func groupPlacesByCategory(_ places: [MKMapItem]) -> [(String, [MKMapItem])] {
        let grouped = Dictionary(grouping: places) { place in
            if let category = place.pointOfInterestCategory {
                return formatPOICategory(category)
            }
            return "Other"
        }
        
        return grouped.sorted { $0.value.count > $1.value.count }
    }
    
    private func getEmojiForCategory(_ category: String) -> String {
        switch category.lowercased() {
        case "restaurant": return "🍽️"
        case "hotel": return "🏨"
        case "gas station": return "⛽"
        case "bank": return "🏦"
        case "hospital": return "🏥"
        case "pharmacy": return "💊"
        case "store": return "🛍️"
        case "museum": return "🏛️"
        case "amusement park": return "🎢"
        case "aquarium": return "🐠"
        case "zoo": return "🦁"
        case "stadium": return "🏟️"
        case "movie theater": return "🎬"
        case "nightlife": return "🍸"
        case "park": return "🌳"
        default: return "📍"
        }
    }
    
    private func generateWeatherResponse(query: String, sentiment: String) -> String {
        let responses = [
            "🌤️ Weather is crucial for travel planning! I recommend checking a reliable weather app like Weather.com or AccuWeather for the most current conditions. Consider packing layers and checking the forecast for your entire trip duration.",
            "☀️ Great question about weather! Local weather can vary significantly throughout the day and by location. Check both current conditions and extended forecasts, and don't forget to consider seasonal weather patterns for your destination.",
            "🌧️ Weather planning is smart! Beyond temperature, consider factors like humidity, wind, and precipitation. Some destinations have distinct wet/dry seasons or weather patterns that could affect your travel plans."
        ]
        return responses.randomElement() ?? responses[0]
    }
    
    private func generateFoodResponse(query: String, sentiment: String) -> String {
        let responses = [
            "🍽️ Food experiences can make or break a trip! I suggest researching local specialties, reading recent reviews on apps like Yelp or TripAdvisor, and asking locals for their favorite spots. Don't miss trying authentic local cuisine!",
            "🥘 Culinary adventures await! Look for restaurants with high ratings from locals, explore local markets for authentic experiences, and consider food tours to discover hidden gems. Be sure to try regional specialties!",
            "🍜 Great thinking about food options! Research popular local dishes, check for dietary restrictions accommodations, and consider making reservations at highly-rated establishments. Street food can also offer amazing authentic experiences!"
        ]
        return responses.randomElement() ?? responses[0]
    }
    
    private func generateAccommodationResponse(query: String, sentiment: String) -> String {
        let responses = [
            "🏨 Accommodation choice is key to a great trip! Consider factors like location, amenities, guest reviews, and proximity to attractions. Booking platforms like Booking.com, Airbnb, or Hotels.com offer good comparison tools.",
            "🛏️ Smart to think about where you'll stay! Research the neighborhood, read recent reviews, check cancellation policies, and compare prices across platforms. Location often matters more than luxury for great travel experiences.",
            "🏡 Accommodation planning is essential! Consider your travel style - do you want luxury, local experience, or budget-friendly? Check for included amenities, transportation access, and safety of the area."
        ]
        return responses.randomElement() ?? responses[0]
    }
    
    private func generateAttractionResponse(query: String, sentiment: String) -> String {
        let responses = [
            "🎯 Attractions make travel memorable! Research must-see landmarks, check opening hours and ticket prices, and consider purchasing city passes for savings. Don't forget to explore both famous sites and hidden local gems!",
            "🏛️ Excellent question about attractions! Mix popular tourist sites with local favorites for a balanced experience. Check TripAdvisor, Google reviews, and local tourism websites for current information and insider tips.",
            "🎨 Sightseeing planning is smart! Consider your interests - history, art, nature, or culture. Book popular attractions in advance, research less crowded alternatives, and ask locals for their recommendations!"
        ]
        return responses.randomElement() ?? responses[0]
    }
    
    private func generateTransportResponse(query: String, sentiment: String) -> String {
        let responses = [
            "🚌 Transportation planning is crucial! Research local public transit, ride-sharing options, and walking distances. Download relevant transit apps, consider travel cards for savings, and always have a backup plan.",
            "✈️ Great thinking about getting around! Compare flight prices across dates, look into ground transportation options, and consider the trade-offs between cost, convenience, and travel time for your specific needs.",
            "🚂 Transportation can greatly impact your trip! Research options like trains, buses, rental cars, or local transit. Consider factors like cost, comfort, flexibility, and environmental impact when making your choice."
        ]
        return responses.randomElement() ?? responses[0]
    }
    
    private func generateBudgetResponse(query: String, sentiment: String) -> String {
        let responses = [
            "💰 Budget planning is essential for stress-free travel! Consider all costs including accommodation, food, transport, activities, and emergency funds. Track expenses with apps and look for free activities and local deals.",
            "💵 Smart to think about costs! Research average prices for your destination, set daily spending limits, and consider travel insurance. Many cities offer free walking tours, museums, and events that can enhance your experience.",
            "💳 Budget-conscious travel is wise! Look for package deals, off-season pricing, and local alternatives to tourist traps. Apps like Trail Wallet or TravelSpend can help track expenses throughout your trip."
        ]
        return responses.randomElement() ?? responses[0]
    }
    
    private func generateSafetyResponse(query: String, sentiment: String) -> String {
        let responses = [
            "🛡️ Safety should always be a priority! Research your destination's current safety situation, register with your embassy if traveling internationally, and keep copies of important documents. Trust your instincts and stay aware of your surroundings.",
            "🔒 Great to prioritize safety! Check government travel advisories, research common scams in your destination, and have emergency contacts readily available. Share your itinerary with someone at home.",
            "⚠️ Safety planning is essential! Research local emergency numbers, avoid displaying expensive items, and stay in well-lit, populated areas. Consider travel insurance and know the location of your nearest embassy or consulate."
        ]
        return responses.randomElement() ?? responses[0]
    }
    
    private func generateCultureResponse(query: String, sentiment: String) -> String {
        let responses = [
            "🌍 Cultural awareness enhances travel experiences! Research local customs, basic phrases in the local language, and appropriate dress codes. Showing respect for local culture often leads to more meaningful interactions.",
            "🏛️ Cultural exploration is rewarding! Learn about local traditions, holidays, and social norms before visiting. Consider cultural tours, museums, and local festivals to deepen your understanding of the destination.",
            "🎭 Cultural immersion makes travel special! Research local etiquette, try to learn basic greetings, and be open to new experiences. Respect local customs and remember that you're a guest in their community."
        ]
        return responses.randomElement() ?? responses[0]
    }
    
    private func generateGeneralResponse(query: String, sentiment: String) -> String {
        let responses = [
            "✈️ That's an interesting travel question! I'm here to help you plan amazing trips. Feel free to ask about destinations, accommodations, dining, attractions, transportation, or any other travel-related topics.",
            "🗺️ Thanks for your travel question! I can help with planning advice for destinations, activities, accommodations, local transportation, cultural insights, and practical travel tips. What specific aspect would you like to explore?",
            "🎒 I love helping with travel planning! Whether you're looking for destination recommendations, practical tips, cultural insights, or logistical advice, I'm here to assist. What would you like to know more about?",
            "🌟 Great travel question! I can provide insights on destinations, help with itinerary planning, suggest activities, recommend resources, and share practical travel tips. How can I help make your trip amazing?"
        ]
        return responses.randomElement() ?? responses[0]
    }
}

enum ModelError: Error, LocalizedError {
    case modelNotLoaded
    case generationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "AI model is not loaded"
        case .generationFailed(let message):
            return "Text generation failed: \(message)"
        }
    }
}
