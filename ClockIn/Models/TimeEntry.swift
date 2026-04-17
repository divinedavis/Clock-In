import Foundation

struct TimeEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var userId: UUID
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
        case clockInAt = "clock_in_at"
        case clockOutAt = "clock_out_at"
        case clockInLat = "clock_in_lat"
        case clockInLng = "clock_in_lng"
        case clockOutLat = "clock_out_lat"
        case clockOutLng = "clock_out_lng"
    }

    static func durationString(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}

struct NewTimeEntry: Encodable {
    var userId: UUID
    var clockInAt: Date
    var clockInLat: Double?
    var clockInLng: Double?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case clockInAt = "clock_in_at"
        case clockInLat = "clock_in_lat"
        case clockInLng = "clock_in_lng"
    }
}

struct ClockOutPatch: Encodable {
    var clockOutAt: Date
    var clockOutLat: Double?
    var clockOutLng: Double?

    enum CodingKeys: String, CodingKey {
        case clockOutAt = "clock_out_at"
        case clockOutLat = "clock_out_lat"
        case clockOutLng = "clock_out_lng"
    }
}
