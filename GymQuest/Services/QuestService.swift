//
//  QuestService.swift
//  GymQuest
//
//  Quest management service for the GymQuest 2.0 RPG system.
//  Handles quest creation, progress detection from logs, and rewards.
//

import Foundation
import SwiftData

@MainActor
class QuestService: ObservableObject {
    static let shared = QuestService()

    private var modelContext: ModelContext?

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Quest Seeding

    /// Seed default quests if none exist
    func seedDefaultQuests() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<Quest>()
        let existingQuests = (try? context.fetch(descriptor)) ?? []

        if existingQuests.isEmpty {
            let defaultQuests = createDefaultQuests()
            for quest in defaultQuests {
                context.insert(quest)
            }
            try? context.save()
        }
    }

    private func createDefaultQuests() -> [Quest] {
        return [
            // Training quests
            Quest(
                title: "First Set of the Day",
                questDescription: "Log at least 1 set in any workout",
                category: .training,
                difficulty: .easy,
                completionCriteria: encodeCriteria(QuestCriteria(setsLogged: 1)),
                xpReward: 20,
                expiry: .daily
            ),
            Quest(
                title: "Dedicated Trainer",
                questDescription: "Complete a full workout (10+ sets)",
                category: .training,
                difficulty: .medium,
                completionCriteria: encodeCriteria(QuestCriteria(setsLogged: 10)),
                xpReward: 50,
                expiry: .daily
            ),
            Quest(
                title: "Push It!",
                questDescription: "Log a workout with RPE 8 or higher",
                category: .training,
                difficulty: .medium,
                completionCriteria: encodeCriteria(QuestCriteria(workoutsCompleted: 1, minimumRPE: 8)),
                xpReward: 40,
                expiry: .daily
            ),
            Quest(
                title: "Leg Day Legend",
                questDescription: "Complete a legs workout",
                category: .training,
                difficulty: .medium,
                completionCriteria: encodeCriteria(QuestCriteria(workoutsCompleted: 1, exerciseType: "Legs")),
                xpReward: 45,
                expiry: .daily
            ),
            Quest(
                title: "Weekly Warrior",
                questDescription: "Complete 4 workouts this week",
                category: .training,
                difficulty: .hard,
                completionCriteria: encodeCriteria(QuestCriteria(workoutsCompleted: 4)),
                xpReward: 100,
                expiry: .weekly
            ),

            // Mobility quests
            Quest(
                title: "Stretch It Out",
                questDescription: "Complete a mobility or active recovery session",
                category: .mobility,
                difficulty: .easy,
                completionCriteria: encodeCriteria(QuestCriteria(workoutsCompleted: 1, exerciseType: "Active Recovery")),
                xpReward: 25,
                expiry: .daily
            ),

            // Learning quests
            Quest(
                title: "Knowledge Seeker",
                questDescription: "View 2 learning items",
                category: .learning,
                difficulty: .easy,
                completionCriteria: encodeCriteria(QuestCriteria(learningItemsViewed: 2)),
                xpReward: 20,
                expiry: .daily
            ),

            // Social quests
            Quest(
                title: "Hype Machine",
                questDescription: "Give kudos to 3 friends' workouts",
                category: .social,
                difficulty: .easy,
                completionCriteria: encodeCriteria(QuestCriteria(kudosGiven: 3)),
                xpReward: 25,
                expiry: .daily
            ),

            // Nutrition quests (if enabled)
            Quest(
                title: "Fuel Up",
                questDescription: "Log 1 meal",
                category: .nutrition,
                difficulty: .easy,
                completionCriteria: encodeCriteria(QuestCriteria(mealsLogged: 1)),
                xpReward: 15,
                expiry: .daily
            )
        ]
    }

    private func encodeCriteria(_ criteria: QuestCriteria) -> String {
        guard let data = try? JSONEncoder().encode(criteria),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    private func decodeCriteria(_ string: String) -> QuestCriteria? {
        guard let data = string.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(QuestCriteria.self, from: data)
    }

    // MARK: - Daily Quest Selection

    /// Get today's active quest for a user
    func getTodaysQuest(userId: UUID) -> (quest: Quest, progress: QuestProgress)? {
        guard let context = modelContext else { return nil }

        let today = Calendar.current.startOfDay(for: Date())

        // Fetch all progress for user and filter in memory (enum predicates unreliable)
        let progressDescriptor = FetchDescriptor<QuestProgress>(
            predicate: #Predicate { $0.odId == userId }
        )

        guard let allProgress = try? context.fetch(progressDescriptor) else { return nil }

        // Filter for active quests started today
        let existingProgress = allProgress.first { progress in
            progress.status == .active && progress.startedAt >= today
        }

        if let existingProgress = existingProgress {
            // Find the associated quest
            let questId = existingProgress.questId
            let questDescriptor = FetchDescriptor<Quest>(
                predicate: #Predicate { $0.id == questId }
            )
            if let quest = (try? context.fetch(questDescriptor))?.first {
                return (quest, existingProgress)
            }
        }

        // No active quest - assign a new one
        return assignNewDailyQuest(userId: userId)
    }

    /// Assign a new daily quest to a user
    private func assignNewDailyQuest(userId: UUID) -> (quest: Quest, progress: QuestProgress)? {
        guard let context = modelContext else { return nil }

        // Fetch all quests and filter in memory (enum predicates unreliable)
        let questDescriptor = FetchDescriptor<Quest>(
            predicate: #Predicate { $0.isActive == true }
        )

        guard let allQuests = try? context.fetch(questDescriptor) else { return nil }

        // Filter for daily quests
        let quests = allQuests.filter { $0.expiry == .daily }

        guard !quests.isEmpty, let quest = quests.randomElement() else { return nil }

        // Determine target value from criteria
        let criteria = decodeCriteria(quest.completionCriteria)
        let targetValue = criteria?.setsLogged ?? criteria?.workoutsCompleted ?? criteria?.mealsLogged ?? criteria?.learningItemsViewed ?? criteria?.kudosGiven ?? 1

        // Create progress entry
        let progress = QuestProgress(
            odId: userId,
            questId: quest.id,
            status: .active,
            progressValue: 0,
            targetValue: targetValue,
            startedAt: Date()
        )

        context.insert(progress)
        try? context.save()

        return (quest, progress)
    }

    // MARK: - Progress Evaluation

    /// Evaluate quest progress based on recent activity
    func evaluateProgress(
        userId: UUID,
        workouts: [Workout],
        reactions: [Reaction],
        mealLogs: [MealLog],
        learningProgress: [LearningProgress]
    ) {
        guard let context = modelContext else { return }

        let today = Calendar.current.startOfDay(for: Date())
        let weekStart = Calendar.current.startOfWeek(for: Date())

        // Fetch all progress for user and filter in memory (enum predicates unreliable)
        let progressDescriptor = FetchDescriptor<QuestProgress>(
            predicate: #Predicate { $0.odId == userId }
        )

        guard let allProgress = try? context.fetch(progressDescriptor) else { return }

        // Filter for active quests
        let activeProgress = allProgress.filter { $0.status == .active }

        for progress in activeProgress {
            // Get the associated quest
            let questId = progress.questId
            let questDescriptor = FetchDescriptor<Quest>(
                predicate: #Predicate { $0.id == questId }
            )

            guard let quest = (try? context.fetch(questDescriptor))?.first,
                  let criteria = decodeCriteria(quest.completionCriteria) else { continue }

            var newProgressValue = 0

            // Evaluate based on criteria type
            let dateFilter: Date = quest.expiry == .daily ? today : weekStart

            if let setsTarget = criteria.setsLogged {
                let todaySets = workouts
                    .filter { $0.date >= dateFilter }
                    .reduce(0) { $0 + $1.totalSets }
                newProgressValue = min(todaySets, setsTarget)
            }

            if let workoutsTarget = criteria.workoutsCompleted {
                var filteredWorkouts = workouts.filter { $0.date >= dateFilter }

                // Filter by exercise type if specified
                if let exerciseType = criteria.exerciseType {
                    filteredWorkouts = filteredWorkouts.filter { $0.type.rawValue == exerciseType }
                }

                // Filter by minimum RPE if specified
                if let minRPE = criteria.minimumRPE {
                    filteredWorkouts = filteredWorkouts.filter { $0.rpe >= minRPE }
                }

                newProgressValue = min(filteredWorkouts.count, workoutsTarget)
            }

            if let mealsTarget = criteria.mealsLogged {
                let todayMeals = mealLogs.filter { $0.dateTime >= dateFilter }.count
                newProgressValue = min(todayMeals, mealsTarget)
            }

            if let learningTarget = criteria.learningItemsViewed {
                let todayLearning = learningProgress.filter {
                    ($0.viewedAt ?? Date.distantPast) >= dateFilter
                }.count
                newProgressValue = min(todayLearning, learningTarget)
            }

            if let kudosTarget = criteria.kudosGiven {
                let todayKudos = reactions.filter { $0.createdAt >= dateFilter }.count
                newProgressValue = min(todayKudos, kudosTarget)
            }

            // Update progress
            if newProgressValue != progress.progressValue {
                progress.progressValue = newProgressValue
                progress.updatedAt = Date()

                // Check for completion
                if progress.progressValue >= progress.targetValue && progress.status != .completed {
                    completeQuest(progress: progress, quest: quest, userId: userId)
                }
            }
        }

        try? context.save()
    }

    // MARK: - Quest Completion

    private func completeQuest(progress: QuestProgress, quest: Quest, userId: UUID) {
        guard let context = modelContext else { return }

        progress.status = .completed
        progress.completedAt = Date()

        // Award XP
        let profileDescriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.id == userId }
        )

        if let profile = (try? context.fetch(profileDescriptor))?.first {
            _ = profile.addXP(quest.xpReward)
        }

        // Track analytics
        AnalyticsService.shared.trackQuestCompleted(
            userId: userId,
            questId: quest.id,
            questType: quest.category.rawValue,
            xpEarned: quest.xpReward
        )

        // Award badge if specified
        if let badge = quest.badgeReward {
            awardBadge(badge, userId: userId)
        }

        try? context.save()
    }

    private func awardBadge(_ badge: String, userId: UUID) {
        guard let context = modelContext else { return }

        let profileDescriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.id == userId }
        )

        if let profile = (try? context.fetch(profileDescriptor))?.first {
            var titles = profile.titlesUnlocked
            if !titles.contains(badge) {
                titles.append(badge)
                profile.titlesUnlocked = titles
            }
        }
    }

    // MARK: - Forgiveness Tokens

    /// Use a forgiveness token to skip a failed quest day
    func useForgiveness(userId: UUID) -> Bool {
        guard let context = modelContext else { return false }

        let calendar = Calendar.current
        let month = calendar.component(.month, from: Date())
        let year = calendar.component(.year, from: Date())

        // Find or create token entry for this month
        let tokenDescriptor = FetchDescriptor<ForgivenessToken>(
            predicate: #Predicate {
                $0.odId == userId && $0.month == month && $0.year == year
            }
        )

        var token: ForgivenessToken

        if let existingToken = (try? context.fetch(tokenDescriptor))?.first {
            token = existingToken
        } else {
            token = ForgivenessToken(
                odId: userId,
                month: month,
                year: year,
                tokensRemaining: 2, // Default per spec
                tokensUsed: 0
            )
            context.insert(token)
        }

        // Check if tokens available
        if token.tokensRemaining > 0 {
            token.tokensRemaining -= 1
            token.tokensUsed += 1
            try? context.save()
            return true
        }

        return false
    }

    /// Get remaining forgiveness tokens for this month
    func getRemainingForgiveness(userId: UUID) -> Int {
        guard let context = modelContext else { return 0 }

        let calendar = Calendar.current
        let month = calendar.component(.month, from: Date())
        let year = calendar.component(.year, from: Date())

        let tokenDescriptor = FetchDescriptor<ForgivenessToken>(
            predicate: #Predicate {
                $0.odId == userId && $0.month == month && $0.year == year
            }
        )

        if let token = (try? context.fetch(tokenDescriptor))?.first {
            return token.tokensRemaining
        }

        return 2 // Default
    }

    // MARK: - Quest History

    /// Get completed quests for a user
    func getCompletedQuests(userId: UUID, limit: Int = 10) -> [(quest: Quest, progress: QuestProgress)] {
        guard let context = modelContext else { return [] }

        // Fetch all progress for user and filter in memory (enum predicates unreliable)
        let progressDescriptor = FetchDescriptor<QuestProgress>(
            predicate: #Predicate { $0.odId == userId },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )

        guard let allProgress = try? context.fetch(progressDescriptor) else { return [] }

        // Filter for completed quests
        let completedProgress = allProgress.filter { $0.status == .completed }

        return completedProgress.prefix(limit).compactMap { progress in
            let questId = progress.questId
            let questDescriptor = FetchDescriptor<Quest>(
                predicate: #Predicate { $0.id == questId }
            )
            guard let quest = (try? context.fetch(questDescriptor))?.first else { return nil }
            return (quest, progress)
        }
    }

    /// Get weekly quest statistics
    func getWeeklyStats(userId: UUID) -> QuestWeeklyStats {
        guard let context = modelContext else {
            return QuestWeeklyStats(completed: 0, xpEarned: 0, streak: 0)
        }

        let weekStart = Calendar.current.startOfWeek(for: Date())

        // Fetch all progress for user and filter in memory (enum predicates unreliable)
        let progressDescriptor = FetchDescriptor<QuestProgress>(
            predicate: #Predicate { $0.odId == userId }
        )

        guard let allProgress = try? context.fetch(progressDescriptor) else {
            return QuestWeeklyStats(completed: 0, xpEarned: 0, streak: 0)
        }

        // Filter for completed quests this week
        let weeklyProgress = allProgress.filter {
            $0.status == .completed &&
            $0.completedAt != nil &&
            ($0.completedAt ?? Date.distantPast) >= weekStart
        }

        // Calculate XP from completed quests
        var xpEarned = 0
        for progress in weeklyProgress {
            let questId = progress.questId
            let questDescriptor = FetchDescriptor<Quest>(
                predicate: #Predicate { $0.id == questId }
            )
            if let quest = (try? context.fetch(questDescriptor))?.first {
                xpEarned += quest.xpReward
            }
        }

        // Calculate streak (consecutive days with completed quests)
        var streak = 0
        var checkDate = Calendar.current.startOfDay(for: Date())

        for _ in 0..<30 {
            let dayStart = checkDate
            let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: checkDate) ?? checkDate

            let hasCompletion = allProgress.contains {
                guard let completed = $0.completedAt else { return false }
                return completed >= dayStart && completed < dayEnd
            }

            if hasCompletion {
                streak += 1
            } else if streak > 0 {
                break
            }

            checkDate = Calendar.current.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }

        return QuestWeeklyStats(
            completed: weeklyProgress.count,
            xpEarned: xpEarned,
            streak: streak
        )
    }
}

// MARK: - Quest Stats

struct QuestWeeklyStats {
    let completed: Int
    let xpEarned: Int
    let streak: Int
}
