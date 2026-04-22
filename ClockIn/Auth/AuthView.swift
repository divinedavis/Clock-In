import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var showEmail = false
    @State private var currentNonce: String?

    var body: some View {
        ZStack {
            backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                marketingStack
                Spacer(minLength: 12)
                brandCard
                Spacer(minLength: 24)
                actionButtons
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showEmail) {
            EmailAuthView()
                .environmentObject(auth)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            stops: [
                .init(color: .white, location: 0.0),
                .init(color: .white, location: 0.46),
                .init(color: Color(red: 0.78, green: 0.88, blue: 1.0), location: 0.54),
                .init(color: Color(red: 0.35, green: 0.60, blue: 0.97), location: 0.72),
                .init(color: Color(red: 0.12, green: 0.38, blue: 0.90), location: 1.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Marketing words

    private var marketingStack: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Clock In")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.14))
            HStack(spacing: 12) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(Color(red: 0.20, green: 0.45, blue: 0.95))
                Text("Track")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
            }
            Text("Clock Out")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.14))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Brand card + copy

    private var brandCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white)
                .frame(width: 64, height: 64)
                .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
                .overlay(
                    Image(systemName: "clock.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Color(red: 0.20, green: 0.45, blue: 0.95))
                )

            VStack(alignment: .leading, spacing: 6) {
                Text("Your time, tracked.")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Clock in and clock out from anywhere — see where every hour of your week went.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            SignInWithAppleButton(
                onRequest: { request in
                    let nonce = AppleSignIn.randomNonce()
                    self.currentNonce = nonce
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = AppleSignIn.sha256(nonce)
                },
                onCompletion: handleAppleCompletion
            )
            .signInWithAppleButtonStyle(.white)
            .frame(height: 54)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.15), radius: 10, y: 4)

            Button {
                showEmail = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "envelope.fill")
                    Text("Continue with Email")
                        .font(.system(size: 17, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(.white.opacity(0.25), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
                .foregroundStyle(.white)
            }

            if let error = auth.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.5), in: Capsule())
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let nonce = currentNonce,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8)
            else {
                auth.errorMessage = "Apple sign-in did not return a valid credential."
                return
            }
            Task { await auth.signInWithApple(idToken: idToken, nonce: nonce) }
        case .failure(let error):
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                return // user tapped cancel — no error surface
            }
            auth.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Email fallback

private struct EmailAuthView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    enum Mode { case signIn, signUp }

    private var passwordsMatch: Bool {
        mode == .signIn || (!confirmPassword.isEmpty && password == confirmPassword)
    }

    private var canSubmit: Bool {
        !auth.isWorking && !email.isEmpty && !password.isEmpty && passwordsMatch
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(mode == .signIn ? "Welcome back" : "Create your account")
                    .font(.title2.weight(.semibold))
                    .padding(.top, 8)

                VStack(spacing: 10) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                    SecureField("Password", text: $password)
                        .textContentType(mode == .signIn ? .password : .newPassword)
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                    if mode == .signUp {
                        SecureField("Confirm password", text: $confirmPassword)
                            .textContentType(.newPassword)
                            .padding()
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                }

                if mode == .signUp, !confirmPassword.isEmpty, password != confirmPassword {
                    Text("Passwords don't match")
                        .font(.footnote).foregroundStyle(.red)
                }

                if let error = auth.errorMessage {
                    Text(error)
                        .font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
                }

                Button(action: submit) {
                    Group {
                        if auth.isWorking {
                            ProgressView().tint(.white)
                        } else {
                            Text(mode == .signIn ? "Sign In" : "Sign Up").fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
                }
                .disabled(!canSubmit)

                Button(mode == .signIn ? "Need an account? Sign up" : "Have an account? Sign in") {
                    mode = (mode == .signIn) ? .signUp : .signIn
                    confirmPassword = ""
                    auth.errorMessage = nil
                }
                .font(.footnote)

                Spacer()
            }
            .padding(.horizontal, 24)
            .onChange(of: auth.state) { _, new in
                if new == .signedIn { dismiss() }
            }
        }
    }

    private func submit() {
        Task {
            switch mode {
            case .signIn: await auth.signIn(email: email, password: password)
            case .signUp: await auth.signUp(email: email, password: password)
            }
        }
    }
}
