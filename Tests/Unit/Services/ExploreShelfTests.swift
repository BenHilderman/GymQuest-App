import XCTest
@testable import GymQuest

@MainActor
final class ExploreShelfTests: XCTestCase {

    // MARK: - Doability score boundaries

    func testDoability_pureCinematicClipScoresLow() {
        let post = Post(
            authorId: UUID(), authorName: "x", authorUsername: "x",
            caption: "raw clip"
        )
        post.mediaItems = [PostMedia(mediaType: .video)]   // single short clip, no exercise tag
        // No sharedWorkoutData, no setCount/duration, no workoutType
        XCTAssertLessThanOrEqual(post.doabilityScore, 0.15)
        XCTAssertEqual(post.intentTag, .watch)
    }

    func testDoability_runnableProgramScoresHigh() {
        let post = Post(
            authorId: UUID(), authorName: "x", authorUsername: "x",
            caption: "leg day blueprint",
            workoutType: "Legs",
            duration: 50,
            setCount: 18
        )
        let shared = SharedWorkoutData(title: "Heavy Legs", workoutType: "Legs", estimatedDuration: 50)
        post.sharedWorkoutData = try? JSONEncoder().encode(shared)
        XCTAssertGreaterThanOrEqual(post.doabilityScore, 0.55)
        XCTAssertEqual(post.intentTag, .train)
    }

    func testDoability_typeOnlyPostIsEither() {
        let post = Post(
            authorId: UUID(), authorName: "x", authorUsername: "x",
            caption: "good push",
            workoutType: "Push"
        )
        // Only +0.05 from workoutType branch
        let s = post.doabilityScore
        XCTAssertGreaterThan(s, 0.0)
        XCTAssertLessThan(s, 0.55)
        XCTAssertEqual(post.intentTag, .either)
    }

    // MARK: - SavedWorkout

    func testSavedWorkout_collectionRoundTrip() {
        let saved = SavedWorkout(userId: UUID(), postId: UUID(), collection: .watch)
        XCTAssertEqual(saved.collection, .watch)
        saved.collection = .train
        XCTAssertEqual(saved.collectionRaw, "train")
    }

    // MARK: - IntentInferenceService

    func testIntent_recentWorkoutForcesTrain() {
        let svc = IntentInferenceService.shared
        svc.setOverride(nil)
        // Force middle-of-night to confirm recency overrides time-of-day.
        let calendar = Calendar.current
        let nightTime = calendar.date(bySettingHour: 23, minute: 30, second: 0, of: Date()) ?? Date()
        let recent = makeWorkout(date: nightTime.addingTimeInterval(-3600))   // 1h before nightTime
        XCTAssertEqual(svc.inferred(recentWorkouts: [recent], now: nightTime), .train)
    }

    func testIntent_lateNightWithNoRecentWorkout_isWatch() {
        let svc = IntentInferenceService.shared
        svc.setOverride(nil)
        let calendar = Calendar.current
        let nightTime = calendar.date(bySettingHour: 23, minute: 30, second: 0, of: Date()) ?? Date()
        XCTAssertEqual(svc.inferred(recentWorkouts: [], now: nightTime), .watch)
    }

    func testIntent_overrideWins() {
        let svc = IntentInferenceService.shared
        svc.setOverride(.watch)
        let recent = makeWorkout(date: Date().addingTimeInterval(-1800))
        XCTAssertEqual(svc.currentIntent(recentWorkouts: [recent]), .watch)
        svc.setOverride(nil)
    }

    // MARK: - ExploreShelfService

    func testHeroPick_prefersDoableInDurationWindow() {
        let profile = makeProfile(preferredDuration: 45)
        let runnable = makePost(workoutType: "Push", duration: 45, withShared: true)
        let tooLong  = makePost(workoutType: "Push", duration: 120, withShared: true)
        let entertainment = makePost(workoutType: nil, duration: nil, withShared: false)

        let ctx = ExploreContext(
            profile: profile,
            recentWorkouts: [],
            allPosts: [tooLong, entertainment, runnable],
            saved: [],
            intent: .train
        )
        let pick = ExploreShelfService.shared.heroPick(for: ctx)
        XCTAssertEqual(pick?.id, runnable.id)
    }

    func testShelves_savedAlwaysFirst() {
        let profile = makeProfile()
        let savedPost = makePost(workoutType: "Push", duration: 30, withShared: true)
        let other     = makePost(workoutType: "Push", duration: 60, withShared: true)
        let saved = SavedWorkout(userId: profile.id, postId: savedPost.id, collection: .train)

        let ctx = ExploreContext(
            profile: profile,
            recentWorkouts: [makeWorkout(type: .push)],
            allPosts: [other, savedPost],
            saved: [saved],
            intent: .train
        )
        let shelves = ExploreShelfService.shared.shelves(for: ctx)
        XCTAssertEqual(shelves.first?.kind, .savedToDo)
    }

    // MARK: - RelativeDateString

    func testRelativeDate_today() {
        let now = Date()
        XCTAssertEqual(RelativeDateString.short(from: now, to: now), "today")
    }

    func testRelativeDate_yesterday() {
        let cal = Calendar.current
        let now = cal.startOfDay(for: Date()).addingTimeInterval(12 * 3600)
        let yest = cal.date(byAdding: .day, value: -1, to: now) ?? now
        XCTAssertEqual(RelativeDateString.short(from: yest, to: now), "yesterday")
    }

    func testRelativeDate_threeDaysAgo() {
        let cal = Calendar.current
        let now = cal.startOfDay(for: Date()).addingTimeInterval(12 * 3600)
        let then = cal.date(byAdding: .day, value: -3, to: now) ?? now
        XCTAssertEqual(RelativeDateString.short(from: then, to: now), "3 days ago")
    }

    func testRelativeDate_lastWeek() {
        let cal = Calendar.current
        let now = cal.startOfDay(for: Date()).addingTimeInterval(12 * 3600)
        let then = cal.date(byAdding: .day, value: -10, to: now) ?? now
        XCTAssertEqual(RelativeDateString.short(from: then, to: now), "last week")
    }

    // MARK: - Hero skip-list

    func testHeroPick_skipsExcludedIds() {
        let profile = makeProfile(preferredDuration: 45)
        let pickA = makePost(workoutType: "Push", duration: 45, withShared: true)
        let pickB = makePost(workoutType: "Push", duration: 50, withShared: true)
        let ctx = ExploreContext(
            profile: profile, recentWorkouts: [], allPosts: [pickA, pickB], saved: [], intent: .train
        )

        let first = ExploreShelfService.shared.heroPick(for: ctx)
        XCTAssertNotNil(first)
        let second = ExploreShelfService.shared.heroPick(for: ctx, excluding: [first!.id])
        XCTAssertNotNil(second)
        XCTAssertNotEqual(first?.id, second?.id)
    }

    func testHeroPick_fallsBackWhenAllRunnableExcluded() {
        let profile = makeProfile()
        let only = makePost(workoutType: "Push", duration: 45, withShared: true)
        let ctx = ExploreContext(
            profile: profile, recentWorkouts: [], allPosts: [only], saved: [], intent: .train
        )
        // Excluding the only runnable post should fall back to the broader pool
        // (still `only` here since there's nothing else); never return nil if
        // there's any post at all.
        XCTAssertNotNil(ExploreShelfService.shared.heroPick(for: ctx, excluding: [only.id]))
    }

    // MARK: - Custom collection shelves

    func testShelves_customCollectionsBecomeOwnShelves() {
        let profile = makeProfile()
        let postA = makePost(workoutType: "Push", duration: 30, withShared: true)
        let postB = makePost(workoutType: "Pull", duration: 40, withShared: true)
        let savedA = SavedWorkout(userId: profile.id, postId: postA.id, collection: .custom, customCollectionName: "Vacation prep")
        let savedB = SavedWorkout(userId: profile.id, postId: postB.id, collection: .custom, customCollectionName: "Vacation prep")
        let other  = SavedWorkout(userId: profile.id, postId: postA.id, collection: .custom, customCollectionName: "Bro split")

        let ctx = ExploreContext(
            profile: profile, recentWorkouts: [],
            allPosts: [postA, postB], saved: [savedA, savedB, other], intent: .train
        )
        let shelves = ExploreShelfService.shared.shelves(for: ctx)
        let titles = shelves.map(\.title)
        XCTAssertTrue(titles.contains("Vacation prep"))
        XCTAssertTrue(titles.contains("Bro split"))
        // Two distinct custom shelves => two distinct ids.
        let customIds = shelves.filter { $0.id.hasPrefix("custom-") }.map(\.id)
        XCTAssertEqual(Set(customIds).count, customIds.count)
    }

    // MARK: - Phase 3: video duration shapes doability

    func testDoability_longTutorialVideoBoosted() {
        let post = Post(
            authorId: UUID(), authorName: "x", authorUsername: "x",
            caption: "form check",
            workoutType: "Push"
        )
        post.mediaItems = [
            PostMedia(exerciseIndex: 0, mediaType: .video, videoDurationSeconds: 90)
        ]
        // Baseline (no duration): score is 0.20 (workoutType) + 0.20 (exerciseIndex tag) = 0.40
        // With long-form bonus: +0.10 = 0.50
        XCTAssertGreaterThanOrEqual(post.doabilityScore, 0.45)
    }

    func testDoability_shortCinematicLoopPenalized() {
        let post = Post(
            authorId: UUID(), authorName: "x", authorUsername: "x",
            caption: "vibes"
        )
        post.mediaItems = [
            PostMedia(mediaType: .video, videoDurationSeconds: 5)
        ]
        // Single-short-clip penalty (-0.20) + sub-8s no-tag penalty (-0.10) → 0
        XCTAssertEqual(post.doabilityScore, 0.0, accuracy: 0.001)
        XCTAssertEqual(post.intentTag, .watch)
    }

    // MARK: - Phase 3: calendar shelf

    func testCalendarShelf_usesScheduledTypeForToday() {
        let cal = Calendar.current
        let now = Date()
        let weekday = cal.component(.weekday, from: now)

        let profile = makeProfile()
        profile.weeklySchedule = [weekday: "Push"]

        let matching = makePost(workoutType: "Push", duration: 45, withShared: true)
        let other    = makePost(workoutType: "Pull", duration: 45, withShared: true)

        let ctx = ExploreContext(
            profile: profile, recentWorkouts: [],
            allPosts: [matching, other], saved: [], intent: .train, now: now
        )
        let shelves = ExploreShelfService.shared.shelves(for: ctx)
        let calendar = shelves.first { $0.kind == .onTheCalendar }
        XCTAssertNotNil(calendar)
        XCTAssertTrue(calendar!.title.contains("Push"))
        XCTAssertTrue(calendar!.posts.contains(where: { $0.id == matching.id }))
    }

    func testCalendarShelf_dayOverrideBeatsTemplate() {
        let cal = Calendar.current
        let now = Date()
        let weekday = cal.component(.weekday, from: now)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let key = formatter.string(from: now)

        let profile = makeProfile()
        profile.weeklySchedule = [weekday: "Push"]   // template says Push
        profile.dayOverrides = [key: "Legs"]         // override says Legs

        let push = makePost(workoutType: "Push", duration: 45, withShared: true)
        let legs = makePost(workoutType: "Legs", duration: 45, withShared: true)

        let ctx = ExploreContext(
            profile: profile, recentWorkouts: [],
            allPosts: [push, legs], saved: [], intent: .train, now: now
        )
        let shelf = ExploreShelfService.shared.shelves(for: ctx).first { $0.kind == .onTheCalendar }
        XCTAssertTrue(shelf?.title.contains("Legs") == true)
    }

    func testCalendarShelf_skipsWhenNoSchedule() {
        let profile = makeProfile()       // no weeklySchedule, no dayOverrides
        let post = makePost(workoutType: "Push", duration: 45, withShared: true)
        let ctx = ExploreContext(
            profile: profile, recentWorkouts: [],
            allPosts: [post], saved: [], intent: .train
        )
        XCTAssertNil(ExploreShelfService.shared.shelves(for: ctx).first { $0.kind == .onTheCalendar })
    }

    // MARK: - Phase 3: squad-is-doing shelf

    func testSquadIsDoing_picksDominantTypeFromFollowedAuthors() {
        let profile = makeProfile()
        let friendA = UUID()
        let friendB = UUID()
        let stranger = UUID()

        let posts: [Post] = [
            postFrom(friendA, type: "Push"),
            postFrom(friendA, type: "Push"),
            postFrom(friendB, type: "Push"),
            postFrom(friendB, type: "Pull"),
            postFrom(stranger, type: "Legs")     // not followed → ignored
        ]

        let ctx = ExploreContext(
            profile: profile, recentWorkouts: [],
            allPosts: posts, saved: [],
            followedUserIds: [friendA, friendB],
            intent: .train
        )
        let shelf = ExploreShelfService.shared.shelves(for: ctx).first { $0.kind == .squadIsDoing }
        XCTAssertNotNil(shelf)
        XCTAssertTrue(shelf!.title.contains("Push"))
    }

    func testSquadIsDoing_noShelfWithoutFollows() {
        let profile = makeProfile()
        let posts = [postFrom(UUID(), type: "Push"), postFrom(UUID(), type: "Push")]
        let ctx = ExploreContext(
            profile: profile, recentWorkouts: [],
            allPosts: posts, saved: [], followedUserIds: [],
            intent: .train
        )
        XCTAssertNil(ExploreShelfService.shared.shelves(for: ctx).first { $0.kind == .squadIsDoing })
    }

    // MARK: - Phase 3: editor's pick

    func testEditorsPick_combinesEngagementAndDoability() {
        let profile = makeProfile()
        // High engagement but very low doability — should be down-ranked.
        let viral = makePost(workoutType: nil, duration: nil, withShared: false)
        viral.likeCount = 500; viral.commentCount = 80

        // Mid engagement, high doability — should win.
        let solid = makePost(workoutType: "Push", duration: 45, withShared: true)
        solid.likeCount = 20; solid.commentCount = 4

        // Filler so the shelf has the >=4 minimum to render.
        let filler1 = makePost(workoutType: "Push", duration: 30, withShared: true)
        let filler2 = makePost(workoutType: "Pull", duration: 30, withShared: true)

        let ctx = ExploreContext(
            profile: profile, recentWorkouts: [],
            allPosts: [viral, solid, filler1, filler2], saved: [], intent: .train
        )
        let shelf = ExploreShelfService.shared.shelves(for: ctx).first { $0.kind == .editorsPick }
        XCTAssertNotNil(shelf)
        XCTAssertEqual(shelf?.posts.first?.id, solid.id, "doable solid post should outrank pure-viral with no structure")
    }

    private func postFrom(_ authorId: UUID, type: String) -> Post {
        let p = Post(
            authorId: authorId,
            authorName: "f", authorUsername: "f",
            caption: "c", workoutType: type, duration: 45, setCount: 12
        )
        let shared = SharedWorkoutData(title: "T", workoutType: type, estimatedDuration: 45)
        p.sharedWorkoutData = try? JSONEncoder().encode(shared)
        return p
    }

    // MARK: - Helpers

    private func makeProfile(preferredDuration: Int = 60) -> UserProfile {
        let p = UserProfile(name: "Test", username: "test")
        p.preferredWorkoutDuration = preferredDuration
        return p
    }

    private func makeWorkout(date: Date = Date(), type: WorkoutType = .push) -> Workout {
        Workout(date: date, type: type)
    }

    private func makePost(workoutType: String?, duration: Int?, withShared: Bool) -> Post {
        let post = Post(
            authorId: UUID(), authorName: "a", authorUsername: "a",
            caption: "p",
            workoutType: workoutType,
            duration: duration ?? 0,
            setCount: 12
        )
        if withShared {
            let shared = SharedWorkoutData(
                title: "T",
                workoutType: workoutType ?? "Push",
                estimatedDuration: duration ?? 30
            )
            post.sharedWorkoutData = try? JSONEncoder().encode(shared)
        }
        return post
    }
}
