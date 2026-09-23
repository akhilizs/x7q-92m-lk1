import SwiftUI

struct OnboardingView: View {
    @Environment(AppStore.self) private var store

    private enum Step: Int, CaseIterable {
        case welcome, name, goal, level, schedule, equipment, body, building
    }

    @State private var step: Step = .welcome
    @State private var draft = UserProfile()
    @State private var weightText = ""
    @State private var ageText = ""
    @State private var generatedPlan: WorkoutPlan?

    var body: some View {
        ZStack {
            if step == .welcome {
                welcome
                    .transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    if step != .building { header }
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .id(step)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                removal: .move(edge: .leading).combined(with: .opacity)))
                    footer
                }
                .appBackground()
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.88), value: step)
    }

    // MARK: Welcome

    private var welcome: some View {
        ZStack(alignment: .bottom) {
            PhotoBackdrop(name: "HeroAthlete", alignment: .top, gradientStart: 0.3)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 26, height: 26)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.white))
                    Text("ForgeFit")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                }
                Spacer()
                Text("Welcome to ForgeFit")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 16)
                Text("Take your body\nto the peak.")
                    .font(.system(size: 38, weight: .regular))
                    .lineSpacing(2)
                    .padding(.bottom, 12)
                Text("Your AI coach builds the plan, adapts it to how you feel and tracks every rep. Let's set you up.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.bottom, 28)
                Button {
                    next()
                } label: {
                    HStack(spacing: 8) {
                        Text("Let's Go")
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(GlassButtonStyle())
                Button("Skip for now") { skip() }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 14)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .background(Color.black)
    }

    // MARK: Header / footer

    private var header: some View {
        HStack(spacing: 16) {
            Button {
                back()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.surfaceRaised))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
            DashProgress(current: step.rawValue - 1, total: Step.allCases.count - 2)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var footer: some View {
        Button {
            next()
        } label: {
            Text(step == .building ? "Let's go" : "Continue")
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!canContinue)
        .opacity(canContinue ? 1 : 0.35)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var canContinue: Bool {
        switch step {
        case .name: return !draft.name.trimmingCharacters(in: .whitespaces).isEmpty
        case .building: return generatedPlan != nil
        default: return true
        }
    }

    // MARK: Steps

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome: EmptyView()
        case .name: nameStep
        case .goal:
            StepScroll(title: "What's your main goal?", subtitle: "Your plan, sets and reps are tuned to it.") {
                GoalGrid(selection: $draft.goal)
            }
        case .level:
            StepScroll(title: "How experienced are you?", subtitle: "We'll match volume and exercise choice to your level.") {
                LevelPicker(selection: $draft.level)
            }
        case .schedule: scheduleStep
        case .equipment:
            StepScroll(title: "What equipment do you have?",
                       subtitle: "Select the machines and gear available to you. Plans only use what you pick.") {
                EquipmentSelector(selection: $draft.equipment)
            }
        case .body: bodyStep
        case .building: buildingStep
        }
    }

    private var nameStep: some View {
        StepScroll(title: "What should we call you?", subtitle: "Your coach will use it to keep things personal.") {
            TextField("Your name", text: $draft.name)
                .font(.system(size: 22, weight: .medium))
                .textInputAutocapitalization(.words)
                .submitLabel(.continue)
                .onSubmit { if canContinue { next() } }
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.stroke))
        }
    }

    private var scheduleStep: some View {
        StepScroll(title: "How often can you train?", subtitle: "Be realistic — consistency beats intensity.") {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Days per week")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                    DaysPerWeekPicker(days: $draft.daysPerWeek)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Minutes per session")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                    SessionLengthPicker(minutes: $draft.sessionMinutes)
                }
            }
        }
    }

    private var bodyStep: some View {
        StepScroll(title: "A few optional details", subtitle: "They help the AI coach personalise advice. Skip anything you like.") {
            VStack(spacing: 14) {
                Picker("Units", selection: $draft.useMetric) {
                    Text("Metric (kg)").tag(true)
                    Text("Imperial (lb)").tag(false)
                }
                .pickerStyle(.segmented)

                HStack(spacing: 12) {
                    LabeledInput(title: "Body weight (\(WeightUnit.label(metric: draft.useMetric)))", text: $weightText, keyboard: .decimalPad)
                    LabeledInput(title: "Age", text: $ageText, keyboard: .numberPad)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Injuries, limitations or preferences")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                    TextField("e.g. sore lower back, love deadlifts, hate lunges", text: $draft.notes, axis: .vertical)
                        .lineLimit(3...5)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.stroke))
                }
            }
        }
    }

    private var buildingStep: some View {
        VStack(spacing: 20) {
            Spacer()
            if let plan = generatedPlan {
                VStack(spacing: 18) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 84, height: 84)
                        .background(Circle().fill(.white))
                        .transition(.scale.combined(with: .opacity))
                    Text("Your plan is ready, \(draft.firstName)!")
                        .font(.system(size: 28, weight: .semibold))
                        .multilineTextAlignment(.center)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            InkTag(text: "\(plan.days.count) days / week")
                            Spacer()
                        }
                        Text(plan.name)
                            .font(.system(size: 22, weight: .medium))
                            .italic()
                        ForEach(plan.days) { day in
                            HStack {
                                Text(day.name).font(.subheadline.weight(.medium))
                                Spacer()
                                Text("\(day.exercises.count) exercises · ~\(day.estimatedMinutes) min")
                                    .font(.caption)
                                    .foregroundStyle(Theme.inkSecondary)
                            }
                        }
                    }
                    .pastelCard(Theme.paper)
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "sparkles")
                        Text("Want it even more personal? Add your Anthropic API key in Profile to unlock the AI coach — it can rebuild this plan and adapt it as you go.")
                            .font(.footnote)
                    }
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 4)
                }
            } else {
                CoachOrb(size: 88, animating: true)
                Text("Building your plan…")
                    .font(.system(size: 24, weight: .semibold))
                Text("Matching exercises to your goal, schedule and equipment.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(24)
        .task {
            guard generatedPlan == nil else { return }
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                generatedPlan = PlanGenerator.generate(profile: draft)
            }
            Haptics.success()
        }
    }

    // MARK: Navigation

    private func next() {
        dismissKeyboard()
        switch step {
        case .body:
            applyBodyDetails()
            step = .building
        case .building:
            finish()
        default:
            if let nextStep = Step(rawValue: step.rawValue + 1) { step = nextStep }
        }
        Haptics.tap()
    }

    private func back() {
        dismissKeyboard()
        if let previous = Step(rawValue: step.rawValue - 1) { step = previous }
    }

    /// Starts with sensible defaults; everything can be changed later in Profile.
    private func skip() {
        generatedPlan = PlanGenerator.generate(profile: draft)
        finish()
    }

    private func applyBodyDetails() {
        if let weight = Double(weightText.replacingOccurrences(of: ",", with: ".")), weight > 0 {
            draft.bodyWeightKg = WeightUnit.toKg(weight, metric: draft.useMetric)
        }
        if let age = Int(ageText), age > 0 { draft.age = age }
    }

    private func finish() {
        guard let plan = generatedPlan else { return }
        store.profile = draft
        if let kg = draft.bodyWeightKg {
            store.bodyWeights = [BodyWeightEntry(date: Date(), weightKg: kg)]
        }
        store.addPlan(plan, makeActive: true)
        store.hasOnboarded = true
        Haptics.success()
    }
}

// MARK: - Helpers

private struct StepScroll<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 30, weight: .regular))
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                content
            }
            .padding(20)
            .padding(.top, 12)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

struct LabeledInput: View {
    let title: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
            TextField("—", text: $text)
                .keyboardType(keyboard)
                .font(.system(size: 20, weight: .medium))
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.stroke))
        }
    }
}
