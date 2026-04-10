import Foundation
import SwiftData

// MARK: - Session Context

struct SessionContext {
    var workoutBoosts: [String: Double]
    var authorBoosts: [String: Double]
    var hashtagBoosts: [String: Double]
    var skippedPostIds: Set<UUID>
    var notInterestedPostIds: Set<UUID>
    var mutualFriendIds: Set<UUID> = []
    var sessionMomentum: Double = 0       // 0..n recent positive interactions in last 5 min
    var currentHour: Int = Calendar.current.component(.hour, from: Date())
}

@MainActor
final class FeedRankingService: ObservableObject {
    static let shared = FeedRankingService()

    // MARK: - Tunable Constants

    /// Bayesian prior for engagement-rate smoothing (kills 1-view = 100% gaming)
    private let engagementPriorViews: Double = 50.0
    private let engagementPriorRate: Double = 0.05

    /// Probability of injecting an exploration post per slot during ranking pass
    private let explorationEpsilon: Double = 0.05

    // MARK: - Public API

    func rankPosts(_ posts: [Post], for userId: UUID, interests: UserInterestProfile?, category: String?, sessionContext: SessionContext? = nil) -> [Post] {
        // Category filter first
        var filtered = posts
        if let category, category != "All" {
            filtered = applyCategory(posts, category: category)
        }

        // Filter out not-interested posts
        if let ctx = sessionContext, !ctx.notInterestedPostIds.isEmpty {
            filtered = filtered.filter { !ctx.notInterestedPostIds.contains($0.id) }
        }

        // Score and sort
        var recentAuthors: [UUID] = []
        var recentWorkoutTypes: [String] = []
        let scored = filtered.map { post -> (Post, Double) in
            let score = computeScore(
                post: post,
                interests: interests,
                recentAuthors: &recentAuthors,
                recentWorkoutTypes: &recentWorkoutTypes,
                sessionContext: sessionContext
            )
            return (post, score)
        }

        var ranked = scored.sorted { $0.1 > $1.1 }.map(\.0)

        // Topic diversity guardrail: enforce rolling-window cap on workout type
        ranked = enforceTopicDiversity(ranked)

        // Discovery injection (anti-echo-chamber)
        ranked = injectDiscoveryPosts(ranked: ranked, allPosts: posts, interests: interests, userId: userId)

        return ranked
    }

    // MARK: - Scoring

    private func computeScore(
        post: Post,
        interests: UserInterestProfile?,
        recentAuthors: inout [UUID],
        recentWorkoutTypes: inout [String],
        sessionContext: SessionContext?
    ) -> Double {
        let engagement = engagementScore(for: post)
        let recency = recencyScore(for: post)
        let personalization = personalizationScore(for: post, interests: interests)
        let quality = contentQualityScore(for: post)
        let diversity = diversityPenalty(for: post, recentAuthors: &recentAuthors, recentWorkoutTypes: &recentWorkoutTypes)
        let coldStart = coldStartBoost(for: post)
        let session = sessionBoost(for: post, context: sessionContext)
        let socialProof = socialProofScore(for: post, context: sessionContext)
        let timeOfDay = timeOfDayScore(for: post, context: sessionContext)
        let wellbeing = wellbeingBoost(for: post)
        let firstImpression = firstImpressionBonus(for: post, interests: interests)

        // Flow-state adaptive weighting: when user is in a hot streak, weight personalization higher
        let momentum = sessionContext?.sessionMomentum ?? 0
        let inFlow = momentum >= 3
        let personalizationWeight = inFlow ? 0.45 : 0.35
        let engagementWeight = inFlow ? 0.20 : 0.25

        let baseScore =
            (engagement * engagementWeight) +
            (recency * 0.18) +
            (personalization * personalizationWeight) +
            (quality * 0.08) +
            (diversity * 0.04) +
            coldStart +
            session +
            socialProof +
            timeOfDay +
            wellbeing +
            firstImpression

        // Content format multiplier (video-first feed)
        return baseScore * contentFormatMultiplier(for: post)
    }

    /// Boost video and carousel posts, downrank photo-only posts
    private func contentFormatMultiplier(for post: Post) -> Double {
        let hasVideo = post.videoData != nil || post.mediaItems.contains { $0.mediaType == .video }
        let isCarousel = post.mediaItems.count > 1
        if hasVideo { return 1.5 }
        if isCarousel { return 1.3 }
        if post.photoData != nil { return 0.4 }
        return 0.3 // text-only
    }

    // MARK: - Engagement (global popularity)

    private func engagementScore(for post: Post) -> Double {
        // Bayesian-smoothed interaction rate (prevents 1-view gaming)
        let interactions =
            Double(post.likeCount) * 1.0 +
            Double(post.commentCount) * 5.0 +
            Double(post.shareCount) * 5.0 +
            Double(post.saveCount) * 5.0
        let views = Double(post.viewCount)
        let smoothedRate = (interactions + engagementPriorViews * engagementPriorRate) / (views + engagementPriorViews)

        var score = sigmoid(smoothedRate, midpoint: 0.08, steepness: 30)

        // Watch time bonus: 30s = full bonus
        let watchBonus = min(post.avgWatchTimeSec / 30.0, 1.0) * 0.3
        score = min(score + watchBonus, 1.0)

        // Rewatch addiction signal: posts users loop are sticky
        if post.avgCompletionCount > 1.0 {
            let rewatchBonus = min((post.avgCompletionCount - 1.0) * 0.15, 0.3)
            score = min(score + rewatchBonus, 1.0)
        }

        // Engagement depth multiplier: variety of interactions > volume
        var depth = 0
        if post.likeCount > 0 { depth += 1 }
        if post.commentCount > 0 { depth += 1 }
        if post.shareCount > 0 { depth += 1 }
        if post.saveCount > 0 { depth += 1 }
        score *= (1.0 + Double(depth) * 0.05)  // up to 1.20x

        // Co-engagement synergy bonus: comments + likes together signal stickiness
        if post.likeCount > 0 && post.commentCount > 0 {
            score *= 1.08
        }

        // Trending velocity: posts gaining engagement quickly
        let hoursOld = max(Date().timeIntervalSince(post.timestamp) / 3600.0, 0.5)
        let velocity = interactions / hoursOld
        if velocity > 10 {
            score = min(score + 0.2, 1.5)
        } else if velocity > 5 {
            score = min(score + 0.1, 1.5)
        }

        // Viral boost (preserved from earlier work)
        let viralRate = (Double(post.likeCount) + Double(post.commentCount) * 3.0) / max(Double(post.viewCount), 10.0)
        if viralRate > 0.5 {
            score = min(score + 0.3, 1.5)
        }

        return min(score, 1.5)
    }

    // MARK: - Recency

    private func recencyScore(for post: Post) -> Double {
        let hoursOld = Date().timeIntervalSince(post.timestamp) / 3600.0
        return exp(-0.03 * hoursOld)
    }

    // MARK: - Personalization

    private func personalizationScore(for post: Post, interests: UserInterestProfile?) -> Double {
        guard let interests else { return 0.5 }

        let workoutAffinity = interests.workoutTypeWeights[post.workoutType ?? ""] ?? 0.5
        let authorAffinity = interests.authorWeights[post.authorId.uuidString] ?? 0.0
        let format: String = post.videoData != nil ? "video" : (post.photoData != nil ? "photo" : "text")
        let formatAffinity = interests.contentFormatWeights[format] ?? 0.5

        // Hashtag affinity: average match across post hashtags
        let postHashtags = post.caption.split(separator: " ")
            .filter { $0.hasPrefix("#") }
            .map { String($0).lowercased() }
        let hashtagAffinity: Double
        if postHashtags.isEmpty {
            hashtagAffinity = 0.0
        } else {
            let sum = postHashtags.reduce(0.0) { $0 + (interests.hashtagWeights[$1] ?? 0.0) }
            hashtagAffinity = sum / Double(postHashtags.count)
        }

        // Emotion affinity
        let emotionAffinity: Double
        if let emotion = post.workoutEmotion, !emotion.isEmpty {
            emotionAffinity = interests.emotionWeights[emotion] ?? 0.0
        } else {
            emotionAffinity = 0.0
        }

        // Per-workout-type completion ratio: TikTok's strongest signal
        // If user historically watches running posts to 90% completion, surface more running posts
        let completionAffinity: Double
        if let workoutType = post.workoutType {
            completionAffinity = interests.videoCompletionWeights[workoutType] ?? 0.0
        } else {
            completionAffinity = 0.0
        }

        // Negative penalties
        let negativeWorkoutPenalty = interests.negativeWorkoutTypeWeights[post.workoutType ?? ""] ?? 0.0
        let negativeAuthorPenalty = interests.negativeAuthorWeights[post.authorId.uuidString] ?? 0.0

        let positiveScore =
            workoutAffinity * 0.22 +
            authorAffinity * 0.18 +
            formatAffinity * 0.12 +
            hashtagAffinity * 0.16 +
            emotionAffinity * 0.16 +
            completionAffinity * 0.16
        let negativePenalty = (negativeAuthorPenalty + negativeWorkoutPenalty) * 0.3

        return max(positiveScore - negativePenalty, 0.0)
    }

    // MARK: - Session boost (real-time in-session learning)

    private func sessionBoost(for post: Post, context: SessionContext?) -> Double {
        guard let ctx = context else { return 0.0 }

        var boost = 0.0

        if let workoutType = post.workoutType {
            boost += ctx.workoutBoosts[workoutType] ?? 0.0
        }

        boost += ctx.authorBoosts[post.authorId.uuidString] ?? 0.0

        let postHashtags = post.caption.split(separator: " ")
            .filter { $0.hasPrefix("#") }
            .map { String($0).lowercased() }
        for tag in postHashtags {
            boost += ctx.hashtagBoosts[tag] ?? 0.0
        }

        return max(min(boost * 0.1, 0.15), -0.15)
    }

    // MARK: - Social proof (friend graph proximity)

    private func socialProofScore(for post: Post, context: SessionContext?) -> Double {
        guard let ctx = context else { return 0.0 }
        // Posts authored by mutual friends get a meaningful boost
        if ctx.mutualFriendIds.contains(post.authorId) {
            return 0.12
        }
        return 0.0
    }

    // MARK: - Time of day appropriateness (wellbeing)

    private func timeOfDayScore(for post: Post, context: SessionContext?) -> Double {
        guard let ctx = context, let workoutType = post.workoutType?.lowercased() else { return 0.0 }
        let hour = ctx.currentHour

        // Morning (5am - 11am): boost active workouts
        if (5..<11).contains(hour) {
            if workoutType.contains("hiit") || workoutType.contains("cardio") || workoutType.contains("run") || workoutType.contains("strength") || workoutType.contains("crossfit") {
                return 0.06
            }
        }
        // Late evening (21 - 5): downrank intense, boost recovery/yoga/mobility
        if hour >= 21 || hour < 5 {
            if workoutType.contains("yoga") || workoutType.contains("stretch") || workoutType.contains("mobility") || workoutType.contains("recovery") {
                return 0.06
            }
            if workoutType.contains("hiit") || workoutType.contains("crossfit") {
                return -0.04
            }
        }
        return 0.0
    }

    // MARK: - Wellbeing (positive emotion bias, anti-doom-scroll)

    private func wellbeingBoost(for post: Post) -> Double {
        guard let emotion = post.workoutEmotion?.lowercased() else { return 0.0 }
        // Small but consistent nudge toward uplifting content
        let positiveEmotions: Set<String> = ["proud", "accomplished", "joyful", "joy", "energized", "motivated", "happy", "grateful", "achievement", "inspired"]
        if positiveEmotions.contains(emotion) {
            return 0.05
        }
        return 0.0
    }

    // MARK: - First impression bonus (serendipity)

    private func firstImpressionBonus(for post: Post, interests: UserInterestProfile?) -> Double {
        guard let interests else { return 0.0 }
        // Authors the user has never engaged with get a small visibility boost
        let authorKey = post.authorId.uuidString
        if interests.authorWeights[authorKey] == nil &&
           interests.negativeAuthorWeights[authorKey] == nil {
            return 0.04
        }
        return 0.0
    }

    // MARK: - Quality

    private func contentQualityScore(for post: Post) -> Double {
        var score = 0.0
        if post.photoData != nil || post.videoData != nil { score += 0.3 }
        if post.songTitle != nil { score += 0.15 }
        if post.sharedWorkoutData != nil { score += 0.25 }
        score += min(Double(post.caption.count) / 200.0, 0.3)
        return score
    }

    // MARK: - Diversity

    private func diversityPenalty(for post: Post, recentAuthors: inout [UUID], recentWorkoutTypes: inout [String]) -> Double {
        let authorRepeat = recentAuthors.suffix(5).filter { $0 == post.authorId }.count
        let typeRepeat = post.workoutType.map { wt in
            recentWorkoutTypes.suffix(5).filter { $0 == wt }.count
        } ?? 0

        recentAuthors.append(post.authorId)
        if let wt = post.workoutType { recentWorkoutTypes.append(wt) }

        let penalty = Double(authorRepeat) * 0.3 + Double(typeRepeat) * 0.15
        return max(1.0 - penalty, 0.0)
    }

    // MARK: - Cold start

    private func coldStartBoost(for post: Post) -> Double {
        // Return tiered boost when no engagement data exists
        if post.viewCount == 0 {
            let age = Date().timeIntervalSince(post.timestamp) / 3600.0
            if age < 1 { return 0.15 }
            if age < 6 { return 0.10 }
            if age < 24 { return 0.05 }
            return 0.02
        }

        let age = Date().timeIntervalSince(post.timestamp)
        if age < 3600 && post.viewCount < 10 {
            return 0.15
        }
        return 0.0
    }

    // MARK: - Topic Diversity Guardrail (rolling window)

    /// Ensures no contiguous 6-post window contains more than 3 posts of the same workout type.
    /// Operates in-place by re-sliding posts that violate the guard.
    private func enforceTopicDiversity(_ posts: [Post]) -> [Post] {
        guard posts.count > 6 else { return posts }
        var result = posts
        let windowSize = 6
        let maxSameType = 3

        var i = 0
        while i + windowSize <= result.count {
            let window = Array(result[i..<i + windowSize])
            var counts: [String: Int] = [:]
            for p in window {
                if let wt = p.workoutType {
                    counts[wt, default: 0] += 1
                }
            }
            // Find any workout type that exceeds the cap
            if let (overType, _) = counts.first(where: { $0.value > maxSameType }) {
                // Find an out-of-window swap candidate that is NOT the over-represented type
                var swapped = false
                for j in (i + windowSize)..<result.count {
                    if result[j].workoutType != overType {
                        // Find the last instance of overType in the window to swap forward
                        if let swapIndex = (i..<i + windowSize).reversed().first(where: { result[$0].workoutType == overType }) {
                            result.swapAt(swapIndex, j)
                            swapped = true
                            break
                        }
                    }
                }
                if !swapped {
                    i += 1
                }
            } else {
                i += 1
            }
        }
        return result
    }

    // MARK: - Category Filtering

    private func applyCategory(_ posts: [Post], category: String) -> [Post] {
        switch category {
        case "PR Moments":
            return posts.filter { $0.caption.lowercased().contains("pr") || $0.caption.contains("\u{1F3C6}") }
        case "Music":
            return posts.filter { $0.songTitle != nil }
        case "Form Tips":
            return posts.filter { $0.caption.lowercased().contains("form") || $0.caption.lowercased().contains("tip") }
        default:
            return posts.filter { $0.workoutType?.lowercased() == category.lowercased() }
        }
    }

    // MARK: - Discovery Injection (with exploration epsilon)

    private func injectDiscoveryPosts(ranked: [Post], allPosts: [Post], interests: UserInterestProfile?, userId: UUID) -> [Post] {
        guard ranked.count >= 4 else { return ranked }

        // Adaptive interval: 4-8 based on profile strength
        let profileStrength = interests.map { Double($0.workoutTypeWeights.count + $0.authorWeights.count) } ?? 0.0
        let interval = max(4, min(8, Int(8.0 - profileStrength * 0.5)))

        let knownAuthorIds: Set<String>
        if let keys = interests?.authorWeights.keys {
            knownAuthorIds = Set(keys)
        } else {
            knownAuthorIds = []
        }

        let knownWorkoutTypes: Set<String> = Set(interests?.workoutTypeWeights.keys ?? [String: Double]().keys)

        var novelPosts = allPosts.filter { post in
            let isNovelAuthor = !knownAuthorIds.contains(post.authorId.uuidString)
            let isNovelTopic = post.workoutType.map { !knownWorkoutTypes.contains($0) } ?? false
            return (isNovelAuthor || isNovelTopic) && post.authorId != userId
        }

        novelPosts.shuffle()

        guard !novelPosts.isEmpty else { return ranked }

        var result = ranked
        var novelIndex = 0

        var insertAt = interval - 1
        while insertAt < result.count && novelIndex < novelPosts.count {
            let novelPost = novelPosts[novelIndex]
            if !result.contains(where: { $0.id == novelPost.id }) {
                result.insert(novelPost, at: insertAt)
            }
            novelIndex += 1
            insertAt += interval
        }

        // Exploration epsilon: occasionally inject extra serendipity even into well-personalized feeds
        if novelIndex < novelPosts.count {
            for slot in stride(from: 2, to: result.count, by: 1) {
                if Double.random(in: 0...1) < explorationEpsilon, novelIndex < novelPosts.count {
                    let novelPost = novelPosts[novelIndex]
                    if !result.contains(where: { $0.id == novelPost.id }) {
                        result.insert(novelPost, at: slot)
                        novelIndex += 1
                    }
                }
            }
        }

        return result
    }

    // MARK: - Math Helpers

    private func sigmoid(_ x: Double, midpoint: Double, steepness: Double) -> Double {
        1.0 / (1.0 + exp(-steepness * (x - midpoint)))
    }
}
