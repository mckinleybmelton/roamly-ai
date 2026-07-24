import Foundation
import CoreLocation

struct GeoFact: Identifiable, Codable {
    let id: UUID
    let pageID: Int
    let title: String
    let summary: String
    let latitude: Double
    let longitude: Double
    let city: String
    let sourceURL: String?
    let cachedAt: Date

    init(pageID: Int, title: String, summary: String, latitude: Double, longitude: Double, city: String, sourceURL: String?) {
        self.id = UUID()
        self.pageID = pageID
        self.title = title
        self.summary = GeoFact.truncate(summary)
        self.latitude = latitude
        self.longitude = longitude
        self.city = city
        self.sourceURL = sourceURL
        self.cachedAt = Date()
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    private static let summaryCharacterLimit = 600

    private static func truncate(_ text: String) -> String {
        guard text.count > summaryCharacterLimit else { return text }
        return String(text.prefix(summaryCharacterLimit)) + "…"
    }
}
