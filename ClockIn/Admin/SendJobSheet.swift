import SwiftUI

struct SendJobSheet: View {
    var onCreated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var address = ""
    @State private var notes = ""
    @State private var scheduledAt = Date().addingTimeInterval(3600)
    @State private var broadcast = true
    @State private var users: [UserRow] = []
    @State private var selected: Set<UUID> = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Job") {
                    TextField("Title (e.g. Brooklyn site walkthrough)", text: $title)
                    TextField("Address", text: $address)
                        .textInputAutocapitalization(.words)
                    DatePicker("Date & time", selection: $scheduledAt)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("Recipients") {
                    Toggle("Send to all users", isOn: $broadcast)
                    if !broadcast {
                        if users.isEmpty {
                            ProgressView()
                        } else {
                            ForEach(users) { u in
                                Button {
                                    toggleSelection(u.userId)
                                } label: {
                                    HStack {
                                        Image(systemName: selected.contains(u.userId) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selected.contains(u.userId) ? .accentColor : .secondary)
                                        Text(u.email).foregroundStyle(.primary)
                                    }
                                }
                            }
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Send Job")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Send") { Task { await save() } }
                            .disabled(!canSave)
                    }
                }
            }
            .task { await loadUsers() }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        (broadcast || !selected.isEmpty)
    }

    private func toggleSelection(_ id: UUID) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    private func loadUsers() async {
        do {
            users = try await JobService.shared.listUsers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await JobService.shared.createJob(
                title: title.trimmingCharacters(in: .whitespaces),
                address: address.isEmpty ? nil : address,
                scheduledAt: scheduledAt,
                notes: notes.isEmpty ? nil : notes,
                recipientUserIds: Array(selected),
                broadcast: broadcast
            )
            onCreated()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
