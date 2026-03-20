import Foundation
import SwiftData

@MainActor
class ChallengeService: ObservableObject {

    static let shared = ChallengeService()

    private var modelContext: ModelContext?

    private init() {}

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Limits

    private let maxActiveIndividual = 3
    private let maxActivePod = 1
    private let maxActiveClub = 2
    private let partialCreditThreshold = 0.8
    private let partialCreditXPMultiplier = 0.5

    // MARK: - Auto Enrollment

    func autoEnroll(userId: UUID, consistencyState: ConsistencyState) {
        guard let context = modelContext else { return }

        let currentIndividualCount = getActiveIndividualCount(userId: userId)
        guard currentIndividualCount < maxActiveIndividual else { return }

        let templates = seedTemplates().filter { template in
            template.scope == .individual &&
            (template.requiredConsistencyState == nil || template.requiredConsistencyState == consistencyState)
        }

        // Find templates the user is not already enrolled in
        let activeEnrollments = getActiveChallenges(userId: userId)
        let activeChallengeIds = Set(activeEnrollments.compactMap { enrollment -> UUID? in
            let challenge = fetchChallenge(by: enrollment.challengeId)
            return challenge?.templateId
        })

        let available = templates.filter { !activeChallengeIds.contains($0.id) }
        let slotsRemaining = maxActiveIndividual - currentIndividualCount

        for template in available.prefix(slotsRemaining) {
            let now = Date()
            let endDate = Calendar.current.date(byAdding: .day, value: template.durationDays, to: now) ?? now

            let challenge = Challenge(
                templateId: template.id,
                scope: .individual,
                title: template.title,
                challengeDescription: template.description,
                goalType: template.goalType,
                goalTarget: template.goalTarget,
                startDate: now,
                endDate: endDate,
                xpReward: template.xpReward
            )
            context.insert(challenge)

            let enrollment = ChallengeEnrollment(
                challengeId: challenge.id,
                userId: userId
            )
            context.insert(enrollment)
        }

        try? context.save()
    }

    // MARK: - Progress Updates

    func updateProgress(userId: UUID, workout: Workout) {
        guard let context = modelContext else { return }

        let enrollments = getActiveChallenges(userId: userId)

        for enrollment in enrollments {
            guard let challenge = fetchChallenge(by: enrollment.challengeId),
                  challenge.isActive else { continue }

            let increment: Int
            switch challenge.goalType {
            case .workouts:
                increment = 1
            case .sets:
                increment = workout.totalSets
            case .volume:
                increment = Int(workout.totalVolume)
            case .duration:
                increment = workout.duration
            case .distance:
                increment = Int(workout.totalDistance ?? 0)
            case .streak:
                // Streak: count as 1 day contribution toward streak target
                increment = 1
            case .games:
                increment = 1
            }

            guard increment > 0 else { continue }

            enrollment.progress += increment
            challenge.currentProgress += increment

            if challenge.currentProgress >= challenge.goalTarget && !challenge.isCompleted {
                completeChallenge(challenge: challenge, enrollment: enrollment, userId: userId)
            }
        }

        try? context.save()
    }

    // MARK: - Expiration & Partial Credit

    func checkExpired() {
        guard let context = modelContext else { return }

        let now = Date()
        let descriptor = FetchDescriptor<Challenge>(
            predicate: #Predicate<Challenge> { challenge in
                !challenge.isCompleted
            }
        )

        guard let challenges = try? context.fetch(descriptor) else { return }

        for challenge in challenges where challenge.endDate <= now {
            challenge.isCompleted = true
            challenge.completedAt = now

            // Award partial credit if 80%+ progress
            if challenge.progress >= partialCreditThreshold {
                let partialXP = Int(Double(challenge.xpReward) * partialCreditXPMultiplier)
                awardXPToEnrolledUsers(challengeId: challenge.id, xp: partialXP, isPartial: true)
            }
        }

        try? context.save()
    }

    // MARK: - Pod Challenge Creation

    func createPodChallenge(podId: UUID, templateId: UUID, creatorId: UUID) -> Challenge? {
        guard let context = modelContext else { return nil }

        // Check pod challenge limit for creator
        let activePodCount = getActiveScopeCount(userId: creatorId, scope: .pod)
        guard activePodCount < maxActivePod else { return nil }

        guard let template = seedTemplates().first(where: { $0.id == templateId && $0.scope == .pod }) else {
            return nil
        }

        let now = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: template.durationDays, to: now) ?? now

        let challenge = Challenge(
            templateId: template.id,
            scope: .pod,
            title: template.title,
            challengeDescription: template.description,
            goalType: template.goalType,
            goalTarget: template.goalTarget,
            startDate: now,
            endDate: endDate,
            xpReward: template.xpReward
        )
        context.insert(challenge)

        // Auto-enroll the creator
        let enrollment = ChallengeEnrollment(
            challengeId: challenge.id,
            userId: creatorId
        )
        context.insert(enrollment)

        try? context.save()
        return challenge
    }

    // MARK: - Queries

    func getActiveChallenges(userId: UUID) -> [ChallengeEnrollment] {
        guard let context = modelContext else { return [] }

        let descriptor = FetchDescriptor<ChallengeEnrollment>(
            predicate: #Predicate<ChallengeEnrollment> { enrollment in
                enrollment.userId == userId && !enrollment.isCompleted
            }
        )

        let enrollments = (try? context.fetch(descriptor)) ?? []

        // Filter to only those whose parent challenge is still active
        return enrollments.filter { enrollment in
            guard let challenge = fetchChallenge(by: enrollment.challengeId) else { return false }
            return challenge.isActive
        }
    }

    func getActiveIndividualCount(userId: UUID) -> Int {
        let active = getActiveChallenges(userId: userId)
        return active.filter { enrollment in
            guard let challenge = fetchChallenge(by: enrollment.challengeId) else { return false }
            return challenge.challengeScope == .individual
        }.count
    }

    // MARK: - Seed Templates

    func seedTemplates() -> [ChallengeTemplate] {
        // Deterministic UUIDs so template IDs are stable across calls
        let ns = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!

        func stableId(_ index: Int) -> UUID {
            var data = ns.uuid
            withUnsafeMutableBytes(of: &data) { ptr in
                ptr[15] = UInt8(index)
            }
            return UUID(uuid: data)
        }

        return [
            // Individual (5)
            ChallengeTemplate(
                id: stableId(1),
                title: "Weekly Warrior",
                description: "Complete 5 workouts this week",
                scope: .individual,
                goalType: .workouts,
                goalTarget: 5,
                durationDays: 7,
                requiredConsistencyState: .onTrack,
                xpReward: 100
            ),
            ChallengeTemplate(
                id: stableId(2),
                title: "Comeback Kid",
                description: "Complete 1 workout this week to get back on track",
                scope: .individual,
                goalType: .workouts,
                goalTarget: 1,
                durationDays: 7,
                requiredConsistencyState: .rebuilding,
                xpReward: 50
            ),
            ChallengeTemplate(
                id: stableId(3),
                title: "Volume Crusher",
                description: "Move 10,000 lbs of total volume this week",
                scope: .individual,
                goalType: .volume,
                goalTarget: 10000,
                durationDays: 7,
                requiredConsistencyState: .onTrack,
                xpReward: 75
            ),
            ChallengeTemplate(
                id: stableId(4),
                title: "Consistency Check",
                description: "Complete 2 workouts in the next 3 days",
                scope: .individual,
                goalType: .workouts,
                goalTarget: 2,
                durationDays: 3,
                requiredConsistencyState: .slipping,
                xpReward: 60
            ),
            ChallengeTemplate(
                id: stableId(5),
                title: "Set Slayer",
                description: "Complete 30 sets this week",
                scope: .individual,
                goalType: .sets,
                goalTarget: 30,
                durationDays: 7,
                requiredConsistencyState: nil,
                xpReward: 80
            ),

            // Pod (5)
            ChallengeTemplate(
                id: stableId(6),
                title: "Pod Power Week",
                description: "Your pod completes 15 workouts together",
                scope: .pod,
                goalType: .workouts,
                goalTarget: 15,
                durationDays: 7,
                requiredConsistencyState: nil,
                xpReward: 120
            ),
            ChallengeTemplate(
                id: stableId(7),
                title: "Team Volume",
                description: "Your pod moves 50,000 lbs of combined volume",
                scope: .pod,
                goalType: .volume,
                goalTarget: 50000,
                durationDays: 7,
                requiredConsistencyState: nil,
                xpReward: 150
            ),
            ChallengeTemplate(
                id: stableId(8),
                title: "All Hands on Deck",
                description: "Every pod member completes at least 1 workout",
                scope: .pod,
                goalType: .workouts,
                goalTarget: 1,
                durationDays: 7,
                requiredConsistencyState: nil,
                xpReward: 100
            ),
            ChallengeTemplate(
                id: stableId(9),
                title: "Streak Builders",
                description: "Each pod member hits a 3-day workout streak",
                scope: .pod,
                goalType: .streak,
                goalTarget: 3,
                durationDays: 7,
                requiredConsistencyState: nil,
                xpReward: 130
            ),
            ChallengeTemplate(
                id: stableId(10),
                title: "Weekend Warriors",
                description: "Pod completes workouts on both Saturday and Sunday",
                scope: .pod,
                goalType: .workouts,
                goalTarget: 2,
                durationDays: 7,
                requiredConsistencyState: nil,
                xpReward: 90
            ),

            // Club (5)
            ChallengeTemplate(
                id: stableId(11),
                title: "Club Challenge",
                description: "The club completes 50 workouts collectively",
                scope: .club,
                goalType: .workouts,
                goalTarget: 50,
                durationDays: 14,
                requiredConsistencyState: nil,
                xpReward: 200
            ),
            ChallengeTemplate(
                id: stableId(12),
                title: "Iron Club",
                description: "The club moves 100,000 lbs of combined volume",
                scope: .club,
                goalType: .volume,
                goalTarget: 100000,
                durationDays: 14,
                requiredConsistencyState: nil,
                xpReward: 250
            ),
            ChallengeTemplate(
                id: stableId(13),
                title: "Full House",
                description: "20 club members complete a workout this week",
                scope: .club,
                goalType: .workouts,
                goalTarget: 20,
                durationDays: 7,
                requiredConsistencyState: nil,
                xpReward: 180
            ),
            ChallengeTemplate(
                id: stableId(14),
                title: "Marathon Month",
                description: "The club completes 100 workouts in 30 days",
                scope: .club,
                goalType: .workouts,
                goalTarget: 100,
                durationDays: 30,
                requiredConsistencyState: nil,
                xpReward: 300
            ),
            ChallengeTemplate(
                id: stableId(15),
                title: "Community Streak",
                description: "The club maintains a 7-day collective workout streak",
                scope: .club,
                goalType: .streak,
                goalTarget: 7,
                durationDays: 10,
                requiredConsistencyState: nil,
                xpReward: 220
            ),
        ]
    }

    // MARK: - Private Helpers

    private func fetchChallenge(by id: UUID) -> Challenge? {
        guard let context = modelContext else { return nil }
        let descriptor = FetchDescriptor<Challenge>(
            predicate: #Predicate<Challenge> { challenge in
                challenge.id == id
            }
        )
        return try? context.fetch(descriptor).first
    }

    private func getActiveScopeCount(userId: UUID, scope: ChallengeScope) -> Int {
        let active = getActiveChallenges(userId: userId)
        return active.filter { enrollment in
            guard let challenge = fetchChallenge(by: enrollment.challengeId) else { return false }
            return challenge.challengeScope == scope
        }.count
    }

    private func completeChallenge(challenge: Challenge, enrollment: ChallengeEnrollment, userId: UUID) {
        challenge.isCompleted = true
        challenge.completedAt = Date()
        enrollment.isCompleted = true
        enrollment.completedAt = Date()

        awardXPToEnrolledUsers(challengeId: challenge.id, xp: challenge.xpReward, isPartial: false)
        createMilestone(userId: userId, challenge: challenge)
    }

    private func awardXPToEnrolledUsers(challengeId: UUID, xp: Int, isPartial: Bool) {
        guard let context = modelContext, xp > 0 else { return }

        let descriptor = FetchDescriptor<ChallengeEnrollment>(
            predicate: #Predicate<ChallengeEnrollment> { enrollment in
                enrollment.challengeId == challengeId
            }
        )

        guard let enrollments = try? context.fetch(descriptor) else { return }

        for enrollment in enrollments {
            let enrollmentUserId = enrollment.userId
            let userDescriptor = FetchDescriptor<UserProfile>(
                predicate: #Predicate<UserProfile> { profile in
                    profile.id == enrollmentUserId
                }
            )
            if let user = try? context.fetch(userDescriptor).first {
                _ = user.addXP(xp)
            }

            if !isPartial {
                enrollment.isCompleted = true
                enrollment.completedAt = Date()
            }
        }
    }

    private func createMilestone(userId: UUID, challenge: Challenge) {
        guard let context = modelContext else { return }

        let milestone = MilestoneEvent(
            userId: userId,
            type: MilestoneType.podGoalHit.rawValue,
            title: "Challenge Complete: \(challenge.title)",
            milestoneDescription: "Completed the \(challenge.title) challenge and earned \(challenge.xpReward) XP"
        )
        context.insert(milestone)
    }
}
