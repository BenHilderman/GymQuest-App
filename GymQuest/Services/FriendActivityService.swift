import Foundation

/// One item in the Friends section — either a recent post from a friend
/// or a nudge prompt for an inactive friend.
enum FriendFeedItem: Identifiable {
    case post(Post)
    case inactive(userId: UUID, name: String, username: String, lastActiveDate: Date?)

    var id: String {
        switch self {
        case .post(let p): return "fpost-\(p.id.uuidString)"
        case .inactive(let uid, _, _, _): return "inactive-\(uid.uuidString)"
        }
    }
}

/// Builds the data for the inline Friends section on Explore.
/// Two queries: recent friend posts (max 5, last 7 days) and inactive
/// friends (>3 days without a post or check-in).
@MainActor
enum FriendActivityService {

    struct Result {
        let items: [FriendFeedItem]
    }

    static func build(
        selfId: UUID,
        allPosts: [Post],
        checkIns: [WorkoutCheckIn],
        follows: [Friend],
        profileLookup: [UUID: UserProfile],
        now: Date = Date()
    ) -> Result {
        let followedIds = Set(follows.filter { $0.userId == selfId }.map(\.odId))
        guard !followedIds.isEmpty else { return Result(items: []) }

        let weekAgo = now.addingTimeInterval(-7 * 86_400)
        let inactiveThreshold = now.addingTimeInterval(-3 * 86_400)

        // Recent friend posts (last 7 days, newest first)
        let friendPosts = allPosts
            .filter { followedIds.contains($0.authorId) && $0.timestamp >= weekAgo }
            .sorted { $0.timestamp > $1.timestamp }

        // Dedup by author — one post per friend (most recent)
        var seenAuthors = Set<UUID>()
        let dedupedPosts: [Post] = friendPosts.compactMap { post in
            guard seenAuthors.insert(post.authorId).inserted else { return nil }
            return post
        }

        // Last activity date per friend (post OR check-in, whichever is newer)
        var lastActivity: [UUID: Date] = [:]
        for post in allPosts where followedIds.contains(post.authorId) {
            if let existing = lastActivity[post.authorId] {
                if post.timestamp > existing { lastActivity[post.authorId] = post.timestamp }
            } else {
                lastActivity[post.authorId] = post.timestamp
            }
        }
        for ci in checkIns where followedIds.contains(ci.userId) {
            if let existing = lastActivity[ci.userId] {
                if ci.timestamp > existing { lastActivity[ci.userId] = ci.timestamp }
            } else {
                lastActivity[ci.userId] = ci.timestamp
            }
        }

        // Inactive friends: followed but no activity in >3 days
        let inactiveFriends: [FriendFeedItem] = followedIds.compactMap { friendId in
            let last = lastActivity[friendId]
            // If they have recent activity, skip
            if let last, last >= inactiveThreshold { return nil }
            // If they posted in the deduped list, skip (covered above)
            if dedupedPosts.contains(where: { $0.authorId == friendId }) { return nil }

            let profile = profileLookup[friendId]
            let follow = follows.first(where: { $0.odId == friendId })
            let name = profile?.name ?? follow?.odName ?? "A friend"
            let username = profile?.username ?? follow?.odUsername ?? ""
            return .inactive(userId: friendId, name: name, username: username, lastActiveDate: last)
        }

        // Assemble: recent posts first (max 5), then inactive nudges (max 2)
        var items: [FriendFeedItem] = dedupedPosts.prefix(5).map { .post($0) }
        items.append(contentsOf: inactiveFriends.prefix(2))

        return Result(items: items)
    }
}
