import Foundation

@MainActor
final class AdminViewModel: ObservableObject {
    @Published var entries: [AdminTimeEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let client = SupabaseManager.shared

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            entries = try await client.rpc("admin_time_entries")
                .execute()
                .value
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
