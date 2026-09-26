import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// The rest timer shown on the Lock Screen and in the Dynamic Island.
/// Shared by the app (which starts it) and the widget extension (which draws it).
struct RestActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startDate: Date
        var endDate: Date
        /// The exercise to do after resting.
        var nextUp: String
    }

    var workoutName: String
}
#endif
