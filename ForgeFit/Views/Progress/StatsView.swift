import SwiftUI
import Charts

struct StatsView: View {
    @Environment(AppStore.self) private var store

    private enum Segment: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case history = "History"
        var id: String { rawValue }
    }

    @State private var segment: Segment = .overview

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Picker("View", selection: $segment) {
                        ForEach(Segment.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    switch segment {
                    case .overview: overview
                    case .history: HistoryList()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .appBackground()
            .navigationTitle("Progress")
            .navigationDestination(for: WorkoutSession.ID.self) { id in
                SessionDetailView(sessionID: id)
            }
            .resumeWorkoutBar()
        }
    }

    @ViewBuilder
    private var overview: some View {
        let metric = store.profile.useMetric
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            StatTile(value: "\(store.sessions.count)", label: "Total workouts", symbol: "figure.strengthtraining.traditional", tint: Theme.accent)
            StatTile(value: "\(store.weekStreak) wk", label: "Weekly streak", symbol: "flame.fill", tint: Theme.orange)
            StatTile(value: Format.compact(WeightUnit.display(store.totalVolumeKg, metric: metric)),
                     label: "Total volume (\(WeightUnit.label(metric: metric)))", symbol: "scalemass.fill", tint: Theme.accent)
            StatTile(value: "\(store.personalRecords.count)", label: "Exercises with PRs", symbol: "trophy.fill", tint: Theme.orange)
        }
        BadgesSection()
        WeeklyVolumeChart()
        BodyWeightCard()
        ExerciseProgressCard()
        PersonalRecordsCard()
    }
}

// MARK: - Weekly volume

private struct WeeklyVolumeChart: View {
    @Environment(AppStore.self) private var store
    @State private var selected: Date?

    var body: some View {
        let metric = store.profile.useMetric
        let unit = WeightUnit.label(metric: metric)
        let stats = store.weeklyStats(weeks: 8)
        let current = stats.last
        let picked = selected.flatMap { date in stats.last { $0.weekStart <= date } }
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weekly volume").font(.display(15, weight: .bold))
                    Text("Last 8 weeks · \(unit)")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                if let current {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(Format.compact(WeightUnit.display(current.volumeKg, metric: metric)))
                            .font(.metric(18))
                            .foregroundStyle(.white)
                        Text("this week").eyebrow()
                    }
                }
            }
            Chart(stats) { week in
                let value = WeightUnit.display(week.volumeKg, metric: metric)
                let emphasised = picked.map { $0.id == week.id } ?? (week.id == current?.id)
                BarMark(x: .value("Week", week.weekStart, unit: .weekOfYear),
                        y: .value("Volume", value),
                        width: .fixed(18))
                    .foregroundStyle(emphasised ? Theme.volt : Theme.volt.opacity(0.32))
                    .cornerRadius(4)
                if let picked, picked.id == week.id {
                    RuleMark(x: .value("Week", week.weekStart, unit: .weekOfYear))
                        .foregroundStyle(Color.white.opacity(0.18))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .annotation(position: .top, spacing: 4,
                                    overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            ChartTooltip(value: "\(Format.compact(value)) \(unit)",
                                         caption: "Week of \(Format.dayMonth.string(from: week.weekStart)) · \(week.workouts) workouts")
                        }
                }
            }
            .chartXSelection(value: $selected)
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(Color.white.opacity(0.07))
                    AxisValueLabel().foregroundStyle(Theme.textTertiary)
                }
            }
            .frame(height: 150)
            .padding(.top, 6)

            HStack(spacing: 6) {
                ForEach(stats) { week in
                    VStack(spacing: 3) {
                        Text("\(week.workouts)")
                            .font(.caption2.weight(.bold).monospacedDigit())
                            .foregroundStyle(week.workouts > 0 ? .white : Theme.textTertiary)
                        Circle()
                            .fill(week.workouts > 0 ? Theme.volt : Color.white.opacity(0.1))
                            .frame(width: 5, height: 5)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Text("Workouts per week")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
                .frame(maxWidth: .infinity)
        }
        .cardStyle(padding: 14)
    }
}

// MARK: - Body weight

private struct BodyWeightCard: View {
    @Environment(AppStore.self) private var store
    @State private var showAdd = false
    @State private var entry = ""

    var body: some View {
        let metric = store.profile.useMetric
        let unit = WeightUnit.label(metric: metric)
        let entries = Array(store.bodyWeights.suffix(30))
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Body weight").font(.display(15, weight: .bold))
                    if let last = entries.last {
                        Text("\(WeightUnit.format(last.weightKg, metric: metric)) \(unit) · \(Format.dayMonth.string(from: last.date))")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        Text("Log your weight to see the trend")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()
                Button {
                    entry = ""
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Theme.accentGradient))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Log body weight")
            }
            if entries.count >= 2 {
                TrendChart(points: entries.map { TrendChart.Point(date: $0.date, value: WeightUnit.display($0.weightKg, metric: metric)) },
                           unit: unit, decimals: 1, padding: 1)
                    .frame(height: 140)
            }
        }
        .cardStyle(padding: 14)
        .alert("Log body weight", isPresented: $showAdd) {
            TextField("Weight (\(unit))", text: $entry)
                .keyboardType(.decimalPad)
            Button("Save") {
                if let value = Double(entry.replacingOccurrences(of: ",", with: ".")), value > 0 {
                    store.addBodyWeight(kg: WeightUnit.toKg(value, metric: metric))
                    Haptics.success()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Exercise progress

private struct ExerciseProgressCard: View {
    @Environment(AppStore.self) private var store
    @State private var exerciseID: String?

    var body: some View {
        let ids = store.trackedExerciseIDs
        let metric = store.profile.useMetric
        let unit = WeightUnit.label(metric: metric)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Strength progress").font(.display(15, weight: .bold))
                    Text("Estimated 1-rep max (\(unit))")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                if !ids.isEmpty {
                    Menu {
                        ForEach(ids, id: \.self) { id in
                            Button(ExerciseLibrary.name(for: id)) { exerciseID = id }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(ExerciseLibrary.name(for: selectedID(ids) ?? ""))
                                .lineLimit(1)
                            Image(systemName: "chevron.up.chevron.down")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                        .overlay(Capsule().strokeBorder(Theme.volt.opacity(0.5)))
                    }
                }
            }
            if let id = selectedID(ids) {
                let points = store.progression(for: id)
                if points.count >= 2 {
                    TrendChart(points: points.map {
                        TrendChart.Point(date: $0.date, value: WeightUnit.display($0.estimatedOneRepMax, metric: metric))
                    }, unit: unit, decimals: 0, padding: 2)
                    .frame(height: 150)
                } else {
                    Text("Log this exercise in at least two workouts to see a trend.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            } else {
                Text("Complete weighted sets to track your strength over time.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .cardStyle()
    }

    private func selectedID(_ ids: [String]) -> String? {
        if let exerciseID, ids.contains(exerciseID) { return exerciseID }
        return ids.first
    }
}

// MARK: - Personal records

private struct PersonalRecordsCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        let records = Array(store.personalRecords.prefix(6))
        let metric = store.profile.useMetric
        let unit = WeightUnit.label(metric: metric)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Personal records").font(.headline)
                Spacer()
                Image(systemName: "trophy.fill").foregroundStyle(Theme.orange)
            }
            if records.isEmpty {
                Text("Your best lifts will show up here.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(index == 0 ? Color.black : Color.white)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(index == 0 ? Color.white : Theme.surfaceRaised))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ExerciseLibrary.name(for: record.exerciseID)).font(.subheadline.weight(.semibold))
                        Text("\(WeightUnit.format(record.weightKg, metric: metric)) \(unit) × \(record.reps) · \(Format.dayMonth.string(from: record.date))")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(WeightUnit.format(record.estimatedOneRepMax, metric: metric, decimals: 0))
                            .font(.system(.headline).weight(.semibold))
                        Text("e1RM").font(.caption2).foregroundStyle(Theme.textTertiary)
                    }
                }
            }
        }
        .cardStyle()
    }
}

// MARK: - History

private struct HistoryList: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        if store.sessions.isEmpty {
            EmptyStateView(symbol: "calendar", title: "No workouts yet",
                           message: "Finish your first workout and it will appear here.")
        } else {
            let groups = Dictionary(grouping: store.sessions) { Format.monthYear.string(from: $0.startedAt) }
            let order = store.sessions.map { Format.monthYear.string(from: $0.startedAt) }.reduce(into: [String]()) { result, key in
                if !result.contains(key) { result.append(key) }
            }
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(order, id: \.self) { month in
                    Text(month.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.top, 6)
                    ForEach(groups[month] ?? []) { session in
                        NavigationLink(value: session.id) {
                            SessionRow(session: session)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
        }
    }
}

// MARK: - Session detail

struct SessionDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let sessionID: UUID
    @State private var confirmDelete = false

    var body: some View {
        if let session = store.sessions.first(where: { $0.id == sessionID }) {
            content(session)
        } else {
            EmptyStateView(symbol: "questionmark", title: "Workout not found", message: "It may have been deleted.")
                .padding()
                .appBackground()
        }
    }

    private func content(_ session: WorkoutSession) -> some View {
        let metric = store.profile.useMetric
        let unit = WeightUnit.label(metric: metric)
        let records = Set(store.newRecords(in: session))
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Format.dayMonth.string(from: session.startedAt).uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Text(session.name)
                        .font(.system(size: 30, weight: .semibold))
                }
                HStack(spacing: 12) {
                    StatTile(value: Format.minutes(session.duration), label: "Duration", symbol: "clock.fill", tint: Theme.blue)
                    StatTile(value: Format.compact(WeightUnit.display(session.totalVolumeKg, metric: metric)),
                             label: "Volume (\(unit))", symbol: "scalemass.fill", tint: Theme.accent)
                    StatTile(value: session.effort.map { "\($0)/10" } ?? "—", label: "Effort", symbol: "bolt.heart.fill", tint: Theme.orange)
                }
                if !session.notes.isEmpty {
                    Label(session.notes, systemImage: "note.text")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .cardStyle(padding: 14, radius: 18)
                }
                ForEach(session.exercises) { ex in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(ex.name).font(.headline)
                            if records.contains(ex.exerciseID) {
                                TagLabel(text: "PR", symbol: "trophy.fill", color: Theme.orange)
                            }
                            Spacer()
                        }
                        ForEach(Array(ex.sets.enumerated()), id: \.element.id) { index, set in
                            HStack {
                                Text(set.isWarmup ? "Warm-up" : set.kind == .drop ? "Drop" : "Set \(ex.sets[..<index].filter { !$0.isWarmup }.count + 1)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.textSecondary)
                                    .frame(width: 54, alignment: .leading)
                                Text(setLabel(set, tracking: ex.tracking, metric: metric, unit: unit))
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                Spacer()
                            }
                        }
                    }
                    .cardStyle(padding: 14, radius: 18)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .appBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareSessionToolbarButton(session: session, records: Array(records),
                                          streak: store.weekStreak, metric: metric)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .resumeWorkoutBar()
        .confirmationDialog("Delete this workout?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                dismiss()
                store.deleteSession(id: session.id)
            }
        }
    }

    private func setLabel(_ set: LoggedSet, tracking: TrackingType, metric: Bool, unit: String) -> String {
        let rpe = set.rpe.map { " @ RPE \($0.rounded() == $0 ? String(Int($0)) : String(format: "%.1f", $0))" } ?? ""
        switch tracking {
        case .weightReps: return "\(WeightUnit.format(set.weightKg, metric: metric)) \(unit) × \(set.reps)\(rpe)"
        case .reps: return "\(set.reps) reps\(rpe)"
        case .time: return Format.rest(set.seconds)
        }
    }
}

/// Renders the share card for a past workout and opens the share sheet.
private struct ShareSessionToolbarButton: View {
    let session: WorkoutSession
    let records: [String]
    let streak: Int
    let metric: Bool
    @State private var image: Image?

    var body: some View {
        Group {
            if let image {
                ShareLink(item: image, preview: SharePreview("\(session.name) workout", image: image)) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share workout")
            } else {
                Image(systemName: "square.and.arrow.up").opacity(0.3)
            }
        }
        .task(id: session.id) {
            let card = WorkoutShareCard(session: session, records: records, streak: streak, metric: metric)
                .environment(\.colorScheme, .dark)
            let renderer = ImageRenderer(content: card)
            renderer.scale = 3
            image = renderer.uiImage.map { Image(uiImage: $0) }
        }
    }
}

// MARK: - Chart pieces

/// A single trend over time: a 2 pt lime line over a faint wash, the latest value labelled at
/// the end, and touch-and-drag to read any point.
struct TrendChart: View {
    struct Point: Identifiable {
        let date: Date
        let value: Double
        var id: Date { date }
    }

    let points: [Point]
    let unit: String
    var decimals = 1
    /// Room above and below the data, in the chart's units.
    var padding: Double = 1
    @State private var selected: Date?

    var body: some View {
        let values = points.map(\.value)
        let low = (values.min() ?? 0) - padding
        let high = (values.max() ?? 0) + padding
        let picked = selected.flatMap { date in
            points.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
        }
        Chart {
            ForEach(points) { point in
                AreaMark(x: .value("Date", point.date),
                         yStart: .value("Base", low),
                         yEnd: .value("Value", point.value))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(LinearGradient(colors: [Theme.volt.opacity(0.2), Theme.volt.opacity(0)],
                                                    startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Date", point.date), y: .value("Value", point.value))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Theme.volt)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            if let picked {
                RuleMark(x: .value("Date", picked.date))
                    .foregroundStyle(Color.white.opacity(0.18))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(position: .top, spacing: 4,
                                overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        ChartTooltip(value: "\(format(picked.value)) \(unit)",
                                     caption: Format.dayMonth.string(from: picked.date))
                    }
                dot(picked)
            } else if let last = points.last {
                dot(last)
                    .annotation(position: .top, alignment: .trailing, spacing: 8) {
                        Text("\(format(last.value)) \(unit)")
                            .font(.metric(11))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color(white: 0.09)))
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.1)))
                    }
            }
        }
        .chartYScale(domain: low...high)
        .chartXSelection(value: $selected)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.day().month(.abbreviated)).foregroundStyle(Theme.textSecondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(Color.white.opacity(0.07))
                AxisValueLabel().foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.top, 8)
    }

    /// An 8 pt dot with a ring in the card colour, so it stays clear of the line.
    private func dot(_ point: Point) -> some ChartContent {
        PointMark(x: .value("Date", point.date), y: .value("Value", point.value))
            .symbolSize(50)
            .foregroundStyle(Theme.volt)
            .symbol {
                Circle()
                    .fill(Theme.volt)
                    .frame(width: 9, height: 9)
                    .overlay(Circle().strokeBorder(Color(white: 0.09), lineWidth: 2).padding(-2))
            }
    }

    private func format(_ value: Double) -> String {
        String(format: "%.\(decimals)f", value)
    }
}

/// The value under the finger while scrubbing a chart.
struct ChartTooltip: View {
    let value: String
    let caption: String

    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.metric(13))
                .foregroundStyle(.white)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(white: 0.16)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.white.opacity(0.12)))
    }
}
