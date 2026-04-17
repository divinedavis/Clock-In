import Foundation
import MapKit
import CoreLocation

@MainActor
final class AddressCompleter: NSObject, ObservableObject {
    @Published var suggestions: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func biasRegion(around coordinate: CLLocationCoordinate2D, radiusMeters: CLLocationDistance = 50_000) {
        completer.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: radiusMeters,
            longitudinalMeters: radiusMeters
        )
    }

    func update(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            suggestions = []
            return
        }
        completer.queryFragment = trimmed
    }

    func formatted(_ result: MKLocalSearchCompletion) -> String {
        if result.subtitle.isEmpty { return result.title }
        return "\(result.title), \(result.subtitle)"
    }
}

extension AddressCompleter: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        Task { @MainActor in
            self.suggestions = Array(results.prefix(3))
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in self.suggestions = [] }
    }
}
