import SwiftUI

struct AdminView: View {
    @StateObject private var vm = AdminViewModel()

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
                } else {
                    List(vm.entries) { entry in
                        AdminEntryRow(entry: entry)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("All Users")
            .task { await vm.load() }
            .refreshable { await vm.load() }
        }
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
