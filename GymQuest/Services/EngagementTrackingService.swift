import Foundation
import SwiftData

extension Notification.Name {
    static let feedShouldReRank = Notification.Name("feedShouldReRankNotification")
}

@MainActor
final class EngagementTrackingService: ObservableObject {
    static let shared = EngagementTrackingService()

    private var activePostId: UUID?
    private var viewStartTime: Date?
    private var modelContext: ModelContext?
    private var interactionCount = 0
    private var lastScoreRefresh: Date = .distantPast

    // MARK: - Session State (in-memory, resets on app launch)

    var sessionWorkoutBoosts: [String: Double] = [:]
    var sessionAuthorBoosts: [String: Double] = [:]
    var sessionHashtagBoosts: [String: Double] = [:]
    var sessionSkippedPostIds: Set<UUID> = []
    var sessionNotInterestedPostIds: Set<UUID> = []

    /// Sliding window of recent positive interaction timestamps (for flow-state detection)
    private var recentPositiveInteractions: [Date] = []
    private let momentumWindow: TimeInterval = 300 // 5 minutes

    /// Number of positive interactions in the last 5 minutes — drives flow-state ranking amp
    var sessionMomentum: Double {
        let cutoff = Date().addingTimeInterval(-momentumWindow)
        return Double(recentPositiveInteractions.filter { $0 > cutoff }.count)
    }

    private func recordPositiveInteraction() {
        let now = Date()
        recentPositiveInteractions.append(now)
        // Trim old entries
        let cutoff = now.addingTimeInterval(-momentumWindow)
        recentPositiveInteractions.removeAll { $0 < cutoff }
    }

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

        // Skip detection: scrolled past in < 2s
        if watchTime < 2.0 {
            engagement.skipped = true
            sessionSkippedPostIds.insert(postId)

            // Record negative session signal for the post's workout type/author
            if let post = fetchPost(postId: postId) {
                if let workoutType = post.workoutType {
                    sessionWorkoutBoosts[workoutType, default: 0] -= 0.3
                }
                sessionAuthorBoosts[post.authorId.uuidString, default: 0] -= 0.2
            }

            saveAndTrackInteraction(userId: userId)
            return
        }

        // Positive engagement path
        engagement.watchTimeSec += watchTime

        // Compute completion ratio
        if let post = fetchPost(postId: postId), let duration = post.duration, duration > 0 {
            let ratio = min(watchTime / Double(duration), 1.0)
            engagement.maxCompletionRatio = max(engagement.maxCompletionRatio, ratio)

            // Extract hashtags from engaged content and boost session
            if watchTime >= 5.0 {
                let hashtags = extractHashtags(from: post.caption)
                for tag in hashtags {
                    sessionHashtagBoosts[tag, default: 0] += 0.2
                }
                if let workoutType = post.workoutType {
                    sessionWorkoutBoosts[workoutType, default: 0] += 0.3
                }
                sessionAuthorBoosts[post.authorId.uuidString, default: 0] += 0.2
                // Linger bonus: 5+ seconds is a strong positive signal — counts toward flow state
                recordPositiveInteraction()
            }
            // Deep linger (>10s) is doubly meaningful
            if watchTime >= 10.0 {
                if let workoutType = post.workoutType {
                    sessionWorkoutBoosts[workoutType, default: 0] += 0.2
                }
                sessionAuthorBoosts[post.authorId.uuidString, default: 0] += 0.15
            }
        }

        updatePostAvgWatchTime(postId: postId, newWatchTime: watchTime)
        saveAndTrackInteraction(userId: userId)
    }

    // MARK: - Video Loop Tracking

    func trackVideoLoop(postId: UUID, userId: UUID) {
        let engagement = getOrCreateEngagement(postId: postId, userId: userId)
        engagement.completionCount += 1

        // Update post-level avgCompletionCount (running mean across all viewers)
        if let ctx = modelContext {
            let descriptor = FetchDescriptor<Post>(predicate: #Predicate { $0.id == postId })
            if let post = try? ctx.fetch(descriptor).first {
                let viewers = max(Double(post.viewCount), 1.0)
                post.avgCompletionCount = ((post.avgCompletionCount * (viewers - 1)) + 1.0) / viewers
            }
        }

        // Strong positive signal — counts toward flow state momentum
        recordPositiveInteraction()
        try? modelContext?.save()
    }

    // MARK: - Not Interested

    func trackNotInterested(postId: UUID, userId: UUID) {
        let engagement = getOrCreateEngagement(postId: postId, userId: userId)
        engagement.notInterested = true
        sessionNotInterestedPostIds.insert(postId)

        // Record strong negative for workout type and author
        if let post = fetchPost(postId: postId) {
            if let workoutType = post.workoutType {
                sessionWorkoutBoosts[workoutType, default: 0] -= 1.0
            }
            sessionAuthorBoosts[post.authorId.uuidString, default: 0] -= 1.0

            let hashtags = extractHashtags(from: post.caption)
            for tag in hashtags {
                sessionHashtagBoosts[tag, default: 0] -= 0.5
            }
        }

        saveAndTrackInteraction(userId: userId)
    }

    // MARK: - Interaction Tracking

    func trackLike(postId: UUID, userId: UUID) {
        let engagement = getOrCreateEngagement(postId: postId, userId: userId)
        engagement.liked = true
        recordPositiveInteraction()
        saveAndTrackInteraction(userId: userId)
    }

    func trackComment(postId: UUID, userId: UUID) {
        let engagement = getOrCreateEngagement(postId: postId, userId: userId)
        engagement.commented = true
        recordPositiveInteraction()
        saveAndTrackInteraction(userId: userId)
    }

    func trackShare(postId: UUID, userId: UUID) {
        let engagement = getOrCreateEngagement(postId: postId, userId: userId)
        engagement.shared = true
        recordPositiveInteraction()

        // Increment share count on the post
        incrementShareCount(postId: postId)
        saveAndTrackInteraction(userId: userId)
    }

    func trackSave(postId: UUID, userId: UUID) {
        let engagement = getOrCreateEngagement(postId: postId, userId: userId)
        engagement.saved = true
        recordPositiveInteraction()

        // Increment save count on the post
        incrementSaveCount(postId: postId)
        saveAndTrackInteraction(userId: userId)
    }

    func trackFollow(postId: UUID, userId: UUID) {
        let engagement = getOrCreateEngagement(postId: postId, userId: userId)
        engagement.followed = true
        recordPositiveInteraction()
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

        // Compute weights from engagement
        var workoutScores: [String: Double] = [:]
        var workoutCounts: [String: Double] = [:]
        var authorScores: [String: Double] = [:]
        var authorCounts: [String: Double] = [:]
        var formatScores: [String: Double] = [:]
        var formatCounts: [String: Double] = [:]
        var hashtagScores: [String: Double] = [:]
        var hashtagCounts: [String: Double] = [:]
        var emotionScores: [String: Double] = [:]
        var emotionCounts: [String: Double] = [:]
        var negativeWorkoutScores: [String: Double] = [:]
        var negativeAuthorScores: [String: Double] = [:]
        var completionRatioSums: [String: Double] = [:]
        var completionRatioCounts: [String: Double] = [:]
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

            // Negative signals
            if engagement.notInterested || engagement.skipped {
                if let workoutType = post.workoutType {
                    negativeWorkoutScores[workoutType, default: 0] += engagement.notInterested ? 3.0 : 1.0
                }
                negativeAuthorScores[post.authorId.uuidString, default: 0] += engagement.notInterested ? 3.0 : 1.0
                continue
            }

            // Positive signals only below this point

            // Workout type affinity
            if let workoutType = post.workoutType {
                workoutScores[workoutType, default: 0] += interactionWeight
                workoutCounts[workoutType, default: 0] += 1

                // Per-workout-type completion ratio (TikTok's strongest signal)
                if engagement.maxCompletionRatio > 0 {
                    completionRatioSums[workoutType, default: 0] += engagement.maxCompletionRatio
                    completionRatioCounts[workoutType, default: 0] += 1
                }
            }

            // Author affinity
            let authorKey = post.authorId.uuidString
            authorScores[authorKey, default: 0] += interactionWeight
            authorCounts[authorKey, default: 0] += 1

            // Format affinity
            let format = post.videoData != nil ? "video" : (post.photoData != nil ? "photo" : "text")
            formatScores[format, default: 0] += interactionWeight
            formatCounts[format, default: 0] += 1

            // Hashtag affinity (from positive engagements)
            if interactionWeight > 1.0 {
                let hashtags = extractHashtags(from: post.caption)
                for tag in hashtags {
                    hashtagScores[tag, default: 0] += interactionWeight * 0.5
                    hashtagCounts[tag, default: 0] += 1
                }
            }

            // Emotion affinity
            if let emotion = post.workoutEmotion, !emotion.isEmpty {
                emotionScores[emotion, default: 0] += interactionWeight
                emotionCounts[emotion, default: 0] += 1
            }
        }

        // Normalize and apply EMA (0.7 new + 0.3 old)
        let newWorkoutWeights = normalizeWeights(scores: workoutScores, counts: workoutCounts)
        let newAuthorWeights = normalizeWeights(scores: authorScores, counts: authorCounts)
        let newFormatWeights = normalizeWeights(scores: formatScores, counts: formatCounts)
        let newHashtagWeights = normalizeWeights(scores: hashtagScores, counts: hashtagCounts)
        let newEmotionWeights = normalizeWeights(scores: emotionScores, counts: emotionCounts)
        let newNegativeWorkoutWeights = normalizeNegativeWeights(scores: negativeWorkoutScores)
        let newNegativeAuthorWeights = normalizeNegativeWeights(scores: negativeAuthorScores)

        // Compute per-workout-type avg completion ratios (raw, no normalization needed — already 0..1)
        var newCompletionWeights: [String: Double] = [:]
        for (key, sum) in completionRatioSums {
            let count = completionRatioCounts[key] ?? 1
            newCompletionWeights[key] = sum / count
        }

        profile.workoutTypeWeights = emaBlend(old: profile.workoutTypeWeights, new: newWorkoutWeights)
        profile.authorWeights = emaBlend(old: profile.authorWeights, new: newAuthorWeights)
        profile.contentFormatWeights = emaBlend(old: profile.contentFormatWeights, new: newFormatWeights)
        profile.hashtagWeights = emaBlend(old: profile.hashtagWeights, new: newHashtagWeights)
        profile.emotionWeights = emaBlend(old: profile.emotionWeights, new: newEmotionWeights)
        profile.negativeWorkoutTypeWeights = emaBlend(old: profile.negativeWorkoutTypeWeights, new: newNegativeWorkoutWeights)
        profile.negativeAuthorWeights = emaBlend(old: profile.negativeAuthorWeights, new: newNegativeAuthorWeights)
        profile.videoCompletionWeights = emaBlend(old: profile.videoCompletionWeights, new: newCompletionWeights)
        profile.avgSessionTimeSec = totalWatchTime / Double(max(engagements.count, 1))
        profile.lastUpdated = Date()

        try? ctx.save()

        // Notify feed to re-rank
        NotificationCenter.default.post(name: .feedShouldReRank, object: nil)
    }

    // MARK: - Post Score Refresh

    func refreshPostScores() {
        guard let ctx = modelContext else { return }

        // Throttle to every 60 seconds
        guard Date().timeIntervalSince(lastScoreRefresh) > 60 else { return }
        lastScoreRefresh = Date()

        let cutoff = Date().addingTimeInterval(-86400) // last 24h
        let descriptor = FetchDescriptor<Post>(predicate: #Predicate { $0.timestamp > cutoff })
        guard let posts = try? ctx.fetch(descriptor) else { return }

        for post in posts {
            let views = max(Double(post.viewCount), 1.0)
            let rawRate = (Double(post.likeCount) + Double(post.commentCount) * 5.0 + Double(post.shareCount) * 5.0 + Double(post.saveCount) * 5.0) / views
            let sigmoid = 1.0 / (1.0 + exp(-30.0 * (rawRate - 0.08)))
            let watchBonus = min(post.avgWatchTimeSec / 30.0, 1.0) * 0.3
            var score = min(sigmoid + watchBonus, 1.0)
            let viralRate = (Double(post.likeCount) + Double(post.commentCount) * 3.0) / max(Double(post.viewCount), 10.0)
            if viralRate > 0.5 {
                score = min(score + 0.3, 1.0)
            }
            post.engagementScore = score
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

    private func fetchPost(postId: UUID) -> Post? {
        guard let ctx = modelContext else { return nil }
        let descriptor = FetchDescriptor<Post>(predicate: #Predicate { $0.id == postId })
        return try? ctx.fetch(descriptor).first
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

        // Update interests every 3 interactions (faster adaptation)
        if interactionCount >= 3 {
            interactionCount = 0
            updateUserInterests(userId: userId)
        }
    }

    private func engagementWeight(_ engagement: PostEngagement) -> Double {
        var weight = 0.0

        // Negative signals
        if engagement.notInterested { return -5.0 }
        if engagement.skipped { return -1.0 }

        // Watch time (0-1 point)
        weight += min(engagement.watchTimeSec / 10.0, 1.0) * 1.0

        // Completion bonus (0-2 points)
        weight += engagement.maxCompletionRatio * 2.0

        // Rewatch bonus (up to 6 points)
        weight += Double(min(engagement.completionCount, 3)) * 2.0

        // Action weights
        if engagement.liked { weight += 1.0 }
        if engagement.commented { weight += 5.0 }
        if engagement.shared { weight += 5.0 }
        if engagement.saved { weight += 5.0 }
        if engagement.followed { weight += 6.0 }

        return weight
    }

    private func extractHashtags(from caption: String) -> [String] {
        caption.split(separator: " ")
            .filter { $0.hasPrefix("#") }
            .map { String($0).lowercased() }
    }

    private func normalizeWeights(scores: [String: Double], counts: [String: Double]) -> [String: Double] {
        guard !scores.isEmpty else { return [:] }
        let maxScore = scores.values.max() ?? 1.0
        guard maxScore > 0 else { return [:] }
        return scores.mapValues { $0 / maxScore }
    }

    private func normalizeNegativeWeights(scores: [String: Double]) -> [String: Double] {
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
