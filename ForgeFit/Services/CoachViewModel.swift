import Foundation
import Observation

/// Drives the AI coach chat: streams Claude's replies and turns
/// `update_workout_plan` tool calls into plan proposals the user can apply.
@Observable
@MainActor
final class CoachViewModel {
    var isResponding = false
    var liveText = ""
    var status: String?

    @ObservationIgnored private var task: Task<Void, Never>?

    static let suggestions: [String] = [
        "My knees hurt when I squat",
        "I only have 30 minutes today",
        "I'm not seeing progress anymore",
        "Make my plan harder",
        "I'm tired and unmotivated",
        "I want bigger arms",
    ]

    private static let staticInstructions = """
    You are Coach Forge, the AI personal trainer inside the ForgeFit app. You help athletes train \
    consistently, safely and effectively, and you can rewrite their workout plan.

    How to coach:
    - Be warm, direct and practical. This is a phone chat, so keep replies short (usually under 120 words), \
    use short paragraphs or a few bullet points, and avoid headings and tables.
    - When the athlete shares a struggle (pain or injury, fatigue, soreness, lack of time, missing equipment, \
    boredom, plateaus, low motivation, schedule changes), acknowledge it and give concrete, specific advice. \
    Ask a clarifying question only when you genuinely need the answer to help.
    - When changing their plan would genuinely help, or they ask for a change or a new plan, call the \
    update_workout_plan tool with the complete revised plan. Keep what works and change what doesn't. \
    The app shows the proposal as a card with an Apply button, so after the tool call just explain the \
    key changes in one or two sentences.
    - Use their logged workouts to spot trends such as skipped exercises, stalled weights, very high effort \
    ratings or missed sessions, and mention them when relevant.
    - Only program exercises from the catalog below, referenced by exercise_id, and only ones their \
    equipment allows unless they tell you their equipment has changed. For exercises tracked in seconds, \
    reps_min and reps_max are seconds.
    - Safety first: you are not a doctor. For sharp or worsening pain, numbness, chest pain, dizziness or a \
    suspected injury, tell them to stop that movement and get it checked by a medical professional. You \
    can still adapt the plan to train around the problem area.
    """

    func send(_ text: String, store: AppStore) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isResponding else { return }

        store.chatMessages.append(ChatMessage(role: .user, text: trimmed))

        guard let key = KeychainStore.apiKey else {
            store.chatMessages.append(ChatMessage(role: .assistant, text: AIError.missingAPIKey.localizedDescription, isError: true))
            return
        }

        let historyBefore = store.chatHistory
        var turns = Self.trimmed(historyBefore)
        turns.append(APITurn(role: "user", content: [["type": "text", "text": trimmed]]))

        isResponding = true
        liveText = ""
        status = "Thinking…"
        Haptics.tap()

        let client = ClaudeClient(apiKey: key, model: store.aiModel)
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.run(turns: turns, client: client, store: store)
                store.chatHistory = result.turns
                let reply = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
                store.chatMessages.append(ChatMessage(role: .assistant,
                                                      text: reply.isEmpty && result.proposal != nil ? "Here's your updated plan." : reply,
                                                      proposal: result.proposal))
                Haptics.success()
            } catch {
                store.chatHistory = historyBefore
                let cancelled = Task.isCancelled || error is CancellationError
                    || (error as? URLError)?.code == .cancelled
                if cancelled {
                    if !self.liveText.isEmpty {
                        store.chatMessages.append(ChatMessage(role: .assistant, text: self.liveText + " …"))
                    }
                } else {
                    store.chatMessages.append(ChatMessage(role: .assistant, text: error.localizedDescription, isError: true))
                    Haptics.warning()
                }
            }
            self.isResponding = false
            self.liveText = ""
            self.status = nil
            self.task = nil
        }
    }

    func stop() {
        task?.cancel()
    }

    /// Keeps the conversation bounded. Always starts at a plain user message so
    /// tool calls and their results stay paired.
    private static func trimmed(_ turns: [APITurn], maxTurns: Int = 40) -> [APITurn] {
        guard turns.count > maxTurns else { return turns }
        var start = turns.count - maxTurns
        while start < turns.count {
            let turn = turns[start]
            let isPlainUser = turn.role == "user"
                && !turn.content.contains { $0["type"] as? String == "tool_result" }
            if isPlainUser { break }
            start += 1
        }
        return Array(turns[start...])
    }

    // MARK: - Conversation loop

    private struct RunResult {
        var turns: [APITurn]
        var text: String
        var proposal: PlanProposal?
    }

    private func run(turns initialTurns: [APITurn], client: ClaudeClient, store: AppStore) async throws -> RunResult {
        var turns = initialTurns
        var text = ""
        var proposal: PlanProposal?

        let catalog = ExerciseLibrary.all
        let tool: [String: Any] = [
            "name": "update_workout_plan",
            "description": """
            Propose a revised version of the athlete's workout plan, or a brand-new plan if they don't have one. \
            Call this whenever the conversation shows their plan should change: pain or injury, too hard or too \
            easy, plateaus, less time per session, a different number of training days, new or missing equipment, \
            boredom, a new goal, or an explicit request to change the plan. Always send the COMPLETE plan with \
            every day and every exercise, not just the parts that changed.
            """,
            "eager_input_streaming": true,
            "input_schema": PlanSchema.plan(ids: catalog.map(\.id), includeChangeSummary: true),
        ]

        let staticSystem = Self.staticInstructions
            + "\n\nEXERCISE CATALOG (id | name | primary muscle | equipment | tracking | type)\n"
            + ExerciseLibrary.promptCatalog(catalog)
        let system: [[String: Any]] = [
            ["type": "text", "text": staticSystem, "cache_control": ["type": "ephemeral"]] as [String: Any],
            ["type": "text", "text": store.coachContext()] as [String: Any],
        ]

        for _ in 0..<4 {
            var params: [String: Any] = [
                "max_tokens": client.model.maxOutputTokens,
                "system": system,
                "tools": [tool],
                "messages": turns.map(\.asRequestMessage),
                "cache_control": ["type": "ephemeral"],
            ]
            if client.model.supportsEffort {
                params["output_config"] = ["effort": "medium"]
            }

            let response = try await client.stream(params) { event in
                self.handle(event)
            }

            if response.stopReason == "refusal" { throw AIError.refused }

            let replyText = response.text
            if !replyText.isEmpty {
                text += (text.isEmpty ? "" : "\n\n") + replyText
            }

            var assistantContent = response.historyContent
            if assistantContent.isEmpty {
                assistantContent = [["type": "text", "text": replyText.isEmpty ? "…" : replyText]]
            }
            turns.append(APITurn(role: "assistant", content: assistantContent))

            let toolUses = response.toolUses
            guard response.stopReason == "tool_use", !toolUses.isEmpty else {
                if response.stopReason == "max_tokens", text.isEmpty { throw AIError.truncated }
                return RunResult(turns: turns, text: text, proposal: proposal)
            }

            var results: [[String: Any]] = []
            for use in toolUses {
                results.append(toolResult(for: use, goal: store.activePlan?.goal ?? store.profile.goal, proposal: &proposal))
            }
            turns.append(APITurn(role: "user", content: results))
            if !liveText.isEmpty { liveText += "\n\n" }
            status = "Wrapping up…"
        }
        return RunResult(turns: turns, text: text, proposal: proposal)
    }

    private func toolResult(for use: ToolUse, goal: FitnessGoal, proposal: inout PlanProposal?) -> [String: Any] {
        guard use.name == "update_workout_plan" else {
            return ["type": "tool_result", "tool_use_id": use.id, "is_error": true,
                    "content": "Unknown tool \(use.name)."]
        }
        guard let input = use.input else {
            let wrapped = (try? JSONSerialization.data(withJSONObject: ["INVALID_JSON": use.rawInput]))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "{\"INVALID_JSON\": \"\"}"
            return ["type": "tool_result", "tool_use_id": use.id, "is_error": true, "content": wrapped]
        }
        do {
            let parsed = try PlanSchema.parse(toolInput: input, goal: goal)
            proposal = PlanProposal(plan: parsed.plan, changeSummary: parsed.changeSummary)
            return ["type": "tool_result", "tool_use_id": use.id,
                    "content": "The revised plan is now shown to the athlete as a card with an Apply button. Don't repeat the plan; briefly explain the key changes and why."]
        } catch {
            return ["type": "tool_result", "tool_use_id": use.id, "is_error": true,
                    "content": "The plan could not be used: \(error.localizedDescription). Check that every exercise_id comes from the catalog and try again."]
        }
    }

    private func handle(_ event: ClaudeStreamEvent) {
        switch event {
        case .thinking:
            if liveText.isEmpty { status = "Thinking…" }
        case .textDelta(let delta):
            liveText += delta
            status = nil
        case .toolStarted:
            status = "Rewriting your plan…"
            Haptics.tap()
        case .toolInputDelta(_, let fragment):
            if fragment.contains("exercise_id") {
                status = "Rewriting your plan…"
            }
        }
    }
}
