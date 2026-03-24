import SwiftUI
import SwiftData

// MARK: - Social Seeder

struct SocialSeeder {

    /// Load bundled album art by filename (without extension)
    private static func bundledAlbumArt(_ name: String) -> Data? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "jpg", subdirectory: "AlbumArt") else {
            // Try without subdirectory
            guard let url = Bundle.main.url(forResource: name, withExtension: "jpg") else { return nil }
            return try? Data(contentsOf: url)
        }
        return try? Data(contentsOf: url)
    }

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
        let seederVersion = "socialSeeder_v9"
        let needsReseed = !UserDefaults.standard.bool(forKey: seederVersion)

        let descriptor = FetchDescriptor<Post>()
        let existing = (try? modelContext.fetchCount(descriptor)) ?? 0

        if needsReseed && existing > 0 {
            // Delete old posts, likes, comments, reactions to re-seed
            let oldPosts = (try? modelContext.fetch(descriptor)) ?? []
            for post in oldPosts { modelContext.delete(post) }
            let oldLikes = (try? modelContext.fetch(FetchDescriptor<Like>())) ?? []
            for like in oldLikes { modelContext.delete(like) }
            let oldComments = (try? modelContext.fetch(FetchDescriptor<Comment>())) ?? []
            for comment in oldComments { modelContext.delete(comment) }
            let oldReactions = (try? modelContext.fetch(FetchDescriptor<Reaction>())) ?? []
            for reaction in oldReactions { modelContext.delete(reaction) }
            let oldFriends = (try? modelContext.fetch(FetchDescriptor<Friend>())) ?? []
            for friend in oldFriends { modelContext.delete(friend) }
        } else if existing > 0 {
            return
        }

        UserDefaults.standard.set(true, forKey: seederVersion)

        // Load demo gym photo for select posts
        #if canImport(UIKit)
        let demoPhotoData: Data? = UIImage(named: "DemoPhotos")?.jpegData(compressionQuality: 0.5) ?? Self.generatePlaceholderPhoto()
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
            songPreviewURL: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview125/v4/62/0a/a5/620aa56f-189e-708a-80f0-cebdada3872e/mzaf_7131619873177773332.plus.aac.p.m4a",
            albumArtURL: "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/a0/4d/c4/a04dc484-03cc-02aa-fa82-5334fcb4bc16/18UMGIM24878.rgb.jpg/300x300bb.jpg",
            musicSource: "Apple Music",
            likeCount: 34,
            commentCount: 4,
            locationName: "The ARC - Queen's",
            spotifyPlaylistURL: "https://open.spotify.com/playlist/37i9dQZF1DX76Wlfdnj7AP",
            workoutEmotion: "Fired Up",
            overlayTheme: "Sunset",
            musicSnippetStart: 5.0
        )
        p1.albumArtData = bundledAlbumArt("lose_yourself")
        p1.photoData = demoPhotoData
        if let photoData = demoPhotoData {
            let items: [PostMedia] = [
                PostMedia(exerciseName: nil, mediaType: .photo, data: photoData),
                PostMedia(exerciseName: "Incline Bench Press", exerciseIndex: 0, mediaType: .photo, data: photoData),
                PostMedia(exerciseName: "Tricep Pushdown", exerciseIndex: 1, mediaType: .photo, data: photoData),
            ]
            p1.mediaItemsData = try? JSONEncoder().encode(items)
        }
        let p1Workout = SharedWorkoutData(
            title: "Chest & Triceps",
            workoutType: "Push",
            estimatedDuration: 62,
            exercises: [
                SharedWorkoutData.SharedExercise(name: "Incline Bench Press", muscleGroup: "Chest", sets: [.init(reps: 8, weight: 185, restSeconds: 90), .init(reps: 8, weight: 185, restSeconds: 90), .init(reps: 6, weight: 205, restSeconds: 120)], demoTips: ["Arch back slightly", "Control the negative"]),
                SharedWorkoutData.SharedExercise(name: "Tricep Pushdown", muscleGroup: "Triceps", sets: [.init(reps: 12, weight: 50, restSeconds: 60), .init(reps: 10, weight: 60, restSeconds: 60)], demoTips: ["Lock elbows at sides", "Squeeze at bottom"]),
                SharedWorkoutData.SharedExercise(name: "Cable Fly", muscleGroup: "Chest", sets: [.init(reps: 12, weight: 30, restSeconds: 60), .init(reps: 12, weight: 30, restSeconds: 60)], demoTips: ["Slight bend in elbows", "Squeeze at center"]),
            ],
            authorName: fakeUsers[0].name,
            authorUsername: fakeUsers[0].username
        )
        p1.sharedWorkoutData = try? JSONEncoder().encode(p1Workout)
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
            workoutEmotion: "Strong",
            overlayTheme: "Ocean"
        )
        p2.photoData = demoPhotoData
        if let photoData = demoPhotoData {
            let items: [PostMedia] = [
                PostMedia(exerciseName: nil, mediaType: .photo, data: photoData),
                PostMedia(exerciseName: "Barbell Row", exerciseIndex: 0, mediaType: .photo, data: photoData),
            ]
            p2.mediaItemsData = try? JSONEncoder().encode(items)
        }
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
            songPreviewURL: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview221/v4/ae/31/31/ae3131fa-7d8a-933b-c444-ecc0753f543e/mzaf_10401695774164926829.plus.aac.p.m4a",
            albumArtURL: "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/47/40/07/474007f1-31bc-bfb1-f474-a9bd5e0a3a0d/10UMGIM09444.rgb.jpg/300x300bb.jpg",
            musicSource: "Apple Music",
            likeCount: 45,
            commentCount: 6,
            locationName: "The ARC - Queen's",
            workoutEmotion: "Fired Up",
            overlayTheme: "Golden",
            musicSnippetStart: 8.0
        )
        p3.albumArtData = bundledAlbumArt("power")
        p3.photoData = demoPhotoData
        if let photoData = demoPhotoData {
            let items: [PostMedia] = [
                PostMedia(exerciseName: nil, mediaType: .photo, data: photoData),
                PostMedia(exerciseName: "Squat", exerciseIndex: 0, mediaType: .photo, data: photoData),
                PostMedia(exerciseName: "Leg Press", exerciseIndex: 1, mediaType: .photo, data: photoData),
            ]
            p3.mediaItemsData = try? JSONEncoder().encode(items)
        }
        let p3Workout = SharedWorkoutData(
            title: "Leg Day Destroyer",
            workoutType: "Legs",
            estimatedDuration: 70,
            exercises: [
                SharedWorkoutData.SharedExercise(name: "Squat", muscleGroup: "Quads", sets: [.init(reps: 3, weight: 345, restSeconds: 180), .init(reps: 5, weight: 315, restSeconds: 150), .init(reps: 5, weight: 315, restSeconds: 150)], demoTips: ["Break at hips first", "Drive knees out"]),
                SharedWorkoutData.SharedExercise(name: "Romanian Deadlift", muscleGroup: "Hamstrings", sets: [.init(reps: 10, weight: 225, restSeconds: 90), .init(reps: 10, weight: 225, restSeconds: 90)], demoTips: ["Hinge at hips", "Feel hamstring stretch"]),
                SharedWorkoutData.SharedExercise(name: "Leg Press", muscleGroup: "Quads", sets: [.init(reps: 12, weight: 450, restSeconds: 90), .init(reps: 10, weight: 500, restSeconds: 90)], demoTips: ["Full range of motion", "Don't lock knees"]),
            ],
            authorName: fakeUsers[2].name,
            authorUsername: fakeUsers[2].username
        )
        p3.sharedWorkoutData = try? JSONEncoder().encode(p3Workout)
        // PR: Jake hit a squat PR
        let p3PR = [FeedPR(exerciseName: "Squat", value: "345×3", previousValue: "335×3", improvement: "+10 lbs", prType: "Weight PR")]
        p3.prMomentsData = try? JSONEncoder().encode(p3PR)
        modelContext.insert(p3)
        postIds.append(p3.id)

        // 4. Cardio + motivation (with route data)
        let runRoute: [RoutePoint] = [
            RoutePoint(latitude: 43.6532, longitude: -79.3832, altitude: 76, timestamp: 0, speed: 3.2, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6540, longitude: -79.3820, altitude: 77, timestamp: 60, speed: 3.5, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6555, longitude: -79.3805, altitude: 78, timestamp: 150, speed: 3.6, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6568, longitude: -79.3798, altitude: 79, timestamp: 240, speed: 3.4, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6580, longitude: -79.3810, altitude: 80, timestamp: 330, speed: 3.3, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6585, longitude: -79.3830, altitude: 81, timestamp: 420, speed: 3.5, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6578, longitude: -79.3850, altitude: 80, timestamp: 510, speed: 3.6, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6565, longitude: -79.3862, altitude: 79, timestamp: 600, speed: 3.4, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6550, longitude: -79.3868, altitude: 78, timestamp: 700, speed: 3.3, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6538, longitude: -79.3860, altitude: 77, timestamp: 800, speed: 3.5, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6528, longitude: -79.3848, altitude: 76, timestamp: 900, speed: 3.6, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6525, longitude: -79.3838, altitude: 76, timestamp: 1000, speed: 3.4, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6530, longitude: -79.3833, altitude: 76, timestamp: 1100, speed: 3.2, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6532, longitude: -79.3832, altitude: 76, timestamp: 1200, speed: 3.0, horizontalAccuracy: 5),
        ]
        let runWorkoutData = SharedWorkoutData(
            title: "Outdoor Run",
            workoutType: "Cardio",
            estimatedDuration: 28,
            authorName: fakeUsers[3].name,
            authorUsername: fakeUsers[3].username,
            routePoints: runRoute
        )
        let runData = try? JSONEncoder().encode(runWorkoutData)
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
            songPreviewURL: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview115/v4/63/1d/09/631d09d4-3ea6-81eb-172e-fbf14eb1bafe/mzaf_10891290295194397649.plus.aac.p.m4a",
            albumArtURL: "https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/e1/f8/72/e1f87224-885e-bb68-476e-b3eeb8362b47/09UMGIM32901.rgb.jpg/300x300bb.jpg",
            musicSource: "Spotify",
            sharedWorkoutData: runData,
            likeCount: 19,
            commentCount: 2,
            spotifyPlaylistURL: "https://open.spotify.com/playlist/37i9dQZF1DX0XUsuxWHRQd",
            workoutEmotion: "Grinding",
            overlayTheme: "Rose",
            musicSnippetStart: 3.0
        )
        p4.photoData = demoPhotoData
        if let photoData = demoPhotoData {
            let items: [PostMedia] = [
                PostMedia(exerciseName: nil, mediaType: .photo, data: photoData),
                PostMedia(exerciseName: "Outdoor Run", exerciseIndex: 0, mediaType: .photo, data: photoData),
            ]
            p4.mediaItemsData = try? JSONEncoder().encode(items)
        }
        p4.albumArtData = bundledAlbumArt("run_this_town")
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
            workoutEmotion: "Strong",
            overlayTheme: "Lavender"
        )
        p5.photoData = demoPhotoData
        if let photoData = demoPhotoData {
            let items: [PostMedia] = [
                PostMedia(exerciseName: nil, mediaType: .photo, data: photoData),
                PostMedia(exerciseName: "Bench Press", exerciseIndex: 0, mediaType: .photo, data: photoData),
            ]
            p5.mediaItemsData = try? JSONEncoder().encode(items)
        }
        // PR: Tyler hit a bench PR
        let p5PR = [FeedPR(exerciseName: "Bench Press", value: "205 lbs", previousValue: "195 lbs", improvement: "+10 lbs", prType: "Weight PR")]
        p5.prMomentsData = try? JSONEncoder().encode(p5PR)
        modelContext.insert(p5)
        postIds.append(p5.id)

        // 6. Caption-only motivation
        let mealPrepWorkout = SharedWorkoutData(
            title: "Quick Push + Meal Prep",
            workoutType: "Push",
            estimatedDuration: 35,
            exercises: [
                SharedWorkoutData.SharedExercise(
                    name: "Bench Press",
                    muscleGroup: "Chest",
                    sets: [
                        .init(reps: 10, weight: 135, restSeconds: 60),
                        .init(reps: 8, weight: 155, restSeconds: 90),
                        .init(reps: 6, weight: 175, restSeconds: 90),
                    ],
                    demoTips: ["Arch back slightly", "Touch chest each rep"]
                ),
                SharedWorkoutData.SharedExercise(
                    name: "Dumbbell Shoulder Press",
                    muscleGroup: "Shoulders",
                    sets: [
                        .init(reps: 10, weight: 40, restSeconds: 60),
                        .init(reps: 8, weight: 45, restSeconds: 60),
                    ],
                    demoTips: ["Press overhead", "Control the negative"]
                ),
                SharedWorkoutData.SharedExercise(
                    name: "Tricep Dips",
                    muscleGroup: "Triceps",
                    sets: [
                        .init(reps: 12, weight: 0, restSeconds: 60),
                        .init(reps: 10, weight: 0, restSeconds: 60),
                    ],
                    demoTips: ["Elbows back", "Full lockout"]
                ),
            ],
            authorName: fakeUsers[5].name,
            authorUsername: fakeUsers[5].username
        )
        let mealPrepData = try? JSONEncoder().encode(mealPrepWorkout)
        let p6 = Post(
            authorId: fakeUsers[5].id,
            authorName: fakeUsers[5].name,
            authorUsername: fakeUsers[5].username,
            timestamp: hoursAgo(6),
            caption: "Post-workout meal prep done for the week. 180g protein daily, hitting macros consistently for 3 weeks straight.",
            workoutType: "Push",
            duration: 35,
            setCount: 10,
            exerciseHighlight: "Bench Press",
            sharedWorkoutData: mealPrepData,
            likeCount: 12,
            commentCount: 1,
            workoutEmotion: "Dialed In"
        )
        p6.photoData = demoPhotoData
        if let photoData = demoPhotoData {
            let items: [PostMedia] = [
                PostMedia(exerciseName: nil, mediaType: .photo, data: photoData),
                PostMedia(exerciseName: "Bench Press", exerciseIndex: 0, mediaType: .photo, data: photoData),
            ]
            p6.mediaItemsData = try? JSONEncoder().encode(items)
        }
        modelContext.insert(p6)
        postIds.append(p6.id)

        // 7. Leg workout with inspired-by
        let legWorkout7 = SharedWorkoutData(
            title: "Quad Destroyer",
            workoutType: "Legs",
            estimatedDuration: 65,
            exercises: [
                SharedWorkoutData.SharedExercise(
                    name: "Bulgarian Split Squat",
                    muscleGroup: "Quads",
                    sets: [
                        .init(reps: 10, weight: 50, restSeconds: 60),
                        .init(reps: 10, weight: 50, restSeconds: 60),
                        .init(reps: 8, weight: 60, restSeconds: 90),
                    ],
                    demoTips: ["Rear foot elevated", "Keep torso upright"]
                ),
                SharedWorkoutData.SharedExercise(
                    name: "Squat",
                    muscleGroup: "Quads",
                    sets: [
                        .init(reps: 8, weight: 185, restSeconds: 90),
                        .init(reps: 8, weight: 205, restSeconds: 120),
                        .init(reps: 6, weight: 225, restSeconds: 120),
                    ],
                    demoTips: ["Break at hips first", "Depth below parallel"]
                ),
                SharedWorkoutData.SharedExercise(
                    name: "Leg Extension",
                    muscleGroup: "Quads",
                    sets: [
                        .init(reps: 15, weight: 90, restSeconds: 60),
                        .init(reps: 12, weight: 110, restSeconds: 60),
                    ],
                    demoTips: ["Squeeze at the top", "Slow negative"]
                ),
            ],
            authorName: fakeUsers[6].name,
            authorUsername: fakeUsers[6].username
        )
        let legData7 = try? JSONEncoder().encode(legWorkout7)
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
            albumArtURL: "https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/7e/e4/ab/7ee4ab84-3d05-7600-e2fc-4e7b11a47a39/18UMGIM52971.rgb.jpg/300x300bb.jpg",
            musicSource: "Spotify",
            sharedWorkoutData: legData7,
            inspiredByUsername: fakeUsers[2].username,
            inspiredByName: fakeUsers[2].name,
            likeCount: 22,
            commentCount: 3,
            workoutEmotion: "Grinding"
        )
        p7.photoData = demoPhotoData
        if let photoData = demoPhotoData {
            let items: [PostMedia] = [
                PostMedia(exerciseName: nil, mediaType: .photo, data: photoData),
                PostMedia(exerciseName: "Bulgarian Split Squat", exerciseIndex: 0, mediaType: .photo, data: photoData),
            ]
            p7.mediaItemsData = try? JSONEncoder().encode(items)
        }
        p7.albumArtData = bundledAlbumArt("sicko_mode")
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
            albumArtURL: "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/a0/4d/c4/a04dc484-03cc-02aa-fa82-5334fcb4bc16/18UMGIM24878.rgb.jpg/300x300bb.jpg",
            musicSource: "Apple Music",
            likeCount: 31,
            commentCount: 2,
            locationName: "The ARC - Queen's",
            workoutEmotion: "Fired Up"
        )
        p8.albumArtData = bundledAlbumArt("till_i_collapse")
        p8.photoData = demoPhotoData
        if let photoData = demoPhotoData {
            let items: [PostMedia] = [
                PostMedia(exerciseName: nil, mediaType: .photo, data: photoData),
                PostMedia(exerciseName: "Deadlift", exerciseIndex: 0, mediaType: .photo, data: photoData),
                PostMedia(exerciseName: "Bench Press", exerciseIndex: 1, mediaType: .photo, data: photoData),
            ]
            p8.mediaItemsData = try? JSONEncoder().encode(items)
        }
        let p8Workout = SharedWorkoutData(
            title: "Full Body Blitz",
            workoutType: "Push",
            estimatedDuration: 75,
            exercises: [
                SharedWorkoutData.SharedExercise(name: "Deadlift", muscleGroup: "Back", sets: [.init(reps: 5, weight: 315, restSeconds: 180), .init(reps: 5, weight: 315, restSeconds: 180)], demoTips: ["Neutral spine", "Drive through heels"]),
                SharedWorkoutData.SharedExercise(name: "Bench Press", muscleGroup: "Chest", sets: [.init(reps: 8, weight: 185, restSeconds: 90), .init(reps: 8, weight: 185, restSeconds: 90)], demoTips: ["Retract scapula", "Touch chest"]),
                SharedWorkoutData.SharedExercise(name: "Barbell Row", muscleGroup: "Back", sets: [.init(reps: 8, weight: 155, restSeconds: 90), .init(reps: 8, weight: 155, restSeconds: 90)], demoTips: ["Hinge at hips", "Pull to belly button"]),
            ],
            authorName: fakeUsers[7].name,
            authorUsername: fakeUsers[7].username
        )
        p8.sharedWorkoutData = try? JSONEncoder().encode(p8Workout)
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
        p9.photoData = demoPhotoData
        if let photoData = demoPhotoData {
            let items: [PostMedia] = [
                PostMedia(exerciseName: nil, mediaType: .photo, data: photoData),
                PostMedia(exerciseName: "Lat Pulldown", exerciseIndex: 0, mediaType: .photo, data: photoData),
            ]
            p9.mediaItemsData = try? JSONEncoder().encode(items)
        }
        modelContext.insert(p9)
        postIds.append(p9.id)

        // 10. Comeback story
        let pushWorkout10 = SharedWorkoutData(
            title: "Comeback Push",
            workoutType: "Push",
            estimatedDuration: 40,
            exercises: [
                SharedWorkoutData.SharedExercise(
                    name: "Dumbbell Press",
                    muscleGroup: "Chest",
                    sets: [
                        .init(reps: 10, weight: 45, restSeconds: 60),
                        .init(reps: 8, weight: 50, restSeconds: 90),
                        .init(reps: 8, weight: 50, restSeconds: 90),
                    ],
                    demoTips: ["Flat bench", "Control the descent"]
                ),
                SharedWorkoutData.SharedExercise(
                    name: "Incline Bench Press",
                    muscleGroup: "Chest",
                    sets: [
                        .init(reps: 8, weight: 115, restSeconds: 90),
                        .init(reps: 6, weight: 135, restSeconds: 90),
                    ],
                    demoTips: ["30 degree incline", "Touch upper chest"]
                ),
                SharedWorkoutData.SharedExercise(
                    name: "Lateral Raise",
                    muscleGroup: "Shoulders",
                    sets: [
                        .init(reps: 15, weight: 15, restSeconds: 45),
                        .init(reps: 12, weight: 20, restSeconds: 45),
                    ],
                    demoTips: ["Slight bend in elbows", "Raise to shoulder height"]
                ),
            ],
            authorName: fakeUsers[9].name,
            authorUsername: fakeUsers[9].username
        )
        let pushData10 = try? JSONEncoder().encode(pushWorkout10)
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
            albumArtURL: "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/02/da/e1/02dae132-5acc-0ee0-7b0c-9db239e4b089/07UMGD06593.rgb.jpg/300x300bb.jpg",
            musicSource: "Spotify",
            sharedWorkoutData: pushData10,
            likeCount: 42,
            commentCount: 5,
            workoutEmotion: "Comeback"
        )
        p10.photoData = demoPhotoData
        if let photoData = demoPhotoData {
            let items: [PostMedia] = [
                PostMedia(exerciseName: nil, mediaType: .photo, data: photoData),
                PostMedia(exerciseName: "Dumbbell Press", exerciseIndex: 0, mediaType: .photo, data: photoData),
            ]
            p10.mediaItemsData = try? JSONEncoder().encode(items)
        }
        p10.albumArtData = bundledAlbumArt("stronger")
        modelContext.insert(p10)
        postIds.append(p10.id)

        // 11. Gym location post
        let legWorkout11 = SharedWorkoutData(
            title: "Morning Squat Session",
            workoutType: "Legs",
            estimatedDuration: 55,
            exercises: [
                SharedWorkoutData.SharedExercise(
                    name: "Squat",
                    muscleGroup: "Quads",
                    sets: [
                        .init(reps: 8, weight: 225, restSeconds: 120),
                        .init(reps: 6, weight: 255, restSeconds: 120),
                        .init(reps: 6, weight: 275, restSeconds: 150),
                    ],
                    demoTips: ["Brace core hard", "Drive through heels"]
                ),
                SharedWorkoutData.SharedExercise(
                    name: "Leg Press",
                    muscleGroup: "Quads",
                    sets: [
                        .init(reps: 12, weight: 360, restSeconds: 90),
                        .init(reps: 10, weight: 410, restSeconds: 90),
                    ],
                    demoTips: ["Feet shoulder width", "Full range of motion"]
                ),
                SharedWorkoutData.SharedExercise(
                    name: "Calf Raise",
                    muscleGroup: "Calves",
                    sets: [
                        .init(reps: 15, weight: 180, restSeconds: 60),
                        .init(reps: 15, weight: 180, restSeconds: 60),
                    ],
                    demoTips: ["Pause at the top", "Full stretch at bottom"]
                ),
            ],
            authorName: fakeUsers[0].name,
            authorUsername: fakeUsers[0].username
        )
        let legData11 = try? JSONEncoder().encode(legWorkout11)
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
            sharedWorkoutData: legData11,
            likeCount: 26,
            commentCount: 3,
            locationName: "The ARC - Queen's",
            workoutEmotion: "Grateful"
        )
        p11.photoData = demoPhotoData
        if let photoData = demoPhotoData {
            let items: [PostMedia] = [
                PostMedia(exerciseName: nil, mediaType: .photo, data: photoData),
                PostMedia(exerciseName: "Squat", exerciseIndex: 0, mediaType: .photo, data: photoData),
            ]
            p11.mediaItemsData = try? JSONEncoder().encode(items)
        }
        modelContext.insert(p11)
        postIds.append(p11.id)

        // 12. Music-focused post
        let pushWorkout12 = SharedWorkoutData(
            title: "OHP PR Day",
            workoutType: "Push",
            estimatedDuration: 48,
            exercises: [
                SharedWorkoutData.SharedExercise(
                    name: "Overhead Press",
                    muscleGroup: "Shoulders",
                    sets: [
                        .init(reps: 8, weight: 95, restSeconds: 90),
                        .init(reps: 6, weight: 115, restSeconds: 90),
                        .init(reps: 3, weight: 135, restSeconds: 120),
                    ],
                    demoTips: ["Brace core", "Lock out at the top"]
                ),
                SharedWorkoutData.SharedExercise(
                    name: "Bench Press",
                    muscleGroup: "Chest",
                    sets: [
                        .init(reps: 8, weight: 155, restSeconds: 90),
                        .init(reps: 8, weight: 175, restSeconds: 90),
                    ],
                    demoTips: ["Retract scapula", "Leg drive"]
                ),
                SharedWorkoutData.SharedExercise(
                    name: "Tricep Pushdown",
                    muscleGroup: "Triceps",
                    sets: [
                        .init(reps: 12, weight: 50, restSeconds: 60),
                        .init(reps: 12, weight: 60, restSeconds: 60),
                    ],
                    demoTips: ["Elbows pinned", "Full extension"]
                ),
            ],
            authorName: fakeUsers[1].name,
            authorUsername: fakeUsers[1].username
        )
        let pushData12 = try? JSONEncoder().encode(pushWorkout12)
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
            albumArtURL: "https://is1-ssl.mzstatic.com/image/thumb/Music122/v4/d0/f4/0e/d0f40ef3-86d2-af95-1003-14212e073991/17UMGIM15991.rgb.jpg/300x300bb.jpg",
            musicSource: "Spotify",
            sharedWorkoutData: pushData12,
            likeCount: 23,
            commentCount: 2,
            spotifyPlaylistURL: "https://open.spotify.com/playlist/37i9dQZF1DX0XUsuxWHRQd",
            workoutEmotion: "Strong"
        )
        p12.photoData = demoPhotoData
        if let photoData = demoPhotoData {
            let items: [PostMedia] = [
                PostMedia(exerciseName: nil, mediaType: .photo, data: photoData),
                PostMedia(exerciseName: "Overhead Press", exerciseIndex: 0, mediaType: .photo, data: photoData),
            ]
            p12.mediaItemsData = try? JSONEncoder().encode(items)
        }
        // PR: Olivia hit an OHP PR
        let p12PR = [FeedPR(exerciseName: "Overhead Press", value: "135 lbs", previousValue: "125 lbs", improvement: "+10 lbs", prType: "Weight PR")]
        p12.prMomentsData = try? JSONEncoder().encode(p12PR)
        p12.albumArtData = bundledAlbumArt("humble")
        modelContext.insert(p12)
        postIds.append(p12.id)

        // 13. Dragging but got it done
        let pullWorkout13 = SharedWorkoutData(
            title: "Light Pull Session",
            workoutType: "Pull",
            estimatedDuration: 35,
            exercises: [
                SharedWorkoutData.SharedExercise(
                    name: "Cable Row",
                    muscleGroup: "Back",
                    sets: [
                        .init(reps: 12, weight: 100, restSeconds: 60),
                        .init(reps: 10, weight: 120, restSeconds: 60),
                        .init(reps: 10, weight: 120, restSeconds: 60),
                    ],
                    demoTips: ["Squeeze shoulder blades", "Controlled tempo"]
                ),
                SharedWorkoutData.SharedExercise(
                    name: "Face Pull",
                    muscleGroup: "Rear Delts",
                    sets: [
                        .init(reps: 15, weight: 30, restSeconds: 45),
                        .init(reps: 15, weight: 35, restSeconds: 45),
                    ],
                    demoTips: ["Pull to forehead", "Externally rotate"]
                ),
                SharedWorkoutData.SharedExercise(
                    name: "Hammer Curl",
                    muscleGroup: "Biceps",
                    sets: [
                        .init(reps: 12, weight: 25, restSeconds: 45),
                        .init(reps: 10, weight: 30, restSeconds: 45),
                    ],
                    demoTips: ["Neutral grip", "No swinging"]
                ),
            ],
            authorName: fakeUsers[3].name,
            authorUsername: fakeUsers[3].username
        )
        let pullData13 = try? JSONEncoder().encode(pullWorkout13)
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
            sharedWorkoutData: pullData13,
            likeCount: 38,
            commentCount: 4,
            workoutEmotion: "Dragging"
        )
        p13.photoData = demoPhotoData
        if let photoData = demoPhotoData {
            let items: [PostMedia] = [
                PostMedia(exerciseName: nil, mediaType: .photo, data: photoData),
                PostMedia(exerciseName: "Cable Row", exerciseIndex: 0, mediaType: .photo, data: photoData),
            ]
            p13.mediaItemsData = try? JSONEncoder().encode(items)
        }
        modelContext.insert(p13)
        postIds.append(p13.id)

        // 14. Inspired-by chain
        let pullWorkout14 = SharedWorkoutData(
            title: "Pull Superset Program",
            workoutType: "Pull",
            estimatedDuration: 52,
            exercises: [
                SharedWorkoutData.SharedExercise(
                    name: "Pull Up",
                    muscleGroup: "Back",
                    sets: [
                        .init(reps: 10, weight: 0, restSeconds: 90),
                        .init(reps: 8, weight: 0, restSeconds: 90),
                        .init(reps: 6, weight: 25, restSeconds: 120),
                    ],
                    demoTips: ["Dead hang start", "Chin over bar"]
                ),
                SharedWorkoutData.SharedExercise(
                    name: "Barbell Row",
                    muscleGroup: "Back",
                    sets: [
                        .init(reps: 8, weight: 145, restSeconds: 90),
                        .init(reps: 8, weight: 165, restSeconds: 90),
                        .init(reps: 6, weight: 185, restSeconds: 90),
                    ],
                    demoTips: ["Hinge at hips", "Pull to belly button"]
                ),
                SharedWorkoutData.SharedExercise(
                    name: "Bicep Curls",
                    muscleGroup: "Biceps",
                    sets: [
                        .init(reps: 12, weight: 30, restSeconds: 60),
                        .init(reps: 10, weight: 35, restSeconds: 60),
                    ],
                    demoTips: ["Squeeze at top", "Slow eccentric"]
                ),
            ],
            authorName: fakeUsers[4].name,
            authorUsername: fakeUsers[4].username
        )
        let pullData14 = try? JSONEncoder().encode(pullWorkout14)
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
            sharedWorkoutData: pullData14,
            inspiredByUsername: fakeUsers[1].username,
            inspiredByName: fakeUsers[1].name,
            likeCount: 15,
            commentCount: 2,
            workoutEmotion: "Fired Up"
        )
        p14.photoData = demoPhotoData
        if let photoData = demoPhotoData {
            let items: [PostMedia] = [
                PostMedia(exerciseName: nil, mediaType: .photo, data: photoData),
                PostMedia(exerciseName: "Pull Up", exerciseIndex: 0, mediaType: .photo, data: photoData),
            ]
            p14.mediaItemsData = try? JSONEncoder().encode(items)
        }
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
        p15.photoData = demoPhotoData
        if let photoData = demoPhotoData {
            let items: [PostMedia] = [
                PostMedia(exerciseName: nil, mediaType: .photo, data: photoData),
                PostMedia(exerciseName: "Squat", exerciseIndex: 0, mediaType: .photo, data: photoData),
            ]
            p15.mediaItemsData = try? JSONEncoder().encode(items)
        }
        modelContext.insert(p15)
        postIds.append(p15.id)

        // 16. Progress milestone workout
        let legWorkout16 = SharedWorkoutData(
            title: "Week 8 Leg Day",
            workoutType: "Legs",
            estimatedDuration: 50,
            exercises: [
                SharedWorkoutData.SharedExercise(
                    name: "Squat",
                    muscleGroup: "Quads",
                    sets: [
                        .init(reps: 8, weight: 185, restSeconds: 90),
                        .init(reps: 6, weight: 205, restSeconds: 120),
                        .init(reps: 4, weight: 225, restSeconds: 150),
                    ],
                    demoTips: ["Brace hard", "Below parallel"]
                ),
                SharedWorkoutData.SharedExercise(
                    name: "Leg Curl",
                    muscleGroup: "Hamstrings",
                    sets: [
                        .init(reps: 12, weight: 80, restSeconds: 60),
                        .init(reps: 10, weight: 90, restSeconds: 60),
                    ],
                    demoTips: ["Squeeze at peak", "Control the eccentric"]
                ),
                SharedWorkoutData.SharedExercise(
                    name: "Walking Lunge",
                    muscleGroup: "Quads",
                    sets: [
                        .init(reps: 12, weight: 40, restSeconds: 60),
                        .init(reps: 12, weight: 40, restSeconds: 60),
                    ],
                    demoTips: ["Long stride", "Knee tracks over toe"]
                ),
            ],
            authorName: fakeUsers[5].name,
            authorUsername: fakeUsers[5].username
        )
        let legData16 = try? JSONEncoder().encode(legWorkout16)
        let p16 = Post(
            authorId: fakeUsers[5].id,
            authorName: fakeUsers[5].name,
            authorUsername: fakeUsers[5].username,
            timestamp: hoursAgo(26),
            caption: "Week 8 of consistent training. Down 4 lbs, squat went from 185 to 225. Trust the process.",
            workoutType: "Legs",
            duration: 50,
            setCount: 15,
            exerciseHighlight: "Squat",
            sharedWorkoutData: legData16,
            likeCount: 29,
            commentCount: 3,
            workoutEmotion: "Grateful"
        )
        p16.photoData = demoPhotoData
        if let photoData = demoPhotoData {
            let items: [PostMedia] = [
                PostMedia(exerciseName: nil, mediaType: .photo, data: photoData),
                PostMedia(exerciseName: "Squat", exerciseIndex: 0, mediaType: .photo, data: photoData),
            ]
            p16.mediaItemsData = try? JSONEncoder().encode(items)
        }
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
            albumArtURL: "https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/e4/7d/96/e47d964e-7879-b498-baf8-b0da1a964695/20UMGIM12176.rgb.jpg/300x300bb.jpg",
            musicSource: "Apple Music",
            likeCount: 14,
            commentCount: 1,
            locationName: "GoodLife Downtown",
            workoutEmotion: "Grinding"
        )
        p17.photoData = demoPhotoData
        if let photoData = demoPhotoData {
            let items: [PostMedia] = [
                PostMedia(exerciseName: nil, mediaType: .photo, data: photoData),
                PostMedia(exerciseName: "Treadmill", exerciseIndex: 0, mediaType: .photo, data: photoData),
            ]
            p17.mediaItemsData = try? JSONEncoder().encode(items)
        }
        let p17Workout = SharedWorkoutData(
            title: "Treadmill HIIT",
            workoutType: "Cardio",
            estimatedDuration: 20,
            exercises: [
                SharedWorkoutData.SharedExercise(name: "Treadmill Intervals", muscleGroup: "Cardio", sets: [.init(reps: 12, weight: 0, restSeconds: 60)], demoTips: ["30s sprint / 60s walk", "Increase incline each round"]),
                SharedWorkoutData.SharedExercise(name: "Jump Rope", muscleGroup: "Cardio", sets: [.init(reps: 3, weight: 0, restSeconds: 30)], demoTips: ["Stay on balls of feet", "Keep wrists relaxed"]),
            ],
            authorName: fakeUsers[7].name,
            authorUsername: fakeUsers[7].username
        )
        p17.sharedWorkoutData = try? JSONEncoder().encode(p17Workout)
        p17.albumArtData = bundledAlbumArt("blinding_lights")
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
        p18.photoData = demoPhotoData
        if let photoData = demoPhotoData {
            let items: [PostMedia] = [
                PostMedia(exerciseName: nil, mediaType: .photo, data: photoData),
                PostMedia(exerciseName: "Lateral Raise", exerciseIndex: 0, mediaType: .photo, data: photoData),
            ]
            p18.mediaItemsData = try? JSONEncoder().encode(items)
        }
        let p18Workout = SharedWorkoutData(
            title: "Shoulder Burner",
            workoutType: "Push",
            estimatedDuration: 42,
            exercises: [
                SharedWorkoutData.SharedExercise(name: "Lateral Raise", muscleGroup: "Shoulders", sets: [.init(reps: 15, weight: 20, restSeconds: 45), .init(reps: 12, weight: 25, restSeconds: 45), .init(reps: 10, weight: 25, restSeconds: 45)], demoTips: ["Slight bend in elbows", "Control the negative"]),
                SharedWorkoutData.SharedExercise(name: "Arnold Press", muscleGroup: "Shoulders", sets: [.init(reps: 10, weight: 40, restSeconds: 90), .init(reps: 8, weight: 45, restSeconds: 90)], demoTips: ["Rotate palms outward", "Full range of motion"]),
                SharedWorkoutData.SharedExercise(name: "Cable Fly", muscleGroup: "Chest", sets: [.init(reps: 12, weight: 25, restSeconds: 60), .init(reps: 12, weight: 25, restSeconds: 60)], demoTips: ["Slight bend in elbows", "Squeeze at center"]),
            ],
            authorName: fakeUsers[6].name,
            authorUsername: fakeUsers[6].username
        )
        p18.sharedWorkoutData = try? JSONEncoder().encode(p18Workout)
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
        let p19Workout = SharedWorkoutData(
            title: "Early Bird Pull",
            workoutType: "Pull",
            estimatedDuration: 58,
            exercises: [
                SharedWorkoutData.SharedExercise(name: "Deadlift", muscleGroup: "Back", sets: [.init(reps: 1, weight: 365, restSeconds: 240), .init(reps: 3, weight: 335, restSeconds: 180)], demoTips: ["Neutral spine", "Brace core hard"]),
                SharedWorkoutData.SharedExercise(name: "Barbell Row", muscleGroup: "Back", sets: [.init(reps: 8, weight: 185, restSeconds: 90), .init(reps: 8, weight: 185, restSeconds: 90)], demoTips: ["Hinge at hips", "Pull to belly button"]),
                SharedWorkoutData.SharedExercise(name: "Pull Up", muscleGroup: "Back", sets: [.init(reps: 10, weight: 0, restSeconds: 90), .init(reps: 8, weight: 0, restSeconds: 90)], demoTips: ["Full hang at bottom", "Chin over bar"]),
            ],
            authorName: fakeUsers[8].name,
            authorUsername: fakeUsers[8].username
        )
        p19.sharedWorkoutData = try? JSONEncoder().encode(p19Workout)
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
        p20.photoData = demoPhotoData
        if let photoData = demoPhotoData {
            let items: [PostMedia] = [
                PostMedia(exerciseName: nil, mediaType: .photo, data: photoData),
                PostMedia(exerciseName: "Squat", exerciseIndex: 0, mediaType: .photo, data: photoData),
            ]
            p20.mediaItemsData = try? JSONEncoder().encode(items)
        }
        let p20Workout = SharedWorkoutData(
            title: "Recovery Legs",
            workoutType: "Legs",
            estimatedDuration: 30,
            exercises: [
                SharedWorkoutData.SharedExercise(name: "Squat", muscleGroup: "Quads", sets: [.init(reps: 10, weight: 135, restSeconds: 90), .init(reps: 10, weight: 135, restSeconds: 90)], demoTips: ["Light weight, focus form", "Full depth"]),
                SharedWorkoutData.SharedExercise(name: "Hip Thrust", muscleGroup: "Glutes", sets: [.init(reps: 12, weight: 135, restSeconds: 60), .init(reps: 12, weight: 135, restSeconds: 60)], demoTips: ["Drive through heels", "Squeeze glutes at top"]),
                SharedWorkoutData.SharedExercise(name: "Leg Extension", muscleGroup: "Quads", sets: [.init(reps: 15, weight: 70, restSeconds: 45), .init(reps: 15, weight: 70, restSeconds: 45)], demoTips: ["Slow and controlled", "Pause at top"]),
            ],
            authorName: fakeUsers[9].name,
            authorUsername: fakeUsers[9].username
        )
        p20.sharedWorkoutData = try? JSONEncoder().encode(p20Workout)
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
            albumArtURL: "https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/75/2e/80/752e8083-8837-e13c-7697-136b5a346873/20UMGIM55963.rgb.jpg/300x300bb.jpg",
            musicSource: "Spotify",
            inspiredByUsername: fakeUsers[3].username,
            inspiredByName: fakeUsers[3].name,
            likeCount: 16,
            commentCount: 1,
            spotifyPlaylistURL: "https://open.spotify.com/playlist/37i9dQZF1DX8tZsk68tuoQ"
        )
        p21.photoData = demoPhotoData
        if let photoData = demoPhotoData {
            let items: [PostMedia] = [
                PostMedia(exerciseName: nil, mediaType: .photo, data: photoData),
                PostMedia(exerciseName: "Outdoor Run", exerciseIndex: 0, mediaType: .photo, data: photoData),
            ]
            p21.mediaItemsData = try? JSONEncoder().encode(items)
        }
        let p21Workout = SharedWorkoutData(
            title: "Outdoor Run",
            workoutType: "Cardio",
            estimatedDuration: 32,
            exercises: [
                SharedWorkoutData.SharedExercise(name: "Outdoor Run", muscleGroup: "Cardio", sets: [.init(reps: 1, weight: 0, restSeconds: 0)], demoTips: ["Steady pace", "Focus on breathing"]),
                SharedWorkoutData.SharedExercise(name: "Walking Lunge", muscleGroup: "Legs", sets: [.init(reps: 20, weight: 0, restSeconds: 60), .init(reps: 20, weight: 0, restSeconds: 60)], demoTips: ["Long strides", "Keep torso upright"]),
            ],
            authorName: fakeUsers[0].name,
            authorUsername: fakeUsers[0].username
        )
        p21.sharedWorkoutData = try? JSONEncoder().encode(p21Workout)
        p21.albumArtData = bundledAlbumArt("levitating")
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
        p22.photoData = demoPhotoData
        if let photoData = demoPhotoData {
            let items: [PostMedia] = [
                PostMedia(exerciseName: nil, mediaType: .photo, data: photoData),
                PostMedia(exerciseName: "Dumbbell Press", exerciseIndex: 0, mediaType: .photo, data: photoData),
            ]
            p22.mediaItemsData = try? JSONEncoder().encode(items)
        }
        let p22Workout = SharedWorkoutData(
            title: "Late Night Push",
            workoutType: "Push",
            estimatedDuration: 38,
            exercises: [
                SharedWorkoutData.SharedExercise(name: "Dumbbell Press", muscleGroup: "Chest", sets: [.init(reps: 10, weight: 70, restSeconds: 90), .init(reps: 8, weight: 75, restSeconds: 90)], demoTips: ["Full stretch at bottom", "Press evenly"]),
                SharedWorkoutData.SharedExercise(name: "Chest Fly", muscleGroup: "Chest", sets: [.init(reps: 12, weight: 30, restSeconds: 60), .init(reps: 12, weight: 30, restSeconds: 60)], demoTips: ["Slight bend in elbows", "Feel the stretch"]),
                SharedWorkoutData.SharedExercise(name: "Tricep Extension", muscleGroup: "Triceps", sets: [.init(reps: 12, weight: 25, restSeconds: 60), .init(reps: 10, weight: 30, restSeconds: 60)], demoTips: ["Lock elbows overhead", "Full range of motion"]),
            ],
            authorName: fakeUsers[4].name,
            authorUsername: fakeUsers[4].username
        )
        p22.sharedWorkoutData = try? JSONEncoder().encode(p22Workout)
        modelContext.insert(p22)
        postIds.append(p22.id)

        // 23. Club shoutout (converted to workout post)
        let p23 = Post(
            authorId: fakeUsers[6].id,
            authorName: fakeUsers[6].name,
            authorUsername: fakeUsers[6].username,
            timestamp: hoursAgo(44),
            caption: "Shoutout to the ARC morning crew. Nothing beats training with people who actually push you.",
            workoutType: "Push",
            duration: 50,
            setCount: 15,
            exerciseHighlight: "Bench Press",
            likeCount: 35,
            commentCount: 3,
            locationName: "The ARC - Queen's",
            workoutEmotion: "Fired Up"
        )
        p23.photoData = demoPhotoData
        if let photoData = demoPhotoData {
            let items: [PostMedia] = [
                PostMedia(exerciseName: nil, mediaType: .photo, data: photoData),
                PostMedia(exerciseName: "Bench Press", exerciseIndex: 0, mediaType: .photo, data: photoData),
            ]
            p23.mediaItemsData = try? JSONEncoder().encode(items)
        }
        let p23Workout = SharedWorkoutData(
            title: "Morning Push Session",
            workoutType: "Push",
            estimatedDuration: 50,
            exercises: [
                SharedWorkoutData.SharedExercise(name: "Bench Press", muscleGroup: "Chest", sets: [.init(reps: 8, weight: 185, restSeconds: 90), .init(reps: 8, weight: 185, restSeconds: 90), .init(reps: 6, weight: 205, restSeconds: 120)], demoTips: ["Retract scapula", "Touch chest"]),
                SharedWorkoutData.SharedExercise(name: "Incline Dumbbell Press", muscleGroup: "Chest", sets: [.init(reps: 10, weight: 60, restSeconds: 90), .init(reps: 8, weight: 65, restSeconds: 90)], demoTips: ["30 degree incline", "Full stretch at bottom"]),
                SharedWorkoutData.SharedExercise(name: "Tricep Dips", muscleGroup: "Triceps", sets: [.init(reps: 12, weight: 0, restSeconds: 60), .init(reps: 10, weight: 0, restSeconds: 60)], demoTips: ["Lean forward slightly", "Full lockout"]),
            ],
            authorName: fakeUsers[6].name,
            authorUsername: fakeUsers[6].username
        )
        p23.sharedWorkoutData = try? JSONEncoder().encode(p23Workout)
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
        let p24Workout = SharedWorkoutData(
            title: "Bench PR Day",
            workoutType: "Push",
            estimatedDuration: 55,
            exercises: [
                SharedWorkoutData.SharedExercise(name: "Bench Press", muscleGroup: "Chest", sets: [.init(reps: 1, weight: 225, restSeconds: 300), .init(reps: 5, weight: 185, restSeconds: 120)], demoTips: ["Arch back", "Leg drive"]),
                SharedWorkoutData.SharedExercise(name: "Incline Dumbbell Press", muscleGroup: "Chest", sets: [.init(reps: 10, weight: 65, restSeconds: 90), .init(reps: 8, weight: 70, restSeconds: 90)], demoTips: ["30 degree incline", "Full stretch"]),
                SharedWorkoutData.SharedExercise(name: "Tricep Dips", muscleGroup: "Triceps", sets: [.init(reps: 15, weight: 0, restSeconds: 60), .init(reps: 12, weight: 0, restSeconds: 60)], demoTips: ["Lean forward for chest", "Full lockout"]),
            ],
            authorName: fakeUsers[8].name,
            authorUsername: fakeUsers[8].username
        )
        p24.sharedWorkoutData = try? JSONEncoder().encode(p24Workout)
        // PR: Liam hit 2 plates on bench
        let p24PR = [FeedPR(exerciseName: "Bench Press", value: "225×1", previousValue: "215×1", improvement: "+10 lbs", prType: "Weight PR")]
        p24.prMomentsData = try? JSONEncoder().encode(p24PR)
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
            albumArtURL: "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/93/57/69/935769dc-30e4-95e1-1da0-a3a2c4382dd0/16UMGIM65828.rgb.jpg/300x300bb.jpg",
            musicSource: "Spotify",
            likeCount: 21,
            commentCount: 2,
            workoutEmotion: "Calm"
        )
        p25.albumArtData = bundledAlbumArt("starboy")
        p25.photoData = demoPhotoData
        if let photoData = demoPhotoData {
            let items: [PostMedia] = [
                PostMedia(exerciseName: nil, mediaType: .photo, data: photoData),
                PostMedia(exerciseName: "Cycling", exerciseIndex: 0, mediaType: .photo, data: photoData),
            ]
            p25.mediaItemsData = try? JSONEncoder().encode(items)
        }
        let cycleRoute: [RoutePoint] = [
            RoutePoint(latitude: 43.6426, longitude: -79.3871, altitude: 75, timestamp: 0, speed: 7.5, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6400, longitude: -79.3820, altitude: 75, timestamp: 120, speed: 8.0, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6380, longitude: -79.3760, altitude: 74, timestamp: 300, speed: 8.2, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6365, longitude: -79.3700, altitude: 74, timestamp: 480, speed: 7.8, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6358, longitude: -79.3640, altitude: 74, timestamp: 660, speed: 8.5, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6370, longitude: -79.3580, altitude: 75, timestamp: 840, speed: 8.0, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6395, longitude: -79.3530, altitude: 75, timestamp: 1020, speed: 7.6, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6420, longitude: -79.3500, altitude: 76, timestamp: 1200, speed: 8.1, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6450, longitude: -79.3520, altitude: 76, timestamp: 1400, speed: 7.9, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6460, longitude: -79.3570, altitude: 75, timestamp: 1600, speed: 8.3, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6450, longitude: -79.3630, altitude: 75, timestamp: 1800, speed: 7.7, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6440, longitude: -79.3700, altitude: 75, timestamp: 2000, speed: 8.0, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6430, longitude: -79.3780, altitude: 75, timestamp: 2200, speed: 7.5, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6426, longitude: -79.3871, altitude: 75, timestamp: 2400, speed: 7.0, horizontalAccuracy: 5),
        ]
        let p25Workout = SharedWorkoutData(
            title: "Waterfront Ride",
            workoutType: "Cardio",
            estimatedDuration: 65,
            exercises: [
                SharedWorkoutData.SharedExercise(name: "Cycling Intervals", muscleGroup: "Cardio", sets: [.init(reps: 1, weight: 0, restSeconds: 0)], demoTips: ["Maintain cadence", "Stay in aero position"]),
            ],
            authorName: fakeUsers[5].name,
            authorUsername: fakeUsers[5].username,
            routePoints: cycleRoute
        )
        p25.sharedWorkoutData = try? JSONEncoder().encode(p25Workout)
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
        p26.photoData = demoPhotoData
        if let photoData = demoPhotoData {
            let items: [PostMedia] = [
                PostMedia(exerciseName: nil, mediaType: .photo, data: photoData),
                PostMedia(exerciseName: "Rowing", exerciseIndex: 0, mediaType: .photo, data: photoData),
            ]
            p26.mediaItemsData = try? JSONEncoder().encode(items)
        }
        let rowRoute: [RoutePoint] = [
            RoutePoint(latitude: 43.6510, longitude: -79.3700, altitude: 75, timestamp: 0, speed: 4.0, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6520, longitude: -79.3680, altitude: 75, timestamp: 60, speed: 4.2, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6535, longitude: -79.3665, altitude: 75, timestamp: 120, speed: 4.5, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6548, longitude: -79.3655, altitude: 75, timestamp: 200, speed: 4.3, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6560, longitude: -79.3660, altitude: 75, timestamp: 280, speed: 4.1, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6565, longitude: -79.3680, altitude: 75, timestamp: 350, speed: 4.4, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6555, longitude: -79.3695, altitude: 75, timestamp: 420, speed: 4.2, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6540, longitude: -79.3705, altitude: 75, timestamp: 500, speed: 4.0, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6525, longitude: -79.3710, altitude: 75, timestamp: 580, speed: 4.3, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6510, longitude: -79.3700, altitude: 75, timestamp: 660, speed: 3.8, horizontalAccuracy: 5),
        ]
        let p26Workout = SharedWorkoutData(
            title: "Row Challenge",
            workoutType: "Cardio",
            estimatedDuration: 25,
            exercises: [
                SharedWorkoutData.SharedExercise(name: "Rowing Intervals", muscleGroup: "Cardio", sets: [.init(reps: 1, weight: 0, restSeconds: 0)], demoTips: ["Drive with legs first", "Keep core tight"]),
            ],
            authorName: fakeUsers[9].name,
            authorUsername: fakeUsers[9].username,
            routePoints: rowRoute
        )
        p26.sharedWorkoutData = try? JSONEncoder().encode(p26Workout)
        modelContext.insert(p26)
        postIds.append(p26.id)

        // 27. Hiking cardio post with route
        let hikeRoute: [RoutePoint] = [
            RoutePoint(latitude: 43.6700, longitude: -79.4100, altitude: 85, timestamp: 0, speed: 1.4, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6715, longitude: -79.4085, altitude: 92, timestamp: 180, speed: 1.5, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6730, longitude: -79.4065, altitude: 105, timestamp: 400, speed: 1.3, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6748, longitude: -79.4050, altitude: 118, timestamp: 620, speed: 1.2, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6760, longitude: -79.4038, altitude: 130, timestamp: 850, speed: 1.1, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6775, longitude: -79.4045, altitude: 142, timestamp: 1080, speed: 1.0, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6782, longitude: -79.4060, altitude: 148, timestamp: 1300, speed: 1.2, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6778, longitude: -79.4080, altitude: 140, timestamp: 1520, speed: 1.4, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6760, longitude: -79.4092, altitude: 125, timestamp: 1740, speed: 1.5, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6740, longitude: -79.4098, altitude: 110, timestamp: 1960, speed: 1.6, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6720, longitude: -79.4100, altitude: 95, timestamp: 2180, speed: 1.5, horizontalAccuracy: 5),
            RoutePoint(latitude: 43.6700, longitude: -79.4100, altitude: 85, timestamp: 2400, speed: 1.3, horizontalAccuracy: 5),
        ]
        let hikeWorkoutData = SharedWorkoutData(
            title: "Morning Hike",
            workoutType: "Cardio",
            estimatedDuration: 48,
            authorName: fakeUsers[6].name,
            authorUsername: fakeUsers[6].username,
            routePoints: hikeRoute
        )
        let hikeData = try? JSONEncoder().encode(hikeWorkoutData)
        let p27 = Post(
            authorId: fakeUsers[6].id,
            authorName: fakeUsers[6].name,
            authorUsername: fakeUsers[6].username,
            timestamp: hoursAgo(38),
            caption: "Sunrise hike through the ravine. 350m elevation gain. Nature is the best pre-workout.",
            workoutType: "Cardio",
            duration: 48,
            exerciseHighlight: "Hiking",
            likeCount: 29,
            commentCount: 3,
            workoutEmotion: "Grateful"
        )
        p27.photoData = demoPhotoData
        if let photoData = demoPhotoData {
            let items: [PostMedia] = [
                PostMedia(exerciseName: nil, mediaType: .photo, data: photoData),
                PostMedia(exerciseName: "Hiking", exerciseIndex: 0, mediaType: .photo, data: photoData),
            ]
            p27.mediaItemsData = try? JSONEncoder().encode(items)
        }
        p27.sharedWorkoutData = hikeData
        modelContext.insert(p27)
        postIds.append(p27.id)

        // MARK: - Challenge Posts

        // 28. "100 Push-ups Daily" challenge by Olivia Park
        let challengeId1 = UUID()
        let challengeEnd1 = Calendar.current.date(byAdding: .month, value: 3, to: now) ?? now
        let challengeData1 = PostChallengeData(
            challengeId: challengeId1,
            title: "100 Push-ups Daily",
            goalType: ChallengeGoalType.sets.rawValue,
            goalTarget: 100,
            endDate: challengeEnd1,
            participantCount: 47
        )
        let p28 = Post(
            authorId: fakeUsers[2].id,
            authorName: fakeUsers[2].name,
            authorUsername: fakeUsers[2].username,
            timestamp: hoursAgo(3),
            caption: "Starting this challenge today! 💪 100 push-ups every single day until summer. Who's joining me?",
            workoutType: "Push",
            likeCount: 62,
            commentCount: 8,
            challengeId: challengeId1,
            challengeData: try? JSONEncoder().encode(challengeData1)
        )
        p28.photoData = demoPhotoData
        modelContext.insert(p28)
        postIds.append(p28.id)

        let challenge1 = Challenge(
            id: challengeId1,
            scope: .club,
            title: "100 Push-ups Daily",
            challengeDescription: "Complete 100 push-ups every day until summer",
            goalType: .sets,
            goalTarget: 100,
            startDate: now,
            endDate: challengeEnd1,
            xpReward: 100
        )
        modelContext.insert(challenge1)

        // 29. "30-Day Gym Streak" challenge by Jake Reeves
        let challengeId2 = UUID()
        let challengeEnd2 = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now
        let challengeData2 = PostChallengeData(
            challengeId: challengeId2,
            title: "30-Day Gym Streak",
            goalType: ChallengeGoalType.streak.rawValue,
            goalTarget: 30,
            endDate: challengeEnd2,
            participantCount: 23
        )
        let p29 = Post(
            authorId: fakeUsers[4].id,
            authorName: fakeUsers[4].name,
            authorUsername: fakeUsers[4].username,
            timestamp: hoursAgo(8),
            caption: "No excuses for the next 30 days. Hit the gym every single day. Let's see who can keep the streak alive 🔥",
            workoutType: "Full Body",
            likeCount: 41,
            commentCount: 5,
            challengeId: challengeId2,
            challengeData: try? JSONEncoder().encode(challengeData2)
        )
        p29.photoData = demoPhotoData
        modelContext.insert(p29)
        postIds.append(p29.id)

        let challenge2 = Challenge(
            id: challengeId2,
            scope: .club,
            title: "30-Day Gym Streak",
            challengeDescription: "Hit the gym every day for 30 consecutive days",
            goalType: .streak,
            goalTarget: 30,
            startDate: now,
            endDate: challengeEnd2,
            xpReward: 100
        )
        modelContext.insert(challenge2)

        // MARK: - Engagement Metrics (batch update all social posts)

        let allSocialPosts = [p1, p2, p3, p4, p5, p6, p7, p8, p9, p10,
                              p11, p12, p13, p14, p15, p16, p17, p18, p19, p20,
                              p21, p22, p23, p24, p25, p26, p27, p28, p29]
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

        // MARK: - Reactions on Social Posts (for social proof line)

        let socialReactions: [(Int, Int, ReactionType, Double)] = [
            // Post 1 (Marcus push day)
            (0, 1, .fire, 0.3), (0, 2, .strong, 0.4), (0, 3, .clap, 0.5), (0, 5, .heart, 0.6), (0, 6, .fire, 0.7),
            // Post 2 (Olivia pull)
            (1, 0, .strong, 0.9), (1, 4, .fire, 1.0), (1, 6, .thumbsUp, 1.1), (1, 8, .clap, 1.2),
            // Post 3 (Jake leg day PR)
            (2, 0, .fire, 2.0), (2, 1, .shocked, 2.1), (2, 3, .strong, 2.2), (2, 5, .clap, 2.3), (2, 7, .fire, 2.4), (2, 9, .heart, 2.5),
            // Post 5 (Tyler push)
            (4, 0, .strong, 5.0), (4, 2, .fire, 5.1), (4, 7, .clap, 5.2), (4, 9, .heart, 5.3),
            // Post 10 (Ava comeback)
            (9, 0, .heart, 13.5), (9, 1, .clap, 13.6), (9, 3, .strong, 13.7), (9, 5, .heart, 13.8), (9, 6, .fire, 13.9),
            // Post 28 (cycling premium)
            (27, 0, .fire, 48.0), (27, 1, .strong, 48.1), (27, 3, .shocked, 48.2), (27, 5, .clap, 48.3), (27, 7, .heart, 48.4), (27, 9, .fire, 48.5),
            // Post 29 (trail run PR)
            (28, 0, .fire, 2.0), (28, 1, .shocked, 2.1), (28, 2, .strong, 2.2), (28, 3, .clap, 2.3), (28, 5, .fire, 2.4), (28, 7, .heart, 2.5), (28, 8, .strong, 2.6), (28, 9, .fire, 2.7),
        ]
        for (postIdx, userIdx, rType, hrs) in socialReactions {
            guard postIdx < postIds.count else { continue }
            let reaction = Reaction(
                odId: fakeUsers[userIdx].id,
                odUsername: fakeUsers[userIdx].username,
                targetType: "post",
                targetId: postIds[postIdx],
                reactionType: rType,
                createdAt: Date().addingTimeInterval(-hrs * 3600)
            )
            modelContext.insert(reaction)
        }

        // MARK: - Current User's Posts (for Activity tab demo data)

        let profileDescriptorEarly = FetchDescriptor<UserProfile>()
        let profilesEarly = (try? modelContext.fetch(profileDescriptorEarly)) ?? []
        var myPostIds: [UUID] = []
        if let myProfile = profilesEarly.first {

            // ── Post A: Bench press session (enriched) ──────────────────
            let myPost1 = Post(
                authorId: myProfile.id,
                authorName: myProfile.name,
                authorUsername: myProfile.username,
                timestamp: hoursAgo(3),
                caption: "Hit 185 on bench for a clean triple. Slow grind but we're getting there.",
                workoutType: "Push",
                duration: 48,
                setCount: 16,
                exerciseHighlight: "Bench Press",
                songTitle: "Lose Yourself",
                artistName: "Eminem",
                albumArtURL: "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/a0/4d/c4/a04dc484-03cc-02aa-fa82-5334fcb4bc16/18UMGIM24878.rgb.jpg/300x300bb.jpg",
                musicSource: "Apple Music",
                detectedActivity: "Weights",
                likeCount: 11,
                commentCount: 5,
                locationName: "GoodLife Fitness",
                workoutEmotion: "Fired Up"
            )
            let postAWorkout = SharedWorkoutData(
                title: "Push Day",
                workoutType: "Push",
                estimatedDuration: 48,
                exercises: [
                    SharedWorkoutData.SharedExercise(name: "Bench Press", muscleGroup: "Chest", sets: [.init(reps: 3, weight: 185, restSeconds: 120), .init(reps: 5, weight: 175, restSeconds: 120), .init(reps: 5, weight: 175, restSeconds: 120)], demoTips: ["Retract scapula", "Drive feet into floor"]),
                    SharedWorkoutData.SharedExercise(name: "Overhead Press", muscleGroup: "Shoulders", sets: [.init(reps: 8, weight: 95, restSeconds: 90), .init(reps: 8, weight: 95, restSeconds: 90), .init(reps: 6, weight: 105, restSeconds: 90)], demoTips: ["Brace core", "Lock out overhead"]),
                    SharedWorkoutData.SharedExercise(name: "Tricep Dips", muscleGroup: "Triceps", sets: [.init(reps: 12, weight: 0, restSeconds: 60), .init(reps: 10, weight: 0, restSeconds: 60)], demoTips: ["Lean slightly forward", "Full lockout"]),
                ],
                authorName: myProfile.name,
                authorUsername: myProfile.username
            )
            myPost1.sharedWorkoutData = try? JSONEncoder().encode(postAWorkout)
            let postAPR = [FeedPR(exerciseName: "Bench Press", value: "185×3", previousValue: "175×3", improvement: "+10 lbs", prType: "Weight PR")]
            myPost1.prMomentsData = try? JSONEncoder().encode(postAPR)
            myPost1.albumArtData = bundledAlbumArt("lose_yourself")
            modelContext.insert(myPost1)
            myPostIds.append(myPost1.id)

            // ── Post B: Leg day (enriched) ──────────────────────────────
            let myPost2 = Post(
                authorId: myProfile.id,
                authorName: myProfile.name,
                authorUsername: myProfile.username,
                timestamp: hoursAgo(18),
                caption: "Leg day done. Squats, RDLs, leg press. Walking is optional tomorrow.",
                workoutType: "Legs",
                duration: 55,
                setCount: 20,
                exerciseHighlight: "Squat",
                detectedActivity: "Weights",
                likeCount: 7,
                commentCount: 3,
                workoutEmotion: "Grinding"
            )
            let postBWorkout = SharedWorkoutData(
                title: "Leg Day",
                workoutType: "Legs",
                estimatedDuration: 55,
                exercises: [
                    SharedWorkoutData.SharedExercise(name: "Squat", muscleGroup: "Quads", sets: [.init(reps: 5, weight: 225, restSeconds: 150), .init(reps: 5, weight: 225, restSeconds: 150), .init(reps: 5, weight: 225, restSeconds: 150)], demoTips: ["Break at hips first", "Drive knees out"]),
                    SharedWorkoutData.SharedExercise(name: "Romanian Deadlift", muscleGroup: "Hamstrings", sets: [.init(reps: 10, weight: 185, restSeconds: 90), .init(reps: 10, weight: 185, restSeconds: 90)], demoTips: ["Hinge at hips", "Feel the stretch"]),
                    SharedWorkoutData.SharedExercise(name: "Leg Press", muscleGroup: "Quads", sets: [.init(reps: 12, weight: 360, restSeconds: 90), .init(reps: 10, weight: 400, restSeconds: 90)], demoTips: ["Full range of motion", "Don't lock knees"]),
                ],
                authorName: myProfile.name,
                authorUsername: myProfile.username
            )
            myPost2.sharedWorkoutData = try? JSONEncoder().encode(postBWorkout)
            modelContext.insert(myPost2)
            myPostIds.append(myPost2.id)

            // ── Post C: Cycling ride with GPS route ─────────────────────
            let cycleRoute: [RoutePoint] = [
                RoutePoint(latitude: 43.6426, longitude: -79.3871, altitude: 76, timestamp: 0, speed: 6.5, horizontalAccuracy: 5),
                RoutePoint(latitude: 43.6450, longitude: -79.3820, altitude: 77, timestamp: 300, speed: 7.0, horizontalAccuracy: 5),
                RoutePoint(latitude: 43.6490, longitude: -79.3780, altitude: 78, timestamp: 600, speed: 7.2, horizontalAccuracy: 5),
                RoutePoint(latitude: 43.6540, longitude: -79.3750, altitude: 79, timestamp: 900, speed: 6.8, horizontalAccuracy: 5),
                RoutePoint(latitude: 43.6590, longitude: -79.3730, altitude: 80, timestamp: 1200, speed: 7.1, horizontalAccuracy: 5),
                RoutePoint(latitude: 43.6630, longitude: -79.3760, altitude: 81, timestamp: 1500, speed: 6.9, horizontalAccuracy: 5),
                RoutePoint(latitude: 43.6650, longitude: -79.3800, altitude: 80, timestamp: 1800, speed: 7.3, horizontalAccuracy: 5),
                RoutePoint(latitude: 43.6640, longitude: -79.3840, altitude: 79, timestamp: 2100, speed: 7.0, horizontalAccuracy: 5),
                RoutePoint(latitude: 43.6610, longitude: -79.3870, altitude: 78, timestamp: 2400, speed: 6.7, horizontalAccuracy: 5),
                RoutePoint(latitude: 43.6570, longitude: -79.3890, altitude: 77, timestamp: 2700, speed: 6.5, horizontalAccuracy: 5),
                RoutePoint(latitude: 43.6520, longitude: -79.3900, altitude: 77, timestamp: 3000, speed: 6.8, horizontalAccuracy: 5),
                RoutePoint(latitude: 43.6480, longitude: -79.3895, altitude: 76, timestamp: 3150, speed: 6.6, horizontalAccuracy: 5),
                RoutePoint(latitude: 43.6450, longitude: -79.3880, altitude: 76, timestamp: 3200, speed: 6.4, horizontalAccuracy: 5),
                RoutePoint(latitude: 43.6426, longitude: -79.3871, altitude: 76, timestamp: 3300, speed: 6.0, horizontalAccuracy: 5),
            ]
            let cycleWorkoutData = SharedWorkoutData(
                title: "Evening Ride",
                workoutType: "Cardio",
                estimatedDuration: 55,
                authorName: myProfile.name,
                authorUsername: myProfile.username,
                routePoints: cycleRoute
            )
            let myPost3 = Post(
                authorId: myProfile.id,
                authorName: myProfile.name,
                authorUsername: myProfile.username,
                timestamp: hoursAgo(26),
                caption: "25km loop along the lakeshore. Wind was brutal on the way back but worth every pedal stroke.",
                workoutType: "Cardio",
                duration: 55,
                exerciseHighlight: "Cycling",
                songTitle: "Blinding Lights",
                artistName: "The Weeknd",
                albumArtURL: "https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/e4/7d/96/e47d964e-7879-b498-baf8-b0da1a964695/20UMGIM12176.rgb.jpg/300x300bb.jpg",
                musicSource: "Spotify",
                detectedActivity: "Cycling",
                sharedWorkoutData: try? JSONEncoder().encode(cycleWorkoutData),
                likeCount: 14,
                commentCount: 3,
                locationName: "Lakeshore Trail",
                workoutEmotion: "Calm"
            )
            myPost3.albumArtData = bundledAlbumArt("blinding_lights")
            modelContext.insert(myPost3)
            myPostIds.append(myPost3.id)

            // ── Post D: Running 5K with GPS route ───────────────────────
            let runRoute5K: [RoutePoint] = [
                RoutePoint(latitude: 44.2253, longitude: -76.4951, altitude: 90, timestamp: 0, speed: 3.0, horizontalAccuracy: 5),
                RoutePoint(latitude: 44.2270, longitude: -76.4930, altitude: 91, timestamp: 180, speed: 3.3, horizontalAccuracy: 5),
                RoutePoint(latitude: 44.2290, longitude: -76.4910, altitude: 92, timestamp: 360, speed: 3.4, horizontalAccuracy: 5),
                RoutePoint(latitude: 44.2310, longitude: -76.4895, altitude: 93, timestamp: 540, speed: 3.5, horizontalAccuracy: 5),
                RoutePoint(latitude: 44.2325, longitude: -76.4910, altitude: 92, timestamp: 720, speed: 3.3, horizontalAccuracy: 5),
                RoutePoint(latitude: 44.2315, longitude: -76.4935, altitude: 91, timestamp: 900, speed: 3.4, horizontalAccuracy: 5),
                RoutePoint(latitude: 44.2298, longitude: -76.4955, altitude: 90, timestamp: 1080, speed: 3.2, horizontalAccuracy: 5),
                RoutePoint(latitude: 44.2278, longitude: -76.4965, altitude: 90, timestamp: 1260, speed: 3.3, horizontalAccuracy: 5),
                RoutePoint(latitude: 44.2260, longitude: -76.4958, altitude: 90, timestamp: 1440, speed: 3.5, horizontalAccuracy: 5),
                RoutePoint(latitude: 44.2253, longitude: -76.4951, altitude: 90, timestamp: 1620, speed: 3.0, horizontalAccuracy: 5),
            ]
            let run5KWorkoutData = SharedWorkoutData(
                title: "5K Run",
                workoutType: "Cardio",
                estimatedDuration: 28,
                authorName: myProfile.name,
                authorUsername: myProfile.username,
                routePoints: runRoute5K
            )
            let myPost4 = Post(
                authorId: myProfile.id,
                authorName: myProfile.name,
                authorUsername: myProfile.username,
                timestamp: hoursAgo(40),
                caption: "New 5K PB — 23:12. Negative split the last km and had enough left to kick. Progress is progress.",
                workoutType: "Cardio",
                duration: 28,
                exerciseHighlight: "Running",
                detectedActivity: "Running",
                sharedWorkoutData: try? JSONEncoder().encode(run5KWorkoutData),
                likeCount: 18,
                commentCount: 4,
                workoutEmotion: "Grinding"
            )
            modelContext.insert(myPost4)
            myPostIds.append(myPost4.id)

            // ── Post E: Pull day with deadlift PR ───────────────────────
            let postEWorkout = SharedWorkoutData(
                title: "Pull Day",
                workoutType: "Pull",
                estimatedDuration: 58,
                exercises: [
                    SharedWorkoutData.SharedExercise(name: "Deadlift", muscleGroup: "Back", sets: [.init(reps: 3, weight: 315, restSeconds: 180), .init(reps: 5, weight: 275, restSeconds: 150), .init(reps: 5, weight: 275, restSeconds: 150)], demoTips: ["Brace hard", "Push the floor away"]),
                    SharedWorkoutData.SharedExercise(name: "Pull Up", muscleGroup: "Back", sets: [.init(reps: 10, weight: 0, restSeconds: 90), .init(reps: 8, weight: 0, restSeconds: 90), .init(reps: 8, weight: 0, restSeconds: 90)], demoTips: ["Full hang at bottom", "Chin over bar"]),
                    SharedWorkoutData.SharedExercise(name: "Barbell Row", muscleGroup: "Back", sets: [.init(reps: 8, weight: 155, restSeconds: 90), .init(reps: 8, weight: 155, restSeconds: 90)], demoTips: ["Hinge at hips", "Pull to belly button"]),
                    SharedWorkoutData.SharedExercise(name: "Face Pull", muscleGroup: "Rear Delts", sets: [.init(reps: 15, weight: 30, restSeconds: 60), .init(reps: 15, weight: 30, restSeconds: 60)], demoTips: ["Pull to forehead", "Squeeze rear delts"]),
                ],
                authorName: myProfile.name,
                authorUsername: myProfile.username
            )
            let myPost5 = Post(
                authorId: myProfile.id,
                authorName: myProfile.name,
                authorUsername: myProfile.username,
                timestamp: hoursAgo(50),
                caption: "315 deadlift for a triple. Been chasing 3 plates for months. Today we got it.",
                workoutType: "Pull",
                duration: 58,
                setCount: 16,
                exerciseHighlight: "Deadlift",
                songTitle: "Till I Collapse",
                artistName: "Eminem",
                albumArtURL: "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/a0/4d/c4/a04dc484-03cc-02aa-fa82-5334fcb4bc16/18UMGIM24878.rgb.jpg/300x300bb.jpg",
                musicSource: "Spotify",
                sharedWorkoutData: try? JSONEncoder().encode(postEWorkout),
                likeCount: 32,
                commentCount: 4,
                locationName: "The ARC - Queen's",
                workoutEmotion: "Strong"
            )
            let postEPR = [FeedPR(exerciseName: "Deadlift", value: "315×3", previousValue: "295×3", improvement: "+20 lbs", prType: "Weight PR")]
            myPost5.prMomentsData = try? JSONEncoder().encode(postEPR)
            myPost5.albumArtData = bundledAlbumArt("till_i_collapse")
            modelContext.insert(myPost5)
            myPostIds.append(myPost5.id)

            // ── Post F: HIIT session ────────────────────────────────────
            let postFWorkout = SharedWorkoutData(
                title: "HIIT Circuit",
                workoutType: "HIIT",
                estimatedDuration: 30,
                exercises: [
                    SharedWorkoutData.SharedExercise(name: "Burpees", muscleGroup: "Full Body", sets: [.init(reps: 15, weight: 0, restSeconds: 30), .init(reps: 12, weight: 0, restSeconds: 30)], demoTips: ["Chest to floor", "Explosive jump"]),
                    SharedWorkoutData.SharedExercise(name: "Box Jumps", muscleGroup: "Legs", sets: [.init(reps: 12, weight: 0, restSeconds: 30), .init(reps: 12, weight: 0, restSeconds: 30)], demoTips: ["Land softly", "Full hip extension"]),
                    SharedWorkoutData.SharedExercise(name: "Kettlebell Swings", muscleGroup: "Posterior Chain", sets: [.init(reps: 20, weight: 53, restSeconds: 30), .init(reps: 20, weight: 53, restSeconds: 30)], demoTips: ["Hip hinge", "Snap hips forward"]),
                    SharedWorkoutData.SharedExercise(name: "Battle Ropes", muscleGroup: "Full Body", sets: [.init(reps: 30, weight: 0, restSeconds: 30), .init(reps: 30, weight: 0, restSeconds: 30)], demoTips: ["Alternating waves", "Stay low"]),
                ],
                authorName: myProfile.name,
                authorUsername: myProfile.username
            )
            let myPost6 = Post(
                authorId: myProfile.id,
                authorName: myProfile.name,
                authorUsername: myProfile.username,
                timestamp: hoursAgo(60),
                caption: "30 min HIIT that felt like 3 hours. Burpees, box jumps, KB swings, battle ropes. I am deceased.",
                workoutType: "HIIT",
                duration: 30,
                setCount: 12,
                songTitle: "Stronger",
                artistName: "Kanye West",
                albumArtURL: "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/02/da/e1/02dae132-5acc-0ee0-7b0c-9db239e4b089/07UMGD06593.rgb.jpg/300x300bb.jpg",
                musicSource: "Apple Music",
                sharedWorkoutData: try? JSONEncoder().encode(postFWorkout),
                likeCount: 9,
                commentCount: 2,
                workoutEmotion: "Fired Up"
            )
            myPost6.albumArtData = bundledAlbumArt("stronger")
            modelContext.insert(myPost6)
            myPostIds.append(myPost6.id)

            // ── Post G: Yoga / recovery (text-only) ─────────────────────
            let myPost7 = Post(
                authorId: myProfile.id,
                authorName: myProfile.name,
                authorUsername: myProfile.username,
                timestamp: hoursAgo(72),
                caption: "Rest day. 45 min yoga flow + foam rolling. Recovery is part of the process — learning to respect it.",
                workoutType: "Yoga",
                duration: 45,
                detectedActivity: "Yoga",
                likeCount: 6,
                commentCount: 2,
                workoutEmotion: "Grateful"
            )
            modelContext.insert(myPost7)
            myPostIds.append(myPost7.id)

            // ── Post H: Full Body + tagged friends + inspired by ────────
            let postHWorkout = SharedWorkoutData(
                title: "Full Body Blitz",
                workoutType: "Full Body",
                estimatedDuration: 50,
                exercises: [
                    SharedWorkoutData.SharedExercise(name: "Squat", muscleGroup: "Quads", sets: [.init(reps: 8, weight: 205, restSeconds: 120), .init(reps: 8, weight: 205, restSeconds: 120)], demoTips: ["Break at hips first", "Drive knees out"]),
                    SharedWorkoutData.SharedExercise(name: "Bench Press", muscleGroup: "Chest", sets: [.init(reps: 8, weight: 165, restSeconds: 90), .init(reps: 8, weight: 165, restSeconds: 90)], demoTips: ["Retract scapula", "Touch chest"]),
                    SharedWorkoutData.SharedExercise(name: "Barbell Row", muscleGroup: "Back", sets: [.init(reps: 8, weight: 145, restSeconds: 90), .init(reps: 8, weight: 145, restSeconds: 90)], demoTips: ["Hinge at hips", "Pull to belly button"]),
                    SharedWorkoutData.SharedExercise(name: "Overhead Press", muscleGroup: "Shoulders", sets: [.init(reps: 8, weight: 85, restSeconds: 90), .init(reps: 8, weight: 85, restSeconds: 90)], demoTips: ["Brace core", "Lock out overhead"]),
                ],
                authorName: myProfile.name,
                authorUsername: myProfile.username
            )
            let myPost8 = Post(
                authorId: myProfile.id,
                authorName: myProfile.name,
                authorUsername: myProfile.username,
                timestamp: hoursAgo(80),
                caption: "Full body day with @marcuschen and @oliviapark. Followed Jake's program and it did not disappoint.",
                workoutType: "Full Body",
                duration: 50,
                setCount: 18,
                songTitle: "Eye of the Tiger",
                artistName: "Survivor",
                albumArtURL: "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/7b/13/81/7b1381df-943e-a951-0290-e0c0eb8e0e3e/886443927087.jpg/300x300bb.jpg",
                musicSource: "Spotify",
                sharedWorkoutData: try? JSONEncoder().encode(postHWorkout),
                inspiredByUsername: "jakereeves",
                inspiredByName: "Jake Reeves",
                taggedUsernames: ["marcuschen", "oliviapark"],
                likeCount: 15,
                commentCount: 3,
                spotifyPlaylistURL: "https://open.spotify.com/playlist/37i9dQZF1DX76Wlfdnj7AP",
                appleMusicPlaylistURL: "https://music.apple.com/playlist/workout-motivation/pl.u-55D6Xp1FGky0oN",
                workoutEmotion: "Strong"
            )
            myPost8.albumArtData = bundledAlbumArt("eye_of_the_tiger")
            modelContext.insert(myPost8)
            myPostIds.append(myPost8.id)

            // ── Likes on user's posts ───────────────────────────────────
            // Post A: 11 likes (users 0-9 + user 0 again)
            let likeDataA: [(Int, Double)] = [(0, 0.5), (1, 1.0), (2, 1.5), (3, 2.0), (4, 3.0), (5, 4.0), (6, 5.0), (7, 6.0), (8, 7.0), (9, 8.0), (0, 9.0)]
            for (userIdx, hrs) in likeDataA {
                modelContext.insert(Like(postId: myPostIds[0], userId: fakeUsers[userIdx].id, userName: fakeUsers[userIdx].name, timestamp: Date().addingTimeInterval(-hrs * 3600)))
            }
            // Post B: 7 likes
            let likeDataB: [(Int, Double)] = [(0, 10.0), (1, 11.0), (2, 12.0), (3, 13.0), (4, 14.0), (5, 15.0), (6, 16.0)]
            for (userIdx, hrs) in likeDataB {
                modelContext.insert(Like(postId: myPostIds[1], userId: fakeUsers[userIdx].id, userName: fakeUsers[userIdx].name, timestamp: Date().addingTimeInterval(-hrs * 3600)))
            }
            // Post C: 14 likes
            for i in 0..<10 {
                modelContext.insert(Like(postId: myPostIds[2], userId: fakeUsers[i].id, userName: fakeUsers[i].name, timestamp: Date().addingTimeInterval(-Double(20 + i) * 3600)))
            }
            for i in 0..<4 {
                modelContext.insert(Like(postId: myPostIds[2], userId: fakeUsers[i].id, userName: fakeUsers[i].name, timestamp: Date().addingTimeInterval(-Double(31 + i) * 3600)))
            }
            // Post D: 18 likes
            for i in 0..<10 {
                modelContext.insert(Like(postId: myPostIds[3], userId: fakeUsers[i].id, userName: fakeUsers[i].name, timestamp: Date().addingTimeInterval(-Double(35 + i) * 3600)))
            }
            for i in 0..<8 {
                modelContext.insert(Like(postId: myPostIds[3], userId: fakeUsers[i].id, userName: fakeUsers[i].name, timestamp: Date().addingTimeInterval(-Double(46 + i) * 3600)))
            }
            // Post E: 32 likes
            for i in 0..<10 {
                modelContext.insert(Like(postId: myPostIds[4], userId: fakeUsers[i].id, userName: fakeUsers[i].name, timestamp: Date().addingTimeInterval(-Double(45 + i) * 3600)))
            }
            for i in 0..<10 {
                modelContext.insert(Like(postId: myPostIds[4], userId: fakeUsers[i].id, userName: fakeUsers[i].name, timestamp: Date().addingTimeInterval(-Double(56 + i) * 3600)))
            }
            for i in 0..<10 {
                modelContext.insert(Like(postId: myPostIds[4], userId: fakeUsers[i].id, userName: fakeUsers[i].name, timestamp: Date().addingTimeInterval(-Double(67 + i) * 3600)))
            }
            for i in 0..<2 {
                modelContext.insert(Like(postId: myPostIds[4], userId: fakeUsers[i].id, userName: fakeUsers[i].name, timestamp: Date().addingTimeInterval(-Double(78 + i) * 3600)))
            }
            // Post F: 9 likes
            for i in 0..<9 {
                modelContext.insert(Like(postId: myPostIds[5], userId: fakeUsers[i].id, userName: fakeUsers[i].name, timestamp: Date().addingTimeInterval(-Double(55 + i) * 3600)))
            }
            // Post G: 6 likes
            for i in 0..<6 {
                modelContext.insert(Like(postId: myPostIds[6], userId: fakeUsers[i].id, userName: fakeUsers[i].name, timestamp: Date().addingTimeInterval(-Double(68 + i) * 3600)))
            }
            // Post H: 15 likes
            for i in 0..<10 {
                modelContext.insert(Like(postId: myPostIds[7], userId: fakeUsers[i].id, userName: fakeUsers[i].name, timestamp: Date().addingTimeInterval(-Double(75 + i) * 3600)))
            }
            for i in 0..<5 {
                modelContext.insert(Like(postId: myPostIds[7], userId: fakeUsers[i].id, userName: fakeUsers[i].name, timestamp: Date().addingTimeInterval(-Double(86 + i) * 3600)))
            }

            // ── Comments on user's posts ────────────────────────────────
            // Post A (5 comments)
            seedComment(ctx: modelContext, postId: myPostIds[0], user: fakeUsers[0], content: "185 triple is solid! Keep pushing", hoursAgo: 1.0)
            seedComment(ctx: modelContext, postId: myPostIds[0], user: fakeUsers[1], content: "Clean reps > heavy reps every time", hoursAgo: 1.5)
            seedComment(ctx: modelContext, postId: myPostIds[0], user: fakeUsers[3], content: "You'll be at 2 plates in no time", hoursAgo: 2.5)
            seedComment(ctx: modelContext, postId: myPostIds[0], user: fakeUsers[2], content: "That PR badge is well deserved", hoursAgo: 2.0)
            seedComment(ctx: modelContext, postId: myPostIds[0], user: fakeUsers[4], content: "Eminem and bench press — elite combo", hoursAgo: 2.8)
            // Post B (3 comments)
            seedComment(ctx: modelContext, postId: myPostIds[1], user: fakeUsers[2], content: "RDLs to finish? You're a warrior", hoursAgo: 12.0)
            seedComment(ctx: modelContext, postId: myPostIds[1], user: fakeUsers[4], content: "Walking is overrated anyway", hoursAgo: 15.0)
            seedComment(ctx: modelContext, postId: myPostIds[1], user: fakeUsers[0], content: "225 squat looking easy for you", hoursAgo: 16.0)
            // Post C (3 comments)
            seedComment(ctx: modelContext, postId: myPostIds[2], user: fakeUsers[1], content: "25km into the wind? Beast mode", hoursAgo: 22.0)
            seedComment(ctx: modelContext, postId: myPostIds[2], user: fakeUsers[3], content: "That route looks gorgeous", hoursAgo: 23.0)
            seedComment(ctx: modelContext, postId: myPostIds[2], user: fakeUsers[5], content: "Need to join you next time!", hoursAgo: 24.0)
            // Post D (4 comments)
            seedComment(ctx: modelContext, postId: myPostIds[3], user: fakeUsers[0], content: "5K PB!! That negative split is chef's kiss", hoursAgo: 36.0)
            seedComment(ctx: modelContext, postId: myPostIds[3], user: fakeUsers[2], content: "Sub-24 is serious. Keep it up", hoursAgo: 37.0)
            seedComment(ctx: modelContext, postId: myPostIds[3], user: fakeUsers[6], content: "What shoes are you running in?", hoursAgo: 38.0)
            seedComment(ctx: modelContext, postId: myPostIds[3], user: fakeUsers[8], content: "Inspiring me to lace up tomorrow", hoursAgo: 39.0)
            // Post E (4 comments)
            seedComment(ctx: modelContext, postId: myPostIds[4], user: fakeUsers[0], content: "3 PLATES!! Welcome to the club 🔥", hoursAgo: 46.0)
            seedComment(ctx: modelContext, postId: myPostIds[4], user: fakeUsers[1], content: "That +20lb jump is insane. How long did that take?", hoursAgo: 47.0)
            seedComment(ctx: modelContext, postId: myPostIds[4], user: fakeUsers[2], content: "The grind pays off. Huge milestone", hoursAgo: 48.0)
            seedComment(ctx: modelContext, postId: myPostIds[4], user: fakeUsers[4], content: "Till I Collapse playing while you hit 315... poetic", hoursAgo: 49.0)
            // Post F (2 comments)
            seedComment(ctx: modelContext, postId: myPostIds[5], user: fakeUsers[3], content: "HIIT is no joke. Respect", hoursAgo: 56.0)
            seedComment(ctx: modelContext, postId: myPostIds[5], user: fakeUsers[7], content: "Battle ropes are my nemesis", hoursAgo: 58.0)
            // Post G (2 comments)
            seedComment(ctx: modelContext, postId: myPostIds[6], user: fakeUsers[1], content: "Recovery days are growth days 🧘", hoursAgo: 68.0)
            seedComment(ctx: modelContext, postId: myPostIds[6], user: fakeUsers[5], content: "This is the way. Rest is underrated", hoursAgo: 70.0)
            // Post H (3 comments)
            seedComment(ctx: modelContext, postId: myPostIds[7], user: fakeUsers[2], content: "Squad workouts hit different", hoursAgo: 76.0)
            seedComment(ctx: modelContext, postId: myPostIds[7], user: fakeUsers[0], content: "Following Jake's program too — it's legit", hoursAgo: 77.0)
            seedComment(ctx: modelContext, postId: myPostIds[7], user: fakeUsers[9], content: "Eye of the Tiger is the only correct song for this", hoursAgo: 78.0)

            // ── Reactions on user's posts ────────────────────────────────
            let allReactions: [(Int, Int, ReactionType, Double)] = [
                // Post A
                (0, 0, .fire, 0.8), (0, 1, .strong, 1.2), (0, 2, .heart, 2.0), (0, 5, .clap, 3.5),
                // Post B
                (1, 3, .strong, 10.0), (1, 4, .fire, 13.0), (1, 6, .thumbsUp, 14.0),
                // Post C
                (2, 1, .heart, 22.0), (2, 3, .clap, 23.0), (2, 5, .thumbsUp, 24.0),
                // Post D
                (3, 0, .fire, 36.0), (3, 2, .strong, 37.0), (3, 6, .clap, 38.0), (3, 8, .heart, 39.0),
                // Post E
                (4, 0, .fire, 46.0), (4, 1, .strong, 47.0), (4, 2, .shocked, 47.5), (4, 4, .fire, 48.0), (4, 7, .clap, 49.0),
                // Post F
                (5, 3, .fire, 56.0), (5, 7, .strong, 58.0),
                // Post G
                (6, 1, .heart, 68.0), (6, 5, .clap, 70.0),
                // Post H
                (7, 0, .strong, 76.0), (7, 2, .fire, 77.0), (7, 9, .clap, 78.0), (7, 4, .heart, 79.0),
            ]
            for (postIdx, userIdx, rType, hrs) in allReactions {
                let reaction = Reaction(
                    odId: fakeUsers[userIdx].id,
                    odUsername: fakeUsers[userIdx].username,
                    targetType: "post",
                    targetId: myPostIds[postIdx],
                    reactionType: rType,
                    createdAt: Date().addingTimeInterval(-hrs * 3600)
                )
                modelContext.insert(reaction)
            }
        }

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

        // Download album art for all posts that have a URL but no cached data
        Task.detached {
            await downloadAlbumArt(modelContext: modelContext)
        }
    }

    @MainActor
    private static func downloadAlbumArt(modelContext: ModelContext) async {
        let descriptor = FetchDescriptor<Post>()
        guard let posts = try? modelContext.fetch(descriptor) else { return }

        for post in posts where post.albumArtURL != nil && post.albumArtData == nil {
            guard let urlString = post.albumArtURL, let url = URL(string: urlString) else { continue }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let http = response as? HTTPURLResponse, http.statusCode == 200, !data.isEmpty {
                    post.albumArtData = data
                }
            } catch {
                // Skip this one, try next
            }
        }
        try? modelContext.save()
    }

    #if canImport(UIKit)
    /// Generates a gradient placeholder gym photo when no bundle asset exists.
    private static func generatePlaceholderPhoto() -> Data? {
        let size = CGSize(width: 400, height: 520) // 4:5.2 aspect ratio
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let colors = [
                UIColor(red: 0.12, green: 0.12, blue: 0.18, alpha: 1.0).cgColor,
                UIColor(red: 0.18, green: 0.14, blue: 0.28, alpha: 1.0).cgColor,
                UIColor(red: 0.10, green: 0.10, blue: 0.15, alpha: 1.0).cgColor
            ]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 0.5, 1])!
            ctx.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])

            // Draw a subtle dumbbell icon in the center
            let iconSize: CGFloat = 60
            let centerX = size.width / 2
            let centerY = size.height / 2 - 20
            ctx.cgContext.setStrokeColor(UIColor.white.withAlphaComponent(0.15).cgColor)
            ctx.cgContext.setLineWidth(4)
            ctx.cgContext.setLineCap(.round)
            // Bar
            ctx.cgContext.move(to: CGPoint(x: centerX - iconSize / 2, y: centerY))
            ctx.cgContext.addLine(to: CGPoint(x: centerX + iconSize / 2, y: centerY))
            // Left weight
            ctx.cgContext.move(to: CGPoint(x: centerX - iconSize / 2, y: centerY - 15))
            ctx.cgContext.addLine(to: CGPoint(x: centerX - iconSize / 2, y: centerY + 15))
            // Right weight
            ctx.cgContext.move(to: CGPoint(x: centerX + iconSize / 2, y: centerY - 15))
            ctx.cgContext.addLine(to: CGPoint(x: centerX + iconSize / 2, y: centerY + 15))
            ctx.cgContext.strokePath()
        }
        return image.jpegData(compressionQuality: 0.7)
    }
    #endif

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
