import Foundation

/// One item in the unified discover feed. Mixed content types ranked by
/// a single algorithm so the best stuff floats up regardless of format.
enum DiscoverFeedItem: Identifiable {
    case video(Post)
    case photo(Post)
    case suggestion(Post, reason: String)

    var id: String {
        switch self {
        case .video(let p): return "vid-\(p.id.uuidString)"
        case .photo(let p): return "photo-\(p.id.uuidString)"
        case .suggestion(let p, _): return "sug-\(p.id.uuidString)"
        }
    }

    var post: Post {
        switch self {
        case .video(let p), .photo(let p), .suggestion(let p, _): return p
        }
    }
}

/// Builds the unified discover feed. One ranking across ALL content —
/// videos, photos, and workout suggestions interleaved.
@MainActor
enum DiscoverFeedBuilder {

    struct Context {
        let allPosts: [Post]
        let profile: UserProfile
        let recentWorkouts: [Workout]
        let followedIds: Set<UUID>
        let watchDwell: [UUID: Double]    // postId → seconds
        let nextRecommendation: NextWorkoutRecommendation
    }

    static func build(from ctx: Context, typeFilter: String? = nil) -> [DiscoverFeedItem] {
        // 1. Pool: all posts with media
        var pool = ctx.allPosts.filter { hasMedia($0) }

        // 2. Type filter (from chip selector)
        if let filter = typeFilter, filter != "All" {
            if filter == "Video" {
                pool = pool.filter { isVideo($0) }
            } else if filter == "Photos" {
                pool = pool.filter { !isVideo($0) }
            } else {
                pool = pool.filter { $0.workoutType?.lowercased() == filter.lowercased() }
            }
        }

        // 3. Score and sort
        let scored = pool.map { post -> (Post, Double) in
            let score = computeScore(post: post, ctx: ctx)
            return (post, score)
        }
        let ranked = scored.sorted { $0.1 > $1.1 }.map(\.0)

        // 4. Diversity pass: no more than 2 consecutive same workout type.
        // Interleave with "unexpected" types the user doesn't usually train
        // to keep the grid interesting for discovery.
        let diversified = enforceDiversity(ranked, maxConsecutiveSameType: 2)

        // 5. Convert to feed items (video vs photo)
        var items: [DiscoverFeedItem] = diversified.prefix(24).map { post in
            isVideo(post) ? .video(post) : .photo(post)
        }

        // 6. Inject suggestion every ~8 items (less aggressive in grid mode)
        let recType = ctx.nextRecommendation.workoutType.lowercased()
        let suggestions = ctx.allPosts
            .filter { $0.workoutType?.lowercased() == recType && $0.sharedWorkoutData != nil }
            .sorted { $0.doabilityScore > $1.doabilityScore }
            .prefix(2)

        var sugIdx = 0
        var insertAt = 8
        while insertAt < items.count && sugIdx < suggestions.count {
            let sug = suggestions[sugIdx]
            if !items.contains(where: { $0.post.id == sug.id }) {
                items.insert(
                    .suggestion(sug, reason: ctx.nextRecommendation.reason),
                    at: min(insertAt, items.count)
                )
            }
            sugIdx += 1
            insertAt += 9
        }

        return items
    }

    /// No more than `max` consecutive items of the same workout type.
    /// When a run of same-type exceeds the limit, pull the next
    /// different-type item forward. Keeps the grid visually varied.
    private static func enforceDiversity(_ posts: [Post], maxConsecutiveSameType: Int) -> [Post] {
        guard posts.count > 3 else { return posts }
        var result = posts
        var i = 0
        while i < result.count - 1 {
            let curType = result[i].workoutType?.lowercased()
            var run = 1
            while i + run < result.count && result[i + run].workoutType?.lowercased() == curType {
                run += 1
            }
            if run > maxConsecutiveSameType {
                // Find next item with a different type and pull it forward
                let breakPoint = i + maxConsecutiveSameType
                for j in breakPoint..<result.count {
                    if result[j].workoutType?.lowercased() != curType {
                        let different = result.remove(at: j)
                        result.insert(different, at: breakPoint)
                        break
                    }
                }
            }
            i += 1
        }
        return result
    }

    // MARK: - Scoring

    private static func computeScore(post: Post, ctx: Context) -> Double {
        var score = 0.0

        // Engagement (20%)
        let eng = Double(post.likeCount + post.commentCount * 3 + post.timesUsed * 12)
        score += min(eng / 100.0, 1.0) * 0.20

        // Personalization — workout type affinity (25%)
        let recentTypes = ctx.recentWorkouts.prefix(10).map { $0.type.rawValue.lowercased() }
        if let type = post.workoutType?.lowercased() {
            let affinity = Double(recentTypes.filter { $0 == type }.count) / max(Double(recentTypes.count), 1)
            score += affinity * 0.25
        }

        // Watch time bias — author affinity (15%)
        let authorPosts = ctx.allPosts.filter { $0.authorId == post.authorId }
        let authorDwell = authorPosts.reduce(0.0) { $0 + (ctx.watchDwell[$1.id] ?? 0) }
        score += min(authorDwell / 120.0, 1.0) * 0.15

        // Doability (15%)
        score += post.doabilityScore * 0.15

        // Recency (15%)
        let age = Date().timeIntervalSince(post.timestamp) / 86_400
        score += max(0, 1.0 - min(age / 30.0, 1.0)) * 0.15

        // Format preference — video boost (10%)
        if isVideo(post) {
            score += 0.10
        }

        // Social boost — from followed users
        if ctx.followedIds.contains(post.authorId) {
            score += 0.05
        }

        // Exploration boost — types the user DOESN'T usually train get a
        // small bump so the feed surfaces unexpected but relevant content.
        // Prevents the echo chamber of only seeing your usual split.
        if let type = post.workoutType?.lowercased() {
            let trainedTypes = Set(ctx.recentWorkouts.prefix(10).map { $0.type.rawValue.lowercased() })
            if !trainedTypes.contains(type) {
                score += 0.04  // small enough to not override strong signals
            }
        }

        // High-entertainment boost — posts with both high engagement AND
        // video are likely genuinely interesting to watch even if they
        // don't match the user's training type.
        if isVideo(post) && (post.likeCount + post.commentCount * 3) > 20 {
            score += 0.06
        }

        return score
    }

    // MARK: - Helpers

    private static func hasMedia(_ post: Post) -> Bool {
        post.photoData != nil || post.videoData != nil || !post.mediaItems.isEmpty
    }

    private static func isVideo(_ post: Post) -> Bool {
        if let v = post.videoData, v.count >= 1024 { return true }
        if post.mediaItems.contains(where: { ($0.data?.count ?? 0) >= 1024 && $0.mediaType == .video }) {
            return true
        }
        return false
    }
}
