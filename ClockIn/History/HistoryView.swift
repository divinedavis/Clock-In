import SwiftUI

struct HistoryView: View {
    @StateObject private var vm = HistoryViewModel()
    @State private var range: Range = .week

    enum Range: String, CaseIterable, Identifiable {
        case day = "Day", week = "Week", month = "Month", year = "Year"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("Range", selection: $range) {
                    ForEach(Range.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                summaryCard

                List {
                    ForEach(vm.groupedEntries(for: range), id: \.label) { group in
                        Section(header: groupHeader(group)) {
                            ForEach(group.entries) { entry in
                                entryRow(entry)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("History")
            .task { await vm.load() }
            .refreshable { await vm.load() }
            .overlay {
                if vm.isLoading && vm.entries.isEmpty {
                    ProgressView()
                } else if !vm.isLoading && vm.entries.isEmpty {
                    ContentUnavailableView("No entries yet", systemImage: "clock.badge.xmark",
                                           description: Text("Clock in on the Clock tab to start tracking."))
                }
            }
        }
    }

    private var summaryCard: some View {
        VStack(spacing: 4) {
            Text("Total this \(range.rawValue.lowercased())")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(TimeEntry.durationString(vm.totalForCurrentPeriod(range)))
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func groupHeader(_ group: HistoryViewModel.Group) -> some View {
        HStack {
            Text(group.label)
            Spacer()
            Text(TimeEntry.durationString(group.total)).monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private func entryRow(_ entry: TimeEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.clockInAt, style: .date).font(.subheadline)
                Text("\(entry.clockInAt.formatted(date: .omitted, time: .shortened)) – \(entry.clockOutAt?.formatted(date: .omitted, time: .shortened) ?? "in progress")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(entry.duration.map { TimeEntry.durationString($0) } ?? "—")
                .monospacedDigit()
        }
    }
}
