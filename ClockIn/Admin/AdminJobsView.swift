import SwiftUI

struct AdminJobsView: View {
    @StateObject private var vm = AdminJobsViewModel()
    @State private var showCompose = false

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.jobs.isEmpty {
                    ProgressView()
                } else if vm.jobs.isEmpty {
                    ContentUnavailableView(
                        "No jobs scheduled",
                        systemImage: "briefcase.fill",
                        description: Text("Tap + to send a new job to your team.")
                    )
                } else {
                    List {
                        ForEach(vm.jobs) { job in
                            JobAdminRow(job: job)
                        }
                        .onDelete { indexSet in
                            Task { await vm.delete(indexSet: indexSet) }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Jobs")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showCompose = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showCompose) {
                SendJobSheet {
                    Task { await vm.load() }
                }
            }
            .task { await vm.load() }
            .refreshable { await vm.load() }
            .alert("Error", isPresented: .constant(vm.errorMessage != nil), presenting: vm.errorMessage) { _ in
                Button("OK") { vm.errorMessage = nil }
            } message: { Text($0) }
        }
    }
}

private struct JobAdminRow: View {
    let job: Job

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(job.title).font(.headline)
                if job.isBroadcast {
                    Text("ALL")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.2), in: Capsule())
                }
            }
            Text(job.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let address = job.address, !address.isEmpty {
                Text(address).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
