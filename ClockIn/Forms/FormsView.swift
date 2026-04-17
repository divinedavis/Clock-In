import SwiftUI

struct FormsView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var vm = FormsViewModel()

    var body: some View {
        Group {
            if vm.isLoading && vm.forms.isEmpty {
                ProgressView()
            } else if vm.forms.isEmpty {
                ContentUnavailableView(
                    "No forms to fill out",
                    systemImage: "doc.text",
                    description: Text("Your admin hasn't sent you any forms.")
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

private struct FormRow: View {
    let form: DirectDepositForm
    let submitted: Bool
    var reload: () async -> Void

    @State private var showEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(form.title).font(.headline)
                Spacer()
                statusBadge
            }
            Button {
                showEditor = true
            } label: {
                Label(submitted ? "Review / resubmit" : "Fill out", systemImage: "pencil.and.outline")
                    .font(.caption)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 6)
        .sheet(isPresented: $showEditor) {
            FillFormView(form: form) {
                await reload()
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if submitted {
            Label("Submitted", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundColor(.green)
        } else {
            Label("Not complete", systemImage: "circle.dashed")
                .font(.caption.weight(.semibold))
                .foregroundColor(.orange)
        }
    }
}
