import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Horizontal shelf of the user's clubs, rendered between the Stories rail
/// and the hero. Restores Clubs to first-class visibility after the Feed
/// pivot. Each card shows member-training count this week and the last
/// activity date. Tap → full ClubFeedView for that club.
struct ClubsShelf: View {
    let clubs: [Club]
    let trainingThisWeekByClub: [UUID: Int]   // clubId → count of members who trained
    let onTap: (Club) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR CLUBS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(GQColors.textTertiary)
                .tracking(1.2)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(clubs, id: \.id) { club in
                        clubCard(club)
                            .onTapGesture {
                                #if canImport(UIKit)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                #endif
                                onTap(club)
                            }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func clubCard(_ club: Club) -> some View {
        let trainingCount = trainingThisWeekByClub[club.id] ?? 0
        return HStack(spacing: 12) {
            banner(club)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(club.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(GQColors.textPrimary)
                    .lineLimit(1)

                Text(trainingCount > 0
                     ? "\(trainingCount) training this week"
                     : "\(club.memberCount) members")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)

                if let last = club.lastActivityDate {
                    Text("Last active \(RelativeDateString.short(from: last))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)
                } else {
                    Text("Tap to see what's up")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .frame(width: 240)
        .homeSocialCard(cornerRadius: 14)
    }

    @ViewBuilder
    private func banner(_ club: Club) -> some View {
        #if canImport(UIKit)
        if let data = club.imageData, let img = UIImage(data: data) {
            Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                LinearGradient(
                    colors: [GQColors.accent.opacity(0.55), GQColors.accent.opacity(0.2)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        #else
        Rectangle().fill(GQColors.surfaceSecondary)
        #endif
    }
}
