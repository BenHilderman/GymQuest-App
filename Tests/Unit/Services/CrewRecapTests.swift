import XCTest
@testable import GymQuest

@MainActor
final class CrewRecapTests: XCTestCase {

    func testRecap_nilWhenNoActivity() {
        let recap = CrewRecapService.lastWeekRecap(
            selfId: UUID(),
            myWorkouts: [],
            friendPosts: [],
            follows: [],
            checkIns: []
        )
        XCTAssertNil(recap)
    }

    func testRecap_countsUserDaysCorrectly() {
        let selfId = UUID()
        let cal = Calendar.current
        let lastMonday = lastWeekMonday()
        let myWorkouts = [
            Workout(date: lastMonday, type: .push),
            Workout(date: cal.date(byAdding: .day, value: 3, to: lastMonday)!, type: .legs)
        ]
        let recap = CrewRecapService.lastWeekRecap(
            selfId: selfId,
            myWorkouts: myWorkouts,
            friendPosts: [],
            follows: [],
            checkIns: []
        )
        XCTAssertEqual(recap?.userDaysTrained, 2)
        XCTAssertEqual(recap?.crewDaysTrained, 2)
        XCTAssertEqual(recap?.duoDays, 0)   // no one else trained with me
    }

    func testRecap_topMemberIsFriendWithMostDays() {
        let selfId = UUID()
        let friend = UUID()
        let cal = Calendar.current
        let monday = lastWeekMonday()
        let friendPosts: [Post] = (0..<4).map { offset in
            Post(authorId: friend, authorName: "Jake", authorUsername: "jake",
                 timestamp: cal.date(byAdding: .day, value: offset, to: monday)!,
                 caption: "c")
        }
        let follow = Friend(userId: selfId, odId: friend, odName: "Jake", odUsername: "jake")

        let recap = CrewRecapService.lastWeekRecap(
            selfId: selfId,
            myWorkouts: [],
            friendPosts: friendPosts,
            follows: [follow],
            checkIns: []
        )
        XCTAssertEqual(recap?.topMemberName, "Jake")
        XCTAssertEqual(recap?.topMemberDays, 4)
    }

    func testRecap_duoDayCountsWhenBothTrainedSameDay() {
        let selfId = UUID()
        let friend = UUID()
        let cal = Calendar.current
        let monday = lastWeekMonday()
        let aligned = cal.date(byAdding: .day, value: 2, to: monday)!
        let myWorkouts = [Workout(date: aligned, type: .pull)]
        let friendPosts = [Post(authorId: friend, authorName: "Sarah", authorUsername: "sarah",
                                timestamp: aligned, caption: "c")]
        let follow = Friend(userId: selfId, odId: friend, odName: "Sarah", odUsername: "sarah")

        let recap = CrewRecapService.lastWeekRecap(
            selfId: selfId,
            myWorkouts: myWorkouts,
            friendPosts: friendPosts,
            follows: [follow],
            checkIns: []
        )
        XCTAssertEqual(recap?.duoDays, 1)
    }

    func testRecap_headlineReflectsStrongWeek() {
        let data = CrewWeeklyRecapData(
            weekStartDate: Date(), weekEndDate: Date(),
            crewDaysTrained: 7, userDaysTrained: 4,
            topMemberName: "Jake", topMemberDays: 6,
            duoDays: 3, totalCheckIns: 12, crewSize: 3
        )
        XCTAssertTrue(data.headline.lowercased().contains("perfect week"))
    }

    // MARK: - Helpers

    /// Monday of the previous ISO week (for aligning test fixtures to the
    /// window CrewRecapService measures).
    private func lastWeekMonday() -> Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let daysSinceMonday = (weekday + 5) % 7
        let thisMonday = cal.date(byAdding: .day, value: -daysSinceMonday, to: today)!
        return cal.date(byAdding: .day, value: -7, to: thisMonday)!
    }
}
