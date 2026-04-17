import Foundation
import Supabase

@MainActor
final class TimeEntryService {
    static let shared = TimeEntryService()
    private let client = SupabaseManager.shared
    private let table = "time_entries"

    func fetchAll() async throws -> [TimeEntry] {
        try await client.from(table)
            .select()
            .order("clock_in_at", ascending: false)
            .execute()
            .value
    }

    func openEntry() async throws -> TimeEntry? {
        let rows: [TimeEntry] = try await client.from(table)
            .select()
            .is("clock_out_at", value: nil)
            .order("clock_in_at", ascending: false)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func clockIn(at date: Date, lat: Double?, lng: Double?) async throws -> TimeEntry {
        let payload = NewTimeEntry(clockInAt: date, clockInLat: lat, clockInLng: lng)
        let inserted: TimeEntry = try await client.from(table)
            .insert(payload, returning: .representation)
            .select()
            .single()
            .execute()
            .value
        return inserted
    }

    func clockOut(entryId: UUID, at date: Date, lat: Double?, lng: Double?) async throws -> TimeEntry {
        let patch = ClockOutPatch(clockOutAt: date, clockOutLat: lat, clockOutLng: lng)
        let updated: TimeEntry = try await client.from(table)
            .update(patch)
            .eq("id", value: entryId)
            .select()
            .single()
            .execute()
            .value
        return updated
    }
}
