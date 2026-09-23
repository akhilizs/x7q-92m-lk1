import SwiftUI

/// Outlined dark option tile with a title, subtitle and radio indicator.
struct OptionRow: View {
    let symbol: String
    let title: String
    let subtitle: String?
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(isSelected ? Color.white : Theme.textTertiary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 17, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.6))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(isSelected ? Theme.textSecondary : Theme.textTertiary)
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer(minLength: 8)
            ZStack {
                Circle()
                    .strokeBorder(isSelected ? Color.white : Color.white.opacity(0.2), lineWidth: 1.2)
                    .frame(width: 22, height: 22)
                if isSelected {
                    Circle().fill(Color.white).frame(width: 12, height: 12)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: isSelected ? 0.13 : 0.075), Color(white: 0.045)],
                                     startPoint: .top, endPoint: .bottom))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(isSelected ? 0.5 : 0.09), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

/// Fitness goal picker.
struct GoalGrid: View {
    @Binding var selection: FitnessGoal

    var body: some View {
        VStack(spacing: 10) {
            ForEach(FitnessGoal.allCases) { goal in
                Button {
                    selection = goal
                    Haptics.tap()
                } label: {
                    OptionRow(symbol: goal.symbol, title: goal.title, subtitle: goal.subtitle,
                              isSelected: selection == goal)
                }
                .buttonStyle(PressableStyle())
            }
        }
    }
}

struct LevelPicker: View {
    @Binding var selection: ExperienceLevel

    var body: some View {
        VStack(spacing: 10) {
            ForEach(ExperienceLevel.allCases) { level in
                Button {
                    selection = level
                    Haptics.tap()
                } label: {
                    OptionRow(symbol: level.symbol, title: level.title, subtitle: level.subtitle,
                              isSelected: selection == level)
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
                        .font(.system(size: 20, weight: selected ? .medium : .light))
                        .frame(width: 50, height: 50)
                        .foregroundStyle(selected ? Color.white : Theme.textTertiary)
                        .background(
                            Circle().fill(Color(white: selected ? 0.15 : 0.06))
                                .overlay(Circle().strokeBorder(Color.white.opacity(selected ? 0.6 : 0.08), lineWidth: 1))
                        )
                        .frame(maxWidth: .infinity)
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
                    VStack(spacing: 1) {
                        Text("\(value)")
                            .font(.system(size: 17, weight: selected ? .medium : .light))
                        Text("min").font(.caption2)
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .foregroundStyle(selected ? Color.white : Theme.textTertiary)
                    .background(SelectableTileBackground(isSelected: selected, radius: 18))
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
                            .font(.caption.weight(.semibold))
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
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white)
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
                .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.white : Theme.textTertiary)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.white.opacity(isSelected ? 0.14 : 0.04)))
            Text(item.displayName)
                .font(.caption.weight(isSelected ? .medium : .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(isSelected ? Color.white : Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(SelectableTileBackground(isSelected: isSelected, radius: 20))
        .overlay(alignment: .topTrailing) {
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(.white))
                    .padding(8)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

/// Dark gradient tile with a bright outline when selected (no solid white fills).
struct SelectableTileBackground: View {
    let isSelected: Bool
    var radius: CGFloat = 20

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(LinearGradient(colors: [Color(white: isSelected ? 0.15 : 0.075), Color(white: 0.045)],
                                 startPoint: .top, endPoint: .bottom))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.white.opacity(isSelected ? 0.55 : 0.08), lineWidth: 1)
            )
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
                    Chip(title: muscle.displayName, isSelected: selection.contains(muscle))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Onboarding-style controls

/// Vertical number wheel: the selected value is large and bright, neighbours fade out.
struct NumberWheel: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String
    var itemHeight: CGFloat = 92
    var height: CGFloat = 320

    @State private var position: Int?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            // A plain VStack (not lazy) gives exact row positions, so the initial
            // value lands precisely in the centre slot.
            VStack(spacing: 0) {
                ForEach(Array(range), id: \.self) { number in
                    let distance = abs(number - (position ?? value))
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(number)")
                            .font(.system(size: distance == 0 ? 72 : 56, weight: .light))
                            .monospacedDigit()
                        Text(unit)
                            .font(.system(size: 20, weight: .light))
                    }
                    .foregroundStyle(.white.opacity(distance == 0 ? 1 : (distance == 1 ? 0.22 : 0.08)))
                    .frame(maxWidth: .infinity)
                    .frame(height: itemHeight)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.snappy) { position = number }
                    }
                    .id(number)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $position, anchor: .center)
        .safeAreaPadding(.vertical, (height - itemHeight) / 2)
        .frame(height: height)
        .animation(.easeOut(duration: 0.15), value: position)
        .onAppear {
            if position == nil { position = value }
        }
        .onChange(of: position) { _, newValue in
            guard let newValue, newValue != value else { return }
            value = newValue
            Haptics.select()
        }
        .accessibilityElement()
        .accessibilityLabel("\(value) \(unit)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: position = min(range.upperBound, value + 1)
            case .decrement: position = max(range.lowerBound, value - 1)
            @unknown default: break
            }
        }
    }
}

/// Large dark choice tile ("Female" / "Male").
struct ChoiceTile: View {
    let title: String
    let isSelected: Bool
    var height: CGFloat = 110

    var body: some View {
        Text(title)
            .font(.system(size: 17, weight: isSelected ? .medium : .regular))
            .foregroundStyle(isSelected ? Color.white : Theme.textTertiary)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: [Color(white: isSelected ? 0.14 : 0.08), Color(white: 0.05)],
                                         startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.white.opacity(isSelected ? 0.55 : 0.1), lineWidth: 1)
            )
            .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

/// Outlined capsule chip used for multi-select lists ("bodybuilding", "tennis").
struct OutlineChip: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: isSelected ? .medium : .regular))
            .foregroundStyle(isSelected ? Color.white : Theme.textTertiary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Capsule().fill(isSelected ? Color.white.opacity(0.08) : Color.clear))
            .overlay(Capsule().strokeBorder(Color.white.opacity(isSelected ? 0.6 : 0.14), lineWidth: 1))
            .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

/// App mark + name, shown top-left in onboarding ("□ FrameFit").
struct BrandMark: View {
    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(Color.white, lineWidth: 1.6)
                .frame(width: 18, height: 18)
            Text("ForgeFit")
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(.white)
    }
}
