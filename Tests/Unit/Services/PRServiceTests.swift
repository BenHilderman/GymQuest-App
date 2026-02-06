import XCTest
import SwiftData
@testable import GymQuest

final class PRServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var prService: PRService!

    @MainActor
    override func setUp() {
        super.setUp()
        container = try! TestModelContainer.create()
        context = container.mainContext
        prService = PRService.shared
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    // MARK: - Weight PR Detection

    @MainActor
    func testDetectWeightPR_findsNewWeightPR() {
        let profile = TestFixtures.makeUserProfile()
        context.insert(profile)

        // Previous workout: Bench Press 3x8 @ 135
        let previousWorkout = TestFixtures.insertFullWorkout(
            into: context,
            date: Calendar.current.date(byAdding: .day, value: -7, to: Date())!,
            exerciseConfigs: [("Bench Press", .chest, [(8, 135), (8, 135), (8, 135)])]
        )

        // New workout: Bench Press 3x8 @ 145 (heavier at same reps)
        let newWorkout = TestFixtures.insertFullWorkout(
            into: context,
            date: Date(),
            exerciseConfigs: [("Bench Press", .chest, [(8, 145), (8, 145), (8, 145)])]
        )

        let result = prService.detectAllPRs(
            workout: newWorkout,
            allWorkouts: [previousWorkout, newWorkout],
            profile: profile,
            modelContext: context
        )

        let weightPRs = result.events.filter { $0.prType == .weightPR }
        XCTAssertFalse(weightPRs.isEmpty, "Should detect a weight PR")
        XCTAssertEqual(weightPRs.first?.exerciseName, "Bench Press")
        XCTAssertEqual(weightPRs.first?.newValue, 145)
    }

    // MARK: - Rep PR Detection

    @MainActor
    func testDetectRepPR_findsNewRepPR() {
        let profile = TestFixtures.makeUserProfile()
        context.insert(profile)

        // Previous: Squat 3x5 @ 225
        let previousWorkout = TestFixtures.insertFullWorkout(
            into: context,
            date: Calendar.current.date(byAdding: .day, value: -7, to: Date())!,
            exerciseConfigs: [("Squat", .quads, [(5, 225), (5, 225), (5, 225)])]
        )

        // New: Squat 3x8 @ 225 (more reps at same weight)
        let newWorkout = TestFixtures.insertFullWorkout(
            into: context,
            date: Date(),
            exerciseConfigs: [("Squat", .quads, [(8, 225), (8, 225), (8, 225)])]
        )

        let result = prService.detectAllPRs(
            workout: newWorkout,
            allWorkouts: [previousWorkout, newWorkout],
            profile: profile,
            modelContext: context
        )

        let repPRs = result.events.filter { $0.prType == .repPR }
        XCTAssertFalse(repPRs.isEmpty, "Should detect a rep PR")
        XCTAssertEqual(repPRs.first?.exerciseName, "Squat")
    }

    // MARK: - Volume PR Detection

    @MainActor
    func testDetectVolumePR_findsNewVolumePR() {
        let profile = TestFixtures.makeUserProfile()
        context.insert(profile)

        // Previous: Deadlift 3x5 @ 225 = volume 3375
        let previousWorkout = TestFixtures.insertFullWorkout(
            into: context,
            date: Calendar.current.date(byAdding: .day, value: -7, to: Date())!,
            exerciseConfigs: [("Deadlift", .back, [(5, 225), (5, 225), (5, 225)])]
        )

        // New: Deadlift 4x8 @ 225 = volume 7200 (>10% improvement, >500 lbs)
        let newWorkout = TestFixtures.insertFullWorkout(
            into: context,
            date: Date(),
            exerciseConfigs: [("Deadlift", .back, [(8, 225), (8, 225), (8, 225), (8, 225)])]
        )

        let result = prService.detectAllPRs(
            workout: newWorkout,
            allWorkouts: [previousWorkout, newWorkout],
            profile: profile,
            modelContext: context
        )

        let volumePRs = result.events.filter { $0.prType == .volumePR }
        XCTAssertFalse(volumePRs.isEmpty, "Should detect a volume PR")
    }

    // MARK: - Estimated 1RM PR Detection

    @MainActor
    func testDetectEstimated1RMPR_findsNewE1RMPR() {
        let profile = TestFixtures.makeUserProfile()
        context.insert(profile)

        // Previous: Bench 3x8 @ 185 → e1RM = 185 * (1 + 8/30) = ~234.3
        let previousWorkout = TestFixtures.insertFullWorkout(
            into: context,
            date: Calendar.current.date(byAdding: .day, value: -7, to: Date())!,
            exerciseConfigs: [("Bench Press", .chest, [(8, 185), (8, 185), (8, 185)])]
        )

        // New: Bench 3x5 @ 225 → e1RM = 225 * (1 + 5/30) = ~262.5 (improvement > 5 lbs)
        let newWorkout = TestFixtures.insertFullWorkout(
            into: context,
            date: Date(),
            exerciseConfigs: [("Bench Press", .chest, [(5, 225), (5, 225), (5, 225)])]
        )

        let result = prService.detectAllPRs(
            workout: newWorkout,
            allWorkouts: [previousWorkout, newWorkout],
            profile: profile,
            modelContext: context
        )

        let e1rmPRs = result.events.filter { $0.prType == .estimated1RMPR }
        XCTAssertFalse(e1rmPRs.isEmpty, "Should detect an estimated 1RM PR")
    }

    // MARK: - No PR When No Improvement

    @MainActor
    func testDetectAllPRs_noPRWhenNoImprovement() {
        let profile = TestFixtures.makeUserProfile()
        context.insert(profile)

        // Previous: Bench 3x8 @ 135
        let previousWorkout = TestFixtures.insertFullWorkout(
            into: context,
            date: Calendar.current.date(byAdding: .day, value: -7, to: Date())!,
            exerciseConfigs: [("Bench Press", .chest, [(8, 135), (8, 135), (8, 135)])]
        )

        // New: Same exact workout
        let newWorkout = TestFixtures.insertFullWorkout(
            into: context,
            date: Date(),
            exerciseConfigs: [("Bench Press", .chest, [(8, 135), (8, 135), (8, 135)])]
        )

        let result = prService.detectAllPRs(
            workout: newWorkout,
            allWorkouts: [previousWorkout, newWorkout],
            profile: profile,
            modelContext: context
        )

        XCTAssertTrue(result.events.isEmpty, "Should not detect any PRs for identical workout")
    }
}
