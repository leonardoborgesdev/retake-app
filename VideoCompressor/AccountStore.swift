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

    func signOut() {
        session = nil
        UserDefaults.standard.removeObject(forKey: sessionKey)
        deleteTokens()
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
}
