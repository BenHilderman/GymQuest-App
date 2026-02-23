//
//  FormPeekSheet.swift
//  GymQuest
//
//  In-workout "Form Peek" quick reference sheet.
//

import SwiftUI
import SwiftData
import AVFoundation

struct FormPeekSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let exercise: FormExercise

    @StateObject private var loopingPlayer: LoopingPlayerManager
    @StateObject private var timeObserver = PlayerTimeObserver()
    @State private var overlayEvents: [OverlayEvent] = []

    init(exercise: FormExercise) {
        self.exercise = exercise

        // Create a placeholder player - will be replaced in onAppear
        let placeholderURL = URL(string: "about:blank")!
        _loopingPlayer = StateObject(wrappedValue: LoopingPlayerManager(url: placeholderURL))
    }

    var repo: FormRepository { FormRepository(modelContext: modelContext) }

    var topCues: [FormCue] {
        exercise.cues.sorted(by: { $0.priority < $1.priority }).prefix(3).map { $0 }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            header

            // Video
            videoSection

            // Top cue
            if let topCue = topCues.first {
                topCueCard(topCue)
            }

            // All cues (expandable)
            if topCues.count > 1 {
                allCuesSection
            }

            Spacer(minLength: 8)
        }
        .padding(16)
        .background(GQColors.background)
        .onAppear {
            loadClip()
        }
        .onDisappear {
            loopingPlayer.pause()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Form Peek")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(GQColors.textSecondary)

                Text(exercise.name)
                    .font(.title3.weight(.bold))
                    .foregroundColor(GQColors.textPrimary)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(GQColors.textSecondary)
            }
        }
    }

    // MARK: - Video

    private var videoSection: some View {
        ZStack {
            FormVideoPlayerView(player: loopingPlayer.player, showsPlaybackControls: false)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 18))

            // Overlays
            FormOverlayLayer(events: overlayEvents, currentTime: timeObserver.currentTime)
                .clipShape(RoundedRectangle(cornerRadius: 18))

            // Play indicator
            VStack {
                Spacer()
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption)
                    Text("Looping")
                        .font(.caption.weight(.medium))
                }
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .padding(12)
            }
        }
    }

    // MARK: - Cues

    private func topCueCard(_ cue: FormCue) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "target")
                .font(.title3)
                .foregroundColor(GQColors.primary)

            Text(cue.text)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(GQColors.textPrimary)
                .multilineTextAlignment(.leading)

            Spacer()
        }
        .padding(14)
        .background(GQColors.primary.opacity(0.15))
        .cornerRadius(14)
    }

    private var allCuesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("All Cues")
                .font(.caption.weight(.semibold))
                .foregroundColor(GQColors.textSecondary)

            ForEach(Array(topCues.dropFirst().enumerated()), id: \.element.id) { index, cue in
                HStack(spacing: 8) {
                    Text("\(index + 2).")
                        .font(.caption.weight(.bold))
                        .foregroundColor(GQColors.primary)
                        .frame(width: 20, alignment: .leading)

                    Text(cue.text)
                        .font(.subheadline)
                        .foregroundColor(GQColors.textPrimary)
                }
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.03))
        .cornerRadius(12)
    }

    // MARK: - Load

    private func loadClip() {
        guard let clip = repo.clip(exercise: exercise, type: .loop, angle: nil),
              let url = clip.bestPlaybackURL else {
            return
        }

        loopingPlayer.replaceURL(url)
        loopingPlayer.play()
        timeObserver.observe(loopingPlayer.player)

        // Load overlays if present
        if let overlayURLString = clip.overlayTimelineURLString,
           let overlayURL = URL(string: overlayURLString) {
            Task {
                do {
                    overlayEvents = try await OverlayTimelineLoader.load(from: overlayURL)
                } catch {
                    overlayEvents = []
                }
            }
        }
    }
}

// MARK: - Form Peek Button (for ActiveWorkoutView)

struct FormPeekButton: View {
    let exerciseName: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 12))

                Text("Form")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(GQColors.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(GQColors.primary.opacity(0.15))
            .cornerRadius(8)
        }
    }
}
