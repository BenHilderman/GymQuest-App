//
//  FormModels.swift
//  GymQuest
//
//  SwiftData models for Form Studio exercises, media sets, clips, and chapters.
//

import Foundation
import SwiftData

@Model
final class FormExercise {
    @Attribute(.unique) var id: UUID
    var name: String
    var patternRaw: String
    var equipment: String
    var difficulty: Int
    var createdAt: Date

    @Relationship(deleteRule: .cascade) var mediaSets: [FormMediaSet] = []
    @Relationship(deleteRule: .cascade) var cues: [FormCue] = []
    @Relationship(deleteRule: .cascade) var faults: [FormFault] = []
    @Relationship(deleteRule: .cascade) var variations: [VariationEdge] = []

    init(
        id: UUID = UUID(),
        name: String,
        pattern: FormMovementPattern,
        equipment: String,
        difficulty: Int
    ) {
        self.id = id
        self.name = name
        self.patternRaw = pattern.rawValue
        self.equipment = equipment
        self.difficulty = difficulty
        self.createdAt = .now
    }

    var pattern: FormMovementPattern { FormMovementPattern(rawValue: patternRaw) ?? .brace }
}

@Model
final class FormMediaSet {
    @Attribute(.unique) var id: UUID
    var version: Int
    var publishedAt: Date
    var defaultAngleRaw: String

    var exercise: FormExercise?
    @Relationship(deleteRule: .cascade) var clips: [FormClip] = []

    init(
        id: UUID = UUID(),
        version: Int,
        publishedAt: Date = .now,
        defaultAngle: ClipAngle = .a45,
        exercise: FormExercise?
    ) {
        self.id = id
        self.version = version
        self.publishedAt = publishedAt
        self.defaultAngleRaw = defaultAngle.rawValue
        self.exercise = exercise
    }

    var defaultAngle: ClipAngle { ClipAngle(rawValue: defaultAngleRaw) ?? .a45 }
}

@Model
final class FormClip {
    @Attribute(.unique) var id: UUID
    var typeRaw: String
    var angleRaw: String

    var hlsURLString: String
    var captionsURLString: String?
    var overlayTimelineURLString: String?
    var durationSeconds: Double

    var localHLSURLString: String?

    var mediaSet: FormMediaSet?
    @Relationship(deleteRule: .cascade) var chapters: [FormChapter] = []

    init(
        id: UUID = UUID(),
        type: ClipType,
        angle: ClipAngle,
        hlsURLString: String,
        captionsURLString: String? = nil,
        overlayTimelineURLString: String? = nil,
        durationSeconds: Double,
        mediaSet: FormMediaSet?
    ) {
        self.id = id
        self.typeRaw = type.rawValue
        self.angleRaw = angle.rawValue
        self.hlsURLString = hlsURLString
        self.captionsURLString = captionsURLString
        self.overlayTimelineURLString = overlayTimelineURLString
        self.durationSeconds = durationSeconds
        self.mediaSet = mediaSet
    }

    var type: ClipType { ClipType(rawValue: typeRaw) ?? .loop }
    var angle: ClipAngle { ClipAngle(rawValue: angleRaw) ?? .a45 }

    var bestPlaybackURL: URL? {
        if let local = localHLSURLString, let u = URL(string: local) { return u }
        return URL(string: hlsURLString)
    }

    var isDownloaded: Bool {
        localHLSURLString != nil
    }
}

@Model
final class FormChapter {
    @Attribute(.unique) var id: UUID
    var title: String
    var timeSeconds: Double
    var order: Int
    var clip: FormClip?

    init(id: UUID = UUID(), title: String, timeSeconds: Double, order: Int, clip: FormClip?) {
        self.id = id
        self.title = title
        self.timeSeconds = timeSeconds
        self.order = order
        self.clip = clip
    }
}

@Model
final class FormCue {
    @Attribute(.unique) var id: UUID
    var text: String
    var priority: Int
    var exercise: FormExercise?

    init(id: UUID = UUID(), text: String, priority: Int, exercise: FormExercise?) {
        self.id = id
        self.text = text
        self.priority = priority
        self.exercise = exercise
    }
}

@Model
final class FormFault {
    @Attribute(.unique) var id: UUID
    var mistake: String
    var fixCue: String
    var priority: Int
    var exercise: FormExercise?

    init(id: UUID = UUID(), mistake: String, fixCue: String, priority: Int, exercise: FormExercise?) {
        self.id = id
        self.mistake = mistake
        self.fixCue = fixCue
        self.priority = priority
        self.exercise = exercise
    }
}

@Model
final class VariationEdge {
    @Attribute(.unique) var id: UUID
    var kind: String
    var targetExerciseId: UUID
    var exercise: FormExercise?

    init(id: UUID = UUID(), kind: String, targetExerciseId: UUID, exercise: FormExercise?) {
        self.id = id
        self.kind = kind
        self.targetExerciseId = targetExerciseId
        self.exercise = exercise
    }
}
