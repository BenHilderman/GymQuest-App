//
//  ExerciseHistoryService.swift
//  GymQuest
//
//  Queries past workout data to provide exercise history, personal bests,
//  frequency stats, and recently used exercises.
//

import Foundation
import SwiftData

struct ExerciseHistoryService {
    let modelContext: ModelContext

    /// Last performed set data for a given exercise name
    func lastPerformed(_ exerciseName: String) -> (weight: Double, reps: Int, date: Date)? {
        let workouts = fetchWorkoutsSortedByDate()
        for workout in workouts {
            for exercise in workout.exercises where exercise.name == exerciseName {
                if let topSet = exercise.sets.max(by: { $0.weight < $1.weight }), topSet.weight > 0 {
                    return (weight: topSet.weight, reps: topSet.reps, date: workout.date)
                }
            }
        }
        return nil
    }

    /// Top set ever for a given exercise (heaviest weight)
    func personalBest(_ exerciseName: String) -> (weight: Double, reps: Int)? {
        let workouts = fetchAllWorkouts()
        var best: (weight: Double, reps: Int)?
        for workout in workouts {
            for exercise in workout.exercises where exercise.name == exerciseName {
                if let topSet = exercise.sets.max(by: { $0.weight < $1.weight }), topSet.weight > 0 {
                    if best == nil || topSet.weight > best!.weight {
                        best = (weight: topSet.weight, reps: topSet.reps)
                    }
                }
            }
        }
        return best
    }

    /// Number of times an exercise has been performed (across all workouts)
    func frequencyCount(_ exerciseName: String) -> Int {
        let workouts = fetchAllWorkouts()
        return workouts.reduce(0) { count, workout in
            count + (workout.exercises.contains(where: { $0.name == exerciseName }) ? 1 : 0)
        }
    }

    /// Most used exercise names, sorted by frequency, top N
    func mostUsedExercises(limit: Int = 10) -> [(name: String, count: Int)] {
        let workouts = fetchAllWorkouts()
        var counts: [String: Int] = [:]
        for workout in workouts {
            for exercise in workout.exercises {
                counts[exercise.name, default: 0] += 1
            }
        }
        return counts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { (name: $0.key, count: $0.value) }
    }

    /// Recently used exercise names (last 2 weeks), deduplicated, ordered by recency
    func recentlyUsedExercises(limit: Int = 10) -> [String] {
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let workouts = fetchWorkoutsSortedByDate().filter { $0.date >= twoWeeksAgo }
        var seen = Set<String>()
        var result: [String] = []
        for workout in workouts {
            for exercise in workout.exercises {
                if !seen.contains(exercise.name) {
                    seen.insert(exercise.name)
                    result.append(exercise.name)
                }
            }
        }
        return Array(result.prefix(limit))
    }

    // MARK: - Private Helpers

    private func fetchWorkoutsSortedByDate() -> [Workout] {
        var descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 100
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchAllWorkouts() -> [Workout] {
        let descriptor = FetchDescriptor<Workout>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
