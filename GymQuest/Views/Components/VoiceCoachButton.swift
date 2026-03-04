//
//  VoiceCoachButton.swift
//  GymQuest
//
//  Floating microphone FAB button for hands-free voice coaching during workouts.
//  Shows transcription and AI response overlays.
//

#if canImport(UIKit)
import SwiftUI
import SwiftData

struct VoiceCoachButton: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var speechService = SpeechRecognitionService.shared
    @StateObject private var voiceCoach = WorkoutVoiceCoachService.shared

    let exercises: [ActiveExercise]
    let currentExerciseName: String?
    let profile: UserProfile
    let allWorkouts: [Workout]

    @State private var showingTranscription = false

    var body: some View {
        VStack(spacing: 0) {
            // AI Response overlay
            if !voiceCoach.lastResponse.isEmpty {
                responseOverlay
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Transcription overlay
            if showingTranscription && !speechService.transcribedText.isEmpty {
                transcriptionOverlay
                    .transition(.opacity)
            }

            // Mic button
            Button {
                toggleListening()
            } label: {
                ZStack {
                    Circle()
                        .fill(speechService.isListening ? Color.red : GQColors.vividPurple)
                        .frame(width: 56, height: 56)
                        .shadow(color: (speechService.isListening ? Color.red : GQColors.vividPurple).opacity(0.4),
                                radius: 8, y: 4)

                    Image(systemName: speechService.isListening ? "mic.fill" : "mic")
                        .font(.title3)
                        .foregroundColor(.white)

                    // Listening pulse animation
                    if speechService.isListening {
                        Circle()
                            .stroke(Color.red.opacity(0.5), lineWidth: 2)
                            .frame(width: 56, height: 56)
                            .scaleEffect(speechService.isListening ? 1.4 : 1.0)
                            .opacity(speechService.isListening ? 0 : 1)
                            .animation(.easeOut(duration: 1.0).repeatForever(autoreverses: false), value: speechService.isListening)
                    }
                }
            }
        }
    }

    // MARK: - Transcription Overlay

    private var transcriptionOverlay: some View {
        Text(speechService.transcribedText)
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.bottom, 8)
    }

    // MARK: - Response Overlay

    private var responseOverlay: some View {
        HStack(spacing: 8) {
            Image(systemName: voiceCoach.isSpeaking ? "speaker.wave.2.fill" : "text.bubble.fill")
                .foregroundColor(GQColors.vividPurple)

            Text(voiceCoach.lastResponse)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(3)
        }
        .padding(12)
        .background(Color.black.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .onTapGesture {
            voiceCoach.lastResponse = ""
            voiceCoach.stopSpeaking()
        }
    }

    // MARK: - Actions

    private func toggleListening() {
        if speechService.isListening {
            speechService.stopListening()
            showingTranscription = false
        } else {
            if !speechService.isAuthorized {
                speechService.requestAuthorization()
                return
            }

            showingTranscription = true
            voiceCoach.lastResponse = ""

            try? speechService.startListening { command in
                Task {
                    await voiceCoach.handleCommand(
                        command,
                        exercises: exercises,
                        currentExerciseName: currentExerciseName,
                        profile: profile,
                        allWorkouts: allWorkouts,
                        modelContext: modelContext
                    )
                }
                speechService.stopListening()
                showingTranscription = false

                // Auto-clear response after 8 seconds
                Task {
                    try? await Task.sleep(for: .seconds(8))
                    voiceCoach.lastResponse = ""
                }
            }
        }
    }
}
#endif
