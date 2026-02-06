import XCTest
import SwiftData
@testable import GymQuest

final class WorkoutTests: XCTestCase {

    // MARK: - totalSets

    func testTotalSets_multipleExercises() {
        let sets1 = [
            TestFixtures.makeExerciseSet(reps: 8, weight: 135),
            TestFixtures.makeExerciseSet(reps: 8, weight: 135),
            TestFixtures.makeExerciseSet(reps: 8, weight: 135)
        ]
        let sets2 = [
            TestFixtures.makeExerciseSet(reps: 10, weight: 85),
            TestFixtures.makeExerciseSet(reps: 10, weight: 85)
        ]

        let ex1 = TestFixtures.makeExercise(name: "Bench Press", sets: sets1)
        let ex2 = TestFixtures.makeExercise(name: "OHP", muscleGroup: .shoulders, sets: sets2)
        let workout = TestFixtures.makeWorkout(exercises: [ex1, ex2])

        XCTAssertEqual(workout.totalSets, 5)
    }

    func testTotalSets_emptyExercises() {
        let workout = TestFixtures.makeWorkout(exercises: [])
        XCTAssertEqual(workout.totalSets, 0)
    }

    // MARK: - totalVolume

    func testTotalVolume_calculatesWeightTimesReps() {
        // 3 sets of 8x135 = 3 * (8 * 135) = 3240
        let sets = [
            TestFixtures.makeExerciseSet(reps: 8, weight: 135),
            TestFixtures.makeExerciseSet(reps: 8, weight: 135),
            TestFixtures.makeExerciseSet(reps: 8, weight: 135)
        ]
        let exercise = TestFixtures.makeExercise(name: "Bench Press", sets: sets)
        let workout = TestFixtures.makeWorkout(exercises: [exercise])

        XCTAssertEqual(workout.totalVolume, 3240.0, accuracy: 0.01)
    }

    func testTotalVolume_bodyweightSetsContributeZero() {
        let sets = [
            TestFixtures.makeExerciseSet(reps: 15, weight: 0),
            TestFixtures.makeExerciseSet(reps: 12, weight: 0)
        ]
        let exercise = TestFixtures.makeExercise(name: "Push-ups", sets: sets)
        let workout = TestFixtures.makeWorkout(exercises: [exercise])

        XCTAssertEqual(workout.totalVolume, 0.0)
    }

    // MARK: - xpValue

    func testXPValue_baseCalculation() {
        // xp = 20 + (totalSets * 5) + (rpe >= 8 ? 10 : 0) + (prEvents.count * 15)
        let sets = [
            TestFixtures.makeExerciseSet(reps: 8, weight: 135),
            TestFixtures.makeExerciseSet(reps: 8, weight: 135)
        ]
        let exercise = TestFixtures.makeExercise(sets: sets)
        let workout = TestFixtures.makeWorkout(rpe: 7, exercises: [exercise])

        // 20 + (2 * 5) + 0 + 0 = 30
        XCTAssertEqual(workout.xpValue, 30)
    }

    func testXPValue_highRPEBonus() {
        let sets = [
            TestFixtures.makeExerciseSet(reps: 5, weight: 225)
        ]
        let exercise = TestFixtures.makeExercise(sets: sets)
        let workout = TestFixtures.makeWorkout(rpe: 9, exercises: [exercise])

        // 20 + (1 * 5) + 10 + 0 = 35
        XCTAssertEqual(workout.xpValue, 35)
    }

    func testXPValue_withPRBonus() {
        let sets = [
            TestFixtures.makeExerciseSet(reps: 5, weight: 225)
        ]
        let exercise = TestFixtures.makeExercise(sets: sets)
        let pr = PREvent(exerciseName: "Bench Press", prType: .weightPR, newValue: 225)
        let workout = TestFixtures.makeWorkout(rpe: 8, exercises: [exercise], prEvents: [pr])

        // 20 + (1 * 5) + 10 + (1 * 15) = 50
        XCTAssertEqual(workout.xpValue, 50)
    }

    // MARK: - hasPRs

    func testHasPRs_trueWhenPREventsExist() {
        let pr = PREvent(exerciseName: "Squat", prType: .weightPR, newValue: 315)
        let workout = TestFixtures.makeWorkout(prEvents: [pr])
        XCTAssertTrue(workout.hasPRs)
    }

    func testHasPRs_falseWhenNoPREvents() {
        let workout = TestFixtures.makeWorkout()
        XCTAssertFalse(workout.hasPRs)
    }

    // MARK: - topSets

    func testTopSets_returnsHighestWeightPerExercise() {
        let benchSets = [
            TestFixtures.makeExerciseSet(reps: 8, weight: 135),
            TestFixtures.makeExerciseSet(reps: 5, weight: 185),
            TestFixtures.makeExerciseSet(reps: 3, weight: 205)
        ]
        let ohpSets = [
            TestFixtures.makeExerciseSet(reps: 10, weight: 85),
            TestFixtures.makeExerciseSet(reps: 8, weight: 95)
        ]

        let bench = TestFixtures.makeExercise(name: "Bench Press", sets: benchSets)
        let ohp = TestFixtures.makeExercise(name: "OHP", muscleGroup: .shoulders, sets: ohpSets)
        let workout = TestFixtures.makeWorkout(exercises: [bench, ohp])

        let tops = workout.topSets
        XCTAssertEqual(tops.count, 2)
        XCTAssertEqual(tops[0].weight, 205)
        XCTAssertEqual(tops[0].reps, 3)
        XCTAssertEqual(tops[1].weight, 95)
        XCTAssertEqual(tops[1].reps, 8)
    }
}
