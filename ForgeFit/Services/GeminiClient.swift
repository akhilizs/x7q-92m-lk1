import Foundation

/// Gemini models the app can use.
enum AIModel: String, CaseIterable, Identifiable, Codable {
    case flash = "gemini-3.8-flash"
    case flashLite = "gemini-3.5-flash-lite"
    case pro = "gemini-3.1-pro-preview"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .flash: return "Gemini 3.8 Flash"
        case .flashLite: return "Gemini 3.5 Flash-Lite"
        case .pro: return "Gemini 3.1 Pro (preview)"
        }
    }

    var blurb: String {
        switch self {
        case .flash: return "Smart and fast — recommended"
        case .flashLite: return "Quickest replies, lowest cost"
        case .pro: return "Deepest reasoning, slower"
        }
    }
}

struct GeminiAPIError: LocalizedError {
    var status: Int?
    var code: String?
    var message: String

    var errorDescription: String? {
        let lower = message.lowercased()
        if lower.contains("api key") || code == "API_KEY_INVALID" {
            return "Your Gemini API key was rejected. Check it in Profile → AI Coach."
        }
        switch status {
        case 401, 403: return "This API key can't use the Gemini API. Check it in Profile → AI Coach."
        case 404: return "The selected Gemini model isn't available for your key. Pick another model in Profile → AI Coach."
        case 429: return "You've hit Gemini's rate limit or quota. Wait a moment and try again."
        case 500, 503: return "Gemini is busy right now. Please try again shortly."
        default: return message
        }
    }

    var isRetryable: Bool {
        guard let status else { return false }
        return status == 429 || status == 500 || status == 503
    }

    static func from(status: Int, body: Data) -> GeminiAPIError {
        let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
        return from(errorObject: json?["error"] as? [String: Any], status: status)
    }

    static func from(errorObject error: [String: Any]?, status: Int?) -> GeminiAPIError {
        let details = error?["details"] as? [[String: Any]]
        let reason = details?.compactMap { $0["reason"] as? String }.first
        let message = error?["message"] as? String ?? "Request failed\(status.map { " (HTTP \($0))" } ?? "")."
        return GeminiAPIError(status: status ?? error?["code"] as? Int,
                              code: reason ?? error?["status"] as? String,
                              message: message)
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
@MainActor
final class GeminiClient {
    let apiKey: String
    let model: AIModel

    init(apiKey: String, model: AIModel) {
        self.apiKey = apiKey
        self.model = model
    }

    private var endpoint: URL {
        URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model.rawValue):streamGenerateContent?alt=sse")!
    }

    /// Streams a generateContent request. `body` is the JSON request body
    /// (`contents`, `systemInstruction`, `tools`, `generationConfig`, …).
    func stream(_ body: [String: Any], onEvent: (AIStreamEvent) -> Void) async throws -> GeminiResponse {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        var attempt = 0
        while true {
            do {
                return try await performStream(request, onEvent: onEvent)
            } catch let error as GeminiAPIError where error.isRetryable && attempt < 2 {
                attempt += 1
                try await Task.sleep(nanoseconds: UInt64(attempt * attempt) * 1_500_000_000)
            }
        }
    }

    private func performStream(_ request: URLRequest, onEvent: (AIStreamEvent) -> Void) async throws -> GeminiResponse {
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
                // Errors mid-stream aren't retried: part of the reply may already be on screen.
                var apiError = GeminiAPIError.from(errorObject: error, status: nil)
                apiError.status = nil
                throw apiError
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
}
