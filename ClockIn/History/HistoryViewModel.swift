import Foundation

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var entries: [TimeEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    struct Group {
        let label: String
        let total: TimeInterval
        let entries: [TimeEntry]
    }

    private let service = TimeEntryService.shared

    func load() async {
        #if DEBUG
        if ScreenshotMode.isEnabled {
            entries = HistoryViewModel.seedEntries()
            return
        }
        #endif
        isLoading = true
        defer { isLoading = false }
        do {
            entries = try await service.fetchAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    #if DEBUG
    // Marketing screenshot support (DEBUG-only, used to capture App Store screenshots). See ScreenshotMode.
    // Weekday shifts for the last ~5 weeks, ending yesterday (today's shift is
    // shown live on the Clock tab instead).
    private static func seedEntries() -> [TimeEntry] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let startMinutes = [0, 5, 10, 15, 20]
        let shiftHours = [7.75, 8.0, 8.5, 8.25, 9.0]
        var result: [TimeEntry] = []
        var dayOffset = 1
        var weekdaysAdded = 0
        while weekdaysAdded < 24, dayOffset < 60 {
            guard let day = cal.date(byAdding: .day, value: -dayOffset, to: today) else { break }
            dayOffset += 1
            let weekday = cal.component(.weekday, from: day) // 1 = Sunday, 7 = Saturday
            guard weekday != 1, weekday != 7 else { continue }
            guard let clockIn = cal.date(
                bySettingHour: 7,
                minute: startMinutes[weekdaysAdded % startMinutes.count],
                second: 0,
                of: day
            ) else { continue }
            let hours = shiftHours[weekdaysAdded % shiftHours.count]
            let clockOut = clockIn.addingTimeInterval(hours * 3600)
            result.append(TimeEntry(
                id: UUID(),
                userId: UUID(),
                clockInAt: clockIn,
                clockOutAt: clockOut,
                clockInLat: 40.7128,
                clockInLng: -74.0060,
                clockOutLat: 40.7128,
                clockOutLng: -74.0060
            ))
            weekdaysAdded += 1
        }
        return result
    }
    #endif

    func totalForCurrentPeriod(_ range: HistoryView.Range) -> TimeInterval {
        let cal = Calendar.current
        let now = Date()
        return entries
            .filter { entry in
                guard let duration = entry.duration else { return false }
                _ = duration
                return sameCurrentPeriod(entry.clockInAt, now: now, range: range, calendar: cal)
            }
            .reduce(0) { $0 + ($1.duration ?? 0) }
    }

    func groupedEntries(for range: HistoryView.Range) -> [Group] {
        let cal = Calendar.current
        let completed = entries.filter { $0.duration != nil }

        let buckets = Dictionary(grouping: completed) { entry -> Date in
            bucketStart(for: entry.clockInAt, range: range, calendar: cal)
        }

        let sortedKeys = buckets.keys.sorted(by: >)
        let formatter = formatter(for: range)

        return sortedKeys.map { key in
            let items = buckets[key] ?? []
            let total = items.reduce(0) { $0 + ($1.duration ?? 0) }
            return Group(label: formatter.string(from: key), total: total, entries: items)
        }
    }

    private func sameCurrentPeriod(_ date: Date, now: Date, range: HistoryView.Range, calendar: Calendar) -> Bool {
        switch range {
        case .day: return calendar.isDate(date, inSameDayAs: now)
        case .week: return calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear)
        case .month: return calendar.isDate(date, equalTo: now, toGranularity: .month)
        case .year: return calendar.isDate(date, equalTo: now, toGranularity: .year)
        }
    }

    private func bucketStart(for date: Date, range: HistoryView.Range, calendar: Calendar) -> Date {
        let components: Set<Calendar.Component>
        switch range {
        case .day: components = [.year, .month, .day]
        case .week: components = [.yearForWeekOfYear, .weekOfYear]
        case .month: components = [.year, .month]
        case .year: components = [.year]
        }
        return calendar.date(from: calendar.dateComponents(components, from: date)) ?? date
    }

    private func formatter(for range: HistoryView.Range) -> DateFormatter {
        let f = DateFormatter()
        switch range {
        case .day: f.dateFormat = "EEEE, MMM d"
        case .week: f.dateFormat = "'Week of' MMM d"
        case .month: f.dateFormat = "MMMM yyyy"
        case .year: f.dateFormat = "yyyy"
        }
        return f
    }
}
