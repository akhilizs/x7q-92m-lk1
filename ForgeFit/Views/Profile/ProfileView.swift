import SwiftUI

struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @State private var confirmReset = false
    @State private var showBody = false

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    statPills
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your activities")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                        NavigationLink { EditGoalView() } label: {
                            ActivityRow(symbol: "target", title: "Goal & level",
                                        subtitle: "\(store.profile.goal.title) · \(store.profile.level.title)")
                        }
                        NavigationLink { EditScheduleView() } label: {
                            ActivityRow(symbol: "calendar", title: "Schedule",
                                        subtitle: "\(store.profile.daysPerWeek) days · \(store.profile.sessionMinutes) min sessions")
                        }
                        NavigationLink { EditEquipmentView() } label: {
                            ActivityRow(symbol: "dumbbell", title: "Equipments",
                                        subtitle: "\(store.profile.equipment.count) items available")
                        }
                        NavigationLink { EditActivitiesView() } label: {
                            ActivityRow(symbol: "figure.run", title: "Favorite sports",
                                        subtitle: store.profile.activities.isEmpty ? "None selected"
                                            : store.profile.activities.prefix(3).joined(separator: ", "))
                        }
                        NavigationLink { EditNotesView() } label: {
                            ActivityRow(symbol: "cross.case", title: "Injuries & preferences",
                                        subtitle: store.profile.notes.isEmpty ? "None added" : store.profile.notes)
                        }
                    }
                    .buttonStyle(PressableStyle())

                    VStack(alignment: .leading, spacing: 10) {
                        Text("AI coach")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                        NavigationLink { AISettingsView() } label: {
                            ActivityRow(symbol: "sparkles", title: "Gemini connection",
                                        subtitle: store.hasAPIKey ? "Connected · \(store.aiModel.displayName)" : "Not connected — add your API key")
                        }
                        .buttonStyle(PressableStyle())
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Preferences")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                        HStack(spacing: 14) {
                            IconBadge(symbol: "ruler", size: 40)
                            Text("Metric units (kg)")
                                .font(.system(size: 16))
                            Spacer()
                            Toggle("", isOn: $store.profile.useMetric)
                                .labelsHidden()
                                .tint(Theme.sky)
                        }
                        .cardStyle(padding: 12, radius: 22)
                        HStack(spacing: 14) {
                            IconBadge(symbol: "person", size: 40)
                            Text("Name")
                                .font(.system(size: 16))
                            TextField("Your name", text: $store.profile.name)
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .cardStyle(padding: 12, radius: 22)
                    }

                    Button(role: .destructive) {
                        confirmReset = true
                    } label: {
                        Text("Reset all data")
                            .font(.subheadline)
                            .foregroundStyle(Theme.danger)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Capsule().strokeBorder(Theme.danger.opacity(0.4)))
                    }
                    Text("ForgeFit \(appVersion) · Your data stays on this device. AI requests go directly from your phone to Google's Gemini API.")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .appBackground()
            .navigationTitle("Profile")
            .resumeWorkoutBar()
            .sheet(isPresented: $showBody) {
                NavigationStack { EditBodyView() }
                    .environment(store)
                    .presentationDetents([.medium, .large])
            }
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
            Text(initials)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Theme.ink)
                .frame(width: 76, height: 76)
                .background(Circle().fill(Theme.tint(for: store.profile.goal)))
            VStack(alignment: .leading, spacing: 4) {
                Text(store.profile.name.isEmpty ? "Athlete" : store.profile.name)
                    .font(.system(size: 22, weight: .medium))
                Text("\(store.profile.goal.title) · \(store.profile.level.title)")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(.top, 4)
    }

    private var statPills: some View {
        let p = store.profile
        return Button {
            showBody = true
        } label: {
            HStack(spacing: 10) {
                StatPill(title: "Gender", value: p.gender.map { $0 == .unspecified ? "—" : $0.title } ?? "—")
                StatPill(title: "Weight", value: p.bodyWeightKg.map {
                    WeightUnit.format($0, metric: p.useMetric, decimals: 0) + WeightUnit.label(metric: p.useMetric)
                } ?? "—")
                StatPill(title: "Height", value: p.heightCm.map { "\(Int($0))cm" } ?? "—")
                StatPill(title: "Age", value: p.age.map { "\($0)" } ?? "—")
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Edit body details")
    }

    private var initials: String {
        let parts = store.profile.name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map(String.init).joined()
        return letters.isEmpty ? "FF" : letters.uppercased()
    }
}

private struct StatPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.1)))
    }
}

/// Row in the "Your activities" list.
private struct ActivityRow: View {
    let symbol: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            IconBadge(symbol: symbol, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textTertiary)
        }
        .cardStyle(padding: 12, radius: 22)
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

private struct EditActivitiesView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Your coach uses these to suggest conditioning and keep training fun.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(Activities.all, id: \.self) { activity in
                        let selected = store.profile.activities.contains(activity)
                        Button {
                            if selected {
                                store.profile.activities.removeAll { $0 == activity }
                            } else {
                                store.profile.activities.append(activity)
                            }
                            Haptics.tap()
                        } label: {
                            OutlineChip(title: activity, isSelected: selected)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
            .padding(20)
        }
        .appBackground()
        .navigationTitle("Favorite sports")
        .resumeWorkoutBar()
    }
}

/// Gender, age, height and body weight.
private struct EditBodyView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var store = store
        let metric = store.profile.useMetric
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("Gender", selection: $store.profile.gender) {
                    Text("—").tag(Gender?.none)
                    ForEach(Gender.allCases) { g in
                        Text(g == .unspecified ? "Other" : g.title).tag(Gender?.some(g))
                    }
                }
                .pickerStyle(.segmented)
                VStack(spacing: 14) {
                    StepperControl(label: "Age", value: Binding(
                        get: { store.profile.age ?? 25 },
                        set: { store.profile.age = $0 }), range: 14...90)
                    StepperControl(label: "Height", value: Binding(
                        get: { Int(store.profile.heightCm ?? 170) },
                        set: { store.profile.heightCm = Double($0) }), range: 120...220, format: { "\($0) cm" })
                    StepperControl(label: "Weight", value: Binding(
                        get: { Int(WeightUnit.display(store.profile.bodyWeightKg ?? 70, metric: metric).rounded()) },
                        set: { store.profile.bodyWeightKg = WeightUnit.toKg(Double($0), metric: metric) }),
                                   range: metric ? 35...200 : 80...440,
                                   format: { "\($0) \(WeightUnit.label(metric: metric))" })
                }
                .cardStyle()
                Text("To track your weight over time, log it from the Progress tab.")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(20)
        }
        .appBackground()
        .navigationTitle("Body details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }.font(.headline)
            }
        }
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

/// API key + model selection for the Gemini-powered coach.
struct AISettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var showsDoneButton = false
    @State private var keyInput = ""
    @State private var checks: [AIModel: ModelCheck] = [:]
    @State private var isChecking = false

    var body: some View {
        @Bindable var store = store
        List {
            Section {
                HStack(spacing: 14) {
                    CoachOrb(size: 48)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Powered by Google Gemini").font(.headline)
                        Text(store.hasAPIKey ? "Connected — your coach is ready." : "Add a Gemini API key to enable AI plans and coach chat.")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(Theme.surface)

            Section {
                SecureField(store.hasAPIKey ? "••••••••  (saved)" : "AIza…", text: $keyInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
                Button {
                    store.setAPIKey(keyInput)
                    keyInput = ""
                    Haptics.success()
                    Task { await runCheck() }
                } label: {
                    Label("Save key", systemImage: "checkmark.shield.fill")
                }
                .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                if store.hasAPIKey {
                    Button(role: .destructive) {
                        store.setAPIKey(nil)
                        checks = [:]
                        Haptics.warning()
                    } label: {
                        Label("Remove key", systemImage: "trash")
                            .foregroundStyle(Theme.danger)
                    }
                }
            } header: {
                Text("Gemini API key")
            } footer: {
                Text("Create a free key in Google AI Studio (aistudio.google.com → Get API key). It's stored in the iOS Keychain on this device and only sent to Google's Gemini API. Usage beyond the free tier is billed to your Google account.")
            }
            .listRowBackground(Theme.surface)

            if store.hasAPIKey {
                Section {
                    Button {
                        Task { await runCheck() }
                    } label: {
                        HStack {
                            Label(isChecking ? "Testing…" : "Test connection", systemImage: "bolt.horizontal.circle")
                            Spacer()
                            if isChecking { ProgressView() }
                        }
                    }
                    .disabled(isChecking)
                } header: {
                    Text("Connection")
                } footer: {
                    Text("Sends a tiny request to each model to see which ones answer with your key right now.")
                }
                .listRowBackground(Theme.surface)
            }

            Section {
                Picker("Model", selection: $store.aiModel) {
                    ForEach(AIModel.allCases) { model in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(model.displayName)
                            Text(model.blurb).font(.caption).foregroundStyle(Theme.textSecondary)
                            if let check = checks[model] {
                                ModelCheckLabel(check: check)
                            }
                        }
                        .tag(model)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Model")
            } footer: {
                Text("If your model is busy or over its free limit, the coach automatically switches to another free Gemini model for that reply.")
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
    }

    private func runCheck() async {
        guard let key = KeychainStore.apiKey, !isChecking else { return }
        isChecking = true
        checks = Dictionary(uniqueKeysWithValues: AIModel.allCases.map { ($0, ModelCheck.pending) })
        for model in AIModel.allCases {
            switch await GeminiClient.check(model: model, apiKey: key) {
            case .success(let seconds): checks[model] = .ok(seconds)
            case .failure(let error): checks[model] = .failed(error)
            }
        }
        isChecking = false
        if checks.values.contains(where: \.isOK) { Haptics.success() } else { Haptics.warning() }
    }
}

enum ModelCheck {
    case pending
    case ok(TimeInterval)
    case failed(GeminiAPIError)

    var isOK: Bool {
        if case .ok = self { return true }
        return false
    }
}

private struct ModelCheckLabel: View {
    let check: ModelCheck

    var body: some View {
        switch check {
        case .pending:
            Label("Waiting…", systemImage: "clock")
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.textTertiary)
        case .ok(let seconds):
            Label("Working · \(String(format: "%.1f", seconds)) s", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.sage)
        case .failed(let error):
            VStack(alignment: .leading, spacing: 2) {
                Label(error.shortLabel, systemImage: "xmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.danger)
                Text(error.detail)
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(3)
            }
        }
    }
}
