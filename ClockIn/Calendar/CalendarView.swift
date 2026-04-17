import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var vm = CalendarViewModel()
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatePicker(
                    "Select date",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal)

                Divider()

                if vm.isLoading && vm.isEmpty {
                    ProgressView().padding()
                    Spacer()
                } else {
                    jobsList
                }
            }
            .navigationTitle("Calendar")
            .task { await vm.load(isAdmin: auth.isAdmin) }
            .refreshable { await vm.load(isAdmin: auth.isAdmin) }
        }
    }

    private var jobsList: some View {
        let entries = vm.entries(on: selectedDate)
        return Group {
            if entries.isEmpty {
                ContentUnavailableView(
                    "Nothing scheduled",
                    systemImage: "calendar.badge.clock",
                    description: Text(selectedDate.formatted(date: .complete, time: .omitted))
                )
                .padding(.top, 24)
                Spacer()
            } else {
                List(entries, id: \.id) { entry in
                    CalendarJobRow(entry: entry)
                }
                .listStyle(.plain)
            }
        }
    }
}

private struct CalendarJobRow: View {
    let entry: CalendarViewModel.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.title).font(.headline)
                Spacer()
                Text(entry.scheduledAt.formatted(date: .omitted, time: .shortened))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if let address = entry.address, !address.isEmpty {
                Label(address, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !entry.recipients.isEmpty {
                Label(entry.recipientSummary, systemImage: "person.2.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let notes = entry.notes, !notes.isEmpty {
                Text(notes).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
