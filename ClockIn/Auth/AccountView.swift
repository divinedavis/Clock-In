import SwiftUI

struct AccountView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var showUploadW4 = false
    @State private var showUploadDirectDeposit = false
    @State private var uploadingKind: CredentialKind?
    @State private var credentialRefreshToken = UUID()
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(auth.userEmail ?? "—").foregroundStyle(.secondary)
                    }
                    if auth.isAdmin {
                        HStack {
                            Text("Role")
                            Spacer()
                            Text("Admin").foregroundStyle(.secondary)
                        }
                    }
                }

                if !auth.isAdmin {
                    Section("Work") {
                        NavigationLink {
                            HistoryView()
                        } label: {
                            Label("Clock-in history", systemImage: "clock.arrow.circlepath")
                        }
                    }

                    CredentialsSection(
                        kind: .osha30,
                        refreshToken: credentialRefreshToken
                    ) { uploadingKind = .osha30 }

                    CredentialsSection(
                        kind: .flaggerCard,
                        refreshToken: credentialRefreshToken
                    ) { uploadingKind = .flaggerCard }
                }

                Section("Forms") {
                    NavigationLink {
                        if auth.isAdmin {
                            AdminFormsView()
                        } else {
                            FormsView()
                        }
                    } label: {
                        Label("All forms", systemImage: "doc.text.fill")
                    }

                    if auth.isAdmin {
                        Button {
                            showUploadW4 = true
                        } label: {
                            Label("Upload W-4 form", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            showUploadDirectDeposit = true
                        } label: {
                            Label("Upload direct deposit form", systemImage: "square.and.arrow.up")
                        }
                    }
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        Task { await auth.signOut() }
                    }
                    Button("Delete Account", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
            }
            .navigationTitle("Account")
            .sheet(isPresented: $showUploadW4) {
                UploadFormSheet(initialTitle: "W-4") { /* no-op */ }
            }
            .sheet(isPresented: $showUploadDirectDeposit) {
                UploadFormSheet(initialTitle: "Direct Deposit") { /* no-op */ }
            }
            .sheet(item: $uploadingKind) { kind in
                CredentialUploadSheet(kind: kind) {
                    credentialRefreshToken = UUID()
                }
                .environmentObject(auth)
            }
            .confirmationDialog(
                "Delete your account?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Permanently", role: .destructive) {
                    Task { await auth.deleteAccount() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your account and all of your time entries, uploaded credentials, and form submissions. This can't be undone.")
            }
        }
    }
}

private struct CredentialsSection: View {
    let kind: CredentialKind
    let refreshToken: UUID
    let onUpload: () -> Void

    @State private var items: [Credential] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.openURL) private var openURL

    var body: some View {
        Section(kind.title) {
            if isLoading && items.isEmpty {
                HStack { ProgressView(); Text("Loading…").foregroundStyle(.secondary) }
            } else if items.isEmpty {
                Text("No \(kind.title) uploaded yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items) { item in
                    Button {
                        Task { await open(item) }
                    } label: {
                        HStack {
                            Label(
                                item.uploadedAt.formatted(date: .abbreviated, time: .shortened),
                                systemImage: item.contentType == "application/pdf" ? "doc.text.fill" : "photo.fill"
                            )
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                }
                .onDelete { indexSet in
                    Task { await delete(indexSet) }
                }
            }

            Button {
                onUpload()
            } label: {
                Label("Upload \(kind.title)", systemImage: "square.and.arrow.up")
            }

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }
        }
        .task(id: refreshToken) { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await CredentialsService.shared.myCredentials(kind: kind)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ indexSet: IndexSet) async {
        let targets = indexSet.map { items[$0] }
        for item in targets {
            do {
                try await CredentialsService.shared.delete(item)
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        }
        await load()
    }

    private func open(_ credential: Credential) async {
        do {
            let url = try await CredentialsService.shared.signedURL(path: credential.filePath)
            openURL(url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
