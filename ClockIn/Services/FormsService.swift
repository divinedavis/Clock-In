import Foundation
import Supabase

@MainActor
final class FormsService {
    static let shared = FormsService()
    private let client = SupabaseManager.shared
    private let formsTable = "direct_deposit_forms"
    private let submissionsTable = "direct_deposit_submissions"
    private let bucket = "forms"

    // MARK: admin

    func adminStatus() async throws -> [AdminFormStatus] {
        try await client.rpc("admin_forms_status").execute().value
    }

    func adminFormStatus(formId: UUID) async throws -> [FormUserStatus] {
        try await client.rpc("admin_form_status", params: ["form_uuid": formId]).execute().value
    }

    func uploadBlankForm(
        title: String,
        data: Data,
        broadcast: Bool,
        recipientUserIds: [UUID]
    ) async throws -> DirectDepositForm {
        let id = UUID()
        let path = "blank/\(id.uuidString).pdf"
        _ = try await client.storage.from(bucket).upload(
            path,
            data: data,
            options: FileOptions(contentType: "application/pdf", upsert: false)
        )
        let payload = NewDirectDepositForm(
            title: title,
            blankFilePath: path,
            isBroadcast: broadcast
        )
        let inserted: DirectDepositForm = try await client.from(formsTable)
            .insert(payload, returning: .representation)
            .select()
            .single()
            .execute()
            .value
        if !broadcast && !recipientUserIds.isEmpty {
            let rows = recipientUserIds.map { FormRecipientRow(formId: inserted.id, userId: $0) }
            _ = try await client.from("form_recipients").insert(rows).execute()
        }
        return inserted
    }

    func downloadBlank(path: String) async throws -> Data {
        try await client.storage.from(bucket).download(path: path)
    }

    func deleteForm(_ form: DirectDepositForm) async throws {
        _ = try await client.storage.from(bucket).remove(paths: [form.blankFilePath])
        _ = try await client.from(formsTable).delete().eq("id", value: form.id).execute()
    }

    // MARK: user

    func myForms() async throws -> [DirectDepositForm] {
        try await client.from(formsTable)
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func mySubmissions() async throws -> [DirectDepositSubmission] {
        try await client.from(submissionsTable).select().execute().value
    }

    func submitFilled(formId: UUID, userId: UUID, data: Data) async throws {
        let path = "submitted/\(userId.uuidString)/\(formId.uuidString).pdf"
        _ = try await client.storage.from(bucket).upload(
            path,
            data: data,
            options: FileOptions(contentType: "application/pdf", upsert: true)
        )
        let payload = NewDirectDepositSubmission(formId: formId, submittedFilePath: path)
        _ = try await client.from(submissionsTable)
            .upsert(payload, onConflict: "form_id,user_id")
            .execute()
    }

    // MARK: shared

    func signedURL(path: String) async throws -> URL {
        try await client.storage.from(bucket).createSignedURL(path: path, expiresIn: 3600)
    }
}
