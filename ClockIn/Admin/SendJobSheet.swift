import SwiftUI
import MapKit

struct SendJobSheet: View {
    var onCreated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var completer = AddressCompleter()
    @StateObject private var location = LocationManager()
    @State private var title = ""
    @State private var address = ""
    @State private var notes = ""
    @State private var scheduledAt = Date().addingTimeInterval(3600)
    @State private var broadcast = true
    @State private var users: [UserRow] = []
    @State private var selected: Set<UUID> = []
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didPickSuggestion = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Job") {
                    TextField("Title (e.g. Brooklyn site walkthrough)", text: $title)

                    TextField("Address", text: $address)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .onChange(of: address) { _, new in
                            if didPickSuggestion {
                                didPickSuggestion = false
                            } else {
                                completer.update(query: new)
                            }
                        }

                    if !completer.suggestions.isEmpty {
                        ForEach(completer.suggestions, id: \.self) { suggestion in
                            Button {
                                didPickSuggestion = true
                                address = completer.formatted(suggestion)
                                completer.suggestions = []
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion.title)
                                        .foregroundStyle(.primary)
                                    if !suggestion.subtitle.isEmpty {
                                        Text(suggestion.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }

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
            .task {
                await loadUsers()
                await primeLocationBias()
            }
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

    private func primeLocationBias() async {
        location.requestPermissionIfNeeded()
        if let loc = try? await location.currentLocation() {
            completer.biasRegion(around: loc.coordinate)
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
