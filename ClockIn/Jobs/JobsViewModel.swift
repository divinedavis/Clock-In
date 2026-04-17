import Foundation

@MainActor
final class JobsViewModel: ObservableObject {
    @Published var jobs: [Job] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = JobService.shared

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            jobs = try await service.fetchMyJobs()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
