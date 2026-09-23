import SwiftUI

struct HomeView: View {
    @Environment(AppStore.self) private var store
    @Binding var selection: AppTab
    @State private var showGenerator = false
    @State private var showBuilder = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    WeekSummaryCards()
                    UpNextCard()
                    planDays
                    coachCard
                    quickActions
                    recentWorkouts
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .appBackground()
            .toolbar(.hidden, for: .navigationBar)
            .resumeWorkoutBar()
            .sheet(isPresented: $showGenerator) { GeneratePlanView().environment(store) }
            .sheet(isPresented: $showBuilder) { PlanBuilderView(existing: nil).environment(store) }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingText)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                Text(store.profile.firstName.isEmpty ? "Hi there" : "Hi, \(store.profile.firstName)")
                    .font(.system(size: 26, weight: .medium))
                    .lineLimit(1)
            }
            Spacer()
            Button {
                selection = .profile
            } label: {
                Text(initials)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(Theme.tint(for: store.profile.goal)))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Open profile")
        }
        .padding(.top, 12)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning, fit human"
        case 12..<17: return "Good afternoon, fit human"
        default: return "Good evening, fit human"
        }
    }

    private var initials: String {
        let letters = store.profile.name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
        return letters.isEmpty ? "FF" : letters.uppercased()
    }

    // MARK: Plan days

    @ViewBuilder
    private var planDays: some View {
        if let plan = store.activePlan {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Your plan", actionTitle: "See all") { selection = .plans }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(plan.days.enumerated()), id: \.element.id) { index, day in
                            NavigationLink {
                                PlanDetailView(planID: plan.id)
                            } label: {
                                DayCard(day: day, index: index, color: Theme.pastel(index))
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.horizontal, -20)
            }
        }
    }

    // MARK: Coach

    private var coachCard: some View {
        Button {
            selection = .coach
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                InkTag(text: "AI Coach", symbol: "sparkles")
                Text("Talk to your coach")
                    .font(.system(size: 22, weight: .medium))
                    .italic()
                Text("Sore knees? No time? Stalled? Tell your coach and it adapts your plan.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: 210, alignment: .leading)
                HStack(spacing: 6) {
                    Text("Start chatting")
                    Image(systemName: "arrow.right")
                }
                .font(.footnote.weight(.semibold))
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .overlay(alignment: .bottomTrailing) {
                FigureArt(symbol: "figure.mind.and.body", size: 92)
                    .offset(x: 10, y: 14)
            }
            .pastelCard(Theme.lilac)
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Quick actions

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Quick actions")
            HStack(spacing: 12) {
                QuickAction(symbol: "sparkles", title: "Generate\nplan") { showGenerator = true }
                QuickAction(symbol: "hammer.fill", title: "Build\nyour own") { showBuilder = true }
                QuickAction(symbol: "bolt.fill", title: "Quick\nworkout") {
                    if store.activeSession == nil {
                        store.startEmptyWorkout()
                    } else {
                        store.isWorkoutPresented = true
                    }
                }
            }
        }
    }

    // MARK: Recent

    @ViewBuilder
    private var recentWorkouts: some View {
        if !store.sessions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Recent workouts", actionTitle: "See all") { selection = .progress }
                ForEach(store.sessions.prefix(3)) { session in
                    NavigationLink {
                        SessionDetailView(sessionID: session.id)
                    } label: {
                        SessionRow(session: session)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }
}

private struct QuickAction: View {
    let symbol: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                IconBadge(symbol: symbol, size: 38)
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(padding: 14, radius: 22)
        }
        .buttonStyle(PressableStyle())
    }
}

/// Pastel card for one training day ("Triceps Bench Dips" style).
struct DayCard: View {
    let day: WorkoutDay
    let index: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            InkTag(text: "Day \(index + 1)")
            Text(day.name)
                .font(.system(size: 20, weight: .medium))
                .italic()
                .lineLimit(1)
            Text(day.focus)
                .font(.caption)
                .foregroundStyle(Theme.inkSecondary)
                .lineLimit(1)
                .frame(maxWidth: 150, alignment: .leading)
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                InkMeta(symbol: "list.bullet", text: "\(day.exercises.count) ex")
                InkMeta(symbol: "clock", text: "~\(day.estimatedMinutes) min")
            }
        }
        .frame(width: 210, height: 150, alignment: .topLeading)
        .overlay(alignment: .topTrailing) {
            FigureArt(symbol: Theme.figure(for: day.muscles.first), size: 70)
                .offset(x: 14, y: 26)
        }
        .pastelCard(color)
    }
}

// MARK: - Weekly summary

private struct WeekSummaryCards: View {
    @Environment(AppStore.self) private var store

    private let dayLetters = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        let metric = store.profile.useMetric
        let daily = store.dailyVolumeThisWeek
        let maxDaily = max(daily.max() ?? 0, 1)
        let lastWeek = store.volumeLastWeekKg
        let thisWeek = store.volumeThisWeekKg
        let volumeProgress = lastWeek > 0 ? thisWeek / lastWeek : (thisWeek > 0 ? 1 : 0)
        let targetMinutes = Double(store.profile.daysPerWeek * store.profile.sessionMinutes)
        let minutes = store.minutesThisWeek
        let trained = store.trainedDaysThisWeek
        VStack(spacing: 12) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Workouts", systemImage: "figure.strengthtraining.traditional")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(store.workoutsThisWeek)")
                            .font(.system(size: 34, weight: .semibold).monospacedDigit())
                        Text("/ \(store.profile.daysPerWeek) this week")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(0..<7, id: \.self) { i in
                        VStack(spacing: 5) {
                            Capsule()
                                .fill(trained.contains(i) ? Color.white : Color.white.opacity(0.12))
                                .frame(width: 7, height: trained.contains(i) ? max(14, 46 * daily[i] / maxDaily) : 8)
                            Text(dayLetters[i])
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(i == store.todayIndex ? Color.white : Theme.textTertiary)
                        }
                    }
                }
                .frame(height: 64, alignment: .bottom)
            }
            .cardStyle(padding: 16, radius: 24)

            HStack(spacing: 12) {
                RingStatCard(title: "Volume",
                             value: Format.compact(WeightUnit.display(thisWeek, metric: metric)),
                             unit: "\(WeightUnit.label(metric: metric)) this week",
                             progress: volumeProgress, color: Theme.orange)
                RingStatCard(title: "Time",
                             value: Format.minutes(minutes * 60),
                             unit: "of \(Int(targetMinutes)) min goal",
                             progress: targetMinutes > 0 ? minutes / targetMinutes : 0, color: Theme.blue)
            }
        }
    }
}

private struct RingStatCard: View {
    let title: String
    let value: String
    let unit: String
    let progress: Double
    let color: Color

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
                Text(value)
                    .font(.system(size: 22, weight: .semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            RingView(progress: progress, color: color, lineWidth: 5, size: 40)
        }
        .cardStyle(padding: 14, radius: 22)
    }
}

// MARK: - Up next

/// Photo card showing the next workout from the active plan.
struct UpNextCard: View {
    @Environment(AppStore.self) private var store
    @State private var showGenerator = false

    var body: some View {
        if let plan = store.activePlan, let day = plan.nextDay {
            ZStack(alignment: .bottomLeading) {
                PhotoBackdrop(name: "WorkoutLift", gradientStart: 0.05)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Up next · Day \(min(plan.nextDayIndex, plan.days.count - 1) + 1) of \(plan.days.count)")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(.ultraThinMaterial, in: Capsule())
                        Spacer()
                        Menu {
                            ForEach(Array(plan.days.enumerated()), id: \.element.id) { index, d in
                                Button(d.name) { store.setNextDay(planID: plan.id, index: index) }
                            }
                        } label: {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: 34, height: 34)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .accessibilityLabel("Change day")
                    }
                    Spacer()
                    Text(day.name)
                        .font(.system(size: 30, weight: .semibold))
                    Text(day.focus)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                    HStack(spacing: 12) {
                        Label("\(day.exercises.count) exercises", systemImage: "list.bullet")
                        Label("~\(day.estimatedMinutes) min", systemImage: "clock")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.bottom, 6)
                    Button {
                        if store.activeSession != nil {
                            store.isWorkoutPresented = true
                        } else {
                            store.startWorkout(day: day, plan: plan)
                        }
                        Haptics.medium()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: store.activeSession == nil ? "play.fill" : "arrow.uturn.forward")
                            Text(store.activeSession == nil ? "Start Workout" : "Resume Workout")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .foregroundStyle(.white)
                .padding(18)
            }
            .frame(height: 330)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(Theme.stroke))
        } else {
            EmptyStateView(symbol: "list.bullet.clipboard", title: "No active plan",
                           message: "Generate a plan for your goal and equipment, or build your own.",
                           actionTitle: "Create a plan") { showGenerator = true }
                .sheet(isPresented: $showGenerator) { GeneratePlanView().environment(store) }
        }
    }
}

struct SessionRow: View {
    @Environment(AppStore.self) private var store
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 1) {
                Text(dayNumber).font(.system(size: 19, weight: .semibold))
                Text(monthShort).font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.textSecondary)
            }
            .foregroundStyle(.white)
            .frame(width: 50, height: 54)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surfaceHigh))

            VStack(alignment: .leading, spacing: 5) {
                Text(session.name).font(.system(size: 16, weight: .medium)).foregroundStyle(.white)
                HStack(spacing: 10) {
                    Label(Format.minutes(session.duration), systemImage: "clock")
                    Label("\(session.completedSetCount) sets", systemImage: "square.stack.3d.up")
                    if session.totalVolumeKg > 0 {
                        Label(Format.compact(WeightUnit.display(session.totalVolumeKg, metric: store.profile.useMetric))
                              + " " + WeightUnit.label(metric: store.profile.useMetric),
                              systemImage: "scalemass")
                    }
                }
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .labelStyle(CompactLabelStyle())
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textTertiary)
        }
        .cardStyle(padding: 12, radius: 22)
    }

    private var dayNumber: String {
        String(Calendar.current.component(.day, from: session.startedAt))
    }

    private var monthShort: String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: session.startedAt).uppercased()
    }
}

struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon
            configuration.title
        }
    }
}
