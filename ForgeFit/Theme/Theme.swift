import SwiftUI
import UIKit

/// Dark design system: pure black canvas, graphite cards, and one high-energy accent
/// (electric lime) for the things that matter — start, streaks, progress, the active tab.
enum Theme {
    // Canvas & surfaces
    static let background = Color.black
    static let surface = Color(white: 0.085)
    static let surfaceRaised = Color(white: 0.13)
    static let surfaceHigh = Color(white: 0.19)
    static let stroke = Color.white.opacity(0.07)

    // Text: bright white for key numbers and titles, muted grey (#8E8E93) for captions.
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 0.557, green: 0.557, blue: 0.576)
    static let textTertiary = Color(red: 0.36, green: 0.36, blue: 0.38)

    /// Electric lime (#D4FF00): primary buttons, streaks, completed sets, trends, the active tab.
    static let volt = Color(red: 212 / 255, green: 1, blue: 0)
    /// A deeper lime for gradients and glows.
    static let voltDeep = Color(red: 0.55, green: 0.78, blue: 0)
    static let voltGradient = LinearGradient(colors: [Color(red: 0.90, green: 1, blue: 0.42), volt],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)

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
    /// Wide, heavy display face for screen titles, workout and plan names.
    static func display(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight).width(.expanded)
    }

    /// Key numbers (volume, time, streaks): wide and bold, with even-width digits.
    static func metric(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight).width(.expanded).monospacedDigit()
    }
}

extension View {
    /// Small uppercase label above a section or a number ("THIS WEEK", "VOLUME").
    func eyebrow() -> some View {
        font(.system(size: 11, weight: .bold).width(.expanded))
            .tracking(0.9)
            .textCase(.uppercase)
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

    /// The standard card: graphite with a soft top light (see `graphiteCard`).
    func cardStyle(padding: CGFloat = 16, radius: CGFloat = 24) -> some View {
        graphiteCard(padding: padding, radius: radius)
    }

    /// Dark graphite card with a soft top light. `highlighted` adds a lime edge and glow
    /// (the active plan, the next day).
    func graphiteCard(padding: CGFloat = 18, radius: CGFloat = 26, highlighted: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return self
            .padding(padding)
            .background(
                shape.fill(LinearGradient(colors: [Color(white: 0.135), Color(white: 0.065)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(
                shape.strokeBorder(
                    highlighted
                        ? LinearGradient(colors: [Theme.volt.opacity(0.85), Theme.volt.opacity(0.12)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.white.opacity(0.14), Color.white.opacity(0.03)],
                                         startPoint: .top, endPoint: .bottom),
                    lineWidth: highlighted ? 1.2 : 1)
            )
            .shadow(color: highlighted ? Theme.volt.opacity(0.16) : .clear, radius: highlighted ? 18 : 0, y: highlighted ? 4 : 0)
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
            .frame(height: 56)
            .background(Capsule().fill(gradient))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
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
