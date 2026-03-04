//
//  ProgressiveOverloadService.swift
//  GymQuest
//
//  Smart progressive overload suggestions based on RPE trends and rep performance.
//  Analyzes last 3-4 sessions per exercise to recommend weight/rep adjustments.
//

import Foundation
import SwiftData

// MARK: - Overload Suggestion

struct OverloadSuggestion {
    let exerciseName: String
    let suggestedWeight: Double
    let suggestedReps: Int
    let reason: String
    let confidence: OverloadConfidence
    let direction: OverloadDirection
}

enum OverloadConfidence: String {
    case high   // 3+ sessions of data
    case medium // 1-2 sessions
    case low    // First time / insufficient data
}

enum OverloadDirection {
    case increase
    case hold
    case decrease
}

// MARK: - Service

@MainActor
class ProgressiveOverloadService {
    static let shared = ProgressiveOverloadService()

    /// Get progressive overload suggestions for a list of exercises based on workout history
    func getSuggestions(
        exercises: [ActiveExercise],
        allWorkouts: [Workout],
        profile: UserProfile
    ) -> [String: OverloadSuggestion] {
        var suggestions: [String: OverloadSuggestion] = [:]

        for exercise in exercises {
            if let suggestion = analyzExercise(
                name: exercise.name,
                allWorkouts: allWorkouts,
                profile: profile
            ) {
                suggestions[exercise.name] = suggestion
            }
        }

        return suggestions
    }

    /// Analyze a single exercise across recent sessions
    private func analyzExercise(
        name: String,
        allWorkouts: [Workout],
        profile: UserProfile
    ) -> OverloadSuggestion? {
        // Find recent sessions containing this exercise (last 4)
        let relevantWorkouts = allWorkouts
            .sorted { $0.date > $1.date }
            .filter { workout in
                workout.exercises.contains { $0.name == name }
            }
            .prefix(4)

        guard !relevantWorkouts.isEmpty else {
            return nil
        }

        let sessions = Array(relevantWorkouts)
        let confidence: OverloadConfidence = sessions.count >= 3 ? .high : (sessions.count >= 1 ? .medium : .low)

        // Get the most recent session's top set
        guard let lastWorkout = sessions.first,
              let lastExercise = lastWorkout.exercises.first(where: { $0.name == name }),
              let topSet = lastExercise.topSet else {
            return nil
        }

        let lastWeight = topSet.weight
        let lastReps = topSet.reps
        let lastRPE = topSet.rpe

        // Determine if this is a barbell or dumbbell exercise
        let isBarbell = isBarbellExercise(name)
        let increment = isBarbell ? 5.0 : 2.5

        // Apply RPE-based rules
        if let rpe = lastRPE {
            if rpe <= 7 {
                // Easy — increase weight
                let newWeight = lastWeight + increment
                return OverloadSuggestion(
                    exerciseName: name,
                    suggestedWeight: newWeight,
                    suggestedReps: lastReps,
                    reason: "RPE \(rpe) last session — ready for more weight",
                    confidence: confidence,
                    direction: .increase
                )
            } else if rpe == 8 {
                // Moderate — same weight, add a rep
                return OverloadSuggestion(
                    exerciseName: name,
                    suggestedWeight: lastWeight,
                    suggestedReps: lastReps + 1,
                    reason: "RPE 8 — add one rep at same weight",
                    confidence: confidence,
                    direction: .increase
                )
            } else if rpe >= 9 {
                // Hard — hold steady
                return OverloadSuggestion(
                    exerciseName: name,
                    suggestedWeight: lastWeight,
                    suggestedReps: lastReps,
                    reason: "RPE \(rpe) — consolidate at current weight",
                    confidence: confidence,
                    direction: .hold
                )
            }
        }

        // Check for missed reps (completed fewer reps than target in recent sessions)
        if sessions.count >= 2 {
            let previousWorkout = sessions[1]
            if let previousExercise = previousWorkout.exercises.first(where: { $0.name == name }),
               let previousTopSet = previousExercise.topSet {
                if lastReps < previousTopSet.reps && lastWeight >= previousTopSet.weight {
                    // Missed reps — decrease weight
                    let newWeight = max(0, lastWeight - increment)
                    return OverloadSuggestion(
                        exerciseName: name,
                        suggestedWeight: newWeight,
                        suggestedReps: previousTopSet.reps,
                        reason: "Rep count dropped — lower weight to rebuild",
                        confidence: confidence,
                        direction: .decrease
                    )
                }
            }
        }

        // Default: try small increase
        return OverloadSuggestion(
            exerciseName: name,
            suggestedWeight: lastWeight + increment,
            suggestedReps: lastReps,
            reason: "Progressive overload — small weight increase",
            confidence: confidence,
            direction: .increase
        )
    }

    private func isBarbellExercise(_ name: String) -> Bool {
        let barbellKeywords = ["barbell", "bench press", "squat", "deadlift", "overhead press",
                               "bent over row", "barbell row", "clean", "snatch", "front squat"]
        let lowered = name.lowercased()
        return barbellKeywords.contains { lowered.contains($0) }
    }
}
