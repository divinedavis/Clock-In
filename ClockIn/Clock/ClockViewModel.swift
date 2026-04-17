import Foundation
import CoreLocation

@MainActor
final class ClockViewModel: ObservableObject {
    @Published var activeEntry: TimeEntry?
    @Published var isWorking = false
    @Published var errorMessage: String?
    @Published var now = Date()

    private let service = TimeEntryService.shared

    var isClockedIn: Bool { activeEntry != nil }

    var elapsedString: String {
        guard let start = activeEntry?.clockInAt else { return "00:00:00" }
        return TimeEntry.durationString(now.timeIntervalSince(start))
    }

    func loadOpenEntry() async {
        do {
            activeEntry = try await service.openEntry()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clockIn(userId: UUID, location: CLLocation?) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            activeEntry = try await service.clockIn(
                userId: userId,
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
