import SwiftUI

struct JobsView: View {
    @StateObject private var vm = JobsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.jobs.isEmpty {
                    ProgressView()
                } else if vm.jobs.isEmpty {
                    ContentUnavailableView(
                        "No jobs assigned",
                        systemImage: "briefcase",
                        description: Text("Your admin hasn't scheduled anything yet.")
                    )
                } else {
                    List(vm.jobs) { job in
                        JobRow(job: job)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Jobs")
            .task { await vm.load() }
            .refreshable { await vm.load() }
        }
    }
}

private struct JobRow: View {
    let job: Job

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(job.title)
                .font(.headline)
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                Text(job.scheduledAt.formatted(date: .abbreviated, time: .shortened))
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            if let address = job.address, !address.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                    Text(address)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            if let notes = job.notes, !notes.isEmpty {
                Text(notes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
}
