import Foundation
import Security

struct AccountSession: Codable, Equatable {
    var name: String
    var email: String
    var createdAt: Date?
}

enum AccountError: LocalizedError {
    case missingFields

    var errorDescription: String? {
        switch self {
        case .missingFields: return "Fill in every field first."
        }
    }
}

@MainActor
final class AccountStore: ObservableObject {
    static let shared = AccountStore()

    @Published private(set) var session: AccountSession?
    /// Set after signUp when the account needs email confirmation before it can log in.
    @Published var pendingConfirmationEmail: String?

    private let service = "com.automatrix.videocompressor.supabase"
    private let sessionKey = "com.automatrix.videocompressor.session"

    private init() {
        if let data = UserDefaults.standard.data(forKey: sessionKey),
           let saved = try? JSONDecoder().decode(AccountSession.self, from: data) {
            session = saved
        }
    }

    var isLoggedIn: Bool { session != nil }

    func signUp(name: String, email: String, password: String) async throws {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !email.isEmpty, !password.isEmpty else { throw AccountError.missingFields }

        guard let supabaseSession = try await SupabaseAuthClient.signUp(name: name, email: email, password: password) else {
            pendingConfirmationEmail = email
            return
        }
        applySession(supabaseSession)
    }

    func logIn(email: String, password: String) async throws {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !email.isEmpty, !password.isEmpty else { throw AccountError.missingFields }

        let supabaseSession = try await SupabaseAuthClient.logIn(email: email, password: password)
        applySession(supabaseSession)
    }

    func signInWithApple(idToken: String, nonce: String) async throws {
        let supabaseSession = try await SupabaseAuthClient.signInWithApple(idToken: idToken, nonce: nonce)
        applySession(supabaseSession)
    }

    func signOut() {
        session = nil
        UserDefaults.standard.removeObject(forKey: sessionKey)
        deleteTokens()
    }

    func requestPasswordReset(email: String) async throws {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !email.isEmpty else { throw AccountError.missingFields }
        try await SupabaseAuthClient.requestPasswordReset(email: email)
    }

    /// Apple 5.1.1(v): apps that support account creation must support in-app account
    /// deletion. Deletes the row server-side (RPC scoped to the caller's own auth.uid()),
    /// then clears everything local the same way signOut does.
    func deleteAccount() async throws {
        guard let tokens = loadTokens() else {
            signOut()
            return
        }
        try await SupabaseAuthClient.deleteAccount(accessToken: tokens.accessToken)
        signOut()
    }

    private func applySession(_ supabaseSession: SupabaseSession) {
        pendingConfirmationEmail = nil
        let account = AccountSession(name: supabaseSession.name, email: supabaseSession.email, createdAt: supabaseSession.createdAt)
        session = account
        if let data = try? JSONEncoder().encode(account) {
            UserDefaults.standard.set(data, forKey: sessionKey)
        }
        storeTokens(supabaseSession)
    }

    // MARK: - Token storage (Keychain)

    private func storeTokens(_ supabaseSession: SupabaseSession) {
        guard let data = try? JSONEncoder().encode(supabaseSession) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "tokens",
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        SecItemAdd(attributes as CFDictionary, nil)
    }

    private func deleteTokens() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "tokens",
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func loadTokens() -> SupabaseSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "tokens",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(SupabaseSession.self, from: data)
    }
}
