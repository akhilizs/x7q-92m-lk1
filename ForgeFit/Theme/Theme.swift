import SwiftUI
import UIKit

/// Calm dark design system: a charcoal canvas, flat cards, plain type and one soft lime
/// accent used sparingly — the hero card, small pills, progress and the active tab.
enum Theme {
    // Canvas & surfaces
    static let background = Color(white: 16 / 255)       // #101010
    static let surface = Color(white: 28 / 255)          // #1C1C1C
    static let surfaceRaised = Color(white: 38 / 255)    // #262626
    static let surfaceHigh = Color(white: 46 / 255)      // #2E2E2E
    static let stroke = Color.white.opacity(0.05)

    // Text: white for titles and numbers, a warm grey for captions.
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 152 / 255, green: 151 / 255, blue: 147 / 255)   // #989793
    static let textTertiary = Color(red: 0.36, green: 0.36, blue: 0.35)

    /// Soft lime (#D4FC60): the hero card, primary buttons, small pills, progress, the active tab.
    static let volt = Color(red: 212 / 255, green: 252 / 255, blue: 96 / 255)
    /// A muted lime for secondary marks (supporting muscles, past weeks).
    static let voltDeep = Color(red: 0.55, green: 0.66, blue: 0.27)
    /// Flat lime (kept as a gradient so it fits where gradients are expected).
    static let voltGradient = LinearGradient(colors: [volt, volt], startPoint: .top, endPoint: .bottom)

    /// Text and marks placed on light (pastel / white) cards.
    static let ink = Color(red: 0.05, green: 0.05, blue: 0.06)
    static let inkSecondary = Color.black.opacity(0.55)

    // Pastels used for program and highlight cards
    static let paper = Color(red: 0.95, green: 0.95, blue: 0.94)
    static let sky = Color(red: 0.74, green: 0.87, blue: 0.92)
    static let rose = Color(red: 0.91, green: 0.75, blue: 0.90)
    static let sand = Color(red: 0.94, green: 0.89, blue: 0.79)
    static let lilac = Color(red: 0.82, green: 0.79, blue: 0.97)
    static let sage = Color(red: 0.80, green: 0.89, blue: 0.81)
    static let pastels: [Color] = [paper, sky, rose, sand, lilac, sage]

    static func pastel(_ index: Int) -> Color {
        pastels[((index % pastels.count) + pastels.count) % pastels.count]
    }

    // Data accents — used sparingly for rings and charts
    static let orange = Color(red: 1.0, green: 0.62, blue: 0.22)
    static let blue = Color(red: 0.38, green: 0.64, blue: 1.0)
    static let danger = Color(red: 1.0, green: 0.38, blue: 0.38)

    // Roles
    static let accent = volt
    static let accentAlt = Color(white: 0.78)
    static let violet = lilac
    static let pink = rose

    static let accentGradient = voltGradient
    /// Brushed-chrome gradient used for AI elements.
    static let aiGradient = LinearGradient(colors: [Color(white: 0.98), Color(white: 0.70)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
    static let graphiteGradient = LinearGradient(colors: [Color(white: 0.24), Color(white: 0.12)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing)

    static func tint(for goal: FitnessGoal) -> Color {
        switch goal {
        case .buildMuscle: return lilac
        case .getStronger: return sand
        case .loseFat: return rose
        case .endurance: return sky
        case .athletic: return sage
        case .generalFitness: return paper
        }
    }

    static func color(for muscle: MuscleGroup) -> Color {
        switch muscle {
        case .chest: return rose
        case .back: return sky
        case .shoulders: return lilac
        case .biceps, .triceps, .forearms: return sand
        case .quads, .hamstrings, .glutes, .calves: return sage
        case .core: return paper
        case .fullBody: return paper
        case .cardio: return rose
        }
    }
}

// MARK: - Type

extension Font {
    /// Titles, workout and plan names: plain SF Pro, semibold.
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight)
    }

    /// Key numbers (volume, time, calories): semibold with even-width digits.
    static func metric(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight).monospacedDigit()
    }
}

extension View {
    /// Small caption above a number or a section ("Volume", "This week").
    func eyebrow() -> some View {
        font(.caption.weight(.medium))
            .foregroundStyle(Theme.textSecondary)
    }
}

// MARK: - Background

struct AppBackground: View {
    var body: some View {
        Theme.background.ignoresSafeArea()
    }
}

extension View {
    /// Pure black app background behind scroll content.
    func appBackground() -> some View {
        background(AppBackground())
    }

    /// The standard card (see `graphiteCard`).
    func cardStyle(padding: CGFloat = 16, radius: CGFloat = 24) -> some View {
        graphiteCard(padding: padding, radius: radius)
    }

    /// A flat card. `highlighted` adds a thin lime edge (the active plan, the next day).
    func graphiteCard(padding: CGFloat = 18, radius: CGFloat = 26, highlighted: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return self
            .padding(padding)
            .background(shape.fill(Theme.surface))
            .overlay(shape.strokeBorder(highlighted ? Theme.volt.opacity(0.55) : Theme.stroke, lineWidth: 1))
    }

    /// Light pastel card with ink-colored content.
    func pastelCard(_ color: Color, padding: CGFloat = 18, radius: CGFloat = 26) -> some View {
        self
            .padding(padding)
            .foregroundStyle(Theme.ink)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(color)
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    func glowBorder(_ gradient: LinearGradient, radius: CGFloat = 24, width: CGFloat = 1) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(gradient, lineWidth: width)
        )
    }
}

// MARK: - Button styles

/// White capsule with black text — the main call to action.
struct PrimaryButtonStyle: ButtonStyle {
    var gradient: LinearGradient = Theme.accentGradient
    var foreground: Color = .black

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline).weight(.semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Capsule().fill(gradient))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Black capsule with white text, for buttons sitting on a lime card.
struct InkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline).weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Capsule().fill(Theme.ink))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Graphite capsule with white text.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline).weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Capsule().fill(Theme.surfaceRaised))
            .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Dark graphite capsule used for step-by-step flows ("Continue →").
struct DarkCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline).weight(.medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Capsule().fill(Color(white: configuration.isPressed ? 0.22 : 0.17)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Frosted capsule used on top of photos ("Let's Go →").
struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline).weight(.medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Haptics

enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func select() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

// MARK: - Formatting helpers

enum Format {
    static func duration(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }

    static func minutes(_ seconds: TimeInterval) -> String {
        let m = Int(seconds / 60)
        if m >= 60 { return "\(m / 60)h \(m % 60)m" }
        return "\(m) min"
    }

    static func compact(_ value: Double) -> String {
        switch value {
        case 1_000_000...: return String(format: "%.1fM", value / 1_000_000)
        case 10_000...: return String(format: "%.0fk", value / 1000)
        case 1000...: return String(format: "%.1fk", value / 1000)
        default: return String(format: "%.0f", value)
        }
    }

    static func rest(_ seconds: Int) -> String {
        if seconds >= 60 {
            let m = seconds / 60, s = seconds % 60
            return s == 0 ? "\(m) min" : "\(m):\(String(format: "%02d", s))"
        }
        return "\(seconds)s"
    }

    static let dayMonth: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, d MMM"
        return f
    }()

    static let monthYear: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()
}

func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

/// Closes the keyboard when the user taps anywhere outside a text field, on every
/// screen (sheets included). Taps still reach buttons and scroll views as usual.
@MainActor
final class TapOutsideToDismissKeyboard: NSObject, UIGestureRecognizerDelegate {
    static let shared = TapOutsideToDismissKeyboard()
    private weak var window: UIWindow?

    func install() {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        guard let target = windows.first(where: \.isKeyWindow) ?? windows.first,
              target !== window else { return }
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        target.addGestureRecognizer(tap)
        window = target
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        gesture.view?.endEditing(true)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Tapping into (another) text field keeps the keyboard up.
        var view = touch.view
        while let current = view {
            if current is UITextField || current is UITextView { return false }
            view = current.superview
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}
