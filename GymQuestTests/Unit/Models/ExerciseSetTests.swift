import XCTest
@testable import GymQuest

final class ExerciseSetTests: XCTestCase {

    // MARK: - estimated1RM (Epley formula: weight × (1 + reps/30))

    func testEstimated1RM_validWeightAndReps() {
        let set = TestFixtures.makeExerciseSet(reps: 8, weight: 185)
        // 185 * (1 + 8/30) = 185 * 1.2667 ≈ 234.33
        XCTAssertNotNil(set.estimated1RM)
        XCTAssertEqual(set.estimated1RM!, 185 * (1 + 8.0 / 30.0), accuracy: 0.01)
    }

    func testEstimated1RM_singleRep() {
        let set = TestFixtures.makeExerciseSet(reps: 1, weight: 315)
        // 315 * (1 + 1/30) = 315 * 1.0333 ≈ 325.5
        XCTAssertNotNil(set.estimated1RM)
        XCTAssertEqual(set.estimated1RM!, 315 * (1 + 1.0 / 30.0), accuracy: 0.01)
    }

    func testEstimated1RM_nilWhenWeightIsZero() {
        let set = TestFixtures.makeExerciseSet(reps: 15, weight: 0)
        XCTAssertNil(set.estimated1RM)
    }

    func testEstimated1RM_nilWhenRepsIsZero() {
        let set = TestFixtures.makeExerciseSet(reps: 0, weight: 135)
        XCTAssertNil(set.estimated1RM)
    }

    func testEstimated1RM_nilWhenRepsExceed12() {
        let set = TestFixtures.makeExerciseSet(reps: 15, weight: 135)
        XCTAssertNil(set.estimated1RM)
    }

    func testEstimated1RM_validAt12Reps() {
        let set = TestFixtures.makeExerciseSet(reps: 12, weight: 135)
        // 135 * (1 + 12/30) = 135 * 1.4 = 189
        XCTAssertNotNil(set.estimated1RM)
        XCTAssertEqual(set.estimated1RM!, 189.0, accuracy: 0.01)
    }

    // MARK: - displayString

    func testDisplayString_weightSet() {
        let set = TestFixtures.makeExerciseSet(reps: 8, weight: 135)
        XCTAssertEqual(set.displayString, "8 × 135 lbs")
    }

    func testDisplayString_bodyweightSet() {
        let set = TestFixtures.makeExerciseSet(reps: 15, weight: 0)
        XCTAssertEqual(set.displayString, "15 reps")
    }

    func testDisplayString_timedSet_minutesAndSeconds() {
        let set = TestFixtures.makeExerciseSet(reps: 0, weight: 0, durationSec: 90)
        XCTAssertEqual(set.displayString, "1m 30s")
    }

    func testDisplayString_timedSet_secondsOnly() {
        let set = TestFixtures.makeExerciseSet(reps: 0, weight: 0, durationSec: 45)
        XCTAssertEqual(set.displayString, "45s")
    }

    func testDisplayString_distanceSet() {
        let set = TestFixtures.makeExerciseSet(reps: 0, weight: 0, distance: 3.1)
        XCTAssertEqual(set.displayString, "3.1 mi")
    }

    func testDisplayString_timedTakesPriorityOverWeight() {
        // If durationSec is set, it should display time even if weight/reps exist
        let set = TestFixtures.makeExerciseSet(reps: 8, weight: 135, durationSec: 60)
        XCTAssertEqual(set.displayString, "1m 0s")
    }
}
