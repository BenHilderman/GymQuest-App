//
//  SquadService.swift
//  GymQuest
//
//  Squad management service for GymQuest 2.0.
//  Handles squad creation, challenges, leaderboards, and member management.
//

import Foundation
import SwiftData

@MainActor
class SquadService: ObservableObject {
    static let shared = SquadService()

    private var modelContext: ModelContext?

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Squad Management

    /// Create a new squad
    func createSquad(name: String, creatorId: UUID, weeklyGoal: WeeklyGoal = WeeklyGoal()) -> Squad? {
        guard let context = modelContext else { return nil }

        let squad = Squad(
            name: name,
            creatorId: creatorId,
            memberIds: [creatorId],
            weeklyGoal: weeklyGoal
        )

        context.insert(squad)
        try? context.save()

        // Sync to Supabase
        if FeatureFlags.shared.supabaseSyncEnabled {
            Task {
                do {
                    let dto = SquadDTO(
                        id: squad.id,
                        name: squad.name,
                        creatorId: SupabaseAuthService.shared.currentUserId ?? squad.creatorId,
                        memberIds: squad.memberIds,
                        inviteCode: squad.inviteCode,
                        streakWeeks: squad.streakWeeks,
                        xpMultiplier: squad.xpMultiplier,
                        createdAt: squad.createdAt,
                        updatedAt: squad.createdAt
                    )
                    try await SupabaseSyncService.shared.insert(dto, table: "squads")
                } catch {
                    print("[SquadService] Supabase sync failed: \(error)")
                }
            }
        }

        // Track analytics
        AnalyticsService.shared.trackSquadCreated(
            userId: creatorId,
            squadId: squad.id
        )

        return squad
    }

    /// Join a squad via invite code
    func joinSquad(inviteCode: String, userId: UUID) -> (success: Bool, squad: Squad?, error: String?) {
        guard let context = modelContext else {
            return (false, nil, "Database not available")
        }

        let codeUpper = inviteCode.uppercased()
        let descriptor = FetchDescriptor<Squad>(
            predicate: #Predicate { $0.inviteCode == codeUpper }
        )

        guard let squad = (try? context.fetch(descriptor))?.first else {
            return (false, nil, "Squad not found")
        }

        if squad.memberIds.contains(userId) {
            return (false, squad, "Already a member")
        }

        if squad.isFull {
            return (false, squad, "Squad is full (max 6 members)")
        }

        squad.memberIds.append(userId)
        try? context.save()

        // Track analytics
        AnalyticsService.shared.trackSquadJoined(
            userId: userId,
            squadId: squad.id
        )

        return (true, squad, nil)
    }

    /// Leave a squad
    func leaveSquad(squadId: UUID, userId: UUID) -> Bool {
        guard let context = modelContext else { return false }

        let descriptor = FetchDescriptor<Squad>(
            predicate: #Predicate { $0.id == squadId }
        )

        guard let squad = (try? context.fetch(descriptor))?.first else {
            return false
        }

        // Creator cannot leave (must delete squad)
        if squad.creatorId == userId {
            return false
        }

        squad.memberIds.removeAll { $0 == userId }
        try? context.save()

        return true
    }

    /// Delete a squad (creator only)
    func deleteSquad(squadId: UUID, userId: UUID) -> Bool {
        guard let context = modelContext else { return false }

        let descriptor = FetchDescriptor<Squad>(
            predicate: #Predicate { $0.id == squadId }
        )

        guard let squad = (try? context.fetch(descriptor))?.first,
              squad.creatorId == userId else {
            return false
        }

        context.delete(squad)
        try? context.save()

        return true
    }

    /// Get user's squads
    func getUserSquads(userId: UUID) -> [Squad] {
        guard let context = modelContext else { return [] }

        let descriptor = FetchDescriptor<Squad>()

        guard let allSquads = try? context.fetch(descriptor) else {
            return []
        }

        return allSquads.filter { $0.memberIds.contains(userId) }
    }

    /// Get squad by ID
    func getSquad(squadId: UUID) -> Squad? {
        guard let context = modelContext else { return nil }

        let descriptor = FetchDescriptor<Squad>(
            predicate: #Predicate { $0.id == squadId }
        )

        return (try? context.fetch(descriptor))?.first
    }

    // MARK: - Challenge Management

    /// Start a weekly challenge for a squad
    func startChallenge(
        squadId: UUID,
        title: String,
        description: String,
        targetValue: Int,
        xpReward: Int = 100
    ) -> SquadChallenge? {
        guard let context = modelContext else { return nil }

        // Get the squad
        let squadDescriptor = FetchDescriptor<Squad>(
            predicate: #Predicate { $0.id == squadId }
        )
        guard let squad = (try? context.fetch(squadDescriptor))?.first else { return nil }

        // Create the challenge
        let challenge = SquadChallenge(
            squadId: squadId,
            title: title,
            challengeDescription: description,
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
            targetValue: targetValue,
            xpReward: xpReward
        )

        context.insert(challenge)
        squad.activeChallengeId = challenge.id
        try? context.save()

        // Track analytics
        AnalyticsService.shared.trackChallengeStarted(
            squadId: squadId,
            challengeId: challenge.id
        )

        return challenge
    }

    /// Get active challenge for a squad
    func getActiveChallenge(squadId: UUID) -> SquadChallenge? {
        guard let context = modelContext else { return nil }

        let descriptor = FetchDescriptor<SquadChallenge>(
            predicate: #Predicate {
                $0.squadId == squadId && $0.isCompleted == false
            },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )

        guard let challenge = (try? context.fetch(descriptor))?.first else { return nil }

        // Check if expired
        if challenge.endDate < Date() {
            challenge.isCompleted = true
            try? context.save()
            return nil
        }

        return challenge
    }

    /// Update challenge progress
    func updateChallengeProgress(squadId: UUID, addedValue: Int) {
        guard let context = modelContext,
              let challenge = getActiveChallenge(squadId: squadId) else { return }

        challenge.currentValue += addedValue

        // Check if completed
        if challenge.currentValue >= challenge.targetValue && !challenge.isCompleted {
            completeChallenge(challenge)
        }

        try? context.save()
    }

    private func completeChallenge(_ challenge: SquadChallenge) {
        guard let context = modelContext else { return }

        challenge.isCompleted = true

        // Get squad to award XP to all members
        let squadId = challenge.squadId
        let squadDescriptor = FetchDescriptor<Squad>(
            predicate: #Predicate { $0.id == squadId }
        )
        guard let squad = (try? context.fetch(squadDescriptor))?.first else { return }

        // Award XP to each member
        for memberId in squad.memberIds {
            let memberIdToFind = memberId
            let profileDescriptor = FetchDescriptor<UserProfile>(
                predicate: #Predicate { $0.id == memberIdToFind }
            )
            if let profile = (try? context.fetch(profileDescriptor))?.first {
                _ = profile.addXP(challenge.xpReward)
            }
        }

        // Increment squad streak
        squad.streakWeeks += 1

        try? context.save()

        // Track analytics
        AnalyticsService.shared.trackChallengeCompleted(
            squadId: squad.id,
            challengeId: challenge.id,
            xpEarned: challenge.xpReward
        )
    }

    // MARK: - Leaderboard

    /// Get leaderboard for a squad (weekly totals)
    func getSquadLeaderboard(squadId: UUID) -> [SquadMemberStats] {
        guard let context = modelContext else { return [] }

        let squadDescriptor = FetchDescriptor<Squad>(
            predicate: #Predicate { $0.id == squadId }
        )
        guard let squad = (try? context.fetch(squadDescriptor))?.first else { return [] }

        let weekStart = Calendar.current.startOfWeek(for: Date())

        var leaderboard: [SquadMemberStats] = []

        for memberId in squad.memberIds {
            // Get member profile
            let profileDescriptor = FetchDescriptor<UserProfile>(
                predicate: #Predicate { $0.id == memberId }
            )
            guard let profile = (try? context.fetch(profileDescriptor))?.first else { continue }

            // Get member's workouts this week
            let workoutDescriptor = FetchDescriptor<Workout>(
                predicate: #Predicate { $0.date >= weekStart }
            )
            // Note: In a real app, workouts would be filtered by userId
            let allWorkouts = (try? context.fetch(workoutDescriptor)) ?? []
            let memberWorkouts = allWorkouts.filter { _ in true } // Placeholder for user filtering

            let weeklyStats = SquadMemberStats(
                userId: memberId,
                username: profile.username,
                profilePhotoData: profile.profilePhotoData,
                sessionsThisWeek: memberWorkouts.count,
                totalVolume: Int(memberWorkouts.reduce(0.0) { $0 + $1.totalVolume }),
                currentStreak: 0, // Calculate separately if needed
                level: profile.level
            )

            leaderboard.append(weeklyStats)
        }

        // Sort by sessions, then by volume
        return leaderboard.sorted {
            if $0.sessionsThisWeek != $1.sessionsThisWeek {
                return $0.sessionsThisWeek > $1.sessionsThisWeek
            }
            return $0.totalVolume > $1.totalVolume
        }
    }

    /// Get squad activity feed (recent workouts from members)
    func getSquadActivity(squadId: UUID, limit: Int = 20) -> [Workout] {
        guard let context = modelContext else { return [] }

        let squadDescriptor = FetchDescriptor<Squad>(
            predicate: #Predicate { $0.id == squadId }
        )
        guard let squad = (try? context.fetch(squadDescriptor))?.first else { return [] }

        let workoutDescriptor = FetchDescriptor<Workout>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        guard let allWorkouts = try? context.fetch(workoutDescriptor) else { return [] }

        // Filter to squad members only
        // Note: In production, workouts would have a userId field
        return Array(allWorkouts.prefix(limit))
    }
}

// MARK: - Squad Member Stats

struct SquadMemberStats: Identifiable {
    var id: UUID { userId }
    let userId: UUID
    let username: String
    let profilePhotoData: Data?
    let sessionsThisWeek: Int
    let totalVolume: Int
    let currentStreak: Int
    let level: Int
}

// MARK: - Analytics Extensions

extension AnalyticsService {
    func trackSquadCreated(userId: UUID, squadId: UUID) {
        trackEvent(
            eventName: "squad_created",
            properties: [
                "user_id": userId.uuidString,
                "squad_id": squadId.uuidString
            ]
        )
    }

    func trackSquadJoined(userId: UUID, squadId: UUID) {
        trackEvent(
            eventName: "squad_joined",
            properties: [
                "user_id": userId.uuidString,
                "squad_id": squadId.uuidString
            ]
        )
    }

    func trackChallengeStarted(squadId: UUID, challengeId: UUID) {
        trackEvent(
            eventName: "challenge_started",
            properties: [
                "squad_id": squadId.uuidString,
                "challenge_id": challengeId.uuidString
            ]
        )
    }

    func trackChallengeCompleted(squadId: UUID, challengeId: UUID, xpEarned: Int) {
        trackEvent(
            eventName: "challenge_completed",
            properties: [
                "squad_id": squadId.uuidString,
                "challenge_id": challengeId.uuidString,
                "xp_earned": "\(xpEarned)"
            ]
        )
    }
}
