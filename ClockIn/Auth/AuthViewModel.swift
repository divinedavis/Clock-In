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
    @Published private(set) var isAdmin: Bool = false

    private let client = SupabaseManager.shared
    private var authChangesTask: Task<Void, Never>?

    func startObservingAuth() {
        authChangesTask?.cancel()
        authChangesTask = Task { [weak self] in
            guard let self else { return }
            for await (event, session) in await self.client.auth.authStateChanges {
                if Task.isCancelled { break }
                await self.handle(event: event, session: session)
            }
        }
    }

    deinit {
        authChangesTask?.cancel()
    }

    private func handle(event: AuthChangeEvent, session: Session?) async {
        switch event {
        case .initialSession, .signedIn, .tokenRefreshed, .userUpdated:
            if let session {
                userEmail = session.user.email
                userId = session.user.id
                await refreshIsAdmin()
                state = .signedIn
            } else {
                state = .signedOut
            }
        case .signedOut, .userDeleted:
            userEmail = nil
            userId = nil
            isAdmin = false
            state = .signedOut
        default:
            break
        }
    }

    func signIn(email: String, password: String) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            _ = try await client.auth.signIn(email: email, password: password)
            // authStateChanges will fire and drive state.
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
            if response.session == nil {
                errorMessage = "Check your email to confirm your account, then sign in."
            }
            // If a session was returned, authStateChanges will fire.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        do {
            try await client.auth.signOut()
            // authStateChanges will fire with .signedOut.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshIsAdmin() async {
        do {
            let value: Bool = try await client.rpc("is_admin").execute().value
            isAdmin = value
        } catch {
            isAdmin = false
        }
    }
}
