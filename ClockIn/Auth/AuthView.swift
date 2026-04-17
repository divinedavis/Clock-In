import SwiftUI

struct AuthView: View {
    @EnvironmentObject var auth: AuthViewModel
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
            VStack(spacing: 24) {
                Image(systemName: "clock.badge.checkmark.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                    .padding(.top, 32)

                Text(mode == .signIn ? "Welcome back" : "Create your account")
                    .font(.title.weight(.semibold))

                VStack(spacing: 12) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))

                    SecureField("Password", text: $password)
                        .textContentType(mode == .signIn ? .password : .newPassword)
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))

                    if mode == .signUp {
                        SecureField("Confirm password", text: $confirmPassword)
                            .textContentType(.newPassword)
                            .padding()
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    }
                }

                if mode == .signUp && !confirmPassword.isEmpty && password != confirmPassword {
                    Text("Passwords don't match")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if let error = auth.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button(action: submit) {
                    Group {
                        if auth.isWorking {
                            ProgressView().tint(.white)
                        } else {
                            Text(mode == .signIn ? "Sign In" : "Sign Up")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
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
