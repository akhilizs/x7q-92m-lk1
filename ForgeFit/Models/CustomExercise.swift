import Foundation

/// An exercise the user added themselves. Saved with their data and synced to their account.
struct CustomExercise: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var primary: MuscleGroup
    var secondary: [MuscleGroup]
    /// Everything needed to do it. Empty means bodyweight.
    var equipment: [Equipment]
    var tracking: TrackingType
    var isCompound: Bool
    var notes: String
    /// Deleted exercises stay resolvable so plans and past workouts keep their names.
    var isDeleted: Bool
    var createdAt: Date

    static let idPrefix = "custom_"

    init(id: String = CustomExercise.newID(), name: String = "", primary: MuscleGroup = .chest,
         secondary: [MuscleGroup] = [], equipment: [Equipment] = [], tracking: TrackingType = .weightReps,
         isCompound: Bool = false, notes: String = "", isDeleted: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.primary = primary
        self.secondary = secondary
        self.equipment = equipment
        self.tracking = tracking
        self.isCompound = isCompound
        self.notes = notes
        self.isDeleted = isDeleted
        self.createdAt = createdAt
    }

    static func newID() -> String {
        idPrefix + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12).lowercased()
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var asExercise: Exercise {
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return Exercise(id: id,
                        name: trimmedName.isEmpty ? "Untitled exercise" : trimmedName,
                        primary: primary,
                        secondary: secondary.filter { $0 != primary },
                        equipment: equipment.isEmpty ? [.bodyweight] : equipment,
                        tracking: tracking,
                        isCompound: isCompound,
                        cue: cleanNotes.isEmpty ? "Your own exercise. Add form notes by editing it in the exercise library." : cleanNotes)
    }
}

extension Exercise {
    /// True for exercises the user created.
    var isCustom: Bool { id.hasPrefix(CustomExercise.idPrefix) }
}
