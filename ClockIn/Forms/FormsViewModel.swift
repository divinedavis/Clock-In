import Foundation

@MainActor
final class FormsViewModel: ObservableObject {
    @Published var forms: [DirectDepositForm] = []
    @Published var submissions: [DirectDepositSubmission] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let forms = FormsService.shared.myForms()
            async let subs = FormsService.shared.mySubmissions()
            self.forms = try await forms
            self.submissions = try await subs
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func isSubmitted(_ form: DirectDepositForm) -> Bool {
        submissions.contains { $0.formId == form.id }
    }
}
