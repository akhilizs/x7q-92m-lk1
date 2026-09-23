import SwiftUI

/// Grid of fitness goal cards.
struct GoalGrid: View {
    @Binding var selection: FitnessGoal

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(FitnessGoal.allCases) { goal in
                GoalCard(goal: goal, isSelected: selection == goal)
                    .onTapGesture {
                        selection = goal
                        Haptics.tap()
                    }
            }
        }
    }
}

private struct GoalCard: View {
    let goal: FitnessGoal
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GradientIcon(symbol: goal.symbol, gradient: Theme.tint(for: goal), size: 40, foreground: .white)
            Text(goal.title)
                .font(.system(.headline, design: .rounded).weight(.bold))
            Text(goal.subtitle)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2, reservesSpace: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isSelected ? Theme.surfaceRaised : Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(isSelected ? AnyShapeStyle(Theme.tint(for: goal)) : AnyShapeStyle(Theme.stroke),
                              lineWidth: isSelected ? 2 : 1)
        )
        .scaleEffect(isSelected ? 1.0 : 0.98)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
    }
}

struct LevelPicker: View {
    @Binding var selection: ExperienceLevel

    var body: some View {
        VStack(spacing: 10) {
            ForEach(ExperienceLevel.allCases) { level in
                let selected = selection == level
                Button {
                    selection = level
                    Haptics.tap()
                } label: {
                    HStack(spacing: 14) {
                        GradientIcon(symbol: level.symbol,
                                     gradient: selected ? Theme.accentGradient : LinearGradient(colors: [Theme.surfaceRaised], startPoint: .top, endPoint: .bottom),
                                     size: 42,
                                     foreground: selected ? .black : .white)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(level.title).font(.headline)
                            Text(level.subtitle)
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(selected ? Theme.accent : Theme.textTertiary)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(selected ? Theme.accent.opacity(0.7) : Theme.stroke, lineWidth: selected ? 1.5 : 1)
                    )
                }
                .buttonStyle(PressableStyle())
            }
        }
    }
}

struct DaysPerWeekPicker: View {
    @Binding var days: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...6, id: \.self) { value in
                let selected = days == value
                Button {
                    days = value
                    Haptics.tap()
                } label: {
                    Text("\(value)")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(selected ? Color.black : Color.white)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(selected ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.surfaceRaised))
                        )
                }
                .buttonStyle(PressableStyle())
            }
        }
    }
}

struct SessionLengthPicker: View {
    @Binding var minutes: Int
    private let options = [30, 45, 60, 75, 90]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { value in
                let selected = minutes == value
                Button {
                    minutes = value
                    Haptics.tap()
                } label: {
                    VStack(spacing: 2) {
                        Text("\(value)")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                        Text("min").font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(selected ? Color.black : Color.white)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(selected ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.surfaceRaised))
                    )
                }
                .buttonStyle(PressableStyle())
            }
        }
    }
}

/// Lets the user pick the machines and equipment they have access to.
struct EquipmentSelector: View {
    @Binding var selection: Set<Equipment>

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(EquipmentPreset.allCases) { preset in
                        Button {
                            selection = preset.equipment
                            Haptics.tap()
                        } label: {
                            Chip(title: preset.title, symbol: preset.symbol,
                                 isSelected: selection == preset.equipment)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            ForEach(EquipmentCategory.allCases) { category in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(category.rawValue.uppercased())
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        let items = Equipment.inCategory(category)
                        let allOn = items.allSatisfy { selection.contains($0) }
                        Button(allOn ? "Clear" : "Select all") {
                            if allOn {
                                selection.subtract(items)
                            } else {
                                selection.formUnion(items)
                            }
                            Haptics.tap()
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    }
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(Equipment.inCategory(category)) { item in
                            EquipmentTile(item: item, isSelected: selection.contains(item))
                                .onTapGesture {
                                    if selection.contains(item) {
                                        selection.remove(item)
                                    } else {
                                        selection.insert(item)
                                    }
                                    Haptics.tap()
                                }
                        }
                    }
                }
            }
        }
    }
}

private struct EquipmentTile: View {
    let item: Equipment
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: item.symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isSelected ? Color.black : Theme.textSecondary)
                .frame(width: 40, height: 40)
                .background(
                    Circle().fill(isSelected ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Color.white.opacity(0.06)))
                )
            Text(item.displayName)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(isSelected ? Color.white : Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isSelected ? Theme.accent.opacity(0.6) : Theme.stroke, lineWidth: isSelected ? 1.5 : 1)
        )
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

/// Optional multi-select of muscle groups to emphasise.
struct MuscleFocusPicker: View {
    @Binding var selection: Set<MuscleGroup>

    private var options: [MuscleGroup] {
        MuscleGroup.allCases.filter { $0 != .fullBody && $0 != .cardio }
    }

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(options) { muscle in
                Button {
                    if selection.contains(muscle) {
                        selection.remove(muscle)
                    } else {
                        selection.insert(muscle)
                    }
                    Haptics.tap()
                } label: {
                    Chip(title: muscle.displayName, isSelected: selection.contains(muscle),
                         tint: Theme.color(for: muscle))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
