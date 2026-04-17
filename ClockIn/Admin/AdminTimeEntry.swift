import Foundation

struct AdminTimeEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var userId: UUID
    var email: String
    var clockInAt: Date
    var clockOutAt: Date?
    var clockInLat: Double?
    var clockInLng: Double?
    var clockOutLat: Double?
    var clockOutLng: Double?

    var duration: TimeInterval? {
        guard let out = clockOutAt else { return nil }
        return out.timeIntervalSince(clockInAt)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case email
        case clockInAt = "clock_in_at"
        case clockOutAt = "clock_out_at"
        case clockInLat = "clock_in_lat"
        case clockInLng = "clock_in_lng"
        case clockOutLat = "clock_out_lat"
        case clockOutLng = "clock_out_lng"
    }
}
