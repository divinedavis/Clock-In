import Foundation
import Supabase

@MainActor
final class CredentialsService {
    static let shared = CredentialsService()
    private let client = SupabaseManager.shared
    private let table = "credentials"
    private let bucket = "credentials"

    func myCredentials(kind: CredentialKind) async throws -> [Credential] {
        try await client.from(table)
            .select()
            .eq("kind", value: kind.rawValue)
            .order("uploaded_at", ascending: false)
            .execute()
            .value
    }

    func upload(
        kind: CredentialKind,
        userId: UUID,
        data: Data,
        ext: String,
        contentType: String
    ) async throws -> Credential {
        let id = UUID()
        // Supabase RLS policies compare to auth.uid()::text (lowercase canonical form);
        // Swift's UUID.uuidString is uppercase, so we must lowercase it to match.
        let path = "\(userId.uuidString.lowercased())/\(kind.rawValue)/\(id.uuidString.lowercased()).\(ext)"
        _ = try await client.storage.from(bucket).upload(
            path,
            data: data,
            options: FileOptions(contentType: contentType, upsert: false)
        )
        let payload = NewCredential(kind: kind, filePath: path, contentType: contentType)
        let inserted: Credential = try await client.from(table)
            .insert(payload, returning: .representation)
            .select()
            .single()
            .execute()
            .value
        return inserted
    }

    func delete(_ credential: Credential) async throws {
        _ = try await client.storage.from(bucket).remove(paths: [credential.filePath])
        _ = try await client.from(table).delete().eq("id", value: credential.id).execute()
    }

    func signedURL(path: String) async throws -> URL {
        try await client.storage.from(bucket).createSignedURL(path: path, expiresIn: 3600)
    }
}
