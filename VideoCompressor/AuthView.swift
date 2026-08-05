import SwiftUI

struct AuthView: View {
    enum Mode { case logIn, signUp }

    @EnvironmentObject private var accountStore: AccountStore
    @State private var mode: Mode = .logIn
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false

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
                .background(Theme.board)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius))
            }
            .disabled(isSubmitting)

            HStack {
                Rectangle().fill(Theme.line).frame(height: 1)
                Text("or").font(.caption2).foregroundStyle(Theme.inkSoft)
                Rectangle().fill(Theme.line).frame(height: 1)
            }

            Button {
                errorMessage = "Sign in with Apple is not connected yet."
            } label: {
                Label("Continue with Apple", systemImage: "apple.logo")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .overlay(RoundedRectangle(cornerRadius: Theme.controlRadius).stroke(Theme.line))
                    .foregroundStyle(Theme.ink)
            }
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
                    .background(Theme.board)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius))
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
}

#Preview {
    AuthView().environmentObject(AccountStore.shared)
}
