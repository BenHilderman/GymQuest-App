//
//  RobotDemoService.swift
//  GymQuest
//
//  Robot demo animation service for GymQuest 2.0.
//  Generates stick-figure exercise demos with labeled joint positions.
//

import Foundation
import SwiftUI

@MainActor
class RobotDemoService: ObservableObject {
    static let shared = RobotDemoService()

    // MARK: - Demo Data

    /// Get demo animation data for an exercise
    func getDemoAnimation(for exerciseName: String) -> ExerciseDemo? {
        let normalizedName = exerciseName.lowercased()
        return exerciseDemos[normalizedName]
    }

    /// Check if demo is available for an exercise
    func hasDemoAvailable(for exerciseName: String) -> Bool {
        return exerciseDemos[exerciseName.lowercased()] != nil
    }

    /// Get 3D model for an exercise (stub - 3D models not yet available)
    func get3DModel(for exerciseName: String) -> ExerciseDemo3D? {
        // 3D models are not yet implemented - return nil
        return nil
    }

    // MARK: - Exercise Demo Database

    private let exerciseDemos: [String: ExerciseDemo] = [
        "bench press": ExerciseDemo(
            name: "Bench Press",
            category: .push,
            keyframes: [
                DemoKeyframe(
                    position: .start,
                    joints: [
                        .shoulder: JointPosition(x: 0.5, y: 0.4, angle: 0),
                        .elbow: JointPosition(x: 0.7, y: 0.45, angle: 90),
                        .wrist: JointPosition(x: 0.75, y: 0.35, angle: 0),
                        .hip: JointPosition(x: 0.5, y: 0.6, angle: 170),
                        .knee: JointPosition(x: 0.55, y: 0.75, angle: 100),
                        .ankle: JointPosition(x: 0.45, y: 0.9, angle: 90)
                    ],
                    cues: ["Shoulder blades retracted", "Feet flat on floor", "Natural arch in lower back"]
                ),
                DemoKeyframe(
                    position: .mid,
                    joints: [
                        .shoulder: JointPosition(x: 0.5, y: 0.4, angle: -30),
                        .elbow: JointPosition(x: 0.65, y: 0.55, angle: 45),
                        .wrist: JointPosition(x: 0.55, y: 0.45, angle: 0),
                        .hip: JointPosition(x: 0.5, y: 0.6, angle: 170),
                        .knee: JointPosition(x: 0.55, y: 0.75, angle: 100),
                        .ankle: JointPosition(x: 0.45, y: 0.9, angle: 90)
                    ],
                    cues: ["Elbows at 45-75 degrees", "Bar touches chest", "Core braced"]
                ),
                DemoKeyframe(
                    position: .end,
                    joints: [
                        .shoulder: JointPosition(x: 0.5, y: 0.4, angle: 0),
                        .elbow: JointPosition(x: 0.7, y: 0.45, angle: 90),
                        .wrist: JointPosition(x: 0.75, y: 0.35, angle: 0),
                        .hip: JointPosition(x: 0.5, y: 0.6, angle: 170),
                        .knee: JointPosition(x: 0.55, y: 0.75, angle: 100),
                        .ankle: JointPosition(x: 0.45, y: 0.9, angle: 90)
                    ],
                    cues: ["Full lockout at top", "Shoulders stay pinned"]
                )
            ],
            keyJoints: [.shoulder, .elbow],
            tempo: "3-1-2-0"
        ),

        "squat": ExerciseDemo(
            name: "Squat",
            category: .legs,
            keyframes: [
                DemoKeyframe(
                    position: .start,
                    joints: [
                        .shoulder: JointPosition(x: 0.5, y: 0.3, angle: 0),
                        .hip: JointPosition(x: 0.5, y: 0.5, angle: 175),
                        .knee: JointPosition(x: 0.5, y: 0.7, angle: 175),
                        .ankle: JointPosition(x: 0.5, y: 0.9, angle: 90)
                    ],
                    cues: ["Stand tall", "Feet shoulder-width", "Toes slightly out"]
                ),
                DemoKeyframe(
                    position: .mid,
                    joints: [
                        .shoulder: JointPosition(x: 0.55, y: 0.35, angle: 15),
                        .hip: JointPosition(x: 0.5, y: 0.55, angle: 120),
                        .knee: JointPosition(x: 0.55, y: 0.7, angle: 120),
                        .ankle: JointPosition(x: 0.5, y: 0.9, angle: 75)
                    ],
                    cues: ["Knees track over toes", "Weight on midfoot", "Core braced"]
                ),
                DemoKeyframe(
                    position: .end,
                    joints: [
                        .shoulder: JointPosition(x: 0.6, y: 0.45, angle: 30),
                        .hip: JointPosition(x: 0.5, y: 0.65, angle: 80),
                        .knee: JointPosition(x: 0.6, y: 0.75, angle: 70),
                        .ankle: JointPosition(x: 0.5, y: 0.9, angle: 60)
                    ],
                    cues: ["Parallel or below", "Chest stays up", "Drive through heels"]
                )
            ],
            keyJoints: [.hip, .knee],
            tempo: "3-1-2-0"
        ),

        "deadlift": ExerciseDemo(
            name: "Deadlift",
            category: .pull,
            keyframes: [
                DemoKeyframe(
                    position: .start,
                    joints: [
                        .shoulder: JointPosition(x: 0.55, y: 0.4, angle: 20),
                        .hip: JointPosition(x: 0.5, y: 0.55, angle: 90),
                        .knee: JointPosition(x: 0.55, y: 0.7, angle: 110),
                        .ankle: JointPosition(x: 0.5, y: 0.9, angle: 80)
                    ],
                    cues: ["Bar over mid-foot", "Shoulders over bar", "Neutral spine"]
                ),
                DemoKeyframe(
                    position: .mid,
                    joints: [
                        .shoulder: JointPosition(x: 0.52, y: 0.35, angle: 10),
                        .hip: JointPosition(x: 0.5, y: 0.52, angle: 130),
                        .knee: JointPosition(x: 0.52, y: 0.72, angle: 140),
                        .ankle: JointPosition(x: 0.5, y: 0.9, angle: 85)
                    ],
                    cues: ["Push floor away", "Bar stays close", "Chest rises with hips"]
                ),
                DemoKeyframe(
                    position: .end,
                    joints: [
                        .shoulder: JointPosition(x: 0.5, y: 0.3, angle: 0),
                        .hip: JointPosition(x: 0.5, y: 0.5, angle: 175),
                        .knee: JointPosition(x: 0.5, y: 0.7, angle: 175),
                        .ankle: JointPosition(x: 0.5, y: 0.9, angle: 90)
                    ],
                    cues: ["Hips fully extended", "Squeeze glutes", "Shoulders back"]
                )
            ],
            keyJoints: [.hip, .shoulder],
            tempo: "2-0-2-1"
        ),

        "overhead press": ExerciseDemo(
            name: "Overhead Press",
            category: .push,
            keyframes: [
                DemoKeyframe(
                    position: .start,
                    joints: [
                        .shoulder: JointPosition(x: 0.5, y: 0.35, angle: 60),
                        .elbow: JointPosition(x: 0.55, y: 0.45, angle: 90),
                        .wrist: JointPosition(x: 0.5, y: 0.32, angle: 0),
                        .hip: JointPosition(x: 0.5, y: 0.6, angle: 175),
                        .knee: JointPosition(x: 0.5, y: 0.75, angle: 175)
                    ],
                    cues: ["Bar at shoulders", "Elbows slightly in front", "Core tight"]
                ),
                DemoKeyframe(
                    position: .mid,
                    joints: [
                        .shoulder: JointPosition(x: 0.5, y: 0.32, angle: 120),
                        .elbow: JointPosition(x: 0.6, y: 0.28, angle: 150),
                        .wrist: JointPosition(x: 0.55, y: 0.2, angle: 0),
                        .hip: JointPosition(x: 0.5, y: 0.6, angle: 175),
                        .knee: JointPosition(x: 0.5, y: 0.75, angle: 175)
                    ],
                    cues: ["Head moves back", "Bar path is vertical", "Ribs down"]
                ),
                DemoKeyframe(
                    position: .end,
                    joints: [
                        .shoulder: JointPosition(x: 0.5, y: 0.3, angle: 175),
                        .elbow: JointPosition(x: 0.5, y: 0.2, angle: 175),
                        .wrist: JointPosition(x: 0.5, y: 0.12, angle: 0),
                        .hip: JointPosition(x: 0.5, y: 0.6, angle: 175),
                        .knee: JointPosition(x: 0.5, y: 0.75, angle: 175)
                    ],
                    cues: ["Full lockout", "Shrug at top", "Head through"]
                )
            ],
            keyJoints: [.shoulder, .elbow],
            tempo: "2-0-2-0"
        ),

        "barbell row": ExerciseDemo(
            name: "Barbell Row",
            category: .pull,
            keyframes: [
                DemoKeyframe(
                    position: .start,
                    joints: [
                        .shoulder: JointPosition(x: 0.55, y: 0.4, angle: 30),
                        .elbow: JointPosition(x: 0.6, y: 0.55, angle: 170),
                        .hip: JointPosition(x: 0.45, y: 0.55, angle: 100),
                        .knee: JointPosition(x: 0.5, y: 0.72, angle: 150)
                    ],
                    cues: ["Hinge at hips", "Arms extended", "Back flat"]
                ),
                DemoKeyframe(
                    position: .end,
                    joints: [
                        .shoulder: JointPosition(x: 0.5, y: 0.38, angle: -15),
                        .elbow: JointPosition(x: 0.55, y: 0.5, angle: 70),
                        .hip: JointPosition(x: 0.45, y: 0.55, angle: 100),
                        .knee: JointPosition(x: 0.5, y: 0.72, angle: 150)
                    ],
                    cues: ["Pull to lower chest", "Squeeze shoulder blades", "Elbows back"]
                )
            ],
            keyJoints: [.elbow, .shoulder],
            tempo: "1-1-3-0"
        ),

        "pull-up": ExerciseDemo(
            name: "Pull-up",
            category: .pull,
            keyframes: [
                DemoKeyframe(
                    position: .start,
                    joints: [
                        .shoulder: JointPosition(x: 0.5, y: 0.25, angle: 175),
                        .elbow: JointPosition(x: 0.5, y: 0.15, angle: 175),
                        .hip: JointPosition(x: 0.5, y: 0.55, angle: 175),
                        .knee: JointPosition(x: 0.5, y: 0.75, angle: 175)
                    ],
                    cues: ["Dead hang", "Shoulders engaged", "Core tight"]
                ),
                DemoKeyframe(
                    position: .end,
                    joints: [
                        .shoulder: JointPosition(x: 0.5, y: 0.2, angle: 30),
                        .elbow: JointPosition(x: 0.55, y: 0.15, angle: 60),
                        .hip: JointPosition(x: 0.5, y: 0.45, angle: 175),
                        .knee: JointPosition(x: 0.5, y: 0.65, angle: 175)
                    ],
                    cues: ["Chin over bar", "Chest to bar", "Shoulders down and back"]
                )
            ],
            keyJoints: [.shoulder, .elbow],
            tempo: "1-1-3-0"
        ),

        // MARK: - Additional Exercises

        "dumbbell curl": ExerciseDemo(
            name: "Dumbbell Curl",
            category: .pull,
            keyframes: [
                DemoKeyframe(
                    position: .start,
                    joints: [
                        .shoulder: JointPosition(x: 0.5, y: 0.35, angle: 0),
                        .elbow: JointPosition(x: 0.5, y: 0.5, angle: 175),
                        .wrist: JointPosition(x: 0.5, y: 0.65, angle: 0),
                        .hip: JointPosition(x: 0.5, y: 0.55, angle: 175),
                        .knee: JointPosition(x: 0.5, y: 0.75, angle: 175)
                    ],
                    cues: ["Arms at sides", "Palms forward", "Stand tall"]
                ),
                DemoKeyframe(
                    position: .mid,
                    joints: [
                        .shoulder: JointPosition(x: 0.5, y: 0.35, angle: 0),
                        .elbow: JointPosition(x: 0.52, y: 0.48, angle: 90),
                        .wrist: JointPosition(x: 0.52, y: 0.42, angle: 0),
                        .hip: JointPosition(x: 0.5, y: 0.55, angle: 175),
                        .knee: JointPosition(x: 0.5, y: 0.75, angle: 175)
                    ],
                    cues: ["Elbows stay pinned", "Control the movement", "No swinging"]
                ),
                DemoKeyframe(
                    position: .end,
                    joints: [
                        .shoulder: JointPosition(x: 0.5, y: 0.35, angle: 0),
                        .elbow: JointPosition(x: 0.52, y: 0.42, angle: 30),
                        .wrist: JointPosition(x: 0.52, y: 0.32, angle: 0),
                        .hip: JointPosition(x: 0.5, y: 0.55, angle: 175),
                        .knee: JointPosition(x: 0.5, y: 0.75, angle: 175)
                    ],
                    cues: ["Squeeze at top", "Keep tension", "Controlled lowering"]
                )
            ],
            keyJoints: [.elbow, .wrist],
            tempo: "2-1-2-0"
        ),

        "tricep pushdown": ExerciseDemo(
            name: "Tricep Pushdown",
            category: .push,
            keyframes: [
                DemoKeyframe(
                    position: .start,
                    joints: [
                        .shoulder: JointPosition(x: 0.5, y: 0.35, angle: 0),
                        .elbow: JointPosition(x: 0.5, y: 0.45, angle: 90),
                        .wrist: JointPosition(x: 0.5, y: 0.38, angle: 0),
                        .hip: JointPosition(x: 0.5, y: 0.55, angle: 175),
                        .knee: JointPosition(x: 0.5, y: 0.75, angle: 170)
                    ],
                    cues: ["Elbows at sides", "Slight lean forward", "Core braced"]
                ),
                DemoKeyframe(
                    position: .end,
                    joints: [
                        .shoulder: JointPosition(x: 0.5, y: 0.35, angle: 0),
                        .elbow: JointPosition(x: 0.5, y: 0.5, angle: 170),
                        .wrist: JointPosition(x: 0.5, y: 0.6, angle: 0),
                        .hip: JointPosition(x: 0.5, y: 0.55, angle: 175),
                        .knee: JointPosition(x: 0.5, y: 0.75, angle: 170)
                    ],
                    cues: ["Full extension", "Squeeze triceps", "Elbows stay stationary"]
                )
            ],
            keyJoints: [.elbow, .wrist],
            tempo: "2-1-2-0"
        ),

        "lat pulldown": ExerciseDemo(
            name: "Lat Pulldown",
            category: .pull,
            keyframes: [
                DemoKeyframe(
                    position: .start,
                    joints: [
                        .shoulder: JointPosition(x: 0.5, y: 0.28, angle: 170),
                        .elbow: JointPosition(x: 0.55, y: 0.2, angle: 170),
                        .wrist: JointPosition(x: 0.6, y: 0.15, angle: 0),
                        .hip: JointPosition(x: 0.5, y: 0.6, angle: 95),
                        .knee: JointPosition(x: 0.5, y: 0.75, angle: 90)
                    ],
                    cues: ["Arms extended overhead", "Slight lean back", "Chest up"]
                ),
                DemoKeyframe(
                    position: .mid,
                    joints: [
                        .shoulder: JointPosition(x: 0.5, y: 0.32, angle: 90),
                        .elbow: JointPosition(x: 0.55, y: 0.38, angle: 90),
                        .wrist: JointPosition(x: 0.55, y: 0.32, angle: 0),
                        .hip: JointPosition(x: 0.5, y: 0.6, angle: 95),
                        .knee: JointPosition(x: 0.5, y: 0.75, angle: 90)
                    ],
                    cues: ["Pull elbows down", "Squeeze shoulder blades", "Bar to chest"]
                ),
                DemoKeyframe(
                    position: .end,
                    joints: [
                        .shoulder: JointPosition(x: 0.5, y: 0.35, angle: 30),
                        .elbow: JointPosition(x: 0.52, y: 0.45, angle: 60),
                        .wrist: JointPosition(x: 0.5, y: 0.38, angle: 0),
                        .hip: JointPosition(x: 0.5, y: 0.6, angle: 95),
                        .knee: JointPosition(x: 0.5, y: 0.75, angle: 90)
                    ],
                    cues: ["Bar below chin", "Full contraction", "Control the release"]
                )
            ],
            keyJoints: [.shoulder, .elbow],
            tempo: "2-1-3-0"
        ),

        "leg press": ExerciseDemo(
            name: "Leg Press",
            category: .legs,
            keyframes: [
                DemoKeyframe(
                    position: .start,
                    joints: [
                        .shoulder: JointPosition(x: 0.45, y: 0.35, angle: 45),
                        .hip: JointPosition(x: 0.5, y: 0.55, angle: 90),
                        .knee: JointPosition(x: 0.55, y: 0.6, angle: 90),
                        .ankle: JointPosition(x: 0.6, y: 0.5, angle: 90)
                    ],
                    cues: ["Back flat on pad", "Feet shoulder-width", "Knees bent 90°"]
                ),
                DemoKeyframe(
                    position: .end,
                    joints: [
                        .shoulder: JointPosition(x: 0.45, y: 0.35, angle: 45),
                        .hip: JointPosition(x: 0.5, y: 0.52, angle: 160),
                        .knee: JointPosition(x: 0.55, y: 0.5, angle: 170),
                        .ankle: JointPosition(x: 0.65, y: 0.42, angle: 90)
                    ],
                    cues: ["Push through heels", "Don't lock knees", "Control the descent"]
                )
            ],
            keyJoints: [.knee, .hip],
            tempo: "2-0-2-0"
        ),

        "leg curl": ExerciseDemo(
            name: "Leg Curl",
            category: .legs,
            keyframes: [
                DemoKeyframe(
                    position: .start,
                    joints: [
                        .shoulder: JointPosition(x: 0.5, y: 0.3, angle: 0),
                        .hip: JointPosition(x: 0.5, y: 0.5, angle: 180),
                        .knee: JointPosition(x: 0.5, y: 0.65, angle: 180),
                        .ankle: JointPosition(x: 0.5, y: 0.85, angle: 90)
                    ],
                    cues: ["Lie flat", "Pad above heels", "Grip handles"]
                ),
                DemoKeyframe(
                    position: .end,
                    joints: [
                        .shoulder: JointPosition(x: 0.5, y: 0.3, angle: 0),
                        .hip: JointPosition(x: 0.5, y: 0.5, angle: 180),
                        .knee: JointPosition(x: 0.5, y: 0.65, angle: 60),
                        .ankle: JointPosition(x: 0.5, y: 0.55, angle: 90)
                    ],
                    cues: ["Curl to glutes", "Squeeze hamstrings", "Controlled release"]
                )
            ],
            keyJoints: [.knee, .ankle],
            tempo: "2-1-3-0"
        ),

        "leg extension": ExerciseDemo(
            name: "Leg Extension",
            category: .legs,
            keyframes: [
                DemoKeyframe(
                    position: .start,
                    joints: [
                        .shoulder: JointPosition(x: 0.45, y: 0.32, angle: 10),
                        .hip: JointPosition(x: 0.5, y: 0.55, angle: 90),
                        .knee: JointPosition(x: 0.55, y: 0.7, angle: 90),
                        .ankle: JointPosition(x: 0.45, y: 0.8, angle: 90)
                    ],
                    cues: ["Sit back in seat", "Knees at 90°", "Hold handles"]
                ),
                DemoKeyframe(
                    position: .end,
                    joints: [
                        .shoulder: JointPosition(x: 0.45, y: 0.32, angle: 10),
                        .hip: JointPosition(x: 0.5, y: 0.55, angle: 90),
                        .knee: JointPosition(x: 0.55, y: 0.7, angle: 175),
                        .ankle: JointPosition(x: 0.7, y: 0.68, angle: 90)
                    ],
                    cues: ["Full extension", "Squeeze quads", "Slow negative"]
                )
            ],
            keyJoints: [.knee, .ankle],
            tempo: "2-1-3-0"
        ),

        "shoulder press": ExerciseDemo(
            name: "Shoulder Press",
            category: .push,
            keyframes: [
                DemoKeyframe(
                    position: .start,
                    joints: [
                        .shoulder: JointPosition(x: 0.5, y: 0.35, angle: 90),
                        .elbow: JointPosition(x: 0.6, y: 0.4, angle: 90),
                        .wrist: JointPosition(x: 0.6, y: 0.3, angle: 0),
                        .hip: JointPosition(x: 0.5, y: 0.6, angle: 175),
                        .knee: JointPosition(x: 0.5, y: 0.75, angle: 175)
                    ],
                    cues: ["Dumbbells at shoulders", "Elbows out", "Core engaged"]
                ),
                DemoKeyframe(
                    position: .end,
                    joints: [
                        .shoulder: JointPosition(x: 0.5, y: 0.3, angle: 175),
                        .elbow: JointPosition(x: 0.5, y: 0.2, angle: 175),
                        .wrist: JointPosition(x: 0.5, y: 0.12, angle: 0),
                        .hip: JointPosition(x: 0.5, y: 0.6, angle: 175),
                        .knee: JointPosition(x: 0.5, y: 0.75, angle: 175)
                    ],
                    cues: ["Press overhead", "Full lockout", "Control descent"]
                )
            ],
            keyJoints: [.shoulder, .elbow],
            tempo: "2-0-2-0"
        ),

        "dumbbell row": ExerciseDemo(
            name: "Dumbbell Row",
            category: .pull,
            keyframes: [
                DemoKeyframe(
                    position: .start,
                    joints: [
                        .shoulder: JointPosition(x: 0.55, y: 0.4, angle: 30),
                        .elbow: JointPosition(x: 0.6, y: 0.55, angle: 170),
                        .wrist: JointPosition(x: 0.6, y: 0.65, angle: 0),
                        .hip: JointPosition(x: 0.45, y: 0.55, angle: 100),
                        .knee: JointPosition(x: 0.5, y: 0.72, angle: 150)
                    ],
                    cues: ["Support on bench", "Back flat", "Arm extended"]
                ),
                DemoKeyframe(
                    position: .end,
                    joints: [
                        .shoulder: JointPosition(x: 0.5, y: 0.38, angle: -15),
                        .elbow: JointPosition(x: 0.55, y: 0.45, angle: 70),
                        .wrist: JointPosition(x: 0.55, y: 0.4, angle: 0),
                        .hip: JointPosition(x: 0.45, y: 0.55, angle: 100),
                        .knee: JointPosition(x: 0.5, y: 0.72, angle: 150)
                    ],
                    cues: ["Pull to hip", "Squeeze back", "Elbow past body"]
                )
            ],
            keyJoints: [.elbow, .shoulder],
            tempo: "1-1-3-0"
        ),

        "chest fly": ExerciseDemo(
            name: "Chest Fly",
            category: .push,
            keyframes: [
                DemoKeyframe(
                    position: .start,
                    joints: [
                        .shoulder: JointPosition(x: 0.5, y: 0.4, angle: 90),
                        .elbow: JointPosition(x: 0.75, y: 0.4, angle: 160),
                        .wrist: JointPosition(x: 0.85, y: 0.35, angle: 0),
                        .hip: JointPosition(x: 0.5, y: 0.6, angle: 170),
                        .knee: JointPosition(x: 0.55, y: 0.75, angle: 100)
                    ],
                    cues: ["Arms wide", "Slight elbow bend", "Chest stretched"]
                ),
                DemoKeyframe(
                    position: .end,
                    joints: [
                        .shoulder: JointPosition(x: 0.5, y: 0.4, angle: 0),
                        .elbow: JointPosition(x: 0.55, y: 0.35, angle: 160),
                        .wrist: JointPosition(x: 0.5, y: 0.3, angle: 0),
                        .hip: JointPosition(x: 0.5, y: 0.6, angle: 170),
                        .knee: JointPosition(x: 0.55, y: 0.75, angle: 100)
                    ],
                    cues: ["Bring together", "Squeeze chest", "Control the arc"]
                )
            ],
            keyJoints: [.shoulder, .elbow],
            tempo: "2-1-2-0"
        ),

        "plank": ExerciseDemo(
            name: "Plank",
            category: .core,
            keyframes: [
                DemoKeyframe(
                    position: .start,
                    joints: [
                        .shoulder: JointPosition(x: 0.3, y: 0.35, angle: 90),
                        .elbow: JointPosition(x: 0.3, y: 0.55, angle: 90),
                        .hip: JointPosition(x: 0.5, y: 0.35, angle: 180),
                        .knee: JointPosition(x: 0.7, y: 0.35, angle: 180),
                        .ankle: JointPosition(x: 0.85, y: 0.35, angle: 90)
                    ],
                    cues: ["Elbows under shoulders", "Body straight", "Core braced"]
                ),
                DemoKeyframe(
                    position: .mid,
                    joints: [
                        .shoulder: JointPosition(x: 0.3, y: 0.35, angle: 90),
                        .elbow: JointPosition(x: 0.3, y: 0.55, angle: 90),
                        .hip: JointPosition(x: 0.5, y: 0.35, angle: 180),
                        .knee: JointPosition(x: 0.7, y: 0.35, angle: 180),
                        .ankle: JointPosition(x: 0.85, y: 0.35, angle: 90)
                    ],
                    cues: ["Hold position", "Breathe steadily", "Squeeze glutes"]
                ),
                DemoKeyframe(
                    position: .end,
                    joints: [
                        .shoulder: JointPosition(x: 0.3, y: 0.35, angle: 90),
                        .elbow: JointPosition(x: 0.3, y: 0.55, angle: 90),
                        .hip: JointPosition(x: 0.5, y: 0.35, angle: 180),
                        .knee: JointPosition(x: 0.7, y: 0.35, angle: 180),
                        .ankle: JointPosition(x: 0.85, y: 0.35, angle: 90)
                    ],
                    cues: ["Maintain alignment", "Don't sag hips", "Keep neutral spine"]
                )
            ],
            keyJoints: [.shoulder, .hip],
            tempo: "Hold"
        ),

        "lunge": ExerciseDemo(
            name: "Lunge",
            category: .legs,
            keyframes: [
                DemoKeyframe(
                    position: .start,
                    joints: [
                        .shoulder: JointPosition(x: 0.5, y: 0.3, angle: 0),
                        .hip: JointPosition(x: 0.5, y: 0.5, angle: 175),
                        .knee: JointPosition(x: 0.5, y: 0.7, angle: 175),
                        .ankle: JointPosition(x: 0.5, y: 0.9, angle: 90)
                    ],
                    cues: ["Stand tall", "Feet hip-width", "Core engaged"]
                ),
                DemoKeyframe(
                    position: .mid,
                    joints: [
                        .shoulder: JointPosition(x: 0.5, y: 0.35, angle: 0),
                        .hip: JointPosition(x: 0.5, y: 0.55, angle: 160),
                        .knee: JointPosition(x: 0.55, y: 0.7, angle: 130),
                        .ankle: JointPosition(x: 0.5, y: 0.9, angle: 80)
                    ],
                    cues: ["Step forward", "Lower controlled", "Keep torso upright"]
                ),
                DemoKeyframe(
                    position: .end,
                    joints: [
                        .shoulder: JointPosition(x: 0.5, y: 0.4, angle: 0),
                        .hip: JointPosition(x: 0.5, y: 0.6, angle: 120),
                        .knee: JointPosition(x: 0.6, y: 0.75, angle: 90),
                        .ankle: JointPosition(x: 0.5, y: 0.9, angle: 70)
                    ],
                    cues: ["Front knee 90°", "Back knee near floor", "Push through front heel"]
                )
            ],
            keyJoints: [.hip, .knee],
            tempo: "2-0-2-0"
        ),

        "romanian deadlift": ExerciseDemo(
            name: "Romanian Deadlift",
            category: .legs,
            keyframes: [
                DemoKeyframe(
                    position: .start,
                    joints: [
                        .shoulder: JointPosition(x: 0.5, y: 0.3, angle: 0),
                        .hip: JointPosition(x: 0.5, y: 0.5, angle: 175),
                        .knee: JointPosition(x: 0.5, y: 0.7, angle: 170),
                        .ankle: JointPosition(x: 0.5, y: 0.9, angle: 90)
                    ],
                    cues: ["Stand tall", "Weight in hands", "Slight knee bend"]
                ),
                DemoKeyframe(
                    position: .end,
                    joints: [
                        .shoulder: JointPosition(x: 0.6, y: 0.45, angle: 30),
                        .hip: JointPosition(x: 0.5, y: 0.55, angle: 90),
                        .knee: JointPosition(x: 0.52, y: 0.72, angle: 160),
                        .ankle: JointPosition(x: 0.5, y: 0.9, angle: 85)
                    ],
                    cues: ["Hinge at hips", "Bar close to legs", "Feel hamstring stretch"]
                )
            ],
            keyJoints: [.hip, .knee],
            tempo: "3-1-2-0"
        ),

        "calf raise": ExerciseDemo(
            name: "Calf Raise",
            category: .legs,
            keyframes: [
                DemoKeyframe(
                    position: .start,
                    joints: [
                        .shoulder: JointPosition(x: 0.5, y: 0.3, angle: 0),
                        .hip: JointPosition(x: 0.5, y: 0.5, angle: 175),
                        .knee: JointPosition(x: 0.5, y: 0.7, angle: 175),
                        .ankle: JointPosition(x: 0.5, y: 0.9, angle: 90)
                    ],
                    cues: ["Feet on edge", "Heels dropped", "Hold support"]
                ),
                DemoKeyframe(
                    position: .end,
                    joints: [
                        .shoulder: JointPosition(x: 0.5, y: 0.28, angle: 0),
                        .hip: JointPosition(x: 0.5, y: 0.48, angle: 175),
                        .knee: JointPosition(x: 0.5, y: 0.68, angle: 175),
                        .ankle: JointPosition(x: 0.5, y: 0.88, angle: 130)
                    ],
                    cues: ["Rise on toes", "Squeeze calves", "Full contraction"]
                )
            ],
            keyJoints: [.ankle, .knee],
            tempo: "2-1-2-1"
        )
    ]
}

// MARK: - Demo Data Structures

struct ExerciseDemo: Identifiable {
    let id = UUID()
    let name: String
    let category: DemoCategory
    let keyframes: [DemoKeyframe]
    let keyJoints: [JointType]
    let tempo: String // e.g., "3-1-2-0" (eccentric-pause-concentric-pause)
}

enum DemoCategory: String {
    case push = "Push"
    case pull = "Pull"
    case legs = "Legs"
    case core = "Core"
    case cardio = "Cardio"
}

struct DemoKeyframe: Identifiable {
    let id = UUID()
    let position: KeyframePosition
    let joints: [JointType: JointPosition]
    let cues: [String]
}

enum KeyframePosition: String {
    case start = "Start"
    case mid = "Mid"
    case end = "End"
}

enum JointType: String, CaseIterable {
    case shoulder = "Shoulder"
    case elbow = "Elbow"
    case wrist = "Wrist"
    case hip = "Hip"
    case knee = "Knee"
    case ankle = "Ankle"

    var color: Color {
        switch self {
        case .shoulder: return .blue
        case .elbow: return .cyan
        case .wrist: return .green
        case .hip: return .orange
        case .knee: return .yellow
        case .ankle: return .pink
        }
    }
}

struct JointPosition {
    let x: CGFloat // 0-1 normalized
    let y: CGFloat // 0-1 normalized
    let angle: CGFloat // degrees
}

// MARK: - Robot Demo View

struct RobotDemoView: View {
    let demo: ExerciseDemo
    @State private var currentKeyframeIndex = 0
    @State private var isAnimating = true

    let timer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var currentKeyframe: DemoKeyframe {
        demo.keyframes[currentKeyframeIndex]
    }

    var body: some View {
        VStack(spacing: 16) {
            // Animation area
            GeometryReader { geo in
                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(white: 0.97))

                    // Stick figure
                    StickFigureView(
                        joints: currentKeyframe.joints,
                        keyJoints: demo.keyJoints,
                        size: geo.size
                    )

                    // Position indicator
                    VStack {
                        HStack {
                            Text(currentKeyframe.position.rawValue)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.3))
                                .cornerRadius(8)

                            Spacer()

                            Button {
                                isAnimating.toggle()
                            } label: {
                                Image(systemName: isAnimating ? "pause.fill" : "play.fill")
                                    .foregroundColor(GQColors.textPrimary)
                                    .padding(8)
                                    .background(Color.black.opacity(0.06))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(12)

                        Spacer()
                    }
                }
            }
            .frame(height: 280)

            // Current cues
            VStack(alignment: .leading, spacing: 8) {
                Text("CURRENT POSITION CUES")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
                    .tracking(0.5)

                ForEach(currentKeyframe.cues, id: \.self) { cue in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                            .padding(.top, 5)
                        Text(cue)
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textPrimary.opacity(0.9))
                    }
                }
            }
            .padding(12)
            .background(Color(white: 0.96))
            .cornerRadius(12)

            // Key joints legend
            HStack(spacing: 16) {
                ForEach(demo.keyJoints, id: \.self) { joint in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(joint.color)
                            .frame(width: 10, height: 10)
                        Text(joint.rawValue)
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                Text("Tempo: \(demo.tempo)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.blue)
            }
        }
        .onReceive(timer) { _ in
            guard isAnimating else { return }
            withAnimation(.easeInOut(duration: 0.5)) {
                currentKeyframeIndex = (currentKeyframeIndex + 1) % demo.keyframes.count
            }
        }
    }
}

// MARK: - Stick Figure View

struct StickFigureView: View {
    let joints: [JointType: JointPosition]
    let keyJoints: [JointType]
    let size: CGSize

    var body: some View {
        Canvas { context, size in
            // Draw stick figure
            drawStickFigure(context: context, size: size)
        }
    }

    private func drawStickFigure(context: GraphicsContext, size: CGSize) {
        let headCenter = CGPoint(x: size.width * 0.5, y: size.height * 0.15)
        let headRadius: CGFloat = 20

        // Draw head
        let headPath = Path(ellipseIn: CGRect(
            x: headCenter.x - headRadius,
            y: headCenter.y - headRadius,
            width: headRadius * 2,
            height: headRadius * 2
        ))
        context.stroke(headPath, with: .color(.white), lineWidth: 3)

        // Get joint positions
        let shoulder = jointPoint(.shoulder, size: size) ?? CGPoint(x: size.width * 0.5, y: size.height * 0.3)
        let elbow = jointPoint(.elbow, size: size)
        let wrist = jointPoint(.wrist, size: size)
        let hip = jointPoint(.hip, size: size) ?? CGPoint(x: size.width * 0.5, y: size.height * 0.55)
        let knee = jointPoint(.knee, size: size)
        let ankle = jointPoint(.ankle, size: size)

        // Neck to shoulders
        drawLine(context: context, from: CGPoint(x: headCenter.x, y: headCenter.y + headRadius), to: shoulder, color: .white)

        // Shoulders to hips (torso)
        drawLine(context: context, from: shoulder, to: hip, color: .white)

        // Arms (if joints available)
        if let elbow = elbow {
            // Left arm
            drawLine(context: context, from: CGPoint(x: shoulder.x - 20, y: shoulder.y), to: CGPoint(x: elbow.x - 20, y: elbow.y), color: .white)
            // Right arm
            drawLine(context: context, from: CGPoint(x: shoulder.x + 20, y: shoulder.y), to: CGPoint(x: elbow.x + 20, y: elbow.y), color: .white)

            if let wrist = wrist {
                drawLine(context: context, from: CGPoint(x: elbow.x - 20, y: elbow.y), to: CGPoint(x: wrist.x - 20, y: wrist.y), color: .white)
                drawLine(context: context, from: CGPoint(x: elbow.x + 20, y: elbow.y), to: CGPoint(x: wrist.x + 20, y: wrist.y), color: .white)
            }
        }

        // Legs (if joints available)
        if let knee = knee {
            // Left leg
            drawLine(context: context, from: CGPoint(x: hip.x - 15, y: hip.y), to: CGPoint(x: knee.x - 15, y: knee.y), color: .white)
            // Right leg
            drawLine(context: context, from: CGPoint(x: hip.x + 15, y: hip.y), to: CGPoint(x: knee.x + 15, y: knee.y), color: .white)

            if let ankle = ankle {
                drawLine(context: context, from: CGPoint(x: knee.x - 15, y: knee.y), to: CGPoint(x: ankle.x - 15, y: ankle.y), color: .white)
                drawLine(context: context, from: CGPoint(x: knee.x + 15, y: knee.y), to: CGPoint(x: ankle.x + 15, y: ankle.y), color: .white)
            }
        }

        // Draw key joints with highlights
        for joint in keyJoints {
            if let position = jointPoint(joint, size: size) {
                let jointPath = Path(ellipseIn: CGRect(
                    x: position.x - 8,
                    y: position.y - 8,
                    width: 16,
                    height: 16
                ))
                context.fill(jointPath, with: .color(joint.color.opacity(0.3)))
                context.stroke(jointPath, with: .color(joint.color), lineWidth: 2)
            }
        }
    }

    private func jointPoint(_ joint: JointType, size: CGSize) -> CGPoint? {
        guard let position = joints[joint] else { return nil }
        return CGPoint(x: size.width * position.x, y: size.height * position.y)
    }

    private func drawLine(context: GraphicsContext, from: CGPoint, to: CGPoint, color: Color) {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        context.stroke(path, with: .color(color), lineWidth: 3)
    }
}

// MARK: - Robot Demo Sheet

struct RobotDemoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let exerciseName: String
    @State private var demo: ExerciseDemo?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let demo = demo {
                        RobotDemoView(demo: demo)
                    } else {
                        VStack(spacing: 16) {
                            ProgressView()
                                .tint(.white)
                            Text("Generating demo...")
                                .foregroundColor(.gray)
                        }
                        .frame(height: 300)
                    }

                    // Info section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ABOUT THIS DEMO")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gray)
                            .tracking(0.5)

                        Text("This animated demo shows the proper form for \(exerciseName). Key joints are highlighted to show correct positioning throughout the movement.")
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textPrimary.opacity(0.8))
                    }
                    .padding(16)
                    .background(Color(white: 0.96))
                    .cornerRadius(12)
                }
                .padding(16)
            }
            .background(GQColors.background.ignoresSafeArea())
            .navigationTitle("Robot Demo")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                loadDemo()
            }
        }
    }

    private func loadDemo() {
        let service = RobotDemoService.shared
        // Simulate loading delay
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            demo = service.getDemoAnimation(for: exerciseName)
        }
    }
}

#Preview {
    RobotDemoSheet(exerciseName: "Squat")
}
