import Foundation

/// Minimal REST client for Supabase Auth (GoTrue) - no SDK dependency, just the
/// two endpoints retake. needs. Points at whatever Supabase project you configure
/// in `Secrets.swift` (see `Secrets.swift.example`) - self-hosted or hosted both work.
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
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }

    enum UserKeys: String, CodingKey {
        case id
        case email
        case userMetadata = "user_metadata"
        case createdAt = "created_at"
    }

    enum MetadataKeys: String, CodingKey {
        case name
    }

    init(accessToken: String, refreshToken: String, userId: String, email: String, name: String, createdAt: Date? = nil) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.userId = userId
        self.email = email
        self.name = name
        self.createdAt = createdAt
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
        if let raw = try? userContainer.decode(String.self, forKey: .createdAt) {
            createdAt = ISO8601DateFormatter.supabase.date(from: raw)
        } else {
            createdAt = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accessToken, forKey: .accessToken)
        try container.encode(refreshToken, forKey: .refreshToken)
    }
}

private extension ISO8601DateFormatter {
    static let supabase: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

enum SupabaseAuthClient {
    static let baseURL = Secrets.supabaseURL
    static let anonKey = Secrets.supabaseAnonKey

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
