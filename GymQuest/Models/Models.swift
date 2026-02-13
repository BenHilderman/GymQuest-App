//
//  Models.swift
//  GymQuest
//
//  Created by Benjamin Hilderman
//
//  All the data models that make the app work. Workouts, exercises, sets,
//  user profiles, chat messages, etc. SwiftData handles saving everything
//  to the phone automatically - I just define the shape of the data here.
//
//  The XP/level system is in here too. You earn XP for completing workouts
//  and level up as you go. Makes it feel more like a game.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Shared Workout Data (for Follow Workout feature)

/// Lightweight workout data that can be embedded in posts for sharing
struct SharedWorkoutData: Codable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var workoutType: String
    var estimatedDuration: Int  // minutes
    var exercises: [SharedExercise]
    var authorName: String
    var authorUsername: String
    var notes: String?

    struct SharedExercise: Codable, Identifiable {
        var id: UUID = UUID()
        var name: String
        var muscleGroup: String
        var sets: [SharedSet]
        var notes: String?
        var demoTips: [String]

        struct SharedSet: Codable, Identifiable {
            var id: UUID = UUID()
            var reps: Int
            var weight: Double
            var restSeconds: Int

            init(id: UUID = UUID(), reps: Int = 0, weight: Double = 0, restSeconds: Int = 60) {
                self.id = id
                self.reps = reps
                self.weight = weight
                self.restSeconds = restSeconds
            }
        }

        init(id: UUID = UUID(), name: String = "", muscleGroup: String = "", sets: [SharedSet] = [], notes: String? = nil, demoTips: [String] = []) {
            self.id = id
            self.name = name
            self.muscleGroup = muscleGroup
            self.sets = sets
            self.notes = notes
            self.demoTips = demoTips
        }
    }

    init(id: UUID = UUID(), title: String = "", workoutType: String = "", estimatedDuration: Int = 0, exercises: [SharedExercise] = [], authorName: String = "", authorUsername: String = "", notes: String? = nil) {
        self.id = id
        self.title = title
        self.workoutType = workoutType
        self.estimatedDuration = estimatedDuration
        self.exercises = exercises
        self.authorName = authorName
        self.authorUsername = authorUsername
        self.notes = notes
    }

    /// Create SharedWorkoutData from a Workout
    static func from(workout: Workout, author: UserProfile) -> SharedWorkoutData {
        let sharedExercises = workout.exercises.map { exercise -> SharedExercise in
            let sharedSets = exercise.sets.map { set -> SharedExercise.SharedSet in
                SharedExercise.SharedSet(
                    reps: set.reps,
                    weight: set.weight,
                    restSeconds: 60  // Default rest time
                )
            }

            // Get form tips from exercise database if available
            let tips = ExtendedExerciseDatabase.find(exercise.name)?.cues ?? []

            return SharedExercise(
                name: exercise.name,
                muscleGroup: exercise.muscleGroup.rawValue,
                sets: sharedSets,
                demoTips: Array(tips.prefix(3))
            )
        }

        return SharedWorkoutData(
            title: workout.title ?? workout.type.rawValue,
            workoutType: workout.type.rawValue,
            estimatedDuration: workout.duration,
            exercises: sharedExercises,
            authorName: author.name,
            authorUsername: author.username,
            notes: workout.notes.isEmpty ? nil : workout.notes
        )
    }

    /// Convert to ActiveExercise array for launching a real workout
    func toActiveExercises() -> [ActiveExercise] {
        exercises.map { ex in
            let mg = MuscleGroup(rawValue: ex.muscleGroup) ?? .chest
            let sets = ex.sets.map { ActiveSet(reps: $0.reps, weight: $0.weight) }
            return ActiveExercise(name: ex.name, muscleGroup: mg, sets: sets)
        }
    }

    /// Encode to Data for storage
    func encode() -> Data? {
        try? JSONEncoder().encode(self)
    }
}

// MARK: - Calendar Extension

extension Calendar {
    /// Get the start of the week (Monday) for a given date
    func startOfWeek(for date: Date) -> Date {
        var cal = self
        cal.firstWeekday = 2 // Monday
        return cal.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: date).date ?? date
    }
}

// MARK: - Workout Source & Privacy

/// Tracks where a workout originated from
enum WorkoutSource: String, Codable {
    case manual = "Manual"
    case template = "Template"
    case healthkit = "HealthKit"
    case strava = "Strava"
    case whoop = "WHOOP"
    case repeatLast = "Repeat Last"
}

/// Privacy level for workouts and posts
enum WorkoutPrivacy: String, Codable, CaseIterable {
    case privateOnly = "Private"
    case friends = "Friends"
    case squad = "Squad"
    case publicFeed = "Public"
}

// MARK: - Exercise Categories & Equipment

/// Movement pattern categories for exercises
enum ExerciseCategory: String, Codable, CaseIterable {
    case push = "Push"
    case pull = "Pull"
    case legs = "Legs"
    case core = "Core"
    case mobility = "Mobility"
    case cardio = "Cardio"
    case compound = "Compound"
    case isolation = "Isolation"
}

/// Equipment types for exercises
enum Equipment: String, Codable, CaseIterable {
    case barbell = "Barbell"
    case dumbbell = "Dumbbell"
    case cable = "Cable"
    case machine = "Machine"
    case bodyweight = "Bodyweight"
    case band = "Band"
    case kettlebell = "Kettlebell"
    case other = "Other"

    var icon: String {
        switch self {
        case .barbell: return "figure.strengthtraining.traditional"
        case .dumbbell: return "dumbbell.fill"
        case .cable: return "cable.connector"
        case .machine: return "gearshape.fill"
        case .bodyweight: return "figure.stand"
        case .band: return "lasso"
        case .kettlebell: return "scalemass.fill"
        case .other: return "questionmark.circle"
        }
    }
}

/// Exercise difficulty level
enum ExerciseDifficulty: String, Codable, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
}

// MARK: - Favorite Exercise

@Model
final class FavoriteExercise {
    var id: UUID
    var name: String
    var muscleGroup: String
    var createdAt: Date

    init(name: String, muscleGroup: String) {
        self.id = UUID()
        self.name = name
        self.muscleGroup = muscleGroup
        self.createdAt = Date()
    }
}

@Model
final class Workout {
    var id: UUID
    var date: Date
    var type: WorkoutType
    var duration: Int // minutes
    var rpe: Int // 1-10 This is the scale of how hard the user felt (Rate of percieved exertion)
    var notes: String
    var createdAt: Date

    // GymQuest 2.0 additions
    var title: String?
    var source: WorkoutSource
    var privacy: WorkoutPrivacy
    var templateId: UUID? // if created from a template
    var isFavorite: Bool

    @Relationship(deleteRule: .cascade) var exercises: [Exercise]
    @Relationship(deleteRule: .cascade) var prEvents: [PREvent]
    @Relationship(deleteRule: .cascade) var mediaItems: [MediaItem]

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        type: WorkoutType = .push,
        duration: Int = 60,
        rpe: Int = 7,
        notes: String = "",
        exercises: [Exercise] = [],
        title: String? = nil,
        source: WorkoutSource = .manual,
        privacy: WorkoutPrivacy = .friends,
        templateId: UUID? = nil,
        prEvents: [PREvent] = [],
        mediaItems: [MediaItem] = [],
        isFavorite: Bool = false
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.duration = duration
        self.rpe = rpe
        self.notes = notes
        self.createdAt = Date()
        self.exercises = exercises
        self.title = title
        self.source = source
        self.privacy = privacy
        self.templateId = templateId
        self.prEvents = prEvents
        self.mediaItems = mediaItems
        self.isFavorite = isFavorite
    }

    var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }

    /// Total volume in lbs (sum of weight × reps for all sets)
    var totalVolume: Double {
        exercises.reduce(0.0) { total, exercise in
            total + exercise.sets.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
        }
    }

    /// Top set per exercise (highest weight)
    var topSets: [TopSetSummary] {
        exercises.compactMap { exercise in
            guard let topSet = exercise.sets.max(by: { $0.weight < $1.weight }) else { return nil }
            return TopSetSummary(
                exerciseName: exercise.name,
                weight: topSet.weight,
                reps: topSet.reps,
                estimated1RM: topSet.estimated1RM
            )
        }
    }

    var xpValue: Int {
        var xp = 20 + (totalSets * 5) + (rpe >= 8 ? 10 : 0)
        // Bonus for PRs
        xp += prEvents.count * 15
        return xp
    }

    /// Check if this is a PR workout
    var hasPRs: Bool {
        !prEvents.isEmpty
    }
}

/// Summary of the top set for an exercise
struct TopSetSummary: Codable, Identifiable {
    var id: UUID = UUID()
    let exerciseName: String
    let weight: Double
    let reps: Int
    let estimated1RM: Double?

    var displayString: String {
        let weightStr = weight > 0 ? "\(Int(weight)) lbs" : "BW"
        return "\(exerciseName): \(reps) × \(weightStr)"
    }
}

/// Personal Record event detected during a workout
@Model
final class PREvent {
    var id: UUID
    var date: Date
    var exerciseId: UUID?
    var exerciseName: String
    var prType: PREventType
    var newValue: Double
    var previousValue: Double?
    var delta: Double? // e.g., +5 lb
    var deltaDisplay: String? // e.g., "+5 lbs"
    var mediaId: UUID? // optional PR clip
    var workout: Workout?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        exerciseId: UUID? = nil,
        exerciseName: String = "",
        prType: PREventType = .weightPR,
        newValue: Double = 0,
        previousValue: Double? = nil,
        delta: Double? = nil,
        deltaDisplay: String? = nil,
        mediaId: UUID? = nil
    ) {
        self.id = id
        self.date = date
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.prType = prType
        self.newValue = newValue
        self.previousValue = previousValue
        self.delta = delta
        self.deltaDisplay = deltaDisplay
        self.mediaId = mediaId
    }
}

enum PREventType: String, Codable {
    case weightPR = "Weight PR"
    case repPR = "Rep PR"
    case volumePR = "Volume PR"
    case estimated1RMPR = "e1RM PR"
}

/// Media attached to workouts, posts, or learning items
@Model
final class MediaItem {
    var id: UUID
    var type: MediaType
    var data: Data?
    var thumbnailData: Data?
    var localPath: String? // for larger files
    var durationSec: Int? // for videos
    var createdAt: Date
    var caption: String?
    var workout: Workout?

    init(
        id: UUID = UUID(),
        type: MediaType = .photo,
        data: Data? = nil,
        thumbnailData: Data? = nil,
        localPath: String? = nil,
        durationSec: Int? = nil,
        createdAt: Date = Date(),
        caption: String? = nil
    ) {
        self.id = id
        self.type = type
        self.data = data
        self.thumbnailData = thumbnailData
        self.localPath = localPath
        self.durationSec = durationSec
        self.createdAt = createdAt
        self.caption = caption
    }
}

enum MediaType: String, Codable {
    case photo = "Photo"
    case video = "Video"
    case prClip = "PR Clip"
}

enum WorkoutType: String, Codable, CaseIterable {
    case push = "Push"
    case pull = "Pull"
    case legs = "Legs"
    case upper = "Upper Body"
    case lower = "Lower Body"
    case fullBody = "Full Body"
    case cardio = "Cardio"
    case rest = "Active Recovery"

    var icon: String {
        switch self {
        case .push: return "arrow.up.circle.fill"
        case .pull: return "arrow.down.circle.fill"
        case .legs: return "figure.walk"
        case .upper: return "figure.arms.open"
        case .lower: return "figure.stand"
        case .fullBody: return "figure.strengthtraining.traditional"
        case .cardio: return "figure.run"
        case .rest: return "leaf.fill"
        }
    }

    var color: Color {
        return Color(red: 0.0, green: 0.9, blue: 0.9) // Cyan accent
    }
}

@Model
final class Exercise {
    var id: UUID
    var name: String
    var muscleGroup: MuscleGroup
    var order: Int

    // GymQuest 2.0 additions
    var category: ExerciseCategory
    var equipment: Equipment
    var primaryMuscleGroups: [String] // For more detailed muscle targeting
    var aliases: [String] // For search + import mapping
    var difficulty: ExerciseDifficulty

    @Relationship(deleteRule: .cascade) var sets: [ExerciseSet]
    var workout: Workout?

    init(
        id: UUID = UUID(),
        name: String = "",
        muscleGroup: MuscleGroup = .chest,
        order: Int = 0,
        sets: [ExerciseSet] = [],
        category: ExerciseCategory = .push,
        equipment: Equipment = .barbell,
        primaryMuscleGroups: [String] = [],
        aliases: [String] = [],
        difficulty: ExerciseDifficulty = .intermediate
    ) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
        self.order = order
        self.sets = sets
        self.category = category
        self.equipment = equipment
        self.primaryMuscleGroups = primaryMuscleGroups
        self.aliases = aliases
        self.difficulty = difficulty
    }

    /// Best set by weight
    var topSet: ExerciseSet? {
        sets.max(by: { $0.weight < $1.weight })
    }

    /// Total volume for this exercise
    var totalVolume: Double {
        sets.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
    }
}

enum MuscleGroup: String, Codable, CaseIterable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case biceps = "Biceps"
    case triceps = "Triceps"
    case quads = "Quads"
    case hamstrings = "Hamstrings"
    case glutes = "Glutes"
    case calves = "Calves"
    case core = "Core"
    case cardio = "Cardio"

    var color: String {
        switch self {
        case .chest: return "red"
        case .back: return "blue"
        case .shoulders: return "orange"
        case .biceps: return "purple"
        case .triceps: return "pink"
        case .quads: return "green"
        case .hamstrings: return "teal"
        case .glutes: return "indigo"
        case .calves: return "mint"
        case .core: return "yellow"
        case .cardio: return "red"
        }
    }

    var optimalWeeklySets: Int {
        switch self {
        case .chest: return 12 // Assuming twice a week 6 sets a workout.
        case .back: return 15
        case .shoulders: return 12
        case .biceps: return 10
        case .triceps: return 10
        case .quads: return 12
        case .hamstrings: return 10
        case .glutes: return 10
        case .calves: return 8
        case .core: return 8
        case .cardio: return 0
        }
    }
}

@Model
final class ExerciseSet {
    var id: UUID
    var reps: Int
    var weight: Double
    var rpe: Int?
    var order: Int
    var exercise: Exercise?

    // GymQuest 2.0 additions for cardio/timed exercises
    var durationSec: Int? // for timed sets (planks, cardio intervals)
    var distance: Double? // for distance-based (running, rowing)
    var notes: String?
    var timestamp: Date

    init(
        id: UUID = UUID(),
        reps: Int = 0,
        weight: Double = 0,
        rpe: Int? = nil,
        order: Int = 0,
        durationSec: Int? = nil,
        distance: Double? = nil,
        notes: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.reps = reps
        self.weight = weight
        self.rpe = rpe
        self.order = order
        self.durationSec = durationSec
        self.distance = distance
        self.notes = notes
        self.timestamp = timestamp
    }

    /// Estimated 1RM using Epley formula: weight × (1 + reps/30)
    var estimated1RM: Double? {
        guard weight > 0, reps > 0, reps <= 12 else { return nil }
        return weight * (1 + Double(reps) / 30.0)
    }

    /// Display string for the set
    var displayString: String {
        if let duration = durationSec {
            let mins = duration / 60
            let secs = duration % 60
            if mins > 0 {
                return "\(mins)m \(secs)s"
            }
            return "\(secs)s"
        }
        if let dist = distance {
            return String(format: "%.1f mi", dist)
        }
        if weight > 0 {
            return "\(reps) × \(Int(weight)) lbs"
        }
        return "\(reps) reps"
    }
}

@Model
final class UserProfile {
    var id: UUID
    var name: String
    var username: String         // for @mentions (like @benjaminhilderman)
    var profilePhotoData: Data?  // optional profile pic
    var goal: FitnessGoal
    var daysPerWeek: Int
    var injuries: String
    var xp: Int
    var level: Int
    var aiProvider: AIProvider
    var apiKey: String
    var ollamaModel: String      // separate field for Ollama model name
    var ollamaHost: String       // host IP/hostname for Ollama server

    // auth fields
    var isAuthenticated: Bool
    var authMethod: String?      // "google" or "email"
    var email: String?
    var passwordHash: String?    // SHA256 hash for local storage
    var googleId: String?
    var dateOfBirth: Date?

    init(
        id: UUID = UUID(),
        name: String = "Athlete",
        username: String = "athlete",
        profilePhotoData: Data? = nil,
        goal: FitnessGoal = .hypertrophy,
        daysPerWeek: Int = 4,
        injuries: String = "",
        xp: Int = 0,
        level: Int = 1,
        aiProvider: AIProvider = .demo,
        apiKey: String = "",
        ollamaModel: String = "llama3.2",
        ollamaHost: String = "localhost",
        isAuthenticated: Bool = false,
        authMethod: String? = nil,
        email: String? = nil,
        passwordHash: String? = nil,
        googleId: String? = nil,
        dateOfBirth: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.username = username
        self.profilePhotoData = profilePhotoData
        self.goal = goal
        self.daysPerWeek = daysPerWeek
        self.injuries = injuries
        self.xp = xp
        self.level = level
        self.aiProvider = aiProvider
        self.apiKey = apiKey
        self.ollamaModel = ollamaModel
        self.ollamaHost = ollamaHost
        self.isAuthenticated = isAuthenticated
        self.authMethod = authMethod
        self.email = email
        self.passwordHash = passwordHash
        self.googleId = googleId
        self.dateOfBirth = dateOfBirth
    }

    func addXP(_ amount: Int) -> Bool {
        xp += amount
        let newLevel = UserProfile.calculateLevel(from: xp).level
        let leveledUp = newLevel > level
        level = newLevel
        return leveledUp
    }

    static func calculateLevel(from xp: Int) -> (level: Int, currentXP: Int, nextXP: Int) {
        let levels = [0, 100, 250, 500, 1000, 2000, 3500, 5500, 8000, 12000, 20000]
        for i in stride(from: levels.count - 1, through: 0, by: -1) {
            if xp >= levels[i] {
                let nextThreshold = i + 1 < levels.count ? levels[i + 1] : levels[i] + 5000
                return (i + 1, xp - levels[i], nextThreshold - levels[i])
            }
        }
        return (1, xp, 100)
    }

    static func levelTitle(for level: Int) -> String {
        let titles = ["Beginner", "Novice", "Apprentice", "Intermediate", "Experienced",
                      "Advanced", "Expert", "Elite", "Master", "Champion", "Legend"]
        return titles[min(level - 1, titles.count - 1)]
    }
}

enum FitnessGoal: String, Codable, CaseIterable {
    case hypertrophy = "Hypertrophy"
    case strength = "Strength"
    case performance = "Performance"
    case general = "General Fitness"
}

enum AIProvider: String, Codable, CaseIterable {
    case openai = "OpenAI (GPT-4)"
    case groq = "Groq (Llama)"
    case ollama = "Ollama (Local)"
    case demo = "Demo Mode"
}

// logs for my debugging when there are issues with the AI API
// Was having an issue with my API usage and I ran out of tokens,
// this showed that error
@Model
final class AILogEntry {
    var id: UUID
    var timestamp: Date
    var prompt: String
    var response: String
    var provider: AIProvider

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        prompt: String = "",
        response: String = "",
        provider: AIProvider = .demo
    ) {
        self.id = id
        self.timestamp = timestamp
        self.prompt = prompt
        self.response = response
        self.provider = provider
    }
}

@Model
final class ChatMessage { // Each message is stored individually with a role so the conversation flows well
    var id: UUID
    var content: String
    var role: MessageRole
    var timestamp: Date

    init(
        id: UUID = UUID(),
        content: String = "",
        role: MessageRole = .user,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.content = content
        self.role = role
        self.timestamp = timestamp
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

// MARK: - Post Media (Exercise-Specific Media)

/// Media item that can be associated with a specific exercise in a post
struct PostMedia: Codable, Identifiable {
    var id: UUID = UUID()
    var exerciseName: String?           // nil = general post media (not exercise-specific)
    var exerciseIndex: Int?             // Index in the workout for ordering
    var mediaType: PostMediaType
    var data: Data?                     // Actual media bytes
    var thumbnailData: Data?            // Video thumbnail for preview
    var caption: String?                // Optional per-media caption
    var timestamp: Date = Date()

    enum PostMediaType: String, Codable {
        case photo
        case video
    }

    init(
        id: UUID = UUID(),
        exerciseName: String? = nil,
        exerciseIndex: Int? = nil,
        mediaType: PostMediaType = .photo,
        data: Data? = nil,
        thumbnailData: Data? = nil,
        caption: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.exerciseName = exerciseName
        self.exerciseIndex = exerciseIndex
        self.mediaType = mediaType
        self.data = data
        self.thumbnailData = thumbnailData
        self.caption = caption
        self.timestamp = timestamp
    }
}

// this is what shows up in the feed - a shareable workout moment
// users can post with or without exact stats, add a photo, caption, and tag friends
@Model
final class Post {
    var id: UUID
    var authorId: UUID
    var authorName: String
    var authorUsername: String
    var timestamp: Date
    var caption: String
    var photoData: Data? // optional image
    var videoData: Data?  // optional video

    // workout info (optional)
    var workoutType: String?
    var duration: Int?
    var setCount: Int?
    var exerciseHighlight: String?

    // music info (TikTok/Instagram style)
    var songTitle: String?
    var artistName: String?
    var songPreviewURL: String?  // For playback
    var musicSource: String?     // "spotify", "apple_music", "ai_suggested"
    var playlistId: String?      // If linked from a playlist

    // activity detection (AI-detected from image)
    var detectedActivity: String?  // "tennis", "weightlifting", etc.

    // Shareable workout data (for "Follow this workout" feature)
    var sharedWorkoutData: Data?  // JSON-encoded SharedWorkoutData

    // Attribution (when copying/following someone's workout)
    var inspiredByUsername: String?   // "@username" whose workout was followed
    var inspiredByWorkoutId: UUID?    // Original workout ID
    var inspiredByName: String?       // Display name of original author

    // social
    var taggedUsernames: [String]
    var likeCount: Int
    var commentCount: Int

    // Enhanced media (GymQuest 2.0 - exercise-aligned media)
    var mediaItemsData: Data?           // JSON-encoded [PostMedia]

    // Location tagging
    var locationName: String?           // e.g., "The ARC - Queen's University"
    var locationId: UUID?               // Link to Community if from known gym

    // Squad/Group tagging
    var taggedSquadIds: [UUID]          // Squads this post is shared with
    var taggedSquadNames: [String]      // Display names for rendering

    // Enhanced music (playlist URLs)
    var spotifyPlaylistURL: String?     // Full Spotify playlist URL
    var appleMusicPlaylistURL: String?  // Full Apple Music playlist URL

    // Workout emotion
    var workoutEmotion: String?         // WorkoutEmotion rawValue

    init(
        id: UUID = UUID(),
        authorId: UUID = UUID(),
        authorName: String = "",
        authorUsername: String = "",
        timestamp: Date = Date(),
        caption: String = "",
        photoData: Data? = nil,
        videoData: Data? = nil,
        workoutType: String? = nil,
        duration: Int? = nil,
        setCount: Int? = nil,
        exerciseHighlight: String? = nil,
        songTitle: String? = nil,
        artistName: String? = nil,
        songPreviewURL: String? = nil,
        musicSource: String? = nil,
        playlistId: String? = nil,
        detectedActivity: String? = nil,
        sharedWorkoutData: Data? = nil,
        inspiredByUsername: String? = nil,
        inspiredByWorkoutId: UUID? = nil,
        inspiredByName: String? = nil,
        taggedUsernames: [String] = [],
        likeCount: Int = 0,
        commentCount: Int = 0,
        mediaItemsData: Data? = nil,
        locationName: String? = nil,
        locationId: UUID? = nil,
        taggedSquadIds: [UUID] = [],
        taggedSquadNames: [String] = [],
        spotifyPlaylistURL: String? = nil,
        appleMusicPlaylistURL: String? = nil,
        workoutEmotion: String? = nil
    ) {
        self.id = id
        self.authorId = authorId
        self.authorName = authorName
        self.authorUsername = authorUsername
        self.timestamp = timestamp
        self.caption = caption
        self.photoData = photoData
        self.videoData = videoData
        self.workoutType = workoutType
        self.duration = duration
        self.setCount = setCount
        self.exerciseHighlight = exerciseHighlight
        self.songTitle = songTitle
        self.artistName = artistName
        self.songPreviewURL = songPreviewURL
        self.musicSource = musicSource
        self.playlistId = playlistId
        self.detectedActivity = detectedActivity
        self.sharedWorkoutData = sharedWorkoutData
        self.inspiredByUsername = inspiredByUsername
        self.inspiredByWorkoutId = inspiredByWorkoutId
        self.inspiredByName = inspiredByName
        self.taggedUsernames = taggedUsernames
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.mediaItemsData = mediaItemsData
        self.locationName = locationName
        self.locationId = locationId
        self.taggedSquadIds = taggedSquadIds
        self.taggedSquadNames = taggedSquadNames
        self.spotifyPlaylistURL = spotifyPlaylistURL
        self.appleMusicPlaylistURL = appleMusicPlaylistURL
        self.workoutEmotion = workoutEmotion
    }

    /// Decode shared workout data for follow feature
    func getSharedWorkout() -> SharedWorkoutData? {
        guard let data = sharedWorkoutData else { return nil }
        return try? JSONDecoder().decode(SharedWorkoutData.self, from: data)
    }

    /// Get/set decoded media items for exercise-aligned media
    var mediaItems: [PostMedia] {
        get {
            guard let data = mediaItemsData else { return [] }
            return (try? JSONDecoder().decode([PostMedia].self, from: data)) ?? []
        }
        set {
            mediaItemsData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Check if post has exercise-specific media
    var hasExerciseMedia: Bool {
        mediaItems.contains { $0.exerciseName != nil }
    }

    /// Check if post has any media (including legacy photoData/videoData)
    var hasMedia: Bool {
        !mediaItems.isEmpty || photoData != nil || videoData != nil
    }

    /// Typed accessor for the workout emotion
    var emotion: WorkoutEmotion? {
        guard let workoutEmotion else { return nil }
        return WorkoutEmotion(rawValue: workoutEmotion)
    }
}

// tracks who follows who - for the feed and @mentions
@Model
final class Friend {
    var id: UUID
    var odId: UUID         // the person i'm following
    var odName: String
    var odUsername: String
    var followedAt: Date

    init(
        id: UUID = UUID(),
        odId: UUID = UUID(),
        odName: String = "",
        odUsername: String = "",
        followedAt: Date = Date()
    ) {
        self.id = id
        self.odId = odId
        self.odName = odName
        self.odUsername = odUsername
        self.followedAt = followedAt
    }
}

// simple like system - who liked what post
@Model
final class Like {
    var id: UUID
    var postId: UUID
    var userId: UUID
    var userName: String
    var timestamp: Date

    init(
        id: UUID = UUID(),
        postId: UUID,
        userId: UUID,
        userName: String = "",
        timestamp: Date = Date()
    ) {
        self.id = id
        self.postId = postId
        self.userId = userId
        self.userName = userName
        self.timestamp = timestamp
    }
}

// comments on posts
@Model
final class Comment {
    var id: UUID
    var postId: UUID
    var authorId: UUID
    var authorName: String
    var authorUsername: String
    var content: String
    var timestamp: Date

    init(
        id: UUID = UUID(),
        postId: UUID = UUID(),
        authorId: UUID = UUID(),
        authorName: String = "",
        authorUsername: String = "",
        content: String = "",
        timestamp: Date = Date()
    ) {
        self.id = id
        self.postId = postId
        self.authorId = authorId
        self.authorName = authorName
        self.authorUsername = authorUsername
        self.content = content
        self.timestamp = timestamp
    }
}

// the "strava map" equivalent for lifting - auto-generated from logged sessions
// shows the users post in an interactive "wokrout card"
@Model
final class WorkoutCard {
    var id: UUID
    var odId: UUID
    var odName: String
    var odUsername: String
    var workoutId: UUID
    var workoutType: String
    var duration: Int
    var totalSets: Int
    var avgRPE: Double?
    var exerciseSummary: String  // JSON encoded array
    var coachTakeaway: String?
    var xpEarned: Int
    var streakCount: Int
    var visibility: CardVisibility
    var taggedUsernames: [String]
    var fistBumpCount: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        odId: UUID = UUID(),
        odName: String = "",
        odUsername: String = "",
        workoutId: UUID = UUID(),
        workoutType: String = "",
        duration: Int = 0,
        totalSets: Int = 0,
        avgRPE: Double? = nil,
        exerciseSummary: String = "[]",
        coachTakeaway: String? = nil,
        xpEarned: Int = 0,
        streakCount: Int = 0,
        visibility: CardVisibility = .pod,
        taggedUsernames: [String] = [],
        fistBumpCount: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.odId = odId
        self.odName = odName
        self.odUsername = odUsername
        self.workoutId = workoutId
        self.workoutType = workoutType
        self.duration = duration
        self.totalSets = totalSets
        self.avgRPE = avgRPE
        self.exerciseSummary = exerciseSummary
        self.coachTakeaway = coachTakeaway
        self.xpEarned = xpEarned
        self.streakCount = streakCount
        self.visibility = visibility
        self.taggedUsernames = taggedUsernames
        self.fistBumpCount = fistBumpCount
        self.createdAt = createdAt
    }

    // decode exercise summary
    func getExercises() -> [ExerciseSummaryItem] {
        guard let data = exerciseSummary.data(using: .utf8),
              let items = try? JSONDecoder().decode([ExerciseSummaryItem].self, from: data) else {
            return []
        }
        return items
    }
}

enum CardVisibility: String, Codable {
    case pod = "Pod"
    case friends = "Friends"
    case privateOnly = "Private"
}

// lightweight exercise info for the card
struct ExerciseSummaryItem: Codable, Identifiable {
    var id: UUID = UUID()
    let name: String
    let sets: Int
    let reps: String  // e.g., "8-10" or "8"
    let weight: Double

    var displayString: String {
        if weight > 0 {
            return "\(sets)×\(reps) @ \(Int(weight)) lbs"
        }
        return "\(sets)×\(reps)"
    }
}

// tracks personal records - the "achievement" system
@Model
final class PRMoment {
    var id: UUID
    var odId: UUID
    var odUsername: String
    var prType: PRType
    var exerciseName: String?
    var value: String           // e.g., "185×5"
    var previousValue: String?  // e.g., "175×5"
    var improvement: String?    // e.g., "+10 lbs"
    var workoutCardId: UUID?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        odId: UUID = UUID(),
        odUsername: String = "",
        prType: PRType = .repPR,
        exerciseName: String? = nil,
        value: String = "",
        previousValue: String? = nil,
        improvement: String? = nil,
        workoutCardId: UUID? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.odId = odId
        self.odUsername = odUsername
        self.prType = prType
        self.exerciseName = exerciseName
        self.value = value
        self.previousValue = previousValue
        self.improvement = improvement
        self.workoutCardId = workoutCardId
        self.createdAt = createdAt
    }
}

enum PRType: String, Codable {
    case repPR = "Rep PR"
    case e1rmPR = "e1RM PR"
    case volumePR = "Volume PR"
    case streakPR = "Streak PR"
    case comebackPR = "Comeback"
}

@Model
final class FistBump {
    var id: UUID
    var odId: UUID
    var targetType: FistBumpTarget
    var targetId: UUID
    var createdAt: Date

    init(
        id: UUID = UUID(),
        odId: UUID = UUID(),
        targetType: FistBumpTarget = .workoutCard,
        targetId: UUID = UUID(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.odId = odId
        self.targetType = targetType
        self.targetId = targetId
        self.createdAt = createdAt
    }
}

enum FistBumpTarget: String, Codable {
    case workoutCard
    case prMoment
}

@Model
final class Pod {
    var id: UUID
    var name: String
    var inviteCode: String
    var creatorId: UUID
    var memberIds: [UUID]
    var streakWeeks: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        inviteCode: String = "",
        creatorId: UUID = UUID(),
        memberIds: [UUID] = [],
        streakWeeks: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.inviteCode = inviteCode.isEmpty ? Pod.generateCode() : inviteCode
        self.creatorId = creatorId
        self.memberIds = memberIds
        self.streakWeeks = streakWeeks
        self.createdAt = createdAt
    }

    static func generateCode() -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).compactMap { _ in chars.randomElement() })
    }
}

// MARK: - Quest System (GymQuest 2.0)

/// Quest categories for the RPG system
enum QuestCategory: String, Codable, CaseIterable {
    case training = "Training"
    case mobility = "Mobility"
    case learning = "Learning"
    case nutrition = "Nutrition"
    case recovery = "Recovery"
    case social = "Social"

    var icon: String {
        switch self {
        case .training: return "dumbbell.fill"
        case .mobility: return "figure.flexibility"
        case .learning: return "book.fill"
        case .nutrition: return "leaf.fill"
        case .recovery: return "bed.double.fill"
        case .social: return "person.2.fill"
        }
    }

    var color: String {
        switch self {
        case .training: return "orange"
        case .mobility: return "blue"
        case .learning: return "purple"
        case .nutrition: return "green"
        case .recovery: return "indigo"
        case .social: return "pink"
        }
    }
}

enum QuestDifficulty: String, Codable, CaseIterable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"

    var xpMultiplier: Double {
        switch self {
        case .easy: return 1.0
        case .medium: return 1.5
        case .hard: return 2.5
        }
    }
}

enum QuestExpiry: String, Codable {
    case daily = "Daily"
    case weekly = "Weekly"
    case none = "No Expiry"
}

/// Quest definition
@Model
final class Quest {
    var id: UUID
    var title: String
    var questDescription: String
    var category: QuestCategory
    var difficulty: QuestDifficulty
    var completionCriteria: String // JSON-encoded criteria
    var xpReward: Int
    var badgeReward: String?
    var titleProgress: String? // Contributes to unlocking a title
    var expiry: QuestExpiry
    var isActive: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String = "",
        questDescription: String = "",
        category: QuestCategory = .training,
        difficulty: QuestDifficulty = .easy,
        completionCriteria: String = "{}",
        xpReward: Int = 25,
        badgeReward: String? = nil,
        titleProgress: String? = nil,
        expiry: QuestExpiry = .daily,
        isActive: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.questDescription = questDescription
        self.category = category
        self.difficulty = difficulty
        self.completionCriteria = completionCriteria
        self.xpReward = xpReward
        self.badgeReward = badgeReward
        self.titleProgress = titleProgress
        self.expiry = expiry
        self.isActive = isActive
        self.createdAt = createdAt
    }
}

/// Quest criteria types that can be evaluated from logs
struct QuestCriteria: Codable {
    var setsLogged: Int?
    var workoutsCompleted: Int?
    var exerciseType: String?
    var muscleGroup: String?
    var minimumRPE: Int?
    var mealsLogged: Int?
    var learningItemsViewed: Int?
    var kudosGiven: Int?
    var squadActivityCount: Int?
}

enum QuestStatus: String, Codable {
    case active = "Active"
    case completed = "Completed"
    case expired = "Expired"
}

/// User's progress on a specific quest
@Model
final class QuestProgress {
    var id: UUID
    var odId: UUID // User ID
    var questId: UUID
    var status: QuestStatus
    var progressValue: Int
    var targetValue: Int
    var startedAt: Date
    var completedAt: Date?
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        odId: UUID = UUID(),
        questId: UUID = UUID(),
        status: QuestStatus = .active,
        progressValue: Int = 0,
        targetValue: Int = 1,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.odId = odId
        self.questId = questId
        self.status = status
        self.progressValue = progressValue
        self.targetValue = targetValue
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.updatedAt = updatedAt
    }

    var progressPercentage: Double {
        guard targetValue > 0 else { return 0 }
        return min(1.0, Double(progressValue) / Double(targetValue))
    }

    var isComplete: Bool {
        progressValue >= targetValue
    }
}

/// Forgiveness token for flexible goal achievement
@Model
final class ForgivenessToken {
    var id: UUID
    var odId: UUID
    var month: Int // 1-12
    var year: Int
    var tokensRemaining: Int
    var tokensUsed: Int

    init(
        id: UUID = UUID(),
        odId: UUID = UUID(),
        month: Int = 1,
        year: Int = 2025,
        tokensRemaining: Int = 2,
        tokensUsed: Int = 0
    ) {
        self.id = id
        self.odId = odId
        self.month = month
        self.year = year
        self.tokensRemaining = tokensRemaining
        self.tokensUsed = tokensUsed
    }
}

// MARK: - Community System (GymQuest 2.0)

/// Community join type
enum CommunityJoinType: String, Codable, CaseIterable {
    case open = "Open"           // Anyone can join
    case request = "Request"     // Request to join, admin approves
}

/// Community (gyms, universities, rec centers)
@Model
final class Community {
    var id: UUID
    var name: String                    // e.g., "The ARC - Queen's University"
    var communityDescription: String
    var location: String?               // e.g., "Kingston, ON"
    var imageData: Data?                // Community banner/logo
    var creatorId: UUID
    var adminIds: [UUID]
    var memberIds: [UUID]
    var pendingRequestIds: [UUID]       // Users requesting to join
    var joinType: CommunityJoinType
    var memberCount: Int
    var isVerified: Bool                // Official gym/university account
    var tags: [String]                  // e.g., ["university", "gym", "weightlifting"]
    var createdAt: Date
    var parentCommunityId: UUID?        // non-nil = this is a channel/sub-community

    init(
        id: UUID = UUID(),
        name: String = "",
        communityDescription: String = "",
        location: String? = nil,
        imageData: Data? = nil,
        creatorId: UUID = UUID(),
        adminIds: [UUID] = [],
        memberIds: [UUID] = [],
        pendingRequestIds: [UUID] = [],
        joinType: CommunityJoinType = .open,
        memberCount: Int = 0,
        isVerified: Bool = false,
        tags: [String] = [],
        createdAt: Date = Date(),
        parentCommunityId: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.communityDescription = communityDescription
        self.location = location
        self.imageData = imageData
        self.creatorId = creatorId
        self.adminIds = adminIds.isEmpty ? [creatorId] : adminIds
        self.memberIds = memberIds.isEmpty ? [creatorId] : memberIds
        self.pendingRequestIds = pendingRequestIds
        self.joinType = joinType
        self.memberCount = memberCount == 0 ? 1 : memberCount
        self.isVerified = isVerified
        self.tags = tags
        self.createdAt = createdAt
        self.parentCommunityId = parentCommunityId
    }

    var isOpen: Bool {
        joinType == .open
    }

    var isChannel: Bool {
        parentCommunityId != nil
    }
}

/// Community post (workout shared to a community)
@Model
final class CommunityPost {
    var id: UUID
    var communityId: UUID
    var authorId: UUID
    var authorName: String
    var authorUsername: String
    var postType: CommunityPostType
    var content: String
    var workoutId: UUID?                // Link to workout if sharing one
    var photoData: Data?
    var likeCount: Int
    var commentCount: Int
    var timestamp: Date
    var channelId: UUID?

    init(
        id: UUID = UUID(),
        communityId: UUID = UUID(),
        authorId: UUID = UUID(),
        authorName: String = "",
        authorUsername: String = "",
        postType: CommunityPostType = .workout,
        content: String = "",
        workoutId: UUID? = nil,
        photoData: Data? = nil,
        likeCount: Int = 0,
        commentCount: Int = 0,
        timestamp: Date = Date(),
        channelId: UUID? = nil
    ) {
        self.id = id
        self.communityId = communityId
        self.authorId = authorId
        self.authorName = authorName
        self.authorUsername = authorUsername
        self.postType = postType
        self.content = content
        self.workoutId = workoutId
        self.photoData = photoData
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.timestamp = timestamp
        self.channelId = channelId
    }
}

enum CommunityPostType: String, Codable, CaseIterable {
    case workout = "Workout"
    case lookingForPartner = "Looking for Partner"
    case question = "Question"
    case achievement = "Achievement"
    case general = "General"

    var icon: String {
        switch self {
        case .workout: return "figure.strengthtraining.traditional"
        case .lookingForPartner: return "person.2.fill"
        case .question: return "questionmark.circle.fill"
        case .achievement: return "trophy.fill"
        case .general: return "text.bubble.fill"
        }
    }
}

// MARK: - Community Membership

enum CommunityRole: String, Codable {
    case member
    case admin
    case owner
}

enum WorkoutPartnerStatus: String, Codable {
    case available
    case notLooking
}

@Model
final class CommunityMembership {
    var id: UUID
    var userId: UUID
    var communityId: UUID
    var role: CommunityRole
    var workoutPartnerStatus: WorkoutPartnerStatus
    var joinedAt: Date

    init(
        id: UUID = UUID(),
        userId: UUID = UUID(),
        communityId: UUID = UUID(),
        role: CommunityRole = .member,
        workoutPartnerStatus: WorkoutPartnerStatus = .notLooking,
        joinedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.communityId = communityId
        self.role = role
        self.workoutPartnerStatus = workoutPartnerStatus
        self.joinedAt = joinedAt
    }
}

// MARK: - Community Challenge

enum ChallengeGoalType: String, Codable, CaseIterable {
    case workouts = "Workouts"
    case sets = "Sets"
    case volume = "Volume (lbs)"
    case streak = "Day Streak"

    var icon: String {
        switch self {
        case .workouts: return "figure.strengthtraining.traditional"
        case .sets: return "flame.fill"
        case .volume: return "scalemass.fill"
        case .streak: return "calendar.badge.checkmark"
        }
    }
}

@Model
final class CommunityChallenge {
    var id: UUID
    var communityId: UUID
    var title: String
    var challengeDescription: String
    var goalType: ChallengeGoalType
    var goalTarget: Int
    var currentProgress: Int
    var startDate: Date
    var endDate: Date
    var participantIds: [UUID]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        communityId: UUID = UUID(),
        title: String = "",
        challengeDescription: String = "",
        goalType: ChallengeGoalType = .sets,
        goalTarget: Int = 20,
        currentProgress: Int = 0,
        startDate: Date = Date(),
        endDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
        participantIds: [UUID] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.communityId = communityId
        self.title = title
        self.challengeDescription = challengeDescription
        self.goalType = goalType
        self.goalTarget = goalTarget
        self.currentProgress = currentProgress
        self.startDate = startDate
        self.endDate = endDate
        self.participantIds = participantIds
        self.createdAt = createdAt
    }

    var progress: Double {
        guard goalTarget > 0 else { return 0 }
        return min(1.0, Double(currentProgress) / Double(goalTarget))
    }

    var daysRemaining: Int {
        max(0, Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0)
    }

    var isActive: Bool {
        Date() >= startDate && Date() <= endDate
    }
}

// MARK: - Squad System (GymQuest 2.0)

enum WeeklyGoalType: String, Codable, CaseIterable {
    case sessionsPerWeek = "Sessions/Week"
    case sessionsOrMobility = "Sessions or Mobility"
    case volumeTarget = "Volume Target"
    case anyActivity = "Any Activity"
}

/// Weekly goal configuration for squads
struct WeeklyGoal: Codable {
    var type: WeeklyGoalType
    var target: Int
    var flexRule: String? // e.g., "3 sessions OR 2 + 1 mobility"
    var forgivenessTokensPerMonth: Int

    init(type: WeeklyGoalType = .sessionsPerWeek, target: Int = 3, flexRule: String? = nil, forgivenessTokensPerMonth: Int = 2) {
        self.type = type
        self.target = target
        self.flexRule = flexRule
        self.forgivenessTokensPerMonth = forgivenessTokensPerMonth
    }
}

/// Squad for social accountability (3-6 members)
@Model
final class Squad {
    var id: UUID
    var name: String
    var creatorId: UUID
    var memberIds: [UUID]
    var inviteCode: String
    var weeklyGoalData: Data? // Encoded WeeklyGoal
    var activeChallengeId: UUID?
    var streakWeeks: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        creatorId: UUID = UUID(),
        memberIds: [UUID] = [],
        inviteCode: String = "",
        weeklyGoal: WeeklyGoal = WeeklyGoal(),
        activeChallengeId: UUID? = nil,
        streakWeeks: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.creatorId = creatorId
        self.memberIds = memberIds
        self.inviteCode = inviteCode.isEmpty ? Squad.generateCode() : inviteCode
        self.weeklyGoalData = try? JSONEncoder().encode(weeklyGoal)
        self.activeChallengeId = activeChallengeId
        self.streakWeeks = streakWeeks
        self.createdAt = createdAt
    }

    var weeklyGoal: WeeklyGoal {
        get {
            guard let data = weeklyGoalData else { return WeeklyGoal() }
            return (try? JSONDecoder().decode(WeeklyGoal.self, from: data)) ?? WeeklyGoal()
        }
        set {
            weeklyGoalData = try? JSONEncoder().encode(newValue)
        }
    }

    static func generateCode() -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).compactMap { _ in chars.randomElement() })
    }

    var memberCount: Int {
        memberIds.count
    }

    var isFull: Bool {
        memberIds.count >= 6
    }
}

/// Squad challenge
@Model
final class SquadChallenge {
    var id: UUID
    var squadId: UUID
    var title: String
    var challengeDescription: String
    var startDate: Date
    var endDate: Date
    var targetValue: Int
    var currentValue: Int
    var xpReward: Int
    var isCompleted: Bool

    init(
        id: UUID = UUID(),
        squadId: UUID = UUID(),
        title: String = "",
        challengeDescription: String = "",
        startDate: Date = Date(),
        endDate: Date = Date().addingTimeInterval(7 * 24 * 60 * 60),
        targetValue: Int = 10,
        currentValue: Int = 0,
        xpReward: Int = 100,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.squadId = squadId
        self.title = title
        self.challengeDescription = challengeDescription
        self.startDate = startDate
        self.endDate = endDate
        self.targetValue = targetValue
        self.currentValue = currentValue
        self.xpReward = xpReward
        self.isCompleted = isCompleted
    }
}

// MARK: - Reaction System (Positive-only)

enum ReactionType: String, Codable, CaseIterable {
    case kudos = "Kudos"
    case fire = "Fire"
    case strong = "Strong"
    case nicePR = "Nice PR"
    case inspired = "Inspired"
    case respect = "Respect"

    var emoji: String {
        switch self {
        case .kudos: return "👊"
        case .fire: return "🔥"
        case .strong: return "💪"
        case .nicePR: return "🏆"
        case .inspired: return "✨"
        case .respect: return "🙌"
        }
    }
}

/// Positive reaction on posts/cards
@Model
final class Reaction {
    var id: UUID
    var odId: UUID // User who reacted
    var odUsername: String
    var targetType: String // "post", "workoutCard", "prMoment"
    var targetId: UUID
    var reactionType: ReactionType
    var createdAt: Date

    init(
        id: UUID = UUID(),
        odId: UUID = UUID(),
        odUsername: String = "",
        targetType: String = "post",
        targetId: UUID = UUID(),
        reactionType: ReactionType = .kudos,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.odId = odId
        self.odUsername = odUsername
        self.targetType = targetType
        self.targetId = targetId
        self.reactionType = reactionType
        self.createdAt = createdAt
    }
}

// MARK: - Learning System (GymQuest 2.0)

enum LearningItemType: String, Codable, CaseIterable {
    case demo = "Demo"
    case cue = "Form Cue"
    case mistake = "Common Mistake"
    case progression = "Progression"
    case mobilityRoutine = "Mobility Routine"
}

/// Learning content item (10-20s demos + cues)
@Model
final class LearningItem {
    var id: UUID
    var exerciseId: UUID? // or topic-based
    var exerciseName: String?
    var topic: String?
    var type: LearningItemType
    var durationSec: Int // target 10-20
    var mediaData: Data? // robot demo or real clip
    var mediaPath: String? // for larger files
    var textCues: [String] // max 2-3 cues
    var commonMistake: String?
    var progressionLinks: [UUID] // links to related LearningItems
    var tags: [String]
    var shareableTemplateId: UUID?
    var viewCount: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        exerciseId: UUID? = nil,
        exerciseName: String? = nil,
        topic: String? = nil,
        type: LearningItemType = .demo,
        durationSec: Int = 15,
        mediaData: Data? = nil,
        mediaPath: String? = nil,
        textCues: [String] = [],
        commonMistake: String? = nil,
        progressionLinks: [UUID] = [],
        tags: [String] = [],
        shareableTemplateId: UUID? = nil,
        viewCount: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.topic = topic
        self.type = type
        self.durationSec = durationSec
        self.mediaData = mediaData
        self.mediaPath = mediaPath
        self.textCues = textCues
        self.commonMistake = commonMistake
        self.progressionLinks = progressionLinks
        self.tags = tags
        self.shareableTemplateId = shareableTemplateId
        self.viewCount = viewCount
        self.createdAt = createdAt
    }

    var displayTitle: String {
        exerciseName ?? topic ?? "Learning Item"
    }
}

/// Tracks user's saved/viewed learning items
@Model
final class LearningProgress {
    var id: UUID
    var odId: UUID
    var learningItemId: UUID
    var viewed: Bool
    var saved: Bool
    var addedToPlan: Bool
    var viewedAt: Date?
    var savedAt: Date?

    init(
        id: UUID = UUID(),
        odId: UUID = UUID(),
        learningItemId: UUID = UUID(),
        viewed: Bool = false,
        saved: Bool = false,
        addedToPlan: Bool = false,
        viewedAt: Date? = nil,
        savedAt: Date? = nil
    ) {
        self.id = id
        self.odId = odId
        self.learningItemId = learningItemId
        self.viewed = viewed
        self.saved = saved
        self.addedToPlan = addedToPlan
        self.viewedAt = viewedAt
        self.savedAt = savedAt
    }
}

// MARK: - Nutrition System (Performance-first, GymQuest 2.0)

enum MealTag: String, Codable, CaseIterable {
    case protein = "Protein"
    case veg = "Vegetables"
    case hydration = "Hydration"
    case preworkout = "Pre-Workout"
    case postworkout = "Post-Workout"
    case balanced = "Balanced"
    case indulgence = "Indulgence"
    case snack = "Snack"

    var icon: String {
        switch self {
        case .protein: return "fish.fill"
        case .veg: return "leaf.fill"
        case .hydration: return "drop.fill"
        case .preworkout: return "bolt.fill"
        case .postworkout: return "arrow.clockwise"
        case .balanced: return "scale.3d"
        case .indulgence: return "birthday.cake.fill"
        case .snack: return "carrot.fill"
        }
    }

    var color: String {
        switch self {
        case .protein: return "red"
        case .veg: return "green"
        case .hydration: return "blue"
        case .preworkout: return "yellow"
        case .postworkout: return "orange"
        case .balanced: return "purple"
        case .indulgence: return "pink"
        case .snack: return "brown"
        }
    }
}

/// Meal type for nutrition logging
enum MealType: String, Codable, CaseIterable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snack = "Snack"
    case preworkout = "Pre-Workout"
    case postworkout = "Post-Workout"

    var icon: String {
        switch self {
        case .breakfast: return "sun.horizon.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.fill"
        case .snack: return "carrot.fill"
        case .preworkout: return "bolt.fill"
        case .postworkout: return "arrow.clockwise"
        }
    }
}

/// Sentiment bucket for workout emotions
enum EmotionSentiment: String, Codable {
    case positive
    case neutral
    case resilient
}

/// How the user felt during / after a workout
enum WorkoutEmotion: String, Codable, CaseIterable {
    case fired = "Fired Up"
    case strong = "Strong"
    case grateful = "Grateful"
    case calm = "Calm"
    case grinding = "Grinding"
    case dragging = "Dragging"
    case anxious = "Anxious"
    case comeback = "Comeback"

    var emoji: String {
        switch self {
        case .fired: return "🔥"
        case .strong: return "💪"
        case .grateful: return "🙏"
        case .calm: return "🧘"
        case .grinding: return "⚙️"
        case .dragging: return "🫠"
        case .anxious: return "😤"
        case .comeback: return "🔄"
        }
    }

    var color: Color {
        switch self {
        case .fired: return GQColors.coralRed
        case .strong: return GQColors.vividPurple
        case .grateful: return GQColors.electricGold
        case .calm: return GQColors.cyanSpark
        case .grinding: return GQColors.sunsetOrange
        case .dragging: return Color.gray
        case .anxious: return GQColors.deepBlue
        case .comeback: return GQColors.success
        }
    }

    var encouragement: String {
        switch self {
        case .fired: return "Let's go!"
        case .strong: return "Beast mode"
        case .grateful: return "Grateful gains"
        case .calm: return "Mind & muscle"
        case .grinding: return "One rep at a time"
        case .dragging: return "Showed up anyway"
        case .anxious: return "Stronger than the noise"
        case .comeback: return "Back in it"
        }
    }

    var sentimentCategory: EmotionSentiment {
        switch self {
        case .fired, .strong, .grateful, .calm: return .positive
        case .grinding: return .neutral
        case .dragging, .anxious, .comeback: return .resilient
        }
    }
}

/// How the user felt after a meal
enum MealFeeling: String, Codable, CaseIterable {
    case great = "Great"
    case good = "Good"
    case okay = "Okay"
    case sluggish = "Sluggish"
    case bad = "Bad"

    var emoji: String {
        switch self {
        case .great: return "🔥"
        case .good: return "😊"
        case .okay: return "😐"
        case .sluggish: return "😴"
        case .bad: return "😩"
        }
    }

    var color: Color {
        switch self {
        case .great: return .green
        case .good: return .blue
        case .okay: return .yellow
        case .sluggish: return .orange
        case .bad: return .red
        }
    }
}

/// Meal log entry (photo + tags + how you felt)
@Model
final class MealLog {
    var id: UUID
    var odId: UUID
    var dateTime: Date
    var mealType: MealType
    var mealDescription: String
    var photoMediaId: UUID?
    var photoData: Data?
    var tags: [String] // MealTag raw values
    var feeling: MealFeeling
    var notes: String?
    var energyLevel: Int? // 1-5
    var hungerLevel: Int? // 1-5
    var privacy: WorkoutPrivacy
    var estimatedCalories: Int?
    var estimatedProtein: Int?
    var estimatedCarbs: Int?
    var estimatedFat: Int?

    init(
        id: UUID = UUID(),
        odId: UUID = UUID(),
        dateTime: Date = Date(),
        mealType: MealType = .lunch,
        mealDescription: String = "",
        photoMediaId: UUID? = nil,
        photoData: Data? = nil,
        tags: [String] = [],
        feeling: MealFeeling = .good,
        notes: String? = nil,
        energyLevel: Int? = nil,
        hungerLevel: Int? = nil,
        privacy: WorkoutPrivacy = .privateOnly,
        estimatedCalories: Int? = nil,
        estimatedProtein: Int? = nil,
        estimatedCarbs: Int? = nil,
        estimatedFat: Int? = nil
    ) {
        self.id = id
        self.odId = odId
        self.dateTime = dateTime
        self.mealType = mealType
        self.mealDescription = mealDescription
        self.photoMediaId = photoMediaId
        self.photoData = photoData
        self.tags = tags
        self.feeling = feeling
        self.notes = notes
        self.energyLevel = energyLevel
        self.hungerLevel = hungerLevel
        self.privacy = privacy
        self.estimatedCalories = estimatedCalories
        self.estimatedProtein = estimatedProtein
        self.estimatedCarbs = estimatedCarbs
        self.estimatedFat = estimatedFat
    }

    var mealTags: [MealTag] {
        tags.compactMap { MealTag(rawValue: $0) }
    }
}

// MARK: - Food Nutrition Estimator

struct FoodNutritionEstimator {
    struct NutritionInfo {
        let calories: Int
        let protein: Int
        let carbs: Int
        let fat: Int
    }

    private static let foodDatabase: [String: NutritionInfo] = [
        // Proteins
        "egg": NutritionInfo(calories: 70, protein: 6, carbs: 1, fat: 5),
        "eggs": NutritionInfo(calories: 70, protein: 6, carbs: 1, fat: 5),
        "chicken": NutritionInfo(calories: 165, protein: 31, carbs: 0, fat: 4),
        "chicken breast": NutritionInfo(calories: 165, protein: 31, carbs: 0, fat: 4),
        "steak": NutritionInfo(calories: 270, protein: 26, carbs: 0, fat: 18),
        "beef": NutritionInfo(calories: 250, protein: 26, carbs: 0, fat: 15),
        "salmon": NutritionInfo(calories: 208, protein: 20, carbs: 0, fat: 13),
        "tuna": NutritionInfo(calories: 130, protein: 28, carbs: 0, fat: 1),
        "shrimp": NutritionInfo(calories: 100, protein: 20, carbs: 1, fat: 1),
        "tofu": NutritionInfo(calories: 80, protein: 8, carbs: 2, fat: 5),
        "turkey": NutritionInfo(calories: 170, protein: 30, carbs: 0, fat: 5),
        "bacon": NutritionInfo(calories: 120, protein: 9, carbs: 0, fat: 9),
        "protein shake": NutritionInfo(calories: 150, protein: 25, carbs: 8, fat: 2),
        "whey": NutritionInfo(calories: 120, protein: 24, carbs: 3, fat: 1),
        "greek yogurt": NutritionInfo(calories: 100, protein: 17, carbs: 6, fat: 1),
        "yogurt": NutritionInfo(calories: 100, protein: 10, carbs: 12, fat: 3),

        // Carbs
        "rice": NutritionInfo(calories: 200, protein: 4, carbs: 45, fat: 0),
        "bread": NutritionInfo(calories: 80, protein: 3, carbs: 15, fat: 1),
        "toast": NutritionInfo(calories: 80, protein: 3, carbs: 15, fat: 1),
        "pasta": NutritionInfo(calories: 220, protein: 8, carbs: 43, fat: 1),
        "oatmeal": NutritionInfo(calories: 150, protein: 5, carbs: 27, fat: 3),
        "oats": NutritionInfo(calories: 150, protein: 5, carbs: 27, fat: 3),
        "potato": NutritionInfo(calories: 160, protein: 4, carbs: 37, fat: 0),
        "sweet potato": NutritionInfo(calories: 110, protein: 2, carbs: 26, fat: 0),
        "banana": NutritionInfo(calories: 105, protein: 1, carbs: 27, fat: 0),
        "apple": NutritionInfo(calories: 95, protein: 0, carbs: 25, fat: 0),

        // Fats & Misc
        "avocado": NutritionInfo(calories: 240, protein: 3, carbs: 12, fat: 22),
        "peanut butter": NutritionInfo(calories: 190, protein: 7, carbs: 7, fat: 16),
        "cheese": NutritionInfo(calories: 110, protein: 7, carbs: 0, fat: 9),
        "butter": NutritionInfo(calories: 100, protein: 0, carbs: 0, fat: 11),
        "olive oil": NutritionInfo(calories: 120, protein: 0, carbs: 0, fat: 14),
        "nuts": NutritionInfo(calories: 170, protein: 5, carbs: 6, fat: 15),
        "almonds": NutritionInfo(calories: 165, protein: 6, carbs: 6, fat: 14),

        // Drinks
        "coffee": NutritionInfo(calories: 5, protein: 0, carbs: 0, fat: 0),
        "milk": NutritionInfo(calories: 120, protein: 8, carbs: 12, fat: 5),
        "juice": NutritionInfo(calories: 110, protein: 1, carbs: 26, fat: 0),
        "smoothie": NutritionInfo(calories: 200, protein: 8, carbs: 35, fat: 4),

        // Meals
        "salad": NutritionInfo(calories: 150, protein: 5, carbs: 12, fat: 8),
        "sandwich": NutritionInfo(calories: 350, protein: 18, carbs: 35, fat: 14),
        "burger": NutritionInfo(calories: 450, protein: 25, carbs: 35, fat: 22),
        "pizza": NutritionInfo(calories: 300, protein: 12, carbs: 36, fat: 12),
        "burrito": NutritionInfo(calories: 500, protein: 20, carbs: 55, fat: 20),
        "sushi": NutritionInfo(calories: 250, protein: 12, carbs: 35, fat: 6),
        "soup": NutritionInfo(calories: 150, protein: 8, carbs: 18, fat: 5),
        "wrap": NutritionInfo(calories: 350, protein: 18, carbs: 35, fat: 14),
    ]

    static func estimate(from text: String) -> NutritionInfo {
        let items = text.lowercased()
            .components(separatedBy: CharacterSet(charactersIn: ",;&+\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var totalCal = 0, totalProtein = 0, totalCarbs = 0, totalFat = 0

        for item in items {
            let (quantity, foodKey) = parseQuantity(from: item)

            if let info = matchFood(foodKey) {
                totalCal += info.calories * quantity
                totalProtein += info.protein * quantity
                totalCarbs += info.carbs * quantity
                totalFat += info.fat * quantity
            }
        }

        return NutritionInfo(calories: totalCal, protein: totalProtein, carbs: totalCarbs, fat: totalFat)
    }

    private static func parseQuantity(from text: String) -> (Int, String) {
        let words = text.split(separator: " ").map { String($0) }
        guard let first = words.first else { return (1, text) }

        if let num = Int(first) {
            let rest = words.dropFirst().joined(separator: " ")
            return (max(1, num), rest.isEmpty ? text : rest)
        }

        let wordNumbers = ["one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6]
        if let num = wordNumbers[first.lowercased()] {
            let rest = words.dropFirst().joined(separator: " ")
            return (num, rest.isEmpty ? text : rest)
        }

        return (1, text)
    }

    private static func matchFood(_ text: String) -> NutritionInfo? {
        let cleaned = text.trimmingCharacters(in: .whitespaces)

        // Exact match first
        if let info = foodDatabase[cleaned] { return info }

        // Try matching longest key first (e.g., "chicken breast" before "chicken")
        let sortedKeys = foodDatabase.keys.sorted { $0.count > $1.count }
        for key in sortedKeys {
            if cleaned.contains(key) {
                return foodDatabase[key]
            }
        }

        return nil
    }
}

// MARK: - Body Measurements (GymQuest 2.0)

enum MeasurementType: String, Codable, CaseIterable {
    case weight = "Weight"
    case bodyFat = "Body Fat %"
    case chest = "Chest"
    case waist = "Waist"
    case hips = "Hips"
    case bicepsLeft = "Biceps (L)"
    case bicepsRight = "Biceps (R)"
    case thighsLeft = "Thighs (L)"
    case thighsRight = "Thighs (R)"
    case calvesLeft = "Calves (L)"
    case calvesRight = "Calves (R)"
    case shoulders = "Shoulders"
    case neck = "Neck"

    var unit: String {
        switch self {
        case .weight: return "lbs"
        case .bodyFat: return "%"
        default: return "in"
        }
    }

    var icon: String {
        switch self {
        case .weight: return "scalemass"
        case .bodyFat: return "percent"
        case .chest: return "figure.arms.open"
        case .waist: return "circle.dashed"
        case .hips: return "figure.stand"
        case .bicepsLeft, .bicepsRight: return "figure.strengthtraining.traditional"
        case .thighsLeft, .thighsRight: return "figure.walk"
        case .calvesLeft, .calvesRight: return "figure.run"
        case .shoulders: return "figure.arms.open"
        case .neck: return "person.bust"
        }
    }
}

@Model
final class BodyMeasurement {
    var id: UUID
    var userId: UUID
    var type: MeasurementType
    var value: Double
    var date: Date
    var notes: String?
    var photoData: Data?

    init(
        id: UUID = UUID(),
        userId: UUID,
        type: MeasurementType,
        value: Double,
        date: Date = Date(),
        notes: String? = nil,
        photoData: Data? = nil
    ) {
        self.id = id
        self.userId = userId
        self.type = type
        self.value = value
        self.date = date
        self.notes = notes
        self.photoData = photoData
    }
}

// MARK: - Workout Templates (GymQuest 2.0)

/// Reusable workout template for quick logging
@Model
final class WorkoutTemplate {
    var id: UUID
    var odId: UUID // Creator
    var name: String
    var workoutType: WorkoutType
    var exerciseData: Data? // Encoded template exercises
    var estimatedDuration: Int // minutes
    var isPublic: Bool
    var useCount: Int
    var createdAt: Date
    var lastUsedAt: Date?

    init(
        id: UUID = UUID(),
        odId: UUID = UUID(),
        name: String = "",
        workoutType: WorkoutType = .push,
        exercises: [TemplateExercise] = [],
        estimatedDuration: Int = 60,
        isPublic: Bool = false,
        useCount: Int = 0,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.odId = odId
        self.name = name
        self.workoutType = workoutType
        self.exerciseData = try? JSONEncoder().encode(exercises)
        self.estimatedDuration = estimatedDuration
        self.isPublic = isPublic
        self.useCount = useCount
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }

    var exercises: [TemplateExercise] {
        get {
            guard let data = exerciseData else { return [] }
            return (try? JSONDecoder().decode([TemplateExercise].self, from: data)) ?? []
        }
        set {
            exerciseData = try? JSONEncoder().encode(newValue)
        }
    }
}

/// Exercise template with suggested sets/reps/weight
struct TemplateExercise: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var muscleGroup: String
    var suggestedSets: Int
    var suggestedReps: String // e.g., "8-12"
    var suggestedWeight: Double?
    var notes: String?
    var order: Int
}

// MARK: - Extended Post Model (GymQuest 2.0)

enum PostType: String, Codable, CaseIterable {
    case workoutCard = "Workout Card"
    case prClip = "PR Clip"
    case learningClip = "Learning"
    case recap = "Weekly Recap"
    case text = "Text"
    case photo = "Photo"
}

// MARK: - Weekly Recap (GymQuest 2.0)

/// Weekly recap summary for sharing
@Model
final class WeeklyRecap {
    var id: UUID
    var odId: UUID
    var weekStart: Date
    var weekEnd: Date
    var workoutCount: Int
    var totalSets: Int
    var totalVolume: Double
    var topExercise: String?
    var prCount: Int
    var streakDays: Int
    var xpEarned: Int
    var insightText: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        odId: UUID = UUID(),
        weekStart: Date = Date(),
        weekEnd: Date = Date(),
        workoutCount: Int = 0,
        totalSets: Int = 0,
        totalVolume: Double = 0,
        topExercise: String? = nil,
        prCount: Int = 0,
        streakDays: Int = 0,
        xpEarned: Int = 0,
        insightText: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.odId = odId
        self.weekStart = weekStart
        self.weekEnd = weekEnd
        self.workoutCount = workoutCount
        self.totalSets = totalSets
        self.totalVolume = totalVolume
        self.topExercise = topExercise
        self.prCount = prCount
        self.streakDays = streakDays
        self.xpEarned = xpEarned
        self.insightText = insightText
        self.createdAt = createdAt
    }
}

// MARK: - Analytics Events (GymQuest 2.0)

enum AnalyticsEventType: String, Codable {
    case workoutStarted = "workout_started"
    case setAdded = "set_added"
    case workoutCompleted = "workout_completed"
    case prDetected = "pr_detected"
    case workoutCardCreated = "workout_card_created"
    case shareExported = "share_exported"
    case squadCreated = "squad_created"
    case squadInviteSent = "squad_invite_sent"
    case questCompleted = "quest_completed"
    case learningItemViewed = "learning_item_viewed"
    case learningItemShared = "learning_item_shared"
    case healthkitImportSuccess = "healthkit_import_success"
    case stravaImportSuccess = "strava_import_success"
    case mealLogged = "meal_logged"
}

/// Local analytics event for tracking key metrics
@Model
final class AnalyticsEvent {
    var id: UUID
    var odId: UUID?
    var eventType: AnalyticsEventType
    var metadata: String? // JSON-encoded extra data
    var timestamp: Date

    init(
        id: UUID = UUID(),
        odId: UUID? = nil,
        eventType: AnalyticsEventType = .workoutStarted,
        metadata: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.odId = odId
        self.eventType = eventType
        self.metadata = metadata
        self.timestamp = timestamp
    }
}

// MARK: - User Profile Extensions (GymQuest 2.0)

extension UserProfile {
    /// Titles the user has unlocked
    var titlesUnlocked: [String] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "titles_\(id.uuidString)") else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "titles_\(id.uuidString)")
            }
        }
    }

    /// Squad IDs the user belongs to
    var squadIds: [UUID] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "squads_\(id.uuidString)") else { return [] }
            return (try? JSONDecoder().decode([UUID].self, from: data)) ?? []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "squads_\(id.uuidString)")
            }
        }
    }
}

// MARK: - Exercise Database

struct ExerciseDatabase {
    static let exercises: [String: MuscleGroup] = [
        // Chest
        "Bench Press": .chest,
        "Incline Bench Press": .chest,
        "Dumbbell Press": .chest,
        "Cable Fly": .chest,
        "Push-ups": .chest,
        "Dips (Chest)": .chest,
        // Back
        "Deadlift": .back,
        "Barbell Row": .back,
        "Pull-ups": .back,
        "Lat Pulldown": .back,
        "Seated Row": .back,
        "Face Pulls": .back,
        // Shoulders
        "Overhead Press": .shoulders,
        "Lateral Raises": .shoulders,
        "Front Raises": .shoulders,
        "Rear Delt Fly": .shoulders,
        "Arnold Press": .shoulders,
        // Arms
        "Bicep Curls": .biceps,
        "Hammer Curls": .biceps,
        "Tricep Pushdown": .triceps,
        "Skull Crushers": .triceps,
        "Tricep Dips": .triceps,
        // Legs
        "Squat": .quads,
        "Leg Press": .quads,
        "Romanian Deadlift": .hamstrings,
        "Leg Curl": .hamstrings,
        "Leg Extension": .quads,
        "Calf Raises": .calves,
        "Lunges": .quads,
        "Hip Thrust": .glutes,
        // Core
        "Plank": .core,
        "Crunches": .core,
        "Leg Raises": .core,
        "Russian Twists": .core,
        "Cable Crunch": .core,
        // Cardio
        "Running": .cardio,
        "Cycling": .cardio,
        "Rowing": .cardio,
        "Jump Rope": .cardio,
        "Stair Climber": .cardio
    ]

    static func exercisesByMuscle(_ muscle: MuscleGroup) -> [String] {
        exercises.filter { $0.value == muscle }.keys.sorted()
    }
}

// MARK: - Extended Exercise Metadata (GymQuest 2.0)

/// Rich exercise metadata for learning, demos, and robot generation
struct ExerciseMetadata: Codable, Identifiable {
    var id: UUID = UUID()
    let name: String
    let muscleGroup: MuscleGroup
    let category: ExerciseCategory
    let equipment: Equipment
    let difficulty: ExerciseDifficulty
    let primaryMuscles: [String]
    let secondaryMuscles: [String]
    let aliases: [String]
    let movementPattern: MovementPattern
    let cues: [String] // Form cues
    let commonMistakes: [String]
    let variations: [String]
}

/// Movement patterns for robot demo generation
enum MovementPattern: String, Codable, CaseIterable {
    case squat = "Squat"
    case hinge = "Hinge"
    case push = "Push"
    case pull = "Pull"
    case lunge = "Lunge"
    case curl = "Curl"
    case tricepsExtension = "Triceps Extension"
    case carry = "Carry"
    case rotation = "Rotation"
    case mobilityStretch = "Mobility Stretch"
    case plank = "Plank"
    case row = "Row"
    case press = "Press"

    var baseMotionId: String {
        rawValue.lowercased().replacingOccurrences(of: " ", with: "_")
    }
}

/// Extended exercise database with full metadata
struct ExtendedExerciseDatabase {
    static let exercises: [ExerciseMetadata] = [
        // CHEST - Push
        ExerciseMetadata(
            name: "Bench Press",
            muscleGroup: .chest,
            category: .push,
            equipment: .barbell,
            difficulty: .intermediate,
            primaryMuscles: ["Chest", "Pectoralis Major"],
            secondaryMuscles: ["Triceps", "Front Deltoids"],
            aliases: ["Flat Bench", "Barbell Bench"],
            movementPattern: .press,
            cues: ["Retract shoulder blades", "Arch upper back slightly", "Bar path: diagonal from chest to lockout"],
            commonMistakes: ["Flaring elbows too wide", "Bouncing off chest", "Lifting hips off bench"],
            variations: ["Close Grip", "Wide Grip", "Pause Reps"]
        ),
        ExerciseMetadata(
            name: "Incline Bench Press",
            muscleGroup: .chest,
            category: .push,
            equipment: .barbell,
            difficulty: .intermediate,
            primaryMuscles: ["Upper Chest", "Clavicular Pectoralis"],
            secondaryMuscles: ["Front Deltoids", "Triceps"],
            aliases: ["Incline Barbell Press", "Incline Press"],
            movementPattern: .press,
            cues: ["Set bench to 30-45 degrees", "Touch bar to upper chest", "Keep wrists stacked over elbows"],
            commonMistakes: ["Bench angle too steep", "Pressing too high on chest", "Excessive arch"],
            variations: ["Dumbbell Incline", "Smith Machine Incline"]
        ),
        ExerciseMetadata(
            name: "Dumbbell Press",
            muscleGroup: .chest,
            category: .push,
            equipment: .dumbbell,
            difficulty: .beginner,
            primaryMuscles: ["Chest", "Pectoralis Major"],
            secondaryMuscles: ["Triceps", "Front Deltoids"],
            aliases: ["DB Press", "Flat Dumbbell Press", "Dumbbell Bench Press"],
            movementPattern: .press,
            cues: ["Control the descent", "Squeeze at the top", "Keep dumbbells from drifting outward"],
            commonMistakes: ["Going too heavy too soon", "Not controlling the negative", "Inconsistent range of motion"],
            variations: ["Neutral Grip", "Single Arm", "Alternating"]
        ),
        ExerciseMetadata(
            name: "Push-ups",
            muscleGroup: .chest,
            category: .push,
            equipment: .bodyweight,
            difficulty: .beginner,
            primaryMuscles: ["Chest", "Pectoralis Major"],
            secondaryMuscles: ["Triceps", "Core", "Front Deltoids"],
            aliases: ["Pushups", "Press-ups"],
            movementPattern: .push,
            cues: ["Hands slightly wider than shoulders", "Body in straight line", "Chest to floor each rep"],
            commonMistakes: ["Hips sagging", "Incomplete range of motion", "Flaring elbows 90 degrees"],
            variations: ["Incline", "Decline", "Diamond", "Wide"]
        ),
        ExerciseMetadata(
            name: "Cable Fly",
            muscleGroup: .chest,
            category: .isolation,
            equipment: .cable,
            difficulty: .beginner,
            primaryMuscles: ["Chest", "Pectoralis Major"],
            secondaryMuscles: ["Front Deltoids"],
            aliases: ["Cable Crossover", "Cable Chest Fly"],
            movementPattern: .push,
            cues: ["Slight bend in elbows", "Squeeze chest at the center", "Control the stretch"],
            commonMistakes: ["Using too much weight", "Bending elbows too much", "Rushing the movement"],
            variations: ["High to Low", "Low to High", "Single Arm"]
        ),

        // BACK - Pull
        ExerciseMetadata(
            name: "Deadlift",
            muscleGroup: .back,
            category: .compound,
            equipment: .barbell,
            difficulty: .advanced,
            primaryMuscles: ["Erector Spinae", "Glutes", "Hamstrings"],
            secondaryMuscles: ["Traps", "Lats", "Forearms", "Core"],
            aliases: ["Conventional Deadlift", "Barbell Deadlift"],
            movementPattern: .hinge,
            cues: ["Bar over mid-foot", "Brace core hard", "Push floor away, don't pull up"],
            commonMistakes: ["Rounding lower back", "Bar drifting forward", "Hyperextending at top"],
            variations: ["Sumo", "Romanian", "Trap Bar", "Deficit"]
        ),
        ExerciseMetadata(
            name: "Barbell Row",
            muscleGroup: .back,
            category: .pull,
            equipment: .barbell,
            difficulty: .intermediate,
            primaryMuscles: ["Lats", "Rhomboids", "Rear Deltoids"],
            secondaryMuscles: ["Biceps", "Erector Spinae", "Core"],
            aliases: ["Bent Over Row", "BB Row", "Pendlay Row"],
            movementPattern: .row,
            cues: ["Hinge at hips ~45 degrees", "Pull to lower chest/upper abs", "Squeeze shoulder blades"],
            commonMistakes: ["Using momentum", "Standing too upright", "Rounding back"],
            variations: ["Underhand Grip", "Pendlay", "Yates Row"]
        ),
        ExerciseMetadata(
            name: "Pull-ups",
            muscleGroup: .back,
            category: .pull,
            equipment: .bodyweight,
            difficulty: .intermediate,
            primaryMuscles: ["Lats", "Biceps"],
            secondaryMuscles: ["Rear Deltoids", "Rhomboids", "Core"],
            aliases: ["Pullups", "Chin-ups"],
            movementPattern: .pull,
            cues: ["Start from dead hang", "Pull elbows down and back", "Chin over bar"],
            commonMistakes: ["Kipping", "Incomplete range of motion", "Not fully extending at bottom"],
            variations: ["Wide Grip", "Chin-up", "Neutral Grip", "Weighted"]
        ),
        ExerciseMetadata(
            name: "Lat Pulldown",
            muscleGroup: .back,
            category: .pull,
            equipment: .cable,
            difficulty: .beginner,
            primaryMuscles: ["Lats"],
            secondaryMuscles: ["Biceps", "Rear Deltoids", "Rhomboids"],
            aliases: ["Cable Pulldown", "Wide Grip Pulldown"],
            movementPattern: .pull,
            cues: ["Lean back slightly", "Pull bar to upper chest", "Squeeze lats at bottom"],
            commonMistakes: ["Leaning back too far", "Using momentum", "Pulling behind neck"],
            variations: ["Close Grip", "Underhand", "Single Arm"]
        ),

        // LEGS - Squat/Hinge/Lunge
        ExerciseMetadata(
            name: "Squat",
            muscleGroup: .quads,
            category: .compound,
            equipment: .barbell,
            difficulty: .intermediate,
            primaryMuscles: ["Quads", "Glutes"],
            secondaryMuscles: ["Hamstrings", "Core", "Erector Spinae"],
            aliases: ["Back Squat", "Barbell Squat", "High Bar Squat"],
            movementPattern: .squat,
            cues: ["Brace core before descent", "Knees track over toes", "Depth: hip crease below knee"],
            commonMistakes: ["Knees caving inward", "Forward lean", "Rising on toes"],
            variations: ["Front Squat", "Low Bar", "Pause Squat", "Box Squat"]
        ),
        ExerciseMetadata(
            name: "Leg Press",
            muscleGroup: .quads,
            category: .compound,
            equipment: .machine,
            difficulty: .beginner,
            primaryMuscles: ["Quads", "Glutes"],
            secondaryMuscles: ["Hamstrings"],
            aliases: ["45 Degree Leg Press", "Sled Leg Press"],
            movementPattern: .squat,
            cues: ["Feet shoulder width apart", "Lower until 90 degrees", "Don't lock knees at top"],
            commonMistakes: ["Letting lower back round", "Partial reps", "Locking knees"],
            variations: ["Single Leg", "High Foot", "Low Foot", "Wide Stance"]
        ),
        ExerciseMetadata(
            name: "Romanian Deadlift",
            muscleGroup: .hamstrings,
            category: .compound,
            equipment: .barbell,
            difficulty: .intermediate,
            primaryMuscles: ["Hamstrings", "Glutes"],
            secondaryMuscles: ["Erector Spinae", "Core"],
            aliases: ["RDL", "Stiff Leg Deadlift"],
            movementPattern: .hinge,
            cues: ["Soft knee bend", "Push hips back", "Bar stays close to legs"],
            commonMistakes: ["Rounding back", "Going too low", "Bending knees too much"],
            variations: ["Single Leg", "Dumbbell", "Deficit"]
        ),
        ExerciseMetadata(
            name: "Lunges",
            muscleGroup: .quads,
            category: .compound,
            equipment: .bodyweight,
            difficulty: .beginner,
            primaryMuscles: ["Quads", "Glutes"],
            secondaryMuscles: ["Hamstrings", "Core"],
            aliases: ["Walking Lunges", "Forward Lunges"],
            movementPattern: .lunge,
            cues: ["Step far enough forward", "Back knee almost touches ground", "Torso stays upright"],
            commonMistakes: ["Knee going past toes", "Leaning forward", "Short steps"],
            variations: ["Reverse", "Walking", "Deficit", "Bulgarian Split Squat"]
        ),
        ExerciseMetadata(
            name: "Hip Thrust",
            muscleGroup: .glutes,
            category: .compound,
            equipment: .barbell,
            difficulty: .intermediate,
            primaryMuscles: ["Glutes"],
            secondaryMuscles: ["Hamstrings", "Core"],
            aliases: ["Barbell Hip Thrust", "Glute Bridge"],
            movementPattern: .hinge,
            cues: ["Upper back on bench", "Drive through heels", "Squeeze glutes at top"],
            commonMistakes: ["Hyperextending lower back", "Not reaching full extension", "Bar placement too high"],
            variations: ["Single Leg", "Banded", "Dumbbell"]
        ),

        // SHOULDERS - Press/Raise
        ExerciseMetadata(
            name: "Overhead Press",
            muscleGroup: .shoulders,
            category: .push,
            equipment: .barbell,
            difficulty: .intermediate,
            primaryMuscles: ["Front Deltoids", "Lateral Deltoids"],
            secondaryMuscles: ["Triceps", "Upper Chest", "Core"],
            aliases: ["Military Press", "OHP", "Standing Press"],
            movementPattern: .press,
            cues: ["Bar starts at shoulders", "Press straight up", "Lock out overhead"],
            commonMistakes: ["Excessive back arch", "Pressing forward", "Not locking out"],
            variations: ["Seated", "Push Press", "Behind Neck", "Dumbbell"]
        ),
        ExerciseMetadata(
            name: "Lateral Raises",
            muscleGroup: .shoulders,
            category: .isolation,
            equipment: .dumbbell,
            difficulty: .beginner,
            primaryMuscles: ["Lateral Deltoids"],
            secondaryMuscles: ["Front Deltoids", "Traps"],
            aliases: ["Side Raises", "Lateral Dumbbell Raises"],
            movementPattern: .push,
            cues: ["Slight bend in elbows", "Lead with elbows", "Raise to shoulder height"],
            commonMistakes: ["Using too much weight", "Swinging", "Shrugging traps"],
            variations: ["Cable", "Incline", "Leaning"]
        ),

        // ARMS - Curl/Extension
        ExerciseMetadata(
            name: "Bicep Curls",
            muscleGroup: .biceps,
            category: .isolation,
            equipment: .dumbbell,
            difficulty: .beginner,
            primaryMuscles: ["Biceps"],
            secondaryMuscles: ["Forearms"],
            aliases: ["Dumbbell Curls", "DB Curls", "Standing Curls"],
            movementPattern: .curl,
            cues: ["Keep elbows pinned", "Full range of motion", "Control the negative"],
            commonMistakes: ["Swinging body", "Moving elbows forward", "Partial reps"],
            variations: ["Hammer", "Incline", "Concentration", "Preacher"]
        ),
        ExerciseMetadata(
            name: "Tricep Pushdown",
            muscleGroup: .triceps,
            category: .isolation,
            equipment: .cable,
            difficulty: .beginner,
            primaryMuscles: ["Triceps"],
            secondaryMuscles: [],
            aliases: ["Cable Pushdown", "Tricep Pressdown", "Rope Pushdown"],
            movementPattern: .tricepsExtension,
            cues: ["Elbows stay at sides", "Full extension at bottom", "Squeeze triceps"],
            commonMistakes: ["Moving elbows", "Leaning forward too much", "Not fully extending"],
            variations: ["Rope", "V-Bar", "Straight Bar", "Single Arm"]
        ),
        ExerciseMetadata(
            name: "Skull Crushers",
            muscleGroup: .triceps,
            category: .isolation,
            equipment: .barbell,
            difficulty: .intermediate,
            primaryMuscles: ["Triceps"],
            secondaryMuscles: [],
            aliases: ["Lying Tricep Extension", "French Press", "Nose Breakers"],
            movementPattern: .tricepsExtension,
            cues: ["Lower bar to forehead/behind head", "Keep elbows pointed up", "Extend fully"],
            commonMistakes: ["Flaring elbows", "Moving upper arms", "Using too much weight"],
            variations: ["EZ Bar", "Dumbbell", "Incline", "Behind Head"]
        ),

        // CORE
        ExerciseMetadata(
            name: "Plank",
            muscleGroup: .core,
            category: .core,
            equipment: .bodyweight,
            difficulty: .beginner,
            primaryMuscles: ["Rectus Abdominis", "Transverse Abdominis"],
            secondaryMuscles: ["Obliques", "Glutes", "Shoulders"],
            aliases: ["Front Plank", "Forearm Plank"],
            movementPattern: .plank,
            cues: ["Straight line from head to heels", "Squeeze glutes", "Don't let hips sag"],
            commonMistakes: ["Hips too high", "Hips sagging", "Looking up"],
            variations: ["Side Plank", "Weighted", "RKC Plank"]
        ),
        ExerciseMetadata(
            name: "Leg Raises",
            muscleGroup: .core,
            category: .core,
            equipment: .bodyweight,
            difficulty: .intermediate,
            primaryMuscles: ["Lower Abs", "Hip Flexors"],
            secondaryMuscles: ["Obliques"],
            aliases: ["Lying Leg Raises", "Hanging Leg Raises"],
            movementPattern: .plank,
            cues: ["Keep lower back pressed down", "Control the descent", "Don't swing"],
            commonMistakes: ["Using momentum", "Arching lower back", "Bending knees too much"],
            variations: ["Hanging", "Captain's Chair", "Weighted"]
        )
    ]

    /// Find exercise by name (case-insensitive, checks aliases)
    static func find(_ name: String) -> ExerciseMetadata? {
        let lowercaseName = name.lowercased()
        return exercises.first { metadata in
            metadata.name.lowercased() == lowercaseName ||
            metadata.aliases.contains { $0.lowercased() == lowercaseName }
        }
    }

    /// Find exercises by muscle group
    static func byMuscleGroup(_ group: MuscleGroup) -> [ExerciseMetadata] {
        exercises.filter { $0.muscleGroup == group }
    }

    /// Find exercises by movement pattern (for robot demos)
    static func byMovementPattern(_ pattern: MovementPattern) -> [ExerciseMetadata] {
        exercises.filter { $0.movementPattern == pattern }
    }

    /// Find exercises by equipment
    static func byEquipment(_ equipment: Equipment) -> [ExerciseMetadata] {
        exercises.filter { $0.equipment == equipment }
    }

    /// Search exercises by query (name, aliases, muscles)
    static func search(_ query: String) -> [ExerciseMetadata] {
        let lowercaseQuery = query.lowercased()
        return exercises.filter { metadata in
            metadata.name.lowercased().contains(lowercaseQuery) ||
            metadata.aliases.contains { $0.lowercased().contains(lowercaseQuery) } ||
            metadata.primaryMuscles.contains { $0.lowercased().contains(lowercaseQuery) }
        }
    }
}
