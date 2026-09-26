import Foundation

/// What a set is for. Warm-ups don't count toward volume, records or suggestions.
enum SetKind: String, Codable, CaseIterable, Hashable {
    case normal, warmup, drop, failure

    var title: String {
        switch self {
        case .normal: return "Working set"
        case .warmup: return "Warm-up"
        case .drop: return "Drop set"
        case .failure: return "To failure"
        }
    }

    /// Letter shown instead of the set number.
    var badge: String? {
        switch self {
        case .normal: return nil
        case .warmup: return "W"
        case .drop: return "D"
        case .failure: return "F"
        }
    }

    var symbol: String {
        switch self {
        case .normal: return "circle"
        case .warmup: return "flame"
        case .drop: return "arrow.down.right"
        case .failure: return "bolt.fill"
        }
    }
}

struct LoggedSet: Identifiable, Codable, Hashable {
    var id = UUID()
    /// Always stored in kilograms.
    var weightKg: Double = 0
    var reps: Int = 0
    var seconds: Int = 0
    var completed: Bool = false
    var kind: SetKind = .normal
    /// Rate of perceived exertion (6–10, in halves), if the athlete logged it.
    var rpe: Double? = nil

    var isWarmup: Bool { kind == .warmup }

    init(id: UUID = UUID(), weightKg: Double = 0, reps: Int = 0, seconds: Int = 0, completed: Bool = false,
         kind: SetKind = .normal, rpe: Double? = nil) {
        self.id = id
        self.weightKg = weightKg
        self.reps = reps
        self.seconds = seconds
        self.completed = completed
        self.kind = kind
        self.rpe = rpe
    }

    /// Tolerant decoding so sets saved by older versions keep loading.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        weightKg = try c.decodeIfPresent(Double.self, forKey: .weightKg) ?? 0
        reps = try c.decodeIfPresent(Int.self, forKey: .reps) ?? 0
        seconds = try c.decodeIfPresent(Int.self, forKey: .seconds) ?? 0
        completed = try c.decodeIfPresent(Bool.self, forKey: .completed) ?? false
        kind = (try? c.decodeIfPresent(SetKind.self, forKey: .kind)) ?? .normal
        rpe = try c.decodeIfPresent(Double.self, forKey: .rpe)
    }
}

struct LoggedExercise: Identifiable, Codable, Hashable {
    var id = UUID()
    var exerciseID: String
    var targetRepsLow: Int
    var targetRepsHigh: Int
    var restSeconds: Int
    var notes: String = ""
    var sets: [LoggedSet]
    /// Exercises sharing a group are done back to back as a superset.
    var supersetGroup: UUID? = nil

    var exercise: Exercise? { ExerciseLibrary.exercise(exerciseID) }
    var name: String { ExerciseLibrary.name(for: exerciseID) }
    var tracking: TrackingType { exercise?.tracking ?? .weightReps }

    /// Sets that count (warm-ups excluded).
    var workingSets: [LoggedSet] { sets.filter { !$0.isWarmup } }
    /// Completed working sets: what volume, records and suggestions are based on.
    var completedSets: [LoggedSet] { sets.filter { $0.completed && !$0.isWarmup } }

    var volumeKg: Double {
        completedSets.reduce(0) { $0 + $1.weightKg * Double($1.reps) }
    }

    /// Best estimated one-rep max (Epley) across completed sets.
    var bestEstimatedOneRepMax: Double {
        completedSets.map { Self.estimatedOneRepMax(weight: $0.weightKg, reps: $0.reps) }.max() ?? 0
    }

    static func estimatedOneRepMax(weight: Double, reps: Int) -> Double {
        guard weight > 0, reps > 0 else { return 0 }
        if reps == 1 { return weight }
        return weight * (1 + Double(reps) / 30.0)
    }

    init(id: UUID = UUID(), exerciseID: String, targetRepsLow: Int, targetRepsHigh: Int,
         restSeconds: Int, notes: String = "", sets: [LoggedSet], supersetGroup: UUID? = nil) {
        self.id = id
        self.exerciseID = exerciseID
        self.targetRepsLow = targetRepsLow
        self.targetRepsHigh = targetRepsHigh
        self.restSeconds = restSeconds
        self.notes = notes
        self.sets = sets
        self.supersetGroup = supersetGroup
    }

    /// Prefills today's sets from the progression suggestion when there is one,
    /// otherwise from last time's numbers.
    init(planned: PlannedExercise, previous: [LoggedSet], suggestion: OverloadSuggestion? = nil) {
        let tracking = planned.exercise?.tracking ?? .weightReps
        let previous = previous.filter { $0.kind != .drop }
        var sets: [LoggedSet] = []
        for i in 0..<max(planned.sets, 1) {
            let prev = i < previous.count ? previous[i] : previous.last
            var set = LoggedSet()
            switch tracking {
            case .weightReps:
                set.weightKg = suggestion?.weightKg ?? prev?.weightKg ?? 0
                set.reps = suggestion?.reps ?? prev?.reps ?? planned.repsHigh
            case .reps:
                set.reps = suggestion?.reps ?? prev?.reps ?? planned.repsHigh
            case .time:
                set.seconds = suggestion?.seconds ?? prev?.seconds ?? planned.repsHigh
            }
            sets.append(set)
        }
        self.init(exerciseID: planned.exerciseID, targetRepsLow: planned.repsLow,
                  targetRepsHigh: planned.repsHigh, restSeconds: planned.restSeconds,
                  notes: planned.notes, sets: sets, supersetGroup: planned.supersetGroup)
    }
}

struct WorkoutSession: Identifiable, Codable, Hashable {
    var id = UUID()
    var planID: UUID?
    var dayID: UUID?
    var name: String
    var startedAt = Date()
    var endedAt: Date?
    var exercises: [LoggedExercise]
    var notes: String = ""
    /// Perceived difficulty 1–10 captured when the workout is finished.
    var effort: Int?

    var duration: TimeInterval {
        (endedAt ?? Date()).timeIntervalSince(startedAt)
    }

    var totalVolumeKg: Double { exercises.reduce(0) { $0 + $1.volumeKg } }
    var completedSetCount: Int { exercises.reduce(0) { $0 + $1.completedSets.count } }
    var totalSetCount: Int { exercises.reduce(0) { $0 + $1.workingSets.count } }

    var progress: Double {
        totalSetCount == 0 ? 0 : Double(completedSetCount) / Double(totalSetCount)
    }

    var muscles: [MuscleGroup] {
        var seen: [MuscleGroup] = []
        for item in exercises where !item.completedSets.isEmpty {
            if let m = item.exercise?.primary, !seen.contains(m) { seen.append(m) }
        }
        return seen
    }

    /// Short text summary used as AI coach context.
    func promptSummary(metric: Bool) -> String {
        let df = DateFormatter()
        df.dateFormat = "EEE d MMM"
        let unit = WeightUnit.label(metric: metric)
        var line = "\(df.string(from: startedAt)) — \(name): \(completedSetCount)/\(totalSetCount) sets, \(Int(duration / 60)) min"
        if let effort { line += ", effort \(effort)/10" }
        let tops = exercises.compactMap { ex -> String? in
            guard let best = ex.completedSets.max(by: { $0.weightKg * Double($0.reps) < $1.weightKg * Double($1.reps) }) else { return nil }
            let rpe = best.rpe.map { " @RPE\(String(format: "%g", $0))" } ?? ""
            switch ex.tracking {
            case .weightReps:
                return "\(ex.exerciseID) \(WeightUnit.format(best.weightKg, metric: metric))\(unit)x\(best.reps)\(rpe)"
            case .reps:
                return "\(ex.exerciseID) x\(best.reps)"
            case .time:
                return "\(ex.exerciseID) \(best.seconds)s"
            }
        }
        if !tops.isEmpty { line += "\n    top sets: " + tops.joined(separator: "; ") }
        let skipped = exercises.filter { $0.completedSets.isEmpty }.map(\.exerciseID)
        if !skipped.isEmpty { line += "\n    skipped: " + skipped.joined(separator: ", ") }
        if !notes.isEmpty { line += "\n    notes: \(notes)" }
        return line
    }
}

struct BodyWeightEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var weightKg: Double
}
