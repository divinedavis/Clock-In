import SwiftUI

struct AdminView: View {
    @StateObject private var vm = AdminViewModel()
    @State private var searchText = ""
    @State private var dateFilter: DateFilter = .all
    @State private var showCustomRange = false
    @State private var customStart: Date = Calendar.current.startOfDay(for: Date())
    @State private var customEnd: Date = Date()

    private var filtered: [AdminTimeEntry] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return vm.entries.filter { entry in
            let emailOK = q.isEmpty || entry.email.lowercased().contains(q)
            let dateOK = dateFilter.includes(entry.clockInAt, customStart: customStart, customEnd: customEnd)
            return emailOK && dateOK
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.entries.isEmpty {
                    ProgressView()
                } else if vm.entries.isEmpty {
                    ContentUnavailableView(
                        "No entries",
                        systemImage: "person.3",
                        description: Text("No one has clocked in yet.")
                    )
                } else if filtered.isEmpty {
                    ContentUnavailableView(
                        "No matches",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text("Try a different search or date range.")
                    )
                } else {
                    List(filtered) { entry in
                        AdminEntryRow(entry: entry)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("All Users")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search by email")
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Date range", selection: $dateFilter) {
                            ForEach(DateFilter.allCases) { f in
                                Text(f.title).tag(f)
                            }
                        }
                        if dateFilter == .custom {
                            Button("Edit custom range…") { showCustomRange = true }
                        }
                    } label: {
                        Label(dateFilter.shortLabel(start: customStart, end: customEnd),
                              systemImage: "calendar")
                    }
                }
            }
            .sheet(isPresented: $showCustomRange) {
                CustomRangeSheet(start: $customStart, end: $customEnd)
            }
            .onChange(of: dateFilter) { _, new in
                if new == .custom { showCustomRange = true }
            }
            .task { await vm.load() }
            .refreshable { await vm.load() }
        }
    }
}

enum DateFilter: String, CaseIterable, Identifiable {
    case all, today, week, month, custom
    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All time"
        case .today: return "Today"
        case .week: return "Last 7 days"
        case .month: return "Last 30 days"
        case .custom: return "Custom range"
        }
    }

    func shortLabel(start: Date, end: Date) -> String {
        switch self {
        case .all: return "All"
        case .today: return "Today"
        case .week: return "7d"
        case .month: return "30d"
        case .custom:
            let f = DateFormatter()
            f.dateFormat = "M/d"
            return "\(f.string(from: start))–\(f.string(from: end))"
        }
    }

    func includes(_ date: Date, customStart: Date, customEnd: Date) -> Bool {
        let cal = Calendar.current
        switch self {
        case .all: return true
        case .today: return cal.isDateInToday(date)
        case .week:
            guard let cutoff = cal.date(byAdding: .day, value: -7, to: Date()) else { return true }
            return date >= cutoff
        case .month:
            guard let cutoff = cal.date(byAdding: .day, value: -30, to: Date()) else { return true }
            return date >= cutoff
        case .custom:
            let lower = cal.startOfDay(for: customStart)
            let upper = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: customEnd)) ?? customEnd
            return date >= lower && date < upper
        }
    }
}

private struct CustomRangeSheet: View {
    @Binding var start: Date
    @Binding var end: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Start", selection: $start, in: ...end, displayedComponents: .date)
                DatePicker("End", selection: $end, in: start...Date(), displayedComponents: .date)
            }
            .navigationTitle("Custom range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct AdminEntryRow: View {
    let entry: AdminTimeEntry
    @State private var inHood: String?
    @State private var outHood: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.email)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(entry.duration.map { TimeEntry.durationString($0) } ?? "in progress")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(entry.clockOutAt == nil ? .green : .secondary)
            }

            HStack {
                Label(inHood ?? "Locating…", systemImage: "arrow.down.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(entry.clockInAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let out = entry.clockOutAt {
                HStack {
                    Label(outHood ?? "Locating…", systemImage: "arrow.up.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(out.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .task {
            if let lat = entry.clockInLat, let lng = entry.clockInLng {
                inHood = await NeighborhoodGeocoder.shared.resolve(lat: lat, lng: lng)
            } else {
                inHood = "No location"
            }
            if let lat = entry.clockOutLat, let lng = entry.clockOutLng {
                outHood = await NeighborhoodGeocoder.shared.resolve(lat: lat, lng: lng)
            } else if entry.clockOutAt != nil {
                outHood = "No location"
            }
        }
    }
}
