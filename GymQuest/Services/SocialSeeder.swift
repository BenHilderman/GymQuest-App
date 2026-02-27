import SwiftUI
import SwiftData

// MARK: - Social Seeder

struct SocialSeeder {

    // Consistent fake users shared across all seed data
    static let fakeUsers: [(id: UUID, name: String, username: String)] = [
        (UUID(uuidString: "A0000001-0000-0000-0000-000000000001")!, "Marcus Chen", "marcuschen"),
        (UUID(uuidString: "A0000001-0000-0000-0000-000000000002")!, "Olivia Park", "oliviapark"),
        (UUID(uuidString: "A0000001-0000-0000-0000-000000000003")!, "Jake Reeves", "jakereeves"),
        (UUID(uuidString: "A0000001-0000-0000-0000-000000000004")!, "Priya Sharma", "priyasharma"),
        (UUID(uuidString: "A0000001-0000-0000-0000-000000000005")!, "Tyler Brooks", "tylerbrooks"),
        (UUID(uuidString: "A0000001-0000-0000-0000-000000000006")!, "Zoe Williams", "zoewilliams"),
        (UUID(uuidString: "A0000001-0000-0000-0000-000000000007")!, "Kai Nakamura", "kainakamura"),
        (UUID(uuidString: "A0000001-0000-0000-0000-000000000008")!, "Emma Rodriguez", "emmarodriguez"),
        (UUID(uuidString: "A0000001-0000-0000-0000-000000000009")!, "Liam Foster", "liamfoster"),
        (UUID(uuidString: "A0000001-0000-0000-0000-00000000000A")!, "Ava Mitchell", "avamitchell"),
    ]

    static func seedIfNeeded(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Post>()
        let existing = (try? modelContext.fetchCount(descriptor)) ?? 0
        guard existing == 0 else { return }

        // Load demo gym photo for select posts
        #if canImport(UIKit)
        let demoPhotoData = UIImage(named: "DemoPhotos")?.jpegData(compressionQuality: 0.5)
        #else
        let demoPhotoData: Data? = nil
        #endif

        let now = Date()
        var postIds: [UUID] = []

        // MARK: - Posts

        // Helper to create a time offset within the last 48 hours
        func hoursAgo(_ h: Double) -> Date {
            now.addingTimeInterval(-h * 3600)
        }

        // 1. Push day workout
        let p1 = Post(
            authorId: fakeUsers[0].id,
            authorName: fakeUsers[0].name,
            authorUsername: fakeUsers[0].username,
            timestamp: hoursAgo(0.5),
            caption: "Chest and tris absolutely fried. That last set of incline was a grind but we got it done.",
            workoutType: "Push",
            duration: 62,
            setCount: 18,
            exerciseHighlight: "Incline Bench Press",
            songTitle: "Lose Yourself",
            artistName: "Eminem",
            musicSource: "Apple Music",
            likeCount: 34,
            commentCount: 4,
            locationName: "The ARC - Queen's",
            spotifyPlaylistURL: "https://open.spotify.com/playlist/37i9dQZF1DX76Wlfdnj7AP",
            workoutEmotion: "Fired Up"
        )
        p1.photoData = demoPhotoData
        if let photoData = demoPhotoData {
            let items: [PostMedia] = [
                PostMedia(exerciseName: nil, mediaType: .photo, data: photoData),
                PostMedia(exerciseName: "Incline Bench Press", exerciseIndex: 0, mediaType: .photo, data: photoData),
                PostMedia(exerciseName: "Tricep Pushdown", exerciseIndex: 1, mediaType: .photo, data: photoData),
            ]
            p1.mediaItemsData = try? JSONEncoder().encode(items)
        }
        modelContext.insert(p1)
        postIds.append(p1.id)

        // 2. Pull day with shared workout data
        let pullWorkout = SharedWorkoutData(
            title: "Back & Biceps Blaster",
            workoutType: "Pull",
            estimatedDuration: 55,
            exercises: [
                SharedWorkoutData.SharedExercise(
                    name: "Barbell Row",
                    muscleGroup: "Back",
                    sets: [
                        .init(reps: 8, weight: 155, restSeconds: 90),
                        .init(reps: 8, weight: 155, restSeconds: 90),
                        .init(reps: 6, weight: 175, restSeconds: 120),
                    ],
                    demoTips: ["Hinge at hips", "Pull to belly button"]
                ),
                SharedWorkoutData.SharedExercise(
                    name: "Pull Up",
                    muscleGroup: "Back",
                    sets: [
                        .init(reps: 10, weight: 0, restSeconds: 90),
                        .init(reps: 8, weight: 0, restSeconds: 90),
                        .init(reps: 6, weight: 25, restSeconds: 120),
                    ],
                    demoTips: ["Full hang at bottom", "Chin over bar"]
                ),
                SharedWorkoutData.SharedExercise(
                    name: "Bicep Curls",
                    muscleGroup: "Biceps",
                    sets: [
                        .init(reps: 12, weight: 30, restSeconds: 60),
                        .init(reps: 10, weight: 35, restSeconds: 60),
                    ],
                    demoTips: ["No swinging", "Squeeze at top"]
                ),
            ],
            authorName: fakeUsers[1].name,
            authorUsername: fakeUsers[1].username
        )
        let pullData = try? JSONEncoder().encode(pullWorkout)
        let p2 = Post(
            authorId: fakeUsers[1].id,
            authorName: fakeUsers[1].name,
            authorUsername: fakeUsers[1].username,
            timestamp: hoursAgo(1.2),
            caption: "New pull routine hits different. Try this one out — the row/pullup superset is brutal in the best way.",
            workoutType: "Pull",
            duration: 55,
            setCount: 14,
            exerciseHighlight: "Barbell Row",
            sharedWorkoutData: pullData,
            likeCount: 28,
            commentCount: 3,
            workoutEmotion: "Strong"
        )
        modelContext.insert(p2)
        postIds.append(p2.id)

        // 3. Leg day
        let p3 = Post(
            authorId: fakeUsers[2].id,
            authorName: fakeUsers[2].name,
            authorUsername: fakeUsers[2].username,
            timestamp: hoursAgo(2.5),
            caption: "345 squat for a triple. Legs are shaking but the PR board is calling my name.",
            workoutType: "Legs",
            duration: 70,
            setCount: 22,
            exerciseHighlight: "Squat",
            songTitle: "Power",
            artistName: "Kanye West",
            musicSource: "Apple Music",
            likeCount: 45,
            commentCount: 6,
            locationName: "The ARC - Queen's",
            workoutEmotion: "Fired Up"
        )
        p3.photoData = demoPhotoData
        if let photoData = demoPhotoData {
            let items: [PostMedia] = [
                PostMedia(exerciseName: nil, mediaType: .photo, data: photoData),
                PostMedia(exerciseName: "Squat", exerciseIndex: 0, mediaType: .photo, data: photoData),
                PostMedia(exerciseName: "Leg Press", exerciseIndex: 1, mediaType: .photo, data: photoData),
            ]
            p3.mediaItemsData = try? JSONEncoder().encode(items)
        }
        modelContext.insert(p3)
        postIds.append(p3.id)

        // 4. Cardio + motivation
        let p4 = Post(
            authorId: fakeUsers[3].id,
            authorName: fakeUsers[3].name,
            authorUsername: fakeUsers[3].username,
            timestamp: hoursAgo(4),
            caption: "5K in 22:34. Not my fastest but showing up when you don't feel like it IS the workout.",
            workoutType: "Cardio",
            duration: 28,
            exerciseHighlight: "Outdoor Run",
            songTitle: "Run This Town",
            artistName: "JAY-Z",
            musicSource: "Spotify",
            likeCount: 19,
            commentCount: 2,
            spotifyPlaylistURL: "https://open.spotify.com/playlist/37i9dQZF1DX0XUsuxWHRQd",
            workoutEmotion: "Grinding"
        )
        modelContext.insert(p4)
        postIds.append(p4.id)

        // 5. Push workout with shared data
        let pushWorkout = SharedWorkoutData(
            title: "Upper Push Power",
            workoutType: "Push",
            estimatedDuration: 50,
            exercises: [
                SharedWorkoutData.SharedExercise(
                    name: "Bench Press",
                    muscleGroup: "Chest",
                    sets: [
                        .init(reps: 5, weight: 185, restSeconds: 120),
                        .init(reps: 5, weight: 195, restSeconds: 120),
                        .init(reps: 3, weight: 205, restSeconds: 180),
                    ],
                    demoTips: ["Retract shoulder blades", "Bar to mid-chest"]
                ),
                SharedWorkoutData.SharedExercise(
                    name: "Overhead Press",
                    muscleGroup: "Shoulders",
                    sets: [
                        .init(reps: 8, weight: 95, restSeconds: 90),
                        .init(reps: 8, weight: 95, restSeconds: 90),
                        .init(reps: 6, weight: 105, restSeconds: 90),
                    ],
                    demoTips: ["Brace core", "Lock out overhead"]
                ),
                SharedWorkoutData.SharedExercise(
                    name: "Dumbbell Press",
                    muscleGroup: "Chest",
                    sets: [
                        .init(reps: 10, weight: 60, restSeconds: 60),
                        .init(reps: 10, weight: 60, restSeconds: 60),
                    ],
                    demoTips: ["Squeeze at the top", "Control the descent"]
                ),
            ],
            authorName: fakeUsers[4].name,
            authorUsername: fakeUsers[4].username
        )
        let pushData = try? JSONEncoder().encode(pushWorkout)
        let p5 = Post(
            authorId: fakeUsers[4].id,
            authorName: fakeUsers[4].name,
            authorUsername: fakeUsers[4].username,
            timestamp: hoursAgo(5.5),
            caption: "This push routine has been my go-to for 3 months. 205 bench never felt so smooth. Share the gains!",
            workoutType: "Push",
            duration: 50,
            setCount: 16,
            exerciseHighlight: "Bench Press",
            sharedWorkoutData: pushData,
            likeCount: 37,
            commentCount: 5,
            locationName: "GoodLife Downtown",
            workoutEmotion: "Strong"
        )
        modelContext.insert(p5)
        postIds.append(p5.id)

        // 6. Caption-only motivation
        let p6 = Post(
            authorId: fakeUsers[5].id,
            authorName: fakeUsers[5].name,
            authorUsername: fakeUsers[5].username,
            timestamp: hoursAgo(6),
            caption: "Rest days are growth days. Stretching, foam rolling, and meal prep. Tomorrow we attack legs.",
            likeCount: 12,
            commentCount: 1
        )
        modelContext.insert(p6)
        postIds.append(p6.id)

        // 7. Leg workout with inspired-by
        let p7 = Post(
            authorId: fakeUsers[6].id,
            authorName: fakeUsers[6].name,
            authorUsername: fakeUsers[6].username,
            timestamp: hoursAgo(8),
            caption: "Followed Jake's leg workout and my quads are done. That Bulgarian split squat finisher is evil.",
            workoutType: "Legs",
            duration: 65,
            setCount: 20,
            exerciseHighlight: "Bulgarian Split Squat",
            songTitle: "Sicko Mode",
            artistName: "Travis Scott",
            musicSource: "Spotify",
            inspiredByUsername: fakeUsers[2].username,
            inspiredByName: fakeUsers[2].name,
            likeCount: 22,
            commentCount: 3,
            workoutEmotion: "Grinding"
        )
        modelContext.insert(p7)
        postIds.append(p7.id)

        // 8. Full body with music
        let p8 = Post(
            authorId: fakeUsers[7].id,
            authorName: fakeUsers[7].name,
            authorUsername: fakeUsers[7].username,
            timestamp: hoursAgo(10),
            caption: "Full body day because sometimes you just want to hit everything. Deadlifts + bench + rows + lunges.",
            workoutType: "Push",
            duration: 75,
            setCount: 24,
            exerciseHighlight: "Deadlift",
            songTitle: "Till I Collapse",
            artistName: "Eminem",
            musicSource: "Apple Music",
            likeCount: 31,
            commentCount: 2,
            locationName: "The ARC - Queen's",
            workoutEmotion: "Fired Up"
        )
        p8.photoData = demoPhotoData
        if let photoData = demoPhotoData {
            let items: [PostMedia] = [
                PostMedia(exerciseName: nil, mediaType: .photo, data: photoData),
                PostMedia(exerciseName: "Deadlift", exerciseIndex: 0, mediaType: .photo, data: photoData),
                PostMedia(exerciseName: "Bench Press", exerciseIndex: 1, mediaType: .photo, data: photoData),
            ]
            p8.mediaItemsData = try? JSONEncoder().encode(items)
        }
        modelContext.insert(p8)
        postIds.append(p8.id)

        // 9. Pull with shared data
        let pullWorkout2 = SharedWorkoutData(
            title: "Lat Destroyer",
            workoutType: "Pull",
            estimatedDuration: 45,
            exercises: [
                SharedWorkoutData.SharedExercise(
                    name: "Lat Pulldown",
                    muscleGroup: "Back",
                    sets: [
                        .init(reps: 12, weight: 120, restSeconds: 60),
                        .init(reps: 10, weight: 140, restSeconds: 90),
                        .init(reps: 8, weight: 160, restSeconds: 90),
                    ],
                    demoTips: ["Drive elbows down", "Lean back slightly"]
                ),
                SharedWorkoutData.SharedExercise(
                    name: "Seated Cable Row",
                    muscleGroup: "Back",
                    sets: [
                        .init(reps: 12, weight: 100, restSeconds: 60),
                        .init(reps: 10, weight: 120, restSeconds: 60),
                    ],
                    demoTips: ["Squeeze shoulder blades", "Don't round back"]
                ),
            ],
            authorName: fakeUsers[8].name,
            authorUsername: fakeUsers[8].username
        )
        let pullData2 = try? JSONEncoder().encode(pullWorkout2)
        let p9 = Post(
            authorId: fakeUsers[8].id,
            authorName: fakeUsers[8].name,
            authorUsername: fakeUsers[8].username,
            timestamp: hoursAgo(12),
            caption: "This lat pulldown progression has my back wider than ever. Give it a try — RPE 8 on the last set.",
            workoutType: "Pull",
            duration: 45,
            setCount: 12,
            exerciseHighlight: "Lat Pulldown",
            sharedWorkoutData: pullData2,
            likeCount: 18,
            commentCount: 2,
            workoutEmotion: "Strong"
        )
        modelContext.insert(p9)
        postIds.append(p9.id)

        // 10. Comeback story
        let p10 = Post(
            authorId: fakeUsers[9].id,
            authorName: fakeUsers[9].name,
            authorUsername: fakeUsers[9].username,
            timestamp: hoursAgo(14),
            caption: "First workout back after 2 weeks off. Everything felt heavy but I showed up. That's what matters.",
            workoutType: "Push",
            duration: 40,
            setCount: 12,
            exerciseHighlight: "Dumbbell Press",
            songTitle: "Stronger",
            artistName: "Kanye West",
            musicSource: "Spotify",
            likeCount: 42,
            commentCount: 5,
            workoutEmotion: "Comeback"
        )
        modelContext.insert(p10)
        postIds.append(p10.id)

        // 11. Gym location post
        let p11 = Post(
            authorId: fakeUsers[0].id,
            authorName: fakeUsers[0].name,
            authorUsername: fakeUsers[0].username,
            timestamp: hoursAgo(16),
            caption: "Morning crew at The ARC just different. 6am squats with the boys. Nothing like starting the day right.",
            workoutType: "Legs",
            duration: 55,
            setCount: 16,
            exerciseHighlight: "Squat",
            likeCount: 26,
            commentCount: 3,
            locationName: "The ARC - Queen's",
            workoutEmotion: "Grateful"
        )
        modelContext.insert(p11)
        postIds.append(p11.id)

        // 12. Music-focused post
        let p12 = Post(
            authorId: fakeUsers[1].id,
            authorName: fakeUsers[1].name,
            authorUsername: fakeUsers[1].username,
            timestamp: hoursAgo(18),
            caption: "New playlist = new PRs. Hit 135 on OHP for the first time. Music really does make a difference.",
            workoutType: "Push",
            duration: 48,
            setCount: 14,
            exerciseHighlight: "Overhead Press",
            songTitle: "HUMBLE.",
            artistName: "Kendrick Lamar",
            musicSource: "Spotify",
            likeCount: 23,
            commentCount: 2,
            spotifyPlaylistURL: "https://open.spotify.com/playlist/37i9dQZF1DX0XUsuxWHRQd",
            workoutEmotion: "Strong"
        )
        modelContext.insert(p12)
        postIds.append(p12.id)

        // 13. Dragging but got it done
        let p13 = Post(
            authorId: fakeUsers[3].id,
            authorName: fakeUsers[3].name,
            authorUsername: fakeUsers[3].username,
            timestamp: hoursAgo(20),
            caption: "Barely slept, almost skipped. Did a light pull session anyway. Sometimes the hardest rep is getting to the gym.",
            workoutType: "Pull",
            duration: 35,
            setCount: 10,
            exerciseHighlight: "Cable Row",
            likeCount: 38,
            commentCount: 4,
            workoutEmotion: "Dragging"
        )
        modelContext.insert(p13)
        postIds.append(p13.id)

        // 14. Inspired-by chain
        let p14 = Post(
            authorId: fakeUsers[4].id,
            authorName: fakeUsers[4].name,
            authorUsername: fakeUsers[4].username,
            timestamp: hoursAgo(22),
            caption: "Tried Olivia's pull routine and I'm hooked. That row/pullup superset is now a staple in my program.",
            workoutType: "Pull",
            duration: 52,
            setCount: 14,
            exerciseHighlight: "Pull Up",
            inspiredByUsername: fakeUsers[1].username,
            inspiredByName: fakeUsers[1].name,
            likeCount: 15,
            commentCount: 2,
            workoutEmotion: "Fired Up"
        )
        modelContext.insert(p14)
        postIds.append(p14.id)

        // 15. Legs with shared data
        let legWorkout = SharedWorkoutData(
            title: "Quad Dominant Leg Day",
            workoutType: "Legs",
            estimatedDuration: 60,
            exercises: [
                SharedWorkoutData.SharedExercise(
                    name: "Squat",
                    muscleGroup: "Quads",
                    sets: [
                        .init(reps: 5, weight: 225, restSeconds: 180),
                        .init(reps: 5, weight: 245, restSeconds: 180),
                        .init(reps: 3, weight: 275, restSeconds: 240),
                    ],
                    demoTips: ["Break at hips and knees simultaneously", "Drive knees out"]
                ),
                SharedWorkoutData.SharedExercise(
                    name: "Leg Press",
                    muscleGroup: "Quads",
                    sets: [
                        .init(reps: 12, weight: 360, restSeconds: 90),
                        .init(reps: 10, weight: 400, restSeconds: 90),
                    ],
                    demoTips: ["Full range of motion", "Don't lock out knees"]
                ),
                SharedWorkoutData.SharedExercise(
                    name: "Romanian Deadlift",
                    muscleGroup: "Hamstrings",
                    sets: [
                        .init(reps: 10, weight: 135, restSeconds: 90),
                        .init(reps: 10, weight: 155, restSeconds: 90),
                    ],
                    demoTips: ["Hinge at hips", "Feel the stretch in hamstrings"]
                ),
            ],
            authorName: fakeUsers[2].name,
            authorUsername: fakeUsers[2].username
        )
        let legData = try? JSONEncoder().encode(legWorkout)
        let p15 = Post(
            authorId: fakeUsers[2].id,
            authorName: fakeUsers[2].name,
            authorUsername: fakeUsers[2].username,
            timestamp: hoursAgo(24),
            caption: "My go-to leg day. Squat heavy, leg press for volume, RDLs to finish. Simple but it works.",
            workoutType: "Legs",
            duration: 60,
            setCount: 17,
            exerciseHighlight: "Squat",
            sharedWorkoutData: legData,
            likeCount: 33,
            commentCount: 4,
            locationName: "The ARC - Queen's",
            workoutEmotion: "Strong"
        )
        modelContext.insert(p15)
        postIds.append(p15.id)

        // 16. Caption only — motivation
        let p16 = Post(
            authorId: fakeUsers[5].id,
            authorName: fakeUsers[5].name,
            authorUsername: fakeUsers[5].username,
            timestamp: hoursAgo(26),
            caption: "Week 8 of consistent training. Down 4 lbs, lifts are going UP. Trust the process and eat your protein.",
            likeCount: 29,
            commentCount: 3
        )
        modelContext.insert(p16)
        postIds.append(p16.id)

        // 17. Cardio at location
        let p17 = Post(
            authorId: fakeUsers[7].id,
            authorName: fakeUsers[7].name,
            authorUsername: fakeUsers[7].username,
            timestamp: hoursAgo(28),
            caption: "Treadmill intervals: 30s sprint / 60s walk x 12. Took 20 minutes but I'm drenched. Efficient.",
            workoutType: "Cardio",
            duration: 20,
            exerciseHighlight: "Treadmill",
            songTitle: "Blinding Lights",
            artistName: "The Weeknd",
            musicSource: "Apple Music",
            likeCount: 14,
            commentCount: 1,
            locationName: "GoodLife Downtown",
            workoutEmotion: "Grinding"
        )
        modelContext.insert(p17)
        postIds.append(p17.id)

        // 18. Push with emotion
        let p18 = Post(
            authorId: fakeUsers[6].id,
            authorName: fakeUsers[6].name,
            authorUsername: fakeUsers[6].username,
            timestamp: hoursAgo(30),
            caption: "Shoulder day. Lateral raises until I can't lift my arms. The pump is the reward.",
            workoutType: "Push",
            duration: 42,
            setCount: 16,
            exerciseHighlight: "Lateral Raise",
            likeCount: 17,
            commentCount: 1,
            workoutEmotion: "Calm"
        )
        modelContext.insert(p18)
        postIds.append(p18.id)

        // 19. Morning workout with location
        let p19 = Post(
            authorId: fakeUsers[8].id,
            authorName: fakeUsers[8].name,
            authorUsername: fakeUsers[8].username,
            timestamp: hoursAgo(34),
            caption: "5:30am alarm. On the platform by 6. Pulled 365 for a clean single. Early bird gets the gains.",
            workoutType: "Pull",
            duration: 58,
            setCount: 15,
            exerciseHighlight: "Deadlift",
            likeCount: 41,
            commentCount: 4,
            locationName: "The ARC - Queen's",
            workoutEmotion: "Fired Up"
        )
        p19.photoData = demoPhotoData
        if let photoData = demoPhotoData {
            let items: [PostMedia] = [
                PostMedia(exerciseName: nil, mediaType: .photo, data: photoData),
                PostMedia(exerciseName: "Deadlift", exerciseIndex: 0, mediaType: .photo, data: photoData),
            ]
            p19.mediaItemsData = try? JSONEncoder().encode(items)
        }
        modelContext.insert(p19)
        postIds.append(p19.id)

        // 20. Grateful post
        let p20 = Post(
            authorId: fakeUsers[9].id,
            authorName: fakeUsers[9].name,
            authorUsername: fakeUsers[9].username,
            timestamp: hoursAgo(38),
            caption: "Grateful for a body that can move. Mobility work + light squats today. Recovery is training too.",
            workoutType: "Legs",
            duration: 30,
            setCount: 8,
            exerciseHighlight: "Squat",
            likeCount: 24,
            commentCount: 2,
            workoutEmotion: "Grateful"
        )
        modelContext.insert(p20)
        postIds.append(p20.id)

        // 21. Music + inspired by
        let p21 = Post(
            authorId: fakeUsers[0].id,
            authorName: fakeUsers[0].name,
            authorUsername: fakeUsers[0].username,
            timestamp: hoursAgo(40),
            caption: "Stole Priya's cardio playlist and ran my fastest mile in months. Music is half the battle.",
            workoutType: "Cardio",
            duration: 32,
            exerciseHighlight: "Outdoor Run",
            songTitle: "Levitating",
            artistName: "Dua Lipa",
            musicSource: "Spotify",
            inspiredByUsername: fakeUsers[3].username,
            inspiredByName: fakeUsers[3].name,
            likeCount: 16,
            commentCount: 1,
            spotifyPlaylistURL: "https://open.spotify.com/playlist/37i9dQZF1DX8tZsk68tuoQ"
        )
        modelContext.insert(p21)
        postIds.append(p21.id)

        // 22. Late night grind
        let p22 = Post(
            authorId: fakeUsers[4].id,
            authorName: fakeUsers[4].name,
            authorUsername: fakeUsers[4].username,
            timestamp: hoursAgo(42),
            caption: "11pm workout because life got busy. No excuses. Got 16 sets in and called it a night.",
            workoutType: "Push",
            duration: 38,
            setCount: 16,
            exerciseHighlight: "Dumbbell Press",
            likeCount: 27,
            commentCount: 3,
            locationName: "GoodLife Downtown",
            workoutEmotion: "Grinding"
        )
        modelContext.insert(p22)
        postIds.append(p22.id)

        // 23. Community shoutout
        let p23 = Post(
            authorId: fakeUsers[6].id,
            authorName: fakeUsers[6].name,
            authorUsername: fakeUsers[6].username,
            timestamp: hoursAgo(44),
            caption: "Shoutout to the ARC morning crew. Nothing beats training with people who actually push you.",
            likeCount: 35,
            commentCount: 3,
            locationName: "The ARC - Queen's"
        )
        modelContext.insert(p23)
        postIds.append(p23.id)

        // 24. PR celebration
        let p24 = Post(
            authorId: fakeUsers[8].id,
            authorName: fakeUsers[8].name,
            authorUsername: fakeUsers[8].username,
            timestamp: hoursAgo(46),
            caption: "FINALLY hit 2 plates on bench. 225 x 1. Months of grinding for this moment. Let's go.",
            workoutType: "Push",
            duration: 55,
            setCount: 18,
            exerciseHighlight: "Bench Press",
            likeCount: 44,
            commentCount: 6,
            workoutEmotion: "Fired Up"
        )
        p24.photoData = demoPhotoData
        if let photoData = demoPhotoData {
            let items: [PostMedia] = [
                PostMedia(exerciseName: nil, mediaType: .photo, data: photoData),
                PostMedia(exerciseName: "Bench Press", exerciseIndex: 0, mediaType: .photo, data: photoData),
                PostMedia(exerciseName: "Incline Dumbbell Press", exerciseIndex: 1, mediaType: .photo, data: photoData),
            ]
            p24.mediaItemsData = try? JSONEncoder().encode(items)
        }
        modelContext.insert(p24)
        postIds.append(p24.id)

        // 25. Cycling cardio post
        let p25 = Post(
            authorId: fakeUsers[5].id,
            authorName: fakeUsers[5].name,
            authorUsername: fakeUsers[5].username,
            timestamp: hoursAgo(36),
            caption: "30km ride along the waterfront. Perfect weather, perfect pace. Cycling is meditation for me.",
            workoutType: "Cardio",
            duration: 65,
            exerciseHighlight: "Cycling",
            songTitle: "Starboy",
            artistName: "The Weeknd",
            musicSource: "Spotify",
            likeCount: 21,
            commentCount: 2,
            workoutEmotion: "Calm"
        )
        modelContext.insert(p25)
        postIds.append(p25.id)

        // 26. Rowing cardio post
        let p26 = Post(
            authorId: fakeUsers[9].id,
            authorName: fakeUsers[9].name,
            authorUsername: fakeUsers[9].username,
            timestamp: hoursAgo(32),
            caption: "2000m row in 7:12. Legs and lungs both screaming. Rowing is the ultimate full-body cardio.",
            workoutType: "Cardio",
            duration: 25,
            exerciseHighlight: "Rowing",
            likeCount: 17,
            commentCount: 2,
            locationName: "The ARC - Queen's",
            workoutEmotion: "Grinding"
        )
        modelContext.insert(p26)
        postIds.append(p26.id)

        // MARK: - Engagement Metrics (batch update all social posts)

        let allSocialPosts = [p1, p2, p3, p4, p5, p6, p7, p8, p9, p10,
                              p11, p12, p13, p14, p15, p16, p17, p18, p19, p20,
                              p21, p22, p23, p24, p25, p26]
        for post in allSocialPosts {
            post.viewCount = post.likeCount * Int.random(in: 6...12)
            post.shareCount = max(post.likeCount / Int.random(in: 6...12), 0)
            post.saveCount = max(post.likeCount / Int.random(in: 4...8), 0)
            post.avgWatchTimeSec = Double.random(in: 5...20)
            let views = max(Double(post.viewCount), 1.0)
            post.engagementScore = min((Double(post.likeCount) + Double(post.commentCount) * 3.0 + Double(post.shareCount) * 5.0 + Double(post.saveCount) * 4.0) / views, 1.0)
        }

        // MARK: - Comments

        // Post 1 (Marcus's push day) — 4 comments
        seedComment(ctx: modelContext, postId: postIds[0], user: fakeUsers[1], content: "Incline is so underrated. What angle do you set it at?", hoursAgo: 0.3)
        seedComment(ctx: modelContext, postId: postIds[0], user: fakeUsers[2], content: "Chest pump must have been insane", hoursAgo: 0.2)
        seedComment(ctx: modelContext, postId: postIds[0], user: fakeUsers[5], content: "The ARC mornings hit different fr", hoursAgo: 0.15)
        seedComment(ctx: modelContext, postId: postIds[0], user: fakeUsers[3], content: "Need to try this routine", hoursAgo: 0.1)

        // Post 2 (Olivia's pull routine) — 3 comments
        seedComment(ctx: modelContext, postId: postIds[1], user: fakeUsers[4], content: "Just followed this workout, my lats are on fire", hoursAgo: 0.8)
        seedComment(ctx: modelContext, postId: postIds[1], user: fakeUsers[6], content: "That superset is no joke. Adding this to my rotation", hoursAgo: 0.5)
        seedComment(ctx: modelContext, postId: postIds[1], user: fakeUsers[0], content: "Clean programming. Love the rep scheme", hoursAgo: 0.3)

        // Post 3 (Jake's leg day) — 6 comments
        seedComment(ctx: modelContext, postId: postIds[2], user: fakeUsers[0], content: "345 for a triple?! Beast mode", hoursAgo: 2)
        seedComment(ctx: modelContext, postId: postIds[2], user: fakeUsers[1], content: "Those legs don't skip leg day clearly", hoursAgo: 1.8)
        seedComment(ctx: modelContext, postId: postIds[2], user: fakeUsers[3], content: "What belt are you using?", hoursAgo: 1.5)
        seedComment(ctx: modelContext, postId: postIds[2], user: fakeUsers[5], content: "PR board? Count me in next week", hoursAgo: 1.2)
        seedComment(ctx: modelContext, postId: postIds[2], user: fakeUsers[7], content: "My knees hurt watching this lol", hoursAgo: 1)
        seedComment(ctx: modelContext, postId: postIds[2], user: fakeUsers[9], content: "Legs looking thick! Keep it up", hoursAgo: 0.8)

        // Post 5 (Tyler's push routine) — 5 comments
        seedComment(ctx: modelContext, postId: postIds[4], user: fakeUsers[0], content: "205 bench is serious. What's your warmup?", hoursAgo: 4)
        seedComment(ctx: modelContext, postId: postIds[4], user: fakeUsers[2], content: "Following this tomorrow. Looks solid", hoursAgo: 3.5)
        seedComment(ctx: modelContext, postId: postIds[4], user: fakeUsers[7], content: "That OHP progression tho", hoursAgo: 3)
        seedComment(ctx: modelContext, postId: postIds[4], user: fakeUsers[9], content: "GoodLife downtown crew represent!", hoursAgo: 2.5)
        seedComment(ctx: modelContext, postId: postIds[4], user: fakeUsers[1], content: "Shared workouts are the best feature", hoursAgo: 2)

        // Post 10 (Ava's comeback) — 5 comments
        seedComment(ctx: modelContext, postId: postIds[9], user: fakeUsers[0], content: "Showing up IS the hardest part. Respect", hoursAgo: 13)
        seedComment(ctx: modelContext, postId: postIds[9], user: fakeUsers[3], content: "We've all been there. Welcome back!", hoursAgo: 12)
        seedComment(ctx: modelContext, postId: postIds[9], user: fakeUsers[5], content: "Comeback season", hoursAgo: 11)
        seedComment(ctx: modelContext, postId: postIds[9], user: fakeUsers[6], content: "Day 1 back is always the worst. It only gets better", hoursAgo: 10)
        seedComment(ctx: modelContext, postId: postIds[9], user: fakeUsers[8], content: "Proud of you for getting back at it", hoursAgo: 9)

        // Post 13 (Priya's dragging day) — 4 comments
        seedComment(ctx: modelContext, postId: postIds[12], user: fakeUsers[0], content: "This is the content I needed today. Almost skipped too", hoursAgo: 19)
        seedComment(ctx: modelContext, postId: postIds[12], user: fakeUsers[2], content: "The hardest rep is always the first one", hoursAgo: 18)
        seedComment(ctx: modelContext, postId: postIds[12], user: fakeUsers[7], content: "Light work is still work. Way to show up", hoursAgo: 17.5)
        seedComment(ctx: modelContext, postId: postIds[12], user: fakeUsers[9], content: "Dragging days build champions", hoursAgo: 17)

        // Post 15 (Jake's leg routine) — 4 comments
        seedComment(ctx: modelContext, postId: postIds[14], user: fakeUsers[4], content: "This is basically my dream leg day", hoursAgo: 23)
        seedComment(ctx: modelContext, postId: postIds[14], user: fakeUsers[6], content: "275 squat triple is goals", hoursAgo: 22)
        seedComment(ctx: modelContext, postId: postIds[14], user: fakeUsers[1], content: "RDLs to finish? You're a menace", hoursAgo: 21)
        seedComment(ctx: modelContext, postId: postIds[14], user: fakeUsers[8], content: "Following this next leg day for sure", hoursAgo: 20)

        // Post 24 (Liam's bench PR) — 6 comments
        seedComment(ctx: modelContext, postId: postIds[23], user: fakeUsers[0], content: "2 PLATES!! Let's gooooo", hoursAgo: 45)
        seedComment(ctx: modelContext, postId: postIds[23], user: fakeUsers[1], content: "Welcome to the 225 club!", hoursAgo: 44)
        seedComment(ctx: modelContext, postId: postIds[23], user: fakeUsers[2], content: "The grind paid off. Huge milestone", hoursAgo: 43)
        seedComment(ctx: modelContext, postId: postIds[23], user: fakeUsers[3], content: "Next stop: 275!", hoursAgo: 42)
        seedComment(ctx: modelContext, postId: postIds[23], user: fakeUsers[5], content: "Months of work for one rep. That's dedication", hoursAgo: 41)
        seedComment(ctx: modelContext, postId: postIds[23], user: fakeUsers[9], content: "Inspiring. I'm chasing 185 rn", hoursAgo: 40)

        // MARK: - Friend Records (Social Graph)

        // Get the current user's profile to set up relationships
        let profileDescriptor = FetchDescriptor<UserProfile>()
        let profiles = (try? modelContext.fetch(profileDescriptor)) ?? []
        if let myProfile = profiles.first {
            let myId = myProfile.id

            // 5 mutual follows (friends) — users 0-4
            for i in 0..<5 {
                // I follow them
                let follow = Friend(userId: myId, odId: fakeUsers[i].id, odName: fakeUsers[i].name, odUsername: fakeUsers[i].username)
                modelContext.insert(follow)
                // They follow me back
                let followBack = Friend(userId: fakeUsers[i].id, odId: myId, odName: myProfile.name, odUsername: myProfile.username)
                modelContext.insert(followBack)
            }

            // 3 one-way follows (following only) — users 5-7
            for i in 5..<8 {
                let follow = Friend(userId: myId, odId: fakeUsers[i].id, odName: fakeUsers[i].name, odUsername: fakeUsers[i].username)
                modelContext.insert(follow)
            }

            // Update profile counts
            myProfile.followingCount = 8
            myProfile.followerCount = 5

            // MARK: - UserInterestProfile (default for dev user)

            let interests = UserInterestProfile(
                userId: myId,
                workoutTypeWeights: ["Push": 0.7, "Pull": 0.6, "Legs": 0.5, "Cardio": 0.3, "Upper Body": 0.6],
                authorWeights: [
                    fakeUsers[0].id.uuidString: 0.8,
                    fakeUsers[1].id.uuidString: 0.6,
                    fakeUsers[2].id.uuidString: 0.5
                ],
                contentFormatWeights: ["video": 0.7, "photo": 0.6, "text": 0.3],
                avgSessionTimeSec: 15.0
            )
            modelContext.insert(interests)
        }

        // MARK: - Fake User Profiles (for privacy & follower counts)

        for (i, user) in fakeUsers.enumerated() {
            // Only create if not already existing
            let uid = user.id
            let existsDescriptor = FetchDescriptor<UserProfile>(predicate: #Predicate { $0.id == uid })
            if (try? modelContext.fetchCount(existsDescriptor)) ?? 0 == 0 {
                let fakeProfile = UserProfile(
                    id: user.id,
                    name: user.name,
                    username: user.username
                )
                // Users 8-9 are private profiles
                fakeProfile.isProfilePublic = (i < 8)
                fakeProfile.followerCount = i < 5 ? Int.random(in: 50...200) : Int.random(in: 10...80)
                fakeProfile.followingCount = Int.random(in: 20...100)
                modelContext.insert(fakeProfile)
            }
        }

        try? modelContext.save()
    }

    private static func seedComment(ctx: ModelContext, postId: UUID, user: (id: UUID, name: String, username: String), content: String, hoursAgo h: Double) {
        let comment = Comment(
            postId: postId,
            authorId: user.id,
            authorName: user.name,
            authorUsername: user.username,
            content: content,
            timestamp: Date().addingTimeInterval(-h * 3600)
        )
        ctx.insert(comment)
    }
}
