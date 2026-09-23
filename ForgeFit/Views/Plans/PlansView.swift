import SwiftUI

struct PlansView: View {
    @Environment(AppStore.self) private var store
    @State private var showGenerator = false
    @State private var showBuilder = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    createSection
                    if let active = store.activePlan {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Active plan")
                            NavigationLink(value: active.id) {
                                PlanCard(plan: active, isActive: true)
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                    let others = store.plans.filter { $0.id != store.activePlanID }
                    if !others.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Saved plans")
                            ForEach(others) { plan in
                                NavigationLink(value: plan.id) {
                                    PlanCard(plan: plan, isActive: false)
                                }
                                .buttonStyle(PressableStyle())
                            }
                        }
                    }
                    ExerciseLibraryLink()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .appBackground()
            .navigationTitle("Plans")
            .navigationDestination(for: UUID.self) { id in
                PlanDetailView(planID: id)
            }
            .resumeWorkoutBar()
            .sheet(isPresented: $showGenerator) { GeneratePlanView().environment(store) }
            .sheet(isPresented: $showBuilder) { PlanBuilderView(existing: nil).environment(store) }
        }
    }

    private var createSection: some View {
        VStack(spacing: 12) {
            Button {
                showGenerator = true
            } label: {
                HStack(spacing: 14) {
                    GradientIcon(symbol: "sparkles", gradient: Theme.aiGradient, size: 50, foreground: .white)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("Generate a plan").font(.headline)
                            if store.hasAPIKey { AIBadge() }
                        }
                        Text("Pick your goal and the machines you have — get a full program in seconds.")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").foregroundStyle(Theme.textTertiary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(LinearGradient(colors: [Theme.violet.opacity(0.25), Theme.blue.opacity(0.1)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                )
                .glowBorder(Theme.aiGradient, radius: 22, width: 1)
            }
            .buttonStyle(PressableStyle())

            Button {
                showBuilder = true
            } label: {
                HStack(spacing: 14) {
                    GradientIcon(symbol: "hammer.fill", gradient: Theme.warmGradient, size: 50, foreground: .white)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Build your own").font(.headline)
                        Text("Choose every exercise, set and rep yourself.")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").foregroundStyle(Theme.textTertiary)
                }
                .cardStyle(padding: 16, radius: 22)
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.top, 4)
    }
}

struct PlanCard: View {
    let plan: WorkoutPlan
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        TagLabel(text: plan.source.label, symbol: plan.source.symbol,
                                 color: plan.source == .ai ? Theme.violet : Theme.accent)
                        if isActive { TagLabel(text: "Active", symbol: "bolt.fill", color: Theme.accent) }
                    }
                    Text(plan.name)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                GradientIcon(symbol: plan.goal.symbol, gradient: Theme.tint(for: plan.goal), size: 40, foreground: .white)
            }
            if !plan.summary.isEmpty {
                Text(plan.summary)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(plan.days) { day in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(day.name).font(.caption.weight(.bold)).foregroundStyle(.white)
                            Text("\(day.exercises.count) ex").font(.caption2).foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.surfaceRaised))
                    }
                }
            }
        }
        .cardStyle(radius: 22)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(isActive ? Theme.accent.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
    }
}

private struct ExerciseLibraryLink: View {
    var body: some View {
        NavigationLink {
            ExerciseLibraryView()
        } label: {
            HStack(spacing: 14) {
                GradientIcon(symbol: "books.vertical.fill", gradient: Theme.accentGradient, size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Exercise library").font(.headline).foregroundStyle(.white)
                    Text("\(ExerciseLibrary.all.count) exercises with form cues")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.textTertiary)
            }
            .cardStyle(padding: 14, radius: 20)
        }
        .buttonStyle(PressableStyle())
    }
}

struct ExerciseLibraryView: View {
    @State private var search = ""
    @State private var muscle: MuscleGroup?

    private var filtered: [Exercise] {
        ExerciseLibrary.all.filter { ex in
            (muscle == nil || ex.primary == muscle) &&
            (search.isEmpty || ex.name.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                MuscleFilterBar(selection: $muscle)
                LazyVStack(spacing: 10) {
                    ForEach(filtered) { ex in
                        ExerciseInfoRow(exercise: ex)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .appBackground()
        .navigationTitle("Exercises")
        .searchable(text: $search, prompt: "Search exercises")
    }
}

struct ExerciseInfoRow: View {
    let exercise: Exercise
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: exercise.primary.symbol)
                    .font(.headline)
                    .foregroundStyle(Theme.color(for: exercise.primary))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.color(for: exercise.primary).opacity(0.15)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.name).font(.subheadline.weight(.bold))
                    Text("\(exercise.primary.displayName) · \(exercise.equipmentLabel)")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textTertiary)
                    .rotationEffect(.degrees(expanded ? 180 : 0))
            }
            if expanded {
                Text(exercise.cue)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                if !exercise.secondary.isEmpty {
                    Text("Also works: " + exercise.secondary.map(\.displayName).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .cardStyle(padding: 12, radius: 18)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { expanded.toggle() }
        }
    }
}

struct MuscleFilterBar: View {
    @Binding var selection: MuscleGroup?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button { selection = nil } label: {
                    Chip(title: "All", isSelected: selection == nil)
                }
                .buttonStyle(.plain)
                ForEach(MuscleGroup.allCases) { muscle in
                    Button {
                        selection = selection == muscle ? nil : muscle
                        Haptics.tap()
                    } label: {
                        Chip(title: muscle.displayName, isSelected: selection == muscle, tint: Theme.color(for: muscle))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
