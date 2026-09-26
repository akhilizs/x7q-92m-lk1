import Foundation

/// How to perform an exercise: setup and execution steps, and the mistakes to avoid.
struct ExerciseGuide {
    let steps: [String]
    let mistakes: [String]
}

/// Rep speed in seconds for each phase, e.g. 3-1-1 = 3 s lowering, 1 s pause, 1 s lifting.
struct Tempo: Equatable {
    let lower: Double
    let pause: Double
    let lift: Double
    let label: String

    var cycle: Double { lower + pause + lift }
}

enum ExerciseGuides {
    static func guide(for id: String) -> ExerciseGuide? { guides[id] }

    static func tempo(for exercise: Exercise) -> Tempo? {
        guard exercise.tracking != .time else { return nil }
        if explosive.contains(exercise.id) {
            return Tempo(lower: 1, pause: 0, lift: 0.5, label: "Explosive: control down, drive up fast")
        }
        if exercise.isCompound {
            return Tempo(lower: 2, pause: 1, lift: 1, label: "2-1-1: 2 s down, 1 s pause, 1 s up")
        }
        return Tempo(lower: 3, pause: 1, lift: 1, label: "3-1-1: 3 s down, 1 s squeeze, 1 s up")
    }

    private static let explosive: Set<String> = [
        "kettlebell_swing", "jump_squat", "medicine_ball_slam", "burpee", "kettlebell_clean_press", "dumbbell_thruster",
    ]

    private static func g(_ steps: [String], _ mistakes: [String]) -> ExerciseGuide {
        ExerciseGuide(steps: steps, mistakes: mistakes)
    }

    private static let guides: [String: ExerciseGuide] = [
        // MARK: Chest
        "barbell_bench_press": g([
            "Lie with eyes under the bar, feet flat, and squeeze your shoulder blades together and down.",
            "Grip slightly wider than shoulders, unrack and lower the bar to your mid-chest with elbows about 45° from your body.",
            "Press up and slightly back over your shoulders while driving your feet into the floor.",
        ], ["Flaring elbows straight out to 90°", "Bouncing the bar off your chest or lifting your hips"]),
        "incline_barbell_bench_press": g([
            "Set the bench to 30–45° and pin your shoulder blades back.",
            "Lower the bar to your upper chest, just below the collarbones.",
            "Press straight up until your arms are extended over your shoulders.",
        ], ["Setting the incline too steep (it turns into a shoulder press)", "Letting the bar drift toward your neck"]),
        "dumbbell_bench_press": g([
            "Sit with the dumbbells on your thighs, lie back and bring them to chest level.",
            "Lower with control until you feel a stretch in your chest, forearms vertical.",
            "Press up and slightly in until the dumbbells nearly touch above your chest.",
        ], ["Dropping too fast at the bottom", "Clanking the dumbbells together and losing tension"]),
        "incline_dumbbell_press": g([
            "Set a low incline (about 30°) and start with the dumbbells at upper-chest height.",
            "Keep wrists stacked over elbows as you lower into a deep stretch.",
            "Press up and slightly together without locking out hard.",
        ], ["Bench too steep", "Arching the lower back off the bench"]),
        "dumbbell_fly": g([
            "Lie on a flat bench with the dumbbells above your chest, palms facing each other.",
            "With a soft bend in the elbows, open your arms wide until you feel a chest stretch.",
            "Bring them back together in a wide arc, like hugging a tree.",
        ], ["Bending the elbows so it becomes a press", "Going so deep the shoulders take over"]),
        "machine_chest_press": g([
            "Adjust the seat so the handles line up with your mid-chest.",
            "Keep your back against the pad and shoulder blades pulled back.",
            "Press forward until almost straight, then return slowly until you feel a stretch.",
        ], ["Seat too low or high (handles at shoulder height)", "Letting the weight stack slam between reps"]),
        "pec_deck_fly": g([
            "Adjust the seat so the handles are at chest height with a slight bend in your elbows.",
            "Bring the handles together in front of your chest and squeeze for a second.",
            "Open slowly until you feel a stretch across your chest.",
        ], ["Rolling the shoulders forward", "Using momentum instead of a controlled squeeze"]),
        "cable_crossover": g([
            "Set the pulleys high, take a handle in each hand and step forward into a staggered stance.",
            "Lean forward slightly and sweep your hands down and together in front of your hips.",
            "Squeeze, then let the cables pull your arms back open under control.",
        ], ["Standing too upright so the shoulders do the work", "Pressing instead of sweeping in an arc"]),
        "smith_incline_press": g([
            "Place an incline bench so the bar path touches your upper chest.",
            "Unrack, lower with control to your upper chest with elbows about 45° out.",
            "Press up to lockout without letting your shoulders roll forward.",
        ], ["Bench in the wrong spot so the bar hits your neck or belly", "Half reps that stop far above the chest"]),
        "push_up": g([
            "Hands slightly wider than shoulders, body in a straight line from head to heels.",
            "Lower until your chest nearly touches the floor, elbows about 45° from your body.",
            "Push the floor away until your arms are straight, keeping your core tight.",
        ], ["Sagging hips or piking your butt up", "Only going halfway down"]),
        "incline_push_up": g([
            "Place your hands on a bench or box, walk your feet back into a straight plank.",
            "Lower your chest to the edge of the bench with elbows angled back.",
            "Press back up while keeping your body rigid.",
        ], ["Letting the hips sag", "Hands too far forward on the bench"]),
        "chest_dip": g([
            "Support yourself on the bars with straight arms and lean your torso forward.",
            "Bend your elbows and lower until your shoulders are just below your elbows.",
            "Press back up while keeping the forward lean.",
        ], ["Going too deep with painful shoulders", "Swinging the legs for momentum"]),
        "band_chest_press": g([
            "Anchor the band behind you at chest height and hold a handle in each hand.",
            "Step forward until there's tension, elbows bent at your sides.",
            "Press your hands forward and together, then return slowly.",
        ], ["Not enough band tension at the start", "Arching your back to finish the rep"]),

        // MARK: Back
        "deadlift": g([
            "Stand with the bar over your mid-foot, hinge down and grip just outside your legs.",
            "Bring your shins to the bar, chest up, and brace your core hard.",
            "Push the floor away and stand tall, keeping the bar close; lower it by pushing your hips back.",
        ], ["Rounding the lower back", "Jerking the bar off the floor or letting it drift away from your legs"]),
        "barbell_row": g([
            "Grip the bar just outside your knees, hinge to about 45° with a flat back.",
            "Pull the bar to your lower ribs, driving your elbows back.",
            "Lower with control without standing up between reps.",
        ], ["Using your legs and back to heave the weight", "Rounding the upper back"]),
        "dumbbell_row": g([
            "Put one knee and hand on the bench, back flat and parallel to the floor.",
            "Pull the dumbbell toward your hip, leading with the elbow.",
            "Pause at the top, then lower until your arm is straight.",
        ], ["Twisting the torso to lift the weight", "Pulling to the chest instead of the hip"]),
        "pull_up": g([
            "Hang from the bar with an overhand grip a bit wider than shoulders.",
            "Pull your shoulder blades down, then drive your elbows toward your ribs until your chin clears the bar.",
            "Lower all the way to a full hang with control.",
        ], ["Kipping or swinging", "Half reps that never reach a full hang"]),
        "chin_up": g([
            "Hang with an underhand, shoulder-width grip.",
            "Pull your chest toward the bar, keeping your elbows in front of you.",
            "Lower slowly to straight arms.",
        ], ["Craning the neck to reach the bar", "Dropping fast on the way down"]),
        "lat_pulldown": g([
            "Grip the bar slightly wider than shoulders and lock your thighs under the pad.",
            "Lean back a little and pull the bar to your upper chest, elbows driving down.",
            "Let the bar rise slowly until your arms are straight.",
        ], ["Pulling behind the neck", "Leaning way back and using momentum"]),
        "close_grip_pulldown": g([
            "Attach a neutral-grip handle and sit tall under the pad.",
            "Pull the handle to your upper chest with elbows tight to your sides.",
            "Return slowly to a full stretch overhead.",
        ], ["Rounding forward at the top", "Yanking with the arms instead of the back"]),
        "seated_cable_row": g([
            "Sit with knees slightly bent and chest tall, holding the handle with straight arms.",
            "Pull the handle to your belly button while squeezing your shoulder blades together.",
            "Let your arms extend forward slowly without rounding your back.",
        ], ["Rocking the torso back and forth", "Shrugging the shoulders up to your ears"]),
        "cable_row_standing": g([
            "Set the pulley at waist height and stand or half-kneel facing it.",
            "Row the handle toward your hip, keeping your torso still.",
            "Reach forward slowly for a full stretch.",
        ], ["Twisting to move the weight", "Short range of motion"]),
        "straight_arm_pulldown": g([
            "Set a bar high on the cable, hinge slightly and grip it with straight arms.",
            "Sweep the bar down to your thighs using your lats, arms almost straight.",
            "Return to eye level slowly.",
        ], ["Bending the elbows so it becomes a pushdown", "Standing too upright"]),
        "inverted_row": g([
            "Set a bar in a rack at waist height and hang under it with straight arms, heels on the floor.",
            "Keep your body rigid and pull your chest to the bar.",
            "Lower until your arms are straight.",
        ], ["Letting the hips sag", "Pulling with the neck instead of the back"]),
        "band_pull_apart": g([
            "Hold a band at shoulder height with straight arms and hands shoulder-width apart.",
            "Pull the band apart until it touches your chest, squeezing your upper back.",
            "Return slowly with control.",
        ], ["Bending the elbows", "Shrugging the shoulders"]),
        "kettlebell_swing": g([
            "Stand with the bell in front of you, hinge and hike it back between your legs.",
            "Snap your hips forward to float the bell to chest height with straight arms.",
            "Let it fall back and hinge again, keeping your back flat.",
        ], ["Squatting instead of hinging", "Lifting the bell with the arms"]),
        "trx_row": g([
            "Hold the handles, walk your feet forward and lean back with straight arms.",
            "Keep your body in a plank and pull your chest to your hands.",
            "Lower slowly; walk your feet forward to make it harder.",
        ], ["Hips sagging", "Flaring elbows high and shrugging"]),
        "back_extension": g([
            "Set the pad just below your hips and cross your arms over your chest.",
            "Lower your torso by hinging at the hips with a flat back.",
            "Raise until your body is in a straight line and squeeze your glutes.",
        ], ["Hyperextending past straight", "Rounding and jerking up quickly"]),

        // MARK: Shoulders
        "overhead_press": g([
            "Start with the bar on your front shoulders, grip just outside shoulder width, glutes squeezed.",
            "Press the bar straight up, moving your head back slightly to clear it.",
            "Lock out overhead with the bar over your mid-foot, then lower to your shoulders.",
        ], ["Leaning back into a standing bench press", "Pressing the bar out in front instead of straight up"]),
        "dumbbell_shoulder_press": g([
            "Sit with back support and the dumbbells at shoulder height, palms forward.",
            "Press overhead until your arms are nearly straight.",
            "Lower slowly to shoulder height.",
        ], ["Arching the lower back", "Lowering only halfway"]),
        "machine_shoulder_press": g([
            "Adjust the seat so the handles start at shoulder height.",
            "Press up until your arms are almost straight, back against the pad.",
            "Return slowly without resting the stack.",
        ], ["Seat too low so the shoulders roll forward", "Locking out hard"]),
        "arnold_press": g([
            "Start with the dumbbells at chin height, palms facing you.",
            "Rotate your palms outward as you press overhead.",
            "Reverse the rotation on the way down.",
        ], ["Rushing the rotation", "Going too heavy and losing control"]),
        "lateral_raise": g([
            "Hold light dumbbells at your sides with a slight bend in the elbows.",
            "Raise your arms out to the sides until they're level with your shoulders.",
            "Lower slowly; lead with the elbows, not the hands.",
        ], ["Swinging the weights up", "Shrugging toward your ears"]),
        "cable_lateral_raise": g([
            "Stand side-on to a low pulley and hold the handle with the far hand.",
            "Raise your arm out to the side to shoulder height.",
            "Lower slowly, keeping tension on the cable.",
        ], ["Leaning away to cheat the weight up", "Going above shoulder height"]),
        "rear_delt_fly": g([
            "Hinge forward with a flat back, dumbbells hanging under your chest.",
            "Raise your arms out to the sides with slightly bent elbows.",
            "Squeeze at the top, then lower slowly.",
        ], ["Rowing instead of flying", "Standing up as you lift"]),
        "reverse_pec_deck": g([
            "Sit facing the pad with the handles set for rear delts.",
            "Pull the handles back in a wide arc until your arms are in line with your body.",
            "Return slowly with control.",
        ], ["Shrugging the shoulders", "Using a jerky motion"]),
        "face_pull": g([
            "Set a rope at face height and grip with thumbs toward you.",
            "Pull the rope toward your face, spreading your hands apart and elbows high.",
            "Finish with your hands beside your ears, then return slowly.",
        ], ["Pulling to the chest with low elbows", "Leaning back to move more weight"]),
        "pike_push_up": g([
            "Start in a downward-dog shape with hips high and hands shoulder-width apart.",
            "Bend your elbows to lower the top of your head toward the floor.",
            "Press back up, keeping your hips high.",
        ], ["Letting hips drop into a normal push-up", "Flaring elbows wide"]),
        "band_lateral_raise": g([
            "Stand on the band and hold an end in each hand at your sides.",
            "Raise your arms out to shoulder height.",
            "Lower slowly against the band.",
        ], ["Swinging the torso", "Raising above shoulder height"]),

        // MARK: Arms
        "barbell_curl": g([
            "Stand tall holding the bar with an underhand, shoulder-width grip.",
            "Curl the bar up, keeping your elbows pinned to your sides.",
            "Squeeze at the top and lower all the way down slowly.",
        ], ["Swinging the torso", "Letting the elbows drift forward"]),
        "ez_bar_curl": g([
            "Grip the angled part of the EZ bar with palms slightly turned in.",
            "Curl up with elbows fixed at your sides.",
            "Lower slowly to straight arms.",
        ], ["Using momentum", "Cutting the bottom of the rep short"]),
        "dumbbell_curl": g([
            "Stand with dumbbells at your sides, palms forward.",
            "Curl up while keeping your elbows still.",
            "Lower slowly to full extension.",
        ], ["Swinging the weights", "Rushing the lowering"]),
        "hammer_curl": g([
            "Hold the dumbbells at your sides with palms facing each other.",
            "Curl up keeping the neutral grip and elbows at your sides.",
            "Lower slowly.",
        ], ["Rotating the wrists", "Leaning back"]),
        "incline_dumbbell_curl": g([
            "Sit back on a bench set to about 45° and let your arms hang straight down.",
            "Curl up without moving your upper arms forward.",
            "Lower into a full stretch.",
        ], ["Bringing the elbows forward", "Going too heavy to control the stretch"]),
        "cable_curl": g([
            "Attach a bar to a low pulley and stand close with an underhand grip.",
            "Curl up with elbows pinned to your sides.",
            "Lower slowly while keeping tension.",
        ], ["Leaning back", "Letting the stack slam"]),
        "band_curl": g([
            "Stand on the band and hold the handles with palms forward.",
            "Curl up while keeping elbows at your sides.",
            "Lower slowly against the tension.",
        ], ["Swinging", "Letting the band snap back"]),
        "close_grip_bench_press": g([
            "Lie on the bench and grip the bar about shoulder-width apart.",
            "Lower to your lower chest with elbows tucked close to your sides.",
            "Press up by extending your elbows.",
        ], ["Grip so narrow the wrists hurt", "Flaring the elbows"]),
        "tricep_pushdown": g([
            "Grip a bar or rope on a high pulley with elbows at your sides.",
            "Push down until your arms are straight and squeeze your triceps.",
            "Let the handle rise to about chest height, elbows still fixed.",
        ], ["Elbows drifting forward", "Leaning over the weight"]),
        "overhead_cable_extension": g([
            "Face away from the pulley holding the rope behind your head, elbows up.",
            "Extend your arms forward and up until straight.",
            "Return slowly into a deep stretch behind your head.",
        ], ["Flaring elbows out wide", "Arching the lower back"]),
        "skull_crusher": g([
            "Lie on a bench holding the EZ bar above your chest with arms straight.",
            "Bend only at the elbows to lower the bar toward your forehead.",
            "Extend back up without moving your upper arms.",
        ], ["Elbows flaring out", "Letting the upper arms swing"]),
        "dumbbell_overhead_extension": g([
            "Hold one dumbbell with both hands overhead, arms straight.",
            "Lower it behind your head by bending your elbows.",
            "Extend back up, keeping your elbows pointed forward.",
        ], ["Elbows flaring", "Arching the back"]),
        "bench_dip": g([
            "Put your hands on the edge of a bench behind you and legs out in front.",
            "Bend your elbows to lower your hips until your arms are about 90°.",
            "Press back up to straight arms.",
        ], ["Going too deep and straining the shoulders", "Letting the hips drift away from the bench"]),
        "tricep_dip": g([
            "Support yourself on parallel bars with an upright torso.",
            "Lower until your elbows are about 90°.",
            "Press back up to straight arms.",
        ], ["Shrugging the shoulders up", "Dropping too deep"]),
        "diamond_push_up": g([
            "Form a diamond with your thumbs and index fingers under your chest.",
            "Lower your chest to your hands, keeping your elbows close.",
            "Push back up with a rigid body.",
        ], ["Sagging hips", "Elbows flaring out"]),
        "farmer_carry": g([
            "Pick up heavy dumbbells with a tall posture and shoulders back.",
            "Walk with short, controlled steps and a tight core.",
            "Keep going for the target time, then set them down with a flat back.",
        ], ["Leaning to one side", "Letting the shoulders round forward"]),
        "wrist_curl": g([
            "Sit with your forearms on your thighs or a bench, wrists over the edge, palms up.",
            "Let the dumbbell roll down to your fingertips.",
            "Curl your wrist up as high as possible.",
        ], ["Moving the forearm", "Going too heavy with tiny reps"]),
        "dead_hang": g([
            "Grip the bar with both hands, shoulder-width apart.",
            "Hang with straight arms and shoulders slightly engaged.",
            "Breathe steadily and hold for time.",
        ], ["Letting the shoulders sag fully passive", "Kicking or swinging"]),

        // MARK: Legs
        "back_squat": g([
            "Set the bar on your upper back, feet shoulder-width apart with toes slightly out.",
            "Brace your core and sit down between your heels, knees tracking over your toes.",
            "Squat to at least parallel, then drive up through your whole foot.",
        ], ["Knees caving inward", "Heels lifting or chest dropping forward"]),
        "front_squat": g([
            "Rest the bar on your front shoulders with elbows high.",
            "Squat down keeping your torso upright.",
            "Drive up while keeping your elbows high.",
        ], ["Elbows dropping so the bar rolls forward", "Rounding the upper back"]),
        "goblet_squat": g([
            "Hold a dumbbell vertically at your chest, feet shoulder-width apart.",
            "Squat down between your knees, keeping your chest up.",
            "Stand back up through your heels.",
        ], ["Leaning forward", "Knees caving in"]),
        "kettlebell_goblet_squat": g([
            "Hold the kettlebell by the horns at chest height.",
            "Squat deep with your elbows inside your knees.",
            "Drive up through your heels.",
        ], ["Rounding the back", "Rising onto the toes"]),
        "leg_press": g([
            "Sit with your back flat on the pad and feet shoulder-width on the platform.",
            "Lower the platform until your knees are about 90° without your lower back rolling up.",
            "Press back up without locking your knees.",
        ], ["Lower back lifting off the pad", "Locking the knees out hard"]),
        "hack_squat": g([
            "Set your shoulders under the pads and feet shoulder-width on the platform.",
            "Squat down under control until your thighs are at least parallel.",
            "Drive back up through your whole foot.",
        ], ["Heels lifting", "Bouncing out of the bottom"]),
        "smith_squat": g([
            "Set the bar on your upper back with feet slightly in front of the bar.",
            "Squat down with control to about parallel.",
            "Press up through your mid-foot.",
        ], ["Feet directly under the bar (knees take all the load)", "Half reps"]),
        "leg_extension": g([
            "Adjust the seat so your knees line up with the machine's pivot.",
            "Extend your legs until straight and squeeze your quads.",
            "Lower slowly.",
        ], ["Kicking the weight up", "Lifting your hips off the seat"]),
        "bulgarian_split_squat": g([
            "Stand about two feet in front of a bench and rest your back foot on it.",
            "Lower straight down until your back knee nearly touches the floor.",
            "Drive up through your front heel.",
        ], ["Front foot too close to the bench", "Front knee caving inward"]),
        "walking_lunge": g([
            "Hold dumbbells at your sides and step forward into a long stride.",
            "Lower until your back knee nearly touches the floor.",
            "Push through your front heel and step into the next lunge.",
        ], ["Short steps that overload the knee", "Leaning forward"]),
        "bodyweight_squat": g([
            "Stand with feet shoulder-width apart, arms out in front for balance.",
            "Sit back and down to at least parallel.",
            "Stand up through your heels.",
        ], ["Heels lifting", "Knees caving"]),
        "reverse_lunge": g([
            "Stand tall and step one foot back.",
            "Lower until both knees are about 90°.",
            "Push through your front foot to return.",
        ], ["Leaning forward", "Back knee slamming into the floor"]),
        "step_up": g([
            "Place one foot fully on a sturdy bench or box.",
            "Drive through that foot to stand up on top.",
            "Step down slowly with control.",
        ], ["Pushing off the bottom foot", "Box too high to stay upright"]),
        "jump_squat": g([
            "Stand with feet shoulder-width apart.",
            "Squat down quickly, then jump as high as you can.",
            "Land softly and sink straight into the next rep.",
        ], ["Landing with stiff legs", "Knees caving on landing"]),
        "romanian_deadlift": g([
            "Hold the bar at hip height with soft knees.",
            "Push your hips back and slide the bar down your thighs until you feel a hamstring stretch.",
            "Drive your hips forward to stand tall.",
        ], ["Rounding the back", "Turning it into a squat by bending the knees too much"]),
        "dumbbell_rdl": g([
            "Hold dumbbells in front of your thighs with soft knees.",
            "Hinge at the hips, sliding them down your legs to mid-shin.",
            "Stand up by squeezing your glutes.",
        ], ["Rounding the back", "Letting the dumbbells drift away from your legs"]),
        "lying_leg_curl": g([
            "Lie face down with the pad just above your heels.",
            "Curl your heels toward your glutes.",
            "Lower slowly to straight legs.",
        ], ["Lifting the hips", "Short, bouncy reps"]),
        "nordic_curl": g([
            "Kneel with your ankles anchored and body upright.",
            "Lower your torso forward as slowly as you can using your hamstrings.",
            "Catch yourself with your hands and push back up.",
        ], ["Bending at the hips", "Dropping fast without control"]),
        "single_leg_rdl": g([
            "Stand on one leg with a soft knee.",
            "Hinge forward, extending the other leg back until your body is nearly parallel to the floor.",
            "Return to standing, squeezing the glute of the standing leg.",
        ], ["Twisting the hips open", "Rounding the back"]),
        "good_morning": g([
            "Set the bar on your upper back with feet hip-width apart.",
            "Push your hips back with soft knees until your torso is nearly parallel to the floor.",
            "Drive your hips forward to stand up.",
        ], ["Rounding the lower back", "Going too heavy too soon"]),
        "hip_thrust": g([
            "Sit with your upper back against a bench and the padded bar over your hips.",
            "Drive through your heels to lift your hips until your body is flat from shoulders to knees.",
            "Squeeze your glutes at the top, then lower.",
        ], ["Arching the lower back at the top", "Feet too far away"]),
        "glute_bridge": g([
            "Lie on your back with knees bent and feet flat.",
            "Drive through your heels to lift your hips.",
            "Squeeze at the top and lower slowly.",
        ], ["Arching the back", "Pushing through the toes"]),
        "cable_kickback": g([
            "Attach an ankle strap to a low pulley and face the machine.",
            "Kick your leg back and up, squeezing your glute.",
            "Return slowly.",
        ], ["Arching the back", "Swinging the leg"]),
        "band_lateral_walk": g([
            "Place a band around your legs just above your knees.",
            "Sit into a quarter squat.",
            "Step sideways, keeping tension on the band.",
        ], ["Standing upright", "Letting the knees cave in"]),
        "standing_calf_raise": g([
            "Stand on the edge of the platform with the pads on your shoulders.",
            "Lower your heels into a deep stretch.",
            "Rise onto your toes and pause at the top.",
        ], ["Bouncing", "Bending the knees"]),
        "dumbbell_calf_raise": g([
            "Hold dumbbells and stand on a step with your heels hanging off.",
            "Lower your heels into a stretch.",
            "Rise onto your toes and squeeze.",
        ], ["Rushing the reps", "Short range of motion"]),
        "leg_press_calf_raise": g([
            "Sit in the leg press with the balls of your feet on the bottom edge of the platform.",
            "Let your heels drop back into a stretch.",
            "Push the platform away with your toes.",
        ], ["Bending the knees", "Letting your feet slip"]),
        "bodyweight_calf_raise": g([
            "Stand on a step with your heels hanging off.",
            "Lower slowly.",
            "Rise onto your toes and pause.",
        ], ["Bouncing", "Holding on too much"]),

        // MARK: Core
        "plank": g([
            "Rest on your forearms and toes, elbows under your shoulders.",
            "Keep your body in a straight line and squeeze your glutes and abs.",
            "Breathe steadily for the whole hold.",
        ], ["Hips sagging", "Hips piked too high"]),
        "side_plank": g([
            "Lie on your side and prop yourself up on one forearm.",
            "Lift your hips so your body is in a straight line.",
            "Hold, then switch sides.",
        ], ["Hips dropping", "Rolling forward"]),
        "hanging_leg_raise": g([
            "Hang from a bar with your shoulders slightly engaged.",
            "Raise your legs by curling your pelvis up.",
            "Lower slowly without swinging.",
        ], ["Swinging for momentum", "Only lifting the knees without tilting the pelvis"]),
        "cable_crunch": g([
            "Kneel facing a high pulley and hold the rope beside your head.",
            "Crunch your ribs toward your hips.",
            "Return slowly.",
        ], ["Pulling with the arms", "Sitting back onto the heels"]),
        "dead_bug": g([
            "Lie on your back with arms up and knees bent at 90°.",
            "Lower the opposite arm and leg toward the floor while pressing your lower back down.",
            "Return and switch sides.",
        ], ["Lower back arching off the floor", "Moving too fast"]),
        "russian_twist": g([
            "Sit with knees bent and lean back slightly.",
            "Rotate your torso side to side.",
            "Keep your chest up throughout.",
        ], ["Rounding the back", "Just moving the arms instead of the torso"]),
        "ab_wheel_rollout": g([
            "Kneel holding the wheel under your shoulders.",
            "Roll forward as far as you can while keeping your back flat.",
            "Pull back using your abs.",
        ], ["Lower back sagging", "Going further than you can control"]),
        "pallof_press": g([
            "Stand side-on to a cable at chest height, holding the handle at your chest.",
            "Press it straight out and resist the rotation.",
            "Hold, then bring it back to your chest.",
        ], ["Twisting toward the cable", "Standing too close"]),
        "medicine_ball_slam": g([
            "Hold the ball overhead with a tall posture.",
            "Slam it down in front of you as hard as you can.",
            "Catch it on the bounce or pick it up with a flat back.",
        ], ["Rounding the back to pick it up", "Using just the arms"]),
        "mountain_climber": g([
            "Start in a high plank with hands under your shoulders.",
            "Drive your knees toward your chest one after the other.",
            "Keep your hips level and move quickly.",
        ], ["Hips bouncing up and down", "Hands drifting forward"]),

        // MARK: Full body
        "burpee": g([
            "Drop into a squat and place your hands on the floor.",
            "Jump your feet back to a plank (add a push-up if you like), then jump them back in.",
            "Explode up into a jump with your arms overhead.",
        ], ["Sagging hips in the plank", "Landing heavily"]),
        "kettlebell_clean_press": g([
            "Swing the bell between your legs and clean it to the rack position at your shoulder.",
            "Press it overhead to a straight arm.",
            "Lower it back to the rack and then to the swing.",
        ], ["Letting the bell bang your forearm", "Leaning back during the press"]),
        "dumbbell_thruster": g([
            "Hold dumbbells at your shoulders.",
            "Squat down, then drive up and use the momentum to press them overhead.",
            "Lower them back to your shoulders as you go into the next squat.",
        ], ["Pressing with the arms only", "Knees caving in"]),
        "trx_squat_row": g([
            "Hold the handles facing the anchor, arms straight.",
            "Squat down, then stand up and row the handles to your chest.",
            "Extend your arms as you sink into the next squat.",
        ], ["Rushing", "Not keeping tension in the straps"]),

        // MARK: Cardio
        "treadmill_run": g([
            "Start with a 3–5 minute easy warm-up.",
            "Run at a pace where you can still speak in short sentences.",
            "Stay tall with relaxed shoulders and a quick, light stride.",
        ], ["Holding the handrails", "Overstriding and landing on your heels"]),
        "incline_walk": g([
            "Set the incline between 8 and 12%.",
            "Walk at a brisk pace without holding the rails.",
            "Keep your posture tall.",
        ], ["Leaning on the handrails", "Walking too slowly to raise your heart rate"]),
        "stationary_bike": g([
            "Set the saddle so your knee is slightly bent at the bottom of the pedal stroke.",
            "Pedal at a steady cadence with moderate resistance.",
            "Keep your upper body relaxed.",
        ], ["Saddle too low", "No resistance, just spinning"]),
        "bike_intervals": g([
            "Warm up for 3–5 minutes.",
            "Sprint hard for about 20–30 seconds, then pedal easy for 60–90 seconds.",
            "Repeat for the planned time.",
        ], ["Skipping the warm-up", "Going too hard on the first sprint"]),
        "rowing_machine": g([
            "Push with your legs first, then lean back slightly and pull the handle to your ribs.",
            "Return in reverse order: arms, then torso, then knees.",
            "Keep a steady rhythm of about 20–24 strokes per minute.",
        ], ["Pulling with the arms before the legs", "Rounding the back"]),
        "elliptical": g([
            "Stand tall and hold the handles lightly.",
            "Push and pull evenly with arms and legs.",
            "Keep resistance moderate and steady.",
        ], ["Leaning on the handles", "Resistance so low you barely work"]),
        "jump_rope": g([
            "Hold the handles at hip height with elbows close.",
            "Turn the rope with your wrists and jump just high enough to clear it.",
            "Land softly on the balls of your feet.",
        ], ["Jumping too high", "Swinging with the whole arm"]),
        "jumping_jacks": g([
            "Stand with feet together and arms at your sides.",
            "Jump your feet out as you raise your arms overhead.",
            "Jump back to the start and keep a steady rhythm.",
        ], ["Landing flat-footed", "Half-height arm swings"]),
    ]
}
