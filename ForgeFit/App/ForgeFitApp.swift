import SwiftUI
import UIKit
import Combine

@main
struct ForgeFitApp: App {
    @State private var store: AppStore
    @State private var sync: CloudSync

    init() {
        let store = AppStore()
        let sync = CloudSync()
        sync.attach(store)
        _store = State(initialValue: store)
        _sync = State(initialValue: sync)

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
                .environment(sync)
                .preferredColorScheme(.dark)
                .tint(.white)
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
    @Environment(CloudSync.self) private var sync
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
        .onAppear {
            TapOutsideToDismissKeyboard.shared.install()
            WorkoutLiveActivity.sync(store.activeSession, metric: store.profile.useMetric)
        }
        .task { await sync.sync() }
        // Keeps the Lock Screen / Dynamic Island in step with the workout in progress.
        .onChange(of: store.activeSession) { _, session in
            WorkoutLiveActivity.sync(session, metric: store.profile.useMetric)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                TapOutsideToDismissKeyboard.shared.install()
                WorkoutLiveActivity.sync(store.activeSession, metric: store.profile.useMetric)
                Reminders.reschedule(for: store)
                Task { await sync.sync() }
            case .background:
                store.saveNow()
                uploadBeforeSuspending()
            default:
                store.saveNow()
            }
        }
        .onOpenURL { url in
            if url.host == "workout" {
                // Tapped the workout on the Lock Screen or in the Dynamic Island.
                if store.activeSession != nil { store.isWorkoutPresented = true }
                return
            }
            Task { await sync.handleCallback(url) }
        }
        .sheet(isPresented: Binding(get: { sync.isResettingPassword },
                                    set: { if !$0 { sync.isResettingPassword = false } })) {
            NavigationStack { SetPasswordView() }
                .environment(sync)
        }
        .sheet(isPresented: Binding(get: { sync.conflict != nil }, set: { _ in })) {
            if let conflict = sync.conflict {
                ConflictChoiceView(conflict: conflict, localWorkouts: store.sessions.count) { choice in
                    Task { await sync.resolveConflict(choice) }
                }
                .appBackground()
                .interactiveDismissDisabled()
            }
        }
        .alert(sync.notice ?? "", isPresented: Binding(get: { sync.notice != nil },
                                                       set: { if !$0 { sync.notice = nil } })) {
            Button("OK") { sync.notice = nil }
        }
    }

    /// Gives pending changes a chance to reach the account before iOS suspends the app.
    private func uploadBeforeSuspending() {
        guard sync.isSignedIn, sync.hasLocalChanges else { return }
        let backgroundTask = BackgroundTask()
        backgroundTask.id = UIApplication.shared.beginBackgroundTask(withName: "Save progress") {
            backgroundTask.end()
        }
        Task {
            await sync.sync()
            backgroundTask.end()
        }
    }
}

@MainActor
private final class BackgroundTask {
    var id = UIBackgroundTaskIdentifier.invalid

    func end() {
        guard id != .invalid else { return }
        UIApplication.shared.endBackgroundTask(id)
        id = .invalid
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
                    .padding(.top, 30)
                    .padding(.bottom, 6)
                    .frame(maxWidth: .infinity)
                    .background(BottomBlurBackground())
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
        .sheet(item: $store.completedWorkout) { completed in
            WorkoutSummaryView(completed: completed)
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
    @Namespace private var tabIndicator

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
                        .font(.system(size: 17, weight: selected ? .bold : .regular))
                        .foregroundStyle(selected ? Theme.ink : Color.white.opacity(0.6))
                        .frame(width: 50, height: 50)
                        .background {
                            if selected {
                                Circle()
                                    .fill(Theme.volt)
                                    .shadow(color: Theme.volt.opacity(0.55), radius: 12)
                                    .matchedGeometryEffect(id: "selectedTab", in: tabIndicator)
                            }
                        }
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
                .fill(LinearGradient(colors: [Color(white: 0.15), Color(white: 0.07)], startPoint: .top, endPoint: .bottom))
                .overlay(Capsule().strokeBorder(LinearGradient(colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)],
                                                               startPoint: .top, endPoint: .bottom), lineWidth: 1))
                // A faint lime halo under the bar, plus a deep shadow to lift it off the content.
                .shadow(color: Theme.volt.opacity(0.10), radius: 24, y: 6)
                .shadow(color: .black.opacity(0.8), radius: 20, y: 10)
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
