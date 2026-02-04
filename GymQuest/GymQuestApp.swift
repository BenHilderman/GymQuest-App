//
//  GymQuestApp.swift
//  GymQuest
//
//  Created by Benjamin Hilderman
//
//  The main entry point for the app. Sets up the database (SwiftData) and
//  the app state that tracks which tab you're on, what modals are open, etc.
//  Think of this as the foundation everything else builds on.
//

import SwiftUI
import SwiftData
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@main
struct GymQuestApp: App {
    let container: ModelContainer
    @StateObject private var appState = AppState()
    @StateObject private var featureFlags = FeatureFlags.shared

    init() {
        let schema = Schema([
            // Core workout models
            Workout.self,
            Exercise.self,
            ExerciseSet.self,
            PREvent.self,
            MediaItem.self,

            // User & Auth
            UserProfile.self,
            AILogEntry.self,
            ChatMessage.self,

            // Social
            Post.self,
            Friend.self,
            Like.self,
            Comment.self,
            WorkoutCard.self,
            PRMoment.self,
            FistBump.self,
            Pod.self,
            Reaction.self,

            // Squads (GymQuest 2.0)
            Squad.self,
            SquadChallenge.self,

            // Quests (GymQuest 2.0)
            Quest.self,
            QuestProgress.self,
            ForgivenessToken.self,

            // Learning (GymQuest 2.0)
            LearningItem.self,
            LearningProgress.self,

            // Nutrition (GymQuest 2.0)
            MealLog.self,

            // Templates (GymQuest 2.0)
            WorkoutTemplate.self,

            // Weekly Recap (GymQuest 2.0)
            WeeklyRecap.self,

            // Analytics (GymQuest 2.0)
            AnalyticsEvent.self
        ])

        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // If migration fails, delete the old store and try again
            print("SwiftData migration failed: \(error)")
            print("Attempting to delete and recreate database...")

            // Get the default store URL
            let url = URL.applicationSupportDirectory.appending(path: "default.store")
            let shm = URL.applicationSupportDirectory.appending(path: "default.store-shm")
            let wal = URL.applicationSupportDirectory.appending(path: "default.store-wal")

            // Delete old database files
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: shm)
            try? FileManager.default.removeItem(at: wal)

            // Try again with fresh database
            do {
                container = try ModelContainer(for: schema, configurations: [modelConfiguration])
                print("Successfully created fresh database")
            } catch {
                fatalError("Could not initialize ModelContainer even after reset: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(featureFlags)
                .modelContainer(container)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    #if canImport(GoogleSignIn)
                    GIDSignIn.sharedInstance.handle(url)
                    #endif
                }
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 420, height: 800)
        #endif
    }
}

// all the global state stuff - selected tab, modals, auth status
// basically the brain of the app
@MainActor
class AppState: ObservableObject {
    @Published var selectedTab: Tab = .home
    @Published var showingLogWorkout = false
    @Published var showingAddExercise = false
    @Published var showingStats = false
    @Published var showingSessionDetails = false
    @Published var selectedSession: Workout?
    @Published var isLoadingAI = false
    @Published var showingCreatePost = false
    @Published var authState: AuthState = .notAuthenticated

    // where we are in the auth flow
    enum AuthState {
        case notAuthenticated
        case onboarding(authMethod: String, email: String?, googleId: String?)
        case authenticated
    }

    // GymQuest 2.0 tabs - Home first with the one-screen rule
    enum Tab: String, CaseIterable {
        case home = "Home"
        case feed = "Feed"
        case coach = "Coach"
        case progress = "Progress"
        case profile = "Profile"

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .feed: return "rectangle.stack.fill"
            case .coach: return "bubble.left.and.bubble.right.fill"
            case .progress: return "chart.bar.fill"
            case .profile: return "person.fill"
            }
        }
    }
}
