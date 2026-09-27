import Foundation

/// Workout and check-in reminder preferences (per device, not synced to the account).
struct ReminderSettings: Codable, Equatable {
    var workoutsEnabled = false
    /// Calendar weekdays: 1 = Sunday … 7 = Saturday.
    var weekdays: Set<Int> = [2, 4, 6]
    var hour = 18
    var minute = 0
    var checkInEnabled = false

    private static let key = "reminderSettings"

    static func load(from defaults: UserDefaults = .standard) -> ReminderSettings {
        guard let data = defaults.data(forKey: key),
              let settings = try? JSONDecoder().decode(ReminderSettings.self, from: data) else { return ReminderSettings() }
        return settings
    }

    func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.key)
        }
    }

    /// One-line description for the Profile screen, e.g. "3 days a week · 3:00 PM".
    var summary: String {
        guard workoutsEnabled else { return checkInEnabled ? "Weekly check-in only" : "Off" }
        guard !weekdays.isEmpty else { return "No days picked" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let time = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date())
            .map { formatter.string(from: $0) } ?? ""
        let days = weekdays.count == 1 ? "1 day a week" : "\(weekdays.count) days a week"
        return "\(days) · \(time)"
    }
}
