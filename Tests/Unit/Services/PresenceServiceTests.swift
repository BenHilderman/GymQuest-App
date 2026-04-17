import XCTest
@testable import GymQuest

@MainActor
final class PresenceServiceTests: XCTestCase {

    // MARK: - liveNow filtering

    func testLiveNow_includesSelfAndFollowsWhoAreTraining() {
        let selfId = UUID()
        let friendId = UUID()
        let strangerId = UUID()

        let states = [
            makeState(userId: selfId, status: .training, mins: 5),
            makeState(userId: friendId, status: .training, mins: 10),
            makeState(userId: strangerId, status: .training, mins: 2)
        ]
        let result = PresenceService.liveNow(
            from: states,
            selfId: selfId,
            followedIds: [friendId]
        )
        XCTAssertEqual(Set(result.map(\.userId)), [selfId, friendId])
    }

    func testLiveNow_excludesIdleAndDone() {
        let selfId = UUID()
        let aId = UUID()
        let bId = UUID()

        let states = [
            makeState(userId: selfId, status: .training, mins: 5),
            makeState(userId: aId, status: .idle, mins: 0),
            makeState(userId: bId, status: .done, mins: 47)
        ]
        let result = PresenceService.liveNow(
            from: states,
            selfId: selfId,
            followedIds: [aId, bId]
        )
        XCTAssertEqual(result.map(\.userId), [selfId])
    }

    func testLiveNow_excludesStaleSessionsOverThreeHours() {
        let selfId = UUID()
        let oldStart = Date().addingTimeInterval(-4 * 3600)
        let stale = UserPresenceState(userId: selfId, status: .training, workoutType: "Push", startedAt: oldStart)

        let result = PresenceService.liveNow(from: [stale], selfId: selfId, followedIds: [])
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - justFinished window

    func testJustFinished_includesFollowedUsersDoneInLast10Min() {
        let friendId = UUID()
        let fresh = UserPresenceState(userId: friendId, status: .done, workoutType: "Legs", startedAt: Date().addingTimeInterval(-1800))
        fresh.updatedAt = Date().addingTimeInterval(-5 * 60)   // 5 min ago

        let old = UserPresenceState(userId: UUID(), status: .done, workoutType: "Push", startedAt: Date().addingTimeInterval(-3600))
        old.updatedAt = Date().addingTimeInterval(-30 * 60)    // 30 min ago — outside window

        let result = PresenceService.justFinished(
            from: [fresh, old],
            followedIds: [friendId, old.userId]
        )
        XCTAssertEqual(result.map(\.userId), [friendId])
    }

    // MARK: - Helpers

    private func makeState(userId: UUID, status: PresenceStatus, mins: Int) -> UserPresenceState {
        UserPresenceState(
            userId: userId,
            status: status,
            workoutType: "Push",
            startedAt: Date().addingTimeInterval(-Double(mins * 60))
        )
    }
}
