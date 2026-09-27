import SwiftUI

struct RemindersView: View {
    @Environment(AppStore.self) private var store
    @State private var permissionDenied = false

    /// Monday first, as Calendar weekday numbers (1 = Sunday).
    private let days: [(weekday: Int, letter: String)] = [(2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S"), (1, "S")]

    private var time: Binding<Date> {
        Binding(
            get: {
                let settings = store.reminderSettings
                return Calendar.current.date(bySettingHour: settings.hour, minute: settings.minute, second: 0, of: Date()) ?? Date()
            },
            set: {
                let parts = Calendar.current.dateComponents([.hour, .minute], from: $0)
                store.reminderSettings.hour = parts.hour ?? 18
                store.reminderSettings.minute = parts.minute ?? 0
            }
        )
    }

    var body: some View {
        // Bound straight to the app's saved settings, so every change sticks the moment it's made.
        @Bindable var store = store
        let settings = store.reminderSettings
        List {
            Section {
                Toggle("Workout reminders", isOn: $store.reminderSettings.workoutsEnabled)
                    .tint(Theme.sky)
                if settings.workoutsEnabled {
                    HStack(spacing: 6) {
                        ForEach(days, id: \.weekday) { day in
                            let on = settings.weekdays.contains(day.weekday)
                            Button {
                                if on {
                                    store.reminderSettings.weekdays.remove(day.weekday)
                                } else {
                                    store.reminderSettings.weekdays.insert(day.weekday)
                                }
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
                if settings.workoutsEnabled && settings.weekdays.isEmpty {
                    Text("Pick at least one day to get reminders.")
                } else {
                    Text("A nudge on the days you train, with your next workout and your streak.")
                }
            }
            .listRowBackground(Theme.surface)

            Section {
                Toggle("Weekly check-in reminder", isOn: $store.reminderSettings.checkInEnabled)
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
        .onChange(of: store.reminderSettings) { old, new in
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
