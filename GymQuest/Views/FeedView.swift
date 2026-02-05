//
//  FeedView.swift
//  GymQuest
//
//  Created by Benjamin Hilderman
//
//  Bold & Energetic social feed with glass morphism
//  Filter pills, workout posts, PRs, learning content
//

import SwiftUI
import SwiftData
import AVKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Feed Tab

enum FeedTab: String, CaseIterable {
    case friends = "Friends"
    case discover = "Discover"
    case communities = "Communities"
}

struct FeedView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var featureFlags: FeatureFlags
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Post.timestamp, order: .reverse) private var posts: [Post]
    @Query(sort: \PRMoment.createdAt, order: .reverse) private var prMoments: [PRMoment]
    @Query(sort: \LearningItem.createdAt, order: .reverse) private var learningItems: [LearningItem]

    let profile: UserProfile

    @State private var selectedTab: FeedTab = .friends
    @State private var showLearnPanel = false
    @State private var selectedExerciseForLearn: String?

    // Friends posts (from people you follow)
    var friendsPosts: [Post] {
        posts.filter { $0.authorId != profile.id }
    }

    // Discovery posts (could be trending/popular)
    var discoverPosts: [Post] {
        posts
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Friends / Discover tabs
                FeedTabsView(selectedTab: $selectedTab)

                // Content based on selected tab
                if selectedTab == .communities {
                    CommunityFeedView(profile: profile)
                } else if selectedTab == .discover {
                    // TikTok-style full screen feed for Discover
                    TikTokFeedView(profile: profile)
                        .ignoresSafeArea()
                } else {
                    // Traditional feed for Friends
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if friendsPosts.isEmpty {
                                EmptyFeedView(onCreatePost: { appState.showingLogWorkout = true })
                            } else {
                                ForEach(friendsPosts) { post in
                                    PostCardV2(
                                        post: post,
                                        currentUserId: profile.id,
                                        currentUserName: profile.name,
                                        onLearnThis: { exerciseName in
                                            selectedExerciseForLearn = exerciseName
                                            showLearnPanel = true
                                        }
                                    )

                                    Rectangle()
                                        .fill(Color.white.opacity(0.08))
                                        .frame(height: 8)
                                }
                            }
                        }
                        .padding(.bottom, 100)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(EnergyBackground())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavBarLogo()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showLearnPanel) {
                if let exerciseName = selectedExerciseForLearn {
                    LearnThisPanel(
                        exerciseName: exerciseName,
                        learningItems: learningItems.filter { $0.exerciseName == exerciseName },
                        profile: profile,
                        onAddToPlan: { item in
                            addLearningToPlan(item)
                            showLearnPanel = false
                        },
                        onClose: { showLearnPanel = false }
                    )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
            }
        }
    }

    private func addLearningToPlan(_ item: LearningItem) {
        // Create or update learning progress
        let progress = LearningProgress(
            odId: profile.id,
            learningItemId: item.id,
            viewed: true,
            addedToPlan: true,
            viewedAt: Date()
        )
        modelContext.insert(progress)

        // Track analytics
        AnalyticsService.shared.trackLearningItemViewed(
            userId: profile.id,
            itemId: item.id,
            exerciseName: item.exerciseName
        )

        try? modelContext.save()
    }
}

// MARK: - Feed Tabs (Friends / Discover)

struct FeedTabsView: View {
    @Binding var selectedTab: FeedTab
    @Namespace private var tabNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(FeedTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 8) {
                        Text(tab.rawValue)
                            .font(.system(size: 16, weight: selectedTab == tab ? .semibold : .medium))
                            .foregroundColor(selectedTab == tab ? .white : GQColors.textTertiary)

                        // Sliding underline indicator
                        ZStack {
                            // Invisible spacer to maintain layout
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: 2)

                            // Animated underline
                            if selectedTab == tab {
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [GQColors.vividPurple, GQColors.cyanSpark],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(height: 2)
                                    .cornerRadius(1)
                                    .matchedGeometryEffect(id: "underline", in: tabNamespace)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Color(white: 0.05))
    }
}

// MARK: - Enhanced Post Card

struct PostCardV2: View {
    let post: Post
    let currentUserId: UUID
    var currentUserName: String = ""
    let onLearnThis: (String) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var isLiked = false
    @State private var showVideoPlayer = false
    @State private var showComments = false
    @State private var hasAppeared = false
    @State private var isPlayingMusic = false
    @State private var showWorkoutDetail = false
    @State private var showFollowWorkout = false

    // Computed activity type from detected activity
    var detectedActivityType: DetectedActivity? {
        guard let activity = post.detectedActivity else { return nil }
        return DetectedActivity(rawValue: activity)
    }

    // Check if post has shareable workout
    var sharedWorkout: SharedWorkoutData? {
        post.getSharedWorkout()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with delete option if own post
            HStack {
                PostHeaderEnhanced(post: post, activityType: detectedActivityType)

                if post.authorId == currentUserId {
                    PostDeleteButton {
                        deletePost()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Inspired by badge (if this workout was copied)
            if let inspiredBy = post.inspiredByUsername {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11))
                    Text("Inspired by @\(inspiredBy)")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(GQColors.cyanSpark)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(GQColors.cyanSpark.opacity(0.1))
                .cornerRadius(16)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            // Caption
            if !post.caption.isEmpty {
                Text(post.caption)
                    .font(.system(size: 15))
                    .foregroundColor(GQColors.textPrimary)
                    .lineSpacing(2)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            // Tagged users, location, and squads
            PostTagsRow(post: post)

            // Media (photo or video) with activity badge overlay - EDGE TO EDGE
            ZStack(alignment: .topTrailing) {
                PostMediaView(post: post, showVideoPlayer: $showVideoPlayer)

                // Activity badge overlay on image
                if let activity = detectedActivityType, post.photoData != nil || post.videoData != nil {
                    ActivityBadge(activityType: activity)
                        .padding(12)
                }
            }

            // Music display (TikTok/Instagram style)
            if let songTitle = post.songTitle, let artistName = post.artistName {
                MusicBadge(
                    songTitle: songTitle,
                    artistName: artistName,
                    isPlaying: isPlayingMusic,
                    onTap: {
                        isPlayingMusic.toggle()
                    }
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

            // Workout stats
            if post.duration != nil || post.setCount != nil {
                WorkoutStatsBarEnhanced(duration: post.duration, setCount: post.setCount)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
            }

            // Follow Workout Button (if workout data available)
            if sharedWorkout != nil {
                FollowWorkoutButton {
                    showWorkoutDetail = true
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

            // Actions row with "Learn this" button
            PostActionsRowAnimated(
                post: post,
                isLiked: $isLiked,
                showComments: $showComments,
                onLearnThis: post.workoutType != nil ? {
                    if let highlight = post.exerciseHighlight {
                        onLearnThis(highlight)
                    }
                } : nil,
                currentUserId: currentUserId,
                currentUserName: currentUserName
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(white: 0.05))
        .overlay(
            Rectangle()
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        // Post entry animation
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                hasAppeared = true
            }
        }
        .fullScreenCover(isPresented: $showVideoPlayer) {
            if let videoData = post.videoData {
                VideoPlayerView(videoData: videoData, isPresented: $showVideoPlayer)
            }
        }
        .sheet(isPresented: $showComments) {
            CommentsSheet(
                post: post,
                currentUserId: currentUserId,
                currentUserName: currentUserName
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showWorkoutDetail) {
            if let workout = sharedWorkout {
                WorkoutDetailSheet(workoutData: workout) {
                    showWorkoutDetail = false
                    showFollowWorkout = true
                }
            }
        }
        .fullScreenCover(isPresented: $showFollowWorkout) {
            if let workout = sharedWorkout {
                FollowWorkoutView(
                    workoutData: workout,
                    profile: UserProfile()
                )
            }
        }
    }

    private func deletePost() {
        modelContext.delete(post)
        try? modelContext.save()
    }
}

// MARK: - Follow Workout Button

struct FollowWorkoutButton: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: "figure.run")
                    .font(.system(size: 16, weight: .semibold))

                Text("Follow This Workout")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
            .foregroundColor(.white.opacity(0.8))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(white: 0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [GQColors.vividPurple, GQColors.cyanSpark],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Enhanced Post Header

struct PostHeaderEnhanced: View {
    let post: Post
    let activityType: DetectedActivity?

    var body: some View {
        HStack(spacing: 12) {
            // Simple avatar
            Circle()
                .fill(GQGradients.primary)
                .frame(width: 42, height: 42)
                .overlay(
                    Text(String(post.authorName.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(post.authorName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)

                    Text("@\(post.authorUsername)")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }

                Text(post.timestamp.timeAgoDisplay())
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }

            Spacer()

            // Workout type badge
            if activityType == nil, let workoutType = post.workoutType {
                Text(workoutType)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(GQColors.accent.opacity(0.3))
                    .cornerRadius(12)
            }
        }
    }
}

// MARK: - Enhanced Workout Stats Bar

struct WorkoutStatsBarEnhanced: View {
    let duration: Int?
    let setCount: Int?

    var body: some View {
        HStack(spacing: 16) {
            if let duration = duration, duration > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.accent)
                    Text("\(duration) min")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
            }

            if let sets = setCount, sets > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.success)
                    Text("\(sets) sets")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

struct PostHeader: View {
    let post: Post

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(LinearGradient(colors: [GQColors.vividPurple, GQColors.cyanSpark], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 42, height: 42)
                .overlay(
                    Text(String(post.authorName.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(post.authorName)
                        .font(.system(size: 15, weight: .semibold))

                    Text("@\(post.authorUsername)")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }

                Text(post.timestamp.timeAgoDisplay())
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }

            Spacer()

            if let workoutType = post.workoutType {
                Text(workoutType)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(GQColors.vividPurple.opacity(0.3))
                    .cornerRadius(12)
            }
        }
    }
}

struct PostMediaView: View {
    let post: Post
    @Binding var showVideoPlayer: Bool
    @State private var imageScale: CGFloat = 1.0
    @State private var showFullScreen = false

    var body: some View {
        Group {
            if let photoData = post.photoData {
                #if canImport(UIKit)
                if let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(minHeight: 350, maxHeight: 500)
                        .clipped()
                        .scaleEffect(imageScale)
                        .onTapGesture(count: 2) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                imageScale = imageScale == 1.0 ? 1.1 : 1.0
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    imageScale = 1.0
                                }
                            }
                        }
                        .onLongPressGesture {
                            showFullScreen = true
                        }
                        .fullScreenCover(isPresented: $showFullScreen) {
                            FullScreenImageView(image: uiImage, isPresented: $showFullScreen)
                        }
                }
                #elseif canImport(AppKit)
                if let nsImage = NSImage(data: photoData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(minHeight: 350, maxHeight: 500)
                        .clipped()
                }
                #endif
            } else if post.videoData != nil {
                VideoThumbnailView(videoData: post.videoData!, showVideoPlayer: $showVideoPlayer)
            }
        }
    }
}

struct WorkoutStatsBar: View {
    let duration: Int?
    let setCount: Int?

    var body: some View {
        HStack(spacing: 20) {
            if let duration = duration {
                Label("\(duration) min", systemImage: "clock")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }

            if let sets = setCount {
                Label("\(sets) sets", systemImage: "flame")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
        }
    }
}

struct PostActionsRow: View {
    let post: Post
    @Binding var isLiked: Bool
    @Binding var showComments: Bool
    let onLearnThis: (() -> Void)?

    var body: some View {
        HStack(spacing: 20) {
            // Like
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isLiked.toggle()
                    post.likeCount += isLiked ? 1 : -1
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 22))
                        .foregroundColor(isLiked ? .red : .white)
                    if post.likeCount > 0 {
                        Text("\(post.likeCount)")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }
            }
            .buttonStyle(.plain)

            // Comments
            Button {
                showComments = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 20))
                    if post.commentCount > 0 {
                        Text("\(post.commentCount)")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.white)

            // Learn This (if workout post)
            if let onLearn = onLearnThis {
                Button(action: onLearn) {
                    HStack(spacing: 4) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 14))
                        Text("Learn")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.cyan.opacity(0.15))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Share
            Button {
                // Share action
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 20))
            }
            .buttonStyle(.plain)
            .foregroundColor(.white)
        }
        .padding(.top, 4)
    }
}

// MARK: - Enhanced Post Actions with Animations

struct PostActionsRowAnimated: View {
    let post: Post
    @Binding var isLiked: Bool
    @Binding var showComments: Bool
    let onLearnThis: (() -> Void)?
    var currentUserId: UUID = UUID()
    var currentUserName: String = ""

    @Environment(\.modelContext) private var modelContext
    @State private var heartScale: CGFloat = 1.0
    @State private var showParticles = false
    @State private var displayedLikeCount: Int = 0
    @State private var displayedCommentCount: Int = 0

    var body: some View {
        HStack(spacing: 20) {
            // Animated Like Button
            Button {
                performLikeAnimation()
            } label: {
                ZStack {
                    // Particle effects
                    if showParticles {
                        HeartParticles()
                    }

                    HStack(spacing: 6) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 22))
                            .foregroundColor(isLiked ? .red : .white)
                            .scaleEffect(heartScale)

                        // Animated counter
                        if displayedLikeCount > 0 {
                            AnimatedCounter(value: displayedLikeCount)
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            // Comments with animated counter
            Button {
                showComments = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 20))

                    if displayedCommentCount > 0 {
                        AnimatedCounter(value: displayedCommentCount)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.white)

            // Learn This (if workout post)
            if let onLearn = onLearnThis {
                Button(action: onLearn) {
                    HStack(spacing: 4) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 14))
                        Text("Learn")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.cyan.opacity(0.15))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Share
            Button {
                // Share action
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 20))
            }
            .buttonStyle(.plain)
            .foregroundColor(.white)
        }
        .padding(.top, 4)
        .onAppear {
            displayedLikeCount = post.likeCount
            displayedCommentCount = post.commentCount
            checkIfLiked()
        }
    }

    private func performLikeAnimation() {
        let wasLiked = isLiked

        // Toggle like state
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isLiked.toggle()
            post.likeCount += isLiked ? 1 : -1
        }

        // Persist the like/unlike to database
        if isLiked {
            // Create new Like record
            let like = Like(
                postId: post.id,
                userId: currentUserId,
                userName: currentUserName
            )
            modelContext.insert(like)
        } else {
            // Remove existing Like record
            let postId = post.id
            let userId = currentUserId
            let descriptor = FetchDescriptor<Like>(
                predicate: #Predicate { $0.postId == postId && $0.userId == userId }
            )
            if let existingLikes = try? modelContext.fetch(descriptor) {
                for like in existingLikes {
                    modelContext.delete(like)
                }
            }
        }
        try? modelContext.save()

        // Heart scale burst animation
        withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
            heartScale = 1.3
        }

        // Reset heart scale after burst
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                heartScale = 1.0
            }
        }

        // Show particles only when liking (not unliking)
        if !wasLiked {
            showParticles = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                showParticles = false
            }
        }

        // Update displayed count with animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            displayedLikeCount = post.likeCount
        }
    }

    private func checkIfLiked() {
        let postId = post.id
        let userId = currentUserId
        let descriptor = FetchDescriptor<Like>(
            predicate: #Predicate { $0.postId == postId && $0.userId == userId }
        )
        if let likes = try? modelContext.fetch(descriptor), !likes.isEmpty {
            isLiked = true
        }
    }
}

// MARK: - Heart Particles Effect

struct HeartParticles: View {
    @State private var particles: [ParticleData] = []

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Image(systemName: "heart.fill")
                    .font(.system(size: particle.size))
                    .foregroundColor(particle.color)
                    .offset(x: particle.x, y: particle.y)
                    .opacity(particle.opacity)
            }
        }
        .onAppear {
            createParticles()
        }
    }

    private func createParticles() {
        // Create 6 particles in different directions
        for i in 0..<6 {
            let angle = Double(i) * 60.0 * .pi / 180.0
            let distance: CGFloat = CGFloat.random(in: 20...40)
            let colors: [Color] = [.red, .pink, .red.opacity(0.7)]
            let particle = ParticleData(
                id: UUID(),
                x: 0,
                y: 0,
                targetX: cos(angle) * distance,
                targetY: sin(angle) * distance,
                size: CGFloat.random(in: 6...10),
                color: colors.randomElement() ?? .red,
                opacity: 1.0
            )
            particles.append(particle)
        }

        // Animate particles outward
        withAnimation(.easeOut(duration: 0.4)) {
            for i in particles.indices {
                particles[i].x = particles[i].targetX
                particles[i].y = particles[i].targetY
                particles[i].opacity = 0
            }
        }
    }
}

struct ParticleData: Identifiable {
    let id: UUID
    var x: CGFloat
    var y: CGFloat
    let targetX: CGFloat
    let targetY: CGFloat
    let size: CGFloat
    let color: Color
    var opacity: Double
}

// MARK: - Animated Counter

struct AnimatedCounter: View {
    let value: Int

    var body: some View {
        Text("\(value)")
            .contentTransition(.numericText())
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: value)
    }
}

// MARK: - PR Feed View

struct PRFeedView: View {
    let prMoments: [PRMoment]
    let profile: UserProfile

    var body: some View {
        if prMoments.isEmpty {
            VStack(spacing: 16) {
                Spacer().frame(height: 60)
                Image(systemName: "trophy")
                    .font(.system(size: 50))
                    .foregroundColor(.yellow.opacity(0.5))

                Text("No PRs yet")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("Keep training and your PRs will show up here")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .padding()
        } else {
            LazyVStack(spacing: 12) {
                ForEach(prMoments) { pr in
                    PRFeedCard(prMoment: pr)
                }
            }
            .padding(16)
        }
    }
}

struct PRFeedCard: View {
    let prMoment: PRMoment

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(GQColors.cyanSpark.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: "trophy.fill")
                    .font(.title2)
                    .foregroundColor(GQColors.cyanSpark)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(prMoment.prType.rawValue.uppercased())
                    .font(GQTypography.sectionHeader)
                    .foregroundColor(GQColors.cyanSpark.opacity(0.8))
                    .tracking(0.5)

                if let exercise = prMoment.exerciseName {
                    Text(exercise)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }

                Text(prMoment.value)
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.textSecondary)

                Text(prMoment.createdAt.timeAgoDisplay())
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textTertiary)
            }

            Spacer()

            if let improvement = prMoment.improvement {
                Text(improvement)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(GQColors.success)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Learning Feed View

struct LearningFeedView: View {
    let learningItems: [LearningItem]
    let profile: UserProfile
    let onAddToPlan: (LearningItem) -> Void

    var body: some View {
        if learningItems.isEmpty {
            VStack(spacing: 16) {
                Spacer().frame(height: 60)
                Image(systemName: "book.closed")
                    .font(.system(size: 50))
                    .foregroundColor(GQColors.vividPurple.opacity(0.5))

                Text("Learning content coming soon")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("Exercise demos and form cues will appear here")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .padding()
        } else {
            LazyVStack(spacing: 12) {
                ForEach(learningItems) { item in
                    LearningFeedCard(item: item, onAddToPlan: { onAddToPlan(item) })
                }
            }
            .padding(16)
        }
    }
}

struct LearningFeedCard: View {
    let item: LearningItem
    let onAddToPlan: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: item.type.icon)
                    .font(.title3)
                    .foregroundColor(GQColors.vividPurple)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)

                    Text(item.type.rawValue)
                        .font(.system(size: 12))
                        .foregroundColor(GQColors.textTertiary)
                }

                Spacer()

                Text("\(item.durationSec)s")
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textTertiary)
            }

            // Cues preview
            if !item.textCues.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(item.textCues.prefix(2), id: \.self) { cue in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(GQColors.success)
                            Text(cue)
                                .font(.system(size: 13))
                                .foregroundColor(GQColors.textSecondary)
                        }
                    }
                }
            }

            // Add to plan button
            Button(action: onAddToPlan) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add to my plan")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(GQColors.vividPurple)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(GQColors.vividPurple.opacity(0.15))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Learn This Panel

struct LearnThisPanel: View {
    @Environment(\.modelContext) private var modelContext
    let exerciseName: String
    let learningItems: [LearningItem]
    let profile: UserProfile
    let onAddToPlan: (LearningItem) -> Void
    let onClose: () -> Void

    @State private var learningContent: ExerciseLearningContent?
    @State private var showingRobotDemo = false
    @State private var hasDemoAvailable = false
    @EnvironmentObject var featureFlags: FeatureFlags

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    exerciseHeader
                    formCuesSection
                    commonMistakesSection
                    demoVideoSection
                    robotDemoSection
                    learningItemsSection
                    addToPlanButton
                }
                .padding(16)
            }
            .background(Color(white: 0.05).ignoresSafeArea())
            .navigationTitle("Learn This")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose)
                }
            }
            .onAppear {
                loadLearningContent()
            }
            .sheet(isPresented: $showingRobotDemo) {
                RobotDemoSheet(exerciseName: exerciseName)
            }
        }
    }

    @ViewBuilder
    private var exerciseHeader: some View {
        VStack(spacing: 8) {
            Text(exerciseName)
                .font(.title2)
                .fontWeight(.bold)

            if let content = learningContent {
                HStack(spacing: 12) {
                    if !content.muscleGroups.isEmpty {
                        Text(content.muscleGroups.first ?? "")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }

                    Text(content.difficulty)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(difficultyColor(content.difficulty).opacity(0.2))
                        .foregroundColor(difficultyColor(content.difficulty))
                        .cornerRadius(6)
                }
            } else if let metadata = ExtendedExerciseDatabase.find(exerciseName) {
                Text(metadata.muscleGroup.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var formCuesSection: some View {
        if let content = learningContent, !content.formCues.isEmpty {
            formCuesCard(cues: content.formCues)
        } else if let metadata = ExtendedExerciseDatabase.find(exerciseName) {
            formCuesCard(cues: metadata.cues)
        }
    }

    private func formCuesCard(cues: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FORM CUES")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
                .tracking(0.5)

            ForEach(cues, id: \.self) { cue in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(cue)
                        .font(.system(size: 14))
                }
            }
        }
        .padding(16)
        .background(Color(white: 0.1))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var commonMistakesSection: some View {
        if let content = learningContent, !content.commonMistakes.isEmpty {
            commonMistakesCard(mistakes: content.commonMistakes)
        } else if let metadata = ExtendedExerciseDatabase.find(exerciseName), !metadata.commonMistakes.isEmpty {
            commonMistakesCard(mistakes: metadata.commonMistakes)
        }
    }

    private func commonMistakesCard(mistakes: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("COMMON MISTAKES")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
                .tracking(0.5)

            ForEach(mistakes, id: \.self) { mistake in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text(mistake)
                        .font(.system(size: 14))
                }
            }
        }
        .padding(16)
        .background(Color(white: 0.1))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var demoVideoSection: some View {
        if let content = learningContent, let videoURL = content.demoVideoURL {
            Button {
                let service = LearningService.shared
                service.configure(modelContext: modelContext)
                service.trackLearningView(userId: profile.id, learningItemId: UUID(), exerciseName: exerciseName)

                if let url = URL(string: videoURL) {
                    #if canImport(UIKit)
                    UIApplication.shared.open(url)
                    #endif
                }
            } label: {
                HStack {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                    Text("Watch Demo Video")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .padding(16)
                .background(
                    LinearGradient(
                        colors: [GQColors.vividPurple, GQColors.cyanSpark],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var robotDemoSection: some View {
        if featureFlags.robotDemosEnabled && hasDemoAvailable {
            Button {
                showingRobotDemo = true
            } label: {
                HStack {
                    Image(systemName: "figure.run")
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Generate Robot Demo")
                            .font(.headline)
                        Text("Animated stick figure with form cues")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .padding(16)
                .background(
                    LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var learningItemsSection: some View {
        if !learningItems.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("DEMOS & GUIDES")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
                    .tracking(0.5)

                ForEach(learningItems) { item in
                    LearningFeedCard(item: item, onAddToPlan: { onAddToPlan(item) })
                }
            }
        }
    }

    private var addToPlanButton: some View {
        Button {
            onClose()
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add \(exerciseName) to my next workout")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .padding(.top, 16)
    }

    private func loadLearningContent() {
        let service = LearningService.shared
        service.configure(modelContext: modelContext)
        learningContent = service.getLearningContent(for: exerciseName)

        // Check if robot demo is available
        hasDemoAvailable = RobotDemoService.shared.hasDemoAvailable(for: exerciseName)

        // Track view (using a generated ID since we're viewing content, not a stored item)
        service.trackLearningView(userId: profile.id, learningItemId: UUID(), exerciseName: exerciseName)
    }

    private func difficultyColor(_ difficulty: String) -> Color {
        switch difficulty.lowercased() {
        case "beginner": return GQColors.success
        case "intermediate": return GQColors.cyanSpark
        case "advanced": return GQColors.vividPurple
        default: return .gray
        }
    }
}

// MARK: - Comments Sheet

struct CommentsSheet: View {
    let post: Post
    let currentUserId: UUID
    var currentUserName: String = ""
    var currentUsername: String = ""
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var comments: [Comment]
    @State private var newComment = ""

    var postComments: [Comment] {
        comments.filter { $0.postId == post.id }.sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        if postComments.isEmpty {
                            Text("No comments yet")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        } else {
                            ForEach(postComments) { comment in
                                CommentRow(comment: comment)
                            }
                        }
                    }
                    .padding(16)
                }

                Divider()
                    .background(Color.white.opacity(0.1))

                // Comment input
                HStack(spacing: 12) {
                    TextField("Add a comment...", text: $newComment)
                        .textFieldStyle(GymQuestTextFieldStyle())

                    Button {
                        addComment()
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.title3)
                    }
                    .disabled(newComment.isEmpty)
                }
                .padding(16)
            }
            .background(Color(white: 0.05).ignoresSafeArea())
            .navigationTitle("Comments")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func addComment() {
        guard !newComment.isEmpty else { return }

        let comment = Comment(
            postId: post.id,
            authorId: currentUserId,
            authorName: currentUserName.isEmpty ? "User" : currentUserName,
            authorUsername: currentUsername,
            content: newComment,
            timestamp: Date()
        )

        modelContext.insert(comment)
        post.commentCount += 1
        try? modelContext.save()
        newComment = ""
    }
}

struct CommentRow: View {
    let comment: Comment

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(comment.authorName.prefix(1)))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(comment.authorName)
                        .font(.system(size: 13, weight: .semibold))

                    Text(comment.timestamp.timeAgoDisplay())
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }

                Text(comment.content)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
    }
}

// MARK: - Coming Soon View

struct ComingSoonView: View {
    let feature: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)

            Image(systemName: "sparkles")
                .font(.system(size: 50))
                .foregroundColor(GQColors.vividPurple.opacity(0.5))

            Text("\(feature)")
                .font(.title3)
                .fontWeight(.semibold)

            Text("This feature is coming soon!")
                .font(.subheadline)
                .foregroundColor(.gray)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Learning Item Type Extension

extension LearningItemType {
    var icon: String {
        switch self {
        case .demo: return "play.circle.fill"
        case .cue: return "checkmark.circle.fill"
        case .mistake: return "xmark.circle.fill"
        case .progression: return "arrow.up.circle.fill"
        case .mobilityRoutine: return "figure.flexibility"
        }
    }
}

struct EmptyFeedView: View {
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
                    .foregroundColor(.gray)
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

// each post in the feed - header, content, actions
struct PostCard: View {
    let post: Post
    let currentUserId: UUID
    @Environment(\.modelContext) private var modelContext

    @State private var isLiked = false
    @State private var showVideoPlayer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // header
            HStack(spacing: 12) {
                Circle()
                    .fill(LinearGradient(colors: [GQColors.vividPurple, GQColors.cyanSpark], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Text(String(post.authorName.prefix(1)).uppercased())
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.authorName)
                        .font(.system(size: 15, weight: .semibold))
                    Text(post.timestamp.timeAgoDisplay())
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }

                Spacer()

                if let workoutType = post.workoutType {
                    Text(workoutType)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(GQColors.vividPurple.opacity(0.3))
                        .cornerRadius(12)
                }
            }

            // caption
            if !post.caption.isEmpty {
                Text(post.caption)
                    .font(.system(size: 15))
                    .lineSpacing(2)
            }

            // photo or video
            if let photoData = post.photoData {
                #if canImport(UIKit)
                if let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxHeight: 400)
                        .clipped()
                        .cornerRadius(12)
                }
                #elseif canImport(AppKit)
                if let nsImage = NSImage(data: photoData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxHeight: 400)
                        .clipped()
                        .cornerRadius(12)
                }
                #endif
            } else if let videoData = post.videoData {
                VideoThumbnailView(videoData: videoData, showVideoPlayer: $showVideoPlayer)
            }

            // workout stats
            if post.duration != nil || post.setCount != nil {
                HStack(spacing: 20) {
                    if let duration = post.duration {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 14))
                            Text("\(duration) min")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(.gray)
                    }

                    if let sets = post.setCount {
                        HStack(spacing: 6) {
                            Image(systemName: "flame")
                                .font(.system(size: 14))
                            Text("\(sets) sets")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(.gray)
                    }
                }
            }

            // actions
            HStack(spacing: 24) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isLiked.toggle()
                        post.likeCount += isLiked ? 1 : -1
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 22))
                            .foregroundColor(isLiked ? .red : .white)
                        if post.likeCount > 0 {
                            Text("\(post.likeCount)")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .buttonStyle(.plain)

                Button {
                    // comments
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.right")
                            .font(.system(size: 20))
                        if post.commentCount > 0 {
                            Text("\(post.commentCount)")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.white)

                Spacer()

                Button {
                    // share
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
                .foregroundColor(.white)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color(white: 0.08))
        .fullScreenCover(isPresented: $showVideoPlayer) {
            if let videoData = post.videoData {
                VideoPlayerView(videoData: videoData, isPresented: $showVideoPlayer)
            }
        }
    }
}

// just a play button on black - tap to watch the actual video
struct VideoThumbnailView: View {
    let videoData: Data
    @Binding var showVideoPlayer: Bool

    var body: some View {
        Button {
            showVideoPlayer = true
        } label: {
            ZStack {
                Color.black
                    .frame(height: 250)
                    .cornerRadius(12)

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .buttonStyle(.plain)
    }
}

// AVPlayer needs a URL, so we write video data to temp file first
struct VideoPlayerView: View {
    let videoData: Data
    @Binding var isPresented: Bool
    @State private var player: AVPlayer?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                ProgressView()
                    .tint(.white)
            }

            // x button to close
            Button {
                player?.pause()
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
                    .padding()
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func setupPlayer() {
        // gotta write to temp file first - avplayer is picky
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
        do {
            try videoData.write(to: tempURL)
            player = AVPlayer(url: tempURL)
            player?.play()
        } catch {
            print("Error creating video: \(error)")
        }
    }
}

// MARK: - Full Screen Image View

#if canImport(UIKit)
struct FullScreenImageView: View {
    let image: UIImage
    @Binding var isPresented: Bool
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = lastScale * value
                        }
                        .onEnded { _ in
                            lastScale = scale
                            if scale < 1.0 {
                                withAnimation(.spring()) {
                                    scale = 1.0
                                    lastScale = 1.0
                                }
                            }
                        }
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { value in
                            lastOffset = offset
                            // Dismiss if dragged down significantly
                            if value.translation.height > 100 && scale <= 1.0 {
                                isPresented = false
                            }
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring()) {
                        if scale > 1.0 {
                            scale = 1.0
                            lastScale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        } else {
                            scale = 2.0
                            lastScale = 2.0
                        }
                    }
                }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .statusBarHidden()
    }
}
#endif

// relative time display (2h, 3d, 1w) like instagram/twitter
extension Date {
    func timeAgoDisplay() -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day, .weekOfYear], from: self, to: now)

        if let weeks = components.weekOfYear, weeks > 0 {
            return weeks == 1 ? "1w" : "\(weeks)w"
        }
        if let days = components.day, days > 0 {
            return days == 1 ? "1d" : "\(days)d"
        }
        if let hours = components.hour, hours > 0 {
            return hours == 1 ? "1h" : "\(hours)h"
        }
        if let minutes = components.minute, minutes > 0 {
            return minutes == 1 ? "1m" : "\(minutes)m"
        }
        return "now"
    }
}

// MARK: - Community Feed View (embedded in Feed tab)

struct CommunityFeedView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var communities: [Community]

    let profile: UserProfile

    @State private var showingCreateCommunity = false
    @State private var showingSearchCommunities = false
    @State private var selectedCommunity: Community?
    @State private var searchText = ""

    var userCommunities: [Community] {
        communities.filter { $0.memberIds.contains(profile.id) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Search bar
                HStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search communities...", text: $searchText)
                            .foregroundColor(.white)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)

                    Button {
                        showingSearchCommunities = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 16)

                if userCommunities.isEmpty {
                    // Empty state
                    VStack(spacing: 24) {
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [GQColors.vividPurple, GQColors.cyanSpark],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .padding(.top, 20)

                        VStack(spacing: 8) {
                            Text("Find Your Gym Community")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)

                            Text("Join communities for your gym, university, or local fitness center to connect with others")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }

                        // Featured communities preview
                        VStack(alignment: .leading, spacing: 12) {
                            Text("POPULAR NEAR YOU")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(GQColors.textTertiary)
                                .tracking(1)
                                .padding(.horizontal, 16)

                            // Example community cards
                            CommunityPreviewCard(
                                name: "The ARC - Queen's University",
                                members: 234,
                                location: "Kingston, ON",
                                isVerified: true
                            ) {
                                // Would join/view
                            }

                            CommunityPreviewCard(
                                name: "GoodLife Fitness Downtown",
                                members: 89,
                                location: "Kingston, ON",
                                isVerified: false
                            ) {
                                // Would join/view
                            }
                        }

                        VStack(spacing: 12) {
                            Button(action: { showingSearchCommunities = true }) {
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                    Text("Browse All Communities")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [GQColors.vividPurple, GQColors.cyanSpark],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                            }

                            Button(action: { showingCreateCommunity = true }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Create a Community")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, 8)
                    }
                    .buttonStyle(.plain)
                } else {
                    // User's communities
                    VStack(alignment: .leading, spacing: 12) {
                        Text("YOUR COMMUNITIES")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(GQColors.textTertiary)
                            .tracking(1)
                            .padding(.horizontal, 16)

                        ForEach(userCommunities) { community in
                            CommunityCard(community: community, profile: profile)
                                .onTapGesture {
                                    selectedCommunity = community
                                }
                        }
                    }

                    // Discover more button
                    Button {
                        showingSearchCommunities = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Discover More Communities")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(GQColors.cyanSpark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(GQColors.cyanSpark.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                }

                Spacer(minLength: 100)
            }
            .padding(.top, 12)
        }
        .scrollContentBackground(.hidden)
        .sheet(isPresented: $showingCreateCommunity) {
            CreateCommunitySheet(profile: profile)
        }
        .sheet(isPresented: $showingSearchCommunities) {
            SearchCommunitiesSheet(profile: profile)
        }
        .sheet(item: $selectedCommunity) { community in
            CommunityDetailView(community: community, profile: profile)
        }
    }
}

// MARK: - Community Preview Card (for empty state)

struct CommunityPreviewCard: View {
    let name: String
    let members: Int
    let location: String
    let isVerified: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Community icon
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [GQColors.vividPurple.opacity(0.3), GQColors.cyanSpark.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        if isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                                .foregroundColor(GQColors.cyanSpark)
                        }
                    }

                    HStack(spacing: 8) {
                        Label("\(members)", systemImage: "person.2.fill")
                        Text("•")
                        Text(location)
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }
}

// MARK: - Community Card (for joined communities)

struct CommunityCard: View {
    let community: Community
    let profile: UserProfile

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Community image
                if let imageData = community.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [GQColors.vividPurple, GQColors.cyanSpark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "building.2.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(community.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        if community.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                                .foregroundColor(GQColors.cyanSpark)
                        }
                    }

                    HStack(spacing: 8) {
                        Label("\(community.memberCount)", systemImage: "person.2.fill")
                        if let location = community.location {
                            Text("•")
                            Text(location)
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }

            // Quick stats or activity
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("12 active today")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }

                Spacer()

                Text("3 new posts")
                    .font(.system(size: 11))
                    .foregroundColor(GQColors.cyanSpark)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
}

// MARK: - Create Community Sheet

struct CreateCommunitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let profile: UserProfile

    @State private var name = ""
    @State private var description = ""
    @State private var location = ""
    @State private var joinType: CommunityJoinType = .open

    var body: some View {
        NavigationStack {
            Form {
                Section("Community Info") {
                    TextField("Name (e.g., The ARC - Queen's)", text: $name)
                    TextField("Location (optional)", text: $location)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Privacy") {
                    Picker("Who can join?", selection: $joinType) {
                        Text("Anyone (Open)").tag(CommunityJoinType.open)
                        Text("Request to Join").tag(CommunityJoinType.request)
                    }
                }

                Section {
                    Text("Communities are great for gyms, universities, or fitness groups. Members can share workouts, find partners, and connect.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("Create Community")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createCommunity()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func createCommunity() {
        let community = Community(
            name: name,
            communityDescription: description,
            location: location.isEmpty ? nil : location,
            creatorId: profile.id,
            joinType: joinType
        )
        modelContext.insert(community)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Search Communities Sheet

struct SearchCommunitiesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allCommunities: [Community]

    let profile: UserProfile

    @State private var searchText = ""

    var filteredCommunities: [Community] {
        if searchText.isEmpty {
            return allCommunities
        }
        return allCommunities.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.location?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if filteredCommunities.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("No communities found")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Try a different search or create your own")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredCommunities) { community in
                        CommunitySearchRow(
                            community: community,
                            isMember: community.memberIds.contains(profile.id),
                            onJoin: { joinCommunity(community) }
                        )
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search by name or location")
            .navigationTitle("Find Communities")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func joinCommunity(_ community: Community) {
        if community.joinType == .open {
            community.memberIds.append(profile.id)
            community.memberCount += 1
        } else {
            community.pendingRequestIds.append(profile.id)
        }
        try? modelContext.save()
    }
}

struct CommunitySearchRow: View {
    let community: Community
    let isMember: Bool
    let onJoin: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [GQColors.vividPurple.opacity(0.3), GQColors.cyanSpark.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(community.name)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)

                    if community.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11))
                            .foregroundColor(GQColors.cyanSpark)
                    }
                }

                HStack(spacing: 6) {
                    Text("\(community.memberCount) members")
                    if let location = community.location {
                        Text("•")
                        Text(location)
                    }
                }
                .font(.system(size: 12))
                .foregroundColor(.gray)
            }

            Spacer()

            if isMember {
                Text("Joined")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            } else {
                Button(action: onJoin) {
                    Text(community.joinType == .open ? "Join" : "Request")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(GQColors.vividPurple)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .listRowBackground(Color.white.opacity(0.05))
    }
}

// MARK: - Community Detail View

struct CommunityDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var communityPosts: [CommunityPost]

    let community: Community
    let profile: UserProfile

    @State private var showingNewPost = false

    var posts: [CommunityPost] {
        communityPosts
            .filter { $0.communityId == community.id }
            .sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 12) {
                        if let imageData = community.imageData,
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [GQColors.vividPurple, GQColors.cyanSpark],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "building.2.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.white)
                                )
                        }

                        HStack(spacing: 4) {
                            Text(community.name)
                                .font(.title2)
                                .fontWeight(.bold)

                            if community.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(GQColors.cyanSpark)
                            }
                        }

                        if !community.communityDescription.isEmpty {
                            Text(community.communityDescription)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }

                        HStack(spacing: 20) {
                            VStack {
                                Text("\(community.memberCount)")
                                    .font(.headline)
                                Text("Members")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }

                            if let location = community.location {
                                VStack {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.headline)
                                    Text(location)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .padding(.top, 12)

                    // Actions
                    HStack(spacing: 12) {
                        Button {
                            showingNewPost = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Post")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(GQColors.vividPurple)
                            .cornerRadius(10)
                        }

                        Button {
                            // Find workout partner
                        } label: {
                            HStack {
                                Image(systemName: "person.2.fill")
                                Text("Find Partner")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(GQColors.cyanSpark)
                            .cornerRadius(10)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)

                    // Posts feed
                    VStack(alignment: .leading, spacing: 12) {
                        Text("RECENT ACTIVITY")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(GQColors.textTertiary)
                            .tracking(1)
                            .padding(.horizontal, 16)

                        if posts.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "text.bubble")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray.opacity(0.5))
                                Text("No posts yet")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Text("Be the first to share something!")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            ForEach(posts) { post in
                                CommunityPostCard(post: post)
                            }
                        }
                    }

                    Spacer(minLength: 40)
                }
            }
            .background(Color(white: 0.05).ignoresSafeArea())
            .navigationTitle("Community")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingNewPost) {
                NewCommunityPostSheet(community: community, profile: profile)
            }
        }
    }
}

// MARK: - Community Post Card

struct CommunityPostCard: View {
    let post: CommunityPost

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 10) {
                Circle()
                    .fill(GQGradients.primary)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(post.authorName.prefix(1)).uppercased())
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.authorName)
                        .font(.system(size: 14, weight: .semibold))
                    Text(post.timestamp.timeAgoDisplay())
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }

                Spacer()

                // Post type badge
                HStack(spacing: 4) {
                    Image(systemName: post.postType.icon)
                        .font(.system(size: 10))
                    Text(post.postType.rawValue)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(GQColors.cyanSpark)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(GQColors.cyanSpark.opacity(0.15))
                .cornerRadius(6)
            }

            // Content
            Text(post.content)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.9))

            // Actions
            HStack(spacing: 20) {
                Button {
                    // Like
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "heart")
                        if post.likeCount > 0 {
                            Text("\(post.likeCount)")
                        }
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                }

                Button {
                    // Comment
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                        if post.commentCount > 0 {
                            Text("\(post.commentCount)")
                        }
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                }

                Spacer()
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
}

// MARK: - New Community Post Sheet

struct NewCommunityPostSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let community: Community
    let profile: UserProfile

    @State private var content = ""
    @State private var postType: CommunityPostType = .general

    var body: some View {
        NavigationStack {
            Form {
                Section("Post Type") {
                    Picker("Type", selection: $postType) {
                        ForEach(CommunityPostType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                }

                Section("What's on your mind?") {
                    TextField("Share with the community...", text: $content, axis: .vertical)
                        .lineLimit(4...10)
                }
            }
            .navigationTitle("New Post")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        createPost()
                    }
                    .disabled(content.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func createPost() {
        let post = CommunityPost(
            communityId: community.id,
            authorId: profile.id,
            authorName: profile.name,
            authorUsername: profile.username,
            postType: postType,
            content: content
        )
        modelContext.insert(post)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Post Tags Row (Shows tagged users, location, squads)

struct PostTagsRow: View {
    let post: Post

    var hasAnyTags: Bool {
        !post.taggedUsernames.isEmpty ||
        post.locationName != nil ||
        !post.taggedSquadIds.isEmpty ||
        post.spotifyPlaylistURL != nil ||
        post.appleMusicPlaylistURL != nil
    }

    var body: some View {
        if hasAnyTags {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Tagged users
                    ForEach(post.taggedUsernames, id: \.self) { username in
                        PostTagBadge(
                            icon: "at",
                            text: username,
                            color: GQColors.cyanSpark
                        )
                    }

                    // Location
                    if let location = post.locationName {
                        PostTagBadge(
                            icon: "location.fill",
                            text: location,
                            color: GQColors.success
                        )
                    }

                    // Squads
                    ForEach(Array(zip(post.taggedSquadIds, post.taggedSquadNames)), id: \.0) { _, squadName in
                        PostTagBadge(
                            icon: "person.3.fill",
                            text: squadName,
                            color: GQColors.vividPurple
                        )
                    }

                    // Spotify playlist link
                    if post.spotifyPlaylistURL != nil {
                        PostTagBadge(
                            icon: "music.note",
                            text: "Spotify Playlist",
                            color: Color(hex: "1DB954")
                        )
                    }

                    // Apple Music playlist link
                    if post.appleMusicPlaylistURL != nil {
                        PostTagBadge(
                            icon: "music.note",
                            text: "Apple Music",
                            color: Color(hex: "FC3C44")
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Post Tag Badge

struct PostTagBadge: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))

            Text(text)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.25))
        .cornerRadius(14)
    }
}

// MARK: - Exercise Media Carousel (for posts with exercise-specific media)

struct ExerciseMediaCarousel: View {
    let mediaItems: [PostMedia]
    @State private var selectedIndex = 0

    var body: some View {
        if !mediaItems.isEmpty {
            VStack(spacing: 8) {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(mediaItems.enumerated()), id: \.element.id) { index, media in
                        ZStack(alignment: .bottomLeading) {
                            // Media content
                            if let data = media.data, let image = UIImage(data: data) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .clipped()
                            }

                            // Exercise label overlay
                            if let exerciseName = media.exerciseName {
                                HStack(spacing: 6) {
                                    Image(systemName: "dumbbell.fill")
                                        .font(.system(size: 10))
                                    Text(exerciseName)
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(8)
                                .padding(12)
                            }

                            // Video indicator
                            if media.mediaType == .video {
                                VStack {
                                    HStack {
                                        Spacer()
                                        Image(systemName: "play.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.white)
                                            .shadow(radius: 4)
                                            .padding(12)
                                    }
                                    Spacer()
                                }
                            }
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: 300)

                // Exercise indicator pills
                if mediaItems.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(mediaItems.enumerated()), id: \.element.id) { index, media in
                                Button {
                                    withAnimation {
                                        selectedIndex = index
                                    }
                                } label: {
                                    Text(media.exerciseName ?? "General")
                                        .font(.system(size: 11, weight: selectedIndex == index ? .semibold : .regular))
                                        .foregroundColor(selectedIndex == index ? .white : GQColors.textSecondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(
                                            selectedIndex == index
                                                ? GQColors.vividPurple
                                                : Color.white.opacity(0.1)
                                        )
                                        .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
    }
}

#Preview {
    FeedView(profile: UserProfile())
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
