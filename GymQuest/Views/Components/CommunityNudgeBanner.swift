import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Dismissible banner slotted at the very top of Explore. Shows exactly one
/// nudge at a time (the highest-priority), with a primary action button and
/// a quiet X to dismiss. Never interrupts video — renders as a compact strip.
struct CommunityNudgeBanner: View {
    let nudge: CommunityNudge
    let onAction: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            iconBadge

            VStack(alignment: .leading, spacing: 2) {
                Text(nudge.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(GQColors.textPrimary)
                    .lineLimit(1)
                Text(nudge.body)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: {
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
                onAction()
            }) {
                Text(nudge.actionLabel)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Capsule().fill(GQGradients.primary))
            }
            .buttonStyle(.plain)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(GQColors.textTertiary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .homeSocialCard(cornerRadius: 14)
    }

    // MARK: - Icon

    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(GQGradients.primary.opacity(0.18))
                .frame(width: 36, height: 36)
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(GQGradients.primary)
        }
    }

    private var iconName: String {
        switch nudge {
        case .justFinished: return "hand.raised.fill"
        case .duoDay: return "sparkles"
        case .friendOnStreak: return "flame.fill"
        case .crewAhead: return "figure.run"
        }
    }
}
