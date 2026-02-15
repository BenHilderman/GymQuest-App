//
//  VoiceNotePlayerView.swift
//  GymQuest
//
//  Compact inline player for voice notes in the feed.
//  Self-contained playback with progress bar.
//

import SwiftUI
import AVFoundation

struct VoiceNotePlayerView: View {
    let audioData: Data
    let duration: TimeInterval

    @State private var isPlaying = false
    @State private var progress: Double = 0
    @State private var currentTime: TimeInterval = 0

    #if canImport(UIKit)
    @State private var player: AVAudioPlayer?
    @State private var playbackTimer: Timer?
    #endif

    var body: some View {
        HStack(spacing: 10) {
            // Play/pause button
            Button {
                togglePlayback()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(GQColors.cyanSpark)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            // Progress capsule
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 4)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [GQColors.cyanSpark, GQColors.vividPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * progress), height: 4)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 34)

            // Duration label
            Text(formatDuration(isPlaying ? currentTime : duration))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(GQColors.surfaceElevated)
        .cornerRadius(12)
        .onDisappear {
            cleanup()
        }
    }

    // MARK: - Playback

    private func togglePlayback() {
        #if canImport(UIKit)
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
        #endif
    }

    #if canImport(UIKit)
    private func startPlayback() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("gymquest_feed_playback_\(UUID().uuidString).m4a")
            try audioData.write(to: tempURL)

            let audioPlayer = try AVAudioPlayer(contentsOf: tempURL)
            player = audioPlayer
            audioPlayer.play()
            isPlaying = true
            progress = 0
            currentTime = 0

            playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                Task { @MainActor in
                    guard let p = player else { return }
                    if p.isPlaying {
                        progress = p.duration > 0 ? p.currentTime / p.duration : 0
                        currentTime = p.currentTime
                    } else {
                        stopPlayback()
                    }
                }
            }
        } catch {
            isPlaying = false
        }
    }

    private func stopPlayback() {
        player?.stop()
        player = nil
        playbackTimer?.invalidate()
        playbackTimer = nil
        isPlaying = false
        progress = 0
        currentTime = 0
    }
    #endif

    private func cleanup() {
        #if canImport(UIKit)
        stopPlayback()
        #endif
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
