import Foundation

/// Gemini models the app can use.
enum AIModel: String, CaseIterable, Identifiable, Codable {
    case flash = "gemini-3.8-flash"
    case flash35 = "gemini-3.5-flash"
    case flashLite = "gemini-3.5-flash-lite"
    case flashLite31 = "gemini-3.1-flash-lite"
    case pro = "gemini-3.1-pro-preview"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .flash: return "Gemini 3.8 Flash"
        case .flash35: return "Gemini 3.5 Flash"
        case .flashLite: return "Gemini 3.5 Flash-Lite"
        case .flashLite31: return "Gemini 3.1 Flash-Lite"
        case .pro: return "Gemini 3.1 Pro (preview)"
        }
    }

    var blurb: String {
        switch self {
        case .flash: return "Smartest free model — recommended"
        case .flash35: return "Fast and dependable · free tier"
        case .flashLite: return "Quickest replies · free tier"
        case .flashLite31: return "Lightweight backup · free tier"
        case .pro: return "Deepest reasoning · paid tier only"
        }
    }

    /// Free-tier models, best first. When the chosen model is busy, over its limit or
    /// unavailable, requests move down this list.
    static let fallbackOrder: [AIModel] = [.flash, .flash35, .flashLite, .flashLite31]
}

/// An error returned by the Gemini API for one model.
struct GeminiAPIError: LocalizedError {
    var status: Int?
    var code: String?
    var message: String
    var model: AIModel?

    var isKeyProblem: Bool {
        if code?.hasPrefix("API_KEY") == true { return true }
        guard let status, [400, 401, 403].contains(status) else { return false }
        let lower = message.lowercased()
        return lower.contains("api key") || lower.contains("api_key")
    }

    var isRegionProblem: Bool {
        message.lowercased().contains("location is not supported")
    }

    /// Busy, overloaded or rate limited: the same request may work a little later.
    var isTransient: Bool {
        guard let status else { return false }
        return [429, 500, 503, 504].contains(status)
    }

    /// Worth sending the same request to a different model.
    var triesAnotherModel: Bool {
        guard !isKeyProblem, !isRegionProblem, let status else { return false }
        return [400, 403, 404, 429, 500, 503, 504].contains(status)
    }

    var summary: String {
        if isKeyProblem { return "Your Gemini API key was rejected. Check it in Profile → AI Coach." }
        if isRegionProblem { return "Google doesn't offer the Gemini API in your region yet." }
        switch status {
        case 401, 403: return "This API key can't use this Gemini model."
        case 404: return "This Gemini model isn't available for your key."
        case 429: return "You've hit Gemini's free-tier limit for now. Wait a minute and try again."
        case 500, 503, 504: return "Gemini is overloaded right now. Please try again in a minute."
        default: return "Gemini couldn't answer that request."
        }
    }

    /// A short label for the connection check.
    var shortLabel: String {
        if isKeyProblem { return "Key rejected" }
        if isRegionProblem { return "Not in your region" }
        switch status {
        case 401, 403: return "No access"
        case 404: return "Not available"
        case 429: return "Free limit reached"
        case 500, 503, 504: return "Busy"
        case let status?: return "Error \(status)"
        case nil: return "Error"
        }
    }

    /// Google's own explanation, shortened, for troubleshooting.
    var detail: String {
        var text = message.split(whereSeparator: \.isNewline).first.map(String.init) ?? message
        if text.count > 120, let end = text.range(of: ". ") {
            text = String(text[..<end.lowerBound]) + "."
        }
        if text.count > 160 { text = String(text.prefix(157)) + "…" }
        return [status.map(String.init), text].compactMap { $0 }.joined(separator: " · ")
    }

    var errorDescription: String? {
        "\(summary)\n\nGoogle: \(detail)"
    }

    static func from(status: Int, body: Data) -> GeminiAPIError {
        let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
        if let error = json?["error"] as? [String: Any] {
            return from(errorObject: error, status: status)
        }
        let text = String(decoding: body.prefix(300), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return GeminiAPIError(status: status, code: nil,
                              message: text.isEmpty ? HTTPURLResponse.localizedString(forStatusCode: status) : text)
    }

    static func from(errorObject error: [String: Any], status: Int?) -> GeminiAPIError {
        let details = error["details"] as? [[String: Any]]
        let reason = details?.compactMap { $0["reason"] as? String }.first
        let resolvedStatus = status ?? error["code"] as? Int
        let message = error["message"] as? String ?? "Request failed\(resolvedStatus.map { " (HTTP \($0))" } ?? "")."
        return GeminiAPIError(status: resolvedStatus,
                              code: reason ?? error["status"] as? String,
                              message: message)
    }
}

/// Every model the app tried failed.
struct GeminiUnavailableError: LocalizedError {
    var failures: [GeminiAPIError]

    var errorDescription: String? {
        let busy = failures.filter(\.isTransient)
        let headline: String
        if !busy.isEmpty, failures.allSatisfy({ $0.isTransient || [403, 404].contains($0.status ?? 0) }) {
            headline = busy.allSatisfy({ $0.status == 429 })
                ? "You've used up Gemini's free-tier limit for now. Free keys allow a set number of requests per minute and per day, so wait a minute and try again."
                : "Google's Gemini models are overloaded right now. Please try again in a minute."
        } else {
            headline = "None of the Gemini models could answer."
        }
        let details = failures.map(\.detail)
        if Set(details).count == 1, let only = details.first {
            return "\(headline)\n\nGoogle: \(only)"
        }
        let lines = failures.map { "• \($0.model?.displayName ?? "Gemini"): \($0.detail)" }
        return headline + "\n\n" + lines.joined(separator: "\n")
    }
}

enum AIStreamEvent {
    case thinking
    case textDelta(String)
    case toolStarted(name: String)
}

struct FunctionCall {
    let id: String?
    let name: String
    let args: [String: Any]
}

struct GeminiResponse {
    /// Every part of the model's reply, kept verbatim (including thought signatures).
    var parts: [[String: Any]]
    var finishReason: String?
    var blockReason: String?

    /// The visible answer (thought summaries excluded).
    var text: String {
        parts.filter { $0["thought"] as? Bool != true }
            .compactMap { $0["text"] as? String }
            .joined()
    }

    var functionCalls: [FunctionCall] {
        parts.compactMap { part in
            guard let call = part["functionCall"] as? [String: Any],
                  let name = call["name"] as? String else { return nil }
            return FunctionCall(id: call["id"] as? String, name: name,
                                args: call["args"] as? [String: Any] ?? [:])
        }
    }

    /// Parts to replay as the model turn. Gemini 3 requires thought signatures to be
    /// sent back unchanged, so only empty text parts without one are dropped.
    var historyParts: [[String: Any]] {
        parts.filter { part in
            let hasSignature = part["thoughtSignature"] != nil
            if part["thought"] as? Bool == true, !hasSignature { return false }
            if let text = part["text"] as? String, text.isEmpty, !hasSignature, part["functionCall"] == nil {
                return false
            }
            return true
        }
    }

    var wasBlocked: Bool {
        if blockReason != nil { return true }
        guard let finishReason else { return false }
        return ["SAFETY", "PROHIBITED_CONTENT", "BLOCKLIST", "SPII", "RECITATION"].contains(finishReason)
    }
}

/// Minimal Gemini API client (generateContent streaming over server-sent events).
///
/// The first request tries the chosen model and, if it is busy, over its free-tier
/// limit or unavailable, the other free models in turn. Once a model answers, later
/// requests from the same client stay on it, so function-call thought signatures
/// always go back to the model that made them.
@MainActor
final class GeminiClient {
    let apiKey: String
    let preferredModel: AIModel
    let allowsFallback: Bool
    /// The model that answered.
    private(set) var model: AIModel?

    /// Models that failed recently are tried last until this time.
    private static var cooldowns: [AIModel: Date] = [:]

    init(apiKey: String, model: AIModel, allowsFallback: Bool = true) {
        self.apiKey = apiKey
        self.preferredModel = model
        self.allowsFallback = allowsFallback
    }

    private var candidates: [AIModel] {
        var models = [preferredModel]
        if allowsFallback {
            models += AIModel.fallbackOrder.filter { $0 != preferredModel }
        }
        let now = Date()
        let cooling = { (model: AIModel) in (Self.cooldowns[model] ?? .distantPast) > now }
        return models.filter { !cooling($0) } + models.filter(cooling)
    }

    /// Streams a generateContent request. `body` is the JSON request body
    /// (`contents`, `systemInstruction`, `tools`, `generationConfig`, …).
    func stream(_ body: [String: Any], onEvent: (AIStreamEvent) -> Void) async throws -> GeminiResponse {
        let payload = try JSONSerialization.data(withJSONObject: body)
        if let model {
            return try await streamWithRetries(model: model, payload: payload, onEvent: onEvent)
        }

        var failures: [GeminiAPIError] = []
        for candidate in candidates {
            try Task.checkCancellation()
            var emitted = false
            do {
                let response = try await performStream(model: candidate, payload: payload) { event in
                    emitted = true
                    onEvent(event)
                }
                Self.cooldowns[candidate] = nil
                model = candidate
                return response
            } catch var error as GeminiAPIError {
                error.model = candidate
                // Once part of a reply is on screen, switching models would duplicate it.
                guard error.triesAnotherModel, !emitted else { throw error }
                if error.isTransient || [403, 404].contains(error.status ?? 0) {
                    Self.cooldowns[candidate] = Date().addingTimeInterval(error.isTransient ? 90 : 3600)
                }
                failures.append(error)
            }
        }
        if failures.count == 1 { throw failures[0] }
        throw GeminiUnavailableError(failures: failures)
    }

    /// Follow-up requests stay on the model that answered and retry briefly if it's busy.
    private func streamWithRetries(model: AIModel, payload: Data,
                                   onEvent: (AIStreamEvent) -> Void) async throws -> GeminiResponse {
        var attempt = 0
        while true {
            var emitted = false
            do {
                return try await performStream(model: model, payload: payload) { event in
                    emitted = true
                    onEvent(event)
                }
            } catch var error as GeminiAPIError {
                error.model = model
                guard error.isTransient, !emitted, attempt < 2 else { throw error }
                attempt += 1
                try await Task.sleep(nanoseconds: UInt64(attempt * attempt) * 1_500_000_000)
            }
        }
    }

    private func performStream(model: AIModel, payload: Data,
                               onEvent: (AIStreamEvent) -> Void) async throws -> GeminiResponse {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model.rawValue):streamGenerateContent?alt=sse")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = payload

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GeminiAPIError(status: nil, code: nil, message: "No response from the server.")
        }
        guard (200..<300).contains(http.statusCode) else {
            var data = Data()
            for try await byte in bytes { data.append(byte) }
            throw GeminiAPIError.from(status: http.statusCode, body: data)
        }

        var parts: [[String: Any]] = []
        var finishReason: String?
        var blockReason: String?

        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard let data = payload.data(using: .utf8),
                  let chunk = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { continue }

            if let error = chunk["error"] as? [String: Any] {
                throw GeminiAPIError.from(errorObject: error, status: nil)
            }
            if let feedback = chunk["promptFeedback"] as? [String: Any],
               let reason = feedback["blockReason"] as? String {
                blockReason = reason
            }
            guard let candidate = (chunk["candidates"] as? [[String: Any]])?.first else { continue }
            if let reason = candidate["finishReason"] as? String {
                finishReason = reason
            }
            guard let content = candidate["content"] as? [String: Any],
                  let newParts = content["parts"] as? [[String: Any]] else { continue }
            for part in newParts {
                parts.append(part)
                if part["thought"] as? Bool == true {
                    onEvent(.thinking)
                } else if let text = part["text"] as? String, !text.isEmpty {
                    onEvent(.textDelta(text))
                } else if let call = part["functionCall"] as? [String: Any] {
                    onEvent(.toolStarted(name: call["name"] as? String ?? ""))
                }
            }
        }

        return GeminiResponse(parts: parts, finishReason: finishReason, blockReason: blockReason)
    }

    /// Sends a tiny request to check that a model answers with this key.
    static func check(model: AIModel, apiKey: String) async -> Result<TimeInterval, GeminiAPIError> {
        let client = GeminiClient(apiKey: apiKey, model: model, allowsFallback: false)
        let body: [String: Any] = [
            "contents": [["role": "user", "parts": [["text": "Reply with the single word OK."]]] as [String: Any]],
            "generationConfig": [
                "thinkingConfig": ["thinkingLevel": "low"] as [String: Any],
                "maxOutputTokens": 1024,
            ] as [String: Any],
        ]
        let start = Date()
        do {
            _ = try await client.stream(body) { _ in }
            return .success(Date().timeIntervalSince(start))
        } catch let error as GeminiAPIError {
            return .failure(error)
        } catch {
            return .failure(GeminiAPIError(status: nil, code: nil, message: error.localizedDescription, model: model))
        }
    }
}
