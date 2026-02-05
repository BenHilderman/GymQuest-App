//
//  MasteryModels.swift
//  GymQuest
//
//  SwiftData models for pattern and exercise mastery tracking with unlock logic.
//

import Foundation
import SwiftData

@Model
final class PatternMastery {
    @Attribute(.unique) var id: UUID
    var oduserId: String
    var patternRaw: String
    var levelRaw: String
    var primerCompleted: Bool
    var updatedAt: Date

    init(id: UUID = UUID(), oduserId: String, pattern: FormMovementPattern) {
        self.id = id
        self.oduserId = oduserId
        self.patternRaw = pattern.rawValue
        self.levelRaw = PatternLevel.learning.rawValue
        self.primerCompleted = false
        self.updatedAt = .now
    }

    var pattern: FormMovementPattern { FormMovementPattern(rawValue: patternRaw) ?? .brace }
    var level: PatternLevel {
        get { PatternLevel(rawValue: levelRaw) ?? .learning }
        set { levelRaw = newValue.rawValue; updatedAt = .now }
    }
}

@Model
final class ExerciseMastery {
    @Attribute(.unique) var id: UUID
    var oduserId: String
    var exerciseId: UUID

    var setupChecklistCompleted: Bool
    var watchedBreakdownCompleted: Bool
    var breakdownWatchProgress: Double
    var sessionsCount: Int

    @Relationship(deleteRule: .cascade) var ratings: [ConfidenceRating] = []

    var stateRaw: String
    var unlockedTier: Int
    var updatedAt: Date

    init(id: UUID = UUID(), oduserId: String, exerciseId: UUID) {
        self.id = id
        self.oduserId = oduserId
        self.exerciseId = exerciseId
        self.setupChecklistCompleted = false
        self.watchedBreakdownCompleted = false
        self.breakdownWatchProgress = 0.0
        self.sessionsCount = 0
        self.stateRaw = ExerciseFormState.new.rawValue
        self.unlockedTier = 0
        self.updatedAt = .now
    }

    var state: ExerciseFormState {
        get { ExerciseFormState(rawValue: stateRaw) ?? .new }
        set { stateRaw = newValue.rawValue; updatedAt = .now }
    }

    var hasTwoHighConfidenceRatings: Bool {
        let high = ratings.filter { $0.value >= 4.0 }
        return high.count >= 2
    }

    var canUnlockNextVariation: Bool {
        setupChecklistCompleted &&
        watchedBreakdownCompleted &&
        sessionsCount >= 2 &&
        hasTwoHighConfidenceRatings
    }

    var progressPercentage: Double {
        var total = 0.0
        if setupChecklistCompleted { total += 25 }
        if watchedBreakdownCompleted { total += 25 }
        total += min(Double(sessionsCount) / 2.0, 1.0) * 25
        if hasTwoHighConfidenceRatings { total += 25 }
        return total
    }

    func markBreakdownWatched() {
        watchedBreakdownCompleted = true
        breakdownWatchProgress = 1.0
        updatedAt = .now
    }

    func incrementSessions() {
        sessionsCount += 1
        updatedAt = .now

        if sessionsCount >= 3 && state == .new {
            state = .practicing
        }
        if sessionsCount >= 5 && hasTwoHighConfidenceRatings {
            state = .consistent
        }
    }
}

@Model
final class ConfidenceRating {
    @Attribute(.unique) var id: UUID
    var value: Double
    var createdAt: Date
    var mastery: ExerciseMastery?

    init(id: UUID = UUID(), value: Double, mastery: ExerciseMastery?) {
        self.id = id
        self.value = value
        self.createdAt = .now
        self.mastery = mastery
    }
}
