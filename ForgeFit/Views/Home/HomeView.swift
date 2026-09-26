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
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.textTertiary)
                Text(store.profile.firstName.isEmpty ? "Hi there" : "Hi, \(store.profile.firstName)")
                    .font(.system(size: 32, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if store.weekStreak > 0 {
                    HStack(spacing: 5) {
                        Image(systemName: "flame.fill")
                        Text(store.weekStreak == 1 ? "1-week streak" : "\(store.weekStreak)-week streak")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Theme.sand))
                    .padding(.top, 2)
                }
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
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.55)))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Weekly check-in ready")
                        .font(.subheadline.weight(.semibold))
                    Text("Let your coach review the week")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.right")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(Theme.ink)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.sky))
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
                    .background(Circle().fill(Theme.lilac))
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
                                DayCard(day: day, index: index, color: Theme.pastel(index),
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
            ZStack(alignment: .bottomLeading) {
                PhotoBackdrop(name: "WorkoutLift", gradientStart: 0.0)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("TODAY · DAY \(min(plan.nextDayIndex, plan.days.count - 1) + 1) OF \(plan.days.count)")
                            .font(.caption2.weight(.bold))
                            .tracking(0.6)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                        Spacer()
                        Menu {
                            ForEach(Array(plan.days.enumerated()), id: \.element.id) { index, d in
                                Button(d.name) { store.setNextDay(planID: plan.id, index: index) }
                            }
                        } label: {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 12, weight: .semibold))
                                .frame(width: 32, height: 32)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .accessibilityLabel("Change day")
                    }
                    Spacer()
                    Text(day.name)
                        .font(.system(size: 34, weight: .medium))
                        .italic()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    HStack(spacing: 12) {
                        Text(day.focus).lineLimit(1)
                        Text("·")
                        Text("\(day.exercises.count) exercises")
                        Text("·")
                        Text("~\(day.estimatedMinutes) min")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.bottom, 6)
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
                        .buttonStyle(PrimaryButtonStyle())
                        if store.activeSession == nil {
                            Button {
                                store.startEmptyWorkout()
                                Haptics.medium()
                            } label: {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 17, weight: .semibold))
                                    .frame(width: 56, height: 56)
                                    .background(.ultraThinMaterial, in: Circle())
                                    .overlay(Circle().strokeBorder(Color.white.opacity(0.2)))
                            }
                            .buttonStyle(PressableStyle())
                            .accessibilityLabel("Start an empty workout")
                        }
                    }
                }
                .foregroundStyle(.white)
                .padding(18)
            }
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(Theme.stroke))
        } else {
            VStack(alignment: .leading, spacing: 12) {
                InkTag(text: "No plan yet", symbol: "sparkles")
                Text("Let's build your plan")
                    .font(.system(size: 26, weight: .medium))
                    .italic()
                Text("Generate one for your goal and equipment, or start an empty workout and log as you go.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
                HStack(spacing: 10) {
                    Button("Create a plan") { showGenerator = true }
                        .buttonStyle(DarkCapsuleButtonStyle())
                    Button {
                        store.startEmptyWorkout()
                    } label: {
                        Image(systemName: "bolt.fill")
                            .frame(width: 54, height: 54)
                            .background(Circle().fill(Theme.ink))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("Start an empty workout")
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .pastelCard(Theme.lilac)
            .sheet(isPresented: $showGenerator) { GeneratePlanView().environment(store) }
        }
    }
}

// MARK: - This week

/// Days trained this week, volume and time, in one card.
private struct WeekCard: View {
    @Environment(AppStore.self) private var store
    private let letters = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        let metric = store.profile.useMetric
        let trained = store.trainedDaysThisWeek
        let today = store.todayIndex
        let thisWeek = store.volumeThisWeekKg
        let lastWeek = store.volumeLastWeekKg
        let targetMinutes = Double(store.profile.daysPerWeek * store.profile.sessionMinutes)
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("This week").font(.headline)
                Spacer()
                Text("\(store.workoutsThisWeek) of \(store.profile.daysPerWeek) workouts")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
            }
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    let done = trained.contains(i)
                    VStack(spacing: 6) {
                        ZStack {
                            Circle().fill(done ? Color.white : Color.clear)
                            Circle().strokeBorder(i == today && !done ? Color.white : Color.white.opacity(done ? 0 : 0.14),
                                                  lineWidth: 1.5)
                            if done {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Theme.ink)
                            }
                        }
                        .frame(width: 34, height: 34)
                        Text(letters[i])
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(i == today ? .white : Theme.textTertiary)
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
        .cardStyle(padding: 16, radius: 26)
        .accessibilityElement(children: .combine)
    }

    private func stat(title: String, value: String, detail: String, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.system(size: 20, weight: .semibold).monospacedDigit())
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
                             color: Theme.sage, lineWidth: 5, size: 46)
                        .overlay(Image(systemName: "fork.knife").font(.system(size: 13, weight: .semibold)))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Today's fuel")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.textSecondary)
                        Text("\(totals.calories) / \(targets.calories) kcal")
                            .font(.system(size: 17, weight: .semibold).monospacedDigit())
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
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(Theme.sage))
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Snap a meal")
        }
        .cardStyle(padding: 14, radius: 26)
    }
}

// MARK: - Shared rows

/// Pastel card for one training day ("Triceps Bench Dips" style).
struct DayCard: View {
    let day: WorkoutDay
    let index: Int
    let color: Color
    var isNext = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            InkTag(text: isNext ? "Up next" : "Day \(index + 1)", symbol: isNext ? "arrow.right" : nil)
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
