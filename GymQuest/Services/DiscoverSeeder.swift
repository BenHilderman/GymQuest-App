import SwiftUI
import SwiftData

// MARK: - Discover Seeder

/// Seeds TikTok-style discover feed with demo workout video posts
struct DiscoverSeeder {

    // Reuse consistent fake users from SocialSeeder
    private static var fakeUsers: [(id: UUID, name: String, username: String)] {
        SocialSeeder.fakeUsers
    }

    static func seedIfNeeded(modelContext: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: "hasSeededDiscoverVideos_v1") else { return }

        let now = Date()

        func hoursAgo(_ h: Double) -> Date {
            now.addingTimeInterval(-h * 3600)
        }

        // Video definitions: (filename, user index, caption, workoutType, duration, setCount, exerciseHighlight,
        //                      songTitle, artistName, musicSource, spotifyURL, appleMusicURL, sharedWorkoutData?)
        struct VideoDef {
            let filename: String
            let userIdx: Int
            let caption: String
            let workoutType: String
            let duration: Int
            let setCount: Int
            let exerciseHighlight: String
            let songTitle: String
            let artistName: String
            let musicSource: String
            let spotifyURL: String?
            let appleMusicURL: String?
            let hoursAgo: Double
            let likeCount: Int
            let commentCount: Int
            let emotion: String
        }

        let defs: [VideoDef] = [
            VideoDef(
                filename: "demo_bench_press", userIdx: 0,
                caption: "225 for reps. Chest day is the best day. #benchpress #push #chestday",
                workoutType: "Push", duration: 58, setCount: 16, exerciseHighlight: "Bench Press",
                songTitle: "Lose Yourself", artistName: "Eminem", musicSource: "Apple Music",
                spotifyURL: "https://open.spotify.com/playlist/37i9dQZF1DX76Wlfdnj7AP",
                appleMusicURL: "https://music.apple.com/playlist/gym-motivation/pl.u-55D6YKEFxVad",
                hoursAgo: 0.5, likeCount: 1247, commentCount: 3, emotion: "Fired Up"
            ),
            VideoDef(
                filename: "demo_shoulder_press", userIdx: 1,
                caption: "OHP PR! 135 for 5. Shoulders are boulders today. #shoulderpress #push #ohp",
                workoutType: "Push", duration: 45, setCount: 12, exerciseHighlight: "Overhead Press",
                songTitle: "HUMBLE.", artistName: "Kendrick Lamar", musicSource: "Spotify",
                spotifyURL: "https://open.spotify.com/playlist/37i9dQZF1DX3rxVfibe1L0",
                appleMusicURL: nil,
                hoursAgo: 1.5, likeCount: 892, commentCount: 4, emotion: "Strong"
            ),
            VideoDef(
                filename: "demo_barbell_row", userIdx: 2,
                caption: "Rows for days. Feel the squeeze at the top. #barbellrow #pull #backday",
                workoutType: "Pull", duration: 52, setCount: 15, exerciseHighlight: "Barbell Row",
                songTitle: "Till I Collapse", artistName: "Eminem", musicSource: "Apple Music",
                spotifyURL: nil,
                appleMusicURL: "https://music.apple.com/playlist/beast-mode/pl.u-2aoqZBACxb5",
                hoursAgo: 3, likeCount: 634, commentCount: 3, emotion: "Grinding"
            ),
            VideoDef(
                filename: "demo_pull_ups", userIdx: 3,
                caption: "Weighted pull-ups +45lbs. Full ROM or it doesn't count. #pullups #pull #calisthenics",
                workoutType: "Pull", duration: 48, setCount: 14, exerciseHighlight: "Pull Up",
                songTitle: "Power", artistName: "Kanye West", musicSource: "Apple Music",
                spotifyURL: nil, appleMusicURL: nil,
                hoursAgo: 5, likeCount: 1563, commentCount: 4, emotion: "Strong"
            ),
            VideoDef(
                filename: "demo_deadlift", userIdx: 4,
                caption: "405 deadlift. New PR! Grip almost gave out but we held on. #deadlift #pull #pr 🏆",
                workoutType: "Pull", duration: 65, setCount: 18, exerciseHighlight: "Deadlift",
                songTitle: "Stronger", artistName: "Kanye West", musicSource: "Spotify",
                spotifyURL: "https://open.spotify.com/playlist/37i9dQZF1DX0XUsuxWHRQd",
                appleMusicURL: "https://music.apple.com/playlist/heavy-lifting/pl.u-BNA6YzrH0rJgB",
                hoursAgo: 6, likeCount: 1891, commentCount: 4, emotion: "Fired Up"
            ),
            VideoDef(
                filename: "demo_squat", userIdx: 5,
                caption: "ATG squats. No quarter reps in this gym. #squat #legs #legday",
                workoutType: "Legs", duration: 70, setCount: 20, exerciseHighlight: "Squat",
                songTitle: "Run This Town", artistName: "JAY-Z", musicSource: "Spotify",
                spotifyURL: "https://open.spotify.com/playlist/37i9dQZF1DX76Wlfdnj7AP",
                appleMusicURL: nil,
                hoursAgo: 8, likeCount: 1102, commentCount: 3, emotion: "Fired Up"
            ),
            VideoDef(
                filename: "demo_leg_press", userIdx: 6,
                caption: "8 plates per side on the leg press. Legs were shaking walking out. #legpress #legs #quads",
                workoutType: "Legs", duration: 55, setCount: 16, exerciseHighlight: "Leg Press",
                songTitle: "DNA.", artistName: "Kendrick Lamar", musicSource: "Spotify",
                spotifyURL: nil, appleMusicURL: nil,
                hoursAgo: 12, likeCount: 723, commentCount: 3, emotion: "Grinding"
            ),
            VideoDef(
                filename: "demo_treadmill", userIdx: 7,
                caption: "Morning 5K done. 22:15. Consistency over intensity. #treadmill #cardio #running",
                workoutType: "Cardio", duration: 28, setCount: 0, exerciseHighlight: "Treadmill Run",
                songTitle: "Blinding Lights", artistName: "The Weeknd", musicSource: "Apple Music",
                spotifyURL: "https://open.spotify.com/playlist/37i9dQZF1DX3rxVfibe1L0",
                appleMusicURL: "https://music.apple.com/playlist/running-mix/pl.u-EdAVzDqCRXy8d",
                hoursAgo: 14, likeCount: 456, commentCount: 3, emotion: "Strong"
            ),
            VideoDef(
                filename: "demo_cycling", userIdx: 8,
                caption: "45 min spin class. Legs are jello but the endorphins are real. #cycling #cardio #spin",
                workoutType: "Cardio", duration: 45, setCount: 0, exerciseHighlight: "Cycling",
                songTitle: "Levitating", artistName: "Dua Lipa", musicSource: "Spotify",
                spotifyURL: nil, appleMusicURL: nil,
                hoursAgo: 18, likeCount: 312, commentCount: 3, emotion: "Strong"
            ),
            VideoDef(
                filename: "demo_yoga", userIdx: 9,
                caption: "Recovery day flow. Mobility is the key to longevity. #yoga #cardio #flexibility #form",
                workoutType: "Cardio", duration: 35, setCount: 0, exerciseHighlight: "Yoga",
                songTitle: "Sunset Lover", artistName: "Petit Biscuit", musicSource: "Apple Music",
                spotifyURL: nil,
                appleMusicURL: "https://music.apple.com/playlist/chill-vibes/pl.u-MDAWvFOtXNP",
                hoursAgo: 24, likeCount: 578, commentCount: 4, emotion: "Relaxed"
            ),
            VideoDef(
                filename: "demo_dumbbell_curl", userIdx: 0,
                caption: "Slow eccentrics on the curls. Time under tension is everything. #dumbbellcurl #pull #arms",
                workoutType: "Pull", duration: 40, setCount: 12, exerciseHighlight: "Dumbbell Curl",
                songTitle: "Sicko Mode", artistName: "Travis Scott", musicSource: "Spotify",
                spotifyURL: "https://open.spotify.com/playlist/37i9dQZF1DX0XUsuxWHRQd",
                appleMusicURL: nil,
                hoursAgo: 30, likeCount: 845, commentCount: 3, emotion: "Grinding"
            ),
            VideoDef(
                filename: "demo_kettlebell", userIdx: 1,
                caption: "100 kettlebell swings. Simple and sinister. #kettlebell #push #functional #tip",
                workoutType: "Push", duration: 25, setCount: 10, exerciseHighlight: "Kettlebell Swing",
                songTitle: "Eye of the Tiger", artistName: "Survivor", musicSource: "Apple Music",
                spotifyURL: nil, appleMusicURL: nil,
                hoursAgo: 36, likeCount: 967, commentCount: 3, emotion: "Fired Up"
            ),
        ]

        // Shared workout data for 8 of 12 posts
        let sharedWorkouts: [String: SharedWorkoutData] = [
            "demo_bench_press": SharedWorkoutData(
                title: "Push Day: Bench Focus",
                workoutType: "Push", estimatedDuration: 58,
                exercises: [
                    .init(name: "Bench Press", muscleGroup: "Chest",
                          sets: [.init(reps: 5, weight: 185), .init(reps: 5, weight: 205), .init(reps: 3, weight: 225)],
                          demoTips: ["Retract shoulder blades", "Bar to mid-chest"]),
                    .init(name: "Incline Dumbbell Press", muscleGroup: "Chest",
                          sets: [.init(reps: 10, weight: 60), .init(reps: 10, weight: 60), .init(reps: 8, weight: 65)],
                          demoTips: ["30-degree incline", "Squeeze at the top"]),
                    .init(name: "Tricep Pushdown", muscleGroup: "Triceps",
                          sets: [.init(reps: 12, weight: 40), .init(reps: 12, weight: 40)],
                          demoTips: ["Elbows pinned to sides", "Full extension"]),
                ],
                authorName: fakeUsers[0].name, authorUsername: fakeUsers[0].username
            ),
            "demo_barbell_row": SharedWorkoutData(
                title: "Pull Day: Row Focus",
                workoutType: "Pull", estimatedDuration: 52,
                exercises: [
                    .init(name: "Barbell Row", muscleGroup: "Back",
                          sets: [.init(reps: 8, weight: 155), .init(reps: 8, weight: 155), .init(reps: 6, weight: 175)],
                          demoTips: ["Hinge at hips", "Pull to belly button"]),
                    .init(name: "Lat Pulldown", muscleGroup: "Back",
                          sets: [.init(reps: 10, weight: 120), .init(reps: 10, weight: 120)],
                          demoTips: ["Wide grip", "Pull to upper chest"]),
                    .init(name: "Face Pull", muscleGroup: "Rear Delts",
                          sets: [.init(reps: 15, weight: 30), .init(reps: 15, weight: 30)],
                          demoTips: ["External rotation", "Squeeze shoulder blades"]),
                ],
                authorName: fakeUsers[2].name, authorUsername: fakeUsers[2].username
            ),
            "demo_pull_ups": SharedWorkoutData(
                title: "Calisthenics Pull",
                workoutType: "Pull", estimatedDuration: 48,
                exercises: [
                    .init(name: "Pull Up", muscleGroup: "Back",
                          sets: [.init(reps: 10, weight: 0), .init(reps: 8, weight: 25), .init(reps: 6, weight: 45)],
                          demoTips: ["Full hang at bottom", "Chin over bar"]),
                    .init(name: "Chin Up", muscleGroup: "Back",
                          sets: [.init(reps: 8, weight: 0), .init(reps: 8, weight: 0)],
                          demoTips: ["Supinated grip", "Engage biceps"]),
                ],
                authorName: fakeUsers[3].name, authorUsername: fakeUsers[3].username
            ),
            "demo_deadlift": SharedWorkoutData(
                title: "Deadlift Day",
                workoutType: "Pull", estimatedDuration: 65,
                exercises: [
                    .init(name: "Deadlift", muscleGroup: "Back",
                          sets: [.init(reps: 5, weight: 315), .init(reps: 3, weight: 365), .init(reps: 1, weight: 405)],
                          demoTips: ["Hips and shoulders rise together", "Bar stays close to body"]),
                    .init(name: "Romanian Deadlift", muscleGroup: "Hamstrings",
                          sets: [.init(reps: 10, weight: 185), .init(reps: 10, weight: 185)],
                          demoTips: ["Slight knee bend", "Feel the hamstring stretch"]),
                ],
                authorName: fakeUsers[4].name, authorUsername: fakeUsers[4].username
            ),
            "demo_squat": SharedWorkoutData(
                title: "Squat Day",
                workoutType: "Legs", estimatedDuration: 70,
                exercises: [
                    .init(name: "Squat", muscleGroup: "Legs",
                          sets: [.init(reps: 5, weight: 275), .init(reps: 5, weight: 295), .init(reps: 3, weight: 315)],
                          demoTips: ["Break at hips first", "Knees track toes"]),
                    .init(name: "Leg Extension", muscleGroup: "Quads",
                          sets: [.init(reps: 12, weight: 100), .init(reps: 12, weight: 100)],
                          demoTips: ["Full extension", "Squeeze at top"]),
                    .init(name: "Leg Curl", muscleGroup: "Hamstrings",
                          sets: [.init(reps: 12, weight: 80), .init(reps: 12, weight: 80)],
                          demoTips: ["Control the negative", "Full ROM"]),
                ],
                authorName: fakeUsers[5].name, authorUsername: fakeUsers[5].username
            ),
            "demo_leg_press": SharedWorkoutData(
                title: "Leg Press Destroyer",
                workoutType: "Legs", estimatedDuration: 55,
                exercises: [
                    .init(name: "Leg Press", muscleGroup: "Legs",
                          sets: [.init(reps: 10, weight: 540), .init(reps: 8, weight: 630), .init(reps: 6, weight: 720)],
                          demoTips: ["Feet shoulder width", "Full depth without butt lifting"]),
                    .init(name: "Calf Raise", muscleGroup: "Calves",
                          sets: [.init(reps: 15, weight: 200), .init(reps: 15, weight: 200)],
                          demoTips: ["Full stretch at bottom", "Pause at top"]),
                ],
                authorName: fakeUsers[6].name, authorUsername: fakeUsers[6].username
            ),
            "demo_dumbbell_curl": SharedWorkoutData(
                title: "Arm Day: Curl Focus",
                workoutType: "Pull", estimatedDuration: 40,
                exercises: [
                    .init(name: "Dumbbell Curl", muscleGroup: "Biceps",
                          sets: [.init(reps: 10, weight: 35), .init(reps: 10, weight: 35), .init(reps: 8, weight: 40)],
                          demoTips: ["No swinging", "Squeeze at top"]),
                    .init(name: "Hammer Curl", muscleGroup: "Biceps",
                          sets: [.init(reps: 10, weight: 30), .init(reps: 10, weight: 30)],
                          demoTips: ["Neutral grip", "Slow eccentric"]),
                ],
                authorName: fakeUsers[0].name, authorUsername: fakeUsers[0].username
            ),
            "demo_kettlebell": SharedWorkoutData(
                title: "Kettlebell Conditioning",
                workoutType: "Push", estimatedDuration: 25,
                exercises: [
                    .init(name: "Kettlebell Swing", muscleGroup: "Full Body",
                          sets: [.init(reps: 20, weight: 53), .init(reps: 20, weight: 53), .init(reps: 20, weight: 53), .init(reps: 20, weight: 53), .init(reps: 20, weight: 53)],
                          demoTips: ["Hip hinge drive", "Arms are just hooks"]),
                ],
                authorName: fakeUsers[1].name, authorUsername: fakeUsers[1].username
            ),
        ]

        var postIds: [UUID] = []

        for def in defs {
            let user = fakeUsers[def.userIdx]

            // Load video data from bundle
            let videoData: Data? = {
                guard let url = Bundle.main.url(forResource: def.filename, withExtension: "mp4") else { return nil }
                return try? Data(contentsOf: url)
            }()

            // Encode shared workout data if available
            let workoutData: Data? = {
                guard let workout = sharedWorkouts[def.filename] else { return nil }
                return try? JSONEncoder().encode(workout)
            }()

            let post = Post(
                authorId: user.id,
                authorName: user.name,
                authorUsername: user.username,
                timestamp: hoursAgo(def.hoursAgo),
                caption: def.caption,
                videoData: videoData,
                workoutType: def.workoutType,
                duration: def.duration,
                setCount: def.setCount > 0 ? def.setCount : nil,
                exerciseHighlight: def.exerciseHighlight,
                songTitle: def.songTitle,
                artistName: def.artistName,
                musicSource: def.musicSource,
                sharedWorkoutData: workoutData,
                likeCount: def.likeCount,
                commentCount: def.commentCount,
                spotifyPlaylistURL: def.spotifyURL,
                appleMusicPlaylistURL: def.appleMusicURL,
                workoutEmotion: def.emotion
            )

            modelContext.insert(post)
            postIds.append(post.id)
        }

        // MARK: - Comments (3-4 per post)

        // Post 0: Bench press
        seedComment(ctx: modelContext, postId: postIds[0], user: fakeUsers[3], content: "That arch is dialed in. Textbook form", hoursAgo: 0.3)
        seedComment(ctx: modelContext, postId: postIds[0], user: fakeUsers[5], content: "225 club! Welcome 🏋️", hoursAgo: 0.2)
        seedComment(ctx: modelContext, postId: postIds[0], user: fakeUsers[7], content: "What's your warmup look like?", hoursAgo: 0.1)

        // Post 1: Shoulder press
        seedComment(ctx: modelContext, postId: postIds[1], user: fakeUsers[4], content: "135 OHP is elite. Most people never hit that", hoursAgo: 1)
        seedComment(ctx: modelContext, postId: postIds[1], user: fakeUsers[6], content: "Strict press or push press?", hoursAgo: 0.8)
        seedComment(ctx: modelContext, postId: postIds[1], user: fakeUsers[8], content: "Boulder shoulders loading...", hoursAgo: 0.5)
        seedComment(ctx: modelContext, postId: postIds[1], user: fakeUsers[0], content: "Clean reps too. No kipping", hoursAgo: 0.3)

        // Post 2: Barbell row
        seedComment(ctx: modelContext, postId: postIds[2], user: fakeUsers[0], content: "Rows are so underrated for back thickness", hoursAgo: 2.5)
        seedComment(ctx: modelContext, postId: postIds[2], user: fakeUsers[5], content: "That squeeze at the top is key", hoursAgo: 2)
        seedComment(ctx: modelContext, postId: postIds[2], user: fakeUsers[9], content: "Following this routine tomorrow", hoursAgo: 1.5)

        // Post 3: Pull ups
        seedComment(ctx: modelContext, postId: postIds[3], user: fakeUsers[1], content: "+45 weighted? Beast mode activated", hoursAgo: 4)
        seedComment(ctx: modelContext, postId: postIds[3], user: fakeUsers[6], content: "Full ROM gang 💪", hoursAgo: 3.5)
        seedComment(ctx: modelContext, postId: postIds[3], user: fakeUsers[8], content: "I can barely do 5 bodyweight lol", hoursAgo: 3)
        seedComment(ctx: modelContext, postId: postIds[3], user: fakeUsers[2], content: "Calisthenics > machines any day", hoursAgo: 2.5)

        // Post 4: Deadlift
        seedComment(ctx: modelContext, postId: postIds[4], user: fakeUsers[0], content: "4 plates!! Absolute unit", hoursAgo: 5)
        seedComment(ctx: modelContext, postId: postIds[4], user: fakeUsers[3], content: "Mixed grip or hook grip?", hoursAgo: 4.5)
        seedComment(ctx: modelContext, postId: postIds[4], user: fakeUsers[7], content: "The lockout was smooth. New PR deserved", hoursAgo: 4)
        seedComment(ctx: modelContext, postId: postIds[4], user: fakeUsers[9], content: "Next stop: 455!", hoursAgo: 3.5)

        // Post 5: Squat
        seedComment(ctx: modelContext, postId: postIds[5], user: fakeUsers[1], content: "ATG or nothing. This is the way", hoursAgo: 7)
        seedComment(ctx: modelContext, postId: postIds[5], user: fakeUsers[4], content: "Depth is impressive. Most people half rep", hoursAgo: 6.5)
        seedComment(ctx: modelContext, postId: postIds[5], user: fakeUsers[8], content: "My knees hurt watching this but respect", hoursAgo: 6)

        // Post 6: Leg press
        seedComment(ctx: modelContext, postId: postIds[6], user: fakeUsers[2], content: "8 plates PER SIDE?! Insane", hoursAgo: 11)
        seedComment(ctx: modelContext, postId: postIds[6], user: fakeUsers[5], content: "How did you walk out after this", hoursAgo: 10.5)
        seedComment(ctx: modelContext, postId: postIds[6], user: fakeUsers[9], content: "Quads of the gods", hoursAgo: 10)

        // Post 7: Treadmill
        seedComment(ctx: modelContext, postId: postIds[7], user: fakeUsers[0], content: "Consistency > everything. Keep it up", hoursAgo: 13)
        seedComment(ctx: modelContext, postId: postIds[7], user: fakeUsers[3], content: "Morning cardio hits different", hoursAgo: 12.5)
        seedComment(ctx: modelContext, postId: postIds[7], user: fakeUsers[6], content: "22:15 is solid! What's your goal pace?", hoursAgo: 12)

        // Post 8: Cycling
        seedComment(ctx: modelContext, postId: postIds[8], user: fakeUsers[1], content: "Spin class warriors are built different", hoursAgo: 17)
        seedComment(ctx: modelContext, postId: postIds[8], user: fakeUsers[4], content: "The endorphin rush after spin is unmatched", hoursAgo: 16.5)
        seedComment(ctx: modelContext, postId: postIds[8], user: fakeUsers[7], content: "Jello legs = good workout", hoursAgo: 16)

        // Post 9: Yoga
        seedComment(ctx: modelContext, postId: postIds[9], user: fakeUsers[2], content: "Recovery is gains. More people need to hear this", hoursAgo: 23)
        seedComment(ctx: modelContext, postId: postIds[9], user: fakeUsers[5], content: "Yoga changed my squat mobility completely", hoursAgo: 22.5)
        seedComment(ctx: modelContext, postId: postIds[9], user: fakeUsers[7], content: "What's your favorite flow for hip openers?", hoursAgo: 22)
        seedComment(ctx: modelContext, postId: postIds[9], user: fakeUsers[0], content: "Mobility work = injury prevention = longevity", hoursAgo: 21.5)

        // Post 10: Dumbbell curl
        seedComment(ctx: modelContext, postId: postIds[10], user: fakeUsers[3], content: "Slow eccentrics are the cheat code", hoursAgo: 29)
        seedComment(ctx: modelContext, postId: postIds[10], user: fakeUsers[6], content: "Time under tension is underrated", hoursAgo: 28.5)
        seedComment(ctx: modelContext, postId: postIds[10], user: fakeUsers[9], content: "Arms looking swole 💪", hoursAgo: 28)

        // Post 11: Kettlebell
        seedComment(ctx: modelContext, postId: postIds[11], user: fakeUsers[4], content: "Simple & Sinister! Pavel would be proud", hoursAgo: 35)
        seedComment(ctx: modelContext, postId: postIds[11], user: fakeUsers[7], content: "100 swings is no joke. Great conditioning", hoursAgo: 34.5)
        seedComment(ctx: modelContext, postId: postIds[11], user: fakeUsers[2], content: "Hip hinge power. Functional fitness at its best", hoursAgo: 34)

        try? modelContext.save()
        UserDefaults.standard.set(true, forKey: "hasSeededDiscoverVideos_v1")
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
