import Foundation
import SwiftData

// MARK: - Session Context

struct SessionContext {
    var workoutBoosts: [String: Double]
    var authorBoosts: [String: Double]
    var hashtagBoosts: [String: Double]
    var skippedPostIds: Set<UUID>
    var notInterestedPostIds: Set<UUID>
}

@MainActor
final class FeedRankingService: ObservableObject {
    static let shared = FeedRankingService()

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
        let scored = filtered.map { post -> (Post, Double) in
            let score = computeScore(post: post, interests: interests, recentAuthors: &recentAuthors, sessionContext: sessionContext)
            return (post, score)
        }

        var ranked = scored.sorted { $0.1 > $1.1 }.map(\.0)

        // Discovery injection
        ranked = injectDiscoveryPosts(ranked: ranked, allPosts: posts, interests: interests, userId: userId)

        return ranked
    }

    // MARK: - Scoring

    private func computeScore(post: Post, interests: UserInterestProfile?, recentAuthors: inout [UUID], sessionContext: SessionContext?) -> Double {
        let engagement = engagementScore(for: post)
        let recency = recencyScore(for: post)
        let personalization = personalizationScore(for: post, interests: interests)
        let quality = contentQualityScore(for: post)
        let diversity = diversityPenalty(for: post, recentAuthors: &recentAuthors)
        let coldStart = coldStartBoost(for: post)
        let session = sessionBoost(for: post, context: sessionContext)

        // Rebalanced weights: personalization-heavy
        return (engagement * 0.25) + (recency * 0.20) + (personalization * 0.35) + (quality * 0.10) + (diversity * 0.05) + coldStart + session
    }

    private func engagementScore(for post: Post) -> Double {
        let views = max(Double(post.viewCount), 1.0)
        let rawRate = (Double(post.likeCount) * 1.0 + Double(post.commentCount) * 3.0 + Double(post.shareCount) * 5.0 + Double(post.saveCount) * 4.0) / views

        var score = sigmoid(rawRate, midpoint: 0.08, steepness: 30)

        // Watch time bonus: 30s = full bonus
        let watchBonus = min(post.avgWatchTimeSec / 30.0, 1.0) * 0.3
        score = min(score + watchBonus, 1.0)

        return score
    }

    private func recencyScore(for post: Post) -> Double {
        let hoursOld = Date().timeIntervalSince(post.timestamp) / 3600.0
        return exp(-0.03 * hoursOld)
    }

    private func personalizationScore(for post: Post, interests: UserInterestProfile?) -> Double {
        guard let interests else { return 0.5 }

        // 5 sub-signals
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

        // Negative penalties
        let negativeWorkoutPenalty = interests.negativeWorkoutTypeWeights[post.workoutType ?? ""] ?? 0.0
        let negativeAuthorPenalty = interests.negativeAuthorWeights[post.authorId.uuidString] ?? 0.0

        let positiveScore = workoutAffinity * 0.25 + authorAffinity * 0.20 + formatAffinity * 0.15 + hashtagAffinity * 0.20 + emotionAffinity * 0.20
        let negativePenalty = (negativeAuthorPenalty + negativeWorkoutPenalty) * 0.3

        return max(positiveScore - negativePenalty, 0.0)
    }

    private func sessionBoost(for post: Post, context: SessionContext?) -> Double {
        guard let ctx = context else { return 0.0 }

        var boost = 0.0

        // Workout type session boost
        if let workoutType = post.workoutType {
            boost += ctx.workoutBoosts[workoutType] ?? 0.0
        }

        // Author session boost
        boost += ctx.authorBoosts[post.authorId.uuidString] ?? 0.0

        // Hashtag session boost
        let postHashtags = post.caption.split(separator: " ")
            .filter { $0.hasPrefix("#") }
            .map { String($0).lowercased() }
        for tag in postHashtags {
            boost += ctx.hashtagBoosts[tag] ?? 0.0
        }

        // Clamp session boost contribution
        return max(min(boost * 0.1, 0.15), -0.15)
    }

    private func contentQualityScore(for post: Post) -> Double {
        var score = 0.0
        if post.photoData != nil || post.videoData != nil { score += 0.3 }
        if post.songTitle != nil { score += 0.15 }
        if post.sharedWorkoutData != nil { score += 0.25 }
        score += min(Double(post.caption.count) / 200.0, 0.3)
        return score
    }

    private func diversityPenalty(for post: Post, recentAuthors: inout [UUID]) -> Double {
        let repeatCount = recentAuthors.suffix(5).filter { $0 == post.authorId }.count
        recentAuthors.append(post.authorId)
        return max(1.0 - Double(repeatCount) * 0.3, 0.0)
    }

    private func coldStartBoost(for post: Post) -> Double {
        // Return neutral when no engagement data exists
        if post.viewCount == 0 {
            let age = Date().timeIntervalSince(post.timestamp) / 3600.0
            // Tiered boost decaying with age
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

    // MARK: - Discovery Injection

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

        // Consider novel topics, not just novel authors
        let knownWorkoutTypes: Set<String> = Set(interests?.workoutTypeWeights.keys ?? [String: Double]().keys)

        var novelPosts = allPosts.filter { post in
            let isNovelAuthor = !knownAuthorIds.contains(post.authorId.uuidString)
            let isNovelTopic = post.workoutType.map { !knownWorkoutTypes.contains($0) } ?? false
            return (isNovelAuthor || isNovelTopic) && post.authorId != userId
        }

        // Shuffle novel posts for variety
        novelPosts.shuffle()

        guard !novelPosts.isEmpty else { return ranked }

        var result = ranked
        var novelIndex = 0

        // Insert at every interval-th slot
        var insertAt = interval - 1
        while insertAt < result.count && novelIndex < novelPosts.count {
            let novelPost = novelPosts[novelIndex]
            if !result.contains(where: { $0.id == novelPost.id }) {
                result.insert(novelPost, at: insertAt)
            }
            novelIndex += 1
            insertAt += interval
        }

        return result
    }

    // MARK: - Math Helpers

    private func sigmoid(_ x: Double, midpoint: Double, steepness: Double) -> Double {
        1.0 / (1.0 + exp(-steepness * (x - midpoint)))
    }
}
