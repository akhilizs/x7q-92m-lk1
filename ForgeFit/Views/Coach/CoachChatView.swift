import SwiftUI

struct CoachChatView: View {
    @Environment(AppStore.self) private var store
    /// Owned by the tab container so a streaming reply survives tab switches.
    @Environment(CoachViewModel.self) private var model
    @State private var input = ""
    @State private var showKeySheet = false
    @State private var previewPlan: WorkoutPlan?
    @State private var confirmClear = false
    @State private var promptCategory = PromptCategory.all[0].id
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            if store.chatMessages.isEmpty {
                                welcome
                            }
                            ForEach(store.chatMessages) { message in
                                MessageBubble(message: message,
                                              onPreview: { previewPlan = $0 },
                                              onApply: { apply(messageID: message.id) },
                                              onDismiss: { store.dismissProposal(messageID: message.id) })
                                    .id(message.id)
                            }
                            if model.isResponding {
                                LiveBubble(text: model.liveText, status: model.status)
                                    .id("live")
                            }
                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                    .scrollDismissesKeyboard(.immediately)
                    .onChange(of: store.chatMessages.count) { _, _ in
                        withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                    .onChange(of: model.liveText) { _, _ in
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                    .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                quickPrompts
                inputBar
            }
            .appBackground()
            .resumeWorkoutBar()
            .navigationTitle("Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        CoachOrb(size: 26, animating: model.isResponding, ambient: true)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Coach Forge").font(.subheadline.weight(.semibold))
                            Text(model.isResponding ? "typing…" : (model.answeredBy ?? store.aiModel).displayName)
                                .font(.caption2)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showKeySheet = true
                        } label: { Label("AI settings", systemImage: "key.fill") }
                        Button(role: .destructive) {
                            confirmClear = true
                        } label: { Label("Clear conversation", systemImage: "trash") }
                            .disabled(store.chatMessages.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showKeySheet) {
                NavigationStack { AISettingsView(showsDoneButton: true) }
                    .environment(store)
            }
            .sheet(item: $previewPlan) { plan in
                NavigationStack {
                    PlanContentView(plan: plan)
                        .navigationTitle("Proposed plan")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { previewPlan = nil }
                            }
                        }
                }
            }
            .confirmationDialog("Clear the conversation?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear", role: .destructive) {
                    model.stop()
                    store.clearChat()
                }
            } message: {
                Text("Your plan and workouts are not affected.")
            }
        }
    }

    // MARK: Welcome

    private var welcome: some View {
        VStack(spacing: 20) {
            CoachOrb(size: 92, ambient: true)
                .padding(.top, 28)
                .padding(.bottom, 6)
            VStack(spacing: 8) {
                Text("Hey\(store.profile.firstName.isEmpty ? "" : " \(store.profile.firstName)"), I'm your coach")
                    .font(.display(21))
                    .multilineTextAlignment(.center)
                Text("Tell me what's going on — sore joints, no time, a plateau, low motivation — and I'll adjust your plan to fit.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if !store.hasAPIKey {
                VStack(spacing: 12) {
                    Label("Connect Gemini to start chatting", systemImage: "key.fill")
                        .font(.subheadline.weight(.semibold))
                    Text("The coach runs on Google's Gemini. Add your API key from Google AI Studio — it's stored securely in your iPhone's Keychain.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Add API key") { showKeySheet = true }
                        .buttonStyle(PrimaryButtonStyle())
                }
                .cardStyle()
            } else {
                promptPicker
            }
        }
        .padding(.bottom, 12)
    }

    /// Category chips, then a swipeable row of ready-made prompts for the chosen category.
    private var promptPicker: some View {
        let category = PromptCategory.all.first { $0.id == promptCategory } ?? PromptCategory.all[0]
        return VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PromptCategory.all) { item in
                        let selected = item.id == promptCategory
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { promptCategory = item.id }
                            Haptics.select()
                        } label: {
                            Label(item.title, systemImage: item.symbol)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(selected ? Theme.ink : .white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(Capsule().fill(selected ? AnyShapeStyle(Theme.volt) : AnyShapeStyle(Theme.surfaceRaised)))
                                .overlay(Capsule().strokeBorder(Color.white.opacity(selected ? 0 : 0.1)))
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.horizontal, -16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(category.prompts, id: \.self) { prompt in
                        Button {
                            send(prompt)
                        } label: {
                            VStack(alignment: .leading, spacing: 14) {
                                Image(systemName: category.symbol)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Theme.volt)
                                    .frame(width: 30, height: 30)
                                    .background(Circle().fill(Theme.volt.opacity(0.12)))
                                Text(prompt)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                                HStack {
                                    Text("Ask")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Theme.textSecondary)
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Theme.volt)
                                }
                            }
                            .frame(width: 168, height: 150, alignment: .topLeading)
                            .graphiteCard(padding: 14, radius: 22)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 16)
            }
            .scrollTargetBehavior(.viewAligned)
            .padding(.horizontal, -16)
            .id(category.id)
            .transition(.opacity)
        }
    }

    /// Once the chat has started: a slim strip of prompts above the input.
    @ViewBuilder
    private var quickPrompts: some View {
        if store.hasAPIKey && !store.chatMessages.isEmpty && !model.isResponding && !inputFocused
            && input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PromptCategory.quick, id: \.self) { prompt in
                        Button {
                            send(prompt)
                        } label: {
                            Text(prompt)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Theme.surfaceRaised))
                                .overlay(Capsule().strokeBorder(Color.white.opacity(0.1)))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.horizontal, 12)
            }
            .padding(.top, 6)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: Input

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if inputFocused {
                Button {
                    inputFocused = false
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(Theme.surfaceRaised))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Hide keyboard")
                .transition(.scale.combined(with: .opacity))
            }

            TextField(store.hasAPIKey ? "Tell your coach how it's going…" : "Add an API key to chat", text: $input, axis: .vertical)
                .lineLimit(1...5)
                .focused($inputFocused)
                .accessibilityIdentifier("coachInput")
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.stroke))
                .disabled(!store.hasAPIKey)

            if model.isResponding {
                Button {
                    model.stop()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(Theme.surfaceRaised))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Stop reply")
            } else {
                Button {
                    send(input)
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(Theme.volt))
                        .shadow(color: Theme.volt.opacity(canSend ? 0.45 : 0), radius: 10)
                        .opacity(canSend ? 1 : 0.4)
                }
                .buttonStyle(PressableStyle())
                .disabled(!canSend)
                .accessibilityLabel("Send")
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Theme.background.opacity(0.85))
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: inputFocused)
    }

    private var canSend: Bool {
        store.hasAPIKey && !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send(_ text: String) {
        guard store.hasAPIKey else {
            showKeySheet = true
            return
        }
        model.send(text, store: store)
        input = ""
        // Give the reply the whole screen; tap the field to keep typing.
        inputFocused = false
    }

    private func apply(messageID: UUID) {
        store.applyProposal(messageID: messageID)
        Haptics.success()
    }
}

// MARK: - Bubbles

private struct MessageBubble: View {
    let message: ChatMessage
    let onPreview: (WorkoutPlan) -> Void
    let onApply: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        if message.role == .user {
            HStack {
                Spacer(minLength: 50)
                Text(message.text)
                    .font(.body)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(
                        UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 20,
                                               bottomTrailingRadius: 6, topTrailingRadius: 20, style: .continuous)
                            .fill(Theme.accentGradient)
                    )
                    .textSelection(.enabled)
            }
        } else {
            HStack(alignment: .top, spacing: 10) {
                CoachOrb(size: 30)
                VStack(alignment: .leading, spacing: 10) {
                    if !message.text.isEmpty {
                        MarkdownText(message.text)
                            .foregroundStyle(message.isError ? Theme.danger : Color.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 11)
                            .background(
                                UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 20,
                                                       bottomTrailingRadius: 20, topTrailingRadius: 20, style: .continuous)
                                    .fill(message.isError ? Theme.danger.opacity(0.12) : Theme.surface)
                            )
                            .overlay(
                                UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 20,
                                                       bottomTrailingRadius: 20, topTrailingRadius: 20, style: .continuous)
                                    .stroke(Theme.stroke, lineWidth: 1)
                            )
                            .textSelection(.enabled)
                    }
                    if let proposal = message.proposal {
                        ProposalCard(proposal: proposal,
                                     onPreview: { onPreview(proposal.plan) },
                                     onApply: onApply,
                                     onDismiss: onDismiss)
                    }
                }
                Spacer(minLength: 24)
            }
        }
    }
}

private struct LiveBubble: View {
    let text: String
    let status: String?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            CoachOrb(size: 30, animating: true, ambient: true)
            VStack(alignment: .leading, spacing: 8) {
                if !text.isEmpty {
                    MarkdownText(text)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(
                            UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 20,
                                                   bottomTrailingRadius: 20, topTrailingRadius: 20, style: .continuous)
                                .fill(Theme.surface)
                        )
                }
                if let status {
                    HStack(spacing: 8) {
                        TypingDots()
                        Text(status)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Theme.surface))
                } else if text.isEmpty {
                    TypingDots()
                        .padding(14)
                        .background(Capsule().fill(Theme.surface))
                }
            }
            Spacer(minLength: 24)
        }
    }
}

private struct TypingDots: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
                    .scaleEffect(animate ? 1 : 0.5)
                    .opacity(animate ? 1 : 0.4)
                    .animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15), value: animate)
            }
        }
        .onAppear { animate = true }
    }
}

private struct ProposalCard: View {
    let proposal: PlanProposal
    let onPreview: () -> Void
    let onApply: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        VoltTag(text: "Plan update", symbol: "sparkles", filled: proposal.status == .pending)
                        switch proposal.status {
                        case .applied: VoltTag(text: "Applied", symbol: "checkmark")
                        case .dismissed: VoltTag(text: "Dismissed")
                        case .pending: EmptyView()
                        }
                    }
                    Text(proposal.plan.name)
                        .font(.display(18))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                MuscleMapView(exercises: proposal.plan.days.flatMap(\.exercises), glow: proposal.status == .pending)
                    .frame(width: 62, height: 82)
            }
            if !proposal.changeSummary.isEmpty {
                Text(proposal.changeSummary)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(proposal.plan.days) { day in
                    HStack {
                        Text(day.name).font(.caption.weight(.semibold))
                        Spacer()
                        Text("\(day.exercises.count) exercises · ~\(day.estimatedMinutes) min")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.05)))

            HStack(spacing: 10) {
                Button(action: onPreview) {
                    Text("Preview")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Capsule().fill(Color.white.opacity(0.1)))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.14)))
                }
                .buttonStyle(PressableStyle())
                if proposal.status == .pending {
                    Button(action: onApply) {
                        Label("Apply", systemImage: "checkmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(Capsule().fill(Theme.volt))
                            .shadow(color: Theme.volt.opacity(0.4), radius: 12)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            if proposal.status == .pending {
                Button("Not now", action: onDismiss)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .graphiteCard(padding: 16, radius: 24, highlighted: proposal.status == .pending)
    }
}

/// Renders the lightweight markdown the coach uses in chat (bold, italics, bullet lists).
struct MarkdownText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                if line.isBullet {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Circle().fill(Color.white.opacity(0.7)).frame(width: 5, height: 5).offset(y: -3)
                        Text(Self.attributed(line.text))
                    }
                } else if line.text.isEmpty {
                    Color.clear.frame(height: 2)
                } else {
                    Text(Self.attributed(line.text))
                }
            }
        }
        .font(.body)
        .fixedSize(horizontal: false, vertical: true)
    }

    private struct Line {
        let text: String
        let isBullet: Bool
    }

    private var lines: [Line] {
        text.components(separatedBy: "\n").map { (raw: String) -> Line in
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            for prefix in ["- ", "* ", "• "] where trimmed.hasPrefix(prefix) {
                return Line(text: String(trimmed.dropFirst(prefix.count)), isBullet: true)
            }
            let stripped = trimmed.hasPrefix("#") ? trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "# ")) : trimmed
            return Line(text: stripped, isBullet: false)
        }
    }

    static func attributed(_ string: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: string, options: options)) ?? AttributedString(string)
    }
}

// MARK: - Prompts

/// Ready-made things to ask the coach, grouped so they fit in a swipeable row.
struct PromptCategory: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let prompts: [String]

    static let all: [PromptCategory] = [
        PromptCategory(id: "fixes", title: "Quick fixes", symbol: "bandage.fill", prompts: [
            "My knees hurt when I squat",
            "I only have 30 minutes today",
            "My lower back feels tight",
            "My shoulder clicks when I press",
        ]),
        PromptCategory(id: "plan", title: "Adjust my plan", symbol: "slider.horizontal.3", prompts: [
            "Make my plan harder",
            "I want bigger arms",
            "I can only train 3 days a week now",
            "Swap what my gym doesn't have",
        ]),
        PromptCategory(id: "progress", title: "Progress", symbol: "chart.line.uptrend.xyaxis", prompts: [
            "I'm not seeing progress anymore",
            "When should I add weight?",
            "Am I doing enough volume?",
        ]),
        PromptCategory(id: "motivation", title: "Motivation", symbol: "flame.fill", prompts: [
            "I'm tired and unmotivated",
            "Help me come back after a break",
            "How do I stay consistent?",
        ]),
    ]

    /// A short mix for the strip above the input once the chat has started.
    static let quick = ["Make my plan harder", "I only have 30 minutes today", "My knees hurt when I squat",
                        "When should I add weight?", "I'm tired and unmotivated"]
}
