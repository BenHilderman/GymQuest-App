import XCTest
@testable import GymQuest

@MainActor
final class FeedBlenderTests: XCTestCase {

    func testBlend_forYouIncludesPostsRegardlessOfAuthor() {
        let profile = makeProfile()
        let mine     = makePost(authorId: profile.id, withMedia: true)
        let stranger = makePost(authorId: UUID(),     withMedia: true)
        let friend   = makePost(authorId: UUID(),     withMedia: true)

        let result = FeedBlenderService.shared.blend(
            posts: [mine, stranger, friend],
            profile: profile,
            followedIds: [],
            saved: [],
            mode: .forYou
        )
        XCTAssertEqual(Set(result.map(\.id)), Set([mine.id, stranger.id, friend.id]))
    }

    func testBlend_followingFiltersToFollowsPlusSelf() {
        let profile = makeProfile()
        let friendId = UUID()
        let stranger = UUID()

        let mine     = makePost(authorId: profile.id, withMedia: true)
        let fromFriend = makePost(authorId: friendId, withMedia: true)
        let fromStranger = makePost(authorId: stranger, withMedia: true)

        let result = FeedBlenderService.shared.blend(
            posts: [mine, fromFriend, fromStranger],
            profile: profile,
            followedIds: [friendId],
            saved: [],
            mode: .following
        )
        let ids = Set(result.map(\.id))
        XCTAssertTrue(ids.contains(mine.id))
        XCTAssertTrue(ids.contains(fromFriend.id))
        XCTAssertFalse(ids.contains(fromStranger.id))
    }

    func testBlend_excludesTextOnlyPosts() {
        let profile = makeProfile()
        let textOnly = makePost(authorId: UUID(), withMedia: false)
        let withPhoto = makePost(authorId: UUID(), withMedia: true)

        let result = FeedBlenderService.shared.blend(
            posts: [textOnly, withPhoto],
            profile: profile,
            followedIds: [],
            saved: [],
            mode: .forYou
        )
        XCTAssertEqual(result.map(\.id), [withPhoto.id])
    }

    func testBlend_dedupesDuplicateIds() {
        let profile = makeProfile()
        let p = makePost(authorId: UUID(), withMedia: true)
        let result = FeedBlenderService.shared.blend(
            posts: [p, p, p],
            profile: profile,
            followedIds: [],
            saved: [],
            mode: .forYou
        )
        XCTAssertEqual(result.count, 1)
    }

    // MARK: - WatchTimeTracker

    func testWatchTracker_accumulatesDwellAcrossClips() {
        let tracker = WatchTimeTracker.shared
        tracker.reset()
        let postA = UUID(), postB = UUID()
        let t0 = Date()
        tracker.didAppear(postA, at: t0)
        tracker.didAppear(postB, at: t0.addingTimeInterval(3))   // closes A with 3s
        tracker.didDisappear(postB, at: t0.addingTimeInterval(8)) // closes B with 5s

        XCTAssertEqual(tracker.dwell(for: postA), 3, accuracy: 0.01)
        XCTAssertEqual(tracker.dwell(for: postB), 5, accuracy: 0.01)
    }

    func testWatchTracker_revisitingClipAccumulates() {
        let tracker = WatchTimeTracker.shared
        tracker.reset()
        let post = UUID()
        let t0 = Date()
        tracker.didAppear(post, at: t0)
        tracker.didDisappear(post, at: t0.addingTimeInterval(2))     // +2
        tracker.didAppear(post, at: t0.addingTimeInterval(10))
        tracker.didDisappear(post, at: t0.addingTimeInterval(15))    // +5
        XCTAssertEqual(tracker.dwell(for: post), 7, accuracy: 0.01)
    }

    // MARK: - Phase 5: watch-time → ranker feedback

    func testWatchTimeBoost_longDwellOnAuthorBoostsTheirOtherPosts() {
        let tracker = WatchTimeTracker.shared
        tracker.reset()

        let profile = makeProfile()
        let creator = UUID()
        let other = UUID()

        let watched = makePost(authorId: creator, withMedia: true)   // user dwells on this
        let creatorOther = makePost(authorId: creator, withMedia: true)
        let stranger = makePost(authorId: other, withMedia: true)

        // Simulate a 30-second watch on the creator's clip.
        let t0 = Date()
        tracker.didAppear(watched.id, at: t0)
        tracker.didDisappear(watched.id, at: t0.addingTimeInterval(30))

        let result = FeedBlenderService.shared.blend(
            posts: [watched, creatorOther, stranger],
            profile: profile,
            followedIds: [],
            saved: [],
            mode: .forYou
        )

        // The creator's other post should outrank the stranger's because of
        // the per-author dwell boost.
        let creatorOtherIdx = result.firstIndex(where: { $0.id == creatorOther.id }) ?? .max
        let strangerIdx = result.firstIndex(where: { $0.id == stranger.id }) ?? .max
        XCTAssertLessThan(creatorOtherIdx, strangerIdx, "long-dwell author's other post should rank higher")

        tracker.reset()
    }

    func testWatchTimeBoost_skippedClipsGetDownranked() {
        let tracker = WatchTimeTracker.shared
        tracker.reset()

        let profile = makeProfile()
        let skipped = makePost(authorId: UUID(), withMedia: true)
        let neutral = makePost(authorId: UUID(), withMedia: true)
        // Equalize engagement so the only differentiator is dwell.
        skipped.likeCount = 10; neutral.likeCount = 10
        skipped.commentCount = 2; neutral.commentCount = 2

        // Simulate a sub-1.5s skip on `skipped`.
        let t0 = Date()
        tracker.didAppear(skipped.id, at: t0)
        tracker.didDisappear(skipped.id, at: t0.addingTimeInterval(0.5))

        let result = FeedBlenderService.shared.blend(
            posts: [skipped, neutral],
            profile: profile,
            followedIds: [],
            saved: [],
            mode: .forYou
        )

        let skippedIdx = result.firstIndex(where: { $0.id == skipped.id }) ?? .max
        let neutralIdx = result.firstIndex(where: { $0.id == neutral.id }) ?? .max
        XCTAssertGreaterThan(skippedIdx, neutralIdx, "sub-1.5s skip should rank below neutral")

        tracker.reset()
    }

    // MARK: - Phase 7A: music continuity

    func testBlend_groupsAdjacentSameSongClips() {
        let profile = makeProfile()
        let song1a = makePost(authorId: UUID(), withMedia: true, song: "Power", artist: "Kanye West")
        let other  = makePost(authorId: UUID(), withMedia: true, song: nil,     artist: nil)
        let song1b = makePost(authorId: UUID(), withMedia: true, song: "Power", artist: "Kanye West")
        let song2  = makePost(authorId: UUID(), withMedia: true, song: "Levels", artist: "Avicii")

        // Equalize engagement so natural order is: song1a, other, song1b, song2
        for p in [song1a, other, song1b, song2] { p.likeCount = 10 }

        let result = FeedBlenderService.shared.blend(
            posts: [song1a, other, song1b, song2],
            profile: profile,
            followedIds: [],
            saved: [],
            mode: .forYou
        )

        // song1a and song1b should end up adjacent (clustering is symmetric —
        // whichever comes first, the other should follow).
        guard let aIdx = result.firstIndex(where: { $0.id == song1a.id }),
              let bIdx = result.firstIndex(where: { $0.id == song1b.id }) else {
            XCTFail("Expected both song1a and song1b in result"); return
        }
        XCTAssertEqual(abs(bIdx - aIdx), 1, "same-song clips should be clustered adjacent")
    }

    // MARK: - Helpers

    private func makeProfile() -> UserProfile {
        UserProfile(name: "T", username: "t")
    }

    private func makePost(
        authorId: UUID,
        withMedia: Bool,
        song: String? = nil,
        artist: String? = nil
    ) -> Post {
        let p = Post(authorId: authorId, authorName: "x", authorUsername: "x", caption: "c")
        if withMedia { p.photoData = Data([0x01]) }
        p.songTitle = song
        p.artistName = artist
        return p
    }
}
