import Foundation

struct Message: Identifiable, Codable, Equatable {
    var id: UUID
    var senderId: UUID
    var recipientId: UUID
    var body: String
    var createdAt: Date
    var readAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case senderId = "sender_id"
        case recipientId = "recipient_id"
        case body
        case createdAt = "created_at"
        case readAt = "read_at"
    }
}

struct NewMessage: Encodable {
    var recipientId: UUID
    var body: String

    enum CodingKeys: String, CodingKey {
        case recipientId = "recipient_id"
        case body
    }
}

struct MarkReadPatch: Encodable {
    var readAt: Date
    enum CodingKeys: String, CodingKey { case readAt = "read_at" }
}

struct Conversation: Identifiable, Codable, Equatable {
    var partnerId: UUID
    var partnerEmail: String
    var lastBody: String
    var lastAt: Date
    var unreadCount: Int

    var id: UUID { partnerId }

    enum CodingKeys: String, CodingKey {
        case partnerId = "partner_id"
        case partnerEmail = "partner_email"
        case lastBody = "last_body"
        case lastAt = "last_at"
        case unreadCount = "unread_count"
    }
}
