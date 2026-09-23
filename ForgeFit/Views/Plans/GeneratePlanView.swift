import SwiftUI

/// Generate a plan from a goal and the equipment/machines available —
/// with the AI coach (Claude) or the instant offline generator.
struct GeneratePlanView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private enum Mode: String, CaseIterable, Identifiable {
        case ai = "AI Coach"
        case instant = "Instant"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .ai
    @State private var goal: FitnessGoal = .buildMuscle
    @State private var level: ExperienceLevel = .beginner
    @State private var days = 3
    @State private var minutes = 60
    @State private var equipment: Set<Equipment> = []
    @State private var focus: Set<MuscleGroup> = []
    @State private var notes = ""
    @State private var loaded = false

    @State private var isGenerating = false
    @State private var progressText = ""
    @State private var result: WorkoutPlan?
    @State private var errorText: String?
    @State private var task: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ZStack {
                if let result {
                    preview(result)
                } else {
                    form
                }
                if isGenerating {
                    GeneratingOverlay(text: progressText, isAI: mode == .ai) {
                        task?.cancel()
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isGenerating)
            .animation(.easeInOut(duration: 0.25), value: result?.id)
            .appBackground()
            .navigationTitle(result == nil ? "Generate Plan" : "Your New Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        task?.cancel()
                        dismiss()
                    }
                }
            }
        }
        .onAppear(perform: loadDefaults)
        .interactiveDismissDisabled(isGenerating)
    }

    // MARK: Form

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                modePicker
                section("Goal", symbol: "target") { GoalGrid(selection: $goal) }
                section("Experience", symbol: "chart.bar.fill") {
                    Picker("Experience", selection: $level) {
                        ForEach(ExperienceLevel.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                section("Days per week", symbol: "calendar") { DaysPerWeekPicker(days: $days) }
                section("Session length", symbol: "timer") { SessionLengthPicker(minutes: $minutes) }
                section("Machines & equipment available", symbol: "dumbbell.fill") {
                    EquipmentSelector(selection: $equipment)
                }
                section("Focus muscles (optional)", symbol: "scope") { MuscleFocusPicker(selection: $focus) }
                if mode == .ai {
                    section("Anything else for your coach?", symbol: "text.bubble.fill") {
                        TextField("e.g. bad left knee, want a bigger chest, no running", text: $notes, axis: .vertical)
                            .lineLimit(2...5)
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.stroke))
                    }
                }
                if let errorText {
                    Label(errorText, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(Theme.danger)
                }
                Button {
                    generate()
                } label: {
                    Label(mode == .ai ? "Generate with AI" : "Generate instantly",
                          systemImage: mode == .ai ? "sparkles" : "wand.and.stars")
                }
                .buttonStyle(PrimaryButtonStyle(gradient: mode == .ai ? Theme.aiGradient : Theme.accentGradient,
                                                foreground: mode == .ai ? .white : .black))
                .disabled(mode == .ai && !store.hasAPIKey)
                .opacity(mode == .ai && !store.hasAPIKey ? 0.5 : 1)
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(Mode.allCases) { m in
                    Button {
                        mode = m
                        Haptics.tap()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: m == .ai ? "sparkles" : "bolt.fill")
                            Text(m.rawValue)
                        }
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(mode == m ? (m == .ai ? Color.white : Color.black) : Theme.textSecondary)
                        .background(
                            Capsule().fill(mode == m
                                           ? AnyShapeStyle(m == .ai ? Theme.aiGradient : Theme.accentGradient)
                                           : AnyShapeStyle(Theme.surface))
                        )
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            Group {
                if mode == .ai {
                    if store.hasAPIKey {
                        Text("Claude designs a program around your goal, equipment and notes — usually in under a minute.")
                    } else {
                        Text("Add your Anthropic API key in Profile → AI Coach to enable AI plans. Instant mode works offline.")
                            .foregroundStyle(Theme.orange)
                    }
                } else {
                    Text("A rule-based program built instantly on your device.")
                }
            }
            .font(.caption)
            .foregroundStyle(Theme.textSecondary)
        }
    }

    private func section<Content: View>(_ title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.textSecondary)
            content()
        }
    }

    // MARK: Preview

    private func preview(_ plan: WorkoutPlan) -> some View {
        VStack(spacing: 0) {
            PlanContentView(plan: plan)
            VStack(spacing: 10) {
                Button {
                    store.addPlan(plan, makeActive: true)
                    Haptics.success()
                    dismiss()
                } label: {
                    Label("Save & make active", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                HStack(spacing: 10) {
                    Button("Adjust options") {
                        result = nil
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    Button("Regenerate") {
                        result = nil
                        generate()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(Theme.background.opacity(0.95))
        }
    }

    // MARK: Actions

    private func loadDefaults() {
        guard !loaded else { return }
        loaded = true
        let p = store.profile
        goal = p.goal
        level = p.level
        days = p.daysPerWeek
        minutes = p.sessionMinutes
        equipment = p.equipment
        mode = store.hasAPIKey ? .ai : .instant
    }

    private func generate() {
        dismissKeyboard()
        errorText = nil
        if equipment.isEmpty { equipment = [.bodyweight] }

        switch mode {
        case .instant:
            isGenerating = true
            progressText = "Building your plan…"
            task = Task {
                try? await Task.sleep(nanoseconds: 700_000_000)
                let plan = PlanGenerator.generate(PlanGenerator.Options(goal: goal, level: level, daysPerWeek: days,
                                                                        sessionMinutes: minutes, equipment: equipment,
                                                                        focus: focus))
                isGenerating = false
                if !Task.isCancelled {
                    result = plan
                    Haptics.success()
                }
            }
        case .ai:
            isGenerating = true
            progressText = "Connecting to your coach…"
            let request = AIPlanDesigner.Request(goal: goal, level: level, daysPerWeek: days, sessionMinutes: minutes,
                                                 equipment: equipment, focus: focus, notes: notes)
            let profile = store.profile
            let model = store.aiModel
            task = Task {
                do {
                    let plan = try await AIPlanDesigner.design(request, profile: profile, model: model) { text in
                        progressText = text
                    }
                    result = plan
                    Haptics.success()
                } catch {
                    let cancelled = Task.isCancelled || error is CancellationError
                        || (error as? URLError)?.code == .cancelled
                    if !cancelled {
                        errorText = error.localizedDescription
                        Haptics.warning()
                    }
                }
                isGenerating = false
            }
        }
    }
}

private struct GeneratingOverlay: View {
    let text: String
    let isAI: Bool
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: 22) {
                if isAI {
                    CoachOrb(size: 96, animating: true)
                } else {
                    ProgressView().controlSize(.large).tint(Theme.accent)
                }
                VStack(spacing: 8) {
                    Text(isAI ? "Your coach is designing your plan" : "Generating")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .multilineTextAlignment(.center)
                    Text(text)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                        .contentTransition(.opacity)
                        .animation(.easeInOut, value: text)
                        .multilineTextAlignment(.center)
                }
                Button("Cancel", action: onCancel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(32)
        }
    }
}
