import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// What the workout Live Activity shows. Shared by the app (which fills it in) and the
/// widget extension (which draws it).
struct WorkoutActivityState: Codable, Hashable {
    /// The exercise to do now (or next, while resting).
    var exercise: String
    /// The set to do, for example "Set 2 of 3 · 60 kg × 8". Empty when nothing's left.
    var detail: String
    var setsDone: Int
    var setsTotal: Int
    /// Set while resting between sets.
    var restStart: Date?
    var restEnd: Date?
}

#if canImport(ActivityKit)
/// The workout in progress, shown on the Lock Screen and in the Dynamic Island for as long
/// as it runs, with a countdown while resting between sets.
struct WorkoutActivityAttributes: ActivityAttributes {
    typealias ContentState = WorkoutActivityState

    var sessionID: UUID
    var workoutName: String
    var startedAt: Date
}
#endif
