import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// "Your next session" card — shows what the user SHOULD train (not what
/// they already did), with 2-3 visual workout options they can start
/// immediately. Each option shows a thumbnail + title + duration + Start.
struct NextSessionCard: View {
    let recommendation: NextWorkoutRecommendation
    let matchingPosts: [Post]
    let onStartPost: (Post) -> Void
    let onTapPost: (Post) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if matchingPosts.isEmpty {
                emptyState
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(matchingPosts.prefix(3).enumerated()), id: \.element.id) { index, post in
                        workoutOption(post: post, rank: index + 1)
                        if index < min(matchingPosts.count, 3) - 1 {
                            Divider().overlay(GQColors.adaptiveOverlay(0.04))
                        }
                    }
                }
            }
        }
        .padding(16)
        .homeSocialCard(cornerRadius: 16)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 14))
                    .foregroundStyle(GQGradients.primary)
                Text("Your Next Session")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)
                Spacer()
                Text(recommendation.workoutType.capitalized)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(GQGradients.primary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(GQGradients.primary.opacity(0.1))
                    .clipShape(Capsule())
            }
            Text(recommendation.reason)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
        }
    }

    // MARK: - Workout option row

    private func workoutOption(post: Post, rank: Int) -> some View {
        HStack(spacing: 12) {
            thumbnail(post)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(displayTitle(post))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(GQColors.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let dur = post.duration, dur > 0 {
                        Text("\(dur) min")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(GQColors.textSecondary)
                    }
                    Text("@\(post.authorUsername)")
                        .font(.system(size: 11))
                        .foregroundColor(GQColors.textTertiary)
                }
            }

            Spacer()

            Button {
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
                onStartPost(post)
            } label: {
                Text("Start")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(GQGradients.primary)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(GQGradients.primary.opacity(0.08)))
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTapPost(post) }
    }

    // MARK: - Thumbnail

    @ViewBuilder
    private func thumbnail(_ post: Post) -> some View {
        #if canImport(UIKit)
        if let data = thumbData(post), let img = UIImage(data: data) {
            Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(GQGradients.primary.opacity(0.08))
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(GQGradients.primary)
            }
        }
        #else
        RoundedRectangle(cornerRadius: 10).fill(GQColors.surfaceSecondary)
        #endif
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            Text("No \(recommendation.workoutType.lowercased()) workouts found yet")
                .font(.system(size: 13))
                .foregroundColor(GQColors.textTertiary)
            Spacer()
        }
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private func displayTitle(_ post: Post) -> String {
        if let data = post.sharedWorkoutData,
           let shared = try? JSONDecoder().decode(SharedWorkoutData.self, from: data),
           !shared.title.isEmpty { return shared.title }
        if let highlight = post.exerciseHighlight { return highlight }
        return post.caption.isEmpty ? (post.workoutType?.capitalized ?? "Workout") : post.caption
    }

    private func thumbData(_ post: Post) -> Data? {
        if let first = post.mediaItems.first { return first.thumbnailData ?? first.data }
        return post.photoData
    }
}
