import SwiftUI

struct HomeView: View {
    @Environment(AppStore.self) private var store
    @Binding var selection: AppTab
    @State private var showGenerator = false
    @State private var showBuilder = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    greeting
                    UpNextCard()
                    WeekStrip()
                    statsRow
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

    private var greeting: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Format.dayMonth.string(from: Date()).uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
                Text(greetingText)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(Theme.warmGradient)
                Text("\(store.weekStreak)")
                    .font(.system(.headline, design: .rounded).weight(.bold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Capsule().fill(Theme.surface))
            .overlay(Capsule().strokeBorder(Theme.stroke))
        }
        .padding(.top, 12)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let part: String
        switch hour {
        case 5..<12: part = "Good morning"
        case 12..<17: part = "Good afternoon"
        default: part = "Good evening"
        }
        let name = store.profile.firstName
        return name.isEmpty ? part : "\(part), \(name)"
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatTile(value: "\(store.workoutsThisWeek)/\(store.profile.daysPerWeek)", label: "This week",
                     symbol: "checkmark.circle.fill", tint: Theme.accent)
            StatTile(value: Format.compact(WeightUnit.display(store.volumeThisWeekKg, metric: store.profile.useMetric)),
                     label: "Volume (\(WeightUnit.label(metric: store.profile.useMetric)))",
                     symbol: "scalemass.fill", tint: Theme.blue)
            StatTile(value: "\(store.sessions.count)", label: "Workouts", symbol: "trophy.fill", tint: Theme.orange)
        }
    }

    private var coachCard: some View {
        Button {
            selection = .coach
        } label: {
            HStack(spacing: 16) {
                CoachOrb(size: 54)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Coach Forge").font(.headline)
                        AIBadge()
                    }
                    Text("Struggling with something? Tell your coach and it'll adjust your plan.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LinearGradient(colors: [Theme.violet.opacity(0.28), Theme.blue.opacity(0.12)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .glowBorder(Theme.aiGradient, radius: 24, width: 1)
        }
        .buttonStyle(PressableStyle())
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Quick actions")
            HStack(spacing: 12) {
                QuickAction(symbol: "wand.and.stars", title: "Generate\nplan", gradient: Theme.aiGradient) {
                    showGenerator = true
                }
                QuickAction(symbol: "hammer.fill", title: "Build\nyour own", gradient: Theme.warmGradient) {
                    showBuilder = true
                }
                QuickAction(symbol: "bolt.fill", title: "Quick\nworkout", gradient: Theme.accentGradient) {
                    if store.activeSession == nil {
                        store.startEmptyWorkout()
                    } else {
                        store.isWorkoutPresented = true
                    }
                }
            }
        }
    }

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
    let gradient: LinearGradient
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                GradientIcon(symbol: symbol, gradient: gradient, size: 38, foreground: .white)
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(padding: 14, radius: 20)
        }
        .buttonStyle(PressableStyle())
    }
}

/// Hero card showing the next workout from the active plan.
struct UpNextCard: View {
    @Environment(AppStore.self) private var store
    @State private var showGenerator = false

    var body: some View {
        if let plan = store.activePlan, let day = plan.nextDay {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("UP NEXT · DAY \(min(plan.nextDayIndex, plan.days.count - 1) + 1) OF \(plan.days.count)")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.black.opacity(0.7))
                    Spacer()
                    Menu {
                        ForEach(Array(plan.days.enumerated()), id: \.element.id) { index, d in
                            Button(d.name) { store.setNextDay(planID: plan.id, index: index) }
                        }
                    } label: {
                        Text("Change")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(.black.opacity(0.12)))
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(day.name)
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(.black)
                    Text(day.focus)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.black.opacity(0.7))
                        .lineLimit(1)
                }
                HStack(spacing: 8) {
                    heroPill("\(day.exercises.count) exercises", symbol: "list.bullet")
                    heroPill("~\(day.estimatedMinutes) min", symbol: "clock.fill")
                    heroPill(plan.source.shortLabel, symbol: plan.source.symbol)
                }
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(day.exercises.prefix(4)) { item in
                        HStack {
                            Circle().fill(.black.opacity(0.5)).frame(width: 5, height: 5)
                            Text(item.name).font(.subheadline.weight(.medium))
                            Spacer()
                            Text(item.targetLabel).font(.caption.weight(.semibold)).monospacedDigit()
                        }
                        .foregroundStyle(.black.opacity(0.8))
                    }
                    if day.exercises.count > 4 {
                        Text("+ \(day.exercises.count - 4) more")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.black.opacity(0.55))
                    }
                }
                Button {
                    if store.activeSession != nil {
                        store.isWorkoutPresented = true
                    } else {
                        store.startWorkout(day: day, plan: plan)
                    }
                    Haptics.medium()
                } label: {
                    HStack {
                        Image(systemName: store.activeSession == nil ? "play.fill" : "arrow.uturn.forward")
                        Text(store.activeSession == nil ? "Start Workout" : "Resume Workout")
                    }
                }
                .buttonStyle(PrimaryButtonStyle(gradient: LinearGradient(colors: [.black], startPoint: .top, endPoint: .bottom),
                                                foreground: Theme.accent))
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Theme.accentGradient)
            )
            .overlay(alignment: .topTrailing) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 120, weight: .black))
                    .foregroundStyle(.black.opacity(0.06))
                    .rotationEffect(.degrees(-20))
                    .offset(x: 20, y: 30)
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: Theme.accent.opacity(0.25), radius: 24, y: 10)
        } else {
            EmptyStateView(symbol: "list.bullet.clipboard.fill", title: "No active plan",
                           message: "Generate a plan for your goal and equipment, or build your own.",
                           actionTitle: "Create a plan") { showGenerator = true }
                .sheet(isPresented: $showGenerator) { GeneratePlanView().environment(store) }
        }
    }

    private func heroPill(_ text: String, symbol: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
            Text(text).lineLimit(1)
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(.black.opacity(0.8))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(.black.opacity(0.1)))
    }
}

struct WeekStrip: View {
    @Environment(AppStore.self) private var store

    private let labels = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        let trained = store.trainedDaysThisWeek
        let today = todayIndex
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                VStack(spacing: 8) {
                    Text(labels[index])
                        .font(.caption.weight(.bold))
                        .foregroundStyle(index == today ? Theme.accent : Theme.textSecondary)
                    ZStack {
                        Circle()
                            .fill(trained.contains(index) ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Color.white.opacity(0.06)))
                            .frame(width: 34, height: 34)
                        if trained.contains(index) {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(.black)
                        } else if index == today {
                            Circle().strokeBorder(Theme.accent, lineWidth: 2).frame(width: 34, height: 34)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .cardStyle(padding: 14)
    }

    private var todayIndex: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return (weekday + 5) % 7
    }
}

struct SessionRow: View {
    @Environment(AppStore.self) private var store
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(dayNumber).font(.system(.title3, design: .rounded).weight(.bold))
                Text(monthShort).font(.caption2.weight(.bold)).foregroundStyle(Theme.textSecondary)
            }
            .frame(width: 50, height: 54)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surfaceRaised))

            VStack(alignment: .leading, spacing: 4) {
                Text(session.name).font(.headline).foregroundStyle(.white)
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
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.textTertiary)
        }
        .cardStyle(padding: 12, radius: 20)
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
