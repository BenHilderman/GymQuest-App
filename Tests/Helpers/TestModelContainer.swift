import Foundation
import SwiftData
@testable import GymQuest

/// Creates an in-memory ModelContainer matching the exact schema from GymQuestApp.swift.
/// Use this in tests to avoid persisting data to disk between test runs.
enum TestModelContainer {

    /// All model types registered in GymQuestApp.swift:25-73
    static let schema = Schema([
        Workout.self,
        Exercise.self,
        ExerciseSet.self,
        PREvent.self,
        MediaItem.self,
        UserProfile.self,
        AILogEntry.self,
        ChatMessage.self,
        Post.self,
        Friend.self,
        Like.self,
        Comment.self,
        WorkoutCard.self,
        PRMoment.self,
        FistBump.self,
        Pod.self,
        Reaction.self,
        Squad.self,
        SquadChallenge.self,
        Quest.self,
        QuestProgress.self,
        ForgivenessToken.self,
        LearningItem.self,
        LearningProgress.self,
        MealLog.self,
        WorkoutTemplate.self,
        WeeklyRecap.self,
        AnalyticsEvent.self
    ])

    /// Creates a fresh in-memory container for each test
    @MainActor
    static func create() throws -> ModelContainer {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
