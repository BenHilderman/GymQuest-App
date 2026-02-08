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
        lightGenerator.impactOccurred()
        #endif
    }

    func select() {
        #if canImport(UIKit)
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
        #endif
    }

    func impact(_ style: HapticStyle = .medium) {
        #if canImport(UIKit)
        switch style {
        case .light: lightGenerator.impactOccurred()
        case .medium: mediumGenerator.impactOccurred()
        case .heavy: heavyGenerator.impactOccurred()
        }
        #endif
    }

    func setComplete(setNumber: Int, totalSets: Int) {
        #if canImport(UIKit)
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
        notificationGenerator.notificationOccurred(.success)
        #endif
    }

    func error() {
        #if canImport(UIKit)
        notificationGenerator.notificationOccurred(.error)
        #endif
    }

    enum HapticStyle {
        case light, medium, heavy
    }
}

// MARK: - Confetti View

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var isAnimating = false

    let colors: [Color] = [
        GQColors.vividPurple, GQColors.cyanSpark, GQColors.success,
        GQColors.electricGold, GQColors.coralRed, GQColors.sunsetOrange
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

struct GQColors {
    // Energy color cycle - bold, vibrant colors that flow
    static let coralRed = Color(hex: "FF6B6B")      // Coral Red
    static let sunsetOrange = Color(hex: "FF8E53")  // Sunset Orange
    static let electricGold = Color(hex: "FFC107") // Electric Gold
    static let vividPurple = Color(hex: "C850C0")  // Vivid Purple
    static let deepBlue = Color(hex: "4158D0")     // Deep Blue
    static let cyanSpark = Color(hex: "00D9FF")    // Cyan Spark

    // Primary accent
    static let primary = vividPurple
    static let secondary = cyanSpark

    // Legacy aliases (use canonical names above instead)
    static let coral = coralRed
    static let peach = sunsetOrange
    static let gold = electricGold
    static let rose = vividPurple
    static let terracotta = Color(hex: "E07855")
    static let sand = Color(hex: "EBD2A6")
    static let electricBlue = cyanSpark
    static let neonPurple = vividPurple
    static let cyberCyan = cyanSpark
    static let hotPink = coralRed
    static let lavender = vividPurple
    static let sky = cyanSpark
    static let mint = Color(hex: "00E676")
    static let butter = electricGold

    // Backgrounds - pure dark
    static let deepBlack = Color(hex: "000000")
    static let background = Color(white: 0.05)      // Standard app background
    static let darkSurface = Color(hex: "0A0A0A")
    static let cardBackground = Color(hex: "121212")
    static let elevatedSurface = Color(hex: "1A1A1A")

    // Text
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.65)
    static let textTertiary = Color.white.opacity(0.4)

    // Semantic colors - bright and vibrant
    static let success = Color(hex: "00E676")  // Bright green
    static let warning = Color(hex: "FFD600")  // Electric yellow
    static let error = Color(hex: "FF5252")    // Hot coral
    static let prGold = Color(hex: "FFD700")

    // Accent
    static let accent = vividPurple
    static let accentLight = cyanSpark
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

// MARK: - Gradients (Apple-clean minimal style)

struct GQGradients {
    // Accent color for consistency
    static let accentColor = GQColors.accent

    // Energy colors - simplified for subtle use
    static let energyColors: [Color] = [
        GQColors.accent,
        GQColors.accent.opacity(0.8)
    ]

    // Primary gradient - purple to cyan
    static let primary = LinearGradient(
        colors: [GQColors.vividPurple, GQColors.cyanSpark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Energy gradient - purple based
    static let energy = LinearGradient(
        colors: [GQColors.vividPurple, GQColors.vividPurple.opacity(0.8)],
        startPoint: .leading,
        endPoint: .trailing
    )

    // Achievement/PR gradient - cyan
    static let achievement = LinearGradient(
        colors: [GQColors.cyanSpark, GQColors.cyanSpark.opacity(0.85)],
        startPoint: .leading,
        endPoint: .trailing
    )

    // Success gradient - clean green
    static let success = LinearGradient(
        colors: [GQColors.success, GQColors.success.opacity(0.85)],
        startPoint: .leading,
        endPoint: .trailing
    )

    // Hero card border - subtle white
    static let heroBorder = LinearGradient(
        colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Glass card subtle border
    static let glassBorder = LinearGradient(
        colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Animated gradient colors for legacy support
    static let animatedColors: [Color] = energyColors

    // Card glow - very subtle
    static let cardGlow = LinearGradient(
        colors: [Color.white.opacity(0.02), Color.clear],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Card border
    static let cardBorder = LinearGradient(
        colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Warm gradient (legacy)
    static let warm = LinearGradient(
        colors: [GQColors.sunsetOrange, GQColors.sunsetOrange.opacity(0.85)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Workout Type Gradients

    /// Returns a vibrant gradient for completed workout tiles based on workout type
    static func workoutGradient(for type: WorkoutType) -> LinearGradient {
        switch type {
        case .push:
            // Purple to Cyan - primary app gradient
            return LinearGradient(
                colors: [GQColors.vividPurple, GQColors.cyanSpark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .pull:
            // Cyan to Deep Blue
            return LinearGradient(
                colors: [GQColors.cyanSpark, GQColors.deepBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .legs:
            // Orange to Gold - warm energy
            return LinearGradient(
                colors: [GQColors.sunsetOrange, GQColors.electricGold],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .upper:
            // Purple to Deep Blue
            return LinearGradient(
                colors: [GQColors.vividPurple, GQColors.deepBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .lower:
            // Sunset Orange to Coral Red
            return LinearGradient(
                colors: [GQColors.sunsetOrange, GQColors.coralRed],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .fullBody:
            // Success Green to Cyan
            return LinearGradient(
                colors: [GQColors.success, GQColors.cyanSpark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .cardio:
            // Success green gradient
            return LinearGradient(
                colors: [GQColors.success, GQColors.success.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .rest:
            // Subtle gray/white gradient for rest days
            return LinearGradient(
                colors: [Color.white.opacity(0.15), Color.white.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
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
        colors: [Color] = [GQColors.vividPurple, GQColors.cyanSpark, GQColors.vividPurple],
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
    static let cardTitle = Font.system(size: 20, weight: .semibold)
    static let sectionHeader = Font.system(size: 12, weight: .bold)
    static let body = Font.system(size: 16, weight: .regular)
    static let caption = Font.system(size: 13, weight: .medium)
    static let stat = Font.system(size: 28, weight: .bold, design: .rounded)
    static let statLabel = Font.system(size: 11, weight: .medium)
}

// MARK: - Energy Background (Animated Gradient Orbs)

struct EnergyBackground: View {
    var body: some View {
        Color(white: 0.05) // Near-black dark grey
            .ignoresSafeArea()
    }
}

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
                ZStack {
                    // Deep shadow for 3D lift
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.black)
                        .shadow(color: .black.opacity(0.7), radius: 16, y: 8)

                    // Main 3D gradient fill
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.15), Color(white: 0.07)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    // Top highlight for curved 3D look
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.06), Color.clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.25), Color.white.opacity(0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - Hero Card (With depth)

struct HeroCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .background(
                ZStack {
                    // Deep shadow
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.black)
                        .shadow(color: .black.opacity(0.6), radius: 16, y: 8)

                    // Card fill with gradient
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.14), Color(white: 0.08)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.25), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
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
                    .foregroundColor(.white)
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
                    .environment(\.colorScheme, .dark)

                // Subtle color tint from the icon color
                Capsule()
                    .fill(color.opacity(0.08))

                // Top highlight for glass reflection
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.15), Color.white.opacity(0.02), Color.clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            }
        )
        .overlay(
            // Glass border with gradient shine
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.05),
                            Color.white.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
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
                    .fill(Color.white.opacity(0.08))

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
            // Gradient border circle
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [GQColors.vividPurple, GQColors.cyanSpark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: 34, height: 34)

            // Background
            Circle()
                .fill(Color(white: 0.1))
                .frame(width: 32, height: 32)

            // Icon
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 14, weight: .semibold))
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
                ZStack {
                    // Shadow that lifts on press
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.black.opacity(0.3))
                        .blur(radius: configuration.isPressed ? 2 : 6)
                        .offset(y: configuration.isPressed ? 1 : 4)

                    // Main button with gradient
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [GQColors.accent, GQColors.accent.opacity(0.85)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    // Top highlight
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(configuration.isPressed ? 0.05 : 0.15), Color.clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .offset(y: configuration.isPressed ? 2 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
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
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(white: configuration.isPressed ? 0.08 : 0.12))

                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(configuration.isPressed ? 0.1 : 0.15), lineWidth: 1)
                }
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { HapticManager.shared.tap() }
            }
    }
}

// MARK: - Text Button Style (Minimal)

struct TextButtonStyle: ButtonStyle {
    let color: Color

    init(color: Color = .white) {
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

// MARK: - Music Display Component

struct MusicBadge: View {
    let songTitle: String
    let artistName: String
    let isPlaying: Bool
    let onTap: () -> Void

    @State private var animateBars = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(GQGradients.primary)
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
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(artistName)
                        .font(.system(size: 9))
                        .foregroundColor(GQColors.textSecondary)
                        .lineLimit(1)
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
                    .strokeBorder(GQGradients.glassBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            if isPlaying {
                animateBars = true
            }
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
    .preferredColorScheme(.dark)
}
