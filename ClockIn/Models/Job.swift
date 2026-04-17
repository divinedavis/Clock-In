import Foundation

struct Job: Identifiable, Codable, Equatable {
    var id: UUID
    var createdBy: UUID
    var title: String
    var address: String?
    var locationLat: Double?
    var locationLng: Double?
    var scheduledAt: Date
    var notes: String?
    var isBroadcast: Bool
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case createdBy = "created_by"
        case title
        case address
        case locationLat = "location_lat"
        case locationLng = "location_lng"
        case scheduledAt = "scheduled_at"
        case notes
        case isBroadcast = "is_broadcast"
        case createdAt = "created_at"
    }
}

struct NewJob: Encodable {
    var title: String
    var address: String?
    var locationLat: Double?
    var locationLng: Double?
    var scheduledAt: Date
    var notes: String?
    var isBroadcast: Bool

    enum CodingKeys: String, CodingKey {
        case title
        case address
        case locationLat = "location_lat"
        case locationLng = "location_lng"
        case scheduledAt = "scheduled_at"
        case notes
        case isBroadcast = "is_broadcast"
    }
}

struct JobRecipientRow: Encodable {
    var jobId: UUID
    var userId: UUID

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case userId = "user_id"
    }
}

struct UserRow: Identifiable, Codable, Hashable {
    var userId: UUID
    var email: String
    var id: UUID { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case email
    }
}
