import Foundation

@MainActor
final class ThreadViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var errorMessage: String?

    func load(partnerId: UUID, me: UUID) async {
        do {
            messages = try await MessageService.shared.thread(with: partnerId, me: me)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func send(to partnerId: UUID, body: String) async {
        do {
            let msg = try await MessageService.shared.send(to: partnerId, body: body)
            messages.append(msg)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markRead(partnerId: UUID, me: UUID) async {
        do {
            try await MessageService.shared.markThreadRead(partnerId: partnerId, me: me)
        } catch {
            // non-fatal
        }
    }
}
