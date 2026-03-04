//
//  LeaderboardService.swift
//  GymQuest
//
//  Manages exercise leaderboards within clubs and squad volume leaderboards.
//  Auto-updates e1RM rankings when workouts are saved. Supports weight class
//  and time-based filtering.
//

import Foundation
import SwiftData

@MainActor
class LeaderboardService {
    static let shared = LeaderboardService()

    // MARK: - Exercise Leaderboard (Club)

    /// Build ranked leaderboard for a specific exercise within a club
    func buildExerciseLeaderboard(
        clubId: UUID,
        exerciseName: String,
        timeFilter: LeaderboardTimeFilter = .allTime,
        weightClass: String? = nil,
        modelContext: ModelContext
    ) -> [ExerciseLeaderboardEntry] {
        let descriptor = FetchDescriptor<ExerciseLeaderboardEntry>()
        guard let allEntries = try? modelContext.fetch(descriptor) else { return [] }

        var filtered = allEntries.filter { entry in
            entry.clubId == clubId && entry.exerciseName == exerciseName
        }

        // Apply weight class filter
        if let weightClass = weightClass {
            filtered = filtered.filter { $0.weightClass == weightClass }
        }

        // Apply time filter
        if timeFilter != .allTime {
            let cutoff = timeFilter.cutoffDate
            filtered = filtered.filter { $0.updatedAt >= cutoff }
        }

        // Sort by estimated 1RM descending
        return filtered.sorted { $0.estimated1RM > $1.estimated1RM }
    }

    /// Auto-update leaderboard entries when a workout is saved
    func updateLeaderboardOnWorkoutSave(
        workout: Workout,
        profile: UserProfile,
        clubMemberships: [ClubMembership],
        modelContext: ModelContext
    ) {
        for exercise in workout.exercises {
            guard let topSet = exercise.topSet else { continue }

            // Calculate e1RM using Epley formula
            let e1RM: Double
            if topSet.reps == 1 {
                e1RM = topSet.weight
            } else {
                e1RM = topSet.weight * (1 + Double(topSet.reps) / 30.0)
            }

            // Update entry for each club the user belongs to
            for membership in clubMemberships {
                let descriptor = FetchDescriptor<ExerciseLeaderboardEntry>()
                let allEntries = (try? modelContext.fetch(descriptor)) ?? []

                let existing = allEntries.first { entry in
                    entry.clubId == membership.clubId &&
                    entry.userId == profile.id &&
                    entry.exerciseName == exercise.name
                }

                if let existing = existing {
                    // Only update if new e1RM is higher
                    if e1RM > existing.estimated1RM {
                        existing.estimated1RM = e1RM
                        existing.updatedAt = Date()
                    }
                } else {
                    // Create new entry
                    let entry = ExerciseLeaderboardEntry(
                        clubId: membership.clubId,
                        userId: profile.id,
                        userName: profile.name,
                        exerciseName: exercise.name,
                        estimated1RM: e1RM,
                        weightClass: weightClassFor(profile: profile),
                        updatedAt: Date()
                    )
                    modelContext.insert(entry)
                }
            }
        }
        try? modelContext.save()
    }

    // MARK: - Squad Leaderboard

    /// Build weekly volume leaderboard for squad members
    func buildSquadLeaderboard(
        squad: Squad,
        allWorkouts: [Workout],
        weekStart: Date
    ) -> [SquadMemberVolume] {
        let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart

        var volumes: [SquadMemberVolume] = []

        for memberId in squad.memberIds {
            let memberWorkouts = allWorkouts.filter { workout in
                workout.date >= weekStart &&
                workout.date < weekEnd
            }

            let totalVolume = memberWorkouts.reduce(0.0) { sum, workout in
                sum + workout.exercises.reduce(0.0) { exSum, exercise in
                    exSum + exercise.sets.reduce(0.0) { setSum, set in
                        setSum + set.weight * Double(set.reps)
                    }
                }
            }

            let totalSets = memberWorkouts.reduce(0) { sum, workout in
                sum + workout.exercises.reduce(0) { $0 + $1.sets.count }
            }

            volumes.append(SquadMemberVolume(
                userId: memberId,
                userName: "Member",
                totalVolume: totalVolume,
                totalSets: totalSets,
                workoutCount: memberWorkouts.count,
                weekStart: weekStart
            ))
        }

        return volumes.sorted { $0.totalVolume > $1.totalVolume }
    }

    /// Compare two squads' total weekly volume
    func compareSquads(
        squad1: Squad,
        squad2: Squad,
        allWorkouts: [Workout],
        weekStart: Date
    ) -> (squad1Volume: Double, squad2Volume: Double) {
        let lb1 = buildSquadLeaderboard(squad: squad1, allWorkouts: allWorkouts, weekStart: weekStart)
        let lb2 = buildSquadLeaderboard(squad: squad2, allWorkouts: allWorkouts, weekStart: weekStart)

        let vol1 = lb1.reduce(0) { $0 + $1.totalVolume }
        let vol2 = lb2.reduce(0) { $0 + $1.totalVolume }

        return (vol1, vol2)
    }

    // MARK: - Helpers

    private func weightClassFor(profile: UserProfile) -> String? {
        guard let weightKg = profile.weightKg else { return nil }
        switch weightKg {
        case ..<60: return "< 60kg"
        case 60..<75: return "60-75kg"
        case 75..<90: return "75-90kg"
        case 90..<105: return "90-105kg"
        case 105..<120: return "105-120kg"
        default: return "120kg+"
        }
    }
}

// MARK: - Time Filter

enum LeaderboardTimeFilter: String, CaseIterable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case allTime = "All Time"

    var cutoffDate: Date {
        let calendar = Calendar.current
        switch self {
        case .weekly:
            return calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        case .monthly:
            return calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        case .allTime:
            return .distantPast
        }
    }
}
