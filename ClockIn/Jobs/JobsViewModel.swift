import Foundation

@MainActor
final class JobsViewModel: ObservableObject {
    @Published var jobs: [Job] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = JobService.shared

    func load() async {
        #if DEBUG
        if ScreenshotMode.isEnabled {
            jobs = JobsViewModel.seedJobs()
            return
        }
        #endif
        isLoading = true
        defer { isLoading = false }
        do {
            jobs = try await service.fetchMyJobs()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    #if DEBUG
    // Marketing screenshot support (DEBUG-only, used to capture App Store screenshots). See ScreenshotMode.
    private static func seedJobs() -> [Job] {
        let cal = Calendar.current
        let today = Date()
        let creator = UUID()
        return [
            Job(
                id: UUID(), createdBy: creator,
                title: "Framing — 4th Ave Site",
                address: "482 4th Ave, Brooklyn, NY",
                locationLat: 40.6668, locationLng: -73.9899,
                scheduledAt: cal.date(bySettingHour: 7, minute: 0, second: 0, of: today) ?? today,
                notes: "Bring OSHA 30 card. Hard hat and boots required.",
                isBroadcast: false, createdAt: today
            ),
            Job(
                id: UUID(), createdBy: creator,
                title: "Drywall — Midtown Tower",
                address: "225 W 34th St, New York, NY",
                locationLat: 40.7508, locationLng: -73.9918,
                scheduledAt: cal.date(
                    byAdding: .day, value: 1,
                    to: cal.date(bySettingHour: 8, minute: 0, second: 0, of: today) ?? today
                ) ?? today,
                notes: "Freight elevator — ask for Mike at security.",
                isBroadcast: false, createdAt: today
            ),
            Job(
                id: UUID(), createdBy: creator,
                title: "Concrete Pour — Astoria Site",
                address: "31-10 Steinway St, Queens, NY",
                locationLat: 40.7677, locationLng: -73.9212,
                scheduledAt: cal.date(
                    byAdding: .day, value: 3,
                    to: cal.date(bySettingHour: 6, minute: 30, second: 0, of: today) ?? today
                ) ?? today,
                notes: nil,
                isBroadcast: true, createdAt: today
            )
        ]
    }
    #endif
}
