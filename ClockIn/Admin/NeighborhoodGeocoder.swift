import Foundation
import CoreLocation

@MainActor
final class NeighborhoodGeocoder: ObservableObject {
    static let shared = NeighborhoodGeocoder()

    @Published private var cache: [String: String] = [:]
    private let geocoder = CLGeocoder()

    private init() {}

    func neighborhood(lat: Double, lng: Double) -> String? {
        cache[Self.key(lat: lat, lng: lng)]
    }

    func resolve(lat: Double, lng: Double) async -> String? {
        let key = Self.key(lat: lat, lng: lng)
        if let cached = cache[key] { return cached }
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(
                CLLocation(latitude: lat, longitude: lng)
            )
            let pm = placemarks.first
            let label = pm?.subLocality
                ?? pm?.locality
                ?? pm?.name
                ?? "Unknown"
            cache[key] = label
            return label
        } catch {
            return nil
        }
    }

    private static func key(lat: Double, lng: Double) -> String {
        String(format: "%.4f,%.4f", lat, lng)
    }
}
