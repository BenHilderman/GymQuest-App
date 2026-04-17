import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Today-matched workout card with colored type accent and "why"
/// match chip. `.homeSocialCard(cornerRadius: 14)` with a colored
/// left-edge strip for visual variety across shelves.
struct TrainCard: View {
    let post: Post
    let isSaved: Bool
    let onTap: () -> Void
    let onStart: () -> Void
    let onToggleSave: () -> Void
    var onLongPressSave: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            // Colored type accent strip (like Today's colored rings)
            RoundedRectangle(cornerRadius: 3)
                .fill(typeColor)
                .frame(width: 4)
                .padding(.vertical, 8)

            HStack(spacing: 10) {
                thumbnail
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        if let type = post.workoutType {
                            Text(type.capitalized)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(typeColor)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(
                                    Capsule().fill(typeColor.opacity(0.12))
                                )
                        }
                        if let dur = post.duration, dur > 0 {
                            Text("\(dur) min")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(GQColors.textSecondary)
                        }
                    }

                    if let reason = matchReason {
                        Text(reason)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(GQColors.textTertiary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSaved ? GQColors.accent : GQColors.textTertiary)
                    .onTapGesture(perform: onToggleSave)
                    .onLongPressGesture(minimumDuration: 0.3) { onLongPressSave?() }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .homeSocialCard(cornerRadius: 14)
        .frame(width: 280)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    @ViewBuilder
    private var thumbnail: some View {
        #if canImport(UIKit)
        if let data = primaryThumbData(), let img = UIImage(data: data) {
            Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(typeColor.opacity(0.12))
                Image(systemName: workoutIcon)
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(typeColor)
            }
        }
        #else
        RoundedRectangle(cornerRadius: 10).fill(GQColors.surfaceSecondary)
        #endif
    }

    // MARK: - Workout type color (matches Today's ring colors)

    private var typeColor: Color {
        switch post.workoutType?.lowercased() {
        case "push": return .purple
        case "pull": return .blue
        case "legs": return .green
        case "cardio": return .orange
        case "core": return .pink
        case "full body": return .cyan
        default: return GQColors.accent
        }
    }

    // MARK: - Match reason

    private var matchReason: String? {
        if post.doabilityScore >= 0.5 { return "Ready to follow set-by-set" }
        if (post.likeCount + post.commentCount * 3) > 30 { return "Popular in community" }
        return nil
    }

    private var displayTitle: String {
        if let shared = decodedShared(), !shared.title.isEmpty { return shared.title }
        if let highlight = post.exerciseHighlight { return highlight }
        if let type = post.workoutType { return type.capitalized }
        return post.caption.isEmpty ? "Workout" : post.caption
    }

    private var workoutIcon: String {
        switch post.workoutType?.lowercased() {
        case "push": return "figure.strengthtraining.traditional"
        case "pull": return "figure.boxing"
        case "legs": return "figure.run"
        case "cardio": return "heart.fill"
        default: return "dumbbell.fill"
        }
    }

    private func primaryThumbData() -> Data? {
        if let first = post.mediaItems.first { return first.thumbnailData ?? first.data }
        return post.photoData
    }

    private func decodedShared() -> SharedWorkoutData? {
        guard let data = post.sharedWorkoutData else { return nil }
        return try? JSONDecoder().decode(SharedWorkoutData.self, from: data)
    }
}
