import SwiftUI
import UIKit

enum Theme {
    // Base palette
    static let background = Color(red: 0.035, green: 0.035, blue: 0.055)
    static let surface = Color(red: 0.085, green: 0.085, blue: 0.115)
    static let surfaceRaised = Color(red: 0.12, green: 0.12, blue: 0.16)
    static let stroke = Color.white.opacity(0.08)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.62)
    static let textTertiary = Color.white.opacity(0.38)

    // Brand
    static let accent = Color(red: 0.78, green: 1.0, blue: 0.24)       // volt lime
    static let accentAlt = Color(red: 0.22, green: 0.94, blue: 0.78)   // aqua
    static let violet = Color(red: 0.58, green: 0.40, blue: 1.0)
    static let blue = Color(red: 0.26, green: 0.56, blue: 1.0)
    static let pink = Color(red: 1.0, green: 0.36, blue: 0.62)
    static let orange = Color(red: 1.0, green: 0.55, blue: 0.24)
    static let danger = Color(red: 1.0, green: 0.33, blue: 0.36)

    static let accentGradient = LinearGradient(colors: [accent, accentAlt],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
    static let aiGradient = LinearGradient(colors: [violet, blue],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
    static let warmGradient = LinearGradient(colors: [orange, pink],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)

    static func tint(for goal: FitnessGoal) -> LinearGradient {
        switch goal {
        case .buildMuscle: return LinearGradient(colors: [violet, blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .getStronger: return LinearGradient(colors: [orange, danger], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .loseFat: return LinearGradient(colors: [pink, orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .endurance: return LinearGradient(colors: [accentAlt, blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .athletic: return LinearGradient(colors: [accent, accentAlt], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .generalFitness: return LinearGradient(colors: [accentAlt, accent], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    static func color(for muscle: MuscleGroup) -> Color {
        switch muscle {
        case .chest: return pink
        case .back: return blue
        case .shoulders: return violet
        case .biceps, .triceps, .forearms: return orange
        case .quads, .hamstrings, .glutes, .calves: return accentAlt
        case .core: return accent
        case .fullBody: return accent
        case .cardio: return danger
        }
    }
}

// MARK: - Background

struct AppBackground: View {
    var body: some View {
        ZStack {
            Theme.background
            Circle()
                .fill(Theme.violet.opacity(0.22))
                .frame(width: 420, height: 420)
                .blur(radius: 120)
                .offset(x: -160, y: -340)
            Circle()
                .fill(Theme.accent.opacity(0.10))
                .frame(width: 380, height: 380)
                .blur(radius: 120)
                .offset(x: 180, y: 260)
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Dark gradient app background behind scroll content.
    func appBackground() -> some View {
        background(AppBackground())
    }

    func cardStyle(padding: CGFloat = 16, radius: CGFloat = 22) -> some View {
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

    func glowBorder(_ gradient: LinearGradient, radius: CGFloat = 24, width: CGFloat = 1.5) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(gradient, lineWidth: width)
        )
    }
}

// MARK: - Button styles

struct PrimaryButtonStyle: ButtonStyle {
    var gradient: LinearGradient = Theme.accentGradient
    var foreground: Color = .black

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded).weight(.bold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Capsule().fill(gradient))
            .shadow(color: Theme.accent.opacity(configuration.isPressed ? 0.1 : 0.25), radius: 16, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Capsule().fill(Theme.surfaceRaised))
            .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
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
