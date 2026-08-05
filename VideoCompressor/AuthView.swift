import SwiftUI

struct AuthView: View {
    enum Mode { case logIn, signUp }

    @EnvironmentObject private var accountStore: AccountStore
    @State private var mode: Mode = .logIn
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 12)
            AppMark(size: 44)
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
                submit()
            } label: {
                Text(mode == .logIn ? "Log in" : "Create account")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.board)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius))
            }

            HStack {
                Rectangle().fill(Theme.line).frame(height: 1)
                Text("or").font(.caption2).foregroundStyle(Theme.inkSoft)
                Rectangle().fill(Theme.line).frame(height: 1)
            }

            Button {
                // No backend yet - Sign in with Apple will be wired once accounts move server-side.
                errorMessage = "Sign in with Apple is not connected yet."
            } label: {
                Label("Continue with Apple", systemImage: "apple.logo")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .overlay(RoundedRectangle(cornerRadius: Theme.controlRadius).stroke(Theme.line))
                    .foregroundStyle(Theme.ink)
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

    private func submit() {
        do {
            switch mode {
            case .logIn:
                try accountStore.logIn(email: email, password: password)
            case .signUp:
                try accountStore.signUp(name: name, email: email, password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    AuthView().environmentObject(AccountStore.shared)
}
