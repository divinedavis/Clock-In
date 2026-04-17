import SwiftUI
import UniformTypeIdentifiers

struct FormsView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var vm = FormsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.forms.isEmpty {
                    ProgressView()
                } else if vm.forms.isEmpty {
                    ContentUnavailableView(
                        "No forms to fill out",
                        systemImage: "doc.text",
                        description: Text("Your admin hasn't posted any forms.")
                    )
                } else {
                    List(vm.forms) { form in
                        FormRow(form: form, submitted: vm.isSubmitted(form)) {
                            await vm.load()
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Forms")
            .task { await vm.load() }
            .refreshable { await vm.load() }
            .alert("Error", isPresented: .constant(vm.errorMessage != nil), presenting: vm.errorMessage) { _ in
                Button("OK") { vm.errorMessage = nil }
            } message: { Text($0) }
        }
    }
}

private struct FormRow: View {
    let form: DirectDepositForm
    let submitted: Bool
    var reload: () async -> Void

    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.openURL) private var openURL
    @State private var showPicker = false
    @State private var isUploading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(form.title).font(.headline)
                Spacer()
                statusBadge
            }

            HStack(spacing: 12) {
                Button {
                    Task { await openBlank() }
                } label: {
                    Label("View blank", systemImage: "arrow.down.doc")
                }
                .buttonStyle(.bordered)

                Button {
                    showPicker = true
                } label: {
                    Label(submitted ? "Resubmit" : "Upload filled", systemImage: "arrow.up.doc")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isUploading)
            }
            .font(.caption)

            if isUploading {
                ProgressView().controlSize(.small)
            }
            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(.vertical, 6)
        .fileImporter(
            isPresented: $showPicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            Task { await handleUpload(result) }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if submitted {
            Label("Submitted", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundColor(.green)
        } else {
            Label("Not submitted", systemImage: "circle.dashed")
                .font(.caption.weight(.semibold))
                .foregroundColor(.orange)
        }
    }

    private func openBlank() async {
        if let url = try? await FormsService.shared.signedURL(path: form.blankFilePath) {
            openURL(url)
        }
    }

    private func handleUpload(_ result: Result<[URL], Error>) async {
        guard let userId = auth.userId else {
            errorMessage = "Not signed in."
            return
        }
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                isUploading = true
                try await FormsService.shared.submitFilled(formId: form.id, userId: userId, data: data)
                isUploading = false
                await reload()
            } catch {
                isUploading = false
                errorMessage = error.localizedDescription
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}
