import SwiftUI

/// Horizontal shelf with Today-style section header (small uppercase,
/// tracked, tertiary color). Matches TodayView's THIS WEEK / STREAK /
/// ACTIVITY section header pattern for visual consistency across tabs.
struct ExploreShelfRow<Card: View>: View {
    let title: String
    let rationale: String?
    @ViewBuilder let cards: () -> Card

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(1.2)
                if let rationale, !rationale.isEmpty {
                    Text(rationale)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(GQColors.textSecondary)
                }
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    cards()
                }
                .padding(.horizontal, 16)
            }
        }
    }
}
