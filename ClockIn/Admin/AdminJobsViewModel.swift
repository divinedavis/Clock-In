import Foundation

@MainActor
final class AdminJobsViewModel: ObservableObject {
    @Published var jobs: [Job] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = JobService.shared

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            jobs = try await service.fetchAllJobs()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(indexSet: IndexSet) async {
        let targets = indexSet.map { jobs[$0] }
        for job in targets {
            do { try await service.deleteJob(id: job.id) }
            catch { errorMessage = error.localizedDescription; return }
        }
        await load()
    }
}
