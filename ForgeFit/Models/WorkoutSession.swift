import Foundation

struct LoggedSet: Identifiable, Codable, Hashable {
    var id = UUID()
    /// Always stored in kilograms.
    var weightKg: Double = 0
    var reps: Int = 0
    var seconds: Int = 0
    var completed: Bool = false
}

struct LoggedExercise: Identifiable, Codable, Hashable {
    var id = UUID()
    var exerciseID: String
    var targetRepsLow: Int
    var targetRepsHigh: Int
    var restSeconds: Int
    var notes: String = ""
    var sets: [LoggedSet]

    var exercise: Exercise? { ExerciseLibrary.exercise(exerciseID) }
    var name: String { ExerciseLibrary.name(for: exerciseID) }
    var tracking: TrackingType { exercise?.tracking ?? .weightReps }

    var completedSets: [LoggedSet] { sets.filter(\.completed) }

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
         restSeconds: Int, notes: String = "", sets: [LoggedSet]) {
        self.id = id
        self.exerciseID = exerciseID
        self.targetRepsLow = targetRepsLow
        self.targetRepsHigh = targetRepsHigh
        self.restSeconds = restSeconds
        self.notes = notes
        self.sets = sets
    }

    init(planned: PlannedExercise, previous: [LoggedSet]) {
        let tracking = planned.exercise?.tracking ?? .weightReps
        var sets: [LoggedSet] = []
        for i in 0..<max(planned.sets, 1) {
            let prev = i < previous.count ? previous[i] : previous.last
            var set = LoggedSet()
            switch tracking {
            case .weightReps:
                set.weightKg = prev?.weightKg ?? 0
                set.reps = prev?.reps ?? planned.repsHigh
            case .reps:
                set.reps = prev?.reps ?? planned.repsHigh
            case .time:
                set.seconds = prev?.seconds ?? planned.repsHigh
            }
            sets.append(set)
        }
        self.init(exerciseID: planned.exerciseID, targetRepsLow: planned.repsLow,
                  targetRepsHigh: planned.repsHigh, restSeconds: planned.restSeconds,
                  notes: planned.notes, sets: sets)
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
    var totalSetCount: Int { exercises.reduce(0) { $0 + $1.sets.count } }

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
            switch ex.tracking {
            case .weightReps:
                return "\(ex.exerciseID) \(WeightUnit.format(best.weightKg, metric: metric))\(unit)x\(best.reps)"
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
