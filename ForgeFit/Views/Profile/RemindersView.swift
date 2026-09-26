import SwiftUI

struct RemindersView: View {
    @Environment(AppStore.self) private var store
    @State private var settings = ReminderSettings.load()
    @State private var permissionDenied = false

    /// Monday first, as Calendar weekday numbers (1 = Sunday).
    private let days: [(weekday: Int, letter: String)] = [(2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S"), (1, "S")]

    private var time: Binding<Date> {
        Binding(
            get: { Calendar.current.date(bySettingHour: settings.hour, minute: settings.minute, second: 0, of: Date()) ?? Date() },
            set: {
                let parts = Calendar.current.dateComponents([.hour, .minute], from: $0)
                settings.hour = parts.hour ?? 18
                settings.minute = parts.minute ?? 0
            }
        )
    }

    var body: some View {
        List {
            Section {
                Toggle("Workout reminders", isOn: $settings.workoutsEnabled)
                    .tint(Theme.sky)
                if settings.workoutsEnabled {
                    HStack(spacing: 6) {
                        ForEach(days, id: \.weekday) { day in
                            let on = settings.weekdays.contains(day.weekday)
                            Button {
                                if on { settings.weekdays.remove(day.weekday) } else { settings.weekdays.insert(day.weekday) }
                                Haptics.select()
                            } label: {
                                Text(day.letter)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(on ? Theme.ink : .white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 38)
                                    .background(Circle().fill(on ? Color.white : Theme.surfaceRaised))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Calendar.current.weekdaySymbols[day.weekday - 1])
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                    DatePicker("Time", selection: time, displayedComponents: .hourAndMinute)
                }
            } header: {
                Text("Training days")
            } footer: {
                Text("A nudge on the days you train, with your next workout and your streak.")
            }
            .listRowBackground(Theme.surface)

            Section {
                Toggle("Weekly check-in reminder", isOn: $settings.checkInEnabled)
                    .tint(Theme.sky)
            } footer: {
                Text("Sundays at 6 pm: your AI coach reviews the week and suggests changes to your plan.")
            }
            .listRowBackground(Theme.surface)

            if permissionDenied {
                Section {
                    Label("Notifications are off for ForgeFit. Turn them on in iPhone Settings → Notifications → ForgeFit.",
                          systemImage: "bell.slash")
                        .font(.footnote)
                        .foregroundStyle(Theme.orange)
                }
                .listRowBackground(Theme.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .resumeWorkoutBar()
        .onChange(of: settings) { old, new in
            new.save()
            let turnedOn = (new.workoutsEnabled && !old.workoutsEnabled) || (new.checkInEnabled && !old.checkInEnabled)
            Task {
                if turnedOn {
                    permissionDenied = !(await Reminders.requestPermission())
                }
                Reminders.reschedule(for: store)
            }
        }
    }
}
