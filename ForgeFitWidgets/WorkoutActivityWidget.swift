import ActivityKit
import SwiftUI
import WidgetKit

@main
struct ForgeFitWidgets: WidgetBundle {
    var body: some Widget {
        WorkoutActivityWidget()
    }
}

private let openWorkoutURL = URL(string: "forgefit://workout")

/// The workout in progress on the Lock Screen and in the Dynamic Island. Timers and the rest
/// progress bar update on their own, so the app doesn't need to be running.
struct WorkoutActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            LockScreenWorkoutView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.9))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(openWorkoutURL)
        } dynamicIsland: { context in
            let phase = Phase(context)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(phase == .training ? context.attributes.workoutName : phase.title)
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: phase.symbol)
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    MainTimer(context: context, phase: phase)
                        .font(.title2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        ExerciseLines(context: context, phase: phase, compact: true)
                        WorkoutProgress(context: context, phase: phase)
                    }
                    .padding(.horizontal, 6)
                }
            } compactLeading: {
                Image(systemName: phase.symbol)
                    .foregroundStyle(.white)
            } compactTrailing: {
                MainTimer(context: context, phase: phase)
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .frame(maxWidth: 56)
            } minimal: {
                Image(systemName: phase.symbol)
                    .foregroundStyle(.white)
            }
            .widgetURL(openWorkoutURL)
            .keylineTint(.white)
        }
    }
}

/// Training, resting, or a rest that has just run out (the app may not have run since).
private enum Phase {
    case training, resting, restOver

    init(_ context: ActivityViewContext<WorkoutActivityAttributes>) {
        let state = context.state
        guard let start = state.restStart, let end = state.restEnd, end > start else {
            self = .training
            return
        }
        self = context.isStale ? .restOver : .resting
    }

    var title: String {
        switch self {
        case .training: return "Workout"
        case .resting: return "Rest"
        case .restOver: return "Rest over"
        }
    }

    var symbol: String {
        switch self {
        case .training: return "dumbbell.fill"
        case .resting: return "timer"
        case .restOver: return "bell.fill"
        }
    }
}

private struct LockScreenWorkoutView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        let phase = Phase(context)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Label(phase.title.uppercased(), systemImage: phase.symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))
                    Text(context.attributes.workoutName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Spacer()
                MainTimer(context: context, phase: phase)
                    .font(.system(size: phase == .resting ? 40 : 30, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
            }
            ExerciseLines(context: context, phase: phase, compact: false)
            WorkoutProgress(context: context, phase: phase)
        }
        .padding(16)
    }
}

/// The rest countdown while resting, otherwise how long the workout has been going.
private struct MainTimer: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>
    let phase: Phase

    var body: some View {
        if phase == .resting, let start = context.state.restStart, let end = context.state.restEnd {
            Text(timerInterval: start...end, countsDown: true)
                .multilineTextAlignment(.trailing)
        } else {
            Text(context.attributes.startedAt, style: .timer)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct ExerciseLines: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>
    let phase: Phase
    let compact: Bool

    var body: some View {
        let state = context.state
        VStack(alignment: .leading, spacing: 2) {
            Text(prefix + state.exercise)
                .font((compact ? Font.subheadline : Font.headline).weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            if !state.detail.isEmpty {
                Text(state.detail)
                    .font(compact ? .caption : .footnote)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
        }
    }

    private var prefix: String {
        switch phase {
        case .training: return ""
        case .resting: return "Next: "
        case .restOver: return "Go: "
        }
    }
}

/// The rest draining while resting, otherwise sets done out of the workout's total.
private struct WorkoutProgress: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>
    let phase: Phase

    var body: some View {
        let state = context.state
        if phase == .resting, let start = state.restStart, let end = state.restEnd {
            ProgressView(timerInterval: start...end, countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(.white)
        } else {
            HStack(spacing: 10) {
                ProgressView(value: Double(min(state.setsDone, state.setsTotal)), total: Double(max(state.setsTotal, 1)))
                    .tint(.white)
                Text("\(state.setsDone)/\(state.setsTotal) sets")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}
