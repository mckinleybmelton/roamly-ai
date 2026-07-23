import Foundation
import CoreLocation

struct GeocodedCity: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let country: String?
    let administrativeArea: String?

    var displayName: String {
        [name, administrativeArea, country]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

enum WikipediaFactsError: Error, LocalizedError {
    case cityNotFound
    case invalidRequest
    case requestFailed

    var errorDescription: String? {
        switch self {
        case .cityNotFound:
            return "Couldn't find that city. Try a more specific name."
        case .invalidRequest:
            return "Couldn't build the request for Wikipedia."
        case .requestFailed:
            return "Couldn't reach Wikipedia. Check your connection and try again."
        }
    }
}

final class WikipediaFactsService {
    private static let userAgent = "RoamlyAI-iOS/1.0 (https://github.com/mckinleybmelton/roamly-ai)"
    private static let gridSpacingMeters = 8000.0
    private static let cellRadiusMeters = 10000
    private static let pageLimit = 50
    private static let maxPagesPerCell = 5

    private let geocoder = CLGeocoder()
    private let session = URLSession.shared

    func geocodeCity(_ name: String) async throws -> [GeocodedCity] {
        let placemarks = try await geocoder.geocodeAddressString(name)
        guard !placemarks.isEmpty else { throw WikipediaFactsError.cityNotFound }

        return placemarks.compactMap { placemark -> GeocodedCity? in
            guard let location = placemark.location else { return nil }
            return GeocodedCity(
                name: placemark.locality ?? placemark.name ?? name,
                coordinate: location.coordinate,
                country: placemark.country,
                administrativeArea: placemark.administrativeArea
            )
        }
    }

    func downloadFacts(for city: GeocodedCity) async throws -> [GeoFact] {
        let gridPoints = gridOffsets(around: city.coordinate, spacingMeters: Self.gridSpacingMeters)
        var mergedFacts: [Int: GeoFact] = [:]

        try await withThrowingTaskGroup(of: Result<[GeoFact], Error>.self) { group in
            for point in gridPoints {
                group.addTask {
                    do {
                        return .success(try await self.fetchCell(center: point, cityName: city.name))
                    } catch {
                        return .failure(error)
                    }
                }
            }

            var sawSuccess = false
            var lastError: Error?
            for try await result in group {
                switch result {
                case .success(let facts):
                    sawSuccess = true
                    for fact in facts {
                        mergedFacts[fact.pageID] = fact
                    }
                case .failure(let error):
                    lastError = error
                }
            }

            if !sawSuccess, let lastError {
                throw lastError
            }
        }

        return Array(mergedFacts.values)
    }

    // MARK: - Grid

    private func gridOffsets(around center: CLLocationCoordinate2D, spacingMeters: Double) -> [CLLocationCoordinate2D] {
        let metersPerDegreeLat = 111_320.0
        let metersPerDegreeLon = 111_320.0 * cos(center.latitude * .pi / 180)
        guard metersPerDegreeLon > 0 else { return [center] }

        let offsets: [Double] = [-1, 0, 1]
        var points: [CLLocationCoordinate2D] = []
        for latOffset in offsets {
            for lonOffset in offsets {
                let dLat = (latOffset * spacingMeters) / metersPerDegreeLat
                let dLon = (lonOffset * spacingMeters) / metersPerDegreeLon
                points.append(CLLocationCoordinate2D(latitude: center.latitude + dLat, longitude: center.longitude + dLon))
            }
        }
        return points
    }

    // MARK: - Network

    private func fetchCell(center: CLLocationCoordinate2D, cityName: String) async throws -> [GeoFact] {
        var facts: [GeoFact] = []
        var continueParams: [String: String]?
        var requestCount = 0

        repeat {
            try Task.checkCancellation()

            guard let url = Self.buildURL(center: center, continueParams: continueParams) else {
                throw WikipediaFactsError.invalidRequest
            }

            var request = URLRequest(url: url)
            request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                throw WikipediaFactsError.requestFailed
            }

            let decoded = try JSONDecoder().decode(MediaWikiResponse.self, from: data)

            if let pages = decoded.query?.pages {
                for page in pages {
                    guard let extract = page.extract, !extract.isEmpty,
                          let coordinate = page.coordinates?.first else {
                        continue
                    }
                    facts.append(GeoFact(
                        pageID: page.pageid,
                        title: page.title,
                        summary: extract,
                        latitude: coordinate.lat,
                        longitude: coordinate.lon,
                        city: cityName,
                        sourceURL: Self.wikipediaURL(forTitle: page.title)
                    ))
                }
            }

            continueParams = decoded.continue?.mapValues { $0.stringValue }
            requestCount += 1
        } while continueParams != nil && requestCount < Self.maxPagesPerCell

        return facts
    }

    /// Builds a Wikipedia article URL from a page title, percent-encoding everything beyond
    /// RFC 3986 unreserved characters (not just spaces) — Wikipedia titles can legitimately
    /// contain '&', '#', '?', '/', and non-ASCII characters that would otherwise produce a
    /// malformed or misinterpreted URL.
    private static func wikipediaURL(forTitle title: String) -> String? {
        let underscored = title.replacingOccurrences(of: " ", with: "_")
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        guard let encoded = underscored.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return nil
        }
        return "https://en.wikipedia.org/wiki/\(encoded)"
    }

    private static func buildURL(center: CLLocationCoordinate2D, continueParams: [String: String]?) -> URL? {
        var components = URLComponents(string: "https://en.wikipedia.org/w/api.php")
        var items: [URLQueryItem] = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "formatversion", value: "2"),
            URLQueryItem(name: "generator", value: "geosearch"),
            URLQueryItem(name: "ggscoord", value: "\(center.latitude)|\(center.longitude)"),
            URLQueryItem(name: "ggsradius", value: "\(cellRadiusMeters)"),
            URLQueryItem(name: "ggslimit", value: "\(pageLimit)"),
            URLQueryItem(name: "prop", value: "extracts|coordinates"),
            URLQueryItem(name: "exintro", value: "1"),
            URLQueryItem(name: "explaintext", value: "1"),
            URLQueryItem(name: "exchars", value: "600"),
            URLQueryItem(name: "colimit", value: "\(pageLimit)"),
        ]
        // MediaWiki's continuation protocol requires echoing back every key it returned in
        // "continue" verbatim — which key(s) appear depends on which prop/generator is the
        // limiting factor (e.g. "excontinue" for extracts, not just "ggscontinue" for geosearch),
        // so this must stay generic rather than hardcoding specific expected key names.
        if let continueParams {
            for (key, value) in continueParams {
                items.append(URLQueryItem(name: key, value: value))
            }
        }
        components?.queryItems = items
        return components?.url
    }
}

// MARK: - MediaWiki response models

private struct MediaWikiResponse: Decodable {
    let `continue`: [String: MediaWikiContinueValue]?
    let query: MediaWikiQuery?
}

/// MediaWiki continuation values can be strings or numbers depending on the key; decode either
/// and normalize to a string for re-encoding as a query parameter on the next request.
private struct MediaWikiContinueValue: Decodable {
    let stringValue: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            stringValue = string
        } else if let int = try? container.decode(Int.self) {
            stringValue = String(int)
        } else {
            stringValue = try String(container.decode(Double.self))
        }
    }
}

private struct MediaWikiQuery: Decodable {
    let pages: [MediaWikiPage]?
}

private struct MediaWikiPage: Decodable {
    let pageid: Int
    let title: String
    let extract: String?
    let coordinates: [MediaWikiCoordinate]?
}

private struct MediaWikiCoordinate: Decodable {
    let lat: Double
    let lon: Double
}
