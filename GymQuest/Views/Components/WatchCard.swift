import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Lean-back clip card for Watch shelves. Vertical aspect ratio, video-first
/// thumbnail, music + author footer, save-to-watch-later in the corner. Tap
/// opens the post detail (full clip playback).
struct WatchCard: View {
    let post: Post
    let isSaved: Bool
    let onTap: () -> Void
    let onToggleSave: () -> Void
    var onLongPressSave: (() -> Void)? = nil

    private let cardWidth: CGFloat = 160
    private let cardHeight: CGFloat = 250

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            mediaThumb
                .frame(width: cardWidth, height: cardHeight)
                .clipped()

            // Bottom gradient wash for legibility
            LinearGradient(
                colors: [.clear, .black.opacity(0.65)],
                startPoint: .center, endPoint: .bottom
            )
            .frame(height: 110)
            .frame(maxHeight: .infinity, alignment: .bottom)

            footer

            videoBadge.padding(8)
            saveButton.padding(8)
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(GQColors.borderDefault.opacity(0.5), lineWidth: 0.5))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var mediaThumb: some View {
        #if canImport(UIKit)
        if let data = primaryThumbData(), let img = UIImage(data: data) {
            Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
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

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !post.caption.isEmpty {
                Text(post.caption)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
            }
            HStack(spacing: 4) {
                Text("@\(post.authorUsername)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                Spacer(minLength: 0)
                Image(systemName: "heart.fill").font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.7))
                Text("\(post.likeCount)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    @ViewBuilder
    private var videoBadge: some View {
        if hasVideo {
            HStack(spacing: 3) {
                Image(systemName: "play.fill").font(.system(size: 9, weight: .bold))
                Text("Clip").font(.system(size: 9, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(Capsule().fill(.black.opacity(0.55)))
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private var saveButton: some View {
        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(isSaved ? GQColors.accent : .white)
            .padding(7)
            .background(Circle().fill(.black.opacity(0.45)))
            .contentShape(Circle())
            .onTapGesture(perform: onToggleSave)
            .onLongPressGesture(minimumDuration: 0.3) {
                onLongPressSave?()
            }
            .frame(maxWidth: .infinity, alignment: .topTrailing)
            .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Derived

    private var hasVideo: Bool {
        post.videoData != nil || post.mediaItems.contains(where: { $0.mediaType == .video })
    }

    private func primaryThumbData() -> Data? {
        if let firstMedia = post.mediaItems.first {
            return firstMedia.thumbnailData ?? firstMedia.data
        }
        return post.photoData
    }
}
