import Foundation

struct TimeEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var start: Date
    var end: Date

    var duration: TimeInterval { end.timeIntervalSince(start) }

    var durationString: String { Self.format(interval: duration) }

    static func format(interval: TimeInterval) -> String {
        let total = Int(interval)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}

@MainActor
final class TimeEntryStore: ObservableObject {
    @Published private(set) var entries: [TimeEntry] = []

    private let url: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("time_entries.json")
    }()

    init() { load() }

    func add(_ entry: TimeEntry) {
        entries.insert(entry, at: 0)
        save()
    }

    func delete(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([TimeEntry].self, from: data) else { return }
        entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
