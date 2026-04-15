import SwiftData
import Foundation
#if canImport(UIKit)
import UIKit
import SwiftUI
#endif

// MARK: - Mock Data Seeder
// Generates 3 months of realistic workout, meal, body measurement, and post data.

struct MockDataSeeder {

    // MARK: - Procedural thumbnail generation

    #if canImport(UIKit)
    /// Render a visually distinct 800×800 JPEG image for a seeded post.
    /// Uses a gradient background + big SF symbol + short label so the grid
    /// is populated with recognizable "photos" without bundled asset files.
    private static func generateThumbnail(index: Int, workoutType: String, isVideo: Bool) -> Data? {
        let size = CGSize(width: 600, height: 600)
        let palettes: [[UIColor]] = [
            [UIColor(red: 0.95, green: 0.60, blue: 0.55, alpha: 1), UIColor(red: 0.82, green: 0.35, blue: 0.55, alpha: 1)],
            [UIColor(red: 0.42, green: 0.60, blue: 0.98, alpha: 1), UIColor(red: 0.78, green: 0.36, blue: 1.00, alpha: 1)],
            [UIColor(red: 0.30, green: 0.78, blue: 0.85, alpha: 1), UIColor(red: 0.24, green: 0.48, blue: 0.90, alpha: 1)],
            [UIColor(red: 0.98, green: 0.75, blue: 0.45, alpha: 1), UIColor(red: 0.90, green: 0.45, blue: 0.30, alpha: 1)],
            [UIColor(red: 0.40, green: 0.82, blue: 0.55, alpha: 1), UIColor(red: 0.24, green: 0.58, blue: 0.65, alpha: 1)],
            [UIColor(red: 0.70, green: 0.55, blue: 0.95, alpha: 1), UIColor(red: 0.40, green: 0.38, blue: 0.82, alpha: 1)],
            [UIColor(red: 0.98, green: 0.45, blue: 0.70, alpha: 1), UIColor(red: 0.55, green: 0.30, blue: 0.85, alpha: 1)],
            [UIColor(red: 0.30, green: 0.38, blue: 0.55, alpha: 1), UIColor(red: 0.18, green: 0.22, blue: 0.35, alpha: 1)],
        ]
        let colors = palettes[index % palettes.count]
        let icon: String
        switch workoutType {
        case "Push": icon = "figure.strengthtraining.traditional"
        case "Pull": icon = "figure.rower"
        case "Legs": icon = "figure.squat"
        case "Upper Body": icon = "figure.arms.open"
        case "Full Body": icon = "figure.cross.training"
        default: icon = "dumbbell.fill"
        }

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            // Gradient background
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [colors[0].cgColor, colors[1].cgColor] as CFArray,
                locations: [0, 1]
            )!
            ctx.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )

            // Subtle overlay vignette bottom
            let vignette = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [UIColor.black.withAlphaComponent(0).cgColor, UIColor.black.withAlphaComponent(0.35).cgColor] as CFArray,
                locations: [0, 1]
            )!
            ctx.cgContext.drawLinearGradient(
                vignette,
                start: CGPoint(x: 0, y: size.height * 0.45),
                end: CGPoint(x: 0, y: size.height),
                options: []
            )

            // Large centered workout icon
            let config = UIImage.SymbolConfiguration(pointSize: 220, weight: .bold)
            if let symbol = UIImage(systemName: icon)?.withConfiguration(config).withTintColor(.white.withAlphaComponent(0.85), renderingMode: .alwaysOriginal) {
                let iconSize = symbol.size
                let iconRect = CGRect(
                    x: (size.width - iconSize.width) / 2,
                    y: (size.height - iconSize.height) / 2 - 30,
                    width: iconSize.width,
                    height: iconSize.height
                )
                symbol.draw(in: iconRect)
            }

            // Video badge mark
            if isVideo {
                let vidConfig = UIImage.SymbolConfiguration(pointSize: 36, weight: .bold)
                if let vid = UIImage(systemName: "video.fill")?.withConfiguration(vidConfig).withTintColor(.white, renderingMode: .alwaysOriginal) {
                    vid.draw(in: CGRect(x: size.width - 70, y: 34, width: 48, height: 34))
                }
            }

            // Workout type label bottom
            let label = workoutType.uppercased() as NSString
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 44, weight: .heavy),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph,
                .kern: 3.0
            ]
            label.draw(
                in: CGRect(x: 0, y: size.height - 108, width: size.width, height: 60),
                withAttributes: attrs
            )
        }
        return image.jpegData(compressionQuality: 0.78)
    }
    #endif



    /// Wipes all previously-seeded profile posts (own + tagged) and reseeds
    /// with procedurally generated JPEG thumbnails so the profile grid looks
    /// lived-in with real-looking photos, videos, and carousels.
    static func resetProfilePosts(modelContext: ModelContext, profile: UserProfile) {
        let userId = profile.id
        let targetUsername = profile.username.lowercased()
        let all = (try? modelContext.fetch(FetchDescriptor<Post>())) ?? []
        for p in all {
            if p.authorId == userId { modelContext.delete(p); continue }
            let tagged = p.taggedUsernames.contains { $0.lowercased() == targetUsername }
            if tagged { modelContext.delete(p) }
        }
        try? modelContext.save()
        fillProfilePosts(modelContext: modelContext, profile: profile, force: true)
    }

    /// Ensures the user has a reasonable number of posts seeded so their
    /// profile grid looks lived-in. Idempotent — only inserts when post count
    /// for the user is below `target`. Seeds photos, videos, and tagged posts
    /// so all three profile tabs populate.
    static func fillProfilePosts(modelContext: ModelContext, profile: UserProfile, target: Int = 30, taggedTarget: Int = 8, force: Bool = false) {
        let userId = profile.id
        let targetUsername = profile.username.lowercased()
        let all = (try? modelContext.fetch(FetchDescriptor<Post>())) ?? []
        let existing = force ? 0 : all.filter { $0.authorId == userId }.count
        let existingTagged = force ? 0 : all.filter { $0.authorId != userId && $0.taggedUsernames.map { $0.lowercased() }.contains(targetUsername) }.count

        let captions = [
            "Push day locked in. Bench felt light today.",
            "Back and bis hit different when the playlist is right.",
            "Leg day survived. Barely.",
            "Upper body pump session. Feeling strong.",
            "Heavy pulls today. Deadlift keeps climbing.",
            "Started the week off right with a solid push session.",
            "3 months consistent and the gains are real.",
            "New squat PR! The grind is paying off.",
            "Shoulders are on fire today.",
            "Morning session. Gym was empty, perfect focus.",
            "Full body burn. Every group got attention.",
            "Consistency > perfection.",
            "Hit the gym before work. Energized all day.",
            "Quick 45-min pull session between meetings.",
            "Lower body crusher. Posterior chain roast.",
            "Hypertrophy block week 3. Volume climbing.",
            "Deload week. Dialed the intensity back.",
            "PR attempt tomorrow — resting tonight.",
            "Felt like a beast today.",
            "Recovery run + mobility work.",
            "Technique day. Slow, heavy, controlled.",
            "Partner lift. Spotter made all the difference.",
            "Shoulder day. Pump city.",
            "Consistency compounds. Week 12 done.",
            "Tempo squats destroyed my legs.",
            "Hit a new 5RM on bench.",
            "Arm day. Biceps on 🔥.",
            "Cardio finisher: 15 min zone 2.",
            "Core circuit to close out.",
            "Home gym grind.",
        ]
        let types = ["Push", "Pull", "Legs", "Upper Body", "Full Body"]
        let emotions = ["Fired Up", "Strong", "Grinding", "Grateful", "Calm"]
        let exercises = ["Bench Press", "Squat", "Deadlift", "Overhead Press", "Barbell Row"]

        let calendar = Calendar.current
        let now = Date()

        let videoDummy = Data(repeating: 0x2, count: 16)

        #if canImport(UIKit)
        // 1) Seed own posts: mix of single photos, single videos, and carousels
        let ownNeeded = max(0, target - existing)
        for i in 0..<ownNeeded {
            let dayOffset = i + Int.random(in: 0...1)
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            // Distribution: 60% single photo, 20% carousel (2-3 photos), 20% single video
            let roll = i % 10
            let wType = types[i % types.count]
            let isSingleVideo = roll < 2            // 0–1 → video (2/10)
            let isCarousel = roll >= 2 && roll < 4  // 2–3 → carousel
            // else 4–9 → single photo (6/10)

            let post: Post
            if isSingleVideo {
                post = Post(
                    authorId: userId,
                    authorName: profile.name,
                    authorUsername: profile.username,
                    timestamp: date,
                    caption: captions[i % captions.count],
                    photoData: nil,
                    videoData: videoDummy,
                    workoutType: wType,
                    duration: Int.random(in: 45...75),
                    setCount: Int.random(in: 14...22),
                    exerciseHighlight: exercises[i % exercises.count],
                    likeCount: Int.random(in: 8...45),
                    commentCount: Int.random(in: 1...8),
                    workoutEmotion: emotions[i % emotions.count]
                )
                // Render a thumbnail and drop it on photoData so the grid
                // shows a real image (still flagged as a video via videoData).
                post.photoData = generateThumbnail(index: i, workoutType: wType, isVideo: true)
            } else if isCarousel {
                let count = (i % 2 == 0) ? 3 : 2
                var items: [PostMedia] = []
                for k in 0..<count {
                    if let img = generateThumbnail(index: i + k * 17, workoutType: wType, isVideo: false) {
                        items.append(PostMedia(exerciseIndex: k, mediaType: .photo, data: img))
                    }
                }
                post = Post(
                    authorId: userId,
                    authorName: profile.name,
                    authorUsername: profile.username,
                    timestamp: date,
                    caption: captions[i % captions.count],
                    photoData: items.first?.data,
                    workoutType: wType,
                    duration: Int.random(in: 45...75),
                    setCount: Int.random(in: 14...22),
                    exerciseHighlight: exercises[i % exercises.count],
                    likeCount: Int.random(in: 8...45),
                    commentCount: Int.random(in: 1...8),
                    workoutEmotion: emotions[i % emotions.count]
                )
                post.mediaItems = items
            } else {
                post = Post(
                    authorId: userId,
                    authorName: profile.name,
                    authorUsername: profile.username,
                    timestamp: date,
                    caption: captions[i % captions.count],
                    photoData: generateThumbnail(index: i, workoutType: wType, isVideo: false),
                    workoutType: wType,
                    duration: Int.random(in: 45...75),
                    setCount: Int.random(in: 14...22),
                    exerciseHighlight: exercises[i % exercises.count],
                    likeCount: Int.random(in: 8...45),
                    commentCount: Int.random(in: 1...8),
                    workoutEmotion: emotions[i % emotions.count]
                )
            }
            modelContext.insert(post)
        }

        // 2) Seed tagged posts authored by fake users
        let taggedNeeded = max(0, taggedTarget - existingTagged)
        let fakes = SocialSeeder.fakeUsers
        for i in 0..<taggedNeeded {
            let fake = fakes[i % fakes.count]
            let dayOffset = i * 2 + Int.random(in: 0...3)
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let isVideo = i % 3 == 0
            let wType = types[i % types.count]
            let photoThumb = generateThumbnail(index: i + 1000, workoutType: wType, isVideo: isVideo)
            let post = Post(
                authorId: fake.id,
                authorName: fake.name,
                authorUsername: fake.username,
                timestamp: date,
                caption: "Partner lift with @\(profile.username) — great session!",
                photoData: photoThumb,
                videoData: isVideo ? videoDummy : nil,
                workoutType: wType,
                duration: Int.random(in: 45...75),
                setCount: Int.random(in: 12...20),
                exerciseHighlight: exercises[i % exercises.count],
                taggedUsernames: [profile.username],
                likeCount: Int.random(in: 10...50),
                commentCount: Int.random(in: 2...10),
                workoutEmotion: emotions[i % emotions.count]
            )
            modelContext.insert(post)
        }
        #endif

        try? modelContext.save()
    }

    /// Ensures a non-rest workout exists for each of the last 7 calendar days.
    /// Safe to call repeatedly; skips days that already have a logged workout.
    static func fillCurrentWeek(modelContext: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let existing = (try? modelContext.fetch(FetchDescriptor<Workout>())) ?? []
        let coveredDays = Set(existing.filter { $0.type != .rest }.map { calendar.startOfDay(for: $0.date) })

        let templates: [(WorkoutType, [(name: String, muscle: MuscleGroup, category: ExerciseCategory, equip: Equipment, sets: [(reps: Int, weight: Double)])])] = [
            (.push, [
                ("Bench Press", .chest, .push, .barbell, [(8, 185), (8, 185), (6, 205)]),
                ("Overhead Press", .shoulders, .push, .barbell, [(8, 115), (8, 115), (6, 125)]),
                ("Incline Dumbbell Press", .chest, .push, .dumbbell, [(10, 70), (10, 70), (8, 75)]),
                ("Tricep Pushdown", .triceps, .push, .cable, [(12, 55), (12, 55), (10, 60)]),
            ]),
            (.pull, [
                ("Barbell Row", .back, .pull, .barbell, [(8, 165), (8, 165), (6, 185)]),
                ("Lat Pulldown", .back, .pull, .cable, [(10, 130), (10, 130), (8, 145)]),
                ("Face Pull", .shoulders, .pull, .cable, [(15, 30), (15, 30), (12, 35)]),
                ("Dumbbell Curl", .biceps, .pull, .dumbbell, [(12, 30), (12, 30), (10, 35)]),
            ]),
            (.legs, [
                ("Squat", .quads, .legs, .barbell, [(8, 225), (8, 225), (5, 255)]),
                ("Romanian Deadlift", .hamstrings, .legs, .barbell, [(8, 185), (8, 185), (8, 205)]),
                ("Leg Press", .quads, .legs, .machine, [(10, 360), (10, 360), (8, 405)]),
                ("Calf Raise", .quads, .legs, .machine, [(15, 200), (15, 200), (15, 200)]),
            ]),
        ]

        for dayOffset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            if coveredDays.contains(day) { continue }

            let tpl = templates[dayOffset % templates.count]
            let exercises = tpl.1.enumerated().map { exIndex, config in
                let sets = config.sets.enumerated().map { setIndex, setConfig in
                    ExerciseSet(
                        reps: setConfig.reps,
                        weight: config.equip == .bodyweight ? 0 : setConfig.weight,
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
                date: day,
                type: tpl.0,
                duration: Int.random(in: 50...75),
                rpe: Int.random(in: 7...9),
                exercises: exercises
            )
            modelContext.insert(workout)
        }

        try? modelContext.save()
    }

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
