import SwiftUI

struct AdminFormsView: View {
    @StateObject private var vm = AdminFormsViewModel()
    @State private var showUpload = false

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.forms.isEmpty {
                    ProgressView()
                } else if vm.forms.isEmpty {
                    ContentUnavailableView(
                        "No forms uploaded",
                        systemImage: "doc.text",
                        description: Text("Tap + to upload a blank direct deposit PDF.")
                    )
                } else {
                    List {
                        ForEach(vm.forms) { form in
                            NavigationLink {
                                AdminFormDetailView(status: form)
                            } label: {
                                AdminFormRow(status: form)
                            }
                        }
                        .onDelete { indexSet in
                            Task { await vm.delete(indexSet) }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Forms")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showUpload = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showUpload) {
                UploadFormSheet { await vm.load() }
            }
            .task { await vm.load() }
            .refreshable { await vm.load() }
            .alert("Error", isPresented: .constant(vm.errorMessage != nil), presenting: vm.errorMessage) { _ in
                Button("OK") { vm.errorMessage = nil }
            } message: { Text($0) }
        }
    }
}

private struct AdminFormRow: View {
    let status: AdminFormStatus
    @Environment(\.openURL) private var openURL
    @State private var isOpening = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(status.title).font(.headline)
                if status.isBroadcast {
                    Text("ALL")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.2), in: Capsule())
                }
                Spacer()
                Text("\(status.submittedCount)/\(status.totalAssigned)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(status.pendingEmails.isEmpty ? .green : .orange)
            }
            if !status.pendingEmails.isEmpty {
                Text("Pending: \(status.pendingEmails.prefix(3).joined(separator: ", "))\(status.pendingEmails.count > 3 ? "…" : "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("All caught up")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            Button {
                Task { await openBlank() }
            } label: {
                Label(isOpening ? "Opening…" : "View blank PDF", systemImage: "arrow.down.doc")
                    .font(.caption)
            }
            .disabled(isOpening)
        }
        .padding(.vertical, 4)
    }

    private func openBlank() async {
        isOpening = true
        defer { isOpening = false }
        if let url = try? await FormsService.shared.signedURL(path: status.blankFilePath) {
            openURL(url)
        }
    }
}
