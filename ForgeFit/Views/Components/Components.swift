import SwiftUI

struct GradientIcon: View {
    let symbol: String
    var gradient: LinearGradient = Theme.accentGradient
    var size: CGFloat = 44
    var foreground: Color = .black

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .fill(gradient)
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(foreground)
        }
        .frame(width: size, height: size)
    }
}

/// Round icon on a soft circular background.
struct IconBadge: View {
    let symbol: String
    var background: Color = Theme.surfaceHigh
    var foreground: Color = .white
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(Circle().fill(background))
    }
}

struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.display(17, weight: .bold))
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}

struct StatTile: View {
    let value: String
    let label: String
    let symbol: String
    var tint: Color = Theme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Theme.surfaceHigh))
            Text(value)
                .font(.metric(21))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 14, radius: 22)
    }
}

struct Chip: View {
    let title: String
    var symbol: String? = nil
    var isSelected: Bool = false
    var tint: Color = Theme.accent

    var body: some View {
        HStack(spacing: 6) {
            if let symbol {
                Image(systemName: symbol).font(.caption.weight(.semibold))
            }
            Text(title).font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .foregroundStyle(isSelected ? Color.white : Theme.textSecondary)
        .background(
            Capsule().fill(Color(white: isSelected ? 0.16 : 0.08))
        )
        .overlay(Capsule().strokeBorder(Color.white.opacity(isSelected ? 0.6 : 0.08), lineWidth: 1))
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

/// Graphite capsule tag for dark surfaces.
struct TagLabel: View {
    let text: String
    var symbol: String? = nil
    var color: Color = Theme.textSecondary

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol) }
            Text(text)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Theme.surfaceHigh))
    }
}

/// Capsule tag for dark cards: filled lime for the thing that matters ("Active", "Up next"),
/// otherwise a quiet graphite pill.
struct VoltTag: View {
    let text: String
    var symbol: String? = nil
    var filled = false

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol) }
            Text(text)
        }
        .font(.system(size: 10, weight: .heavy).width(.expanded))
        .tracking(0.6)
        .textCase(.uppercase)
        .foregroundStyle(filled ? Theme.ink : .white)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(filled ? AnyShapeStyle(Theme.volt) : AnyShapeStyle(Color.white.opacity(0.09))))
        .overlay(Capsule().strokeBorder(Color.white.opacity(filled ? 0 : 0.08), lineWidth: 1))
    }
}

/// Small icon + text pair for dark cards ("4 days", "~50 min").
struct MetaLabel: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(Theme.textSecondary)
    }
}

/// Black capsule tag for light (pastel) cards — "Yoga", "Bodybuilding".
struct InkTag: View {
    let text: String
    var symbol: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol) }
            Text(text)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Theme.ink))
    }
}

struct AIBadge: View {
    var text: String = "AI"

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
            Text(text)
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(.black)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Theme.aiGradient))
    }
}

/// Brushed-chrome orb that represents the AI coach. With `ambient`, a slowly turning
/// lime/cyan aura breathes behind it, faster while the coach is replying.
struct CoachOrb: View {
    var size: CGFloat = 64
    var animating: Bool = false
    var ambient: Bool = false
    @State private var breathe = false
    @State private var spin = false

    var body: some View {
        ZStack {
            if ambient {
                Circle()
                    .fill(AngularGradient(colors: [Theme.volt, Color(red: 0.25, green: 0.92, blue: 1.0),
                                                   Theme.volt.opacity(0.15), Theme.volt],
                                          center: .center))
                    .frame(width: size * 1.3, height: size * 1.3)
                    .blur(radius: size * 0.3)
                    .opacity(animating ? 0.95 : 0.55)
                    .scaleEffect(breathe ? 1.14 : 0.88)
                    .rotationEffect(.degrees(spin ? 360 : 0))
            } else {
                Circle()
                    .fill(Color.white.opacity(0.35))
                    .blur(radius: size * 0.22)
                    .scaleEffect(breathe ? 1.1 : 0.85)
                    .opacity(animating ? 0.9 : 0.35)
            }
            Circle()
                .fill(Theme.aiGradient)
                .overlay(
                    Circle().fill(RadialGradient(colors: [.white.opacity(0.9), .clear],
                                                 center: .topLeading, startRadius: 1, endRadius: size * 0.6))
                )
                .overlay(Circle().strokeBorder(ambient ? Theme.volt.opacity(0.7) : Color.white.opacity(0.5), lineWidth: 1))
            Image(systemName: "sparkles")
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .rotationEffect(.degrees(breathe && animating ? 10 : 0))
        }
        .frame(width: size, height: size)
        // Restart the loops when the coach starts or stops replying, so the pace follows it.
        .task(id: animating) {
            breathe = false
            spin = false
            try? await Task.sleep(nanoseconds: 20_000_000)
            withAnimation(.easeInOut(duration: animating ? 0.8 : 2.4).repeatForever(autoreverses: true)) {
                breathe = true
            }
            if ambient {
                withAnimation(.linear(duration: animating ? 3 : 10).repeatForever(autoreverses: false)) {
                    spin = true
                }
            }
        }
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            IconBadge(symbol: symbol, size: 56)
            Text(title)
                .font(.system(size: 20, weight: .semibold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: 24)
    }
}

/// A thin bar that fills in when it first appears, with a soft glow in its colour.
struct ProgressBar: View {
    let value: Double
    var fill: Color = Theme.volt
    var height: CGFloat = 5
    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1))
                Capsule().fill(fill)
                    .frame(width: max(height, geo.size.width * (appeared ? min(max(value, 0), 1) : 0)))
                    .shadow(color: fill.opacity(0.4), radius: height * 0.9)
            }
        }
        .frame(height: height)
        .animation(.spring(response: 0.8, dampingFraction: 0.85), value: appeared)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: value)
        .onAppear { appeared = true }
    }
}

/// Segmented dash indicator used at the top of onboarding.
struct DashProgress: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? Color.white : Color.white.opacity(0.18))
                    .frame(height: 3)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: current)
    }
}

/// A progress ring that sweeps in when it first appears.
struct RingView: View {
    let progress: Double
    var color: Color = Theme.volt
    var lineWidth: CGFloat = 6
    var size: CGFloat = 44
    @State private var appeared = false

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.1), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: appeared ? min(max(progress, 0.02), 1) : 0)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.35), radius: lineWidth)
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.9, dampingFraction: 0.85), value: appeared)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
        .onAppear { appeared = true }
    }
}

/// Black & white photo with a readable gradient at the bottom.
struct PhotoBackdrop: View {
    let name: String
    var alignment: Alignment = .center
    var gradientStart: Double = 0.35

    var body: some View {
        GeometryReader { geo in
            Image(name)
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height, alignment: alignment)
                .clipped()
                .overlay(
                    LinearGradient(stops: [
                        .init(color: .clear, location: gradientStart),
                        .init(color: .black.opacity(0.9), location: 1),
                    ], startPoint: .top, endPoint: .bottom)
                )
        }
        .accessibilityHidden(true)
    }
}

/// Text field that edits a Double live (keeps the binding updated on every keystroke).
struct NumberField: View {
    let placeholder: String
    @Binding var value: Double
    var decimals: Bool = true
    @State private var text: String = ""

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(decimals ? .decimalPad : .numberPad)
            .multilineTextAlignment(.center)
            .onAppear { text = Self.format(value) }
            .onChange(of: text) { _, newValue in
                let normalized = newValue.replacingOccurrences(of: ",", with: ".")
                if let parsed = Double(normalized) {
                    if abs(parsed - value) > 0.0001 { value = parsed }
                } else if newValue.isEmpty, value != 0 {
                    value = 0
                }
            }
            .onChange(of: value) { _, newValue in
                let current = Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0
                if abs(current - newValue) > 0.0001 { text = Self.format(newValue) }
            }
    }

    static func format(_ value: Double) -> String {
        if value == 0 { return "" }
        if value.rounded() == value { return String(Int(value)) }
        return String(format: "%.1f", value)
    }
}

/// Integer version of `NumberField`.
struct IntField: View {
    let placeholder: String
    @Binding var value: Int

    var body: some View {
        NumberField(placeholder: placeholder,
                    value: Binding(get: { Double(value) }, set: { value = Int($0.rounded()) }),
                    decimals: false)
    }
}

struct StepperControl: View {
    let label: String
    @Binding var value: Int
    var range: ClosedRange<Int>
    var step: Int = 1
    var format: (Int) -> String = { "\($0)" }

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 4)
            stepButton("minus", accessibility: "Decrease \(label)", disabled: value <= range.lowerBound) {
                value = max(range.lowerBound, value - step)
            }
            Text(format(value))
                .font(.system(.subheadline).weight(.semibold))
                .monospacedDigit()
                .frame(minWidth: 44)
            stepButton("plus", accessibility: "Increase \(label)", disabled: value >= range.upperBound) {
                value = min(range.upperBound, value + step)
            }
        }
    }

    /// A round − / + button. The whole 44 pt square takes the tap (not just the thin symbol),
    /// and holding it keeps stepping.
    private func stepButton(_ symbol: String, accessibility: String, disabled: Bool,
                            action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.tap()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 38, height: 38)
                .background(Circle().fill(Theme.surfaceHigh))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
        .accessibilityLabel(accessibility)
    }
}

/// Simple flow layout that wraps children onto multiple lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Frosted, fading backdrop for buttons and bars that float over scrolling content,
/// so content blurs out underneath instead of being cut off by a hard black edge.
struct BottomBlurBackground: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            LinearGradient(colors: [Color.black.opacity(0), Color.black.opacity(0.5)],
                           startPoint: .top, endPoint: .bottom)
        }
        .mask(
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.45),
                .init(color: .black, location: 1),
            ], startPoint: .top, endPoint: .bottom)
        )
        .ignoresSafeArea(edges: .bottom)
        .allowsHitTesting(false)
    }
}
