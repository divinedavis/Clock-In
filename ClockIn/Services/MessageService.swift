import Foundation

@MainActor
final class MessageService {
    static let shared = MessageService()
    private let client = SupabaseManager.shared
    private let table = "messages"

    func myConversations() async throws -> [Conversation] {
        try await client.rpc("my_conversations").execute().value
    }

    func listOtherUsers() async throws -> [UserRow] {
        try await client.rpc("list_messageable_users").execute().value
    }

    func thread(with partnerId: UUID, me: UUID) async throws -> [Message] {
        let orA = "and(sender_id.eq.\(me.uuidString),recipient_id.eq.\(partnerId.uuidString))"
        let orB = "and(sender_id.eq.\(partnerId.uuidString),recipient_id.eq.\(me.uuidString))"
        return try await client.from(table)
            .select()
            .or("\(orA),\(orB)")
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    func send(to partnerId: UUID, body: String) async throws -> Message {
        let payload = NewMessage(recipientId: partnerId, body: body)
        let inserted: Message = try await client.from(table)
            .insert(payload, returning: .representation)
            .select()
            .single()
            .execute()
            .value
        return inserted
    }

    func markThreadRead(partnerId: UUID, me: UUID) async throws {
        _ = try await client.from(table)
            .update(MarkReadPatch(readAt: Date()))
            .eq("sender_id", value: partnerId)
            .eq("recipient_id", value: me)
            .is("read_at", value: nil)
            .execute()
    }
}
