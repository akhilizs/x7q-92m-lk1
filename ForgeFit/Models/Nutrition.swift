import Foundation

/// One logged meal (from a photo, a description or typed in by hand).
struct MealEntry: Identifiable, Codable, Hashable {
    enum Source: String, Codable {
        case photo, description, manual
    }

    var id = UUID()
    var date = Date()
    var name: String
    var calories: Int
    var proteinG: Double
    var carbsG: Double = 0
    var fatG: Double = 0
    /// Short breakdown, e.g. "Grilled chicken · ~150 g".
    var items: [String] = []
    var source: Source = .manual
    /// Whether a thumbnail was saved on this device (photos aren't synced).
    var hasPhoto = false
}

/// Daily calorie and macro targets.
struct NutritionTargets: Equatable {
    var calories: Int
    var proteinG: Int
    var carbsG: Int
    var fatG: Int
    /// True when weight, height or age is missing, so defaults were used.
    var isRough: Bool
}

struct NutritionTotals: Equatable {
    var calories = 0
    var proteinG = 0.0
    var carbsG = 0.0
    var fatG = 0.0

    init(meals: [MealEntry] = []) {
        for meal in meals {
            calories += meal.calories
            proteinG += meal.proteinG
            carbsG += meal.carbsG
            fatG += meal.fatG
        }
    }
}

enum NutritionMath {
    /// Mifflin–St Jeor resting energy × an activity factor from training days, adjusted for the goal.
    /// Protein is set per kg of body weight; fat at 25% of calories; carbs fill the rest.
    static func targets(for profile: UserProfile) -> NutritionTargets {
        let weight = profile.bodyWeightKg ?? 75
        let height = profile.heightCm ?? 172
        let age = Double(profile.age ?? 30)
        let sexOffset: Double
        switch profile.gender {
        case .male: sexOffset = 5
        case .female: sexOffset = -161
        default: sexOffset = -78
        }
        let resting = 10 * weight + 6.25 * height - 5 * age + sexOffset
        let activity = min(1.2 + 0.075 * Double(profile.daysPerWeek), 1.75)
        let goalFactor: Double
        let proteinPerKg: Double
        switch profile.goal {
        case .loseFat: goalFactor = 0.8; proteinPerKg = 2.2
        case .buildMuscle: goalFactor = 1.1; proteinPerKg = 2.0
        case .getStronger: goalFactor = 1.05; proteinPerKg = 2.0
        case .athletic: goalFactor = 1.05; proteinPerKg = 1.8
        case .endurance: goalFactor = 1.05; proteinPerKg = 1.6
        case .generalFitness: goalFactor = 1.0; proteinPerKg = 1.6
        }
        var calories = Int((resting * activity * goalFactor / 10).rounded()) * 10
        var protein = Int((weight * proteinPerKg).rounded())
        if let custom = profile.calorieTarget, custom > 0 { calories = custom }
        if let custom = profile.proteinTarget, custom > 0 { protein = custom }
        let fat = Int((Double(calories) * 0.25 / 9).rounded())
        let carbs = max(50, Int(((Double(calories) - Double(protein) * 4 - Double(fat) * 9) / 4).rounded()))
        let rough = profile.bodyWeightKg == nil || profile.heightCm == nil || profile.age == nil
        return NutritionTargets(calories: calories, proteinG: protein, carbsG: carbs, fatG: fat,
                                isRough: rough && profile.calorieTarget == nil)
    }

    static func meals(_ meals: [MealEntry], on day: Date, calendar: Calendar = .current) -> [MealEntry] {
        meals.filter { calendar.isDate($0.date, inSameDayAs: day) }.sorted { $0.date < $1.date }
    }

    /// Days (start of day) on which logged protein reached the target.
    static func proteinDaysHit(_ meals: [MealEntry], target: Int, calendar: Calendar = .current) -> Int {
        guard target > 0 else { return 0 }
        let byDay = Dictionary(grouping: meals) { calendar.startOfDay(for: $0.date) }
        return byDay.values.filter { NutritionTotals(meals: $0).proteinG >= Double(target) }.count
    }
}
