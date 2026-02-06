import XCTest
import SwiftData
@testable import GymQuest

final class SwiftDataPerformanceTests: XCTestCase {

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

    // MARK: - Fetch 1000 Workouts

    @MainActor
    func testPerformance_fetch1000Workouts() throws {
        // Seed 1000 workouts
        for i in 0..<1000 {
            let date = Calendar.current.date(byAdding: .hour, value: -i, to: Date())!
            let sets = [ExerciseSet(reps: 8, weight: 135)]
            let exercise = Exercise(name: "Bench Press", muscleGroup: .chest, sets: sets)
            let workout = Workout(date: date, type: .push, exercises: [exercise])
            context.insert(workout)
        }
        try context.save()

        measure {
            let descriptor = FetchDescriptor<Workout>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            let _ = try? context.fetch(descriptor)
        }
    }

    // MARK: - Streak Calculation on 365 Days

    @MainActor
    func testPerformance_streakCalculation365Days() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Create 365 consecutive daily workouts
        var workouts: [Workout] = []
        for dayOffset in 0..<365 {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
            workouts.append(Workout(date: date, type: .push))
        }

        let aiService = AIService()

        measure {
            let _ = aiService.calculateStreak(workouts: workouts)
        }
    }

    // MARK: - PR Detection on 100 Workouts

    @MainActor
    func testPerformance_prDetection100Workouts() throws {
        let profile = TestFixtures.makeUserProfile()
        context.insert(profile)

        // Seed 100 previous workouts with gradually increasing weights
        var allWorkouts: [Workout] = []
        for i in 0..<100 {
            let date = Calendar.current.date(byAdding: .day, value: -(100 - i), to: Date())!
            let weight = 135.0 + Double(i)
            let sets = [
                ExerciseSet(reps: 8, weight: weight, order: 0),
                ExerciseSet(reps: 8, weight: weight, order: 1),
                ExerciseSet(reps: 8, weight: weight, order: 2)
            ]
            let exercise = Exercise(name: "Bench Press", muscleGroup: .chest, sets: sets)
            let workout = Workout(date: date, type: .push, exercises: [exercise])
            context.insert(workout)
            allWorkouts.append(workout)
        }
        try context.save()

        let prService = PRService.shared
        let latestWorkout = allWorkouts.last!

        measure {
            let _ = prService.detectAllPRs(
                workout: latestWorkout,
                allWorkouts: allWorkouts,
                profile: profile,
                modelContext: context
            )
        }
    }
}
