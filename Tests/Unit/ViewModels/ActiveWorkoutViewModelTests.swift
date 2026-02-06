import XCTest
import SwiftData
@testable import GymQuest

final class ActiveWorkoutViewModelTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var profile: UserProfile!
    private var vm: ActiveWorkoutViewModel!

    @MainActor
    override func setUp() {
        super.setUp()
        container = try! TestModelContainer.create()
        context = container.mainContext
        profile = TestFixtures.makeUserProfile()
        context.insert(profile)
        vm = ActiveWorkoutViewModel(profile: profile, workoutType: .push, modelContext: context)
    }

    @MainActor
    override func tearDown() {
        vm?.cleanup()
        vm = nil
        profile = nil
        container = nil
        context = nil
        super.tearDown()
    }

    // MARK: - progressPercentage

    @MainActor
    func testProgressPercentage_zeroSets() {
        // No exercises → 0 sets → 0%
        XCTAssertEqual(vm.progressPercentage, 0)
    }

    @MainActor
    func testProgressPercentage_halfCompleted() {
        let exercise = ActiveExercise(
            name: "Bench Press",
            muscleGroup: .chest,
            sets: [
                ActiveSet(reps: 8, weight: 135, isCompleted: true),
                ActiveSet(reps: 8, weight: 135, isCompleted: false)
            ]
        )
        vm.exercises = [exercise]

        XCTAssertEqual(vm.progressPercentage, 0.5, accuracy: 0.01)
    }

    @MainActor
    func testProgressPercentage_allCompleted() {
        let exercise = ActiveExercise(
            name: "Bench Press",
            muscleGroup: .chest,
            sets: [
                ActiveSet(reps: 8, weight: 135, isCompleted: true),
                ActiveSet(reps: 8, weight: 135, isCompleted: true)
            ]
        )
        vm.exercises = [exercise]

        XCTAssertEqual(vm.progressPercentage, 1.0, accuracy: 0.01)
    }

    // MARK: - completedSetsCount

    @MainActor
    func testCompletedSetsCount_countsOnlyCompleted() {
        let exercise = ActiveExercise(
            name: "Bench Press",
            muscleGroup: .chest,
            sets: [
                ActiveSet(reps: 8, weight: 135, isCompleted: true),
                ActiveSet(reps: 8, weight: 135, isCompleted: false),
                ActiveSet(reps: 8, weight: 135, isCompleted: true)
            ]
        )
        vm.exercises = [exercise]

        XCTAssertEqual(vm.completedSetsCount, 2)
    }

    @MainActor
    func testCompletedSetsCount_multipleExercises() {
        let ex1 = ActiveExercise(
            name: "Bench Press",
            muscleGroup: .chest,
            sets: [
                ActiveSet(reps: 8, weight: 135, isCompleted: true),
                ActiveSet(reps: 8, weight: 135, isCompleted: true)
            ]
        )
        let ex2 = ActiveExercise(
            name: "OHP",
            muscleGroup: .shoulders,
            sets: [
                ActiveSet(reps: 10, weight: 85, isCompleted: true),
                ActiveSet(reps: 10, weight: 85, isCompleted: false)
            ]
        )
        vm.exercises = [ex1, ex2]

        XCTAssertEqual(vm.completedSetsCount, 3)
    }

    // MARK: - formatTime

    @MainActor
    func testFormatTime_90seconds() {
        XCTAssertEqual(vm.formatTime(90), "1:30")
    }

    @MainActor
    func testFormatTime_0seconds() {
        XCTAssertEqual(vm.formatTime(0), "0:00")
    }

    @MainActor
    func testFormatTime_60seconds() {
        XCTAssertEqual(vm.formatTime(60), "1:00")
    }

    @MainActor
    func testFormatTime_3661seconds() {
        XCTAssertEqual(vm.formatTime(3661), "61:01")
    }

    // MARK: - formatVolume

    @MainActor
    func testFormatVolume_under1000() {
        XCTAssertEqual(vm.formatVolume(500), "500")
    }

    @MainActor
    func testFormatVolume_2500() {
        XCTAssertEqual(vm.formatVolume(2500), "2.5k")
    }

    @MainActor
    func testFormatVolume_exactly1000() {
        XCTAssertEqual(vm.formatVolume(1000), "1.0k")
    }

    @MainActor
    func testFormatVolume_zero() {
        XCTAssertEqual(vm.formatVolume(0), "0")
    }

    // MARK: - checkMilestone

    @MainActor
    func testCheckMilestone_triggers25Percent() {
        let exercise = ActiveExercise(
            name: "Bench Press",
            muscleGroup: .chest,
            sets: [
                ActiveSet(reps: 8, weight: 135, isCompleted: true),
                ActiveSet(reps: 8, weight: 135, isCompleted: false),
                ActiveSet(reps: 8, weight: 135, isCompleted: false),
                ActiveSet(reps: 8, weight: 135, isCompleted: false)
            ]
        )
        vm.exercises = [exercise]
        vm.checkMilestone()

        XCTAssertNotNil(vm.activeMilestone)
        XCTAssertEqual(vm.activeMilestone?.percentage, 0.25)
        XCTAssertEqual(vm.lastCelebratedMilestone, 0.25)
    }

    @MainActor
    func testCheckMilestone_triggers50Percent() {
        let exercise = ActiveExercise(
            name: "Bench Press",
            muscleGroup: .chest,
            sets: [
                ActiveSet(reps: 8, weight: 135, isCompleted: true),
                ActiveSet(reps: 8, weight: 135, isCompleted: true),
                ActiveSet(reps: 8, weight: 135, isCompleted: false),
                ActiveSet(reps: 8, weight: 135, isCompleted: false)
            ]
        )
        vm.exercises = [exercise]
        vm.lastCelebratedMilestone = 0.25 // Already celebrated 25%
        vm.checkMilestone()

        XCTAssertNotNil(vm.activeMilestone)
        XCTAssertEqual(vm.activeMilestone?.percentage, 0.50)
    }

    @MainActor
    func testCheckMilestone_doesNotRepeatMilestone() {
        let exercise = ActiveExercise(
            name: "Bench Press",
            muscleGroup: .chest,
            sets: [
                ActiveSet(reps: 8, weight: 135, isCompleted: true),
                ActiveSet(reps: 8, weight: 135, isCompleted: false),
                ActiveSet(reps: 8, weight: 135, isCompleted: false),
                ActiveSet(reps: 8, weight: 135, isCompleted: false)
            ]
        )
        vm.exercises = [exercise]
        vm.lastCelebratedMilestone = 0.25 // Already celebrated 25%
        vm.checkMilestone()

        // Should NOT trigger again at 25%
        XCTAssertNil(vm.activeMilestone)
    }
}
