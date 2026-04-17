import SwiftUI
import SwiftData

/// One slot in the Scroll feed. Mostly clips; periodic interrupt cards bridge
/// entertainment back to a runnable workout.
enum ScrollFeedItem: Identifiable {
    case clip(Post)
    case interrupt(Post)

    var id: String {
        switch self {
        case .clip(let p): return "clip-\(p.id.uuidString)"
        case .interrupt(let p): return "interrupt-\(p.id.uuidString)"
        }
    }
}

/// The "Shorts" surface — full-screen vertical paging Reels-style scroll.
/// Presented as a fullscreen sheet from Explore (Train), not as the Feed
/// front door, so the app's training identity stays primary.
///
/// `initialPostId` lets Explore deep-link straight to a specific clip
/// when the user taps a preview in the Shorts shelf.
struct ScrollFeedView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    let profile: UserProfile
    var initialPostId: UUID? = nil

    @Query(sort: \Post.timestamp, order: .reverse) private var allPosts: [Post]
    @Query private var saved: [SavedWorkout]
    @Query private var follows: [Friend]

    @State private var currentPostId: String?
    @State private var sheetForComments: Post?
    @State private var sheetForCollection: Post?
    @State private var sheetForFollow: Post?

    var body: some View {
        ZStack(alignment: .top) {
            scrollContent
            topBar
        }
        .ignoresSafeArea()
        .background(Color.black.ignoresSafeArea())
        .sheet(item: $sheetForComments) { post in
            CommentsSheet(
                post: post,
                currentUserId: profile.id,
                currentUserName: profile.name,
                currentUsername: profile.username
            )
        }
        .sheet(item: $sheetForCollection) { post in
            CollectionPickerSheet(post: post, userId: profile.id)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $sheetForFollow) { post in
            if let data = post.sharedWorkoutData,
               let shared = try? JSONDecoder().decode(SharedWorkoutData.self, from: data) {
                FollowWorkoutView(workoutData: shared, profile: profile)
            }
        }
    }

    // MARK: - Scroll content

    @ViewBuilder
    private var scrollContent: some View {
        let items = feedItems
        if items.isEmpty {
            emptyState
        } else {
            GeometryReader { geo in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(items) { item in
                            itemView(for: item)
                                .frame(width: geo.size.width, height: geo.size.height)
                                .id(item.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $currentPostId)
                .ignoresSafeArea()
                .onAppear {
                    if currentPostId == nil {
                        if let initialId = initialPostId {
                            currentPostId = "clip-\(initialId)"
                        } else {
                            currentPostId = items.first?.id
                        }
                    }
                }
                .onChange(of: currentPostId) { old, _ in
                    #if canImport(UIKit)
                    if old != nil {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    #endif
                    preloadUpcomingClips()
                }
            }
        }
    }

    @ViewBuilder
    private func itemView(for item: ScrollFeedItem) -> some View {
        switch item {
        case .clip(let post):
            ScrollFeedClip(
                post: post,
                profile: profile,
                isActive: currentPostId == item.id,
                onComment: { sheetForComments = post },
                onShare: { share(post) },
                onSave: { quickSave(post) },
                onLongPressSave: { sheetForCollection = post },
                onStartWorkout: { startOrPreview(post) }
            )
        case .interrupt(let post):
            WorkoutInterruptCard(
                post: post,
                onStart: { startOrPreview(post) },
                onSkip: { advancePastCurrent() }
            )
        }
    }

    /// Programmatically scroll one page down (used by the interrupt's
    /// "Keep scrolling" button so the user doesn't have to swipe manually).
    private func advancePastCurrent() {
        let items = feedItems
        guard let cur = currentPostId,
              let idx = items.firstIndex(where: { $0.id == cur }),
              idx + 1 < items.count else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            currentPostId = items[idx + 1].id
        }
    }

    // MARK: - Top bar overlay

    private var topBar: some View {
        ZStack {
            LinearGradient(
                colors: [.black.opacity(0.4), .clear],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 110)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)

            Text("Shorts")
                .font(.system(size: 16, weight: .heavy))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.4), radius: 4)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack {
                closeButton
                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 6)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var closeButton: some View {
        Button {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .heavy))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(.black.opacity(0.45)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "play.rectangle.on.rectangle")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(.white.opacity(0.5))
            Text("No clips yet — pull to refresh")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Back to Train") { dismiss() }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16).padding(.vertical, 9)
                .background(Capsule().fill(GQGradients.primary))
                .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: - Derived

    private var blendedClips: [Post] {
        let followedIds = Set(follows.filter { $0.userId == profile.id }.map(\.odId))
        return FeedBlenderService.shared.blend(
            posts: allPosts,
            profile: profile,
            followedIds: followedIds,
            saved: saved.filter { $0.userId == profile.id },
            mode: .forYou
        )
    }

    /// Stitches workout-interrupt cards into the clip stream every 8 items.
    /// Picks the most-runnable post for the interrupt (highest doability),
    /// falling back to the first clip if nothing's clearly runnable.
    private var feedItems: [ScrollFeedItem] {
        let clips = blendedClips
        guard !clips.isEmpty else { return [] }
        let interruptPost = clips.max(by: { $0.doabilityScore < $1.doabilityScore }) ?? clips[0]
        var items: [ScrollFeedItem] = []
        for (i, post) in clips.enumerated() {
            items.append(.clip(post))
            // Inject after every 8 clips, but only if there's actually
            // a runnable workout to promote.
            if (i + 1) % 8 == 0 && interruptPost.sharedWorkoutData != nil {
                items.append(.interrupt(interruptPost))
            }
        }
        return items
    }

    // MARK: - Actions

    private func quickSave(_ post: Post) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        let mySaves = saved.filter { $0.postId == post.id && $0.userId == profile.id }
        // Default destination = Watch later; the long-press picker remains for finer control.
        SavedWorkoutService.toggle(
            postId: post.id,
            userId: profile.id,
            collection: .watch,
            in: modelContext,
            existing: mySaves
        )
    }

    private func startOrPreview(_ post: Post) {
        guard post.sharedWorkoutData != nil else { return }
        sheetForFollow = post
    }

    /// Pre-write video data for the next 2 clip items to temp files so
    /// ScrollClipVideoPlayer.prepareIfNeeded can skip the multi-MB write.
    private func preloadUpcomingClips() {
        let items = feedItems
        guard let cur = currentPostId,
              let idx = items.firstIndex(where: { $0.id == cur }) else { return }
        var toPreload: [(id: UUID, videoData: Data)] = []
        for offset in 1...2 {
            let next = idx + offset
            guard next < items.count else { break }
            if case .clip(let post) = items[next] {
                if let v = post.videoData, v.count >= 1024 {
                    toPreload.append((id: post.id, videoData: v))
                } else if let media = post.mediaItems.first(where: { ($0.data?.count ?? 0) >= 1024 && $0.mediaType == .video }),
                          let data = media.data {
                    toPreload.append((id: post.id, videoData: data))
                }
            }
        }
        if !toPreload.isEmpty {
            ClipPreloader.shared.preload(posts: toPreload)
        }
    }

    private func share(_ post: Post) {
        #if canImport(UIKit)
        let text = "@\(post.authorUsername) on Lift AI: \(post.caption)"
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .first?
            .present(av, animated: true)
        #endif
    }
}
