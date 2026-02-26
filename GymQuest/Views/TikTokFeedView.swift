//
//  TikTokFeedView.swift
//  GymQuest
//
//  TikTok-style vertical scrolling feed with full-screen posts
//  Features: Double-tap to like, side action buttons, auto-scroll,
//  video lifecycle management, music integration, playlist sharing
//

import SwiftUI
import SwiftData
import AVKit

// MARK: - Bookmark Store

enum BookmarkStore {
    private static let key = "gq_bookmarked_posts"

    static func isBookmarked(_ postId: UUID) -> Bool {
        let set = loadSet()
        return set.contains(postId.uuidString)
    }

    static func toggle(_ postId: UUID) -> Bool {
        var set = loadSet()
        let idStr = postId.uuidString
        if set.contains(idStr) {
            set.remove(idStr)
        } else {
            set.insert(idStr)
        }
        UserDefaults.standard.set(Array(set), forKey: key)
        return set.contains(idStr)
    }

    private static func loadSet() -> Set<String> {
        let arr = UserDefaults.standard.stringArray(forKey: key) ?? []
        return Set(arr)
    }
}

// MARK: - TikTok Style Feed

struct TikTokFeedView: View {
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

    // Cached data for performance
    @State private var cachedMutualFriendIds: Set<UUID> = []
    @State private var cachedRankedPosts: [Post] = []

    private let categories = ["All", "Push", "Pull", "Legs", "Cardio", "PR Moments", "Form Tips", "Music"]

    private var userInterests: UserInterestProfile? {
        interestProfiles.first { $0.userId == profile.id }
    }

    var filteredPosts: [Post] { cachedRankedPosts }

    private func refreshMutualFriendIds() {
        let myFollowing = Set(allFriendRecords.filter { $0.userId == profile.id }.map(\.odId))
        let myFollowers = Set(allFriendRecords.filter { $0.odId == profile.id }.map(\.userId))
        cachedMutualFriendIds = myFollowing.intersection(myFollowers)
    }

    private func isUserPublicOrFriend(_ authorId: UUID) -> Bool {
        if authorId == profile.id { return true }
        if cachedMutualFriendIds.contains(authorId) { return true }
        return allUserProfiles.first { $0.id == authorId }?.isProfilePublic ?? true
    }

    private func refreshRankedPosts() {
        let media = allPosts.filter { post in
            (post.photoData != nil || post.videoData != nil || post.workoutType != nil)
            && isUserPublicOrFriend(post.authorId)
            && !(post.videoAspectRatio.map { $0 > 1.0 } ?? false)
        }
        cachedRankedPosts = FeedRankingService.shared.rankPosts(media, for: profile.id, interests: userInterests, category: selectedCategory ?? "All")
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if filteredPosts.isEmpty {
                    EmptyTikTokFeed(onCreatePost: { showCreatePost = true })
                } else {
                    feedContent(geometry: geometry)
                }

                // Top header overlay
                VStack(spacing: 0) {
                    categoryFilterPills
                    Spacer()
                }

                // Swipe-up tutorial overlay (first launch only)
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
        .sheet(isPresented: $showCreatePost) {
            CreatePostView(profile: profile)
        }
        .onAppear {
            if !hasSeeded {
                DiscoverSeeder.seedIfNeeded(modelContext: modelContext)
                hasSeeded = true
            }
            refreshMutualFriendIds()
            refreshRankedPosts()
            if !hasSeenTutorial && !cachedRankedPosts.isEmpty {
                showTutorial = true
            }
            EngagementTrackingService.shared.configure(modelContext: modelContext)
            EngagementTrackingService.shared.refreshPostScores()
        }
        .onChange(of: allPosts.count) { refreshRankedPosts() }
        .onChange(of: selectedCategory) { refreshRankedPosts() }
        .onChange(of: allFriendRecords.count) {
            refreshMutualFriendIds()
            refreshRankedPosts()
        }
    }

    // MARK: - Feed Content

    @ViewBuilder
    private func feedContent(geometry: GeometryProxy) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(Array(filteredPosts.enumerated()), id: \.element.id) { index, post in
                    TikTokPostCard(
                        post: post,
                        profile: profile,
                        screenHeight: geometry.size.height,
                        isVisible: index == (scrolledIndex ?? 0)
                    )
                    .frame(height: geometry.size.height)
                    .id(index)
                    .onAppear {
                        EngagementTrackingService.shared.trackPostAppeared(postId: post.id, userId: profile.id)
                    }
                    .onDisappear {
                        EngagementTrackingService.shared.trackPostDisappeared(postId: post.id, userId: profile.id)
                    }
                    .scrollTransition(.animated(.easeInOut(duration: 0.25))) { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0.4)
                    }
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrolledIndex)
        .ignoresSafeArea()
    }

    // MARK: - Category Filter Pills

    private var categoryFilterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    let isSelected = (selectedCategory ?? "All") == category
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            selectedCategory = category == "All" ? nil : category
                            scrolledIndex = 0
                        }
                    } label: {
                        Text(category)
                            .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                            .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                isSelected
                                    ? AnyShapeStyle(LinearGradient(
                                        colors: [GQColors.vividPurple, GQColors.cyanSpark],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                                    : AnyShapeStyle(Color.white.opacity(0.1))
                            )
                            .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .padding(.top, 4)
        }
        .background(
            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.5), location: 0),
                    .init(color: Color.black.opacity(0.25), location: 0.7),
                    .init(color: Color.clear, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: - Position Indicator

    private var positionIndicator: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Text("\((scrolledIndex ?? 0) + 1)/\(filteredPosts.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(10)
            }
            .padding(.trailing, 16)
            .padding(.bottom, 96)
        }
    }
}

// MARK: - TikTok Post Card (Full Screen)

struct TikTokPostCard: View {
    let post: Post
    let profile: UserProfile
    let screenHeight: CGFloat
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
    @State private var likeCount: Int = 0
    @State private var lastTapLocation: CGPoint = .zero
    @State private var isBookmarked = false
    @State private var isFollowing = false
    @State private var commentCount: Int = 0
    @State private var showingCopySheet = false

    private var sharedWorkout: SharedWorkoutData? {
        post.getSharedWorkout()
    }

    private var hasPlaylist: Bool {
        post.spotifyPlaylistURL != nil || post.appleMusicPlaylistURL != nil
    }

    var body: some View {
        ZStack {
            PostBackground(post: post, isVisible: isVisible)

            doubleTapOverlay

            if showHeartAnimation {
                FloatingHeart(at: lastTapLocation)
            }

            contentOverlay
        }
        .frame(height: screenHeight)
        .onAppear(perform: loadState)
        .sheet(isPresented: $showComments) {
            TikTokCommentsSheet(post: post, profile: profile, onCommentPosted: { commentCount += 1 })
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showShare) {
            TikTokShareSheet(
                post: post,
                isBookmarked: $isBookmarked,
                onSharePost: sharePost,
                onCopyLink: copyLink,
                onBookmarkToggle: toggleBookmark,
                onSharePlaylist: hasPlaylist ? { showPlaylistPreview = true } : nil
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showPlaylistPreview) {
            PlaylistPreviewSheet(
                workoutType: post.workoutType ?? "Workout",
                spotifyURL: post.spotifyPlaylistURL,
                appleMusicURL: post.appleMusicPlaylistURL
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog("Open Music", isPresented: $showMusicActions) {
            musicActionButtons
        }
        .sheet(isPresented: $showingCopySheet) {
            if let workout = sharedWorkout {
                WorkoutCopySheet(workoutData: workout, profile: profile)
            }
        }
    }

    // MARK: - Double Tap

    private var doubleTapOverlay: some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { location in
                lastTapLocation = location
                triggerLike()
            }
    }

    // MARK: - Content Overlay

    private var contentOverlay: some View {
        ZStack(alignment: .bottom) {
            // Invisible spacer to fill full card height
            Color.clear

            // Right side buttons — vertically centered
            HStack {
                Spacer()
                VStack {
                    Spacer()
                    rightSideButtons
                    Spacer()
                        .frame(height: 60)
                }
            }

            // Bottom info — full width, just above tab bar
            leftSideInfo
        }
    }

    // MARK: - Left Side Info

    private var leftSideInfo: some View {
        VStack(alignment: .leading, spacing: 5) {
            authorRow
            captionWithTags
            tiktokWorkoutOverlay
            musicTicker
        }
        .padding(.leading, 20)
        .padding(.trailing, 68)
        .padding(.bottom, 90)
    }

    @ViewBuilder
    private var tiktokWorkoutOverlay: some View {
        if let workout = sharedWorkout {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(workout.exercises.prefix(3).enumerated()), id: \.offset) { _, exercise in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 4, height: 4)
                        let setCount = exercise.sets.count
                        let topWeight = exercise.sets.map(\.weight).max() ?? 0
                        let topReps = exercise.sets.first?.reps ?? 0
                        if topWeight > 0 {
                            Text("\(exercise.name) — \(setCount)×\(topReps) @ \(Int(topWeight)) lbs")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.85))
                        } else {
                            Text("\(exercise.name) — \(setCount)×\(topReps)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                }
                if workout.exercises.count > 3 {
                    Text("+\(workout.exercises.count - 3) more exercises")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(Color.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private var authorRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(GQColors.primary)
                .frame(width: 30, height: 30)
                .overlay(
                    Text(String(post.authorName.prefix(1)).uppercased())
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text("@\(post.authorUsername)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                if let workoutType = post.workoutType {
                    Text(workoutType)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            if post.authorId != profile.id {
                followButton
            }
        }
    }

    private var followButton: some View {
        Button {
            toggleFollow()
        } label: {
            Text(isFollowing ? "Following" : "Follow")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isFollowing ? .white.opacity(0.7) : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isFollowing ? Color.white.opacity(0.1) : Color.white.opacity(0.15))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            isFollowing
                                ? AnyShapeStyle(Color.white.opacity(0.2))
                                : AnyShapeStyle(LinearGradient(
                                    colors: [GQColors.vividPurple, GQColors.cyanSpark],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )),
                            lineWidth: 1.4
                        )
                )
                .cornerRadius(4)
        }
    }

    @ViewBuilder
    private var captionText: some View {
        if !post.caption.isEmpty {
            Text(post.caption)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var captionWithTags: some View {
        if !post.caption.isEmpty {
            let cleanCaption = post.caption.split(separator: " ").filter { !$0.hasPrefix("#") }.joined(separator: " ")
            let hashtags = post.caption.split(separator: " ").filter { $0.hasPrefix("#") }

            (Text(cleanCaption)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.85))
            + Text(hashtags.isEmpty ? "" : " ")
            + Text(hashtags.joined(separator: " "))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(GQColors.cyanSpark))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var workoutStats: some View {
        if post.duration != nil || post.setCount != nil {
            HStack(spacing: 12) {
                if let duration = post.duration {
                    HStack(spacing: 3) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                        Text("\(duration)m")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                if let sets = post.setCount {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                        Text("\(sets) sets")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
            }
            .foregroundColor(.white.opacity(0.7))
        }
    }

    private var hashtagPills: some View {
        let hashtags = extractHashtags(from: post.caption)
        return Group {
            if !hashtags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(hashtags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(GQColors.cyanSpark)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(GQColors.cyanSpark.opacity(0.12))
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var musicTicker: some View {
        if let song = post.songTitle {
            MusicMarqueeTicker(songTitle: song, artistName: post.artistName)
                .onTapGesture {
                    if hasPlaylist {
                        showPlaylistPreview = true
                    } else {
                        showMusicActions = true
                    }
                }
        }
    }

    @ViewBuilder
    private var musicSection: some View {
        if let song = post.songTitle {
            VStack(alignment: .leading, spacing: 4) {
                MusicMarqueeTicker(songTitle: song, artistName: post.artistName)
                    .onTapGesture {
                        showMusicActions = true
                    }

                if hasPlaylist {
                    PlaylistPill(
                        spotifyURL: post.spotifyPlaylistURL,
                        appleMusicURL: post.appleMusicPlaylistURL
                    ) {
                        showPlaylistPreview = true
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var musicActionButtons: some View {
        if let spotifyURL = post.spotifyPlaylistURL {
            Button("Open in Spotify") {
                openURL(spotifyURL)
            }
        }
        if let appleMusicURL = post.appleMusicPlaylistURL {
            Button("Open in Apple Music") {
                openURL(appleMusicURL)
            }
        }
        Button("Cancel", role: .cancel) {}
    }

    // MARK: - Right Side Buttons

    private var rightSideButtons: some View {
        VStack(spacing: 22) {
            // Like button with long-press reaction picker
            ZStack(alignment: .leading) {
                if showReactionPicker {
                    ReactionPickerBubble(
                        postId: post.id,
                        profileId: profile.id,
                        profileUsername: profile.username,
                        onReact: { _ in
                            if !isLiked { triggerLike() }
                            showReactionPicker = false
                        },
                        onDismiss: { showReactionPicker = false }
                    )
                    .offset(x: -200, y: 0)
                    .transition(.scale(scale: 0.5, anchor: .trailing).combined(with: .opacity))
                }

                TikTokActionButton(
                    icon: isLiked ? "heart.fill" : "heart",
                    count: likeCount,
                    color: isLiked ? GQColors.primary : .white
                ) {
                    toggleLike()
                }
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.4)
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showReactionPicker.toggle()
                            }
                            #if canImport(UIKit)
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                            #endif
                        }
                )
            }

            // Comment button
            TikTokActionButton(
                icon: "bubble.right.fill",
                count: commentCount,
                color: .white
            ) {
                showComments = true
                EngagementTrackingService.shared.trackComment(postId: post.id, userId: profile.id)
            }

            // Share button
            TikTokActionButton(
                icon: "arrowshape.turn.up.right.fill",
                count: nil,
                color: .white
            ) {
                showShare = true
                EngagementTrackingService.shared.trackShare(postId: post.id, userId: profile.id)
            }

            // Bookmark
            TikTokActionButton(
                icon: isBookmarked ? "bookmark.fill" : "bookmark",
                count: nil,
                color: isBookmarked ? GQColors.cyanSpark : .white
            ) {
                toggleBookmark()
                EngagementTrackingService.shared.trackSave(postId: post.id, userId: profile.id)
            }
        }
        .padding(.trailing, 14)
        .padding(.bottom, 80)
    }

    // MARK: - Actions

    private func loadState() {
        likeCount = post.likeCount
        commentCount = post.commentCount
        isBookmarked = BookmarkStore.isBookmarked(post.id)

        // Check if already liked
        let postId = post.id
        let userId = profile.id
        let descriptor = FetchDescriptor<Like>(predicate: #Predicate { $0.postId == postId && $0.userId == userId })
        isLiked = ((try? modelContext.fetchCount(descriptor)) ?? 0) > 0

        // Check if following
        let authorId = post.authorId
        let myId = profile.id
        let friendDescriptor = FetchDescriptor<Friend>(predicate: #Predicate { $0.userId == myId && $0.odId == authorId })
        isFollowing = ((try? modelContext.fetchCount(friendDescriptor)) ?? 0) > 0
    }

    private func triggerLike() {
        if !isLiked {
            #if canImport(UIKit)
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            #endif

            isLiked = true
            likeCount += 1

            let like = Like(postId: post.id, userId: profile.id, userName: profile.name)
            modelContext.insert(like)
            post.likeCount = likeCount
            try? modelContext.save()
            EngagementTrackingService.shared.trackLike(postId: post.id, userId: profile.id)

            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                showHeartAnimation = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation { showHeartAnimation = false }
            }
        }
    }

    private func toggleLike() {
        if isLiked {
            // Unlike
            isLiked = false
            likeCount -= 1
            post.likeCount = likeCount

            let postId = post.id
            let userId = profile.id
            let descriptor = FetchDescriptor<Like>(predicate: #Predicate { $0.postId == postId && $0.userId == userId })
            if let likes = try? modelContext.fetch(descriptor) {
                for like in likes { modelContext.delete(like) }
            }
            try? modelContext.save()

            #if canImport(UIKit)
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            #endif
        } else {
            triggerLike()
        }
    }

    private func toggleBookmark() {
        isBookmarked = BookmarkStore.toggle(post.id)
        #if canImport(UIKit)
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        #endif
    }

    private func toggleFollow() {
        let authorId = post.authorId
        let myId = profile.id
        if isFollowing {
            let descriptor = FetchDescriptor<Friend>(predicate: #Predicate { $0.userId == myId && $0.odId == authorId })
            if let friends = try? modelContext.fetch(descriptor) {
                for friend in friends { modelContext.delete(friend) }
            }
            isFollowing = false
            // Update counts
            profile.followingCount = max(profile.followingCount - 1, 0)
            updateAuthorFollowerCount(authorId: authorId, delta: -1)
        } else {
            let friend = Friend(
                userId: profile.id,
                odId: post.authorId,
                odName: post.authorName,
                odUsername: post.authorUsername
            )
            modelContext.insert(friend)
            isFollowing = true
            EngagementTrackingService.shared.trackFollow(postId: post.id, userId: profile.id)
            // Update counts
            profile.followingCount += 1
            updateAuthorFollowerCount(authorId: authorId, delta: 1)
        }
        try? modelContext.save()

        #if canImport(UIKit)
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        #endif
    }

    private func updateAuthorFollowerCount(authorId: UUID, delta: Int) {
        let descriptor = FetchDescriptor<UserProfile>(predicate: #Predicate { $0.id == authorId })
        if let authorProfile = try? modelContext.fetch(descriptor).first {
            authorProfile.followerCount = max(authorProfile.followerCount + delta, 0)
        }
    }

    private func sharePost() {
        #if canImport(UIKit)
        let text = "\(post.authorName)'s \(post.workoutType ?? "workout") on Lift AI: \(post.caption)"
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
        #endif
    }

    private func copyLink() {
        #if canImport(UIKit)
        UIPasteboard.general.string = "liftai://post/\(post.id.uuidString)"
        #endif
    }

    private func openURL(_ urlString: String) {
        #if canImport(UIKit)
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
        #endif
    }

    private func extractHashtags(from text: String) -> [String] {
        let words = text.split(separator: " ")
        return words.filter { $0.hasPrefix("#") }.map { String($0) }
    }
}

// MARK: - Post Background

struct PostBackground: View {
    let post: Post
    var isVisible: Bool = true

    @State private var player: AVPlayer?
    @State private var isPlaying = true
    @State private var userPaused = false
    @State private var videoAspectRatio: CGFloat?

    var body: some View {
        Group {
            if let videoData = post.videoData, !videoData.isEmpty {
                videoContent(videoData: videoData)
            } else if let photoData = post.photoData {
                photoContent(photoData: photoData)
            } else {
                gradientBackground
            }
        }
        .overlay(readabilityGradient)
    }

    @ViewBuilder
    private func videoContent(videoData: Data) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = player {
                if let ratio = videoAspectRatio, ratio > 1.0 {
                    // Horizontal video — letterbox with fit
                    VideoPlayer(player: player)
                        .aspectRatio(ratio, contentMode: .fit)
                        .disabled(true)
                } else {
                    // Vertical or unknown — fill
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                        .disabled(true)
                }
            }

            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { togglePlayback() }

            if userPaused {
                Image(systemName: "play.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white.opacity(0.7))
                    .transition(.opacity)
            }
        }
        .onAppear { setupPlayer(with: videoData) }
        .onDisappear { teardownPlayer() }
        .onChange(of: isVisible) { _, visible in
            if visible && !userPaused {
                player?.play()
                isPlaying = true
            } else {
                player?.pause()
                if !visible {
                    player?.seek(to: .zero)
                }
                isPlaying = false
            }
        }
    }

    @ViewBuilder
    private func photoContent(photoData: Data) -> some View {
        #if canImport(UIKit)
        if let uiImage = UIImage(data: photoData) {
            let imageRatio = uiImage.size.width / uiImage.size.height
            if imageRatio > 1.0 {
                // Landscape photo — fit with black bars
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                    .ignoresSafeArea()
            } else {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
            }
        }
        #endif
    }

    private var gradientBackground: some View {
        LinearGradient(
            colors: [
                Color(hex: "1a1a2e"),
                Color(hex: "16213e"),
                Color(hex: "0f0f1a")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var readabilityGradient: some View {
        LinearGradient(
            stops: [
                .init(color: Color.black.opacity(0.15), location: 0),
                .init(color: Color.clear, location: 0.25),
                .init(color: Color.clear, location: 0.6),
                .init(color: Color.black.opacity(0.4), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func setupPlayer(with data: Data) {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(post.id.uuidString)
            .appendingPathExtension("mp4")
        try? data.write(to: tempURL)

        let asset = AVAsset(url: tempURL)

        // Detect aspect ratio
        Task {
            if let tracks = try? await asset.loadTracks(withMediaType: .video),
               let track = tracks.first {
                let size = try? await track.load(.naturalSize)
                let transform = try? await track.load(.preferredTransform)
                if let size = size, let transform = transform {
                    let transformed = size.applying(transform)
                    let width = abs(transformed.width)
                    let height = abs(transformed.height)
                    if height > 0 {
                        await MainActor.run {
                            videoAspectRatio = width / height
                        }
                    }
                }
            }
        }

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
        }
        player = avPlayer
        isPlaying = true
    }

    private func togglePlayback() {
        guard let player = player else { return }
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

    private func teardownPlayer() {
        player?.pause()
        player = nil
    }
}

// MARK: - Reaction Picker Bubble

struct ReactionPickerBubble: View {
    let postId: UUID
    let profileId: UUID
    let profileUsername: String
    let onReact: (ReactionType) -> Void
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ReactionType.allCases, id: \.self) { reaction in
                Button {
                    saveReaction(reaction)
                    onReact(reaction)
                } label: {
                    Text(reaction.emoji)
                        .font(.system(size: 28))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
    }

    private func saveReaction(_ type: ReactionType) {
        let reaction = Reaction(
            odId: profileId,
            odUsername: profileUsername,
            targetType: "post",
            targetId: postId,
            reactionType: type
        )
        modelContext.insert(reaction)
        try? modelContext.save()
    }
}

// MARK: - Playlist Pill

struct PlaylistPill: View {
    let spotifyURL: String?
    let appleMusicURL: String?
    let onTap: () -> Void

    private var isSpotify: Bool { spotifyURL != nil }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                if isSpotify {
                    SpotifyIcon(size: 14)
                } else {
                    AppleMusicIcon(size: 14)
                }

                Text("View Playlist")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.12))
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Playlist Preview Sheet

struct PlaylistPreviewSheet: View {
    let workoutType: String
    let spotifyURL: String?
    let appleMusicURL: String?

    @Environment(\.dismiss) private var dismiss

    private var isSpotify: Bool { spotifyURL != nil }
    private var serviceColor: Color { isSpotify ? Color(hex: "1DB954") : Color(hex: "FC3C44") }

    private var tracks: [(String, String)] {
        playlistTracks(for: workoutType)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    playlistHeader
                    trackList
                    openButtons
                }
            }
            .gqPageBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }

    // MARK: - Playlist Header

    private var playlistHeader: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [GQColors.vividPurple.opacity(0.8), serviceColor.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 160, height: 160)
                .overlay(
                    Image(systemName: "music.note.list")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.8))
                )
                .shadow(color: serviceColor.opacity(0.3), radius: 20, y: 8)

            Text("\(workoutType) Playlist")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)

            Text("\(tracks.count) tracks")
                .font(.system(size: 14))
                .foregroundColor(GQColors.textSecondary)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Track List

    private var trackList: some View {
        VStack(spacing: 0) {
            ForEach(Array(tracks.enumerated()), id: \.offset) { index, track in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(GQColors.textSecondary)
                        .frame(width: 24)

                    if index == 0 {
                        MusicEQBars(barCount: 3, barWidth: 2.5, maxHeight: 14, color: serviceColor, isPlaying: true)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.0)
                            .font(.system(size: 15, weight: index == 0 ? .semibold : .regular))
                            .foregroundColor(index == 0 ? serviceColor : .white)
                            .lineLimit(1)
                        Text(track.1)
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "ellipsis")
                        .font(.system(size: 14))
                        .foregroundColor(GQColors.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if index < tracks.count - 1 {
                    Divider()
                        .background(Color.white.opacity(0.05))
                        .padding(.leading, 52)
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Open Buttons

    private var openButtons: some View {
        VStack(spacing: 12) {
            if let spotifyURL = spotifyURL {
                openServiceButton(label: "Open in Spotify", icon: { SpotifyIcon(size: 20) }, color: Color(hex: "1DB954"), url: spotifyURL)
            }
            if let appleMusicURL = appleMusicURL {
                openServiceButton(label: "Open in Apple Music", icon: { AppleMusicIcon(size: 20) }, color: Color(hex: "FC3C44"), url: appleMusicURL)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
    }

    private func openServiceButton<Icon: View>(label: String, icon: () -> Icon, color: Color, url: String) -> some View {
        Button {
            #if canImport(UIKit)
            if let u = URL(string: url) {
                UIApplication.shared.open(u)
            }
            #endif
        } label: {
            HStack(spacing: 10) {
                icon()
                Text(label)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.4), lineWidth: 1)
            )
        }
    }

    // MARK: - Curated Track Lists

    private func playlistTracks(for type: String) -> [(String, String)] {
        switch type.lowercased() {
        case "push":
            return [
                ("Lose Yourself", "Eminem"),
                ("HUMBLE.", "Kendrick Lamar"),
                ("Stronger", "Kanye West"),
                ("Till I Collapse", "Eminem"),
                ("Power", "Kanye West"),
                ("Can't Hold Us", "Macklemore"),
                ("Remember The Name", "Fort Minor"),
                ("Eye of the Tiger", "Survivor"),
            ]
        case "pull":
            return [
                ("Sicko Mode", "Travis Scott"),
                ("DNA.", "Kendrick Lamar"),
                ("Jumpman", "Drake & Future"),
                ("Mask Off", "Future"),
                ("Black Skinhead", "Kanye West"),
                ("No Role Modelz", "J. Cole"),
                ("m.A.A.d city", "Kendrick Lamar"),
                ("Backseat Freestyle", "Kendrick Lamar"),
            ]
        case "legs":
            return [
                ("Run This Town", "JAY-Z"),
                ("All I Do Is Win", "DJ Khaled"),
                ("We Ready", "Archie Eversole"),
                ("Pump It", "The Black Eyed Peas"),
                ("Stronger", "Kanye West"),
                ("Work", "Rihanna"),
                ("Started From The Bottom", "Drake"),
                ("Harder Better Faster", "Daft Punk"),
            ]
        case "cardio":
            return [
                ("Blinding Lights", "The Weeknd"),
                ("Levitating", "Dua Lipa"),
                ("Sunset Lover", "Petit Biscuit"),
                ("Don't Start Now", "Dua Lipa"),
                ("Physical", "Dua Lipa"),
                ("Running Up That Hill", "Kate Bush"),
                ("Break My Stride", "Matthew Wilder"),
                ("Unstoppable", "Sia"),
            ]
        default:
            return [
                ("Lose Yourself", "Eminem"),
                ("Stronger", "Kanye West"),
                ("Till I Collapse", "Eminem"),
                ("Eye of the Tiger", "Survivor"),
                ("Power", "Kanye West"),
                ("HUMBLE.", "Kendrick Lamar"),
            ]
        }
    }
}

// MARK: - TikTok Action Button

struct TikTokActionButton: View {
    let icon: String
    let count: Int?
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation { isPressed = false }
            }
        }) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(color)
                    .scaleEffect(isPressed ? 1.2 : 1.0)

                if let count = count, count > 0 {
                    Text(formatCount(count))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1000000 {
            return String(format: "%.1fM", Double(count) / 1000000)
        } else if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000)
        }
        return "\(count)"
    }
}

// MARK: - Floating Heart Animation

struct FloatingHeart: View {
    let at: CGPoint

    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 1
    @State private var yOffset: CGFloat = 0

    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 100))
            .foregroundColor(GQColors.primary)
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(y: yOffset)
            .position(at)
            .onAppear {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    scale = 1
                }
                withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                    yOffset = -50
                    opacity = 0
                }
            }
    }
}

// MARK: - TikTok Comments Sheet

struct TikTokCommentsSheet: View {
    let post: Post
    let profile: UserProfile
    var onCommentPosted: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allComments: [Comment]
    @State private var newComment = ""
    @FocusState private var isCommentFocused: Bool

    var comments: [Comment] {
        allComments.filter { $0.postId == post.id }.sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("\(comments.count) comments")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()
                    .background(Color.white.opacity(0.1))

                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(comments) { comment in
                            TikTokCommentRow(comment: comment)
                        }
                    }
                    .padding(16)
                }

                commentInput
            }
            .gqPageBackground()
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var commentInput: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(GQColors.primary)
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(profile.name.prefix(1)).uppercased())
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                )

            TextField("Add comment...", text: $newComment)
                .font(.system(size: 15))
                .focused($isCommentFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(GQColors.surfaceOverlay.opacity(0.82))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(GQGradients.glassBorder, lineWidth: 0.8)
                )

            if !newComment.isEmpty {
                Button {
                    postComment()
                } label: {
                    Text("Post")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(GQColors.primary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(GQColors.surfaceBase.opacity(0.88))
    }

    private func postComment() {
        guard !newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let comment = Comment(
            postId: post.id,
            authorId: profile.id,
            authorName: profile.name,
            authorUsername: profile.username,
            content: newComment
        )

        modelContext.insert(comment)
        post.commentCount += 1
        try? modelContext.save()

        onCommentPosted?()
        newComment = ""
        isCommentFocused = false

        #if canImport(UIKit)
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        #endif
    }
}

// MARK: - TikTok Comment Row

struct TikTokCommentRow: View {
    let comment: Comment
    @State private var isLiked = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(GQColors.elevatedSurface)
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(comment.authorName.prefix(1)).uppercased())
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(comment.authorName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)

                    Text(comment.timestamp.timeAgoDisplay())
                        .font(.system(size: 12))
                        .foregroundColor(GQColors.textSecondary)
                }

                Text(comment.content)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.9))

                Button {
                    // Reply action
                } label: {
                    Text("Reply")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(GQColors.textSecondary)
                }
                .padding(.top, 4)
            }

            Spacer()

            Button {
                withAnimation { isLiked.toggle() }
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 14))
                        .foregroundColor(isLiked ? GQColors.primary : GQColors.textSecondary)
                }
            }
        }
    }
}

// MARK: - TikTok Share Sheet

struct TikTokShareSheet: View {
    let post: Post
    @Binding var isBookmarked: Bool
    var onSharePost: () -> Void
    var onCopyLink: () -> Void
    var onBookmarkToggle: () -> Void
    var onSharePlaylist: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var showReportConfirmation = false

    var body: some View {
        VStack(spacing: 20) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 12)

            Text("Share")
                .font(.system(size: 16, weight: .semibold))

            shareGrid

            Spacer()
        }
        .gqPageBackground()
        .alert("Post Reported", isPresented: $showReportConfirmation) {
            Button("OK") { dismiss() }
        } message: {
            Text("Thank you for your report. We'll review this post.")
        }
    }

    private var shareGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
            shareButton(title: "Share Post", icon: "square.and.arrow.up") {
                onSharePost()
                dismiss()
            }

            if post.getSharedWorkout() != nil {
                shareButton(title: "Share Workout", icon: "figure.run") {
                    onSharePost()
                    dismiss()
                }
            }

            if onSharePlaylist != nil {
                shareButton(title: "Share Playlist", icon: "music.note.list") {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onSharePlaylist?()
                    }
                }
            }

            shareButton(title: "Copy Link", icon: "link") {
                onCopyLink()
                dismiss()
            }

            shareButton(title: isBookmarked ? "Saved" : "Save", icon: isBookmarked ? "bookmark.fill" : "bookmark") {
                onBookmarkToggle()
            }

            shareButton(title: "Report", icon: "exclamationmark.triangle") {
                showReportConfirmation = true
            }
        }
        .padding(.horizontal, 24)
    }

    private func shareButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Circle()
                    .fill(GQColors.cardBackground)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                    )

                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(GQColors.textSecondary)
            }
        }
    }
}

// MARK: - Empty TikTok Feed

struct EmptyTikTokFeed: View {
    let onCreatePost: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 100)

            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.3))

            VStack(spacing: 8) {
                Text("No posts yet")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("Share your first post with the community")
                    .font(.subheadline)
                    .foregroundColor(GQColors.textTertiary)
                    .multilineTextAlignment(.center)
            }

            Button("Create Post") {
                onCreatePost()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(GQColors.textPrimary)
            .frame(width: 160, height: 48)
            .background(GQColors.cardBackground)
            .cornerRadius(24)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Music Marquee Ticker

struct MusicMarqueeTicker: View {
    let songTitle: String
    let artistName: String?

    @State private var scrollOffset: CGFloat = 0

    private var displayText: String {
        if let artist = artistName {
            return "\(songTitle) - \(artist)"
        }
        return songTitle
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "music.note")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))

            Text(displayText)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Discover Tutorial Overlay

struct DiscoverTutorialOverlay: View {
    let onDismiss: () -> Void

    @State private var chevronOffset: CGFloat = 0
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                Image(systemName: "chevron.up")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
                    .offset(y: chevronOffset)

                Text("Swipe up to discover\nmore workouts")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Button {
                    onDismiss()
                } label: {
                    Text("Got it")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 10)
                        .background(GQColors.cardBackground)
                        .cornerRadius(20)
                }
                .padding(.top, 8)

                Spacer()
                    .frame(height: 120)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.4)) {
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
        .opacity(opacity)
    }
}

// MARK: - Preview

#Preview {
    TikTokFeedView(profile: UserProfile(name: "Ben", username: "ben"))
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
