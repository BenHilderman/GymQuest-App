import SwiftUI

/// Minimal one-line crew recap — subtle, dismissible, matches Today's
/// section header language. Not a big card anymore.
struct CrewRecapCard: View {
    let recap: CrewWeeklyRecapData
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(GQGradients.primary)
            Text("Last week: \(recap.crewDaysTrained)/7 crew days")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(GQColors.textSecondary)
            if let top = recap.topMemberName {
                Text("· \(top) led")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(GQColors.textTertiary)
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(GQColors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(GQColors.adaptiveOverlay(0.04)))
    }
}
