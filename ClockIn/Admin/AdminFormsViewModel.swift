import Foundation

@MainActor
final class AdminFormsViewModel: ObservableObject {
    @Published var forms: [AdminFormStatus] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            forms = try await FormsService.shared.adminStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ indexSet: IndexSet) async {
        let targets = indexSet.map { forms[$0] }
        for status in targets {
            let form = DirectDepositForm(
                id: status.formId,
                createdBy: UUID(),
                title: status.title,
                blankFilePath: status.blankFilePath,
                isBroadcast: true,
                createdAt: status.createdAt
            )
            do { try await FormsService.shared.deleteForm(form) }
            catch { errorMessage = error.localizedDescription; return }
        }
        await load()
    }
}
