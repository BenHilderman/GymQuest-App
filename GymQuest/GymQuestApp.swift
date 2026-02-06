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
    let databaseError: String?  // Non-nil if database failed to initialize
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
            AnalyticsEvent.self,

            // Form Studio
            FormExercise.self,
            FormMediaSet.self,
            FormClip.self,
            FormChapter.self,
            FormCue.self,
            FormFault.self,
            VariationEdge.self,
            PatternMastery.self,
            ExerciseMastery.self,
            ConfidenceRating.self
        ])

        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            databaseError = nil
        } catch {
            // If migration fails, delete the old store and try again
            #if DEBUG
            print("SwiftData migration failed: \(error)")
            print("Attempting to delete and recreate database...")
            #endif

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
                databaseError = nil
                #if DEBUG
                print("Successfully created fresh database")
                #endif
            } catch {
                // Last resort: use in-memory container so the app can at least show an error
                #if DEBUG
                print("Database initialization failed completely: \(error)")
                #endif
                let inMemoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                container = try! ModelContainer(for: schema, configurations: [inMemoryConfig])
                databaseError = "Unable to access your workout data. Please restart the app or contact support if this persists."
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            if let errorMessage = databaseError {
                // Show error state when database couldn't initialize
                DatabaseErrorView(message: errorMessage)
                    .preferredColorScheme(.dark)
            } else {
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

    // Active workout state — non-nil means a workout is in progress
    @Published var activeWorkoutType: WorkoutType?

    // Shared rest timer state (so mini bar can show countdown)
    @Published var isResting = false
    @Published var restTimeRemaining = 0
    @Published var restTimerTotal = 0

    // Timer visibility
    @Published var workoutTimerHidden = false

    // where we are in the auth flow
    enum AuthState {
        case notAuthenticated
        case onboarding(authMethod: String, email: String?, googleId: String?, tempPassword: String?)
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

// MARK: - Database Error View

/// Shown when the app's database cannot initialize
struct DatabaseErrorView: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)

                Text("Something Went Wrong")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text(message)
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button {
                    // Restart the app by crashing - user will relaunch
                    // In production, could use exit(0) or guide user to Settings
                    #if DEBUG
                    fatalError("User requested app restart after database error")
                    #endif
                } label: {
                    Text("Try Again")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 32)
                .padding(.top, 16)
            }
        }
    }
}
