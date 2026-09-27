import Foundation
import UserNotifications

@MainActor
enum Reminders {
    private static let workoutPrefix = "forgefit.reminder.workout."
    private static let checkInID = "forgefit.reminder.checkin"

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Re-creates the reminders so they mention the next workout and current streak.
    static func reschedule(for store: AppStore) {
        apply(store.reminderSettings, nextWorkout: store.activePlan?.nextDay?.name, streak: store.weekStreak)
    }

    static func apply(_ settings: ReminderSettings, nextWorkout: String?, streak: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: (1...7).map { workoutPrefix + String($0) } + [checkInID])

        if settings.workoutsEnabled {
            for weekday in settings.weekdays {
                let content = UNMutableNotificationContent()
                content.title = "Time to train 💪"
                var body = nextWorkout.map { "Up next: \($0)." } ?? "Your workout is waiting."
                if streak > 1 { body += " Keep your \(streak)-week streak going." }
                content.body = body
                content.sound = .default
                var when = DateComponents()
                when.weekday = weekday
                when.hour = settings.hour
                when.minute = settings.minute
                let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
                center.add(UNNotificationRequest(identifier: workoutPrefix + String(weekday), content: content, trigger: trigger))
            }
        }

        if settings.checkInEnabled {
            let content = UNMutableNotificationContent()
            content.title = "Your weekly check-in is ready"
            content.body = "See how your week went and let your coach fine-tune next week's plan."
            content.sound = .default
            var when = DateComponents()
            when.weekday = 1
            when.hour = 18
            let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
            center.add(UNNotificationRequest(identifier: checkInID, content: content, trigger: trigger))
        }
    }
}
