import Foundation

enum AIError: LocalizedError {
    case missingAPIKey
    case refused
    case truncated
    case invalidPlan(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Add your Gemini API key in Profile → AI Coach to use AI features."
        case .refused: return "The coach couldn't help with that request. Try rephrasing it."
        case .truncated: return "The response was cut off before it finished. Please try again."
        case .invalidPlan(let reason): return "The AI returned a plan the app couldn't use (\(reason)). Please try again."
        }
    }
}

/// JSON schemas and parsing for AI-designed workout plans.
enum PlanSchema {
    /// `ids` restricts exercise_id to an enum and closes every object (strict structured
    /// output). Without it the schema stays simple and the app validates IDs itself.
    static func exerciseItem(ids: [String]?) -> [String: Any] {
        var exerciseID: [String: Any] = ["type": "string",
                                         "description": "exercise_id of an exercise from the EXERCISE CATALOG."]
        if let ids { exerciseID["enum"] = ids }
        let properties: [String: Any] = [
            "exercise_id": exerciseID,
            "sets": ["type": "integer", "description": "Number of working sets (1-6)."] as [String: Any],
            "reps_min": ["type": "integer",
                         "description": "Low end of the rep range, or seconds for time-tracked exercises."] as [String: Any],
            "reps_max": ["type": "integer",
                         "description": "High end of the rep range, or seconds for time-tracked exercises."] as [String: Any],
            "rest_seconds": ["type": "integer", "description": "Rest after each set, in seconds."] as [String: Any],
            "notes": ["type": "string",
                      "description": "Short cue or intensity target (e.g. 'RPE 8', '3 s lowering'). Empty string if none."] as [String: Any],
        ]
        return closed([
            "type": "object",
            "properties": properties,
            "required": ["exercise_id", "sets", "reps_min", "reps_max", "rest_seconds", "notes"],
        ], if: ids != nil)
    }

    static func plan(ids: [String]?, includeChangeSummary: Bool) -> [String: Any] {
        let day: [String: Any] = closed([
            "type": "object",
            "properties": [
                "name": ["type": "string", "description": "Short day name, e.g. 'Push' or 'Lower Power'."] as [String: Any],
                "focus": ["type": "string", "description": "Main muscles trained, e.g. 'Chest · Shoulders · Triceps'."] as [String: Any],
                "exercises": ["type": "array", "items": exerciseItem(ids: ids)] as [String: Any],
            ] as [String: Any],
            "required": ["name", "focus", "exercises"],
        ], if: ids != nil)
        var properties: [String: Any] = [
            "name": ["type": "string", "description": "Short, motivating plan name (max 4 words)."] as [String: Any],
            "summary": ["type": "string",
                        "description": "2-3 sentences: who it's for, how it's structured and how to progress."] as [String: Any],
            "days": ["type": "array", "items": day] as [String: Any],
        ]
        var required = ["name", "summary", "days"]
        if includeChangeSummary {
            properties["change_summary"] = [
                "type": "string",
                "description": "One or two sentences describing what changed compared with the current plan and why.",
            ] as [String: Any]
            required.append("change_summary")
        }
        return closed([
            "type": "object",
            "properties": properties,
            "required": required,
        ], if: ids != nil)
    }

    private static func closed(_ object: [String: Any], if strict: Bool) -> [String: Any] {
        var object = object
        if strict { object["additionalProperties"] = false }
        return object
    }

    private struct Payload: Decodable {
        struct Item: Decodable {
            let exerciseID: String
            let sets: Int
            let repsMin: Int
            let repsMax: Int
            let restSeconds: Int
            let notes: String?

            enum CodingKeys: String, CodingKey {
                case exerciseID = "exercise_id"
                case sets
                case repsMin = "reps_min"
                case repsMax = "reps_max"
                case restSeconds = "rest_seconds"
                case notes
            }
        }

        struct Day: Decodable {
            let name: String
            let focus: String?
            let exercises: [Item]
        }

        let name: String
        let summary: String?
        let days: [Day]
        let changeSummary: String?

        enum CodingKeys: String, CodingKey {
            case name, summary, days
            case changeSummary = "change_summary"
        }
    }

    /// Validates and converts AI output into a `WorkoutPlan`.
    static func parse(_ data: Data, goal: FitnessGoal) throws -> (plan: WorkoutPlan, changeSummary: String) {
        let payload: Payload
        do {
            payload = try JSONDecoder().decode(Payload.self, from: data)
        } catch {
            throw AIError.invalidPlan("malformed JSON")
        }

        let days: [WorkoutDay] = payload.days.compactMap { day in
            let items: [PlannedExercise] = day.exercises.compactMap { item in
                guard ExerciseLibrary.exercise(item.exerciseID) != nil else { return nil }
                let low = max(1, min(item.repsMin, item.repsMax))
                let high = max(low, max(item.repsMin, item.repsMax))
                return PlannedExercise(exerciseID: item.exerciseID,
                                       sets: min(max(item.sets, 1), 10),
                                       repsLow: low,
                                       repsHigh: high,
                                       restSeconds: min(max(item.restSeconds, 0), 600),
                                       notes: item.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
            }
            guard !items.isEmpty else { return nil }
            let focus = day.focus?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return WorkoutDay(name: day.name, focus: focus, exercises: items)
        }
        guard !days.isEmpty else { throw AIError.invalidPlan("no usable training days") }

        let plan = WorkoutPlan(name: payload.name.isEmpty ? "AI Plan" : payload.name,
                               summary: payload.summary ?? "",
                               goal: goal,
                               source: .ai,
                               days: days)
        return (plan, payload.changeSummary ?? "")
    }

    static func parse(toolInput: [String: Any], goal: FitnessGoal) throws -> (plan: WorkoutPlan, changeSummary: String) {
        let data = try JSONSerialization.data(withJSONObject: toolInput)
        return try parse(data, goal: goal)
    }
}

/// Designs complete workout plans with Gemini.
@MainActor
enum AIPlanDesigner {
    static let systemPrompt = """
    You are the AI coach inside ForgeFit, an experienced strength & conditioning coach who designs safe, \
    effective, evidence-based training programs for gym-goers of every level.

    Design a complete weekly training plan for the athlete described by the user. Principles:
    - Build exactly the requested number of training days. Each day must fit the session length: \
    budget roughly 2–3 minutes per working set including rest, plus about 5 minutes of warm-up.
    - Only use exercises from the provided catalog (already filtered to the athlete's equipment) and \
    reference them by exercise_id.
    - Order each day from big compound lifts to smaller isolation work, and spread weekly volume sensibly \
    across muscle groups (about 10–20 hard sets per major muscle per week for muscle gain; less for beginners).
    - Match sets, rep ranges and rest periods to the goal and experience level. For exercises tracked in \
    seconds, reps_min and reps_max are seconds (for example a 30–45 s plank or 600–900 s of cardio).
    - Respect every injury, limitation and preference. Avoid loading painful areas and choose joint-friendly \
    alternatives instead.
    - Give priority to any focus muscle groups the athlete asks for.
    - Give each day a short name and a focus line listing its main muscles. Use the notes field for a brief \
    cue or intensity target when it helps, otherwise an empty string.
    """

    struct Request {
        var goal: FitnessGoal
        var level: ExperienceLevel
        var daysPerWeek: Int
        var sessionMinutes: Int
        var equipment: Set<Equipment>
        var focus: Set<MuscleGroup>
        var notes: String
    }

    static func design(_ request: Request, profile: UserProfile, model: AIModel,
                       onProgress: (String) -> Void) async throws -> WorkoutPlan {
        guard let key = KeychainStore.apiKey else { throw AIError.missingAPIKey }
        let client = GeminiClient(apiKey: key, model: model)

        let catalog = ExerciseLibrary.available(with: request.equipment.union([.bodyweight]))
        let ids = catalog.map(\.id)

        var athlete = profile
        athlete.goal = request.goal
        athlete.level = request.level
        athlete.daysPerWeek = request.daysPerWeek
        athlete.sessionMinutes = request.sessionMinutes
        athlete.equipment = request.equipment

        var message = "ATHLETE\n\(athlete.promptSummary)"
        if !request.focus.isEmpty {
            let focus = MuscleGroup.allCases.filter { request.focus.contains($0) }.map(\.displayName)
            message += "\n\nFocus muscle groups: \(focus.joined(separator: ", "))"
        }
        let notes = request.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty {
            message += "\n\nExtra requests from the athlete: \(notes)"
        }
        message += "\n\nEXERCISE CATALOG (id | name | primary muscle | equipment | tracking | type)\n"
        message += ExerciseLibrary.promptCatalog(catalog)

        func body(strict: Bool) -> [String: Any] {
            let generationConfig: [String: Any] = [
                "responseMimeType": "application/json",
                "responseJsonSchema": PlanSchema.plan(ids: strict ? ids : nil, includeChangeSummary: false),
                "thinkingConfig": ["thinkingLevel": "medium"] as [String: Any],
                "maxOutputTokens": 32768,
            ]
            return [
                "systemInstruction": ["parts": [["text": systemPrompt]]] as [String: Any],
                "contents": [["role": "user", "parts": [["text": message]]] as [String: Any]],
                "generationConfig": generationConfig,
            ]
        }

        onProgress("Analyzing your goals…")
        var json = ""
        func handle(_ event: AIStreamEvent) {
            switch event {
            case .thinking:
                if json.isEmpty { onProgress("Thinking through your program…") }
            case .textDelta(let text):
                json += text
                let exercises = json.components(separatedBy: "\"exercise_id\"").count - 1
                let days = json.components(separatedBy: "\"focus\"").count - 1
                if exercises > 0 {
                    onProgress("Designing day \(max(days, 1)) · \(exercises) exercises placed")
                } else {
                    onProgress("Structuring your week…")
                }
            case .toolStarted:
                break
            }
        }

        let response: GeminiResponse
        do {
            response = try await client.stream(body(strict: true), onEvent: handle)
        } catch let error where rejectedSchema(error) {
            // Some models reject the strict exercise_id enum; the app validates IDs itself anyway.
            onProgress("Retrying with a simpler request…")
            json = ""
            response = try await client.stream(body(strict: false), onEvent: handle)
        }

        if response.wasBlocked { throw AIError.refused }
        if response.finishReason == "MAX_TOKENS" { throw AIError.truncated }
        onProgress("Finalizing…")
        return try PlanSchema.parse(Data(response.text.utf8), goal: request.goal).plan
    }

    /// A 400 or 500 usually means the request itself (the strict schema) was the problem.
    private static func rejectedSchema(_ error: Error) -> Bool {
        let failures: [GeminiAPIError]
        if let error = error as? GeminiAPIError {
            failures = [error]
        } else if let error = error as? GeminiUnavailableError {
            failures = error.failures
        } else {
            return false
        }
        return failures.contains { ($0.status == 400 || $0.status == 500) && !$0.isKeyProblem && !$0.isRegionProblem }
    }
}
