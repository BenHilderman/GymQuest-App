//
//  WorkoutVoiceCoachService.swift
//  GymQuest
//
//  Routes voice commands to appropriate handlers during workouts.
//  Provides spoken responses via AVSpeechSynthesizer for hands-free coaching.
//

#if canImport(UIKit)
import Foundation
import AVFoundation
import SwiftData

@MainActor
class WorkoutVoiceCoachService: ObservableObject {
    static let shared = WorkoutVoiceCoachService()

    @Published var lastResponse: String = ""
    @Published var isSpeaking: Bool = false

    private let synthesizer = AVSpeechSynthesizer()

    /// Handle a parsed voice command during an active workout
    func handleCommand(
        _ command: VoiceCommand,
        exercises: [ActiveExercise],
        currentExerciseName: String?,
        profile: UserProfile,
        allWorkouts: [Workout],
        modelContext: ModelContext
    ) async {
        let response: String

        switch command {
        case .askWeight(let exerciseName):
            response = handleWeightQuery(
                exerciseName: exerciseName ?? currentExerciseName,
                exercises: exercises,
                allWorkouts: allWorkouts,
                profile: profile
            )

        case .askVolume:
            response = handleVolumeQuery(exercises: exercises)

        case .setFeedback(let rpe):
            response = handleSetFeedback(rpe: rpe)

        case .askForm(let exerciseName):
            response = handleFormQuery(exerciseName: exerciseName ?? currentExerciseName)

        case .generalQuestion(let text):
            response = await handleGeneralQuery(
                text: text,
                profile: profile,
                allWorkouts: allWorkouts,
                modelContext: modelContext
            )
        }

        lastResponse = response
        speak(response)
    }

    // MARK: - Command Handlers

    private func handleWeightQuery(
        exerciseName: String?,
        exercises: [ActiveExercise],
        allWorkouts: [Workout],
        profile: UserProfile
    ) -> String {
        guard let name = exerciseName else {
            return "Which exercise are you asking about?"
        }

        let suggestions = ProgressiveOverloadService.shared.getSuggestions(
            exercises: exercises,
            allWorkouts: allWorkouts,
            profile: profile
        )

        if let suggestion = suggestions[name] {
            let weightStr = suggestion.suggestedWeight.formatted(.number.precision(.fractionLength(0)))
            return "For \(name), try \(weightStr) pounds for \(suggestion.suggestedReps) reps. \(suggestion.reason)."
        }

        return "I don't have enough data for \(name) yet. Start with a comfortable weight and log your RPE."
    }

    private func handleVolumeQuery(exercises: [ActiveExercise]) -> String {
        let completedSets = exercises.reduce(0) { $0 + $1.sets.filter { $0.isCompleted }.count }
        let totalSets = exercises.reduce(0) { $0 + $1.sets.count }
        let totalVolume = exercises.reduce(0.0) { sum, ex in
            sum + ex.sets.filter { $0.isCompleted }.reduce(0.0) { $0 + $1.volume }
        }
        let volumeStr = totalVolume.formatted(.number.precision(.fractionLength(0)))

        return "You've completed \(completedSets) of \(totalSets) sets. Total volume: \(volumeStr) pounds."
    }

    private func handleSetFeedback(rpe: String?) -> String {
        guard let rpeStr = rpe, let rpeValue = Int(rpeStr) else {
            return "Got it. How would you rate that set — easy, moderate, or hard?"
        }

        switch rpeValue {
        case 1...5:
            return "RPE \(rpeValue) — that was easy. Consider adding weight next set."
        case 6...7:
            return "RPE \(rpeValue) — good working intensity. You're in the sweet spot."
        case 8:
            return "RPE \(rpeValue) — solid effort. One or two reps left in the tank."
        case 9:
            return "RPE \(rpeValue) — that was tough. Hold here or consider a lighter next set."
        case 10:
            return "RPE 10 — maximal effort. Take extra rest before your next set."
        default:
            return "Noted."
        }
    }

    private func handleFormQuery(exerciseName: String?) -> String {
        guard let name = exerciseName else {
            return "Which exercise do you need form cues for?"
        }

        // Check extended exercise database for form cues
        if let metadata = ExtendedExerciseDatabase.find(name) {
            let cues = metadata.cues
            if !cues.isEmpty {
                return "\(name): \(cues.joined(separator: ". "))"
            }
        }

        // Fallback cues for common exercises
        let lowered = name.lowercased()
        if lowered.contains("squat") {
            return "Squat cues: Chest up, knees tracking over toes, drive through heels, brace your core."
        } else if lowered.contains("bench") {
            return "Bench press cues: Retract shoulder blades, arch upper back, feet flat, drive bar in a slight arc."
        } else if lowered.contains("deadlift") {
            return "Deadlift cues: Hinge at hips, keep bar close, neutral spine, engage lats, push the floor away."
        } else if lowered.contains("overhead") || lowered.contains("ohp") {
            return "Overhead press cues: Brace core, press straight up, squeeze glutes, avoid excessive back arch."
        }

        return "Focus on controlled reps with full range of motion for \(name)."
    }

    private func handleGeneralQuery(
        text: String,
        profile: UserProfile,
        allWorkouts: [Workout],
        modelContext: ModelContext
    ) async -> String {
        // Delegate to AI service for open-ended questions
        let aiService = AIService()
        do {
            return try await aiService.chat(
                prompt: text,
                profile: profile,
                workouts: allWorkouts,
                modelContext: modelContext
            )
        } catch {
            return "I couldn't process that right now. Try asking again."
        }
    }

    // MARK: - Text-to-Speech

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.1
        utterance.pitchMultiplier = 1.0
        utterance.volume = 0.9

        isSpeaking = true
        synthesizer.speak(utterance)

        // Track speaking state
        Task {
            try? await Task.sleep(for: .seconds(Double(text.count) / 15.0))
            isSpeaking = false
        }
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
}
#endif
