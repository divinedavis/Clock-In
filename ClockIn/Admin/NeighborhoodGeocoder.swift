import Foundation
import CoreLocation

actor NeighborhoodGeocoder {
    static let shared = NeighborhoodGeocoder()

    private let geocoder = CLGeocoder()
    private var cache: [String: String] = [:]
    private var inFlight: [String: Task<String, Never>] = [:]

    private init() {}

    func resolve(lat: Double, lng: Double) async -> String {
        let key = Self.key(lat: lat, lng: lng)
        if let cached = cache[key] { return cached }
        if let task = inFlight[key] { return await task.value }

        let task = Task<String, Never> { [geocoder] in
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(
                    CLLocation(latitude: lat, longitude: lng)
                )
                let pm = placemarks.first
                return pm?.subLocality ?? pm?.locality ?? pm?.name ?? "Unknown"
            } catch {
                return "Unknown"
            }
        }
        inFlight[key] = task
        let label = await task.value
        inFlight[key] = nil
        cache[key] = label
        return label
    }

    private static func key(lat: Double, lng: Double) -> String {
        String(format: "%.4f,%.4f", lat, lng)
    }
}
