import Foundation

enum ChatRole: String, Codable {
    case user
    case assistant
}

enum ProposalStatus: String, Codable {
    case pending
    case applied
    case dismissed
}

struct PlanProposal: Codable, Hashable {
    var plan: WorkoutPlan
    var changeSummary: String
    var status: ProposalStatus = .pending
}

/// A message as shown in the coach chat UI.
struct ChatMessage: Identifiable, Codable, Hashable {
    var id = UUID()
    var role: ChatRole
    var text: String
    var date = Date()
    var proposal: PlanProposal?
    var isError = false
}

/// One raw turn of the Gemini conversation (`role` is "user" or "model"). The parts
/// are kept verbatim (thought signatures, function calls, ...) so they can be replayed exactly.
struct APITurn: Codable, Hashable {
    var role: String
    var contentJSON: Data

    init(role: String, content: [[String: Any]]) {
        self.role = role
        self.contentJSON = (try? JSONSerialization.data(withJSONObject: content)) ?? Data("[]".utf8)
    }

    var content: [[String: Any]] {
        (try? JSONSerialization.jsonObject(with: contentJSON)) as? [[String: Any]] ?? []
    }

    var asGeminiContent: [String: Any] {
        ["role": role, "parts": content]
    }
}
