import Foundation
import CoreLocation

@MainActor
final class ClockViewModel: ObservableObject {
    @Published var activeEntry: TimeEntry?
    @Published var isWorking = false
    @Published var errorMessage: String?

    private let service = TimeEntryService.shared

    var isClockedIn: Bool { activeEntry != nil }

    func loadOpenEntry() async {
        #if DEBUG
        if ScreenshotMode.isEnabled {
            let clockInAt = Calendar.current.date(byAdding: .minute, value: -222, to: Date()) ?? Date()
            activeEntry = TimeEntry(
                id: UUID(),
                userId: UUID(),
                clockInAt: clockInAt,
                clockOutAt: nil,
                clockInLat: 40.7128,
                clockInLng: -74.0060,
                clockOutLat: nil,
                clockOutLng: nil
            )
            return
        }
        #endif
        do {
            activeEntry = try await service.openEntry()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clockIn(location: CLLocation?) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            activeEntry = try await service.clockIn(
                at: Date(),
                lat: location?.coordinate.latitude,
                lng: location?.coordinate.longitude
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clockOut(location: CLLocation?) async {
        guard let entry = activeEntry else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            _ = try await service.clockOut(
                entryId: entry.id,
                at: Date(),
                lat: location?.coordinate.latitude,
                lng: location?.coordinate.longitude
            )
            activeEntry = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
