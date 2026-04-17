import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Compact feed tile for a `WorkoutCheckIn` — visually distinct from a
/// full Post card because check-ins are casual "I just trained" signals,
/// not curated moments.
struct CheckInTile: View {
    let checkIn: WorkoutCheckIn
    let onCheer: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            avatar
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text("@\(checkIn.userUsername)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(GQColors.textPrimary)
                    Text("· \(RelativeDateString.short(from: checkIn.timestamp))")
                        .font(.system(size: 11))
                        .foregroundColor(GQColors.textTertiary)
                }
                Text(headline)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(GQColors.textPrimary)
                    .lineLimit(2)
                if let note = checkIn.note, !note.isEmpty {
                    Text("\"\(note)\"")
                        .font(.system(size: 12))
                        .foregroundColor(GQColors.textSecondary)
                        .italic()
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onCheer) {
                Text("💪")
                    .font(.system(size: 20))
                    .padding(10)
                    .background(Circle().fill(GQColors.surfaceSecondary))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(GQColors.surfaceBase))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(GQColors.borderDefault.opacity(0.5), lineWidth: 0.5))
    }

    private var headline: String {
        let type = checkIn.workoutType.capitalized
        let dur = checkIn.durationMinutes
        return "Just finished \(type) · \(dur) min ✓"
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(GQGradients.primary)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(checkIn.userName.prefix(1)).uppercased())
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                )
            Circle()
                .fill(GQColors.success)
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(GQColors.background, lineWidth: 2))
                .frame(width: 40, height: 40, alignment: .bottomTrailing)
        }
    }
}
