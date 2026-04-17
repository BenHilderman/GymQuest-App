import SwiftUI

/// Horizontal row of workout-type chips for manual discovery. Each chip
/// is color-coded to match the TrainCard accent for that type. Tap →
/// calls back with the selected type for filtering.
struct CategoryBrowseRow: View {
    let onSelect: (String) -> Void

    private let categories: [(label: String, icon: String, color: Color)] = [
        ("Push", "figure.strengthtraining.traditional", .purple),
        ("Pull", "figure.boxing", .blue),
        ("Legs", "figure.run", .green),
        ("Cardio", "heart.fill", .orange),
        ("Core", "figure.core.training", .pink),
        ("Full Body", "bolt.fill", .cyan)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BROWSE")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(GQColors.textTertiary)
                .tracking(1.2)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories, id: \.label) { cat in
                        Button {
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                            onSelect(cat.label)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: cat.icon)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(cat.color)
                                Text(cat.label)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(GQColors.textPrimary)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(
                                Capsule().fill(cat.color.opacity(0.08))
                            )
                            .overlay(
                                Capsule().stroke(cat.color.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}
