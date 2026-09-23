import Foundation
import Observation

/// Drives the AI coach chat: streams Gemini's replies and turns
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
        turns.append(APITurn(role: "user", content: [["text": trimmed]]))

        isResponding = true
        liveText = ""
        status = "Thinking…"
        Haptics.tap()

        let client = GeminiClient(apiKey: key, model: store.aiModel)
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
                && !turn.content.contains { $0["functionResponse"] != nil }
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

    private func run(turns initialTurns: [APITurn], client: GeminiClient, store: AppStore) async throws -> RunResult {
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
            "parametersJsonSchema": PlanSchema.plan(ids: catalog.map(\.id), includeChangeSummary: true),
        ]

        let staticSystem = Self.staticInstructions
            + "\n\nEXERCISE CATALOG (id | name | primary muscle | equipment | tracking | type)\n"
            + ExerciseLibrary.promptCatalog(catalog)
        let systemInstruction: [String: Any] = [
            "parts": [["text": staticSystem], ["text": store.coachContext()]],
        ]

        for _ in 0..<4 {
            let body: [String: Any] = [
                "systemInstruction": systemInstruction,
                "contents": turns.map(\.asGeminiContent),
                "tools": [["functionDeclarations": [tool]] as [String: Any]],
                "toolConfig": ["functionCallingConfig": ["mode": "AUTO"]] as [String: Any],
                "generationConfig": [
                    "thinkingConfig": ["thinkingLevel": "low"] as [String: Any],
                    "maxOutputTokens": 32768,
                ] as [String: Any],
            ]

            let response = try await client.stream(body) { event in
                self.handle(event)
            }

            if response.wasBlocked { throw AIError.refused }

            let replyText = response.text
            if !replyText.isEmpty {
                text += (text.isEmpty ? "" : "\n\n") + replyText
            }

            // The model turn is replayed verbatim so Gemini 3 thought signatures survive.
            var modelParts = response.historyParts
            if modelParts.isEmpty {
                modelParts = [["text": replyText.isEmpty ? "…" : replyText]]
            }
            turns.append(APITurn(role: "model", content: modelParts))

            let calls = response.functionCalls
            guard !calls.isEmpty else {
                if response.finishReason == "MALFORMED_FUNCTION_CALL", text.isEmpty {
                    throw AIError.invalidPlan("the coach sent an incomplete plan update")
                }
                if response.finishReason == "MAX_TOKENS", text.isEmpty { throw AIError.truncated }
                return RunResult(turns: turns, text: text, proposal: proposal)
            }

            let results = calls.map { functionResponse(for: $0, goal: store.activePlan?.goal ?? store.profile.goal,
                                                        proposal: &proposal) }
            turns.append(APITurn(role: "user", content: results))
            if !liveText.isEmpty { liveText += "\n\n" }
            status = "Wrapping up…"
        }
        return RunResult(turns: turns, text: text, proposal: proposal)
    }

    private func functionResponse(for call: FunctionCall, goal: FitnessGoal, proposal: inout PlanProposal?) -> [String: Any] {
        let result: [String: Any]
        if call.name != "update_workout_plan" {
            result = ["error": "Unknown function \(call.name)."]
        } else {
            do {
                let parsed = try PlanSchema.parse(toolInput: call.args, goal: goal)
                proposal = PlanProposal(plan: parsed.plan, changeSummary: parsed.changeSummary)
                result = ["result": "The revised plan is now shown to the athlete as a card with an Apply button. Don't repeat the plan; briefly explain the key changes and why."]
            } catch {
                result = ["error": "The plan could not be used: \(error.localizedDescription). Check that every exercise_id comes from the catalog and try again."]
            }
        }
        var response: [String: Any] = ["name": call.name, "response": result]
        if let id = call.id { response["id"] = id }
        return ["functionResponse": response]
    }

    private func handle(_ event: AIStreamEvent) {
        switch event {
        case .thinking:
            if liveText.isEmpty { status = "Thinking…" }
        case .textDelta(let delta):
            liveText += delta
            status = nil
        case .toolStarted:
            status = "Rewriting your plan…"
            Haptics.tap()
        }
    }
}
