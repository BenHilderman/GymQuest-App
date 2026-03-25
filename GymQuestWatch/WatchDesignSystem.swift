//
//  WatchDesignSystem.swift
//  GymQuestWatch
//
//  Apple-native watchOS design system. Neutral palette with gradient accents.
//

import SwiftUI
import ImageIO

// MARK: - Layout

enum WatchLayout {
    static let horizontalPadding: CGFloat = 8
    static let cornerRadius: CGFloat = 14
    static let gifSize: CGFloat = 36
    static let spacingSmall: CGFloat = 4
    static let spacingMedium: CGFloat = 8
    static let spacingLarge: CGFloat = 12
}

// MARK: - Colors (Neutral palette only)

enum WatchColors {
    static let deepBlue = Color(hex: "3D7CFF")
    static let vividPurple = Color(hex: "C95BFF")

    // Neutrals
    static let background = Color(white: 0.06)
    static let surface = Color(white: 0.13)
    static let surfaceElevated = Color(white: 0.17)
    static let surfaceLight = Color(white: 0.22)
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.55)
    static let textTertiary = Color(white: 0.38)
    static let border = Color(white: 0.20)
    static let success = Color(hex: "34C759")
    static let gold = Color(hex: "FFD700")
}

// MARK: - Gradients (Only color in the app)

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

    static let subtle = LinearGradient(
        colors: [WatchColors.deepBlue.opacity(0.15), WatchColors.vividPurple.opacity(0.15)],
        startPoint: .leading,
        endPoint: .trailing
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
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(WatchColors.textTertiary)
                    .frame(width: size, height: size)
                    .background(WatchColors.surface)
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

// MARK: - Glass Card Modifier

struct WatchGlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(WatchColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: WatchLayout.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: WatchLayout.cornerRadius)
                    .stroke(WatchColors.border, lineWidth: 0.5)
            )
    }
}

extension View {
    func watchGlass() -> some View {
        modifier(WatchGlassCard())
    }
}
