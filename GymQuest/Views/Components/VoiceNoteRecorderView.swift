//
//  VoiceNoteRecorderView.swift
//  GymQuest
//
//  Recording UI component for attaching voice notes to posts.
//  Three states: idle (mic pill), recording (pulsing + timer), recorded (playback + delete).
//

import SwiftUI

struct VoiceNoteRecorderView: View {
    @Binding var voiceNoteData: Data?
    @Binding var voiceNoteDuration: TimeInterval

    @StateObject private var service = VoiceNoteService.shared

    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        Group {
            switch service.recordingState {
            case .idle:
                idleView
            case .recording:
                recordingView
            case .recorded:
                recordedView
            }
        }
        .animation(.easeInOut(duration: 0.2), value: service.recordingState)
    }

    // MARK: - Idle State

    private var idleView: some View {
        Button {
            service.startRecording()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(GQColors.textSecondary)

                Text("Add voice note")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.05))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Recording State

    private var recordingView: some View {
        HStack(spacing: 12) {
            // Pulsing red dot
            Circle()
                .fill(GQColors.textSecondary)
                .frame(width: 10, height: 10)
                .scaleEffect(pulseScale)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                        pulseScale = 1.4
                    }
                }
                .onDisappear {
                    pulseScale = 1.0
                }

            // Live timer
            Text(formatDuration(service.recordingDuration))
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)

            Spacer()

            // Stop button
            Button {
                if let data = service.stopRecording() {
                    voiceNoteData = data
                    voiceNoteDuration = service.recordingDuration
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 11))
                    Text("Stop")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(GQColors.textSecondary)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(GQColors.textSecondary.opacity(0.12))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(GQColors.textSecondary.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Recorded State

    private var recordedView: some View {
        HStack(spacing: 10) {
            // Play/pause button
            Button {
                if service.isPlaying {
                    service.stopPlayback()
                } else if let data = service.recordedData {
                    service.playAudio(from: data)
                }
            } label: {
                Image(systemName: service.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(GQColors.textSecondary)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.08))
                        .frame(height: 4)

                    Capsule()
                        .fill(GQColors.textSecondary)
                        .frame(width: geo.size.width * service.playbackProgress, height: 4)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 32)

            // Duration
            Text(formatDuration(voiceNoteDuration))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(GQColors.textSecondary)

            // Delete button
            Button {
                voiceNoteData = nil
                voiceNoteDuration = 0
                service.deleteRecording()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(GQColors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(GQColors.textSecondary.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
