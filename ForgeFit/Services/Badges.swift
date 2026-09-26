import Foundation

/// A milestone the athlete can earn. Badges are worked out from history, so they
/// stay in step with synced data and never need storing.
struct Badge: Identifiable, Hashable {
    enum Tone: Int, Hashable {
        case paper, sky, rose, sand, lilac, sage
    }

    let id: String
    let title: String
    let detail: String
    let symbol: String
    let tone: Tone
}

struct BadgeStatus: Identifiable, Hashable {
    let badge: Badge
    let current: Double
    let target: Double

    var id: String { badge.id }
    var isEarned: Bool { current >= target }
    var fraction: Double { target > 0 ? min(current / target, 1) : 0 }
}

enum BadgeBook {
    struct Facts {
        var workouts = 0
        var longestWeekStreak = 0
        var totalVolumeKg = 0.0
        var bestLiftKg: [String: Double] = [:]
        var records = 0
        var earlyBird = false
        var nightOwl = false
        var allOut = false
        var meals = 0
        var proteinDays = 0
    }

    static func facts(sessions: [WorkoutSession], meals: [MealEntry], proteinTarget: Int,
                      calendar: Calendar = BadgeBook.mondayCalendar) -> Facts {
        var facts = Facts()
        facts.workouts = sessions.count
        facts.totalVolumeKg = sessions.reduce(0) { $0 + $1.totalVolumeKg }
        facts.longestWeekStreak = longestWeekStreak(sessions.map(\.startedAt), calendar: calendar)
        var bestSoFar: [String: Double] = [:]
        for session in sessions.sorted(by: { $0.startedAt < $1.startedAt }) {
            let hour = calendar.component(.hour, from: session.startedAt)
            if hour < 7 { facts.earlyBird = true }
            if hour >= 21 { facts.nightOwl = true }
            if session.effort == 10 { facts.allOut = true }
            for exercise in session.exercises where exercise.tracking == .weightReps {
                let heaviest = exercise.completedSets.filter { $0.reps > 0 }.map(\.weightKg).max() ?? 0
                facts.bestLiftKg[exercise.exerciseID] = max(facts.bestLiftKg[exercise.exerciseID] ?? 0, heaviest)
                let e1rm = exercise.bestEstimatedOneRepMax
                guard e1rm > 0 else { continue }
                if let previous = bestSoFar[exercise.exerciseID], e1rm > previous + 0.01 {
                    facts.records += 1
                }
                bestSoFar[exercise.exerciseID] = max(bestSoFar[exercise.exerciseID] ?? 0, e1rm)
            }
        }
        facts.meals = meals.count
        facts.proteinDays = NutritionMath.proteinDaysHit(meals, target: proteinTarget, calendar: calendar)
        return facts
    }

    static func evaluate(_ f: Facts) -> [BadgeStatus] {
        func lift(_ ids: [String]) -> Double { ids.map { f.bestLiftKg[$0] ?? 0 }.max() ?? 0 }
        let bench = lift(["barbell_bench_press"])
        let squat = lift(["back_squat", "front_squat"])
        let deadlift = lift(["deadlift"])
        // Plate milestones: 60 / 100 / 140 / 180 kg (135 / 225 / 315 / 405 lb), with a little slack.
        func plates(_ kg: Double) -> Double { kg - 0.5 }
        let items: [(Badge, Double, Double)] = [
            (Badge(id: "first_workout", title: "First Rep", detail: "Finish your first workout",
                   symbol: "figure.strengthtraining.traditional", tone: .paper), Double(f.workouts), 1),
            (Badge(id: "workouts_10", title: "Committed", detail: "Finish 10 workouts",
                   symbol: "10.circle.fill", tone: .sky), Double(f.workouts), 10),
            (Badge(id: "workouts_50", title: "Half Century", detail: "Finish 50 workouts",
                   symbol: "50.circle.fill", tone: .lilac), Double(f.workouts), 50),
            (Badge(id: "workouts_100", title: "Centurion", detail: "Finish 100 workouts",
                   symbol: "crown.fill", tone: .sand), Double(f.workouts), 100),
            (Badge(id: "streak_4", title: "Month Strong", detail: "Train 4 weeks in a row",
                   symbol: "flame.fill", tone: .rose), Double(f.longestWeekStreak), 4),
            (Badge(id: "streak_12", title: "Unbreakable", detail: "Train 12 weeks in a row",
                   symbol: "flame.circle.fill", tone: .sand), Double(f.longestWeekStreak), 12),
            (Badge(id: "volume_10t", title: "10 Tonnes", detail: "Lift 10,000 kg in total",
                   symbol: "scalemass.fill", tone: .sage), f.totalVolumeKg, 10_000),
            (Badge(id: "volume_100t", title: "100 Tonnes", detail: "Lift 100,000 kg in total",
                   symbol: "mountain.2.fill", tone: .lilac), f.totalVolumeKg, 100_000),
            (Badge(id: "bench_60", title: "Bench: 1 Plate", detail: "Bench press 60 kg / 135 lb",
                   symbol: "1.circle", tone: .sky), bench, plates(60)),
            (Badge(id: "bench_100", title: "Bench: 2 Plates", detail: "Bench press 100 kg / 225 lb",
                   symbol: "2.circle", tone: .sky), bench, plates(100)),
            (Badge(id: "squat_100", title: "Squat: 2 Plates", detail: "Squat 100 kg / 225 lb",
                   symbol: "2.circle.fill", tone: .sage), squat, plates(100)),
            (Badge(id: "squat_140", title: "Squat: 3 Plates", detail: "Squat 140 kg / 315 lb",
                   symbol: "3.circle.fill", tone: .sage), squat, plates(140)),
            (Badge(id: "deadlift_140", title: "Pull: 3 Plates", detail: "Deadlift 140 kg / 315 lb",
                   symbol: "3.square.fill", tone: .rose), deadlift, plates(140)),
            (Badge(id: "deadlift_180", title: "Pull: 4 Plates", detail: "Deadlift 180 kg / 405 lb",
                   symbol: "4.square.fill", tone: .rose), deadlift, plates(180)),
            (Badge(id: "pr_1", title: "Record Breaker", detail: "Set a personal record",
                   symbol: "trophy.fill", tone: .sand), Double(f.records), 1),
            (Badge(id: "pr_25", title: "PR Machine", detail: "Set 25 personal records",
                   symbol: "rosette", tone: .sand), Double(f.records), 25),
            (Badge(id: "early_bird", title: "Early Bird", detail: "Start a workout before 7 am",
                   symbol: "sunrise.fill", tone: .paper), f.earlyBird ? 1 : 0, 1),
            (Badge(id: "night_owl", title: "Night Owl", detail: "Start a workout after 9 pm",
                   symbol: "moon.stars.fill", tone: .lilac), f.nightOwl ? 1 : 0, 1),
            (Badge(id: "all_out", title: "All Out", detail: "Rate a workout 10/10 effort",
                   symbol: "bolt.heart.fill", tone: .rose), f.allOut ? 1 : 0, 1),
            (Badge(id: "fuel_1", title: "Fuel Up", detail: "Log your first meal",
                   symbol: "fork.knife", tone: .sage), Double(f.meals), 1),
            (Badge(id: "protein_7", title: "Protein Pro", detail: "Hit your protein target on 7 days",
                   symbol: "leaf.fill", tone: .sage), Double(f.proteinDays), 7),
        ]
        return items.map { BadgeStatus(badge: $0.0, current: $0.1, target: $0.2) }
    }

    /// Badges earned in `after` that weren't earned in `before`.
    static func newlyEarned(before: [BadgeStatus], after: [BadgeStatus]) -> [Badge] {
        let had = Set(before.filter(\.isEarned).map(\.id))
        return after.filter { $0.isEarned && !had.contains($0.id) }.map(\.badge)
    }

    static func longestWeekStreak(_ dates: [Date], calendar: Calendar) -> Int {
        let weeks = Set(dates.compactMap { calendar.dateInterval(of: .weekOfYear, for: $0)?.start }).sorted()
        var longest = 0
        var current = 0
        var previous: Date?
        for week in weeks {
            if let previous, calendar.date(byAdding: .weekOfYear, value: 1, to: previous) == week {
                current += 1
            } else {
                current = 1
            }
            longest = max(longest, current)
            previous = week
        }
        return longest
    }

    static let mondayCalendar: Calendar = {
        var c = Calendar.current
        c.firstWeekday = 2
        return c
    }()
}
