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
import MapKit
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
                        // Stories row — friends working out now
                        WorkingOutNowRow(recentFriendCount: friendsPosts.filter { $0.timestamp > Date().addingTimeInterval(-86400) }.count)
                            .padding(.top, 6)

                        LazyVStack(spacing: 0) {
                            if friendsPosts.isEmpty {
                                EmptyFeedView(onCreatePost: { appState.showingLogWorkout = true })
                            } else {
                                ForEach(friendsPosts) { post in
                                    PostCardV2(
                                        post: post,
                                        currentUserId: profile.id,
                                        currentUserName: profile.name
                                    )

                                    Rectangle()
                                        .fill(GQColors.borderSubtle)
                                        .frame(height: 8)
                                }
                            }
                        }
                        .padding(.bottom, 100)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .gqPageBackground()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavBarLogo()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                SocialSeeder.seedIfNeeded(modelContext: modelContext)
            }
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

    private var tabIndex: Int {
        FeedTab.allCases.firstIndex(of: selectedTab) ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(FeedTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue)
                        .font(.system(size: 16, weight: selectedTab == tab ? .semibold : .medium))
                        .foregroundColor(selectedTab == tab ? .white : GQColors.textTertiary)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedTab = tab
                            }
                        }
                }
            }
            .padding(.bottom, 8)

            // Single sliding underline
            GeometryReader { geometry in
                let tabWidth = geometry.size.width / CGFloat(FeedTab.allCases.count)
                LinearGradient(
                    colors: [GQColors.vividPurple, GQColors.cyanSpark],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: tabWidth, height: 2)
                .clipShape(RoundedRectangle(cornerRadius: 1))
                .offset(x: tabWidth * CGFloat(tabIndex))
                .animation(.easeInOut(duration: 0.3), value: tabIndex)
            }
            .frame(height: 2)
        }
        .padding(.horizontal, 32)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(GQColors.surfaceBase)
    }
}

// MARK: - Enhanced Post Card

struct PostCardV2: View {
    let post: Post
    let currentUserId: UUID
    var currentUserName: String = ""

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @State private var isLiked = false
    @State private var showVideoPlayer = false
    @State private var showComments = false
    @State private var hasAppeared = false
    @State private var isPlayingMusic = false
    @State private var showWorkoutDetail = false
    @State private var isSaved = false
    @State private var showFullCaption = false
    @State private var photoScale: CGFloat = 1.0

    var detectedActivityType: DetectedActivity? {
        guard let activity = post.detectedActivity else { return nil }
        return DetectedActivity(rawValue: activity)
    }

    var sharedWorkout: SharedWorkoutData? {
        post.getSharedWorkout()
    }

    /// Compact post: no photo or video attached
    private var isCompactPost: Bool {
        post.photoData == nil && post.videoData == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isCompactPost {
                compactTextOnlyLayout
            } else {
                headerRow
                inspiredByBadge
                heroSection
                captionSection
                compactBottomBar
            }
        }
        .background(GQColors.surfaceBase)
        .overlay(
            Rectangle()
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onChange(of: geo.frame(in: .global).midY) { _, midY in
                        let screenMid = UIScreen.main.bounds.height / 2
                        let zone = UIScreen.main.bounds.height * 0.2
                        let inCenter = abs(midY - screenMid) < zone
                        if post.songTitle != nil {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isPlayingMusic = inCenter
                            }
                        }
                    }
            }
        )
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
                    launchFollowWorkout(workout)
                }
            }
        }
    }

    // MARK: - Extracted ViewBuilders

    @ViewBuilder
    private var headerRow: some View {
        HStack {
            PostHeaderEnhanced(post: post, activityType: detectedActivityType, locationName: post.locationName)

            if post.authorId == currentUserId {
                PostDeleteButton {
                    deletePost()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var compactTextOnlyLayout: some View {
        HStack(alignment: .top, spacing: 10) {
            // Small avatar
            Circle()
                .fill(GQColors.primary)
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(post.authorName.prefix(1)).uppercased())
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(post.authorName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text("@\(post.authorUsername)")
                        .font(.system(size: 12))
                        .foregroundColor(GQColors.textSecondary)
                    Text(post.timestamp.timeAgoDisplay())
                        .font(.system(size: 12))
                        .foregroundColor(GQColors.textTertiary)
                }

                Text(post.caption)
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.textPrimary)
                    .lineSpacing(2)
                    .lineLimit(3)

                // Inline workout stats pill
                if post.workoutType != nil || post.duration != nil {
                    HStack(spacing: 8) {
                        if let type = post.workoutType {
                            Text(type)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(GQColors.cyanSpark)
                        }
                        if let duration = post.duration {
                            HStack(spacing: 2) {
                                Image(systemName: "clock")
                                    .font(.system(size: 9))
                                Text("\(duration)m")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(GQColors.textSecondary)
                        }
                        if let sets = post.setCount {
                            HStack(spacing: 2) {
                                Image(systemName: "flame")
                                    .font(.system(size: 9))
                                Text("\(sets) sets")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(GQColors.textSecondary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
                }

                // Inline actions
                HStack(spacing: 20) {
                    Button { showComments = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.right")
                                .font(.system(size: 12))
                            if post.commentCount > 0 {
                                Text("\(post.commentCount)")
                                    .font(.system(size: 12))
                            }
                        }
                        .foregroundColor(GQColors.textSecondary)
                    }
                    .buttonStyle(.plain)

                    Button {
                        if !isLiked {
                            isLiked = true
                            post.likeCount += 1
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 12))
                            if post.likeCount > 0 {
                                Text("\(post.likeCount)")
                                    .font(.system(size: 12))
                            }
                        }
                        .foregroundColor(isLiked ? GQColors.primary : GQColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var inspiredByBadge: some View {
        if let inspiredBy = post.inspiredByUsername {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11))
                Text("Inspired by @\(inspiredBy)")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(Color.white.opacity(0.6))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08))
            .cornerRadius(16)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private var heroSection: some View {
        if post.photoData != nil || post.videoData != nil {
            photoHero
        } else if sharedWorkout != nil {
            WorkoutHeroCard(
                workout: sharedWorkout,
                workoutType: post.workoutType,
                emotion: post.emotion,
                duration: post.duration,
                setCount: post.setCount,
                exerciseHighlight: post.exerciseHighlight,
                locationName: post.locationName
            )
            .padding(.horizontal, 16)
        } else if post.workoutType != nil {
            WorkoutHeroCard(
                workout: nil,
                workoutType: post.workoutType,
                emotion: post.emotion,
                duration: post.duration,
                setCount: post.setCount,
                exerciseHighlight: post.exerciseHighlight,
                locationName: post.locationName
            )
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var photoHero: some View {
        if post.mediaItems.count > 1 {
            // Multi-media carousel with music overlay on image
            ZStack(alignment: .bottom) {
                ExerciseMediaCarousel(mediaItems: post.mediaItems)

                if let song = post.songTitle, let artist = post.artistName {
                    photoMusicBar(song: song, artist: artist)
                        .padding(.bottom, 40) // above page dots
                }
            }
            .clipped()
        } else {
            // Single photo/video with overlays
            ZStack(alignment: .topLeading) {
                ZStack(alignment: .topTrailing) {
                    PostMediaView(post: post, showVideoPlayer: $showVideoPlayer)
                        .scaleEffect(photoScale)

                    if let activity = detectedActivityType, post.photoData != nil || post.videoData != nil {
                        ActivityBadge(activityType: activity)
                            .padding(12)
                    }
                }

                // Emotion pill overlay
                if let emotion = post.emotion {
                    emotionPill(emotion)
                        .padding(12)
                }

                // Music + stats at bottom of image
                VStack(spacing: 0) {
                    Spacer()

                    if let song = post.songTitle, let artist = post.artistName {
                        photoMusicBar(song: song, artist: artist)
                    }

                    if post.duration != nil || post.setCount != nil || post.workoutType != nil {
                        photoStatsOverlay
                    }
                }
            }
            .clipped()
            .onAppear {
                withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                    photoScale = 1.02
                }
            }
        }
    }

    @ViewBuilder
    private func photoMusicBar(song: String, artist: String) -> some View {
        let isSpotify = post.musicSource?.lowercased().contains("spotify") == true

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isPlayingMusic.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                MusicEQBars(barCount: 3, barWidth: 2.5, maxHeight: 12, color: .white.opacity(0.9), isPlaying: isPlayingMusic)

                Text("\(song) — \(artist)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)

                if post.musicSource != nil {
                    if isSpotify {
                        SpotifyIcon(size: 16)
                    } else {
                        AppleMusicIcon(size: 16)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.black.opacity(0.25))
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .fill(.clear)
                    .overlay(
                        Capsule()
                            .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                    )
            )
            .fixedSize()
            .environment(\.colorScheme, .dark)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var photoStatsOverlay: some View {
        HStack(spacing: 12) {
            if let type = post.workoutType {
                Text(type)
                    .font(.system(size: 13, weight: .semibold))
            }
            if let duration = post.duration, duration > 0 {
                Text("\(duration) min")
                    .font(.system(size: 13, weight: .medium))
            }
            if let sets = post.setCount, sets > 0 {
                Text("\(sets) sets")
                    .font(.system(size: 13, weight: .medium))
            }
            Spacer()
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    @ViewBuilder
    private var captionSection: some View {
        if !post.caption.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(post.caption)
                    .font(.system(size: 15))
                    .foregroundColor(GQColors.textPrimary)
                    .lineSpacing(2)
                    .lineLimit(showFullCaption ? nil : 2)

                if !showFullCaption && post.caption.count > 80 {
                    Button("more") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showFullCaption = true
                        }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(GQColors.textTertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private var compactBottomBar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Only show music badge if post has no photo/video (otherwise it's on the image)
            if post.photoData == nil && post.videoData == nil,
               let songTitle = post.songTitle, let artistName = post.artistName {
                MusicBadge(
                    songTitle: songTitle,
                    artistName: artistName,
                    isPlaying: isPlayingMusic,
                    musicSource: post.musicSource,
                    onTap: {
                        isPlayingMusic.toggle()
                    }
                )
                .contextMenu {
                    Button {
                        openMusicSearch(song: songTitle, artist: artistName, service: .spotify)
                    } label: {
                        Label("Open in Spotify", systemImage: "arrow.up.right")
                    }
                    Button {
                        openMusicSearch(song: songTitle, artist: artistName, service: .appleMusic)
                    } label: {
                        Label("Open in Apple Music", systemImage: "arrow.up.right")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            if let voiceData = post.voiceNoteData, let duration = post.voiceNoteDuration {
                VoiceNotePlayerView(audioData: voiceData, duration: duration)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }

            PostActionsRowCompact(
                post: post,
                isLiked: $isLiked,
                showComments: $showComments,
                isSaved: $isSaved,
                hasWorkout: sharedWorkout != nil,
                onFollowWorkout: sharedWorkout != nil ? {
                    showWorkoutDetail = true
                } : nil,
                onSave: sharedWorkout != nil ? {
                    if let workout = sharedWorkout {
                        saveWorkout(workout)
                    }
                } : nil,
                currentUserId: currentUserId,
                currentUserName: currentUserName
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func emotionPill(_ emotion: WorkoutEmotion) -> some View {
        HStack(spacing: 4) {
            Text(emotion.emoji)
                .font(.system(size: 14))
            Text(emotion.encouragement)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }

    private func saveWorkout(_ workout: SharedWorkoutData) {
        var saved = loadSavedWorkouts()
        if !saved.contains(where: { $0.id == workout.id }) {
            saved.append(workout)
            if let data = try? JSONEncoder().encode(saved) {
                UserDefaults.standard.set(data, forKey: "savedWorkouts")
            }
        }
    }

    private func loadSavedWorkouts() -> [SharedWorkoutData] {
        guard let data = UserDefaults.standard.data(forKey: "savedWorkouts"),
              let decoded = try? JSONDecoder().decode([SharedWorkoutData].self, from: data)
        else { return [] }
        return decoded
    }

    private func launchFollowWorkout(_ workout: SharedWorkoutData) {
        let exercises = workout.toActiveExercises()
        let workoutType = WorkoutType(rawValue: workout.workoutType) ?? .push
        appState.startWorkout(type: workoutType, exercises: exercises)
        appState.selectedTab = .home
    }

    private enum MusicService { case spotify, appleMusic }

    private func openMusicSearch(song: String, artist: String, service: MusicService) {
        let query = "\(song) \(artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        #if canImport(UIKit)
        switch service {
        case .spotify:
            if let appURL = URL(string: "spotify:search:\(query)"),
               UIApplication.shared.canOpenURL(appURL) {
                UIApplication.shared.open(appURL)
            } else if let webURL = URL(string: "https://open.spotify.com/search/\(query)") {
                UIApplication.shared.open(webURL)
            }
        case .appleMusic:
            if let url = URL(string: "https://music.apple.com/search?term=\(query)") {
                UIApplication.shared.open(url)
            }
        }
        #endif
    }

    private func deletePost() {
        modelContext.delete(post)
        try? modelContext.save()
    }
}

// MARK: - Workout Hero Card

struct WorkoutHeroCard: View {
    let workout: SharedWorkoutData?
    let workoutType: String?
    let emotion: WorkoutEmotion?
    let duration: Int?
    let setCount: Int?
    var exerciseHighlight: String? = nil
    var locationName: String? = nil

    @State private var shimmerOffset: CGFloat = -1
    @State private var iconAnimating = false
    @State private var breathingScale: CGFloat = 1.0
    @State private var shape1Offset: CGSize = .zero
    @State private var shape2Offset: CGSize = .zero
    @State private var shape3Offset: CGSize = .zero
    @State private var shape4Offset: CGSize = .zero
    @State private var displayedDuration: Int = 0
    @State private var displayedSetCount: Int = 0
    @State private var statsAppeared = false
    @State private var volumeBarAppeared = false
    @State private var watermarkRocking = false
    @State private var watermarkOpacity: Double = 0.07

    private var cardioSubType: CardioSubType? {
        guard workoutType == "Cardio" else { return nil }
        return CardioSubType.from(exerciseHighlight)
    }

    private var gradientColors: [Color] {
        if let type = workoutType, let wt = WorkoutType(rawValue: type) {
            return GQGradients.workoutGradientColors(for: wt)
        }
        return [GQColors.deepBlue, GQColors.cyanSpark]
    }

    private var hasExercises: Bool {
        guard let w = workout else { return false }
        return !w.exercises.isEmpty
    }

    // MARK: - Watermark Icons

    private var watermarkIcons: (String, String) {
        guard let type = workoutType, let wt = WorkoutType(rawValue: type) else {
            return ("dumbbell.fill", "figure.strengthtraining.traditional")
        }
        switch wt {
        case .push: return ("dumbbell.fill", "figure.strengthtraining.traditional")
        case .pull: return ("figure.strengthtraining.traditional", "arrow.down.circle.fill")
        case .legs: return ("figure.walk", "figure.stand")
        case .upper: return ("figure.arms.open", "dumbbell.fill")
        case .lower: return ("figure.stand", "figure.walk")
        case .fullBody: return ("figure.strengthtraining.traditional", "dumbbell.fill")
        case .cardio: return ("figure.run", "heart.fill")
        case .rest: return ("leaf.fill", "moon.fill")
        }
    }

    // MARK: - Muscle Group Data

    private var muscleGroups: [MuscleGroup] {
        if let exercises = workout?.exercises, !exercises.isEmpty {
            let groups = exercises.compactMap { MuscleGroup(rawValue: $0.muscleGroup) }
            var seen = Set<MuscleGroup>()
            return groups.filter { seen.insert($0).inserted }
        }
        guard let type = workoutType, let wt = WorkoutType(rawValue: type) else { return [] }
        switch wt {
        case .push: return [.chest, .triceps, .shoulders]
        case .pull: return [.back, .biceps]
        case .legs: return [.quads, .hamstrings, .glutes]
        case .upper: return [.chest, .back, .shoulders]
        case .lower: return [.quads, .hamstrings, .glutes, .calves]
        case .fullBody: return [.chest, .back, .shoulders, .quads]
        case .cardio: return [.cardio]
        case .rest: return []
        }
    }

    private func muscleGroupColor(_ group: MuscleGroup) -> Color {
        switch group.color {
        case "red": return .red
        case "blue": return .blue
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "green": return .green
        case "teal": return .teal
        case "indigo": return .indigo
        case "mint": return .mint
        case "yellow": return .yellow
        default: return .gray
        }
    }

    private func exerciseVolume(_ ex: SharedWorkoutData.SharedExercise) -> Double {
        ex.sets.reduce(0) { $0 + $1.weight * Double($1.reps) }
    }

    private func equipmentIcon(for exerciseName: String) -> String {
        ExtendedExerciseDatabase.find(exerciseName)?.equipment.icon ?? "dumbbell.fill"
    }

    // MARK: - Shimmer Overlay

    @ViewBuilder
    private var shimmerOverlay: some View {
        GeometryReader { geo in
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white.opacity(0.12), location: 0.45),
                    .init(color: .white.opacity(0.2), location: 0.5),
                    .init(color: .white.opacity(0.12), location: 0.55),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: geo.size.width * 1.5)
            .offset(x: geo.size.width * shimmerOffset)
            .allowsHitTesting(false)
        }
    }

    var body: some View {
        if hasExercises {
            exerciseHeroContent
        } else {
            statsOnlyContent
        }
    }

    // MARK: - Exercise Hero Content

    @ViewBuilder
    private var exerciseHeroContent: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: gradientColors.map { $0.opacity(0.3) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Animated decorative watermark icons
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    ZStack {
                        Image(systemName: watermarkIcons.0)
                            .font(.system(size: 70, weight: .thin))
                            .foregroundColor(.white.opacity(watermarkOpacity))
                            .rotationEffect(.degrees(watermarkRocking ? -7 : -17))
                            .offset(x: -30, y: -10)

                        Image(systemName: watermarkIcons.1)
                            .font(.system(size: 55, weight: .thin))
                            .foregroundColor(.white.opacity(watermarkOpacity * 0.85))
                            .rotationEffect(.degrees(watermarkRocking ? 20 : 10))
                            .offset(x: 10, y: 15)
                    }
                    .padding(.trailing, 10)
                    .padding(.bottom, 40)
                }
            }

            // Floating energy particles
            floatingParticles

            VStack(alignment: .leading, spacing: 0) {
                if let emotion = emotion {
                    heroEmotionPill(emotion)
                        .padding(.top, 14)
                        .padding(.leading, 14)
                }

                Spacer().frame(height: emotion != nil ? 10 : 14)

                muscleGroupIndicators
                    .padding(.horizontal, 14)

                Spacer().frame(height: 10)

                exerciseTable

                Spacer(minLength: 8)

                heroStatsBar
            }

            shimmerOverlay
        }
        .frame(minHeight: 260)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).delay(0.3)) {
                shimmerOffset = 1.5
            }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                watermarkRocking = true
            }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                watermarkOpacity = 0.10
            }
            volumeBarAppeared = true
        }
    }

    // MARK: - Stats Only Content (Enhanced)

    @ViewBuilder
    private var statsOnlyContent: some View {
        let isCardioWithRoute = cardioSubType?.isOutdoor == true
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: gradientColors.map { $0.opacity(0.3) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Animated floating decorative shapes
            ZStack {
                Circle()
                    .fill(.white.opacity(0.06))
                    .frame(width: 80, height: 80)
                    .offset(x: -90 + shape1Offset.width, y: -40 + shape1Offset.height)

                Circle()
                    .fill(.white.opacity(0.04))
                    .frame(width: 50, height: 50)
                    .offset(x: 100 + shape2Offset.width, y: 50 + shape2Offset.height)

                Capsule()
                    .fill(.white.opacity(0.05))
                    .frame(width: 60, height: 20)
                    .rotationEffect(.degrees(-25))
                    .offset(x: 80 + shape3Offset.width, y: -60 + shape3Offset.height)

                Circle()
                    .fill(.white.opacity(0.07))
                    .frame(width: 30, height: 30)
                    .offset(x: -70 + shape4Offset.width, y: 60 + shape4Offset.height)
            }

            // Floating energy particles
            floatingParticles

            VStack(spacing: 8) {
                if let emotion = emotion {
                    heroEmotionPill(emotion)
                }

                if !muscleGroups.isEmpty {
                    muscleGroupIndicators
                        .padding(.horizontal, 14)
                        .padding(.top, 4)
                }

                Spacer()

                if let subType = cardioSubType {
                    // Cardio-specific content
                    if subType.isOutdoor {
                        // Route visualization for outdoor cardio
                        CardioRouteView(
                            postId: exerciseHighlight ?? "route",
                            distance: cardioDistanceKm,
                            pace: cardioPace,
                            gradientColors: [subType.color, GQColors.cyanSpark],
                            locationName: locationName
                        )
                        .padding(.horizontal, 14)
                    } else {
                        // Indoor cardio icon + machine label
                        cardioIconContent(subType)
                    }
                } else if let type = workoutType, let wt = WorkoutType(rawValue: type) {
                    ZStack {
                        Circle()
                            .fill(gradientColors.first?.opacity(0.3) ?? .clear)
                            .frame(width: 90, height: 90)
                            .blur(radius: 15)

                        Image(systemName: wt.icon)
                            .font(.system(size: 60, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: gradientColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .scaleEffect(breathingScale)
                            .symbolEffect(.bounce, options: .repeating.speed(0.3), value: iconAnimating)
                    }

                    Text(type)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                } else if let type = workoutType {
                    Text(type)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }

                // Count-up stat numbers
                HStack(spacing: 6) {
                    if let d = duration, d > 0 {
                        Text("\(statsAppeared ? d : 0) min")
                            .font(.system(size: 15, weight: .medium))
                            .contentTransition(.numericText())
                    }
                    if let s = setCount, s > 0 {
                        Text("\u{00B7}")
                        Text("\(statsAppeared ? s : 0) sets")
                            .font(.system(size: 15, weight: .medium))
                            .contentTransition(.numericText())
                    }
                }
                .foregroundColor(.white.opacity(0.8))

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)

            shimmerOverlay
        }
        .frame(height: isCardioWithRoute ? 280 : 220)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).delay(0.3)) {
                shimmerOffset = 1.5
            }
            // Breathing scale
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                breathingScale = 1.05
            }
            // Floating shapes drift
            withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
                shape1Offset = CGSize(width: 8, height: -12)
            }
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true).delay(0.5)) {
                shape2Offset = CGSize(width: -10, height: 8)
            }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true).delay(1)) {
                shape3Offset = CGSize(width: -12, height: 10)
            }
            withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true).delay(0.3)) {
                shape4Offset = CGSize(width: 10, height: -8)
            }
            // Icon bounce trigger
            iconAnimating = true
            // Count-up stats
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                statsAppeared = true
            }
        }
    }

    // MARK: - Cardio Icon Content (Indoor)

    @ViewBuilder
    private func cardioIconContent(_ subType: CardioSubType) -> some View {
        ZStack {
            Circle()
                .fill(subType.color.opacity(0.3))
                .frame(width: 90, height: 90)
                .blur(radius: 15)

            Image(systemName: subType.icon)
                .font(.system(size: 55, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [subType.color, GQColors.cyanSpark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(breathingScale)
                .symbolEffect(.bounce, options: .repeating.speed(0.3), value: iconAnimating)
        }

        VStack(spacing: 2) {
            Text(subType.rawValue)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)

            if let machine = subType.machineLabel {
                Text("on \(machine)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    // MARK: - Cardio Helpers

    private var cardioDistanceKm: Double {
        guard let d = duration, d > 0 else { return 3.0 }
        return Double(d) * 0.18
    }

    private var cardioPace: String {
        guard let d = duration, d > 0 else { return "5:30" }
        let dist = cardioDistanceKm
        guard dist > 0 else { return "5:30" }
        let paceMin = Double(d) / dist
        let mins = Int(paceMin)
        let secs = Int((paceMin - Double(mins)) * 60)
        return "\(mins):\(String(format: "%02d", secs))"
    }

    // MARK: - Floating Energy Particles

    @ViewBuilder
    private var floatingParticles: some View {
        ForEach(0..<7, id: \.self) { i in
            FloatingParticle(
                index: i,
                color: gradientColors[i % gradientColors.count]
            )
        }
    }

    // MARK: - Muscle Group Indicators

    @ViewBuilder
    private var muscleGroupIndicators: some View {
        let groups = muscleGroups
        if !groups.isEmpty {
            HStack(spacing: 6) {
                ForEach(groups.prefix(5), id: \.self) { group in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(muscleGroupColor(group))
                            .frame(width: 7, height: 7)
                        Text(group.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Exercise Table (with equipment icons + volume bars)

    @ViewBuilder
    private var exerciseTable: some View {
        if let exercises = workout?.exercises {
            let displayExercises = Array(exercises.prefix(3))
            let remaining = exercises.count - 3
            let maxVol = displayExercises.map { exerciseVolume($0) }.max() ?? 1

            VStack(spacing: 6) {
                ForEach(displayExercises) { ex in
                    let vol = exerciseVolume(ex)
                    let proportion = maxVol > 0 ? vol / maxVol : 0

                    exerciseRow(ex, proportion: proportion)
                }

                if remaining > 0 {
                    Text("+\(remaining) more")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 14)
        }
    }

    @ViewBuilder
    private func exerciseRow(_ ex: SharedWorkoutData.SharedExercise, proportion: Double) -> some View {
        HStack(spacing: 6) {
            Image(systemName: equipmentIcon(for: ex.name))
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 16)

            Text(ex.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()

            let setCount = ex.sets.count
            let reps = ex.sets.first?.reps ?? 0
            let weight = ex.sets.first?.weight ?? 0

            Text("\(setCount)\u{00D7}\(reps)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.7))

            if weight > 0 {
                Text("\(Int(weight)) lbs")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 60, alignment: .trailing)
            } else {
                Text("BW")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 60, alignment: .trailing)
            }
        }
        .padding(.vertical, 4)
        .background(alignment: .leading) {
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: gradientColors.map { $0.opacity(0.15) },
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * (volumeBarAppeared ? max(proportion, 0.05) : 0), height: 24)
                    .frame(maxHeight: .infinity, alignment: .center)
                    .animation(.easeOut(duration: 0.6).delay(0.2), value: volumeBarAppeared)
            }
        }
    }

    @ViewBuilder
    private var heroStatsBar: some View {
        HStack(spacing: 12) {
            if let type = workoutType {
                Text(type)
                    .font(.system(size: 13, weight: .semibold))
            }
            if let d = duration, d > 0 {
                Text("\(d) min")
                    .font(.system(size: 13, weight: .medium))
            }
            if let s = setCount, s > 0 {
                Text("\(s) sets")
                    .font(.system(size: 13, weight: .medium))
            }
            Spacer()
        }
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    @ViewBuilder
    private func heroEmotionPill(_ emotion: WorkoutEmotion) -> some View {
        HStack(spacing: 4) {
            Text(emotion.emoji)
                .font(.system(size: 14))
            Text(emotion.encouragement)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}

// MARK: - Floating Particle

struct FloatingParticle: View {
    let index: Int
    let color: Color

    @State private var offsetY: CGFloat = 0
    @State private var opacity: Double = 0

    private var size: CGFloat { CGFloat.random(in: 3...6) }
    private var startX: CGFloat { CGFloat(index * 47 + 20) }
    private var speed: Double { Double.random(in: 3...5) }

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color.opacity(0.6), color.opacity(0.1)],
                    center: .center,
                    startRadius: 0,
                    endRadius: size
                )
            )
            .frame(width: size, height: size)
            .offset(x: startX - 160, y: offsetY)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: speed).repeatForever(autoreverses: false).delay(Double(index) * 0.4)) {
                    offsetY = -120
                    opacity = 0
                }
                withAnimation(.easeIn(duration: 0.5).delay(Double(index) * 0.4)) {
                    opacity = 0.7
                }
            }
    }
}

// MARK: - Cardio Route View

struct CardioRouteView: View {
    let postId: String
    let distance: Double
    let pace: String
    var gradientColors: [Color] = [GQColors.success, GQColors.cyanSpark]
    var locationName: String? = nil

    @State private var showRoute = false

    private var routeCoordinates: [CLLocationCoordinate2D] {
        var rng = SeededRNG(seed: postId.hashValue)
        let count = Int.random(in: 8...12, using: &rng)

        // Base location from locationName
        let base: (lat: Double, lng: Double) = {
            let loc = locationName?.lowercased() ?? ""
            if loc.contains("arc") || loc.contains("queen") {
                return (44.2253, -76.4951) // Kingston / Queen's area
            } else if loc.contains("goodlife") && loc.contains("downtown") {
                return (43.6510, -79.3832) // Toronto downtown
            }
            return (43.6510 + Double.random(in: -0.5...0.5, using: &rng),
                    -79.3832 + Double.random(in: -0.5...0.5, using: &rng))
        }()

        var coords: [CLLocationCoordinate2D] = []
        var lat = base.lat
        var lng = base.lng
        for _ in 0..<count {
            lat += Double.random(in: -0.003...0.003, using: &rng)
            lng += Double.random(in: -0.003...0.003, using: &rng)
            coords.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
        }
        return coords
    }

    private var mapCameraPosition: MapCameraPosition {
        let coords = routeCoordinates
        guard !coords.isEmpty else { return .automatic }
        let lats = coords.map(\.latitude)
        let lngs = coords.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lngs.min()! + lngs.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: (lats.max()! - lats.min()!) * 1.6 + 0.005,
            longitudeDelta: (lngs.max()! - lngs.min()!) * 1.6 + 0.005
        )
        return .region(MKCoordinateRegion(center: center, span: span))
    }

    var body: some View {
        VStack(spacing: 8) {
            let coords = routeCoordinates

            ZStack {
                Map(initialPosition: mapCameraPosition, interactionModes: []) {
                    if showRoute {
                        MapPolyline(coordinates: coords)
                            .stroke(
                                LinearGradient(
                                    colors: gradientColors,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 3
                            )
                    }

                    // Start marker
                    if let first = coords.first {
                        Annotation("", coordinate: first) {
                            Circle()
                                .fill(GQColors.success)
                                .frame(width: 14, height: 14)
                                .overlay(
                                    Text("S")
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
                    }

                    // End marker
                    if let last = coords.last {
                        Annotation("", coordinate: last) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 14, height: 14)
                                .overlay(
                                    Text("F")
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
                    }
                }
                .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
                .colorScheme(.dark)
            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Stats pill
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "map")
                        .font(.system(size: 11))
                        .foregroundColor(gradientColors.first ?? .green)
                    Text(String(format: "%.1f km", distance))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }

                HStack(spacing: 4) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 11))
                        .foregroundColor(gradientColors.last ?? .cyan)
                    Text("\(pace) /km")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).delay(0.3)) {
                showRoute = true
            }
        }
    }
}

// MARK: - Seeded RNG for deterministic routes

struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

// MARK: - Compact Actions Row

struct PostActionsRowCompact: View {
    let post: Post
    @Binding var isLiked: Bool
    @Binding var showComments: Bool
    @Binding var isSaved: Bool
    var hasWorkout: Bool = false
    var onFollowWorkout: (() -> Void)?
    var onSave: (() -> Void)?
    var currentUserId: UUID = UUID()
    var currentUserName: String = ""

    @Environment(\.modelContext) private var modelContext
    @State private var heartScale: CGFloat = 1.0
    @State private var showParticles = false
    @State private var displayedLikeCount: Int = 0
    @State private var displayedCommentCount: Int = 0
    @State private var showReactionPicker = false

    var body: some View {
        HStack(spacing: 16) {
            compactLikeButton
            compactCommentButton

            if hasWorkout, let onFollow = onFollowWorkout {
                compactFollowButton(onFollow)
            }

            Spacer()

            if hasWorkout {
                compactSaveButton
            }

            compactShareButton
        }
        .padding(.top, 4)
        .onAppear {
            displayedLikeCount = post.likeCount
            displayedCommentCount = post.commentCount
            checkIfLiked()
        }
    }

    @ViewBuilder
    private var compactLikeButton: some View {
        ZStack(alignment: .top) {
            if showReactionPicker {
                HStack(spacing: 8) {
                    ForEach(ReactionType.allCases, id: \.self) { reaction in
                        Button {
                            addReaction(reaction)
                            withAnimation(.spring(response: 0.2)) { showReactionPicker = false }
                        } label: {
                            Text(reaction.emoji)
                                .font(.system(size: 24))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                )
                .offset(y: -44)
                .transition(.scale(scale: 0.5, anchor: .bottom).combined(with: .opacity))
                .zIndex(10)
            }

            Button {
                performLikeAnimation()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 20))
                        .foregroundColor(isLiked ? .red : .white)
                        .scaleEffect(heartScale)

                    if displayedLikeCount > 0 {
                        AnimatedCounter(value: displayedLikeCount)
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textTertiary)
                    }
                }
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.4)
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            showReactionPicker.toggle()
                        }
                    }
            )
        }
    }

    @ViewBuilder
    private var compactCommentButton: some View {
        Button {
            showComments = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "bubble.right")
                    .font(.system(size: 18))

                if displayedCommentCount > 0 {
                    AnimatedCounter(value: displayedCommentCount)
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .foregroundColor(.white)
    }

    @ViewBuilder
    private func compactFollowButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "figure.run")
                    .font(.system(size: 12, weight: .semibold))
                Text("Follow")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(GQColors.cyanSpark)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(GQColors.cyanSpark.opacity(0.12))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var compactSaveButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isSaved.toggle()
            }
            if isSaved { onSave?() }
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        } label: {
            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                .font(.system(size: 18))
                .foregroundColor(isSaved ? GQColors.cyanSpark : .white.opacity(0.6))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var compactShareButton: some View {
        Button {
            // Share action
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 18))
        }
        .buttonStyle(.plain)
        .foregroundColor(.white)
    }

    // MARK: - Like Logic

    private func performLikeAnimation() {
        let wasLiked = isLiked

        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isLiked.toggle()
            post.likeCount += isLiked ? 1 : -1
        }

        if isLiked {
            let like = Like(
                postId: post.id,
                userId: currentUserId,
                userName: currentUserName
            )
            modelContext.insert(like)
        } else {
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

        withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
            heartScale = 1.3
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                heartScale = 1.0
            }
        }

        if !wasLiked {
            showParticles = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                showParticles = false
            }
        }

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

    private func addReaction(_ type: ReactionType) {
        let reaction = Reaction(
            odId: currentUserId,
            odUsername: currentUserName,
            targetType: "post",
            targetId: post.id,
            reactionType: type
        )
        modelContext.insert(reaction)
        try? modelContext.save()

        if !isLiked {
            performLikeAnimation()
        }
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
            .foregroundColor(.white.opacity(0.85))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .homeSocialCard(accent: GQColors.cyanSpark, emphasized: true, cornerRadius: 12)
        }
        .buttonStyle(GQInteractiveStyle())
    }
}

// MARK: - Working Out Now Row

struct WorkingOutNowRow: View {
    @EnvironmentObject var appState: AppState
    var recentFriendCount: Int = 0

    private let socialService = SocialActivityService.shared

    @State private var selectedFriend: String?
    @State private var pulseGreen = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Summary cell
                VStack(spacing: 3) {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                            .foregroundColor(GQColors.terracotta)
                        Text("\(socialService.friendsActiveToday)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Text("today")
                        .font(.system(size: 10))
                        .foregroundColor(GQColors.textTertiary)
                }
                .frame(width: 40)

                // Active friends from SocialActivityService
                ForEach(socialService.activeFriends) { friend in
                    Button {
                        selectedFriend = friend.name
                    } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .stroke(
                                        friend.isLive ? GQColors.success.opacity(pulseGreen ? 0.8 : 0.4) : GQColors.cyanSpark.opacity(0.5),
                                        lineWidth: 2
                                    )
                                    .frame(width: 48, height: 48)

                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Text(friend.avatarInitial)
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(.white)
                                    )

                                // Workout badge
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        Text(String(friend.workoutType.prefix(1)))
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 16, height: 16)
                                            .background(friend.isLive ? GQColors.success : GQColors.cyanSpark)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
                                    }
                                }
                                .frame(width: 48, height: 48)
                            }

                            Text(friend.name)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                            Text("\(friend.minutesElapsed)m")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
        .padding(.vertical, 8)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseGreen = true
            }
        }
        .sheet(item: Binding<WorkoutStoryItem?>(
            get: {
                guard let name = selectedFriend,
                      let friend = socialService.activeFriends.first(where: { $0.name == name })
                else { return nil }
                return WorkoutStoryItem(name: friend.name, type: friend.workoutType, minutes: friend.minutesElapsed, workout: "\(friend.workoutType) Day", exercises: friend.exercise)
            },
            set: { item in
                selectedFriend = item?.name
            }
        )) { friend in
            WorkoutStorySheet(friend: friend)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Workout Story Sheet

struct WorkoutStoryItem: Identifiable {
    let id = UUID()
    let name: String
    let type: String
    let minutes: Int
    let workout: String
    let exercises: String
}

struct WorkoutStorySheet: View {
    let friend: WorkoutStoryItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(GQColors.cyanSpark.opacity(0.5), lineWidth: 2)
                        .frame(width: 52, height: 52)

                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text(String(friend.name.prefix(1)))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        )
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(friend.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 7, height: 7)
                        Text("Working out now · \(friend.minutes)m")
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textTertiary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)

            // Workout info card
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 14))
                        .foregroundColor(GQColors.cyanSpark)
                    Text(friend.workout)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }

                Divider()
                    .overlay(Color.white.opacity(0.08))

                // Exercise list
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(friend.exercises.components(separatedBy: ", "), id: \.self) { exercise in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 5, height: 5)
                            Text(exercise)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }

                Divider()
                    .overlay(Color.white.opacity(0.08))

                // Stats
                HStack(spacing: 20) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textSecondary)
                        Text("\(friend.minutes) min")
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textTertiary)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.cyanSpark)
                        Text(friend.type)
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textTertiary)
                    }
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.06))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
            .padding(.horizontal, 20)

            Spacer()
        }
        .gqPageBackground()
    }
}

// MARK: - Enhanced Post Header

struct PostHeaderEnhanced: View {
    let post: Post
    let activityType: DetectedActivity?
    var locationName: String? = nil

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
                        .foregroundColor(GQColors.textTertiary)
                }

                HStack(spacing: 4) {
                    Text(post.timestamp.timeAgoDisplay())
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textTertiary)

                    if let location = locationName {
                        Text("·")
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textTertiary)
                        Image(systemName: "location.fill")
                            .font(.system(size: 9))
                            .foregroundColor(GQColors.textTertiary)
                        Text(location)
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textTertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Workout type badge
            if activityType == nil, let workoutType = post.workoutType {
                Text(workoutType)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.6))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.08))
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
                        .foregroundColor(GQColors.textSecondary)
                    Text("\(duration) min")
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textTertiary)
                }
            }

            if let sets = setCount, sets > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.terracotta)
                    Text("\(sets) sets")
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textTertiary)
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
                        .foregroundColor(GQColors.textTertiary)
                }

                Text(post.timestamp.timeAgoDisplay())
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textTertiary)
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
                        .frame(minHeight: 420, maxHeight: 550)
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
                        .frame(minHeight: 420, maxHeight: 550)
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
                    .foregroundColor(GQColors.textTertiary)
            }

            if let sets = setCount {
                Label("\(sets) sets", systemImage: "flame")
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.textTertiary)
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
                            .foregroundColor(GQColors.textTertiary)
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
                            .foregroundColor(GQColors.textTertiary)
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
                    .foregroundColor(GQColors.vividPurple)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(GQColors.vividPurple.opacity(0.12))
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
    @State private var showReactionPicker = false

    var body: some View {
        HStack(spacing: 20) {
            // Animated Like Button with reaction picker
            ZStack(alignment: .top) {
                // Reaction picker overlay
                if showReactionPicker {
                    HStack(spacing: 8) {
                        ForEach(ReactionType.allCases, id: \.self) { reaction in
                            Button {
                                addReaction(reaction)
                                withAnimation(.spring(response: 0.2)) { showReactionPicker = false }
                            } label: {
                                Text(reaction.emoji)
                                    .font(.system(size: 24))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                    )
                    .offset(y: -44)
                    .transition(.scale(scale: 0.5, anchor: .bottom).combined(with: .opacity))
                    .zIndex(10)

                    // Nudge for resilient-emotion posts
                    if post.emotion?.sentimentCategory == .resilient {
                        Text("They showed up when it was hard — drop a reaction")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(GQColors.success.opacity(0.8))
                            .offset(y: -68)
                            .transition(.opacity)
                            .zIndex(9)
                    }
                }

                Button {
                    performLikeAnimation()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 22))
                            .foregroundColor(isLiked ? .red : .white)
                            .scaleEffect(heartScale)

                        // Animated counter
                        if displayedLikeCount > 0 {
                            AnimatedCounter(value: displayedLikeCount)
                                .font(.system(size: 14))
                                .foregroundColor(GQColors.textTertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.4)
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                showReactionPicker.toggle()
                            }
                        }
                )
            }

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
                            .foregroundColor(GQColors.textTertiary)
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
                    .foregroundColor(GQColors.vividPurple)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(GQColors.vividPurple.opacity(0.12))
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

    private func addReaction(_ type: ReactionType) {
        let reaction = Reaction(
            odId: currentUserId,
            odUsername: currentUserName,
            targetType: "post",
            targetId: post.id,
            reactionType: type
        )
        modelContext.insert(reaction)
        try? modelContext.save()

        // Also count as a like
        if !isLiked {
            performLikeAnimation()
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
                    .foregroundColor(GQColors.textTertiary)
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
                    .foregroundColor(GQColors.textTertiary)
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
            .gqPageBackground()
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
                            .foregroundColor(GQColors.textTertiary)
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
                    .foregroundColor(GQColors.textTertiary)
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
                .foregroundColor(GQColors.textTertiary)
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
                .foregroundColor(GQColors.textTertiary)
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
                    .foregroundColor(GQColors.textTertiary)
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
                                .foregroundColor(GQColors.textTertiary)
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
            .gqPageBackground()
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
                        .foregroundColor(GQColors.textTertiary)
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
                .foregroundColor(GQColors.textTertiary)

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
                        .foregroundColor(GQColors.textTertiary)
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
                        .foregroundColor(GQColors.textTertiary)
                    }

                    if let sets = post.setCount {
                        HStack(spacing: 6) {
                            Image(systemName: "flame")
                                .font(.system(size: 14))
                            Text("\(sets) sets")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(GQColors.textTertiary)
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
                                .foregroundColor(GQColors.textTertiary)
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
                                .foregroundColor(GQColors.textTertiary)
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

// MARK: - Community Seeder

struct CommunitySeeder {
    static func seedIfNeeded(modelContext: ModelContext, userId: UUID) {
        let descriptor = FetchDescriptor<Community>(predicate: #Predicate { $0.parentCommunityId == nil })
        let existing = (try? modelContext.fetchCount(descriptor)) ?? 0
        guard existing == 0 else { return }

        let dummyUsers = (0..<8).map { _ in UUID() }

        // The ARC - Queen's University
        let arc = Community(
            name: "The ARC - Queen's University",
            communityDescription: "Queen's Athletics & Recreation Centre community",
            location: "Kingston, ON",
            creatorId: dummyUsers[0],
            memberIds: [userId] + Array(dummyUsers.prefix(5)),
            joinType: .open,
            memberCount: 234,
            isVerified: true,
            tags: ["university", "gym", "kingston"]
        )
        modelContext.insert(arc)

        // ARC channels
        for name in ["Morning Lifters", "Powerlifting Club", "Running Group"] {
            let channel = Community(
                name: name,
                communityDescription: "",
                creatorId: dummyUsers[0],
                memberIds: [userId] + Array(dummyUsers.prefix(3)),
                memberCount: Int.random(in: 15...60),
                parentCommunityId: arc.id
            )
            modelContext.insert(channel)
        }

        // GoodLife Fitness Downtown
        let goodlife = Community(
            name: "GoodLife Fitness Downtown",
            communityDescription: "Local GoodLife community",
            location: "Kingston, ON",
            creatorId: dummyUsers[1],
            memberIds: [userId] + Array(dummyUsers.prefix(4)),
            joinType: .open,
            memberCount: 89,
            isVerified: true,
            tags: ["gym", "kingston"]
        )
        modelContext.insert(goodlife)

        for name in ["Classes", "General"] {
            let channel = Community(
                name: name,
                communityDescription: "",
                creatorId: dummyUsers[1],
                memberIds: [userId] + Array(dummyUsers.prefix(2)),
                memberCount: Int.random(in: 20...50),
                parentCommunityId: goodlife.id
            )
            modelContext.insert(channel)
        }

        // Global communities
        let globals: [(String, String, Int)] = [
            ("Home Gym Heroes", "For everyone training at home", 1420),
            ("Beginner Gains", "New to lifting? Start here", 3200),
            ("PR Chasers", "Chasing personal records every week", 890),
        ]
        for (gName, gDesc, gCount) in globals {
            let g = Community(
                name: gName,
                communityDescription: gDesc,
                creatorId: dummyUsers[2],
                memberIds: Array(dummyUsers.prefix(3)),
                joinType: .open,
                memberCount: gCount,
                tags: ["global"]
            )
            modelContext.insert(g)
        }

        // Seed memberships for user
        for comm in [arc, goodlife] {
            let membership = CommunityMembership(
                userId: userId,
                communityId: comm.id,
                role: .member
            )
            modelContext.insert(membership)
        }

        // Seed one active challenge per gym community
        let arcChallenge = CommunityChallenge(
            communityId: arc.id,
            title: "Complete 20 Sets This Week",
            challengeDescription: "Hit at least 20 total sets before Sunday",
            goalType: .sets,
            goalTarget: 20,
            currentProgress: 13,
            startDate: Calendar.current.date(byAdding: .day, value: -4, to: Date()) ?? Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date(),
            participantIds: [userId] + Array(dummyUsers.prefix(4))
        )
        modelContext.insert(arcChallenge)

        let glChallenge = CommunityChallenge(
            communityId: goodlife.id,
            title: "5 Workouts This Week",
            challengeDescription: "Show up 5 times — consistency wins",
            goalType: .workouts,
            goalTarget: 5,
            currentProgress: 2,
            startDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date(),
            participantIds: [userId] + Array(dummyUsers.prefix(3))
        )
        modelContext.insert(glChallenge)

        // Seed challenges for global communities
        let globalFetched = (try? modelContext.fetch(FetchDescriptor<Community>(predicate: #Predicate { $0.location == nil && $0.parentCommunityId == nil }))) ?? []
        for gComm in globalFetched {
            let challengeTitle: String
            let challengeDesc: String
            let goalType: ChallengeGoalType
            let goalTarget: Int
            let progress: Int
            switch gComm.name {
            case "Home Gym Heroes":
                challengeTitle = "30 Home Workouts This Month"
                challengeDesc = "No gym? No excuses. Get 30 sessions in at home"
                goalType = .workouts
                goalTarget = 30
                progress = 18
            case "Beginner Gains":
                challengeTitle = "7-Day Streak Challenge"
                challengeDesc = "Work out every day for a week — any duration counts"
                goalType = .streak
                goalTarget = 7
                progress = 4
            default:
                challengeTitle = "Hit 50 Sets This Week"
                challengeDesc = "Volume is king — push for 50 total sets"
                goalType = .sets
                goalTarget = 50
                progress = 31
            }
            let gc = CommunityChallenge(
                communityId: gComm.id,
                title: challengeTitle,
                challengeDescription: challengeDesc,
                goalType: goalType,
                goalTarget: goalTarget,
                currentProgress: progress,
                startDate: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 4, to: Date()) ?? Date(),
                participantIds: Array(dummyUsers.prefix(5))
            )
            modelContext.insert(gc)
        }

        // Seed community posts — spread across all communities
        let samplePosts: [(UUID, String, String, CommunityPostType)] = [
            // ARC posts
            (arc.id, "Alex K.", "Just hit a 225 bench PR! The ARC energy is different at 6am", .achievement),
            (arc.id, "Jordan M.", "Anyone down for leg day tomorrow around 3pm?", .lookingForPartner),
            (arc.id, "Taylor S.", "The powerlifting platform was empty this morning. Rare W", .general),
            (arc.id, "Chris L.", "Hit 315 deadlift today. ARC morning crew witnessed it", .achievement),
            // GoodLife posts
            (goodlife.id, "Sam R.", "Great spin class this morning, instructor was amazing", .general),
            (goodlife.id, "Morgan P.", "Looking for a bench spotter, usually train at 5pm weekdays", .lookingForPartner),
            (goodlife.id, "Dana K.", "First week done at GoodLife. The machines are so much nicer than my old gym", .general),
        ]

        // Posts for global communities
        let globalPosts: [(String, String, String, CommunityPostType)] = [
            ("Home Gym Heroes", "Riley T.", "Finally got a squat rack in my garage. Game changer", .achievement),
            ("Home Gym Heroes", "Jesse W.", "Resistance bands + bodyweight = underrated combo", .workout),
            ("Beginner Gains", "Casey M.", "Just finished my first ever full week of training!", .achievement),
            ("Beginner Gains", "Pat H.", "What's the difference between sumo and conventional deadlift?", .question),
            ("PR Chasers", "Quinn D.", "315 squat at 165 bodyweight. PR by 10 lbs!", .achievement),
        ]

        for (cid, author, content, ptype) in samplePosts {
            let post = CommunityPost(
                communityId: cid,
                authorId: dummyUsers.randomElement()!,
                authorName: author,
                authorUsername: author.lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ".", with: ""),
                postType: ptype,
                content: content,
                likeCount: Int.random(in: 2...18),
                commentCount: Int.random(in: 0...5),
                timestamp: Date().addingTimeInterval(Double.random(in: -86400...0))
            )
            modelContext.insert(post)
        }

        for (commName, author, content, ptype) in globalPosts {
            if let comm = globalFetched.first(where: { $0.name == commName }) {
                let post = CommunityPost(
                    communityId: comm.id,
                    authorId: dummyUsers.randomElement()!,
                    authorName: author,
                    authorUsername: author.lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ".", with: ""),
                    postType: ptype,
                    content: content,
                    likeCount: Int.random(in: 3...22),
                    commentCount: Int.random(in: 0...4),
                    timestamp: Date().addingTimeInterval(Double.random(in: -86400...0))
                )
                modelContext.insert(post)
            }
        }

        try? modelContext.save()
    }
}

// MARK: - Community Feed View (embedded in Feed tab)

struct CommunityFeedView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allCommunities: [Community]
    @Query private var allChallenges: [CommunityChallenge]
    @Query private var allCommunityPosts: [CommunityPost]

    let profile: UserProfile

    @State private var showingCreateCommunity = false
    @State private var showingSearchCommunities = false
    @State private var selectedCommunity: Community?

    private var topLevelCommunities: [Community] {
        allCommunities.filter { $0.parentCommunityId == nil }
    }

    private var yourCommunities: [Community] {
        topLevelCommunities.filter { $0.memberIds.contains(profile.id) }
    }

    private var recommendedCommunities: [Community] {
        topLevelCommunities.filter { !$0.memberIds.contains(profile.id) }
    }

    private var yourActiveChallenges: [CommunityChallenge] {
        let yourIds = Set(yourCommunities.map(\.id))
        return allChallenges.filter { $0.isActive && yourIds.contains($0.communityId) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 1. Active Challenge Spotlight
                challengeSpotlight

                // 2. Your Communities
                if !yourCommunities.isEmpty {
                    yourCommunitiesSection
                }

                // 3. Recommended For You
                if !recommendedCommunities.isEmpty {
                    recommendedSection
                }

                // 4. Create a Community
                createCommunityButton

                Spacer(minLength: 100)
            }
            .padding(.top, 12)
        }
        .scrollContentBackground(.hidden)
        .onAppear {
            CommunitySeeder.seedIfNeeded(modelContext: modelContext, userId: profile.id)
        }
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

    // MARK: - Challenge Spotlight

    @ViewBuilder
    private var challengeSpotlight: some View {
        if !yourActiveChallenges.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 12))
                    Text("ACTIVE CHALLENGES")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(GQColors.textTertiary)
                        .tracking(1)
                }
                .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(yourActiveChallenges) { challenge in
                            challengeSpotlightCard(challenge)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    @ViewBuilder
    private func challengeSpotlightCard(_ challenge: CommunityChallenge) -> some View {
        let communityName = yourCommunities.first(where: { $0.id == challenge.communityId })?.name ?? "Community"
        Button {
            // Navigate to challenge detail (no-op for now)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                // Community label
                Text(communityName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(GQColors.cyanSpark)
                    .lineLimit(1)

                // Challenge title
                Text(challenge.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 34, alignment: .topLeading)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 6)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [GQColors.vividPurple, GQColors.cyanSpark],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * challenge.progress, height: 6)
                    }
                }
                .frame(height: 6)

                // Stats row
                HStack {
                    Text("\(challenge.currentProgress)/\(challenge.goalTarget)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(challenge.daysRemaining)d left")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(6)
                }

                // Participants
                Text("\(challenge.participantIds.count) participating")
                    .font(.system(size: 10))
                    .foregroundColor(GQColors.textTertiary)
            }
            .padding(14)
            .frame(width: 220)
            .homeSocialCard(accent: GQColors.vividPurple, emphasized: true, cornerRadius: 14)
        }
        .gqInteractive(scale: 0.96, haptic: .light)
    }

    // MARK: - Your Communities Section

    @ViewBuilder
    private var yourCommunitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR COMMUNITIES")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(GQColors.textTertiary)
                .tracking(1)
                .padding(.horizontal, 16)

            ForEach(yourCommunities) { community in
                enhancedCommunityCard(community)
                    .onTapGesture { selectedCommunity = community }
            }
        }
    }

    // MARK: - Recommended Section

    @ViewBuilder
    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundColor(GQColors.cyanSpark)
                    .font(.system(size: 12))
                Text("RECOMMENDED FOR YOU")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(1)
            }
            .padding(.horizontal, 16)

            ForEach(recommendedCommunities) { community in
                recommendedCommunityCard(community)
            }
        }
    }

    @ViewBuilder
    private func recommendedCommunityCard(_ community: Community) -> some View {
        let reason: String = {
            if community.location != nil {
                return "Near you in Kingston"
            } else if community.memberCount > 1000 {
                return "Popular"
            } else {
                return "Based on your workouts"
            }
        }()

        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [GQColors.vividPurple.opacity(0.7), GQColors.cyanSpark.opacity(0.7)],
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

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Text(community.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        if community.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11))
                                .foregroundColor(GQColors.cyanSpark)
                        }
                    }

                    if !community.communityDescription.isEmpty {
                        Text(community.communityDescription)
                            .font(.system(size: 12))
                            .foregroundColor(GQColors.textTertiary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 9))
                            .foregroundColor(GQColors.cyanSpark)
                        Text(reason)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(GQColors.cyanSpark)

                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(GQColors.textTertiary)

                        Text("\(community.memberCount) members")
                            .font(.system(size: 11))
                            .foregroundColor(GQColors.textTertiary)
                    }
                }

                Spacer()

                // Inline join button
                Button(action: {
                    withAnimation {
                        community.memberIds.append(profile.id)
                        try? modelContext.save()
                    }
                }) {
                    Text("Join")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(
                            LinearGradient(
                                colors: [GQColors.vividPurple, GQColors.cyanSpark],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .homeSocialCard(cornerRadius: 12, subtle: true)
        .padding(.horizontal, 16)
    }

    // MARK: - Enhanced Community Card (for Your Communities)

    @ViewBuilder
    private func enhancedCommunityCard(_ community: Community) -> some View {
        let postCount24h = recentPostCount(for: community.id)
        let hasChallenge = allChallenges.contains(where: { $0.communityId == community.id && $0.isActive })
        let activeNow = max(2, community.memberCount / 30)

        VStack(spacing: 12) {
            HStack(spacing: 12) {
                #if canImport(UIKit)
                if let imageData = community.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } else {
                    communityCircleIcon
                }
                #else
                communityCircleIcon
                #endif

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

                    if !community.communityDescription.isEmpty {
                        Text(community.communityDescription)
                            .font(.system(size: 12))
                            .foregroundColor(GQColors.textTertiary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 8) {
                        Label("\(community.memberCount)", systemImage: "person.2.fill")
                        if let location = community.location {
                            Text("•")
                            Text(location)
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.textTertiary)
            }

            // Dynamic activity badges
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("\(activeNow) active now")
                        .font(.system(size: 11))
                        .foregroundColor(GQColors.textTertiary)
                }

                if hasChallenge {
                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                        Text("Challenge active")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                    }
                }

                Spacer()

                if postCount24h > 0 {
                    Text("\(postCount24h) new posts")
                        .font(.system(size: 11))
                        .foregroundColor(GQColors.cyanSpark)
                }
            }
        }
        .padding(14)
        .homeSocialCard(cornerRadius: 12, subtle: true)
        .padding(.horizontal, 16)
    }

    private var communityCircleIcon: some View {
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

    // MARK: - Create Community Button

    @ViewBuilder
    private var createCommunityButton: some View {
        Button(action: { showingCreateCommunity = true }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Create a Community")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    private func recentPostCount(for communityId: UUID) -> Int {
        let cutoff = Date().addingTimeInterval(-86400)
        return allCommunityPosts.filter { $0.communityId == communityId && $0.timestamp > cutoff }.count
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
                    .foregroundColor(GQColors.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.textTertiary)
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
                    .foregroundColor(GQColors.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.textTertiary)
            }

            // Quick stats or activity
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("12 active today")
                        .font(.system(size: 11))
                        .foregroundColor(GQColors.textTertiary)
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
                        .foregroundColor(GQColors.textTertiary)
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

        let membership = CommunityMembership(
            userId: profile.id,
            communityId: community.id,
            role: .owner
        )
        modelContext.insert(membership)

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
                            .foregroundColor(GQColors.textTertiary)
                        Text("No communities found")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Try a different search or create your own")
                            .font(.subheadline)
                            .foregroundColor(GQColors.textTertiary)
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

            let membership = CommunityMembership(
                userId: profile.id,
                communityId: community.id,
                role: .member
            )
            modelContext.insert(membership)
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
                .foregroundColor(GQColors.textTertiary)
            }

            Spacer()

            if isMember {
                Text("Joined")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(GQColors.textTertiary)
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

enum CommunitySection: String, CaseIterable {
    case feed = "Feed"
    case leaderboard = "Leaderboard"
    case members = "Members"
}

struct CommunityDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var communityPosts: [CommunityPost]
    @Query private var allCommunities: [Community]
    @Query private var allChallenges: [CommunityChallenge]
    @Query private var allMemberships: [CommunityMembership]

    let community: Community
    let profile: UserProfile

    @State private var showingNewPost = false
    @State private var selectedSection: CommunitySection = .feed
    @State private var showPartnerOnly = false

    private var isMember: Bool {
        community.memberIds.contains(profile.id)
    }

    private var posts: [CommunityPost] {
        communityPosts
            .filter { $0.communityId == community.id }
            .sorted { $0.timestamp > $1.timestamp }
    }

    private var channels: [Community] {
        allCommunities.filter { $0.parentCommunityId == community.id }
    }

    private var activeChallenges: [CommunityChallenge] {
        allChallenges.filter { $0.communityId == community.id && $0.isActive }
    }

    private var memberships: [CommunityMembership] {
        allMemberships.filter { $0.communityId == community.id }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    detailHeader
                    joinButton
                    workingOutNowRow
                    challengeCards
                    channelCards
                    actionButtons
                    communitySectionPicker
                    sectionContent
                    Spacer(minLength: 40)
                }
            }
            .gqPageBackground()
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

    // MARK: - Header

    @ViewBuilder
    private var detailHeader: some View {
        VStack(spacing: 12) {
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
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Tag pills
            if !community.tags.isEmpty {
                communityTagPills
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
    }

    // MARK: - Tag Pills

    @ViewBuilder
    private var communityTagPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(community.tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(GQColors.cyanSpark)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(GQColors.cyanSpark.opacity(0.12))
                        .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Join Button

    @ViewBuilder
    private var joinButton: some View {
        if !isMember {
            Button {
                if community.isOpen {
                    community.memberIds.append(profile.id)
                    community.memberCount += 1
                    let m = CommunityMembership(userId: profile.id, communityId: community.id, role: .member)
                    modelContext.insert(m)
                } else {
                    community.pendingRequestIds.append(profile.id)
                }
                try? modelContext.save()
            } label: {
                Text(community.isOpen ? "Join Community" : "Request to Join")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [GQColors.vividPurple, GQColors.cyanSpark],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
        } else if community.pendingRequestIds.contains(profile.id) {
            Text("Request Pending")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
                .padding(.horizontal, 16)
        }
    }

    // MARK: - Who's Working Out

    @ViewBuilder
    private var workingOutNowRow: some View {
        let activeNames = ["Alex K.", "Jordan M.", "Sam R."]
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("WHO'S WORKING OUT")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(1)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(activeNames, id: \.self) { name in
                        VStack(spacing: 6) {
                            Circle()
                                .fill(GQGradients.primary)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Text(String(name.prefix(1)))
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                )
                                .overlay(
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 12, height: 12)
                                        .overlay(Circle().stroke(Color.black, lineWidth: 2))
                                        .offset(x: 15, y: 15)
                                )
                            Text(name)
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                        .frame(width: 60)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Channels

    @ViewBuilder
    private var channelCards: some View {
        if !channels.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("CHANNELS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(1)
                    .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(channels) { channel in
                            VStack(spacing: 6) {
                                Image(systemName: "number")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(GQColors.cyanSpark)
                                Text(channel.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text("\(channel.memberCount) members")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 110, height: 80)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(GQColors.cyanSpark.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Active Challenge Cards

    @ViewBuilder
    private var challengeCards: some View {
        ForEach(activeChallenges) { challenge in
            Button {
                // Navigate to challenge detail (no-op for now)
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(.yellow)
                        Text("ACTIVE CHALLENGE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(GQColors.textTertiary)
                            .tracking(1)
                        Spacer()
                        Text("\(challenge.daysRemaining)d left")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(GQColors.sunsetOrange)
                    }

                    Text(challenge.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)

                    AnimatedProgressBar(
                        progress: challenge.progress,
                        height: 8,
                        colors: [GQColors.vividPurple, GQColors.cyanSpark]
                    )

                    HStack {
                        Text("\(challenge.currentProgress) / \(challenge.goalTarget) \(challenge.goalType.rawValue.lowercased())")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(challenge.participantIds.count) participating")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                .padding(14)
                .homeSocialCard(cornerRadius: 14, subtle: true)
                .padding(.horizontal, 16)
            }
            .gqInteractive(scale: 0.97, haptic: .light)
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        if isMember {
            HStack(spacing: 12) {
                Button { showingNewPost = true } label: {
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
                    selectedSection = .members
                    showPartnerOnly = true
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
        }
    }

    // MARK: - Section Picker

    @ViewBuilder
    private var communitySectionPicker: some View {
        HStack(spacing: 0) {
            ForEach(CommunitySection.allCases, id: \.self) { section in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSection = section
                        if section != .members { showPartnerOnly = false }
                    }
                } label: {
                    Text(section.rawValue)
                        .font(.system(size: 13, weight: selectedSection == section ? .bold : .medium))
                        .foregroundColor(selectedSection == section ? .white : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedSection == section ? GQColors.vividPurple.opacity(0.2) : Color.clear
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
        .padding(.horizontal, 16)
    }

    // MARK: - Section Content

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .feed:
            communityFeedSection
        case .leaderboard:
            communityLeaderboardSection
        case .members:
            communityMembersSection
        }
    }

    // MARK: - Feed Section

    @ViewBuilder
    private var communityFeedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
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
    }

    // MARK: - Leaderboard Section

    @ViewBuilder
    private var communityLeaderboardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("THIS WEEK")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(GQColors.textTertiary)
                .tracking(1)
                .padding(.horizontal, 16)

            ForEach(Array(leaderboardData.enumerated()), id: \.offset) { index, entry in
                HStack(spacing: 12) {
                    Text("#\(index + 1)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(medalColor(for: index))
                        .frame(width: 32)

                    Circle()
                        .fill(GQGradients.primary)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text(String(entry.name.prefix(1)))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text("\(entry.sets) sets")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Text("\(entry.points) pts")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(GQColors.cyanSpark)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(index < 3 ? Color.white.opacity(0.04) : Color.clear)
                .cornerRadius(10)
            }
        }
    }

    // MARK: - Members Section

    @ViewBuilder
    private var communityMembersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(community.memberCount) MEMBERS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(1)

                Spacer()

                Button {
                    withAnimation { showPartnerOnly.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showPartnerOnly ? "person.2.fill" : "person.2")
                            .font(.system(size: 11))
                        Text("Looking for Partner")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(showPartnerOnly ? GQColors.cyanSpark : .gray)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(showPartnerOnly ? GQColors.cyanSpark.opacity(0.15) : Color.white.opacity(0.05))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            let displayed = showPartnerOnly
                ? memberData.filter { $0.lookingForPartner }
                : memberData

            ForEach(displayed, id: \.name) { member in
                HStack(spacing: 12) {
                    Circle()
                        .fill(GQGradients.primary)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text(String(member.name.prefix(1)))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(member.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)

                        HStack(spacing: 6) {
                            Text(member.role)
                                .font(.system(size: 12))
                                .foregroundColor(.gray)

                            if member.lookingForPartner {
                                Text("Looking for partner")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(GQColors.cyanSpark)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(GQColors.cyanSpark.opacity(0.15))
                                    .cornerRadius(4)
                            }
                        }
                    }

                    Spacer()

                    if member.isOnline {
                        Circle()
                            .fill(GQColors.success)
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
        }
    }

    // MARK: - Data

    private var leaderboardData: [(name: String, sets: Int, workouts: Int, points: Int)] {
        [
            ("Alex K.", 42, 5, 210),
            ("Jordan M.", 38, 4, 190),
            ("Sam R.", 35, 5, 175),
            ("Taylor W.", 30, 3, 150),
            ("Casey B.", 25, 3, 125)
        ]
    }

    private var memberData: [(name: String, role: String, isOnline: Bool, lookingForPartner: Bool)] {
        [
            ("Alex K.", "Admin", true, false),
            ("Jordan M.", "Member", true, true),
            ("Sam R.", "Member", false, true),
            ("Taylor W.", "Member", true, false),
            ("Casey B.", "Member", false, false)
        ]
    }

    private func medalColor(for index: Int) -> Color {
        switch index {
        case 0: return .yellow
        case 1: return Color(white: 0.75)
        case 2: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return .gray
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
                        .foregroundColor(GQColors.textTertiary)
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
                    .foregroundColor(GQColors.textTertiary)
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
                    .foregroundColor(GQColors.textTertiary)
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
                    if let spotifyURLString = post.spotifyPlaylistURL, let url = URL(string: spotifyURLString) {
                        Button {
                            #if canImport(UIKit)
                            UIApplication.shared.open(url)
                            #endif
                        } label: {
                            PostTagBadge(
                                icon: "music.note",
                                text: "Spotify Playlist",
                                color: Color(hex: "1DB954")
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // Apple Music playlist link
                    if let appleMusicURLString = post.appleMusicPlaylistURL, let url = URL(string: appleMusicURLString) {
                        Button {
                            #if canImport(UIKit)
                            UIApplication.shared.open(url)
                            #endif
                        } label: {
                            PostTagBadge(
                                icon: "music.note",
                                text: "Apple Music",
                                color: Color(hex: "FC3C44")
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Emotion Badge

struct EmotionBadge: View {
    let emotion: WorkoutEmotion
    var likeCount: Int = 0

    var body: some View {
        HStack(spacing: 6) {
            Text(emotion.emoji)
                .font(.system(size: 14))
            Text(emotion.encouragement)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.7))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.08))
        )
    }
}

// MARK: - Post Tag Badge

struct PostTagBadge: View {
    let icon: String
    let text: String
    var color: Color = .white

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))

            Text(text)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
        }
        .foregroundColor(Color.white.opacity(0.6))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.08))
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
                .frame(minHeight: 420, maxHeight: 550)

                // Exercise indicator pills
                if mediaItems.count > 1 {
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
