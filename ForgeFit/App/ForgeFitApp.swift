import SwiftUI
import UIKit
import Combine

@main
struct ForgeFitApp: App {
    @State private var store = AppStore()

    init() {
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.backgroundColor = .black
        nav.titleTextAttributes = [.foregroundColor: UIColor.white]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor.white,
                                        .font: UIFont.systemFont(ofSize: 32, weight: .semibold)]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}

enum AppTab: Hashable, CaseIterable {
    case home, plans, coach, progress, profile

    var title: String {
        switch self {
        case .home: return "Home"
        case .plans: return "Plans"
        case .coach: return "Coach"
        case .progress: return "Progress"
        case .profile: return "Profile"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "house.fill"
        case .plans: return "dumbbell.fill"
        case .coach: return "sparkles"
        case .progress: return "chart.bar.fill"
        case .profile: return "person.fill"
        }
    }
}

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if store.hasOnboarded {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: store.hasOnboarded)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { store.saveNow() }
        }
    }
}

private struct FloatingBarSpaceKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// Height reserved at the bottom of each tab for the floating tab bar.
    var floatingBarSpace: CGFloat {
        get { self[FloatingBarSpaceKey.self] }
        set { self[FloatingBarSpaceKey.self] = newValue }
    }
}

struct MainTabView: View {
    @Environment(AppStore.self) private var store
    @State private var selection: AppTab = .home
    @State private var keyboardVisible = false
    @State private var coach = CoachViewModel()

    var body: some View {
        @Bindable var store = store
        ZStack(alignment: .bottom) {
            // Only the selected tab is in the hierarchy, so hidden tabs never
            // intercept taps or VoiceOver focus.
            tabContent(selection)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .environment(\.floatingBarSpace, keyboardVisible ? 0 : 76)
                .environment(coach)

            if !keyboardVisible {
                FloatingTabBar(selection: $selection)
                    .padding(.bottom, 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: keyboardVisible)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardVisible = false
        }
        .fullScreenCover(isPresented: $store.isWorkoutPresented) {
            ActiveWorkoutView()
                .environment(store)
        }
    }

    @ViewBuilder
    private func tabContent(_ tab: AppTab) -> some View {
        switch tab {
        case .home: HomeView(selection: $selection)
        case .plans: PlansView()
        case .coach: CoachChatView()
        case .progress: StatsView()
        case .profile: ProfileView()
        }
    }
}

/// Capsule tab bar floating above the content; the selected tab becomes a white circle.
struct FloatingTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 14) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let selected = selection == tab
                Button {
                    if selection != tab {
                        selection = tab
                        Haptics.tap()
                    }
                } label: {
                    Image(systemName: tab.symbol)
                        .font(.system(size: 17, weight: selected ? .semibold : .regular))
                        .foregroundStyle(selected ? Color.black : Color.white.opacity(0.7))
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(selected ? Color.white : Color.clear))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Color(white: 0.09))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                .shadow(color: .black.opacity(0.7), radius: 22, y: 8)
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selection)
    }
}

/// Reserves room for the floating tab bar and shows the "workout in progress"
/// bar when the active workout is minimized.
struct ResumeWorkoutBar: ViewModifier {
    @Environment(AppStore.self) private var store
    @Environment(\.floatingBarSpace) private var barSpace

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                if let session = store.activeSession, !store.isWorkoutPresented {
                    Button {
                        store.isWorkoutPresented = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(.white))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.name).font(.subheadline.weight(.semibold))
                                TimelineView(.periodic(from: .now, by: 1)) { _ in
                                    Text("In progress · \(Format.duration(session.duration))")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                            Spacer()
                            Text("Resume")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Capsule().fill(Theme.surfaceRaised))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12)))
                    }
                    .buttonStyle(PressableStyle())
                    .padding(.horizontal, 16)
                }
                Color.clear.frame(height: barSpace)
            }
        }
    }
}

extension View {
    func resumeWorkoutBar() -> some View {
        modifier(ResumeWorkoutBar())
    }
}
