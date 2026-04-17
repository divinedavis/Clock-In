import Foundation
import Supabase

@MainActor
final class AuthViewModel: ObservableObject {
    enum State { case loading, signedIn, signedOut }

    @Published var state: State = .loading
    @Published var errorMessage: String?
    @Published var isWorking = false
    @Published private(set) var userEmail: String?
    @Published private(set) var userId: UUID?

    private let client = SupabaseManager.shared

    func restoreSession() async {
        do {
            let session = try await client.auth.session
            userEmail = session.user.email
            userId = session.user.id
            state = .signedIn
        } catch {
            state = .signedOut
        }
    }

    func signIn(email: String, password: String) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let session = try await client.auth.signIn(email: email, password: password)
            userEmail = session.user.email
            userId = session.user.id
            state = .signedIn
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signUp(email: String, password: String) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let response = try await client.auth.signUp(email: email, password: password)
            if response.session != nil {
                userEmail = response.user.email
                userId = response.user.id
                state = .signedIn
            } else {
                errorMessage = "Check your email to confirm your account, then sign in."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        do {
            try await client.auth.signOut()
            userEmail = nil
            userId = nil
            state = .signedOut
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
