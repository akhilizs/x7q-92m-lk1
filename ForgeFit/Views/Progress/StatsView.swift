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
                     label: "Total volume (\(WeightUnit.label(metric: metric)))", symbol: "scalemass.fill", tint: Theme.blue)
            StatTile(value: "\(store.personalRecords.count)", label: "Exercises with PRs", symbol: "trophy.fill", tint: Theme.pink)
        }
        WeeklyVolumeChart()
        BodyWeightCard()
        ExerciseProgressCard()
        PersonalRecordsCard()
    }
}

// MARK: - Weekly volume

private struct WeeklyVolumeChart: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        let metric = store.profile.useMetric
        let stats = store.weeklyStats(weeks: 8)
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weekly volume").font(.headline)
                    Text("Last 8 weeks · \(WeightUnit.label(metric: metric))")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }
            Chart(stats) { week in
                BarMark(
                    x: .value("Week", week.weekStart, unit: .weekOfYear),
                    y: .value("Volume", WeightUnit.display(week.volumeKg, metric: metric))
                )
                .foregroundStyle(Theme.accentGradient)
                .cornerRadius(6)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                    AxisValueLabel().foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(height: 180)

            HStack(spacing: 6) {
                ForEach(stats) { week in
                    VStack(spacing: 4) {
                        Text("\(week.workouts)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(week.workouts > 0 ? Theme.accent : Theme.textTertiary)
                        Circle()
                            .fill(week.workouts > 0 ? Theme.accent : Color.white.opacity(0.1))
                            .frame(width: 6, height: 6)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Text("Workouts per week")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
                .frame(maxWidth: .infinity)
        }
        .cardStyle()
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
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Body weight").font(.headline)
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
                let values = entries.map { WeightUnit.display($0.weightKg, metric: metric) }
                let low = (values.min() ?? 0) - 1
                let high = (values.max() ?? 0) + 1
                Chart(entries) { item in
                    LineMark(x: .value("Date", item.date), y: .value("Weight", WeightUnit.display(item.weightKg, metric: metric)))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Theme.accentAlt)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    AreaMark(x: .value("Date", item.date),
                             yStart: .value("Base", low),
                             yEnd: .value("Weight", WeightUnit.display(item.weightKg, metric: metric)))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(LinearGradient(colors: [Theme.accentAlt.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                    PointMark(x: .value("Date", item.date), y: .value("Weight", WeightUnit.display(item.weightKg, metric: metric)))
                        .foregroundStyle(Theme.accentAlt)
                        .symbolSize(30)
                }
                .chartYScale(domain: low...high)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated)).foregroundStyle(Theme.textSecondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                        AxisValueLabel().foregroundStyle(Theme.textSecondary)
                    }
                }
                .frame(height: 160)
            }
        }
        .cardStyle()
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
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Strength progress").font(.headline)
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
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Theme.accent.opacity(0.12)))
                    }
                }
            }
            if let id = selectedID(ids) {
                let points = store.progression(for: id)
                if points.count >= 2 {
                    Chart(points) { point in
                        LineMark(x: .value("Date", point.date),
                                 y: .value("e1RM", WeightUnit.display(point.estimatedOneRepMax, metric: metric)))
                            .interpolationMethod(.monotone)
                            .foregroundStyle(Theme.aiGradient)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        PointMark(x: .value("Date", point.date),
                                  y: .value("e1RM", WeightUnit.display(point.estimatedOneRepMax, metric: metric)))
                            .foregroundStyle(Theme.violet)
                    }
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisValueLabel(format: .dateTime.day().month(.abbreviated)).foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                            AxisValueLabel().foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .frame(height: 170)
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
                Image(systemName: "trophy.fill").foregroundStyle(Theme.warmGradient)
            }
            if records.isEmpty {
                Text("Your best lifts will show up here.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(index == 0 ? Color.black : Color.white)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(index == 0 ? AnyShapeStyle(Theme.warmGradient) : AnyShapeStyle(Theme.surfaceRaised)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ExerciseLibrary.name(for: record.exerciseID)).font(.subheadline.weight(.semibold))
                        Text("\(WeightUnit.format(record.weightKg, metric: metric)) \(unit) × \(record.reps) · \(Format.dayMonth.string(from: record.date))")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(WeightUnit.format(record.estimatedOneRepMax, metric: metric, decimals: 0))
                            .font(.system(.headline, design: .rounded).weight(.bold))
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
                        .font(.caption.weight(.heavy))
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
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.textSecondary)
                    Text(session.name)
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
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
                                Text("Set \(index + 1)")
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
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .confirmationDialog("Delete this workout?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                dismiss()
                store.deleteSession(id: session.id)
            }
        }
    }

    private func setLabel(_ set: LoggedSet, tracking: TrackingType, metric: Bool, unit: String) -> String {
        switch tracking {
        case .weightReps: return "\(WeightUnit.format(set.weightKg, metric: metric)) \(unit) × \(set.reps)"
        case .reps: return "\(set.reps) reps"
        case .time: return Format.rest(set.seconds)
        }
    }
}
