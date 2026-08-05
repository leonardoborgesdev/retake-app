import Foundation
import CryptoKit
import Security

/// Local-only account store. There is no backend yet - this exists so the
/// login/signup/account UI works end to end today. Credentials never leave
/// the device; when a real backend is added, replace the body of
/// signUp/logIn and keep the published session contract the same.
struct AccountSession: Codable, Equatable {
    var name: String
    var email: String
}

enum AccountError: LocalizedError {
    case emailInUse
    case invalidCredentials
    case missingFields

    var errorDescription: String? {
        switch self {
        case .emailInUse: return "An account with this email already exists."
        case .invalidCredentials: return "Wrong email or password."
        case .missingFields: return "Fill in every field first."
        }
    }
}

@MainActor
final class AccountStore: ObservableObject {
    static let shared = AccountStore()

    @Published private(set) var session: AccountSession?

    private let service = "com.automatrix.videocompressor.account"
    private let sessionKey = "com.automatrix.videocompressor.session"

    private init() {
        if let data = UserDefaults.standard.data(forKey: sessionKey),
           let saved = try? JSONDecoder().decode(AccountSession.self, from: data) {
            session = saved
        }
    }

    var isLoggedIn: Bool { session != nil }

    func signUp(name: String, email: String, password: String) throws {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !email.isEmpty, !password.isEmpty else { throw AccountError.missingFields }
        guard readPasswordHash(email: email) == nil else { throw AccountError.emailInUse }

        try storePasswordHash(email: email, password: password)
        UserDefaults.standard.set(name, forKey: nameKey(for: email))
        setSession(AccountSession(name: name, email: email))
    }

    func logIn(email: String, password: String) throws {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !email.isEmpty, !password.isEmpty else { throw AccountError.missingFields }
        guard let storedHash = readPasswordHash(email: email), storedHash == hash(password) else {
            throw AccountError.invalidCredentials
        }
        let name = UserDefaults.standard.string(forKey: nameKey(for: email)) ?? email
        setSession(AccountSession(name: name, email: email))
    }

    func signOut() {
        session = nil
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }

    private func setSession(_ session: AccountSession) {
        self.session = session
        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: sessionKey)
        }
    }

    private func nameKey(for email: String) -> String { "name-\(email)" }

    private func hash(_ password: String) -> String {
        let digest = SHA256.hash(data: Data(password.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func storePasswordHash(email: String, password: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: email,
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = Data(hash(password).utf8)
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: "AccountStore", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Could not save the account to the Keychain."])
        }
    }

    private func readPasswordHash(email: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: email,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
