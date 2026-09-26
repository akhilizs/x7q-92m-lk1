import Foundation

/// Estimates calories and macros from a meal photo and/or description with Gemini.
enum MealAnalyzer {
    struct Estimate: Decodable, Equatable {
        struct Item: Decodable, Equatable {
            let name: String
            let portion: String?
            let calories: Double
            let proteinG: Double

            enum CodingKeys: String, CodingKey {
                case name, portion, calories
                case proteinG = "protein_g"
            }
        }

        let name: String
        let items: [Item]
        let calories: Double
        let proteinG: Double
        let carbsG: Double
        let fatG: Double
        let confidence: String?
        let note: String?

        enum CodingKeys: String, CodingKey {
            case name, items, calories, confidence, note
            case proteinG = "protein_g"
            case carbsG = "carbs_g"
            case fatG = "fat_g"
        }

        var isFood: Bool { calories > 0 || !items.isEmpty }
    }

    static let instructions = """
    You are a sports nutritionist estimating the nutrition of a meal from a photo and/or a short description. \
    Identify each food, estimate a realistic portion from visual cues (plate size, utensils, packaging) or the \
    description, and estimate calories and macronutrients using standard food composition values. Include \
    cooking oils, sauces and drinks you can see or that are mentioned. Be realistic rather than conservative. \
    If the photo doesn't show food, return zero values, an empty items list and explain in the note. \
    Keep the name short (max 5 words). The note is one short sentence (e.g. what you assumed about portions).
    """

    static func schema(strict: Bool) -> [String: Any] {
        func number(_ description: String) -> [String: Any] { ["type": "number", "description": description] }
        var item: [String: Any] = [
            "type": "object",
            "properties": [
                "name": ["type": "string"] as [String: Any],
                "portion": ["type": "string", "description": "e.g. '1 cup', '~150 g'"] as [String: Any],
                "calories": number("kcal"),
                "protein_g": number("grams of protein"),
            ] as [String: Any],
            "required": ["name", "portion", "calories", "protein_g"],
        ]
        var root: [String: Any] = [
            "type": "object",
            "properties": [
                "name": ["type": "string", "description": "Short meal name"] as [String: Any],
                "items": ["type": "array", "items": item] as [String: Any],
                "calories": number("total kcal"),
                "protein_g": number("total grams of protein"),
                "carbs_g": number("total grams of carbohydrate"),
                "fat_g": number("total grams of fat"),
                "confidence": ["type": "string", "enum": ["low", "medium", "high"]] as [String: Any],
                "note": ["type": "string"] as [String: Any],
            ] as [String: Any],
            "required": ["name", "items", "calories", "protein_g", "carbs_g", "fat_g", "confidence", "note"],
        ]
        if strict {
            item["additionalProperties"] = false
            var properties = root["properties"] as! [String: Any]
            properties["items"] = ["type": "array", "items": item] as [String: Any]
            root["properties"] = properties
            root["additionalProperties"] = false
        }
        return root
    }

    @MainActor
    static func analyze(photoJPEG: Data?, description: String, model: AIModel) async throws -> Estimate {
        guard let key = KeychainStore.apiKey else { throw AIError.missingAPIKey }
        let client = GeminiClient(apiKey: key, model: model)

        var parts: [[String: Any]] = []
        if let photoJPEG {
            parts.append(["inlineData": ["mimeType": "image/jpeg", "data": photoJPEG.base64EncodedString()] as [String: Any]])
        }
        let text = description.trimmingCharacters(in: .whitespacesAndNewlines)
        parts.append(["text": text.isEmpty ? "Estimate the nutrition of this meal." : "Meal: \(text)"])

        func body(strict: Bool) -> [String: Any] {
            [
                "systemInstruction": ["parts": [["text": instructions]]] as [String: Any],
                "contents": [["role": "user", "parts": parts] as [String: Any]],
                "generationConfig": [
                    "responseMimeType": "application/json",
                    "responseJsonSchema": schema(strict: strict),
                    "thinkingConfig": ["thinkingLevel": "low"] as [String: Any],
                    "maxOutputTokens": 4096,
                ] as [String: Any],
            ]
        }

        let response: GeminiResponse
        do {
            response = try await client.stream(body(strict: true)) { _ in }
        } catch let error where GeminiClient.mayBeRequestProblem(error) {
            response = try await client.stream(body(strict: false)) { _ in }
        }
        if response.wasBlocked { throw AIError.refused }
        if response.finishReason == "MAX_TOKENS" { throw AIError.truncated }
        return try parse(response.text)
    }

    static func parse(_ text: String) throws -> Estimate {
        // Models occasionally wrap JSON in a code fence.
        var json = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if json.hasPrefix("```") {
            json = json.components(separatedBy: "\n").dropFirst().joined(separator: "\n")
            if let fence = json.range(of: "```", options: .backwards) { json = String(json[..<fence.lowerBound]) }
        }
        guard let data = json.data(using: .utf8),
              let estimate = try? JSONDecoder().decode(Estimate.self, from: data) else {
            throw AIError.unreadable
        }
        return estimate
    }

    static func entry(from estimate: Estimate, date: Date, source: MealEntry.Source, hasPhoto: Bool) -> MealEntry {
        MealEntry(date: date,
                  name: estimate.name.isEmpty ? "Meal" : estimate.name,
                  calories: max(0, Int(estimate.calories.rounded())),
                  proteinG: max(0, estimate.proteinG.rounded()),
                  carbsG: max(0, estimate.carbsG.rounded()),
                  fatG: max(0, estimate.fatG.rounded()),
                  items: estimate.items.map { item in
                      let portion = item.portion.map { $0.isEmpty ? "" : " · \($0)" } ?? ""
                      return "\(item.name)\(portion) · \(Int(item.calories.rounded())) kcal"
                  },
                  source: source,
                  hasPhoto: hasPhoto)
    }
}
