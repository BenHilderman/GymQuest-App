import XCTest
import SwiftData
@testable import GymQuest

final class SwiftDataIntegrationTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    @MainActor
    override func setUp() {
        super.setUp()
        container = try! TestModelContainer.create()
        context = container.mainContext
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    // MARK: - Full CRUD Lifecycle

    @MainActor
    func testWorkout_fullCRUDCycle() throws {
        // CREATE: Insert a workout with exercises and sets
        let workout = TestFixtures.insertFullWorkout(
            into: context,
            exerciseConfigs: [
                ("Bench Press", .chest, [(8, 135), (8, 135), (8, 135)]),
                ("Overhead Press", .shoulders, [(10, 85), (10, 85)])
            ]
        )

        // READ: Fetch and verify
        let descriptor = FetchDescriptor<Workout>()
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.exercises.count, 2)
        XCTAssertEqual(fetched.first?.totalSets, 5)

        // Verify totalVolume: (3 * 8 * 135) + (2 * 10 * 85) = 3240 + 1700 = 4940
        XCTAssertEqual(fetched.first?.totalVolume ?? 0, 4940.0, accuracy: 0.01)

        // UPDATE: Change RPE on a set
        let firstSet = fetched.first!.exercises[0].sets[0]
        firstSet.rpe = 9
        try context.save()

        // Verify update persisted
        let refetched = try context.fetch(descriptor)
        let updatedSet = refetched.first!.exercises[0].sets.first(where: { $0.id == firstSet.id })
        XCTAssertEqual(updatedSet?.rpe, 9)

        // DELETE: Remove workout
        context.delete(workout)
        try context.save()

        let afterDelete = try context.fetch(descriptor)
        XCTAssertEqual(afterDelete.count, 0)
    }

    // MARK: - Cascade Deletes

    @MainActor
    func testCascadeDelete_removesExercisesAndSets() throws {
        let workout = TestFixtures.insertFullWorkout(
            into: context,
            exerciseConfigs: [
                ("Squat", .quads, [(5, 225), (5, 225), (5, 225)])
            ]
        )

        // Verify exercises and sets exist
        let exerciseDescriptor = FetchDescriptor<Exercise>()
        let setDescriptor = FetchDescriptor<ExerciseSet>()

        XCTAssertEqual(try context.fetch(exerciseDescriptor).count, 1)
        XCTAssertEqual(try context.fetch(setDescriptor).count, 3)

        // Delete workout → cascade should delete exercises and sets
        context.delete(workout)
        try context.save()

        XCTAssertEqual(try context.fetch(exerciseDescriptor).count, 0, "Exercises should be cascade deleted")
        XCTAssertEqual(try context.fetch(setDescriptor).count, 0, "Sets should be cascade deleted")
    }

    // MARK: - PR Detection End-to-End

    @MainActor
    func testPRDetection_endToEnd() throws {
        let profile = TestFixtures.makeUserProfile()
        context.insert(profile)

        // Week 1: Bench Press 3x8 @ 135
        let week1 = TestFixtures.insertFullWorkout(
            into: context,
            date: Calendar.current.date(byAdding: .day, value: -7, to: Date())!,
            exerciseConfigs: [("Bench Press", .chest, [(8, 135), (8, 135), (8, 135)])]
        )

        // Week 2: Bench Press 3x8 @ 145 (PR!)
        let week2 = TestFixtures.insertFullWorkout(
            into: context,
            date: Date(),
            exerciseConfigs: [("Bench Press", .chest, [(8, 145), (8, 145), (8, 145)])]
        )

        let prService = PRService.shared
        let result = prService.detectAllPRs(
            workout: week2,
            allWorkouts: [week1, week2],
            profile: profile,
            modelContext: context
        )

        // Should detect at least one PR (weight PR at minimum)
        XCTAssertFalse(result.events.isEmpty, "Should detect PRs for improved workout")

        // Verify PREvent was persisted
        let prDescriptor = FetchDescriptor<PREvent>()
        let savedPRs = try context.fetch(prDescriptor)
        XCTAssertFalse(savedPRs.isEmpty, "PR events should be saved to SwiftData")
    }

    // MARK: - UserProfile Persistence

    @MainActor
    func testUserProfile_XPAndLevelPersist() throws {
        let profile = TestFixtures.makeUserProfile(xp: 0, level: 1)
        context.insert(profile)
        try context.save()

        // Add XP and level up
        let leveledUp = profile.addXP(150)
        XCTAssertTrue(leveledUp)
        try context.save()

        // Fetch fresh and verify
        let descriptor = FetchDescriptor<UserProfile>()
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.first?.xp, 150)
        XCTAssertEqual(fetched.first?.level, 2)
    }

    // MARK: - Multiple Workouts Query

    @MainActor
    func testMultipleWorkouts_sortByDate() throws {
        let date1 = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let date2 = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let date3 = Date()

        let _ = TestFixtures.insertFullWorkout(into: context, date: date1)
        let _ = TestFixtures.insertFullWorkout(into: context, date: date3)
        let _ = TestFixtures.insertFullWorkout(into: context, date: date2)

        let descriptor = FetchDescriptor<Workout>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let workouts = try context.fetch(descriptor)

        XCTAssertEqual(workouts.count, 3)
        XCTAssertTrue(workouts[0].date >= workouts[1].date)
        XCTAssertTrue(workouts[1].date >= workouts[2].date)
    }
}
