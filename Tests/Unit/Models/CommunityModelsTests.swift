import XCTest
@testable import GymQuest

@MainActor
final class CommunityModelsTests: XCTestCase {

    // MARK: - WorkoutCheckIn round-trip

    func testWorkoutCheckIn_storesAllFields() {
        let userId = UUID()
        let checkIn = WorkoutCheckIn(
            userId: userId,
            userName: "Tester",
            userUsername: "tester",
            workoutType: "Push",
            durationMinutes: 55,
            note: "Felt strong"
        )
        XCTAssertEqual(checkIn.userId, userId)
        XCTAssertEqual(checkIn.workoutType, "Push")
        XCTAssertEqual(checkIn.durationMinutes, 55)
        XCTAssertEqual(checkIn.note, "Felt strong")
    }

    func testWorkoutCheckIn_nilNoteSupported() {
        let checkIn = WorkoutCheckIn(
            userId: UUID(),
            userName: "x",
            userUsername: "x",
            workoutType: "Legs",
            durationMinutes: 30
        )
        XCTAssertNil(checkIn.note)
        XCTAssertEqual(checkIn.withFriends, "")
    }

    // MARK: - FloatingReaction

    func testFloatingReaction_idIsUnique() {
        let a = FloatingReaction(emoji: "🔥", xOffset: 0)
        let b = FloatingReaction(emoji: "🔥", xOffset: 0)
        XCTAssertNotEqual(a.id, b.id)
    }
}
