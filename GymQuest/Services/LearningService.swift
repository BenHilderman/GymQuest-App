//
//  LearningService.swift
//  GymQuest
//
//  Learning system service for GymQuest 2.0.
//  Provides form cues, common mistakes, and demo video links for exercises.
//

import Foundation
import SwiftData

@MainActor
class LearningService: ObservableObject {
    static let shared = LearningService()

    private var modelContext: ModelContext?

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Learning Content

    /// Get learning content for an exercise
    func getLearningContent(for exerciseName: String) -> ExerciseLearningContent {
        let normalizedName = exerciseName.lowercased()

        // Check extended database first using find method
        if let exercise = ExtendedExerciseDatabase.find(normalizedName) {
            return ExerciseLearningContent(
                exerciseName: exercise.name,
                formCues: exercise.cues,
                commonMistakes: getCommonMistakes(for: normalizedName),
                demoVideoURL: getDemoVideoURL(for: normalizedName),
                muscleGroups: exercise.primaryMuscles,
                equipment: exercise.equipment.rawValue,
                difficulty: exercise.difficulty.rawValue
            )
        }

        // Fallback for exercises not in database
        return ExerciseLearningContent(
            exerciseName: exerciseName,
            formCues: getGenericFormCues(for: normalizedName),
            commonMistakes: getGenericCommonMistakes(for: normalizedName),
            demoVideoURL: nil,
            muscleGroups: [],
            equipment: "Various",
            difficulty: "Intermediate"
        )
    }

    /// Get all learning items for an exercise
    func getLearningItems(for exerciseName: String) -> [LearningItem] {
        guard let context = modelContext else { return [] }

        // Fetch all learning items and filter in memory due to optional property
        let descriptor = FetchDescriptor<LearningItem>()

        guard let items = try? context.fetch(descriptor) else { return [] }

        let normalizedName = exerciseName.lowercased()
        return items.filter { item in
            guard let name = item.exerciseName else { return false }
            return name.lowercased().contains(normalizedName)
        }
    }

    /// Track that a learning item was viewed
    func trackLearningView(userId: UUID, learningItemId: UUID, exerciseName: String?) {
        guard let context = modelContext else { return }

        let progress = LearningProgress(
            odId: userId,
            learningItemId: learningItemId,
            viewed: true,
            viewedAt: Date()
        )

        context.insert(progress)
        try? context.save()

        // Track analytics
        AnalyticsService.shared.trackLearningItemViewed(
            userId: userId,
            itemId: learningItemId,
            exerciseName: exerciseName
        )
    }

    /// Get user's learning progress
    func getUserLearningProgress(userId: UUID) -> [LearningProgress] {
        guard let context = modelContext else { return [] }

        let descriptor = FetchDescriptor<LearningProgress>(
            predicate: #Predicate { $0.odId == userId }
        )

        guard let progress = try? context.fetch(descriptor) else { return [] }
        return progress.sorted { ($0.viewedAt ?? Date.distantPast) > ($1.viewedAt ?? Date.distantPast) }
    }

    // MARK: - Common Mistakes Database

    private func getCommonMistakes(for exercise: String) -> [String] {
        let mistakes: [String: [String]] = [
            "bench press": [
                "Flaring elbows out at 90 degrees - keep them at 45-75 degrees",
                "Bouncing the bar off your chest - pause briefly at the bottom",
                "Lifting hips off the bench - maintain arch and drive through legs",
                "Not retracting shoulder blades - squeeze them together and keep them down"
            ],
            "squat": [
                "Knees caving inward - push knees out over toes",
                "Rising on toes - keep weight on midfoot/heels",
                "Forward lean/chest dropping - stay upright, brace core",
                "Not hitting depth - aim for parallel or below"
            ],
            "deadlift": [
                "Rounding the lower back - maintain neutral spine",
                "Bar drifting away from body - keep bar path close to legs",
                "Jerking the bar off the floor - build tension then pull",
                "Looking up excessively - keep neck neutral"
            ],
            "overhead press": [
                "Leaning back excessively - keep core tight, slight lean is OK",
                "Pressing bar forward - press straight up, bar path should be vertical",
                "Not shrugging at top - fully extend and shrug shoulders at lockout",
                "Flaring elbows too much - keep elbows slightly in front of bar"
            ],
            "barbell row": [
                "Using momentum/body English - stay controlled, no swinging",
                "Rounding upper back - maintain neutral spine throughout",
                "Standing too upright - hinge forward to about 45 degrees",
                "Pulling to wrong spot - aim for lower chest/upper abs"
            ],
            "pull-up": [
                "Using momentum/kipping - strict form, control the movement",
                "Not getting full range - dead hang at bottom, chin over bar at top",
                "Shrugging shoulders - keep shoulders down and back",
                "Neglecting negative - control the descent, 2-3 seconds down"
            ],
            "romanian deadlift": [
                "Rounding lower back - maintain neutral spine, hinge at hips",
                "Bending knees too much - keep slight bend, this is a hip hinge",
                "Not feeling hamstring stretch - push hips back, feel the stretch",
                "Bar drifting forward - keep bar close to legs throughout"
            ],
            "lat pulldown": [
                "Pulling to chest with momentum - control the movement",
                "Leaning back too far - slight lean is OK, not excessive",
                "Using arms too much - focus on pulling with elbows",
                "Incomplete range - full stretch at top, squeeze at bottom"
            ],
            "dumbbell curl": [
                "Swinging the weight - keep upper arms stationary",
                "Elbows drifting forward - pin elbows to sides",
                "Going too fast - control both concentric and eccentric",
                "Not fully extending - get full range of motion"
            ],
            "tricep pushdown": [
                "Elbows flaring out - keep elbows pinned to sides",
                "Using body momentum - isolate the triceps",
                "Not locking out - fully extend at the bottom",
                "Leaning over the bar - stay upright"
            ]
        ]

        return mistakes[exercise] ?? [
            "Using momentum instead of controlled movement",
            "Not using full range of motion",
            "Improper breathing - exhale on exertion"
        ]
    }

    private func getGenericFormCues(for exercise: String) -> [String] {
        // Generic cues based on movement patterns
        if exercise.contains("press") || exercise.contains("push") {
            return [
                "Brace your core before each rep",
                "Control the negative portion (lowering)",
                "Exhale on the push, inhale on the lower"
            ]
        } else if exercise.contains("row") || exercise.contains("pull") {
            return [
                "Squeeze your shoulder blades together",
                "Pull with your elbows, not your hands",
                "Keep your core engaged throughout"
            ]
        } else if exercise.contains("squat") || exercise.contains("leg") {
            return [
                "Keep your chest up and core braced",
                "Drive through your whole foot",
                "Don't let your knees cave inward"
            ]
        } else {
            return [
                "Maintain proper posture throughout",
                "Control the movement in both directions",
                "Breathe properly - don't hold your breath"
            ]
        }
    }

    private func getGenericCommonMistakes(for exercise: String) -> [String] {
        return [
            "Using momentum instead of muscle control",
            "Shortening the range of motion",
            "Improper breathing pattern"
        ]
    }

    // MARK: - Demo Video URLs

    private func getDemoVideoURL(for exercise: String) -> String? {
        // In production, these would be links to actual demo videos
        // For now, returning placeholder URLs
        let videoURLs: [String: String] = [
            "bench press": "https://gymquest.app/demos/bench-press",
            "squat": "https://gymquest.app/demos/squat",
            "deadlift": "https://gymquest.app/demos/deadlift",
            "overhead press": "https://gymquest.app/demos/ohp",
            "barbell row": "https://gymquest.app/demos/barbell-row",
            "pull-up": "https://gymquest.app/demos/pull-up",
            "romanian deadlift": "https://gymquest.app/demos/rdl",
            "lat pulldown": "https://gymquest.app/demos/lat-pulldown",
            "dumbbell curl": "https://gymquest.app/demos/db-curl",
            "tricep pushdown": "https://gymquest.app/demos/tricep-pushdown"
        ]

        return videoURLs[exercise]
    }

    // MARK: - Seed Learning Content

    /// Seed default learning items if none exist
    func seedDefaultLearningContent() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<LearningItem>()
        let existingItems = (try? context.fetch(descriptor)) ?? []

        if existingItems.isEmpty {
            let defaultItems = createDefaultLearningItems()
            for item in defaultItems {
                context.insert(item)
            }
            try? context.save()
        }
    }

    private func createDefaultLearningItems() -> [LearningItem] {
        var items: [LearningItem] = []

        // Create learning items for each exercise in extended database
        for exercise in ExtendedExerciseDatabase.exercises {
            // Form cues item
            items.append(LearningItem(
                exerciseName: exercise.name,
                type: .cue,
                textCues: exercise.cues,
                tags: [exercise.muscleGroup.rawValue]
            ))

            // Common mistakes item
            let mistakes = getCommonMistakes(for: exercise.name.lowercased())
            if !mistakes.isEmpty {
                items.append(LearningItem(
                    exerciseName: exercise.name,
                    type: .mistake,
                    commonMistake: mistakes.first,
                    tags: [exercise.muscleGroup.rawValue]
                ))
            }

            // Demo item
            items.append(LearningItem(
                exerciseName: exercise.name,
                type: .demo,
                durationSec: 15,
                tags: [exercise.muscleGroup.rawValue, exercise.equipment.rawValue]
            ))
        }

        return items
    }
}

// MARK: - Exercise Learning Content

struct ExerciseLearningContent {
    let exerciseName: String
    let formCues: [String]
    let commonMistakes: [String]
    let demoVideoURL: String?
    let muscleGroups: [String]
    let equipment: String
    let difficulty: String
}

// MARK: - Analytics Extension

extension AnalyticsService {
    func trackLearningViewed(userId: UUID, exerciseName: String, itemType: String) {
        trackEvent(
            eventName: "learning_viewed",
            properties: [
                "user_id": userId.uuidString,
                "exercise_name": exerciseName,
                "item_type": itemType
            ]
        )
    }
}
