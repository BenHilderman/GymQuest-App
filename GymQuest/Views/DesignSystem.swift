//
//  DesignSystem.swift
//  GymQuest
//
//  Bold & Energetic design system with animated multi-color gradients
//  Premium dark theme with vibrant accents
//  Inspired by: Nike Training Club, Peloton, Strava
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Haptic Manager

final class HapticManager {
    static let shared = HapticManager()

    #if canImport(UIKit)
    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()
    #endif

    private var isEnabled: Bool {
        #if canImport(UIKit)
        guard UserDefaults.standard.object(forKey: "hapticFeedbackEnabled") as? Bool ?? true else { return false }
        return !UIAccessibility.isReduceMotionEnabled
        #else
        return false
        #endif
    }

    private init() {
        #if canImport(UIKit)
        lightGenerator.prepare()
        mediumGenerator.prepare()
        heavyGenerator.prepare()
        selectionGenerator.prepare()
        notificationGenerator.prepare()
        #endif
    }

    func tap() {
        #if canImport(UIKit)
        guard isEnabled else { return }
        lightGenerator.impactOccurred()
        #endif
    }

    func select() {
        #if canImport(UIKit)
        guard isEnabled else { return }
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
        #endif
    }

    func impact(_ style: HapticStyle = .medium) {
        #if canImport(UIKit)
        guard isEnabled else { return }
        switch style {
        case .light: lightGenerator.impactOccurred()
        case .medium: mediumGenerator.impactOccurred()
        case .heavy: heavyGenerator.impactOccurred()
        }
        #endif
    }

    func setComplete(setNumber: Int, totalSets: Int) {
        #if canImport(UIKit)
        guard isEnabled else { return }
        // Progressive intensity: later sets get heavier haptics
        let progress = Double(setNumber) / Double(max(totalSets, 1))
        if progress >= 1.0 {
            // Final set: double tap pattern
            heavyGenerator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.heavyGenerator.impactOccurred()
            }
        } else if progress >= 0.5 {
            mediumGenerator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                self.mediumGenerator.impactOccurred()
            }
        } else {
            lightGenerator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                self.lightGenerator.impactOccurred()
            }
        }
        #endif
    }

    func workoutComplete() {
        #if canImport(UIKit)
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.heavyGenerator.impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.mediumGenerator.impactOccurred()
        }
        #endif
    }

    func success() {
        #if canImport(UIKit)
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.success)
        #endif
    }

    func error() {
        #if canImport(UIKit)
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.error)
        #endif
    }

    // MARK: - Workout Haptics (from ActiveWorkoutViewModel)

    func buttonTap() {
        tap()
    }

    func restTimerWarning() {
        impact(.medium)
    }

    func restTimerCountdown() {
        impact(.heavy)
    }

    func restTimerDone() {
        success()
    }

    func prDetected() {
        #if canImport(UIKit)
        guard isEnabled else { return }
        heavyGenerator.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            self.mediumGenerator.impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            self.heavyGenerator.impactOccurred()
        }
        #endif
    }

    func milestoneReached() {
        #if canImport(UIKit)
        guard isEnabled else { return }
        heavyGenerator.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.heavyGenerator.impactOccurred()
        }
        #endif
    }

    func countdownBeat() {
        impact(.heavy)
    }

    func countdownGo() {
        #if canImport(UIKit)
        guard isEnabled else { return }
        heavyGenerator.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.heavyGenerator.impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.notificationGenerator.notificationOccurred(.success)
        }
        #endif
    }

    func fieldEdit() {
        tap()
    }

    // Legacy aliases
    func setComplete() {
        success()
    }

    func exerciseComplete() {
        #if canImport(UIKit)
        guard isEnabled else { return }
        heavyGenerator.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.notificationGenerator.notificationOccurred(.success)
        }
        #endif
    }

    enum HapticStyle {
        case light, medium, heavy
    }
}

// MARK: - Live PR Banner (in-workout overlay)

struct LivePRBanner: View {
    let exerciseName: String
    let prType: String
    let delta: String

    @State private var trophyScale: CGFloat = 0.3
    @State private var glowOpacity: Double = 1.0
    @State private var deltaValue: Int = 0
    @State private var appeared = false

    private var deltaNumber: Int? {
        let cleaned = delta.replacingOccurrences(of: "+", with: "")
            .replacingOccurrences(of: " lbs", with: "")
            .replacingOccurrences(of: " reps", with: "")
            .replacingOccurrences(of: " lb", with: "")
        return Int(cleaned)
    }

    var body: some View {
        ZStack {
            HStack(spacing: 10) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .scaleEffect(trophyScale)

                VStack(alignment: .leading, spacing: 2) {
                    Text("NEW \(prType)")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.white.opacity(0.9))
                    Text(exerciseName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }

                Spacer()

                if let target = deltaNumber {
                    Text(delta.contains("lbs") ? "+\(deltaValue) lbs" : delta.contains("reps") ? "+\(deltaValue) reps" : "+\(deltaValue)")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.white.opacity(0.2)))
                        .onAppear {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                deltaValue = target
                            }
                        }
                } else {
                    Text(delta)
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.white.opacity(0.2)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [GQColors.prGold, GQColors.prGold.opacity(0.8), Color.orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .opacity(glowOpacity)
            )
            .animatedGradientBorder(
                cornerRadius: 14,
                lineWidth: 1.5,
                colors: [GQColors.prGold, .white.opacity(0.6), GQColors.prGold],
                duration: 3.0
            )
            .shadow(color: GQColors.prGold.opacity(0.4), radius: 12, y: 4)
            .padding(.horizontal, 16)

            MiniConfettiBurst()
                .allowsHitTesting(false)
        }
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                trophyScale = 1.0
            }
            withAnimation(
                .easeInOut(duration: 1.2)
                .repeatForever(autoreverses: true)
            ) {
                glowOpacity = 0.85
            }
        }
    }
}

// MARK: - Mini Confetti Burst

struct MiniConfettiBurst: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var isAnimating = false

    let colors: [Color] = [GQColors.prGold, .orange, .yellow, .white]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(particle.color)
                        .frame(width: particle.size.width, height: particle.size.height)
                        .rotationEffect(.degrees(isAnimating ? particle.spinEnd : particle.spinStart))
                        .position(
                            x: isAnimating ? particle.endX : geo.size.width / 2,
                            y: isAnimating ? particle.endY : geo.size.height * 0.2
                        )
                        .opacity(isAnimating ? 0 : 1)
                }
            }
            .onAppear {
                particles = (0..<20).map { _ in
                    ConfettiParticle(
                        color: colors.randomElement() ?? .white,
                        size: CGSize(width: CGFloat.random(in: 3...7), height: CGFloat.random(in: 6...12)),
                        endX: CGFloat.random(in: -20...geo.size.width + 20),
                        endY: CGFloat.random(in: geo.size.height * 0.4...geo.size.height + 60),
                        spinStart: Double.random(in: 0...360),
                        spinEnd: Double.random(in: 360...720)
                    )
                }
                withAnimation(.easeOut(duration: 1.0)) {
                    isAnimating = true
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - PR Badge Card (completion screen)

struct PRBadgeCard: View {
    let exerciseName: String
    let prType: String
    let delta: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                AnimatedGradientCircle(
                    size: 40,
                    lineWidth: 2,
                    colors: [GQColors.prGold, .orange, GQColors.prGold],
                    duration: 6
                )
                Image(systemName: "trophy.fill")
                    .font(.system(size: 18))
                    .foregroundColor(GQColors.prGold)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(prType)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(GQColors.prGold)
                Text(exerciseName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)
            }

            Spacer()

            Text(delta)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(GQColors.prGold)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    RadialGradient(
                        colors: [GQColors.prGold.opacity(0.08), GQColors.cardBackground],
                        center: .leading,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
        )
        .animatedGradientBorder(
            cornerRadius: 12,
            lineWidth: 1.5,
            colors: [GQColors.prGold, .white.opacity(0.6), GQColors.prGold],
            duration: 4
        )
    }
}

// MARK: - Coach Insight Card

struct CoachInsightCard: View {
    let message: String
    let icon: String
    let tintColor: Color

    @State private var iconRotation: Double = -10
    @State private var accentPulse: Double = 0.6

    init(message: String, icon: String = "sparkles", tintColor: Color = GQColors.deepBlue) {
        self.message = message
        self.icon = icon
        self.tintColor = tintColor
    }

    private var isFlameInsight: Bool { icon == "flame.fill" }

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(tintColor)
                .frame(width: 3)
                .opacity(accentPulse)

            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(tintColor)
                    .rotationEffect(.degrees(iconRotation))

                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(GQColors.textPrimary)
                    .lineLimit(2)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(GQColors.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(tintColor.opacity(0.2), lineWidth: 1))
        .conditionalAnimatedBorder(
            enabled: isFlameInsight,
            cornerRadius: 12,
            lineWidth: 1.5,
            colors: [GQColors.success, GQColors.cyanSpark, GQColors.success],
            duration: 5
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                iconRotation = 0
            }
            withAnimation(
                .easeInOut(duration: 0.6)
            ) {
                accentPulse = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeInOut(duration: 0.6)) {
                    accentPulse = 0.6
                }
            }
        }
    }
}

extension View {
    @ViewBuilder
    func conditionalAnimatedBorder(
        enabled: Bool,
        cornerRadius: CGFloat,
        lineWidth: CGFloat,
        colors: [Color],
        duration: Double
    ) -> some View {
        if enabled {
            self.animatedGradientBorder(
                cornerRadius: cornerRadius,
                lineWidth: lineWidth,
                colors: colors,
                duration: duration
            )
        } else {
            self
        }
    }
}

// MARK: - Confetti View

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var isAnimating = false

    let colors: [Color] = [
        GQColors.primary, GQColors.secondary, GQColors.success, GQColors.prGold
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(particle.color)
                        .frame(width: particle.size.width, height: particle.size.height)
                        .rotationEffect(.degrees(isAnimating ? particle.spinEnd : particle.spinStart))
                        .position(
                            x: isAnimating ? particle.endX : geo.size.width / 2,
                            y: isAnimating ? particle.endY : geo.size.height * 0.3
                        )
                        .opacity(isAnimating ? 0 : 1)
                }
            }
            .onAppear {
                generateParticles(in: geo.size)
                withAnimation(.easeOut(duration: 1.5)) {
                    isAnimating = true
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func generateParticles(in size: CGSize) {
        particles = (0..<40).map { _ in
            ConfettiParticle(
                color: colors.randomElement() ?? .white,
                size: CGSize(
                    width: CGFloat.random(in: 4...10),
                    height: CGFloat.random(in: 8...16)
                ),
                endX: CGFloat.random(in: -40...size.width + 40),
                endY: CGFloat.random(in: size.height * 0.5...size.height + 100),
                spinStart: Double.random(in: 0...360),
                spinEnd: Double.random(in: 360...1080)
            )
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGSize
    let endX: CGFloat
    let endY: CGFloat
    let spinStart: Double
    let spinEnd: Double
}

// MARK: - Animated Number View

struct AnimatedNumber: View {
    let value: Int
    let font: Font
    let color: Color

    init(_ value: Int, font: Font = .system(size: 28, weight: .bold), color: Color = .white) {
        self.value = value
        self.font = font
        self.color = color
    }

    var body: some View {
        Text("\(value)")
            .font(font)
            .foregroundColor(color)
            .contentTransition(.numericText())
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: value)
    }
}

// MARK: - Bounce Appear Modifier

struct BounceAppear: ViewModifier {
    let delay: Double
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(appeared ? 1.0 : 0.8)
            .opacity(appeared ? 1.0 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(delay)) {
                    appeared = true
                }
            }
    }
}

extension View {
    func bounceAppear(delay: Double = 0) -> some View {
        modifier(BounceAppear(delay: delay))
    }
}

// MARK: - Color Palette
//
// Active palette (use for all new components):
//   - deepBlue  (#3D7CFF) — primary brand, buttons, links
//   - vividPurple (#C95BFF) — secondary accent, AI badges, highlights
//   - success    (#1ED760) — positive states, streaks, confirmations
//
// Deprecated for new use (keep for existing surfaces only):
//   - cyanSpark, coralRed, sunsetOrange, electricGold
//

struct GQColors {
    // Energy color cycle - bold, vibrant colors that flow
    static let coralRed = Color(hex: "FF4E9A")
    static let sunsetOrange = Color(hex: "FF6CC8")
    static let electricGold = Color(hex: "4CCBFF")
    static let vividPurple = Color(hex: "C95BFF")  // Purple-pink accent
    static let deepBlue = Color(hex: "3D7CFF")
    static let cyanSpark = Color(hex: "33D1FF")

    // Primary accent
    static let primary = deepBlue
    static let secondary = vividPurple

    // Legacy aliases (use canonical names above instead)
    static let coral = coralRed
    static let peach = sunsetOrange
    static let gold = electricGold
    static let rose = vividPurple
    static let terracotta = Color(hex: "DA7C4A")
    static let sand = Color(hex: "EBD2A6")
    static let electricBlue = deepBlue
    static let neonPurple = deepBlue
    static let cyberCyan = cyanSpark
    static let hotPink = coralRed
    static let lavender = vividPurple
    static let sky = cyanSpark
    static let mint = Color(hex: "1ED760")
    static let butter = electricGold

    // Backgrounds — adaptive light/dark
    static let deepBlack = adaptive(light: "FFFFFF", dark: "0A0A0A")
    static let background = adaptive(light: "F2F2F7", dark: "121212")
    static let darkSurface = adaptive(light: "FFFFFF", dark: "1A1A1A")
    static let cardBackground = adaptive(light: "FFFFFF", dark: "1E1E1E")
    static let elevatedSurface = adaptive(light: "FFFFFF", dark: "1E1E1E")

    // Text — adaptive light/dark
    static let textPrimary = adaptive(light: "1C1C1E", dark: "F5F5F5")
    static let textSecondary = adaptive(light: "3C3C43", dark: "F5F5F5").opacity(0.60)
    static let textTertiary = adaptive(light: "3C3C43", dark: "F5F5F5").opacity(0.40)

    // Semantic colors - bright and vibrant
    static let success = Color(hex: "1ED760")
    static let warning = Color(hex: "FFD600")  // Electric yellow
    static let error = Color(hex: "FF5252")    // Hot coral
    static let prGold = Color(hex: "FFD700")

    // Accent
    static let accent = deepBlue
    static let accentLight = cyanSpark

    // Surface tokens — adaptive light/dark
    static let surfaceBase = adaptive(light: "FFFFFF", dark: "1A1A1A")
    static let surfaceElevated = adaptive(light: "F9F9FB", dark: "242424")
    static let surfaceOverlay = adaptive(light: "F0F0F5", dark: "2A2A2A")
    static let borderSubtle = adaptiveOverlay(0.04)
    static let borderDefault = adaptiveOverlay(0.08)
    static let borderProminent = adaptiveOverlay(0.12)

    // Accent border — subtle adaptive stroke
    static let borderAccent = LinearGradient(
        colors: [GQColors.adaptiveOverlay(0.08), GQColors.adaptiveOverlay(0.06)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Overlay tokens — semantic surface variations
    static let surfaceSecondary = adaptiveOverlay(0.04)
    static let overlaySubtle = adaptiveOverlay(0.03)
    static let overlayLight = adaptiveOverlay(0.05)
    static let overlayMedium = adaptiveOverlay(0.08)

    // Section label color — vibrant uppercase headers
    static let sectionLabel = GQColors.cyanSpark.opacity(0.8)

    // MARK: - Adaptive Helpers

    static func adaptive(light: String, dark: String) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(hex: dark)
                : UIColor(hex: light)
        })
        #elseif canImport(AppKit)
        return Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(hex: dark)
                : NSColor(hex: light)
        })
        #else
        return Color(hex: light)
        #endif
    }

    static func adaptiveOverlay(_ opacity: Double) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(opacity)
                : UIColor.black.withAlphaComponent(opacity)
        })
        #elseif canImport(AppKit)
        return Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor.white.withAlphaComponent(opacity)
                : NSColor.black.withAlphaComponent(opacity)
        })
        #else
        return Color.black.opacity(opacity)
        #endif
    }
}

// MARK: - Spacing & Layout Constants

struct GQSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32

    // Standard horizontal padding for screen content
    static let screenHorizontal: CGFloat = 16
}

struct GQRadius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
}

struct GQLayout {
    static let screenHorizontal: CGFloat = GQSpacing.screenHorizontal
    static let sectionSpacing: CGFloat = GQSpacing.lg
    static let pageTop: CGFloat = 10
    static let pageBottom: CGFloat = 90
    static let cardHorizontal: CGFloat = 14
    static let cardVertical: CGFloat = 13
}

struct GQMotion {
    static let press = Animation.spring(response: 0.22, dampingFraction: 0.72)
    static let micro = Animation.spring(response: 0.2, dampingFraction: 0.75)
    static let standard = Animation.easeOut(duration: 0.25)
}

// MARK: - Shadow System

enum GQShadow {
    case card
    case elevated
    case floating

    var color: Color { Color.black }

    var opacity: Double {
        switch self {
        case .card: return 0.06
        case .elevated: return 0.10
        case .floating: return 0.16
        }
    }

    var radius: CGFloat {
        switch self {
        case .card: return 8
        case .elevated: return 12
        case .floating: return 20
        }
    }

    var y: CGFloat {
        switch self {
        case .card: return 3
        case .elevated: return 4
        case .floating: return 8
        }
    }
}

extension View {
    func gqShadow(_ level: GQShadow = .card) -> some View {
        shadow(color: level.color.opacity(level.opacity), radius: level.radius, y: level.y)
    }
}

// MARK: - Unified Card Modifier

struct GQCardModifier: ViewModifier {
    var cornerRadius: CGFloat
    var shadow: GQShadow

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(GQColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(GQColors.borderDefault, lineWidth: 1)
            )
            .gqShadow(shadow)
    }
}

extension View {
    func gqCard(cornerRadius: CGFloat = GQRadius.lg, shadow: GQShadow = .card) -> some View {
        modifier(GQCardModifier(cornerRadius: cornerRadius, shadow: shadow))
    }
}

// MARK: - Hex Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Platform Color Hex Extensions

#if canImport(UIKit)
extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: 1.0
        )
    }
}
#endif

#if canImport(AppKit) && !canImport(UIKit)
import AppKit
extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: 1.0
        )
    }
}
#endif

// MARK: - Gradients (Apple-clean minimal style)

struct GQGradients {
    // Accent color for consistency
    static let accentColor = GQColors.accent

    // Energy colors - simplified for subtle use
    static let energyColors: [Color] = [
        GQColors.deepBlue,
        GQColors.vividPurple
    ]

    // Primary gradient - blue to pink
    static let primary = LinearGradient(
        colors: [GQColors.deepBlue, GQColors.vividPurple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Energy gradient - blue to pink/purple
    static let energy = LinearGradient(
        colors: [GQColors.deepBlue, GQColors.vividPurple],
        startPoint: .leading,
        endPoint: .trailing
    )

    // Achievement/PR gradient - blue to pink/purple
    static let achievement = LinearGradient(
        colors: [GQColors.deepBlue, GQColors.vividPurple],
        startPoint: .leading,
        endPoint: .trailing
    )

    // Success gradient - aligned to theme
    static let success = LinearGradient(
        colors: [GQColors.deepBlue, GQColors.vividPurple],
        startPoint: .leading,
        endPoint: .trailing
    )

    // Hero card border - glass edge with subtle depth
    static let heroBorder = LinearGradient(
        colors: [Color.black.opacity(0.10), Color.black.opacity(0.04), Color.black.opacity(0.08)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Glass card border
    static let glassBorder = LinearGradient(
        colors: [Color.black.opacity(0.08), Color.black.opacity(0.03), Color.black.opacity(0.06)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Animated gradient colors for legacy support
    static let animatedColors: [Color] = energyColors

    // Card glow - very subtle
    static let cardGlow = LinearGradient(
        colors: [Color.black.opacity(0.02), Color.clear],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Card border
    static let cardBorder = LinearGradient(
        colors: [Color.black.opacity(0.06), Color.black.opacity(0.02), Color.black.opacity(0.05)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Warm gradient (legacy)
    static let warm = LinearGradient(
        colors: [GQColors.deepBlue, GQColors.vividPurple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Workout Type Gradients

    /// Theme card gradient — card background fading into blue-purple.
    static func workoutCardGradient(for type: WorkoutType) -> LinearGradient {
        LinearGradient(
            colors: [GQColors.deepBlue.opacity(0.18), GQColors.vividPurple.opacity(0.28)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Returns a solid-style fill for workout tiles while preserving existing call sites.
    static func workoutGradient(for type: WorkoutType) -> LinearGradient {
        let color = workoutColor(for: type)
        return LinearGradient(
            colors: [color, color],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func workoutColor(for type: WorkoutType) -> Color {
        GQColors.deepBlue
    }

    /// Returns raw color array for a workout type — useful for theming rings, progress bars, checkmarks, etc.
    static func workoutGradientColors(for type: WorkoutType) -> [Color] {
        [GQColors.deepBlue, GQColors.vividPurple]
    }
}

// MARK: - Animated Gradient Circle

/// A circle with a full gradient border that rotates smoothly around
struct AnimatedGradientCircle: View {
    let size: CGFloat
    let lineWidth: CGFloat
    let colors: [Color]
    let duration: Double

    @State private var rotation: Double = 0

    init(
        size: CGFloat = 40,
        lineWidth: CGFloat = 2,
        colors: [Color] = [GQColors.deepBlue, GQColors.vividPurple, GQColors.deepBlue],
        duration: Double = 8.0
    ) {
        self.size = size
        self.lineWidth = lineWidth
        self.colors = colors
        self.duration = duration
    }

    var body: some View {
        Circle()
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: [
                        colors[0],
                        colors[1],
                        colors[0]
                    ]),
                    center: .center
                ),
                lineWidth: lineWidth
            )
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(
                    .linear(duration: duration)
                    .repeatForever(autoreverses: false)
                ) {
                    rotation = 360
                }
            }
    }
}

/// View modifier to add an animated gradient border to any shape
struct AnimatedGradientBorder: ViewModifier {
    let cornerRadius: CGFloat
    let lineWidth: CGFloat
    let colors: [Color]
    let duration: Double

    @State private var phase: CGFloat = 0

    init(
        cornerRadius: CGFloat = 16,
        lineWidth: CGFloat = 2,
        colors: [Color] = [GQColors.vividPurple, GQColors.cyanSpark, GQColors.vividPurple],
        duration: Double = 8.0
    ) {
        self.cornerRadius = cornerRadius
        self.lineWidth = lineWidth
        self.colors = colors
        self.duration = duration
    }

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                colors[0],
                                colors[1],
                                colors[0]
                            ]),
                            center: .center,
                            startAngle: .degrees(phase),
                            endAngle: .degrees(phase + 360)
                        ),
                        lineWidth: lineWidth
                    )
            )
            .onAppear {
                withAnimation(
                    .linear(duration: duration)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 360
                }
            }
    }
}

extension View {
    /// Adds a slowly rotating gradient border to any view
    func animatedGradientBorder(
        cornerRadius: CGFloat = 16,
        lineWidth: CGFloat = 2,
        colors: [Color] = [GQColors.vividPurple, GQColors.cyanSpark, GQColors.vividPurple],
        duration: Double = 8.0
    ) -> some View {
        modifier(AnimatedGradientBorder(
            cornerRadius: cornerRadius,
            lineWidth: lineWidth,
            colors: colors,
            duration: duration
        ))
    }
}

// MARK: - Typography

struct GQTypography {
    static let heroTitle = Font.system(size: 32, weight: .bold)
    static let heroNumber = Font.system(size: 48, weight: .bold, design: .rounded)
    static let heroMetric = Font.system(size: 56, weight: .bold, design: .rounded)
    static let cardTitle = Font.system(size: 20, weight: .semibold)
    static let sectionTitle = Font.system(size: 18, weight: .semibold)
    static let sectionHeader = Font.system(size: 12, weight: .bold)
    static let body = Font.system(size: 16, weight: .regular)
    static let cardBody = Font.system(size: 14, weight: .regular)
    static let caption = Font.system(size: 13, weight: .medium)
    static let micro = Font.system(size: 10, weight: .medium)
    static let stat = Font.system(size: 28, weight: .bold, design: .rounded)
    static let statLabel = Font.system(size: 11, weight: .medium)
}

// MARK: - Energy Background (Animated Gradient Orbs)

struct EnergyBackground: View {
    var body: some View {
        HomeEnergyBackground()
    }
}

// MARK: - Home Background (Cleaner blue -> pink vibe)

struct HomeEnergyBackground: View {
    var body: some View {
        Rectangle().fill(GQColors.background).ignoresSafeArea()
    }
}

// MARK: - Dead Code (Commented out during premium simplification — delete after verification)

/*
private struct AuroraFlowBackground: View { ... }
struct StarfieldOverlay: View { ... }
struct ShimmerSweepOverlay: View { ... }
— Full implementations removed for cleanliness. These animated overlays
  (aurora ribbons, starfield sparkles, shimmer sweep) are no longer used
  after the HomeEnergyBackground simplification.
*/

// MARK: - Glass Card (3D depth)

struct GlassCard<Content: View>: View {
    let accentColor: Color
    let cornerRadius: CGFloat
    let showGlow: Bool
    @ViewBuilder let content: Content

    init(
        accentColor: Color = GQColors.accent,
        cornerRadius: CGFloat = 16,
        showGlow: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.accentColor = accentColor
        self.cornerRadius = cornerRadius
        self.showGlow = showGlow
        self.content = content()
    }

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(GQColors.surfaceBase)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(GQColors.borderDefault, lineWidth: 1)
            )
            .gqShadow(.card)
    }
}

// MARK: - Hero Card (With depth)

struct HeroCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(GQColors.surfaceBase)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(GQColors.borderDefault, lineWidth: 1)
            )
            .gqShadow(.elevated)
    }
}

// MARK: - Premium Badge

struct PremiumBadge: View {
    var size: CGFloat = 14

    var body: some View {
        Image(systemName: "checkmark.seal.fill")
            .font(.system(size: size))
            .foregroundStyle(GQGradients.primary)
    }
}

// MARK: - Stat Pill (Glass morphism style)

struct StatPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            // Icon with subtle glow
            ZStack {
                // Soft glow behind icon
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 28, height: 28)
                    .blur(radius: 6)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(GQColors.textPrimary)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(GQColors.textTertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            ZStack {
                // Glass base - frosted effect
                Capsule()
                    .fill(.ultraThinMaterial)

                // Subtle color tint from the icon color
                Capsule()
                    .fill(color.opacity(0.08))

                // Top highlight for glass reflection
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.03), Color.black.opacity(0.01), Color.clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            }
        )
        .overlay(
            // Glass border with gradient shine
            Capsule()
                .stroke(GQGradients.glassBorder, lineWidth: 0.85)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }
}

// MARK: - Progress Bar (Clean Apple style)

struct AnimatedProgressBar: View {
    let progress: Double
    let height: CGFloat
    let colors: [Color]

    @State private var animatedProgress: Double = 0

    init(progress: Double, height: CGFloat = 6, colors: [Color] = [GQColors.accent]) {
        self.progress = min(1.0, max(0, progress))
        self.height = height
        self.colors = colors
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Color.black.opacity(0.06))

                // Filled portion - solid color
                Capsule()
                    .fill(colors.first ?? GQColors.accent)
                    .frame(width: geo.size.width * animatedProgress)
            }
        }
        .frame(height: height)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeOut(duration: 0.4)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Gradient Text

struct GradientText: View {
    let text: String
    let gradient: LinearGradient
    let font: Font

    init(_ text: String, gradient: LinearGradient = GQGradients.primary, font: Font = .headline) {
        self.text = text
        self.gradient = gradient
        self.font = font
    }

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(gradient)
    }
}

// MARK: - Nav Logo (With gradient border)

struct NavBarLogo: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(GQGradients.primary)
                .frame(width: 34, height: 34)

            Image(systemName: "dumbbell.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Primary Button Style (Satisfying click feedback)

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(GQGradients.primary)
            )
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.04 : 0.07), radius: configuration.isPressed ? 4 : 8, y: configuration.isPressed ? 2 : 4)
            .scaleEffect(configuration.isPressed ? 0.972 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(GQMotion.press, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { HapticManager.shared.tap() }
            }
    }
}

// MARK: - Secondary Button Style (Glass with satisfying feedback)

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(GQColors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(GQColors.surfaceBase)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [Color.black.opacity(configuration.isPressed ? 0.06 : 0.08), Color.black.opacity(configuration.isPressed ? 0.02 : 0.04)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.04 : 0.06), radius: configuration.isPressed ? 3 : 7, y: configuration.isPressed ? 1 : 3)
            .scaleEffect(configuration.isPressed ? 0.972 : 1.0)
            .offset(y: configuration.isPressed ? 1.0 : 0)
            .animation(GQMotion.micro, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { HapticManager.shared.tap() }
            }
    }
}

// MARK: - Workout Flow Styles (Unified look for workout surfaces)

struct WorkoutFlowBackground: View {
    var accent: Color = GQColors.vividPurple
    var secondaryAccent: Color = GQColors.cyanSpark

    var body: some View {
        EnergyBackground()
    }
}

struct WorkoutFlowPrimaryButtonStyle: ButtonStyle {
    var accent: Color = GQColors.vividPurple
    var cornerRadius: CGFloat = 14

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(GQGradients.primary)
            )
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.04 : 0.07), radius: configuration.isPressed ? 4 : 8, y: configuration.isPressed ? 2 : 4)
            .scaleEffect(configuration.isPressed ? 0.972 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(GQMotion.press, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { HapticManager.shared.tap() }
            }
    }
}

struct WorkoutFlowSecondaryButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 14

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(GQColors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(GQColors.surfaceBase)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [Color.black.opacity(configuration.isPressed ? 0.06 : 0.08), Color.black.opacity(configuration.isPressed ? 0.02 : 0.04)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.04 : 0.06), radius: configuration.isPressed ? 3 : 7, y: configuration.isPressed ? 1 : 3)
            .scaleEffect(configuration.isPressed ? 0.975 : 1.0)
            .offset(y: configuration.isPressed ? 1.0 : 0)
            .animation(GQMotion.micro, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { HapticManager.shared.tap() }
            }
    }
}

struct WorkoutFlowCardModifier: ViewModifier {
    var accent: Color
    var emphasized: Bool
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .modifier(GQCardModifier(cornerRadius: cornerRadius, shadow: emphasized ? .elevated : .card))
    }
}

// SilkNoiseTexture, GrainOverlay, AmbientLightSweep — removed during premium simplification

// MARK: - Home/Social Surface Styles

// DriftingGlow — removed during premium simplification

struct HomeSocialCardModifier: ViewModifier {
    var accent: Color?
    var emphasized: Bool
    var cornerRadius: CGFloat
    var subtle: Bool
    var sweepDelay: Double

    func body(content: Content) -> some View {
        content
            .modifier(GQCardModifier(cornerRadius: cornerRadius, shadow: emphasized ? .elevated : .card))
    }
}

struct HomeSocialPrimaryButtonStyle: ButtonStyle {
    var accent: Color = GQColors.vividPurple
    var cornerRadius: CGFloat = 14

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(GQGradients.primary)
            )
            .scaleEffect(configuration.isPressed ? 0.975 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(GQMotion.press, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { HapticManager.shared.tap() }
            }
    }
}

struct HomeSocialSecondaryButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 14

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(GQColors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(GQColors.surfaceBase)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [Color.black.opacity(configuration.isPressed ? 0.06 : 0.08), Color.black.opacity(configuration.isPressed ? 0.02 : 0.04)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .offset(y: configuration.isPressed ? 1 : 0)
            .animation(GQMotion.micro, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { HapticManager.shared.tap() }
            }
    }
}

extension View {
    func workoutFlowCard(
        accent: Color = GQColors.vividPurple,
        emphasized: Bool = false,
        cornerRadius: CGFloat = 16
    ) -> some View {
        modifier(
            WorkoutFlowCardModifier(
                accent: accent,
                emphasized: emphasized,
                cornerRadius: cornerRadius
            )
        )
    }

    func homeSocialCard(
        accent: Color? = nil,
        emphasized: Bool = false,
        cornerRadius: CGFloat = 16,
        subtle: Bool = false,
        sweepDelay: Double = 0
    ) -> some View {
        modifier(
            HomeSocialCardModifier(
                accent: accent,
                emphasized: emphasized,
                cornerRadius: cornerRadius,
                subtle: subtle,
                sweepDelay: sweepDelay
            )
        )
    }
}

struct WorkoutFlowMetricChip: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    var compact: Bool = false

    var body: some View {
        if compact {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(GQColors.textTertiary)
                Text(value)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(GQColors.textSecondary)
            }
        } else {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(color)

                VStack(alignment: .leading, spacing: 1) {
                    Text(value)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(GQColors.surfaceBase)
            )
            .overlay(
                Capsule()
                    .stroke(GQColors.borderDefault, lineWidth: 1)
            )
        }
    }
}

struct GQScreenTitleBlock: View {
    let title: String
    var subtitle: String? = nil
    var accent: Color = GQColors.vividPurple

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(GQColors.textPrimary)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundColor(GQColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .workoutFlowCard(accent: accent, cornerRadius: 18)
    }
}

// MARK: - Text Button Style (Minimal)

struct TextButtonStyle: ButtonStyle {
    let color: Color

    init(color: Color = GQColors.textPrimary) {
        self.color = color
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(color)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Universal Interactive Button Style

struct GQInteractiveStyle: ButtonStyle {
    var scaleAmount: CGFloat = 0.97
    var hapticStyle: HapticManager.HapticStyle = .light

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(GQMotion.press, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { HapticManager.shared.impact(hapticStyle) }
            }
    }
}

extension View {
    func gqInteractive(scale: CGFloat = 0.97, haptic: HapticManager.HapticStyle = .light) -> some View {
        self.buttonStyle(GQInteractiveStyle(scaleAmount: scale, hapticStyle: haptic))
    }
}

// MARK: - Unified Page Chrome

struct GQPageChromeModifier: ViewModifier {
    var tint: Color = GQColors.cyanSpark

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .toolbarBackground(.hidden, for: .navigationBar)
            // toolbarColorScheme follows system automatically
            .tint(tint)
    }
}

extension View {
    func gqPageChrome(tint: Color = GQColors.cyanSpark) -> some View {
        modifier(GQPageChromeModifier(tint: tint))
    }

    func gqPageBackground(tint: Color = GQColors.cyanSpark) -> some View {
        self
            .background { GQColors.background.ignoresSafeArea() }
            .modifier(GQPageChromeModifier(tint: tint))
    }

    func gqHomePageBackground(tint: Color = GQColors.cyanSpark) -> some View {
        self
            .background { GQColors.background.ignoresSafeArea() }
            .modifier(GQPageChromeModifier(tint: tint))
    }

    func gqScreenHorizontalPadding() -> some View {
        padding(.horizontal, GQLayout.screenHorizontal)
    }

    func gqPageScrollInsets(
        top: CGFloat = GQLayout.pageTop,
        bottom: CGFloat = GQLayout.pageBottom
    ) -> some View {
        padding(.top, top).padding(.bottom, bottom)
    }
}

// MARK: - Staggered Appear Modifier

struct StaggeredAppear: ViewModifier {
    let index: Int
    let stagger: Double
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .animation(
                .spring(response: 0.4, dampingFraction: 0.75).delay(Double(index) * stagger),
                value: appeared
            )
            .onAppear {
                appeared = true
            }
    }
}

extension View {
    func staggeredAppear(index: Int, stagger: Double = 0.06) -> some View {
        modifier(StaggeredAppear(index: index, stagger: stagger))
    }
}

// BreathingFloat — removed during premium simplification
// Legacy extension kept as no-op so call sites don't break
extension View {
    func breathingFloat(intensity: CGFloat = 1.0) -> some View {
        self // no-op
    }
}

// MARK: - Legacy Support - Shifting Gradient Background

struct ShiftingGradientBackground: View {
    var body: some View {
        EnergyBackground()
    }
}

// MARK: - Legacy Support - Animated Gradient Background

struct AnimatedGradientBackground: View {
    var body: some View {
        EnergyBackground()
    }
}

// MARK: - Legacy Support - Glowing Card

struct GlowingCard<Content: View>: View {
    @ViewBuilder let content: Content
    var glowColor: Color = GQColors.neonPurple
    var intensity: Double = 0.3

    var body: some View {
        GlassCard(accentColor: glowColor, showGlow: intensity > 0) {
            content
        }
    }
}

// MARK: - Legacy Support - Gradient Button Style

struct GradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PrimaryButtonStyle().makeBody(configuration: configuration)
    }
}

// MARK: - Legacy Support - Neon Button Style

struct NeonButtonStyle: ButtonStyle {
    var color: Color = GQColors.electricBlue

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(color.opacity(0.3))
                        .blur(radius: 8)

                    RoundedRectangle(cornerRadius: 24)
                        .fill(color.opacity(configuration.isPressed ? 0.8 : 0.6))

                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                }
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { HapticManager.shared.tap() }
            }
    }
}

// MARK: - Workout Type Badge

struct WorkoutTypeBadge: View {
    let type: WorkoutType
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            Circle()
                .fill(GQGradients.workoutGradient(for: type))
                .frame(width: size, height: size)
            Image(systemName: type.icon)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

struct WorkoutTypeBadgeFromString: View {
    let typeName: String
    var size: CGFloat = 40

    var body: some View {
        let workoutType = WorkoutType(rawValue: typeName) ?? .custom
        WorkoutTypeBadge(type: workoutType, size: size)
    }
}

// MARK: - Activity Badge

struct ActivityBadge: View {
    let activityType: DetectedActivity

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: activityType.icon)
                .font(.system(size: 10, weight: .bold))
            Text(activityType.rawValue)
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(activityType.gradient)
        )
        .shadow(color: activityType.color.opacity(0.5), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Detected Activity Types

enum DetectedActivity: String, CaseIterable {
    case weightlifting = "Weights"
    case running = "Running"
    case cycling = "Cycling"
    case swimming = "Swimming"
    case tennis = "Tennis"
    case basketball = "Basketball"
    case soccer = "Soccer"
    case yoga = "Yoga"
    case hiking = "Hiking"
    case boxing = "Boxing"
    case crossfit = "CrossFit"
    case general = "Workout"

    var icon: String {
        switch self {
        case .weightlifting: return "dumbbell.fill"
        case .running: return "figure.run"
        case .cycling: return "bicycle"
        case .swimming: return "figure.pool.swim"
        case .tennis: return "tennisball.fill"
        case .basketball: return "basketball.fill"
        case .soccer: return "soccerball"
        case .yoga: return "figure.yoga"
        case .hiking: return "figure.hiking"
        case .boxing: return "figure.boxing"
        case .crossfit: return "flame.fill"
        case .general: return "figure.mixed.cardio"
        }
    }

    var color: Color {
        switch self {
        case .weightlifting: return GQColors.vividPurple
        case .running: return GQColors.cyanSpark
        case .cycling: return GQColors.cyanSpark
        case .swimming: return GQColors.deepBlue
        case .tennis: return GQColors.success
        case .basketball: return GQColors.sunsetOrange
        case .soccer: return GQColors.success
        case .yoga: return GQColors.vividPurple
        case .hiking: return GQColors.success
        case .boxing: return GQColors.coralRed
        case .crossfit: return GQColors.coralRed
        case .general: return GQColors.cyanSpark
        }
    }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [color, color.opacity(0.7)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var keywords: [String] {
        switch self {
        case .weightlifting: return ["gym", "weights", "dumbbell", "barbell", "bench", "squat", "deadlift"]
        case .running: return ["run", "jog", "marathon", "track", "trail", "shoes"]
        case .cycling: return ["bike", "bicycle", "cycling", "peloton", "spin"]
        case .swimming: return ["pool", "swim", "lap", "water"]
        case .tennis: return ["tennis", "racket", "court", "serve"]
        case .basketball: return ["basketball", "hoop", "court", "dunk"]
        case .soccer: return ["soccer", "football", "goal", "pitch"]
        case .yoga: return ["yoga", "mat", "stretch", "pose", "meditation"]
        case .hiking: return ["hike", "trail", "mountain", "nature", "outdoor"]
        case .boxing: return ["boxing", "gloves", "punch", "bag", "ring"]
        case .crossfit: return ["crossfit", "wod", "box", "amrap", "burpee"]
        case .general: return []
        }
    }
}

// MARK: - Cardio Sub-Types

enum CardioSubType: String, CaseIterable {
    case outdoorRun = "Outdoor Run"
    case treadmill = "Treadmill"
    case cycling = "Cycling"
    case rowing = "Rowing"
    case swimming = "Swimming"
    case hiking = "Hiking"
    case stairClimber = "Stair Climber"
    case elliptical = "Elliptical"
    case jumpRope = "Jump Rope"

    var icon: String {
        switch self {
        case .outdoorRun: return "figure.run"
        case .treadmill: return "figure.run.treadmill"
        case .cycling: return "bicycle"
        case .rowing: return "figure.rower"
        case .swimming: return "figure.pool.swim"
        case .hiking: return "figure.hiking"
        case .stairClimber: return "figure.stair.stepper"
        case .elliptical: return "figure.elliptical"
        case .jumpRope: return "figure.jumprope"
        }
    }

    var machineLabel: String? {
        switch self {
        case .treadmill: return "Treadmill"
        case .stairClimber: return "Stair Climber"
        case .elliptical: return "Elliptical"
        case .rowing: return "Rowing Machine"
        default: return nil
        }
    }

    var isOutdoor: Bool {
        switch self {
        case .outdoorRun, .cycling, .hiking, .swimming: return true
        default: return false
        }
    }

    var color: Color {
        switch self {
        case .outdoorRun: return GQColors.success
        case .treadmill: return GQColors.cyanSpark
        case .cycling: return Color(hex: "FF9500")
        case .rowing: return GQColors.deepBlue
        case .swimming: return GQColors.cyanSpark
        case .hiking: return GQColors.success
        case .stairClimber: return GQColors.vividPurple
        case .elliptical: return GQColors.coralRed
        case .jumpRope: return GQColors.warning
        }
    }

    static func from(_ highlight: String?) -> CardioSubType? {
        guard let highlight else { return nil }
        return CardioSubType.allCases.first { $0.rawValue.lowercased() == highlight.lowercased() }
    }
}

// MARK: - Music EQ Bars Component

struct MusicEQBars: View {
    var barCount: Int = 3
    var barWidth: CGFloat = 3
    var maxHeight: CGFloat = 16
    var color: Color = GQColors.vividPurple
    var isPlaying: Bool = true

    @State private var animating = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(
                        width: barWidth,
                        height: isPlaying ? (animating ? CGFloat.random(in: maxHeight * 0.4...maxHeight) : CGFloat.random(in: maxHeight * 0.25...maxHeight * 0.75)) : maxHeight * 0.35
                    )
                    .animation(
                        isPlaying ? .easeInOut(duration: 0.35).repeatForever().delay(Double(i) * 0.1) : .default,
                        value: animating
                    )
            }
        }
        .onAppear {
            if isPlaying { animating = true }
        }
        .onDisappear {
            animating = false
        }
        .onChange(of: isPlaying) { _, playing in
            animating = playing
        }
    }
}

// MARK: - Music Photo Overlay

struct MusicPhotoOverlay: View {
    let songTitle: String
    let artistName: String
    var musicSource: String? = nil

    @State private var vinylRotation: Double = 0
    @State private var isVisible = false

    private var isSpotify: Bool { musicSource == "Spotify" }
    private var serviceColor: Color { isSpotify ? Color(hex: "1DB954") : Color(hex: "FC3C44") }

    var body: some View {
        HStack(spacing: 10) {
            // Spinning vinyl
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 32, height: 32)
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    .frame(width: 32, height: 32)
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [Color.white.opacity(0.1), Color.white.opacity(0.05), Color.white.opacity(0.1)],
                            center: .center
                        )
                    )
                    .frame(width: 30, height: 30)
                Circle()
                    .fill(serviceColor)
                    .frame(width: 10, height: 10)
            }
            .rotationEffect(.degrees(vinylRotation))

            VStack(alignment: .leading, spacing: 2) {
                Text(songTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(artistName)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }

            Spacer()

            MusicEQBars(barCount: 3, barWidth: 2.5, maxHeight: 14, color: serviceColor, isPlaying: true)

            if musicSource != nil {
                if isSpotify {
                    SpotifyIcon(size: 16)
                } else {
                    AppleMusicIcon(size: 16)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
        .onAppear {
            isVisible = true
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                vinylRotation = 360
            }
        }
        .onDisappear {
            isVisible = false
            vinylRotation = 0
        }
    }
}

// MARK: - Music Service Icons

struct SpotifyIcon: View {
    var size: CGFloat = 20

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "1DB954"))
                .frame(width: size, height: size)

            // Three curved bars of decreasing width
            VStack(spacing: size * 0.06) {
                ForEach(0..<3, id: \.self) { i in
                    let barWidth = size * (0.55 - CGFloat(i) * 0.12)
                    RoundedRectangle(cornerRadius: size * 0.04)
                        .fill(.white)
                        .frame(width: barWidth, height: size * 0.1)
                        .offset(x: -CGFloat(i) * size * 0.03)
                }
            }
        }
    }
}

struct AppleMusicIcon: View {
    var size: CGFloat = 20

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "FC3C44"), Color(hex: "FA233B")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size, height: size)

            Image(systemName: "music.note")
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Music Display Component

struct MusicBadge: View {
    let songTitle: String
    let artistName: String
    let isPlaying: Bool
    var musicSource: String? = nil
    let onTap: () -> Void

    @State private var animateBars = false

    private var isSpotify: Bool { musicSource == "Spotify" }
    private var serviceColor: Color { isSpotify ? Color(hex: "1DB954") : Color(hex: "FC3C44") }
    private var serviceLabel: String { isSpotify ? "Spotify" : "Apple Music" }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // Animated bars
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(GQColors.vividPurple)
                            .frame(width: 3, height: isPlaying ? (animateBars ? CGFloat.random(in: 8...16) : CGFloat.random(in: 4...12)) : 6)
                            .animation(
                                isPlaying ? .easeInOut(duration: 0.3).repeatForever().delay(Double(i) * 0.1) : .default,
                                value: animateBars
                            )
                    }
                }
                .frame(width: 14, height: 16)

                VStack(alignment: .leading, spacing: 1) {
                    Text(songTitle)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                        .lineLimit(1)

                    Text(artistName)
                        .font(.system(size: 9))
                        .foregroundColor(GQColors.textSecondary)
                        .lineLimit(1)
                }

                // Service indicator
                if musicSource != nil {
                    HStack(spacing: 3) {
                        if isSpotify {
                            SpotifyIcon(size: 14)
                        } else {
                            AppleMusicIcon(size: 14)
                        }
                        Text(serviceLabel)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(serviceColor)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(serviceColor.opacity(0.15)))
                }

                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 10))
                    .foregroundColor(GQColors.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.5))
                    )
            )
            .overlay(
                Capsule()
                    .strokeBorder(GQGradients.glassBorder, lineWidth: 0.85)
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            if isPlaying {
                animateBars = true
            }
        }
        .onDisappear {
            animateBars = false
        }
    }
}

// MARK: - Post Delete Button

struct PostDeleteButton: View {
    let onDelete: () -> Void
    @State private var showConfirmation = false

    var body: some View {
        Button {
            showConfirmation = true
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 16))
                .foregroundColor(GQColors.textTertiary)
        }
        .confirmationDialog("Delete Post", isPresented: $showConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }
}

// MARK: - Shimmer Effect

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.1),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: -geo.size.width + phase * geo.size.width * 2)
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
            .onDisappear {
                phase = 0
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }
}

// MARK: - Interactive Post Card Wrapper

struct InteractivePostCard<Content: View>: View {
    @ViewBuilder let content: Content
    @State private var isPressed = false

    var body: some View {
        content
            .background(GQColors.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .fill(
                        LinearGradient(
                            colors: [GQColors.vividPurple.opacity(0.05), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .scaleEffect(isPressed ? 0.99 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
            .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
                isPressed = pressing
            }, perform: {})
    }
}

// MARK: - Legacy Support - Animated Gradient View

struct AnimatedGradientView: View {
    var body: some View {
        EnergyBackground()
    }
}

// MARK: - Heart Burst Overlay

struct HeartBurstOverlay: View {
    let isActive: Bool

    private struct HeartParticle: Identifiable {
        let id = UUID()
        let angle: Double
        let distance: CGFloat
        let scale: CGFloat
    }

    @State private var particles: [HeartParticle] = []
    @State private var animateOut = false

    private func spawnParticles() {
        particles = (0..<5).map { i in
            let baseAngle = -90.0 + Double(i) * 40.0 - 80.0
            let jitter = Double.random(in: -15...15)
            return HeartParticle(
                angle: baseAngle + jitter,
                distance: CGFloat.random(in: 20...35),
                scale: CGFloat.random(in: 0.4...0.7)
            )
        }
        withAnimation(.easeOut(duration: 0.5)) {
            animateOut = true
        }
    }

    var body: some View {
        ZStack {
            ForEach(particles) { p in
                let rad = p.angle * .pi / 180
                let dx = animateOut ? cos(rad) * p.distance : 0
                let dy = animateOut ? sin(rad) * p.distance : 0

                Image(systemName: "heart.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.red)
                    .scaleEffect(animateOut ? p.scale * 0.3 : p.scale)
                    .opacity(animateOut ? 0 : 1)
                    .offset(x: dx, y: dy)
            }
        }
        .onAppear {
            if isActive {
                spawnParticles()
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        EnergyBackground()

        ScrollView {
            VStack(spacing: 20) {
                NavBarLogo()

                HeroCard {
                    VStack(spacing: 12) {
                        GradientText("Level Up!", font: GQTypography.heroTitle)
                        Text("You're crushing it today")
                            .foregroundColor(GQColors.textSecondary)
                    }
                    .padding(24)
                }
                .padding(.horizontal)

                GlassCard {
                    VStack(spacing: 12) {
                        Text("Glass Card")
                            .font(GQTypography.cardTitle)
                        Text("With glass morphism effect")
                            .foregroundColor(GQColors.textSecondary)
                    }
                    .padding(20)
                }
                .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        StatPill(icon: "flame.fill", value: "5", label: "Streak", color: GQColors.success)
                        StatPill(icon: "dumbbell.fill", value: "42", label: "Sets", color: GQColors.vividPurple)
                        StatPill(icon: "bolt.fill", value: "2,450", label: "XP", color: GQColors.electricGold)
                    }
                    .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Progress")
                        .font(GQTypography.sectionHeader)
                        .foregroundColor(GQColors.textTertiary)
                    AnimatedProgressBar(progress: 0.7)
                }
                .padding(.horizontal)

                Button("Start Workout") {}
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 32)

                Button("Secondary Action") {}
                    .buttonStyle(SecondaryButtonStyle())
                    .padding(.horizontal, 32)

                HStack {
                    ActivityBadge(activityType: .tennis)
                    ActivityBadge(activityType: .weightlifting)
                    ActivityBadge(activityType: .running)
                }

                MusicBadge(
                    songTitle: "Eye of the Tiger",
                    artistName: "Survivor",
                    isPlaying: true,
                    onTap: {}
                )
            }
            .padding()
        }
    }
}
