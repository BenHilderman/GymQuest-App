//
//  WatchWorkoutModels.swift
//  GymQuestWatch
//
//  Lightweight workout data types for watchOS. No SwiftData dependency.
//

import Foundation
import SwiftUI

// MARK: - Active Workout Types

struct WatchActiveExercise: Identifiable {
    let id = UUID()
    var name: String
    var muscleGroup: String
    var sets: [WatchActiveSet]
}

struct WatchActiveSet: Identifiable {
    let id = UUID()
    var reps: Int
    var weight: Double
    var isCompleted: Bool = false
    var rpe: Int?

    var volume: Double { Double(reps) * weight }
}

// MARK: - Completed Workout (Codable for UserDefaults)

struct WatchCompletedWorkout: Codable, Identifiable {
    var id = UUID()
    let type: String
    let date: Date
    let durationSeconds: Int
    let exercises: [CompletedExercise]
    var totalVolume: Double {
        exercises.flatMap(\.sets).reduce(0) { $0 + Double($1.reps) * $1.weight }
    }
    var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }
    var prsAchieved: Int = 0

    struct CompletedExercise: Codable, Identifiable {
        var id = UUID()
        let name: String
        let sets: [CompletedSet]
    }

    struct CompletedSet: Codable {
        let reps: Int
        let weight: Double
    }
}

// MARK: - Workout History Persistence

enum WorkoutHistory {
    private static let key = "watchWorkoutHistory"
    private static let maxItems = 20

    static func load() -> [WatchCompletedWorkout] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let workouts = try? JSONDecoder().decode([WatchCompletedWorkout].self, from: data)
        else { return [] }
        return workouts
    }

    static func save(_ workout: WatchCompletedWorkout) {
        var history = load()
        history.insert(workout, at: 0)
        if history.count > maxItems { history = Array(history.prefix(maxItems)) }
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func delete(at offsets: IndexSet) {
        var history = load()
        history.remove(atOffsets: offsets)
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - Workout Templates

struct ExerciseTemplate {
    let name: String
    let muscleGroup: String
    let sets: Int
    let reps: Int
    let weight: Double
}

let watchWorkoutTemplates: [String: [ExerciseTemplate]] = [
    "Push": [
        ExerciseTemplate(name: "Bench Press", muscleGroup: "Chest", sets: 3, reps: 10, weight: 135),
        ExerciseTemplate(name: "Overhead Press", muscleGroup: "Shoulders", sets: 3, reps: 8, weight: 95),
        ExerciseTemplate(name: "Incline Dumbbell Press", muscleGroup: "Chest", sets: 3, reps: 10, weight: 50),
        ExerciseTemplate(name: "Lateral Raises", muscleGroup: "Shoulders", sets: 3, reps: 12, weight: 20),
        ExerciseTemplate(name: "Tricep Pushdowns", muscleGroup: "Triceps", sets: 3, reps: 12, weight: 40),
    ],
    "Pull": [
        ExerciseTemplate(name: "Barbell Row", muscleGroup: "Back", sets: 3, reps: 10, weight: 135),
        ExerciseTemplate(name: "Pull-Ups", muscleGroup: "Back", sets: 3, reps: 8, weight: 0),
        ExerciseTemplate(name: "Face Pulls", muscleGroup: "Rear Delts", sets: 3, reps: 15, weight: 30),
        ExerciseTemplate(name: "Barbell Curl", muscleGroup: "Biceps", sets: 3, reps: 10, weight: 65),
        ExerciseTemplate(name: "Hammer Curls", muscleGroup: "Biceps", sets: 3, reps: 12, weight: 30),
    ],
    "Legs": [
        ExerciseTemplate(name: "Squat", muscleGroup: "Quads", sets: 4, reps: 8, weight: 185),
        ExerciseTemplate(name: "Romanian Deadlift", muscleGroup: "Hamstrings", sets: 3, reps: 10, weight: 135),
        ExerciseTemplate(name: "Leg Press", muscleGroup: "Quads", sets: 3, reps: 12, weight: 270),
        ExerciseTemplate(name: "Leg Curls", muscleGroup: "Hamstrings", sets: 3, reps: 12, weight: 90),
        ExerciseTemplate(name: "Calf Raises", muscleGroup: "Calves", sets: 4, reps: 15, weight: 135),
    ],
    "Upper": [
        ExerciseTemplate(name: "Bench Press", muscleGroup: "Chest", sets: 3, reps: 10, weight: 135),
        ExerciseTemplate(name: "Barbell Row", muscleGroup: "Back", sets: 3, reps: 10, weight: 135),
        ExerciseTemplate(name: "Overhead Press", muscleGroup: "Shoulders", sets: 3, reps: 8, weight: 95),
        ExerciseTemplate(name: "Lat Pulldown", muscleGroup: "Back", sets: 3, reps: 10, weight: 120),
        ExerciseTemplate(name: "Dumbbell Curls", muscleGroup: "Biceps", sets: 3, reps: 12, weight: 30),
    ],
    "Lower": [
        ExerciseTemplate(name: "Squat", muscleGroup: "Quads", sets: 4, reps: 8, weight: 185),
        ExerciseTemplate(name: "Hip Thrusts", muscleGroup: "Glutes", sets: 3, reps: 10, weight: 185),
        ExerciseTemplate(name: "Walking Lunges", muscleGroup: "Quads", sets: 3, reps: 12, weight: 40),
        ExerciseTemplate(name: "Leg Curls", muscleGroup: "Hamstrings", sets: 3, reps: 12, weight: 90),
        ExerciseTemplate(name: "Calf Raises", muscleGroup: "Calves", sets: 4, reps: 15, weight: 135),
    ],
    "Full Body": [
        ExerciseTemplate(name: "Deadlift", muscleGroup: "Back", sets: 3, reps: 5, weight: 225),
        ExerciseTemplate(name: "Bench Press", muscleGroup: "Chest", sets: 3, reps: 8, weight: 135),
        ExerciseTemplate(name: "Squat", muscleGroup: "Quads", sets: 3, reps: 8, weight: 185),
        ExerciseTemplate(name: "Overhead Press", muscleGroup: "Shoulders", sets: 3, reps: 8, weight: 95),
        ExerciseTemplate(name: "Barbell Row", muscleGroup: "Back", sets: 3, reps: 8, weight: 135),
    ],
    "Cardio": [
        ExerciseTemplate(name: "Jump Rope", muscleGroup: "Cardio", sets: 5, reps: 60, weight: 0),
        ExerciseTemplate(name: "Burpees", muscleGroup: "Cardio", sets: 4, reps: 15, weight: 0),
        ExerciseTemplate(name: "Mountain Climbers", muscleGroup: "Cardio", sets: 4, reps: 30, weight: 0),
        ExerciseTemplate(name: "Box Jumps", muscleGroup: "Cardio", sets: 4, reps: 12, weight: 0),
    ],
]

// MARK: - Rest Time Defaults

func defaultRestSeconds(for exerciseName: String) -> Int {
    let compound = ["Bench Press", "Squat", "Deadlift", "Overhead Press",
                    "Barbell Row", "Hip Thrusts", "Leg Press", "Romanian Deadlift"]
    let isolation = ["Lateral Raises", "Tricep Pushdowns", "Barbell Curl",
                     "Hammer Curls", "Dumbbell Curls", "Leg Curls",
                     "Calf Raises", "Face Pulls"]
    if compound.contains(exerciseName) { return 120 }
    if isolation.contains(exerciseName) { return 60 }
    return 90
}

// MARK: - Workout Type Metadata

struct WorkoutTypeInfo: Identifiable {
    let id: String
    let name: String
    let icon: String
    let color: Color

    static let all: [WorkoutTypeInfo] = [
        WorkoutTypeInfo(id: "Push", name: "Push", icon: "figure.strengthtraining.traditional", color: WatchColors.deepBlue),
        WorkoutTypeInfo(id: "Pull", name: "Pull", icon: "figure.arms.open", color: WatchColors.vividPurple),
        WorkoutTypeInfo(id: "Legs", name: "Legs", icon: "figure.run", color: WatchColors.success),
        WorkoutTypeInfo(id: "Upper", name: "Upper", icon: "figure.highintensity.intervaltraining", color: WatchColors.deepBlue),
        WorkoutTypeInfo(id: "Lower", name: "Lower", icon: "figure.step.training", color: WatchColors.vividPurple),
        WorkoutTypeInfo(id: "Full Body", name: "Full Body", icon: "figure.cross.training", color: WatchColors.deepBlue),
    ]
}

// MARK: - Helpers

func buildExercises(for type: String) -> [WatchActiveExercise] {
    guard let templates = watchWorkoutTemplates[type] else { return [] }
    return templates.map { template in
        WatchActiveExercise(
            name: template.name,
            muscleGroup: template.muscleGroup,
            sets: (0..<template.sets).map { _ in
                WatchActiveSet(reps: template.reps, weight: template.weight)
            }
        )
    }
}

func formatDuration(_ seconds: Int) -> String {
    let m = seconds / 60
    let s = seconds % 60
    return String(format: "%d:%02d", m, s)
}

func formatVolume(_ volume: Double) -> String {
    if volume >= 1_000_000 { return String(format: "%.1fM", volume / 1_000_000) }
    if volume >= 1_000 { return String(format: "%.1fk", volume / 1_000) }
    return String(format: "%.0f", volume)
}
