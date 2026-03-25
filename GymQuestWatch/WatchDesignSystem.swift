//
//  WatchDesignSystem.swift
//  GymQuestWatch
//
//  watchOS design system matching the iOS/tvOS brand.
//

import SwiftUI
import ImageIO

// MARK: - Layout Constants

enum WatchLayout {
    static let horizontalPadding: CGFloat = 8
    static let cornerRadius: CGFloat = 12
    static let gifSize: CGFloat = 36
    static let spacingSmall: CGFloat = 4
    static let spacingMedium: CGFloat = 8
    static let spacingLarge: CGFloat = 12
}

// MARK: - Brand Colors

enum WatchColors {
    static let deepBlue = Color(hex: "3D7CFF")
    static let vividPurple = Color(hex: "C95BFF")
    static let cyanSpark = Color(hex: "33D1FF")
    static let success = Color.green
    static let gold = Color(hex: "FFD700")
    static let background = Color(white: 0.08)
    static let surface = Color(white: 0.14)
    static let surfaceElevated = Color(white: 0.18)
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.6)
}

// MARK: - Gradients

enum WatchGradients {
    static let primary = LinearGradient(
        colors: [WatchColors.deepBlue, WatchColors.vividPurple],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let primaryVertical = LinearGradient(
        colors: [WatchColors.deepBlue, WatchColors.vividPurple],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        r = Double((int >> 16) & 0xFF) / 255.0
        g = Double((int >> 8) & 0xFF) / 255.0
        b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Exercise GIF View (Watch)

struct WatchGifView: View {
    let exerciseName: String
    let size: CGFloat

    init(_ exerciseName: String, size: CGFloat = WatchLayout.gifSize) {
        self.exerciseName = exerciseName
        self.size = size
    }

    var body: some View {
        Group {
            if let gifImage = loadGifFrame() {
                gifImage
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundStyle(WatchColors.vividPurple)
                    .frame(width: size, height: size)
                    .background(WatchColors.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func loadGifFrame() -> Image? {
        guard let url = ExerciseGifService.shared.gifURL(for: exerciseName),
              let data = try? Data(contentsOf: url),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        return Image(decorative: cgImage, scale: 1.0)
    }
}

// MARK: - Gradient Button Style

struct WatchPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.footnote.bold())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(WatchGradients.primary)
            .clipShape(RoundedRectangle(cornerRadius: WatchLayout.cornerRadius))
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}
