import Foundation

@MainActor
final class MessagesViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            conversations = try await MessageService.shared.myConversations()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
