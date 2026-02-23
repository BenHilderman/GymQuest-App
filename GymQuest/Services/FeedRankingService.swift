import Foundation
import SwiftData

@MainActor
final class FeedRankingService: ObservableObject {
    static let shared = FeedRankingService()

    // MARK: - Public API

    func rankPosts(_ posts: [Post], for userId: UUID, interests: UserInterestProfile?, category: String?) -> [Post] {
        // Category filter first
        var filtered = posts
        if let category, category != "All" {
            filtered = applyCategory(posts, category: category)
        }

        // Score and sort
        var recentAuthors: [UUID] = []
        let scored = filtered.map { post -> (Post, Double) in
            let score = computeScore(post: post, interests: interests, recentAuthors: &recentAuthors)
            return (post, score)
        }

        var ranked = scored.sorted { $0.1 > $1.1 }.map(\.0)

        // Discovery injection: every ~7th post, inject a novel author
        ranked = injectDiscoveryPosts(ranked: ranked, allPosts: posts, interests: interests, userId: userId)

        return ranked
    }

    // MARK: - Scoring

    private func computeScore(post: Post, interests: UserInterestProfile?, recentAuthors: inout [UUID]) -> Double {
        let engagement = engagementScore(for: post)
        let recency = recencyScore(for: post)
        let personalization = personalizationScore(for: post, interests: interests)
        let quality = contentQualityScore(for: post)
        let diversity = diversityPenalty(for: post, recentAuthors: &recentAuthors)
        let coldStart = coldStartBoost(for: post)

        return (engagement * 0.35) + (recency * 0.25) + (personalization * 0.25) + (quality * 0.10) + (diversity * 0.05) + coldStart
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

        let workoutAffinity = interests.workoutTypeWeights[post.workoutType ?? ""] ?? 0.5
        let authorAffinity = interests.authorWeights[post.authorId.uuidString] ?? 0.0
        let format: String = post.videoData != nil ? "video" : (post.photoData != nil ? "photo" : "text")
        let formatAffinity = interests.contentFormatWeights[format] ?? 0.5

        return workoutAffinity * 0.4 + authorAffinity * 0.35 + formatAffinity * 0.25
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
            return posts.filter { $0.caption.lowercased().contains("pr") || $0.caption.contains("🏆") }
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
        guard ranked.count >= 7 else { return ranked }

        let knownAuthorIds: Set<String>
        if let keys = interests?.authorWeights.keys {
            knownAuthorIds = Set(keys)
        } else {
            knownAuthorIds = []
        }
        let novelPosts = allPosts.filter { post in
            !knownAuthorIds.contains(post.authorId.uuidString) && post.authorId != userId
        }.sorted { $0.engagementScore > $1.engagementScore }

        guard !novelPosts.isEmpty else { return ranked }

        var result = ranked
        var novelIndex = 0

        // Insert at every 7th slot
        var insertAt = 6
        while insertAt < result.count && novelIndex < novelPosts.count {
            let novelPost = novelPosts[novelIndex]
            if !result.contains(where: { $0.id == novelPost.id }) {
                result.insert(novelPost, at: insertAt)
            }
            novelIndex += 1
            insertAt += 7
        }

        return result
    }

    // MARK: - Math Helpers

    private func sigmoid(_ x: Double, midpoint: Double, steepness: Double) -> Double {
        1.0 / (1.0 + exp(-steepness * (x - midpoint)))
    }
}
