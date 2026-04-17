import SwiftUI
import SwiftData
import AVKit
#if canImport(UIKit)
import UIKit
#endif

/// One floating reaction sticker that rises over the clip after the user
/// taps an emoji in the picker. Lives only in-memory on the clip view.
struct FloatingReaction: Identifiable {
    let id = UUID()
    let emoji: String
    let startedAt: Date = Date()
    let xOffset: CGFloat   // -80...80, randomized so repeat taps don't stack
}

/// One full-screen card in the vertical Scroll feed. Photo or autoplay
/// video, right-rail actions (like / comment / share / save), bottom
/// info (author / caption / music), inline "Start →" pill when the post
/// has a runnable workout. Designed to feel like Reels: edge-to-edge
/// media, minimal chrome, gestures over buttons.
struct ScrollFeedClip: View {
    let post: Post
    let profile: UserProfile
    /// Only the active clip plays its video and starts dwell tracking.
    /// Driven by ScrollFeedView's `.scrollPosition` binding.
    let isActive: Bool

    let onComment: () -> Void
    let onShare: () -> Void
    let onSave: () -> Void
    let onLongPressSave: () -> Void
    let onStartWorkout: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var saved: [SavedWorkout]

    @State private var isLiked: Bool = false
    @State private var localLikeCount: Int = 0
    @State private var showHeartBurst: Bool = false
    @State private var heartLocation: CGPoint = .zero
    @State private var isPaused: Bool = false

    /// Long-press on the heart opens this reaction picker. One tap sends a
    /// Reaction and animates a floating sticker up over the clip — the
    /// fastest form of support in the app.
    @State private var showingReactionPicker: Bool = false
    @State private var reactionStickers: [FloatingReaction] = []

    private let reactionCatalog: [(emoji: String, type: ReactionType)] = [
        ("🔥", .fire),
        ("💪", .strong),
        ("👀", .eyes),
        ("🙌", .raisedHands)
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                mediaLayer
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                // Gradient wash so text stays legible no matter the photo
                LinearGradient(
                    colors: [.black.opacity(0.45), .clear, .clear, .black.opacity(0.65)],
                    startPoint: .top, endPoint: .bottom
                )

                if showHeartBurst {
                    DoubleTapHeartBurst(isActive: true, location: heartLocation)
                }

                ForEach(reactionStickers) { sticker in
                    floatingStickerView(sticker)
                }

                if isPaused {
                    Image(systemName: "play.fill")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundColor(.white.opacity(0.85))
                        .shadow(radius: 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.scale.combined(with: .opacity))
                }

                bottomInfo
                    .padding(.horizontal, 16)
                    .padding(.bottom, bottomChromeInset)
                    .padding(.trailing, 70)   // leave room for the right rail

                rightRail
                    .padding(.trailing, 12)
                    .padding(.bottom, bottomChromeInset + 4)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                if hasRunnableWorkout {
                    startPill
                        .padding(.trailing, 78)
                        .padding(.bottom, bottomChromeInset + (isCaptionTall ? 90 : 70))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { location in
                doubleTap(at: location)
            }
            .onTapGesture(count: 1) {
                togglePause()
            }
        }
        .ignoresSafeArea()
        .background(Color.black)
        .onAppear {
            seedLikeState()
            WatchTimeTracker.shared.didAppear(post.id)
        }
        .onDisappear {
            WatchTimeTracker.shared.didDisappear(post.id)
        }
    }

    // MARK: - Media layer

    @ViewBuilder
    private var mediaLayer: some View {
        #if canImport(UIKit)
        if let videoData = effectiveVideoData {
            ScrollClipVideoPlayer(videoData: videoData, isActive: isActive && !isPaused, postId: post.id)
        } else if let photoData = effectivePhotoData, let img = UIImage(data: photoData) {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            LinearGradient(
                colors: [GQColors.accent.opacity(0.6), .black],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        #else
        Color.black
        #endif
    }

    // MARK: - Right rail

    private var rightRail: some View {
        VStack(spacing: 22) {
            authorAvatar

            ZStack(alignment: .trailing) {
                actionButton(
                    icon: isLiked ? "heart.fill" : "heart",
                    count: localLikeCount,
                    tint: isLiked ? .red : .white
                ) {
                    toggleLike()
                }
                .onLongPressGesture(minimumDuration: 0.25) {
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    #endif
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showingReactionPicker = true
                    }
                }

                if showingReactionPicker {
                    reactionPicker
                        .offset(x: -60, y: 0)
                        .transition(.scale(scale: 0.6, anchor: .trailing).combined(with: .opacity))
                }
            }

            actionButton(icon: "bubble.right.fill", count: post.commentCount, tint: .white) {
                onComment()
            }

            actionButton(icon: isSavedByCurrentUser ? "bookmark.fill" : "bookmark",
                          count: nil,
                          tint: isSavedByCurrentUser ? GQColors.accent : .white) {
                onSave()
            }
            .onLongPressGesture(minimumDuration: 0.3) {
                onLongPressSave()
            }

            actionButton(icon: "paperplane.fill", count: nil, tint: .white) {
                onShare()
            }
        }
    }

    private var authorAvatar: some View {
        Circle()
            .fill(GQGradients.primary)
            .frame(width: 44, height: 44)
            .overlay(
                Text(String(post.authorName.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            )
            .overlay(Circle().stroke(.white, lineWidth: 2))
    }

    // MARK: - Reaction picker + stickers

    private var reactionPicker: some View {
        HStack(spacing: 8) {
            ForEach(reactionCatalog, id: \.emoji) { entry in
                Button {
                    sendReaction(emoji: entry.emoji, type: entry.type)
                } label: {
                    Text(entry.emoji)
                        .font(.system(size: 26))
                        .padding(6)
                        .background(Circle().fill(.ultraThinMaterial))
                        .environment(\.colorScheme, .dark)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Capsule().fill(.black.opacity(0.55)))
        .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.45), radius: 10, y: 4)
    }

    /// Floating emoji sticker that rises over the clip after a reaction
    /// tap. Uses a simple linear opacity + upward drift animation keyed to
    /// its own startedAt so stacking multiple reactions reads cleanly.
    @ViewBuilder
    private func floatingStickerView(_ sticker: FloatingReaction) -> some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSince(sticker.startedAt)
            let progress = min(1.0, elapsed / 1.6)
            Text(sticker.emoji)
                .font(.system(size: 40))
                .offset(x: sticker.xOffset, y: -CGFloat(progress) * 220)
                .opacity(1.0 - progress)
                .scaleEffect(1.0 + CGFloat(progress) * 0.4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 28)
                .padding(.bottom, 140)
                .allowsHitTesting(false)
        }
    }

    private func sendReaction(emoji: String, type: ReactionType) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        let sticker = FloatingReaction(
            emoji: emoji,
            xOffset: CGFloat.random(in: -70...10)
        )
        reactionStickers.append(sticker)

        let reaction = Reaction(
            odId: profile.id,
            odUsername: profile.username,
            targetType: "post",
            targetId: post.id,
            reactionType: type
        )
        modelContext.insert(reaction)
        try? modelContext.save()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            showingReactionPicker = false
        }

        // Retire the sticker from the view after its animation completes so
        // the array doesn't balloon over long sessions.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            reactionStickers.removeAll { $0.id == sticker.id }
        }
    }

    private func actionButton(icon: String, count: Int?, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(tint)
                    .shadow(color: .black.opacity(0.4), radius: 4)
                if let count, count > 0 {
                    Text(formatCount(count))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.4), radius: 3)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom info

    private var bottomInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("@\(post.authorUsername)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 3)

            if !post.caption.isEmpty {
                Text(post.caption)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(3)
                    .shadow(color: .black.opacity(0.5), radius: 3)
            }

            if let song = post.songTitle, let artist = post.artistName {
                HStack(spacing: 6) {
                    Image(systemName: "music.note")
                        .font(.system(size: 11, weight: .semibold))
                    Text("\(song) · \(artist)")
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundColor(.white.opacity(0.95))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Capsule().fill(.white.opacity(0.18)))
            }
        }
    }

    // MARK: - Start pill

    private var startPill: some View {
        Button(action: onStartWorkout) {
            HStack(spacing: 6) {
                Image(systemName: "play.fill").font(.system(size: 11, weight: .bold))
                Text("Start").font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(Capsule().fill(GQGradients.primary))
            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Derived

    private var hasRunnableWorkout: Bool {
        post.sharedWorkoutData != nil
    }

    /// The OS tab bar (~85pt on Pro) sits over the bottom of the clip
    /// because we ignore safe area for the media. We push the chrome up so
    /// captions and actions don't get covered.
    private var bottomChromeInset: CGFloat { 100 }

    private var isCaptionTall: Bool {
        post.caption.count > 60 || (post.songTitle != nil && post.artistName != nil)
    }

    /// Demo seeders sometimes write tiny placeholder bytes into `videoData`
    /// which AVPlayer renders as a black void. Real videos are MB-scale, so
    /// any payload under 1KB is treated as missing — we fall back to the
    /// photo path instead of showing a broken player.
    private static let minVideoBytes = 1024

    private var effectiveVideoData: Data? {
        if let v = post.videoData, v.count >= Self.minVideoBytes { return v }
        if let firstVideo = post.mediaItems.first(where: { $0.mediaType == .video }),
           let data = firstVideo.data, data.count >= Self.minVideoBytes {
            return data
        }
        return nil
    }

    /// Harmonized with TrainCard / WatchCard / ShortsPreviewCard: prefer the
    /// first mediaItem's thumbnail/data, then the legacy cover `photoData`.
    /// Single-video posts from the seeder have the first-frame on both, so
    /// ordering mostly affects multi-media and user-authored posts.
    private var effectivePhotoData: Data? {
        if let first = post.mediaItems.first {
            if let thumb = first.thumbnailData { return thumb }
            if let data = first.data { return data }
        }
        return post.photoData
    }

    private var isSavedByCurrentUser: Bool {
        saved.contains { $0.userId == profile.id && $0.postId == post.id }
    }

    // MARK: - Like

    private func seedLikeState() {
        // Local-only optimistic state; persistence is via post.likeCount.
        localLikeCount = post.likeCount
    }

    private func toggleLike() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        if isLiked {
            isLiked = false
            localLikeCount = max(0, localLikeCount - 1)
            post.likeCount = max(0, post.likeCount - 1)
        } else {
            isLiked = true
            localLikeCount += 1
            post.likeCount += 1
        }
        try? modelContext.save()
    }

    private func doubleTap(at location: CGPoint) {
        heartLocation = location
        showHeartBurst = true
        if !isLiked {
            isLiked = true
            localLikeCount += 1
            post.likeCount += 1
            try? modelContext.save()
        }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        #endif
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            showHeartBurst = false
        }
    }

    private func togglePause() {
        withAnimation(.easeInOut(duration: 0.18)) {
            isPaused.toggle()
        }
    }

    private func formatCount(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000     { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}

// MARK: - Scroll-friendly video player

#if canImport(UIKit)
/// Looping video player optimized for the Scroll feed: sound on by default,
/// active-only playback, automatic loop, lazy AVPlayer init. Renders a slim
/// progress scrubber along the bottom edge so users have a visual sense of
/// clip length and position.
struct ScrollClipVideoPlayer: View {
    let videoData: Data
    let isActive: Bool
    /// Post id used to check ClipPreloader's cache for a pre-written file.
    var postId: UUID? = nil

    @State private var player: AVPlayer?
    @State private var tempURL: URL?
    @State private var loopObserver: NSObjectProtocol?
    @State private var timeObserver: Any?
    @State private var isMuted: Bool = false
    @State private var progress: Double = 0   // 0..1

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let player = player {
                VideoPlayer(player: player)
                    .disabled(true)
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.black
            }

            Button {
                isMuted.toggle()
                player?.isMuted = isMuted
            } label: {
                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 16)
            .padding(.bottom, 24)

            scrubber
        }
        .onAppear {
            prepareIfNeeded()
            if isActive { player?.play() }
        }
        .onChange(of: isActive) { _, active in
            if active { player?.seek(to: .zero); player?.play() }
            else { player?.pause() }
        }
        .onDisappear { tearDown() }
    }

    /// Hairline progress bar pinned to the bottom of the clip — visible
    /// signal of length without competing with the chrome.
    private var scrubber: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(.white.opacity(0.18))
                    .frame(height: 2)
                Rectangle()
                    .fill(.white.opacity(0.95))
                    .frame(width: max(0, geo.size.width * progress), height: 2)
            }
        }
        .frame(height: 2)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    private func prepareIfNeeded() {
        guard player == nil else { return }
        let url: URL

        // Check if this is a "bundle:" marker (lightweight seeder data).
        // If so, load the real video directly from the app bundle — avoids
        // ever writing 4MB to a temp file during seeding.
        if let markerString = String(data: videoData.prefix(200), encoding: .utf8),
           markerString.hasPrefix("bundle:") {
            let resourceName = String(markerString.dropFirst(7)).trimmingCharacters(in: .controlCharacters.union(.init(charactersIn: "\0")))
            if let bundleURL = Bundle.main.url(forResource: resourceName, withExtension: "mp4") {
                url = bundleURL
            } else {
                return // resource not found
            }
        } else if let pid = postId,
           let cached = ClipPreloader.shared.cachedURL(for: pid),
           FileManager.default.fileExists(atPath: cached.path) {
            url = cached
        } else {
            let fresh = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".mov")
            try? videoData.write(to: fresh)
            url = fresh
        }
        do {
            let p = AVPlayer(url: url)
            p.isMuted = false
            player = p
            tempURL = url
            loopObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: p.currentItem,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    p.seek(to: .zero)
                    p.play()
                }
            }
            // Update scrubber 4x/sec — frequent enough to feel live, sparse
            // enough that it doesn't burn cycles.
            let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
            timeObserver = p.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
                guard let item = p.currentItem else { return }
                let total = CMTimeGetSeconds(item.duration)
                guard total > 0, total.isFinite else { return }
                let cur = CMTimeGetSeconds(time)
                Task { @MainActor in
                    progress = max(0, min(1, cur / total))
                }
            }
        } catch {
            // Player stays nil; the black background remains.
        }
    }

    private func tearDown() {
        if let obs = loopObserver {
            NotificationCenter.default.removeObserver(obs)
            loopObserver = nil
        }
        if let obs = timeObserver, let p = player {
            p.removeTimeObserver(obs)
            timeObserver = nil
        }
        player?.pause()
        player = nil
        if let u = tempURL { try? FileManager.default.removeItem(at: u); tempURL = nil }
    }
}
#endif
