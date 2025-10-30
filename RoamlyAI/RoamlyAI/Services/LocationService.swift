import Foundation
import CoreLocation
import MapKit

@MainActor
class LocationService: NSObject, ObservableObject {
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var hasLocationPermission = false
    @Published var locationError: String?
    @Published var isLoadingLocation = false
    @Published var currentPlacemark: CLPlacemark?
    @Published var nearbyPlaces: [MKMapItem] = []
    
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters
        
        authorizationStatus = locationManager.authorizationStatus
        updatePermissionStatus()
    }
    
    func requestLocationPermission() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            locationError = "Location access denied. Please enable in Settings."
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        @unknown default:
            locationError = "Unknown location authorization status"
        }
    }
    
    func startLocationUpdates() {
        guard hasLocationPermission else {
            requestLocationPermission()
            return
        }
        
        isLoadingLocation = true
        locationError = nil
        locationManager.startUpdatingLocation()
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        isLoadingLocation = false
    }
    
    func getCurrentLocationInfo() async -> LocationInfo? {
        guard let location = currentLocation else {
            return nil
        }
        
        do {
            // Get reverse geocoding info
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            let placemark = placemarks.first
            
            await MainActor.run {
                self.currentPlacemark = placemark
            }
            
            // Search for nearby points of interest
            let nearbyItems = await searchNearbyPlaces(around: location)
            
            await MainActor.run {
                self.nearbyPlaces = nearbyItems
            }
            
            return LocationInfo(
                coordinate: location.coordinate,
                placemark: placemark,
                nearbyPlaces: nearbyItems
            )
            
        } catch {
            await MainActor.run {
                self.locationError = "Failed to get location details: \(error.localizedDescription)"
            }
            return LocationInfo(
                coordinate: location.coordinate,
                placemark: nil,
                nearbyPlaces: []
            )
        }
    }
    
    private func searchNearbyPlaces(around location: CLLocation) async -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "restaurants attractions landmarks hotels shopping"
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 1000, // 1km radius
            longitudinalMeters: 1000
        )
        
        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            return Array(response.mapItems.prefix(10)) // Limit to 10 results
        } catch {
            print("Error searching nearby places: \(error)")
            return []
        }
    }
    
    private func updatePermissionStatus() {
        hasLocationPermission = authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
    
    func getLocationDescription() -> String {
        guard let placemark = currentPlacemark else {
            if let coordinate = currentLocation?.coordinate {
                return "Coordinates: \(String(format: "%.4f", coordinate.latitude)), \(String(format: "%.4f", coordinate.longitude))"
            }
            return "Location unavailable"
        }
        
        var components: [String] = []
        
        if let name = placemark.name {
            components.append(name)
        }
        if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }
        if let locality = placemark.locality {
            components.append(locality)
        }
        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }
        if let country = placemark.country {
            components.append(country)
        }
        
        return components.isEmpty ? "Unknown location" : components.joined(separator: ", ")
    }
    
    func getNearbyPlacesDescription() -> String {
        guard !nearbyPlaces.isEmpty else {
            return "No nearby places found"
        }
        
        let placeNames = nearbyPlaces.prefix(5).compactMap { $0.name }
        return "Nearby: " + placeNames.joined(separator: ", ")
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        currentLocation = location
        isLoadingLocation = false
        locationError = nil
        
        // Stop continuous updates to save battery
        // We'll request updates manually when needed
        manager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLoadingLocation = false
        locationError = "Location error: \(error.localizedDescription)"
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        updatePermissionStatus()
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        case .denied, .restricted:
            locationError = "Location access denied"
        case .notDetermined:
            break
        @unknown default:
            locationError = "Unknown authorization status"
        }
    }
}

// MARK: - Supporting Models
struct LocationInfo {
    let coordinate: CLLocationCoordinate2D
    let placemark: CLPlacemark?
    let nearbyPlaces: [MKMapItem]
    
    var formattedCoordinates: String {
        "\(String(format: "%.4f", coordinate.latitude)), \(String(format: "%.4f", coordinate.longitude))"
    }
    
    var cityName: String? {
        placemark?.locality
    }
    
    var countryName: String? {
        placemark?.country
    }
    
    var fullAddress: String? {
        guard let placemark = placemark else { return nil }
        
        var components: [String] = []
        if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }
        if let locality = placemark.locality {
            components.append(locality)
        }
        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }
        if let country = placemark.country {
            components.append(country)
        }
        
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
}
