import SwiftUI
import UIKit

/// Monochrome "dark mode done right" design system: pure black canvas,
/// graphite cards, white primary actions and soft pastel program cards.
enum Theme {
    // Canvas & surfaces
    static let background = Color.black
    static let surface = Color(white: 0.085)
    static let surfaceRaised = Color(white: 0.13)
    static let surfaceHigh = Color(white: 0.19)
    static let stroke = Color.white.opacity(0.07)

    // Text
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.55)
    static let textTertiary = Color.white.opacity(0.32)

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

    // Monochrome roles
    static let accent = Color.white
    static let accentAlt = Color(white: 0.78)
    static let violet = lilac
    static let pink = rose

    static let accentGradient = LinearGradient(colors: [.white, Color(white: 0.88)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
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

    /// A large figure illustration for program/day cards.
    static func figure(for muscle: MuscleGroup?) -> String {
        switch muscle {
        case .chest, .triceps: return "figure.strengthtraining.functional"
        case .back, .biceps, .forearms: return "figure.rower"
        case .shoulders: return "figure.boxing"
        case .quads, .glutes, .hamstrings, .calves: return "figure.step.training"
        case .core: return "figure.core.training"
        case .cardio: return "figure.run"
        default: return "figure.strengthtraining.traditional"
        }
    }

    static func figure(for goal: FitnessGoal) -> String {
        switch goal {
        case .buildMuscle: return "figure.strengthtraining.traditional"
        case .getStronger: return "figure.cross.training"
        case .loseFat: return "figure.highintensity.intervaltraining"
        case .endurance: return "figure.run"
        case .athletic: return "figure.basketball"
        case .generalFitness: return "figure.mind.and.body"
        }
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

    func cardStyle(padding: CGFloat = 16, radius: CGFloat = 24) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            )
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
