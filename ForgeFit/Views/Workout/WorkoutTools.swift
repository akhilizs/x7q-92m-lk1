import SwiftUI

// MARK: - Swap exercise

/// Alternatives for the same muscle with the equipment available.
struct SwapExerciseSheet: View {
    let current: LoggedExercise
    let equipment: Set<Equipment>
    let excluding: Set<String>
    let onSwap: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showAllEquipment = false

    var body: some View {
        let options = Alternatives.options(for: current.exerciseID,
                                           equipment: showAllEquipment ? Set(Equipment.allCases) : equipment,
                                           excluding: excluding)
        NavigationStack {
            List {
                Section {
                    Toggle("Include equipment I don't have", isOn: $showAllEquipment)
                        .tint(Theme.sky)
                } footer: {
                    Text("Same muscles as \(current.name). Sets you've already done stay logged.")
                }
                .listRowBackground(Theme.surface)

                Section("Alternatives") {
                    if options.isEmpty {
                        Text("No alternatives with your equipment.")
                            .foregroundStyle(Theme.textSecondary)
                    }
                    ForEach(options) { exercise in
                        Button {
                            onSwap(exercise)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                IconBadge(symbol: exercise.primary.symbol, background: Theme.color(for: exercise.primary),
                                          foreground: Theme.ink, size: 38)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name).foregroundStyle(.white)
                                    Text("\(exercise.equipmentLabel) · \(exercise.isCompound ? "Compound" : "Isolation")")
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                    }
                }
                .listRowBackground(Theme.surface)
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .navigationTitle("Swap \(current.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - How-to guide

struct ExerciseGuideView: View {
    let exercise: Exercise
    /// False when pushed onto a navigation stack (Back already closes it).
    var showsDone = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let guide = ExerciseGuides.guide(for: exercise.id)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    IconBadge(symbol: exercise.primary.symbol, background: Theme.color(for: exercise.primary),
                              foreground: Theme.ink, size: 54)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.name)
                            .font(.system(size: 24, weight: .semibold))
                        Text(muscleLine)
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                        Text(exercise.equipmentLabel)
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }

                if let tempo = ExerciseGuides.tempo(for: exercise) {
                    TempoGuide(tempo: tempo)
                } else {
                    Label(exercise.primary == .cardio ? "Keep a steady pace you could hold for the whole block."
                                                      : "Hold the position and breathe steadily.",
                          systemImage: "wind")
                        .font(.subheadline)
                        .cardStyle()
                }

                if let guide {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How to do it").font(.headline)
                        ForEach(Array(guide.steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Theme.ink)
                                    .frame(width: 24, height: 24)
                                    .background(Circle().fill(Theme.paper))
                                Text(step)
                                    .font(.subheadline)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Avoid").font(.headline)
                        ForEach(guide.mistakes, id: \.self) { mistake in
                            Label(mistake, systemImage: "xmark.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                                .symbolRenderingMode(.hierarchical)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                }

                Label(exercise.cue, systemImage: "lightbulb.fill")
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.sand))

                if let url = videoURL {
                    Link(destination: url) {
                        Label("Watch form videos", systemImage: "play.rectangle.fill")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding(20)
        }
        .appBackground()
        .navigationTitle("How to")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDone {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var muscleLine: String {
        ([exercise.primary] + exercise.secondary).map(\.displayName).joined(separator: " · ")
    }

    private var videoURL: URL? {
        var components = URLComponents(string: "https://www.youtube.com/results")
        components?.queryItems = [URLQueryItem(name: "search_query", value: "\(exercise.name) proper form")]
        return components?.url
    }
}

/// A looping animation of one rep at the recommended speed.
struct TempoGuide: View {
    let tempo: Tempo

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: tempo.cycle)
            let current = phase(at: t)
            HStack(spacing: 18) {
                ZStack(alignment: .top) {
                    Capsule().fill(Color.white.opacity(0.08)).frame(width: 10, height: 120)
                    Circle()
                        .fill(color(for: current.name))
                        .frame(width: 30, height: 30)
                        .shadow(color: color(for: current.name).opacity(0.6), radius: 10)
                        .offset(y: CGFloat(current.depth) * 90)
                }
                .frame(width: 40, height: 120)
                VStack(alignment: .leading, spacing: 8) {
                    Text("REP TEMPO")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.textTertiary)
                    Text(current.name)
                        .font(.system(size: 26, weight: .semibold))
                        .contentTransition(.opacity)
                    Text(tempo.label)
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .cardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rep tempo: \(tempo.label)")
    }

    /// Depth 0 = top of the rep, 1 = bottom.
    private func phase(at t: Double) -> (name: String, depth: Double) {
        if t < tempo.lower {
            return ("Lower", ease(t / tempo.lower))
        }
        if t < tempo.lower + tempo.pause {
            return ("Pause", 1)
        }
        let lifted = (t - tempo.lower - tempo.pause) / max(tempo.lift, 0.01)
        return ("Lift", 1 - ease(min(lifted, 1)))
    }

    private func ease(_ x: Double) -> Double { x * x * (3 - 2 * x) }

    private func color(for phase: String) -> Color {
        switch phase {
        case "Lower": return Theme.sky
        case "Pause": return Theme.sand
        default: return Theme.sage
        }
    }
}

// MARK: - Plate calculator

struct PlateCalculatorView: View {
    let exercise: Exercise?
    let metric: Bool
    @State private var target: Double
    @State private var bar: Double
    @Environment(\.dismiss) private var dismiss

    init(exercise: Exercise?, startKg: Double, metric: Bool) {
        self.exercise = exercise
        self.metric = metric
        let barKg = Warmup.barKg(for: exercise, metric: metric)
        let bar = (WeightUnit.display(barKg, metric: metric)).rounded()
        _bar = State(initialValue: bar)
        let start = WeightUnit.display(startKg, metric: metric)
        _target = State(initialValue: start > bar ? (start * 2).rounded() / 2 : bar + (metric ? 40 : 90))
    }

    private var unit: String { WeightUnit.label(metric: metric) }
    private var bars: [Double] { metric ? [20, 15, 10] : [45, 35, 25] }
    private var step: Double { metric ? 2.5 : 5 }

    var body: some View {
        let load = Plates.load(target: target, bar: bar, plates: Plates.available(metric: metric))
        ScrollView {
            VStack(spacing: 20) {
                HStack(spacing: 16) {
                    stepButton("minus") { target = max(bar, target - step) }
                    VStack(spacing: 2) {
                        Text(format(target))
                            .font(.system(size: 44, weight: .semibold).monospacedDigit())
                        Text("\(unit) total")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(minWidth: 140)
                    stepButton("plus") { target += step }
                }
                .padding(.top, 8)

                Picker("Bar", selection: $bar) {
                    ForEach(bars, id: \.self) { value in
                        Text("\(format(value)) \(unit) bar").tag(value)
                    }
                }
                .pickerStyle(.segmented)

                BarDrawing(perSide: load.perSide, metric: metric)
                    .frame(height: 150)
                    .cardStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Each side").font(.headline)
                    if load.perSide.isEmpty {
                        Text("Just the bar.")
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        Text(load.perSide.map { format($0) }.joined(separator: " + ") + " \(unit)")
                            .font(.title3.weight(.semibold).monospacedDigit())
                    }
                    if !load.exact {
                        Label("Closest you can load: \(format(load.total)) \(unit)", systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(Theme.orange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
            }
            .padding(20)
        }
        .appBackground()
        .navigationTitle("Plate Calculator")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.tap()
        } label: {
            Image(systemName: symbol)
                .font(.headline)
                .frame(width: 48, height: 48)
                .background(Circle().fill(Theme.surfaceRaised))
        }
        .buttonStyle(PressableStyle())
    }

    private func format(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : trim(value)
    }

    private func trim(_ value: Double) -> String {
        var text = String(format: "%.2f", value)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }
}

/// One side of a loaded bar, heaviest plate nearest the middle.
private struct BarDrawing: View {
    let perSide: [Double]
    let metric: Bool

    var body: some View {
        GeometryReader { geo in
            let maxPlate = metric ? 25.0 : 45.0
            HStack(spacing: 3) {
                Rectangle()
                    .fill(Color(white: 0.6))
                    .frame(width: 60, height: 10)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(white: 0.75))
                    .frame(width: 12, height: 34)
                ForEach(Array(perSide.enumerated()), id: \.offset) { _, plate in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(color(for: plate))
                        .frame(width: plate >= (metric ? 10 : 25) ? 16 : 11,
                               height: max(34, geo.size.height * 0.85 * CGFloat(0.4 + 0.6 * plate / maxPlate)))
                        .overlay(
                            Text(label(plate))
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Theme.ink)
                                .rotationEffect(.degrees(-90))
                                .fixedSize()
                        )
                }
                Rectangle()
                    .fill(Color(white: 0.6))
                    .frame(width: 30, height: 10)
                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(perSide.isEmpty ? "Empty bar" : "Each side: " + perSide.map(label).joined(separator: ", "))
    }

    private func label(_ plate: Double) -> String {
        plate.rounded() == plate ? String(Int(plate)) : String(plate)
    }

    private func color(for plate: Double) -> Color {
        let order = metric ? [25.0, 20, 15, 10, 5, 2.5, 1.25] : [45.0, 35, 25, 10, 5, 2.5]
        let palette = [Theme.rose, Theme.sky, Theme.sand, Theme.sage, Theme.paper, Theme.lilac, Color(white: 0.7)]
        let index = order.firstIndex(of: plate) ?? palette.count - 1
        return palette[min(index, palette.count - 1)]
    }
}
