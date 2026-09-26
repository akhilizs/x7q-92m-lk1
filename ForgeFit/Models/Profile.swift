import Foundation

enum FitnessGoal: String, Codable, CaseIterable, Identifiable {
    case buildMuscle
    case getStronger
    case loseFat
    case endurance
    case athletic
    case generalFitness

    var id: String { rawValue }

    var title: String {
        switch self {
        case .buildMuscle: return "Build Muscle"
        case .getStronger: return "Get Stronger"
        case .loseFat: return "Lose Fat"
        case .endurance: return "Endurance"
        case .athletic: return "Athletic Power"
        case .generalFitness: return "Stay Fit"
        }
    }

    var subtitle: String {
        switch self {
        case .buildMuscle: return "Hypertrophy-focused volume"
        case .getStronger: return "Heavy compounds, low reps"
        case .loseFat: return "Keep muscle, burn more"
        case .endurance: return "Higher reps, less rest"
        case .athletic: return "Explosive, well-rounded"
        case .generalFitness: return "Balanced health & energy"
        }
    }

    /// Completes the phrase "a plan to …".
    var purpose: String {
        switch self {
        case .buildMuscle: return "build muscle"
        case .getStronger: return "get stronger"
        case .loseFat: return "lose fat while keeping muscle"
        case .endurance: return "build endurance"
        case .athletic: return "build athletic power"
        case .generalFitness: return "stay fit and healthy"
        }
    }

    var symbol: String {
        switch self {
        case .buildMuscle: return "figure.strengthtraining.traditional"
        case .getStronger: return "bolt.fill"
        case .loseFat: return "flame.fill"
        case .endurance: return "figure.run"
        case .athletic: return "figure.basketball"
        case .generalFitness: return "heart.fill"
        }
    }

    /// Default prescription used by the offline plan generator.
    var prescription: (sets: Int, repsLow: Int, repsHigh: Int, rest: Int, compoundRest: Int) {
        switch self {
        case .buildMuscle: return (3, 8, 12, 90, 120)
        case .getStronger: return (3, 6, 8, 120, 180)
        case .loseFat: return (3, 12, 15, 45, 60)
        case .endurance: return (2, 15, 20, 30, 45)
        case .athletic: return (3, 5, 8, 90, 150)
        case .generalFitness: return (3, 10, 12, 60, 90)
        }
    }
}

enum ExperienceLevel: String, Codable, CaseIterable, Identifiable {
    case beginner, intermediate, advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }

    var subtitle: String {
        switch self {
        case .beginner: return "Less than 6 months of consistent training"
        case .intermediate: return "6 months – 2 years, comfortable with the main lifts"
        case .advanced: return "2+ years, chasing progress on a structured plan"
        }
    }

    var symbol: String {
        switch self {
        case .beginner: return "leaf.fill"
        case .intermediate: return "flame.fill"
        case .advanced: return "crown.fill"
        }
    }
}

enum Gender: String, Codable, CaseIterable, Identifiable {
    case female, male, unspecified

    var id: String { rawValue }

    var title: String {
        switch self {
        case .female: return "Female"
        case .male: return "Male"
        case .unspecified: return "Prefer not to say"
        }
    }
}

/// Sports and activities the athlete enjoys (shared with the AI coach).
enum Activities {
    static let all = ["bodybuilding", "powerlifting", "running", "cycling", "swimming", "yoga",
                      "pilates", "crossfit", "football", "basketball", "tennis", "boxing",
                      "martial arts", "climbing", "hiking", "dance"]
}

struct UserProfile: Codable, Equatable {
    var name: String = ""
    var goal: FitnessGoal = .buildMuscle
    var level: ExperienceLevel = .beginner
    var daysPerWeek: Int = 3
    var sessionMinutes: Int = 60
    var equipment: Set<Equipment> = EquipmentPreset.fullGym.equipment
    var bodyWeightKg: Double? = nil
    var heightCm: Double? = nil
    var age: Int? = nil
    var useMetric: Bool = true
    /// Injuries, limitations or preferences — shared with the AI coach.
    var notes: String = ""
    var gender: Gender? = nil
    var activities: [String] = []
    /// Custom daily targets; nil means "work it out from my profile".
    var calorieTarget: Int? = nil
    var proteinTarget: Int? = nil

    init() {}

    /// Tolerant decoding so data saved by older versions keeps loading.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = UserProfile()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? defaults.name
        goal = try c.decodeIfPresent(FitnessGoal.self, forKey: .goal) ?? defaults.goal
        level = try c.decodeIfPresent(ExperienceLevel.self, forKey: .level) ?? defaults.level
        daysPerWeek = try c.decodeIfPresent(Int.self, forKey: .daysPerWeek) ?? defaults.daysPerWeek
        sessionMinutes = try c.decodeIfPresent(Int.self, forKey: .sessionMinutes) ?? defaults.sessionMinutes
        equipment = try c.decodeIfPresent(Set<Equipment>.self, forKey: .equipment) ?? defaults.equipment
        bodyWeightKg = try c.decodeIfPresent(Double.self, forKey: .bodyWeightKg)
        heightCm = try c.decodeIfPresent(Double.self, forKey: .heightCm)
        age = try c.decodeIfPresent(Int.self, forKey: .age)
        useMetric = try c.decodeIfPresent(Bool.self, forKey: .useMetric) ?? defaults.useMetric
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? defaults.notes
        gender = try c.decodeIfPresent(Gender.self, forKey: .gender)
        activities = try c.decodeIfPresent([String].self, forKey: .activities) ?? []
        calorieTarget = try c.decodeIfPresent(Int.self, forKey: .calorieTarget)
        proteinTarget = try c.decodeIfPresent(Int.self, forKey: .proteinTarget)
    }

    var firstName: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.split(separator: " ").first.map(String.init) ?? ""
    }

    var promptSummary: String {
        var lines: [String] = []
        if !name.isEmpty { lines.append("Name: \(name)") }
        lines.append("Goal: \(goal.title) (\(goal.subtitle))")
        lines.append("Experience: \(level.title)")
        lines.append("Training days per week: \(daysPerWeek)")
        lines.append("Session length: \(sessionMinutes) minutes")
        if let gender, gender != .unspecified { lines.append("Sex: \(gender.rawValue)") }
        if let age { lines.append("Age: \(age)") }
        if let bodyWeightKg { lines.append(String(format: "Body weight: %.1f kg", bodyWeightKg)) }
        if let heightCm { lines.append(String(format: "Height: %.0f cm", heightCm)) }
        let eq = Equipment.allCases.filter { equipment.contains($0) }.map(\.rawValue).joined(separator: ", ")
        lines.append("Available equipment: \(eq.isEmpty ? "bodyweight only" : eq)")
        if !activities.isEmpty {
            lines.append("Enjoys: \(activities.joined(separator: ", "))")
        }
        if !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("Injuries / limitations / preferences: \(notes)")
        }
        return lines.joined(separator: "\n")
    }
}

enum WeightUnit {
    static let lbPerKg = 2.2046226218

    static func display(_ kg: Double, metric: Bool) -> Double {
        metric ? kg : kg * lbPerKg
    }

    static func toKg(_ value: Double, metric: Bool) -> Double {
        metric ? value : value / lbPerKg
    }

    static func label(metric: Bool) -> String { metric ? "kg" : "lb" }

    static func format(_ kg: Double, metric: Bool, decimals: Int = 1) -> String {
        let v = display(kg, metric: metric)
        if v.rounded() == v { return String(format: "%.0f", v) }
        return String(format: "%.\(decimals)f", v)
    }
}
