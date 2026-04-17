import XCTest
@testable import GymQuest

@MainActor
final class CommunityTests: XCTestCase {

    // MARK: - CrewRhythmService

    func testCrewRhythm_countsDistinctDaysCrewTrained() {
        let selfId = UUID()
        let friend = UUID()

        let today = Date()
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: today) ?? today
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: today) ?? today

        let myWorkouts: [Workout] = [
            Workout(date: today, type: .push),
            Workout(date: yesterday, type: .pull)
        ]
        let friendPosts: [Post] = [
            postFromAuthor(friend, on: yesterday),
            postFromAuthor(friend, on: twoDaysAgo)
        ]
        let follow = Friend(userId: selfId, odId: friend, odName: "Jake", odUsername: "jake")

        let rhythm = CrewRhythmService.weekRhythm(
            selfId: selfId,
            myWorkouts: myWorkouts,
            friendPosts: friendPosts,
            follows: [follow],
            profileLookup: [:]
        )

        // Crew trained distinct days: today (me), yesterday (both), 2-days-ago (friend)
        XCTAssertEqual(rhythm.daysTrainedByCrew, 3)
        XCTAssertEqual(rhythm.userDaysTrained, 2)
    }

    func testCrewRhythm_topMemberIsFriendWithMostDays() {
        let selfId = UUID()
        let heavy = UUID()
        let light = UUID()
        let cal = Calendar.current
        let now = Date()

        let friendPosts: [Post] = (0..<4).map { postFromAuthor(heavy, on: cal.date(byAdding: .day, value: -$0, to: now)!) }
            + [postFromAuthor(light, on: now)]
        let follows = [
            Friend(userId: selfId, odId: heavy, odName: "Heavy", odUsername: "heavy"),
            Friend(userId: selfId, odId: light, odName: "Light", odUsername: "light")
        ]

        let rhythm = CrewRhythmService.weekRhythm(
            selfId: selfId,
            myWorkouts: [],
            friendPosts: friendPosts,
            follows: follows
        )

        XCTAssertEqual(rhythm.topMember?.username, "heavy")
        XCTAssertGreaterThanOrEqual(rhythm.topMember?.daysTrained ?? 0, 4)
    }

    func testCrewRhythm_duoDayCompanionSurfaces() {
        let selfId = UUID()
        let companion = UUID()
        let today = Date()

        let myWorkouts = [Workout(date: today, type: .legs)]
        let friendPosts = [postFromAuthor(companion, on: today)]
        let follow = Friend(userId: selfId, odId: companion, odName: "Sarah", odUsername: "sarah")

        let rhythm = CrewRhythmService.weekRhythm(
            selfId: selfId,
            myWorkouts: myWorkouts,
            friendPosts: friendPosts,
            follows: [follow]
        )
        XCTAssertEqual(rhythm.todayCompanions.first?.username, "sarah")
    }

    // MARK: - CommunityNudgeService

    func testNudge_duoDayFiresWhenCompanionPresent() {
        let rhythm = CrewRhythm(
            totalDaysTracked: 7, daysTrainedByCrew: 3, userDaysTrained: 1,
            perDayCrewCount: [0, 0, 1, 1, 1, 0, 2],
            topMember: nil,
            todayCompanions: [(name: "Sarah", username: "sarah")]
        )
        let nudges = CommunityNudgeService.nudges(
            rhythm: rhythm, justFinishedStates: [], profileLookup: [:],
            dismissedIds: []
        )
        XCTAssertTrue(nudges.contains(where: {
            if case .duoDay(let name) = $0 { return name == "Sarah" }
            return false
        }))
    }

    func testNudge_dismissalSuppresses() {
        let rhythm = CrewRhythm(
            totalDaysTracked: 7, daysTrainedByCrew: 3, userDaysTrained: 0,
            perDayCrewCount: [1, 0, 0, 1, 1, 0, 0],
            topMember: (name: "Jake", username: "jake", daysTrained: 3),
            todayCompanions: []
        )
        let first = CommunityNudgeService.nudges(
            rhythm: rhythm, justFinishedStates: [], profileLookup: [:], dismissedIds: []
        )
        // First call yields a friendOnStreak (3 days for Jake).
        XCTAssertTrue(first.contains(where: {
            if case .friendOnStreak(let name, _) = $0 { return name == "Jake" }
            return false
        }))
        // Dismissing should suppress on the next call.
        let dismissedId = first.first(where: {
            if case .friendOnStreak = $0 { return true } else { return false }
        })!.id
        let second = CommunityNudgeService.nudges(
            rhythm: rhythm, justFinishedStates: [], profileLookup: [:],
            dismissedIds: [dismissedId]
        )
        XCTAssertFalse(second.contains(where: {
            if case .friendOnStreak(let name, _) = $0 { return name == "Jake" }
            return false
        }))
    }

    func testNudge_justFinishedIsHighestPriority() {
        let rhythm = CrewRhythm(
            totalDaysTracked: 7, daysTrainedByCrew: 4, userDaysTrained: 0,
            perDayCrewCount: [1, 1, 1, 1, 0, 0, 0],
            topMember: (name: "Jake", username: "jake", daysTrained: 4),
            todayCompanions: []
        )
        let friendId = UUID()
        let finished = UserPresenceState(
            userId: friendId, status: .done, workoutType: "Push",
            startedAt: Date().addingTimeInterval(-1800)
        )
        finished.updatedAt = Date().addingTimeInterval(-5 * 60)

        let nudges = CommunityNudgeService.nudges(
            rhythm: rhythm, justFinishedStates: [finished],
            profileLookup: [friendId: makeProfile(id: friendId, name: "Marcus")],
            dismissedIds: []
        )
        if case .justFinished = nudges.first {
            XCTAssertTrue(true)
        } else {
            XCTFail("justFinished should appear first")
        }
    }

    // MARK: - Helpers

    private func postFromAuthor(_ id: UUID, on date: Date) -> Post {
        let p = Post(authorId: id, authorName: "X", authorUsername: "x", timestamp: date, caption: "c")
        return p
    }

    private func makeProfile(id: UUID, name: String) -> UserProfile {
        let p = UserProfile(name: name, username: name.lowercased())
        p.id = id
        return p
    }
}
