import XCTest
@testable import GymQuest

@MainActor
final class FriendActivityTests: XCTestCase {

    func testBuild_recentPostsFromFollowedUsers() {
        let selfId = UUID()
        let friend = UUID()
        let stranger = UUID()

        let posts = [
            makePost(author: friend, hoursAgo: 2),
            makePost(author: stranger, hoursAgo: 1),
            makePost(author: friend, hoursAgo: 24)
        ]
        let follow = Friend(userId: selfId, odId: friend, odName: "Jake", odUsername: "jake")

        let result = FriendActivityService.build(
            selfId: selfId, allPosts: posts, checkIns: [],
            follows: [follow], profileLookup: [:]
        )

        let postItems = result.items.compactMap { item -> Post? in
            if case .post(let p) = item { return p } else { return nil }
        }
        XCTAssertEqual(postItems.count, 1, "Only one deduped post per friend")
        XCTAssertEqual(postItems.first?.authorId, friend)
    }

    func testBuild_inactiveFriendAfter3Days() {
        let selfId = UUID()
        let active = UUID()
        let inactive = UUID()

        let posts = [makePost(author: active, hoursAgo: 12)]
        let follows = [
            Friend(userId: selfId, odId: active, odName: "Active", odUsername: "active"),
            Friend(userId: selfId, odId: inactive, odName: "Ghost", odUsername: "ghost")
        ]

        let result = FriendActivityService.build(
            selfId: selfId, allPosts: posts, checkIns: [],
            follows: follows, profileLookup: [:]
        )

        let nudges = result.items.compactMap { item -> UUID? in
            if case .inactive(let uid, _, _, _) = item { return uid } else { return nil }
        }
        XCTAssertTrue(nudges.contains(inactive))
        XCTAssertFalse(nudges.contains(active))
    }

    func testBuild_emptyWhenNoFollows() {
        let result = FriendActivityService.build(
            selfId: UUID(), allPosts: [makePost(author: UUID(), hoursAgo: 1)],
            checkIns: [], follows: [], profileLookup: [:]
        )
        XCTAssertTrue(result.items.isEmpty)
    }

    func testBuild_checkInCountsAsActivity() {
        let selfId = UUID()
        let friend = UUID()
        let follows = [Friend(userId: selfId, odId: friend, odName: "F", odUsername: "f")]
        let checkIn = WorkoutCheckIn(
            userId: friend, userName: "F", userUsername: "f",
            workoutType: "Push", durationMinutes: 45,
            timestamp: Date().addingTimeInterval(-12 * 3600)
        )

        let result = FriendActivityService.build(
            selfId: selfId, allPosts: [], checkIns: [checkIn],
            follows: follows, profileLookup: [:]
        )
        let nudges = result.items.compactMap { item -> UUID? in
            if case .inactive = item { return nil } else { return nil }
        }
        // Friend has a recent check-in so should NOT appear as inactive
        let inactiveIds = result.items.compactMap { item -> UUID? in
            if case .inactive(let uid, _, _, _) = item { return uid } else { return nil }
        }
        XCTAssertFalse(inactiveIds.contains(friend))
    }

    private func makePost(author: UUID, hoursAgo: Int) -> Post {
        Post(authorId: author, authorName: "X", authorUsername: "x",
             timestamp: Date().addingTimeInterval(-Double(hoursAgo) * 3600),
             caption: "c", photoData: Data([0x01]))
    }
}
