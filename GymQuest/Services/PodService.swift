//
//  PodService.swift
//  GymQuest
//
//  Pod System (System 2) — matching, enrollment, lifecycle
//  management, streak tracking, and leader assignment for
//  small accountability pods.
//

import Foundation
import SwiftData

// MARK: - Pod Preferences

struct PodPreferences {
    var schedulePreference: String
    var trainingStyle: String
    var level: PodLevel

    init(
        schedulePreference: String = "Flexible",
        trainingStyle: String = "General",
        level: PodLevel = .beginner
    ) {
        self.schedulePreference = schedulePreference
        self.trainingStyle = trainingStyle
        self.level = level
    }
}

// MARK: - Pod Service

@MainActor
class PodService: ObservableObject {
    static let shared = PodService()
    private var modelContext: ModelContext?

    private init() {}

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Matching Weights

    private enum MatchWeight {
        static let trainingTime: Double = 0.35
        static let daysPerWeek: Double = 0.30
        static let gymType: Double = 0.20
        static let confidence: Double = 0.15
    }

    // MARK: - Match & Enroll

    /// Find the best-fit open pod for a user's profile, or create a new one.
    @discardableResult
    func matchAndEnroll(userId: UUID, profile: BeginnerSupportProfile) -> Pod? {
        guard let ctx = modelContext else { return nil }

        // Fetch all non-full, non-dead pods with open visibility
        let descriptor = FetchDescriptor<Pod>()
        guard let allPods = try? ctx.fetch(descriptor) else { return nil }

        let candidates = allPods.filter { pod in
            !pod.isFull
            && pod.lifecycleState != .dead
            && pod.podVisibility == .open
        }

        var bestPod: Pod?
        var bestScore: Double = -1

        for pod in candidates {
            let score = matchScore(pod: pod, profile: profile)
            if score > bestScore {
                bestScore = score
                bestPod = pod
            }
        }

        if let pod = bestPod {
            joinPod(podId: pod.id, userId: userId, isPrimary: true)
            return pod
        }

        // No match — create a new pod with the user as first member
        let preferences = PodPreferences(
            schedulePreference: profile.preferredTrainingTime.capitalized,
            trainingStyle: "General",
            level: confidenceToLevel(profile.confidenceLevel)
        )
        return createPod(userId: userId, name: generatePodName(), preferences: preferences)
    }

    // MARK: - Create Pod

    @discardableResult
    func createPod(userId: UUID, name: String, preferences: PodPreferences) -> Pod? {
        guard let ctx = modelContext else { return nil }

        let pod = Pod(
            name: name,
            creatorId: userId,
            memberIds: [userId],
            level: preferences.level,
            schedulePreference: preferences.schedulePreference,
            trainingStyle: preferences.trainingStyle,
            autoCreated: true
        )
        ctx.insert(pod)

        let membership = PodMembership(
            podId: pod.id,
            userId: userId,
            role: .leader,
            isPrimaryPod: true
        )
        ctx.insert(membership)

        try? ctx.save()

        // Sync to Supabase
        if FeatureFlags.shared.supabaseSyncEnabled {
            Task {
                do {
                    let dto = PodDTO(
                        id: pod.id,
                        name: pod.name,
                        creatorId: SupabaseAuthService.shared.currentUserId ?? pod.creatorId,
                        memberIds: pod.memberIds,
                        inviteCode: pod.inviteCode,
                        level: pod.level,
                        lifecycle: pod.lifecycle,
                        maxMembers: pod.maxMembers,
                        weeklyWorkoutTarget: pod.weeklyWorkoutTarget,
                        streakWeeks: pod.streakWeeks,
                        createdAt: pod.createdAt,
                        updatedAt: pod.createdAt
                    )
                    try await SupabaseSyncService.shared.insert(dto, table: "pods")
                } catch {
                    print("[PodService] Supabase sync failed: \(error)")
                }
            }
        }

        return pod
    }

    // MARK: - Check-In

    func checkIn(podId: UUID, userId: UUID, type: PodCheckInType, workoutId: UUID? = nil) {
        guard let ctx = modelContext else { return }

        let checkInRecord = PodCheckIn(
            podId: podId,
            userId: userId,
            type: type,
            workoutId: workoutId
        )
        ctx.insert(checkInRecord)

        // Update pod's last activity date
        if let pod = fetchPod(id: podId, context: ctx) {
            pod.lastActivityDate = Date()
        }

        try? ctx.save()
    }

    // MARK: - Lifecycle Evaluation

    /// Check all pods for stale/dead transitions based on last activity.
    func evaluateLifecycles() {
        guard let ctx = modelContext else { return }

        let descriptor = FetchDescriptor<Pod>()
        guard let allPods = try? ctx.fetch(descriptor) else { return }

        let now = Date()

        for pod in allPods {
            guard pod.lifecycleState != .dead else { continue }

            let daysSinceActivity: Int
            if let lastActivity = pod.lastActivityDate {
                daysSinceActivity = Calendar.current.dateComponents(
                    [.day], from: lastActivity, to: now
                ).day ?? 0
            } else {
                daysSinceActivity = Calendar.current.dateComponents(
                    [.day], from: pod.createdAt, to: now
                ).day ?? 0
            }

            if daysSinceActivity >= 28 {
                pod.lifecycleState = .dead
            } else if daysSinceActivity >= 14 {
                pod.lifecycleState = .stale
            } else if pod.memberCount >= 3 {
                pod.lifecycleState = .active
            }
            // 1-2 members stays .forming unless stale/dead
        }

        try? ctx.save()
    }

    // MARK: - Migration

    /// If the user's current primary pod is stale and they've been on-track 4+ weeks,
    /// find a better pod to migrate to.
    func offerMigration(userId: UUID) -> Pod? {
        guard let ctx = modelContext else { return nil }

        // Check user is on-track 4+ weeks
        guard let momentum = fetchMomentum(userId: userId, context: ctx),
              momentum.consistencyState == .onTrack,
              momentum.streak >= 4 else {
            return nil
        }

        // Check primary pod is stale
        guard let primaryPod = getPrimaryPod(userId: userId),
              primaryPod.lifecycleState == .stale else {
            return nil
        }

        // Find a better active pod
        let descriptor = FetchDescriptor<Pod>()
        guard let allPods = try? ctx.fetch(descriptor) else { return nil }

        let candidates = allPods.filter { pod in
            pod.id != primaryPod.id
            && !pod.isFull
            && pod.lifecycleState == .active
            && pod.podVisibility == .open
        }

        // Return the pod with the most members (most active community)
        return candidates.max(by: { $0.memberCount < $1.memberCount })
    }

    // MARK: - Streak

    /// Called on week rollover. Increments streak if ALL members hit target,
    /// preserves (but doesn't increment) if exactly one member missed.
    func updatePodStreak(podId: UUID) {
        guard let ctx = modelContext else { return }
        guard let pod = fetchPod(id: podId, context: ctx) else { return }

        let memberships = fetchMemberships(podId: podId, context: ctx)
        guard !memberships.isEmpty else { return }

        let missedCount = memberships.filter {
            $0.weeklyCompletedWorkouts < pod.weeklyWorkoutTarget
        }.count

        if missedCount == 0 {
            // All members hit target — streak increments
            pod.streakWeeks += 1
        } else if missedCount == 1 && memberships.count >= 5 {
            // 4/5+ hit target — forgiveness: streak preserved, no increment
        } else {
            // Streak broken
            pod.streakWeeks = 0
        }

        // Reset weekly counts for next week
        for membership in memberships {
            membership.weeklyCompletedWorkouts = 0
        }

        try? ctx.save()
    }

    // MARK: - Leader Assignment

    /// Auto-assign leader when pod reaches 3+ members.
    /// Picks the member with the most weeklyCompletedWorkouts.
    func autoAssignLeader(podId: UUID) {
        guard let ctx = modelContext else { return }
        guard let pod = fetchPod(id: podId, context: ctx),
              pod.memberCount >= 3 else { return }

        let memberships = fetchMemberships(podId: podId, context: ctx)

        // Check if there's already a leader
        let hasLeader = memberships.contains { $0.podRole == .leader }
        guard !hasLeader else { return }

        // Assign the most active member as leader
        if let mostActive = memberships.max(by: {
            $0.weeklyCompletedWorkouts < $1.weeklyCompletedWorkouts
        }) {
            mostActive.role = PodRole.leader.rawValue
            try? ctx.save()
        }
    }

    // MARK: - Join / Leave

    func joinPod(podId: UUID, userId: UUID, isPrimary: Bool) {
        guard let ctx = modelContext else { return }
        guard let pod = fetchPod(id: podId, context: ctx),
              !pod.isFull,
              !pod.memberIds.contains(userId) else { return }

        // Enforce max 2 pods per user
        guard getUserPodCount(userId: userId) < 2 else { return }

        // If joining as primary, clear existing primary
        if isPrimary {
            clearPrimaryPod(userId: userId, context: ctx)
        }

        // Add to pod
        pod.memberIds.append(userId)

        let membership = PodMembership(
            podId: podId,
            userId: userId,
            role: .member,
            isPrimaryPod: isPrimary
        )
        ctx.insert(membership)

        // Update lifecycle if we hit 3 members
        if pod.memberCount >= 3 && pod.lifecycleState == .forming {
            pod.lifecycleState = .active
            autoAssignLeader(podId: podId)
        }

        try? ctx.save()
    }

    func leavePod(podId: UUID, userId: UUID) {
        guard let ctx = modelContext else { return }
        guard let pod = fetchPod(id: podId, context: ctx) else { return }

        pod.memberIds.removeAll { $0 == userId }

        // Remove membership
        let memberships = fetchMemberships(podId: podId, context: ctx)
        if let membership = memberships.first(where: { $0.userId == userId }) {
            ctx.delete(membership)
        }

        // If pod is now empty, mark as dead
        if pod.memberIds.isEmpty {
            pod.lifecycleState = .dead
        }
        // If leader left and pod still has 3+ members, reassign
        else if pod.memberCount >= 3 {
            let remaining = fetchMemberships(podId: podId, context: ctx)
            let hasLeader = remaining.contains { $0.podRole == .leader }
            if !hasLeader {
                autoAssignLeader(podId: podId)
            }
        }
        // Drop back to forming if under 3
        else if pod.memberCount < 3 && pod.lifecycleState == .active {
            pod.lifecycleState = .forming
        }

        try? ctx.save()
    }

    // MARK: - Queries

    func getPrimaryPod(userId: UUID) -> Pod? {
        guard let ctx = modelContext else { return nil }

        let descriptor = FetchDescriptor<PodMembership>()
        guard let memberships = try? ctx.fetch(descriptor) else { return nil }

        guard let primary = memberships.first(where: {
            $0.userId == userId && $0.isPrimaryPod
        }) else { return nil }

        return fetchPod(id: primary.podId, context: ctx)
    }

    func getUserPodCount(userId: UUID) -> Int {
        guard let ctx = modelContext else { return 0 }

        let descriptor = FetchDescriptor<PodMembership>()
        guard let memberships = try? ctx.fetch(descriptor) else { return 0 }

        return memberships.filter { $0.userId == userId }.count
    }

    // MARK: - Private Helpers

    private func matchScore(pod: Pod, profile: BeginnerSupportProfile) -> Double {
        var score: Double = 0

        // Training time match (0.35)
        let podTime = pod.schedulePreference.lowercased()
        let userTime = profile.preferredTrainingTime.lowercased()
        if podTime == userTime || podTime == "flexible" || userTime == "flexible" {
            score += MatchWeight.trainingTime
        } else if podTime.hasPrefix(userTime.prefix(3)) {
            score += MatchWeight.trainingTime * 0.5
        }

        // Days per week match (0.30) — compare pod target to user's preferred days
        let daysDiff = abs(pod.weeklyWorkoutTarget - profile.daysPerWeek)
        if daysDiff == 0 {
            score += MatchWeight.daysPerWeek
        } else if daysDiff == 1 {
            score += MatchWeight.daysPerWeek * 0.7
        } else if daysDiff == 2 {
            score += MatchWeight.daysPerWeek * 0.3
        }

        // Gym type match (0.20)
        let podStyle = pod.trainingStyle.lowercased()
        let userGym = profile.gymType.lowercased()
        if podStyle == "general" || podStyle == userGym {
            score += MatchWeight.gymType
        }

        // Confidence level match (0.15) — map to pod level
        let userLevel = confidenceToLevel(profile.confidenceLevel)
        if pod.podLevel == userLevel {
            score += MatchWeight.confidence
        } else {
            // Adjacent levels get partial credit
            let podIdx = PodLevel.allCases.firstIndex(of: pod.podLevel) ?? 0
            let userIdx = PodLevel.allCases.firstIndex(of: userLevel) ?? 0
            if abs(podIdx - userIdx) == 1 {
                score += MatchWeight.confidence * 0.5
            }
        }

        return score
    }

    private func confidenceToLevel(_ confidence: Int) -> PodLevel {
        switch confidence {
        case 1...2: return .beginner
        case 3: return .intermediate
        case 4...5: return .advanced
        default: return .beginner
        }
    }

    private func generatePodName() -> String {
        let adjectives = [
            "Iron", "Steady", "Rising", "Strong", "Focused",
            "Relentless", "Gritty", "Bold", "Driven", "Solid"
        ]
        let nouns = [
            "Squad", "Crew", "Pack", "Unit", "Team",
            "Force", "Circle", "Alliance", "Collective", "Core"
        ]
        let adj = adjectives.randomElement() ?? "Strong"
        let noun = nouns.randomElement() ?? "Squad"
        return "\(adj) \(noun)"
    }

    private func fetchPod(id: UUID, context: ModelContext) -> Pod? {
        let descriptor = FetchDescriptor<Pod>()
        guard let pods = try? context.fetch(descriptor) else { return nil }
        return pods.first { $0.id == id }
    }

    private func fetchMemberships(podId: UUID, context: ModelContext) -> [PodMembership] {
        let descriptor = FetchDescriptor<PodMembership>()
        guard let all = try? context.fetch(descriptor) else { return [] }
        return all.filter { $0.podId == podId }
    }

    private func fetchMomentum(userId: UUID, context: ModelContext) -> UserMomentumState? {
        let descriptor = FetchDescriptor<UserMomentumState>()
        guard let all = try? context.fetch(descriptor) else { return nil }
        return all.first { $0.userId == userId }
    }

    private func clearPrimaryPod(userId: UUID, context: ModelContext) {
        let descriptor = FetchDescriptor<PodMembership>()
        guard let memberships = try? context.fetch(descriptor) else { return }
        for m in memberships where m.userId == userId && m.isPrimaryPod {
            m.isPrimaryPod = false
        }
    }
}
