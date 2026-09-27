import Foundation

/// Catalog of exercises: the built-in ones plus the user's own. IDs are stable and are
/// what the AI coach references when it builds or edits a plan.
enum ExerciseLibrary {
    static let builtIn: [Exercise] = [
        // MARK: Chest
        ex("barbell_bench_press", "Barbell Bench Press", .chest, [.triceps, .shoulders], [.barbell, .bench], .weightReps, true,
           "Shoulder blades pinned, bar to mid-chest, drive feet into the floor."),
        ex("incline_barbell_bench_press", "Incline Barbell Bench Press", .chest, [.shoulders, .triceps], [.barbell, .bench], .weightReps, true,
           "30–45° incline, touch upper chest, elbows ~45° from torso."),
        ex("dumbbell_bench_press", "Dumbbell Bench Press", .chest, [.triceps, .shoulders], [.dumbbells, .bench], .weightReps, true,
           "Lower with control until a deep chest stretch, press up and slightly in."),
        ex("incline_dumbbell_press", "Incline Dumbbell Press", .chest, [.shoulders, .triceps], [.dumbbells, .bench], .weightReps, true,
           "Low incline, keep wrists stacked over elbows."),
        ex("dumbbell_fly", "Dumbbell Fly", .chest, [.shoulders], [.dumbbells, .bench], .weightReps, false,
           "Soft elbows, open wide like hugging a tree, squeeze at the top."),
        ex("machine_chest_press", "Machine Chest Press", .chest, [.triceps, .shoulders], [.chestPressMachine], .weightReps, true,
           "Handles at mid-chest height, press without locking out hard."),
        ex("pec_deck_fly", "Pec Deck Fly", .chest, [.shoulders], [.pecDeck], .weightReps, false,
           "Slight bend in elbows, pause and squeeze when handles meet."),
        ex("cable_crossover", "Cable Crossover", .chest, [.shoulders], [.cableMachine], .weightReps, false,
           "Step forward, slight lean, bring hands together below chest."),
        ex("smith_incline_press", "Smith Machine Incline Press", .chest, [.shoulders, .triceps], [.smithMachine, .bench], .weightReps, true,
           "Set bench so bar path hits upper chest."),
        ex("push_up", "Push-up", .chest, [.triceps, .shoulders, .core], [.bodyweight], .reps, true,
           "Body in one straight line, chest touches the floor."),
        ex("incline_push_up", "Incline Push-up", .chest, [.triceps], [.bodyweight, .bench], .reps, true,
           "Hands on bench — easier regression of the push-up."),
        ex("chest_dip", "Chest Dip", .chest, [.triceps, .shoulders], [.dipStation], .reps, true,
           "Lean forward, lower until shoulders are just below elbows."),
        ex("band_chest_press", "Band Chest Press", .chest, [.triceps], [.resistanceBands], .reps, true,
           "Anchor band behind you, press forward and squeeze."),

        // MARK: Back
        ex("deadlift", "Conventional Deadlift", .back, [.hamstrings, .glutes, .forearms], [.barbell], .weightReps, true,
           "Bar over mid-foot, brace hard, push the floor away."),
        ex("barbell_row", "Barbell Bent-over Row", .back, [.biceps, .forearms], [.barbell], .weightReps, true,
           "Hinge to ~45°, pull bar to lower ribs, no jerking."),
        ex("dumbbell_row", "One-arm Dumbbell Row", .back, [.biceps], [.dumbbells, .bench], .weightReps, true,
           "Pull elbow toward hip, pause at the top."),
        ex("pull_up", "Pull-up", .back, [.biceps, .forearms], [.pullUpBar], .reps, true,
           "Full hang to chin over bar, drive elbows down."),
        ex("chin_up", "Chin-up", .back, [.biceps], [.pullUpBar], .reps, true,
           "Underhand grip, chest up to the bar."),
        ex("lat_pulldown", "Lat Pulldown", .back, [.biceps], [.latPulldown], .weightReps, true,
           "Pull bar to upper chest, lean back slightly, control the return."),
        ex("close_grip_pulldown", "Close-grip Pulldown", .back, [.biceps], [.latPulldown], .weightReps, true,
           "Neutral grip, elbows tight to your sides."),
        ex("seated_cable_row", "Seated Cable Row", .back, [.biceps], [.seatedRow], .weightReps, true,
           "Tall chest, pull to belly button, squeeze shoulder blades."),
        ex("cable_row_standing", "Cable Row (Cable Stack)", .back, [.biceps], [.cableMachine], .weightReps, true,
           "Half-kneel or stand, row the handle to your hip."),
        ex("straight_arm_pulldown", "Straight-arm Pulldown", .back, [.core], [.cableMachine], .weightReps, false,
           "Arms long, sweep bar down to thighs using lats."),
        ex("inverted_row", "Inverted Row", .back, [.biceps, .core], [.squatRack], .reps, true,
           "Body rigid under a racked bar, pull chest to bar."),
        ex("band_pull_apart", "Band Pull-apart", .back, [.shoulders], [.resistanceBands], .reps, false,
           "Arms straight, pull band to chest, squeeze upper back."),
        ex("kettlebell_swing", "Kettlebell Swing", .glutes, [.hamstrings, .back, .core], [.kettlebell], .reps, true,
           "Explosive hip hinge — hips drive the bell, not arms."),
        ex("trx_row", "Suspension Row", .back, [.biceps, .core], [.suspensionTrainer], .reps, true,
           "Walk feet forward to make it harder."),
        ex("back_extension", "Back Extension", .back, [.glutes, .hamstrings], [.bodyweight, .bench], .reps, false,
           "Hinge at hips, squeeze glutes to rise."),

        // MARK: Shoulders
        ex("overhead_press", "Barbell Overhead Press", .shoulders, [.triceps, .core], [.barbell], .weightReps, true,
           "Glutes tight, press bar up and slightly back over mid-foot."),
        ex("dumbbell_shoulder_press", "Seated Dumbbell Shoulder Press", .shoulders, [.triceps], [.dumbbells, .bench], .weightReps, true,
           "Lower to ear level, press without clanking at the top."),
        ex("machine_shoulder_press", "Machine Shoulder Press", .shoulders, [.triceps], [.shoulderPressMachine], .weightReps, true,
           "Seat so handles start at shoulder height."),
        ex("arnold_press", "Arnold Press", .shoulders, [.triceps], [.dumbbells], .weightReps, true,
           "Rotate palms from facing you to facing forward as you press."),
        ex("lateral_raise", "Dumbbell Lateral Raise", .shoulders, [], [.dumbbells], .weightReps, false,
           "Lead with elbows, raise to shoulder height, slow negative."),
        ex("cable_lateral_raise", "Cable Lateral Raise", .shoulders, [], [.cableMachine], .weightReps, false,
           "Cable behind the body for constant tension."),
        ex("rear_delt_fly", "Rear Delt Fly", .shoulders, [.back], [.dumbbells], .weightReps, false,
           "Hinge forward, sweep arms out wide, pinkies up."),
        ex("reverse_pec_deck", "Reverse Pec Deck", .shoulders, [.back], [.pecDeck], .weightReps, false,
           "Chest on pad, open arms wide, pause at the back."),
        ex("face_pull", "Face Pull", .shoulders, [.back], [.cableMachine], .weightReps, false,
           "Rope to forehead, elbows high, rotate hands back."),
        ex("pike_push_up", "Pike Push-up", .shoulders, [.triceps], [.bodyweight], .reps, true,
           "Hips high, lower head toward floor between hands."),
        ex("band_lateral_raise", "Band Lateral Raise", .shoulders, [], [.resistanceBands], .reps, false,
           "Stand on band, raise to shoulder height."),

        // MARK: Biceps
        ex("barbell_curl", "Barbell Curl", .biceps, [.forearms], [.barbell], .weightReps, false,
           "Elbows pinned, no swinging, squeeze at the top."),
        ex("ez_bar_curl", "EZ-bar Curl", .biceps, [.forearms], [.ezBar], .weightReps, false,
           "Angled grip is easier on the wrists."),
        ex("dumbbell_curl", "Dumbbell Curl", .biceps, [.forearms], [.dumbbells], .weightReps, false,
           "Supinate (turn pinky up) as you curl."),
        ex("hammer_curl", "Hammer Curl", .biceps, [.forearms], [.dumbbells], .weightReps, false,
           "Neutral grip, curl across or straight up."),
        ex("incline_dumbbell_curl", "Incline Dumbbell Curl", .biceps, [], [.dumbbells, .bench], .weightReps, false,
           "Arms hang behind torso for a big stretch."),
        ex("cable_curl", "Cable Curl", .biceps, [.forearms], [.cableMachine], .weightReps, false,
           "Constant tension — slow on the way down."),
        ex("band_curl", "Band Curl", .biceps, [], [.resistanceBands], .reps, false,
           "Stand on band, curl with control."),

        // MARK: Triceps
        ex("close_grip_bench_press", "Close-grip Bench Press", .triceps, [.chest], [.barbell, .bench], .weightReps, true,
           "Hands shoulder-width, elbows tucked."),
        ex("tricep_pushdown", "Cable Tricep Pushdown", .triceps, [], [.cableMachine], .weightReps, false,
           "Elbows glued to sides, full lockout."),
        ex("overhead_cable_extension", "Overhead Cable Extension", .triceps, [], [.cableMachine], .weightReps, false,
           "Face away from stack, stretch deep behind the head."),
        ex("skull_crusher", "EZ-bar Skull Crusher", .triceps, [], [.ezBar, .bench], .weightReps, false,
           "Lower bar behind the head, keep elbows pointed up."),
        ex("dumbbell_overhead_extension", "Dumbbell Overhead Extension", .triceps, [], [.dumbbells], .weightReps, false,
           "Both hands on one dumbbell, deep stretch."),
        ex("bench_dip", "Bench Dip", .triceps, [.chest], [.bodyweight, .bench], .reps, false,
           "Hands on bench edge, lower until elbows reach 90°."),
        ex("tricep_dip", "Parallel Bar Dip", .triceps, [.chest, .shoulders], [.dipStation], .reps, true,
           "Stay upright to bias triceps."),
        ex("diamond_push_up", "Diamond Push-up", .triceps, [.chest], [.bodyweight], .reps, true,
           "Hands together under chest."),

        // MARK: Forearms
        ex("farmer_carry", "Farmer's Carry", .forearms, [.core, .fullBody], [.dumbbells], .time, true,
           "Heavy weights, tall posture, short quick steps."),
        ex("wrist_curl", "Dumbbell Wrist Curl", .forearms, [], [.dumbbells, .bench], .weightReps, false,
           "Forearms on bench, curl the wrist only."),
        ex("dead_hang", "Dead Hang", .forearms, [.back], [.pullUpBar], .time, false,
           "Relax shoulders into a full hang, grip hard."),

        // MARK: Quads
        ex("back_squat", "Barbell Back Squat", .quads, [.glutes, .hamstrings, .core], [.barbell, .squatRack], .weightReps, true,
           "Brace, sit between your hips, knees track over toes."),
        ex("front_squat", "Barbell Front Squat", .quads, [.glutes, .core], [.barbell, .squatRack], .weightReps, true,
           "Elbows high, stay upright."),
        ex("goblet_squat", "Goblet Squat", .quads, [.glutes, .core], [.dumbbells], .weightReps, true,
           "Hold dumbbell at chest, elbows inside knees."),
        ex("kettlebell_goblet_squat", "Kettlebell Goblet Squat", .quads, [.glutes, .core], [.kettlebell], .weightReps, true,
           "Hold by the horns, sit deep."),
        ex("leg_press", "Leg Press", .quads, [.glutes], [.legPress], .weightReps, true,
           "Lower until knees reach ~90°, never lock knees hard."),
        ex("hack_squat", "Hack Squat", .quads, [.glutes], [.hackSquat], .weightReps, true,
           "Feet mid-platform, deep controlled reps."),
        ex("smith_squat", "Smith Machine Squat", .quads, [.glutes], [.smithMachine], .weightReps, true,
           "Feet slightly forward of the bar."),
        ex("leg_extension", "Leg Extension", .quads, [], [.legExtension], .weightReps, false,
           "Pause and squeeze at the top."),
        ex("bulgarian_split_squat", "Bulgarian Split Squat", .quads, [.glutes], [.dumbbells, .bench], .weightReps, true,
           "Rear foot on bench, drop straight down."),
        ex("walking_lunge", "Dumbbell Walking Lunge", .quads, [.glutes, .hamstrings], [.dumbbells], .weightReps, true,
           "Long steps, back knee kisses the floor."),
        ex("bodyweight_squat", "Bodyweight Squat", .quads, [.glutes], [.bodyweight], .reps, true,
           "Arms forward for balance, full depth."),
        ex("reverse_lunge", "Reverse Lunge", .quads, [.glutes], [.bodyweight], .reps, true,
           "Step back, keep front shin vertical."),
        ex("step_up", "Step-up", .quads, [.glutes], [.bodyweight, .bench], .reps, true,
           "Drive through the heel of the top leg."),
        ex("jump_squat", "Jump Squat", .quads, [.glutes, .calves], [.bodyweight], .reps, true,
           "Land softly and go straight into the next rep."),

        // MARK: Hamstrings
        ex("romanian_deadlift", "Romanian Deadlift", .hamstrings, [.glutes, .back], [.barbell], .weightReps, true,
           "Soft knees, push hips back, bar slides down thighs."),
        ex("dumbbell_rdl", "Dumbbell Romanian Deadlift", .hamstrings, [.glutes], [.dumbbells], .weightReps, true,
           "Hinge until a strong hamstring stretch."),
        ex("lying_leg_curl", "Leg Curl", .hamstrings, [.calves], [.legCurl], .weightReps, false,
           "Hips pressed down, slow eccentric."),
        ex("nordic_curl", "Nordic Hamstring Curl", .hamstrings, [], [.bodyweight], .reps, false,
           "Anchor feet, lower as slowly as possible."),
        ex("single_leg_rdl", "Single-leg RDL", .hamstrings, [.glutes, .core], [.bodyweight], .reps, false,
           "Hips square, reach long through the back leg."),
        ex("good_morning", "Good Morning", .hamstrings, [.back, .glutes], [.barbell, .squatRack], .weightReps, true,
           "Bar on back, hinge with flat spine."),

        // MARK: Glutes
        ex("hip_thrust", "Barbell Hip Thrust", .glutes, [.hamstrings], [.barbell, .bench], .weightReps, true,
           "Chin tucked, ribs down, full hip lockout."),
        ex("glute_bridge", "Glute Bridge", .glutes, [.hamstrings], [.bodyweight], .reps, false,
           "Drive through heels, squeeze 1–2 s at the top."),
        ex("cable_kickback", "Cable Glute Kickback", .glutes, [], [.cableMachine], .weightReps, false,
           "Slight forward lean, kick back and squeeze."),
        ex("band_lateral_walk", "Banded Lateral Walk", .glutes, [], [.resistanceBands], .reps, false,
           "Quarter squat, step wide, keep tension."),

        // MARK: Calves
        ex("standing_calf_raise", "Standing Calf Raise", .calves, [], [.calfRaiseMachine], .weightReps, false,
           "Full stretch at the bottom, pause at the top."),
        ex("dumbbell_calf_raise", "Dumbbell Calf Raise", .calves, [], [.dumbbells], .weightReps, false,
           "Stand on a step edge for full range."),
        ex("leg_press_calf_raise", "Leg Press Calf Raise", .calves, [], [.legPress], .weightReps, false,
           "Balls of feet on the platform edge."),
        ex("bodyweight_calf_raise", "Bodyweight Calf Raise", .calves, [], [.bodyweight], .reps, false,
           "Slow tempo, single-leg to progress."),

        // MARK: Core
        ex("plank", "Plank", .core, [.shoulders], [.bodyweight], .time, false,
           "Squeeze glutes, ribs down, breathe."),
        ex("side_plank", "Side Plank", .core, [], [.bodyweight], .time, false,
           "Hips high, body in one line."),
        ex("hanging_leg_raise", "Hanging Leg Raise", .core, [.forearms], [.pullUpBar], .reps, false,
           "No swinging, curl pelvis up."),
        ex("cable_crunch", "Cable Crunch", .core, [], [.cableMachine], .weightReps, false,
           "Kneel, crunch ribs toward hips."),
        ex("dead_bug", "Dead Bug", .core, [], [.bodyweight], .reps, false,
           "Low back glued to floor, move opposite arm and leg."),
        ex("russian_twist", "Russian Twist", .core, [], [.bodyweight], .reps, false,
           "Lean back, rotate from the ribs."),
        ex("ab_wheel_rollout", "Ab Rollout", .core, [.shoulders], [.bodyweight], .reps, false,
           "Hollow body, roll only as far as you can control."),
        ex("pallof_press", "Pallof Press", .core, [], [.cableMachine], .reps, false,
           "Resist rotation, press straight out."),
        ex("medicine_ball_slam", "Medicine Ball Slam", .core, [.fullBody], [.medicineBall], .reps, true,
           "Reach tall, slam hard, squat to pick up."),
        ex("mountain_climber", "Mountain Climber", .core, [.cardio], [.bodyweight], .time, false,
           "Hips level, drive knees fast."),

        // MARK: Full body / conditioning
        ex("burpee", "Burpee", .fullBody, [.cardio, .chest], [.bodyweight], .reps, true,
           "Chest to floor, jump and clap overhead."),
        ex("kettlebell_clean_press", "Kettlebell Clean & Press", .fullBody, [.shoulders, .glutes], [.kettlebell], .reps, true,
           "Clean to rack position, press overhead."),
        ex("dumbbell_thruster", "Dumbbell Thruster", .fullBody, [.quads, .shoulders], [.dumbbells], .weightReps, true,
           "Front squat into a push press in one motion."),
        ex("trx_squat_row", "Suspension Squat to Row", .fullBody, [.back, .quads], [.suspensionTrainer], .reps, true,
           "Squat down, row yourself up."),

        // MARK: Cardio
        ex("treadmill_run", "Treadmill Run", .cardio, [.quads, .calves], [.treadmill], .time, false,
           "Conversational pace unless intervals are prescribed."),
        ex("incline_walk", "Incline Treadmill Walk", .cardio, [.glutes, .calves], [.treadmill], .time, false,
           "10–15% incline, don't hold the rails."),
        ex("stationary_bike", "Stationary Bike", .cardio, [.quads], [.stationaryBike], .time, false,
           "Steady cadence ~80–90 rpm."),
        ex("bike_intervals", "Bike Sprint Intervals", .cardio, [.quads], [.stationaryBike], .time, false,
           "20 s all-out, 40 s easy — repeat."),
        ex("rowing_machine", "Rowing Machine", .cardio, [.back, .quads], [.rowingMachine], .time, false,
           "Legs, hips, arms — then reverse on the return."),
        ex("elliptical", "Elliptical", .cardio, [.quads], [.elliptical], .time, false,
           "Moderate resistance, steady breathing."),
        ex("jump_rope", "Jump Rope", .cardio, [.calves], [.jumpRope], .time, false,
           "Small hops on the balls of the feet."),
        ex("jumping_jacks", "Jumping Jacks", .cardio, [.calves], [.bodyweight], .time, false,
           "Light and rhythmic — great warm-up."),
    ]

    private static let byID: [String: Exercise] = Dictionary(uniqueKeysWithValues: builtIn.map { ($0.id, $0) })

    /// The user's own exercises, kept in step with `AppStore.customExercises`.
    private static var customByID: [String: Exercise] = [:]
    private static var customActive: [Exercise] = []

    static func register(_ custom: [CustomExercise]) {
        customByID = Dictionary(custom.map { ($0.id, $0.asExercise) }, uniquingKeysWith: { first, _ in first })
        customActive = pickable(custom)
    }

    /// Everything that can be picked: the user's own exercises (A–Z) first, then the built-in ones.
    static var all: [Exercise] { customActive + builtIn }

    /// The pickable catalog for a given set of custom exercises.
    static func catalog(custom: [CustomExercise]) -> [Exercise] {
        pickable(custom) + builtIn
    }

    /// Custom exercises that haven't been deleted, A–Z.
    private static func pickable(_ custom: [CustomExercise]) -> [Exercise] {
        custom.filter { !$0.isDeleted }
            .map(\.asExercise)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Looks up any exercise, including custom ones that were deleted (so history keeps its names).
    static func exercise(_ id: String) -> Exercise? { byID[id] ?? customByID[id] }

    static func name(for id: String) -> String {
        if let exercise = exercise(id) { return exercise.name }
        if id.hasPrefix(CustomExercise.idPrefix) { return "Custom exercise" }
        return id.replacingOccurrences(of: "_", with: " ").capitalized
    }

    static func available(with equipment: Set<Equipment>) -> [Exercise] {
        all.filter { $0.isAvailable(with: equipment) }
    }

    /// Compact catalog listing used inside AI prompts.
    static func promptCatalog(_ exercises: [Exercise]) -> String {
        exercises.map { e in
            let eq = e.equipment.map(\.rawValue).joined(separator: "+")
            let kind = (e.isCompound ? "compound" : "isolation") + (e.isCustom ? ", the athlete's own exercise" : "")
            return "\(e.id) | \(e.name) | \(e.primary.rawValue) | \(eq) | \(e.tracking.promptLabel) | \(kind)"
        }.joined(separator: "\n")
    }

    private static func ex(_ id: String, _ name: String, _ primary: MuscleGroup, _ secondary: [MuscleGroup],
                           _ equipment: [Equipment], _ tracking: TrackingType, _ compound: Bool, _ cue: String) -> Exercise {
        Exercise(id: id, name: name, primary: primary, secondary: secondary, equipment: equipment,
                 tracking: tracking, isCompound: compound, cue: cue)
    }
}
