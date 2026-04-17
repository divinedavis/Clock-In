import Foundation

@MainActor
final class CalendarViewModel: ObservableObject {
    struct Entry: Identifiable, Equatable {
        let id: UUID
        let title: String
        let address: String?
        let scheduledAt: Date
        let notes: String?
        let recipients: [String]
        let isBroadcast: Bool

        var recipientSummary: String {
            if isBroadcast { return "All users" }
            if recipients.count <= 2 { return recipients.joined(separator: ", ") }
            return "\(recipients.prefix(2).joined(separator: ", ")) +\(recipients.count - 2) more"
        }
    }

    @Published var entries: [Entry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    var isEmpty: Bool { entries.isEmpty }

    func load(isAdmin: Bool) async {
        isLoading = true
        defer { isLoading = false }
        do {
            if isAdmin {
                let jobs = try await JobService.shared.fetchAllJobsWithRecipients()
                entries = jobs.map {
                    Entry(
                        id: $0.id,
                        title: $0.title,
                        address: $0.address,
                        scheduledAt: $0.scheduledAt,
                        notes: $0.notes,
                        recipients: $0.recipientEmails,
                        isBroadcast: $0.isBroadcast
                    )
                }
            } else {
                let jobs = try await JobService.shared.fetchMyJobs()
                entries = jobs.map {
                    Entry(
                        id: $0.id,
                        title: $0.title,
                        address: $0.address,
                        scheduledAt: $0.scheduledAt,
                        notes: $0.notes,
                        recipients: ["You"],
                        isBroadcast: false
                    )
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func entries(on day: Date) -> [Entry] {
        let cal = Calendar.current
        return entries
            .filter { cal.isDate($0.scheduledAt, inSameDayAs: day) }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }
}
