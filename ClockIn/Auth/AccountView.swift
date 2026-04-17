import SwiftUI

struct AccountView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var showUploadW4 = false
    @State private var showUploadDirectDeposit = false

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
                }
            }
            .navigationTitle("Account")
            .sheet(isPresented: $showUploadW4) {
                UploadFormSheet(initialTitle: "W-4") { /* no-op */ }
            }
            .sheet(isPresented: $showUploadDirectDeposit) {
                UploadFormSheet(initialTitle: "Direct Deposit") { /* no-op */ }
            }
        }
    }
}
