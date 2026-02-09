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

    // Backgrounds - pure dark
    static let deepBlack = Color(hex: "000000")
    static let background = Color(hex: "0A0A0A")
    static let darkSurface = Color(hex: "111111")
    static let cardBackground = Color(hex: "191919")
    static let elevatedSurface = Color(hex: "222222")

    // Text
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.72)
    static let textTertiary = Color.white.opacity(0.50)

    // Semantic colors - bright and vibrant
    static let success = Color(hex: "1ED760")
    static let warning = Color(hex: "FFD600")  // Electric yellow
    static let error = Color(hex: "FF5252")    // Hot coral
    static let prGold = Color(hex: "FFD700")

    // Accent
    static let accent = deepBlue
    static let accentLight = cyanSpark

    // Surface tokens - standardized surface colors
    static let surfaceBase = Color(hex: "1C1C1C")
    static let surfaceElevated = Color(hex: "262626")
    static let surfaceOverlay = Color(hex: "2F2F2F")
    static let borderSubtle = Color.white.opacity(0.06)
    static let borderDefault = Color.white.opacity(0.11)
    static let borderProminent = Color.white.opacity(0.16)
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
    static let pageBottom: CGFloat = 120
    static let cardHorizontal: CGFloat = 14
    static let cardVertical: CGFloat = 13
}

struct GQMotion {
    static let press = Animation.spring(response: 0.22, dampingFraction: 0.72)
    static let micro = Animation.spring(response: 0.2, dampingFraction: 0.75)
    static let standard = Animation.easeOut(duration: 0.25)
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
        colors: [Color.white.opacity(0.18), Color.white.opacity(0.05), Color.black.opacity(0.20)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Glass card border
    static let glassBorder = LinearGradient(
        colors: [Color.white.opacity(0.14), Color.white.opacity(0.04), Color.black.opacity(0.16)],
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
        colors: [Color.white.opacity(0.10), Color.white.opacity(0.03), Color.black.opacity(0.12)],
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
        switch type {
        case .push: return GQColors.deepBlue
        case .pull: return GQColors.vividPurple
        case .legs: return GQColors.cyanSpark
        case .upper: return GQColors.vividPurple
        case .lower: return GQColors.deepBlue
        case .fullBody: return GQColors.cyanSpark
        case .cardio: return GQColors.success
        case .rest: return Color.white.opacity(0.12)
        }
    }

    /// Returns raw color array for a workout type — useful for theming rings, progress bars, checkmarks, etc.
    static func workoutGradientColors(for type: WorkoutType) -> [Color] {
        switch type {
        case .push: return [GQColors.deepBlue, GQColors.cyanSpark]
        case .pull: return [GQColors.vividPurple, GQColors.deepBlue]
        case .legs: return [GQColors.cyanSpark, GQColors.vividPurple]
        case .upper: return [GQColors.vividPurple, GQColors.cyanSpark]
        case .lower: return [GQColors.deepBlue, GQColors.vividPurple]
        case .fullBody: return [GQColors.cyanSpark, GQColors.deepBlue]
        case .cardio: return [GQColors.success, GQColors.cyanSpark]
        case .rest: return [Color.white.opacity(0.15), Color.white.opacity(0.08)]
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
        HomeEnergyBackground()
    }
}

// MARK: - Home Background (Cleaner blue -> pink vibe)

struct HomeEnergyBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "020307"), Color(hex: "04050A"), Color(hex: "06070D")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(hex: "7AA8FF").opacity(0.09),
                    Color(hex: "7AA8FF").opacity(0.03),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 20,
                endRadius: 520
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(hex: "FF74C7").opacity(0.08),
                    Color(hex: "FF74C7").opacity(0.025),
                    Color.clear
                ],
                center: .bottomTrailing,
                startRadius: 10,
                endRadius: 500
            )
            .ignoresSafeArea()

            AuroraFlowBackground()
                .opacity(0.86)
                .blendMode(.screen)
                .ignoresSafeArea()

            RadialGradient(
                colors: [Color.clear, Color.black.opacity(0.20), Color.black.opacity(0.36)],
                center: .center,
                startRadius: 130,
                endRadius: 760
            )
            .blendMode(.multiply)
            .ignoresSafeArea()

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.11), Color.black.opacity(0.30)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}

private struct AuroraFlowBackground: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate

                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: 70))
                    drawRibbon(
                        in: &layer,
                        size: size,
                        time: time * 0.16,
                        baseY: size.height * 0.26,
                        amplitude: size.height * 0.085,
                        frequency: 1.38,
                        lineWidth: max(size.width * 0.22, 128),
                        colors: [
                            Color(hex: "58A8FF").opacity(0.20),
                            Color(hex: "4DD6FF").opacity(0.15),
                            Color(hex: "FF70CA").opacity(0.18)
                        ]
                    )
                    drawRibbon(
                        in: &layer,
                        size: size,
                        time: time * 0.13 + 1.1,
                        baseY: size.height * 0.48,
                        amplitude: size.height * 0.078,
                        frequency: 1.20,
                        lineWidth: max(size.width * 0.20, 116),
                        colors: [
                            Color(hex: "45B9FF").opacity(0.16),
                            Color(hex: "8AA3FF").opacity(0.14),
                            Color(hex: "FF7EBF").opacity(0.16)
                        ]
                    )
                    drawRibbon(
                        in: &layer,
                        size: size,
                        time: time * 0.10 + 2.2,
                        baseY: size.height * 0.76,
                        amplitude: size.height * 0.070,
                        frequency: 1.04,
                        lineWidth: max(size.width * 0.18, 102),
                        colors: [
                            Color(hex: "63A6FF").opacity(0.12),
                            Color(hex: "FF78CC").opacity(0.13),
                            Color(hex: "55C8FF").opacity(0.11)
                        ]
                    )
                }

                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: 96))
                    drawOrb(
                        in: &layer,
                        center: CGPoint(
                            x: size.width * (0.22 + (0.04 * sin(time * 0.045))),
                            y: size.height * (0.24 + (0.03 * cos(time * 0.055)))
                        ),
                        size: CGSize(width: size.width * 0.76, height: size.height * 0.44),
                        colors: [
                            Color(hex: "53A7FF").opacity(0.14),
                            Color(hex: "53A7FF").opacity(0.06),
                            Color.clear
                        ]
                    )
                    drawOrb(
                        in: &layer,
                        center: CGPoint(
                            x: size.width * (0.78 + (0.04 * cos(time * 0.040))),
                            y: size.height * (0.68 + (0.025 * sin(time * 0.052)))
                        ),
                        size: CGSize(width: size.width * 0.70, height: size.height * 0.40),
                        colors: [
                            Color(hex: "FF79C9").opacity(0.12),
                            Color(hex: "FF79C9").opacity(0.05),
                            Color.clear
                        ]
                    )
                    drawOrb(
                        in: &layer,
                        center: CGPoint(
                            x: size.width * (0.52 + (0.03 * sin(time * 0.038 + 1.5))),
                            y: size.height * (0.46 + (0.02 * cos(time * 0.050 + 0.7)))
                        ),
                        size: CGSize(width: size.width * 0.82, height: size.height * 0.52),
                        colors: [
                            Color.white.opacity(0.05),
                            Color(hex: "6FAEFF").opacity(0.04),
                            Color.clear
                        ]
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func drawRibbon(
        in context: inout GraphicsContext,
        size: CGSize,
        time: Double,
        baseY: CGFloat,
        amplitude: CGFloat,
        frequency: Double,
        lineWidth: CGFloat,
        colors: [Color]
    ) {
        let startX = -size.width * 0.16
        let endX = size.width * 1.16
        let points = 14
        var path = Path()

        for step in 0...points {
            let progress = Double(step) / Double(points)
            let x = startX + CGFloat(progress) * (endX - startX)
            let waveA = sin((progress * frequency * .pi * 2) + time)
            let waveB = sin((progress * (frequency * 0.62) * .pi * 2) - (time * 0.72))
            let y = baseY + (CGFloat(waveA) * amplitude * 0.72) + (CGFloat(waveB) * amplitude * 0.28)

            if step == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        context.stroke(
            path,
            with: .linearGradient(
                Gradient(colors: colors),
                startPoint: CGPoint(x: startX, y: baseY - amplitude),
                endPoint: CGPoint(x: endX, y: baseY + amplitude)
            ),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        )
    }

    private func drawOrb(
        in context: inout GraphicsContext,
        center: CGPoint,
        size: CGSize,
        colors: [Color]
    ) {
        let rect = CGRect(
            x: center.x - (size.width * 0.5),
            y: center.y - (size.height * 0.5),
            width: size.width,
            height: size.height
        )
        context.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(colors: colors),
                center: center,
                startRadius: 0,
                endRadius: max(size.width, size.height) * 0.55
            )
        )
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
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(GQColors.surfaceBase)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.10), Color.white.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.22), radius: 8, y: 3)
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
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.10), Color.white.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .animatedGradientBorder(
                        cornerRadius: 18,
                        lineWidth: 1.5,
                        colors: [GQColors.vividPurple, GQColors.cyanSpark, GQColors.vividPurple],
                        duration: 4.0
                    )
            )
            .shadow(color: .black.opacity(0.24), radius: 10, y: 4)
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
                .stroke(GQGradients.glassBorder, lineWidth: 0.85)
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
                .fill(GQColors.surfaceElevated)
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
                RoundedRectangle(cornerRadius: 16)
                    .fill(GQColors.surfaceBase)
            )
            .overlay {
                if configuration.isPressed {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .animatedGradientBorder(
                            cornerRadius: 16,
                            lineWidth: 1.6,
                            colors: [GQColors.vividPurple, GQColors.cyanSpark, GQColors.vividPurple],
                            duration: 4.0
                        )
                }
            }
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.16 : 0.26), radius: configuration.isPressed ? 4 : 8, y: configuration.isPressed ? 2 : 4)
            .scaleEffect(configuration.isPressed ? 0.972 : 1.0)
            .offset(y: configuration.isPressed ? 1.5 : 0)
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
            .foregroundColor(.white)
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
                            colors: [Color.white.opacity(configuration.isPressed ? 0.08 : 0.10), Color.white.opacity(configuration.isPressed ? 0.03 : 0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.14 : 0.22), radius: configuration.isPressed ? 3 : 7, y: configuration.isPressed ? 1 : 3)
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
                    .fill(GQColors.surfaceBase)
            )
            .overlay {
                if configuration.isPressed {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .animatedGradientBorder(
                            cornerRadius: cornerRadius,
                            lineWidth: 1.6,
                            colors: [accent, GQColors.cyanSpark, accent],
                            duration: 4.0
                        )
                }
            }
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.16 : 0.26), radius: configuration.isPressed ? 4 : 8, y: configuration.isPressed ? 2 : 4)
            .scaleEffect(configuration.isPressed ? 0.972 : 1.0)
            .offset(y: configuration.isPressed ? 1.5 : 0)
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
            .foregroundColor(.white)
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
                            colors: [Color.white.opacity(configuration.isPressed ? 0.08 : 0.10), Color.white.opacity(configuration.isPressed ? 0.03 : 0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.14 : 0.22), radius: configuration.isPressed ? 3 : 7, y: configuration.isPressed ? 1 : 3)
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
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(GQColors.surfaceBase)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.10), Color.white.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .overlay {
                if emphasized {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .animatedGradientBorder(
                            cornerRadius: cornerRadius,
                            lineWidth: 1.6,
                            colors: [accent, GQColors.cyanSpark, accent],
                            duration: 4.0
                        )
                }
            }
            .shadow(color: Color.black.opacity(emphasized ? 0.22 : 0.18), radius: emphasized ? 8 : 6, y: emphasized ? 3 : 2)
    }
}

// MARK: - Home/Social Surface Styles

struct HomeSocialCardModifier: ViewModifier {
    var accent: Color?
    var emphasized: Bool
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(GQColors.surfaceBase)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.10), Color.white.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .overlay {
                if emphasized, let accent {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .animatedGradientBorder(
                            cornerRadius: cornerRadius,
                            lineWidth: 1.6,
                            colors: [accent, GQColors.cyanSpark, accent],
                            duration: 4.0
                        )
                }
            }
            .shadow(color: Color.black.opacity(emphasized ? 0.22 : 0.18), radius: emphasized ? 8 : 6, y: emphasized ? 3 : 2)
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
                    .fill(GQColors.surfaceBase)
            )
            .overlay {
                if configuration.isPressed {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .animatedGradientBorder(
                            cornerRadius: cornerRadius,
                            lineWidth: 1.6,
                            colors: [accent, GQColors.cyanSpark, accent],
                            duration: 4.0
                        )
                }
            }
            .scaleEffect(configuration.isPressed ? 0.975 : 1.0)
            .offset(y: configuration.isPressed ? 1 : 0)
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
            .foregroundColor(.white)
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
                            colors: [Color.white.opacity(configuration.isPressed ? 0.08 : 0.10), Color.white.opacity(configuration.isPressed ? 0.03 : 0.05)],
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
        cornerRadius: CGFloat = 16
    ) -> some View {
        modifier(
            HomeSocialCardModifier(
                accent: accent,
                emphasized: emphasized,
                cornerRadius: cornerRadius
            )
        )
    }
}

struct WorkoutFlowMetricChip: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
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

struct GQScreenTitleBlock: View {
    let title: String
    var subtitle: String? = nil
    var accent: Color = GQColors.vividPurple

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.white)

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
            .toolbarColorScheme(.dark, for: .navigationBar)
            .tint(tint)
    }
}

extension View {
    func gqPageChrome(tint: Color = GQColors.cyanSpark) -> some View {
        modifier(GQPageChromeModifier(tint: tint))
    }

    func gqPageBackground(tint: Color = GQColors.cyanSpark) -> some View {
        self
            .background(HomeEnergyBackground())
            .modifier(GQPageChromeModifier(tint: tint))
    }

    func gqHomePageBackground(tint: Color = GQColors.cyanSpark) -> some View {
        self
            .background(HomeEnergyBackground())
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

// MARK: - Breathing Float Modifier

struct BreathingFloat: ViewModifier {
    let intensity: CGFloat
    @State private var offsetY: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(y: offsetY)
            .onAppear {
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                    offsetY = -intensity * 4
                }
            }
    }
}

extension View {
    func breathingFloat(intensity: CGFloat = 1.0) -> some View {
        modifier(BreathingFloat(intensity: intensity))
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
                    .strokeBorder(GQGradients.glassBorder, lineWidth: 0.85)
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
