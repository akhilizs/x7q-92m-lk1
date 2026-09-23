import SwiftUI

struct CoachChatView: View {
    @Environment(AppStore.self) private var store
    @State private var model = CoachViewModel()
    @State private var input = ""
    @State private var showKeySheet = false
    @State private var previewPlan: WorkoutPlan?
    @State private var confirmClear = false
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
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: store.chatMessages.count) { _, _ in
                        withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                    .onChange(of: model.liveText) { _, _ in
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                    .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                inputBar
            }
            .appBackground()
            .navigationTitle("Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        CoachOrb(size: 26, animating: model.isResponding)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Coach Forge").font(.subheadline.weight(.bold))
                            Text(model.isResponding ? "typing…" : store.aiModel.displayName)
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
        VStack(spacing: 18) {
            CoachOrb(size: 88)
                .padding(.top, 20)
            VStack(spacing: 8) {
                Text("Hey\(store.profile.firstName.isEmpty ? "" : " \(store.profile.firstName)"), I'm your coach")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .multilineTextAlignment(.center)
                Text("Tell me what's going on — sore joints, no time, a plateau, low motivation — and I'll adjust your plan to fit.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if !store.hasAPIKey {
                VStack(spacing: 12) {
                    Label("Connect Claude to start chatting", systemImage: "key.fill")
                        .font(.subheadline.weight(.semibold))
                    Text("The coach runs on Anthropic's Claude. Add your API key — it's stored securely in your iPhone's Keychain.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Add API key") { showKeySheet = true }
                        .buttonStyle(PrimaryButtonStyle(gradient: Theme.aiGradient, foreground: .white))
                }
                .cardStyle()
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(CoachViewModel.suggestions, id: \.self) { suggestion in
                        Button {
                            send(suggestion)
                        } label: {
                            Text(suggestion)
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(Theme.surfaceRaised))
                                .overlay(Capsule().strokeBorder(Theme.violet.opacity(0.4)))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
        }
        .padding(.bottom, 12)
    }

    // MARK: Input

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField(store.hasAPIKey ? "Tell your coach how it's going…" : "Add an API key to chat", text: $input, axis: .vertical)
                .lineLimit(1...5)
                .focused($inputFocused)
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
            } else {
                Button {
                    send(input)
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(Theme.aiGradient))
                        .opacity(canSend ? 1 : 0.4)
                }
                .buttonStyle(PressableStyle())
                .disabled(!canSend)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Theme.background.opacity(0.85))
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
            CoachOrb(size: 30, animating: true)
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
                    .fill(Theme.violet)
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
            HStack(spacing: 8) {
                AIBadge(text: "PLAN UPDATE")
                Spacer()
                switch proposal.status {
                case .applied: TagLabel(text: "Applied", symbol: "checkmark", color: Theme.accent)
                case .dismissed: TagLabel(text: "Dismissed", color: Theme.textTertiary)
                case .pending: EmptyView()
                }
            }
            Text(proposal.plan.name)
                .font(.system(.title3, design: .rounded).weight(.bold))
            if !proposal.changeSummary.isEmpty {
                Text(proposal.changeSummary)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(proposal.plan.days) { day in
                    HStack {
                        Text(day.name).font(.caption.weight(.bold))
                        Spacer()
                        Text("\(day.exercises.count) exercises · ~\(day.estimatedMinutes) min")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black.opacity(0.25)))

            HStack(spacing: 10) {
                Button("Preview", action: onPreview)
                    .buttonStyle(SecondaryButtonStyle())
                if proposal.status == .pending {
                    Button(action: onApply) {
                        Label("Apply", systemImage: "checkmark")
                    }
                    .buttonStyle(PrimaryButtonStyle(gradient: Theme.aiGradient, foreground: .white))
                }
            }
            if proposal.status == .pending {
                Button("Not now", action: onDismiss)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [Theme.violet.opacity(0.22), Theme.blue.opacity(0.1)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .glowBorder(Theme.aiGradient, radius: 22, width: 1)
    }
}

/// Renders the lightweight markdown Claude uses in chat (bold, italics, bullet lists).
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
                        Circle().fill(Theme.violet).frame(width: 5, height: 5).offset(y: -3)
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
