import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Inline preview shelf for vertical short clips, rendered inside Explore.
/// Each card is a portrait-aspect thumbnail that, when tapped, launches
/// the full-screen ScrollFeedView starting at that clip — keeping Train
/// as the front door while putting Shorts one tap away.
struct ShortsShelf: View {
    let posts: [Post]
    let onTap: (Post) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Text("SHORTS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(1.2)
                Text("· tap to scroll")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(GQColors.textTertiary)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(Array(posts.prefix(4).enumerated()), id: \.element.id) { idx, post in
                        ShortsPreviewCard(post: post, autoplay: idx == 0)
                            .onTapGesture {
                                #if canImport(UIKit)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                #endif
                                onTap(post)
                            }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

/// Single vertical-aspect tile for a clip. ~120×200pt. Shows the post's
/// thumbnail (or a procedural fallback) with a play badge top-right and
/// the author handle bottom-left.
struct ShortsPreviewCard: View {
    let post: Post
    var autoplay: Bool = false

    private let cardWidth: CGFloat = 120
    private let cardHeight: CGFloat = 200

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if autoplay {
                autoplayMedia
                    .frame(width: cardWidth, height: cardHeight)
                    .clipped()
            } else {
                thumbnail
                    .frame(width: cardWidth, height: cardHeight)
                    .clipped()
            }

            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.7)],
                startPoint: .top, endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text("@\(post.authorUsername)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.5), radius: 2)
                if let workoutType = post.workoutType {
                    Text(workoutType.capitalized)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "play.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .padding(5)
                .background(Circle().fill(.black.opacity(0.55)))
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(GQColors.borderDefault.opacity(0.5), lineWidth: 0.5))
    }

    @ViewBuilder
    private var thumbnail: some View {
        #if canImport(UIKit)
        if let data = thumbData(), let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            LinearGradient(
                colors: [GQColors.accent.opacity(0.5), .black.opacity(0.6)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        #else
        Rectangle().fill(GQColors.surfaceSecondary)
        #endif
    }

    private func thumbData() -> Data? {
        if let first = post.mediaItems.first { return first.thumbnailData ?? first.data }
        return post.photoData
    }

    /// Miniature muted looping player for the first card. Adds movement
    /// to the page so it feels alive instead of a wall of stills.
    @ViewBuilder
    private var autoplayMedia: some View {
        #if canImport(UIKit)
        if let videoData = effectiveVideoData {
            ScrollClipVideoPlayer(videoData: videoData, isActive: true)
        } else {
            thumbnail
        }
        #else
        thumbnail
        #endif
    }

    private var effectiveVideoData: Data? {
        if let v = post.videoData, v.count >= 1024 { return v }
        if let media = post.mediaItems.first(where: { ($0.data?.count ?? 0) >= 1024 && $0.mediaType == .video }),
           let data = media.data { return data }
        return nil
    }
}
