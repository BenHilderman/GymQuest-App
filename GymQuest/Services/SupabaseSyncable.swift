//
//  SupabaseSyncable.swift
//  GymQuest
//
//  Sync status, syncable protocol, and all Codable DTOs for Supabase tables.
//

import Foundation

// MARK: - Sync Status

enum SyncStatus: String, Codable {
    case local
    case pending
    case synced
    case conflict
}

// MARK: - Syncable Protocol

protocol SupabaseSyncable {
    var id: UUID { get }
    var updatedAt: Date { get }
    var syncStatusRaw: String { get set }
    func toDTO() -> Encodable
}

// MARK: - Profile DTO

struct ProfileDTO: Codable {
    let id: UUID
    let username: String
    let displayName: String
    let email: String?
    let profilePhotoUrl: String?
    let isPremium: Bool
    let fitnessGoal: String?
    let xp: Int
    let level: Int
    let followerCount: Int
    let followingCount: Int
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case email
        case profilePhotoUrl = "profile_photo_url"
        case isPremium = "is_premium"
        case fitnessGoal = "fitness_goal"
        case xp
        case level
        case followerCount = "follower_count"
        case followingCount = "following_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Post DTO

struct PostDTO: Codable {
    let id: UUID
    let authorId: UUID
    let authorName: String
    let authorUsername: String
    let caption: String?
    let workoutType: String?
    let duration: Int?
    let setCount: Int?
    let exerciseHighlight: String?
    let songTitle: String?
    let artistName: String?
    let mediaUrls: [String]?
    let mediaItems: String?
    let likeCount: Int
    let commentCount: Int
    let isDeleted: Bool
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case authorName = "author_name"
        case authorUsername = "author_username"
        case caption
        case workoutType = "workout_type"
        case duration
        case setCount = "set_count"
        case exerciseHighlight = "exercise_highlight"
        case songTitle = "song_title"
        case artistName = "artist_name"
        case mediaUrls = "media_urls"
        case mediaItems = "media_items"
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case isDeleted = "is_deleted"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Serialized Media Item

/// JSON-serializable snapshot of a PostMedia entry for Supabase round-trips.
/// Preserves per-clip metadata (type, caption, exercise linkage, order) alongside
/// the uploaded media URL, so a downloaded post can reconstruct its carousel.
struct SerializedMediaItem: Codable {
    let id: UUID
    let mediaType: String
    let caption: String?
    let exerciseName: String?
    let exerciseIndex: Int?
    let order: Int

    init(from media: PostMedia, order: Int) {
        self.id = media.id
        self.mediaType = media.mediaType.rawValue
        self.caption = media.caption
        self.exerciseName = media.exerciseName
        self.exerciseIndex = media.exerciseIndex
        self.order = order
    }
}

// MARK: - Comment DTO

struct CommentDTO: Codable {
    let id: UUID
    let postId: UUID
    let authorId: UUID
    let authorName: String
    let authorUsername: String
    let content: String
    let parentCommentId: UUID?
    let likeCount: Int
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case authorId = "author_id"
        case authorName = "author_name"
        case authorUsername = "author_username"
        case content
        case parentCommentId = "parent_comment_id"
        case likeCount = "like_count"
        case createdAt = "created_at"
    }
}

// MARK: - Like DTO

struct LikeDTO: Codable {
    let id: UUID?
    let postId: UUID
    let userId: UUID
    let userName: String
    let createdAt: Date?

    init(id: UUID? = nil, postId: UUID, userId: UUID, userName: String, createdAt: Date? = nil) {
        self.id = id
        self.postId = postId
        self.userId = userId
        self.userName = userName
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case userId = "user_id"
        case userName = "user_name"
        case createdAt = "created_at"
    }
}

// MARK: - Reaction DTO

struct ReactionDTO: Codable {
    let id: UUID?
    let userId: UUID
    let userUsername: String
    let targetType: String
    let targetId: UUID
    let reactionType: String
    let createdAt: Date?

    init(id: UUID? = nil, userId: UUID, userUsername: String, targetType: String, targetId: UUID, reactionType: String, createdAt: Date? = nil) {
        self.id = id
        self.userId = userId
        self.userUsername = userUsername
        self.targetType = targetType
        self.targetId = targetId
        self.reactionType = reactionType
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case userUsername = "user_username"
        case targetType = "target_type"
        case targetId = "target_id"
        case reactionType = "reaction_type"
        case createdAt = "created_at"
    }
}

// MARK: - Follow DTO

struct FollowDTO: Codable {
    let id: UUID?
    let followerId: UUID
    let followingId: UUID
    let createdAt: Date?

    init(id: UUID? = nil, followerId: UUID, followingId: UUID, createdAt: Date? = nil) {
        self.id = id
        self.followerId = followerId
        self.followingId = followingId
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case followerId = "follower_id"
        case followingId = "following_id"
        case createdAt = "created_at"
    }
}

// MARK: - Squad DTO

struct SquadDTO: Codable {
    let id: UUID
    let name: String
    let creatorId: UUID
    let memberIds: [UUID]
    let inviteCode: String
    let streakWeeks: Int
    let xpMultiplier: Double
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case creatorId = "creator_id"
        case memberIds = "member_ids"
        case inviteCode = "invite_code"
        case streakWeeks = "streak_weeks"
        case xpMultiplier = "xp_multiplier"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Pod DTO

struct PodDTO: Codable {
    let id: UUID
    let name: String
    let creatorId: UUID
    let memberIds: [UUID]
    let inviteCode: String
    let level: String
    let lifecycle: String
    let maxMembers: Int
    let weeklyWorkoutTarget: Int
    let streakWeeks: Int
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case creatorId = "creator_id"
        case memberIds = "member_ids"
        case inviteCode = "invite_code"
        case level
        case lifecycle
        case maxMembers = "max_members"
        case weeklyWorkoutTarget = "weekly_workout_target"
        case streakWeeks = "streak_weeks"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Club DTO

struct ClubDTO: Codable {
    let id: UUID
    let name: String
    let description: String?
    let location: String?
    let creatorId: UUID
    let adminIds: [UUID]
    let memberIds: [UUID]
    let joinType: String
    let category: String?
    let memberCount: Int
    let isVerified: Bool
    let imageUrl: String?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case location
        case creatorId = "creator_id"
        case adminIds = "admin_ids"
        case memberIds = "member_ids"
        case joinType = "join_type"
        case category
        case memberCount = "member_count"
        case isVerified = "is_verified"
        case imageUrl = "image_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Club Post DTO

struct ClubPostDTO: Codable {
    let id: UUID
    let clubId: UUID
    let authorId: UUID
    let authorName: String
    let authorUsername: String
    let content: String?
    let photoUrl: String?
    let likeCount: Int
    let commentCount: Int
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case clubId = "club_id"
        case authorId = "author_id"
        case authorName = "author_name"
        case authorUsername = "author_username"
        case content
        case photoUrl = "photo_url"
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case createdAt = "created_at"
    }
}

// MARK: - Notification DTO

struct NotificationDTO: Codable {
    let id: UUID?
    let userId: UUID
    let type: String
    let fromId: UUID?
    let fromName: String?
    let fromUsername: String?
    let targetId: UUID?
    let targetType: String?
    let message: String?
    let isRead: Bool
    let createdAt: Date?

    init(id: UUID? = nil, userId: UUID, type: String, fromId: UUID? = nil, fromName: String? = nil, fromUsername: String? = nil, targetId: UUID? = nil, targetType: String? = nil, message: String? = nil, isRead: Bool = false, createdAt: Date? = nil) {
        self.id = id
        self.userId = userId
        self.type = type
        self.fromId = fromId
        self.fromName = fromName
        self.fromUsername = fromUsername
        self.targetId = targetId
        self.targetType = targetType
        self.message = message
        self.isRead = isRead
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type
        case fromId = "from_id"
        case fromName = "from_name"
        case fromUsername = "from_username"
        case targetId = "target_id"
        case targetType = "target_type"
        case message
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}

// MARK: - Workout DTO

struct WorkoutDTO: Codable {
    let id: UUID
    let userId: UUID
    let workoutType: String
    let title: String?
    let duration: Int
    let totalVolume: Double
    let setCount: Int
    let exerciseCount: Int
    let caloriesBurned: Int?
    let notes: String?
    let startedAt: Date
    let completedAt: Date?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case workoutType = "workout_type"
        case title
        case duration
        case totalVolume = "total_volume"
        case setCount = "set_count"
        case exerciseCount = "exercise_count"
        case caloriesBurned = "calories_burned"
        case notes
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case createdAt = "created_at"
    }
}

// MARK: - Workout Exercise DTO

struct WorkoutExerciseDTO: Codable {
    let id: UUID
    let workoutId: UUID
    let name: String
    let muscleGroup: String?
    let exerciseOrder: Int
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case workoutId = "workout_id"
        case name
        case muscleGroup = "muscle_group"
        case exerciseOrder = "exercise_order"
        case notes
    }
}

// MARK: - Exercise Set DTO

struct ExerciseSetDTO: Codable {
    let id: UUID
    let exerciseId: UUID
    let setOrder: Int
    let reps: Int
    let weight: Double
    let isCompleted: Bool
    let rpe: Int?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case exerciseId = "exercise_id"
        case setOrder = "set_order"
        case reps
        case weight
        case isCompleted = "is_completed"
        case rpe
        case createdAt = "created_at"
    }
}

// MARK: - Workout Check-In DTO (Phase 8D)

struct CheckInDTO: Codable {
    let id: UUID
    let userId: UUID
    let userName: String
    let userUsername: String
    let workoutType: String
    let durationMinutes: Int
    let note: String?
    let withFriends: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case userName = "user_name"
        case userUsername = "user_username"
        case workoutType = "workout_type"
        case durationMinutes = "duration_minutes"
        case note
        case withFriends = "with_friends"
        case createdAt = "created_at"
    }
}

// MARK: - Presence DTO (Phase 8A)

struct PresenceDTO: Codable {
    let userId: UUID
    let status: String
    let workoutType: String?
    let startedAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case status
        case workoutType = "workout_type"
        case startedAt = "started_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Analytics Event DTO

struct AnalyticsEventDTO: Codable {
    let id: UUID?
    let userId: UUID?
    let eventType: String
    let metadata: String?
    let createdAt: Date?

    init(id: UUID? = nil, userId: UUID? = nil, eventType: String, metadata: String? = nil, createdAt: Date? = nil) {
        self.id = id
        self.userId = userId
        self.eventType = eventType
        self.metadata = metadata
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case eventType = "event_type"
        case metadata
        case createdAt = "created_at"
    }
}
