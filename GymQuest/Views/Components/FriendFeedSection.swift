import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// Inline Friends section on Explore — compact post cards + inactive
/// nudges. Matches `.homeSocialCard(cornerRadius: 14)` design language
/// from Today's widgets.
struct FriendFeedSection: View {
    let items: [FriendFeedItem]
    let profileLookup: [UUID: UserProfile]
    let onPostTap: (Post) -> Void
    let onQuickReact: (Post) -> Void
    let onSendNudge: (UUID) -> Void
    let onSeeAll: () -> Void
    var onStartWorkout: (() -> Void)? = nil

    var body: some View {
        if items.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("FRIENDS")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(GQColors.textTertiary)
                        .tracking(1.2)
                    Spacer()
                    Button(action: onSeeAll) {
                        Text("See all →")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(GQColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)

                VStack(spacing: 8) {
                    ForEach(items) { item in
                        switch item {
                        case .post(let post):
                            CompactFriendPostCard(
                                post: post,
                                authorProfile: profileLookup[post.authorId],
                                onTap: { onPostTap(post) },
                                onReact: { onQuickReact(post) }
                            )
                        case .inactive(let userId, let name, _, let lastDate):
                            InactiveFriendNudgeCard(
                                friendName: name,
                                lastActiveDate: lastDate,
                                onSend: { onSendNudge(userId) }
                            )
                        }
                    }

                    yourTurnCTA
                }
                .padding(.horizontal, 16)
            }
        }
    }

    /// Gentle motivational push after seeing all your friends' activity.
    /// The natural impulse after "Jake trained, Sarah trained" is "I should too."
    @ViewBuilder
    private var yourTurnCTA: some View {
        let postCount = items.filter { if case .post = $0 { return true } else { return false } }.count
        if postCount >= 2, let onStartWorkout {
            Button(action: onStartWorkout) {
                HStack(spacing: 8) {
                    Text("Your friends showed up")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(GQColors.textSecondary)
                    Spacer()
                    Text("Your turn →")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(GQGradients.primary)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(GQColors.surfaceSecondary)
                )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Compact Friend Post Card

struct CompactFriendPostCard: View {
    let post: Post
    let authorProfile: UserProfile?
    let onTap: () -> Void
    let onReact: () -> Void

    @State private var reactScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 10) {
            avatar
            thumbnail
            info
            Spacer(minLength: 0)
            reactButton
        }
        .padding(10)
        .homeSocialCard(cornerRadius: 14)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private var avatar: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(GQGradients.primary)
                .frame(width: 38, height: 38)
                .overlay(
                    Text(String((authorProfile?.name ?? post.authorName).prefix(1)).uppercased())
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                )

            Text(workoutEmoji)
                .font(.system(size: 10))
                .frame(width: 16, height: 16)
                .background(Circle().fill(GQColors.background))
                .offset(x: 2, y: 2)
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        #if canImport(UIKit)
        if let data = thumbData(), let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        #endif
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(authorProfile?.name ?? post.authorName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(GQColors.textPrimary)
                    .lineLimit(1)
                Text("· \(RelativeDateString.warm(from: post.timestamp))")
                    .font(.system(size: 11))
                    .foregroundColor(GQColors.textTertiary)
            }

            if let type = post.workoutType, let dur = post.duration, dur > 0 {
                HStack(spacing: 6) {
                    Text(type.capitalized)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                    Text("·")
                        .foregroundColor(GQColors.textTertiary)
                    Text("\(dur) min")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(GQColors.textSecondary)
                }
            }

            Text(post.caption)
                .font(.system(size: 12))
                .foregroundColor(GQColors.textSecondary)
                .lineLimit(1)

            HStack(spacing: 8) {
                Label("\(post.likeCount)", systemImage: "heart.fill")
                Label("\(post.commentCount)", systemImage: "bubble.right.fill")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(GQColors.textTertiary)
        }
    }

    private var reactButton: some View {
        Button(action: {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                reactScale = 1.5
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    reactScale = 1.0
                }
            }
            onReact()
        }) {
            Text("💪")
                .font(.system(size: 20))
                .scaleEffect(reactScale)
                .frame(width: 38, height: 38)
                .background(Circle().fill(GQColors.surfaceSecondary))
        }
        .buttonStyle(.plain)
    }

    private var workoutEmoji: String {
        switch post.workoutType?.lowercased() {
        case "push": return "🏋️"
        case "pull": return "💪"
        case "legs": return "🦵"
        case "cardio": return "🏃"
        case "core": return "🧘"
        case "full body": return "⚡"
        default: return "🏋️"
        }
    }

    private func thumbData() -> Data? {
        if let first = post.mediaItems.first { return first.thumbnailData ?? first.data }
        return post.photoData
    }
}

// MARK: - Inactive Friend Nudge Card

struct InactiveFriendNudgeCard: View {
    let friendName: String
    let lastActiveDate: Date?
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(GQColors.surfaceSecondary)
                    .frame(width: 36, height: 36)
                Image(systemName: "person.fill.questionmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(GQColors.textTertiary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(friendName) hasn't trained \(sinceText)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)
                    .lineLimit(1)
                Text("Send a nudge — \"we miss you\"")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)
            }

            Spacer(minLength: 0)

            Button(action: {
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
                onSend()
            }) {
                Text("💪")
                    .font(.system(size: 16))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(GQGradients.primary))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .homeSocialCard(cornerRadius: 14)
    }

    private var sinceText: String {
        guard let last = lastActiveDate else { return "in a while" }
        return "since \(RelativeDateString.warm(from: last))"
    }
}
