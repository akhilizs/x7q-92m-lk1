import Foundation

/// Sample training history used by UI tests (`-uiTestDemoHistory` launch argument)
/// so the progress screens can be exercised with realistic data.
enum DemoData {
    static func seed(_ store: AppStore) {
        var profile = UserProfile()
        profile.name = "Alex Rivera"
        profile.goal = .buildMuscle
        profile.level = .intermediate
        profile.daysPerWeek = 4
        profile.sessionMinutes = 60
        profile.equipment = EquipmentPreset.fullGym.equipment
        profile.bodyWeightKg = 82
        profile.heightCm = 180
        profile.age = 29
        profile.gender = .male
        profile.activities = ["bodybuilding", "running"]
        store.profile = profile

        let plan = PlanGenerator.generate(profile: profile)
        store.plans = [plan]
        store.activePlanID = plan.id

        let calendar = Calendar.current
        let now = Date()
        let thisWeek = store.startOfWeek(now)
        var sessions: [WorkoutSession] = []
        var dayCounter = 0

        for weekOffset in stride(from: 6, through: 0, by: -1) {
            for weekday in [0, 1, 3, 4] {
                guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: thisWeek),
                      let day = calendar.date(byAdding: .day, value: weekday, to: weekStart),
                      let start = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: day),
                      start < now.addingTimeInterval(-3600) else { continue }
                let planDay = plan.days[dayCounter % plan.days.count]
                dayCounter += 1
                let progress = 1 + Double(6 - weekOffset) * 0.03
                let exercises = planDay.exercises.map { loggedExercise(for: $0, progress: progress) }
                sessions.append(WorkoutSession(planID: plan.id, dayID: planDay.id, name: planDay.name,
                                               startedAt: start, endedAt: start.addingTimeInterval(56 * 60),
                                               exercises: exercises, effort: 7 + dayCounter % 2))
            }
        }
        store.sessions = sessions.sorted { $0.startedAt > $1.startedAt }
        if let i = store.plans.firstIndex(where: { $0.id == plan.id }) {
            store.plans[i].nextDayIndex = dayCounter % plan.days.count
        }

        store.bodyWeights = (0..<12).compactMap { i in
            guard let date = calendar.date(byAdding: .day, value: -(11 - i) * 4, to: now) else { return nil }
            let wobble = [0.3, -0.2, 0.1, -0.1, 0.2, -0.3][i % 6]
            return BodyWeightEntry(date: date, weightKg: 84.5 - Double(i) * 0.22 + wobble)
        }
        let today = calendar.startOfDay(for: now)
        func at(_ hour: Int) -> Date { calendar.date(byAdding: .hour, value: hour, to: today) ?? today }
        store.meals = [
            MealEntry(date: at(8), name: "Greek yogurt & berries", calories: 420, proteinG: 32, carbsG: 48, fatG: 11,
                      items: ["Greek yogurt · 250 g · 240 kcal", "Blueberries · 1 cup · 85 kcal", "Granola · 25 g · 95 kcal"],
                      source: .photo),
            MealEntry(date: at(13), name: "Chicken rice bowl", calories: 690, proteinG: 54, carbsG: 78, fatG: 16,
                      items: ["Grilled chicken · ~180 g · 300 kcal", "White rice · 1 cup · 240 kcal", "Veg & sauce · 150 kcal"],
                      source: .description),
        ].filter { $0.date <= now }
        store.hasOnboarded = true
    }

    private static func loggedExercise(for planned: PlannedExercise, progress: Double) -> LoggedExercise {
        let exercise = planned.exercise
        let tracking = exercise?.tracking ?? .weightReps
        let equipment = exercise?.equipment ?? []
        let base: Double
        if equipment.contains(.barbell) || equipment.contains(.legPress) || equipment.contains(.hackSquat) {
            base = exercise?.isCompound == true ? 80 : 35
        } else if equipment.contains(.dumbbells) || equipment.contains(.kettlebell) {
            base = exercise?.isCompound == true ? 26 : 12
        } else {
            base = exercise?.isCompound == true ? 55 : 30
        }
        let weight = (base * progress / 2.5).rounded() * 2.5
        let sets: [LoggedSet] = (0..<planned.sets).map { i in
            var set = LoggedSet()
            set.completed = true
            switch tracking {
            case .weightReps:
                set.weightKg = weight
                set.reps = max(planned.repsLow, planned.repsHigh - i)
            case .reps:
                set.reps = max(planned.repsLow, planned.repsHigh - i)
            case .time:
                set.seconds = planned.repsHigh
            }
            return set
        }
        return LoggedExercise(exerciseID: planned.exerciseID, targetRepsLow: planned.repsLow,
                              targetRepsHigh: planned.repsHigh, restSeconds: planned.restSeconds, sets: sets)
    }
}
