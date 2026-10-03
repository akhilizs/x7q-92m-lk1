import SwiftUI

/// A front and/or back body with the trained muscles highlighted: primary muscles in the accent,
/// supporting muscles muted. Used on plan, day and exercise cards.
struct MuscleMapView: View {
    enum Sides { case front, back, both, auto }
    enum Region { case full, upper, lower, auto }
    /// `onDark` for the dark cards; `onAccent` draws in ink for the lime hero card.
    enum Style { case onDark, onAccent }

    var primary: Set<MuscleGroup>
    var secondary: Set<MuscleGroup> = []
    var sides: Sides = .both
    var region: Region = .full
    var style: Style = .onDark

    var body: some View {
        let lit = Self.drawn(primary)
        let supporting = Self.drawn(secondary).subtracting(lit)
        let views = resolvedSides(lit: lit)
        let box = viewBox(resolvedRegion(lit: lit.isEmpty ? supporting : lit))
        Canvas { context, size in
            let gap: CGFloat = 8
            let totalWidth = box.width * CGFloat(views.count) + gap * CGFloat(views.count - 1)
            let scale = min(size.width / totalWidth, size.height / box.height)
            let originX = (size.width - totalWidth * scale) / 2
            let originY = (size.height - box.height * scale) / 2

            for (index, parts) in views.enumerated() {
                var transform = CGAffineTransform(translationX: originX + CGFloat(index) * (box.width + gap) * scale,
                                                  y: originY)
                transform = transform.scaledBy(x: scale, y: scale).translatedBy(x: -box.minX, y: -box.minY)

                for part in parts {
                    let color: Color
                    switch part.kind {
                    case .base: color = palette.base
                    case .body: color = palette.body
                    case .muscle(let group):
                        if lit.contains(group) {
                            color = palette.primary
                        } else if supporting.contains(group) {
                            color = palette.secondary
                        } else {
                            color = palette.muscle
                        }
                    }
                    context.fill(Self.path(part.points, transform), with: .color(color))
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var palette: (base: Color, body: Color, muscle: Color, secondary: Color, primary: Color) {
        switch style {
        case .onDark:
            return (Color(white: 0.15), Color(white: 0.22), Color(white: 0.29), Theme.voltDeep, Theme.volt)
        case .onAccent:
            return (Theme.ink.opacity(0.07), Theme.ink.opacity(0.14), Theme.ink.opacity(0.2), Theme.ink.opacity(0.5), Theme.ink)
        }
    }

    // MARK: Layout

    private func resolvedSides(lit: Set<MuscleGroup>) -> [[MuscleMapGeometry.Part]] {
        switch sides {
        case .front: return [MuscleMapGeometry.front]
        case .back: return [MuscleMapGeometry.back]
        case .both: return [MuscleMapGeometry.front, MuscleMapGeometry.back]
        case .auto:
            let backOnly: Set<MuscleGroup> = [.back, .triceps, .hamstrings, .glutes]
            let frontOnly: Set<MuscleGroup> = [.chest, .biceps, .core, .quads]
            let showsBack = !lit.isDisjoint(with: backOnly) && lit.isDisjoint(with: frontOnly)
            return [showsBack ? MuscleMapGeometry.back : MuscleMapGeometry.front]
        }
    }

    private func resolvedRegion(lit: Set<MuscleGroup>) -> Region {
        guard region == .auto else { return region }
        let upper: Set<MuscleGroup> = [.chest, .back, .shoulders, .biceps, .triceps, .forearms, .core]
        let lower: Set<MuscleGroup> = [.quads, .hamstrings, .glutes, .calves]
        if !lit.isEmpty && lit.isSubset(of: upper) { return .upper }
        if !lit.isEmpty && lit.isSubset(of: lower) { return .lower }
        return .full
    }

    private func viewBox(_ region: Region) -> CGRect {
        switch region {
        case .upper: return CGRect(x: 14, y: 2, width: 72, height: 98)
        case .lower: return CGRect(x: 26, y: 82, width: 48, height: 108)
        case .full, .auto: return CGRect(x: 14, y: 2, width: 72, height: 188)
        }
    }

    // MARK: Muscles

    /// The muscle regions a group lights up. Full body and cardio light the big movers.
    static func drawn(_ groups: Set<MuscleGroup>) -> Set<MuscleGroup> {
        var result = Set<MuscleGroup>()
        for group in groups {
            switch group {
            case .fullBody:
                result.formUnion([.chest, .back, .shoulders, .quads, .glutes, .hamstrings, .core])
            case .cardio:
                result.formUnion([.quads, .hamstrings, .glutes, .calves])
            default:
                result.insert(group)
            }
        }
        return result
    }

    /// A smooth closed shape through the points (Catmull-Rom), matching the design script.
    static func path(_ points: [CGPoint], _ transform: CGAffineTransform) -> Path {
        var path = Path()
        let count = points.count
        guard count > 2 else { return path }
        path.move(to: points[0])
        for i in 0..<count {
            let p0 = points[(i - 1 + count) % count]
            let p1 = points[i]
            let p2 = points[(i + 1) % count]
            let p3 = points[(i + 2) % count]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        path.closeSubpath()
        return path.applying(transform)
    }
}

extension MuscleMapView {
    /// The muscles a single exercise works.
    init(exercise: Exercise, sides: Sides = .auto, region: Region = .auto) {
        self.init(primary: [exercise.primary], secondary: Set(exercise.secondary), sides: sides, region: region)
    }

    /// The muscles a set of planned exercises works: the most-trained groups lit fully.
    init(exercises: [PlannedExercise], sides: Sides = .both, style: Style = .onDark) {
        var counts: [MuscleGroup: Int] = [:]
        var supporting = Set<MuscleGroup>()
        for item in exercises {
            guard let exercise = item.exercise else { continue }
            counts[exercise.primary, default: 0] += item.sets
            supporting.formUnion(exercise.secondary)
        }
        let top = counts.values.max() ?? 0
        // Groups with at least a third of the busiest group's sets count as main targets.
        let primary = Set(counts.filter { top > 0 && Double($0.value) >= Double(top) / 3 }.keys)
        self.init(primary: primary, secondary: supporting.union(counts.keys), sides: sides, region: .full, style: style)
    }
}

/// A small rounded tile with the muscle map of one exercise, for list rows.
struct MuscleBadge: View {
    let exercise: Exercise
    var size: CGFloat = 40

    var body: some View {
        MuscleMapView(exercise: exercise)
            .padding(size * 0.08)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous).fill(Color(white: 0.09)))
    }
}
