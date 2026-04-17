import SwiftUI
import UniformTypeIdentifiers

struct UploadFormSheet: View {
    var onCompleted: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var pickedData: Data?
    @State private var pickedName: String?
    @State private var showPicker = false
    @State private var broadcast = true
    @State private var users: [UserRow] = []
    @State private var selected: Set<UUID> = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Form") {
                    TextField("Title (e.g. W-4, Direct Deposit)", text: $title)
                }
                Section("PDF") {
                    Button {
                        showPicker = true
                    } label: {
                        Label(pickedName ?? "Choose PDF", systemImage: "doc.badge.plus")
                    }
                    if let name = pickedName {
                        Text(name).font(.caption).foregroundStyle(.secondary)
                    }
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
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Upload Form")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving { ProgressView() }
                    else {
                        Button("Upload") { Task { await upload() } }
                            .disabled(!canSubmit)
                    }
                }
            }
            .fileImporter(
                isPresented: $showPicker,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handlePickerResult(result)
            }
            .task {
                do { users = try await JobService.shared.listUsers() }
                catch { errorMessage = error.localizedDescription }
            }
        }
    }

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && pickedData != nil
            && (broadcast || !selected.isEmpty)
    }

    private func toggleSelection(_ id: UUID) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    private func handlePickerResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                pickedData = try Data(contentsOf: url)
                pickedName = url.lastPathComponent
            } catch {
                errorMessage = error.localizedDescription
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func upload() async {
        guard let data = pickedData else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await FormsService.shared.uploadBlankForm(
                title: title.trimmingCharacters(in: .whitespaces),
                data: data,
                broadcast: broadcast,
                recipientUserIds: Array(selected)
            )
            await onCompleted()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
