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
        case medium     // 80×80pt — expanded cards
        case large      // full width × 250pt — form demo sheet

        var dimension: CGFloat {
            switch self {
            case .thumbnail: return 40
            case .medium: return 80
            case .large: return 250
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .thumbnail: return 8
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
                .resizable()
                .scaledToFill()
                .frame(width: size.dimension, height: size.dimension)
                .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius))
                .background(
                    RoundedRectangle(cornerRadius: size.cornerRadius)
                        .fill(GQColors.surfaceElevated)
                )
        case .large:
            AnimatedImage(url: url, isAnimating: .constant(true))
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
        case .thumbnail, .medium:
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
