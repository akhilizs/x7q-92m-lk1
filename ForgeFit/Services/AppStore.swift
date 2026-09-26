import Foundation
import Observation

/// Single source of truth for the app. Persists everything as JSON in
/// Application Support and saves automatically (debounced) on change.
@Observable
final class AppStore {
    var hasOnboarded: Bool { didSet { scheduleSave() } }
    var profile: UserProfile { didSet { scheduleSave() } }
    var plans: [WorkoutPlan] { didSet { scheduleSave() } }
    var activePlanID: UUID? { didSet { scheduleSave() } }
    /// Finished workouts, newest first.
    var sessions: [WorkoutSession] { didSet { scheduleSave() } }
    var bodyWeights: [BodyWeightEntry] { didSet { scheduleSave() } }
    var activeSession: WorkoutSession? { didSet { scheduleSave() } }
    var chatMessages: [ChatMessage] { didSet { scheduleSave() } }
    var chatHistory: [APITurn] { didSet { scheduleSave() } }
    var aiModel: AIModel { didSet { scheduleSave() } }
    var meals: [MealEntry] { didSet { scheduleSave() } }
    /// When the coach last ran a weekly check-in.
    var lastCheckIn: Date? { didSet { scheduleSave() } }

    /// UI state (not persisted)
    var isWorkoutPresented = false
    /// Summary shown after a workout is saved (records, new badges, share card).
    var completedWorkout: CompletedWorkout?
    var hasAPIKey: Bool = KeychainStore.apiKey != nil

    /// Called whenever persisted data changes (used by cloud sync).
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private var saveWorkItem: DispatchWorkItem?
    private let fileURL: URL

    /// Everything the app persists, as saved to disk and to the user's account.
    struct Snapshot: Codable {
        var hasOnboarded: Bool
        var profile: UserProfile
        var plans: [WorkoutPlan]
        var activePlanID: UUID?
        var sessions: [WorkoutSession]
        var bodyWeights: [BodyWeightEntry]
        var activeSession: WorkoutSession?
        var chatMessages: [ChatMessage]
        var chatHistory: [APITurn]
        /// Stored as a raw string so unknown/older model IDs don't break loading.
        var aiModel: String?
        var meals: [MealEntry]? = nil
        var lastCheckIn: Date? = nil
    }

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("forgefit-data.json")
        fileURL = url

        // UI tests start from a clean slate (and optionally with sample history).
        let arguments = ProcessInfo.processInfo.arguments
        let resetForTests = arguments.contains("-uiTestReset")
        let snapshot = resetForTests ? nil : (try? Data(contentsOf: url))
            .flatMap { try? Self.decoder.decode(Snapshot.self, from: $0) }

        hasOnboarded = snapshot?.hasOnboarded ?? false
        profile = snapshot?.profile ?? UserProfile()
        plans = snapshot?.plans ?? []
        activePlanID = snapshot?.activePlanID
        sessions = snapshot?.sessions ?? []
        bodyWeights = snapshot?.bodyWeights ?? []
        activeSession = snapshot?.activeSession
        chatMessages = snapshot?.chatMessages ?? []
        chatHistory = Self.replayableHistory(snapshot?.chatHistory ?? [])
        aiModel = snapshot?.aiModel.flatMap(AIModel.init(rawValue:)) ?? .flash
        meals = snapshot?.meals ?? []
        lastCheckIn = snapshot?.lastCheckIn

        if arguments.contains("-uiTestDemoHistory") {
            DemoData.seed(self)
        }
    }

    // MARK: Persistence

    /// History from the earlier Claude-based coach can't be replayed to Gemini.
    private static func replayableHistory(_ turns: [APITurn]) -> [APITurn] {
        turns.contains { $0.role == "assistant" } ? [] : turns
    }

    func makeSnapshot() -> Snapshot {
        Snapshot(hasOnboarded: hasOnboarded, profile: profile, plans: plans,
                 activePlanID: activePlanID, sessions: sessions, bodyWeights: bodyWeights,
                 activeSession: activeSession, chatMessages: chatMessages,
                 chatHistory: chatHistory, aiModel: aiModel.rawValue,
                 meals: meals, lastCheckIn: lastCheckIn)
    }

    /// Replaces everything with `snapshot` (for example progress loaded from the user's account).
    func apply(_ snapshot: Snapshot) {
        hasOnboarded = snapshot.hasOnboarded
        profile = snapshot.profile
        plans = snapshot.plans
        activePlanID = snapshot.activePlanID
        sessions = snapshot.sessions
        bodyWeights = snapshot.bodyWeights
        activeSession = snapshot.activeSession
        if activeSession == nil { isWorkoutPresented = false }
        chatMessages = snapshot.chatMessages
        chatHistory = Self.replayableHistory(snapshot.chatHistory)
        if let model = snapshot.aiModel.flatMap(AIModel.init(rawValue:)) { aiModel = model }
        meals = snapshot.meals ?? []
        lastCheckIn = snapshot.lastCheckIn
        saveNow()
    }

    /// True once there's something worth keeping beyond the onboarding answers.
    var hasProgress: Bool {
        !sessions.isEmpty || !bodyWeights.isEmpty || !chatMessages.isEmpty || activeSession != nil || !meals.isEmpty
    }

    static func encode(_ snapshot: Snapshot) throws -> Data {
        try encoder.encode(snapshot)
    }

    static func decode(_ data: Data) -> Snapshot? {
        try? decoder.decode(Snapshot.self, from: data)
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private func scheduleSave() {
        onChange?()
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: item)
    }

    func saveNow() {
        saveWorkItem?.cancel()
        saveWorkItem = nil
        do {
            let data = try Self.encoder.encode(makeSnapshot())
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("ForgeFit: failed to save data: \(error)")
        }
    }

    func resetAll() {
        hasOnboarded = false
        profile = UserProfile()
        plans = []
        activePlanID = nil
        sessions = []
        bodyWeights = []
        activeSession = nil
        isWorkoutPresented = false
        chatMessages = []
        chatHistory = []
        meals = []
        lastCheckIn = nil
        completedWorkout = nil
        saveNow()
    }

    // MARK: API key

    func setAPIKey(_ key: String?) {
        let trimmed = key?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        KeychainStore.apiKey = trimmed.isEmpty ? nil : trimmed
        hasAPIKey = KeychainStore.apiKey != nil
    }

    // MARK: Plans

    var activePlan: WorkoutPlan? {
        guard let activePlanID else { return nil }
        return plans.first { $0.id == activePlanID }
    }

    func plan(id: UUID) -> WorkoutPlan? {
        plans.first { $0.id == id }
    }

    func addPlan(_ plan: WorkoutPlan, makeActive: Bool) {
        plans.insert(plan, at: 0)
        if makeActive || activePlanID == nil { activePlanID = plan.id }
    }

    func updatePlan(_ plan: WorkoutPlan) {
        guard let index = plans.firstIndex(where: { $0.id == plan.id }) else { return }
        plans[index] = plan
    }

    func deletePlan(id: UUID) {
        plans.removeAll { $0.id == id }
        if activePlanID == id { activePlanID = plans.first?.id }
    }

    func duplicatePlan(id: UUID) {
        guard var copy = plan(id: id) else { return }
        copy.id = UUID()
        copy.name += " Copy"
        copy.createdAt = Date()
        copy.source = .custom
        copy.nextDayIndex = 0
        copy.days = copy.days.map { day in
            var d = day
            d.id = UUID()
            d.exercises = d.exercises.map { var e = $0; e.id = UUID(); return e }
            return d
        }
        addPlan(copy, makeActive: false)
    }

    func setNextDay(planID: UUID, index: Int) {
        guard let i = plans.firstIndex(where: { $0.id == planID }) else { return }
        plans[i].nextDayIndex = index
    }

    // MARK: Workouts

    func startWorkout(day: WorkoutDay, plan: WorkoutPlan?) {
        let exercises = day.exercises.map { planned in
            LoggedExercise(planned: planned, previous: previousSets(for: planned.exerciseID),
                           suggestion: suggestion(for: planned.exerciseID, low: planned.repsLow, high: planned.repsHigh))
        }
        activeSession = WorkoutSession(planID: plan?.id, dayID: day.id, name: day.name, exercises: exercises)
        isWorkoutPresented = true
    }

    func startEmptyWorkout() {
        activeSession = WorkoutSession(name: "Quick Workout", exercises: [])
        isWorkoutPresented = true
    }

    func makeLoggedExercise(for exercise: Exercise) -> LoggedExercise {
        let p = profile.goal.prescription
        let planned: PlannedExercise
        switch exercise.tracking {
        case .time:
            let cardio = exercise.primary == .cardio
            planned = PlannedExercise(exerciseID: exercise.id, sets: cardio ? 1 : 3,
                                      repsLow: cardio ? 600 : 30, repsHigh: cardio ? 900 : 45,
                                      restSeconds: cardio ? 0 : 45)
        default:
            planned = PlannedExercise(exerciseID: exercise.id, sets: p.sets, repsLow: p.repsLow,
                                      repsHigh: p.repsHigh, restSeconds: exercise.isCompound ? p.compoundRest : p.rest)
        }
        return LoggedExercise(planned: planned, previous: previousSets(for: exercise.id),
                              suggestion: suggestion(for: exercise.id, low: planned.repsLow, high: planned.repsHigh))
    }

    /// Today's progression suggestion for an exercise, based on the last time it was done.
    func suggestion(for exerciseID: String, low: Int, high: Int) -> OverloadSuggestion? {
        Progression.suggest(for: ExerciseLibrary.exercise(exerciseID), targetLow: low, targetHigh: high,
                            previous: previousSets(for: exerciseID), metric: profile.useMetric)
    }

    @discardableResult
    func finishActiveWorkout(effort: Int?, notes: String) -> CompletedWorkout? {
        guard var session = activeSession else { return nil }
        let badgesBefore = badgeStatuses
        session.endedAt = Date()
        session.effort = effort
        session.notes = notes
        // Drop exercises where nothing was completed and unfinished sets.
        session.exercises = session.exercises.compactMap { ex in
            var e = ex
            e.sets = e.sets.filter(\.completed)
            return e.sets.isEmpty ? nil : e
        }
        if !session.exercises.isEmpty {
            sessions.insert(session, at: 0)
            if let planID = session.planID, let dayID = session.dayID,
               let i = plans.firstIndex(where: { $0.id == planID }),
               let dayIndex = plans[i].days.firstIndex(where: { $0.id == dayID }) {
                plans[i].nextDayIndex = (dayIndex + 1) % max(plans[i].days.count, 1)
            }
        }
        activeSession = nil
        isWorkoutPresented = false
        guard !session.exercises.isEmpty else { return nil }
        return CompletedWorkout(session: session, records: newRecords(in: session),
                                newBadges: BadgeBook.newlyEarned(before: badgesBefore, after: badgeStatuses),
                                streak: weekStreak)
    }

    func discardActiveWorkout() {
        activeSession = nil
        isWorkoutPresented = false
    }

    func deleteSession(id: UUID) {
        sessions.removeAll { $0.id == id }
    }

    /// Completed sets from the most recent workout that included this exercise.
    func previousSets(for exerciseID: String) -> [LoggedSet] {
        for session in sessions {
            if let ex = session.exercises.first(where: { $0.exerciseID == exerciseID }), !ex.completedSets.isEmpty {
                return ex.completedSets
            }
        }
        return []
    }

    // MARK: Stats

    struct WeekStat: Identifiable {
        let weekStart: Date
        let volumeKg: Double
        let workouts: Int
        var id: Date { weekStart }
    }

    struct PersonalRecord: Identifiable {
        let exerciseID: String
        let estimatedOneRepMax: Double
        let weightKg: Double
        let reps: Int
        let date: Date
        var id: String { exerciseID }
    }

    struct ExercisePoint: Identifiable {
        let date: Date
        let estimatedOneRepMax: Double
        let bestWeightKg: Double
        var id: Date { date }
    }

    private var calendar: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2
        return c
    }

    func startOfWeek(_ date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    var workoutsThisWeek: Int {
        let start = startOfWeek(Date())
        return sessions.filter { $0.startedAt >= start }.count
    }

    var volumeThisWeekKg: Double {
        let start = startOfWeek(Date())
        return sessions.filter { $0.startedAt >= start }.reduce(0) { $0 + $1.totalVolumeKg }
    }

    var totalVolumeKg: Double { sessions.reduce(0) { $0 + $1.totalVolumeKg } }

    var volumeLastWeekKg: Double {
        let start = startOfWeek(Date())
        guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: start) else { return 0 }
        return sessions.filter { $0.startedAt >= previous && $0.startedAt < start }.reduce(0) { $0 + $1.totalVolumeKg }
    }

    /// Minutes trained this week.
    var minutesThisWeek: Double {
        let start = startOfWeek(Date())
        return sessions.filter { $0.startedAt >= start }.reduce(0) { $0 + $1.duration / 60 }
    }

    /// Volume per day of the current week, Monday first.
    var dailyVolumeThisWeek: [Double] {
        let start = startOfWeek(Date())
        var result = Array(repeating: 0.0, count: 7)
        for s in sessions where s.startedAt >= start {
            let day = min(max(calendar.dateComponents([.day], from: start, to: s.startedAt).day ?? 0, 0), 6)
            result[day] += max(s.totalVolumeKg, 1)
        }
        return result
    }

    /// Index of today in a Monday-first week.
    var todayIndex: Int {
        let start = startOfWeek(Date())
        return min(max(calendar.dateComponents([.day], from: start, to: Date()).day ?? 0, 0), 6)
    }

    /// Consecutive weeks (including this one if trained) with at least one workout.
    var weekStreak: Int {
        var streak = 0
        var week = startOfWeek(Date())
        let trainedWeeks = Set(sessions.map { startOfWeek($0.startedAt) })
        if !trainedWeeks.contains(week) {
            week = calendar.date(byAdding: .weekOfYear, value: -1, to: week) ?? week
        }
        while trainedWeeks.contains(week) {
            streak += 1
            guard let prev = calendar.date(byAdding: .weekOfYear, value: -1, to: week) else { break }
            week = prev
        }
        return streak
    }

    /// Which days of the current week (Mon = 0) had a workout.
    var trainedDaysThisWeek: Set<Int> {
        let start = startOfWeek(Date())
        var result = Set<Int>()
        for s in sessions where s.startedAt >= start {
            let day = calendar.dateComponents([.day], from: start, to: s.startedAt).day ?? 0
            result.insert(min(max(day, 0), 6))
        }
        return result
    }

    func weeklyStats(weeks: Int) -> [WeekStat] {
        let current = startOfWeek(Date())
        return (0..<weeks).reversed().compactMap { offset in
            guard let start = calendar.date(byAdding: .weekOfYear, value: -offset, to: current),
                  let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) else { return nil }
            let inWeek = sessions.filter { $0.startedAt >= start && $0.startedAt < end }
            return WeekStat(weekStart: start, volumeKg: inWeek.reduce(0) { $0 + $1.totalVolumeKg },
                            workouts: inWeek.count)
        }
    }

    var personalRecords: [PersonalRecord] {
        var best: [String: PersonalRecord] = [:]
        for session in sessions {
            for ex in session.exercises where ex.tracking == .weightReps {
                for set in ex.completedSets {
                    let e1rm = LoggedExercise.estimatedOneRepMax(weight: set.weightKg, reps: set.reps)
                    guard e1rm > 0 else { continue }
                    if e1rm > (best[ex.exerciseID]?.estimatedOneRepMax ?? 0) {
                        best[ex.exerciseID] = PersonalRecord(exerciseID: ex.exerciseID, estimatedOneRepMax: e1rm,
                                                             weightKg: set.weightKg, reps: set.reps,
                                                             date: session.startedAt)
                    }
                }
            }
        }
        return best.values.sorted { $0.estimatedOneRepMax > $1.estimatedOneRepMax }
    }

    /// Weighted exercises the user has logged, most frequent first (ties go to the heavier lift).
    var trackedExerciseIDs: [String] {
        var counts: [String: Int] = [:]
        var best: [String: Double] = [:]
        for s in sessions {
            for ex in s.exercises where ex.tracking == .weightReps {
                counts[ex.exerciseID, default: 0] += 1
                best[ex.exerciseID] = max(best[ex.exerciseID] ?? 0, ex.bestEstimatedOneRepMax)
            }
        }
        return counts.keys.sorted { a, b in
            if counts[a] != counts[b] { return counts[a, default: 0] > counts[b, default: 0] }
            if best[a] != best[b] { return best[a, default: 0] > best[b, default: 0] }
            return a < b
        }
    }

    func progression(for exerciseID: String) -> [ExercisePoint] {
        sessions.reversed().compactMap { s in
            guard let ex = s.exercises.first(where: { $0.exerciseID == exerciseID }),
                  ex.bestEstimatedOneRepMax > 0 else { return nil }
            let heaviest = ex.completedSets.map(\.weightKg).max() ?? 0
            return ExercisePoint(date: s.startedAt, estimatedOneRepMax: ex.bestEstimatedOneRepMax, bestWeightKg: heaviest)
        }
    }

    /// PRs set within a given session (compared to all earlier sessions).
    func newRecords(in session: WorkoutSession) -> [String] {
        let earlier = sessions.filter { $0.startedAt < session.startedAt && $0.id != session.id }
        return session.exercises.compactMap { ex in
            guard ex.tracking == .weightReps, ex.bestEstimatedOneRepMax > 0 else { return nil }
            let previousBest = earlier.compactMap { s in s.exercises.first { $0.exerciseID == ex.exerciseID }?.bestEstimatedOneRepMax }.max() ?? 0
            return (previousBest > 0 && ex.bestEstimatedOneRepMax > previousBest + 0.01) ? ex.exerciseID : nil
        }
    }

    // MARK: Badges

    var badgeStatuses: [BadgeStatus] {
        BadgeBook.evaluate(BadgeBook.facts(sessions: sessions, meals: meals,
                                           proteinTarget: nutritionTargets.proteinG, calendar: calendar))
    }

    // MARK: Nutrition

    var nutritionTargets: NutritionTargets { NutritionMath.targets(for: profile) }

    func meals(on day: Date) -> [MealEntry] {
        NutritionMath.meals(meals, on: day, calendar: calendar)
    }

    func addMeal(_ meal: MealEntry) {
        meals.append(meal)
        meals.sort { $0.date < $1.date }
    }

    func deleteMeal(id: UUID) {
        meals.removeAll { $0.id == id }
    }

    // MARK: Weekly check-in

    /// A check-in is offered once a week when there's been training to review.
    var isCheckInDue: Bool {
        let weekAgo = Date().addingTimeInterval(-7 * 86_400)
        let recent = sessions.filter { $0.startedAt >= weekAgo }.count
        if let lastCheckIn {
            return Date().timeIntervalSince(lastCheckIn) >= 6.5 * 86_400 && recent >= 1
        }
        return recent >= 2 || sessions.count >= 3
    }

    // MARK: Body weight

    func addBodyWeight(kg: Double, date: Date = Date()) {
        bodyWeights.append(BodyWeightEntry(date: date, weightKg: kg))
        bodyWeights.sort { $0.date < $1.date }
        profile.bodyWeightKg = bodyWeights.last?.weightKg
    }

    func deleteBodyWeight(id: UUID) {
        bodyWeights.removeAll { $0.id == id }
    }

    // MARK: Coach

    func clearChat() {
        chatMessages = []
        chatHistory = []
    }

    func applyProposal(messageID: UUID) {
        guard let index = chatMessages.firstIndex(where: { $0.id == messageID }),
              var proposal = chatMessages[index].proposal else { return }
        var plan = proposal.plan
        plan.id = UUID()
        plan.createdAt = Date()
        plan.nextDayIndex = 0
        addPlan(plan, makeActive: true)
        proposal.status = .applied
        proposal.plan = plan
        chatMessages[index].proposal = proposal
    }

    func dismissProposal(messageID: UUID) {
        guard let index = chatMessages.firstIndex(where: { $0.id == messageID }) else { return }
        chatMessages[index].proposal?.status = .dismissed
    }

    /// Context block describing the athlete for AI prompts.
    func coachContext() -> String {
        let df = DateFormatter()
        df.dateFormat = "EEEE d MMMM yyyy"
        var parts: [String] = ["Today is \(df.string(from: Date()))."]
        parts.append("ATHLETE PROFILE\n\(profile.promptSummary)")
        parts.append("Preferred units: \(profile.useMetric ? "kg" : "lb")")
        if let plan = activePlan {
            let next = plan.nextDay.map { "Next scheduled day: \($0.name)" } ?? ""
            parts.append("CURRENT PLAN\n\(plan.promptDescription)\n\(next)")
        } else {
            parts.append("CURRENT PLAN\nNo active plan yet.")
        }
        let recent = sessions.prefix(8).map { $0.promptSummary(metric: profile.useMetric) }
        parts.append("RECENT WORKOUTS (newest first)\n" + (recent.isEmpty ? "None logged yet." : recent.joined(separator: "\n")))
        parts.append("Workouts this week: \(workoutsThisWeek). Weekly streak: \(weekStreak).")
        let weekAgo = Date().addingTimeInterval(-7 * 86_400)
        let recentMeals = meals.filter { $0.date >= weekAgo }
        if !recentMeals.isEmpty {
            let days = Set(recentMeals.map { calendar.startOfDay(for: $0.date) }).count
            let totals = NutritionTotals(meals: recentMeals)
            let t = nutritionTargets
            parts.append(String(format: "NUTRITION (last 7 days, %d days logged): avg %.0f kcal and %.0f g protein per logged day; targets %d kcal and %d g protein.",
                                days, Double(totals.calories) / Double(days), totals.proteinG / Double(days), t.calories, t.proteinG))
        }
        if bodyWeights.count >= 2, let first = bodyWeights.suffix(10).first, let last = bodyWeights.last {
            parts.append(String(format: "Body weight trend: %.1f kg → %.1f kg over the last %d entries.",
                                first.weightKg, last.weightKg, min(bodyWeights.count, 10)))
        }
        return parts.joined(separator: "\n\n")
    }
}

/// Shown after a workout is saved.
struct CompletedWorkout: Identifiable {
    let session: WorkoutSession
    let records: [String]
    let newBadges: [Badge]
    let streak: Int

    var id: UUID { session.id }
}
