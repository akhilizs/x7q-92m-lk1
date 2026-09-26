import ActivityKit
import SwiftUI
import WidgetKit

@main
struct ForgeFitWidgets: WidgetBundle {
    var body: some Widget {
        RestTimerLiveActivity()
    }
}

/// Rest countdown on the Lock Screen and in the Dynamic Island. The countdown and
/// progress bar update on their own, so the app doesn't need to be running.
struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestActivityAttributes.self) { context in
            LockScreenRestView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.9))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Rest", systemImage: "timer")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Countdown(state: context.state, isStale: context.isStale)
                        .font(.title2.weight(.semibold).monospacedDigit())
                        .padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        RestProgress(state: context.state, isStale: context.isStale)
                        Text(nextLine(context.state, isStale: context.isStale))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 6)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(.white)
            } compactTrailing: {
                Countdown(state: context.state, isStale: context.isStale)
                    .monospacedDigit()
                    .frame(maxWidth: 44)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(.white)
            }
            .keylineTint(.white)
        }
    }
}

private struct LockScreenRestView: View {
    let context: ActivityViewContext<RestActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.isStale ? "REST OVER" : "REST")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))
                    Text(context.attributes.workoutName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Spacer()
                Countdown(state: context.state, isStale: context.isStale)
                    .font(.system(size: 40, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
            }
            RestProgress(state: context.state, isStale: context.isStale)
            Text(nextLine(context.state, isStale: context.isStale))
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
        }
        .padding(16)
    }
}

private struct Countdown: View {
    let state: RestActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        if isStale || state.endDate <= state.startDate {
            Text("0:00")
        } else {
            Text(timerInterval: state.startDate...state.endDate, countsDown: true)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct RestProgress: View {
    let state: RestActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        if isStale || state.endDate <= state.startDate {
            ProgressView(value: 0)
                .tint(.white)
        } else {
            ProgressView(timerInterval: state.startDate...state.endDate, countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(.white)
        }
    }
}

private func nextLine(_ state: RestActivityAttributes.ContentState, isStale: Bool) -> String {
    if isStale { return state.nextUp.isEmpty ? "Time for your next set" : "Go: \(state.nextUp)" }
    return state.nextUp.isEmpty ? "Next set coming up" : "Next: \(state.nextUp)"
}
