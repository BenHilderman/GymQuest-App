import SwiftUI

/// Option 8 — "Today's Plan" style suggestion card. One full-width
/// `.homeSocialCard` per recommendation. Layout is an exact copy of
/// `planCardShell` from TodayView: icon circle | VStack(label+title) |
/// Spacer | action button.
struct SuggestionCard: View {
    let capsLabel: String           // "BECAUSE YOU TRAINED LEGS" — caps section header
    let title: String               // Best workout name
    let subtitle: String?           // "60 min · 3 exercises"
    let icon: String                // SF Symbol name
    let actionLabel: String         // "Start ▸"
    let onAction: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(GQGradients.primary.opacity(0.08))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(GQGradients.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(capsLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(GQColors.textTertiary)
                Text(title)
                    .font(.system(size: 15.8, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)
                }
            }

            Spacer()

            Button(action: onAction) {
                Text(actionLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(GQGradients.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(GQGradients.primary.opacity(0.08)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .homeSocialCard(cornerRadius: 14)
    }
}
