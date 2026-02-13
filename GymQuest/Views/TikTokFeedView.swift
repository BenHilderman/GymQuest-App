//
//  TikTokFeedView.swift
//  GymQuest
//
//  TikTok-style vertical scrolling feed with full-screen posts
//  Features: Double-tap to like, side action buttons, auto-scroll,
//  addictive engagement patterns for retention
//

import SwiftUI
import SwiftData
import AVKit

// MARK: - TikTok Style Feed

struct TikTokFeedView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Post.timestamp, order: .reverse) private var posts: [Post]

    let profile: UserProfile

    @State private var currentIndex = 0
    @State private var showCreatePost = false
    @State private var selectedCategory: String? = nil

    private let categories = ["All", "Push", "Pull", "Legs", "Cardio", "PR Moments", "Form Tips", "Music"]

    var filteredPosts: [Post] {
        guard let category = selectedCategory, category != "All" else { return posts.map { $0 } }
        if category == "PR Moments" {
            return posts.filter { $0.caption.lowercased().contains("pr") || $0.caption.contains("🏆") }
        }
        if category == "Music" {
            return posts.filter { $0.songTitle != nil }
        }
        if category == "Form Tips" {
            return posts.filter { $0.caption.lowercased().contains("form") || $0.caption.lowercased().contains("tip") }
        }
        return posts.filter { $0.workoutType?.lowercased() == category.lowercased() }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if filteredPosts.isEmpty {
                    EmptyTikTokFeed(onCreatePost: { showCreatePost = true })
                } else {
                    // Vertical paging TabView - TikTok style
                    TabView(selection: $currentIndex) {
                        ForEach(Array(filteredPosts.enumerated()), id: \.element.id) { index, post in
                            TikTokPostCard(
                                post: post,
                                profile: profile,
                                screenHeight: geometry.size.height
                            )
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .ignoresSafeArea()
                }

                // Top header overlay with category filters
                VStack(spacing: 0) {
                    categoryFilterPills
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showCreatePost) {
            CreatePostView(profile: profile)
        }
    }

    private var categoryFilterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    let isSelected = (selectedCategory ?? "All") == category
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            selectedCategory = category == "All" ? nil : category
                            currentIndex = 0
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
        }
    }
}

// MARK: - TikTok Post Card (Full Screen)

struct TikTokPostCard: View {
    let post: Post
    let profile: UserProfile
    let screenHeight: CGFloat

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @State private var isLiked = false
    @State private var showHeartAnimation = false
    @State private var showComments = false
    @State private var showShare = false
    @State private var likeCount: Int = 0
    @State private var lastTapLocation: CGPoint = .zero

    private var sharedWorkout: SharedWorkoutData? {
        post.getSharedWorkout()
    }

    var body: some View {
        ZStack {
            // Background content (image or video)
            PostBackground(post: post)

            // Double-tap overlay for like
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { location in
                    lastTapLocation = location
                    triggerLike()
                }

            // Floating heart animation
            if showHeartAnimation {
                FloatingHeart(at: lastTapLocation)
            }

            // Content overlay
            HStack(alignment: .bottom) {
                // Left side - Post info
                VStack(alignment: .leading, spacing: 12) {
                    Spacer()

                    // Author info
                    HStack(spacing: 10) {
                        Circle()
                            .fill(GQColors.primary)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(String(post.authorName.prefix(1)).uppercased())
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text("@\(post.authorUsername)")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)

                            if let workoutType = post.workoutType {
                                Text(workoutType)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }

                        // Follow button
                        if post.authorId != profile.id {
                            Button {
                                // Follow action
                            } label: {
                                Text("Follow")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(GQColors.surfaceBase)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [GQColors.vividPurple, GQColors.cyanSpark],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                ),
                                                lineWidth: 1.4
                                            )
                                    )
                                    .cornerRadius(4)
                            }
                        }
                    }

                    // Caption
                    if !post.caption.isEmpty {
                        Text(post.caption)
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .frame(maxWidth: 280, alignment: .leading)
                    }

                    // Workout stats
                    if post.duration != nil || post.setCount != nil {
                        HStack(spacing: 16) {
                            if let duration = post.duration {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock.fill")
                                        .font(.system(size: 12))
                                    Text("\(duration)m")
                                        .font(.system(size: 13, weight: .medium))
                                }
                            }
                            if let sets = post.setCount {
                                HStack(spacing: 4) {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 12))
                                    Text("\(sets) sets")
                                        .font(.system(size: 13, weight: .medium))
                                }
                            }
                        }
                        .foregroundColor(.white.opacity(0.9))
                    }

                    // Hashtag pills (extracted from caption)
                    hashtagPills

                    // Music marquee ticker (like TikTok)
                    if let song = post.songTitle {
                        MusicMarqueeTicker(
                            songTitle: song,
                            artistName: post.artistName
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)

                // Right side - Action buttons (TikTok style)
                VStack(spacing: 20) {
                    Spacer()

                    // Like button
                    TikTokActionButton(
                        icon: isLiked ? "heart.fill" : "heart",
                        count: likeCount,
                        color: isLiked ? GQColors.primary : .white
                    ) {
                        triggerLike()
                    }

                    // Comment button
                    TikTokActionButton(
                        icon: "bubble.right.fill",
                        count: post.commentCount,
                        color: .white
                    ) {
                        showComments = true
                    }

                    // Share button
                    TikTokActionButton(
                        icon: "arrowshape.turn.up.right.fill",
                        count: 0,
                        color: .white
                    ) {
                        showShare = true
                    }

                    // Bookmark
                    TikTokActionButton(
                        icon: "bookmark.fill",
                        count: nil,
                        color: .white
                    ) {
                        // Save action
                    }

                    // Follow Workout (only when post has shared workout data)
                    if sharedWorkout != nil {
                        TikTokActionButton(
                            icon: "figure.run",
                            count: nil,
                            color: GQColors.cyanSpark
                        ) {
                            if let workout = sharedWorkout {
                                let exercises = workout.toActiveExercises()
                                let workoutType = WorkoutType(rawValue: workout.workoutType) ?? .push
                                appState.startWorkout(type: workoutType, exercises: exercises)
                                appState.selectedTab = .home
                            }
                        }
                    }
                }
                .padding(.trailing, 12)
                .padding(.bottom, 100)
            }
        }
        .frame(height: screenHeight)
        .onAppear {
            likeCount = post.likeCount
        }
        .sheet(isPresented: $showComments) {
            TikTokCommentsSheet(
                post: post,
                profile: profile
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showShare) {
            TikTokShareSheet(post: post)
                .presentationDetents([.medium])
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
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(GQColors.cyanSpark)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(GQColors.cyanSpark.opacity(0.15))
                                .cornerRadius(10)
                        }
                    }
                }
            }
        }
    }

    private func extractHashtags(from text: String) -> [String] {
        let words = text.split(separator: " ")
        return words.filter { $0.hasPrefix("#") }.map { String($0) }
    }

    private func triggerLike() {
        if !isLiked {
            // Haptic feedback
            #if canImport(UIKit)
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            #endif

            isLiked = true
            likeCount += 1

            // Save like
            let like = Like(postId: post.id, userId: profile.id, userName: profile.name)
            modelContext.insert(like)
            post.likeCount = likeCount
            try? modelContext.save()

            // Show heart animation
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                showHeartAnimation = true
            }

            // Hide after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation {
                    showHeartAnimation = false
                }
            }
        }
    }
}

// MARK: - Post Background

struct PostBackground: View {
    let post: Post
    @State private var player: AVPlayer?
    @State private var isPlaying = true

    var body: some View {
        Group {
            if let videoData = post.videoData, !videoData.isEmpty {
                // Video post — autoplay, loop, muted
                ZStack {
                    if let player = player {
                        VideoPlayer(player: player)
                            .ignoresSafeArea()
                            .disabled(true) // Disable default controls
                    } else {
                        Color.black.ignoresSafeArea()
                    }

                    // Play/pause tap overlay
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            togglePlayback()
                        }

                    // Pause icon flash
                    if !isPlaying {
                        Image(systemName: "play.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white.opacity(0.7))
                            .transition(.opacity)
                    }
                }
                .onAppear { setupPlayer(with: videoData) }
                .onDisappear { teardownPlayer() }
            } else if let photoData = post.photoData {
                #if canImport(UIKit)
                if let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .ignoresSafeArea()
                }
                #endif
            } else {
                // Gradient background for text-only posts
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
        }
        .overlay(
            // Dark gradient overlay for readability
            LinearGradient(
                colors: [
                    Color.black.opacity(0.3),
                    Color.clear,
                    Color.clear,
                    Color.black.opacity(0.7)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func setupPlayer(with data: Data) {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(post.id.uuidString)
            .appendingPathExtension("mp4")
        try? data.write(to: tempURL)
        let avPlayer = AVPlayer(url: tempURL)
        avPlayer.isMuted = true
        avPlayer.play()
        // Loop playback
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
        } else {
            player.play()
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
                withAnimation {
                    isPressed = false
                }
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(color)
                    .scaleEffect(isPressed ? 1.3 : 1.0)

                if let count = count, count > 0 {
                    Text(formatCount(count))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
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
                // Comments count header
                HStack {
                    Text("\(comments.count) comments")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()
                    .background(Color.white.opacity(0.1))

                // Comments list
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(comments) { comment in
                            TikTokCommentRow(comment: comment)
                        }
                    }
                    .padding(16)
                }

                // Comment input
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
            .gqPageBackground()
            .navigationBarTitleDisplayMode(.inline)
        }
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

        newComment = ""
        isCommentFocused = false

        // Haptic
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

                // Reply button
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

            // Like comment
            Button {
                withAnimation {
                    isLiked.toggle()
                }
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
    @Environment(\.dismiss) private var dismiss

    let shareOptions = [
        ("Send to", "paperplane.fill"),
        ("Repost", "arrow.2.squarepath"),
        ("Save", "bookmark.fill"),
        ("Copy link", "link"),
        ("Share to...", "square.and.arrow.up")
    ]

    var body: some View {
        VStack(spacing: 20) {
            // Handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 12)

            Text("Share")
                .font(.system(size: 16, weight: .semibold))

            // Share options
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                ForEach(shareOptions, id: \.0) { option in
                    Button {
                        // Share action
                        dismiss()
                    } label: {
                        VStack(spacing: 8) {
                            Circle()
                                .fill(GQColors.cardBackground)
                                .frame(width: 56, height: 56)
                                .overlay(
                                    Image(systemName: option.1)
                                        .font(.system(size: 22))
                                        .foregroundColor(.white)
                                )

                            Text(option.0)
                                .font(.system(size: 11))
                                .foregroundColor(GQColors.textSecondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .gqPageBackground()
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
            .foregroundColor(.black)
            .frame(width: 160, height: 48)
            .background(Color.white)
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
        HStack(spacing: 10) {
            // Spinning disc icon
            Image(systemName: "opticaldisc.fill")
                .font(.system(size: 14))
                .foregroundColor(.white)
                .rotationEffect(.degrees(scrollOffset * 2))

            // Scrolling text
            Text(displayText)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .offset(x: scrollOffset)
        }
        .frame(maxWidth: 220, alignment: .leading)
        .clipped()
        .onAppear {
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: true)) {
                scrollOffset = -30
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TikTokFeedView(profile: UserProfile(name: "Ben", username: "ben"))
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
