import Foundation
import SwiftData

@MainActor
final class EngagementTrackingService: ObservableObject {
    static let shared = EngagementTrackingService()

    private var activePostId: UUID?
    private var viewStartTime: Date?
    private var modelContext: ModelContext?
    private var interactionCount = 0
    private var lastScoreRefresh: Date = .distantPast

    // MARK: - Setup

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Watch Time Tracking

    func trackPostAppeared(postId: UUID, userId: UUID) {
        // Finalize previous post if any
        if let prev = activePostId {
            trackPostDisappeared(postId: prev, userId: userId)
        }
        activePostId = postId
        viewStartTime = Date()

        // Increment view count on the post
        incrementViewCount(postId: postId)
    }

    func trackPostDisappeared(postId: UUID, userId: UUID) {
        guard postId == activePostId, let start = viewStartTime else { return }
        let watchTime = Date().timeIntervalSince(start)

        activePostId = nil
        viewStartTime = nil

        // Only record meaningful views (> 0.5s)
        guard watchTime > 0.5 else { return }

        let engagement = getOrCreateEngagement(postId: postId, userId: userId)
        engagement.watchTimeSec += watchTime

        updatePostAvgWatchTime(postId: postId, newWatchTime: watchTime)
        saveAndTrackInteraction(userId: userId)
    }

    // MARK: - Interaction Tracking

    func trackLike(postId: UUID, userId: UUID) {
        let engagement = getOrCreateEngagement(postId: postId, userId: userId)
        engagement.liked = true
        saveAndTrackInteraction(userId: userId)
    }

    func trackComment(postId: UUID, userId: UUID) {
        let engagement = getOrCreateEngagement(postId: postId, userId: userId)
        engagement.commented = true
        saveAndTrackInteraction(userId: userId)
    }

    func trackShare(postId: UUID, userId: UUID) {
        let engagement = getOrCreateEngagement(postId: postId, userId: userId)
        engagement.shared = true

        // Increment share count on the post
        incrementShareCount(postId: postId)
        saveAndTrackInteraction(userId: userId)
    }

    func trackSave(postId: UUID, userId: UUID) {
        let engagement = getOrCreateEngagement(postId: postId, userId: userId)
        engagement.saved = true

        // Increment save count on the post
        incrementSaveCount(postId: postId)
        saveAndTrackInteraction(userId: userId)
    }

    func trackFollow(postId: UUID, userId: UUID) {
        let engagement = getOrCreateEngagement(postId: postId, userId: userId)
        engagement.followed = true
        saveAndTrackInteraction(userId: userId)
    }

    // MARK: - Interest Profile Updates

    func updateUserInterests(userId: UUID) {
        guard let ctx = modelContext else { return }

        let descriptor = FetchDescriptor<PostEngagement>(predicate: #Predicate { $0.userId == userId })
        guard let engagements = try? ctx.fetch(descriptor), !engagements.isEmpty else { return }

        // Fetch or create interest profile
        let profileDescriptor = FetchDescriptor<UserInterestProfile>(predicate: #Predicate { $0.userId == userId })
        let profile: UserInterestProfile
        if let existing = try? ctx.fetch(profileDescriptor).first {
            profile = existing
        } else {
            profile = UserInterestProfile(userId: userId)
            ctx.insert(profile)
        }

        // Compute workout type weights from engagement
        var workoutScores: [String: Double] = [:]
        var workoutCounts: [String: Double] = [:]
        var authorScores: [String: Double] = [:]
        var authorCounts: [String: Double] = [:]
        var formatScores: [String: Double] = [:]
        var formatCounts: [String: Double] = [:]
        var totalWatchTime: Double = 0

        // Fetch posts for engagement context
        let postIds = Set(engagements.map(\.postId))
        let allPostsDescriptor = FetchDescriptor<Post>()
        let allPosts = (try? ctx.fetch(allPostsDescriptor)) ?? []
        let postMap = Dictionary(uniqueKeysWithValues: allPosts.compactMap { post in
            postIds.contains(post.id) ? (post.id, post) : nil
        })

        for engagement in engagements {
            guard let post = postMap[engagement.postId] else { continue }

            let interactionWeight = engagementWeight(engagement)
            totalWatchTime += engagement.watchTimeSec

            // Workout type affinity
            if let workoutType = post.workoutType {
                workoutScores[workoutType, default: 0] += interactionWeight
                workoutCounts[workoutType, default: 0] += 1
            }

            // Author affinity
            let authorKey = post.authorId.uuidString
            authorScores[authorKey, default: 0] += interactionWeight
            authorCounts[authorKey, default: 0] += 1

            // Format affinity
            let format = post.videoData != nil ? "video" : (post.photoData != nil ? "photo" : "text")
            formatScores[format, default: 0] += interactionWeight
            formatCounts[format, default: 0] += 1
        }

        // Normalize and apply EMA (0.7 new + 0.3 old)
        let newWorkoutWeights = normalizeWeights(scores: workoutScores, counts: workoutCounts)
        let newAuthorWeights = normalizeWeights(scores: authorScores, counts: authorCounts)
        let newFormatWeights = normalizeWeights(scores: formatScores, counts: formatCounts)

        profile.workoutTypeWeights = emaBlend(old: profile.workoutTypeWeights, new: newWorkoutWeights)
        profile.authorWeights = emaBlend(old: profile.authorWeights, new: newAuthorWeights)
        profile.contentFormatWeights = emaBlend(old: profile.contentFormatWeights, new: newFormatWeights)
        profile.avgSessionTimeSec = totalWatchTime / Double(max(engagements.count, 1))
        profile.lastUpdated = Date()

        try? ctx.save()
    }

    // MARK: - Post Score Refresh

    func refreshPostScores() {
        guard let ctx = modelContext else { return }

        // Only refresh every 5 minutes
        guard Date().timeIntervalSince(lastScoreRefresh) > 300 else { return }
        lastScoreRefresh = Date()

        let cutoff = Date().addingTimeInterval(-86400) // last 24h
        let descriptor = FetchDescriptor<Post>(predicate: #Predicate { $0.timestamp > cutoff })
        guard let posts = try? ctx.fetch(descriptor) else { return }

        for post in posts {
            let views = max(Double(post.viewCount), 1.0)
            let rawRate = (Double(post.likeCount) + Double(post.commentCount) * 3.0 + Double(post.shareCount) * 5.0 + Double(post.saveCount) * 4.0) / views
            let sigmoid = 1.0 / (1.0 + exp(-30.0 * (rawRate - 0.08)))
            let watchBonus = min(post.avgWatchTimeSec / 30.0, 1.0) * 0.3
            post.engagementScore = min(sigmoid + watchBonus, 1.0)
        }

        try? ctx.save()
    }

    // MARK: - Private Helpers

    private func getOrCreateEngagement(postId: UUID, userId: UUID) -> PostEngagement {
        guard let ctx = modelContext else {
            return PostEngagement(postId: postId, userId: userId)
        }

        let descriptor = FetchDescriptor<PostEngagement>(predicate: #Predicate {
            $0.postId == postId && $0.userId == userId
        })

        if let existing = try? ctx.fetch(descriptor).first {
            return existing
        }

        let engagement = PostEngagement(postId: postId, userId: userId)
        ctx.insert(engagement)
        return engagement
    }

    private func incrementViewCount(postId: UUID) {
        guard let ctx = modelContext else { return }
        let descriptor = FetchDescriptor<Post>(predicate: #Predicate { $0.id == postId })
        if let post = try? ctx.fetch(descriptor).first {
            post.viewCount += 1
        }
    }

    private func incrementShareCount(postId: UUID) {
        guard let ctx = modelContext else { return }
        let descriptor = FetchDescriptor<Post>(predicate: #Predicate { $0.id == postId })
        if let post = try? ctx.fetch(descriptor).first {
            post.shareCount += 1
        }
    }

    private func incrementSaveCount(postId: UUID) {
        guard let ctx = modelContext else { return }
        let descriptor = FetchDescriptor<Post>(predicate: #Predicate { $0.id == postId })
        if let post = try? ctx.fetch(descriptor).first {
            post.saveCount += 1
        }
    }

    private func updatePostAvgWatchTime(postId: UUID, newWatchTime: Double) {
        guard let ctx = modelContext else { return }
        let descriptor = FetchDescriptor<Post>(predicate: #Predicate { $0.id == postId })
        if let post = try? ctx.fetch(descriptor).first {
            let views = max(Double(post.viewCount), 1.0)
            // Running average
            post.avgWatchTimeSec = ((post.avgWatchTimeSec * (views - 1)) + newWatchTime) / views
        }
    }

    private func saveAndTrackInteraction(userId: UUID) {
        try? modelContext?.save()
        interactionCount += 1

        // Update interests every 10 interactions
        if interactionCount >= 10 {
            interactionCount = 0
            updateUserInterests(userId: userId)
        }
    }

    private func engagementWeight(_ engagement: PostEngagement) -> Double {
        var weight = 0.0
        weight += min(engagement.watchTimeSec / 10.0, 1.0) * 1.0 // watch time
        if engagement.liked { weight += 1.0 }
        if engagement.commented { weight += 3.0 }
        if engagement.shared { weight += 5.0 }
        if engagement.saved { weight += 4.0 }
        if engagement.followed { weight += 6.0 }
        return weight
    }

    private func normalizeWeights(scores: [String: Double], counts: [String: Double]) -> [String: Double] {
        guard !scores.isEmpty else { return [:] }
        let maxScore = scores.values.max() ?? 1.0
        guard maxScore > 0 else { return [:] }
        return scores.mapValues { $0 / maxScore }
    }

    private func emaBlend(old: [String: Double], new: [String: Double]) -> [String: Double] {
        var result = old
        for (key, newVal) in new {
            let oldVal = old[key] ?? 0.0
            result[key] = 0.7 * newVal + 0.3 * oldVal
        }
        return result
    }
}
