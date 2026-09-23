import Foundation

enum PlanSource: String, Codable {
    case ai
    case generated
    case custom

    var label: String {
        switch self {
        case .ai: return "AI Coach"
        case .generated: return "Smart Generator"
        case .custom: return "Custom"
        }
    }

    var shortLabel: String {
        switch self {
        case .ai: return "AI"
        case .generated: return "Auto"
        case .custom: return "Custom"
        }
    }

    var symbol: String {
        switch self {
        case .ai: return "sparkles"
        case .generated: return "wand.and.stars"
        case .custom: return "hammer.fill"
        }
    }
}

struct PlannedExercise: Identifiable, Codable, Hashable {
    var id = UUID()
    var exerciseID: String
    var sets: Int
    /// For time-tracked exercises these are seconds.
    var repsLow: Int
    var repsHigh: Int
    var restSeconds: Int
    var notes: String = ""

    var exercise: Exercise? { ExerciseLibrary.exercise(exerciseID) }
    var name: String { ExerciseLibrary.name(for: exerciseID) }

    var targetLabel: String {
        let tracking = exercise?.tracking ?? .weightReps
        let range = repsLow == repsHigh ? "\(repsLow)" : "\(repsLow)–\(repsHigh)"
        switch tracking {
        case .time:
            if repsHigh >= 120 {
                let lo = repsLow / 60, hi = repsHigh / 60
                return lo == hi ? "\(sets) × \(lo) min" : "\(sets) × \(lo)–\(hi) min"
            }
            return "\(sets) × \(range) s"
        default:
            return "\(sets) × \(range)"
        }
    }
}

struct WorkoutDay: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var focus: String
    var exercises: [PlannedExercise]

    var estimatedMinutes: Int {
        let seconds = exercises.reduce(0) { total, item in
            let work = (item.exercise?.tracking == .time) ? item.repsHigh : 40
            return total + item.sets * (work + item.restSeconds)
        }
        return max(10, Int((Double(seconds) / 60.0).rounded()) + 5)
    }

    var muscles: [MuscleGroup] {
        var seen: [MuscleGroup] = []
        for item in exercises {
            if let m = item.exercise?.primary, !seen.contains(m) { seen.append(m) }
        }
        return seen
    }
}

struct WorkoutPlan: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var summary: String
    var goal: FitnessGoal
    var source: PlanSource
    var days: [WorkoutDay]
    var createdAt = Date()
    /// Index of the day to train next (rotates after each finished session).
    var nextDayIndex: Int = 0

    var nextDay: WorkoutDay? {
        guard !days.isEmpty else { return nil }
        return days[min(max(nextDayIndex, 0), days.count - 1)]
    }

    var totalExercises: Int { days.reduce(0) { $0 + $1.exercises.count } }

    /// Compact text form used as context for the AI coach.
    var promptDescription: String {
        var lines = ["Plan: \(name) — goal \(goal.title), \(days.count) days/week"]
        if !summary.isEmpty { lines.append("Summary: \(summary)") }
        for (i, day) in days.enumerated() {
            lines.append("Day \(i + 1): \(day.name) (\(day.focus))")
            for item in day.exercises {
                var line = "  - \(item.exerciseID): \(item.sets) sets x \(item.repsLow)-\(item.repsHigh), rest \(item.restSeconds)s"
                if !item.notes.isEmpty { line += " — \(item.notes)" }
                lines.append(line)
            }
        }
        return lines.joined(separator: "\n")
    }
}
