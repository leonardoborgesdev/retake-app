import Foundation

/// Minimal REST client for Supabase Auth (GoTrue) - no SDK dependency, just the
/// two endpoints retake. needs. Self-hosted instance, see docs/design-mockup.md
/// for where it runs.
enum SupabaseAuthError: LocalizedError {
    case server(String)
    case decodingFailed
    case emailNotConfirmed

    var errorDescription: String? {
        switch self {
        case .server(let message):
            return message
        case .decodingFailed:
            return "Unexpected response from the server."
        case .emailNotConfirmed:
            return "Check your email and confirm your account before logging in."
        }
    }
}

struct SupabaseSession: Codable {
    let accessToken: String
    let refreshToken: String
    let userId: String
    let email: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }

    enum UserKeys: String, CodingKey {
        case id
        case email
        case userMetadata = "user_metadata"
    }

    enum MetadataKeys: String, CodingKey {
        case name
    }

    init(accessToken: String, refreshToken: String, userId: String, email: String, name: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.userId = userId
        self.email = email
        self.name = name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        refreshToken = try container.decode(String.self, forKey: .refreshToken)
        let userContainer = try container.nestedContainer(keyedBy: UserKeys.self, forKey: .user)
        userId = try userContainer.decode(String.self, forKey: .id)
        email = try userContainer.decode(String.self, forKey: .email)
        if let metadata = try? userContainer.nestedContainer(keyedBy: MetadataKeys.self, forKey: .userMetadata) {
            name = (try? metadata.decode(String.self, forKey: .name)) ?? email
        } else {
            name = email
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accessToken, forKey: .accessToken)
        try container.encode(refreshToken, forKey: .refreshToken)
    }
}

enum SupabaseAuthClient {
    static let baseURL = URL(string: "https://supabase-retake.automatrixapps99x.win")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzgyMTUxMTY0LCJleHAiOjE5Mzk4MzExNjR9.5mQJDVI7TBn-tsn0J3Mz1Qm1HFjDApd38F58M0sLFdE"

    /// Returns nil (not an error) when signup succeeded but the account needs email
    /// confirmation before it has a session - autoconfirm is off on this instance.
    static func signUp(name: String, email: String, password: String) async throws -> SupabaseSession? {
        var request = makeRequest(url: baseURL.appendingPathComponent("auth/v1/signup"))
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "email": email,
            "password": password,
            "data": ["name": name],
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        try checkStatus(response, data: data)

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           json["access_token"] == nil {
            return nil
        }
        return try decodeSession(data)
    }

    static func logIn(email: String, password: String) async throws -> SupabaseSession {
        let url = URL(string: baseURL.absoluteString + "/auth/v1/token?grant_type=password")!
        var request = makeRequest(url: url)
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "email": email,
            "password": password,
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        try checkStatus(response, data: data)
        return try decodeSession(data)
    }

    private static func makeRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    private static func checkStatus(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard http.statusCode >= 400 else { return }
        let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["msg"] as? String
            ?? (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error_description"] as? String
            ?? "Server error (\(http.statusCode))."
        if message.lowercased().contains("confirm") {
            throw SupabaseAuthError.emailNotConfirmed
        }
        throw SupabaseAuthError.server(message)
    }

    private static func decodeSession(_ data: Data) throws -> SupabaseSession {
        do {
            return try JSONDecoder().decode(SupabaseSession.self, from: data)
        } catch {
            throw SupabaseAuthError.decodingFailed
        }
    }
}
