import SwiftUI

/// "Today": the next workout first, then the week, food, coach, plan and history.
struct HomeView: View {
    @Environment(AppStore.self) private var store
    @Environment(CoachViewModel.self) private var coach
    @Binding var selection: AppTab

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if store.isCheckInDue && store.hasAPIKey {
                        checkInBanner
                    }
                    TodayCard()
                    WeekCard()
                    NutritionHomeCard()
                    coachBar
                    planDays
                    recentWorkouts
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .appBackground()
            .toolbar(.hidden, for: .navigationBar)
            .resumeWorkoutBar()
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                selection = .profile
            } label: {
                Text(initials)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.surfaceRaised))
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Open profile")
            VStack(alignment: .leading, spacing: 2) {
                Text("Welcome back")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                Text(store.profile.firstName.isEmpty ? "Athlete" : store.profile.firstName)
                    .font(.display(18))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            Spacer()
            if store.weekStreak > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                    Text(store.weekStreak == 1 ? "1-week streak" : "\(store.weekStreak)-week streak")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.volt)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Theme.surface))
                .overlay(Capsule().strokeBorder(Theme.stroke))
            }
        }
        .padding(.top, 10)
    }

    private var initials: String {
        let letters = store.profile.name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
        return letters.isEmpty ? "FF" : letters.uppercased()
    }

    // MARK: Weekly check-in

    private var checkInBanner: some View {
        Button {
            selection = .coach
            coach.startWeeklyCheckIn(store: store)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "checklist")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Theme.volt))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Weekly check-in ready")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Let your coach review the week")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.volt)
            }
            .graphiteCard(padding: 12, radius: 22, highlighted: true)
        }
        .buttonStyle(PressableStyle())
        .disabled(coach.isResponding)
        .accessibilityLabel("Start weekly check-in")
    }

    // MARK: Coach

    private var coachBar: some View {
        Button {
            selection = .coach
        } label: {
            HStack(spacing: 12) {
                CoachOrb(size: 34)
                Text("Ask your coach anything…")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Image(systemName: "arrow.up")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Theme.volt))
            }
            .padding(.leading, 8)
            .padding(.trailing, 10)
            .padding(.vertical, 8)
            .background(Capsule().fill(Theme.surface))
            .overlay(Capsule().strokeBorder(Theme.stroke))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Ask your coach")
    }

    // MARK: Plan days

    @ViewBuilder
    private var planDays: some View {
        if let plan = store.activePlan, plan.days.count > 1 {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Your plan", actionTitle: "See all") { selection = .plans }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(plan.days.enumerated()), id: \.element.id) { index, day in
                            NavigationLink {
                                PlanDetailView(planID: plan.id)
                            } label: {
                                DayCard(day: day, index: index,
                                        isNext: index == min(plan.nextDayIndex, plan.days.count - 1))
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

    // MARK: Recent

    @ViewBuilder
    private var recentWorkouts: some View {
        if !store.sessions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Recent", actionTitle: "See all") { selection = .progress }
                ForEach(store.sessions.prefix(2)) { session in
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

// MARK: - Today

/// The next workout, front and centre: start it, or start an empty session.
private struct TodayCard: View {
    @Environment(AppStore.self) private var store
    @State private var showGenerator = false

    var body: some View {
        if let plan = store.activePlan, let day = plan.nextDay {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Day \(min(plan.nextDayIndex, plan.days.count - 1) + 1) of \(plan.days.count)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.volt)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Theme.ink))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Today's workout")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Theme.inkSecondary)
                            Text(day.name)
                                .font(.display(26))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text(day.focus)
                                .font(.subheadline)
                                .foregroundStyle(Theme.inkSecondary)
                                .lineLimit(1)
                        }
                        HStack(spacing: 6) {
                            pill("\(day.exercises.count) exercises", symbol: "list.bullet")
                            pill("~\(day.estimatedMinutes) min", symbol: "clock")
                        }
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 6) {
                        Menu {
                            ForEach(Array(plan.days.enumerated()), id: \.element.id) { index, d in
                                Button(d.name) { store.setNextDay(planID: plan.id, index: index) }
                            }
                        } label: {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(Theme.ink.opacity(0.1)))
                        }
                        .accessibilityLabel("Change day")
                        MuscleMapView(exercises: day.exercises, style: .onAccent)
                            .frame(width: 70, height: 92)
                    }
                }
                HStack(spacing: 10) {
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
                    .buttonStyle(InkButtonStyle())
                    if store.activeSession == nil {
                        Button {
                            store.startEmptyWorkout()
                            Haptics.medium()
                        } label: {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                                .frame(width: 52, height: 52)
                                .background(Circle().strokeBorder(Theme.ink.opacity(0.3), lineWidth: 1.2))
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel("Start an empty workout")
                    }
                }
            }
            .foregroundStyle(Theme.ink)
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Theme.volt))
        } else {
            VStack(alignment: .leading, spacing: 12) {
                VoltTag(text: "No plan yet", symbol: "sparkles", filled: true)
                Text("Let's build your plan")
                    .font(.display(22))
                    .foregroundStyle(.white)
                Text("Generate one for your goal and equipment, or start an empty workout and log as you go.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                HStack(spacing: 10) {
                    Button("Create a plan") { showGenerator = true }
                        .buttonStyle(PrimaryButtonStyle())
                    Button {
                        store.startEmptyWorkout()
                    } label: {
                        Image(systemName: "bolt.fill")
                            .frame(width: 56, height: 56)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.16)))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("Start an empty workout")
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .graphiteCard(padding: 18, radius: 28, highlighted: true)
            .sheet(isPresented: $showGenerator) { GeneratePlanView().environment(store) }
        }
    }
}

extension TodayCard {
    fileprivate func pill(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.caption.weight(.medium))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().strokeBorder(Theme.ink.opacity(0.25), lineWidth: 1))
    }
}

// MARK: - This week

/// Days trained this week, volume and time, in one card.
private struct WeekCard: View {
    @Environment(AppStore.self) private var store
    @State private var appeared = false
    private let letters = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        let metric = store.profile.useMetric
        let trained = store.trainedDaysThisWeek
        let today = store.todayIndex
        let thisWeek = store.volumeThisWeekKg
        let lastWeek = store.volumeLastWeekKg
        let targetMinutes = Double(store.profile.daysPerWeek * store.profile.sessionMinutes)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("This week").font(.display(15, weight: .bold))
                Spacer()
                Text("\(store.workoutsThisWeek) of \(store.profile.daysPerWeek) workouts")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
            }
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    let done = trained.contains(i)
                    VStack(spacing: 5) {
                        ZStack {
                            Circle().fill(done ? Theme.volt : Color.white.opacity(0.04))
                            Circle().strokeBorder(i == today && !done ? Theme.volt : Color.white.opacity(done ? 0 : 0.12),
                                                  lineWidth: 1.5)
                            if done {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .heavy))
                                    .foregroundStyle(Theme.ink)
                            }
                        }
                        .frame(width: 32, height: 32)
                        // Fade in one after another when the screen opens.
                        .scaleEffect(appeared ? 1 : 0.85)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(Double(i) * 0.04), value: appeared)
                        Text(letters[i])
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(i == today ? Theme.volt : Theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Rectangle().fill(Theme.stroke).frame(height: 1)
            HStack(alignment: .top, spacing: 16) {
                stat(title: "Volume",
                     value: "\(Format.compact(WeightUnit.display(thisWeek, metric: metric))) \(WeightUnit.label(metric: metric))",
                     detail: volumeDetail(thisWeek: thisWeek, lastWeek: lastWeek),
                     progress: lastWeek > 0 ? thisWeek / lastWeek : (thisWeek > 0 ? 1 : 0))
                stat(title: "Time",
                     value: Format.minutes(store.minutesThisWeek * 60),
                     detail: "of \(Int(targetMinutes)) min goal",
                     progress: targetMinutes > 0 ? store.minutesThisWeek / targetMinutes : 0)
            }
        }
        .graphiteCard(padding: 14, radius: 26)
        .accessibilityElement(children: .combine)
        .onAppear { appeared = true }
    }

    private func stat(title: String, value: String, detail: String, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).eyebrow()
            Text(value)
                .font(.metric(18))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            ProgressBar(value: min(progress, 1), height: 4)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func volumeDetail(thisWeek: Double, lastWeek: Double) -> String {
        guard lastWeek > 0 else { return thisWeek > 0 ? "first week tracked" : "no lifting yet" }
        let change = Int(((thisWeek / lastWeek) - 1) * 100)
        return change >= 0 ? "+\(change)% vs last week" : "\(change)% vs last week"
    }
}

// MARK: - Nutrition

/// Today's calories and protein, with a shortcut to snap a meal.
private struct NutritionHomeCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        let totals = NutritionTotals(meals: store.meals(on: Date()))
        let targets = store.nutritionTargets
        HStack(spacing: 12) {
            NavigationLink {
                NutritionView()
            } label: {
                HStack(spacing: 14) {
                    RingView(progress: Double(totals.calories) / Double(max(targets.calories, 1)),
                             color: Theme.volt, lineWidth: 5, size: 46)
                        .overlay(Image(systemName: "fork.knife").font(.system(size: 13, weight: .semibold)))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Today's fuel")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.textSecondary)
                        Text("\(totals.calories) / \(targets.calories) kcal")
                            .font(.metric(15))
                            .foregroundStyle(.white)
                        Text("\(Int(totals.proteinG)) / \(targets.proteinG) g protein")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Nutrition, \(totals.calories) of \(targets.calories) calories today")

            NavigationLink {
                NutritionView(startWith: .snap)
            } label: {
                Image(systemName: "camera.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.volt))
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Snap a meal")
        }
        .graphiteCard(padding: 14, radius: 26)
    }
}

// MARK: - Shared rows

/// One training day: name, focus and the muscles it hits.
struct DayCard: View {
    let day: WorkoutDay
    let index: Int
    var isNext = false

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            VStack(alignment: .leading, spacing: 8) {
                VoltTag(text: isNext ? "Up next" : "Day \(index + 1)", symbol: isNext ? "arrow.right" : nil, filled: isNext)
                Text(day.name)
                    .font(.display(16))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(day.focus)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    MetaLabel(symbol: "list.bullet", text: "\(day.exercises.count) ex")
                    MetaLabel(symbol: "clock", text: "~\(day.estimatedMinutes)m")
                }
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            MuscleMapView(exercises: day.exercises)
                .frame(width: 70, height: 112)
        }
        .frame(width: 236, height: 132)
        .graphiteCard(padding: 14, radius: 24, highlighted: isNext)
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
