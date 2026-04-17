import SwiftUI
import AVKit
#if canImport(UIKit)
import UIKit
#endif

/// Inline autoplay video card for the unified discover feed. Plays
/// muted when scrolled into view. Full-width with author + engagement
/// below. Tap opens fullscreen Shorts. "Start" shows when runnable.
struct DiscoverVideoCard: View {
    let post: Post
    let isVisible: Bool
    let onTap: () -> Void
    let onStart: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                videoPlayer
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                if onStart != nil {
                    Button { onStart?() } label: {
                        Text("Start ▸")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Capsule().fill(GQGradients.primary))
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)

            postInfo
        }
        .padding(16)
        .homeSocialCard(cornerRadius: 16)
    }

    @ViewBuilder
    private var videoPlayer: some View {
        #if canImport(UIKit)
        if let videoData = effectiveVideoData {
            ScrollClipVideoPlayer(videoData: videoData, isActive: isVisible, postId: post.id)
        } else {
            photoFallback
        }
        #else
        Rectangle().fill(GQColors.surfaceSecondary)
        #endif
    }

    @ViewBuilder
    private var photoFallback: some View {
        #if canImport(UIKit)
        if let data = post.photoData, let img = UIImage(data: data) {
            Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
        } else {
            Rectangle().fill(GQColors.surfaceSecondary)
        }
        #endif
    }

    private var postInfo: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text("@\(post.authorUsername)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                    if let type = post.workoutType {
                        Text("· \(type.capitalized)")
                            .font(.system(size: 12))
                            .foregroundColor(GQColors.textTertiary)
                    }
                }
                Text(post.caption)
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
            HStack(spacing: 12) {
                Label("\(post.likeCount)", systemImage: "heart.fill")
                Label("\(post.commentCount)", systemImage: "bubble.right.fill")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(GQColors.textTertiary)
        }
    }

    private var effectiveVideoData: Data? {
        if let v = post.videoData, v.count >= 1024 { return v }
        if let media = post.mediaItems.first(where: { ($0.data?.count ?? 0) >= 1024 && $0.mediaType == .video }),
           let data = media.data { return data }
        return nil
    }
}

// MARK: - Photo Card

/// Full-width photo card for the discover feed. Same card language as
/// Today's widgets but with a prominent image.
struct DiscoverPhotoCard: View {
    let post: Post
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            photoImage
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)

            postInfo
        }
        .padding(16)
        .homeSocialCard(cornerRadius: 16)
    }

    @ViewBuilder
    private var photoImage: some View {
        #if canImport(UIKit)
        if let data = thumbData(), let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                Rectangle().fill(GQColors.surfaceSecondary)
                Image(systemName: "photo")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(GQColors.textTertiary)
            }
        }
        #else
        Rectangle().fill(GQColors.surfaceSecondary)
        #endif
    }

    private var postInfo: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text("@\(post.authorUsername)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                    if let type = post.workoutType {
                        Text("· \(type.capitalized)")
                            .font(.system(size: 12))
                            .foregroundColor(GQColors.textTertiary)
                    }
                }
                if !post.caption.isEmpty {
                    Text(post.caption)
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textSecondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            HStack(spacing: 12) {
                Label("\(post.likeCount)", systemImage: "heart.fill")
                Label("\(post.commentCount)", systemImage: "bubble.right.fill")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(GQColors.textTertiary)
        }
    }

    private func thumbData() -> Data? {
        if let first = post.mediaItems.first { return first.thumbnailData ?? first.data }
        return post.photoData
    }
}
