//
//  ExerciseDatabase.swift
//  GymQuest
//
//  Comprehensive exercise database with 150+ exercises.
//  Each exercise includes full metadata: muscle groups, equipment,
//  form cues, common mistakes, and variations.
//

import Foundation
import SwiftUI

// MARK: - Exercise Metadata

struct ExerciseMetadata: Codable, Identifiable {
    var id: UUID = UUID()
    let name: String
    let muscleGroup: MuscleGroup
    let category: ExerciseCategory
    let equipment: Equipment
    let difficulty: ExerciseDifficulty
    let primaryMuscles: [String]
    let secondaryMuscles: [String]
    let aliases: [String]
    let movementPattern: MovementPattern
    let cues: [String]
    let commonMistakes: [String]
    let variations: [String]
}

// MARK: - Extended Exercise Database

struct ExtendedExerciseDatabase {
    static let exercises: [ExerciseMetadata] = [

        // ═══════════════════════════════════════
        // CHEST (12)
        // ═══════════════════════════════════════

        ExerciseMetadata(
            name: "Bench Press", muscleGroup: .chest, category: .push, equipment: .barbell,
            difficulty: .intermediate,
            primaryMuscles: ["Chest", "Pectoralis Major"],
            secondaryMuscles: ["Triceps", "Front Deltoids"],
            aliases: ["Flat Bench", "Barbell Bench"],
            movementPattern: .press,
            cues: ["Retract shoulder blades", "Arch upper back slightly", "Bar path: diagonal from chest to lockout"],
            commonMistakes: ["Flaring elbows too wide", "Bouncing off chest", "Lifting hips off bench"],
            variations: ["Close Grip", "Wide Grip", "Pause Reps"]
        ),
        ExerciseMetadata(
            name: "Incline Bench Press", muscleGroup: .chest, category: .push, equipment: .barbell,
            difficulty: .intermediate,
            primaryMuscles: ["Upper Chest", "Clavicular Pectoralis"],
            secondaryMuscles: ["Front Deltoids", "Triceps"],
            aliases: ["Incline Barbell Press", "Incline Press"],
            movementPattern: .press,
            cues: ["Set bench to 30-45 degrees", "Touch bar to upper chest", "Keep wrists stacked over elbows"],
            commonMistakes: ["Bench angle too steep", "Pressing too high on chest", "Excessive arch"],
            variations: ["Dumbbell Incline", "Smith Machine Incline"]
        ),
        ExerciseMetadata(
            name: "Dumbbell Press", muscleGroup: .chest, category: .push, equipment: .dumbbell,
            difficulty: .beginner,
            primaryMuscles: ["Chest", "Pectoralis Major"],
            secondaryMuscles: ["Triceps", "Front Deltoids"],
            aliases: ["DB Press", "Flat Dumbbell Press", "Dumbbell Bench Press"],
            movementPattern: .press,
            cues: ["Control the descent", "Squeeze at the top", "Keep dumbbells from drifting outward"],
            commonMistakes: ["Going too heavy too soon", "Not controlling the negative", "Inconsistent range of motion"],
            variations: ["Neutral Grip", "Single Arm", "Alternating"]
        ),
        ExerciseMetadata(
            name: "Push-ups", muscleGroup: .chest, category: .push, equipment: .bodyweight,
            difficulty: .beginner,
            primaryMuscles: ["Chest", "Pectoralis Major"],
            secondaryMuscles: ["Triceps", "Core", "Front Deltoids"],
            aliases: ["Pushups", "Press-ups"],
            movementPattern: .push,
            cues: ["Hands slightly wider than shoulders", "Body in straight line", "Chest to floor each rep"],
            commonMistakes: ["Hips sagging", "Incomplete range of motion", "Flaring elbows 90 degrees"],
            variations: ["Incline", "Decline", "Diamond", "Wide"]
        ),
        ExerciseMetadata(
            name: "Cable Fly", muscleGroup: .chest, category: .isolation, equipment: .cable,
            difficulty: .beginner,
            primaryMuscles: ["Chest", "Pectoralis Major"],
            secondaryMuscles: ["Front Deltoids"],
            aliases: ["Cable Crossover", "Cable Chest Fly"],
            movementPattern: .push,
            cues: ["Slight bend in elbows", "Squeeze chest at the center", "Control the stretch"],
            commonMistakes: ["Using too much weight", "Bending elbows too much", "Rushing the movement"],
            variations: ["High to Low", "Low to High", "Single Arm"]
        ),
        ExerciseMetadata(
            name: "Decline Bench Press", muscleGroup: .chest, category: .push, equipment: .barbell,
            difficulty: .intermediate,
            primaryMuscles: ["Lower Chest", "Pectoralis Major"],
            secondaryMuscles: ["Triceps", "Front Deltoids"],
            aliases: ["Decline Barbell Press"],
            movementPattern: .press,
            cues: ["Set bench to 15-30 degree decline", "Lower to lower chest", "Press up and slightly back"],
            commonMistakes: ["Too steep a decline", "Bar drifting toward face", "No spotter on heavy sets"],
            variations: ["Dumbbell Decline", "Smith Machine Decline"]
        ),
        ExerciseMetadata(
            name: "Dumbbell Fly", muscleGroup: .chest, category: .isolation, equipment: .dumbbell,
            difficulty: .beginner,
            primaryMuscles: ["Chest", "Pectoralis Major"],
            secondaryMuscles: ["Front Deltoids"],
            aliases: ["DB Fly", "Flat Fly", "Chest Fly"],
            movementPattern: .push,
            cues: ["Slight bend in elbows throughout", "Lower until stretch in chest", "Squeeze to bring together"],
            commonMistakes: ["Straightening arms at bottom", "Going too heavy", "Turning it into a press"],
            variations: ["Incline Fly", "Decline Fly"]
        ),
        ExerciseMetadata(
            name: "Chest Dips", muscleGroup: .chest, category: .push, equipment: .bodyweight,
            difficulty: .intermediate,
            primaryMuscles: ["Lower Chest", "Pectoralis Major"],
            secondaryMuscles: ["Triceps", "Front Deltoids"],
            aliases: ["Dips", "Parallel Bar Dips"],
            movementPattern: .push,
            cues: ["Lean torso forward 30 degrees", "Lower until upper arms parallel", "Elbows slightly flared"],
            commonMistakes: ["Going too deep", "Staying too upright", "Swinging body"],
            variations: ["Weighted", "Machine Assisted", "Ring Dips"]
        ),
        ExerciseMetadata(
            name: "Incline Dumbbell Press", muscleGroup: .chest, category: .push, equipment: .dumbbell,
            difficulty: .beginner,
            primaryMuscles: ["Upper Chest", "Clavicular Pectoralis"],
            secondaryMuscles: ["Front Deltoids", "Triceps"],
            aliases: ["Incline DB Press"],
            movementPattern: .press,
            cues: ["30-45 degree incline", "Press up and slightly inward", "Lower to upper chest level"],
            commonMistakes: ["Bench too steep", "Dumbbells drifting forward", "Uneven pressing"],
            variations: ["Neutral Grip", "Alternating Arms"]
        ),
        ExerciseMetadata(
            name: "Machine Chest Press", muscleGroup: .chest, category: .push, equipment: .machine,
            difficulty: .beginner,
            primaryMuscles: ["Chest", "Pectoralis Major"],
            secondaryMuscles: ["Triceps", "Front Deltoids"],
            aliases: ["Seated Chest Press", "Chest Press Machine"],
            movementPattern: .press,
            cues: ["Adjust seat so handles align with mid-chest", "Press forward smoothly", "Control the return"],
            commonMistakes: ["Seat too high or low", "Locking out elbows", "Using momentum"],
            variations: ["Wide Grip", "Narrow Grip"]
        ),
        ExerciseMetadata(
            name: "Landmine Press", muscleGroup: .chest, category: .push, equipment: .barbell,
            difficulty: .intermediate,
            primaryMuscles: ["Upper Chest", "Front Deltoids"],
            secondaryMuscles: ["Triceps", "Core"],
            aliases: ["Angled Press", "Landmine Chest Press"],
            movementPattern: .press,
            cues: ["Stand at end of barbell in landmine", "Press up and forward", "Brace core throughout"],
            commonMistakes: ["Leaning back too much", "Not bracing core", "Using too narrow a stance"],
            variations: ["Single Arm", "Kneeling", "Standing"]
        ),
        ExerciseMetadata(
            name: "Svend Press", muscleGroup: .chest, category: .isolation, equipment: .other,
            difficulty: .beginner,
            primaryMuscles: ["Inner Chest", "Pectoralis Major"],
            secondaryMuscles: ["Front Deltoids"],
            aliases: ["Plate Squeeze Press"],
            movementPattern: .press,
            cues: ["Squeeze plates together hard", "Press forward from chest", "Maintain constant squeeze"],
            commonMistakes: ["Not squeezing hard enough", "Moving too fast", "Using too heavy plates"],
            variations: ["Standing", "Seated"]
        ),

        // ═══════════════════════════════════════
        // BACK (12)
        // ═══════════════════════════════════════

        ExerciseMetadata(
            name: "Deadlift", muscleGroup: .back, category: .compound, equipment: .barbell,
            difficulty: .advanced,
            primaryMuscles: ["Erector Spinae", "Glutes", "Hamstrings"],
            secondaryMuscles: ["Traps", "Lats", "Forearms", "Core"],
            aliases: ["Conventional Deadlift", "Barbell Deadlift"],
            movementPattern: .hinge,
            cues: ["Bar over mid-foot", "Brace core hard", "Push floor away, don't pull up"],
            commonMistakes: ["Rounding lower back", "Bar drifting forward", "Hyperextending at top"],
            variations: ["Sumo", "Romanian", "Trap Bar", "Deficit"]
        ),
        ExerciseMetadata(
            name: "Barbell Row", muscleGroup: .back, category: .pull, equipment: .barbell,
            difficulty: .intermediate,
            primaryMuscles: ["Lats", "Rhomboids", "Rear Deltoids"],
            secondaryMuscles: ["Biceps", "Erector Spinae", "Core"],
            aliases: ["Bent Over Row", "BB Row", "Pendlay Row"],
            movementPattern: .row,
            cues: ["Hinge at hips ~45 degrees", "Pull to lower chest/upper abs", "Squeeze shoulder blades"],
            commonMistakes: ["Using momentum", "Standing too upright", "Rounding back"],
            variations: ["Underhand Grip", "Pendlay", "Yates Row"]
        ),
        ExerciseMetadata(
            name: "Pull-ups", muscleGroup: .back, category: .pull, equipment: .bodyweight,
            difficulty: .intermediate,
            primaryMuscles: ["Lats", "Biceps"],
            secondaryMuscles: ["Rear Deltoids", "Rhomboids", "Core"],
            aliases: ["Pullups", "Chin-ups"],
            movementPattern: .pull,
            cues: ["Start from dead hang", "Pull elbows down and back", "Chin over bar"],
            commonMistakes: ["Kipping", "Incomplete range of motion", "Not fully extending at bottom"],
            variations: ["Wide Grip", "Chin-up", "Neutral Grip", "Weighted"]
        ),
        ExerciseMetadata(
            name: "Lat Pulldown", muscleGroup: .back, category: .pull, equipment: .cable,
            difficulty: .beginner,
            primaryMuscles: ["Lats"],
            secondaryMuscles: ["Biceps", "Rear Deltoids", "Rhomboids"],
            aliases: ["Cable Pulldown", "Wide Grip Pulldown"],
            movementPattern: .pull,
            cues: ["Lean back slightly", "Pull bar to upper chest", "Squeeze lats at bottom"],
            commonMistakes: ["Leaning back too far", "Using momentum", "Pulling behind neck"],
            variations: ["Close Grip", "Underhand", "Single Arm"]
        ),
        ExerciseMetadata(
            name: "Seated Cable Row", muscleGroup: .back, category: .pull, equipment: .cable,
            difficulty: .beginner,
            primaryMuscles: ["Lats", "Rhomboids", "Mid Traps"],
            secondaryMuscles: ["Biceps", "Rear Deltoids"],
            aliases: ["Cable Row", "Seated Row"],
            movementPattern: .row,
            cues: ["Sit tall, slight forward lean to start", "Pull to lower chest", "Squeeze shoulder blades together"],
            commonMistakes: ["Excessive body lean", "Using momentum", "Rounding shoulders forward"],
            variations: ["V-Bar", "Wide Grip", "Single Arm"]
        ),
        ExerciseMetadata(
            name: "T-Bar Row", muscleGroup: .back, category: .pull, equipment: .barbell,
            difficulty: .intermediate,
            primaryMuscles: ["Lats", "Rhomboids", "Mid Traps"],
            secondaryMuscles: ["Biceps", "Rear Deltoids", "Core"],
            aliases: ["T-Bar", "Landmine Row"],
            movementPattern: .row,
            cues: ["Straddle the bar", "Hinge forward 45 degrees", "Pull to chest"],
            commonMistakes: ["Standing too upright", "Rounding back", "Using too much body English"],
            variations: ["Close Grip", "Wide Grip", "Single Arm"]
        ),
        ExerciseMetadata(
            name: "Face Pulls", muscleGroup: .back, category: .pull, equipment: .cable,
            difficulty: .beginner,
            primaryMuscles: ["Rear Deltoids", "Rhomboids", "External Rotators"],
            secondaryMuscles: ["Mid Traps", "Biceps"],
            aliases: ["Cable Face Pull", "Rope Face Pull"],
            movementPattern: .pull,
            cues: ["Set cable at face height", "Pull rope to face, elbows high", "Externally rotate at end"],
            commonMistakes: ["Cable too low", "Not pulling far enough", "Using too much weight"],
            variations: ["Band Face Pulls", "Prone on Bench"]
        ),
        ExerciseMetadata(
            name: "Dumbbell Row", muscleGroup: .back, category: .pull, equipment: .dumbbell,
            difficulty: .beginner,
            primaryMuscles: ["Lats", "Rhomboids"],
            secondaryMuscles: ["Biceps", "Rear Deltoids", "Core"],
            aliases: ["DB Row", "One-Arm Row", "Single Arm Dumbbell Row"],
            movementPattern: .row,
            cues: ["Hand and knee on bench", "Pull to hip, not shoulder", "Keep torso stable"],
            commonMistakes: ["Rotating torso", "Pulling to shoulder", "Using momentum"],
            variations: ["Kroc Row", "Chest Supported", "Meadows Row"]
        ),
        ExerciseMetadata(
            name: "Chest-Supported Row", muscleGroup: .back, category: .pull, equipment: .dumbbell,
            difficulty: .beginner,
            primaryMuscles: ["Lats", "Rhomboids", "Mid Traps"],
            secondaryMuscles: ["Biceps", "Rear Deltoids"],
            aliases: ["Incline DB Row", "Seal Row"],
            movementPattern: .row,
            cues: ["Lie chest down on incline bench", "Pull both dumbbells up", "Squeeze shoulder blades"],
            commonMistakes: ["Lifting chest off bench", "Not full range of motion", "Going too heavy"],
            variations: ["Barbell Seal Row", "Machine Chest Supported"]
        ),
        ExerciseMetadata(
            name: "Rack Pull", muscleGroup: .back, category: .compound, equipment: .barbell,
            difficulty: .intermediate,
            primaryMuscles: ["Erector Spinae", "Traps", "Lats"],
            secondaryMuscles: ["Glutes", "Forearms"],
            aliases: ["Block Pull", "Partial Deadlift"],
            movementPattern: .hinge,
            cues: ["Set pins at knee height", "Same form as deadlift top half", "Lock out hips fully"],
            commonMistakes: ["Rounding upper back", "Hitching the bar", "Setting pins too high"],
            variations: ["Below Knee", "Above Knee", "Snatch Grip"]
        ),
        ExerciseMetadata(
            name: "Meadows Row", muscleGroup: .back, category: .pull, equipment: .barbell,
            difficulty: .intermediate,
            primaryMuscles: ["Lats", "Teres Major"],
            secondaryMuscles: ["Rear Deltoids", "Biceps"],
            aliases: ["Landmine Meadows Row", "One Arm Landmine Row"],
            movementPattern: .row,
            cues: ["Stand perpendicular to landmine", "Staggered stance", "Pull elbow back and up"],
            commonMistakes: ["Standing too far from bar", "Not enough hip hinge", "Rotating torso"],
            variations: ["Overhand Grip", "Underhand Grip"]
        ),
        ExerciseMetadata(
            name: "Straight Arm Pulldown", muscleGroup: .back, category: .isolation, equipment: .cable,
            difficulty: .beginner,
            primaryMuscles: ["Lats"],
            secondaryMuscles: ["Teres Major", "Core"],
            aliases: ["Straight Arm Pushdown", "Lat Pushdown"],
            movementPattern: .pull,
            cues: ["Arms nearly straight throughout", "Pull bar to thighs in an arc", "Squeeze lats at bottom"],
            commonMistakes: ["Bending elbows too much", "Using too much weight", "Leaning forward"],
            variations: ["Rope Attachment", "Single Arm"]
        ),

        // ═══════════════════════════════════════
        // SHOULDERS (10)
        // ═══════════════════════════════════════

        ExerciseMetadata(
            name: "Overhead Press", muscleGroup: .shoulders, category: .push, equipment: .barbell,
            difficulty: .intermediate,
            primaryMuscles: ["Front Deltoids", "Lateral Deltoids"],
            secondaryMuscles: ["Triceps", "Upper Chest", "Core"],
            aliases: ["Military Press", "OHP", "Standing Press"],
            movementPattern: .press,
            cues: ["Bar starts at shoulders", "Press straight up", "Lock out overhead"],
            commonMistakes: ["Excessive back arch", "Pressing forward", "Not locking out"],
            variations: ["Seated", "Push Press", "Dumbbell"]
        ),
        ExerciseMetadata(
            name: "Lateral Raises", muscleGroup: .shoulders, category: .isolation, equipment: .dumbbell,
            difficulty: .beginner,
            primaryMuscles: ["Lateral Deltoids"],
            secondaryMuscles: ["Front Deltoids", "Traps"],
            aliases: ["Side Raises", "Lateral Dumbbell Raises"],
            movementPattern: .push,
            cues: ["Slight bend in elbows", "Lead with elbows", "Raise to shoulder height"],
            commonMistakes: ["Using too much weight", "Swinging", "Shrugging traps"],
            variations: ["Cable", "Incline", "Leaning"]
        ),
        ExerciseMetadata(
            name: "Arnold Press", muscleGroup: .shoulders, category: .push, equipment: .dumbbell,
            difficulty: .intermediate,
            primaryMuscles: ["Front Deltoids", "Lateral Deltoids"],
            secondaryMuscles: ["Triceps", "Upper Traps"],
            aliases: ["Arnold Dumbbell Press"],
            movementPattern: .press,
            cues: ["Start with palms facing you", "Rotate as you press up", "Full lockout at top"],
            commonMistakes: ["Not rotating fully", "Using momentum", "Elbows flaring too wide"],
            variations: ["Seated", "Standing", "Single Arm"]
        ),
        ExerciseMetadata(
            name: "Front Raises", muscleGroup: .shoulders, category: .isolation, equipment: .dumbbell,
            difficulty: .beginner,
            primaryMuscles: ["Front Deltoids"],
            secondaryMuscles: ["Lateral Deltoids", "Upper Chest"],
            aliases: ["Front Delt Raises", "Dumbbell Front Raise"],
            movementPattern: .push,
            cues: ["Arms slightly bent", "Raise to eye level", "Control the descent"],
            commonMistakes: ["Swinging body", "Going too high", "Using too much weight"],
            variations: ["Barbell", "Cable", "Plate Front Raise"]
        ),
        ExerciseMetadata(
            name: "Rear Delt Fly", muscleGroup: .shoulders, category: .isolation, equipment: .dumbbell,
            difficulty: .beginner,
            primaryMuscles: ["Rear Deltoids"],
            secondaryMuscles: ["Rhomboids", "Mid Traps"],
            aliases: ["Reverse Fly", "Bent Over Fly", "Rear Delt Raise"],
            movementPattern: .pull,
            cues: ["Hinge forward, chest parallel to floor", "Lead with elbows", "Squeeze shoulder blades"],
            commonMistakes: ["Not hinging enough", "Using momentum", "Going too heavy"],
            variations: ["Cable", "Machine", "Incline Bench"]
        ),
        ExerciseMetadata(
            name: "Upright Row", muscleGroup: .shoulders, category: .pull, equipment: .barbell,
            difficulty: .intermediate,
            primaryMuscles: ["Lateral Deltoids", "Upper Traps"],
            secondaryMuscles: ["Front Deltoids", "Biceps"],
            aliases: ["Barbell Upright Row"],
            movementPattern: .pull,
            cues: ["Wider grip to reduce impingement", "Pull to chest height", "Lead with elbows"],
            commonMistakes: ["Grip too narrow", "Pulling too high", "Internal rotation of shoulders"],
            variations: ["Dumbbell", "Cable", "EZ Bar"]
        ),
        ExerciseMetadata(
            name: "Cable Lateral Raise", muscleGroup: .shoulders, category: .isolation, equipment: .cable,
            difficulty: .beginner,
            primaryMuscles: ["Lateral Deltoids"],
            secondaryMuscles: ["Front Deltoids", "Traps"],
            aliases: ["Cable Side Raise", "Single Arm Cable Lateral"],
            movementPattern: .push,
            cues: ["Cable at low position, cross-body", "Raise to shoulder height", "Pause at top"],
            commonMistakes: ["Leaning away too much", "Using momentum", "Going past shoulder height"],
            variations: ["Behind Back", "Dual Cable"]
        ),
        ExerciseMetadata(
            name: "Shoulder Landmine Press", muscleGroup: .shoulders, category: .push, equipment: .barbell,
            difficulty: .intermediate,
            primaryMuscles: ["Front Deltoids", "Upper Chest"],
            secondaryMuscles: ["Triceps", "Core", "Serratus Anterior"],
            aliases: ["Half-Kneeling Landmine Press", "Landmine Shoulder Press"],
            movementPattern: .press,
            cues: ["Half-kneeling position", "Press at an angle overhead", "Brace core throughout"],
            commonMistakes: ["Arching lower back", "Not bracing core", "Pressing straight up"],
            variations: ["Standing", "Kneeling", "Two Arm"]
        ),
        ExerciseMetadata(
            name: "Rear Delt Face Pulls", muscleGroup: .shoulders, category: .isolation, equipment: .cable,
            difficulty: .beginner,
            primaryMuscles: ["Rear Deltoids", "External Rotators"],
            secondaryMuscles: ["Rhomboids", "Mid Traps"],
            aliases: ["High Face Pulls", "Shoulder Face Pulls"],
            movementPattern: .pull,
            cues: ["High cable attachment", "Pull to forehead", "External rotate at end position"],
            commonMistakes: ["Too much weight", "Not externally rotating", "Cable too low"],
            variations: ["Band", "Rope", "Single Arm"]
        ),
        ExerciseMetadata(
            name: "Seated Dumbbell Press", muscleGroup: .shoulders, category: .push, equipment: .dumbbell,
            difficulty: .beginner,
            primaryMuscles: ["Front Deltoids", "Lateral Deltoids"],
            secondaryMuscles: ["Triceps", "Upper Traps"],
            aliases: ["Seated DB Press", "Dumbbell Shoulder Press"],
            movementPattern: .press,
            cues: ["Back against pad", "Press straight up", "Dumbbells touch lightly at top"],
            commonMistakes: ["Arching back off pad", "Pressing unevenly", "Not full ROM"],
            variations: ["Neutral Grip", "Alternating", "Single Arm"]
        ),

        // ═══════════════════════════════════════
        // BICEPS (8)
        // ═══════════════════════════════════════

        ExerciseMetadata(
            name: "Bicep Curls", muscleGroup: .biceps, category: .isolation, equipment: .dumbbell,
            difficulty: .beginner,
            primaryMuscles: ["Biceps"],
            secondaryMuscles: ["Forearms"],
            aliases: ["Dumbbell Curls", "DB Curls", "Standing Curls"],
            movementPattern: .curl,
            cues: ["Keep elbows pinned", "Full range of motion", "Control the negative"],
            commonMistakes: ["Swinging body", "Moving elbows forward", "Partial reps"],
            variations: ["Hammer", "Incline", "Concentration", "Preacher"]
        ),
        ExerciseMetadata(
            name: "Barbell Curl", muscleGroup: .biceps, category: .isolation, equipment: .barbell,
            difficulty: .beginner,
            primaryMuscles: ["Biceps", "Biceps Brachii"],
            secondaryMuscles: ["Forearms", "Brachialis"],
            aliases: ["BB Curl", "Standing Barbell Curl", "EZ Bar Curl"],
            movementPattern: .curl,
            cues: ["Elbows at sides", "Curl to shoulder height", "Squeeze at top"],
            commonMistakes: ["Swinging hips", "Elbows drifting forward", "Using back"],
            variations: ["EZ Bar", "Wide Grip", "Narrow Grip", "21s"]
        ),
        ExerciseMetadata(
            name: "Hammer Curls", muscleGroup: .biceps, category: .isolation, equipment: .dumbbell,
            difficulty: .beginner,
            primaryMuscles: ["Brachialis", "Brachioradialis"],
            secondaryMuscles: ["Biceps", "Forearms"],
            aliases: ["Hammer Curl", "Neutral Grip Curl"],
            movementPattern: .curl,
            cues: ["Palms face each other", "Curl straight up", "Squeeze at top"],
            commonMistakes: ["Swinging body", "Rotating wrists", "Partial range of motion"],
            variations: ["Cross-Body", "Cable", "Rope"]
        ),
        ExerciseMetadata(
            name: "Preacher Curls", muscleGroup: .biceps, category: .isolation, equipment: .barbell,
            difficulty: .intermediate,
            primaryMuscles: ["Biceps", "Short Head"],
            secondaryMuscles: ["Brachialis", "Forearms"],
            aliases: ["Preacher Curl", "Scott Curl"],
            movementPattern: .curl,
            cues: ["Armpits snug against pad", "Lower fully", "Curl to full contraction"],
            commonMistakes: ["Not lowering fully", "Lifting off pad", "Going too heavy"],
            variations: ["Dumbbell", "EZ Bar", "Machine", "Single Arm"]
        ),
        ExerciseMetadata(
            name: "Concentration Curls", muscleGroup: .biceps, category: .isolation, equipment: .dumbbell,
            difficulty: .beginner,
            primaryMuscles: ["Biceps", "Bicep Peak"],
            secondaryMuscles: ["Forearms"],
            aliases: ["Concentration Curl", "Seated Curl"],
            movementPattern: .curl,
            cues: ["Elbow against inner thigh", "Curl to shoulder", "Squeeze at top"],
            commonMistakes: ["Using momentum", "Not full extension", "Elbow moving off thigh"],
            variations: ["Standing", "Cable"]
        ),
        ExerciseMetadata(
            name: "Incline Dumbbell Curls", muscleGroup: .biceps, category: .isolation, equipment: .dumbbell,
            difficulty: .intermediate,
            primaryMuscles: ["Biceps", "Long Head"],
            secondaryMuscles: ["Forearms"],
            aliases: ["Incline Curl", "Incline DB Curl"],
            movementPattern: .curl,
            cues: ["Set bench to 45-60 degrees", "Let arms hang straight", "Curl without moving upper arm"],
            commonMistakes: ["Bench too upright", "Swinging arms", "Moving elbows forward"],
            variations: ["Alternating", "Hammer Grip"]
        ),
        ExerciseMetadata(
            name: "Cable Curls", muscleGroup: .biceps, category: .isolation, equipment: .cable,
            difficulty: .beginner,
            primaryMuscles: ["Biceps"],
            secondaryMuscles: ["Forearms"],
            aliases: ["Cable Bicep Curl", "Cable Curl"],
            movementPattern: .curl,
            cues: ["Stand facing low cable", "Elbows at sides", "Squeeze at the top"],
            commonMistakes: ["Leaning back", "Moving elbows", "Using body momentum"],
            variations: ["Rope", "Bar", "Single Arm", "High Cable"]
        ),
        ExerciseMetadata(
            name: "Spider Curls", muscleGroup: .biceps, category: .isolation, equipment: .dumbbell,
            difficulty: .intermediate,
            primaryMuscles: ["Biceps", "Short Head"],
            secondaryMuscles: ["Brachialis"],
            aliases: ["Spider Curl", "Prone Incline Curl"],
            movementPattern: .curl,
            cues: ["Lie chest on incline bench", "Arms hang straight down", "Curl without moving upper arms"],
            commonMistakes: ["Using momentum", "Not full range", "Moving upper arms"],
            variations: ["Barbell", "EZ Bar", "Cable"]
        ),

        // ═══════════════════════════════════════
        // TRICEPS (8)
        // ═══════════════════════════════════════

        ExerciseMetadata(
            name: "Tricep Pushdown", muscleGroup: .triceps, category: .isolation, equipment: .cable,
            difficulty: .beginner,
            primaryMuscles: ["Triceps"],
            secondaryMuscles: ["Forearms"],
            aliases: ["Cable Pushdown", "Tricep Pressdown", "Rope Pushdown"],
            movementPattern: .tricepsExtension,
            cues: ["Elbows stay at sides", "Full extension at bottom", "Squeeze triceps"],
            commonMistakes: ["Moving elbows", "Leaning forward too much", "Not fully extending"],
            variations: ["Rope", "V-Bar", "Straight Bar", "Single Arm"]
        ),
        ExerciseMetadata(
            name: "Skull Crushers", muscleGroup: .triceps, category: .isolation, equipment: .barbell,
            difficulty: .intermediate,
            primaryMuscles: ["Triceps"],
            secondaryMuscles: ["Forearms"],
            aliases: ["Lying Tricep Extension", "French Press", "Nose Breakers"],
            movementPattern: .tricepsExtension,
            cues: ["Lower bar to forehead/behind head", "Keep elbows pointed up", "Extend fully"],
            commonMistakes: ["Flaring elbows", "Moving upper arms", "Using too much weight"],
            variations: ["EZ Bar", "Dumbbell", "Incline", "Behind Head"]
        ),
        ExerciseMetadata(
            name: "Overhead Tricep Extension", muscleGroup: .triceps, category: .isolation, equipment: .dumbbell,
            difficulty: .beginner,
            primaryMuscles: ["Triceps", "Long Head"],
            secondaryMuscles: ["Forearms"],
            aliases: ["Overhead Extension", "Tricep Overhead"],
            movementPattern: .tricepsExtension,
            cues: ["Hold weight overhead", "Lower behind head", "Extend fully overhead"],
            commonMistakes: ["Flaring elbows wide", "Arching back", "Not full range of motion"],
            variations: ["Cable", "Single Arm", "EZ Bar"]
        ),
        ExerciseMetadata(
            name: "Close-Grip Bench Press", muscleGroup: .triceps, category: .push, equipment: .barbell,
            difficulty: .intermediate,
            primaryMuscles: ["Triceps", "Chest"],
            secondaryMuscles: ["Front Deltoids"],
            aliases: ["CGBP", "Close Grip Bench"],
            movementPattern: .press,
            cues: ["Hands shoulder-width apart", "Elbows tucked to sides", "Touch lower chest"],
            commonMistakes: ["Grip too narrow", "Flaring elbows", "Bouncing off chest"],
            variations: ["Smith Machine", "Dumbbell"]
        ),
        ExerciseMetadata(
            name: "Tricep Dips", muscleGroup: .triceps, category: .push, equipment: .bodyweight,
            difficulty: .intermediate,
            primaryMuscles: ["Triceps"],
            secondaryMuscles: ["Chest", "Front Deltoids"],
            aliases: ["Bench Dips", "Bodyweight Dips"],
            movementPattern: .push,
            cues: ["Keep torso upright", "Lower until 90 degrees", "Elbows pointed back"],
            commonMistakes: ["Going too deep", "Leaning forward too much", "Rushing reps"],
            variations: ["Weighted", "Machine Assisted", "Bench Dips"]
        ),
        ExerciseMetadata(
            name: "Kickbacks", muscleGroup: .triceps, category: .isolation, equipment: .dumbbell,
            difficulty: .beginner,
            primaryMuscles: ["Triceps"],
            secondaryMuscles: ["Rear Deltoids"],
            aliases: ["Tricep Kickback", "DB Kickback"],
            movementPattern: .tricepsExtension,
            cues: ["Hinge forward, upper arm parallel to floor", "Extend arm fully back", "Squeeze at lockout"],
            commonMistakes: ["Swinging the weight", "Upper arm dropping", "Not extending fully"],
            variations: ["Cable", "Dual Arm", "Single Arm"]
        ),
        ExerciseMetadata(
            name: "Diamond Push-ups", muscleGroup: .triceps, category: .push, equipment: .bodyweight,
            difficulty: .intermediate,
            primaryMuscles: ["Triceps"],
            secondaryMuscles: ["Chest", "Front Deltoids"],
            aliases: ["Close Grip Push-ups", "Triangle Push-ups"],
            movementPattern: .push,
            cues: ["Hands together forming diamond", "Lower chest to hands", "Keep elbows close"],
            commonMistakes: ["Hips sagging", "Elbows flaring out", "Incomplete reps"],
            variations: ["Elevated", "Deficit"]
        ),
        ExerciseMetadata(
            name: "JM Press", muscleGroup: .triceps, category: .push, equipment: .barbell,
            difficulty: .advanced,
            primaryMuscles: ["Triceps"],
            secondaryMuscles: ["Chest", "Front Deltoids"],
            aliases: ["JM Blakely Press"],
            movementPattern: .press,
            cues: ["Hybrid of close-grip bench and skull crusher", "Lower to chin/throat area", "Press back to lockout"],
            commonMistakes: ["Turning into a bench press", "Bar path too low", "Using too much weight"],
            variations: ["EZ Bar", "Dumbbell"]
        ),

        // ═══════════════════════════════════════
        // QUADS (10)
        // ═══════════════════════════════════════

        ExerciseMetadata(
            name: "Squat", muscleGroup: .quads, category: .compound, equipment: .barbell,
            difficulty: .intermediate,
            primaryMuscles: ["Quads", "Glutes"],
            secondaryMuscles: ["Hamstrings", "Core", "Erector Spinae"],
            aliases: ["Back Squat", "Barbell Squat", "High Bar Squat"],
            movementPattern: .squat,
            cues: ["Brace core before descent", "Knees track over toes", "Depth: hip crease below knee"],
            commonMistakes: ["Knees caving inward", "Forward lean", "Rising on toes"],
            variations: ["Front Squat", "Low Bar", "Pause Squat", "Box Squat"]
        ),
        ExerciseMetadata(
            name: "Leg Press", muscleGroup: .quads, category: .compound, equipment: .machine,
            difficulty: .beginner,
            primaryMuscles: ["Quads", "Glutes"],
            secondaryMuscles: ["Hamstrings"],
            aliases: ["45 Degree Leg Press", "Sled Leg Press"],
            movementPattern: .squat,
            cues: ["Feet shoulder width apart", "Lower until 90 degrees", "Don't lock knees at top"],
            commonMistakes: ["Letting lower back round", "Partial reps", "Locking knees"],
            variations: ["Single Leg", "High Foot", "Low Foot", "Wide Stance"]
        ),
        ExerciseMetadata(
            name: "Front Squat", muscleGroup: .quads, category: .compound, equipment: .barbell,
            difficulty: .advanced,
            primaryMuscles: ["Quads", "Core"],
            secondaryMuscles: ["Glutes", "Upper Back"],
            aliases: ["Barbell Front Squat"],
            movementPattern: .squat,
            cues: ["Clean grip or cross-arm", "Elbows high, chest up", "Sit straight down"],
            commonMistakes: ["Elbows dropping", "Wrist pain from grip", "Leaning forward"],
            variations: ["Goblet Squat", "Zercher Squat"]
        ),
        ExerciseMetadata(
            name: "Goblet Squat", muscleGroup: .quads, category: .compound, equipment: .dumbbell,
            difficulty: .beginner,
            primaryMuscles: ["Quads", "Glutes"],
            secondaryMuscles: ["Core", "Upper Back"],
            aliases: ["DB Goblet Squat", "Kettlebell Goblet Squat"],
            movementPattern: .squat,
            cues: ["Hold weight at chest", "Elbows between knees at bottom", "Push knees out"],
            commonMistakes: ["Leaning forward", "Not going deep enough", "Weight pulling you forward"],
            variations: ["Kettlebell", "Pulse", "1.5 Rep"]
        ),
        ExerciseMetadata(
            name: "Leg Extension", muscleGroup: .quads, category: .isolation, equipment: .machine,
            difficulty: .beginner,
            primaryMuscles: ["Quads", "Rectus Femoris"],
            secondaryMuscles: ["Vastus Lateralis", "Vastus Medialis"],
            aliases: ["Quad Extension", "Seated Leg Extension"],
            movementPattern: .push,
            cues: ["Adjust pad to lower shin", "Extend fully", "Control the descent"],
            commonMistakes: ["Using momentum", "Not full extension", "Lifting hips off seat"],
            variations: ["Single Leg", "Pause at Top"]
        ),
        ExerciseMetadata(
            name: "Hack Squat", muscleGroup: .quads, category: .compound, equipment: .machine,
            difficulty: .intermediate,
            primaryMuscles: ["Quads"],
            secondaryMuscles: ["Glutes", "Hamstrings"],
            aliases: ["Hack Squat Machine"],
            movementPattern: .squat,
            cues: ["Shoulders under pads", "Feet lower on platform for quads", "Full depth"],
            commonMistakes: ["Knees caving", "Not going deep enough", "Locking knees at top"],
            variations: ["Reverse Hack Squat", "Narrow Stance", "Wide Stance"]
        ),
        ExerciseMetadata(
            name: "Bulgarian Split Squat", muscleGroup: .quads, category: .compound, equipment: .dumbbell,
            difficulty: .intermediate,
            primaryMuscles: ["Quads", "Glutes"],
            secondaryMuscles: ["Hamstrings", "Core"],
            aliases: ["BSS", "Rear Foot Elevated Split Squat"],
            movementPattern: .lunge,
            cues: ["Rear foot on bench", "Torso upright", "Front knee tracks over toes"],
            commonMistakes: ["Standing too close to bench", "Leaning forward", "Knee going past toes excessively"],
            variations: ["Barbell", "Bodyweight", "Deficit"]
        ),
        ExerciseMetadata(
            name: "Sissy Squat", muscleGroup: .quads, category: .isolation, equipment: .bodyweight,
            difficulty: .advanced,
            primaryMuscles: ["Quads", "Rectus Femoris"],
            secondaryMuscles: ["Core", "Hip Flexors"],
            aliases: ["Sissy Hack Squat"],
            movementPattern: .squat,
            cues: ["Rise onto toes", "Lean back, knees forward", "Lower until knees past toes deeply"],
            commonMistakes: ["Not enough lean", "Rounding back", "Losing balance"],
            variations: ["Weighted", "Machine Sissy Squat"]
        ),
        ExerciseMetadata(
            name: "Walking Lunges", muscleGroup: .quads, category: .compound, equipment: .dumbbell,
            difficulty: .beginner,
            primaryMuscles: ["Quads", "Glutes"],
            secondaryMuscles: ["Hamstrings", "Core"],
            aliases: ["Lunges", "Forward Lunges", "DB Walking Lunges"],
            movementPattern: .lunge,
            cues: ["Long stride forward", "Back knee almost touches ground", "Torso stays upright"],
            commonMistakes: ["Short steps", "Leaning forward", "Knee caving inward"],
            variations: ["Reverse Lunges", "Barbell", "Bodyweight"]
        ),
        ExerciseMetadata(
            name: "Step-Ups", muscleGroup: .quads, category: .compound, equipment: .dumbbell,
            difficulty: .beginner,
            primaryMuscles: ["Quads", "Glutes"],
            secondaryMuscles: ["Hamstrings", "Core"],
            aliases: ["Dumbbell Step-Ups", "Box Step-Ups"],
            movementPattern: .lunge,
            cues: ["Full foot on box", "Drive through front heel", "Control descent"],
            commonMistakes: ["Pushing off back foot", "Box too high", "Leaning forward"],
            variations: ["Barbell", "Lateral Step-Up", "Deficit"]
        ),

        // ═══════════════════════════════════════
        // HAMSTRINGS (8)
        // ═══════════════════════════════════════

        ExerciseMetadata(
            name: "Romanian Deadlift", muscleGroup: .hamstrings, category: .compound, equipment: .barbell,
            difficulty: .intermediate,
            primaryMuscles: ["Hamstrings", "Glutes"],
            secondaryMuscles: ["Erector Spinae", "Core"],
            aliases: ["RDL", "Stiff Leg Deadlift"],
            movementPattern: .hinge,
            cues: ["Soft knee bend", "Push hips back", "Bar stays close to legs"],
            commonMistakes: ["Rounding back", "Going too low", "Bending knees too much"],
            variations: ["Single Leg", "Dumbbell", "Deficit"]
        ),
        ExerciseMetadata(
            name: "Lying Leg Curl", muscleGroup: .hamstrings, category: .isolation, equipment: .machine,
            difficulty: .beginner,
            primaryMuscles: ["Hamstrings"],
            secondaryMuscles: ["Calves"],
            aliases: ["Hamstring Curl", "Prone Leg Curl"],
            movementPattern: .curl,
            cues: ["Hips pressed into pad", "Curl to full contraction", "Control the descent"],
            commonMistakes: ["Hips rising off pad", "Using momentum", "Not full range"],
            variations: ["Single Leg", "Toes Pointed In"]
        ),
        ExerciseMetadata(
            name: "Seated Leg Curl", muscleGroup: .hamstrings, category: .isolation, equipment: .machine,
            difficulty: .beginner,
            primaryMuscles: ["Hamstrings"],
            secondaryMuscles: ["Calves"],
            aliases: ["Seated Hamstring Curl"],
            movementPattern: .curl,
            cues: ["Adjust pad to just above ankles", "Curl under and squeeze", "Slow eccentric"],
            commonMistakes: ["Using momentum", "Not full range", "Seat not adjusted properly"],
            variations: ["Single Leg", "Pause Reps"]
        ),
        ExerciseMetadata(
            name: "Nordic Curls", muscleGroup: .hamstrings, category: .isolation, equipment: .bodyweight,
            difficulty: .advanced,
            primaryMuscles: ["Hamstrings"],
            secondaryMuscles: ["Calves", "Glutes"],
            aliases: ["Nordic Hamstring Curl", "NHC"],
            movementPattern: .curl,
            cues: ["Kneel with ankles anchored", "Lower body forward slowly", "Use hamstrings to control"],
            commonMistakes: ["Bending at hips", "Falling forward uncontrolled", "Not enough eccentric control"],
            variations: ["Assisted with Band", "Slider Variation"]
        ),
        ExerciseMetadata(
            name: "Good Mornings", muscleGroup: .hamstrings, category: .compound, equipment: .barbell,
            difficulty: .intermediate,
            primaryMuscles: ["Hamstrings", "Erector Spinae"],
            secondaryMuscles: ["Glutes", "Core"],
            aliases: ["Barbell Good Morning"],
            movementPattern: .hinge,
            cues: ["Bar on upper back", "Hinge at hips", "Feel stretch in hamstrings"],
            commonMistakes: ["Rounding back", "Going too heavy", "Bending knees too much"],
            variations: ["Seated", "Banded", "Single Leg"]
        ),
        ExerciseMetadata(
            name: "Glute-Ham Raise", muscleGroup: .hamstrings, category: .compound, equipment: .machine,
            difficulty: .advanced,
            primaryMuscles: ["Hamstrings", "Glutes"],
            secondaryMuscles: ["Erector Spinae", "Calves"],
            aliases: ["GHR", "GHD Raise"],
            movementPattern: .hinge,
            cues: ["Start with torso perpendicular", "Lower under control", "Pull yourself back up with hamstrings"],
            commonMistakes: ["Using back instead of hamstrings", "Not going low enough", "Using hands to push"],
            variations: ["Banded Assisted", "Weighted"]
        ),
        ExerciseMetadata(
            name: "Single-Leg RDL", muscleGroup: .hamstrings, category: .compound, equipment: .dumbbell,
            difficulty: .intermediate,
            primaryMuscles: ["Hamstrings", "Glutes"],
            secondaryMuscles: ["Core", "Erector Spinae"],
            aliases: ["Single Leg Romanian Deadlift", "One Leg RDL"],
            movementPattern: .hinge,
            cues: ["Hinge on one leg", "Back leg extends behind", "Maintain flat back"],
            commonMistakes: ["Rotating hips", "Rounding back", "Losing balance"],
            variations: ["Kettlebell", "Barbell", "Bodyweight"]
        ),
        ExerciseMetadata(
            name: "Stiff-Leg Deadlift", muscleGroup: .hamstrings, category: .compound, equipment: .barbell,
            difficulty: .intermediate,
            primaryMuscles: ["Hamstrings", "Erector Spinae"],
            secondaryMuscles: ["Glutes", "Core"],
            aliases: ["Stiff Leg DL", "Straight Leg Deadlift"],
            movementPattern: .hinge,
            cues: ["Legs nearly straight", "Lower bar along legs", "Feel deep hamstring stretch"],
            commonMistakes: ["Rounding lower back", "Knees bending too much", "Bar drifting away from body"],
            variations: ["Deficit", "Dumbbell"]
        ),

        // ═══════════════════════════════════════
        // GLUTES (8)
        // ═══════════════════════════════════════

        ExerciseMetadata(
            name: "Hip Thrust", muscleGroup: .glutes, category: .compound, equipment: .barbell,
            difficulty: .intermediate,
            primaryMuscles: ["Glutes"],
            secondaryMuscles: ["Hamstrings", "Core"],
            aliases: ["Barbell Hip Thrust", "Glute Bridge"],
            movementPattern: .hinge,
            cues: ["Upper back on bench", "Drive through heels", "Squeeze glutes at top"],
            commonMistakes: ["Hyperextending lower back", "Not reaching full extension", "Bar placement too high"],
            variations: ["Single Leg", "Banded", "Dumbbell"]
        ),
        ExerciseMetadata(
            name: "Glute Bridge", muscleGroup: .glutes, category: .isolation, equipment: .bodyweight,
            difficulty: .beginner,
            primaryMuscles: ["Glutes"],
            secondaryMuscles: ["Hamstrings", "Core"],
            aliases: ["Floor Glute Bridge", "Bridge"],
            movementPattern: .hinge,
            cues: ["Lie on back, feet flat", "Push hips up", "Squeeze glutes at top for 2 seconds"],
            commonMistakes: ["Pushing through toes", "Not full hip extension", "Arching lower back"],
            variations: ["Single Leg", "Banded", "Weighted"]
        ),
        ExerciseMetadata(
            name: "Cable Kickback", muscleGroup: .glutes, category: .isolation, equipment: .cable,
            difficulty: .beginner,
            primaryMuscles: ["Glutes", "Gluteus Maximus"],
            secondaryMuscles: ["Hamstrings"],
            aliases: ["Glute Kickback", "Cable Glute Kickback"],
            movementPattern: .hinge,
            cues: ["Ankle strap on low cable", "Kick leg straight back", "Squeeze glute at top"],
            commonMistakes: ["Arching lower back", "Using momentum", "Leaning too far forward"],
            variations: ["Standing", "Kneeling", "Band"]
        ),
        ExerciseMetadata(
            name: "Glute-Focused BSS", muscleGroup: .glutes, category: .compound, equipment: .dumbbell,
            difficulty: .intermediate,
            primaryMuscles: ["Glutes"],
            secondaryMuscles: ["Quads", "Hamstrings", "Core"],
            aliases: ["Glute Split Squat", "Bulgarian Split Squat Glute Focus"],
            movementPattern: .lunge,
            cues: ["Longer stride than quad-focused", "Lean torso slightly forward", "Push through heel"],
            commonMistakes: ["Stance too short", "Not leaning enough", "Pushing through toes"],
            variations: ["Barbell", "Bodyweight"]
        ),
        ExerciseMetadata(
            name: "Sumo Deadlift", muscleGroup: .glutes, category: .compound, equipment: .barbell,
            difficulty: .intermediate,
            primaryMuscles: ["Glutes", "Adductors"],
            secondaryMuscles: ["Quads", "Hamstrings", "Erector Spinae"],
            aliases: ["Sumo DL", "Wide Stance Deadlift"],
            movementPattern: .hinge,
            cues: ["Wide stance, toes out", "Grip inside knees", "Push knees out and drive hips"],
            commonMistakes: ["Hips shooting up first", "Knees caving", "Not pushing knees out enough"],
            variations: ["Deficit", "Block Pull"]
        ),
        ExerciseMetadata(
            name: "Frog Pumps", muscleGroup: .glutes, category: .isolation, equipment: .bodyweight,
            difficulty: .beginner,
            primaryMuscles: ["Glutes"],
            secondaryMuscles: ["Adductors"],
            aliases: ["Frog Pump"],
            movementPattern: .hinge,
            cues: ["Soles of feet together, knees out", "Lie on back", "Push hips up using glutes only"],
            commonMistakes: ["Using hamstrings", "Not squeezing glutes", "Rushing reps"],
            variations: ["Weighted", "Banded"]
        ),
        ExerciseMetadata(
            name: "Hip Abduction Machine", muscleGroup: .glutes, category: .isolation, equipment: .machine,
            difficulty: .beginner,
            primaryMuscles: ["Gluteus Medius", "Gluteus Minimus"],
            secondaryMuscles: ["TFL"],
            aliases: ["Abduction Machine", "Seated Hip Abduction"],
            movementPattern: .push,
            cues: ["Sit upright", "Push knees apart", "Control the return"],
            commonMistakes: ["Leaning back too much", "Using momentum", "Not full range"],
            variations: ["Leaning Forward", "Standing Cable"]
        ),
        ExerciseMetadata(
            name: "Curtsy Lunge", muscleGroup: .glutes, category: .compound, equipment: .dumbbell,
            difficulty: .intermediate,
            primaryMuscles: ["Gluteus Medius", "Glutes"],
            secondaryMuscles: ["Quads", "Adductors"],
            aliases: ["Cross-Behind Lunge", "Curtsey Lunge"],
            movementPattern: .lunge,
            cues: ["Step back and across behind front leg", "Lower until front thigh parallel", "Push through front heel"],
            commonMistakes: ["Not crossing far enough", "Knee caving on front leg", "Torso leaning forward"],
            variations: ["Bodyweight", "Barbell"]
        ),

        // ═══════════════════════════════════════
        // CALVES (5)
        // ═══════════════════════════════════════

        ExerciseMetadata(
            name: "Standing Calf Raise", muscleGroup: .calves, category: .isolation, equipment: .machine,
            difficulty: .beginner,
            primaryMuscles: ["Gastrocnemius"],
            secondaryMuscles: ["Soleus"],
            aliases: ["Calf Raise", "Standing Calf"],
            movementPattern: .push,
            cues: ["Balls of feet on edge", "Full stretch at bottom", "Rise as high as possible"],
            commonMistakes: ["Bouncing", "Partial range of motion", "Using too much weight"],
            variations: ["Dumbbell", "Barbell", "Smith Machine"]
        ),
        ExerciseMetadata(
            name: "Seated Calf Raise", muscleGroup: .calves, category: .isolation, equipment: .machine,
            difficulty: .beginner,
            primaryMuscles: ["Soleus"],
            secondaryMuscles: ["Gastrocnemius"],
            aliases: ["Seated Calf"],
            movementPattern: .push,
            cues: ["Knees at 90 degrees under pad", "Full stretch at bottom", "Pause at top"],
            commonMistakes: ["Bouncing", "Not full range", "Going too fast"],
            variations: ["Dumbbell on Knee", "Plate on Knee"]
        ),
        ExerciseMetadata(
            name: "Donkey Calf Raise", muscleGroup: .calves, category: .isolation, equipment: .machine,
            difficulty: .intermediate,
            primaryMuscles: ["Gastrocnemius"],
            secondaryMuscles: ["Soleus"],
            aliases: ["Donkey Calf"],
            movementPattern: .push,
            cues: ["Hinge at hips with back flat", "Full stretch at bottom", "Explode up on toes"],
            commonMistakes: ["Rounding back", "Not enough stretch", "Rushing reps"],
            variations: ["Machine", "Partner Weighted"]
        ),
        ExerciseMetadata(
            name: "Leg Press Calf Raise", muscleGroup: .calves, category: .isolation, equipment: .machine,
            difficulty: .beginner,
            primaryMuscles: ["Gastrocnemius", "Soleus"],
            secondaryMuscles: [],
            aliases: ["Calf Press", "Leg Press Calf"],
            movementPattern: .push,
            cues: ["Only toes on platform", "Press through balls of feet", "Full range of motion"],
            commonMistakes: ["Locking knees", "Partial reps", "Too much weight"],
            variations: ["Single Leg", "Toes In", "Toes Out"]
        ),
        ExerciseMetadata(
            name: "Single-Leg Calf Raise", muscleGroup: .calves, category: .isolation, equipment: .bodyweight,
            difficulty: .beginner,
            primaryMuscles: ["Gastrocnemius", "Soleus"],
            secondaryMuscles: [],
            aliases: ["One Leg Calf Raise", "Unilateral Calf Raise"],
            movementPattern: .push,
            cues: ["Stand on edge of step", "Full stretch at bottom", "Pause at top"],
            commonMistakes: ["Rushing reps", "Not going low enough", "Not holding at top"],
            variations: ["Weighted", "On Step"]
        ),

        // ═══════════════════════════════════════
        // CORE (12)
        // ═══════════════════════════════════════

        ExerciseMetadata(
            name: "Plank", muscleGroup: .core, category: .core, equipment: .bodyweight,
            difficulty: .beginner,
            primaryMuscles: ["Rectus Abdominis", "Transverse Abdominis"],
            secondaryMuscles: ["Obliques", "Glutes", "Shoulders"],
            aliases: ["Front Plank", "Forearm Plank"],
            movementPattern: .plank,
            cues: ["Straight line from head to heels", "Squeeze glutes", "Don't let hips sag"],
            commonMistakes: ["Hips too high", "Hips sagging", "Looking up"],
            variations: ["Side Plank", "Weighted", "RKC Plank"]
        ),
        ExerciseMetadata(
            name: "Leg Raises", muscleGroup: .core, category: .core, equipment: .bodyweight,
            difficulty: .intermediate,
            primaryMuscles: ["Lower Abs", "Hip Flexors"],
            secondaryMuscles: ["Obliques"],
            aliases: ["Lying Leg Raises", "Flat Leg Raises"],
            movementPattern: .plank,
            cues: ["Keep lower back pressed down", "Control the descent", "Don't swing"],
            commonMistakes: ["Using momentum", "Arching lower back", "Bending knees too much"],
            variations: ["Hanging", "Captain's Chair", "Weighted"]
        ),
        ExerciseMetadata(
            name: "Hanging Leg Raise", muscleGroup: .core, category: .core, equipment: .bodyweight,
            difficulty: .advanced,
            primaryMuscles: ["Lower Abs", "Hip Flexors"],
            secondaryMuscles: ["Obliques", "Forearms"],
            aliases: ["Hanging Raise", "Hanging Knee Raise"],
            movementPattern: .plank,
            cues: ["Dead hang from bar", "Raise legs to parallel or higher", "Curl pelvis up"],
            commonMistakes: ["Swinging", "Using momentum", "Not curling pelvis"],
            variations: ["Knee Raise", "Toes to Bar", "Windshield Wipers"]
        ),
        ExerciseMetadata(
            name: "Cable Crunch", muscleGroup: .core, category: .core, equipment: .cable,
            difficulty: .intermediate,
            primaryMuscles: ["Rectus Abdominis"],
            secondaryMuscles: ["Obliques"],
            aliases: ["Cable Crunches", "Kneeling Cable Crunch"],
            movementPattern: .plank,
            cues: ["Kneel facing cable", "Rope behind head", "Crunch down, rounding spine"],
            commonMistakes: ["Sitting back on heels", "Pulling with arms", "Not rounding spine"],
            variations: ["Standing", "Oblique Cable Crunch"]
        ),
        ExerciseMetadata(
            name: "Ab Wheel Rollout", muscleGroup: .core, category: .core, equipment: .other,
            difficulty: .intermediate,
            primaryMuscles: ["Rectus Abdominis", "Transverse Abdominis"],
            secondaryMuscles: ["Lats", "Shoulders", "Hip Flexors"],
            aliases: ["Ab Roller", "Wheel Rollout"],
            movementPattern: .plank,
            cues: ["Start on knees", "Roll out extending hips and shoulders", "Pull back using abs"],
            commonMistakes: ["Lower back sagging", "Not going far enough", "Bending at hips on return"],
            variations: ["Standing Rollout", "Barbell Rollout"]
        ),
        ExerciseMetadata(
            name: "Russian Twist", muscleGroup: .core, category: .core, equipment: .bodyweight,
            difficulty: .beginner,
            primaryMuscles: ["Obliques"],
            secondaryMuscles: ["Rectus Abdominis", "Hip Flexors"],
            aliases: ["Seated Twist", "Russian Twists"],
            movementPattern: .rotation,
            cues: ["Lean back 45 degrees", "Rotate torso side to side", "Feet off ground for harder"],
            commonMistakes: ["Moving arms not torso", "Going too fast", "Rounding back"],
            variations: ["Weighted", "Medicine Ball", "Feet Elevated"]
        ),
        ExerciseMetadata(
            name: "Pallof Press", muscleGroup: .core, category: .core, equipment: .cable,
            difficulty: .intermediate,
            primaryMuscles: ["Obliques", "Transverse Abdominis"],
            secondaryMuscles: ["Rectus Abdominis", "Glutes"],
            aliases: ["Anti-Rotation Press", "Cable Pallof"],
            movementPattern: .rotation,
            cues: ["Stand sideways to cable", "Press handles straight ahead", "Resist rotation"],
            commonMistakes: ["Allowing rotation", "Pressing too fast", "Standing too close"],
            variations: ["Half-Kneeling", "Split Stance", "Band"]
        ),
        ExerciseMetadata(
            name: "Dead Bug", muscleGroup: .core, category: .core, equipment: .bodyweight,
            difficulty: .beginner,
            primaryMuscles: ["Transverse Abdominis", "Rectus Abdominis"],
            secondaryMuscles: ["Hip Flexors", "Obliques"],
            aliases: ["Dead Bugs"],
            movementPattern: .plank,
            cues: ["Lie on back, arms up", "Extend opposite arm and leg", "Keep lower back pressed to floor"],
            commonMistakes: ["Back arching off floor", "Moving too fast", "Not bracing core"],
            variations: ["Weighted", "Band", "Ball Between Knees"]
        ),
        ExerciseMetadata(
            name: "Bicycle Crunches", muscleGroup: .core, category: .core, equipment: .bodyweight,
            difficulty: .beginner,
            primaryMuscles: ["Obliques", "Rectus Abdominis"],
            secondaryMuscles: ["Hip Flexors"],
            aliases: ["Bicycle Crunch", "Criss-Cross"],
            movementPattern: .rotation,
            cues: ["Hands behind head", "Elbow to opposite knee", "Fully extend opposite leg"],
            commonMistakes: ["Pulling on neck", "Moving too fast", "Not fully extending leg"],
            variations: ["Slow Tempo", "Weighted"]
        ),
        ExerciseMetadata(
            name: "Woodchoppers", muscleGroup: .core, category: .core, equipment: .cable,
            difficulty: .intermediate,
            primaryMuscles: ["Obliques"],
            secondaryMuscles: ["Rectus Abdominis", "Shoulders"],
            aliases: ["Cable Woodchop", "Wood Chop"],
            movementPattern: .rotation,
            cues: ["Rotate from hips and core", "Arms stay relatively straight", "High to low or low to high"],
            commonMistakes: ["Using arms instead of core", "Not rotating hips", "Going too heavy"],
            variations: ["High to Low", "Low to High", "Medicine Ball"]
        ),
        ExerciseMetadata(
            name: "Dragon Flag", muscleGroup: .core, category: .core, equipment: .bodyweight,
            difficulty: .advanced,
            primaryMuscles: ["Rectus Abdominis", "Transverse Abdominis"],
            secondaryMuscles: ["Obliques", "Hip Flexors", "Lats"],
            aliases: ["Bruce Lee Flag"],
            movementPattern: .plank,
            cues: ["Grip bench behind head", "Lower body as one rigid unit", "Don't bend at hips"],
            commonMistakes: ["Bending at hips", "Not enough control", "Going too low too soon"],
            variations: ["Tucked", "Single Leg", "Full"]
        ),
        ExerciseMetadata(
            name: "L-Sit", muscleGroup: .core, category: .calisthenics, equipment: .bodyweight,
            difficulty: .advanced,
            primaryMuscles: ["Hip Flexors", "Rectus Abdominis"],
            secondaryMuscles: ["Quads", "Triceps", "Obliques"],
            aliases: ["L Sit Hold", "Parallel Bar L-Sit"],
            movementPattern: .plank,
            cues: ["Press down through hands", "Legs straight and parallel to floor", "Point toes"],
            commonMistakes: ["Bending knees", "Rounding back", "Not pressing down enough"],
            variations: ["Tucked L-Sit", "Ring L-Sit", "Floor L-Sit"]
        ),

        // ═══════════════════════════════════════
        // CARDIO (15)
        // ═══════════════════════════════════════

        ExerciseMetadata(
            name: "Treadmill Run", muscleGroup: .cardio, category: .cardio, equipment: .treadmill,
            difficulty: .beginner,
            primaryMuscles: ["Quads", "Hamstrings", "Calves"],
            secondaryMuscles: ["Glutes", "Core", "Hip Flexors"],
            aliases: ["Treadmill", "Indoor Run"],
            movementPattern: .sprint,
            cues: ["Upright posture", "Land midfoot", "Arms at 90 degrees"],
            commonMistakes: ["Holding handrails", "Overstriding", "Looking down"],
            variations: ["Incline Walk", "Interval Sprints", "Steady State"]
        ),
        ExerciseMetadata(
            name: "Outdoor Run", muscleGroup: .cardio, category: .cardio, equipment: .bodyweight,
            difficulty: .beginner,
            primaryMuscles: ["Quads", "Hamstrings", "Calves"],
            secondaryMuscles: ["Glutes", "Core"],
            aliases: ["Running", "Jogging", "Road Run"],
            movementPattern: .sprint,
            cues: ["Relaxed shoulders", "Midfoot strike", "Consistent cadence"],
            commonMistakes: ["Starting too fast", "Heel striking", "Tensing upper body"],
            variations: ["Tempo Run", "Fartlek", "Long Run"]
        ),
        ExerciseMetadata(
            name: "Cycling", muscleGroup: .cardio, category: .cardio, equipment: .bike,
            difficulty: .beginner,
            primaryMuscles: ["Quads", "Hamstrings", "Glutes"],
            secondaryMuscles: ["Calves", "Core"],
            aliases: ["Outdoor Cycling", "Road Cycling", "Biking"],
            movementPattern: .cycle,
            cues: ["Smooth pedal stroke", "Maintain cadence 80-100 RPM", "Relax grip"],
            commonMistakes: ["Seat too low", "Mashing gears", "Gripping too tight"],
            variations: ["Hill Climbs", "Intervals", "Endurance"]
        ),
        ExerciseMetadata(
            name: "Indoor Cycling", muscleGroup: .cardio, category: .cardio, equipment: .bike,
            difficulty: .beginner,
            primaryMuscles: ["Quads", "Hamstrings"],
            secondaryMuscles: ["Calves", "Glutes", "Core"],
            aliases: ["Spin Class", "Stationary Bike", "Spin Bike"],
            movementPattern: .cycle,
            cues: ["Adjust seat height properly", "Smooth pedal stroke", "Maintain cadence"],
            commonMistakes: ["Bouncing in saddle", "Resistance too low", "Poor seat position"],
            variations: ["HIIT Intervals", "Steady State", "Tabata"]
        ),
        ExerciseMetadata(
            name: "Rowing Machine", muscleGroup: .cardio, category: .cardio, equipment: .rower,
            difficulty: .intermediate,
            primaryMuscles: ["Lats", "Quads", "Hamstrings"],
            secondaryMuscles: ["Core", "Biceps", "Shoulders"],
            aliases: ["Erg", "Indoor Rowing", "Rower"],
            movementPattern: .row,
            cues: ["Legs-back-arms sequence", "Drive through heels", "Lean back slightly at finish"],
            commonMistakes: ["Arms before legs", "Rushing the recovery", "Rounding back"],
            variations: ["Steady State", "Intervals", "Sprint Pieces"]
        ),
        ExerciseMetadata(
            name: "Swimming", muscleGroup: .cardio, category: .cardio, equipment: .swimGear,
            difficulty: .intermediate,
            primaryMuscles: ["Lats", "Shoulders", "Core"],
            secondaryMuscles: ["Triceps", "Chest", "Legs"],
            aliases: ["Pool Swimming", "Laps", "Swim Workout"],
            movementPattern: .swim,
            cues: ["Streamline body position", "Bilateral breathing", "Long strokes"],
            commonMistakes: ["Head too high", "Crossing over center", "Kicking too much"],
            variations: ["Freestyle", "Backstroke", "Breaststroke", "IM"]
        ),
        ExerciseMetadata(
            name: "Hiking", muscleGroup: .cardio, category: .cardio, equipment: .bodyweight,
            difficulty: .beginner,
            primaryMuscles: ["Quads", "Glutes", "Calves"],
            secondaryMuscles: ["Hamstrings", "Core"],
            aliases: ["Trail Hiking", "Hill Walk"],
            movementPattern: .sprint,
            cues: ["Steady pace uphill", "Trekking poles for balance", "Stay hydrated"],
            commonMistakes: ["Starting too fast", "Poor footwear", "Not enough water"],
            variations: ["Day Hike", "Weighted Pack", "Incline Treadmill"]
        ),
        ExerciseMetadata(
            name: "Jump Rope", muscleGroup: .cardio, category: .cardio, equipment: .jumpRope,
            difficulty: .beginner,
            primaryMuscles: ["Calves", "Quads"],
            secondaryMuscles: ["Shoulders", "Forearms", "Core"],
            aliases: ["Skipping", "Rope Jumping"],
            movementPattern: .jump,
            cues: ["Jump 1-2 inches off ground", "Wrists drive the rope", "Stay on balls of feet"],
            commonMistakes: ["Jumping too high", "Using arms too much", "Landing flat-footed"],
            variations: ["Double Unders", "Crossovers", "High Knees"]
        ),
        ExerciseMetadata(
            name: "Stair Climber", muscleGroup: .cardio, category: .cardio, equipment: .machine,
            difficulty: .beginner,
            primaryMuscles: ["Quads", "Glutes", "Calves"],
            secondaryMuscles: ["Hamstrings", "Core"],
            aliases: ["StairMaster", "Step Mill", "Stair Stepper"],
            movementPattern: .sprint,
            cues: ["Upright posture", "Full steps", "Don't lean on handrails"],
            commonMistakes: ["Leaning on rails", "Taking tiny steps", "Hunching over"],
            variations: ["Steady State", "Intervals", "Double Steps"]
        ),
        ExerciseMetadata(
            name: "Elliptical", muscleGroup: .cardio, category: .cardio, equipment: .machine,
            difficulty: .beginner,
            primaryMuscles: ["Quads", "Glutes"],
            secondaryMuscles: ["Hamstrings", "Core", "Arms"],
            aliases: ["Elliptical Trainer", "Cross Trainer"],
            movementPattern: .cycle,
            cues: ["Upright posture", "Push and pull handles", "Maintain resistance"],
            commonMistakes: ["Zero resistance", "Hunching over", "Not using handles"],
            variations: ["Reverse Stride", "High Incline", "Intervals"]
        ),
        ExerciseMetadata(
            name: "Walking", muscleGroup: .cardio, category: .cardio, equipment: .bodyweight,
            difficulty: .beginner,
            primaryMuscles: ["Quads", "Calves"],
            secondaryMuscles: ["Glutes", "Hamstrings", "Core"],
            aliases: ["Brisk Walk", "LISS Walking", "Incline Walk"],
            movementPattern: .sprint,
            cues: ["Brisk pace", "Swing arms naturally", "Heel-to-toe roll"],
            commonMistakes: ["Too slow pace", "Looking at phone", "Slouching"],
            variations: ["Incline Treadmill", "Weighted Walk", "Ruck"]
        ),
        ExerciseMetadata(
            name: "Sprints", muscleGroup: .cardio, category: .cardio, equipment: .bodyweight,
            difficulty: .intermediate,
            primaryMuscles: ["Quads", "Hamstrings", "Glutes"],
            secondaryMuscles: ["Calves", "Core", "Hip Flexors"],
            aliases: ["Sprint Intervals", "Track Sprints"],
            movementPattern: .sprint,
            cues: ["Drive knees high", "Pump arms hard", "Stay on balls of feet"],
            commonMistakes: ["Not warming up", "Overstriding", "Tensing shoulders"],
            variations: ["Hill Sprints", "Sled Sprints", "Shuttle Runs"]
        ),
        ExerciseMetadata(
            name: "Battle Ropes", muscleGroup: .cardio, category: .hiit, equipment: .other,
            difficulty: .intermediate,
            primaryMuscles: ["Shoulders", "Core"],
            secondaryMuscles: ["Arms", "Legs", "Back"],
            aliases: ["Battling Ropes", "Wave Ropes"],
            movementPattern: .push,
            cues: ["Athletic stance", "Alternate or simultaneous waves", "Keep core braced"],
            commonMistakes: ["Standing too upright", "Arms only no body", "Losing rhythm"],
            variations: ["Alternating Waves", "Slams", "Circles"]
        ),
        ExerciseMetadata(
            name: "Assault Bike", muscleGroup: .cardio, category: .hiit, equipment: .bike,
            difficulty: .intermediate,
            primaryMuscles: ["Quads", "Shoulders"],
            secondaryMuscles: ["Core", "Hamstrings", "Arms"],
            aliases: ["Air Bike", "Fan Bike", "Airdyne"],
            movementPattern: .cycle,
            cues: ["Push and pull handles simultaneously", "Maintain high RPM", "Keep core tight"],
            commonMistakes: ["Only using legs", "Pacing too conservatively", "Hunching over"],
            variations: ["Tabata", "Steady State", "Sprint Intervals"]
        ),
        ExerciseMetadata(
            name: "Sled Push", muscleGroup: .cardio, category: .hiit, equipment: .other,
            difficulty: .intermediate,
            primaryMuscles: ["Quads", "Glutes"],
            secondaryMuscles: ["Calves", "Core", "Shoulders"],
            aliases: ["Prowler Push", "Sled Drive"],
            movementPattern: .sprint,
            cues: ["Low handle position", "Drive through legs", "Keep body at 45 degrees"],
            commonMistakes: ["Standing too upright", "Short choppy steps", "Not driving through toes"],
            variations: ["Heavy Slow", "Light Fast", "High Handle"]
        ),

        // ═══════════════════════════════════════
        // HIIT / CROSSFIT (12)
        // ═══════════════════════════════════════

        ExerciseMetadata(
            name: "Burpees", muscleGroup: .fullBody, category: .hiit, equipment: .bodyweight,
            difficulty: .intermediate,
            primaryMuscles: ["Quads", "Chest", "Shoulders"],
            secondaryMuscles: ["Core", "Triceps", "Hamstrings"],
            aliases: ["Burpee"],
            movementPattern: .jump,
            cues: ["Squat down, hands to floor", "Jump feet back to plank", "Push-up then jump up"],
            commonMistakes: ["Skipping the push-up", "Not full extension on jump", "Landing stiff-legged"],
            variations: ["Box Jump Burpee", "No Push-up", "Tuck Jump Burpee"]
        ),
        ExerciseMetadata(
            name: "Box Jumps", muscleGroup: .fullBody, category: .plyometric, equipment: .box,
            difficulty: .intermediate,
            primaryMuscles: ["Quads", "Glutes", "Calves"],
            secondaryMuscles: ["Hamstrings", "Core"],
            aliases: ["Box Jump", "Plyo Box Jump"],
            movementPattern: .jump,
            cues: ["Swing arms for momentum", "Land softly with bent knees", "Stand fully at top"],
            commonMistakes: ["Landing too hard", "Not standing up fully", "Box too high for ability"],
            variations: ["Step Down", "Seated Box Jump", "Depth Jump"]
        ),
        ExerciseMetadata(
            name: "Kettlebell Swings", muscleGroup: .fullBody, category: .hiit, equipment: .kettlebell,
            difficulty: .intermediate,
            primaryMuscles: ["Glutes", "Hamstrings"],
            secondaryMuscles: ["Core", "Shoulders", "Lats"],
            aliases: ["KB Swing", "Russian Swing", "American Swing"],
            movementPattern: .hinge,
            cues: ["Hinge at hips not squat", "Snap hips forward", "Arms are just along for the ride"],
            commonMistakes: ["Squatting instead of hinging", "Using arms to lift", "Rounding back"],
            variations: ["Single Arm", "American", "Alternating"]
        ),
        ExerciseMetadata(
            name: "Thrusters", muscleGroup: .fullBody, category: .hiit, equipment: .barbell,
            difficulty: .intermediate,
            primaryMuscles: ["Quads", "Shoulders", "Glutes"],
            secondaryMuscles: ["Core", "Triceps"],
            aliases: ["Barbell Thruster", "Squat to Press"],
            movementPattern: .squat,
            cues: ["Front squat position", "Drive up from squat into overhead press", "One fluid motion"],
            commonMistakes: ["Pressing before standing", "Not reaching full depth", "Bar drifting forward"],
            variations: ["Dumbbell", "Kettlebell", "Single Arm"]
        ),
        ExerciseMetadata(
            name: "Wall Balls", muscleGroup: .fullBody, category: .hiit, equipment: .medicineBall,
            difficulty: .intermediate,
            primaryMuscles: ["Quads", "Shoulders", "Glutes"],
            secondaryMuscles: ["Core", "Triceps"],
            aliases: ["Wall Ball Shots", "Wall Ball"],
            movementPattern: .squat,
            cues: ["Squat with ball at chest", "Throw to target on wall", "Catch and go directly into next squat"],
            commonMistakes: ["Not squatting deep enough", "Not hitting target", "Pausing at bottom"],
            variations: ["Heavy Ball", "Low Target", "Single Arm"]
        ),
        ExerciseMetadata(
            name: "Clean and Jerk", muscleGroup: .fullBody, category: .olympic, equipment: .barbell,
            difficulty: .advanced,
            primaryMuscles: ["Quads", "Glutes", "Shoulders", "Traps"],
            secondaryMuscles: ["Core", "Hamstrings", "Triceps"],
            aliases: ["C&J", "Clean & Jerk"],
            movementPattern: .pull,
            cues: ["First pull: slow off floor", "Second pull: explosive hip extension", "Catch in front rack, then jerk overhead"],
            commonMistakes: ["Pulling with arms", "Not fully extending hips", "Poor catch position"],
            variations: ["Power Clean + Push Jerk", "Hang Clean & Jerk"]
        ),
        ExerciseMetadata(
            name: "Power Clean", muscleGroup: .fullBody, category: .olympic, equipment: .barbell,
            difficulty: .advanced,
            primaryMuscles: ["Quads", "Glutes", "Traps"],
            secondaryMuscles: ["Hamstrings", "Core", "Shoulders"],
            aliases: ["Clean", "Barbell Clean"],
            movementPattern: .pull,
            cues: ["Bar close to body", "Explosive hip extension", "Catch in quarter squat front rack"],
            commonMistakes: ["Early arm pull", "Bar swinging away", "Not catching properly"],
            variations: ["Hang Power Clean", "Muscle Clean"]
        ),
        ExerciseMetadata(
            name: "Snatch", muscleGroup: .fullBody, category: .olympic, equipment: .barbell,
            difficulty: .advanced,
            primaryMuscles: ["Quads", "Glutes", "Shoulders", "Traps"],
            secondaryMuscles: ["Core", "Hamstrings", "Upper Back"],
            aliases: ["Barbell Snatch", "Full Snatch"],
            movementPattern: .pull,
            cues: ["Wide grip", "Explosive hip extension", "Pull under bar, catch overhead in squat"],
            commonMistakes: ["Bar too far from body", "Not getting under the bar", "Soft lockout overhead"],
            variations: ["Power Snatch", "Hang Snatch", "Muscle Snatch"]
        ),
        ExerciseMetadata(
            name: "Man Makers", muscleGroup: .fullBody, category: .hiit, equipment: .dumbbell,
            difficulty: .advanced,
            primaryMuscles: ["Chest", "Back", "Shoulders", "Quads"],
            secondaryMuscles: ["Core", "Triceps", "Biceps"],
            aliases: ["Man Maker", "Dumbbell Man Maker"],
            movementPattern: .push,
            cues: ["Plank on dumbbells", "Push-up, row each side, squat clean, press overhead"],
            commonMistakes: ["Sloppy form when tired", "Skipping movements", "Going too heavy"],
            variations: ["No Row", "Lighter Weight"]
        ),
        ExerciseMetadata(
            name: "Turkish Get-Up", muscleGroup: .fullBody, category: .compound, equipment: .kettlebell,
            difficulty: .advanced,
            primaryMuscles: ["Shoulders", "Core", "Glutes"],
            secondaryMuscles: ["Quads", "Hamstrings", "Triceps"],
            aliases: ["TGU", "Get-Up"],
            movementPattern: .flow,
            cues: ["Keep arm locked out overhead", "Move through each position deliberately", "Eye on the weight"],
            commonMistakes: ["Rushing transitions", "Bending elbow", "Not stabilizing at each position"],
            variations: ["Half Get-Up", "Dumbbell", "Barbell"]
        ),
        ExerciseMetadata(
            name: "Farmer's Walk", muscleGroup: .fullBody, category: .compound, equipment: .dumbbell,
            difficulty: .beginner,
            primaryMuscles: ["Forearms", "Traps", "Core"],
            secondaryMuscles: ["Shoulders", "Glutes", "Quads"],
            aliases: ["Farmer Walk", "Farmer Carry", "Loaded Carry"],
            movementPattern: .carry,
            cues: ["Shoulders back and down", "Tight core", "Walk with purpose, even strides"],
            commonMistakes: ["Leaning to one side", "Shrugging shoulders", "Taking too small steps"],
            variations: ["Single Arm", "Trap Bar", "Kettlebell"]
        ),
        ExerciseMetadata(
            name: "HIIT Sled Push", muscleGroup: .fullBody, category: .hiit, equipment: .other,
            difficulty: .intermediate,
            primaryMuscles: ["Quads", "Glutes", "Calves"],
            secondaryMuscles: ["Core", "Shoulders"],
            aliases: ["Prowler Sprint", "Speed Sled"],
            movementPattern: .sprint,
            cues: ["Light weight, fast pace", "Drive through toes", "Stay low"],
            commonMistakes: ["Too upright", "Overloading weight", "Not driving knees"],
            variations: ["Backward Drag", "Lateral Push"]
        ),

        // ═══════════════════════════════════════
        // CALISTHENICS (10)
        // ═══════════════════════════════════════

        ExerciseMetadata(
            name: "Muscle-ups", muscleGroup: .back, category: .calisthenics, equipment: .bodyweight,
            difficulty: .advanced,
            primaryMuscles: ["Lats", "Chest", "Triceps"],
            secondaryMuscles: ["Biceps", "Core", "Shoulders"],
            aliases: ["Bar Muscle Up", "Muscle Up"],
            movementPattern: .pull,
            cues: ["Explosive pull above bar", "Transition: lean forward over bar", "Press out to lockout"],
            commonMistakes: ["Not enough explosiveness", "Chicken winging", "No false grip on rings"],
            variations: ["Ring Muscle-Up", "Strict", "Kipping"]
        ),
        ExerciseMetadata(
            name: "Handstand Push-ups", muscleGroup: .shoulders, category: .calisthenics, equipment: .bodyweight,
            difficulty: .advanced,
            primaryMuscles: ["Shoulders", "Triceps"],
            secondaryMuscles: ["Core", "Upper Traps"],
            aliases: ["HSPU", "Wall Handstand Push-Up"],
            movementPattern: .press,
            cues: ["Kick up to handstand against wall", "Lower head to floor", "Press back to lockout"],
            commonMistakes: ["Not full range of motion", "Arching back", "Kicking too hard"],
            variations: ["Pike Push-up", "Deficit HSPU", "Freestanding"]
        ),
        ExerciseMetadata(
            name: "Pistol Squats", muscleGroup: .quads, category: .calisthenics, equipment: .bodyweight,
            difficulty: .advanced,
            primaryMuscles: ["Quads", "Glutes"],
            secondaryMuscles: ["Hamstrings", "Core", "Hip Flexors"],
            aliases: ["Single Leg Squat", "Pistol Squat"],
            movementPattern: .squat,
            cues: ["One leg extended forward", "Sit back and down", "Drive through heel to stand"],
            commonMistakes: ["Knee caving", "Losing balance", "Not enough depth"],
            variations: ["Assisted", "Box Pistol", "Weighted"]
        ),
        ExerciseMetadata(
            name: "Calisthenics L-Sit", muscleGroup: .core, category: .calisthenics, equipment: .bodyweight,
            difficulty: .advanced,
            primaryMuscles: ["Hip Flexors", "Rectus Abdominis"],
            secondaryMuscles: ["Quads", "Triceps"],
            aliases: ["Parallette L-Sit"],
            movementPattern: .plank,
            cues: ["Depress shoulders", "Legs straight at 90 degrees", "Point toes"],
            commonMistakes: ["Bending knees", "Shoulders shrugging up", "Not pressing down enough"],
            variations: ["Tucked", "One Leg Extended", "Ring L-Sit"]
        ),
        ExerciseMetadata(
            name: "Human Flag", muscleGroup: .core, category: .calisthenics, equipment: .bodyweight,
            difficulty: .advanced,
            primaryMuscles: ["Obliques", "Lats", "Shoulders"],
            secondaryMuscles: ["Core", "Forearms"],
            aliases: ["Side Flag", "Pole Flag"],
            movementPattern: .plank,
            cues: ["Top arm pushes, bottom arm pulls", "Engage entire core", "Start with tucked knees"],
            commonMistakes: ["Not enough upper body strength", "Hips sagging", "Gripping wrong"],
            variations: ["Tucked", "Straddle", "Full"]
        ),
        ExerciseMetadata(
            name: "Front Lever", muscleGroup: .back, category: .calisthenics, equipment: .bodyweight,
            difficulty: .advanced,
            primaryMuscles: ["Lats", "Core"],
            secondaryMuscles: ["Shoulders", "Biceps"],
            aliases: ["Bar Front Lever"],
            movementPattern: .pull,
            cues: ["Hang from bar", "Raise body to horizontal", "Maintain straight body line"],
            commonMistakes: ["Hips dropping", "Bending at waist", "Not enough lat engagement"],
            variations: ["Tucked", "Advanced Tuck", "One Leg"]
        ),
        ExerciseMetadata(
            name: "Back Lever", muscleGroup: .back, category: .calisthenics, equipment: .bodyweight,
            difficulty: .advanced,
            primaryMuscles: ["Lats", "Shoulders", "Biceps"],
            secondaryMuscles: ["Core", "Chest"],
            aliases: ["Ring Back Lever"],
            movementPattern: .pull,
            cues: ["Rotate backward from inverted hang", "Extend to horizontal behind bar", "Keep body straight"],
            commonMistakes: ["Bending at hips", "Excessive shoulder strain", "Progressing too fast"],
            variations: ["Tucked", "Straddle", "Full"]
        ),
        ExerciseMetadata(
            name: "Planche", muscleGroup: .shoulders, category: .calisthenics, equipment: .bodyweight,
            difficulty: .advanced,
            primaryMuscles: ["Shoulders", "Chest", "Core"],
            secondaryMuscles: ["Triceps", "Forearms", "Wrists"],
            aliases: ["Full Planche", "Planche Hold"],
            movementPattern: .push,
            cues: ["Lean forward on hands", "Protract shoulders", "Body parallel to ground"],
            commonMistakes: ["Not enough forward lean", "Bending at hips", "Insufficient wrist prep"],
            variations: ["Tuck Planche", "Advanced Tuck", "Straddle"]
        ),
        ExerciseMetadata(
            name: "Ring Dips", muscleGroup: .triceps, category: .calisthenics, equipment: .bodyweight,
            difficulty: .advanced,
            primaryMuscles: ["Triceps", "Chest"],
            secondaryMuscles: ["Shoulders", "Core"],
            aliases: ["Gymnastic Ring Dips"],
            movementPattern: .push,
            cues: ["Rings turned out at top", "Lower with control", "Press to full lockout"],
            commonMistakes: ["Rings wobbling", "Going too deep", "Not turning rings out"],
            variations: ["Strict", "Kipping", "Weighted"]
        ),
        ExerciseMetadata(
            name: "Toes to Bar", muscleGroup: .core, category: .calisthenics, equipment: .bodyweight,
            difficulty: .intermediate,
            primaryMuscles: ["Core", "Hip Flexors"],
            secondaryMuscles: ["Lats", "Forearms"],
            aliases: ["T2B", "Toes-to-Bar"],
            movementPattern: .plank,
            cues: ["Hang from bar", "Kip or strict raise toes to bar", "Control the descent"],
            commonMistakes: ["All kip no core", "Not reaching the bar", "Losing grip"],
            variations: ["Knees to Elbows", "Strict", "Kipping"]
        ),

        // ═══════════════════════════════════════
        // YOGA / MOBILITY (12)
        // ═══════════════════════════════════════

        ExerciseMetadata(
            name: "Sun Salutation", muscleGroup: .flexibility, category: .yoga, equipment: .bodyweight,
            difficulty: .beginner,
            primaryMuscles: ["Full Body", "Shoulders", "Hamstrings"],
            secondaryMuscles: ["Core", "Chest", "Quads"],
            aliases: ["Surya Namaskar", "Sun Sal"],
            movementPattern: .flow,
            cues: ["Flow through each pose with breath", "Inhale on extension, exhale on flexion", "Maintain steady rhythm"],
            commonMistakes: ["Rushing through poses", "Holding breath", "Skipping transitions"],
            variations: ["Sun Sal A", "Sun Sal B", "Modified"]
        ),
        ExerciseMetadata(
            name: "Warrior I", muscleGroup: .flexibility, category: .yoga, equipment: .bodyweight,
            difficulty: .beginner,
            primaryMuscles: ["Quads", "Hip Flexors", "Shoulders"],
            secondaryMuscles: ["Core", "Calves", "Glutes"],
            aliases: ["Virabhadrasana I"],
            movementPattern: .flow,
            cues: ["Front knee over ankle", "Back foot at 45 degrees", "Arms reach overhead"],
            commonMistakes: ["Knee past toes", "Hips not squared", "Compressing lower back"],
            variations: ["High Lunge", "Humble Warrior"]
        ),
        ExerciseMetadata(
            name: "Warrior II", muscleGroup: .flexibility, category: .yoga, equipment: .bodyweight,
            difficulty: .beginner,
            primaryMuscles: ["Quads", "Hip Abductors", "Shoulders"],
            secondaryMuscles: ["Core", "Glutes"],
            aliases: ["Virabhadrasana II"],
            movementPattern: .flow,
            cues: ["Front knee over ankle", "Hips open to side", "Arms extended, gaze over front hand"],
            commonMistakes: ["Front knee caving in", "Leaning forward", "Shoulders tense"],
            variations: ["Reverse Warrior", "Extended Side Angle"]
        ),
        ExerciseMetadata(
            name: "Downward Dog", muscleGroup: .flexibility, category: .yoga, equipment: .bodyweight,
            difficulty: .beginner,
            primaryMuscles: ["Hamstrings", "Calves", "Shoulders"],
            secondaryMuscles: ["Core", "Lats", "Forearms"],
            aliases: ["Down Dog", "Adho Mukha Svanasana"],
            movementPattern: .flow,
            cues: ["Hands shoulder-width, feet hip-width", "Push hips up and back", "Press heels toward floor"],
            commonMistakes: ["Rounding back", "Locking knees", "Weight too far forward"],
            variations: ["Three-Legged Dog", "Puppy Pose"]
        ),
        ExerciseMetadata(
            name: "Foam Rolling", muscleGroup: .flexibility, category: .mobility, equipment: .foamRoller,
            difficulty: .beginner,
            primaryMuscles: ["Full Body"],
            secondaryMuscles: ["Fascia", "Muscle Tissue"],
            aliases: ["SMR", "Self-Myofascial Release", "Foam Roll"],
            movementPattern: .mobilityStretch,
            cues: ["Roll slowly over muscle", "Pause on tender spots", "Breathe through discomfort"],
            commonMistakes: ["Rolling too fast", "Rolling directly on joints", "Holding breath"],
            variations: ["Lacrosse Ball", "Massage Gun"]
        ),
        ExerciseMetadata(
            name: "Pigeon Pose", muscleGroup: .flexibility, category: .yoga, equipment: .bodyweight,
            difficulty: .intermediate,
            primaryMuscles: ["Hip Flexors", "Glutes", "Piriformis"],
            secondaryMuscles: ["Hamstrings", "Lower Back"],
            aliases: ["Eka Pada Rajakapotasana", "Sleeping Pigeon"],
            movementPattern: .flow,
            cues: ["Front shin parallel to mat", "Square hips to front", "Fold forward gently"],
            commonMistakes: ["Hips not level", "Forcing too deep", "Knee pain"],
            variations: ["Figure-4 Stretch", "King Pigeon"]
        ),
        ExerciseMetadata(
            name: "Cat-Cow Stretch", muscleGroup: .flexibility, category: .mobility, equipment: .bodyweight,
            difficulty: .beginner,
            primaryMuscles: ["Spine", "Core"],
            secondaryMuscles: ["Shoulders", "Hips"],
            aliases: ["Cat-Cow", "Spinal Wave"],
            movementPattern: .mobilityStretch,
            cues: ["Hands under shoulders, knees under hips", "Inhale: arch back (cow)", "Exhale: round spine (cat)"],
            commonMistakes: ["Moving too fast", "Not syncing with breath", "Limited range"],
            variations: ["Seated Cat-Cow", "Standing Cat-Cow"]
        ),
        ExerciseMetadata(
            name: "Hip Opener Flow", muscleGroup: .flexibility, category: .mobility, equipment: .bodyweight,
            difficulty: .intermediate,
            primaryMuscles: ["Hip Flexors", "Adductors", "Glutes"],
            secondaryMuscles: ["Hamstrings", "Core"],
            aliases: ["Hip Flow", "Hip Mobility Routine"],
            movementPattern: .flow,
            cues: ["Move between hip stretches fluidly", "Hold each position 3-5 breaths", "Focus on tight areas"],
            commonMistakes: ["Bouncing in stretches", "Ignoring tight side", "Going too deep too fast"],
            variations: ["90/90 Flow", "Couch Stretch Flow"]
        ),
        ExerciseMetadata(
            name: "Shoulder Mobility", muscleGroup: .flexibility, category: .mobility, equipment: .band,
            difficulty: .beginner,
            primaryMuscles: ["Shoulders", "Rotator Cuff"],
            secondaryMuscles: ["Upper Back", "Chest"],
            aliases: ["Shoulder Dislocates", "Band Pull-Aparts"],
            movementPattern: .mobilityStretch,
            cues: ["Wide grip on band", "Bring arms overhead and behind", "Slow and controlled"],
            commonMistakes: ["Grip too narrow", "Rushing movement", "Shrugging shoulders"],
            variations: ["PVC Pipe Dislocates", "Wall Slides"]
        ),
        ExerciseMetadata(
            name: "Thoracic Spine Mobility", muscleGroup: .flexibility, category: .mobility, equipment: .foamRoller,
            difficulty: .beginner,
            primaryMuscles: ["Thoracic Spine", "Upper Back"],
            secondaryMuscles: ["Core", "Shoulders"],
            aliases: ["T-Spine Mobility", "Thoracic Extension"],
            movementPattern: .mobilityStretch,
            cues: ["Foam roller under upper back", "Arms crossed or behind head", "Extend over roller"],
            commonMistakes: ["Rolling lower back", "Going too fast", "Not extending far enough"],
            variations: ["Seated Rotation", "Open Books"]
        ),
        ExerciseMetadata(
            name: "Hamstring Stretch", muscleGroup: .flexibility, category: .mobility, equipment: .bodyweight,
            difficulty: .beginner,
            primaryMuscles: ["Hamstrings"],
            secondaryMuscles: ["Calves", "Lower Back"],
            aliases: ["Standing Hamstring Stretch", "Seated Forward Fold"],
            movementPattern: .mobilityStretch,
            cues: ["Hinge at hips, not waist", "Keep back flat", "Reach toward toes"],
            commonMistakes: ["Rounding back", "Bouncing", "Locking knees aggressively"],
            variations: ["Standing", "Seated", "Supine with Strap"]
        ),
        ExerciseMetadata(
            name: "Quad Stretch", muscleGroup: .flexibility, category: .mobility, equipment: .bodyweight,
            difficulty: .beginner,
            primaryMuscles: ["Quads", "Hip Flexors"],
            secondaryMuscles: ["Knees"],
            aliases: ["Standing Quad Stretch", "Couch Stretch"],
            movementPattern: .mobilityStretch,
            cues: ["Pull heel to glute", "Keep knees together", "Squeeze glute on stretching side"],
            commonMistakes: ["Arching lower back", "Knee pulling outward", "Not squeezing glute"],
            variations: ["Lying", "Couch Stretch", "Half-Kneeling"]
        ),

        // ═══════════════════════════════════════
        // MARTIAL ARTS (8)
        // ═══════════════════════════════════════

        ExerciseMetadata(
            name: "Heavy Bag Work", muscleGroup: .fullBody, category: .martialArts, equipment: .heavyBag,
            difficulty: .intermediate,
            primaryMuscles: ["Shoulders", "Core", "Chest"],
            secondaryMuscles: ["Arms", "Legs", "Back"],
            aliases: ["Bag Work", "Heavy Bag", "Punching Bag"],
            movementPattern: .strike,
            cues: ["Rotate hips into punches", "Keep hands up", "Breathe with each strike"],
            commonMistakes: ["Dropping hands", "Not rotating hips", "Punching with arms only"],
            variations: ["3-Minute Rounds", "Power Shots", "Speed Rounds"]
        ),
        ExerciseMetadata(
            name: "Shadow Boxing", muscleGroup: .fullBody, category: .martialArts, equipment: .bodyweight,
            difficulty: .beginner,
            primaryMuscles: ["Shoulders", "Core"],
            secondaryMuscles: ["Legs", "Arms", "Back"],
            aliases: ["Shadow Box", "Boxing Drill"],
            movementPattern: .strike,
            cues: ["Visualize an opponent", "Move feet constantly", "Throw combinations"],
            commonMistakes: ["Flat-footed", "No head movement", "Dropping guard"],
            variations: ["With Weights", "Mirror Work", "Timed Rounds"]
        ),
        ExerciseMetadata(
            name: "Kick Combos", muscleGroup: .fullBody, category: .martialArts, equipment: .bodyweight,
            difficulty: .intermediate,
            primaryMuscles: ["Quads", "Hip Flexors", "Glutes"],
            secondaryMuscles: ["Core", "Hamstrings", "Calves"],
            aliases: ["Kickboxing Combos", "Kick Drills"],
            movementPattern: .kick,
            cues: ["Chamber knee before kicking", "Turn hip over for power", "Rechamber after each kick"],
            commonMistakes: ["Not chambering", "Telegraphing kicks", "Poor balance"],
            variations: ["Roundhouse", "Front Kick", "Side Kick"]
        ),
        ExerciseMetadata(
            name: "Grappling Drills", muscleGroup: .fullBody, category: .martialArts, equipment: .bodyweight,
            difficulty: .intermediate,
            primaryMuscles: ["Core", "Back", "Shoulders"],
            secondaryMuscles: ["Arms", "Legs", "Neck"],
            aliases: ["Wrestling Drills", "BJJ Drills"],
            movementPattern: .flow,
            cues: ["Maintain base and posture", "Control breathing", "Use technique over strength"],
            commonMistakes: ["Relying on strength", "Poor breathing", "Tense muscles"],
            variations: ["Positional Sparring", "Technical Drills", "Flow Rolling"]
        ),
        ExerciseMetadata(
            name: "Speed Bag", muscleGroup: .fullBody, category: .martialArts, equipment: .other,
            difficulty: .intermediate,
            primaryMuscles: ["Shoulders", "Arms"],
            secondaryMuscles: ["Core", "Hand-Eye Coordination"],
            aliases: ["Speed Ball", "Boxing Speed Bag"],
            movementPattern: .strike,
            cues: ["Small circular motions", "Keep elbows up", "Find the rhythm"],
            commonMistakes: ["Hitting too hard", "Dropping elbows", "Losing rhythm"],
            variations: ["Front Circle", "Alternating Hands"]
        ),
        ExerciseMetadata(
            name: "Mitt Work", muscleGroup: .fullBody, category: .martialArts, equipment: .other,
            difficulty: .intermediate,
            primaryMuscles: ["Shoulders", "Core", "Chest"],
            secondaryMuscles: ["Arms", "Legs"],
            aliases: ["Pad Work", "Focus Mitts", "Partner Drills"],
            movementPattern: .strike,
            cues: ["Snap punches back quickly", "Move feet between combos", "Stay on balls of feet"],
            commonMistakes: ["Pushing instead of snapping", "Standing still", "Dropping guard between combos"],
            variations: ["Defense Drills", "Counter Drills", "Power Rounds"]
        ),
        ExerciseMetadata(
            name: "Clinch Work", muscleGroup: .fullBody, category: .martialArts, equipment: .bodyweight,
            difficulty: .advanced,
            primaryMuscles: ["Core", "Neck", "Shoulders"],
            secondaryMuscles: ["Arms", "Back", "Legs"],
            aliases: ["Clinch Training", "Muay Thai Clinch"],
            movementPattern: .flow,
            cues: ["Control head position", "Use frames and underhooks", "Maintain balance"],
            commonMistakes: ["Over-committing", "Poor posture", "Not controlling head"],
            variations: ["Single Collar", "Double Collar", "Body Lock"]
        ),
        ExerciseMetadata(
            name: "Ground and Pound", muscleGroup: .fullBody, category: .martialArts, equipment: .bodyweight,
            difficulty: .intermediate,
            primaryMuscles: ["Shoulders", "Core", "Hips"],
            secondaryMuscles: ["Arms", "Chest"],
            aliases: ["GNP", "Ground Strikes"],
            movementPattern: .strike,
            cues: ["Maintain top position", "Use hips for power", "Create angles"],
            commonMistakes: ["Losing position", "Wild strikes", "Not maintaining base"],
            variations: ["From Guard", "From Mount", "From Side Control"]
        ),

        // ═══════════════════════════════════════
        // SPORT-SPECIFIC (8)
        // ═══════════════════════════════════════

        ExerciseMetadata(
            name: "Agility Ladder", muscleGroup: .fullBody, category: .sport, equipment: .other,
            difficulty: .beginner,
            primaryMuscles: ["Calves", "Quads", "Hip Flexors"],
            secondaryMuscles: ["Core", "Coordination"],
            aliases: ["Speed Ladder", "Ladder Drills"],
            movementPattern: .sprint,
            cues: ["Stay on balls of feet", "Quick light steps", "Arms drive movement"],
            commonMistakes: ["Looking down", "Flat feet", "Moving too slowly"],
            variations: ["In-Out", "Lateral", "Ickey Shuffle", "Crossover"]
        ),
        ExerciseMetadata(
            name: "Cone Drills", muscleGroup: .fullBody, category: .sport, equipment: .other,
            difficulty: .beginner,
            primaryMuscles: ["Quads", "Calves", "Glutes"],
            secondaryMuscles: ["Core", "Hamstrings"],
            aliases: ["Agility Cones", "5-10-5 Drill"],
            movementPattern: .sprint,
            cues: ["Low center of gravity", "Plant and cut sharply", "Decelerate before cutting"],
            commonMistakes: ["Rounding turns", "Standing too upright", "Not decelerating"],
            variations: ["T-Drill", "Pro Agility", "L-Drill"]
        ),
        ExerciseMetadata(
            name: "Sprint Drills", muscleGroup: .fullBody, category: .sport, equipment: .bodyweight,
            difficulty: .intermediate,
            primaryMuscles: ["Quads", "Hamstrings", "Glutes"],
            secondaryMuscles: ["Calves", "Core", "Hip Flexors"],
            aliases: ["Speed Work", "Acceleration Drills"],
            movementPattern: .sprint,
            cues: ["45-degree body lean at start", "Drive knees up", "Full arm extension"],
            commonMistakes: ["Standing upright too early", "Not driving arms", "Overstriding"],
            variations: ["Resisted Sprints", "Hill Sprints", "Flying Starts"]
        ),
        ExerciseMetadata(
            name: "Vertical Jump Training", muscleGroup: .fullBody, category: .plyometric, equipment: .bodyweight,
            difficulty: .intermediate,
            primaryMuscles: ["Quads", "Glutes", "Calves"],
            secondaryMuscles: ["Core", "Hamstrings"],
            aliases: ["Vert Training", "Jump Training", "Plyos"],
            movementPattern: .jump,
            cues: ["Full countermovement", "Swing arms explosively", "Land softly with bent knees"],
            commonMistakes: ["Not using arms", "Landing stiff", "Not enough depth on countermovement"],
            variations: ["Depth Jumps", "Tuck Jumps", "Broad Jumps"]
        ),
        ExerciseMetadata(
            name: "Lateral Shuffles", muscleGroup: .fullBody, category: .sport, equipment: .bodyweight,
            difficulty: .beginner,
            primaryMuscles: ["Quads", "Glutes", "Adductors"],
            secondaryMuscles: ["Core", "Calves"],
            aliases: ["Lateral Slide", "Side Shuffle", "Defensive Slides"],
            movementPattern: .sprint,
            cues: ["Low athletic position", "Push off outside foot", "Don't cross feet"],
            commonMistakes: ["Standing too tall", "Crossing feet over", "Bouncing up and down"],
            variations: ["With Band", "With Touch", "Cone to Cone"]
        ),
        ExerciseMetadata(
            name: "Reaction Drills", muscleGroup: .fullBody, category: .sport, equipment: .other,
            difficulty: .intermediate,
            primaryMuscles: ["Full Body", "CNS"],
            secondaryMuscles: ["Quads", "Core"],
            aliases: ["Reaction Training", "Visual Reaction"],
            movementPattern: .sprint,
            cues: ["Stay in athletic ready position", "React to visual or audio cue", "Explode in the correct direction"],
            commonMistakes: ["Anticipating cues", "Slow first step", "Not in ready position"],
            variations: ["Partner Cues", "Light Board", "Ball Drops"]
        ),
        ExerciseMetadata(
            name: "Tire Flips", muscleGroup: .fullBody, category: .sport, equipment: .other,
            difficulty: .intermediate,
            primaryMuscles: ["Glutes", "Quads", "Back"],
            secondaryMuscles: ["Core", "Shoulders", "Arms"],
            aliases: ["Tire Flip"],
            movementPattern: .hinge,
            cues: ["Get low, hands under tire", "Drive through legs", "Flip and push over"],
            commonMistakes: ["Rounding back", "Lifting with back", "Bicep curl grip"],
            variations: ["Heavy Singles", "Speed Flips"]
        ),
        ExerciseMetadata(
            name: "Prowler Push", muscleGroup: .fullBody, category: .sport, equipment: .other,
            difficulty: .intermediate,
            primaryMuscles: ["Quads", "Glutes", "Calves"],
            secondaryMuscles: ["Core", "Shoulders"],
            aliases: ["Prowler", "Sled Work"],
            movementPattern: .sprint,
            cues: ["Lean into sled at 45 degrees", "Drive through toes", "Keep arms extended"],
            commonMistakes: ["Standing too upright", "Short steps", "Arms bending"],
            variations: ["High Handle", "Low Handle", "Backward Drag"]
        ),
    ]

    // MARK: - Search & Lookup Methods

    /// Find exercise by name (case-insensitive, checks aliases)
    static func find(_ name: String) -> ExerciseMetadata? {
        let lowercaseName = name.lowercased()
        return exercises.first { metadata in
            metadata.name.lowercased() == lowercaseName ||
            metadata.aliases.contains { $0.lowercased() == lowercaseName }
        }
    }

    /// Find exercises by muscle group
    static func byMuscleGroup(_ group: MuscleGroup) -> [ExerciseMetadata] {
        exercises.filter { $0.muscleGroup == group }
    }

    /// Find exercises by movement pattern
    static func byMovementPattern(_ pattern: MovementPattern) -> [ExerciseMetadata] {
        exercises.filter { $0.movementPattern == pattern }
    }

    /// Find exercises by equipment
    static func byEquipment(_ equipment: Equipment) -> [ExerciseMetadata] {
        exercises.filter { $0.equipment == equipment }
    }

    /// Search exercises by query (name, aliases, muscles, equipment, category, muscle group)
    static func search(_ query: String) -> [ExerciseMetadata] {
        let lowercaseQuery = query.lowercased()
        return exercises.filter { metadata in
            metadata.name.lowercased().contains(lowercaseQuery) ||
            metadata.aliases.contains { $0.lowercased().contains(lowercaseQuery) } ||
            metadata.primaryMuscles.contains { $0.lowercased().contains(lowercaseQuery) } ||
            metadata.equipment.rawValue.lowercased().contains(lowercaseQuery) ||
            metadata.category.rawValue.lowercased().contains(lowercaseQuery) ||
            metadata.muscleGroup.rawValue.lowercased().contains(lowercaseQuery)
        }
    }
}
