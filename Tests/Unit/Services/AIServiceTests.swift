import XCTest
@testable import GymQuest

final class AIServiceTests: XCTestCase {

    private var aiService: AIService!

    @MainActor
    override func setUp() {
        super.setUp()
        aiService = AIService()
    }

    override func tearDown() {
        aiService = nil
        super.tearDown()
    }

    // MARK: - calculateStreak

    @MainActor
    func testCalculateStreak_emptyWorkouts() {
        let streak = aiService.calculateStreak(workouts: [])
        XCTAssertEqual(streak, 0)
    }

    @MainActor
    func testCalculateStreak_consecutiveDays() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let workouts = (0..<5).map { dayOffset -> Workout in
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
            return TestFixtures.makeWorkout(date: date)
        }

        let streak = aiService.calculateStreak(workouts: workouts)
        XCTAssertEqual(streak, 5)
    }

    @MainActor
    func testCalculateStreak_gapBreaksStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Workouts today and yesterday, then a gap, then 3 days ago
        var workouts: [Workout] = []
        workouts.append(TestFixtures.makeWorkout(date: today))
        workouts.append(TestFixtures.makeWorkout(date: calendar.date(byAdding: .day, value: -1, to: today)!))
        // Skip day -2
        workouts.append(TestFixtures.makeWorkout(date: calendar.date(byAdding: .day, value: -3, to: today)!))

        let streak = aiService.calculateStreak(workouts: workouts)
        XCTAssertEqual(streak, 2)
    }

    @MainActor
    func testCalculateStreak_noWorkoutToday_startsFromYesterday() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Workouts yesterday and day before — streak should still count
        // because the algorithm checks today first (no workout) then yesterday
        let workouts = [
            TestFixtures.makeWorkout(date: calendar.date(byAdding: .day, value: -1, to: today)!),
            TestFixtures.makeWorkout(date: calendar.date(byAdding: .day, value: -2, to: today)!)
        ]

        let streak = aiService.calculateStreak(workouts: workouts)
        // Today has no workout, so streak starts from yesterday → 2
        // But the algorithm skips today (streak=0, no session, streak==0 so continues)
        // then finds day -1 (streak=1), day -2 (streak=2), day -3 no workout → break
        XCTAssertEqual(streak, 2)
    }

    // MARK: - calculateWeeklyVolume

    @MainActor
    func testCalculateWeeklyVolume_groupsByMuscle() {
        let chestSets = [
            TestFixtures.makeExerciseSet(reps: 8, weight: 135),
            TestFixtures.makeExerciseSet(reps: 8, weight: 135),
            TestFixtures.makeExerciseSet(reps: 8, weight: 135)
        ]
        let backSets = [
            TestFixtures.makeExerciseSet(reps: 10, weight: 135),
            TestFixtures.makeExerciseSet(reps: 10, weight: 135)
        ]

        let chestExercise = TestFixtures.makeExercise(name: "Bench Press", muscleGroup: .chest, sets: chestSets)
        let backExercise = TestFixtures.makeExercise(name: "Barbell Row", muscleGroup: .back, sets: backSets)

        let workout = TestFixtures.makeWorkout(exercises: [chestExercise, backExercise])

        let volume = aiService.calculateWeeklyVolume(workouts: [workout])
        XCTAssertEqual(volume["Chest"], 3) // 3 sets
        XCTAssertEqual(volume["Back"], 2) // 2 sets
    }

    @MainActor
    func testCalculateWeeklyVolume_emptyWorkouts() {
        let volume = aiService.calculateWeeklyVolume(workouts: [])
        XCTAssertTrue(volume.isEmpty)
    }

    // MARK: - shouldDeload

    @MainActor
    func testShouldDeload_trueWhen3PlusHighVolumeWeeks() {
        let calendar = Calendar.current
        var workouts: [Workout] = []

        // Create 4 weeks of 4+ sessions at RPE 8
        for weekOffset in 0..<4 {
            let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: calendar.startOfWeek(for: Date()))!
            for dayOffset in 0..<4 {
                let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart)!
                workouts.append(TestFixtures.makeWorkout(date: date, rpe: 8))
            }
        }

        XCTAssertTrue(aiService.shouldDeload(workouts: workouts))
    }

    @MainActor
    func testShouldDeload_falseWhenLowVolume() {
        let calendar = Calendar.current
        var workouts: [Workout] = []

        // Only 2 sessions per week → not enough volume
        for weekOffset in 0..<4 {
            let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: calendar.startOfWeek(for: Date()))!
            for dayOffset in 0..<2 {
                let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart)!
                workouts.append(TestFixtures.makeWorkout(date: date, rpe: 8))
            }
        }

        XCTAssertFalse(aiService.shouldDeload(workouts: workouts))
    }

    @MainActor
    func testShouldDeload_falseWhenLowRPE() {
        let calendar = Calendar.current
        var workouts: [Workout] = []

        // 4+ sessions per week but RPE only 5 → not intense enough
        for weekOffset in 0..<4 {
            let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: calendar.startOfWeek(for: Date()))!
            for dayOffset in 0..<5 {
                let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart)!
                workouts.append(TestFixtures.makeWorkout(date: date, rpe: 5))
            }
        }

        XCTAssertFalse(aiService.shouldDeload(workouts: workouts))
    }

    // MARK: - buildContext

    @MainActor
    func testBuildContext_limitsTo10Workouts() {
        let profile = TestFixtures.makeUserProfile()
        let workouts = (0..<15).map { _ in TestFixtures.makeWorkout() }

        let context = aiService.buildContext(profile: profile, workouts: workouts)
        XCTAssertEqual(context.recentSessions.count, 10)
    }

    @MainActor
    func testBuildContext_populatesUserContext() {
        let profile = TestFixtures.makeUserProfile(
            name: "Ben",
            goal: .strength,
            daysPerWeek: 5,
            injuries: "Lower back"
        )
        let context = aiService.buildContext(profile: profile, workouts: [])

        XCTAssertEqual(context.user.name, "Ben")
        XCTAssertEqual(context.user.goal, "Strength")
        XCTAssertEqual(context.user.daysPerWeek, 5)
        XCTAssertEqual(context.user.injuries, "Lower back")
    }

    // MARK: - getDemoResponse

    @MainActor
    func testGetDemoResponse_returnsNonEmptyString() {
        let profile = TestFixtures.makeUserProfile()
        let context = aiService.buildContext(profile: profile, workouts: [])

        let response = aiService.getDemoResponse(prompt: "How should I train today?", context: context)
        XCTAssertFalse(response.isEmpty)
    }
}
