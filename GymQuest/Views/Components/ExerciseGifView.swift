//
//  ExerciseGifView.swift
//  GymQuest
//
//  Reusable animated GIF component for exercise demonstrations.
//  Loads bundled GIFs via SDWebImageSwiftUI for efficient animated playback.
//

import SwiftUI
import SDWebImageSwiftUI

struct ExerciseGifView: View {
    let exerciseName: String
    var size: GifSize = .thumbnail
    var showFallback: Bool = true

    enum GifSize {
        case thumbnail  // 40×40pt — list rows
        case detail     // 44×44pt — detail page rows, scaledToFit
        case medium     // 80×80pt — expanded cards
        case large      // full width × 250pt — form demo sheet

        var dimension: CGFloat {
            switch self {
            case .thumbnail: return 40
            case .detail: return 44
            case .medium: return 80
            case .large: return 250
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .thumbnail: return 8
            case .detail: return 10
            case .medium: return 12
            case .large: return 12
            }
        }
    }

    private var gifURL: URL? {
        ExerciseGifService.shared.gifURL(for: exerciseName)
    }

    var body: some View {
        if let url = gifURL {
            gifContent(url: url)
        } else if showFallback {
            fallbackContent
        }
    }

    @ViewBuilder
    private func gifContent(url: URL) -> some View {
        switch size {
        case .thumbnail, .medium:
            AnimatedImage(url: url, isAnimating: .constant(true))
                .customLoopCount(0)
                .playbackRate(1.5)
                .resizable()
                .scaledToFill()
                .frame(width: size.dimension, height: size.dimension)
                .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius))
                .background(
                    RoundedRectangle(cornerRadius: size.cornerRadius)
                        .fill(GQColors.surfaceElevated)
                )
        case .detail:
            AnimatedImage(url: url, isAnimating: .constant(true))
                .customLoopCount(0)
                .playbackRate(1.5)
                .resizable()
                .scaledToFit()
                .frame(width: size.dimension, height: size.dimension)
                .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius))
                .background(
                    RoundedRectangle(cornerRadius: size.cornerRadius)
                        .fill(GQColors.surfaceElevated)
                )
        case .large:
            AnimatedImage(url: url, isAnimating: .constant(true))
                .customLoopCount(0)
                .playbackRate(1.5)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: size.dimension)
                .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius))
                .background(
                    RoundedRectangle(cornerRadius: size.cornerRadius)
                        .fill(GQColors.surfaceElevated)
                )
        }
    }

    @ViewBuilder
    private var fallbackContent: some View {
        let metadata = ExtendedExerciseDatabase.find(exerciseName)
        switch size {
        case .thumbnail, .detail, .medium:
            ZStack {
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .fill(GQColors.surfaceElevated)
                    .frame(width: size.dimension, height: size.dimension)
                Image(systemName: metadata?.equipment.icon ?? "figure.strengthtraining.traditional")
                    .font(.system(size: size == .thumbnail ? 16 : 28))
                    .foregroundColor(GQColors.textTertiary)
            }
        case .large:
            ZStack {
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [GQColors.surfaceElevated, GQColors.surfaceBase],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: size.cornerRadius)
                            .stroke(GQGradients.glassBorder, lineWidth: 1)
                    )
                    .frame(height: size.dimension)

                VStack(spacing: 12) {
                    Image(systemName: metadata?.equipment.icon ?? "figure.strengthtraining.traditional")
                        .font(.system(size: 48))
                        .foregroundColor(GQColors.textTertiary.opacity(0.6))
                    Text("No demo available")
                        .font(.caption)
                        .foregroundColor(GQColors.textTertiary)
                }
            }
        }
    }
}

// MARK: - Exercise GIF Strip (horizontal scrolling for feed posts)

struct ExerciseGifStripItem: View {
    let exercise: SharedWorkoutData.SharedExercise

    private var setSummary: String {
        let count = exercise.sets.count
        let topReps = exercise.sets.first?.reps ?? 0
        let topWeight = exercise.sets.map(\.weight).max() ?? 0
        if topWeight > 0 {
            return "\(count)×\(topReps) @ \(Int(topWeight))"
        }
        return "\(count)×\(topReps)"
    }

    var body: some View {
        VStack(spacing: 4) {
            ExerciseGifView(exerciseName: exercise.name, size: .medium)

            Text(exercise.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(GQColors.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: 80)

            Text(setSummary)
                .font(.system(size: 10))
                .foregroundColor(GQColors.textTertiary)
                .lineLimit(1)
        }
    }
}

struct ExerciseGifStrip: View {
    let exercises: [SharedWorkoutData.SharedExercise]
    let totalCount: Int
    var onTapMore: (() -> Void)? = nil

    private var visibleExercises: [SharedWorkoutData.SharedExercise] {
        Array(exercises.prefix(6))
    }

    private var overflowCount: Int {
        max(0, totalCount - 6)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(visibleExercises) { exercise in
                    ExerciseGifStripItem(exercise: exercise)
                }

                if overflowCount > 0 {
                    Button {
                        onTapMore?()
                    } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(GQColors.surfaceElevated)
                                    .frame(width: 80, height: 80)
                                Text("+\(overflowCount)")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(GQColors.textSecondary)
                            }
                            Text("more")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(GQColors.textTertiary)
                            Spacer().frame(height: 12) // align with set summary row
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Overlay Exercise GIF Strip (compact variant for media overlays)

struct OverlayExerciseGifStrip: View {
    let exercises: [SharedWorkoutData.SharedExercise]
    let totalCount: Int
    var onTapMore: (() -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(exercises) { exercise in
                        OverlayExerciseGifItem(exercise: exercise)
                    }
                }
                .padding(.horizontal, 4)
                .frame(minWidth: geo.size.width)
            }
        }
        .frame(height: 66)
    }
}

struct OverlayExerciseGifItem: View {
    let exercise: SharedWorkoutData.SharedExercise

    private var setSummary: String {
        let count = exercise.sets.count
        let topWeight = exercise.sets.map(\.weight).max() ?? 0
        if topWeight > 0 { return "\(count)s · \(Int(topWeight))lb" }
        return "\(count) sets"
    }

    var body: some View {
        VStack(spacing: 2) {
            ExerciseGifView(exerciseName: exercise.name, size: .detail)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 2)
            Text(exercise.name)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 1)
                .lineLimit(1)
                .frame(maxWidth: 52)
            Text(setSummary)
                .font(.system(size: 9, weight: .regular))
                .foregroundColor(.white.opacity(0.85))
                .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 1)
                .lineLimit(1)
        }
    }
}
