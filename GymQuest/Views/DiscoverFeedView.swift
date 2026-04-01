import SwiftUI
import SwiftData
import AVKit
import Combine
import Supabase

// MARK: - BookmarkStore

enum BookmarkStore {
    private static let key = "gq_bookmarked_posts"

    static func isBookmarked(_ postId: UUID) -> Bool {
        let set = loadSet()
        return set.contains(postId.uuidString)
    }

    @discardableResult
    static func toggle(_ postId: UUID) -> Bool {
        var set = loadSet()
        let idString = postId.uuidString
        if set.contains(idString) {
            set.remove(idString)
        } else {
            set.insert(idString)
        }
        UserDefaults.standard.set(Array(set), forKey: key)
        return set.contains(idString)
    }

    private static func loadSet() -> Set<String> {
        let arr = UserDefaults.standard.stringArray(forKey: key) ?? []
        return Set(arr)
    }
}

// MARK: - DiscoverFeedView

struct DiscoverFeedView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext

    @Query private var allPosts: [Post]
    @Query private var interestProfiles: [UserInterestProfile]
    @Query private var allFriendRecords: [Friend]
    @Query private var allUserProfiles: [UserProfile]

    let profile: UserProfile

    @State private var scrolledIndex: Int? = 0
    @State private var showCreatePost = false
    @State private var selectedCategory: String? = nil
    @AppStorage("hasSeenDiscoverTutorial") private var hasSeenTutorial = false
    @State private var showTutorial = false
    @State private var hasSeeded = false
    @State private var cachedMutualFriendIds: Set<UUID> = []
    @State private var cachedRankedPosts: [Post] = []

    var body: some View {
        GeometryReader { geo in
            let cardSize = geo.size
            ZStack {
                Color.black

                if cachedRankedPosts.isEmpty {
                    EmptyDiscoverFeed(showCreatePost: $showCreatePost)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(cachedRankedPosts.enumerated()), id: \.element.id) { index, post in
                                DiscoverFeedCard(
                                    post: post,
                                    profile: profile,
                                    cardSize: cardSize,
                                    isVisible: scrolledIndex == index
                                )
                                .frame(width: cardSize.width, height: cardSize.height)
                                .id(index)
                                .onAppear {
                                    EngagementTrackingService.shared.trackPostAppeared(postId: post.id, userId: profile.id)
                                }
                                .onDisappear {
                                    EngagementTrackingService.shared.trackPostDisappeared(postId: post.id, userId: profile.id)
                                }
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: $scrolledIndex)
                    .refreshable {
                        await refreshDiscoverFeed()
                    }
                }

                // Category pills pinned at top
                VStack {
                    CategoryFilterBar(
                        selectedCategory: $selectedCategory
                    )
                    Spacer()
                }

                // Tutorial overlay
                if showTutorial {
                    DiscoverTutorialOverlay {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showTutorial = false
                        }
                        hasSeenTutorial = true
                    }
                }
            }
        }
        .padding(.bottom, 56)
        .onAppear {
            if !hasSeeded {
                DiscoverSeeder.seedIfNeeded(modelContext: modelContext)
                hasSeeded = true
            }
            EngagementTrackingService.shared.configure(modelContext: modelContext)
            EngagementTrackingService.shared.refreshPostScores()
            computeMutualFriends()
            refreshRankedPosts()
            if !hasSeenTutorial && !cachedRankedPosts.isEmpty {
                showTutorial = true
            }
        }
        .onChange(of: allPosts.count) {
            refreshRankedPosts()
        }
        .onChange(of: selectedCategory) {
            scrolledIndex = 0
            refreshRankedPosts()
        }
        .onChange(of: allFriendRecords.count) {
            computeMutualFriends()
            refreshRankedPosts()
        }
        .onReceive(NotificationCenter.default.publisher(for: .feedShouldReRank)) { _ in
            refreshRankedPosts()
        }
        .sheet(isPresented: $showCreatePost) {
            CreatePostView(profile: profile)
        }
    }

    private func refreshDiscoverFeed() async {
        EngagementTrackingService.shared.refreshPostScores()
        computeMutualFriends()
        refreshRankedPosts()
    }

    // MARK: - Data Logic

    private func computeMutualFriends() {
        let following = Set(allFriendRecords.filter { $0.userId == profile.id }.map(\.odId))
        let followers = Set(allFriendRecords.filter { $0.odId == profile.id }.map(\.userId))
        cachedMutualFriendIds = following.intersection(followers)
    }

    private func isUserPublicOrFriend(_ authorId: UUID) -> Bool {
        if authorId == profile.id { return true }
        if cachedMutualFriendIds.contains(authorId) { return true }
        if let authorProfile = allUserProfiles.first(where: { $0.id == authorId }) {
            return authorProfile.isProfilePublic
        }
        return false
    }

    private func refreshRankedPosts() {
        let service = EngagementTrackingService.shared
        let eligible = allPosts.filter { post in
            (post.photoData != nil || post.videoData != nil || post.workoutType != nil)
            && isUserPublicOrFriend(post.authorId)
            && !(post.videoAspectRatio.map { $0 > 1.0 } ?? false)
            && !service.sessionNotInterestedPostIds.contains(post.id)
        }
        let userInterests = interestProfiles.first { $0.userId == profile.id }

        let sessionContext = SessionContext(
            workoutBoosts: service.sessionWorkoutBoosts,
            authorBoosts: service.sessionAuthorBoosts,
            hashtagBoosts: service.sessionHashtagBoosts,
            skippedPostIds: service.sessionSkippedPostIds,
            notInterestedPostIds: service.sessionNotInterestedPostIds
        )

        cachedRankedPosts = FeedRankingService.shared.rankPosts(
            eligible,
            for: profile.id,
            interests: userInterests,
            category: selectedCategory ?? "All",
            sessionContext: sessionContext
        )
    }
}

// MARK: - CategoryFilterBar

struct CategoryFilterBar: View {
    @Binding var selectedCategory: String?

    private let categories = ["All", "Push", "Pull", "Legs", "Cardio", "PR Moments", "Form Tips", "Music"]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    let isSelected = (category == "All" && selectedCategory == nil) || selectedCategory == category
                    Button {
                        selectedCategory = category == "All" ? nil : category
                    } label: {
                        Text(category)
                            .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                            .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Group {
                                    if isSelected {
                                        GQGradients.primary
                                    } else {
                                        Color.white.opacity(0.1)
                                    }
                                }
                            )
                            .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - DiscoverFeedCard

struct DiscoverFeedCard: View {
    let post: Post
    let profile: UserProfile
    let cardSize: CGSize
    var isVisible: Bool = true

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @Query private var allFriends: [Friend]

    @State private var isLiked = false
    @State private var showHeartAnimation = false
    @State private var showComments = false
    @State private var showShare = false
    @State private var showPlaylistPreview = false
    @State private var showMusicActions = false
    @State private var showReactionPicker = false
    @State private var likeCount = 0
    @State private var lastTapLocation: CGPoint = .zero
    @State private var isBookmarked = false
    @State private var isFollowing = false
    @State private var commentCount = 0
    @State private var showWorkoutDetail = false
    @State private var showFullRouteMap = false
    @State private var profileUserId: IdentifiableUUID?

    var body: some View {
        ZStack {
            // Layer 1: Media background
            PostMediaBackground(post: post, isVisible: isVisible, size: cardSize, userId: profile.id)

            // Layer 2: Double-tap target
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { location in
                    lastTapLocation = location
                    triggerLike()
                }

            // Layer 3: Workout overlay (GIF strip or route map)
            discoverWorkoutOverlay

            // Layer 4: Content overlay
            PostContentOverlay(
                post: post,
                profile: profile,
                isLiked: $isLiked,
                likeCount: $likeCount,
                commentCount: $commentCount,
                isBookmarked: $isBookmarked,
                isFollowing: $isFollowing,
                showComments: $showComments,
                showShare: $showShare,
                showPlaylistPreview: $showPlaylistPreview,
                showMusicActions: $showMusicActions,
                showReactionPicker: $showReactionPicker,
                onLikeTap: toggleLike,
                onBookmarkTap: toggleBookmark,
                onFollowTap: toggleFollow,
                onReaction: { type in handleReaction(type) },
                onNotInterested: handleNotInterested,
                onTapUsername: { profileUserId = IdentifiableUUID(id: post.authorId) }
            )

            // Floating heart animation
            if showHeartAnimation {
                FloatingHeart(at: lastTapLocation)
            }
        }
        .clipped()
        .onAppear { loadState() }
        .sheet(isPresented: $showComments) {
            DiscoverCommentsSheet(post: post, profile: profile) {
                commentCount = post.commentCount
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showShare) {
            DiscoverShareSheet(
                post: post,
                isBookmarked: $isBookmarked,
                onSharePlaylist: (post.spotifyPlaylistURL != nil || post.appleMusicPlaylistURL != nil) ? {
                    showShare = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showPlaylistPreview = true
                    }
                } : nil,
                onToggleBookmark: toggleBookmark
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showPlaylistPreview) {
            PlaylistPreviewSheet(post: post)
        }
        .confirmationDialog("Music", isPresented: $showMusicActions, titleVisibility: .hidden) {
            if let urlString = post.spotifyPlaylistURL, let url = URL(string: urlString) {
                Button("Open in Spotify") {
                    #if canImport(UIKit)
                    UIApplication.shared.open(url)
                    #endif
                }
            }
            if let urlString = post.appleMusicPlaylistURL, let url = URL(string: urlString) {
                Button("Open in Apple Music") {
                    #if canImport(UIKit)
                    UIApplication.shared.open(url)
                    #endif
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showWorkoutDetail) {
            if let workout = post.getSharedWorkout() {
                WorkoutDetailSheet(
                    workoutData: workout,
                    onFollow: {
                        showWorkoutDetail = false
                    }
                )
            }
        }
        .fullScreenCover(isPresented: $showFullRouteMap) {
            if let workout = post.getSharedWorkout(), let points = workout.routePoints, !points.isEmpty {
                NavigationStack {
                    PostRouteMapView(
                        routePoints: points,
                        distance: "5.00 km",
                        pace: "4:31 /km",
                        height: .infinity
                    )
                    .ignoresSafeArea()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { showFullRouteMap = false } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                    }
                    .toolbarBackground(.hidden, for: .navigationBar)
                }
            }
        }
        .sheet(item: $profileUserId) { wrapped in
            UserProfileSheet(userId: wrapped.id, currentProfile: profile)
        }
    }

    // MARK: - Workout Overlay

    @ViewBuilder
    private var discoverWorkoutOverlay: some View {
        let workout = post.getSharedWorkout()
        let hasExercises = workout != nil && !(workout?.exercises.isEmpty ?? true)
        let hasRoute: Bool = {
            guard let w = workout, let pts = w.routePoints, !pts.isEmpty else { return false }
            let cardioKeywords = ["Cardio", "Run", "Cycling", "Walking", "Hiking"]
            let type = post.workoutType ?? ""
            let highlight = post.exerciseHighlight ?? ""
            return cardioKeywords.contains(where: { type.contains($0) || highlight.contains($0) })
        }()

        if hasRoute, let points = workout?.routePoints {
            VStack {
                Spacer()
                PostRouteMapView(
                    routePoints: points,
                    distance: "5.00 km",
                    pace: "4:31 /km"
                )
                .onTapGesture { showFullRouteMap = true }
                .padding(.horizontal, 12)
                .padding(.bottom, 80)
            }
        } else if hasExercises, let w = workout {
            VStack {
                Spacer()
                VStack(spacing: 0) {
                    OverlayExerciseGifStrip(
                        exercises: w.exercises,
                        totalCount: w.exercises.count,
                        onTapMore: { showWorkoutDetail = true }
                    )
                }
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(.bottom, 70)
            }
        }
    }

    // MARK: - State Loading

    private func loadState() {
        likeCount = post.likeCount
        commentCount = post.commentCount
        isBookmarked = BookmarkStore.isBookmarked(post.id)

        let postId = post.id
        let userId = profile.id

        // Check like status
        let likeDescriptor = FetchDescriptor<Like>(predicate: #Predicate {
            $0.postId == postId && $0.userId == userId
        })
        isLiked = (try? modelContext.fetchCount(likeDescriptor)) ?? 0 > 0

        // Check follow status
        let authorId = post.authorId
        let myId = profile.id
        let followDescriptor = FetchDescriptor<Friend>(predicate: #Predicate {
            $0.userId == myId && $0.odId == authorId
        })
        isFollowing = (try? modelContext.fetchCount(followDescriptor)) ?? 0 > 0
    }

    // MARK: - Interactions

    private func triggerLike() {
        guard !isLiked else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        isLiked = true
        likeCount += 1
        post.likeCount = likeCount

        let like = Like(postId: post.id, userId: profile.id, userName: profile.name)
        modelContext.insert(like)
        try? modelContext.save()

        FeedContentService.shared.syncLikeToSupabase(postId: post.id, userId: profile.id, userName: profile.name)
        EngagementTrackingService.shared.trackLike(postId: post.id, userId: profile.id)

        showHeartAnimation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showHeartAnimation = false
        }
    }

    private func toggleLike() {
        if isLiked {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            isLiked = false
            likeCount -= 1
            post.likeCount = likeCount

            let postId = post.id
            let userId = profile.id
            let descriptor = FetchDescriptor<Like>(predicate: #Predicate {
                $0.postId == postId && $0.userId == userId
            })
            if let likes = try? modelContext.fetch(descriptor) {
                for like in likes { modelContext.delete(like) }
            }
            try? modelContext.save()
            FeedContentService.shared.syncUnlikeToSupabase(postId: post.id, userId: profile.id)
        } else {
            triggerLike()
        }
    }

    private func toggleBookmark() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        isBookmarked = BookmarkStore.toggle(post.id)
        EngagementTrackingService.shared.trackSave(postId: post.id, userId: profile.id)
    }

    private func toggleFollow() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        let authorId = post.authorId
        let myId = profile.id

        if isFollowing {
            isFollowing = false
            profile.followingCount = max(0, profile.followingCount - 1)
            let descriptor = FetchDescriptor<Friend>(predicate: #Predicate {
                $0.userId == myId && $0.odId == authorId
            })
            if let records = try? modelContext.fetch(descriptor) {
                for record in records { modelContext.delete(record) }
            }

            // Sync unfollow to Supabase
            if FeatureFlags.shared.supabaseSyncEnabled {
                Task {
                    do {
                        try await SupabaseConfig.client.from("follows")
                            .delete()
                            .eq("follower_id", value: myId.uuidString)
                            .eq("following_id", value: authorId.uuidString)
                            .execute()
                    } catch {
                        print("[DiscoverFeedView] Supabase unfollow sync failed: \(error)")
                    }
                }
            }
        } else {
            isFollowing = true
            profile.followingCount += 1
            let friend = Friend(userId: profile.id, odId: post.authorId, odName: post.authorName, odUsername: post.authorUsername)
            modelContext.insert(friend)
            EngagementTrackingService.shared.trackFollow(postId: post.id, userId: profile.id)

            // Sync follow to Supabase
            if FeatureFlags.shared.supabaseSyncEnabled {
                Task {
                    do {
                        let dto = FollowDTO(followerId: myId, followingId: authorId)
                        try await SupabaseSyncService.shared.insert(dto, table: "follows")
                    } catch {
                        print("[DiscoverFeedView] Supabase follow sync failed: \(error)")
                    }
                }
            }
        }
        updateAuthorFollowerCount(authorId: authorId, increment: isFollowing)
        try? modelContext.save()
    }

    private func updateAuthorFollowerCount(authorId: UUID, increment: Bool) {
        let descriptor = FetchDescriptor<UserProfile>(predicate: #Predicate {
            $0.id == authorId
        })
        if let author = try? modelContext.fetch(descriptor).first {
            author.followerCount += increment ? 1 : -1
        }
    }

    private func handleReaction(_ type: ReactionType) {
        let reaction = Reaction(
            odId: profile.id,
            odUsername: profile.username,
            targetType: "post",
            targetId: post.id,
            reactionType: type
        )
        modelContext.insert(reaction)
        try? modelContext.save()
        if !isLiked { triggerLike() }
        showReactionPicker = false

        if FeatureFlags.shared.supabaseSyncEnabled {
            Task {
                do {
                    let dto = ReactionDTO(
                        userId: SupabaseAuthService.shared.currentUserId ?? reaction.odId,
                        userUsername: reaction.odUsername,
                        targetType: reaction.targetType,
                        targetId: reaction.targetId,
                        reactionType: reaction.reactionType.rawValue
                    )
                    try await SupabaseSyncService.shared.insert(dto, table: "reactions")
                } catch {
                    print("[Reaction] Supabase sync failed: \(error)")
                }
            }
        }
    }

    private func handleNotInterested() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        EngagementTrackingService.shared.trackNotInterested(postId: post.id, userId: profile.id)
    }
}

// MARK: - PostMediaBackground

struct PostMediaBackground: View {
    let post: Post
    var isVisible: Bool = true
    let size: CGSize
    var userId: UUID? = nil

    var body: some View {
        Group {
            if post.videoData != nil {
                DiscoverVideoPlayer(post: post, isVisible: isVisible, userId: userId)
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else if let photoData = post.photoData {
                #if canImport(UIKit)
                if let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size.width, height: size.height)
                        .clipped()
                } else {
                    fallbackGradient
                }
                #else
                fallbackGradient
                #endif
            } else {
                fallbackGradient
            }
        }
    }

    private var fallbackGradient: some View {
        LinearGradient(
            colors: [
                GQColors.surfaceBase,
                GQColors.background
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - DiscoverVideoPlayer

struct DiscoverVideoPlayer: View {
    let post: Post
    var isVisible: Bool = true
    var userId: UUID? = nil

    @State private var player: AVPlayer?
    @State private var isPlaying = true
    @State private var userPaused = false

    var body: some View {
        ZStack {
            if let player {
                RawVideoView(player: player)
            }

            // Tap to toggle play/pause
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { togglePlayback() }

            // Pause icon
            if userPaused {
                Image(systemName: "play.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white.opacity(0.7))
                    .allowsHitTesting(false)
            }
        }
        .onAppear { setupPlayer() }
        .onDisappear { teardownPlayer() }
        .onChange(of: isVisible) { _, newValue in
            if newValue && !userPaused {
                player?.seek(to: .zero)
                player?.play()
                isPlaying = true
            } else if !newValue {
                player?.pause()
                isPlaying = false
            }
        }
    }

    private func setupPlayer() {
        guard let data = post.videoData else { return }
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(post.id.uuidString).mp4")
        try? data.write(to: tempURL)

        let avPlayer = AVPlayer(url: tempURL)
        avPlayer.isMuted = true
        avPlayer.play()

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: avPlayer.currentItem,
            queue: .main
        ) { _ in
            avPlayer.seek(to: .zero)
            avPlayer.play()

            // Track video loop/rewatch
            if let uid = userId {
                EngagementTrackingService.shared.trackVideoLoop(postId: post.id, userId: uid)
            }
        }

        player = avPlayer
        isPlaying = true
    }

    private func teardownPlayer() {
        player?.pause()
        player = nil
    }

    private func togglePlayback() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            userPaused = true
        } else {
            player.play()
            userPaused = false
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            isPlaying.toggle()
        }
    }
}

// MARK: - RawVideoView (no built-in controls overlay)

#if canImport(UIKit)
struct RawVideoView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> UIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    private class PlayerUIView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
#endif

// MARK: - PostContentOverlay

struct PostContentOverlay: View {
    let post: Post
    let profile: UserProfile
    @Binding var isLiked: Bool
    @Binding var likeCount: Int
    @Binding var commentCount: Int
    @Binding var isBookmarked: Bool
    @Binding var isFollowing: Bool
    @Binding var showComments: Bool
    @Binding var showShare: Bool
    @Binding var showPlaylistPreview: Bool
    @Binding var showMusicActions: Bool
    @Binding var showReactionPicker: Bool
    var onLikeTap: () -> Void
    var onBookmarkTap: () -> Void
    var onFollowTap: () -> Void
    var onReaction: (ReactionType) -> Void
    var onNotInterested: () -> Void
    var onTapUsername: (() -> Void)? = nil

    private var hasMusic: Bool { post.songTitle != nil && post.artistName != nil }
    private var isSpotify: Bool { post.musicSource?.lowercased().contains("spotify") == true }
    private var serviceColor: Color { isSpotify ? Color(hex: "1DB954") : Color(hex: "FC3C44") }

    var body: some View {
        ZStack {
            // Full gradient overlay
            VStack(spacing: 0) {
                // Top fade (for music pill)
                LinearGradient(
                    colors: [.black.opacity(0.5), .black.opacity(0.15), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)

                Spacer()

                // Bottom fade (for info + actions)
                LinearGradient(
                    colors: [.clear, .black.opacity(0.1), .black.opacity(0.5), .black.opacity(0.75)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 220)
            }
            .allowsHitTesting(false)

            VStack {
                // ── Top: Music pill (centered) ──
                if hasMusic, let song = post.songTitle, let artist = post.artistName {
                    Button {
                        if post.spotifyPlaylistURL != nil || post.appleMusicPlaylistURL != nil {
                            showPlaylistPreview = true
                        } else {
                            showMusicActions = true
                        }
                    } label: {
                        HStack(spacing: 10) {
                            // Album art placeholder
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(serviceColor.opacity(0.3))
                                    )
                                    .frame(width: 40, height: 40)

                                Image(systemName: "music.note")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(song)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(artist)
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.7))
                                    .lineLimit(1)
                            }

                            MusicEQBars(barCount: 3, barWidth: 2, maxHeight: 12, color: .white, isPlaying: true)
                                .frame(width: 14, height: 12)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(serviceColor.opacity(0.12))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(.white.opacity(0.2), lineWidth: 0.5)
                                )
                        )
                        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 60)
                    .frame(maxWidth: .infinity)
                }

                Spacer()

                // ── Bottom: Info + Actions ──
                HStack(alignment: .bottom, spacing: 12) {
                    PostInfoSection(
                        post: post,
                        profile: profile,
                        isFollowing: $isFollowing,
                        showPlaylistPreview: $showPlaylistPreview,
                        showMusicActions: $showMusicActions,
                        onFollowTap: onFollowTap,
                        onTapUsername: onTapUsername
                    )

                    ActionButtonColumn(
                        post: post,
                        profile: profile,
                        isLiked: $isLiked,
                        likeCount: $likeCount,
                        commentCount: $commentCount,
                        isBookmarked: $isBookmarked,
                        showComments: $showComments,
                        showShare: $showShare,
                        showReactionPicker: $showReactionPicker,
                        onLikeTap: onLikeTap,
                        onBookmarkTap: onBookmarkTap,
                        onReaction: onReaction,
                        onNotInterested: onNotInterested
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
    }
}

// MARK: - PostInfoSection

struct PostInfoSection: View {
    let post: Post
    let profile: UserProfile
    @Binding var isFollowing: Bool
    @Binding var showPlaylistPreview: Bool
    @Binding var showMusicActions: Bool
    var onFollowTap: () -> Void
    var onTapUsername: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Author row
            HStack(spacing: 8) {
                Button {
                    onTapUsername?()
                } label: {
                    Text("@\(post.authorUsername)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)

                if post.authorId != profile.id {
                    Button {
                        onFollowTap()
                    } label: {
                        Text(isFollowing ? "Following" : "Follow")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(isFollowing ? .white.opacity(0.6) : .white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(isFollowing ? Color.white.opacity(0.15) : Color.white.opacity(0.25))
                            )
                    }
                }
            }

            // Caption with hashtags
            if !post.caption.isEmpty {
                captionWithHashtags
            }

            // Playlist pill (only if has playlist links, music is shown at top)
            if post.spotifyPlaylistURL != nil || post.appleMusicPlaylistURL != nil {
                PlaylistPill(spotifyURL: post.spotifyPlaylistURL, appleMusicURL: post.appleMusicPlaylistURL) {
                    showPlaylistPreview = true
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var captionWithHashtags: some View {
        let words = post.caption.split(separator: " ", omittingEmptySubsequences: false)
        let text = words.reduce(Text("")) { result, word in
            let str = String(word)
            if str.hasPrefix("#") {
                return result + Text(str).foregroundColor(GQColors.deepBlue).bold() + Text(" ")
            } else {
                return result + Text(str) + Text(" ")
            }
        }
        text
            .font(.system(size: 14, weight: .regular))
            .foregroundColor(.white.opacity(0.9))
            .lineLimit(3)
    }

}

// MARK: - ActionButtonColumn

struct ActionButtonColumn: View {
    let post: Post
    let profile: UserProfile
    @Binding var isLiked: Bool
    @Binding var likeCount: Int
    @Binding var commentCount: Int
    @Binding var isBookmarked: Bool
    @Binding var showComments: Bool
    @Binding var showShare: Bool
    @Binding var showReactionPicker: Bool
    var onLikeTap: () -> Void
    var onBookmarkTap: () -> Void
    var onReaction: (ReactionType) -> Void
    var onNotInterested: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Like button with long-press reaction
            ZStack(alignment: .topLeading) {
                if showReactionPicker {
                    ReactionPickerBubble(
                        postId: post.id,
                        profileId: profile.id,
                        profileUsername: profile.username,
                        onSelect: { type in onReaction(type) }
                    )
                    .offset(x: -160, y: -20)
                    .transition(.scale.combined(with: .opacity))
                }

                DiscoverActionButton(
                    icon: isLiked ? "heart.fill" : "heart",
                    count: likeCount,
                    tint: isLiked ? GQColors.textSecondary : .white
                ) {
                    onLikeTap()
                }
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.4)
                        .onEnded { _ in
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            #endif
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showReactionPicker.toggle()
                            }
                        }
                )
            }

            // Comment button
            DiscoverActionButton(
                icon: "bubble.right.fill",
                count: commentCount,
                tint: .white
            ) {
                EngagementTrackingService.shared.trackComment(postId: post.id, userId: profile.id)
                showComments = true
            }

            // Share button
            DiscoverActionButton(
                icon: "arrowshape.turn.up.right.fill",
                count: post.shareCount,
                tint: .white
            ) {
                EngagementTrackingService.shared.trackShare(postId: post.id, userId: profile.id)
                showShare = true
            }

            // Bookmark button
            DiscoverActionButton(
                icon: isBookmarked ? "bookmark.fill" : "bookmark",
                count: 0,
                tint: isBookmarked ? GQColors.textSecondary : .white
            ) {
                onBookmarkTap()
            }

            // Not Interested button
            DiscoverActionButton(
                icon: "hand.thumbsdown",
                count: 0,
                tint: .white
            ) {
                onNotInterested()
            }
        }
    }
}

// MARK: - DiscoverActionButton

struct DiscoverActionButton: View {
    let icon: String
    let count: Int
    var tint: Color = .white
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(tint)
                    .shadow(color: .black.opacity(0.4), radius: 3, y: 1)

                if count > 0 {
                    Text(formatCount(count))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                }
            }
        }
        .scaleEffect(isPressed ? 0.85 : 1.0)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - FloatingHeart

struct FloatingHeart: View {
    let at: CGPoint

    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 1
    @State private var yOffset: CGFloat = 0

    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 80))
            .foregroundColor(GQColors.textSecondary)
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(y: yOffset)
            .position(at)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    scale = 1.2
                }
                withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                    yOffset = -40
                    opacity = 0
                    scale = 0.6
                }
            }
    }
}

// MARK: - ReactionPickerBubble

struct ReactionPickerBubble: View {
    let postId: UUID
    let profileId: UUID
    let profileUsername: String
    var onSelect: (ReactionType) -> Void

    private let reactions: [(ReactionType, String)] = [
        (.heart, "❤️"), (.fire, "🔥"), (.thumbsUp, "👍"),
        (.strong, "💪"), (.clap, "👏"), (.shocked, "😮")
    ]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(reactions, id: \.0) { type, emoji in
                Button {
                    onSelect(type)
                } label: {
                    Text(emoji)
                        .font(.system(size: 28))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        )
    }
}

// MARK: - DiscoverCommentsSheet

struct DiscoverCommentsSheet: View {
    let post: Post
    let profile: UserProfile
    var onCommentPosted: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var allComments: [Comment]
    @State private var newComment = ""
    @FocusState private var isCommentFocused: Bool

    private var postComments: [Comment] {
        allComments
            .filter { $0.postId == post.id }
            .sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(postComments) { comment in
                            DiscoverCommentRow(comment: comment)
                        }
                    }
                }

                Divider()

                // Comment input
                HStack(spacing: 10) {
                    TextField("Add a comment...", text: $newComment)
                        .font(.system(size: 15))
                        .focused($isCommentFocused)

                    Button("Post") {
                        postNewComment()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(GQColors.textSecondary)
                    .disabled(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func postNewComment() {
        let trimmed = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let comment = Comment(
            postId: post.id,
            authorId: profile.id,
            authorName: profile.name,
            authorUsername: profile.username,
            content: trimmed
        )
        modelContext.insert(comment)
        post.commentCount += 1
        try? modelContext.save()

        onCommentPosted()
        newComment = ""
        isCommentFocused = false

        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

// MARK: - DiscoverCommentRow

struct DiscoverCommentRow: View {
    let comment: Comment
    @State private var isLiked = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(GQGradients.primary)
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(comment.authorName.prefix(1)).uppercased())
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(comment.authorUsername)
                        .font(.system(size: 13, weight: .bold))
                    Text(comment.timestamp, style: .relative)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Text(comment.content)
                    .font(.system(size: 14))

                HStack(spacing: 16) {
                    Button("Reply") {}
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button {
                isLiked.toggle()
            } label: {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 12))
                    .foregroundColor(isLiked ? GQColors.textSecondary : .secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - DiscoverShareSheet

struct DiscoverShareSheet: View {
    let post: Post
    @Binding var isBookmarked: Bool
    var onSharePlaylist: (() -> Void)?
    var onToggleBookmark: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showReportConfirmation = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                LazyVGrid(columns: columns, spacing: 20) {
                    shareButton(icon: "square.and.arrow.up", label: "Share Post") {
                        #if canImport(UIKit)
                        let text = "\(post.authorName)'s \(post.workoutType ?? "workout") on Lift AI: \(post.caption)"
                        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let root = windowScene.keyWindow?.rootViewController {
                            root.present(av, animated: true)
                        }
                        #endif
                    }

                    if post.getSharedWorkout() != nil {
                        shareButton(icon: "figure.strengthtraining.traditional", label: "Share Workout") {
                            #if canImport(UIKit)
                            let text = "\(post.authorName)'s \(post.workoutType ?? "workout") on Lift AI"
                            let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let root = windowScene.keyWindow?.rootViewController {
                                root.present(av, animated: true)
                            }
                            #endif
                        }
                    }

                    if onSharePlaylist != nil {
                        shareButton(icon: "music.note.list", label: "Share Playlist") {
                            onSharePlaylist?()
                        }
                    }

                    shareButton(icon: "link", label: "Copy Link") {
                        #if canImport(UIKit)
                        UIPasteboard.general.string = "liftai://post/\(post.id.uuidString)"
                        #endif
                        dismiss()
                    }

                    shareButton(
                        icon: isBookmarked ? "bookmark.fill" : "bookmark",
                        label: isBookmarked ? "Saved" : "Save"
                    ) {
                        onToggleBookmark()
                    }

                    shareButton(icon: "exclamationmark.triangle", label: "Report") {
                        showReportConfirmation = true
                    }
                }
                .padding(.horizontal, 16)

                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Post Reported", isPresented: $showReportConfirmation) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Thank you for your report. We'll review this post.")
            }
        }
    }

    @ViewBuilder
    private func shareButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Color.white.opacity(0.1)))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .foregroundColor(.primary)
    }
}

// MARK: - PlaylistPreviewSheet

struct PlaylistPreviewSheet: View {
    let post: Post

    private var tracks: [(String, String)] {
        let type = post.workoutType?.lowercased() ?? ""
        switch type {
        case "push":
            return [
                ("Lose Yourself", "Eminem"), ("HUMBLE.", "Kendrick Lamar"),
                ("Stronger", "Kanye West"), ("Till I Collapse", "Eminem"),
                ("Power", "Kanye West"), ("Can't Hold Us", "Macklemore"),
                ("Remember The Name", "Fort Minor"), ("Eye of the Tiger", "Survivor")
            ]
        case "pull":
            return [
                ("Sicko Mode", "Travis Scott"), ("DNA.", "Kendrick Lamar"),
                ("Jumpman", "Drake & Future"), ("Mask Off", "Future"),
                ("Black Skinhead", "Kanye West"), ("No Role Modelz", "J. Cole"),
                ("m.A.A.d city", "Kendrick Lamar"), ("Backseat Freestyle", "Kendrick Lamar")
            ]
        case "legs":
            return [
                ("Run This Town", "JAY-Z"), ("All I Do Is Win", "DJ Khaled"),
                ("We Ready", "Archie Eversole"), ("Pump It", "Black Eyed Peas"),
                ("Stronger", "Kanye West"), ("Work", "Rihanna"),
                ("Started From The Bottom", "Drake"), ("Harder Better Faster", "Daft Punk")
            ]
        case "cardio":
            return [
                ("Blinding Lights", "The Weeknd"), ("Levitating", "Dua Lipa"),
                ("Sunset Lover", "Petit Biscuit"), ("Don't Start Now", "Dua Lipa"),
                ("Physical", "Dua Lipa"), ("Running Up That Hill", "Kate Bush"),
                ("Break My Stride", "Matthew Wilder"), ("Unstoppable", "Sia")
            ]
        default:
            return [
                ("Lose Yourself", "Eminem"), ("Stronger", "Kanye West"),
                ("Till I Collapse", "Eminem"), ("Eye of the Tiger", "Survivor"),
                ("Power", "Kanye West"), ("HUMBLE.", "Kendrick Lamar")
            ]
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    RoundedRectangle(cornerRadius: 16)
                        .fill(GQGradients.primary)
                        .frame(height: 120)
                        .overlay(
                            VStack(spacing: 6) {
                                Image(systemName: "music.note.list")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                                Text("\(post.workoutType ?? "Workout") Playlist")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                Text("\(tracks.count) tracks")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        )
                        .padding(.horizontal, 16)

                    // Track list
                    VStack(spacing: 0) {
                        ForEach(Array(tracks.enumerated()), id: \.offset) { index, track in
                            HStack(spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(width: 20)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(track.0)
                                        .font(.system(size: 15, weight: index == 0 ? .bold : .regular))
                                        .foregroundColor(index == 0 ? GQColors.textSecondary : .primary)
                                    Text(track.1)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if index == 0 {
                                    MusicEQBars()
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                    }

                    // Open buttons
                    HStack(spacing: 12) {
                        if let urlString = post.spotifyPlaylistURL, let url = URL(string: urlString) {
                            Button {
                                #if canImport(UIKit)
                                UIApplication.shared.open(url)
                                #endif
                            } label: {
                                Label("Open in Spotify", systemImage: "play.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(GQColors.deepBlue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                        if let urlString = post.appleMusicPlaylistURL, let url = URL(string: urlString) {
                            Button {
                                #if canImport(UIKit)
                                UIApplication.shared.open(url)
                                #endif
                            } label: {
                                Label("Apple Music", systemImage: "play.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(GQColors.deepBlue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .padding(.vertical, 16)
            }
            .navigationTitle("Playlist")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - MusicMarqueeTicker

struct MusicMarqueeTicker: View {
    let post: Post
    var onTap: () -> Void

    @State private var resolvedArtURL: String?

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                AlbumArtAsync(
                    localData: post.albumArtData,
                    urlString: resolvedArtURL ?? post.albumArtURL,
                    isSpotify: post.musicSource?.lowercased().contains("spotify") == true
                )
                Text(tickerText)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundColor(.white.opacity(0.85))
        }
        .task(id: post.id) {
            guard post.albumArtURL == nil, post.albumArtData == nil,
                  let song = post.songTitle, !song.isEmpty else { return }
            let artist = post.artistName ?? ""
            if let url = await AlbumArtService.shared.artworkURL(song: song, artist: artist) {
                resolvedArtURL = url.absoluteString
                post.albumArtURL = url.absoluteString
            }
        }
    }

    private var tickerText: String {
        if let artist = post.artistName, !artist.isEmpty {
            return "\(post.songTitle ?? "") · \(artist)"
        }
        return post.songTitle ?? ""
    }
}

// MARK: - PlaylistPill

struct PlaylistPill: View {
    let spotifyURL: String?
    let appleMusicURL: String?
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: spotifyURL != nil ? "waveform" : "music.note")
                    .font(.system(size: 11))
                Text("View Playlist")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
            )
        }
    }
}

// MARK: - EmptyDiscoverFeed

struct EmptyDiscoverFeed: View {
    @Binding var showCreatePost: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 48))
                .foregroundStyle(GQGradients.primary)

            Text("Nothing to Discover Yet")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(GQColors.textPrimary)

            Text("Complete a workout to get personalized recommendations")
                .font(.system(size: 15))
                .foregroundColor(GQColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Log a Workout") {
                showCreatePost = true
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(width: 180)
        }
    }
}

// MARK: - DiscoverTutorialOverlay

struct DiscoverTutorialOverlay: View {
    var onDismiss: () -> Void

    @State private var chevronOffset: CGFloat = 0
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
                    .offset(y: chevronOffset)

                Text("Swipe up to discover\nmore workouts")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Button("Got it") {
                    onDismiss()
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(GQColors.cardBackground)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Capsule().fill(.white))
            }
        }
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.4)) {
                opacity = 1
            }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                chevronOffset = -16
            }
            Task {
                try? await Task.sleep(for: .seconds(4))
                onDismiss()
            }
        }
        .allowsHitTesting(true)
    }
}

// MARK: - Helpers

private func formatCount(_ count: Int) -> String {
    if count >= 1_000_000 {
        return String(format: "%.1fM", Double(count) / 1_000_000)
    } else if count >= 1_000 {
        return String(format: "%.1fK", Double(count) / 1_000)
    }
    return "\(count)"
}

// MARK: - Preview

#Preview {
    DiscoverFeedView(profile: UserProfile(name: "Ben", username: "ben"))
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
