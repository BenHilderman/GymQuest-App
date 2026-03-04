//
//  SpeechRecognitionService.swift
//  GymQuest
//
//  Live speech recognition for hands-free voice commands during workouts.
//  Uses on-device SFSpeechRecognizer with continuous audio engine.
//

#if canImport(UIKit)
import Foundation
import Speech
import AVFoundation
import Combine

// MARK: - Voice Commands

enum VoiceCommand {
    case askWeight(exerciseName: String?)
    case askVolume
    case setFeedback(rpe: String?)
    case askForm(exerciseName: String?)
    case generalQuestion(text: String)
}

// MARK: - Service

@MainActor
class SpeechRecognitionService: ObservableObject {
    static let shared = SpeechRecognitionService()

    @Published var isListening = false
    @Published var transcribedText = ""
    @Published var isAuthorized = false

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    private init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    // MARK: - Authorization

    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                self?.isAuthorized = (status == .authorized)
            }
        }
    }

    // MARK: - Start / Stop

    func startListening(onCommand: @escaping (VoiceCommand) -> Void) throws {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            return
        }

        // Cancel any existing task
        stopListening()

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = true

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let text = result.bestTranscription.formattedString
                Task { @MainActor in
                    self.transcribedText = text
                }

                if result.isFinal {
                    let command = Self.parseCommand(text)
                    Task { @MainActor in
                        onCommand(command)
                    }
                }
            }

            if error != nil {
                Task { @MainActor in
                    self.stopListening()
                }
            }
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        isListening = true
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        isListening = false
        transcribedText = ""
    }

    // MARK: - Command Parsing

    static func parseCommand(_ text: String) -> VoiceCommand {
        let lowered = text.lowercased()

        // Weight queries
        if lowered.contains("how much") && lowered.contains("weight") ||
           lowered.contains("what weight") ||
           lowered.contains("suggested weight") ||
           lowered.contains("what should i lift") {
            let exerciseName = extractExerciseName(from: lowered)
            return .askWeight(exerciseName: exerciseName)
        }

        // Volume queries
        if lowered.contains("volume") ||
           lowered.contains("how many sets") ||
           lowered.contains("total sets") ||
           lowered.contains("how much have i done") {
            return .askVolume
        }

        // RPE / feedback
        if lowered.contains("felt easy") || lowered.contains("rpe") ||
           lowered.contains("felt hard") || lowered.contains("too heavy") {
            let rpe = extractRPE(from: lowered)
            return .setFeedback(rpe: rpe)
        }

        // Form queries
        if lowered.contains("form") || lowered.contains("technique") ||
           lowered.contains("how do i") || lowered.contains("cue") {
            let exerciseName = extractExerciseName(from: lowered)
            return .askForm(exerciseName: exerciseName)
        }

        // Default: general question
        return .generalQuestion(text: text)
    }

    private static func extractExerciseName(from text: String) -> String? {
        let exercises = ["bench press", "squat", "deadlift", "overhead press",
                        "barbell row", "pull up", "chin up", "dumbbell curl",
                        "lat pulldown", "leg press", "romanian deadlift"]
        return exercises.first { text.contains($0) }
    }

    private static func extractRPE(from text: String) -> String? {
        if text.contains("easy") { return "5" }
        if text.contains("moderate") { return "7" }
        if text.contains("hard") { return "9" }
        if text.contains("failed") { return "10" }

        // Try to find "rpe" followed by a number
        if let range = text.range(of: "rpe ") {
            let after = String(text[range.upperBound...]).prefix(2).trimmingCharacters(in: .whitespaces)
            if Int(after) != nil { return after }
        }
        return nil
    }
}
#endif
