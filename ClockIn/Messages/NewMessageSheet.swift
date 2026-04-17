import SwiftUI

struct NewMessageSheet: View {
    var onSent: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var auth: AuthViewModel
    @State private var users: [UserRow] = []
    @State private var filter = ""
    @State private var selected: UserRow?
    @State private var draft = ""
    @State private var isSending = false
    @State private var errorMessage: String?

    private var filteredUsers: [UserRow] {
        let q = filter.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return users }
        return users.filter { $0.email.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipient") {
                    if let selected {
                        HStack {
                            Text(selected.email)
                            Spacer()
                            Button("Change") { self.selected = nil }
                                .font(.caption)
                        }
                    } else {
                        TextField("Search by email", text: $filter)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        if users.isEmpty {
                            ProgressView()
                        } else {
                            ForEach(filteredUsers.prefix(8)) { user in
                                Button(user.email) {
                                    self.selected = user
                                }
                                .foregroundStyle(.primary)
                            }
                        }
                    }
                }
                Section("Message") {
                    TextField("Write a message", text: $draft, axis: .vertical)
                        .lineLimit(3...8)
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSending { ProgressView() }
                    else {
                        Button("Send") { Task { await send() } }
                            .disabled(!canSend)
                    }
                }
            }
            .task { await loadUsers() }
        }
    }

    private var canSend: Bool {
        selected != nil && !draft.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func loadUsers() async {
        do {
            users = try await MessageService.shared.listOtherUsers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func send() async {
        guard let partner = selected else { return }
        isSending = true
        defer { isSending = false }
        do {
            _ = try await MessageService.shared.send(
                to: partner.userId,
                body: draft.trimmingCharacters(in: .whitespaces)
            )
            await onSent()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
