//
//  PRService.swift
//  GymQuest
//
//  Enhanced PR detection service for GymQuest 2.0.
//  Detects weight PRs, rep PRs, volume PRs, and estimated 1RM PRs.
//  Creates PREvent records and PRMoment display objects.
//

import Foundation
import SwiftData

@MainActor
class PRService: ObservableObject {
    static let shared = PRService()

    // MARK: - PR Detection

    /// Comprehensive PR detection across all PR types
    /// Returns both PREvents (for storage) and PRMoments (for display)
    func detectAllPRs(
        workout: Workout,
        allWorkouts: [Workout],
        profile: UserProfile,
        modelContext: ModelContext
    ) -> (events: [PREvent], moments: [PRMoment]) {
        var prEvents: [PREvent] = []
        var prMoments: [PRMoment] = []

        let previousWorkouts = allWorkouts.filter { $0.id != workout.id && $0.date < workout.date }

        for exercise in workout.exercises {
            // Check for weight PR (same rep range, higher weight)
            if let weightPR = detectWeightPR(exercise: exercise, previousWorkouts: previousWorkouts, profile: profile) {
                prEvents.append(weightPR.event)
                prMoments.append(weightPR.moment)
            }

            // Check for rep PR (same weight, more reps)
            if let repPR = detectRepPR(exercise: exercise, previousWorkouts: previousWorkouts, profile: profile) {
                prEvents.append(repPR.event)
                prMoments.append(repPR.moment)
            }

            // Check for volume PR (highest total volume for this exercise in a session)
            if let volumePR = detectVolumePR(exercise: exercise, previousWorkouts: previousWorkouts, profile: profile) {
                prEvents.append(volumePR.event)
                prMoments.append(volumePR.moment)
            }

            // Check for estimated 1RM PR
            if let e1rmPR = detectEstimated1RMPR(exercise: exercise, previousWorkouts: previousWorkouts, profile: profile) {
                prEvents.append(e1rmPR.event)
                prMoments.append(e1rmPR.moment)
            }
        }

        // Check for streak PR (7-day milestones)
        if let streakPR = detectStreakPR(workout: workout, allWorkouts: allWorkouts, profile: profile) {
            prEvents.append(streakPR.event)
            prMoments.append(streakPR.moment)
        }

        // Save PR events to the workout
        for event in prEvents {
            event.workout = workout
            modelContext.insert(event)
        }

        // Save PR moments
        for moment in prMoments {
            modelContext.insert(moment)
        }

        try? modelContext.save()

        return (prEvents, prMoments)
    }

    // MARK: - Weight PR Detection

    /// Detects if user lifted heavier weight at the same rep count
    private func detectWeightPR(
        exercise: Exercise,
        previousWorkouts: [Workout],
        profile: UserProfile
    ) -> (event: PREvent, moment: PRMoment)? {
        guard let bestSet = exercise.sets.max(by: { $0.weight < $1.weight }),
              bestSet.weight > 0,
              bestSet.reps > 0 else { return nil }

        var previousBest: (weight: Double, reps: Int)? = nil

        for workout in previousWorkouts {
            for ex in workout.exercises where ex.name == exercise.name {
                for set in ex.sets where set.reps == bestSet.reps && set.weight > 0 {
                    if previousBest == nil || set.weight > previousBest!.weight {
                        previousBest = (set.weight, set.reps)
                    }
                }
            }
        }

        if let prev = previousBest, bestSet.weight > prev.weight {
            let improvement = bestSet.weight - prev.weight

            let event = PREvent(
                date: Date(),
                exerciseId: exercise.id,
                exerciseName: exercise.name,
                prType: .weightPR,
                newValue: bestSet.weight,
                previousValue: prev.weight,
                delta: improvement,
                deltaDisplay: "+\(Int(improvement)) lbs"
            )

            let moment = PRMoment(
                odId: profile.id,
                odUsername: profile.username,
                prType: .repPR, // Using repPR for display compatibility
                exerciseName: exercise.name,
                value: "\(Int(bestSet.weight)) × \(bestSet.reps)",
                previousValue: "\(Int(prev.weight)) × \(prev.reps)",
                improvement: "+\(Int(improvement)) lbs"
            )

            return (event, moment)
        } else if previousBest == nil && bestSet.weight >= 45 {
            // First recorded lift with meaningful weight
            let event = PREvent(
                date: Date(),
                exerciseId: exercise.id,
                exerciseName: exercise.name,
                prType: .weightPR,
                newValue: bestSet.weight,
                previousValue: nil,
                delta: nil,
                deltaDisplay: "First PR!"
            )

            let moment = PRMoment(
                odId: profile.id,
                odUsername: profile.username,
                prType: .repPR,
                exerciseName: exercise.name,
                value: "\(Int(bestSet.weight)) × \(bestSet.reps)",
                previousValue: nil,
                improvement: "First PR!"
            )

            return (event, moment)
        }

        return nil
    }

    // MARK: - Rep PR Detection

    /// Detects if user did more reps at the same weight
    private func detectRepPR(
        exercise: Exercise,
        previousWorkouts: [Workout],
        profile: UserProfile
    ) -> (event: PREvent, moment: PRMoment)? {
        guard let bestSet = exercise.sets.max(by: { $0.reps < $1.reps }),
              bestSet.weight > 0,
              bestSet.reps > 0 else { return nil }

        var previousBest: (weight: Double, reps: Int)? = nil

        for workout in previousWorkouts {
            for ex in workout.exercises where ex.name == exercise.name {
                for set in ex.sets where set.weight == bestSet.weight && set.reps > 0 {
                    if previousBest == nil || set.reps > previousBest!.reps {
                        previousBest = (set.weight, set.reps)
                    }
                }
            }
        }

        if let prev = previousBest, bestSet.reps > prev.reps {
            let improvement = bestSet.reps - prev.reps

            let event = PREvent(
                date: Date(),
                exerciseId: exercise.id,
                exerciseName: exercise.name,
                prType: .repPR,
                newValue: Double(bestSet.reps),
                previousValue: Double(prev.reps),
                delta: Double(improvement),
                deltaDisplay: "+\(improvement) reps"
            )

            let moment = PRMoment(
                odId: profile.id,
                odUsername: profile.username,
                prType: .repPR,
                exerciseName: exercise.name,
                value: "\(Int(bestSet.weight)) × \(bestSet.reps)",
                previousValue: "\(Int(prev.weight)) × \(prev.reps)",
                improvement: "+\(improvement) reps @ \(Int(bestSet.weight)) lbs"
            )

            return (event, moment)
        }

        return nil
    }

    // MARK: - Volume PR Detection

    /// Detects if user achieved highest total volume for an exercise in a single session
    private func detectVolumePR(
        exercise: Exercise,
        previousWorkouts: [Workout],
        profile: UserProfile
    ) -> (event: PREvent, moment: PRMoment)? {
        let currentVolume = exercise.totalVolume
        guard currentVolume > 0 else { return nil }

        var previousBestVolume: Double = 0

        for workout in previousWorkouts {
            for ex in workout.exercises where ex.name == exercise.name {
                let vol = ex.totalVolume
                if vol > previousBestVolume {
                    previousBestVolume = vol
                }
            }
        }

        // Only trigger if at least 10% improvement and meaningful volume
        let improvementThreshold = 0.10
        let minVolume = 500.0 // Minimum volume to count as PR

        if currentVolume > previousBestVolume * (1 + improvementThreshold) && currentVolume >= minVolume {
            let improvement = currentVolume - previousBestVolume

            let event = PREvent(
                date: Date(),
                exerciseId: exercise.id,
                exerciseName: exercise.name,
                prType: .volumePR,
                newValue: currentVolume,
                previousValue: previousBestVolume > 0 ? previousBestVolume : nil,
                delta: improvement,
                deltaDisplay: "+\(Int(improvement)) lbs volume"
            )

            let moment = PRMoment(
                odId: profile.id,
                odUsername: profile.username,
                prType: .volumePR,
                exerciseName: exercise.name,
                value: "\(Int(currentVolume)) lbs total",
                previousValue: previousBestVolume > 0 ? "\(Int(previousBestVolume)) lbs" : nil,
                improvement: previousBestVolume > 0 ? "+\(Int(improvement)) lbs" : "Volume PR!"
            )

            return (event, moment)
        }

        return nil
    }

    // MARK: - Estimated 1RM PR Detection

    /// Detects if user achieved a new estimated 1RM
    private func detectEstimated1RMPR(
        exercise: Exercise,
        previousWorkouts: [Workout],
        profile: UserProfile
    ) -> (event: PREvent, moment: PRMoment)? {
        // Find current best e1RM
        var currentBestE1RM: Double = 0
        var bestSetForE1RM: ExerciseSet?

        for set in exercise.sets {
            if let e1rm = set.estimated1RM, e1rm > currentBestE1RM {
                currentBestE1RM = e1rm
                bestSetForE1RM = set
            }
        }

        guard currentBestE1RM > 0, let bestSet = bestSetForE1RM else { return nil }

        // Find previous best e1RM
        var previousBestE1RM: Double = 0

        for workout in previousWorkouts {
            for ex in workout.exercises where ex.name == exercise.name {
                for set in ex.sets {
                    if let e1rm = set.estimated1RM, e1rm > previousBestE1RM {
                        previousBestE1RM = e1rm
                    }
                }
            }
        }

        // Only trigger if meaningful improvement (at least 5 lbs)
        let minImprovement = 5.0

        if currentBestE1RM > previousBestE1RM + minImprovement {
            let improvement = currentBestE1RM - previousBestE1RM

            let event = PREvent(
                date: Date(),
                exerciseId: exercise.id,
                exerciseName: exercise.name,
                prType: .estimated1RMPR,
                newValue: currentBestE1RM,
                previousValue: previousBestE1RM > 0 ? previousBestE1RM : nil,
                delta: improvement,
                deltaDisplay: "+\(Int(improvement)) lbs e1RM"
            )

            let moment = PRMoment(
                odId: profile.id,
                odUsername: profile.username,
                prType: .e1rmPR,
                exerciseName: exercise.name,
                value: "e1RM: \(Int(currentBestE1RM)) lbs",
                previousValue: previousBestE1RM > 0 ? "\(Int(previousBestE1RM)) lbs" : nil,
                improvement: previousBestE1RM > 0 ? "+\(Int(improvement)) lbs" : "New e1RM!"
            )

            return (event, moment)
        }

        return nil
    }

    // MARK: - Streak PR Detection

    /// Detects 7-day streak milestones
    private func detectStreakPR(
        workout: Workout,
        allWorkouts: [Workout],
        profile: UserProfile
    ) -> (event: PREvent, moment: PRMoment)? {
        let calendar = Calendar.current
        let sortedWorkouts = allWorkouts.sorted { $0.date > $1.date }

        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        for _ in 0..<365 {
            let hasSession = sortedWorkouts.contains { w in
                calendar.isDate(w.date, inSameDayAs: checkDate)
            }

            if hasSession {
                streak += 1
            } else if streak > 0 {
                break
            }

            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }

        // Calculate previous streak (before this workout)
        let previousWorkouts = allWorkouts.filter { $0.id != workout.id && $0.date < workout.date }
        var previousStreak = 0
        checkDate = calendar.startOfDay(for: workout.date)

        for _ in 0..<365 {
            let hasSession = previousWorkouts.contains { w in
                calendar.isDate(w.date, inSameDayAs: checkDate)
            }

            if hasSession {
                previousStreak += 1
            } else if previousStreak > 0 {
                break
            }

            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }

        // Trigger at 7-day milestones
        if streak >= 7 && streak % 7 == 0 && streak > previousStreak {
            let event = PREvent(
                date: Date(),
                exerciseId: nil,
                exerciseName: "Streak",
                prType: .repPR, // Using repPR for compatibility
                newValue: Double(streak),
                previousValue: Double(previousStreak),
                delta: Double(streak - previousStreak),
                deltaDisplay: "\(streak) days!"
            )

            let moment = PRMoment(
                odId: profile.id,
                odUsername: profile.username,
                prType: .streakPR,
                exerciseName: nil,
                value: "\(streak) day streak",
                previousValue: nil,
                improvement: "New record!"
            )

            return (event, moment)
        }

        return nil
    }

    // MARK: - Workout Summary

    /// Generate a workout summary for shareable cards
    func generateWorkoutSummary(workout: Workout, profile: UserProfile, allWorkouts: [Workout]) -> WorkoutSummary {
        let calendar = Calendar.current
        let sortedWorkouts = allWorkouts.sorted { $0.date > $1.date }

        // Calculate streak
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        for _ in 0..<365 {
            let hasSession = sortedWorkouts.contains { w in
                calendar.isDate(w.date, inSameDayAs: checkDate)
            }

            if hasSession {
                streak += 1
            } else if streak > 0 {
                break
            }

            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }

        // Find top set (highest weight)
        var topSet: TopSetSummary?
        for exercise in workout.exercises {
            if let best = exercise.topSet {
                if topSet == nil || best.weight > (topSet?.weight ?? 0) {
                    topSet = TopSetSummary(
                        exerciseName: exercise.name,
                        weight: best.weight,
                        reps: best.reps,
                        estimated1RM: best.estimated1RM
                    )
                }
            }
        }

        // Calculate weekly sessions
        let weekStart = calendar.startOfWeek(for: Date())
        let weeklyWorkouts = allWorkouts.filter { $0.date >= weekStart }

        // Generate insight
        let insight = generateInsight(workout: workout, streak: streak, weeklyWorkouts: weeklyWorkouts)

        return WorkoutSummary(
            workoutId: workout.id,
            date: workout.date,
            type: workout.type,
            duration: workout.duration,
            totalSets: workout.totalSets,
            totalVolume: workout.totalVolume,
            topSet: topSet,
            streak: streak,
            xpEarned: workout.xpValue,
            prCount: workout.prEvents.count,
            insight: insight
        )
    }

    /// Generate a contextual insight for the workout
    private func generateInsight(workout: Workout, streak: Int, weeklyWorkouts: [Workout]) -> String {
        // Streak-based insights
        if streak >= 14 {
            return "Two-week streak! Consistency is building real progress."
        } else if streak == 7 {
            return "One week down! Keep this momentum going."
        }

        // Volume-based insights
        let weeklyVolume = weeklyWorkouts.reduce(0.0) { $0 + $1.totalVolume }
        if weeklyVolume > 50000 {
            return "High volume week. Make sure you're recovering properly."
        }

        // RPE-based insights
        if workout.rpe >= 9 {
            return "That was a grind. Prioritize sleep and nutrition today."
        } else if workout.rpe <= 6 {
            return "Light session logged. Good for recovery days."
        }

        // Session count insights
        if weeklyWorkouts.count >= 5 {
            return "5+ sessions this week. You're locked in."
        }

        // Default workout-type based insights
        switch workout.type {
        case .push:
            return "Pressing work done. Shoulders and triceps got volume."
        case .pull:
            return "Back and biceps hit. Balance this with push volume."
        case .legs:
            return "Lower body session complete. Legs drive total-body strength."
        case .upper:
            return "Upper body trained. Keep push/pull ratio balanced."
        case .lower:
            return "Legs done. Don't skip the stretching."
        case .fullBody:
            return "Full body stimulus. Great for strength and efficiency."
        case .cardio:
            return "Conditioning logged. Heart health matters too."
        case .rest:
            return "Recovery counts. Active rest accelerates progress."
        case .glutes:
            return "Glute work logged. Progressive overload is key."
        case .abs:
            return "Core training done. Strong core supports all lifts."
        case .custom:
            return "Custom workout complete. Keep showing up."
        }
    }
}

// MARK: - Workout Summary Model

struct WorkoutSummary {
    let workoutId: UUID
    let date: Date
    let type: WorkoutType
    let duration: Int
    let totalSets: Int
    let totalVolume: Double
    let topSet: TopSetSummary?
    let streak: Int
    let xpEarned: Int
    let prCount: Int
    let insight: String

    var formattedVolume: String {
        if totalVolume >= 1000 {
            return String(format: "%.1fk lbs", totalVolume / 1000)
        }
        return "\(Int(totalVolume)) lbs"
    }
}
