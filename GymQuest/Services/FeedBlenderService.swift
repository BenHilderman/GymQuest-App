import Foundation

/// Filter pill above the Scroll feed.
/// `forYou` is the algorithmic mix (default landing).
/// `following` narrows to people the user follows + their own posts.
enum ScrollFeedMode: String, CaseIterable, Identifiable {
    case forYou
    case following

    var id: String { rawValue }

    var label: String {
        switch self {
        case .forYou: return "For You"
        case .following: return "Following"
        }
    }
}

/// Builds the ordered list of posts that powers the vertical Scroll feed.
/// Reuses FeedRankingService for the heavy lifting; this layer adds the
/// mode filter, the media-required gate (no text-only posts in the
/// full-screen scroll), and dedup.
@MainActor
final class FeedBlenderService {
    static let shared = FeedBlenderService()
    private init() {}

    func blend(
        posts: [Post],
        profile: UserProfile,
        followedIds: Set<UUID>,
        saved: [SavedWorkout],
        mode: ScrollFeedMode
    ) -> [Post] {
        let withMedia = posts.filter { hasMedia($0) }

        let pool: [Post]
        switch mode {
        case .forYou:
            pool = withMedia
        case .following:
            // Following = my squad's content + my own posts. Empty squad
            // collapses to "just me", which is fine — better than blank.
            let allowed = followedIds.union([profile.id])
            pool = withMedia.filter { allowed.contains($0.authorId) }
        }

        let ranked = FeedRankingService.shared.rankPosts(
            pool,
            for: profile.id,
            interests: nil,
            category: nil,
            sessionContext: makeSessionContext(for: pool)
        )

        return musicGrouped(dedupe(ranked))
    }

    /// Cluster adjacent clips that share the same song — preserves the
    /// "vibe" of a musical moment in the Shorts scroll. Conservative:
    /// only nudges same-song clips forward within a short lookahead window
    /// so we don't dramatically re-rank the feed.
    private func musicGrouped(_ posts: [Post], lookAhead: Int = 4) -> [Post] {
        guard posts.count > 2 else { return posts }
        var result = posts
        var i = 0
        while i < result.count - 1 {
            let cur = result[i]
            guard let curSong = songKey(cur) else { i += 1; continue }
            // Next slot doesn't match — look ahead for a same-song candidate
            // and pull it forward to i+1.
            if songKey(result[i + 1]) != curSong {
                let upper = min(result.count, i + 1 + lookAhead)
                for j in (i + 2)..<upper {
                    if songKey(result[j]) == curSong {
                        let match = result.remove(at: j)
                        result.insert(match, at: i + 1)
                        break
                    }
                }
            }
            i += 1
        }
        return result
    }

    private func songKey(_ post: Post) -> String? {
        guard let song = post.songTitle, let artist = post.artistName,
              !song.isEmpty, !artist.isEmpty else { return nil }
        return "\(song)|\(artist)".lowercased()
    }

    /// Pulls cumulative dwell from WatchTimeTracker and rolls it up to a
    /// per-author total. Drives the watch-time boost in FeedRankingService.
    private func makeSessionContext(for pool: [Post]) -> SessionContext {
        let dwellByPost = WatchTimeTracker.shared.dwellByPost
        var dwellByAuthor: [UUID: Double] = [:]
        for post in pool {
            guard let dwell = dwellByPost[post.id], dwell > 0 else { continue }
            dwellByAuthor[post.authorId, default: 0] += dwell
        }
        return SessionContext(
            workoutBoosts: [:],
            authorBoosts: [:],
            hashtagBoosts: [:],
            skippedPostIds: [],
            notInterestedPostIds: [],
            dwellByPost: dwellByPost,
            dwellByAuthor: dwellByAuthor
        )
    }

    // MARK: - Helpers

    private func hasMedia(_ post: Post) -> Bool {
        post.photoData != nil || post.videoData != nil || !post.mediaItems.isEmpty
    }

    private func dedupe(_ posts: [Post]) -> [Post] {
        var seen = Set<UUID>()
        return posts.filter { seen.insert($0.id).inserted }
    }
}
