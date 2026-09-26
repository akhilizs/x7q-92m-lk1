import SwiftUI

extension Badge.Tone {
    var color: Color {
        switch self {
        case .paper: return Theme.paper
        case .sky: return Theme.sky
        case .rose: return Theme.rose
        case .sand: return Theme.sand
        case .lilac: return Theme.lilac
        case .sage: return Theme.sage
        }
    }
}

struct BadgeMedal: View {
    let badge: Badge
    let earned: Bool
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            Circle()
                .fill(earned ? AnyShapeStyle(badge.tone.color) : AnyShapeStyle(Theme.surfaceRaised))
            Circle()
                .strokeBorder(earned ? Color.white.opacity(0.6) : Theme.stroke, lineWidth: 2)
                .padding(3)
            Image(systemName: badge.symbol)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(earned ? Theme.ink : Theme.textTertiary)
        }
        .frame(width: size, height: size)
        .shadow(color: earned ? badge.tone.color.opacity(0.35) : .clear, radius: 10)
    }
}

/// Badge preview on the Progress tab.
struct BadgesSection: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        let statuses = store.badgeStatuses
        let earned = statuses.filter(\.isEarned)
        let next = statuses.filter { !$0.isEarned }.sorted { $0.fraction > $1.fraction }
        let preview = Array((earned.suffix(3) + next.prefix(4 - min(earned.count, 3))).prefix(4))
        NavigationLink {
            BadgesView()
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Badges", systemImage: "rosette")
                        .font(.headline)
                    Spacer()
                    Text("\(earned.count)/\(statuses.count)")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
                HStack(spacing: 0) {
                    ForEach(preview) { status in
                        VStack(spacing: 6) {
                            BadgeMedal(badge: status.badge, earned: status.isEarned, size: 54)
                            Text(status.badge.title)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(status.isEarned ? .white : Theme.textTertiary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .cardStyle()
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Badges, \(earned.count) of \(statuses.count) earned")
    }
}

struct BadgesView: View {
    @Environment(AppStore.self) private var store
    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 14)]

    var body: some View {
        let statuses = store.badgeStatuses
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 52, height: 52)
                        .background(Circle().fill(Theme.orange))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.weekStreak == 1 ? "1-week streak" : "\(store.weekStreak)-week streak")
                            .font(.system(size: 20, weight: .semibold))
                        Text("Weeks in a row with at least one workout.")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .cardStyle()

                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(statuses) { status in
                        VStack(spacing: 8) {
                            BadgeMedal(badge: status.badge, earned: status.isEarned, size: 68)
                            Text(status.badge.title)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(status.isEarned ? .white : Theme.textSecondary)
                                .multilineTextAlignment(.center)
                            Text(status.badge.detail)
                                .font(.caption2)
                                .foregroundStyle(Theme.textTertiary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            if !status.isEarned && status.target > 1 {
                                ProgressBar(value: status.fraction)
                                    .frame(width: 70)
                                Text(progressText(status))
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .padding(20)
        }
        .appBackground()
        .navigationTitle("Badges")
        .resumeWorkoutBar()
    }

    private func progressText(_ status: BadgeStatus) -> String {
        let metric = store.profile.useMetric
        if status.badge.id.hasPrefix("volume") {
            return "\(Format.compact(WeightUnit.display(status.current, metric: metric))) / \(Format.compact(WeightUnit.display(status.target, metric: metric)))"
        }
        if ["bench", "squat", "deadlift"].contains(where: { status.badge.id.hasPrefix($0) }) {
            let unit = WeightUnit.label(metric: metric)
            return "\(WeightUnit.format(status.current, metric: metric, decimals: 0)) / \(WeightUnit.format(status.target + 0.5, metric: metric, decimals: 0)) \(unit)"
        }
        return "\(Int(status.current)) / \(Int(status.target))"
    }
}
