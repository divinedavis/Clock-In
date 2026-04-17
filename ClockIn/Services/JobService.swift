import Foundation
import CoreLocation

@MainActor
final class JobService {
    static let shared = JobService()
    private let client = SupabaseManager.shared
    private let jobsTable = "jobs"
    private let recipientsTable = "job_recipients"

    func fetchMyJobs() async throws -> [Job] {
        try await client.from(jobsTable)
            .select()
            .order("scheduled_at", ascending: true)
            .execute()
            .value
    }

    func fetchAllJobs() async throws -> [Job] {
        try await client.from(jobsTable)
            .select()
            .order("scheduled_at", ascending: false)
            .execute()
            .value
    }

    func listUsers() async throws -> [UserRow] {
        try await client.rpc("admin_list_users").execute().value
    }

    func createJob(
        title: String,
        address: String?,
        scheduledAt: Date,
        notes: String?,
        recipientUserIds: [UUID],
        broadcast: Bool
    ) async throws -> Job {
        var lat: Double?
        var lng: Double?
        if let address, !address.isEmpty {
            if let coord = try? await geocode(address) {
                lat = coord.latitude
                lng = coord.longitude
            }
        }

        let payload = NewJob(
            title: title,
            address: address,
            locationLat: lat,
            locationLng: lng,
            scheduledAt: scheduledAt,
            notes: notes,
            isBroadcast: broadcast
        )

        let inserted: Job = try await client.from(jobsTable)
            .insert(payload, returning: .representation)
            .select()
            .single()
            .execute()
            .value

        if !broadcast && !recipientUserIds.isEmpty {
            let rows = recipientUserIds.map { JobRecipientRow(jobId: inserted.id, userId: $0) }
            _ = try await client.from(recipientsTable)
                .insert(rows)
                .execute()
        }

        return inserted
    }

    func deleteJob(id: UUID) async throws {
        _ = try await client.from(jobsTable)
            .delete()
            .eq("id", value: id)
            .execute()
    }

    private func geocode(_ address: String) async throws -> CLLocationCoordinate2D {
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.geocodeAddressString(address)
        guard let loc = placemarks.first?.location?.coordinate else {
            throw NSError(domain: "Geocode", code: 1, userInfo: [NSLocalizedDescriptionKey: "Address not found"])
        }
        return loc
    }
}
