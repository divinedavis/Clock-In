import SwiftUI

struct AccountView: View {
    @EnvironmentObject var auth: AuthViewModel

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
                        Label("Direct deposit forms", systemImage: "doc.text.fill")
                    }
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        Task { await auth.signOut() }
                    }
                }
            }
            .navigationTitle("Account")
        }
    }
}
