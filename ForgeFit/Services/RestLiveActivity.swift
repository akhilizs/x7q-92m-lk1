import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Starts, updates and ends the rest-timer Live Activity.
@MainActor
enum RestLiveActivity {
    static func start(end: Date, nextUp: String, workoutName: String) {
        #if canImport(ActivityKit)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = RestActivityAttributes.ContentState(startDate: Date(), endDate: end, nextUp: nextUp)
        let content = ActivityContent(state: state, staleDate: end)
        if let current = Activity<RestActivityAttributes>.activities.first {
            Task { await current.update(content) }
            return
        }
        _ = try? Activity.request(attributes: RestActivityAttributes(workoutName: workoutName),
                                  content: content, pushType: nil)
        #endif
    }

    /// Moves the end time (for the ±15 s buttons).
    static func update(end: Date, nextUp: String) {
        #if canImport(ActivityKit)
        for activity in Activity<RestActivityAttributes>.activities {
            var state = activity.content.state
            state.endDate = max(end, state.startDate)
            state.nextUp = nextUp
            Task { await activity.update(ActivityContent(state: state, staleDate: end)) }
        }
        #endif
    }

    static func stop() {
        #if canImport(ActivityKit)
        for activity in Activity<RestActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
        #endif
    }

    /// Ends timers that ran out while the app was in the background.
    static func endFinished() {
        #if canImport(ActivityKit)
        for activity in Activity<RestActivityAttributes>.activities where activity.content.state.endDate <= Date() {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
        #endif
    }
}
