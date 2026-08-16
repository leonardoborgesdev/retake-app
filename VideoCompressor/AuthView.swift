import SwiftUI
import AuthenticationServices
import CryptoKit

struct AuthView: View {
    enum Mode { case logIn, signUp }

    @EnvironmentObject private var accountStore: AccountStore
    @State private var mode: Mode = .logIn
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var showForgotPassword = false
    @State private var resetEmail = ""
    @State private var isSendingReset = false
    @State private var resetSent = false
    // Regenerated on every tap of the Apple button (onRequest), read back once Apple
    // calls onCompletion - GoTrue re-hashes this raw value and checks it against the
    // nonce claim inside the identity token, to prove the token wasn't replayed.
    @State private var currentAppleNonce = ""

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 12)
            AppMark(size: 44)

            if let pendingEmail = accountStore.pendingConfirmationEmail {
                confirmationPending(email: pendingEmail)
            } else {
                form
            }

            Spacer()
        }
        .padding(24)
        .background(Theme.paper)
        .alert("Could not continue", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
        .onAppear {
#if DEBUG
            // Debug-only: `defaults write <bundle-id> debugEmail -string "..."` +
            // debugPassword lets QA/screenshot runs skip typing credentials by hand.
            // Compiled out of Release entirely.
            if let debugEmail = UserDefaults.standard.string(forKey: "debugEmail"), !debugEmail.isEmpty,
               let debugPassword = UserDefaults.standard.string(forKey: "debugPassword"), !debugPassword.isEmpty {
                Task {
                    try? await accountStore.logIn(email: debugEmail, password: debugPassword)
                }
            }
#endif
        }
    }

    private var form: some View {
        VStack(spacing: 20) {
            Text(mode == .logIn ? "Welcome back." : "Create account.")
                .font(Theme.displayFont(20))

            Picker("Mode", selection: $mode) {
                Text("Log in").tag(Mode.logIn)
                Text("Sign up").tag(Mode.signUp)
            }
            .pickerStyle(.segmented)
            .padding(.top, 4)

            VStack(spacing: 12) {
                if mode == .signUp {
                    field(label: "Name", text: $name, placeholder: "Your name", capitalization: .words)
                }
                field(label: "Email", text: $email, placeholder: "you@email.com", keyboard: .emailAddress)
                field(label: "Password", text: $password, placeholder: "Password", isSecure: true)
            }

            Button {
                Task { await submit() }
            } label: {
                Group {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text(mode == .logIn ? "Log in" : "Create account")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .primaryButtonSurface()
            }
            .disabled(isSubmitting)

            HStack(spacing: 10) {
                Rectangle().fill(Theme.line).frame(height: 1)
                Text("or").font(.caption2).foregroundStyle(Theme.inkSoft)
                Rectangle().fill(Theme.line).frame(height: 1)
            }

            SignInWithAppleButton(.continue) { request in
                let nonce = Self.randomNonceString()
                currentAppleNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = Self.sha256(nonce)
            } onCompletion: { result in
                switch result {
                case .success(let authorization):
                    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                          let tokenData = credential.identityToken,
                          let identityToken = String(data: tokenData, encoding: .utf8) else {
                        errorMessage = "Could not read the Apple credential."
                        return
                    }
                    Task { await submitAppleSignIn(idToken: identityToken, nonce: currentAppleNonce) }
                case .failure(let error):
                    // .canceled fires when the user dismisses the Apple sheet - not a
                    // real error, don't show an alert for it.
                    let nsError = error as NSError
                    if nsError.domain == ASAuthorizationError.errorDomain,
                       nsError.code == ASAuthorizationError.canceled.rawValue {
                        return
                    }
                    errorMessage = error.localizedDescription
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 46)
            .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius))

            if mode == .logIn {
                Button {
                    resetEmail = email
                    resetSent = false
                    showForgotPassword = true
                } label: {
                    Text("Forgot password?")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            forgotPasswordSheet
        }
    }

    private var forgotPasswordSheet: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 12)
            Image(systemName: "key.fill")
                .font(.system(size: 34))
                .foregroundStyle(Theme.accent)

            if resetSent {
                Text("Check your email").font(Theme.displayFont(18))
                Text("We sent a password reset link to \(resetEmail). Tap it, set a new password, then log in.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                Button {
                    showForgotPassword = false
                } label: {
                    Text("Done")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .primaryButtonSurface()
                }
            } else {
                Text("Reset password").font(Theme.displayFont(18))
                Text("We'll send a reset link to your email.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
                field(label: "Email", text: $resetEmail, placeholder: "you@email.com", keyboard: .emailAddress)
                Button {
                    Task { await sendReset() }
                } label: {
                    Group {
                        if isSendingReset {
                            ProgressView().tint(.white)
                        } else {
                            Text("Send reset link")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .primaryButtonSurface()
                }
                .disabled(isSendingReset || resetEmail.isEmpty)
            }
            Spacer()
        }
        .padding(24)
        .background(Theme.paper)
        .alert("Could not continue", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
    }

    private func sendReset() async {
        isSendingReset = true
        defer { isSendingReset = false }
        do {
            try await accountStore.requestPasswordReset(email: resetEmail)
            resetSent = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func confirmationPending(email: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 34))
                .foregroundStyle(Theme.accent)
            Text("Check your email").font(Theme.displayFont(18))
            Text("We sent a confirmation link to \(email). Tap it, then log in below.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)

            Button {
                accountStore.pendingConfirmationEmail = nil
                mode = .logIn
                self.email = email
            } label: {
                Text("Back to log in")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .primaryButtonSurface()
            }
        }
    }

    private func field(label: String, text: Binding<String>, placeholder: String, keyboard: UIKeyboardType = .default, isSecure: Bool = false, capitalization: TextInputAutocapitalization = .never) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.inkSoft)
            Group {
                if isSecure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(capitalization)
                        .autocorrectionDisabled()
                }
            }
            .padding(10)
            .background(Theme.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            switch mode {
            case .logIn:
                try await accountStore.logIn(email: email, password: password)
            case .signUp:
                try await accountStore.signUp(name: name, email: email, password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submitAppleSignIn(idToken: String, nonce: String) async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await accountStore.signInWithApple(idToken: idToken, nonce: nonce)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Standard Sign in with Apple nonce recipe: a random raw value is hashed with
    // SHA256 and sent as the authorization request's nonce; Apple echoes it back inside
    // the identity token's "nonce" claim. The raw value (not the hash) then goes to
    // Supabase, which re-hashes it server-side to confirm the token matches this request.
    private static func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            precondition(status == errSecSuccess, "Unable to generate nonce.")
            for random in randoms {
                guard remaining > 0 else { break }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

#Preview {
    AuthView().environmentObject(AccountStore.shared)
}
