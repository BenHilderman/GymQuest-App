import Foundation
import SwiftData

@MainActor
final class WorkoutAdaptationService: ObservableObject {

    static let shared = WorkoutAdaptationService()

    private var modelContext: ModelContext?

    private init() {}

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Estimated minutes per exercise

    /// Rough estimate: ~3 min per set (includes rest).
    private func estimatedMinutes(for exercises: [ActiveExercise]) -> Int {
        let totalSets = exercises.reduce(0) { total, ex in total + ex.sets.count }
        return totalSets * 3
    }

    // MARK: - Shorten Workout

    /// Removes exercises from the end and trims sets on remaining exercises
    /// until the workout fits within `targetMinutes`.
    func shortenWorkout(
        exercises: [ActiveExercise],
        targetMinutes: Int,
        originalMinutes: Int
    ) -> [ActiveExercise] {
        guard !exercises.isEmpty, targetMinutes > 0, targetMinutes < originalMinutes else {
            return exercises
        }

        var sorted = exercises
        var current = estimatedMinutes(for: sorted)

        // Phase 1: Remove exercises from the end until we fit or only one remains.
        while current > targetMinutes, sorted.count > 1 {
            sorted.removeLast()
            current = estimatedMinutes(for: sorted)
        }

        // Phase 2: If still over budget, reduce sets on remaining exercises (keep at least 1).
        if current > targetMinutes {
            sorted = sorted.map { exercise in
                var ex = exercise
                while estimatedMinutes(for: [ex]) > targetMinutes / max(sorted.count, 1),
                      ex.sets.count > 1 {
                    ex.sets.removeLast()
                }
                return ex
            }
        }

        return sorted
    }

    // MARK: - Equipment Swap

    /// Finds an equivalent exercise from `ExtendedExerciseDatabase` targeting the same
    /// muscle group with one of the `availableEquipment` options.
    func swapEquipment(
        exerciseName: String,
        currentEquipment: String,
        availableEquipment: [String]
    ) -> (name: String, equipment: String)? {
        guard let original = ExtendedExerciseDatabase.find(exerciseName) else {
            return nil
        }

        let targetMuscle = original.muscleGroup

        // Preferred swap order based on current equipment.
        let swapChain: [String]
        switch currentEquipment.lowercased() {
        case "barbell":
            swapChain = ["dumbbell", "bodyweight"]
        case "dumbbell":
            swapChain = ["bodyweight"]
        default:
            swapChain = ["dumbbell", "bodyweight"]
        }

        // Walk the swap chain in order of preference, only considering available equipment.
        for preferred in swapChain {
            guard availableEquipment.map({ $0.lowercased() }).contains(preferred) else { continue }

            if let match = ExtendedExerciseDatabase.exercises.first(where: {
                $0.name != exerciseName
                && $0.muscleGroup == targetMuscle
                && $0.equipment.rawValue.lowercased() == preferred
            }) {
                return (name: match.name, equipment: match.equipment.rawValue)
            }
        }

        // Fallback: any available equipment matching the muscle group.
        for equip in availableEquipment {
            if let match = ExtendedExerciseDatabase.exercises.first(where: {
                $0.name != exerciseName
                && $0.muscleGroup == targetMuscle
                && $0.equipment.rawValue.lowercased() == equip.lowercased()
            }) {
                return (name: match.name, equipment: match.equipment.rawValue)
            }
        }

        return nil
    }

    // MARK: - Comeback Workout

    /// Generates a reduced-volume full-body workout for users in `.comeback` state.
    /// 50% volume, RPE 6 cap, targets 20-30 min. Prefers exercises the user has done recently.
    func generateComebackWorkout(
        userId: UUID,
        recentExerciseNames: [String]
    ) -> [ActiveExercise] {
        let targetGroups: [MuscleGroup] = [.chest, .back, .quads, .shoulders, .core]
        var selected: [ActiveExercise] = []
        var usedNames: Set<String> = []

        for group in targetGroups {
            // Prefer a familiar exercise the user has done recently.
            let match = recentExerciseNames.lazy.compactMap { name -> ExerciseMetadata? in
                guard !usedNames.contains(name) else { return nil }
                guard let meta = ExtendedExerciseDatabase.find(name),
                      meta.muscleGroup == group else { return nil }
                return meta
            }.first

            // Fallback to any exercise from the database for this group.
            let chosen = match ?? ExtendedExerciseDatabase.exercises.first {
                $0.muscleGroup == group && !usedNames.contains($0.name)
            }

            guard let exercise = chosen else { continue }
            usedNames.insert(exercise.name)

            // 50% volume: 2 sets instead of typical 3-4. RPE capped at 6.
            let sets = (0..<2).map { _ in
                ActiveSet(reps: 8, weight: 0, rpe: 6)
            }

            let activeEx = ActiveExercise(name: exercise.name, muscleGroup: exercise.muscleGroup, sets: sets)
            selected.append(activeEx)
        }

        return selected
    }

    // MARK: - Fatigue Adjustment

    /// If the user's actual RPE is 9+ and planned RPE was 7 or below, suggest a 10% weight reduction.
    func suggestFatigueAdjustment(
        currentRPE: Int,
        plannedRPE: Int,
        currentWeight: Double
    ) -> Double? {
        guard currentRPE >= 9, plannedRPE <= 7, currentWeight > 0 else {
            return nil
        }
        let reduced = (currentWeight * 0.9).rounded()
        return reduced
    }

    // MARK: - Log Adaptation

    /// Persists a `WorkoutAdaptation` record via SwiftData.
    func logAdaptation(
        userId: UUID,
        reason: AdaptationReason,
        original: String?,
        adapted: String?,
        details: String
    ) {
        guard let context = modelContext else { return }

        let record = WorkoutAdaptation(
            id: UUID(),
            userId: userId,
            workoutDate: Date(),
            reason: reason,
            originalExercise: original,
            adaptedExercise: adapted,
            details: details,
            createdAt: Date()
        )

        context.insert(record)
        try? context.save()
    }
}
