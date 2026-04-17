import Foundation
import SwiftData
#if canImport(Supabase)
import Supabase
#endif

// MARK: - Feed Content Service (System 7)
// Feed Creation Rules: auto-generation, validation, and rate limiting for feed posts.

@MainActor
final class FeedContentService: ObservableObject {

    static let shared = FeedContentService()

    private var modelContext: ModelContext?

    // MARK: - Rate Limiting State

    /// Tracks timestamps of posts per user for rate limiting (userId -> [timestamp])
    private var postTimestamps: [UUID: [Date]] = [:]

    private static let maxPostsPerDay = 5
    private static let cooldownInterval: TimeInterval = 60 // seconds
    private static let captionMaxLength = 500

    private init() {}

    // MARK: - Configuration

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Input Sanitization

    /// Strips HTML-unsafe characters and trims whitespace to prevent injection.
    static func sanitize(_ input: String) -> String {
        input
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Post Creation

    /// Creates a draft workout share post. The user can edit or discard before publishing.
    func createWorkoutShareDraft(
        workout: Workout,
        authorId: UUID,
        authorName: String,
        authorUsername: String
    ) -> Post {
        let exerciseNames = workout.exercises.map { $0.name }
        let highlight = exerciseNames.first

        let caption = Self.sanitize(buildWorkoutCaption(workout: workout))

        let post = Post(
            authorId: authorId,
            authorName: authorName,
            authorUsername: authorUsername,
            caption: caption,
            workoutType: workout.type.rawValue,
            duration: workout.duration,
            setCount: workout.totalSets,
            exerciseHighlight: highlight
        )

        return post
    }

    /// Creates a milestone post from a surfaced MilestoneEvent.
    func createMilestonePost(
        milestone: MilestoneEvent,
        authorId: UUID,
        authorName: String,
        authorUsername: String
    ) -> Post {
        let post = Post(
            authorId: authorId,
            authorName: authorName,
            authorUsername: authorUsername,
            caption: Self.sanitize("\(milestone.title) — \(milestone.milestoneDescription)")
        )

        return post
    }

    /// Creates a comeback post for the first workout after a COMEBACK consistency state.
    func createComebackPost(
        authorId: UUID,
        authorName: String,
        authorUsername: String
    ) -> Post {
        let post = Post(
            authorId: authorId,
            authorName: authorName,
            authorUsername: authorUsername,
            caption: Self.sanitize("Back at it! Starting the comeback.")
        )

        return post
    }

    /// Creates a PR moment post.
    func createPRPost(
        exerciseName: String,
        value: String,
        authorId: UUID,
        authorName: String,
        authorUsername: String
    ) -> Post {
        let post = Post(
            authorId: authorId,
            authorName: authorName,
            authorUsername: authorUsername,
            caption: Self.sanitize("New PR on \(exerciseName): \(value)"),
            exerciseHighlight: exerciseName
        )

        return post
    }

    /// Creates a pod weekly summary post.
    func createPodWeeklySummary(
        podName: String,
        membersTrained: Int,
        totalMembers: Int,
        weeklyTarget: Int,
        authorId: UUID,
        authorName: String,
        authorUsername: String
    ) -> Post {
        let caption = Self.sanitize("\(podName) weekly summary: \(membersTrained)/\(totalMembers) members trained this week (target: \(weeklyTarget)).")

        let post = Post(
            authorId: authorId,
            authorName: authorName,
            authorUsername: authorUsername,
            caption: caption
        )

        return post
    }

    // MARK: - Validation

    /// Validates a post meets content requirements.
    /// Returns (valid, error) where error is nil when valid.
    func validatePost(_ post: Post) -> (valid: Bool, error: String?) {
        // Caption length check
        if post.caption.count > Self.captionMaxLength {
            return (false, "Caption exceeds \(Self.captionMaxLength) characters.")
        }

        // Must have at least one form of content
        let hasCaption = !post.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasPhoto = post.photoData != nil
        let hasVideo = post.videoData != nil
        let hasWorkoutData = post.workoutType != nil || post.duration != nil || post.setCount != nil

        if !hasCaption && !hasPhoto && !hasVideo && !hasWorkoutData {
            return (false, "Post must have a caption, photo, video, or workout data.")
        }

        return (true, nil)
    }

    // MARK: - Rate Limiting

    /// Returns true if the user is under the rate limit (max 5 posts/day, 60s cooldown).
    func checkRateLimit(userId: UUID) -> Bool {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)

        // Clean up old entries and keep only today's timestamps
        var timestamps = postTimestamps[userId] ?? []
        timestamps = timestamps.filter { $0 >= startOfDay }

        // Check daily limit
        if timestamps.count >= Self.maxPostsPerDay {
            return false
        }

        // Check cooldown (last post must be at least 60s ago)
        if let lastPost = timestamps.last, now.timeIntervalSince(lastPost) < Self.cooldownInterval {
            return false
        }

        return true
    }

    /// Records a post timestamp for rate limiting. Call after a post is successfully published.
    func recordPost(userId: UUID) {
        var timestamps = postTimestamps[userId] ?? []
        timestamps.append(Date())
        postTimestamps[userId] = timestamps
    }

    // MARK: - Supabase Sync

    #if canImport(Supabase)
    /// Call after a post has been successfully inserted into SwiftData.
    func syncPostToSupabase(_ post: Post) {
        guard FeatureFlags.shared.supabaseSyncEnabled else { return }
        Task {
            do {
                var mediaUrls: [String] = []
                // Upload each carousel item first (preserves order).
                for item in post.mediaItems {
                    guard let bytes = item.data ?? item.thumbnailData else { continue }
                    do {
                        let url = try await SupabaseStorageService.shared.uploadPostMedia(postId: post.id, imageData: bytes)
                        mediaUrls.append(url)
                    } catch {
                        print("[FeedContentService] mediaItem upload failed: \(error)")
                    }
                }
                // Fall back to legacy single photo if there are no mediaItems.
                if mediaUrls.isEmpty, let photoData = post.photoData {
                    let url = try await SupabaseStorageService.shared.uploadPostMedia(postId: post.id, imageData: photoData)
                    mediaUrls.append(url)
                }

                // Serialize carousel metadata so per-clip captions + types
                // survive the round trip.
                let mediaItemsJSON: String? = {
                    guard !post.mediaItems.isEmpty else { return nil }
                    let serialized = post.mediaItems.enumerated().map { SerializedMediaItem(from: $1, order: $0) }
                    guard let data = try? JSONEncoder().encode(serialized),
                          let str = String(data: data, encoding: .utf8) else { return nil }
                    return str
                }()

                let dto = PostDTO(
                    id: post.id,
                    authorId: SupabaseAuthService.shared.currentUserId ?? post.authorId,
                    authorName: post.authorName,
                    authorUsername: post.authorUsername,
                    caption: post.caption,
                    workoutType: post.workoutType,
                    duration: post.duration != 0 ? post.duration : nil,
                    setCount: post.setCount != 0 ? post.setCount : nil,
                    exerciseHighlight: post.exerciseHighlight,
                    songTitle: post.songTitle,
                    artistName: post.artistName,
                    mediaUrls: mediaUrls.isEmpty ? nil : mediaUrls,
                    mediaItems: mediaItemsJSON,
                    likeCount: 0,
                    commentCount: 0,
                    isDeleted: false,
                    createdAt: post.timestamp,
                    updatedAt: post.timestamp
                )
                try await SupabaseSyncService.shared.insert(dto, table: "posts")
            } catch {
                print("[FeedContentService] Supabase post sync failed: \(error)")
            }
        }
    }

    /// Call after a like has been locally inserted.
    func syncLikeToSupabase(postId: UUID, userId: UUID, userName: String) {
        guard FeatureFlags.shared.supabaseSyncEnabled else { return }
        Task {
            do {
                let dto = LikeDTO(
                    postId: postId,
                    userId: SupabaseAuthService.shared.currentUserId ?? userId,
                    userName: userName
                )
                try await SupabaseSyncService.shared.insert(dto, table: "likes")
            } catch {
                print("[FeedContentService] Supabase like sync failed: \(error)")
            }
        }
    }

    /// Call after a like has been locally deleted (unliked).
    func syncUnlikeToSupabase(postId: UUID, userId: UUID) {
        guard FeatureFlags.shared.supabaseSyncEnabled else { return }
        Task {
            do {
                let resolvedUserId = SupabaseAuthService.shared.currentUserId ?? userId
                try await SupabaseConfig.client.from("likes")
                    .delete()
                    .eq("post_id", value: postId.uuidString)
                    .eq("user_id", value: resolvedUserId.uuidString)
                    .execute()
            } catch {
                print("[FeedContentService] Supabase unlike sync failed: \(error)")
            }
        }
    }
    #endif

    // MARK: - Private Helpers

    private func buildWorkoutCaption(workout: Workout) -> String {
        let typeLabel = workout.type.rawValue.capitalized
        let durationMin = workout.duration
        let sets = workout.totalSets

        var parts: [String] = []
        parts.append("\(typeLabel) workout")
        parts.append("\(durationMin) min")
        if sets > 0 {
            parts.append("\(sets) sets")
        }
        if workout.hasPRs {
            let prCount = workout.prEvents.count
            parts.append("\(prCount) PR\(prCount == 1 ? "" : "s")")
        }

        return parts.joined(separator: " · ")
    }
}
