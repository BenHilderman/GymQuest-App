import Foundation
import SwiftData

// MARK: - Production Seeder (System 9)
// Seeds the app ecosystem with official content: bot account, clubs, templates, posts, challenges.
// All IDs are deterministic for idempotent seeding.

struct ProductionSeeder {

    // MARK: - Deterministic UUIDs

    static let botId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private static let clubIds = [
        UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
        UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
        UUID(uuidString: "00000000-0000-0000-0000-000000000012")!
    ]

    private static let templateIds = [
        UUID(uuidString: "00000000-0000-0000-0000-000000000020")!,
        UUID(uuidString: "00000000-0000-0000-0000-000000000021")!,
        UUID(uuidString: "00000000-0000-0000-0000-000000000022")!,
        UUID(uuidString: "00000000-0000-0000-0000-000000000023")!,
        UUID(uuidString: "00000000-0000-0000-0000-000000000024")!
    ]

    private static let postBaseUUID = "00000000-0000-0000-0000-0000000001"  // append 00-09

    // MARK: - Main Entry Point

    static func seedIfNeeded(modelContext: ModelContext) {
        // Check if @liftai bot already exists
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.id == botId }
        )
        let existing = (try? modelContext.fetch(descriptor))?.first
        if existing != nil { return }

        let id = seedBotAccount(modelContext: modelContext)
        seedOfficialClubs(modelContext: modelContext, botId: id)
        seedRoutineTemplates(modelContext: modelContext, botId: id)
        seedBotContent(modelContext: modelContext, botId: id)

        try? modelContext.save()
    }

    // MARK: - Bot Account

    @discardableResult
    static func seedBotAccount(modelContext: ModelContext) -> UUID {
        let bot = UserProfile(
            id: botId,
            name: "Lift AI",
            username: "liftai",
            goal: .hypertrophy,
            daysPerWeek: 5,
            injuries: "",
            xp: 99999,
            level: 50,
            aiProvider: .demo,
            apiKey: "",
            isAuthenticated: true
        )
        bot.isProfilePublic = true
        bot.isPremium = true
        bot.followerCount = 10000

        modelContext.insert(bot)
        return botId
    }

    // MARK: - Official Clubs

    static func seedOfficialClubs(modelContext: ModelContext, botId: UUID) {
        let clubs: [(UUID, String, String, ClubCategory, [String])] = [
            (
                clubIds[0],
                "Lift AI Community",
                "The official Lift AI community. Share workouts, find training partners, and stay motivated together.",
                .generalFitness,
                ["official", "community", "fitness", "motivation"]
            ),
            (
                clubIds[1],
                "Beginner Lifters",
                "A welcoming space for anyone starting their lifting journey. No question is too basic here.",
                .weightlifting,
                ["beginner", "weightlifting", "learning", "supportive"]
            ),
            (
                clubIds[2],
                "Comeback Club",
                "Getting back into fitness after a break? You're not alone. This club is for anyone rebuilding their routine.",
                .generalFitness,
                ["comeback", "restart", "consistency", "support"]
            )
        ]

        for (id, name, desc, category, tags) in clubs {
            let club = Club(
                id: id,
                name: name,
                clubDescription: desc,
                creatorId: botId,
                adminIds: [botId],
                memberIds: [botId],
                joinType: .open,
                memberCount: 1,
                isVerified: true,
                tags: tags,
                category: category
            )
            modelContext.insert(club)

            let membership = ClubMembership(
                userId: botId,
                clubId: id,
                role: .owner,
                workoutPartnerStatus: .notLooking
            )
            modelContext.insert(membership)
        }
    }

    // MARK: - Routine Templates

    static func seedRoutineTemplates(modelContext: ModelContext, botId: UUID) {
        let templates: [(UUID, String, WorkoutType, Int, String, [TemplateExercise])] = [
            // 1. Beginner Full Body 3x
            (
                templateIds[0],
                "Beginner Full Body 3x",
                .fullBody,
                45,
                "Beginner",
                [
                    TemplateExercise(name: "Goblet Squat", muscleGroup: "Legs", suggestedSets: 3, suggestedReps: "10-12", suggestedWeight: 25, order: 0),
                    TemplateExercise(name: "Dumbbell Bench Press", muscleGroup: "Chest", suggestedSets: 3, suggestedReps: "10-12", suggestedWeight: 20, order: 1),
                    TemplateExercise(name: "Dumbbell Row", muscleGroup: "Back", suggestedSets: 3, suggestedReps: "10-12", suggestedWeight: 20, order: 2),
                    TemplateExercise(name: "Dumbbell Shoulder Press", muscleGroup: "Shoulders", suggestedSets: 3, suggestedReps: "10-12", suggestedWeight: 15, order: 3),
                    TemplateExercise(name: "Plank", muscleGroup: "Core", suggestedSets: 3, suggestedReps: "30-45 sec", suggestedWeight: nil, order: 4)
                ]
            ),
            // 2. PPL 5x
            (
                templateIds[1],
                "Push Pull Legs 5x",
                .push,
                60,
                "Intermediate",
                [
                    TemplateExercise(name: "Barbell Bench Press", muscleGroup: "Chest", suggestedSets: 4, suggestedReps: "6-8", suggestedWeight: 135, order: 0),
                    TemplateExercise(name: "Overhead Press", muscleGroup: "Shoulders", suggestedSets: 3, suggestedReps: "8-10", suggestedWeight: 85, order: 1),
                    TemplateExercise(name: "Incline Dumbbell Press", muscleGroup: "Chest", suggestedSets: 3, suggestedReps: "10-12", suggestedWeight: 40, order: 2),
                    TemplateExercise(name: "Lateral Raise", muscleGroup: "Shoulders", suggestedSets: 3, suggestedReps: "12-15", suggestedWeight: 15, order: 3),
                    TemplateExercise(name: "Tricep Pushdown", muscleGroup: "Arms", suggestedSets: 3, suggestedReps: "12-15", suggestedWeight: 40, order: 4),
                    TemplateExercise(name: "Overhead Tricep Extension", muscleGroup: "Arms", suggestedSets: 3, suggestedReps: "12-15", suggestedWeight: 25, order: 5)
                ]
            ),
            // 3. Upper/Lower 4x
            (
                templateIds[2],
                "Upper Lower Split 4x",
                .upper,
                55,
                "Intermediate",
                [
                    TemplateExercise(name: "Barbell Bench Press", muscleGroup: "Chest", suggestedSets: 4, suggestedReps: "6-8", suggestedWeight: 135, order: 0),
                    TemplateExercise(name: "Barbell Row", muscleGroup: "Back", suggestedSets: 4, suggestedReps: "6-8", suggestedWeight: 115, order: 1),
                    TemplateExercise(name: "Dumbbell Shoulder Press", muscleGroup: "Shoulders", suggestedSets: 3, suggestedReps: "8-10", suggestedWeight: 35, order: 2),
                    TemplateExercise(name: "Lat Pulldown", muscleGroup: "Back", suggestedSets: 3, suggestedReps: "10-12", suggestedWeight: 100, order: 3),
                    TemplateExercise(name: "Dumbbell Curl", muscleGroup: "Arms", suggestedSets: 3, suggestedReps: "10-12", suggestedWeight: 25, order: 4),
                    TemplateExercise(name: "Tricep Dip", muscleGroup: "Arms", suggestedSets: 3, suggestedReps: "8-12", suggestedWeight: nil, order: 5)
                ]
            ),
            // 4. Quick 20-Min
            (
                templateIds[3],
                "Quick 20-Min Full Body",
                .fullBody,
                20,
                "Beginner",
                [
                    TemplateExercise(name: "Kettlebell Swing", muscleGroup: "Full Body", suggestedSets: 3, suggestedReps: "15", suggestedWeight: 35, order: 0),
                    TemplateExercise(name: "Push-Up", muscleGroup: "Chest", suggestedSets: 3, suggestedReps: "10-15", suggestedWeight: nil, order: 1),
                    TemplateExercise(name: "Bodyweight Squat", muscleGroup: "Legs", suggestedSets: 3, suggestedReps: "15-20", suggestedWeight: nil, order: 2),
                    TemplateExercise(name: "Plank", muscleGroup: "Core", suggestedSets: 3, suggestedReps: "30-45 sec", suggestedWeight: nil, order: 3)
                ]
            ),
            // 5. Comeback Ease-In
            (
                templateIds[4],
                "Comeback Ease-In",
                .fullBody,
                30,
                "Beginner",
                [
                    TemplateExercise(name: "Leg Press", muscleGroup: "Legs", suggestedSets: 2, suggestedReps: "12-15", suggestedWeight: 90, order: 0),
                    TemplateExercise(name: "Machine Chest Press", muscleGroup: "Chest", suggestedSets: 2, suggestedReps: "12-15", suggestedWeight: 50, order: 1),
                    TemplateExercise(name: "Seated Cable Row", muscleGroup: "Back", suggestedSets: 2, suggestedReps: "12-15", suggestedWeight: 60, order: 2),
                    TemplateExercise(name: "Dumbbell Lateral Raise", muscleGroup: "Shoulders", suggestedSets: 2, suggestedReps: "12-15", suggestedWeight: 10, order: 3),
                    TemplateExercise(name: "Dead Bug", muscleGroup: "Core", suggestedSets: 2, suggestedReps: "10 each side", suggestedWeight: nil, order: 4)
                ]
            )
        ]

        for (id, name, type, duration, difficulty, exercises) in templates {
            let template = WorkoutTemplate(
                id: id,
                odId: botId,
                name: name,
                workoutType: type,
                exercises: exercises,
                estimatedDuration: duration,
                isPublic: true,
                useCount: 0
            )
            modelContext.insert(template)
        }
    }

    // MARK: - Bot Content (10 Featured Posts)

    static func seedBotContent(modelContext: ModelContext, botId: UUID) {
        let captions: [String] = [
            "Welcome to Lift AI! Whether you're just starting out or getting back into it, this is your space. Let's build something together.",
            "Consistency beats intensity every time. 3 workouts a week for a year will always beat 7 workouts a week for a month.",
            "Tip: Track your rest times. They matter more than you think for hypertrophy. 60-90 seconds between sets is the sweet spot.",
            "You don't need a perfect plan to start. Pick 4-5 exercises, do 3 sets each, and show up again tomorrow. That's the whole secret.",
            "Progressive overload doesn't always mean more weight. More reps, better form, slower eccentrics -- all count.",
            "New to lifting? Start with machines. They guide your movement and build confidence. Free weights will come naturally.",
            "Rest days aren't lazy days. Your muscles grow during recovery, not during the workout. Respect the process.",
            "Feeling off today? A 50% effort workout is infinitely better than skipping entirely. Just show up.",
            "Check out our Beginner Full Body 3x template in the routines tab. It's designed to build a strong foundation without overwhelming you.",
            "Your fitness journey is yours alone. Don't compare your chapter 1 to someone else's chapter 20. Keep going."
        ]

        let baseDateComponents = DateComponents(year: 2026, month: 3, day: 1)
        let calendar = Calendar.current
        let baseDate = calendar.date(from: baseDateComponents) ?? Date()

        for i in 0..<10 {
            let postId = UUID(uuidString: "\(postBaseUUID)\(String(format: "%02d", i))")!
            let postDate = calendar.date(byAdding: .day, value: i, to: baseDate) ?? Date()

            let post = Post(
                id: postId,
                authorId: botId,
                authorName: "Lift AI",
                authorUsername: "liftai",
                timestamp: postDate,
                caption: captions[i],
                isPremiumAuthor: true
            )
            modelContext.insert(post)
        }
    }

    // MARK: - Welcome Notifications (Cold-Start)

    static func seedWelcomeNotifications(modelContext: ModelContext, userId: UUID) {
        let notifIds = [
            UUID(uuidString: "00000000-0000-0000-0000-000000000040")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000041")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000042")!,
        ]

        // Check if already seeded
        let descriptor = FetchDescriptor<NotificationLog>(
            predicate: #Predicate { $0.id == notifIds[0] }
        )
        if let existing = try? modelContext.fetch(descriptor), !existing.isEmpty { return }

        let notifications: [(UUID, String, String)] = [
            (notifIds[0], "welcome", "Welcome. Log what you did whenever you're ready."),
            (notifIds[1], "pod", "You've been matched with a Pod. Say hi to your accountability crew!"),
            (notifIds[2], "tip", "Tip: Tap the form check icon during a set to get real-time feedback on your technique."),
        ]

        for (id, category, title) in notifications {
            let notif = NotificationLog(
                id: id,
                userId: userId,
                category: category,
                sentAt: Date(),
                title: title
            )
            modelContext.insert(notif)
        }
    }

    // MARK: - Challenge Templates

    static func seedChallengeTemplates() -> [ChallengeTemplate] {
        return [
            // Individual - Workout Count
            ChallengeTemplate(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000030")!,
                title: "First Steps",
                description: "Complete 3 workouts this week. Small wins build big habits.",
                scope: .individual,
                goalType: .workouts,
                goalTarget: 3,
                durationDays: 7,
                requiredConsistencyState: nil,
                xpReward: 50
            ),
            ChallengeTemplate(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000031")!,
                title: "Week Warrior",
                description: "Hit 5 workouts in a single week. You've got this.",
                scope: .individual,
                goalType: .workouts,
                goalTarget: 5,
                durationDays: 7,
                requiredConsistencyState: nil,
                xpReward: 100
            ),
            ChallengeTemplate(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000032")!,
                title: "Monthly Commitment",
                description: "Log 16 workouts in 30 days. That's roughly 4 per week.",
                scope: .individual,
                goalType: .workouts,
                goalTarget: 16,
                durationDays: 30,
                requiredConsistencyState: nil,
                xpReward: 300
            ),
            // Individual - Streak
            ChallengeTemplate(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000033")!,
                title: "3-Day Streak",
                description: "Work out 3 days in a row. Build momentum one day at a time.",
                scope: .individual,
                goalType: .streak,
                goalTarget: 3,
                durationDays: 7,
                requiredConsistencyState: nil,
                xpReward: 75
            ),
            ChallengeTemplate(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000034")!,
                title: "Iron Week",
                description: "Maintain a 7-day workout streak. One workout every day for a week.",
                scope: .individual,
                goalType: .streak,
                goalTarget: 7,
                durationDays: 10,
                requiredConsistencyState: nil,
                xpReward: 200
            ),
            // Individual - Volume
            ChallengeTemplate(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000035")!,
                title: "Volume Loader",
                description: "Move 10,000 lbs total in a single week. Every rep counts.",
                scope: .individual,
                goalType: .volume,
                goalTarget: 10000,
                durationDays: 7,
                requiredConsistencyState: nil,
                xpReward: 150
            ),
            ChallengeTemplate(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000036")!,
                title: "Tonnage King",
                description: "Accumulate 50,000 lbs of volume in 30 days.",
                scope: .individual,
                goalType: .volume,
                goalTarget: 50000,
                durationDays: 30,
                requiredConsistencyState: nil,
                xpReward: 400
            ),
            // Individual - Sets
            ChallengeTemplate(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000037")!,
                title: "Set Collector",
                description: "Complete 50 sets in a week. Quality reps, big gains.",
                scope: .individual,
                goalType: .sets,
                goalTarget: 50,
                durationDays: 7,
                requiredConsistencyState: nil,
                xpReward: 100
            ),
            ChallengeTemplate(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000038")!,
                title: "Century Sets",
                description: "Knock out 100 sets in two weeks. Stay focused.",
                scope: .individual,
                goalType: .sets,
                goalTarget: 100,
                durationDays: 14,
                requiredConsistencyState: nil,
                xpReward: 250
            ),
            // Individual - Duration
            ChallengeTemplate(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000039")!,
                title: "Time Under Tension",
                description: "Spend 120 minutes working out this week.",
                scope: .individual,
                goalType: .duration,
                goalTarget: 120,
                durationDays: 7,
                requiredConsistencyState: nil,
                xpReward: 100
            ),
            // Comeback-specific
            ChallengeTemplate(
                id: UUID(uuidString: "00000000-0000-0000-0000-00000000003a")!,
                title: "Comeback Starter",
                description: "Complete your first workout after a break. The hardest step is showing up.",
                scope: .individual,
                goalType: .workouts,
                goalTarget: 1,
                durationDays: 7,
                requiredConsistencyState: .rebuilding,
                xpReward: 50
            ),
            ChallengeTemplate(
                id: UUID(uuidString: "00000000-0000-0000-0000-00000000003b")!,
                title: "Back on Track",
                description: "Hit 4 workouts over two weeks while rebuilding. Slow and steady.",
                scope: .individual,
                goalType: .workouts,
                goalTarget: 4,
                durationDays: 14,
                requiredConsistencyState: .rebuilding,
                xpReward: 150
            ),
            // Pod-scoped
            ChallengeTemplate(
                id: UUID(uuidString: "00000000-0000-0000-0000-00000000003c")!,
                title: "Pod Power Week",
                description: "Your pod collectively logs 15 workouts in a week. Lift each other up.",
                scope: .pod,
                goalType: .workouts,
                goalTarget: 15,
                durationDays: 7,
                requiredConsistencyState: nil,
                xpReward: 200
            ),
            // Club-scoped
            ChallengeTemplate(
                id: UUID(uuidString: "00000000-0000-0000-0000-00000000003d")!,
                title: "Club Grind",
                description: "The club collectively moves 500,000 lbs in a month. Strength in numbers.",
                scope: .club,
                goalType: .volume,
                goalTarget: 500000,
                durationDays: 30,
                requiredConsistencyState: nil,
                xpReward: 500
            ),
            ChallengeTemplate(
                id: UUID(uuidString: "00000000-0000-0000-0000-00000000003e")!,
                title: "Club Streak Race",
                description: "See who in the club can hold the longest streak over 14 days.",
                scope: .club,
                goalType: .streak,
                goalTarget: 14,
                durationDays: 14,
                requiredConsistencyState: nil,
                xpReward: 350
            )
        ]
    }
}
