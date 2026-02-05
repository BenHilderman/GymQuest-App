//
//  FormRepository.swift
//  GymQuest
//
//  Repository for fetching form exercises, clips, and mastery data.
//

import Foundation
import SwiftData

struct FormRepository {
    let modelContext: ModelContext

    // MARK: - Exercises

    func allExercises() -> [FormExercise] {
        let descriptor = FetchDescriptor<FormExercise>(sortBy: [SortDescriptor(\.name)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func exercises(for pattern: FormMovementPattern) -> [FormExercise] {
        let patternRaw = pattern.rawValue
        let descriptor = FetchDescriptor<FormExercise>(
            predicate: #Predicate { $0.patternRaw == patternRaw },
            sortBy: [SortDescriptor(\.difficulty), SortDescriptor(\.name)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func exercise(byId id: UUID) -> FormExercise? {
        let descriptor = FetchDescriptor<FormExercise>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }

    // MARK: - Media Sets & Clips

    func latestMediaSet(for exercise: FormExercise) -> FormMediaSet? {
        exercise.mediaSets.sorted(by: { $0.version > $1.version }).first
    }

    func clip(
        exercise: FormExercise,
        type: ClipType,
        angle: ClipAngle? = nil
    ) -> FormClip? {
        guard let set = latestMediaSet(for: exercise) else { return nil }

        let desiredAngle = angle ?? set.defaultAngle
        let clips = set.clips.filter { $0.type == type }

        if let exact = clips.first(where: { $0.angle == desiredAngle }) { return exact }
        return clips.first
    }

    func availableAngles(exercise: FormExercise, type: ClipType) -> [ClipAngle] {
        guard let set = latestMediaSet(for: exercise) else { return [] }
        return set.clips
            .filter { $0.type == type }
            .map { $0.angle }
            .uniqued()
    }

    func availableClipTypes(for exercise: FormExercise) -> [ClipType] {
        guard let set = latestMediaSet(for: exercise) else { return [] }
        return set.clips.map { $0.type }.uniqued()
    }

    // MARK: - Mastery

    func mastery(oduserId: String, exerciseId: UUID) -> ExerciseMastery {
        let descriptor = FetchDescriptor<ExerciseMastery>(
            predicate: #Predicate { $0.oduserId == oduserId && $0.exerciseId == exerciseId }
        )
        if let found = try? modelContext.fetch(descriptor).first { return found }

        let created = ExerciseMastery(oduserId: oduserId, exerciseId: exerciseId)
        modelContext.insert(created)
        return created
    }

    func patternMastery(oduserId: String, pattern: FormMovementPattern) -> PatternMastery {
        let patternRaw = pattern.rawValue
        let descriptor = FetchDescriptor<PatternMastery>(
            predicate: #Predicate { $0.oduserId == oduserId && $0.patternRaw == patternRaw }
        )
        if let found = try? modelContext.fetch(descriptor).first { return found }

        let created = PatternMastery(oduserId: oduserId, pattern: pattern)
        modelContext.insert(created)
        return created
    }

    func addConfidenceRating(_ value: Double, to mastery: ExerciseMastery) {
        let rating = ConfidenceRating(value: value, mastery: mastery)
        mastery.ratings.append(rating)
        mastery.updatedAt = .now

        if mastery.ratings.count >= 2 && mastery.hasTwoHighConfidenceRatings {
            if mastery.state == .practicing {
                mastery.state = .consistent
            }
        }
    }

    func updateClipLocalURL(clipId: UUID, localURL: String) {
        let descriptor = FetchDescriptor<FormClip>(
            predicate: #Predicate { $0.id == clipId }
        )
        if let clip = try? modelContext.fetch(descriptor).first {
            clip.localHLSURLString = localURL
        }
    }
}

// MARK: - Array Extension

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
