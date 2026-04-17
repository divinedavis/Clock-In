import SwiftUI

struct ContentView: View {
    @StateObject private var store = TimeEntryStore()
    @State private var clockedInAt: Date?
    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                statusCard
                clockButton
                entriesList
            }
            .padding()
            .navigationTitle("Clock In")
            .onReceive(timer) { now = $0 }
        }
    }

    private var statusCard: some View {
        VStack(spacing: 8) {
            Text(clockedInAt == nil ? "Clocked Out" : "Clocked In")
                .font(.headline)
                .foregroundColor(clockedInAt == nil ? .secondary : .green)
            Text(elapsedString)
                .font(.system(size: 48, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var clockButton: some View {
        Button(action: toggleClock) {
            Text(clockedInAt == nil ? "Clock In" : "Clock Out")
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding()
                .background(clockedInAt == nil ? Color.accentColor : Color.red, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
        }
    }

    private var entriesList: some View {
        List {
            Section("Recent Entries") {
                if store.entries.isEmpty {
                    Text("No entries yet").foregroundStyle(.secondary)
                } else {
                    ForEach(store.entries) { entry in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(entry.start, style: .date)
                                Text("\(entry.start, style: .time) – \(entry.end, style: .time)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(entry.durationString).monospacedDigit()
                        }
                    }
                    .onDelete(perform: store.delete)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var elapsedString: String {
        guard let start = clockedInAt else { return "00:00:00" }
        return TimeEntry.format(interval: now.timeIntervalSince(start))
    }

    private func toggleClock() {
        if let start = clockedInAt {
            store.add(TimeEntry(start: start, end: Date()))
            clockedInAt = nil
        } else {
            clockedInAt = Date()
        }
    }
}

#Preview {
    ContentView()
}
