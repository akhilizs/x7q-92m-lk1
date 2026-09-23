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
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(foreground)
        }
        .frame(width: size, height: size)
    }
}

struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(.title3, design: .rounded).weight(.bold))
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
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
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(Circle().fill(tint.opacity(0.15)))
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 14, radius: 20)
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
                Image(systemName: symbol).font(.caption.weight(.bold))
            }
            Text(title).font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .foregroundStyle(isSelected ? Color.black : Color.white)
        .background(
            Capsule().fill(isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(Theme.surfaceRaised))
        )
        .overlay(Capsule().strokeBorder(isSelected ? Color.clear : Theme.stroke, lineWidth: 1))
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

struct TagLabel: View {
    let text: String
    var symbol: String? = nil
    var color: Color = Theme.textSecondary

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol) }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.14)))
    }
}

struct AIBadge: View {
    var text: String = "AI"

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
            Text(text)
        }
        .font(.caption2.weight(.heavy))
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Theme.aiGradient))
    }
}

/// Animated glowing orb used to represent the AI coach.
struct CoachOrb: View {
    var size: CGFloat = 64
    var animating: Bool = false
    @State private var phase = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.aiGradient)
                .blur(radius: size * 0.25)
                .opacity(0.8)
                .scaleEffect(phase ? 1.15 : 0.9)
            Circle()
                .fill(Theme.aiGradient)
                .overlay(
                    Circle()
                        .fill(RadialGradient(colors: [.white.opacity(0.55), .clear],
                                             center: .topLeading, startRadius: 1, endRadius: size * 0.7))
                )
            Image(systemName: "sparkles")
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(phase && animating ? 12 : 0))
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeInOut(duration: animating ? 0.9 : 2.4).repeatForever(autoreverses: true)) {
                phase = true
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
            GradientIcon(symbol: symbol, size: 60)
            Text(title)
                .font(.system(.title3, design: .rounded).weight(.bold))
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

/// A thin rounded progress bar.
struct ProgressBar: View {
    let value: Double
    var gradient: LinearGradient = Theme.accentGradient
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule().fill(gradient)
                    .frame(width: max(height, geo.size.width * min(max(value, 0), 1)))
            }
        }
        .frame(height: height)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: value)
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
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 4)
            Button {
                value = max(range.lowerBound, value - step)
                Haptics.tap()
            } label: {
                Image(systemName: "minus").frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .background(Circle().fill(Theme.surfaceRaised))
            Text(format(value))
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .monospacedDigit()
                .frame(minWidth: 44)
            Button {
                value = min(range.upperBound, value + step)
                Haptics.tap()
            } label: {
                Image(systemName: "plus").frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .background(Circle().fill(Theme.surfaceRaised))
        }
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
