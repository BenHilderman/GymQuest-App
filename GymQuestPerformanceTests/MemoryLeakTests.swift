import XCTest
import SwiftData
@testable import GymQuest

final class MemoryLeakTests: XCTestCase {

    // MARK: - ActiveWorkoutViewModel Deallocation

    @MainActor
    func testActiveWorkoutViewModel_deallocatesAfterCleanup() throws {
        let container = try TestModelContainer.create()
        let context = container.mainContext

        let profile = TestFixtures.makeUserProfile()
        context.insert(profile)

        // Create VM and hold a weak reference
        var vm: ActiveWorkoutViewModel? = ActiveWorkoutViewModel(
            profile: profile,
            workoutType: .push,
            modelContext: context
        )

        weak var weakVM = vm

        // Start timers to create potential retain cycles
        vm?.startWorkoutTimer()

        // Add some exercises with sets
        vm?.exercises = [
            ActiveExercise(
                name: "Bench Press",
                muscleGroup: .chest,
                sets: [
                    ActiveSet(reps: 8, weight: 135, isCompleted: true),
                    ActiveSet(reps: 8, weight: 135, isCompleted: false)
                ]
            )
        ]

        // Cleanup should cancel all timers
        vm?.cleanup()
        vm = nil

        // The weak reference should be nil after cleanup + deallocation
        // Note: This may not immediately deallocate due to autorelease pools,
        // but verifying cleanup() was called without crashes is valuable
        XCTAssertNil(weakVM, "ActiveWorkoutViewModel should deallocate after cleanup()")
    }

    // MARK: - AIService Deallocation

    @MainActor
    func testAIService_deallocatesCleanly() {
        var aiService: AIService? = AIService()
        weak var weakService = aiService

        aiService = nil

        XCTAssertNil(weakService, "AIService should deallocate cleanly")
    }

    // MARK: - AuthService Deallocation

    @MainActor
    func testAuthService_deallocatesCleanly() throws {
        let container = try TestModelContainer.create()

        var authService: AuthService? = AuthService()
        authService?.setModelContext(container.mainContext)
        weak var weakService = authService

        authService = nil

        XCTAssertNil(weakService, "AuthService should deallocate cleanly")
    }
}
