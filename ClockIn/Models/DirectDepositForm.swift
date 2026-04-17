import Foundation

struct DirectDepositForm: Identifiable, Codable, Equatable {
    var id: UUID
    var createdBy: UUID
    var title: String
    var blankFilePath: String
    var isBroadcast: Bool
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case createdBy = "created_by"
        case title
        case blankFilePath = "blank_file_path"
        case isBroadcast = "is_broadcast"
        case createdAt = "created_at"
    }
}

struct DirectDepositSubmission: Identifiable, Codable, Equatable {
    var id: UUID
    var formId: UUID
    var userId: UUID
    var submittedFilePath: String
    var submittedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case formId = "form_id"
        case userId = "user_id"
        case submittedFilePath = "submitted_file_path"
        case submittedAt = "submitted_at"
    }
}

struct NewDirectDepositForm: Encodable {
    var title: String
    var blankFilePath: String
    var isBroadcast: Bool

    enum CodingKeys: String, CodingKey {
        case title
        case blankFilePath = "blank_file_path"
        case isBroadcast = "is_broadcast"
    }
}

struct NewDirectDepositSubmission: Encodable {
    var formId: UUID
    var submittedFilePath: String

    enum CodingKeys: String, CodingKey {
        case formId = "form_id"
        case submittedFilePath = "submitted_file_path"
    }
}

struct AdminFormStatus: Identifiable, Codable, Equatable {
    var formId: UUID
    var title: String
    var blankFilePath: String
    var isBroadcast: Bool
    var createdAt: Date
    var totalAssigned: Int
    var submittedCount: Int
    var pendingEmails: [String]

    var id: UUID { formId }

    enum CodingKeys: String, CodingKey {
        case formId = "form_id"
        case title
        case blankFilePath = "blank_file_path"
        case isBroadcast = "is_broadcast"
        case createdAt = "created_at"
        case totalAssigned = "total_assigned"
        case submittedCount = "submitted_count"
        case pendingEmails = "pending_emails"
    }
}

struct FormRecipientRow: Encodable {
    var formId: UUID
    var userId: UUID

    enum CodingKeys: String, CodingKey {
        case formId = "form_id"
        case userId = "user_id"
    }
}
