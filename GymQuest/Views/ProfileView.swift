//
//  ProfileView.swift
//  GymQuest
//
//  Created by Benjamin Hilderman
//
//  Bold & Energetic profile with glass morphism
//  Posts feed, level/XP stats, settings
//

import SwiftUI
import SwiftData
import AVKit

private let profileNeutralAccent = Color.white.opacity(0.20)
private let profilePrimaryAccent = Color.white.opacity(0.70)
private let profileFireAccent = Color(hex: "FF9500")

struct ProfileView: View {
    @Query(sort: \Post.timestamp, order: .reverse) private var posts: [Post]
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]

    let profile: UserProfile

    @State private var showingSettings = false
    @State private var selectedWorkout: Workout?
    @State private var selectedPost: Post?
    @State private var selectedTab: ProfileContentTab = .posts
    @State private var emotionInsightsExpanded = false
    @State private var showingCoach = false

    private var profileAccent: Color {
        profileNeutralAccent
    }

    private var userPosts: [Post] {
        let targetUsername = profile.username.lowercased()
        let targetName = profile.name.lowercased()

        return posts.filter { post in
            post.authorId == profile.id ||
            post.authorUsername.lowercased() == targetUsername ||
            post.authorName.lowercased() == targetName
        }
    }

    private var totalWorkoutCount: Int {
        workouts.filter { $0.type != .rest }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Edge-to-edge: no card wrapper
                    profileHeader

                    // AI Coach entry
                    aiCoachCard

                    // Tab bar + content merged into one card
                    VStack(spacing: 0) {
                        profileTabBar
                        profileTabContent
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                    }
                    .homeSocialCard(cornerRadius: 14)
                }
                .padding(.horizontal, 16)
                .padding(.top, GQLayout.pageTop)
                .padding(.bottom, GQLayout.pageBottom)
            }
            .scrollContentBackground(.hidden)
            .gqPageBackground()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("@\(profile.username)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                #endif
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingSettings) {
                SettingsView(profile: profile)
            }
            .sheet(item: $selectedWorkout) { workout in
                SessionDetailView(session: workout)
            }
            .sheet(
                isPresented: Binding(
                    get: { selectedPost != nil },
                    set: { isPresented in
                        if !isPresented { selectedPost = nil }
                    }
                )
            ) {
                if let selectedPost {
                    PostDetailView(post: selectedPost, profile: profile)
                }
            }
            .sheet(isPresented: $showingCoach) {
                CoachView(profile: profile, workouts: Array(workouts), aiService: AIService())
            }
        }
    }

    // MARK: - AI Coach Card

    private var aiCoachCard: some View {
        Button {
            showingCoach = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(GQColors.cyanSpark.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(GQColors.cyanSpark)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Coach")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Chat, plans & form analysis")
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(GQColors.textTertiary)
            }
            .padding(14)
            .homeSocialCard(cornerRadius: 14)
        }
        .buttonStyle(GQInteractiveStyle())
    }

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Avatar + stat columns row
            HStack(spacing: 20) {
                profileAvatar

                HStack(spacing: 0) {
                    igStatColumn(value: "\(userPosts.count)", label: "Posts")
                    igStatColumn(value: "\(totalWorkoutCount)", label: "Workouts")
                    igStatColumn(value: "\(profile.xp)", label: "XP")
                }
            }

            // Name + level
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text("\(UserProfile.levelTitle(for: profile.level)) · Lv.\(profile.level)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(GQColors.textTertiary)
            }

            // Edit Profile button
            Button {
                showingSettings = true
            } label: {
                Text("Edit Profile")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }
            .buttonStyle(GQInteractiveStyle())
        }
        .padding(14)
    }

    private func igStatColumn(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(GQColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var profileAvatar: some View {
        ZStack {
            AnimatedGradientCircle(
                size: 84,
                lineWidth: 2,
                colors: [GQColors.vividPurple, GQColors.cyanSpark, GQColors.vividPurple],
                duration: 6.0
            )

            Group {
                #if canImport(UIKit)
                if let photoData = profile.profilePhotoData, let image = UIImage(data: photoData) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    avatarInitial
                }
                #elseif canImport(AppKit)
                if let photoData = profile.profilePhotoData, let image = NSImage(data: photoData) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    avatarInitial
                }
                #else
                avatarInitial
                #endif
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())
        }
    }

    private var avatarInitial: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.10))
            Text(String(profile.name.prefix(1)).uppercased())
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.white)
        }
    }

    @ViewBuilder
    private func collapsibleEmotionCard(insights: EmotionInsights) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    emotionInsightsExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "FF3B30"))
                    Text("EMOTION JOURNEY")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(GQColors.textTertiary)
                        .tracking(1)
                    Spacer()
                    Text("\(insights.totalPostsWithEmotion) workouts")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(GQColors.textTertiary)
                        .rotationEffect(.degrees(emotionInsightsExpanded ? 90 : 0))
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            // Distribution bar always visible
            EmotionDistributionBar(
                distribution: insights.distribution,
                total: insights.totalPostsWithEmotion
            )
            .padding(.horizontal, 14)
            .padding(.bottom, emotionInsightsExpanded ? 8 : 14)

            if emotionInsightsExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    if insights.resilienceStreak >= 2 {
                        HStack(spacing: 8) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "FF9500"))
                            Text("\(insights.resilienceStreak) workouts showing up when it's hard")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
                    }

                    let columns = [GridItem(.adaptive(minimum: 80), spacing: 8)]
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                        ForEach(insights.distribution) { item in
                            HStack(spacing: 4) {
                                Text(item.emotion.emoji)
                                    .font(.system(size: 12))
                                Text("\(item.count)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(item.emotion.color)
                            }
                        }
                    }

                    Text(insights.encouragementMessage)
                        .font(.system(size: 13, weight: .medium))
                        .italic()
                        .foregroundColor(GQColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .homeSocialCard()
    }

    private var profileTabBar: some View {
        HStack(spacing: 0) {
            ForEach(ProfileContentTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(selectedTab == tab ? .white : GQColors.textTertiary)

                        Rectangle()
                            .fill(selectedTab == tab ? Color.white : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var profileTabContent: some View {
        switch selectedTab {
        case .posts:
            if userPosts.isEmpty {
                ProfileEmptyState(
                    icon: "camera.on.rectangle",
                    title: "No posts yet",
                    subtitle: "Share your sessions and progress here."
                )
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 2),
                        GridItem(.flexible(), spacing: 2),
                        GridItem(.flexible(), spacing: 2)
                    ],
                    spacing: 2
                ) {
                    ForEach(userPosts) { post in
                        Button {
                            selectedPost = post
                        } label: {
                            ProfilePostThumbnail(post: post)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

        case .workouts:
            if workouts.isEmpty {
                ProfileEmptyState(
                    icon: "figure.strengthtraining.traditional",
                    title: "No workouts yet",
                    subtitle: "Log your first workout to build your archive."
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(workouts) { workout in
                        WorkoutHistoryRowV2(workout: workout)
                            .onTapGesture {
                                selectedWorkout = workout
                            }
                    }
                }
            }

        }
    }
}

private enum ProfileContentTab: CaseIterable {
    case posts
    case workouts

    var icon: String {
        switch self {
        case .posts: return "square.grid.3x3.fill"
        case .workouts: return "list.bullet.rectangle"
        }
    }
}


private struct ProfileEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(GQColors.textTertiary)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundColor(GQColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
    }
}


// MARK: - Profile Lifetime Stat Item

struct ProfileLifetimeStatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Workout History Row (from Workout model)

struct WorkoutHistoryRowV2: View {
    let workout: Workout
    private var iconAccent: Color {
        GQGradients.workoutGradientColors(for: workout.type).first ?? profilePrimaryAccent
    }
    private var accent: Color {
        profileNeutralAccent
    }

    var body: some View {
        HStack(spacing: 10) {
            WorkoutTypeBadge(type: workout.type, size: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text(workout.title ?? workout.type.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    if workout.duration > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                                .foregroundColor(Color.white.opacity(0.5))
                            Text("\(workout.duration) min")
                                .font(.system(size: 13))
                                .foregroundColor(GQColors.textSecondary)
                        }
                    }
                    if workout.totalSets > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "FF9500"))
                            Text("\(workout.totalSets) sets")
                                .font(.system(size: 13))
                                .foregroundColor(GQColors.textSecondary)
                        }
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(GQColors.textTertiary)
        }
        .padding(14)
        .homeSocialCard(accent: accent, subtle: true)
    }
}

// MARK: - Workout History Row (legacy - from Post model)

struct WorkoutHistoryRow: View {
    let post: Post

    var body: some View {
        HStack(spacing: 14) {
            // Date circle
            VStack(spacing: 2) {
                Text(post.timestamp.formatted(.dateTime.day()))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Text(post.timestamp.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.system(size: 11))
                    .foregroundColor(GQColors.textTertiary)
            }
            .frame(width: 44)

            // Workout info
            VStack(alignment: .leading, spacing: 4) {
                Text(post.workoutType ?? "Workout")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    if let duration = post.duration, duration > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                                .foregroundColor(Color.white.opacity(0.5))
                            Text("\(duration) min")
                                .font(.system(size: 13))
                                .foregroundColor(GQColors.textSecondary)
                        }
                    }
                    if let sets = post.setCount, sets > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "FF9500"))
                            Text("\(sets) sets")
                                .font(.system(size: 13))
                                .foregroundColor(GQColors.textSecondary)
                        }
                    }
                }
            }

            Spacer()

            // Thumbnail if has photo
            #if canImport(UIKit)
            if let data = post.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)
            }
            #endif

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(GQColors.textTertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(GQColors.surfaceBase)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                LinearGradient(
                    colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
        )
    }
}

// MARK: - Post Thumbnail (Grid style)

struct ProfilePostThumbnail: View {
    let post: Post

    var body: some View {
        ZStack {
            #if canImport(UIKit)
            if let data = post.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [.black.opacity(0.4), .clear],
                            startPoint: .bottom,
                            endPoint: .center
                        )
                    )
            } else if post.videoData != nil {
                GQColors.surfaceElevated
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.8))
                    )
            } else {
                // No media - show workout type badge
                GQColors.surfaceBase
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        VStack(spacing: 6) {
                            if let type = post.workoutType {
                                WorkoutTypeBadgeFromString(typeName: type, size: 36)
                                Text(type)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(GQColors.textTertiary)
                            } else {
                                Image(systemName: "dumbbell.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(profilePrimaryAccent)
                            }
                        }
                    )
            }
            #elseif canImport(AppKit)
            if let data = post.photoData, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [.black.opacity(0.4), .clear],
                            startPoint: .bottom,
                            endPoint: .center
                        )
                    )
            } else {
                GQColors.surfaceBase
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 24))
                            .foregroundColor(profilePrimaryAccent)
                    )
            }
            #endif
        }
        .overlay(alignment: .bottomLeading) {
            if let type = post.workoutType {
                WorkoutTypeBadgeFromString(typeName: type, size: 24)
                    .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                    .padding(4)
            }
        }
        .cornerRadius(4)
    }
}

// MARK: - Profile Post Card (Grid card with stats)

struct ProfilePostCard: View {
    let post: Post

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image/Media area
            ZStack(alignment: .bottomLeading) {
                #if canImport(UIKit)
                if let data = post.photoData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 140)
                        .clipped()
                } else if post.videoData != nil {
                    GQColors.surfaceElevated
                        .frame(height: 140)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white.opacity(0.8))
                        )
                } else {
                    // No media - gradient background with icon
                    LinearGradient(
                        colors: [GQColors.deepBlue.opacity(0.22), profileFireAccent.opacity(0.16)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 140)
                    .overlay(
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.4))
                    )
                }
                #elseif canImport(AppKit)
                if let data = post.photoData, let image = NSImage(data: data) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 140)
                        .clipped()
                } else {
                    LinearGradient(
                        colors: [GQColors.deepBlue.opacity(0.22), profileFireAccent.opacity(0.16)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 140)
                    .overlay(
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.4))
                    )
                }
                #endif

                // Workout type badge overlay
                if let workoutType = post.workoutType {
                    Text(workoutType)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(GQColors.surfaceOverlay.opacity(0.90))
                        )
                        .padding(8)
                }
            }

            // Stats below image
            HStack(spacing: 12) {
                if let duration = post.duration, duration > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                            .foregroundColor(GQColors.cyanSpark)
                        Text("\(duration)m")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                }

                if let sets = post.setCount, sets > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11))
                            .foregroundColor(profileFireAccent)
                        Text("\(sets)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                }

                Spacer()

                // Time ago
                Text(post.timestamp.timeAgoDisplay())
                    .font(.system(size: 11))
                    .foregroundColor(GQColors.textTertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(GQColors.surfaceBase)
        }
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

// shown when post has no photo/video - displays workout info visually
struct WorkoutStatsCard: View {
    let post: Post

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 40))
                .foregroundStyle(GQGradients.primary)
                .opacity(0.6)

            if let type = post.workoutType {
                Text(type)
                    .font(.headline)
                    .foregroundColor(.white)
            }

            HStack(spacing: 32) {
                if let duration = post.duration {
                    VStack(spacing: 4) {
                        Text("\(duration)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(GQColors.cyanSpark)
                        Text("min")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(GQColors.textTertiary)
                    }
                }
                if let sets = post.setCount {
                    VStack(spacing: 4) {
                        Text("\(sets)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(profileFireAccent)
                        Text("sets")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(GQColors.textTertiary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .background(GQColors.surfaceBase)
    }
}

// full screen view of a post with all details
struct PostDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let post: Post
    let profile: UserProfile

    @State private var showVideoPlayer = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // header
                    HStack(spacing: 12) {
                        Circle()
                            .fill(GQGradients.primary)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Text(String(post.authorName.prefix(1)).uppercased())
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(post.authorName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                            Text(post.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 13))
                                .foregroundColor(GQColors.textTertiary)
                        }

                        Spacer()

                        if let workoutType = post.workoutType {
                            Text(workoutType)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.white.opacity(0.22), lineWidth: 1)
                                        )
                                )
                        }
                    }
                    .padding(.horizontal)

                    // media
                    #if canImport(UIKit)
                    if let data = post.photoData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .cornerRadius(12)
                            .padding(.horizontal)
                    } else if post.videoData != nil {
                        Button {
                            showVideoPlayer = true
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .frame(height: 250)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(GQGradients.glassBorder, lineWidth: 1)
                                    )
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundStyle(GQGradients.primary)
                            }
                        }
                        .padding(.horizontal)
                    }
                    #endif

                    // caption
                    if !post.caption.isEmpty {
                        Text(post.caption)
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .lineSpacing(4)
                            .padding(.horizontal)
                    }

                    // workout stats
                    if post.duration != nil || post.setCount != nil {
                        GlassCard(accentColor: profileNeutralAccent, cornerRadius: 16, showGlow: false) {
                            HStack(spacing: 32) {
                                if let duration = post.duration {
                                    VStack(spacing: 4) {
                                        Text("\(duration)")
                                            .font(.system(size: 28, weight: .bold))
                                            .foregroundColor(GQColors.cyanSpark)
                                        Text("minutes")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(GQColors.textTertiary)
                                    }
                                }
                                if let sets = post.setCount {
                                    VStack(spacing: 4) {
                                        Text("\(sets)")
                                            .font(.system(size: 28, weight: .bold))
                                            .foregroundColor(profileFireAccent)
                                        Text("sets")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(GQColors.textTertiary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .padding(.horizontal)
                    }

                    // engagement
                    HStack(spacing: 24) {
                        Label("\(post.likeCount) likes", systemImage: "heart.fill")
                            .foregroundColor(profileFireAccent)
                        Label("\(post.commentCount) comments", systemImage: "bubble.right")
                            .foregroundColor(GQColors.textTertiary)
                        Spacer()
                    }
                    .font(.subheadline)
                    .padding(.horizontal)

                    Spacer().frame(height: 40)
                }
                .padding(.top)
            }
            .gqPageBackground()
            .navigationTitle("Post")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            #if canImport(UIKit)
            .fullScreenCover(isPresented: $showVideoPlayer) {
                if let videoData = post.videoData {
                    ProfileVideoPlayerView(videoData: videoData, isPresented: $showVideoPlayer)
                }
            }
            #endif
        }
    }
}

#if canImport(UIKit)
struct ProfileVideoPlayerView: View {
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
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
            do {
                try videoData.write(to: tempURL)
                player = AVPlayer(url: tempURL)
                player?.play()
            } catch {
                print("Error creating video: \(error)")
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}
#endif

// account settings - name, ai provider, api keys, logout
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState

    let profile: UserProfile

    @State private var name: String = ""
    @State private var username: String = ""
    @State private var aiProvider: AIProvider = .demo
    @State private var apiKey: String = ""
    @State private var ollamaModel: String = "llama3.2"
    @State private var ollamaHost: String = "localhost"
    @State private var showingLogoutAlert = false
    @State private var isTestingConnection = false
    @State private var connectionStatus: String?
    @State private var showingConnectionAlert = false
    @State private var showingSaveError = false

    @StateObject private var authService = AuthService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: GQLayout.sectionSpacing) {
                    GQScreenTitleBlock(
                        title: "Settings",
                        subtitle: "Profile, integrations, and AI preferences.",
                        accent: profileNeutralAccent
                    )
                    .gqScreenHorizontalPadding()
                    .padding(.top, GQLayout.pageTop)

                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader("Profile")
                        settingsTextField(title: "Name", text: $name)
                        settingsTextField(title: "Username", text: $username)
                    }
                    .padding(16)
                    .homeSocialCard(accent: profileNeutralAccent)
                    .gqScreenHorizontalPadding()

                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader("Integrations")

                        NavigationLink {
                            IntegrationsView(profile: profile)
                        } label: {
                            settingsRow(
                                icon: "link.circle.fill",
                                title: "Connected Services",
                                subtitle: "Apple Health, WHOOP, Strava",
                                color: GQColors.cyanSpark
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            SquadView(profile: profile)
                        } label: {
                            settingsRow(
                                icon: "person.3.fill",
                                title: "Squads",
                                subtitle: "Team challenges and accountability",
                                color: .blue
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            NotificationSettingsView()
                        } label: {
                            settingsRow(
                                icon: "bell.fill",
                                title: "Notifications",
                                subtitle: "Reminders and updates",
                                color: GQColors.sunsetOrange
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            BodyMeasurementsView(profile: profile)
                        } label: {
                            settingsRow(
                                icon: "ruler",
                                title: "Body Measurements",
                                subtitle: "Track physical changes over time",
                                color: GQColors.electricGold
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                    .homeSocialCard(accent: profileNeutralAccent)
                    .gqScreenHorizontalPadding()

                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader("AI")

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Provider")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(GQColors.textSecondary)
                            Picker("Provider", selection: $aiProvider) {
                                ForEach(AIProvider.allCases, id: \.self) { p in
                                    Text(p.rawValue).tag(p)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.07))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                        }
                        .onChange(of: aiProvider) { _, newValue in
                            if newValue == .ollama {
                                testOllamaConnection()
                            }
                        }

                        if aiProvider == .ollama {
                            settingsTextField(
                                title: "Host IP",
                                text: $ollamaHost,
                                placeholder: "e.g. 192.168.1.100",
                                isURL: true
                            )
                            settingsTextField(
                                title: "Model Name",
                                text: $ollamaModel,
                                placeholder: "e.g. llama3.2"
                            )
                            Button {
                                testOllamaConnection()
                            } label: {
                                HStack(spacing: 8) {
                                    if isTestingConnection {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "network")
                                    }
                                    Text(isTestingConnection ? "Testing..." : "Test Connection")
                                }
                            }
                            .buttonStyle(HomeSocialPrimaryButtonStyle(accent: GQColors.cyanSpark))
                            .disabled(isTestingConnection)
                        } else if aiProvider != .demo {
                            settingsSecureField(title: "API Key", text: $apiKey)
                        }
                    }
                    .padding(16)
                    .homeSocialCard(accent: profileNeutralAccent)
                    .gqScreenHorizontalPadding()

                    HStack(spacing: 10) {
                        WorkoutFlowMetricChip(
                            icon: "star.fill",
                            value: "Lv \(profile.level)",
                            label: "Current Level",
                            color: GQColors.electricGold
                        )
                        WorkoutFlowMetricChip(
                            icon: "bolt.fill",
                            value: "\(profile.xp)",
                            label: "XP",
                            color: GQColors.success
                        )
                    }
                    .gqScreenHorizontalPadding()

                    Button(role: .destructive) {
                        showingLogoutAlert = true
                    } label: {
                        Text("Sign Out")
                    }
                    .buttonStyle(HomeSocialSecondaryButtonStyle())
                    .gqScreenHorizontalPadding()

                    Spacer(minLength: 36)
                }
                .padding(.bottom, GQLayout.pageBottom)
            }
            .gqPageBackground()
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        profile.name = name
                        profile.username = username.isEmpty ? name.lowercased().replacingOccurrences(of: " ", with: "") : username
                        profile.aiProvider = aiProvider
                        profile.apiKey = apiKey
                        profile.ollamaModel = ollamaModel
                        profile.ollamaHost = ollamaHost
                        do {
                            try modelContext.save()
                            dismiss()
                        } catch {
                            showingSaveError = true
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Sign Out", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authService.setModelContext(modelContext)
                    authService.logout(profile: profile)
                    dismiss()
                    appState.authState = .notAuthenticated
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Ollama Connection", isPresented: $showingConnectionAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(connectionStatus ?? "Unknown status")
            }
            .alert("Save Failed", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Could not save settings. Please try again.")
            }
            .onAppear {
                name = profile.name
                username = profile.username
                aiProvider = profile.aiProvider
                apiKey = profile.apiKey
                ollamaModel = profile.ollamaModel
                ollamaHost = profile.ollamaHost
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(GQColors.textTertiary)
            .tracking(0.6)
    }

    @ViewBuilder
    private func settingsTextField(
        title: String,
        text: Binding<String>,
        placeholder: String? = nil,
        isURL: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(GQColors.textSecondary)
            TextField(placeholder ?? title, text: text)
                .autocorrectionDisabled(isURL)
                #if os(iOS)
                .keyboardType(isURL ? .URL : .default)
                .textInputAutocapitalization(isURL ? .never : .sentences)
                #endif
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.07))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    private func settingsSecureField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(GQColors.textSecondary)
            SecureField(title, text: text)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.07))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    private func settingsRow(
        icon: String,
        title: String,
        subtitle: String,
        color: Color
    ) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.18))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(color)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(GQColors.textTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .homeSocialCard(accent: color, subtle: true)
    }

    // pings local ollama server to verify connection works
    private func testOllamaConnection() {
        isTestingConnection = true

        Task {
            let host = ollamaHost.isEmpty ? "localhost" : ollamaHost
            let urlString = "http://\(host):11434/api/tags"

            guard let url = URL(string: urlString) else {
                await MainActor.run {
                    connectionStatus = "Invalid URL"
                    showingConnectionAlert = true
                    isTestingConnection = false
                }
                return
            }

            var request = URLRequest(url: url)
            request.timeoutInterval = 10

            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    await MainActor.run {
                        connectionStatus = "No response from Ollama"
                        showingConnectionAlert = true
                        isTestingConnection = false
                    }
                    return
                }

                if httpResponse.statusCode == 200 {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let models = json["models"] as? [[String: Any]] {
                        let modelNames = models.compactMap { $0["name"] as? String }
                        await MainActor.run {
                            if modelNames.isEmpty {
                                connectionStatus = "Connected! No models installed. Run: ollama pull llama3.2"
                            } else {
                                connectionStatus = "Connected! Available models: \(modelNames.joined(separator: ", "))"
                            }
                            showingConnectionAlert = true
                            isTestingConnection = false
                        }
                    } else {
                        await MainActor.run {
                            connectionStatus = "Connected to Ollama!"
                            showingConnectionAlert = true
                            isTestingConnection = false
                        }
                    }
                } else {
                    await MainActor.run {
                        connectionStatus = "Ollama returned error: \(httpResponse.statusCode)"
                        showingConnectionAlert = true
                        isTestingConnection = false
                    }
                }
            } catch {
                await MainActor.run {
                    connectionStatus = "Connection failed: \(error.localizedDescription)\n\nMake sure Ollama is running with:\nOLLAMA_HOST=0.0.0.0 ollama serve"
                    showingConnectionAlert = true
                    isTestingConnection = false
                }
            }
        }
    }
}

#Preview {
    ProfileView(profile: UserProfile())
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
