import SwiftUI

struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @State private var confirmReset = false

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            List {
                Section {
                    header
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Section("Training") {
                    NavigationLink {
                        EditGoalView()
                    } label: {
                        row("Goal & level", value: "\(store.profile.goal.title) · \(store.profile.level.title)", symbol: "target", tint: Theme.accent)
                    }
                    NavigationLink {
                        EditScheduleView()
                    } label: {
                        row("Schedule", value: "\(store.profile.daysPerWeek)× · \(store.profile.sessionMinutes) min", symbol: "calendar", tint: Theme.blue)
                    }
                    NavigationLink {
                        EditEquipmentView()
                    } label: {
                        row("Equipment", value: "\(store.profile.equipment.count) items", symbol: "dumbbell.fill", tint: Theme.orange)
                    }
                    NavigationLink {
                        EditNotesView()
                    } label: {
                        row("Injuries & preferences", value: store.profile.notes.isEmpty ? "None" : "Added", symbol: "cross.case.fill", tint: Theme.pink)
                    }
                }
                .listRowBackground(Theme.surface)

                Section("AI Coach") {
                    NavigationLink {
                        AISettingsView()
                    } label: {
                        row("Claude connection", value: store.hasAPIKey ? store.aiModel.displayName : "Not connected",
                            symbol: "sparkles", tint: Theme.violet)
                    }
                }
                .listRowBackground(Theme.surface)

                Section("Preferences") {
                    Toggle(isOn: $store.profile.useMetric) {
                        row("Metric units (kg)", value: nil, symbol: "ruler.fill", tint: Theme.accentAlt)
                    }
                    .tint(Theme.sky)
                    HStack {
                        row("Name", value: nil, symbol: "person.fill", tint: Theme.accent)
                        TextField("Your name", text: $store.profile.name)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .listRowBackground(Theme.surface)

                Section {
                    Button(role: .destructive) {
                        confirmReset = true
                    } label: {
                        Label("Reset all data", systemImage: "arrow.counterclockwise")
                            .foregroundStyle(Theme.danger)
                    }
                } footer: {
                    Text("ForgeFit \(appVersion) · Your data stays on this device. AI requests go directly from your phone to Anthropic.")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
                .listRowBackground(Theme.surface)
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .navigationTitle("Profile")
            .resumeWorkoutBar()
            .confirmationDialog("Reset everything?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Delete all data", role: .destructive) {
                    store.resetAll()
                }
            } message: {
                Text("Plans, workouts, body weight and chat history will be permanently deleted.")
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var header: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(Theme.tint(for: store.profile.goal)).frame(width: 68, height: 68)
                Text(initials)
                    .font(.system(.title2).weight(.semibold))
                    .foregroundStyle(Theme.ink)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(store.profile.name.isEmpty ? "Athlete" : store.profile.name)
                    .font(.system(.title2).weight(.semibold))
                HStack(spacing: 6) {
                    TagLabel(text: store.profile.goal.title, symbol: store.profile.goal.symbol, color: Theme.accent)
                    TagLabel(text: store.profile.level.title, color: Theme.accentAlt)
                }
            }
            Spacer()
        }
        .padding(.vertical, 12)
    }

    private var initials: String {
        let parts = store.profile.name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map(String.init).joined()
        return letters.isEmpty ? "💪" : letters.uppercased()
    }

    private func row(_ title: String, value: String?, symbol: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(tint.opacity(0.15)))
            Text(title)
            if let value {
                Spacer()
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Editors

private struct EditGoalView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                GoalGrid(selection: $store.profile.goal)
                LevelPicker(selection: $store.profile.level)
                Text("Changing these won't alter your current plan. Generate a new plan or ask your coach to adapt it.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(20)
        }
        .appBackground()
        .navigationTitle("Goal & Level")
        .resumeWorkoutBar()
    }
}

private struct EditScheduleView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Label("Days per week", systemImage: "calendar")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                DaysPerWeekPicker(days: $store.profile.daysPerWeek)
                Label("Minutes per session", systemImage: "timer")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                SessionLengthPicker(minutes: $store.profile.sessionMinutes)
            }
            .padding(20)
        }
        .appBackground()
        .navigationTitle("Schedule")
        .resumeWorkoutBar()
    }
}

private struct EditEquipmentView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Plans, the exercise picker and your AI coach only use the equipment selected here.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                EquipmentSelector(selection: $store.profile.equipment)
            }
            .padding(20)
        }
        .appBackground()
        .navigationTitle("Equipment")
        .resumeWorkoutBar()
    }
}

private struct EditNotesView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Share injuries, limitations or preferences. Your AI coach takes these into account for every plan and answer.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                TextField("e.g. old shoulder injury — avoid overhead pressing; prefer machines", text: $store.profile.notes, axis: .vertical)
                    .lineLimit(4...10)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.stroke))
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .appBackground()
        .navigationTitle("Injuries & Preferences")
        .resumeWorkoutBar()
    }
}

/// API key + model selection for the Claude-powered coach.
struct AISettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var showsDoneButton = false
    @State private var keyInput = ""
    @State private var saved = false

    var body: some View {
        @Bindable var store = store
        List {
            Section {
                HStack(spacing: 14) {
                    CoachOrb(size: 48)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Powered by Claude").font(.headline)
                        Text(store.hasAPIKey ? "Connected — your coach is ready." : "Add an Anthropic API key to enable AI plans and coach chat.")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(Theme.surface)

            Section {
                SecureField(store.hasAPIKey ? "••••••••  (saved)" : "sk-ant-…", text: $keyInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
                Button {
                    store.setAPIKey(keyInput)
                    keyInput = ""
                    saved = true
                    Haptics.success()
                } label: {
                    Label("Save key", systemImage: "checkmark.shield.fill")
                }
                .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                if store.hasAPIKey {
                    Button(role: .destructive) {
                        store.setAPIKey(nil)
                        Haptics.warning()
                    } label: {
                        Label("Remove key", systemImage: "trash")
                            .foregroundStyle(Theme.danger)
                    }
                }
            } header: {
                Text("Anthropic API key")
            } footer: {
                Text("Create a key at console.anthropic.com. It's stored in the iOS Keychain on this device and only sent to api.anthropic.com. API usage is billed to your Anthropic account.")
            }
            .listRowBackground(Theme.surface)

            Section {
                Picker("Model", selection: $store.aiModel) {
                    ForEach(ClaudeModel.allCases) { model in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.displayName)
                            Text(model.blurb).font(.caption).foregroundStyle(Theme.textSecondary)
                        }
                        .tag(model)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Model")
            }
            .listRowBackground(Theme.surface)
        }
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle("AI Coach")
        .navigationBarTitleDisplayMode(.inline)
        .resumeWorkoutBar()
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.font(.headline)
                }
            }
        }
        .alert("API key saved", isPresented: $saved) {
            Button("OK") {}
        } message: {
            Text("Your AI coach is ready to go.")
        }
    }
}
