import SwiftData
import Foundation

// MARK: - Mock Data Seeder
// Generates 3 months of realistic workout, meal, body measurement, and post data.

struct MockDataSeeder {

    static func seedIfNeeded(modelContext: ModelContext, profile: UserProfile) {
        let descriptor = FetchDescriptor<Workout>()
        let existing = (try? modelContext.fetchCount(descriptor)) ?? 0
        guard existing == 0 else { return }

        #if DEBUG
        print("MockDataSeeder: Seeding 3 months of mock data...")
        #endif

        let calendar = Calendar.current
        let now = Date()
        let profileId = profile.id

        // 3 months = ~90 days, 4-5 workouts/week = ~56 workouts
        // PPL split: Push / Pull / Legs / Upper / Lower, with rest days

        let schedule: [(WorkoutType, [(name: String, muscle: MuscleGroup, category: ExerciseCategory, equip: Equipment, sets: [(reps: Int, weight: Double)])])] = [
            (.push, [
                ("Bench Press", .chest, .push, .barbell, [(8, 185), (8, 185), (6, 205)]),
                ("Overhead Press", .shoulders, .push, .barbell, [(8, 115), (8, 115), (6, 125)]),
                ("Incline Dumbbell Press", .chest, .push, .dumbbell, [(10, 70), (10, 70), (8, 75)]),
                ("Lateral Raise", .shoulders, .push, .dumbbell, [(12, 20), (12, 20), (12, 25)]),
                ("Tricep Pushdown", .triceps, .push, .cable, [(12, 50), (12, 55), (10, 60)]),
            ]),
            (.pull, [
                ("Barbell Row", .back, .pull, .barbell, [(8, 165), (8, 165), (6, 185)]),
                ("Pull Up", .back, .pull, .bodyweight, [(8, 0), (7, 0), (6, 0)]),
                ("Face Pull", .shoulders, .pull, .cable, [(15, 30), (15, 30), (12, 35)]),
                ("Barbell Curl", .biceps, .pull, .barbell, [(10, 65), (10, 65), (8, 75)]),
                ("Hammer Curl", .biceps, .pull, .dumbbell, [(12, 30), (12, 30), (10, 35)]),
            ]),
            (.legs, [
                ("Squat", .quads, .legs, .barbell, [(8, 225), (8, 225), (5, 255)]),
                ("Romanian Deadlift", .hamstrings, .legs, .barbell, [(8, 185), (8, 185), (8, 205)]),
                ("Leg Press", .quads, .legs, .machine, [(10, 360), (10, 360), (8, 405)]),
                ("Leg Curl", .hamstrings, .legs, .machine, [(12, 90), (12, 90), (10, 100)]),
                ("Calf Raise", .quads, .legs, .machine, [(15, 180), (15, 180), (15, 200)]),
            ]),
            (.upper, [
                ("Dumbbell Bench Press", .chest, .push, .dumbbell, [(10, 75), (10, 75), (8, 80)]),
                ("Cable Row", .back, .pull, .cable, [(10, 120), (10, 120), (8, 140)]),
                ("Dumbbell Shoulder Press", .shoulders, .push, .dumbbell, [(10, 50), (10, 50), (8, 55)]),
                ("Lat Pulldown", .back, .pull, .cable, [(10, 130), (10, 130), (8, 145)]),
                ("Dumbbell Curl", .biceps, .pull, .dumbbell, [(12, 30), (12, 30), (10, 35)]),
            ]),
            (.pull, [
                ("Deadlift", .back, .pull, .barbell, [(5, 275), (5, 275), (3, 315)]),
                ("Chin Up", .back, .pull, .bodyweight, [(8, 0), (7, 0), (6, 0)]),
                ("Seated Cable Row", .back, .pull, .cable, [(10, 140), (10, 140), (8, 155)]),
                ("Preacher Curl", .biceps, .pull, .machine, [(10, 55), (10, 55), (8, 65)]),
                ("Reverse Fly", .shoulders, .pull, .dumbbell, [(12, 15), (12, 15), (12, 20)]),
            ]),
        ]

        // Generate workout days over 90 days (skip ~2 rest days per week)
        // Pattern: Mon Push, Tue Pull, Wed off, Thu Legs, Fri Upper, Sat Pull, Sun off
        let weekPattern: [Int?] = [0, 1, nil, 2, 3, 4, nil] // indices into schedule, nil = rest

        var allWorkouts: [Workout] = []
        var allPRs: [PREvent] = []

        // Track personal bests for PR detection
        var personalBests: [String: Double] = [:]

        for dayOffset in (0..<90).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let weekday = calendar.component(.weekday, from: date) // 1=Sun, 2=Mon...
            let patternIndex = (weekday + 5) % 7 // Convert to 0=Mon

            guard let scheduleIndex = weekPattern[patternIndex] else { continue }

            let template = schedule[scheduleIndex]

            // Progressive overload: increase weight slightly over time
            let weekNumber = dayOffset / 7
            let progressFactor = 1.0 + Double(90 - dayOffset) / 600.0 // ~15% increase over 3 months

            let exercises = template.1.enumerated().map { exIndex, config in
                let sets = config.sets.enumerated().map { setIndex, setConfig in
                    let adjustedWeight = config.equip == .bodyweight ? 0 : round(setConfig.weight * progressFactor / 5) * 5
                    return ExerciseSet(
                        reps: setConfig.reps,
                        weight: adjustedWeight,
                        rpe: setIndex == config.sets.count - 1 ? 9 : 7,
                        order: setIndex
                    )
                }
                return Exercise(
                    name: config.name,
                    muscleGroup: config.muscle,
                    order: exIndex,
                    sets: sets,
                    category: config.category,
                    equipment: config.equip
                )
            }

            let workout = Workout(
                date: date,
                type: template.0,
                duration: Int.random(in: 50...75),
                rpe: Int.random(in: 7...9),
                exercises: exercises
            )

            allWorkouts.append(workout)
            modelContext.insert(workout)

            // Check for PRs (every ~2 weeks, main lifts get a PR)
            for ex in exercises {
                let topWeight = ex.sets.map(\.weight).max() ?? 0
                guard topWeight > 0 else { continue }
                let prev = personalBests[ex.name] ?? 0
                if topWeight > prev {
                    personalBests[ex.name] = topWeight
                    if prev > 0 { // Skip the very first entry
                        let pr = PREvent(
                            date: date,
                            exerciseName: ex.name,
                            prType: .weightPR,
                            newValue: topWeight,
                            previousValue: prev,
                            delta: topWeight - prev,
                            deltaDisplay: "+\(Int(topWeight - prev)) lbs"
                        )
                        allPRs.append(pr)
                        modelContext.insert(pr)
                    }
                }
            }
        }

        // MARK: - Body Measurements (weekly weigh-ins, trending down slightly)

        let startWeight: Double = 195
        let endWeight: Double = 185
        let weightStep = (startWeight - endWeight) / 13.0 // 13 weeks

        for week in 0..<13 {
            guard let date = calendar.date(byAdding: .weekOfYear, value: -(12 - week), to: now) else { continue }
            let weight = startWeight - (weightStep * Double(week)) + Double.random(in: -0.8...0.8)
            let measurement = BodyMeasurement(
                userId: profileId,
                type: .weight,
                value: round(weight * 10) / 10,
                date: date
            )
            modelContext.insert(measurement)
        }

        // Body fat every 4 weeks
        for month in 0..<3 {
            guard let date = calendar.date(byAdding: .month, value: -(2 - month), to: now) else { continue }
            let bf = 18.0 - Double(month) * 1.2 + Double.random(in: -0.3...0.3)
            let measurement = BodyMeasurement(
                userId: profileId,
                type: .bodyFat,
                value: round(bf * 10) / 10,
                date: date
            )
            modelContext.insert(measurement)
        }

        // MARK: - Meal Logs (3 meals/day, ~85% logged = realistic)

        let mealTemplates: [(MealType, String, [String], Int, Int, Int, Int)] = [
            (.breakfast, "Oatmeal with protein powder and berries", ["Protein", "Carbs"], 450, 35, 55, 10),
            (.breakfast, "Eggs, toast, and avocado", ["Protein", "Healthy Fats"], 520, 30, 35, 28),
            (.breakfast, "Greek yogurt with granola and honey", ["Protein"], 380, 28, 48, 8),
            (.breakfast, "Protein smoothie with banana and PB", ["Protein", "Pre-Workout"], 480, 40, 45, 16),
            (.lunch, "Chicken breast, rice, and broccoli", ["Protein", "Vegetables"], 620, 48, 65, 12),
            (.lunch, "Turkey wrap with spinach and hummus", ["Protein", "Vegetables"], 510, 38, 45, 18),
            (.lunch, "Salmon bowl with quinoa and greens", ["Protein", "Healthy Fats"], 580, 42, 50, 20),
            (.lunch, "Steak burrito bowl", ["Protein", "Carbs"], 680, 45, 70, 22),
            (.dinner, "Grilled salmon with sweet potato", ["Protein", "Healthy Fats"], 550, 40, 45, 18),
            (.dinner, "Chicken stir fry with vegetables", ["Protein", "Vegetables"], 490, 42, 38, 14),
            (.dinner, "Lean ground turkey pasta", ["Protein", "Carbs"], 620, 45, 68, 16),
            (.dinner, "Shrimp tacos with slaw", ["Protein"], 480, 35, 42, 16),
            (.snack, "Protein bar", ["Protein"], 220, 20, 24, 8),
            (.snack, "Trail mix and jerky", ["Protein", "Healthy Fats"], 310, 18, 22, 18),
            (.postworkout, "Protein shake with banana", ["Post-Workout", "Protein"], 350, 35, 40, 4),
        ]

        let feelings: [MealFeeling] = [.great, .great, .good, .good, .good, .okay]

        for dayOffset in (0..<90).reversed() {
            // Skip ~15% of days randomly for realism
            if Int.random(in: 0..<100) < 15 { continue }

            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }

            // Breakfast
            let bIdx = Int.random(in: 0..<4)
            let b = mealTemplates[bIdx]
            seedMeal(modelContext: modelContext, profileId: profileId, date: date, hour: 8, template: b, feelings: feelings)

            // Lunch
            let lIdx = Int.random(in: 4..<8)
            let l = mealTemplates[lIdx]
            seedMeal(modelContext: modelContext, profileId: profileId, date: date, hour: 12, template: l, feelings: feelings)

            // Dinner
            let dIdx = Int.random(in: 8..<12)
            let d = mealTemplates[dIdx]
            seedMeal(modelContext: modelContext, profileId: profileId, date: date, hour: 19, template: d, feelings: feelings)

            // Post-workout snack on workout days
            let weekday = calendar.component(.weekday, from: date)
            let patternIndex = (weekday + 5) % 7
            if weekPattern[patternIndex] != nil {
                let sIdx = Int.random(in: 12..<15)
                let s = mealTemplates[sIdx]
                seedMeal(modelContext: modelContext, profileId: profileId, date: date, hour: 16, template: s, feelings: feelings)
            }
        }

        // MARK: - Posts (2-3 per week, workout recaps)

        let captions = [
            "Push day was absolutely insane today. New bench PR, let's go!",
            "Back and bis hit different when the playlist is right.",
            "Leg day survived. Barely. Those squats were brutal.",
            "Upper body pump session. Feeling strong.",
            "Heavy pulls today. Deadlift keeps climbing.",
            "Started the week off right with a solid push session.",
            "Rest day? Never heard of her. Just kidding, tomorrow.",
            "3 months consistent and the gains are real.",
            "That post-workout meal hit different today.",
            "New squat PR! The grind is paying off.",
            "Shoulders are on fire. Lateral raises to failure.",
            "Morning session today. The gym was empty, perfect focus.",
            "Full body burn today. Every muscle group got attention.",
            "Consistency > perfection. Another day, another workout.",
            "Hit the gym before work. Feeling energized all day.",
        ]

        let emotions: [String] = ["Fired Up", "Strong", "Grinding", "Grateful", "Calm"]

        var postCount = 0
        for dayOffset in stride(from: 87, through: 0, by: -3) {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            guard postCount < captions.count else { break }

            let user = SocialSeeder.fakeUsers[postCount % SocialSeeder.fakeUsers.count]
            let caption = captions[postCount]
            let workoutTypes = ["Push", "Pull", "Legs", "Upper Body", "Full Body"]

            let post = Post(
                authorId: profile.id,
                authorName: profile.name,
                authorUsername: profile.username,
                timestamp: date,
                caption: caption,
                workoutType: workoutTypes[postCount % workoutTypes.count],
                duration: Int.random(in: 45...75),
                setCount: Int.random(in: 14...22),
                exerciseHighlight: ["Bench Press", "Squat", "Deadlift", "Overhead Press", "Barbell Row"][postCount % 5],
                likeCount: Int.random(in: 8...45),
                commentCount: Int.random(in: 1...8),
                workoutEmotion: emotions[postCount % emotions.count]
            )
            modelContext.insert(post)
            postCount += 1
        }

        // MARK: - User Goals

        let benchGoal = UserGoal(
            userId: profileId,
            type: "exercise",
            exerciseName: "Bench Press",
            targetWeight: 225,
            targetReps: 5
        )
        modelContext.insert(benchGoal)

        let squatGoal = UserGoal(
            userId: profileId,
            type: "exercise",
            exerciseName: "Squat",
            targetWeight: 315,
            targetReps: 3
        )
        modelContext.insert(squatGoal)

        let weightGoal = UserGoal(
            userId: profileId,
            type: "bodyweight",
            targetWeight: 180
        )
        modelContext.insert(weightGoal)

        try? modelContext.save()

        #if DEBUG
        print("MockDataSeeder: Done — \(allWorkouts.count) workouts, \(allPRs.count) PRs, meals, measurements, \(postCount) posts, 3 goals")
        #endif
    }

    private static func seedMeal(
        modelContext: ModelContext,
        profileId: UUID,
        date: Date,
        hour: Int,
        template: (MealType, String, [String], Int, Int, Int, Int),
        feelings: [MealFeeling]
    ) {
        let calendar = Calendar.current
        guard let mealDate = calendar.date(bySettingHour: hour, minute: Int.random(in: 0...45), second: 0, of: date) else { return }

        let meal = MealLog(
            odId: profileId,
            dateTime: mealDate,
            mealType: template.0,
            mealDescription: template.1,
            tags: template.2,
            feeling: feelings.randomElement() ?? .good,
            estimatedCalories: template.3 + Int.random(in: -30...30),
            estimatedProtein: template.4 + Int.random(in: -5...5),
            estimatedCarbs: template.5 + Int.random(in: -5...5),
            estimatedFat: template.6 + Int.random(in: -3...3)
        )
        modelContext.insert(meal)
    }
}
