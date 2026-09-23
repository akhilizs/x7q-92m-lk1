import SwiftUI
import UIKit

@main
struct ForgeFitApp: App {
    @State private var store = AppStore()

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
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

enum AppTab: Hashable {
    case home, plans, coach, progress, profile
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

struct MainTabView: View {
    @Environment(AppStore.self) private var store
    @State private var selection: AppTab = .home

    var body: some View {
        @Bindable var store = store
        TabView(selection: $selection) {
            HomeView(selection: $selection)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(AppTab.home)
            PlansView()
                .tabItem { Label("Plans", systemImage: "list.bullet.rectangle.portrait.fill") }
                .tag(AppTab.plans)
            CoachChatView()
                .tabItem { Label("Coach", systemImage: "sparkles") }
                .tag(AppTab.coach)
            StatsView()
                .tabItem { Label("Progress", systemImage: "chart.bar.xaxis") }
                .tag(AppTab.progress)
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
                .tag(AppTab.profile)
        }
        .fullScreenCover(isPresented: $store.isWorkoutPresented) {
            ActiveWorkoutView()
                .environment(store)
        }
    }
}

/// Floating "workout in progress" bar shown when the active workout is minimized.
struct ResumeWorkoutBar: ViewModifier {
    @Environment(AppStore.self) private var store

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom) {
            if let session = store.activeSession, !store.isWorkoutPresented {
                Button {
                    store.isWorkoutPresented = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Theme.accentGradient))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.name).font(.subheadline.weight(.bold))
                            TimelineView(.periodic(from: .now, by: 1)) { _ in
                                Text("In progress · \(Format.duration(session.duration))")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        Spacer()
                        Text("Resume")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.accent)
                    }
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.accent.opacity(0.4)))
                }
                .buttonStyle(PressableStyle())
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
    }
}

extension View {
    func resumeWorkoutBar() -> some View {
        modifier(ResumeWorkoutBar())
    }
}
