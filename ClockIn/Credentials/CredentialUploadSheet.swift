import SwiftUI
import UniformTypeIdentifiers

struct CredentialUploadSheet: View {
    let kind: CredentialKind
    var onUploaded: () async -> Void

    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var pickedData: Data?
    @State private var pickedName: String?
    @State private var contentType: String = "application/octet-stream"
    @State private var ext: String = "bin"
    @State private var showFilePicker = false
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("File") {
                    if let name = pickedName {
                        Label(name, systemImage: "doc.fill")
                            .lineLimit(1)
                    } else {
                        Text("No file selected")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Add") {
                    if cameraAvailable {
                        Button {
                            showCamera = true
                        } label: {
                            Label("Take photo", systemImage: "camera.fill")
                        }
                    }
                    Button {
                        showLibrary = true
                    } label: {
                        Label("Choose from library", systemImage: "photo.on.rectangle")
                    }
                    Button {
                        showFilePicker = true
                    } label: {
                        Label("Choose file (PDF or image)", systemImage: "doc.badge.plus")
                    }
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Upload \(kind.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Upload") { Task { await upload() } }
                            .disabled(pickedData == nil)
                    }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.pdf, .image],
                allowsMultipleSelection: false
            ) { result in
                handleFile(result)
            }
            .sheet(isPresented: $showCamera) {
                CameraPicker(source: .camera) { data in
                    pickedData = data
                    pickedName = "photo.jpg"
                    contentType = "image/jpeg"
                    ext = "jpg"
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showLibrary) {
                CameraPicker(source: .photoLibrary) { data in
                    pickedData = data
                    pickedName = "photo.jpg"
                    contentType = "image/jpeg"
                    ext = "jpg"
                }
                .ignoresSafeArea()
            }
        }
    }

    private func handleFile(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let lowerExt = url.pathExtension.lowercased()
                pickedData = data
                pickedName = url.lastPathComponent
                switch lowerExt {
                case "pdf":
                    contentType = "application/pdf"; ext = "pdf"
                case "jpg", "jpeg":
                    contentType = "image/jpeg"; ext = "jpg"
                case "png":
                    contentType = "image/png"; ext = "png"
                case "heic":
                    contentType = "image/heic"; ext = "heic"
                case "heif":
                    contentType = "image/heif"; ext = "heif"
                default:
                    contentType = "application/octet-stream"
                    ext = lowerExt.isEmpty ? "bin" : lowerExt
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func upload() async {
        guard let data = pickedData, let userId = auth.userId else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await CredentialsService.shared.upload(
                kind: kind,
                userId: userId,
                data: data,
                ext: ext,
                contentType: contentType
            )
            await onUploaded()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
