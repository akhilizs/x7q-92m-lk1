import Foundation

/// The Supabase project used for accounts and cloud save. Filled in at build time from
/// the SUPABASE_URL and SUPABASE_KEY build settings (see supabase/setup.sql); `nil` when the build
/// has no project configured, in which case the app works offline only.
struct SupabaseConfig {
    let url: URL
    /// Publishable (or legacy anon) key. Safe to ship in the app: row level security
    /// limits every account to its own data.
    let key: String

    static let current: SupabaseConfig? = {
        func value(_ name: String) -> String? {
            // Launch arguments (`-SupabaseURL …`) override the build, for UI tests.
            let raw = UserDefaults.standard.string(forKey: name)
                ?? Bundle.main.object(forInfoDictionaryKey: name) as? String
            let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty || trimmed.hasPrefix("$(") ? nil : trimmed
        }
        guard let urlString = value("SupabaseURL"), let url = URL(string: urlString),
              url.scheme == "https" || url.scheme == "http",
              let key = value("SupabaseKey") else { return nil }
        return SupabaseConfig(url: url, key: key)
    }()
}

/// A signed-in Supabase user.
struct AuthSession: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var userID: String
    var email: String

    var needsRefresh: Bool { expiresAt.timeIntervalSinceNow < 60 }
}

struct SupabaseError: LocalizedError {
    var status: Int?
    var code: String?
    var message: String

    /// The access token was rejected; refreshing it may help.
    var isUnauthorized: Bool { status == 401 || code == "PGRST301" || code == "PGRST303" || code == "bad_jwt" }

    /// The account was deleted (for example from the Supabase dashboard) while this
    /// device was still logged in: its data row can't reference the user any more.
    var isAccountGone: Bool { code == "23503" || code == "user_not_found" }

    var errorDescription: String? {
        switch code {
        case "invalid_credentials":
            return "Wrong email or password."
        case "invalid_grant" where message.lowercased().contains("credentials"):
            return "Wrong email or password."
        case "email_not_confirmed":
            return "Confirm your email first: open the link we sent you, then log in."
        case "user_already_exists", "email_exists":
            return "There's already an account with this email. Log in instead."
        case "weak_password":
            return "Choose a stronger password (at least 6 characters)."
        case "email_address_invalid":
            return "Enter a valid email address."
        case "over_email_send_rate_limit":
            return "Too many emails were sent from ForgeFit recently, so we couldn't send yours. Please try again in about an hour."
        case "over_request_rate_limit":
            return "Too many attempts. Wait a few minutes and try again."
        case "signup_disabled":
            return "New accounts are turned off for this app."
        case "refresh_token_not_found", "refresh_token_already_used", "session_not_found", "session_expired":
            return "Your session expired. Log in again to keep saving your progress."
        case "PGRST205", "PGRST202", "42P01", "42883":
            return "Cloud save isn't set up yet. Run supabase/setup.sql in your Supabase project."
        case "23503", "user_not_found":
            return "This account no longer exists. Your progress is still on this iPhone: log in or create a new account to keep saving it."
        case "42501":
            return "The database refused to save your progress. Run supabase/setup.sql again in your Supabase project."
        default:
            return message
        }
    }

    static func from(status: Int, data: Data) -> SupabaseError {
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        // Auth errors: {error_code, msg} (or older {error, error_description}).
        // Database errors: {code, message, details, hint}.
        let code = json["error_code"] as? String
            ?? json["code"] as? String
            ?? json["error"] as? String
        let message = json["msg"] as? String
            ?? json["message"] as? String
            ?? json["error_description"] as? String
            ?? (String(data: data.prefix(200), encoding: .utf8).flatMap { $0.isEmpty ? nil : $0 })
            ?? HTTPURLResponse.localizedString(forStatusCode: status)
        return SupabaseError(status: status, code: code, message: message)
    }
}

/// A copy of the app's data stored in the `user_data` table.
struct CloudSave {
    /// Seconds since 1970 when the device saved it; used to spot changes from other devices.
    var savedAt: Double
    /// The JSON-encoded `AppStore.Snapshot`.
    var snapshot: Data
}

/// Minimal Supabase REST client: email + password auth and one row of JSON per user.
final class SupabaseClient {
    typealias Transport = (URLRequest) async throws -> (Data, URLResponse)

    /// Where confirmation and password-reset emails send the user back to (the app's URL scheme).
    static let callbackURL = "forgefit://auth-callback"

    let config: SupabaseConfig
    private let transport: Transport

    init(config: SupabaseConfig, transport: @escaping Transport = { try await URLSession.shared.data(for: $0) }) {
        self.config = config
        self.transport = transport
    }

    // MARK: Auth

    /// Creates an account. Returns `nil` when the project requires the email to be
    /// confirmed first (a confirmation link has been sent).
    func signUp(email: String, password: String) async throws -> AuthSession? {
        let data = try await send("auth/v1/signup", method: "POST",
                                  query: [URLQueryItem(name: "redirect_to", value: Self.callbackURL)],
                                  body: ["email": email, "password": password])
        let json = try Self.object(data)
        guard json["access_token"] != nil else { return nil }
        return try Self.session(from: json)
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        let data = try await send("auth/v1/token", method: "POST",
                                  query: [URLQueryItem(name: "grant_type", value: "password")],
                                  body: ["email": email, "password": password])
        return try Self.session(from: Self.object(data))
    }

    func refresh(_ session: AuthSession) async throws -> AuthSession {
        let data = try await send("auth/v1/token", method: "POST",
                                  query: [URLQueryItem(name: "grant_type", value: "refresh_token")],
                                  body: ["refresh_token": session.refreshToken])
        return try Self.session(from: Self.object(data), fallback: session)
    }

    /// Revokes the session on the server. Failures are ignored: the app forgets it either way.
    func signOut(_ session: AuthSession) async {
        _ = try? await send("auth/v1/logout", method: "POST", token: session.accessToken)
    }

    func sendPasswordReset(email: String) async throws {
        _ = try await send("auth/v1/recover", method: "POST",
                           query: [URLQueryItem(name: "redirect_to", value: Self.callbackURL)],
                           body: ["email": email])
    }

    func updatePassword(_ password: String, session: AuthSession) async throws {
        _ = try await send("auth/v1/user", method: "PUT", body: ["password": password], token: session.accessToken)
    }

    /// Reads the session from a confirmation or password-reset link that opened the app
    /// (`forgefit://auth-callback#access_token=…&refresh_token=…&type=recovery`).
    func session(fromCallback url: URL) async throws -> (session: AuthSession, type: String?) {
        let link = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var components = URLComponents()
        components.percentEncodedQuery = link?.percentEncodedFragment ?? link?.percentEncodedQuery
        var params: [String: String] = [:]
        for item in components.queryItems ?? [] { params[item.name] = item.value }

        if let description = params["error_description"] ?? params["error"] {
            let message = params["error_code"] == "otp_expired"
                ? "That link has expired. Request a new one and try again."
                : description.replacingOccurrences(of: "+", with: " ")
            throw SupabaseError(status: nil, code: params["error_code"], message: message)
        }
        guard let access = params["access_token"], let refresh = params["refresh_token"] else {
            throw SupabaseError(status: nil, code: nil, message: "That link didn't contain a login.")
        }
        let userData = try await send("auth/v1/user", token: access)
        var json: [String: Any] = ["access_token": access, "refresh_token": refresh, "user": try Self.object(userData)]
        json["expires_at"] = params["expires_at"].flatMap(Double.init)
        json["expires_in"] = params["expires_in"].flatMap(Double.init)
        return (try Self.session(from: json), params["type"])
    }

    // MARK: Cloud save

    func fetchSave(_ session: AuthSession) async throws -> CloudSave? {
        let data = try await send("rest/v1/user_data",
                                  query: [URLQueryItem(name: "select", value: "data"),
                                          URLQueryItem(name: "user_id", value: "eq.\(session.userID)")],
                                  token: session.accessToken)
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let payload = rows.first?["data"] as? [String: Any],
              let snapshot = payload["snapshot"] as? [String: Any] else { return nil }
        let savedAt = Self.number(payload["savedAt"]) ?? 0
        return CloudSave(savedAt: savedAt, snapshot: try JSONSerialization.data(withJSONObject: snapshot))
    }

    func upload(_ save: CloudSave, session: AuthSession) async throws {
        let snapshot = try JSONSerialization.jsonObject(with: save.snapshot)
        let body: [String: Any] = [
            "user_id": session.userID,
            "data": ["savedAt": save.savedAt, "snapshot": snapshot] as [String: Any],
            "updated_at": Self.timestamp(Date(timeIntervalSince1970: save.savedAt)),
        ]
        _ = try await send("rest/v1/user_data", method: "POST",
                           query: [URLQueryItem(name: "on_conflict", value: "user_id")],
                           body: body, token: session.accessToken,
                           headers: ["Prefer": "resolution=merge-duplicates,return=minimal"])
    }

    /// Deletes the user's account and cloud data (the `delete_user` function in setup.sql).
    func deleteAccount(_ session: AuthSession) async throws {
        _ = try await send("rest/v1/rpc/delete_user", method: "POST", body: [String: Any](), token: session.accessToken)
    }

    // MARK: Plumbing

    private func send(_ path: String, method: String = "GET", query: [URLQueryItem] = [],
                      body: Any? = nil, token: String? = nil, headers: [String: String] = [:]) async throws -> Data {
        var components = URLComponents(url: config.url.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue(config.key, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }

        let (data, response) = try await transport(request)
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseError(status: nil, code: nil, message: "No response from the server.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw SupabaseError.from(status: http.statusCode, data: data)
        }
        return data
    }

    private static func object(_ data: Data) throws -> [String: Any] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SupabaseError(status: nil, code: nil, message: "Unexpected response from the server.")
        }
        return json
    }

    private static func session(from json: [String: Any], fallback: AuthSession? = nil) throws -> AuthSession {
        guard let access = json["access_token"] as? String else {
            throw SupabaseError(status: nil, code: nil, message: "The server didn't return a login.")
        }
        let user = json["user"] as? [String: Any]
        let expiresAt: Date
        if let at = number(json["expires_at"]) {
            expiresAt = Date(timeIntervalSince1970: at)
        } else {
            expiresAt = Date().addingTimeInterval(number(json["expires_in"]) ?? 3600)
        }
        guard let userID = user?["id"] as? String ?? fallback?.userID else {
            throw SupabaseError(status: nil, code: nil, message: "The server didn't return a user.")
        }
        return AuthSession(accessToken: access,
                           refreshToken: json["refresh_token"] as? String ?? fallback?.refreshToken ?? "",
                           expiresAt: expiresAt,
                           userID: userID,
                           email: user?["email"] as? String ?? fallback?.email ?? "")
    }

    private static func number(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        return (value as? NSNumber)?.doubleValue
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
