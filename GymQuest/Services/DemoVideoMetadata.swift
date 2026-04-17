import Foundation

/// Hand-crafted metadata for each bundled demo video. Gives the seeder
/// realistic captions, matched workout types, and occasional music attribution
/// so the Scroll feed reads like real content instead of lorem-ipsum filler.
struct DemoVideoMetadata {
    let resourceName: String
    let workoutType: String       // Push / Pull / Legs / Cardio / Full Body / Core
    let exerciseHighlight: String // named lift
    let captions: [String]        // pool to rotate through for variety
    let songTitle: String?
    let artistName: String?

    /// Canonical list — one entry per file in Resources/DemoVideos.
    static let all: [DemoVideoMetadata] = [
        DemoVideoMetadata(
            resourceName: "demo_squat",
            workoutType: "Legs",
            exerciseHighlight: "Back Squat",
            captions: [
                "New PR — 315×3 felt like a cheat day",
                "Quad pump is unreal today",
                "Leg day non-negotiable"
            ],
            songTitle: "Power",
            artistName: "Kanye West"
        ),
        DemoVideoMetadata(
            resourceName: "demo_bench_press",
            workoutType: "Push",
            exerciseHighlight: "Bench Press",
            captions: [
                "Chest day annihilation",
                "Form over ego. Every time.",
                "225 for reps feeling smooth"
            ],
            songTitle: "HUMBLE.",
            artistName: "Kendrick Lamar"
        ),
        DemoVideoMetadata(
            resourceName: "demo_deadlift",
            workoutType: "Pull",
            exerciseHighlight: "Deadlift",
            captions: [
                "Pulled a new 1RM today — 455",
                "Back felt locked in",
                "Deadlifts > coffee"
            ],
            songTitle: "Till I Collapse",
            artistName: "Eminem"
        ),
        DemoVideoMetadata(
            resourceName: "demo_pull_ups",
            workoutType: "Pull",
            exerciseHighlight: "Pull-Ups",
            captions: [
                "Bodyweight day — 15 strict",
                "Lats screaming",
                "Calisthenics hits different"
            ],
            songTitle: "Lose Yourself",
            artistName: "Eminem"
        ),
        DemoVideoMetadata(
            resourceName: "demo_shoulder_press",
            workoutType: "Push",
            exerciseHighlight: "Overhead Press",
            captions: [
                "Shoulder mobility unlocked",
                "Strict press — no leg drive",
                "Delts are done"
            ],
            songTitle: nil,
            artistName: nil
        ),
        DemoVideoMetadata(
            resourceName: "demo_barbell_row",
            workoutType: "Pull",
            exerciseHighlight: "Barbell Row",
            captions: [
                "Back thickness day",
                "Row heavy, row often",
                "Mid-traps on fire"
            ],
            songTitle: "Can't Hold Us",
            artistName: "Macklemore"
        ),
        DemoVideoMetadata(
            resourceName: "demo_dumbbell_curl",
            workoutType: "Pull",
            exerciseHighlight: "Dumbbell Curl",
            captions: [
                "Arm day quickie",
                "Slow eccentrics, clean reps",
                "Biceps pump achieved"
            ],
            songTitle: "Pump It",
            artistName: "The Black Eyed Peas"
        ),
        DemoVideoMetadata(
            resourceName: "demo_kettlebell",
            workoutType: "Full Body",
            exerciseHighlight: "Kettlebell Swing",
            captions: [
                "Kettlebell conditioning — 20 min EMOM",
                "Posterior chain activated",
                "Short, brutal, effective"
            ],
            songTitle: "Eye of the Tiger",
            artistName: "Survivor"
        ),
        DemoVideoMetadata(
            resourceName: "demo_leg_press",
            workoutType: "Legs",
            exerciseHighlight: "Leg Press",
            captions: [
                "Leg press stack + chains",
                "Can't walk tomorrow",
                "Quads > everything"
            ],
            songTitle: nil,
            artistName: nil
        ),
        DemoVideoMetadata(
            resourceName: "demo_treadmill",
            workoutType: "Cardio",
            exerciseHighlight: "Treadmill",
            captions: [
                "Zone 2 — 45 min easy",
                "Morning miles in the bag",
                "Cardio before coffee = cheat code"
            ],
            songTitle: "Runaway",
            artistName: "Kanye West"
        ),
        DemoVideoMetadata(
            resourceName: "demo_cycling",
            workoutType: "Cardio",
            exerciseHighlight: "Cycling",
            captions: [
                "40km bike loop, full send",
                "Legs fried but smiling",
                "Cycling off arm day"
            ],
            songTitle: "Levels",
            artistName: "Avicii"
        ),
        DemoVideoMetadata(
            resourceName: "demo_yoga",
            workoutType: "Core",
            exerciseHighlight: "Yoga Flow",
            captions: [
                "Recovery flow between lifts",
                "Hip mobility reset",
                "Yoga mat > foam roller"
            ],
            songTitle: "Weightless",
            artistName: "Marconi Union"
        )
    ]
}
