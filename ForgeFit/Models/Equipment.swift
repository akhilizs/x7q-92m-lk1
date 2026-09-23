import Foundation

enum EquipmentCategory: String, CaseIterable, Identifiable {
    case freeWeights = "Free Weights"
    case machines = "Machines"
    case cardio = "Cardio"
    case accessories = "Accessories"

    var id: String { rawValue }
}

enum Equipment: String, Codable, CaseIterable, Identifiable, Hashable {
    case bodyweight
    case dumbbells
    case barbell
    case ezBar
    case kettlebell
    case bench
    case squatRack
    case pullUpBar
    case dipStation
    case cableMachine
    case latPulldown
    case seatedRow
    case chestPressMachine
    case shoulderPressMachine
    case pecDeck
    case legPress
    case hackSquat
    case legExtension
    case legCurl
    case smithMachine
    case calfRaiseMachine
    case resistanceBands
    case medicineBall
    case suspensionTrainer
    case treadmill
    case stationaryBike
    case rowingMachine
    case elliptical
    case jumpRope

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bodyweight: return "Bodyweight"
        case .dumbbells: return "Dumbbells"
        case .barbell: return "Barbell"
        case .ezBar: return "EZ Curl Bar"
        case .kettlebell: return "Kettlebell"
        case .bench: return "Bench"
        case .squatRack: return "Squat Rack"
        case .pullUpBar: return "Pull-up Bar"
        case .dipStation: return "Dip Station"
        case .cableMachine: return "Cable Machine"
        case .latPulldown: return "Lat Pulldown"
        case .seatedRow: return "Seated Row"
        case .chestPressMachine: return "Chest Press"
        case .shoulderPressMachine: return "Shoulder Press"
        case .pecDeck: return "Pec Deck"
        case .legPress: return "Leg Press"
        case .hackSquat: return "Hack Squat"
        case .legExtension: return "Leg Extension"
        case .legCurl: return "Leg Curl"
        case .smithMachine: return "Smith Machine"
        case .calfRaiseMachine: return "Calf Raise"
        case .resistanceBands: return "Bands"
        case .medicineBall: return "Medicine Ball"
        case .suspensionTrainer: return "TRX Straps"
        case .treadmill: return "Treadmill"
        case .stationaryBike: return "Bike"
        case .rowingMachine: return "Rower"
        case .elliptical: return "Elliptical"
        case .jumpRope: return "Jump Rope"
        }
    }

    var symbol: String {
        switch self {
        case .bodyweight: return "figure.strengthtraining.functional"
        case .dumbbells: return "dumbbell.fill"
        case .barbell: return "figure.strengthtraining.traditional"
        case .ezBar: return "line.3.crossed.swirl.circle"
        case .kettlebell: return "scalemass.fill"
        case .bench: return "bed.double.fill"
        case .squatRack: return "square.split.bottomrightquarter"
        case .pullUpBar: return "figure.climbing"
        case .dipStation: return "arrow.down.to.line.compact"
        case .cableMachine: return "cable.connector"
        case .latPulldown: return "arrow.down.circle.fill"
        case .seatedRow: return "figure.rower"
        case .chestPressMachine: return "arrow.right.circle.fill"
        case .shoulderPressMachine: return "arrow.up.circle.fill"
        case .pecDeck: return "arrow.left.and.right.circle.fill"
        case .legPress: return "figure.step.training"
        case .hackSquat: return "figure.cross.training"
        case .legExtension: return "figure.flexibility"
        case .legCurl: return "figure.cooldown"
        case .smithMachine: return "rectangle.split.3x1.fill"
        case .calfRaiseMachine: return "shoeprints.fill"
        case .resistanceBands: return "lasso"
        case .medicineBall: return "circle.fill"
        case .suspensionTrainer: return "link"
        case .treadmill: return "figure.run"
        case .stationaryBike: return "figure.outdoor.cycle"
        case .rowingMachine: return "oar.2.crossed"
        case .elliptical: return "figure.elliptical"
        case .jumpRope: return "figure.jumprope"
        }
    }

    var category: EquipmentCategory {
        switch self {
        case .bodyweight, .dumbbells, .barbell, .ezBar, .kettlebell:
            return .freeWeights
        case .cableMachine, .latPulldown, .seatedRow, .chestPressMachine, .shoulderPressMachine,
             .pecDeck, .legPress, .hackSquat, .legExtension, .legCurl, .smithMachine, .calfRaiseMachine:
            return .machines
        case .treadmill, .stationaryBike, .rowingMachine, .elliptical, .jumpRope:
            return .cardio
        case .bench, .squatRack, .pullUpBar, .dipStation, .resistanceBands, .medicineBall, .suspensionTrainer:
            return .accessories
        }
    }

    static func inCategory(_ category: EquipmentCategory) -> [Equipment] {
        allCases.filter { $0.category == category }
    }
}

enum EquipmentPreset: String, CaseIterable, Identifiable {
    case fullGym
    case homeDumbbells
    case bodyweightOnly
    case machinesOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullGym: return "Full Gym"
        case .homeDumbbells: return "Home Gym"
        case .bodyweightOnly: return "Bodyweight"
        case .machinesOnly: return "Machines"
        }
    }

    var symbol: String {
        switch self {
        case .fullGym: return "building.2.fill"
        case .homeDumbbells: return "house.fill"
        case .bodyweightOnly: return "figure.walk"
        case .machinesOnly: return "gearshape.2.fill"
        }
    }

    var equipment: Set<Equipment> {
        switch self {
        case .fullGym:
            return Set(Equipment.allCases)
        case .homeDumbbells:
            return [.bodyweight, .dumbbells, .bench, .pullUpBar, .resistanceBands, .kettlebell, .jumpRope]
        case .bodyweightOnly:
            return [.bodyweight, .pullUpBar, .jumpRope]
        case .machinesOnly:
            return [.bodyweight, .cableMachine, .latPulldown, .seatedRow, .chestPressMachine,
                    .shoulderPressMachine, .pecDeck, .legPress, .legExtension, .legCurl,
                    .smithMachine, .calfRaiseMachine, .treadmill, .stationaryBike, .elliptical, .bench]
        }
    }
}
