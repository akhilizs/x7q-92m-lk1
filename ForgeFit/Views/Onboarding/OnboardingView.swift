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
        VStack(spacing: 0) {
            if step != .welcome && step != .building {
                header
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(step)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)))
            if step != .welcome {
                footer
            }
        }
        .appBackground()
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: step)
    }

    // MARK: Header / footer

    private var header: some View {
        HStack(spacing: 14) {
            Button {
                back()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.surfaceRaised))
            }
            .buttonStyle(.plain)
            ProgressBar(value: Double(step.rawValue) / Double(Step.allCases.count - 2))
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
        .opacity(canContinue ? 1 : 0.4)
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
        case .welcome: welcome
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

    private var welcome: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Theme.accentGradient)
                    .frame(width: 180, height: 180)
                    .blur(radius: 60)
                    .opacity(0.5)
                GradientIcon(symbol: "dumbbell.fill", size: 110)
                    .rotationEffect(.degrees(-12))
            }
            VStack(spacing: 12) {
                Text("ForgeFit")
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                Text("Your AI-powered gym coach.\nSmart plans, effortless tracking, real results.")
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            VStack(alignment: .leading, spacing: 14) {
                FeatureRow(symbol: "sparkles", title: "AI-built plans", text: "Tailored to your goal and equipment")
                FeatureRow(symbol: "bubble.left.and.bubble.right.fill", title: "Coach chat", text: "Talk through struggles, get a better plan")
                FeatureRow(symbol: "chart.line.uptrend.xyaxis", title: "Track everything", text: "Sets, PRs, volume and body weight")
            }
            .padding(.horizontal, 8)
            Spacer()
            Button("Get Started") { next() }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
    }

    private var nameStep: some View {
        StepScroll(title: "First, what should we call you?", subtitle: "Your coach will use it to keep things personal.") {
            TextField("Your name", text: $draft.name)
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .textInputAutocapitalization(.words)
                .submitLabel(.continue)
                .onSubmit { if canContinue { next() } }
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.stroke))
        }
    }

    private var scheduleStep: some View {
        StepScroll(title: "How often can you train?", subtitle: "Be realistic — consistency beats intensity.") {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Days per week", systemImage: "calendar")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    DaysPerWeekPicker(days: $draft.daysPerWeek)
                }
                VStack(alignment: .leading, spacing: 10) {
                    Label("Minutes per session", systemImage: "timer")
                        .font(.subheadline.weight(.semibold))
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
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    TextField("e.g. sore lower back, love deadlifts, hate lunges", text: $draft.notes, axis: .vertical)
                        .lineLimit(3...5)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.stroke))
                }
            }
        }
    }

    private var buildingStep: some View {
        VStack(spacing: 20) {
            Spacer()
            if let plan = generatedPlan {
                VStack(spacing: 18) {
                    ZStack {
                        Circle().fill(Theme.accentGradient).frame(width: 90, height: 90)
                        Image(systemName: "checkmark")
                            .font(.system(size: 40, weight: .heavy))
                            .foregroundStyle(.black)
                    }
                    .transition(.scale.combined(with: .opacity))
                    Text("Your plan is ready, \(draft.firstName)!")
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .multilineTextAlignment(.center)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(plan.name).font(.headline)
                            Spacer()
                            TagLabel(text: "\(plan.days.count) days/week", color: Theme.accent)
                        }
                        ForEach(plan.days) { day in
                            HStack {
                                Text(day.name).font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("\(day.exercises.count) exercises · ~\(day.estimatedMinutes) min")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                    .cardStyle()
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "sparkles").foregroundStyle(Theme.violet)
                        Text("Want it even more personal? Add your Anthropic API key in Profile to unlock the AI coach — it can rebuild this plan and adapt it as you go.")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.horizontal, 4)
                }
            } else {
                CoachOrb(size: 90, animating: true)
                Text("Building your plan…")
                    .font(.system(.title2, design: .rounded).weight(.bold))
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
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                content
            }
            .padding(20)
            .padding(.top, 8)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

private struct FeatureRow: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(Theme.accent)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Theme.accent.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.bold))
                Text(text).font(.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
    }
}

struct LabeledInput: View {
    let title: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            TextField("—", text: $text)
                .keyboardType(keyboard)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.stroke))
        }
    }
}
