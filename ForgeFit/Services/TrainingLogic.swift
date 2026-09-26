import Foundation

/// "Last time → try today" for one exercise.
struct OverloadSuggestion: Equatable {
    enum Kind: Equatable {
        /// Hit the top of the rep range on every set: add weight.
        case addWeight
        /// In range: same weight, one more rep.
        case addReps
        /// Below range: same weight until every set reaches the bottom of the range.
        case repeatWeight
        /// Well below range: take some weight off and rebuild.
        case deload
        /// Timed hold: a few seconds longer.
        case holdLonger
    }

    var kind: Kind
    var weightKg: Double?
    var reps: Int?
    var seconds: Int?
    /// One short sentence explaining why.
    var reason: String

    var isIncrease: Bool { kind == .addWeight || kind == .addReps || kind == .holdLonger }
}

/// Double progression: work up to the top of the rep range, then add weight.
enum Progression {
    static func suggest(for exercise: Exercise?, targetLow: Int, targetHigh: Int,
                        previous: [LoggedSet], metric: Bool) -> OverloadSuggestion? {
        let tracking = exercise?.tracking ?? .weightReps
        // Drop sets and warm-ups don't say much about the working weight.
        let sets = previous.filter { !$0.isWarmup && $0.kind != .drop }
        guard !sets.isEmpty else { return nil }
        let low = max(1, min(targetLow, targetHigh))
        let high = max(low, targetHigh)

        switch tracking {
        case .weightReps:
            let top = sets.map(\.weightKg).max() ?? 0
            guard top > 0 else { return repsSuggestion(sets: sets, low: low, high: high) }
            let atTop = sets.filter { $0.weightKg >= top - 0.01 }.map(\.reps)
            let fewest = atTop.min() ?? 0
            let unit = WeightUnit.label(metric: metric)
            if fewest >= high {
                let step = increment(for: exercise, metric: metric)
                let next = roundToLoadable(top + step, exercise: exercise, metric: metric, down: false)
                let added = WeightUnit.format(next - top, metric: metric)
                return OverloadSuggestion(kind: .addWeight, weightKg: next, reps: low,
                                          reason: "You hit \(high) reps on every set last time — add \(added) \(unit).")
            }
            if fewest >= low {
                let reps = min(fewest + 1, high)
                return OverloadSuggestion(kind: .addReps, weightKg: top, reps: reps,
                                          reason: "Same weight — aim for \(reps) reps on each set.")
            }
            if fewest <= low - 3 {
                let lighter = roundToLoadable(top * 0.9, exercise: exercise, metric: metric, down: true)
                return OverloadSuggestion(kind: .deload, weightKg: lighter, reps: low,
                                          reason: "Reps fell well short last time — take ~10% off and build back up.")
            }
            return OverloadSuggestion(kind: .repeatWeight, weightKg: top, reps: low,
                                      reason: "Same weight — get every set to \(low) reps before adding more.")
        case .reps:
            return repsSuggestion(sets: sets, low: low, high: high)
        case .time:
            // Long cardio blocks are programmed by time, not progressed set to set.
            guard high < 120 else { return nil }
            let best = sets.map(\.seconds).max() ?? 0
            guard best > 0 else { return nil }
            return OverloadSuggestion(kind: .holdLonger, seconds: best + 5,
                                      reason: "Hold 5 s longer than last time.")
        }
    }

    private static func repsSuggestion(sets: [LoggedSet], low: Int, high: Int) -> OverloadSuggestion? {
        let fewest = sets.map(\.reps).min() ?? 0
        guard fewest > 0 else { return nil }
        if fewest >= high {
            return OverloadSuggestion(kind: .addReps, reps: fewest + 1,
                                      reason: "Top of the range on every set — add a rep or try a harder variation.")
        }
        return OverloadSuggestion(kind: .addReps, reps: min(fewest + 1, high),
                                  reason: "Beat last time by one rep on each set.")
    }

    /// Typical jump: bigger for lower-body compounds, smaller for dumbbells.
    static func increment(for exercise: Exercise?, metric: Bool) -> Double {
        let lowerBody: Set<MuscleGroup> = [.quads, .hamstrings, .glutes]
        let bigLift = exercise.map { $0.isCompound && (lowerBody.contains($0.primary) || $0.id == "deadlift") } ?? false
        if isDumbbell(exercise) {
            return metric ? 2 : WeightUnit.toKg(5, metric: false)
        }
        if metric { return bigLift ? 5 : 2.5 }
        return WeightUnit.toKg(bigLift ? 10 : 5, metric: false)
    }

    /// Rounds to weights you can actually load (2.5 kg / 5 lb plates, 2 kg / 5 lb dumbbell steps).
    static func roundToLoadable(_ kg: Double, exercise: Exercise?, metric: Bool, down: Bool) -> Double {
        let step = metric ? (isDumbbell(exercise) ? 2 : 2.5) : 5
        let value = WeightUnit.display(kg, metric: metric) / step
        let rounded = (down ? value.rounded(.down) : value.rounded()) * step
        return WeightUnit.toKg(max(rounded, step), metric: metric)
    }

    static func isDumbbell(_ exercise: Exercise?) -> Bool {
        guard let equipment = exercise?.equipment else { return false }
        return (equipment.contains(.dumbbells) || equipment.contains(.kettlebell)) && !equipment.contains(.barbell)
    }
}

/// Warm-up ramps before the first working set.
enum Warmup {
    static func usesBar(_ exercise: Exercise?) -> Bool {
        guard let equipment = exercise?.equipment else { return false }
        return equipment.contains(.barbell) || equipment.contains(.ezBar) || equipment.contains(.smithMachine)
    }

    static func barKg(for exercise: Exercise?, metric: Bool) -> Double {
        if exercise?.equipment.contains(.ezBar) == true { return metric ? 10 : WeightUnit.toKg(25, metric: false) }
        return metric ? 20 : WeightUnit.toKg(45, metric: false)
    }

    /// Warm-up sets for a working weight: empty bar then 40/60/80% for barbell lifts,
    /// 50/75% for everything else. Returns nothing when the load is too light to need one.
    static func sets(for exercise: Exercise?, workingKg: Double, metric: Bool) -> [LoggedSet] {
        guard workingKg > 0, exercise?.tracking == .weightReps else { return [] }
        var ramp: [(kg: Double, reps: Int)] = []
        if usesBar(exercise) {
            let bar = barKg(for: exercise, metric: metric)
            guard workingKg > bar + 0.5 else { return [] }
            ramp.append((bar, 10))
            for (fraction, reps) in [(0.4, 8), (0.6, 5), (0.8, 3)] {
                let kg = Plates.roundToPlates(workingKg * fraction, metric: metric)
                ramp.append((kg, reps))
            }
        } else {
            for (fraction, reps) in [(0.5, 10), (0.75, 5)] {
                let kg = Progression.roundToLoadable(workingKg * fraction, exercise: exercise, metric: metric, down: true)
                ramp.append((kg, reps))
            }
        }
        // Keep each step heavier than the last and lighter than the working weight.
        var result: [LoggedSet] = []
        var last = 0.0
        for step in ramp where step.kg > last + 0.01 && step.kg < workingKg - 0.01 {
            result.append(LoggedSet(weightKg: step.kg, reps: step.reps, kind: .warmup))
            last = step.kg
        }
        return result
    }
}

/// What to put on each side of the bar.
struct PlateLoad: Equatable {
    /// Plates for one side, heaviest first, in the display unit.
    var perSide: [Double]
    /// Total the bar will weigh, in the display unit.
    var total: Double
    var exact: Bool
}

enum Plates {
    static let kilograms: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]
    static let pounds: [Double] = [45, 35, 25, 10, 5, 2.5]

    static func available(metric: Bool) -> [Double] { metric ? kilograms : pounds }

    /// Greedy loading works for standard plate sets; values are in the display unit.
    static func load(target: Double, bar: Double, plates: [Double]) -> PlateLoad {
        guard target > bar else { return PlateLoad(perSide: [], total: bar, exact: abs(target - bar) < 0.01) }
        var remaining = (target - bar) / 2
        var perSide: [Double] = []
        for plate in plates.sorted(by: >) {
            while remaining >= plate - 0.001 {
                perSide.append(plate)
                remaining -= plate
            }
        }
        let total = bar + 2 * perSide.reduce(0, +)
        return PlateLoad(perSide: perSide, total: total, exact: abs(total - target) < 0.01)
    }

    /// Nearest weight a standard plate set can make (2.5 kg / 5 lb steps).
    static func roundToPlates(_ kg: Double, metric: Bool) -> Double {
        let step = metric ? 2.5 : 5
        let value = (WeightUnit.display(kg, metric: metric) / step).rounded() * step
        return WeightUnit.toKg(value, metric: metric)
    }
}

/// Swapping an exercise for one that trains the same thing with the equipment at hand.
enum Alternatives {
    static func options(for exerciseID: String, equipment: Set<Equipment>, excluding: Set<String>) -> [Exercise] {
        guard let original = ExerciseLibrary.exercise(exerciseID) else { return [] }
        let available = equipment.union([.bodyweight])
        let candidates = ExerciseLibrary.all.filter {
            $0.id != exerciseID && !excluding.contains($0.id) && $0.isAvailable(with: available)
                && ($0.primary == original.primary || $0.secondary.first == original.primary)
        }
        func score(_ e: Exercise) -> Int {
            var s = 0
            if e.primary == original.primary { s += 10 }
            if e.isCompound == original.isCompound { s += 3 }
            if e.tracking == original.tracking { s += 2 }
            s += Set(e.secondary).intersection(original.secondary).count
            if !Set(e.equipment).isDisjoint(with: original.equipment.filter { $0 != .bodyweight }) { s += 1 }
            return s
        }
        return candidates.sorted { a, b in
            let sa = score(a), sb = score(b)
            return sa != sb ? sa > sb : a.name < b.name
        }
    }
}
