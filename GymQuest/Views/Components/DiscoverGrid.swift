import SwiftUI
import AVKit
#if canImport(UIKit)
import UIKit
#endif

/// Instagram Explore-style grid. 3 columns with occasional 2×2 featured
/// cells for recommended workouts/videos. Dense thumbnails for scanning
/// many options at once. Videos autoplay muted when scrolled into view.
struct DiscoverGrid: View {
    let items: [DiscoverFeedItem]
    let onTapVideo: (Post) -> Void     // opens fullscreen Shorts
    let onTapPhoto: (Post) -> Void     // opens post detail
    let onStartWorkout: (Post) -> Void

    /// ID of the item currently closest to the viewport center — drives
    /// autoplay on the featured video cell.
    @State private var activeVideoId: String?

    private let spacing: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            let cellSize = (geo.size.width - spacing * 2 - 32) / 3
            ScrollView {
                gridLayout(cellSize: cellSize)
                    .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Grid layout with featured cells

    @ViewBuilder
    private func gridLayout(cellSize: CGFloat) -> some View {
        // Build rows: every 9 items, row pattern is [3, 2+featured, 3, featured+2]
        // Simplified: first 3 are small, 4th is featured (2×2), next 2 small beside it,
        // then repeat.
        let grouped = stride(from: 0, to: items.count, by: 9).map { start in
            Array(items[start..<min(start + 9, items.count)])
        }

        LazyVStack(spacing: spacing) {
            ForEach(Array(grouped.enumerated()), id: \.offset) { groupIdx, group in
                gridGroup(group, cellSize: cellSize, groupOffset: groupIdx)
            }
        }
    }

    @ViewBuilder
    private func gridGroup(_ group: [DiscoverFeedItem], cellSize: CGFloat, groupOffset: Int) -> some View {
        // Row 1: 3 small cells
        if group.count >= 3 {
            HStack(spacing: spacing) {
                smallCell(group[0], size: cellSize)
                smallCell(group[1], size: cellSize)
                smallCell(group[2], size: cellSize)
            }
        }

        // Row 2-3: featured (2×2) + 2 small stacked (alternating left/right)
        if group.count >= 4 {
            let featuredOnLeft = groupOffset % 2 == 0
            let featured = group[3]
            let featuredSize = cellSize * 2 + spacing
            let smalls = Array(group.dropFirst(4).prefix(2))

            HStack(spacing: spacing) {
                if featuredOnLeft {
                    featuredCell(featured, size: featuredSize)
                    VStack(spacing: spacing) {
                        ForEach(smalls) { item in
                            smallCell(item, size: cellSize)
                        }
                        if smalls.count < 2 {
                            Color.clear.frame(width: cellSize, height: cellSize)
                        }
                    }
                    .frame(width: cellSize)
                } else {
                    VStack(spacing: spacing) {
                        ForEach(smalls) { item in
                            smallCell(item, size: cellSize)
                        }
                        if smalls.count < 2 {
                            Color.clear.frame(width: cellSize, height: cellSize)
                        }
                    }
                    .frame(width: cellSize)
                    featuredCell(featured, size: featuredSize)
                }
            }
        }

        // Row 4: remaining small cells (up to 3)
        let remaining = Array(group.dropFirst(6))
        if !remaining.isEmpty {
            HStack(spacing: spacing) {
                ForEach(remaining) { item in
                    smallCell(item, size: cellSize)
                }
                ForEach(0..<max(0, 3 - remaining.count), id: \.self) { _ in
                    Color.clear.frame(width: cellSize, height: cellSize)
                }
            }
        }
    }

    // MARK: - Small cell (1×1 square thumbnail)

    private func smallCell(_ item: DiscoverFeedItem, size: CGFloat) -> some View {
        Button {
            handleTap(item)
        } label: {
            ZStack {
                thumbnailView(item.post)
                    .frame(width: size, height: size)
                    .clipped()

                // Top-right: play icon for video OR multi-image badge
                if isVideo(item) {
                    HStack(spacing: 3) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 8, weight: .bold))
                        if item.post.mediaItems.count > 1 {
                            Text("\(item.post.mediaItems.count)")
                                .font(.system(size: 8, weight: .bold))
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 5).padding(.vertical, 3)
                    .background(Capsule().fill(.black.opacity(0.55)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(4)
                }

                // Bottom-left: duration badge
                if let dur = item.post.duration, dur > 0 {
                    Text("\(dur)m")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Capsule().fill(.black.opacity(0.55)))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .padding(4)
                }

                // Bottom-right: engagement
                if item.post.likeCount > 5 {
                    HStack(spacing: 2) {
                        Image(systemName: "heart.fill").font(.system(size: 7))
                        Text("\(item.post.likeCount)")
                            .font(.system(size: 8, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 4).padding(.vertical, 2)
                    .background(Capsule().fill(.black.opacity(0.45)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(4)
                }
            }
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Featured cell (2×2 with autoplay video or large photo)

    private func featuredCell(_ item: DiscoverFeedItem, size: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            #if canImport(UIKit)
            if isVideo(item), let videoData = effectiveVideoData(item.post) {
                ScrollClipVideoPlayer(videoData: videoData, isActive: true, postId: item.post.id)
                    .frame(width: size, height: size)
                    .clipped()
            } else {
                thumbnailView(item.post)
                    .frame(width: size, height: size)
                    .clipped()
            }
            #endif

            // Overlay info
            LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 3) {
                if let type = item.post.workoutType {
                    Text(type.capitalized)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(.white.opacity(0.25)))
                }
                Text(item.post.caption)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.5), radius: 2)
            }
            .padding(8)

            if item.post.sharedWorkoutData != nil {
                Button { onStartWorkout(item.post) } label: {
                    Text("Start")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(GQGradients.primary))
                }
                .buttonStyle(.plain)
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture { handleTap(item) }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func thumbnailView(_ post: Post) -> some View {
        #if canImport(UIKit)
        if let data = thumbData(post), let img = UIImage(data: data) {
            Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                Rectangle().fill(GQColors.surfaceSecondary)
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(GQColors.textTertiary)
            }
        }
        #else
        Rectangle().fill(GQColors.surfaceSecondary)
        #endif
    }

    private func thumbData(_ post: Post) -> Data? {
        if let first = post.mediaItems.first { return first.thumbnailData ?? first.data }
        return post.photoData
    }

    private func isVideo(_ item: DiscoverFeedItem) -> Bool {
        if case .video = item { return true }
        return false
    }

    private func effectiveVideoData(_ post: Post) -> Data? {
        if let v = post.videoData, v.count >= 1024 { return v }
        if let media = post.mediaItems.first(where: { ($0.data?.count ?? 0) >= 1024 && $0.mediaType == .video }),
           let data = media.data { return data }
        return nil
    }

    private func handleTap(_ item: DiscoverFeedItem) {
        switch item {
        case .video(let post): onTapVideo(post)
        case .photo(let post): onTapPhoto(post)
        case .suggestion(let post, _): onTapPhoto(post)
        }
    }
}
