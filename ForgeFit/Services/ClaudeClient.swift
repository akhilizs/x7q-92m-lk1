import Foundation

enum ClaudeModel: String, CaseIterable, Identifiable, Codable {
    case opus5 = "claude-opus-5"
    case sonnet5 = "claude-sonnet-5"
    case haiku45 = "claude-haiku-4-5"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .opus5: return "Claude Opus 5"
        case .sonnet5: return "Claude Sonnet 5"
        case .haiku45: return "Claude Haiku 4.5"
        }
    }

    var blurb: String {
        switch self {
        case .opus5: return "Smartest coaching and plan design (default)"
        case .sonnet5: return "Fast and capable at a lower cost"
        case .haiku45: return "Quickest replies, lowest cost"
        }
    }

    /// `output_config.effort` is not accepted by Haiku 4.5.
    var supportsEffort: Bool { self != .haiku45 }

    /// Server-side refusal fallbacks (`fallbacks: "default"`).
    var supportsServerFallback: Bool { self == .opus5 }

    /// Streaming requests can use a generous output cap on every supported model.
    var maxOutputTokens: Int { 64000 }
}

struct ClaudeAPIError: LocalizedError {
    var status: Int?
    var type: String?
    var message: String

    var errorDescription: String? {
        switch status {
        case 401: return "Your Anthropic API key was rejected. Check it in Profile → AI Coach."
        case 403: return "This API key doesn't have permission to use this model."
        case 404: return "The selected model isn't available for this API key. Try another model in Profile → AI Coach."
        case 429: return "Rate limit reached — give it a moment and try again."
        case 529: return "Claude is overloaded right now. Please try again shortly."
        default: return message
        }
    }

    var isRetryable: Bool {
        guard let status else { return false }
        return status == 408 || status == 429 || status >= 500
    }

    static func from(status: Int, body: Data) -> ClaudeAPIError {
        let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
        let error = json?["error"] as? [String: Any]
        let message = error?["message"] as? String ?? "Request failed (HTTP \(status))."
        return ClaudeAPIError(status: status, type: error?["type"] as? String, message: message)
    }
}

struct ToolUse {
    let id: String
    let name: String
    /// nil when the streamed input was not valid JSON.
    let input: [String: Any]?
    let rawInput: String
}

enum ClaudeStreamEvent {
    case thinking
    case textDelta(String)
    case toolStarted(name: String)
    case toolInputDelta(totalCharacters: Int, fragment: String)
}

struct ClaudeResponse {
    var content: [[String: Any]]
    var stopReason: String?
    var model: String?
    var rawToolInputs: [String: String]

    var text: String {
        content.filter { $0["type"] as? String == "text" }
            .compactMap { $0["text"] as? String }
            .joined()
    }

    var toolUses: [ToolUse] {
        content.compactMap { block in
            guard block["type"] as? String == "tool_use",
                  let id = block["id"] as? String,
                  let name = block["name"] as? String else { return nil }
            let raw = rawToolInputs[id] ?? ""
            let valid = raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || (try? JSONSerialization.jsonObject(with: Data(raw.utf8))) is [String: Any]
            return ToolUse(id: id, name: name, input: valid ? (block["input"] as? [String: Any]) : nil, rawInput: raw)
        }
    }

    /// Content safe to send back as the assistant turn in the next request.
    var historyContent: [[String: Any]] {
        var blocks = content
        // After a mid-output fallback, blocks produced before the last fallback marker
        // (other than text) must not be echoed back.
        if let lastFallback = blocks.lastIndex(where: { $0["type"] as? String == "fallback" }) {
            let dropTypes: Set<String> = ["thinking", "redacted_thinking", "tool_use", "server_tool_use"]
            blocks = blocks.enumerated().compactMap { index, block in
                let type = block["type"] as? String ?? ""
                return index < lastFallback && dropTypes.contains(type) ? nil : block
            }
        }
        return blocks.filter { block in
            let type = block["type"] as? String ?? ""
            if type == "fallback" { return false }
            if type == "text" { return !((block["text"] as? String) ?? "").isEmpty }
            return true
        }
    }
}

/// Minimal Claude Messages API client using URLSession + server-sent events.
@MainActor
final class ClaudeClient {
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    let apiKey: String
    let model: ClaudeModel

    init(apiKey: String, model: ClaudeModel) {
        self.apiKey = apiKey
        self.model = model
    }

    /// Sends a streaming Messages request. `params` holds everything except
    /// `model`/`stream`, which are filled in here.
    func stream(_ params: [String: Any], onEvent: (ClaudeStreamEvent) -> Void) async throws -> ClaudeResponse {
        var body = params
        body["model"] = model.rawValue
        body["stream"] = true

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        if model.supportsServerFallback {
            // If Claude declines a request, retry it server-side on Anthropic's
            // recommended fallback model instead of returning a refusal.
            body["fallbacks"] = "default"
            request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        var attempt = 0
        while true {
            do {
                return try await performStream(request, onEvent: onEvent)
            } catch let error as ClaudeAPIError where error.isRetryable && attempt < 2 {
                attempt += 1
                try await Task.sleep(nanoseconds: UInt64(attempt * attempt) * 1_500_000_000)
            }
        }
    }

    private func performStream(_ request: URLRequest, onEvent: (ClaudeStreamEvent) -> Void) async throws -> ClaudeResponse {
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ClaudeAPIError(status: nil, type: nil, message: "No response from the server.")
        }
        guard (200..<300).contains(http.statusCode) else {
            var data = Data()
            for try await byte in bytes { data.append(byte) }
            throw ClaudeAPIError.from(status: http.statusCode, body: data)
        }

        var blocks: [Int: [String: Any]] = [:]
        var toolJSON: [Int: String] = [:]
        var rawToolInputs: [String: String] = [:]
        var stopReason: String?
        var modelName: String?

        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard let data = payload.data(using: .utf8),
                  let event = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let type = event["type"] as? String else { continue }

            switch type {
            case "message_start":
                if let message = event["message"] as? [String: Any] {
                    modelName = message["model"] as? String
                }

            case "content_block_start":
                guard let index = event["index"] as? Int,
                      let block = event["content_block"] as? [String: Any] else { continue }
                blocks[index] = block
                switch block["type"] as? String {
                case "tool_use":
                    toolJSON[index] = ""
                    onEvent(.toolStarted(name: block["name"] as? String ?? ""))
                case "thinking", "redacted_thinking":
                    onEvent(.thinking)
                default:
                    break
                }

            case "content_block_delta":
                guard let index = event["index"] as? Int,
                      let delta = event["delta"] as? [String: Any],
                      var block = blocks[index] else { continue }
                switch delta["type"] as? String {
                case "text_delta":
                    let text = delta["text"] as? String ?? ""
                    block["text"] = (block["text"] as? String ?? "") + text
                    onEvent(.textDelta(text))
                case "thinking_delta":
                    block["thinking"] = (block["thinking"] as? String ?? "") + (delta["thinking"] as? String ?? "")
                    onEvent(.thinking)
                case "signature_delta":
                    block["signature"] = delta["signature"] as? String ?? ""
                case "input_json_delta":
                    let fragment = delta["partial_json"] as? String ?? ""
                    let total = (toolJSON[index] ?? "") + fragment
                    toolJSON[index] = total
                    onEvent(.toolInputDelta(totalCharacters: total.count, fragment: fragment))
                default:
                    break
                }
                blocks[index] = block

            case "content_block_stop":
                guard let index = event["index"] as? Int, var block = blocks[index],
                      let raw = toolJSON[index] else { continue }
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if let id = block["id"] as? String { rawToolInputs[id] = trimmed }
                if trimmed.isEmpty {
                    block["input"] = [String: Any]()
                } else if let object = (try? JSONSerialization.jsonObject(with: Data(trimmed.utf8))) as? [String: Any] {
                    block["input"] = object
                } else {
                    // Keep the turn replayable; the caller reports the bad input back to Claude.
                    block["input"] = [String: Any]()
                }
                blocks[index] = block

            case "message_delta":
                if let delta = event["delta"] as? [String: Any], let reason = delta["stop_reason"] as? String {
                    stopReason = reason
                }

            case "error":
                // Mid-stream errors are not retried automatically: part of the reply
                // may already be on screen.
                let error = event["error"] as? [String: Any]
                let errorType = error?["type"] as? String
                let message = errorType == "overloaded_error"
                    ? "Claude is overloaded right now. Please try again shortly."
                    : (error?["message"] as? String ?? "The stream ended with an error.")
                throw ClaudeAPIError(status: nil, type: errorType, message: message)

            default:
                break
            }
        }

        let ordered = blocks.keys.sorted().compactMap { blocks[$0] }
        return ClaudeResponse(content: ordered, stopReason: stopReason, model: modelName, rawToolInputs: rawToolInputs)
    }
}
