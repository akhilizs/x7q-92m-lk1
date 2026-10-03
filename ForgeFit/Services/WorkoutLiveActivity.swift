import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Keeps the workout in progress on the Lock Screen and in the Dynamic Island: the current
/// exercise and set, how far through the workout you are, and a countdown while resting.
@MainActor
enum WorkoutLiveActivity {
    /// The exercise the athlete last finished a set of; shown while it has sets left.
    private static var focusExerciseID: UUID?
    /// The rest in progress. Kept here so updates never race each other.
    private static var rest: ClosedRange<Date>?
    private static var restRestored = false
    #if canImport(ActivityKit)
    private static var lastState: WorkoutActivityState?
    private static var updates: Task<Void, Never>?
    #endif

    /// Starts, refreshes or ends the activity to match the workout in progress.
    static func sync(_ session: WorkoutSession?, metric: Bool) {
        #if canImport(ActivityKit)
        if !restRestored {
            // After a relaunch, pick up a rest that's still running.
            restRestored = true
            if let state = running.first?.content.state, let start = state.restStart, let end = state.restEnd,
               end > Date(), end >= start {
                rest = start...end
            }
        }
        if let current = rest, current.upperBound <= Date() { rest = nil }
        apply(session, metric: metric)
        #endif
    }

    static func focus(on exerciseID: UUID) {
        focusExerciseID = exerciseID
    }

    static func startRest(until end: Date, session: WorkoutSession?, metric: Bool) {
        let start = Date()
        rest = start...max(end, start)
        apply(session, metric: metric)
    }

    /// Moves the end of the current rest (the ±15 s buttons).
    static func moveRest(to end: Date, session: WorkoutSession?, metric: Bool) {
        let start = rest?.lowerBound ?? Date()
        rest = start...max(end, start)
        apply(session, metric: metric)
    }

    static func endRest(session: WorkoutSession?, metric: Bool) {
        rest = nil
        apply(session, metric: metric)
    }

    /// The workout was finished or discarded.
    static func end() {
        apply(nil, metric: true)
    }

    // MARK: Internals

    private static func apply(_ session: WorkoutSession?, metric: Bool) {
        #if canImport(ActivityKit)
        let activities = running
        guard let session else {
            focusExerciseID = nil
            rest = nil
            lastState = nil
            enqueue {
                for activity in activities { await activity.end(nil, dismissalPolicy: .immediate) }
            }
            return
        }
        // Anything left over from an earlier workout.
        let stale = activities.filter { $0.attributes.sessionID != session.id }
        if !stale.isEmpty {
            enqueue {
                for activity in stale { await activity.end(nil, dismissalPolicy: .immediate) }
            }
        }

        let state = WorkoutActivityContent.state(for: session, focus: focusExerciseID, rest: rest, metric: metric)
        let content = ActivityContent(state: state, staleDate: state.restEnd)
        if let activity = activities.first(where: { $0.attributes.sessionID == session.id }) {
            guard state != lastState else { return }
            lastState = state
            enqueue { await activity.update(content) }
        } else {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            let attributes = WorkoutActivityAttributes(sessionID: session.id, workoutName: session.name,
                                                       startedAt: session.startedAt)
            if (try? Activity.request(attributes: attributes, content: content, pushType: nil)) != nil {
                lastState = state
            }
        }
        #endif
    }

    #if canImport(ActivityKit)
    private static var running: [Activity<WorkoutActivityAttributes>] {
        Activity<WorkoutActivityAttributes>.activities.filter { $0.activityState == .active || $0.activityState == .stale }
    }

    /// Runs activity updates one after another, in the order they were made.
    private static func enqueue(_ work: @escaping @MainActor () async -> Void) {
        let previous = updates
        updates = Task { @MainActor in
            await previous?.value
            await work()
        }
    }
    #endif
}

/// Works out what the Live Activity says about a workout.
enum WorkoutActivityContent {
    static func state(for session: WorkoutSession, focus: UUID?, rest: ClosedRange<Date>?,
                      metric: Bool) -> WorkoutActivityState {
        let pending = session.exercises.filter { exercise in exercise.sets.contains { !$0.completed } }
        let current = pending.first { $0.id == focus } ?? pending.first
        var exercise = session.exercises.isEmpty ? "Add your first exercise" : "All sets done"
        var detail = ""
        if let current, let set = current.sets.first(where: { !$0.completed }) {
            exercise = current.name
            let working = current.workingSets
            let label = set.isWarmup
                ? "Warm-up"
                : "Set \((working.firstIndex { $0.id == set.id } ?? 0) + 1) of \(working.count)"
            detail = [label, target(of: set, tracking: current.tracking, metric: metric)]
                .compactMap { $0 }
                .joined(separator: " · ")
        }
        return WorkoutActivityState(exercise: exercise, detail: detail,
                                    setsDone: session.completedSetCount, setsTotal: session.totalSetCount,
                                    restStart: rest?.lowerBound, restEnd: rest?.upperBound)
    }

    /// What the set asks for, for example "60 kg × 8", "12 reps" or "0:45".
    static func target(of set: LoggedSet, tracking: TrackingType, metric: Bool) -> String? {
        switch tracking {
        case .weightReps:
            guard set.reps > 0 else { return nil }
            guard set.weightKg > 0 else { return "\(set.reps) reps" }
            return "\(WeightUnit.format(set.weightKg, metric: metric)) \(WeightUnit.label(metric: metric)) × \(set.reps)"
        case .reps:
            return set.reps > 0 ? "\(set.reps) reps" : nil
        case .time:
            guard set.seconds > 0 else { return nil }
            return String(format: "%d:%02d", set.seconds / 60, set.seconds % 60)
        }
    }
}
