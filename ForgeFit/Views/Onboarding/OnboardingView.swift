import SwiftUI

struct OnboardingView: View {
    @Environment(AppStore.self) private var store
    @Environment(CloudSync.self) private var sync
    @State private var showLogIn = false

    private enum Step: Int, CaseIterable {
        case welcome, name, gender, age, height, weight, goal, level, activities, schedule, equipment, notes, building

        /// Steps that show the dash progress (everything between welcome and building).
        static var questionCount: Int { allCases.count - 2 }
    }

    @State private var step: Step = .welcome
    @State private var draft = UserProfile()
    @State private var age = 25
    @State private var heightCm = 170
    @State private var weight = 70
    @State private var generatedPlan: WorkoutPlan?

    var body: some View {
        ZStack {
            if step == .welcome {
                welcome
                    .transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    header
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .id(step)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                removal: .move(edge: .leading).combined(with: .opacity)))
                }
                // Content scrolls underneath the footer and blurs out instead of being cut off.
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    footer
                        .padding(.top, 36)
                        .background(BottomBlurBackground())
                }
                .appBackground()
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.88), value: step)
        .sheet(isPresented: $showLogIn) {
            NavigationStack { AuthView(mode: .logIn) }
                .environment(store)
                .environment(sync)
        }
    }

    // MARK: Welcome

    private var welcome: some View {
        ZStack(alignment: .bottom) {
            PhotoBackdrop(name: "HeroAthlete", alignment: .top, gradientStart: 0.3)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 16) {
                    BrandMark()
                    DashProgress(current: -1, total: 6)
                        .frame(maxWidth: 150)
                    Spacer(minLength: 0)
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
                HStack(spacing: 8) {
                    Button {
                        skip()
                    } label: {
                        Text("Skip for now").frame(minHeight: 44).padding(.horizontal, 8).contentShape(Rectangle())
                    }
                    if sync.isConfigured && !sync.isSignedIn {
                        Text("·").foregroundStyle(.white.opacity(0.3))
                        Button {
                            showLogIn = true
                        } label: {
                            Text("I have an account").frame(minHeight: 44).padding(.horizontal, 8).contentShape(Rectangle())
                        }
                        .foregroundStyle(.white)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
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
            BrandMark()
            if step != .building {
                DashProgress(current: step.rawValue - 1, total: Step.questionCount)
            } else {
                Spacer()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Button {
                next()
            } label: {
                HStack(spacing: 6) {
                    Text(step == .building ? "Let's go" : "Continue")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .buttonStyle(FooterButtonStyle(prominent: step == .building))
            .disabled(!canContinue)
            .opacity(canContinue ? 1 : 0.4)

            if step != .building {
                // Full-width, 44 pt tall, so a tap anywhere under Continue goes back.
                Button {
                    back()
                } label: {
                    Text("Back")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
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
        case .name:
            StepScroll(title: "what is your\nname?", subtitle: "Your coach will use it to keep things personal.") {
                TextField("Your name", text: $draft.name)
                    .font(.system(size: 24, weight: .light))
                    .textInputAutocapitalization(.words)
                    .submitLabel(.continue)
                    .onSubmit { if canContinue { next() } }
                    .padding(.horizontal, 20)
                    .frame(height: 64)
                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(white: 0.07)))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.white.opacity(0.12)))
            }
        case .gender:
            StepScroll(title: "what is your\ngender?", subtitle: "Please select your gender.") {
                VStack(spacing: 12) {
                    ForEach([Gender.female, Gender.male], id: \.self) { g in
                        Button {
                            draft.gender = g
                            Haptics.tap()
                        } label: {
                            ChoiceTile(title: g.title, isSelected: draft.gender == g)
                        }
                        .buttonStyle(PressableStyle())
                    }
                    Button {
                        draft.gender = .unspecified
                        Haptics.tap()
                    } label: {
                        Text(Gender.unspecified.title)
                            .font(.footnote)
                            .foregroundStyle(draft.gender == .unspecified ? Color.white : Theme.textTertiary)
                            .padding(.vertical, 8)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        case .age:
            WheelStep(title: "what is your\nage?", subtitle: "Please select your age.") {
                NumberWheel(value: $age, range: 14...90, unit: "yrs")
            }
        case .height:
            WheelStep(title: "what is your\nheight?", subtitle: "Please select your height.") {
                NumberWheel(value: $heightCm, range: 120...220, unit: "cm")
            } footnote: {
                Text(feetAndInches(heightCm))
            }
        case .weight:
            WheelStep(title: "what is your\nweight?", subtitle: "Please select your weight.") {
                NumberWheel(value: $weight,
                            range: draft.useMetric ? 35...200 : 80...440,
                            unit: WeightUnit.label(metric: draft.useMetric))
                    .id(draft.useMetric)
            } footnote: {
                unitToggle
            }
        case .goal:
            StepScroll(title: "what is your\nmain goal?", subtitle: "Your plan, sets and reps are tuned to it.") {
                GoalGrid(selection: $draft.goal)
            }
        case .level:
            StepScroll(title: "how experienced\nare you?", subtitle: "We match volume and exercise choice to your level.") {
                LevelPicker(selection: $draft.level)
            }
        case .activities:
            StepScroll(title: "what is your\nfavorite sport?", subtitle: "Please select your favorite sports. Pick as many as you like.") {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(Activities.all, id: \.self) { activity in
                        let selected = draft.activities.contains(activity)
                        Button {
                            if selected {
                                draft.activities.removeAll { $0 == activity }
                            } else {
                                draft.activities.append(activity)
                            }
                            Haptics.tap()
                        } label: {
                            OutlineChip(title: activity, isSelected: selected)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
        case .schedule:
            StepScroll(title: "how often can\nyou train?", subtitle: "Be realistic — consistency beats intensity.") {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Days per week")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                        DaysPerWeekPicker(days: $draft.daysPerWeek)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Minutes per session")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                        SessionLengthPicker(minutes: $draft.sessionMinutes)
                    }
                }
            }
        case .equipment:
            StepScroll(title: "what equipment\ndo you have?",
                       subtitle: "Select the machines and gear available to you. Plans only use what you pick.") {
                EquipmentSelector(selection: $draft.equipment)
            }
        case .notes:
            StepScroll(title: "any injuries or\nlimitations?", subtitle: "Optional — your AI coach works around them.") {
                TextField("e.g. sore lower back, old shoulder injury, no jumping", text: $draft.notes, axis: .vertical)
                    .font(.system(size: 17, weight: .light))
                    .lineLimit(4...8)
                    .padding(18)
                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(white: 0.07)))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.white.opacity(0.12)))
            }
        case .building:
            buildingStep
        }
    }

    private var unitToggle: some View {
        HStack(spacing: 0) {
            ForEach([true, false], id: \.self) { metric in
                Button {
                    guard draft.useMetric != metric else { return }
                    let kg = WeightUnit.toKg(Double(weight), metric: draft.useMetric)
                    draft.useMetric = metric
                    weight = Int(WeightUnit.display(kg, metric: metric).rounded())
                    Haptics.tap()
                } label: {
                    Text(WeightUnit.label(metric: metric))
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(draft.useMetric == metric ? Color.black : Theme.textSecondary)
                        .frame(width: 56, height: 32)
                        .background(Capsule().fill(draft.useMetric == metric ? Color.white : Color.clear))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Theme.surfaceRaised))
    }

    private var buildingStep: some View {
        VStack(spacing: 20) {
            Spacer()
            if let plan = generatedPlan {
                VStack(spacing: 18) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 80, height: 80)
                        .background(Circle().fill(Theme.volt))
                        .shadow(color: Theme.volt.opacity(0.45), radius: 24)
                        .transition(.scale.combined(with: .opacity))
                    Text("Your plan is ready, \(draft.firstName)!")
                        .font(.system(size: 28, weight: .light))
                        .multilineTextAlignment(.center)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 10) {
                                VoltTag(text: "\(plan.days.count) days / week", filled: true)
                                Text(plan.name)
                                    .font(.display(19))
                                    .foregroundStyle(.white)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            MuscleMapView(exercises: plan.days.flatMap(\.exercises), glow: true)
                                .frame(width: 76, height: 100)
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
                    .graphiteCard(highlighted: true)
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "sparkles")
                        Text("Want it even more personal? Add your Gemini API key in Profile to unlock the AI coach — it can rebuild this plan and adapt it as you go.")
                            .font(.footnote)
                    }
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 4)
                }
            } else {
                CoachOrb(size: 88, animating: true)
                Text("building your plan…")
                    .font(.system(size: 26, weight: .light))
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
        case .notes:
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
        draft.age = age
        draft.heightCm = Double(heightCm)
        draft.bodyWeightKg = WeightUnit.toKg(Double(weight), metric: draft.useMetric)
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

    private func feetAndInches(_ cm: Int) -> String {
        let totalInches = Double(cm) / 2.54
        let feet = Int(totalInches / 12)
        let inches = Int(totalInches.rounded()) - feet * 12
        return "≈ \(feet)′ \(inches)″"
    }
}

// MARK: - Helpers

/// Lowercase light question title + small subtitle, as in the reference design.
private struct QuestionTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 32, weight: .light))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StepScroll<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                QuestionTitle(title: title, subtitle: subtitle)
                content
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

/// A question with a centred number wheel.
private struct WheelStep<Wheel: View, Footnote: View>: View {
    let title: String
    let subtitle: String
    let wheel: Wheel
    let footnote: Footnote

    init(title: String, subtitle: String, @ViewBuilder wheel: () -> Wheel,
         @ViewBuilder footnote: () -> Footnote) {
        self.title = title
        self.subtitle = subtitle
        self.wheel = wheel()
        self.footnote = footnote()
    }

    var body: some View {
        VStack(spacing: 0) {
            QuestionTitle(title: title, subtitle: subtitle)
                .padding(.horizontal, 24)
                .padding(.top, 28)
            Spacer(minLength: 8)
            wheel
            footnote
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 8)
            Spacer(minLength: 8)
        }
    }
}

extension WheelStep where Footnote == EmptyView {
    init(title: String, subtitle: String, @ViewBuilder wheel: () -> Wheel) {
        self.init(title: title, subtitle: subtitle, wheel: wheel, footnote: { EmptyView() })
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

/// Graphite "Continue" for each question; the lime primary button for the final "Let's go".
private struct FooterButtonStyle: ButtonStyle {
    let prominent: Bool

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        if prominent {
            PrimaryButtonStyle().makeBody(configuration: configuration)
        } else {
            DarkCapsuleButtonStyle().makeBody(configuration: configuration)
        }
    }
}
