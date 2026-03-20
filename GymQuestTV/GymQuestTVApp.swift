import SwiftUI
import SwiftData

@main
struct LiftAITVApp: App {
    let container: ModelContainer
    let databaseError: String?

    init() {
        let schema = Schema([
            // Core workout models
            Workout.self, Exercise.self, ExerciseSet.self, PREvent.self,
            MediaItem.self, FavoriteExercise.self,
            // User & Auth
            UserProfile.self, AILogEntry.self, ChatMessage.self,
            // Social
            Post.self, Friend.self, Like.self, Comment.self,
            PostEngagement.self, UserInterestProfile.self, WorkoutCard.self,
            PRMoment.self, FistBump.self, Pod.self, PodMembership.self,
            PodCheckIn.self, AccountabilityNudge.self, ComebackPlan.self,
            Challenge.self, ChallengeEnrollment.self, UserMomentumState.self,
            NotificationLog.self, WorkoutAdaptation.self, MilestoneEvent.self,
            Reaction.self,
            // Squads
            Squad.self, SquadChallenge.self,
            // Quests
            Quest.self, QuestProgress.self, ForgivenessToken.self,
            // Learning
            LearningItem.self, LearningProgress.self,
            // Nutrition
            MealLog.self,
            // Clubs
            Club.self, ClubPost.self, ClubMembership.self,
            ClubChallenge.self, ClubEvent.self,
            // Templates
            WorkoutTemplate.self,
            // Weekly Recap
            WeeklyRecap.self,
            // Schedule
            ScheduledPlanDay.self,
            // Permissions
            BlockedUser.self, MutedUser.self, ContentReport.self,
            // Analytics
            AnalyticsEvent.self,
            // Training Plans & Coaching
            TrainingPlan.self, CoachNote.self, ExerciseLeaderboardEntry.self,
            // Goals
            UserGoal.self,
            // Form Studio
            FormExercise.self, FormMediaSet.self, FormClip.self,
            FormChapter.self, FormCue.self, FormFault.self,
            VariationEdge.self, PatternMastery.self, ExerciseMastery.self,
            ConfidenceRating.self
        ])

        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            databaseError = nil
        } catch {
            // Migration failed — nuke the store and retry
            let url = URL.applicationSupportDirectory.appending(path: "default.store")
            let shm = URL.applicationSupportDirectory.appending(path: "default.store-shm")
            let wal = URL.applicationSupportDirectory.appending(path: "default.store-wal")
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: shm)
            try? FileManager.default.removeItem(at: wal)

            do {
                container = try ModelContainer(for: schema, configurations: [modelConfiguration])
                databaseError = nil
            } catch {
                // Last resort: in-memory only so the app still launches
                let inMemoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                container = try! ModelContainer(for: schema, configurations: [inMemoryConfig])
                databaseError = "Unable to load workout data."
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            if let error = databaseError {
                Text(error)
                    .font(.title)
                    .foregroundColor(.secondary)
            } else {
                TVContentView()
                    .modelContainer(container)
                    .preferredColorScheme(.dark)
            }
        }
    }
}
