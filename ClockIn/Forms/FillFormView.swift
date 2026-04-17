import SwiftUI
import PDFKit

struct FillFormView: View {
    let form: DirectDepositForm
    var onSubmitted: () async -> Void

    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var blankData: Data?
    @State private var document: PDFDocument?
    @State private var isLoading = true
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading form…")
                } else if let data = blankData {
                    PDFFormEditor(data: data, document: $document)
                } else {
                    ContentUnavailableView(
                        "Couldn't load form",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage ?? "Try again later.")
                    )
                }
            }
            .navigationTitle(form.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button("Submit") { Task { await submit() } }
                            .disabled(document == nil)
                    }
                }
            }
            .task { await load() }
            .alert("Error", isPresented: .constant(errorMessage != nil), presenting: errorMessage) { _ in
                Button("OK") { errorMessage = nil }
            } message: { Text($0) }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            blankData = try await FormsService.shared.downloadBlank(path: form.blankFilePath)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submit() async {
        guard let doc = document, let userId = auth.userId else {
            errorMessage = "Not signed in."
            return
        }
        guard let out = doc.dataRepresentation() else {
            errorMessage = "Couldn't serialize the PDF."
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await FormsService.shared.submitFilled(formId: form.id, userId: userId, data: out)
            await onSubmitted()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
