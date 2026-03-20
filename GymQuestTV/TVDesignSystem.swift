import SwiftUI

#if os(tvOS)

// MARK: - TV Layout Constants (1920x1080, 10-foot viewing)

enum TVLayout {
    // Safe areas & insets
    static let safeAreaInset: CGFloat = 60
    static let edgeInsets: CGFloat = 80
    static let horizontalInset: CGFloat = 80
    static let topInset: CGFloat = 40
    static let bottomSafeArea: CGFloat = 60
    static let pagePadding: CGFloat = 60

    // Card sizes
    static let cardWidth: CGFloat = 400
    static let cardHeight: CGFloat = 300
    static let heroCardWidth: CGFloat = 800
    static let heroCardHeight: CGFloat = 450
    static let activityCardWidth: CGFloat = 480
    static let cardInset: CGFloat = 40

    // Spacing
    static let spacingSmall: CGFloat = 8
    static let spacingMedium: CGFloat = 16
    static let spacingLarge: CGFloat = 24
    static let gridSpacing: CGFloat = 48
    static let sectionSpacing: CGFloat = 60
    static let cardSpacing: CGFloat = 40
    static let chipSpacing: CGFloat = 10
    static let rowHeaderSpacing: CGFloat = 16
    static let rowPadding: CGFloat = 20

    // Corners & Focus
    static let cornerRadius: CGFloat = 20
    static let cardCornerRadius: CGFloat = 20
    static let heroCornerRadius: CGFloat = 24
    static let focusScale: CGFloat = 1.05
    static let focusPadding: CGFloat = 20

    // Feed-specific
    static let heroHeight: CGFloat = 520
    static let heroContentPadding: CGFloat = 48
    static let cardImageHeight: CGFloat = 180
    static let cardContentPadding: CGFloat = 16
    static let prHeaderHeight: CGFloat = 120
    static let activityImageHeight: CGFloat = 140
    static let avatarSize: CGFloat = 36
    static let avatarFontSize: CGFloat = 15
    static let detailPadding: CGFloat = 80

    // Colors
    static let offWhite = Color(white: 0.93)
}

// MARK: - TV Typography (scaled for 10-foot viewing)

enum TVTypography {
    // Hero sizes
    static let heroNumber = Font.system(size: 96, weight: .bold, design: .rounded)
    static let heroMetric = Font.system(size: 120, weight: .bold, design: .rounded)
    static let heroTitle = Font.system(size: 42, weight: .bold)

    // Section & card
    static let sectionTitle = Font.system(size: 36, weight: .bold, design: .rounded)
    static let cardTitle = Font.system(size: 28, weight: .semibold)
    static let cardBody = Font.system(size: 22, weight: .regular)

    // Body & caption
    static let body = Font.system(size: 29, weight: .regular)
    static let caption = Font.system(size: 20, weight: .medium)
    static let micro = Font.system(size: 16, weight: .medium)

    // Stats
    static let stat = Font.system(size: 48, weight: .bold, design: .rounded)
    static let statValue = Font.system(size: 28, weight: .bold, design: .rounded)
    static let statLabel = Font.system(size: 18, weight: .medium)
    static let statLarge = Font.system(size: 36, weight: .bold, design: .rounded)

    // Buttons & badges
    static let buttonLabel = Font.system(size: 24, weight: .semibold)
    static let badge = Font.system(size: 20, weight: .semibold)

    // PR-specific
    static let prBadge = Font.system(size: 22, weight: .heavy)
    static let prExercise = Font.system(size: 20, weight: .semibold)
    static let prValue = Font.system(size: 24, weight: .bold, design: .rounded)
    static let prValueLarge = Font.system(size: 32, weight: .bold, design: .rounded)
    static let prInline = Font.system(size: 16, weight: .semibold)

    // Raw CGFloat sizes (for .font(.system(size:)) usage in workout views)
    enum Size {
        static let hero: CGFloat = 56
        static let title: CGFloat = 36
        static let stat: CGFloat = 48
        static let body: CGFloat = 29
        static let caption: CGFloat = 20
    }
}

// MARK: - Focus Card Modifier

struct TVFocusCardModifier: ViewModifier {
    @Environment(\.isFocused) var isFocused
    var cornerRadius: CGFloat = TVLayout.cornerRadius

    func body(content: Content) -> some View {
        content
            .scaleEffect(isFocused ? TVLayout.focusScale : 1.0)
            .shadow(
                color: isFocused ? Color.black.opacity(0.35) : .clear,
                radius: isFocused ? 24 : 0,
                y: isFocused ? 12 : 0
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
    }
}

extension View {
    func tvFocusCard(cornerRadius: CGFloat = TVLayout.cornerRadius) -> some View {
        modifier(TVFocusCardModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Parallax Card (signature tvOS interaction)

struct TVParallaxCard<Content: View>: View {
    let content: Content
    var width: CGFloat = TVLayout.cardWidth
    var height: CGFloat = TVLayout.cardHeight
    var cornerRadius: CGFloat = TVLayout.cornerRadius

    init(
        width: CGFloat = TVLayout.cardWidth,
        height: CGFloat = TVLayout.cardHeight,
        cornerRadius: CGFloat = TVLayout.cornerRadius,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        Button(action: {}) {
            content
                .frame(width: width, height: height)
                .background(Color(white: 0.18))
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        .buttonStyle(TVCardButtonStyle(cornerRadius: cornerRadius))
        .hoverEffect(.lift)
    }
}

// MARK: - TV Card Button Style

struct TVCardButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = TVLayout.cornerRadius
    @Environment(\.isFocused) var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isFocused ? TVLayout.focusScale : 1.0)
            .shadow(
                color: isFocused ? Color.black.opacity(0.35) : Color.black.opacity(0.15),
                radius: isFocused ? 24 : 8,
                y: isFocused ? 12 : 4
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isFocused)
    }
}

// MARK: - TV Glass Card

struct TVGlassCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = TVLayout.cornerRadius
    @Environment(\.isFocused) var isFocused

    init(cornerRadius: CGFloat = TVLayout.cornerRadius, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(white: 0.18))
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(
                color: isFocused ? Color.black.opacity(0.35) : Color.black.opacity(0.12),
                radius: isFocused ? 24 : 12,
                y: isFocused ? 12 : 6
            )
    }
}

// MARK: - TV Feed Card Button Style

struct TVFeedCardButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isFocused ? TVLayout.focusScale : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .shadow(
                color: isFocused ? Color.black.opacity(0.35) : Color.black.opacity(0.1),
                radius: isFocused ? 24 : 8,
                y: isFocused ? 12 : 4
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - TV Section Header

struct TVSectionHeader: View {
    let title: String
    let icon: String?

    init(_ title: String, icon: String? = nil) {
        self.title = title
        self.icon = icon
    }

    var body: some View {
        HStack {
            Text(title)
                .font(TVTypography.sectionTitle)
                .foregroundColor(TVLayout.offWhite)
            Spacer()
        }
        .padding(.bottom, 8)
    }
}

// MARK: - TV Stat Card

struct TVStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(TVTypography.stat)
                .foregroundStyle(GQGradients.primary)
            Text(title.uppercased())
                .font(TVTypography.caption)
                .tracking(1.2)
                .foregroundColor(GQColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(white: 0.18))
        .clipShape(RoundedRectangle(cornerRadius: TVLayout.cornerRadius))
    }
}

// MARK: - Focus-Aware Button Style for TV

struct TVPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isFocused) var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TVTypography.buttonLabel)
            .foregroundColor(.white)
            .padding(.horizontal, 40)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(GQGradients.primary)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : (isFocused ? 1.05 : 1.0))
            .shadow(
                color: isFocused ? GQColors.deepBlue.opacity(0.5) : .clear,
                radius: isFocused ? 24 : 0,
                y: isFocused ? 12 : 0
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

#endif
