import Foundation
import CoreLocation

@MainActor
class GeoFactsStore: ObservableObject {
    @Published private(set) var downloadedCities: [String] = []
    @Published private(set) var isDownloading = false
    @Published var downloadError: String?

    private let wikipediaService = WikipediaFactsService()
    private let fileManager = FileManager.default

    private var manifest: [CityRecord] = []
    private var factsCache: [String: [GeoFact]] = [:]

    private nonisolated static let defaultRadiusMeters: CLLocationDistance = 750
    private nonisolated static let defaultMaxResults = 8

    init() {
        loadManifest()
    }

    // MARK: - Public API

    func geocodeCandidates(for query: String) async throws -> [GeocodedCity] {
        try await wikipediaService.geocodeCity(query)
    }

    func downloadCity(_ city: GeocodedCity) async throws {
        isDownloading = true
        downloadError = nil
        defer { isDownloading = false }

        do {
            let facts = try await wikipediaService.downloadFacts(for: city)
            try persist(facts: facts, for: city)

            let record = CityRecord(
                name: city.name,
                centerLatitude: city.coordinate.latitude,
                centerLongitude: city.coordinate.longitude,
                downloadedAt: Date(),
                factCount: facts.count
            )
            manifest.removeAll { $0.name.caseInsensitiveCompare(city.name) == .orderedSame }
            manifest.append(record)
            try saveManifest()

            factsCache[city.name] = facts
            downloadedCities = manifest.map { $0.name }
        } catch {
            downloadError = error.localizedDescription
            throw error
        }
    }

    func deleteCity(_ name: String) {
        manifest.removeAll { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        try? saveManifest()
        factsCache.removeValue(forKey: name)
        try? fileManager.removeItem(at: cityDirectory(for: name))
        downloadedCities = manifest.map { $0.name }
    }

    func recordInfo(for name: String) -> (factCount: Int, downloadedAt: Date)? {
        guard let record = manifest.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else {
            return nil
        }
        return (record.factCount, record.downloadedAt)
    }

    /// Facts near a coordinate, drawn from across every downloaded city — capped to `maxResults`,
    /// sorted nearest-first. Deliberately searches all downloaded cities rather than just
    /// whichever one has the closest center point: a user standing near the edge of one city's
    /// coverage could otherwise get zero facts just because a *different* city's centroid happens
    /// to be closer, even though that other city has nothing actually nearby. Returns `[]` when
    /// nothing is downloaded or nothing falls within `radiusMeters`, which is distinct from (and
    /// should not be conflated with) a download/lookup error.
    func facts(
        near coordinate: CLLocationCoordinate2D,
        radiusMeters: CLLocationDistance = defaultRadiusMeters,
        maxResults: Int = defaultMaxResults
    ) -> [GeoFact] {
        guard !manifest.isEmpty else { return [] }
        let queryLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        var candidates: [(GeoFact, CLLocationDistance)] = []
        for record in manifest {
            for fact in loadFactsIfNeeded(for: record.name) {
                let distance = fact.location.distance(from: queryLocation)
                if distance <= radiusMeters {
                    candidates.append((fact, distance))
                }
            }
        }

        return candidates
            .sorted { $0.1 < $1.1 }
            .prefix(maxResults)
            .map { $0.0 }
    }

    private func loadFactsIfNeeded(for cityName: String) -> [GeoFact] {
        if let cached = factsCache[cityName] {
            return cached
        }
        guard let loaded = try? loadFacts(for: cityName) else { return [] }
        factsCache[cityName] = loaded
        return loaded
    }

    // MARK: - Persistence

    private var baseDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("GeoFacts", isDirectory: true)
    }

    private var manifestURL: URL {
        baseDirectory.appendingPathComponent("manifest.json")
    }

    private func cityDirectory(for name: String) -> URL {
        baseDirectory.appendingPathComponent(sanitize(name), isDirectory: true)
    }

    private func factsURL(for name: String) -> URL {
        cityDirectory(for: name).appendingPathComponent("facts.json")
    }

    private func sanitize(_ name: String) -> String {
        let cleaned = name.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return cleaned.isEmpty ? "city" : cleaned
    }

    private func ensureBaseDirectoryExists() throws {
        guard !fileManager.fileExists(atPath: baseDirectory.path) else { return }
        try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        var directory = baseDirectory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? directory.setResourceValues(values)
    }

    private func persist(facts: [GeoFact], for city: GeocodedCity) throws {
        try ensureBaseDirectoryExists()
        let directory = cityDirectory(for: city.name)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let data = try JSONEncoder().encode(facts)
        try data.write(to: factsURL(for: city.name), options: .atomic)
    }

    private func loadFacts(for cityName: String) throws -> [GeoFact] {
        let data = try Data(contentsOf: factsURL(for: cityName))
        return try JSONDecoder().decode([GeoFact].self, from: data)
    }

    private func loadManifest() {
        guard let data = try? Data(contentsOf: manifestURL),
              let records = try? JSONDecoder().decode([CityRecord].self, from: data) else {
            manifest = []
            downloadedCities = []
            return
        }
        manifest = records
        downloadedCities = records.map { $0.name }
    }

    private func saveManifest() throws {
        try ensureBaseDirectoryExists()
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: manifestURL, options: .atomic)
    }
}

private struct CityRecord: Codable {
    let name: String
    let centerLatitude: Double
    let centerLongitude: Double
    let downloadedAt: Date
    let factCount: Int
}
