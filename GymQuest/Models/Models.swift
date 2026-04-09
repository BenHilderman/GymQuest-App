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
import CoreLocation

// MARK: - Route Point (GPS tracking for cardio workouts)

struct RoutePoint: Codable {
    let latitude: Double
    let longitude: Double
    let altitude: Double?
    let timestamp: TimeInterval // seconds since workout start
    let speed: Double?          // m/s from CLLocation
    let horizontalAccuracy: Double?
}

// MARK: - Run Analysis Types

struct KilometerSplit: Identifiable {
    let id: Int // 1-based km number
    let distanceMeters: Double
    let durationSeconds: Double
    let elevationChange: Double // meters, positive = uphill
    var paceSecondsPerKm: Double {
        guard distanceMeters > 0 else { return 0 }
        return durationSeconds / (distanceMeters / 1000.0)
    }
    var paceString: String {
        let total = Int(paceSecondsPerKm)
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }
}

enum PaceCategory {
    case fast, medium, slow

    var color: Color {
        switch self {
        case .fast: return GQColors.success
        case .medium: return GQColors.warning
        case .slow: return GQColors.textSecondary
        }
    }
}

struct PaceSegment: Identifiable {
    let id = UUID()
    let points: [RoutePoint]
    let paceSecondsPerKm: Double
    let paceCategory: PaceCategory
}

struct ElevationPoint: Identifiable {
    let id = UUID()
    let distanceKm: Double
    let altitude: Double
}

// MARK: - Run Analysis Computation

enum RunAnalysis {
    static func computeSplits(from points: [RoutePoint]) -> [KilometerSplit] {
        guard points.count >= 2 else { return [] }
        var splits: [KilometerSplit] = []
        var splitStart = 0
        var cumulativeDistance: Double = 0
        var splitDistance: Double = 0

        for i in 1..<points.count {
            let prev = CLLocation(latitude: points[i-1].latitude, longitude: points[i-1].longitude)
            let curr = CLLocation(latitude: points[i].latitude, longitude: points[i].longitude)
            let seg = curr.distance(from: prev)
            cumulativeDistance += seg
            splitDistance += seg

            if splitDistance >= 1000 {
                let duration = points[i].timestamp - points[splitStart].timestamp
                let elevChange = (points[i].altitude ?? 0) - (points[splitStart].altitude ?? 0)
                splits.append(KilometerSplit(
                    id: splits.count + 1,
                    distanceMeters: splitDistance,
                    durationSeconds: duration,
                    elevationChange: elevChange
                ))
                splitStart = i
                splitDistance = 0
            }
        }

        // Final partial split if > 200m
        if splitDistance > 200 {
            let duration = points.last!.timestamp - points[splitStart].timestamp
            let elevChange = (points.last!.altitude ?? 0) - (points[splitStart].altitude ?? 0)
            splits.append(KilometerSplit(
                id: splits.count + 1,
                distanceMeters: splitDistance,
                durationSeconds: duration,
                elevationChange: elevChange
            ))
        }

        return splits
    }

    static func computePaceSegments(from points: [RoutePoint], averagePace: Double) -> [PaceSegment] {
        guard points.count >= 2, averagePace > 0 else { return [] }
        let fastThreshold = averagePace * 0.92
        let slowThreshold = averagePace * 1.08

        func category(for pace: Double) -> PaceCategory {
            if pace < fastThreshold { return .fast }
            if pace > slowThreshold { return .slow }
            return .medium
        }

        var segments: [PaceSegment] = []
        var currentPoints: [RoutePoint] = [points[0]]
        var currentCategory: PaceCategory = .medium

        for i in 1..<points.count {
            let prev = CLLocation(latitude: points[i-1].latitude, longitude: points[i-1].longitude)
            let curr = CLLocation(latitude: points[i].latitude, longitude: points[i].longitude)
            let dist = curr.distance(from: prev)
            let time = points[i].timestamp - points[i-1].timestamp

            guard dist > 0, time > 0 else {
                currentPoints.append(points[i])
                continue
            }

            let segPace = time / (dist / 1000.0)
            let cat = category(for: segPace)

            if cat != currentCategory && currentPoints.count > 1 {
                segments.append(PaceSegment(
                    points: currentPoints,
                    paceSecondsPerKm: averagePace,
                    paceCategory: currentCategory
                ))
                currentPoints = [points[i-1]] // overlap for continuity
                currentCategory = cat
            }
            currentPoints.append(points[i])
        }

        if currentPoints.count > 1 {
            segments.append(PaceSegment(
                points: currentPoints,
                paceSecondsPerKm: averagePace,
                paceCategory: currentCategory
            ))
        }

        return segments
    }

    static func computeElevationProfile(from points: [RoutePoint]) -> [ElevationPoint] {
        guard points.count >= 2 else { return [] }
        var profile: [ElevationPoint] = []
        var cumDistance: Double = 0

        for i in 0..<points.count {
            if i > 0 {
                let prev = CLLocation(latitude: points[i-1].latitude, longitude: points[i-1].longitude)
                let curr = CLLocation(latitude: points[i].latitude, longitude: points[i].longitude)
                cumDistance += curr.distance(from: prev)
            }
            if let alt = points[i].altitude {
                profile.append(ElevationPoint(distanceKm: cumDistance / 1000.0, altitude: alt))
            }
        }

        return profile
    }

    static func computeElevationGain(from points: [RoutePoint]) -> Double {
        var gain: Double = 0
        var lastAlt: Double?
        for point in points {
            guard let alt = point.altitude else { continue }
            if let prev = lastAlt {
                let delta = alt - prev
                if delta > 0.5 { gain += delta }
            }
            lastAlt = alt
        }
        return gain
    }
}

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
    var routePoints: [RoutePoint]?

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

    init(id: UUID = UUID(), title: String = "", workoutType: String = "", estimatedDuration: Int = 0, exercises: [SharedExercise] = [], authorName: String = "", authorUsername: String = "", notes: String? = nil, routePoints: [RoutePoint]? = nil) {
        self.id = id
        self.title = title
        self.workoutType = workoutType
        self.estimatedDuration = estimatedDuration
        self.exercises = exercises
        self.authorName = authorName
        self.authorUsername = authorUsername
        self.notes = notes
        self.routePoints = routePoints
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
            notes: workout.notes.isEmpty ? nil : workout.notes,
            routePoints: workout.routePoints.isEmpty ? nil : workout.routePoints
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

// MARK: - Feed PR Data (lightweight, for feed display)

struct FeedPR: Codable, Identifiable {
    var id: UUID = UUID()
    var exerciseName: String
    var value: String           // e.g., "205 lbs" or "345×3"
    var previousValue: String?  // e.g., "185 lbs"
    var improvement: String?    // e.g., "+20 lbs"
    var prType: String          // "Weight PR", "Rep PR", "Volume PR"
}

// MARK: - Post Challenge Data (lightweight, for feed display)

struct PostChallengeData: Codable {
    var challengeId: UUID
    var title: String
    var goalType: String       // ChallengeGoalType rawValue
    var goalTarget: Int
    var endDate: Date
    var participantCount: Int  // snapshot, updated on join
}

// MARK: - Post Widget (interactive data card)

enum PostWidgetType: String, Codable, CaseIterable {
    case goal       // Goal progress ring
    case pr         // PR celebration
    case macros     // Today's macros donut
    case body       // Body weight + sparkline
    case streak     // Streak/milestone
    case cardio     // Run/cardio stats

    var icon: String {
        switch self {
        case .goal: return "target"
        case .pr: return "trophy.fill"
        case .macros: return "chart.pie.fill"
        case .body: return "figure.stand"
        case .streak: return "flame.fill"
        case .cardio: return "figure.run"
        }
    }

    var label: String {
        switch self {
        case .goal: return "Goal"
        case .pr: return "PR"
        case .macros: return "Macros"
        case .body: return "Weight"
        case .streak: return "Streak"
        case .cardio: return "Cardio"
        }
    }
}

struct PostWidget: Codable {
    let type: PostWidgetType
    // Goal
    var goalExercise: String?
    var goalTarget: Double?
    var goalCurrent: Double?
    var goalUnit: String?
    // PR
    var prExercise: String?
    var prValue: String?
    var prPrevious: String?
    var prImprovement: String?
    var prType: String?
    // Macros
    var calories: Int?
    var protein: Int?
    var carbs: Int?
    var fat: Int?
    // Body
    var bodyWeight: Double?
    var bodyChange: Double?
    var bodyHistory: [Double]?
    // Streak
    var streakDays: Int?
    var milestoneCount: Int?
    var milestoneLabel: String?
    // Cardio
    var distance: Double?
    var pace: String?
    var elevation: Double?
}

// MARK: - Feed Motivation Types

enum MotivationType: String, CaseIterable {
    case streak
    case comeback
    case milestone
    case general

    var icon: String {
        switch self {
        case .streak: return "flame.fill"
        case .comeback: return "arrow.counterclockwise"
        case .milestone: return "star.fill"
        case .general: return "quote.opening"
        }
    }

    var accentColor: Color {
        switch self {
        case .streak: return GQColors.success
        case .comeback: return Color(hex: "FF8C42")
        case .milestone: return GQColors.textSecondary
        case .general: return GQColors.primary
        }
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
    case hiit = "HIIT"
    case plyometric = "Plyometric"
    case olympic = "Olympic"
    case calisthenics = "Calisthenics"
    case yoga = "Yoga"
    case martialArts = "Martial Arts"
    case sport = "Sport"
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
    case foamRoller = "Foam Roller"
    case medicineBall = "Medicine Ball"
    case box = "Box"
    case heavyBag = "Heavy Bag"
    case swimGear = "Swim Gear"
    case treadmill = "Treadmill"
    case bike = "Bike"
    case rower = "Rower"
    case jumpRope = "Jump Rope"
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
        case .foamRoller: return "cylinder.fill"
        case .medicineBall: return "circle.fill"
        case .box: return "square.fill"
        case .heavyBag: return "figure.boxing"
        case .swimGear: return "figure.pool.swim"
        case .treadmill: return "figure.run"
        case .bike: return "bicycle"
        case .rower: return "figure.rower"
        case .jumpRope: return "figure.jumprope"
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

    // GPS route tracking for cardio workouts
    var routeData: Data?        // JSON-encoded [RoutePoint]
    var totalDistance: Double?   // meters
    var averagePace: Double?    // seconds per kilometer
    var elevationGain: Double?  // meters

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
        isFavorite: Bool = false,
        routeData: Data? = nil,
        totalDistance: Double? = nil,
        averagePace: Double? = nil,
        elevationGain: Double? = nil
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
        self.routeData = routeData
        self.totalDistance = totalDistance
        self.averagePace = averagePace
        self.elevationGain = elevationGain
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

    /// Decoded route points from GPS tracking
    var routePoints: [RoutePoint] {
        get {
            guard let data = routeData else { return [] }
            return (try? JSONDecoder().decode([RoutePoint].self, from: data)) ?? []
        }
        set { routeData = try? JSONEncoder().encode(newValue) }
    }

    /// Whether this workout has a valid GPS route
    var hasRoute: Bool { routeData != nil && (totalDistance ?? 0) > 0 }
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
    case glutes = "Glutes"
    case abs = "Abs"
    case hiit = "HIIT"
    case yoga = "Yoga"
    case custom = "Custom"

    var icon: String {
        switch self {
        case .push: return "figure.martial.arts"
        case .pull: return "figure.rower"
        case .legs: return "figure.walk"
        case .upper: return "figure.boxing"
        case .lower: return "figure.cross.training"
        case .fullBody: return "figure.strengthtraining.traditional"
        case .cardio: return "figure.run"
        case .rest: return "figure.cooldown"
        case .glutes: return "figure.flexibility"
        case .abs: return "figure.core.training"
        case .hiit: return "figure.highintensity.intervaltraining"
        case .yoga: return "figure.yoga"
        case .custom: return "plus.circle.fill"
        }
    }

    var color: Color {
        return Color(red: 0.0, green: 0.9, blue: 0.9) // Cyan accent
    }

    var isGPSEligible: Bool {
        switch self {
        case .cardio, .hiit: return true
        default: return false
        }
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = raw == "Other" ? .custom : (WorkoutType(rawValue: raw) ?? .custom)
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
    case fullBody = "Full Body"
    case flexibility = "Flexibility"

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
        case .fullBody: return "cyan"
        case .flexibility: return "blue"
        }
    }

    var optimalWeeklySets: Int {
        switch self {
        case .chest: return 12
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
        case .fullBody: return 0
        case .flexibility: return 0
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
    var supabaseId: UUID?

    // Fitness profile fields
    var genderRaw: String?
    var heightCm: Double?
    var weightKg: Double?
    var weightUnitRaw: String = WeightUnit.lbs.rawValue
    var heightUnitRaw: String = HeightUnit.ftIn.rawValue
    var distanceUnitRaw: String = DistanceUnit.km.rawValue
    var workoutEnvironmentRaw: String?
    var experienceLevelRaw: String?
    var availableEquipmentJSON: String = "[]"
    var fitnessProfileCompleted: Bool = false
    var isPremium: Bool = false
    var freeTrialWorkoutsRemaining: Int = 3
    var lastPaywallShownDate: Date?
    var paywallDismissCount: Int = 0
    var preferredWorkoutDuration: Int = 60
    var gymName: String = ""
    var subscriptionExpiryDate: Date?

    // Nutrition & body goals
    var dailyCalorieGoal: Int = 2000
    var proteinGoalGrams: Int = 150
    var carbsGoalGrams: Int = 250
    var fatGoalGrams: Int = 65
    var goalWeight: Double?

    // Privacy & social counts
    var isProfilePublic: Bool = true
    var followerCount: Int = 0
    var followingCount: Int = 0

    // Referral system
    var referralCode: String = ""
    var referredByCode: String = ""
    var referralCount: Int = 0

    static func generateReferralCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in chars.randomElement()! })
    }

    // Social hero widget grid config (JSON-encoded WidgetGridConfig)
    var widgetConfigJSON: String = WidgetGridConfig.defaultJSON

    // Computed wrappers for raw-stored enums
    var gender: Gender? {
        get { genderRaw.flatMap { Gender(rawValue: $0) } }
        set { genderRaw = newValue?.rawValue }
    }

    var weightUnit: WeightUnit {
        get { WeightUnit(rawValue: weightUnitRaw) ?? .lbs }
        set { weightUnitRaw = newValue.rawValue }
    }

    var heightUnit: HeightUnit {
        get { HeightUnit(rawValue: heightUnitRaw) ?? .ftIn }
        set { heightUnitRaw = newValue.rawValue }
    }

    var distanceUnit: DistanceUnit {
        get { DistanceUnit(rawValue: distanceUnitRaw) ?? .km }
        set { distanceUnitRaw = newValue.rawValue }
    }

    var workoutEnvironment: WorkoutEnvironment? {
        get { workoutEnvironmentRaw.flatMap { WorkoutEnvironment(rawValue: $0) } }
        set { workoutEnvironmentRaw = newValue?.rawValue }
    }

    var experienceLevel: ExperienceLevel? {
        get { experienceLevelRaw.flatMap { ExperienceLevel(rawValue: $0) } }
        set { experienceLevelRaw = newValue?.rawValue }
    }

    var widgetGridConfig: WidgetGridConfig {
        get { WidgetGridConfig.from(json: widgetConfigJSON) }
        set { widgetConfigJSON = newValue.toJSON() }
    }

    var availableEquipment: [EquipmentType] {
        get {
            guard let data = availableEquipmentJSON.data(using: .utf8),
                  let raw = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return raw.compactMap { EquipmentType(rawValue: $0) }
        }
        set {
            let raw = newValue.map { $0.rawValue }
            if let data = try? JSONEncoder().encode(raw),
               let str = String(data: data, encoding: .utf8) {
                availableEquipmentJSON = str
            }
        }
    }

    // MARK: - Unit Conversion Helpers

    static func lbsToKg(_ lbs: Double) -> Double { lbs * 0.453592 }
    static func kgToLbs(_ kg: Double) -> Double { kg / 0.453592 }
    static func ftInToCm(feet: Int, inches: Int) -> Double { Double(feet * 12 + inches) * 2.54 }
    static func cmToFtIn(_ cm: Double) -> (feet: Int, inches: Int) {
        let totalInches = Int(cm / 2.54)
        return (totalInches / 12, totalInches % 12)
    }

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
        dateOfBirth: Date? = nil,
        supabaseId: UUID? = nil
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
        self.supabaseId = supabaseId
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

enum SocialWidgetType: String, Codable, CaseIterable {
    case workouts = "workouts"
    case calories = "calories"
    case steps = "steps"
    case macros = "macros"
    case activeCalories = "activeCalories"
    case sleep = "sleep"
    case streak = "streak"
    case heartRate = "heartRate"
    case recovery = "recovery"
    case none = "none"

    var displayName: String {
        switch self {
        case .workouts: "Workouts"
        case .calories: "Calories"
        case .steps: "Steps"
        case .macros: "Macros"
        case .activeCalories: "Active Calories"
        case .sleep: "Sleep"
        case .streak: "Streak"
        case .heartRate: "Heart Rate"
        case .recovery: "Recovery"
        case .none: "None"
        }
    }

    var subtitle: String {
        switch self {
        case .workouts: "Weekly workout count vs goal"
        case .calories: "Today's calories vs daily goal"
        case .steps: "Steps today from HealthKit"
        case .macros: "Protein, carbs & fat breakdown"
        case .activeCalories: "Calories burned today"
        case .sleep: "Last night's sleep duration"
        case .streak: "Consecutive workout days"
        case .heartRate: "Resting heart rate"
        case .recovery: "Recovery readiness score"
        case .none: "Hide the hero widget"
        }
    }

    var iconName: String {
        switch self {
        case .workouts: "dumbbell.fill"
        case .calories: "flame.fill"
        case .steps: "figure.walk"
        case .macros: "chart.bar.fill"
        case .activeCalories: "bolt.heart.fill"
        case .sleep: "moon.fill"
        case .streak: "trophy.fill"
        case .heartRate: "heart.fill"
        case .recovery: "battery.100.bolt"
        case .none: "eye.slash"
        }
    }

    var accentColor: Color {
        GQColors.textSecondary
    }

    /// All selectable types (excludes .none)
    static var selectableTypes: [SocialWidgetType] {
        allCases.filter { $0 != .none }
    }
}

enum WidgetLayout: String, Codable, CaseIterable {
    case single   // 1 full-width
    case double   // 2 half-width side-by-side
    case triple   // 3 third-width side-by-side

    var slotCount: Int {
        switch self {
        case .single: 1
        case .double: 2
        case .triple: 3
        }
    }
}

struct WidgetGridConfig: Codable {
    var layout: WidgetLayout = .single
    var slots: [SocialWidgetType] = [.workouts]

    static let defaultJSON: String = {
        let config = WidgetGridConfig()
        return config.toJSON()
    }()

    static func from(json: String) -> WidgetGridConfig {
        guard let data = json.data(using: .utf8),
              let config = try? JSONDecoder().decode(WidgetGridConfig.self, from: data) else {
            return WidgetGridConfig()
        }
        return config
    }

    func toJSON() -> String {
        guard let data = try? JSONEncoder().encode(self),
              let str = String(data: data, encoding: .utf8) else {
            return WidgetGridConfig.defaultJSON
        }
        return str
    }

    /// Adjust slot count to match layout, padding with unique types or trimming from end
    mutating func adjustSlots() {
        let needed = layout.slotCount
        if slots.count < needed {
            let usedTypes = Set(slots.filter { $0 != .none })
            let available = SocialWidgetType.selectableTypes.filter { !usedTypes.contains($0) }
            var nextIndex = 0
            while slots.count < needed {
                if nextIndex < available.count {
                    slots.append(available[nextIndex])
                    nextIndex += 1
                } else {
                    slots.append(.steps)
                }
            }
        } else if slots.count > needed {
            slots = Array(slots.prefix(needed))
        }
    }

    /// True when every slot is .none
    var allEmpty: Bool {
        slots.allSatisfy { $0 == .none }
    }
}

enum FitnessGoal: String, Codable, CaseIterable {
    case hypertrophy = "Hypertrophy"
    case strength = "Strength"
    case performance = "Performance"
    case general = "General Fitness"
    case musclePreservation = "Muscle Preservation"
}

// MARK: - Fitness Profile Enums

enum Gender: String, Codable, CaseIterable {
    case male = "Male"
    case female = "Female"
    case nonBinary = "Non-Binary"
    case preferNotToSay = "Prefer Not to Say"
}

enum WeightUnit: String, Codable, CaseIterable {
    case kg = "kg"
    case lbs = "lbs"
}

enum HeightUnit: String, Codable, CaseIterable {
    case cm = "cm"
    case ftIn = "ft/in"
}

enum DistanceUnit: String, Codable, CaseIterable {
    case km = "km"
    case miles = "miles"
}

enum WorkoutEnvironment: String, Codable, CaseIterable {
    case home = "Home"
    case gym = "Gym"
    case both = "Both"
    case outdoor = "Outdoor"
}

enum ExperienceLevel: String, Codable, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
}

enum EquipmentType: String, Codable, CaseIterable {
    case barbell = "Barbell"
    case dumbbells = "Dumbbells"
    case kettlebells = "Kettlebells"
    case cables = "Cables"
    case machines = "Machines"
    case resistanceBands = "Resistance Bands"
    case pullUpBar = "Pull-Up Bar"
    case bench = "Bench"
    case bodyweightOnly = "Bodyweight Only"
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
    @Attribute(.externalStorage) var photoData: Data? // optional image
    @Attribute(.externalStorage) var videoData: Data?  // optional video

    // workout info (optional)
    var workoutType: String?
    var duration: Int?
    var setCount: Int?
    var exerciseHighlight: String?

    // music info (TikTok/Instagram style)
    var songTitle: String?
    var artistName: String?
    var songPreviewURL: String?  // For playback
    var albumArtURL: String?     // Pre-fetched cover image URL
    var albumArtData: Data?      // Cached album art image data for instant display
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

    // engagement metrics (feed ranking)
    var viewCount: Int
    var shareCount: Int
    var saveCount: Int
    var avgWatchTimeSec: Double
    var engagementScore: Double

    // Enhanced media (GymQuest 2.0 - exercise-aligned media)
    var mediaItemsData: Data?           // JSON-encoded [PostMedia]

    // Location tagging
    var locationName: String?           // e.g., "The ARC - Queen's University"
    var locationId: UUID?               // Link to Club if from known gym

    // Squad/Group tagging
    var taggedSquadIds: [UUID]          // Squads this post is shared with
    var taggedSquadNames: [String]      // Display names for rendering

    // Enhanced music (playlist URLs)
    var spotifyPlaylistURL: String?     // Full Spotify playlist URL
    var appleMusicPlaylistURL: String?  // Full Apple Music playlist URL

    // Workout emotion
    var workoutEmotion: String?         // WorkoutEmotion rawValue

    // PR moments (inline feed display)
    var prMomentsData: Data?            // JSON-encoded [FeedPR]

    // Voice note (audio clip attached to post)
    @Attribute(.externalStorage) var voiceNoteData: Data?
    var voiceNoteDuration: Double?
    var isPremiumAuthor: Bool

    // Post theme overlay
    var overlayTheme: String?           // PostTheme rawValue

    // Music snippet (which section of preview to play)
    var musicSnippetStart: Double?

    // Video metadata
    var videoAspectRatio: Double?

    // Challenge attached to post
    var challengeId: UUID?
    var challengeData: Data?            // JSON-encoded PostChallengeData

    // Interactive widget card (ONE per post)
    var postWidgetData: Data?           // JSON-encoded PostWidget

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
        albumArtURL: String? = nil,
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
        viewCount: Int = 0,
        shareCount: Int = 0,
        saveCount: Int = 0,
        avgWatchTimeSec: Double = 0,
        engagementScore: Double = 0,
        mediaItemsData: Data? = nil,
        locationName: String? = nil,
        locationId: UUID? = nil,
        taggedSquadIds: [UUID] = [],
        taggedSquadNames: [String] = [],
        spotifyPlaylistURL: String? = nil,
        appleMusicPlaylistURL: String? = nil,
        workoutEmotion: String? = nil,
        prMomentsData: Data? = nil,
        voiceNoteData: Data? = nil,
        voiceNoteDuration: Double? = nil,
        isPremiumAuthor: Bool = false,
        overlayTheme: String? = nil,
        musicSnippetStart: Double? = nil,
        videoAspectRatio: Double? = nil,
        challengeId: UUID? = nil,
        challengeData: Data? = nil,
        postWidgetData: Data? = nil
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
        self.albumArtURL = albumArtURL
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
        self.viewCount = viewCount
        self.shareCount = shareCount
        self.saveCount = saveCount
        self.avgWatchTimeSec = avgWatchTimeSec
        self.engagementScore = engagementScore
        self.mediaItemsData = mediaItemsData
        self.locationName = locationName
        self.locationId = locationId
        self.taggedSquadIds = taggedSquadIds
        self.taggedSquadNames = taggedSquadNames
        self.spotifyPlaylistURL = spotifyPlaylistURL
        self.appleMusicPlaylistURL = appleMusicPlaylistURL
        self.workoutEmotion = workoutEmotion
        self.prMomentsData = prMomentsData
        self.voiceNoteData = voiceNoteData
        self.voiceNoteDuration = voiceNoteDuration
        self.isPremiumAuthor = isPremiumAuthor
        self.overlayTheme = overlayTheme
        self.musicSnippetStart = musicSnippetStart
        self.videoAspectRatio = videoAspectRatio
        self.challengeId = challengeId
        self.challengeData = challengeData
        self.postWidgetData = postWidgetData
    }

    /// Decode shared workout data for follow feature
    func getSharedWorkout() -> SharedWorkoutData? {
        guard let data = sharedWorkoutData else { return nil }
        return try? JSONDecoder().decode(SharedWorkoutData.self, from: data)
    }

    /// Decode inline PR moments for feed display
    func getFeedPRs() -> [FeedPR] {
        guard let data = prMomentsData else { return [] }
        return (try? JSONDecoder().decode([FeedPR].self, from: data)) ?? []
    }

    /// Decode attached challenge data for feed display
    func getPostChallenge() -> PostChallengeData? {
        guard let data = challengeData else { return nil }
        return try? JSONDecoder().decode(PostChallengeData.self, from: data)
    }

    func getPostWidget() -> PostWidget? {
        guard let data = postWidgetData else { return nil }
        return try? JSONDecoder().decode(PostWidget.self, from: data)
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

    /// Typed accessor for the post overlay theme
    var theme: PostTheme? {
        guard let overlayTheme else { return nil }
        return PostTheme(rawValue: overlayTheme)
    }

}

// tracks who follows who - for the feed and @mentions
@Model
final class Friend {
    var id: UUID
    var userId: UUID       // the person doing the following
    var odId: UUID         // the person being followed
    var odName: String
    var odUsername: String
    var followedAt: Date

    init(
        id: UUID = UUID(),
        userId: UUID = UUID(),
        odId: UUID = UUID(),
        odName: String = "",
        odUsername: String = "",
        followedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
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
    var parentCommentId: UUID?
    var replyToAuthorName: String?
    var likeCount: Int

    init(
        id: UUID = UUID(),
        postId: UUID = UUID(),
        authorId: UUID = UUID(),
        authorName: String = "",
        authorUsername: String = "",
        content: String = "",
        timestamp: Date = Date(),
        parentCommentId: UUID? = nil,
        replyToAuthorName: String? = nil,
        likeCount: Int = 0
    ) {
        self.id = id
        self.postId = postId
        self.authorId = authorId
        self.authorName = authorName
        self.authorUsername = authorUsername
        self.content = content
        self.timestamp = timestamp
        self.parentCommentId = parentCommentId
        self.replyToAuthorName = replyToAuthorName
        self.likeCount = likeCount
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
    case weightPR = "Weight PR"
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

// MARK: - Consistency State (System 1)

enum ConsistencyState: String, Codable, CaseIterable {
    case onTrack = "On Track"
    case slipping = "Slipping"
    case atRisk = "At Risk"
    case comeback = "Comeback"
    case rebuilding = "Rebuilding"
}

// MARK: - Pod Lifecycle State (System 2)

enum PodLifecycleState: String, Codable {
    case forming = "Forming"
    case active = "Active"
    case stale = "Stale"
    case dead = "Dead"
}

enum PodLevel: String, Codable, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
}

enum PodVisibility: String, Codable {
    case open = "Open"
    case inviteOnly = "Invite Only"
}

enum PodRole: String, Codable {
    case member = "Member"
    case leader = "Leader"
}

enum PodCheckInType: String, Codable, CaseIterable {
    case trainingNow = "Training Now"
    case done = "Done"
    case needPush = "Need a Push"
    case restDay = "Rest Day"

    var emoji: String {
        switch self {
        case .trainingNow: return "\u{1F3CB}\u{FE0F}"
        case .done: return "\u{2705}"
        case .needPush: return "\u{1F4AA}"
        case .restDay: return "\u{1F634}"
        }
    }
}

enum NudgeSourceType: String, Codable {
    case ai = "AI"
    case pod = "Pod"
    case club = "Club"
    case system = "System"
}

enum NudgeType: String, Codable, CaseIterable {
    case missedWorkout = "Missed Workout"
    case comeback = "Comeback"
    case streakRisk = "Streak Risk"
    case podSupport = "Pod Support"
    case weeklyGoal = "Weekly Goal"

    var icon: String {
        switch self {
        case .missedWorkout: return "exclamationmark.circle"
        case .comeback: return "arrow.counterclockwise"
        case .streakRisk: return "flame"
        case .podSupport: return "hand.thumbsup"
        case .weeklyGoal: return "target"
        }
    }
}

enum ChallengeScope: String, Codable {
    case individual = "Individual"
    case pod = "Pod"
    case club = "Club"
}

@Model
final class Pod {
    var id: UUID
    var clubId: UUID?
    var name: String
    var summary: String
    var inviteCode: String
    var creatorId: UUID
    var memberIds: [UUID]
    var level: String
    var schedulePreference: String
    var trainingStyle: String
    var maxMembers: Int
    var weeklyWorkoutTarget: Int
    var streakWeeks: Int
    var visibility: String
    var lifecycle: String
    var lastActivityDate: Date?
    var autoCreated: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        clubId: UUID? = nil,
        name: String = "",
        summary: String = "",
        inviteCode: String = "",
        creatorId: UUID = UUID(),
        memberIds: [UUID] = [],
        level: PodLevel = .beginner,
        schedulePreference: String = "Flexible",
        trainingStyle: String = "General",
        maxMembers: Int = 6,
        weeklyWorkoutTarget: Int = 3,
        streakWeeks: Int = 0,
        visibility: PodVisibility = .open,
        lifecycleState: PodLifecycleState = .forming,
        lastActivityDate: Date? = nil,
        autoCreated: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.clubId = clubId
        self.name = name
        self.summary = summary
        self.inviteCode = inviteCode.isEmpty ? Pod.generateCode() : inviteCode
        self.creatorId = creatorId
        self.memberIds = memberIds
        self.level = level.rawValue
        self.schedulePreference = schedulePreference
        self.trainingStyle = trainingStyle
        self.maxMembers = maxMembers
        self.weeklyWorkoutTarget = weeklyWorkoutTarget
        self.streakWeeks = streakWeeks
        self.visibility = visibility.rawValue
        self.lifecycle = lifecycleState.rawValue
        self.lastActivityDate = lastActivityDate
        self.autoCreated = autoCreated
        self.createdAt = createdAt
    }

    var podLevel: PodLevel { PodLevel(rawValue: level) ?? .beginner }
    var podVisibility: PodVisibility { PodVisibility(rawValue: visibility) ?? .open }
    var lifecycleState: PodLifecycleState {
        get { PodLifecycleState(rawValue: lifecycle) ?? .forming }
        set { lifecycle = newValue.rawValue }
    }
    var isFull: Bool { memberIds.count >= maxMembers }
    var memberCount: Int { memberIds.count }

    static func generateCode() -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).compactMap { _ in chars.randomElement() })
    }
}

// MARK: - Pod Membership

@Model
final class PodMembership {
    var id: UUID
    var podId: UUID
    var userId: UUID
    var role: String
    var joinedAt: Date
    var weeklyCompletedWorkouts: Int
    var currentStreak: Int
    var isPrimaryPod: Bool

    init(
        id: UUID = UUID(),
        podId: UUID = UUID(),
        userId: UUID = UUID(),
        role: PodRole = .member,
        joinedAt: Date = Date(),
        weeklyCompletedWorkouts: Int = 0,
        currentStreak: Int = 0,
        isPrimaryPod: Bool = true
    ) {
        self.id = id
        self.podId = podId
        self.userId = userId
        self.role = role.rawValue
        self.joinedAt = joinedAt
        self.weeklyCompletedWorkouts = weeklyCompletedWorkouts
        self.currentStreak = currentStreak
        self.isPrimaryPod = isPrimaryPod
    }

    var podRole: PodRole { PodRole(rawValue: role) ?? .member }
}

// MARK: - Pod Check-In

@Model
final class PodCheckIn {
    var id: UUID
    var podId: UUID
    var userId: UUID
    var type: String
    var workoutId: UUID?
    var message: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        podId: UUID = UUID(),
        userId: UUID = UUID(),
        type: PodCheckInType = .done,
        workoutId: UUID? = nil,
        message: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.podId = podId
        self.userId = userId
        self.type = type.rawValue
        self.workoutId = workoutId
        self.message = message
        self.createdAt = createdAt
    }

    var checkInType: PodCheckInType { PodCheckInType(rawValue: type) ?? .done }
}

// MARK: - Accountability Nudge

@Model
final class AccountabilityNudge {
    var id: UUID
    var userId: UUID
    var sourceType: String
    var nudgeType: String
    var title: String
    var message: String
    var actionLabel: String
    var createdAt: Date
    var actedAt: Date?

    init(
        id: UUID = UUID(),
        userId: UUID = UUID(),
        sourceType: NudgeSourceType = .system,
        nudgeType: NudgeType = .weeklyGoal,
        title: String = "",
        message: String = "",
        actionLabel: String = "View",
        createdAt: Date = Date(),
        actedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.sourceType = sourceType.rawValue
        self.nudgeType = nudgeType.rawValue
        self.title = title
        self.message = message
        self.actionLabel = actionLabel
        self.createdAt = createdAt
        self.actedAt = actedAt
    }

    var source: NudgeSourceType { NudgeSourceType(rawValue: sourceType) ?? .system }
    var nudge: NudgeType { NudgeType(rawValue: nudgeType) ?? .weeklyGoal }
    var isActedOn: Bool { actedAt != nil }
}

// MARK: - Comeback Plan

@Model
final class ComebackPlan {
    var id: UUID
    var userId: UUID
    var reason: String
    var suggestedWorkoutType: String
    var suggestedDuration: Int
    var encouragement: String
    var createdAt: Date
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        userId: UUID = UUID(),
        reason: String = "missed_days",
        suggestedWorkoutType: String = "Full Body",
        suggestedDuration: Int = 30,
        encouragement: String = "Welcome back! A shorter session is all you need to get moving again.",
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.reason = reason
        self.suggestedWorkoutType = suggestedWorkoutType
        self.suggestedDuration = suggestedDuration
        self.encouragement = encouragement
        self.createdAt = createdAt
        self.completedAt = completedAt
    }

    var isCompleted: Bool { completedAt != nil }
}

// MARK: - Challenge

@Model
final class Challenge {
    var id: UUID
    var templateId: UUID?
    var scope: String
    var title: String
    var challengeDescription: String
    var goalType: ChallengeGoalType
    var goalTarget: Int
    var currentProgress: Int
    var startDate: Date
    var endDate: Date
    var xpReward: Int
    var isCompleted: Bool
    var completedAt: Date?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        templateId: UUID? = nil,
        scope: ChallengeScope = .individual,
        title: String = "",
        challengeDescription: String = "",
        goalType: ChallengeGoalType = .workouts,
        goalTarget: Int = 1,
        currentProgress: Int = 0,
        startDate: Date = Date(),
        endDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
        xpReward: Int = 50,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.templateId = templateId
        self.scope = scope.rawValue
        self.title = title
        self.challengeDescription = challengeDescription
        self.goalType = goalType
        self.goalTarget = goalTarget
        self.currentProgress = currentProgress
        self.startDate = startDate
        self.endDate = endDate
        self.xpReward = xpReward
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.createdAt = createdAt
    }

    var challengeScope: ChallengeScope { ChallengeScope(rawValue: scope) ?? .individual }
    var progress: Double {
        guard goalTarget > 0 else { return 0 }
        return min(1.0, Double(currentProgress) / Double(goalTarget))
    }
    var daysRemaining: Int {
        max(0, Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0)
    }
    var isActive: Bool { !isCompleted && Date() < endDate }
}

// MARK: - Challenge Enrollment

@Model
final class ChallengeEnrollment {
    var id: UUID
    var challengeId: UUID
    var userId: UUID
    var progress: Int
    var isCompleted: Bool
    var completedAt: Date?
    var enrolledAt: Date

    init(
        id: UUID = UUID(),
        challengeId: UUID = UUID(),
        userId: UUID = UUID(),
        progress: Int = 0,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        enrolledAt: Date = Date()
    ) {
        self.id = id
        self.challengeId = challengeId
        self.userId = userId
        self.progress = progress
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.enrolledAt = enrolledAt
    }
}

// MARK: - User Momentum State

@Model
final class UserMomentumState {
    var id: UUID
    var userId: UUID
    var state: String
    var currentWeekTarget: Int
    var currentWeekCompleted: Int
    var missedDaysInRow: Int
    var streak: Int
    var lastWorkoutDate: Date?
    var comebackEligible: Bool
    var beginnerPhaseActive: Bool
    var beginnerGraceEndDate: Date?
    var firstWorkoutCompleted: Bool
    var firstWeekCompleted: Bool
    var lastStateTransition: Date?
    var weeklyVelocity: Double
    var rebuildingWeekCount: Int

    init(
        id: UUID = UUID(),
        userId: UUID = UUID(),
        consistencyState: ConsistencyState = .onTrack,
        currentWeekTarget: Int = 3,
        currentWeekCompleted: Int = 0,
        missedDaysInRow: Int = 0,
        streak: Int = 0,
        lastWorkoutDate: Date? = nil,
        comebackEligible: Bool = false,
        beginnerPhaseActive: Bool = true,
        beginnerGraceEndDate: Date? = nil,
        firstWorkoutCompleted: Bool = false,
        firstWeekCompleted: Bool = false,
        lastStateTransition: Date? = nil,
        weeklyVelocity: Double = 0,
        rebuildingWeekCount: Int = 0
    ) {
        self.id = id
        self.userId = userId
        self.state = consistencyState.rawValue
        self.currentWeekTarget = currentWeekTarget
        self.currentWeekCompleted = currentWeekCompleted
        self.missedDaysInRow = missedDaysInRow
        self.streak = streak
        self.lastWorkoutDate = lastWorkoutDate
        self.comebackEligible = comebackEligible
        self.beginnerPhaseActive = beginnerPhaseActive
        self.beginnerGraceEndDate = beginnerGraceEndDate
        self.firstWorkoutCompleted = firstWorkoutCompleted
        self.firstWeekCompleted = firstWeekCompleted
        self.lastStateTransition = lastStateTransition
        self.weeklyVelocity = weeklyVelocity
        self.rebuildingWeekCount = rebuildingWeekCount
    }

    var consistencyState: ConsistencyState {
        get { ConsistencyState(rawValue: state) ?? .onTrack }
        set { state = newValue.rawValue }
    }
    var effectiveWeeklyTarget: Int {
        consistencyState == .rebuilding ? max(1, currentWeekTarget - 1) : currentWeekTarget
    }
    var weeklyProgress: Double {
        guard currentWeekTarget > 0 else { return 0 }
        return min(1.0, Double(currentWeekCompleted) / Double(currentWeekTarget))
    }
    var isOnTrack: Bool { currentWeekCompleted >= currentWeekTarget }
    var needsComebackNudge: Bool { missedDaysInRow >= 3 && !comebackEligible }
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

// MARK: - Club System (GymQuest 2.0)

/// Club join type
enum ClubJoinType: String, Codable, CaseIterable {
    case open = "Open"           // Anyone can join
    case request = "Request"     // Request to join, admin approves
}

/// Club category for activity/sports-driven clubs
enum ClubCategory: String, Codable, CaseIterable {
    // Activity-based
    case running = "Running"
    case cycling = "Cycling"
    case weightlifting = "Weightlifting"
    case crossfit = "CrossFit"
    case yoga = "Yoga"
    case hiit = "HIIT"
    case swimming = "Swimming"
    // Sports/recreation
    case basketball = "Basketball"
    case soccer = "Soccer"
    case tennis = "Tennis"
    case volleyball = "Volleyball"
    case hockey = "Hockey"
    // General
    case generalFitness = "General Fitness"
    case martialArts = "Martial Arts"
    case dance = "Dance"
    case climbing = "Climbing"

    var icon: String {
        switch self {
        case .running: return "figure.run"
        case .cycling: return "figure.outdoor.cycle"
        case .weightlifting: return "figure.strengthtraining.traditional"
        case .crossfit: return "figure.highintensity.intervaltraining"
        case .yoga: return "figure.mind.and.body"
        case .hiit: return "bolt.heart.fill"
        case .swimming: return "figure.pool.swim"
        case .basketball: return "basketball.fill"
        case .soccer: return "soccerball"
        case .tennis: return "tennis.racket"
        case .volleyball: return "volleyball.fill"
        case .hockey: return "hockey.puck.fill"
        case .generalFitness: return "dumbbell.fill"
        case .martialArts: return "figure.martial.arts"
        case .dance: return "figure.dance"
        case .climbing: return "figure.climbing"
        }
    }

    var color: Color {
        switch self {
        case .running: return GQColors.textSecondary
        case .cycling: return GQColors.deepBlue
        case .weightlifting: return GQColors.deepBlue
        case .crossfit: return GQColors.textSecondary
        case .yoga: return GQColors.mint
        case .hiit: return GQColors.textSecondary
        case .swimming: return GQColors.textSecondary
        case .basketball: return GQColors.terracotta
        case .soccer: return GQColors.mint
        case .tennis: return GQColors.textSecondary
        case .volleyball: return GQColors.textSecondary
        case .hockey: return GQColors.deepBlue
        case .generalFitness: return GQColors.textSecondary
        case .martialArts: return GQColors.textSecondary
        case .dance: return GQColors.deepBlue
        case .climbing: return GQColors.terracotta
        }
    }

    var isActivityBased: Bool {
        switch self {
        case .running, .cycling, .weightlifting, .crossfit, .yoga, .hiit, .swimming:
            return true
        default:
            return false
        }
    }
}

/// Club (gyms, universities, rec centers)
@Model
final class Club {
    var id: UUID
    var name: String                    // e.g., "The ARC - Queen's University"
    var clubDescription: String
    var location: String?               // e.g., "Kingston, ON"
    var latitude: Double?
    var longitude: Double?
    var imageData: Data?                // Club banner/logo
    var creatorId: UUID
    var adminIds: [UUID]
    var memberIds: [UUID]
    var pendingRequestIds: [UUID]       // Users requesting to join
    var joinType: ClubJoinType
    var memberCount: Int
    var isVerified: Bool                // Official gym/university account
    var tags: [String]                  // e.g., ["university", "gym", "weightlifting"]
    var createdAt: Date
    var parentClubId: UUID?        // non-nil = this is a channel/sub-club
    var category: ClubCategory?
    var lastActivityDate: Date?
    var isListedInDiscovery: Bool

    var resolvedCategory: ClubCategory { category ?? .generalFitness }

    init(
        id: UUID = UUID(),
        name: String = "",
        clubDescription: String = "",
        location: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        imageData: Data? = nil,
        creatorId: UUID = UUID(),
        adminIds: [UUID] = [],
        memberIds: [UUID] = [],
        pendingRequestIds: [UUID] = [],
        joinType: ClubJoinType = .open,
        memberCount: Int = 0,
        isVerified: Bool = false,
        tags: [String] = [],
        createdAt: Date = Date(),
        parentClubId: UUID? = nil,
        category: ClubCategory? = nil,
        lastActivityDate: Date? = nil,
        isListedInDiscovery: Bool = false
    ) {
        self.id = id
        self.name = name
        self.clubDescription = clubDescription
        self.location = location
        self.latitude = latitude
        self.longitude = longitude
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
        self.parentClubId = parentClubId
        self.category = category
        self.lastActivityDate = lastActivityDate
        self.isListedInDiscovery = isListedInDiscovery
    }

    var isOpen: Bool {
        joinType == .open
    }

    var isChannel: Bool {
        parentClubId != nil
    }
}

/// Club post (workout shared to a club)
@Model
final class ClubPost {
    var id: UUID
    var clubId: UUID
    var authorId: UUID
    var authorName: String
    var authorUsername: String
    var postType: ClubPostType
    var content: String
    var workoutId: UUID?                // Link to workout if sharing one
    var photoData: Data?
    var likeCount: Int
    var commentCount: Int
    var timestamp: Date
    var channelId: UUID?

    init(
        id: UUID = UUID(),
        clubId: UUID = UUID(),
        authorId: UUID = UUID(),
        authorName: String = "",
        authorUsername: String = "",
        postType: ClubPostType = .workout,
        content: String = "",
        workoutId: UUID? = nil,
        photoData: Data? = nil,
        likeCount: Int = 0,
        commentCount: Int = 0,
        timestamp: Date = Date(),
        channelId: UUID? = nil
    ) {
        self.id = id
        self.clubId = clubId
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

enum ClubPostType: String, Codable, CaseIterable {
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

// MARK: - Club Membership

enum ClubRole: String, Codable {
    case member
    case admin
    case owner
    case verifiedCoach
}

enum WorkoutPartnerStatus: String, Codable {
    case available
    case notLooking
}

@Model
final class ClubMembership {
    var id: UUID
    var userId: UUID
    var clubId: UUID
    var role: ClubRole
    var workoutPartnerStatus: WorkoutPartnerStatus
    var joinedAt: Date

    init(
        id: UUID = UUID(),
        userId: UUID = UUID(),
        clubId: UUID = UUID(),
        role: ClubRole = .member,
        workoutPartnerStatus: WorkoutPartnerStatus = .notLooking,
        joinedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.clubId = clubId
        self.role = role
        self.workoutPartnerStatus = workoutPartnerStatus
        self.joinedAt = joinedAt
    }
}

// MARK: - Club Event

enum ClubEventType: String, Codable, CaseIterable {
    case workout = "Workout"
    case meetup = "Meetup"
    case competition = "Competition"
    case social = "Social"
    case groupRun = "Group Run"
    case groupRide = "Group Ride"
    case practice = "Practice"
    case pickupGame = "Pickup Game"
    case tournament = "Tournament"
    case scrimmage = "Scrimmage"

    var icon: String {
        switch self {
        case .workout: return "figure.strengthtraining.traditional"
        case .meetup: return "person.3.fill"
        case .competition: return "trophy.fill"
        case .social: return "party.popper.fill"
        case .groupRun: return "figure.run"
        case .groupRide: return "figure.outdoor.cycle"
        case .practice: return "sportscourt.fill"
        case .pickupGame: return "basketball.fill"
        case .tournament: return "trophy.fill"
        case .scrimmage: return "soccerball"
        }
    }

    var color: Color {
        switch self {
        case .workout: return GQColors.textSecondary
        case .meetup: return GQColors.deepBlue
        case .competition: return GQColors.textSecondary
        case .social: return GQColors.textSecondary
        case .groupRun: return GQColors.textSecondary
        case .groupRide: return GQColors.deepBlue
        case .practice: return GQColors.mint
        case .pickupGame: return GQColors.terracotta
        case .tournament: return GQColors.textSecondary
        case .scrimmage: return GQColors.mint
        }
    }
}

@Model
final class ClubEvent {
    var id: UUID
    var clubId: UUID
    var creatorId: UUID
    var creatorName: String
    var title: String
    var eventDescription: String
    var location: String?
    var date: Date
    var endDate: Date?
    var maxAttendees: Int?
    var attendeeIds: [UUID]
    var eventType: ClubEventType
    var createdAt: Date
    var isRecurring: Bool
    var recurrenceRule: String?    // "weekly", "biweekly", "monthly"

    init(
        id: UUID = UUID(),
        clubId: UUID = UUID(),
        creatorId: UUID = UUID(),
        creatorName: String = "",
        title: String = "",
        eventDescription: String = "",
        location: String? = nil,
        date: Date = Date(),
        endDate: Date? = nil,
        maxAttendees: Int? = nil,
        attendeeIds: [UUID] = [],
        eventType: ClubEventType = .workout,
        createdAt: Date = Date(),
        isRecurring: Bool = false,
        recurrenceRule: String? = nil
    ) {
        self.id = id
        self.clubId = clubId
        self.creatorId = creatorId
        self.creatorName = creatorName
        self.title = title
        self.eventDescription = eventDescription
        self.location = location
        self.date = date
        self.endDate = endDate
        self.maxAttendees = maxAttendees
        self.attendeeIds = attendeeIds
        self.eventType = eventType
        self.createdAt = createdAt
        self.isRecurring = isRecurring
        self.recurrenceRule = recurrenceRule
    }
}

// MARK: - Club Challenge

enum ChallengeGoalType: String, Codable, CaseIterable {
    case workouts = "Workouts"
    case sets = "Sets"
    case volume = "Volume (lbs)"
    case streak = "Day Streak"
    case distance = "Distance (km)"
    case duration = "Duration (min)"
    case games = "Games Played"

    var icon: String {
        switch self {
        case .workouts: return "figure.strengthtraining.traditional"
        case .sets: return "flame.fill"
        case .volume: return "scalemass.fill"
        case .streak: return "calendar.badge.checkmark"
        case .distance: return "map.fill"
        case .duration: return "timer"
        case .games: return "sportscourt.fill"
        }
    }
}

@Model
final class ClubChallenge {
    var id: UUID
    var clubId: UUID
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
        clubId: UUID = UUID(),
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
        self.clubId = clubId
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
    var squadVsSquadOpponentId: UUID?
    var xpMultiplier: Double
    var weeklyLeaderboardData: Data?

    init(
        id: UUID = UUID(),
        name: String = "",
        creatorId: UUID = UUID(),
        memberIds: [UUID] = [],
        inviteCode: String = "",
        weeklyGoal: WeeklyGoal = WeeklyGoal(),
        activeChallengeId: UUID? = nil,
        streakWeeks: Int = 0,
        createdAt: Date = Date(),
        squadVsSquadOpponentId: UUID? = nil,
        xpMultiplier: Double = 1.0,
        weeklyLeaderboardData: Data? = nil
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
        self.squadVsSquadOpponentId = squadVsSquadOpponentId
        self.xpMultiplier = xpMultiplier
        self.weeklyLeaderboardData = weeklyLeaderboardData
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
    case heart = "Love"
    case fire = "Fire"
    case thumbsUp = "Nice"
    case strong = "Strong"
    case clap = "Props"
    case shocked = "Wow"

    var emoji: String {
        switch self {
        case .heart: return "❤️"
        case .fire: return "🔥"
        case .thumbsUp: return "👍"
        case .strong: return "💪"
        case .clap: return "👏"
        case .shocked: return "😮"
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
        reactionType: ReactionType = .heart,
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

/// Theme overlay for post photos in the feed
enum PostTheme: String, Codable, CaseIterable {
    case sunset = "Sunset"
    case ocean = "Ocean"
    case lavender = "Lavender"
    case golden = "Golden"
    case rose = "Rose"
    case midnight = "Midnight"

    var emoji: String {
        switch self {
        case .sunset: return "🌅"
        case .ocean: return "🌊"
        case .lavender: return "💜"
        case .golden: return "✨"
        case .rose: return "🌹"
        case .midnight: return "🌙"
        }
    }

    var topGradientColors: [Color] {
        switch self {
        case .sunset:
            return [
                Color(red: 0.9, green: 0.4, blue: 0.2).opacity(0.45),
                Color(red: 0.9, green: 0.5, blue: 0.3).opacity(0.15),
                .clear
            ]
        case .ocean:
            return [
                Color(red: 0.1, green: 0.4, blue: 0.6).opacity(0.45),
                Color(red: 0.1, green: 0.5, blue: 0.7).opacity(0.15),
                .clear
            ]
        case .lavender:
            return [
                Color(red: 0.5, green: 0.3, blue: 0.7).opacity(0.45),
                Color(red: 0.6, green: 0.4, blue: 0.8).opacity(0.15),
                .clear
            ]
        case .golden:
            return [
                Color(red: 0.9, green: 0.7, blue: 0.2).opacity(0.45),
                Color(red: 0.95, green: 0.8, blue: 0.3).opacity(0.15),
                .clear
            ]
        case .rose:
            return [
                Color(red: 0.85, green: 0.3, blue: 0.4).opacity(0.45),
                Color(red: 0.9, green: 0.4, blue: 0.5).opacity(0.15),
                .clear
            ]
        case .midnight:
            return [
                Color(red: 0.1, green: 0.05, blue: 0.2).opacity(0.45),
                Color(red: 0.1, green: 0.05, blue: 0.2).opacity(0.15),
                .clear
            ]
        }
    }

    var bottomGradientColors: [Color] {
        switch self {
        case .sunset:
            return [
                .clear,
                Color(red: 0.8, green: 0.3, blue: 0.1).opacity(0.3),
                Color(red: 0.6, green: 0.15, blue: 0.05).opacity(0.6)
            ]
        case .ocean:
            return [
                .clear,
                Color(red: 0.05, green: 0.2, blue: 0.4).opacity(0.3),
                Color(red: 0.02, green: 0.1, blue: 0.3).opacity(0.6)
            ]
        case .lavender:
            return [
                .clear,
                Color(red: 0.3, green: 0.15, blue: 0.5).opacity(0.3),
                Color(red: 0.2, green: 0.08, blue: 0.4).opacity(0.6)
            ]
        case .golden:
            return [
                .clear,
                Color(red: 0.7, green: 0.5, blue: 0.1).opacity(0.3),
                Color(red: 0.5, green: 0.3, blue: 0.05).opacity(0.6)
            ]
        case .rose:
            return [
                .clear,
                Color(red: 0.6, green: 0.15, blue: 0.2).opacity(0.3),
                Color(red: 0.4, green: 0.08, blue: 0.12).opacity(0.6)
            ]
        case .midnight:
            return [
                .clear,
                Color(red: 0.15, green: 0.05, blue: 0.1).opacity(0.3),
                Color(red: 0.1, green: 0.03, blue: 0.12).opacity(0.6)
            ]
        }
    }

    var previewColors: [Color] {
        switch self {
        case .sunset: return [Color(red: 0.9, green: 0.4, blue: 0.2), Color(red: 0.6, green: 0.15, blue: 0.05)]
        case .ocean: return [Color(red: 0.1, green: 0.4, blue: 0.6), Color(red: 0.02, green: 0.1, blue: 0.3)]
        case .lavender: return [Color(red: 0.5, green: 0.3, blue: 0.7), Color(red: 0.2, green: 0.08, blue: 0.4)]
        case .golden: return [Color(red: 0.9, green: 0.7, blue: 0.2), Color(red: 0.5, green: 0.3, blue: 0.05)]
        case .rose: return [Color(red: 0.85, green: 0.3, blue: 0.4), Color(red: 0.4, green: 0.08, blue: 0.12)]
        case .midnight: return [Color(red: 0.15, green: 0.1, blue: 0.25), Color(red: 0.1, green: 0.03, blue: 0.12)]
        }
    }
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
        case .fired: return GQColors.textSecondary
        case .strong: return GQColors.deepBlue
        case .grateful: return GQColors.textSecondary
        case .calm: return GQColors.textSecondary
        case .grinding: return GQColors.textSecondary
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

    struct FoodEntry {
        let caloriesPer100g: Int
        let proteinPer100g: Int
        let carbsPer100g: Int
        let fatPer100g: Int
        let defaultServingGrams: Int
        let servingDescription: String
    }

    // MARK: - USDA-aligned per-100g food database (~120+ entries)

    private static let foodDatabase: [String: FoodEntry] = [
        // Proteins
        "egg": FoodEntry(caloriesPer100g: 155, proteinPer100g: 13, carbsPer100g: 1, fatPer100g: 11, defaultServingGrams: 50, servingDescription: "1 large egg"),
        "eggs": FoodEntry(caloriesPer100g: 155, proteinPer100g: 13, carbsPer100g: 1, fatPer100g: 11, defaultServingGrams: 50, servingDescription: "1 large egg"),
        "chicken": FoodEntry(caloriesPer100g: 165, proteinPer100g: 31, carbsPer100g: 0, fatPer100g: 4, defaultServingGrams: 170, servingDescription: "1 breast"),
        "chicken breast": FoodEntry(caloriesPer100g: 165, proteinPer100g: 31, carbsPer100g: 0, fatPer100g: 4, defaultServingGrams: 170, servingDescription: "1 breast"),
        "chicken thigh": FoodEntry(caloriesPer100g: 209, proteinPer100g: 26, carbsPer100g: 0, fatPer100g: 11, defaultServingGrams: 115, servingDescription: "1 thigh"),
        "steak": FoodEntry(caloriesPer100g: 271, proteinPer100g: 26, carbsPer100g: 0, fatPer100g: 18, defaultServingGrams: 225, servingDescription: "8 oz steak"),
        "beef": FoodEntry(caloriesPer100g: 250, proteinPer100g: 26, carbsPer100g: 0, fatPer100g: 15, defaultServingGrams: 115, servingDescription: "4 oz patty"),
        "ground beef": FoodEntry(caloriesPer100g: 250, proteinPer100g: 26, carbsPer100g: 0, fatPer100g: 15, defaultServingGrams: 115, servingDescription: "4 oz"),
        "salmon": FoodEntry(caloriesPer100g: 208, proteinPer100g: 20, carbsPer100g: 0, fatPer100g: 13, defaultServingGrams: 170, servingDescription: "1 fillet"),
        "tuna": FoodEntry(caloriesPer100g: 130, proteinPer100g: 28, carbsPer100g: 0, fatPer100g: 1, defaultServingGrams: 85, servingDescription: "1 can"),
        "shrimp": FoodEntry(caloriesPer100g: 99, proteinPer100g: 24, carbsPer100g: 0, fatPer100g: 0, defaultServingGrams: 85, servingDescription: "3 oz"),
        "tofu": FoodEntry(caloriesPer100g: 76, proteinPer100g: 8, carbsPer100g: 2, fatPer100g: 5, defaultServingGrams: 125, servingDescription: "1/2 block"),
        "turkey": FoodEntry(caloriesPer100g: 135, proteinPer100g: 30, carbsPer100g: 0, fatPer100g: 1, defaultServingGrams: 85, servingDescription: "3 oz"),
        "turkey breast": FoodEntry(caloriesPer100g: 135, proteinPer100g: 30, carbsPer100g: 0, fatPer100g: 1, defaultServingGrams: 85, servingDescription: "3 oz"),
        "bacon": FoodEntry(caloriesPer100g: 541, proteinPer100g: 37, carbsPer100g: 1, fatPer100g: 42, defaultServingGrams: 24, servingDescription: "3 slices"),
        "protein shake": FoodEntry(caloriesPer100g: 400, proteinPer100g: 80, carbsPer100g: 13, fatPer100g: 7, defaultServingGrams: 32, servingDescription: "1 scoop"),
        "whey": FoodEntry(caloriesPer100g: 400, proteinPer100g: 80, carbsPer100g: 13, fatPer100g: 7, defaultServingGrams: 32, servingDescription: "1 scoop"),
        "greek yogurt": FoodEntry(caloriesPer100g: 59, proteinPer100g: 10, carbsPer100g: 4, fatPer100g: 0, defaultServingGrams: 170, servingDescription: "1 cup"),
        "yogurt": FoodEntry(caloriesPer100g: 61, proteinPer100g: 3, carbsPer100g: 5, fatPer100g: 3, defaultServingGrams: 170, servingDescription: "1 cup"),
        "cottage cheese": FoodEntry(caloriesPer100g: 98, proteinPer100g: 11, carbsPer100g: 3, fatPer100g: 4, defaultServingGrams: 115, servingDescription: "1/2 cup"),
        "pork": FoodEntry(caloriesPer100g: 242, proteinPer100g: 27, carbsPer100g: 0, fatPer100g: 14, defaultServingGrams: 115, servingDescription: "4 oz"),
        "pork chop": FoodEntry(caloriesPer100g: 231, proteinPer100g: 26, carbsPer100g: 0, fatPer100g: 13, defaultServingGrams: 140, servingDescription: "1 chop"),
        "lamb": FoodEntry(caloriesPer100g: 294, proteinPer100g: 25, carbsPer100g: 0, fatPer100g: 21, defaultServingGrams: 115, servingDescription: "4 oz"),
        "tilapia": FoodEntry(caloriesPer100g: 96, proteinPer100g: 20, carbsPer100g: 0, fatPer100g: 2, defaultServingGrams: 115, servingDescription: "1 fillet"),
        "cod": FoodEntry(caloriesPer100g: 82, proteinPer100g: 18, carbsPer100g: 0, fatPer100g: 1, defaultServingGrams: 115, servingDescription: "1 fillet"),
        "crab": FoodEntry(caloriesPer100g: 97, proteinPer100g: 19, carbsPer100g: 0, fatPer100g: 2, defaultServingGrams: 85, servingDescription: "3 oz"),
        "lobster": FoodEntry(caloriesPer100g: 89, proteinPer100g: 19, carbsPer100g: 0, fatPer100g: 1, defaultServingGrams: 145, servingDescription: "1 tail"),
        "scallops": FoodEntry(caloriesPer100g: 69, proteinPer100g: 12, carbsPer100g: 3, fatPer100g: 1, defaultServingGrams: 85, servingDescription: "3 oz"),
        "jerky": FoodEntry(caloriesPer100g: 410, proteinPer100g: 33, carbsPer100g: 11, fatPer100g: 26, defaultServingGrams: 28, servingDescription: "1 oz"),
        "beef jerky": FoodEntry(caloriesPer100g: 410, proteinPer100g: 33, carbsPer100g: 11, fatPer100g: 26, defaultServingGrams: 28, servingDescription: "1 oz"),

        // Carbs
        "rice": FoodEntry(caloriesPer100g: 130, proteinPer100g: 3, carbsPer100g: 28, fatPer100g: 0, defaultServingGrams: 195, servingDescription: "1 cup cooked"),
        "brown rice": FoodEntry(caloriesPer100g: 123, proteinPer100g: 3, carbsPer100g: 26, fatPer100g: 1, defaultServingGrams: 195, servingDescription: "1 cup cooked"),
        "bread": FoodEntry(caloriesPer100g: 265, proteinPer100g: 9, carbsPer100g: 49, fatPer100g: 3, defaultServingGrams: 30, servingDescription: "1 slice"),
        "toast": FoodEntry(caloriesPer100g: 265, proteinPer100g: 9, carbsPer100g: 49, fatPer100g: 3, defaultServingGrams: 30, servingDescription: "1 slice"),
        "whole wheat bread": FoodEntry(caloriesPer100g: 252, proteinPer100g: 12, carbsPer100g: 43, fatPer100g: 4, defaultServingGrams: 30, servingDescription: "1 slice"),
        "pasta": FoodEntry(caloriesPer100g: 131, proteinPer100g: 5, carbsPer100g: 25, fatPer100g: 1, defaultServingGrams: 200, servingDescription: "1 cup cooked"),
        "spaghetti": FoodEntry(caloriesPer100g: 131, proteinPer100g: 5, carbsPer100g: 25, fatPer100g: 1, defaultServingGrams: 200, servingDescription: "1 cup cooked"),
        "oatmeal": FoodEntry(caloriesPer100g: 68, proteinPer100g: 2, carbsPer100g: 12, fatPer100g: 1, defaultServingGrams: 235, servingDescription: "1 cup cooked"),
        "oats": FoodEntry(caloriesPer100g: 389, proteinPer100g: 17, carbsPer100g: 66, fatPer100g: 7, defaultServingGrams: 40, servingDescription: "1/2 cup dry"),
        "potato": FoodEntry(caloriesPer100g: 77, proteinPer100g: 2, carbsPer100g: 17, fatPer100g: 0, defaultServingGrams: 213, servingDescription: "1 medium"),
        "sweet potato": FoodEntry(caloriesPer100g: 86, proteinPer100g: 2, carbsPer100g: 20, fatPer100g: 0, defaultServingGrams: 130, servingDescription: "1 medium"),
        "banana": FoodEntry(caloriesPer100g: 89, proteinPer100g: 1, carbsPer100g: 23, fatPer100g: 0, defaultServingGrams: 118, servingDescription: "1 medium"),
        "apple": FoodEntry(caloriesPer100g: 52, proteinPer100g: 0, carbsPer100g: 14, fatPer100g: 0, defaultServingGrams: 182, servingDescription: "1 medium"),
        "orange": FoodEntry(caloriesPer100g: 47, proteinPer100g: 1, carbsPer100g: 12, fatPer100g: 0, defaultServingGrams: 131, servingDescription: "1 medium"),
        "blueberries": FoodEntry(caloriesPer100g: 57, proteinPer100g: 1, carbsPer100g: 14, fatPer100g: 0, defaultServingGrams: 148, servingDescription: "1 cup"),
        "strawberries": FoodEntry(caloriesPer100g: 32, proteinPer100g: 1, carbsPer100g: 8, fatPer100g: 0, defaultServingGrams: 152, servingDescription: "1 cup"),
        "grapes": FoodEntry(caloriesPer100g: 69, proteinPer100g: 1, carbsPer100g: 18, fatPer100g: 0, defaultServingGrams: 92, servingDescription: "1 cup"),
        "mango": FoodEntry(caloriesPer100g: 60, proteinPer100g: 1, carbsPer100g: 15, fatPer100g: 0, defaultServingGrams: 165, servingDescription: "1 cup"),
        "quinoa": FoodEntry(caloriesPer100g: 120, proteinPer100g: 4, carbsPer100g: 21, fatPer100g: 2, defaultServingGrams: 185, servingDescription: "1 cup cooked"),
        "bagel": FoodEntry(caloriesPer100g: 257, proteinPer100g: 10, carbsPer100g: 50, fatPer100g: 2, defaultServingGrams: 105, servingDescription: "1 bagel"),
        "tortilla": FoodEntry(caloriesPer100g: 218, proteinPer100g: 6, carbsPer100g: 36, fatPer100g: 5, defaultServingGrams: 64, servingDescription: "1 large"),
        "cereal": FoodEntry(caloriesPer100g: 379, proteinPer100g: 7, carbsPer100g: 84, fatPer100g: 1, defaultServingGrams: 30, servingDescription: "1 cup"),
        "granola": FoodEntry(caloriesPer100g: 471, proteinPer100g: 10, carbsPer100g: 64, fatPer100g: 20, defaultServingGrams: 55, servingDescription: "1/2 cup"),
        "pancake": FoodEntry(caloriesPer100g: 227, proteinPer100g: 6, carbsPer100g: 28, fatPer100g: 10, defaultServingGrams: 77, servingDescription: "1 large"),
        "pancakes": FoodEntry(caloriesPer100g: 227, proteinPer100g: 6, carbsPer100g: 28, fatPer100g: 10, defaultServingGrams: 77, servingDescription: "1 large"),
        "waffle": FoodEntry(caloriesPer100g: 291, proteinPer100g: 8, carbsPer100g: 33, fatPer100g: 14, defaultServingGrams: 75, servingDescription: "1 waffle"),
        "french toast": FoodEntry(caloriesPer100g: 229, proteinPer100g: 10, carbsPer100g: 24, fatPer100g: 10, defaultServingGrams: 65, servingDescription: "1 slice"),
        "corn": FoodEntry(caloriesPer100g: 86, proteinPer100g: 3, carbsPer100g: 19, fatPer100g: 1, defaultServingGrams: 90, servingDescription: "1 ear"),

        // Fats & Misc
        "avocado": FoodEntry(caloriesPer100g: 160, proteinPer100g: 2, carbsPer100g: 9, fatPer100g: 15, defaultServingGrams: 150, servingDescription: "1 whole"),
        "peanut butter": FoodEntry(caloriesPer100g: 588, proteinPer100g: 25, carbsPer100g: 20, fatPer100g: 50, defaultServingGrams: 32, servingDescription: "2 tbsp"),
        "almond butter": FoodEntry(caloriesPer100g: 614, proteinPer100g: 21, carbsPer100g: 19, fatPer100g: 56, defaultServingGrams: 32, servingDescription: "2 tbsp"),
        "cheese": FoodEntry(caloriesPer100g: 402, proteinPer100g: 25, carbsPer100g: 1, fatPer100g: 33, defaultServingGrams: 28, servingDescription: "1 slice"),
        "cheddar": FoodEntry(caloriesPer100g: 402, proteinPer100g: 25, carbsPer100g: 1, fatPer100g: 33, defaultServingGrams: 28, servingDescription: "1 slice"),
        "mozzarella": FoodEntry(caloriesPer100g: 280, proteinPer100g: 28, carbsPer100g: 3, fatPer100g: 17, defaultServingGrams: 28, servingDescription: "1 oz"),
        "cream cheese": FoodEntry(caloriesPer100g: 342, proteinPer100g: 6, carbsPer100g: 4, fatPer100g: 34, defaultServingGrams: 28, servingDescription: "2 tbsp"),
        "butter": FoodEntry(caloriesPer100g: 717, proteinPer100g: 1, carbsPer100g: 0, fatPer100g: 81, defaultServingGrams: 14, servingDescription: "1 tbsp"),
        "olive oil": FoodEntry(caloriesPer100g: 884, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 100, defaultServingGrams: 14, servingDescription: "1 tbsp"),
        "coconut oil": FoodEntry(caloriesPer100g: 862, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 100, defaultServingGrams: 14, servingDescription: "1 tbsp"),
        "nuts": FoodEntry(caloriesPer100g: 607, proteinPer100g: 20, carbsPer100g: 21, fatPer100g: 54, defaultServingGrams: 28, servingDescription: "1 oz"),
        "almonds": FoodEntry(caloriesPer100g: 579, proteinPer100g: 21, carbsPer100g: 22, fatPer100g: 50, defaultServingGrams: 28, servingDescription: "1 oz"),
        "walnuts": FoodEntry(caloriesPer100g: 654, proteinPer100g: 15, carbsPer100g: 14, fatPer100g: 65, defaultServingGrams: 28, servingDescription: "1 oz"),
        "cashews": FoodEntry(caloriesPer100g: 553, proteinPer100g: 18, carbsPer100g: 30, fatPer100g: 44, defaultServingGrams: 28, servingDescription: "1 oz"),
        "peanuts": FoodEntry(caloriesPer100g: 567, proteinPer100g: 26, carbsPer100g: 16, fatPer100g: 49, defaultServingGrams: 28, servingDescription: "1 oz"),
        "trail mix": FoodEntry(caloriesPer100g: 462, proteinPer100g: 14, carbsPer100g: 44, fatPer100g: 29, defaultServingGrams: 40, servingDescription: "1/4 cup"),
        "hummus": FoodEntry(caloriesPer100g: 166, proteinPer100g: 8, carbsPer100g: 14, fatPer100g: 10, defaultServingGrams: 30, servingDescription: "2 tbsp"),
        "guacamole": FoodEntry(caloriesPer100g: 160, proteinPer100g: 2, carbsPer100g: 9, fatPer100g: 15, defaultServingGrams: 30, servingDescription: "2 tbsp"),

        // Drinks
        "coffee": FoodEntry(caloriesPer100g: 1, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 0, defaultServingGrams: 240, servingDescription: "1 cup"),
        "latte": FoodEntry(caloriesPer100g: 56, proteinPer100g: 3, carbsPer100g: 5, fatPer100g: 3, defaultServingGrams: 240, servingDescription: "1 cup"),
        "milk": FoodEntry(caloriesPer100g: 42, proteinPer100g: 3, carbsPer100g: 5, fatPer100g: 1, defaultServingGrams: 240, servingDescription: "1 cup"),
        "whole milk": FoodEntry(caloriesPer100g: 61, proteinPer100g: 3, carbsPer100g: 5, fatPer100g: 3, defaultServingGrams: 240, servingDescription: "1 cup"),
        "almond milk": FoodEntry(caloriesPer100g: 15, proteinPer100g: 1, carbsPer100g: 1, fatPer100g: 1, defaultServingGrams: 240, servingDescription: "1 cup"),
        "oat milk": FoodEntry(caloriesPer100g: 47, proteinPer100g: 1, carbsPer100g: 7, fatPer100g: 2, defaultServingGrams: 240, servingDescription: "1 cup"),
        "juice": FoodEntry(caloriesPer100g: 45, proteinPer100g: 1, carbsPer100g: 10, fatPer100g: 0, defaultServingGrams: 240, servingDescription: "1 cup"),
        "orange juice": FoodEntry(caloriesPer100g: 45, proteinPer100g: 1, carbsPer100g: 10, fatPer100g: 0, defaultServingGrams: 240, servingDescription: "1 cup"),
        "smoothie": FoodEntry(caloriesPer100g: 54, proteinPer100g: 2, carbsPer100g: 10, fatPer100g: 1, defaultServingGrams: 350, servingDescription: "1 large"),
        "protein smoothie": FoodEntry(caloriesPer100g: 71, proteinPer100g: 7, carbsPer100g: 9, fatPer100g: 1, defaultServingGrams: 350, servingDescription: "1 large"),
        "soda": FoodEntry(caloriesPer100g: 41, proteinPer100g: 0, carbsPer100g: 11, fatPer100g: 0, defaultServingGrams: 355, servingDescription: "1 can"),
        "beer": FoodEntry(caloriesPer100g: 43, proteinPer100g: 0, carbsPer100g: 4, fatPer100g: 0, defaultServingGrams: 355, servingDescription: "1 can"),
        "wine": FoodEntry(caloriesPer100g: 83, proteinPer100g: 0, carbsPer100g: 3, fatPer100g: 0, defaultServingGrams: 148, servingDescription: "1 glass"),
        "energy drink": FoodEntry(caloriesPer100g: 45, proteinPer100g: 0, carbsPer100g: 11, fatPer100g: 0, defaultServingGrams: 250, servingDescription: "1 can"),

        // Meals
        "salad": FoodEntry(caloriesPer100g: 20, proteinPer100g: 1, carbsPer100g: 4, fatPer100g: 0, defaultServingGrams: 300, servingDescription: "1 large bowl"),
        "chicken salad": FoodEntry(caloriesPer100g: 110, proteinPer100g: 14, carbsPer100g: 4, fatPer100g: 5, defaultServingGrams: 200, servingDescription: "1 serving"),
        "sandwich": FoodEntry(caloriesPer100g: 175, proteinPer100g: 9, carbsPer100g: 18, fatPer100g: 7, defaultServingGrams: 200, servingDescription: "1 sandwich"),
        "burger": FoodEntry(caloriesPer100g: 225, proteinPer100g: 13, carbsPer100g: 18, fatPer100g: 11, defaultServingGrams: 200, servingDescription: "1 burger"),
        "cheeseburger": FoodEntry(caloriesPer100g: 250, proteinPer100g: 14, carbsPer100g: 18, fatPer100g: 14, defaultServingGrams: 215, servingDescription: "1 burger"),
        "pizza": FoodEntry(caloriesPer100g: 266, proteinPer100g: 11, carbsPer100g: 33, fatPer100g: 10, defaultServingGrams: 107, servingDescription: "1 slice"),
        "burrito": FoodEntry(caloriesPer100g: 177, proteinPer100g: 9, carbsPer100g: 22, fatPer100g: 6, defaultServingGrams: 285, servingDescription: "1 burrito"),
        "sushi": FoodEntry(caloriesPer100g: 143, proteinPer100g: 6, carbsPer100g: 21, fatPer100g: 4, defaultServingGrams: 170, servingDescription: "6 pieces"),
        "soup": FoodEntry(caloriesPer100g: 30, proteinPer100g: 2, carbsPer100g: 4, fatPer100g: 1, defaultServingGrams: 250, servingDescription: "1 bowl"),
        "chicken soup": FoodEntry(caloriesPer100g: 36, proteinPer100g: 4, carbsPer100g: 3, fatPer100g: 1, defaultServingGrams: 250, servingDescription: "1 bowl"),
        "wrap": FoodEntry(caloriesPer100g: 175, proteinPer100g: 9, carbsPer100g: 18, fatPer100g: 7, defaultServingGrams: 200, servingDescription: "1 wrap"),
        "taco": FoodEntry(caloriesPer100g: 210, proteinPer100g: 11, carbsPer100g: 21, fatPer100g: 10, defaultServingGrams: 78, servingDescription: "1 taco"),
        "tacos": FoodEntry(caloriesPer100g: 210, proteinPer100g: 11, carbsPer100g: 21, fatPer100g: 10, defaultServingGrams: 78, servingDescription: "1 taco"),
        "stir fry": FoodEntry(caloriesPer100g: 117, proteinPer100g: 8, carbsPer100g: 10, fatPer100g: 5, defaultServingGrams: 250, servingDescription: "1 serving"),
        "fried rice": FoodEntry(caloriesPer100g: 163, proteinPer100g: 5, carbsPer100g: 20, fatPer100g: 7, defaultServingGrams: 200, servingDescription: "1 serving"),
        "mac and cheese": FoodEntry(caloriesPer100g: 164, proteinPer100g: 6, carbsPer100g: 18, fatPer100g: 7, defaultServingGrams: 200, servingDescription: "1 serving"),
        "ramen": FoodEntry(caloriesPer100g: 436, proteinPer100g: 10, carbsPer100g: 62, fatPer100g: 17, defaultServingGrams: 85, servingDescription: "1 pack"),
        "noodles": FoodEntry(caloriesPer100g: 138, proteinPer100g: 5, carbsPer100g: 25, fatPer100g: 2, defaultServingGrams: 200, servingDescription: "1 cup cooked"),
        "chicken wings": FoodEntry(caloriesPer100g: 203, proteinPer100g: 18, carbsPer100g: 0, fatPer100g: 14, defaultServingGrams: 85, servingDescription: "3 wings"),
        "wings": FoodEntry(caloriesPer100g: 203, proteinPer100g: 18, carbsPer100g: 0, fatPer100g: 14, defaultServingGrams: 85, servingDescription: "3 wings"),
        "fries": FoodEntry(caloriesPer100g: 312, proteinPer100g: 3, carbsPer100g: 41, fatPer100g: 15, defaultServingGrams: 117, servingDescription: "1 medium"),
        "french fries": FoodEntry(caloriesPer100g: 312, proteinPer100g: 3, carbsPer100g: 41, fatPer100g: 15, defaultServingGrams: 117, servingDescription: "1 medium"),

        // Snacks & Desserts
        "protein bar": FoodEntry(caloriesPer100g: 350, proteinPer100g: 25, carbsPer100g: 40, fatPer100g: 10, defaultServingGrams: 60, servingDescription: "1 bar"),
        "granola bar": FoodEntry(caloriesPer100g: 471, proteinPer100g: 10, carbsPer100g: 64, fatPer100g: 20, defaultServingGrams: 42, servingDescription: "1 bar"),
        "chips": FoodEntry(caloriesPer100g: 536, proteinPer100g: 7, carbsPer100g: 53, fatPer100g: 35, defaultServingGrams: 28, servingDescription: "1 oz"),
        "popcorn": FoodEntry(caloriesPer100g: 375, proteinPer100g: 12, carbsPer100g: 74, fatPer100g: 4, defaultServingGrams: 28, servingDescription: "3 cups"),
        "chocolate": FoodEntry(caloriesPer100g: 546, proteinPer100g: 5, carbsPer100g: 60, fatPer100g: 31, defaultServingGrams: 40, servingDescription: "1 bar"),
        "dark chocolate": FoodEntry(caloriesPer100g: 546, proteinPer100g: 5, carbsPer100g: 60, fatPer100g: 31, defaultServingGrams: 40, servingDescription: "1 bar"),
        "ice cream": FoodEntry(caloriesPer100g: 207, proteinPer100g: 4, carbsPer100g: 24, fatPer100g: 11, defaultServingGrams: 132, servingDescription: "1 cup"),
        "cookie": FoodEntry(caloriesPer100g: 502, proteinPer100g: 5, carbsPer100g: 65, fatPer100g: 25, defaultServingGrams: 30, servingDescription: "1 cookie"),
        "cookies": FoodEntry(caloriesPer100g: 502, proteinPer100g: 5, carbsPer100g: 65, fatPer100g: 25, defaultServingGrams: 30, servingDescription: "1 cookie"),
        "brownie": FoodEntry(caloriesPer100g: 405, proteinPer100g: 5, carbsPer100g: 51, fatPer100g: 21, defaultServingGrams: 56, servingDescription: "1 piece"),
        "donut": FoodEntry(caloriesPer100g: 421, proteinPer100g: 5, carbsPer100g: 49, fatPer100g: 23, defaultServingGrams: 60, servingDescription: "1 donut"),
        "cake": FoodEntry(caloriesPer100g: 257, proteinPer100g: 3, carbsPer100g: 36, fatPer100g: 12, defaultServingGrams: 80, servingDescription: "1 slice"),
        "muffin": FoodEntry(caloriesPer100g: 340, proteinPer100g: 5, carbsPer100g: 45, fatPer100g: 16, defaultServingGrams: 113, servingDescription: "1 muffin"),
        "rice cake": FoodEntry(caloriesPer100g: 387, proteinPer100g: 8, carbsPer100g: 82, fatPer100g: 3, defaultServingGrams: 9, servingDescription: "1 cake"),

        // Vegetables
        "broccoli": FoodEntry(caloriesPer100g: 34, proteinPer100g: 3, carbsPer100g: 7, fatPer100g: 0, defaultServingGrams: 91, servingDescription: "1 cup"),
        "spinach": FoodEntry(caloriesPer100g: 23, proteinPer100g: 3, carbsPer100g: 4, fatPer100g: 0, defaultServingGrams: 30, servingDescription: "1 cup raw"),
        "kale": FoodEntry(caloriesPer100g: 49, proteinPer100g: 4, carbsPer100g: 9, fatPer100g: 1, defaultServingGrams: 67, servingDescription: "1 cup"),
        "carrots": FoodEntry(caloriesPer100g: 41, proteinPer100g: 1, carbsPer100g: 10, fatPer100g: 0, defaultServingGrams: 61, servingDescription: "1 medium"),
        "tomato": FoodEntry(caloriesPer100g: 18, proteinPer100g: 1, carbsPer100g: 4, fatPer100g: 0, defaultServingGrams: 123, servingDescription: "1 medium"),
        "cucumber": FoodEntry(caloriesPer100g: 15, proteinPer100g: 1, carbsPer100g: 4, fatPer100g: 0, defaultServingGrams: 52, servingDescription: "1/2 cup"),
        "bell pepper": FoodEntry(caloriesPer100g: 31, proteinPer100g: 1, carbsPer100g: 6, fatPer100g: 0, defaultServingGrams: 119, servingDescription: "1 medium"),
        "mushrooms": FoodEntry(caloriesPer100g: 22, proteinPer100g: 3, carbsPer100g: 3, fatPer100g: 0, defaultServingGrams: 70, servingDescription: "1 cup"),
        "onion": FoodEntry(caloriesPer100g: 40, proteinPer100g: 1, carbsPer100g: 9, fatPer100g: 0, defaultServingGrams: 110, servingDescription: "1 medium"),
        "asparagus": FoodEntry(caloriesPer100g: 20, proteinPer100g: 2, carbsPer100g: 4, fatPer100g: 0, defaultServingGrams: 134, servingDescription: "1 cup"),
        "green beans": FoodEntry(caloriesPer100g: 31, proteinPer100g: 2, carbsPer100g: 7, fatPer100g: 0, defaultServingGrams: 125, servingDescription: "1 cup"),
        "zucchini": FoodEntry(caloriesPer100g: 17, proteinPer100g: 1, carbsPer100g: 3, fatPer100g: 0, defaultServingGrams: 113, servingDescription: "1 medium"),
        "cauliflower": FoodEntry(caloriesPer100g: 25, proteinPer100g: 2, carbsPer100g: 5, fatPer100g: 0, defaultServingGrams: 107, servingDescription: "1 cup"),
        "edamame": FoodEntry(caloriesPer100g: 121, proteinPer100g: 12, carbsPer100g: 9, fatPer100g: 5, defaultServingGrams: 155, servingDescription: "1 cup"),

        // Legumes/Grains
        "black beans": FoodEntry(caloriesPer100g: 132, proteinPer100g: 9, carbsPer100g: 24, fatPer100g: 1, defaultServingGrams: 172, servingDescription: "1 cup"),
        "chickpeas": FoodEntry(caloriesPer100g: 164, proteinPer100g: 9, carbsPer100g: 27, fatPer100g: 3, defaultServingGrams: 164, servingDescription: "1 cup"),
        "lentils": FoodEntry(caloriesPer100g: 116, proteinPer100g: 9, carbsPer100g: 20, fatPer100g: 0, defaultServingGrams: 198, servingDescription: "1 cup"),
    ]

    // MARK: - Public API

    static func estimate(from text: String) -> NutritionInfo {
        estimate(from: text, weightGrams: nil)
    }

    static func estimate(from text: String, weightGrams: Int? = nil) -> NutritionInfo {
        let items = text.lowercased()
            .components(separatedBy: CharacterSet(charactersIn: ",;&+\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var totalCal = 0, totalProtein = 0, totalCarbs = 0, totalFat = 0
        var isFirstItem = true

        for item in items {
            let (quantity, foodKey) = parseQuantity(from: item)

            if let entry = matchFood(foodKey) {
                let grams: Int
                if isFirstItem, let w = weightGrams {
                    grams = w
                } else {
                    grams = entry.defaultServingGrams
                }

                totalCal += entry.caloriesPer100g * grams / 100 * quantity
                totalProtein += entry.proteinPer100g * grams / 100 * quantity
                totalCarbs += entry.carbsPer100g * grams / 100 * quantity
                totalFat += entry.fatPer100g * grams / 100 * quantity
            }

            isFirstItem = false
        }

        return NutritionInfo(calories: totalCal, protein: totalProtein, carbs: totalCarbs, fat: totalFat)
    }

    static func defaultServing(for text: String) -> (grams: Int, description: String)? {
        let items = text.lowercased()
            .components(separatedBy: CharacterSet(charactersIn: ",;&+\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard let first = items.first else { return nil }
        let (_, foodKey) = parseQuantity(from: first)
        guard let entry = matchFood(foodKey) else { return nil }
        return (grams: entry.defaultServingGrams, description: entry.servingDescription)
    }

    // MARK: - Private helpers

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

    private static func matchFood(_ text: String) -> FoodEntry? {
        let cleaned = text.trimmingCharacters(in: .whitespaces)

        // Exact match first
        if let entry = foodDatabase[cleaned] { return entry }

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
        case .weight: return "figure.stand"
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
    var savedFromAuthor: String?    // Display name of who created it
    var savedFromUsername: String?   // @username of creator

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
        lastUsedAt: Date? = nil,
        savedFromAuthor: String? = nil,
        savedFromUsername: String? = nil
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
        self.savedFromAuthor = savedFromAuthor
        self.savedFromUsername = savedFromUsername
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

    static func fromSharedWorkout(_ workout: SharedWorkoutData, userId: UUID) -> WorkoutTemplate {
        let templateExercises = workout.exercises.enumerated().map { index, exercise in
            TemplateExercise(
                name: exercise.name,
                muscleGroup: exercise.muscleGroup,
                suggestedSets: exercise.sets.count,
                suggestedReps: "\(exercise.sets.first?.reps ?? 10)",
                suggestedWeight: exercise.sets.first?.weight,
                order: index
            )
        }
        return WorkoutTemplate(
            odId: userId,
            name: "\(workout.title) (from @\(workout.authorUsername))",
            workoutType: WorkoutType(rawValue: workout.workoutType) ?? .push,
            exercises: templateExercises,
            estimatedDuration: workout.estimatedDuration
        )
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
    case comebackCardShown = "comeback_card_shown"
    case learnItemSaved = "learn_item_saved"
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

// MARK: - Movement Pattern

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
    case jump = "Jump"
    case sprint = "Sprint"
    case throw_ = "Throw"
    case kick = "Kick"
    case swim = "Swim"
    case cycle = "Cycle"
    case flow = "Flow"
    case strike = "Strike"

    var baseMotionId: String {
        rawValue.lowercased().replacingOccurrences(of: " ", with: "_")
    }
}

// MARK: - Engagement Tracking (Feed Algorithm)

/// Tracks per-user engagement with each post for personalization signals
@Model
final class PostEngagement {
    var id: UUID
    var postId: UUID
    var userId: UUID
    var watchTimeSec: Double
    var liked: Bool
    var commented: Bool
    var shared: Bool
    var saved: Bool
    var followed: Bool
    var timestamp: Date
    var completionCount: Int = 0
    var maxCompletionRatio: Double = 0
    var skipped: Bool = false
    var notInterested: Bool = false

    init(
        id: UUID = UUID(),
        postId: UUID = UUID(),
        userId: UUID = UUID(),
        watchTimeSec: Double = 0,
        liked: Bool = false,
        commented: Bool = false,
        shared: Bool = false,
        saved: Bool = false,
        followed: Bool = false,
        timestamp: Date = Date(),
        completionCount: Int = 0,
        maxCompletionRatio: Double = 0,
        skipped: Bool = false,
        notInterested: Bool = false
    ) {
        self.id = id
        self.postId = postId
        self.userId = userId
        self.watchTimeSec = watchTimeSec
        self.liked = liked
        self.commented = commented
        self.shared = shared
        self.saved = saved
        self.followed = followed
        self.timestamp = timestamp
        self.completionCount = completionCount
        self.maxCompletionRatio = maxCompletionRatio
        self.skipped = skipped
        self.notInterested = notInterested
    }
}

/// Stores computed interest weights per user for feed personalization
@Model
final class UserInterestProfile {
    var id: UUID
    var userId: UUID
    var workoutTypeWeightsJSON: String
    var authorWeightsJSON: String
    var contentFormatWeightsJSON: String
    var hashtagWeightsJSON: String = "{}"
    var emotionWeightsJSON: String = "{}"
    var negativeWorkoutTypeWeightsJSON: String = "{}"
    var negativeAuthorWeightsJSON: String = "{}"
    var avgSessionTimeSec: Double
    var lastUpdated: Date

    var workoutTypeWeights: [String: Double] {
        get { Self.decodeWeights(workoutTypeWeightsJSON) }
        set { workoutTypeWeightsJSON = Self.encodeWeights(newValue) }
    }

    var authorWeights: [String: Double] {
        get { Self.decodeWeights(authorWeightsJSON) }
        set { authorWeightsJSON = Self.encodeWeights(newValue) }
    }

    var contentFormatWeights: [String: Double] {
        get { Self.decodeWeights(contentFormatWeightsJSON) }
        set { contentFormatWeightsJSON = Self.encodeWeights(newValue) }
    }

    var hashtagWeights: [String: Double] {
        get { Self.decodeWeights(hashtagWeightsJSON) }
        set { hashtagWeightsJSON = Self.encodeWeights(newValue) }
    }

    var emotionWeights: [String: Double] {
        get { Self.decodeWeights(emotionWeightsJSON) }
        set { emotionWeightsJSON = Self.encodeWeights(newValue) }
    }

    var negativeWorkoutTypeWeights: [String: Double] {
        get { Self.decodeWeights(negativeWorkoutTypeWeightsJSON) }
        set { negativeWorkoutTypeWeightsJSON = Self.encodeWeights(newValue) }
    }

    var negativeAuthorWeights: [String: Double] {
        get { Self.decodeWeights(negativeAuthorWeightsJSON) }
        set { negativeAuthorWeightsJSON = Self.encodeWeights(newValue) }
    }

    init(
        id: UUID = UUID(),
        userId: UUID = UUID(),
        workoutTypeWeights: [String: Double] = [:],
        authorWeights: [String: Double] = [:],
        contentFormatWeights: [String: Double] = [:],
        hashtagWeights: [String: Double] = [:],
        emotionWeights: [String: Double] = [:],
        negativeWorkoutTypeWeights: [String: Double] = [:],
        negativeAuthorWeights: [String: Double] = [:],
        avgSessionTimeSec: Double = 0,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.workoutTypeWeightsJSON = Self.encodeWeights(workoutTypeWeights)
        self.authorWeightsJSON = Self.encodeWeights(authorWeights)
        self.contentFormatWeightsJSON = Self.encodeWeights(contentFormatWeights)
        self.hashtagWeightsJSON = Self.encodeWeights(hashtagWeights)
        self.emotionWeightsJSON = Self.encodeWeights(emotionWeights)
        self.negativeWorkoutTypeWeightsJSON = Self.encodeWeights(negativeWorkoutTypeWeights)
        self.negativeAuthorWeightsJSON = Self.encodeWeights(negativeAuthorWeights)
        self.avgSessionTimeSec = avgSessionTimeSec
        self.lastUpdated = lastUpdated
    }

    private static func encodeWeights(_ weights: [String: Double]) -> String {
        (try? String(data: JSONEncoder().encode(weights), encoding: .utf8)) ?? "{}"
    }

    private static func decodeWeights(_ json: String) -> [String: Double] {
        guard let data = json.data(using: .utf8) else { return [:] }
        return (try? JSONDecoder().decode([String: Double].self, from: data)) ?? [:]
    }
}

// MARK: - Training Plan (AI-generated periodized plans)

struct TrainingPlanExercise: Codable, Identifiable {
    var id = UUID()
    var name: String
    var sets: Int
    var reps: Int
    var weight: Double?
    var rpe: Int?
    var notes: String?
}

struct TrainingPlanDay: Codable, Identifiable {
    var id = UUID()
    var dayNumber: Int
    var label: String // e.g. "Push Day", "Upper Body"
    var workoutType: String
    var exercises: [TrainingPlanExercise]
    var isRestDay: Bool
}

struct TrainingPlanWeek: Codable, Identifiable {
    var id = UUID()
    var weekNumber: Int
    var focus: String // e.g. "Volume", "Intensity", "Deload"
    var days: [TrainingPlanDay]
}

@Model
final class TrainingPlan {
    var id: UUID
    var userId: UUID
    var title: String
    var weeksJSON: Data? // Encoded [TrainingPlanWeek]
    var currentWeek: Int
    var currentDay: Int
    var isActive: Bool
    var createdAt: Date
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        userId: UUID = UUID(),
        title: String = "AI Training Plan",
        weeks: [TrainingPlanWeek] = [],
        currentWeek: Int = 1,
        currentDay: Int = 1,
        isActive: Bool = true,
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.weeksJSON = try? JSONEncoder().encode(weeks)
        self.currentWeek = currentWeek
        self.currentDay = currentDay
        self.isActive = isActive
        self.createdAt = createdAt
        self.completedAt = completedAt
    }

    var weeks: [TrainingPlanWeek] {
        get {
            guard let data = weeksJSON else { return [] }
            return (try? JSONDecoder().decode([TrainingPlanWeek].self, from: data)) ?? []
        }
        set {
            weeksJSON = try? JSONEncoder().encode(newValue)
        }
    }

    var totalWeeks: Int { weeks.count }

    var currentDayPlan: TrainingPlanDay? {
        guard currentWeek > 0, currentWeek <= weeks.count else { return nil }
        let week = weeks[currentWeek - 1]
        guard currentDay > 0, currentDay <= week.days.count else { return nil }
        return week.days[currentDay - 1]
    }
}

// MARK: - Coach Notes (Hybrid Coaching)

enum CoachNotePriority: String, Codable, CaseIterable {
    case normal
    case important
    case urgent
}

@Model
final class CoachNote {
    var id: UUID
    var coachId: UUID
    var memberId: UUID
    var noteText: String
    var priority: String // Stored as raw value
    var exerciseName: String?
    var dayNumber: Int?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        coachId: UUID = UUID(),
        memberId: UUID = UUID(),
        noteText: String = "",
        priority: CoachNotePriority = .normal,
        exerciseName: String? = nil,
        dayNumber: Int? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.coachId = coachId
        self.memberId = memberId
        self.noteText = noteText
        self.priority = priority.rawValue
        self.exerciseName = exerciseName
        self.dayNumber = dayNumber
        self.createdAt = createdAt
    }

    var notePriority: CoachNotePriority {
        get { CoachNotePriority(rawValue: priority) ?? .normal }
        set { priority = newValue.rawValue }
    }
}

// MARK: - Exercise Leaderboard (Gym Segments)

@Model
final class ExerciseLeaderboardEntry {
    var id: UUID
    var clubId: UUID
    var userId: UUID
    var userName: String
    var exerciseName: String
    var estimated1RM: Double
    var weightClass: String?
    var ageGroup: String?
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        clubId: UUID = UUID(),
        userId: UUID = UUID(),
        userName: String = "",
        exerciseName: String = "",
        estimated1RM: Double = 0,
        weightClass: String? = nil,
        ageGroup: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.clubId = clubId
        self.userId = userId
        self.userName = userName
        self.exerciseName = exerciseName
        self.estimated1RM = estimated1RM
        self.weightClass = weightClass
        self.ageGroup = ageGroup
        self.updatedAt = updatedAt
    }
}

// MARK: - Squad Member Volume (Squad Leaderboard)

struct SquadMemberVolume: Codable, Identifiable {
    var id = UUID()
    var userId: UUID
    var userName: String
    var totalVolume: Double
    var totalSets: Int
    var workoutCount: Int
    var weekStart: Date
}

// MARK: - User Goals

@Model
final class UserGoal {
    var id: UUID
    var userId: UUID
    var type: String          // "exercise" or "bodyweight"
    var exerciseName: String? // nil for bodyweight goals
    var targetWeight: Double
    var targetReps: Int?      // nil for bodyweight goals
    var createdAt: Date
    var achievedAt: Date?

    init(userId: UUID, type: String, exerciseName: String? = nil, targetWeight: Double, targetReps: Int? = nil) {
        self.id = UUID()
        self.userId = userId
        self.type = type
        self.exerciseName = exerciseName
        self.targetWeight = targetWeight
        self.targetReps = targetReps
        self.createdAt = Date()
        self.achievedAt = nil
    }

    var isExerciseGoal: Bool { type == "exercise" }
    var isBodyweightGoal: Bool { type == "bodyweight" }
    var isAchieved: Bool { achievedAt != nil }
}

// MARK: - Challenge Template (non-persisted)

struct ChallengeTemplate: Codable, Identifiable {
    var id: UUID
    var title: String
    var description: String
    var scope: ChallengeScope
    var goalType: ChallengeGoalType
    var goalTarget: Int
    var durationDays: Int
    var requiredConsistencyState: ConsistencyState?
    var xpReward: Int
}

// MARK: - Content Privacy & Feed Item Type

enum ContentPrivacy: String, Codable {
    case publicFeed = "Public"
    case friends = "Friends"
    case `private` = "Private"
    case pod = "Pod"
    case privateOnly = "Private Only"
    case club = "Club"
}

enum FeedItemType: String, Codable {
    case workoutShare = "Workout Share"
    case manualPost = "Manual Post"
    case prCelebration = "PR Celebration"
    case milestone = "Milestone"
    case milestoneAchieved = "Milestone Achieved"
    case comebackStarted = "Comeback Started"
    case podSummary = "Pod Summary"
    case prMoment = "PR Moment"
}

// MARK: - Notification Log

@Model
final class NotificationLog {
    var id: UUID
    var userId: UUID
    var category: String
    var sentAt: Date
    var title: String
    var readAt: Date?

    init(id: UUID = UUID(), userId: UUID = UUID(), category: String = "", sentAt: Date = Date(), title: String = "", readAt: Date? = nil) {
        self.id = id
        self.userId = userId
        self.category = category
        self.sentAt = sentAt
        self.title = title
        self.readAt = readAt
    }
}

// MARK: - Workout Adaptation

enum AdaptationReason: String, Codable {
    case plateau = "Plateau"
    case fatigue = "Fatigue"
    case recovery = "Recovery"
    case progression = "Progression"
}

@Model
final class WorkoutAdaptation {
    var id: UUID
    var userId: UUID
    var workoutDate: Date
    var reason: AdaptationReason
    var originalExercise: String?
    var adaptedExercise: String?
    var details: String
    var createdAt: Date

    init(id: UUID = UUID(), userId: UUID = UUID(), workoutDate: Date = Date(), reason: AdaptationReason = .progression, originalExercise: String? = nil, adaptedExercise: String? = nil, details: String = "", createdAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.workoutDate = workoutDate
        self.reason = reason
        self.originalExercise = originalExercise
        self.adaptedExercise = adaptedExercise
        self.details = details
        self.createdAt = createdAt
    }
}

// MARK: - Scheduled Plan Day

enum PlanDayStatus: String, Codable {
    case planned, completed, missed, moved, shortened, swapped, rest, recovery, comeback, rebalanced
}

@Model
final class ScheduledPlanDay {
    var id: UUID
    var planId: UUID
    var planWeekNumber: Int
    var planDayNumber: Int
    var dayOfWeek: Int // 1=Sun..7=Sat
    var scheduledDate: Date
    var originalDate: Date?
    var status: String // PlanDayStatus rawValue
    var label: String
    var workoutType: String
    var isRestDay: Bool
    var exercisesData: Data? // JSON-encoded [TrainingPlanExercise]
    var workoutId: UUID?

    var dayStatus: PlanDayStatus {
        get { PlanDayStatus(rawValue: status) ?? .planned }
        set { status = newValue.rawValue }
    }

    var exercises: [TrainingPlanExercise] {
        get {
            guard let data = exercisesData else { return [] }
            return (try? JSONDecoder().decode([TrainingPlanExercise].self, from: data)) ?? []
        }
        set {
            exercisesData = try? JSONEncoder().encode(newValue)
        }
    }

    init(
        id: UUID = UUID(),
        planId: UUID = UUID(),
        planWeekNumber: Int = 1,
        planDayNumber: Int = 1,
        dayOfWeek: Int = 1,
        scheduledDate: Date = Date(),
        originalDate: Date? = nil,
        status: PlanDayStatus = .planned,
        label: String = "",
        workoutType: String = "",
        isRestDay: Bool = false,
        exercises: [TrainingPlanExercise] = [],
        workoutId: UUID? = nil
    ) {
        self.id = id
        self.planId = planId
        self.planWeekNumber = planWeekNumber
        self.planDayNumber = planDayNumber
        self.dayOfWeek = dayOfWeek
        self.scheduledDate = scheduledDate
        self.originalDate = originalDate
        self.status = status.rawValue
        self.label = label
        self.workoutType = workoutType
        self.isRestDay = isRestDay
        self.exercisesData = try? JSONEncoder().encode(exercises)
        self.workoutId = workoutId
    }
}

// MARK: - Milestone Event

@Model
final class MilestoneEvent {
    var id: UUID
    var userId: UUID
    var type: String
    var title: String
    var createdAt: Date

    var milestoneDescription: String

    init(id: UUID = UUID(), userId: UUID = UUID(), type: String = "", title: String = "", milestoneDescription: String = "", createdAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.type = type
        self.title = title
        self.milestoneDescription = milestoneDescription
        self.createdAt = createdAt
    }
}

enum MilestoneType: String, Codable {
    case podGoalHit = "Pod Goal Hit"
    case streakWeek = "Streak Week"
    case firstPR = "First PR"
    case comebackComplete = "Comeback Complete"
    case firstWorkout = "First Workout"
    case firstFullWeek = "First Full Week"
    case consistencyStreak7 = "Consistency Streak 7"
    case consistencyStreak30 = "Consistency Streak 30"
}

// MARK: - Club Admin Action

enum ClubAdminAction: String, Codable {
    case kick = "Kick"
    case ban = "Ban"
    case promote = "Promote"
    case demote = "Demote"
}

// MARK: - User Relationship

enum UserRelationship: String, Codable {
    case none = "None"
    case friend = "Friend"
    case blocked = "Blocked"
    case podMate = "Pod Mate"
    case clubMate = "Club Mate"
}

// MARK: - Blocked User

@Model
final class BlockedUser {
    var id: UUID
    var userId: UUID
    var blockedUserId: UUID
    var createdAt: Date

    init(
        id: UUID = UUID(),
        userId: UUID,
        blockedUserId: UUID,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.blockedUserId = blockedUserId
        self.createdAt = createdAt
    }
}

// MARK: - Muted User

@Model
final class MutedUser {
    var id: UUID
    var userId: UUID
    var mutedUserId: UUID
    var createdAt: Date

    init(
        id: UUID = UUID(),
        userId: UUID,
        mutedUserId: UUID,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.mutedUserId = mutedUserId
        self.createdAt = createdAt
    }
}

// MARK: - Content Report

@Model
final class ContentReport {
    var id: UUID
    var reporterId: UUID
    var contentType: String
    var contentId: UUID
    var reason: String
    var details: String?
    var createdAt: Date
    var resolved: Bool

    init(
        id: UUID = UUID(),
        reporterId: UUID,
        contentType: String,
        contentId: UUID,
        reason: String,
        details: String? = nil,
        createdAt: Date = Date(),
        resolved: Bool = false
    ) {
        self.id = id
        self.reporterId = reporterId
        self.contentType = contentType
        self.contentId = contentId
        self.reason = reason
        self.details = details
        self.createdAt = createdAt
        self.resolved = resolved
    }
}

// MARK: - Beginner Support Profile

struct BeginnerSupportProfile {
    var preferredTrainingTime: String = "flexible"
    var daysPerWeek: Int = 3
    var gymType: String = "commercial"
    var confidenceLevel: Int = 1
}

// ExtendedExerciseDatabase and ExerciseMetadata are now in ExerciseDatabase.swift
