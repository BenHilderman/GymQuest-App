//
//  FormContentSeeder.swift
//  GymQuest
//
//  Seeds form content from JSON for exercises, clips, cues, and faults.
//

import Foundation
import SwiftData

// MARK: - DTO Structures

struct FormContentDTO: Codable {
    let exercises: [ExerciseDTO]

    struct ExerciseDTO: Codable {
        let id: String
        let name: String
        let pattern: String
        let equipment: String
        let difficulty: Int
        let cues: [String]
        let faults: [FaultDTO]
        let mediaSet: MediaSetDTO
        let variations: [VariationDTO]?
    }

    struct FaultDTO: Codable {
        let mistake: String
        let fix: String
    }

    struct MediaSetDTO: Codable {
        let version: Int
        let defaultAngle: String
        let clips: [ClipDTO]
    }

    struct ClipDTO: Codable {
        let type: String
        let angle: String
        let hlsURL: String
        let overlayURL: String?
        let duration: Double
        let chapters: [ChapterDTO]?
    }

    struct ChapterDTO: Codable {
        let title: String
        let time: Double
        let order: Int
    }

    struct VariationDTO: Codable {
        let kind: String
        let targetId: String
    }
}

// MARK: - Seeder

enum FormContentSeeder {

    static func seedIfNeeded(modelContext: ModelContext) {
        let existing = (try? modelContext.fetch(FetchDescriptor<FormExercise>())) ?? []
        guard existing.isEmpty else { return }

        // Try to load from bundle
        if let url = Bundle.main.url(forResource: "form_content_sample", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                try seed(from: data, modelContext: modelContext)
                return
            } catch {
                print("Failed to seed from bundle: \(error)")
            }
        }

        // Fall back to sample data
        seedSampleData(modelContext: modelContext)
    }

    static func seed(from data: Data, modelContext: ModelContext) throws {
        let dto = try JSONDecoder().decode(FormContentDTO.self, from: data)

        for ex in dto.exercises {
            let exId = UUID(uuidString: ex.id) ?? UUID()

            let pattern = FormMovementPattern(rawValue: ex.pattern) ?? .brace

            let exercise = FormExercise(
                id: exId,
                name: ex.name,
                pattern: pattern,
                equipment: ex.equipment,
                difficulty: ex.difficulty
            )

            // Cues (max 5)
            for (i, cueText) in ex.cues.prefix(5).enumerated() {
                let cue = FormCue(text: cueText, priority: i + 1, exercise: exercise)
                exercise.cues.append(cue)
            }

            // Faults (max 3)
            for (i, f) in ex.faults.prefix(3).enumerated() {
                let fault = FormFault(mistake: f.mistake, fixCue: f.fix, priority: i + 1, exercise: exercise)
                exercise.faults.append(fault)
            }

            // Media set + clips
            let defaultAngle = ClipAngle(rawValue: ex.mediaSet.defaultAngle) ?? .a45
            let set = FormMediaSet(version: ex.mediaSet.version, defaultAngle: defaultAngle, exercise: exercise)

            for c in ex.mediaSet.clips {
                let clipType = ClipType(rawValue: c.type) ?? .loop
                let clipAngle = ClipAngle(rawValue: c.angle) ?? .a45

                let clip = FormClip(
                    type: clipType,
                    angle: clipAngle,
                    hlsURLString: c.hlsURL,
                    overlayTimelineURLString: c.overlayURL,
                    durationSeconds: c.duration,
                    mediaSet: set
                )

                // Chapters
                if let chapters = c.chapters {
                    for ch in chapters {
                        let chapter = FormChapter(title: ch.title, timeSeconds: ch.time, order: ch.order, clip: clip)
                        clip.chapters.append(chapter)
                    }
                }

                set.clips.append(clip)
            }

            exercise.mediaSets.append(set)

            // Variations
            if let variations = ex.variations {
                for v in variations {
                    let targetId = UUID(uuidString: v.targetId) ?? UUID()
                    let edge = VariationEdge(kind: v.kind, targetExerciseId: targetId, exercise: exercise)
                    exercise.variations.append(edge)
                }
            }

            modelContext.insert(exercise)
        }
    }

    // MARK: - Sample Data

    static func seedSampleData(modelContext: ModelContext) {
        // Bench Press
        let benchPress = FormExercise(
            name: "Barbell Bench Press",
            pattern: .horizontalPush,
            equipment: "barbell",
            difficulty: 2
        )

        benchPress.cues.append(FormCue(text: "Retract and depress shoulder blades", priority: 1, exercise: benchPress))
        benchPress.cues.append(FormCue(text: "Plant feet firmly on floor", priority: 2, exercise: benchPress))
        benchPress.cues.append(FormCue(text: "Lower bar to mid-chest", priority: 3, exercise: benchPress))
        benchPress.cues.append(FormCue(text: "Drive through full range", priority: 4, exercise: benchPress))
        benchPress.cues.append(FormCue(text: "Lock out at the top", priority: 5, exercise: benchPress))

        benchPress.faults.append(FormFault(mistake: "Flared elbows at 90°", fixCue: "Tuck elbows to 45-75° angle", priority: 1, exercise: benchPress))
        benchPress.faults.append(FormFault(mistake: "Bouncing bar off chest", fixCue: "Pause briefly at chest", priority: 2, exercise: benchPress))
        benchPress.faults.append(FormFault(mistake: "Hips coming off bench", fixCue: "Maintain arch, keep glutes down", priority: 3, exercise: benchPress))

        let benchMediaSet = FormMediaSet(version: 1, defaultAngle: .a45, exercise: benchPress)

        // Using Apple's sample HLS streams for demo
        // In production, replace with your own exercise video URLs
        let loopClip = FormClip(
            type: .loop,
            angle: .a45,
            hlsURLString: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8",
            durationSeconds: 12.0,
            mediaSet: benchMediaSet
        )
        benchMediaSet.clips.append(loopClip)

        let breakdownClip = FormClip(
            type: .breakdown,
            angle: .a45,
            hlsURLString: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8",
            durationSeconds: 75.0,
            mediaSet: benchMediaSet
        )

        breakdownClip.chapters.append(FormChapter(title: "Setup", timeSeconds: 0, order: 1, clip: breakdownClip))
        breakdownClip.chapters.append(FormChapter(title: "Unrack", timeSeconds: 15, order: 2, clip: breakdownClip))
        breakdownClip.chapters.append(FormChapter(title: "Descent", timeSeconds: 30, order: 3, clip: breakdownClip))
        breakdownClip.chapters.append(FormChapter(title: "Press", timeSeconds: 50, order: 4, clip: breakdownClip))
        breakdownClip.chapters.append(FormChapter(title: "Lockout", timeSeconds: 65, order: 5, clip: breakdownClip))

        benchMediaSet.clips.append(breakdownClip)

        let coachEyeClip = FormClip(
            type: .coachEye,
            angle: .side,
            hlsURLString: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8",
            durationSeconds: 90.0,
            mediaSet: benchMediaSet
        )
        benchMediaSet.clips.append(coachEyeClip)

        benchPress.mediaSets.append(benchMediaSet)
        modelContext.insert(benchPress)

        // Squat
        let squat = FormExercise(
            name: "Barbell Back Squat",
            pattern: .squat,
            equipment: "barbell",
            difficulty: 2
        )

        squat.cues.append(FormCue(text: "Brace core before descent", priority: 1, exercise: squat))
        squat.cues.append(FormCue(text: "Break at hips and knees together", priority: 2, exercise: squat))
        squat.cues.append(FormCue(text: "Keep knees tracking over toes", priority: 3, exercise: squat))
        squat.cues.append(FormCue(text: "Drive through full foot", priority: 4, exercise: squat))

        squat.faults.append(FormFault(mistake: "Knees caving inward", fixCue: "Push knees out over pinky toe", priority: 1, exercise: squat))
        squat.faults.append(FormFault(mistake: "Butt wink at bottom", fixCue: "Work on hip mobility, stop before wink", priority: 2, exercise: squat))

        let squatMediaSet = FormMediaSet(version: 1, defaultAngle: .a45, exercise: squat)

        let squatLoop = FormClip(
            type: .loop,
            angle: .a45,
            hlsURLString: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8",
            durationSeconds: 10.0,
            mediaSet: squatMediaSet
        )
        squatMediaSet.clips.append(squatLoop)

        squat.mediaSets.append(squatMediaSet)
        modelContext.insert(squat)

        // Deadlift
        let deadlift = FormExercise(
            name: "Conventional Deadlift",
            pattern: .hinge,
            equipment: "barbell",
            difficulty: 3
        )

        deadlift.cues.append(FormCue(text: "Bar over mid-foot", priority: 1, exercise: deadlift))
        deadlift.cues.append(FormCue(text: "Grip just outside knees", priority: 2, exercise: deadlift))
        deadlift.cues.append(FormCue(text: "Chest up, lats engaged", priority: 3, exercise: deadlift))
        deadlift.cues.append(FormCue(text: "Push floor away", priority: 4, exercise: deadlift))
        deadlift.cues.append(FormCue(text: "Lock out hips at top", priority: 5, exercise: deadlift))

        deadlift.faults.append(FormFault(mistake: "Rounded lower back", fixCue: "Brace harder, reduce weight if needed", priority: 1, exercise: deadlift))
        deadlift.faults.append(FormFault(mistake: "Bar drifting forward", fixCue: "Keep bar close, drag up thighs", priority: 2, exercise: deadlift))

        let deadliftMediaSet = FormMediaSet(version: 1, defaultAngle: .side, exercise: deadlift)

        let deadliftLoop = FormClip(
            type: .loop,
            angle: .side,
            hlsURLString: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8",
            durationSeconds: 12.0,
            mediaSet: deadliftMediaSet
        )
        deadliftMediaSet.clips.append(deadliftLoop)

        deadlift.mediaSets.append(deadliftMediaSet)
        modelContext.insert(deadlift)

        print("Seeded 3 sample exercises for Form Studio")
    }
}
