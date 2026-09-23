import Foundation

/// Rule-based plan generator. Works fully offline and is used when no AI key
/// is configured (and as the instant starter plan after onboarding).
enum PlanGenerator {
    struct Options {
        var goal: FitnessGoal
        var level: ExperienceLevel
        var daysPerWeek: Int
        var sessionMinutes: Int
        var equipment: Set<Equipment>
        var focus: Set<MuscleGroup> = []
    }

    private struct Slot {
        let muscles: [MuscleGroup]
        let compound: Bool
    }

    private enum DayType {
        case fullBody, upper, lower, push, pull, legs

        var title: String {
            switch self {
            case .fullBody: return "Full Body"
            case .upper: return "Upper"
            case .lower: return "Lower"
            case .push: return "Push"
            case .pull: return "Pull"
            case .legs: return "Legs"
            }
        }

        var slots: [Slot] {
            switch self {
            case .fullBody:
                return [Slot(muscles: [.quads], compound: true),
                        Slot(muscles: [.chest], compound: true),
                        Slot(muscles: [.back], compound: true),
                        Slot(muscles: [.hamstrings, .glutes], compound: true),
                        Slot(muscles: [.shoulders], compound: false),
                        Slot(muscles: [.core], compound: false),
                        Slot(muscles: [.biceps], compound: false),
                        Slot(muscles: [.triceps], compound: false)]
            case .upper:
                return [Slot(muscles: [.chest], compound: true),
                        Slot(muscles: [.back], compound: true),
                        Slot(muscles: [.shoulders], compound: true),
                        Slot(muscles: [.back], compound: true),
                        Slot(muscles: [.chest], compound: false),
                        Slot(muscles: [.shoulders], compound: false),
                        Slot(muscles: [.biceps], compound: false),
                        Slot(muscles: [.triceps], compound: false)]
            case .lower:
                return [Slot(muscles: [.quads], compound: true),
                        Slot(muscles: [.hamstrings], compound: true),
                        Slot(muscles: [.glutes, .quads], compound: true),
                        Slot(muscles: [.quads], compound: false),
                        Slot(muscles: [.hamstrings], compound: false),
                        Slot(muscles: [.calves], compound: false),
                        Slot(muscles: [.core], compound: false),
                        Slot(muscles: [.glutes], compound: false)]
            case .push:
                return [Slot(muscles: [.chest], compound: true),
                        Slot(muscles: [.shoulders], compound: true),
                        Slot(muscles: [.chest], compound: true),
                        Slot(muscles: [.chest], compound: false),
                        Slot(muscles: [.shoulders], compound: false),
                        Slot(muscles: [.triceps], compound: false),
                        Slot(muscles: [.triceps], compound: false),
                        Slot(muscles: [.core], compound: false)]
            case .pull:
                return [Slot(muscles: [.back], compound: true),
                        Slot(muscles: [.back], compound: true),
                        Slot(muscles: [.back], compound: true),
                        Slot(muscles: [.shoulders], compound: false),
                        Slot(muscles: [.biceps], compound: false),
                        Slot(muscles: [.biceps], compound: false),
                        Slot(muscles: [.forearms, .core], compound: false),
                        Slot(muscles: [.back], compound: false)]
            case .legs:
                return [Slot(muscles: [.quads], compound: true),
                        Slot(muscles: [.hamstrings], compound: true),
                        Slot(muscles: [.quads, .glutes], compound: true),
                        Slot(muscles: [.glutes], compound: false),
                        Slot(muscles: [.hamstrings], compound: false),
                        Slot(muscles: [.calves], compound: false),
                        Slot(muscles: [.core], compound: false),
                        Slot(muscles: [.quads], compound: false)]
            }
        }
    }

    static func generate(profile: UserProfile) -> WorkoutPlan {
        generate(Options(goal: profile.goal, level: profile.level, daysPerWeek: profile.daysPerWeek,
                         sessionMinutes: profile.sessionMinutes, equipment: profile.equipment))
    }

    static func generate(_ options: Options) -> WorkoutPlan {
        let days = min(max(options.daysPerWeek, 1), 6)
        let split = splitFor(days: days, level: options.level)
        let available = ExerciseLibrary.available(with: options.equipment.union([.bodyweight]))
        let perDay = exerciseCount(minutes: options.sessionMinutes)

        var typeCounts: [String: Int] = [:]
        var workoutDays: [WorkoutDay] = []
        for type in split.types {
            let variant = typeCounts[type.title, default: 0]
            typeCounts[type.title] = variant + 1
            let sameTypeTotal = split.types.filter { $0.title == type.title }.count
            let name = sameTypeTotal > 1 ? "\(type.title) \(["A", "B", "C"][min(variant, 2)])" : type.title
            workoutDays.append(buildDay(name: name, type: type, variant: variant, count: perDay,
                                        options: options, available: available))
        }

        return WorkoutPlan(name: split.name,
                           summary: summary(for: options, splitName: split.name, days: days),
                           goal: options.goal,
                           source: .generated,
                           days: workoutDays)
    }

    // MARK: - Internals

    private static func splitFor(days: Int, level: ExperienceLevel) -> (name: String, types: [DayType]) {
        switch days {
        case 1: return ("Full Body Express", [.fullBody])
        case 2: return ("Full Body 2×", [.fullBody, .fullBody])
        case 3:
            return level == .beginner
                ? ("Full Body 3×", [.fullBody, .fullBody, .fullBody])
                : ("Push · Pull · Legs", [.push, .pull, .legs])
        case 4: return ("Upper / Lower Split", [.upper, .lower, .upper, .lower])
        case 5: return ("PPL + Upper/Lower", [.push, .pull, .legs, .upper, .lower])
        default: return ("Push · Pull · Legs 2×", [.push, .pull, .legs, .push, .pull, .legs])
        }
    }

    private static func exerciseCount(minutes: Int) -> Int {
        switch minutes {
        case ..<35: return 4
        case ..<50: return 5
        case ..<65: return 6
        case ..<80: return 7
        default: return 8
        }
    }

    private static func buildDay(name: String, type: DayType, variant: Int, count: Int,
                                 options: Options, available: [Exercise]) -> WorkoutDay {
        var used = Set<String>()
        var items: [PlannedExercise] = []
        var slots = type.slots

        // Bias toward any focus muscles by moving matching slots forward.
        if !options.focus.isEmpty {
            let focused = slots.filter { !Set($0.muscles).isDisjoint(with: options.focus) }
            let rest = slots.filter { Set($0.muscles).isDisjoint(with: options.focus) }
            slots = focused + rest
        }

        let wantsCardio = options.goal == .loseFat || options.goal == .endurance
        let strengthSlots = wantsCardio ? max(count - 1, 3) : count

        // First pass only takes exercises matching the slot's compound/isolation
        // intent; the second pass fills any gaps with whatever is available.
        var filled = Set<Int>()
        for strict in [true, false] {
            for (slotIndex, slot) in slots.enumerated() where !filled.contains(slotIndex) {
                if items.count >= strengthSlots { break }
                let candidates = available
                    .filter { slot.muscles.contains($0.primary) && !used.contains($0.id) }
                    .filter { !strict || $0.isCompound == slot.compound }
                    .sorted { a, b in
                        if a.isCompound != b.isCompound { return a.isCompound == slot.compound }
                        // Prefer loadable exercises over bodyweight when available.
                        let aLoad = a.tracking == .weightReps, bLoad = b.tracking == .weightReps
                        if aLoad != bLoad { return aLoad }
                        return a.id < b.id
                    }
                guard !candidates.isEmpty else { continue }
                let pick = candidates[(variant + slotIndex / 4) % candidates.count]
                used.insert(pick.id)
                filled.insert(slotIndex)
                items.append(prescribe(pick, isMainLift: items.isEmpty, options: options))
            }
        }

        if wantsCardio, let cardio = cardioFinisher(available: available, variant: variant) {
            var finisher = prescribe(cardio, isMainLift: false, options: options)
            finisher.sets = 1
            finisher.repsLow = options.goal == .loseFat ? 600 : 900
            finisher.repsHigh = options.goal == .loseFat ? 900 : 1200
            finisher.restSeconds = 0
            finisher.notes = "Finisher — steady, sustainable pace."
            items.append(finisher)
        }

        let focus = uniqueMuscles(items).prefix(4).map(\.displayName).joined(separator: " · ")
        return WorkoutDay(name: name, focus: focus.isEmpty ? type.title : focus, exercises: items)
    }

    private static func cardioFinisher(available: [Exercise], variant: Int) -> Exercise? {
        let cardio = available.filter { $0.primary == .cardio }
        guard !cardio.isEmpty else { return nil }
        let machines = cardio.filter { !$0.equipment.contains(.bodyweight) }
        let pool = machines.isEmpty ? cardio : machines
        return pool[variant % pool.count]
    }

    private static func prescribe(_ exercise: Exercise, isMainLift: Bool, options: Options) -> PlannedExercise {
        let p = options.goal.prescription
        var sets = p.sets
        var low = p.repsLow
        var high = p.repsHigh
        var rest = exercise.isCompound ? p.compoundRest : p.rest
        var notes = ""

        switch options.level {
        case .beginner: if !exercise.isCompound { sets = max(2, sets - 1) }
        case .intermediate: break
        case .advanced: if exercise.isCompound { sets += 1 }
        }

        if isMainLift && exercise.isCompound {
            switch options.goal {
            case .getStronger:
                sets = options.level == .beginner ? 3 : 5
                low = 3; high = 5; rest = 180
                notes = "Main lift — add weight when you hit the top of the range on every set."
            case .athletic:
                notes = "Move the weight fast and crisp on every rep."
            default:
                notes = "Main lift — leave 1–2 reps in the tank."
            }
        } else if options.goal == .getStronger && !exercise.isCompound {
            low = 8; high = 12
        }

        switch exercise.tracking {
        case .reps:
            low = max(low, 8); high = max(high, 12)
        case .time:
            if exercise.primary == .cardio {
                sets = 1; low = 600; high = 900; rest = 0
            } else {
                low = 30; high = options.level == .beginner ? 40 : 60; rest = 45
            }
        case .weightReps:
            break
        }

        return PlannedExercise(exerciseID: exercise.id, sets: sets, repsLow: low, repsHigh: high,
                               restSeconds: rest, notes: notes)
    }

    private static func uniqueMuscles(_ items: [PlannedExercise]) -> [MuscleGroup] {
        var seen: [MuscleGroup] = []
        for item in items {
            if let m = item.exercise?.primary, m != .cardio, !seen.contains(m) { seen.append(m) }
        }
        return seen
    }

    private static func summary(for options: Options, splitName: String, days: Int) -> String {
        let progression: String
        switch options.goal {
        case .getStronger: progression = "Add a little weight to your main lifts each week while keeping form crisp."
        case .buildMuscle: progression = "Once you hit the top of a rep range on every set, add weight next session."
        case .loseFat: progression = "Keep lifting heavy enough to hold on to muscle; the finishers drive extra burn."
        case .endurance: progression = "Shorten rest or add reps over time before adding load."
        case .athletic: progression = "Prioritise quality, fast reps — stop sets before speed drops."
        case .generalFitness: progression = "Aim to beat last session by a rep or a small jump in weight."
        }
        return "A \(days)-day \(splitName) plan to \(options.goal.purpose), built around your equipment. \(progression)"
    }
}
