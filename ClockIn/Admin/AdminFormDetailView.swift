import SwiftUI

struct AdminFormDetailView: View {
    let status: AdminFormStatus

    @State private var rows: [FormUserStatus] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.openURL) private var openURL

    private var signed: [FormUserStatus] { rows.filter { $0.submittedAt != nil } }
    private var unsigned: [FormUserStatus] { rows.filter { $0.submittedAt == nil } }

    var body: some View {
        List {
            Section("Form") {
                HStack {
                    Text(status.title).font(.headline)
                    Spacer()
                    if status.isBroadcast {
                        Text("ALL")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.2), in: Capsule())
                    }
                }
                Button {
                    Task { await openBlank() }
                } label: {
                    Label("View blank PDF", systemImage: "arrow.down.doc")
                }
            }

            Section {
                if signed.isEmpty {
                    Text("No one has signed yet").foregroundStyle(.secondary)
                } else {
                    ForEach(signed) { user in
                        HStack {
                            Label(user.email, systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .lineLimit(1)
                            Spacer()
                            if let at = user.submittedAt {
                                Text(at.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("Signed · \(signed.count)")
            }

            Section {
                if unsigned.isEmpty {
                    Text("Everyone is signed up").foregroundStyle(.secondary)
                } else {
                    ForEach(unsigned) { user in
                        Label(user.email, systemImage: "circle.dashed")
                            .foregroundColor(.orange)
                    }
                }
            } header: {
                Text("Not signed · \(unsigned.count)")
            }
        }
        .navigationTitle(status.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .overlay {
            if isLoading && rows.isEmpty { ProgressView() }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil), presenting: errorMessage) { _ in
            Button("OK") { errorMessage = nil }
        } message: { Text($0) }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            rows = try await FormsService.shared.adminFormStatus(formId: status.formId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func openBlank() async {
        if let url = try? await FormsService.shared.signedURL(path: status.blankFilePath) {
            openURL(url)
        }
    }
}
