import Foundation
import SwiftData
@testable import GymQuest

/// Factory methods for creating test data.
/// All methods return detached objects — call modelContext.insert() if SwiftData persistence is needed.
enum TestFixtures {

    // MARK: - UserProfile

    @MainActor
    static func makeUserProfile(
        name: String = "Test User",
        username: String = "testuser",
        goal: FitnessGoal = .hypertrophy,
        daysPerWeek: Int = 4,
        injuries: String = "",
        xp: Int = 0,
        level: Int = 1,
        aiProvider: AIProvider = .demo,
        isAuthenticated: Bool = true,
        email: String? = "test@example.com",
        passwordHash: String? = nil
    ) -> UserProfile {
        UserProfile(
            name: name,
            username: username,
            goal: goal,
            daysPerWeek: daysPerWeek,
            injuries: injuries,
            xp: xp,
            level: level,
            aiProvider: aiProvider,
            isAuthenticated: isAuthenticated,
            email: email,
            passwordHash: passwordHash
        )
    }

    // MARK: - ExerciseSet

    static func makeExerciseSet(
        reps: Int = 8,
        weight: Double = 135,
        rpe: Int? = 7,
        order: Int = 0,
        durationSec: Int? = nil,
        distance: Double? = nil
    ) -> ExerciseSet {
        ExerciseSet(
            reps: reps,
            weight: weight,
            rpe: rpe,
            order: order,
            durationSec: durationSec,
            distance: distance
        )
    }

    // MARK: - Exercise

    static func makeExercise(
        name: String = "Bench Press",
        muscleGroup: MuscleGroup = .chest,
        order: Int = 0,
        sets: [ExerciseSet] = [],
        category: ExerciseCategory = .push,
        equipment: Equipment = .barbell
    ) -> Exercise {
        Exercise(
            name: name,
            muscleGroup: muscleGroup,
            order: order,
            sets: sets,
            category: category,
            equipment: equipment
        )
    }

    // MARK: - Workout

    static func makeWorkout(
        date: Date = Date(),
        type: WorkoutType = .push,
        duration: Int = 60,
        rpe: Int = 7,
        notes: String = "",
        exercises: [Exercise] = [],
        prEvents: [PREvent] = []
    ) -> Workout {
        Workout(
            date: date,
            type: type,
            duration: duration,
            rpe: rpe,
            notes: notes,
            exercises: exercises,
            prEvents: prEvents
        )
    }

    // MARK: - Convenience: Full Workout

    /// Creates a complete workout with exercises and sets, inserts into context
    @MainActor
    static func insertFullWorkout(
        into context: ModelContext,
        date: Date = Date(),
        type: WorkoutType = .push,
        rpe: Int = 7,
        exerciseConfigs: [(name: String, muscle: MuscleGroup, sets: [(reps: Int, weight: Double)])] = [
            ("Bench Press", .chest, [(8, 135), (8, 135), (8, 135)]),
            ("Overhead Press", .shoulders, [(10, 85), (10, 85), (10, 85)])
        ]
    ) -> Workout {
        let exercises = exerciseConfigs.enumerated().map { index, config in
            let sets = config.sets.enumerated().map { setIndex, setConfig in
                ExerciseSet(reps: setConfig.reps, weight: setConfig.weight, order: setIndex)
            }
            return Exercise(
                name: config.name,
                muscleGroup: config.muscle,
                order: index,
                sets: sets
            )
        }

        let workout = Workout(
            date: date,
            type: type,
            duration: 60,
            rpe: rpe,
            exercises: exercises
        )

        context.insert(workout)
        try? context.save()
        return workout
    }

    // MARK: - JSON Fixture Loading

    /// Loads a JSON fixture file from the GymQuestTests/Fixtures directory
    static func loadFixture(_ name: String) -> Data {
        let bundle = Bundle(for: _FixtureBundleAnchor.self)
        guard let url = bundle.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            fatalError("Missing fixture: \(name).json — ensure it's in GymQuestTests/Fixtures and included in the test target")
        }
        return data
    }
}

/// Anchor class for locating the test bundle (enums can't be used with Bundle(for:))
private final class _FixtureBundleAnchor {}
