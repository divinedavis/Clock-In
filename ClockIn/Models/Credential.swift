import Foundation

enum CredentialKind: String, Codable, CaseIterable, Identifiable {
    case osha30 = "osha_30"
    case flaggerCard = "flagger_card"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .osha30: return "OSHA 30"
        case .flaggerCard: return "Flagger Card"
        }
    }
}

struct Credential: Identifiable, Codable, Equatable {
    var id: UUID
    var userId: UUID
    var kind: CredentialKind
    var filePath: String
    var contentType: String?
    var uploadedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case kind
        case filePath = "file_path"
        case contentType = "content_type"
        case uploadedAt = "uploaded_at"
    }
}

struct NewCredential: Encodable {
    var kind: CredentialKind
    var filePath: String
    var contentType: String?

    enum CodingKeys: String, CodingKey {
        case kind
        case filePath = "file_path"
        case contentType = "content_type"
    }
}
