import Foundation

enum MuscleGroup: String, Codable, CaseIterable, Identifiable, Hashable {
    case chest, back, shoulders, biceps, triceps, forearms
    case quads, hamstrings, glutes, calves, core
    case fullBody, cardio

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chest: return "Chest"
        case .back: return "Back"
        case .shoulders: return "Shoulders"
        case .biceps: return "Biceps"
        case .triceps: return "Triceps"
        case .forearms: return "Forearms"
        case .quads: return "Quads"
        case .hamstrings: return "Hamstrings"
        case .glutes: return "Glutes"
        case .calves: return "Calves"
        case .core: return "Core"
        case .fullBody: return "Full Body"
        case .cardio: return "Cardio"
        }
    }

    var symbol: String {
        switch self {
        case .chest: return "figure.arms.open"
        case .back: return "figure.rower"
        case .shoulders: return "figure.boxing"
        case .biceps: return "figure.strengthtraining.traditional"
        case .triceps: return "figure.strengthtraining.functional"
        case .forearms: return "hand.raised.fill"
        case .quads: return "figure.step.training"
        case .hamstrings: return "figure.flexibility"
        case .glutes: return "figure.cross.training"
        case .calves: return "shoeprints.fill"
        case .core: return "figure.core.training"
        case .fullBody: return "figure.mixed.cardio"
        case .cardio: return "heart.fill"
        }
    }
}

enum TrackingType: String, Codable, Hashable {
    /// Weight x reps (e.g. bench press)
    case weightReps
    /// Reps only (e.g. push-ups)
    case reps
    /// Timed hold or cardio, tracked in seconds
    case time

    var promptLabel: String {
        switch self {
        case .weightReps: return "weight+reps"
        case .reps: return "reps"
        case .time: return "seconds"
        }
    }
}

struct Exercise: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let primary: MuscleGroup
    let secondary: [MuscleGroup]
    /// Every item in this list is required to perform the exercise.
    let equipment: [Equipment]
    let tracking: TrackingType
    let isCompound: Bool
    let cue: String

    func isAvailable(with available: Set<Equipment>) -> Bool {
        equipment.allSatisfy { $0 == .bodyweight || available.contains($0) }
    }

    var equipmentLabel: String {
        let names = equipment.filter { $0 != .bodyweight }.map(\.displayName)
        return names.isEmpty ? "Bodyweight" : names.joined(separator: " + ")
    }
}
