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
import PhotosUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Feed Tab

enum FeedTab: String, CaseIterable {
    case social = "Feed"
    case discover = "Discover"
    case clubs = "Clubs"
}

struct FeedView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var featureFlags: FeatureFlags
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Post.timestamp, order: .reverse) private var posts: [Post]
    @Query private var allFriendRecords: [Friend]
    @Query private var allUserProfiles: [UserProfile]

    let profile: UserProfile

    @State private var selectedFeedTab: FeedTab = .social
    @State private var showLearnPanel = false
    @State private var selectedExerciseForLearn: String?
    @State private var activeSquad: Squad?
    @State private var squadChallenge: SquadChallenge?
    @State private var hasSeeded = false

    // MARK: - Cached Social Graph

    @State private var cachedFollowingIds: Set<UUID> = []
    @State private var cachedFollowerIds: Set<UUID> = []
    @State private var cachedMutualIds: Set<UUID> = []
    @State private var cachedFriendsPosts: [Post] = []

    private func refreshSocialGraph() {
        cachedFollowingIds = Set(allFriendRecords.filter { $0.userId == profile.id }.map(\.odId))
        cachedFollowerIds = Set(allFriendRecords.filter { $0.odId == profile.id }.map(\.userId))
        cachedMutualIds = cachedFollowingIds.intersection(cachedFollowerIds)
    }

    /// Check if a user's profile is public
    private func isUserPublic(_ userId: UUID) -> Bool {
        allUserProfiles.first { $0.id == userId }?.isProfilePublic ?? true
    }

    private func refreshFriendsPosts() {
        cachedFriendsPosts = posts.filter { post in
            let authorId = post.authorId
            if cachedMutualIds.contains(authorId) { return true }
            if cachedFollowingIds.contains(authorId) && isUserPublic(authorId) { return true }
            return false
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab switcher pinned at top
                FeedTabsView(selectedTab: $selectedFeedTab)

                // Tab content
                switch selectedFeedTab {
                case .social:
                    socialFeedContent
                case .discover:
                    DiscoverFeedView(profile: profile)
                case .clubs:
                    ClubFeedView(profile: profile)
                }
            }
            .scrollContentBackground(.hidden)
            .gqPageBackground()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        appState.showingCreatePost = true
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 20))
                            .foregroundColor(GQColors.textSecondary)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $appState.showingCreatePost) {
                CreatePostView(profile: profile)
            }
            .onAppear {
                if !hasSeeded {
                    hasSeeded = true
                    SocialSeeder.seedIfNeeded(modelContext: modelContext)
                }
                loadActiveSquad()
                Task {
                    refreshSocialGraph()
                    refreshFriendsPosts()
                }
            }
            .onChange(of: allFriendRecords.count) {
                refreshSocialGraph()
                refreshFriendsPosts()
            }
            .onChange(of: posts.count) {
                refreshFriendsPosts()
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToFeedTab)) { notification in
                if let tab = notification.object as? FeedTab {
                    selectedFeedTab = tab
                }
            }
            .sheet(isPresented: $showLearnPanel) {
                if let exerciseName = selectedExerciseForLearn {
                    LearnThisPanel(
                        exerciseName: exerciseName,
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

    // MARK: - Social Feed Content

    @ViewBuilder
    private var socialFeedContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Stories row — friends working out now (hidden when empty)
                if !SocialActivityService.shared.activeFriends.isEmpty {
                    Rectangle()
                        .fill(GQColors.borderSubtle)
                        .frame(height: 1)
                        .padding(.horizontal, 4)

                    WorkingOutNowRow(recentFriendCount: cachedFriendsPosts.filter { $0.timestamp > Date().addingTimeInterval(-86400) }.count)
                }

                // Squad challenge (if active)
                if featureFlags.squadsEnabled, let squad = activeSquad, let challenge = squadChallenge {
                    SquadChallengeCard(squad: squad, challenge: challenge)
                        .padding(.bottom, 4)
                }
            }
            .padding(.horizontal, 16)

            // Thin separator before feed posts
            Rectangle()
                .fill(GQColors.borderSubtle)
                .frame(height: 1)
                .padding(.top, 4)

            LazyVStack(spacing: 0) {
                if cachedFriendsPosts.isEmpty {
                    socialEmptyState
                } else {
                    ForEach(cachedFriendsPosts) { post in
                        PostCardV2(
                            post: post,
                            currentUserId: profile.id,
                            currentUserName: profile.name,
                            profile: profile
                        )

                        Rectangle()
                            .fill(GQColors.borderSubtle)
                            .frame(height: 1)
                    }
                }
            }
            .padding(.bottom, 100)
        }
        .refreshable {
            await refreshSocialFeed()
        }
    }

    private func refreshSocialFeed() async {
        refreshSocialGraph()
        refreshFriendsPosts()
        loadActiveSquad()
    }

    // MARK: - Social Empty State

    private var socialEmptyState: some View {
        EmptyFeedState(
            icon: "person.2.fill",
            title: "Your Feed is Empty",
            subtitle: "Follow friends to see their workouts here"
        )
    }

    // MARK: - Load Active Squad

    private func loadActiveSquad() {
        guard featureFlags.squadsEnabled else { return }

        let squadService = SquadService.shared
        squadService.configure(modelContext: modelContext)

        let userSquads = squadService.getUserSquads(userId: profile.id)
        if let squad = userSquads.first {
            activeSquad = squad
            squadChallenge = squadService.getActiveChallenge(squadId: squad.id)
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

// MARK: - Feed Tabs (Social / Discover / Clubs)

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
                        .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                        .foregroundColor(selectedTab == tab ? GQColors.textPrimary : GQColors.textTertiary)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedTab = tab
                            }
                        }
                }
            }
            .padding(.bottom, 6)

            // Single sliding underline
            GeometryReader { geometry in
                let tabWidth = geometry.size.width / CGFloat(FeedTab.allCases.count)
                Rectangle()
                    .fill(GQGradients.primary)
                .frame(width: tabWidth, height: 1.5)
                .clipShape(RoundedRectangle(cornerRadius: 0.75))
                .offset(x: tabWidth * CGFloat(tabIndex))
                .animation(.easeInOut(duration: 0.3), value: tabIndex)
            }
            .frame(height: 1.5)
        }
        .padding(.horizontal, 20)
        .padding(.top, -10)
        .padding(.bottom, 2)
        .background(
            GQColors.background
            .ignoresSafeArea(edges: .top)
        )
    }
}

// MARK: - Enhanced Post Card

struct PostCardV2: View {
    let post: Post
    let currentUserId: UUID
    var currentUserName: String = ""
    var profile: UserProfile? = nil

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
    @State private var showingCopySheet = false
    @State private var copySheetWorkout: SharedWorkoutData?
    @State private var cachedTopComment: Comment?
    // Emoji reactions handled via action bar reaction picker
    @State private var showFullRouteMap = false
    @State private var profileUserId: IdentifiableUUID?
    @State private var cachedWorkout: SharedWorkoutData?

    var detectedActivityType: DetectedActivity? {
        guard let activity = post.detectedActivity else { return nil }
        return DetectedActivity(rawValue: activity)
    }

    var sharedWorkout: SharedWorkoutData? {
        cachedWorkout
    }

    /// Compact post: only truly non-workout posts (text shoutouts etc.)
    private var isCompactPost: Bool {
        post.photoData == nil && post.videoData == nil && post.workoutType == nil && sharedWorkout == nil
    }

    private var topComment: Comment? {
        cachedTopComment
    }

    private func fetchTopComment() {
        let postId = post.id
        var descriptor = FetchDescriptor<Comment>(
            predicate: #Predicate { $0.postId == postId },
            sortBy: [SortDescriptor(\Comment.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        cachedTopComment = try? modelContext.fetch(descriptor).first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isCompactPost {
                compactTextOnlyLayout
                inlineCommentPreview
            } else {
                headerRow
                inspiredByBadge
                heroSection
                captionSection
                compactBottomBar
                inlineCommentPreview
            }
        }
        .background(GQColors.surfaceBase)
        .opacity(hasAppeared ? 1 : 0)
        .task {
            cachedWorkout = post.getSharedWorkout()
        }
        .onAppear {
            hasAppeared = true
            fetchTopComment()
            if post.songTitle != nil {
                isPlayingMusic = true
            }
            // No-op: emoji reactions are in the action bar
        }
        .onDisappear {
            if post.songTitle != nil {
                isPlayingMusic = false
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
                WorkoutDetailSheet(
                    workoutData: workout,
                    onFollow: {
                        showWorkoutDetail = false
                        launchFollowWorkout(workout)
                    },
                    onAddExercise: { exercise in
                        let mg = MuscleGroup(rawValue: exercise.muscleGroup) ?? .chest
                        let sets = exercise.sets.map { ActiveSet(reps: $0.reps, weight: $0.weight) }
                        let active = ActiveExercise(name: exercise.name, muscleGroup: mg, sets: sets)
                        if appState.activeWorkout != nil {
                            appState.activeWorkout?.exercises.append(active)
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showingCopySheet) {
            if let workout = copySheetWorkout, let userProfile = profile {
                WorkoutCopySheet(workoutData: workout, profile: userProfile)
            }
        }
        .fullScreenCover(isPresented: $showFullRouteMap) {
            if let points = sharedWorkout?.routePoints {
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
            if let p = profile {
                UserProfileSheet(userId: wrapped.id, currentProfile: p)
            }
        }
    }

    // MARK: - Extracted ViewBuilders

    @ViewBuilder
    private var headerRow: some View {
        HStack {
            PostHeaderEnhanced(
                post: post,
                activityType: detectedActivityType,
                locationName: post.locationName,
                onTapUser: { profileUserId = IdentifiableUUID(id: post.authorId) }
            )

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
            // Small avatar (tappable)
            Button {
                profileUserId = IdentifiableUUID(id: post.authorId)
            } label: {
                Circle()
                    .fill(GQColors.primary)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(post.authorName.prefix(1)).uppercased())
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Button {
                        profileUserId = IdentifiableUUID(id: post.authorId)
                    } label: {
                        HStack(spacing: 6) {
                            Text(post.authorName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(GQColors.textPrimary)
                            Text("@\(post.authorUsername)")
                                .font(.system(size: 12))
                                .foregroundColor(GQColors.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
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
                            HStack(spacing: 4) {
                                let wt = WorkoutType(rawValue: type) ?? .custom
                                Image(systemName: wt.icon)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(GQGradients.workoutColor(for: wt))
                                Text(type)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(GQGradients.workoutColor(for: wt))
                            }
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
                    .background(GQColors.adaptiveOverlay(0.06))
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
        .overlay(alignment: .leading) {
            if let emotion = post.emotion {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(emotion.color)
                    .frame(width: 3)
                    .padding(.vertical, 12)
            }
        }
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
            .foregroundColor(GQColors.textTertiary)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }


    @ViewBuilder
    private var heroSection: some View {
        if post.photoData != nil || post.videoData != nil {
            photoHero
        }
    }

    @ViewBuilder
    private var photoHero: some View {
        ZStack {
            if post.mediaItems.count > 1 {
                ExerciseMediaCarousel(mediaItems: post.mediaItems)
            } else {
                PostMediaView(post: post, showVideoPlayer: $showVideoPlayer)
            }

            // Top overlays: music bar + activity badge
            VStack {
                HStack(alignment: .top) {
                    if let activity = detectedActivityType {
                        ActivityBadge(activityType: activity)
                    }

                    Spacer()

                    if let song = post.songTitle, let artist = post.artistName {
                        photoMusicBar(song: song, artist: artist)
                    }

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                Spacer()
            }

            // Workout overlay at bottom
            VStack(spacing: 0) {
                Spacer()
                mediaWorkoutOverlay
            }
        }
        .clipShape(Rectangle())
    }

    @ViewBuilder
    private func photoMusicBar(song: String, artist: String) -> some View {
        let isSpotify = post.musicSource?.lowercased().contains("spotify") == true
        let serviceColor: Color = isSpotify ? Color(hex: "1DB954") : Color(hex: "FC3C44")

        Button {
            let service: MusicService = (post.musicSource?.lowercased().contains("spotify") == true) ? .spotify : .appleMusic
            openMusicSearch(song: song, artist: artist, service: service)
        } label: {
            HStack(spacing: 6) {
                if post.musicSource != nil {
                    if isSpotify {
                        SpotifyIcon(size: 18)
                    } else {
                        AppleMusicIcon(size: 18)
                    }
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Color.white.opacity(0.2)))
                }

                Text(song)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(1)

                MusicEQBars(barCount: 3, barWidth: 2, maxHeight: 10, color: serviceColor, isPlaying: isPlayingMusic)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.black.opacity(0.45)))
            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                openMusicSearch(song: song, artist: artist, service: .spotify)
            } label: {
                Label("Open in Spotify", systemImage: "arrow.up.right")
            }
            Button {
                openMusicSearch(song: song, artist: artist, service: .appleMusic)
            } label: {
                Label("Open in Apple Music", systemImage: "arrow.up.right")
            }
        }
    }

    private var isCardioWithRoute: Bool {
        guard let workout = sharedWorkout,
              let points = workout.routePoints, !points.isEmpty else { return false }
        let cardioKeywords = ["Cardio", "Run", "Cycling", "Walking", "Hiking", "Rowing"]
        let type = post.workoutType ?? ""
        let highlight = post.exerciseHighlight ?? ""
        return cardioKeywords.contains(where: { type.contains($0) || highlight.contains($0) })
    }

    private var cardioActivityIcon: String {
        if let highlight = post.exerciseHighlight, let subType = CardioSubType.from(highlight) {
            return subType.icon
        }
        return "figure.run"
    }

    /// Maps cardio exercise highlights to GIF-capable exercise names from the ExerciseDB.
    private var cardioGifName: String? {
        guard let highlight = post.exerciseHighlight else { return nil }
        let lower = highlight.lowercased()
        if lower.contains("run") || lower.contains("jog") { return "Treadmill Run" }
        if lower.contains("row") { return "Rowing Machine" }
        if lower.contains("walk") || lower.contains("hik") { return "Walking" }
        return nil
    }

    @ViewBuilder
    private var mediaWorkoutOverlay: some View {
        let hasStats = post.duration != nil || post.setCount != nil || post.workoutType != nil
        let hasExercises = sharedWorkout != nil && !(sharedWorkout?.exercises.isEmpty ?? true)

        if isCardioWithRoute, let points = sharedWorkout?.routePoints {
            // Compact bottom-left map card for cardio posts
            HStack {
                HStack(spacing: 8) {
                    PostRouteMapView(
                        routePoints: points,
                        distance: post.duration.map { _ in "5.00 km" },
                        pace: "4:31 /km",
                        height: 90
                    )
                    .frame(width: 140, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 2)
                    .onTapGesture { showFullRouteMap = true }

                    VStack(alignment: .leading, spacing: 6) {
                        if let gifName = cardioGifName {
                            ExerciseGifView(exerciseName: gifName, size: .thumbnail, showFallback: false)
                        }
                        if cardioGifName == nil {
                            Image(systemName: cardioActivityIcon)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.white)
                        }

                        if let highlight = post.exerciseHighlight {
                            Text(highlight)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                                .lineLimit(1)
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        } else if hasStats || hasExercises {
            VStack(alignment: .leading, spacing: 6) {
                if hasStats {
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
                    .padding(.horizontal, 12)
                }

                if hasExercises, let workout = sharedWorkout {
                    OverlayExerciseGifStrip(
                        exercises: workout.exercises,
                        totalCount: workout.exercises.count,
                        onTapMore: { showWorkoutDetail = true }
                    )
                } else if let highlight = post.exerciseHighlight, !highlight.isEmpty {
                    HStack(spacing: 10) {
                        ExerciseGifView(exerciseName: highlight, size: .thumbnail)
                        Text(highlight)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                }
            }
            .foregroundColor(.white)
            .padding(.bottom, 6)
            .padding(.top, 24)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
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
            .padding(.top, 12)
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
                .padding(.top, 12)
            }

            if let voiceData = post.voiceNoteData, let duration = post.voiceNoteDuration {
                VoiceNotePlayerView(audioData: voiceData, duration: duration)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
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

    @ViewBuilder
    private var inlineCommentPreview: some View {
        if post.commentCount > 0, let comment = topComment {
            VStack(alignment: .leading, spacing: 4) {
                Button {
                    showComments = true
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(GQGradients.primary)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Text(String(comment.authorName.prefix(1)).uppercased())
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            )

                        Text(comment.authorName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(GQColors.textPrimary)

                        Text(comment.content)
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textSecondary)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)

                if post.commentCount > 1 {
                    Button {
                        showComments = true
                    } label: {
                        Text("View all \(post.commentCount) comments")
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Helpers

    private func saveWorkout(_ workout: SharedWorkoutData) {
        copySheetWorkout = workout
        showingCopySheet = true
    }

    private func launchFollowWorkout(_ workout: SharedWorkoutData) {
        copySheetWorkout = workout
        showingCopySheet = true
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
    var onCopy: (() -> Void)? = nil
    var onTap: (() -> Void)? = nil

    @State private var showCopied = false

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

    private var workoutTypeIcon: String {
        if let type = workoutType, let wt = WorkoutType(rawValue: type) { return wt.icon }
        return "dumbbell.fill"
    }

    private func equipmentIcon(for exerciseName: String) -> String {
        ExtendedExerciseDatabase.find(exerciseName)?.equipment.icon ?? "dumbbell.fill"
    }

    var body: some View {
        Group {
            if hasExercises {
                exerciseHeroContent
            } else {
                statsOnlyContent
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }

    // MARK: - Exercise Hero Content

    @ViewBuilder
    private var exerciseHeroContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(gradientColors.first ?? GQColors.deepBlue)
                    .frame(width: 3, height: 36)

                Image(systemName: workoutTypeIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(gradientColors.first ?? GQColors.deepBlue)

                if let type = workoutType {
                    Text(type)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                }

                Spacer()

                HStack(spacing: 6) {
                    if let d = duration, d > 0 {
                        Text("\(d) min")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(GQColors.textSecondary)
                    }
                    if let s = setCount, s > 0 {
                        Text("\u{00B7}")
                            .foregroundColor(GQColors.textSecondary)
                        Text("\(s) sets")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(GQColors.textSecondary)
                    }
                }

                copyButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()
                .padding(.horizontal, 16)

            // Exercise list
            exerciseTable
                .padding(.top, 10)
                .padding(.bottom, 14)
        }
        .gqCard(cornerRadius: 16)
    }

    // MARK: - Stats Only Content

    @ViewBuilder
    private var statsOnlyContent: some View {
        let isCardioWithRoute = cardioSubType?.isOutdoor == true

        VStack(alignment: .leading, spacing: 0) {
            if isCardioWithRoute, let subType = cardioSubType {
                // Cardio header + route
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(subType.color)
                        .frame(width: 3, height: 36)

                    Image(systemName: subType.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(subType.color)

                    Text(subType.rawValue)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)

                    Spacer()

                    if let d = duration, d > 0 {
                        Text("\(d) min")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(GQColors.textSecondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

                CardioRouteView(
                    postId: exerciseHighlight ?? "route",
                    distance: cardioDistanceKm,
                    pace: cardioPace,
                    gradientColors: [subType.color, GQColors.cyanSpark],
                    locationName: locationName
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            } else {
                // Non-cardio or indoor cardio: horizontal card
                HStack(spacing: 14) {
                    Circle()
                        .fill((gradientColors.first ?? GQColors.deepBlue).opacity(0.12))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: workoutTypeIcon)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(gradientColors.first ?? GQColors.deepBlue)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(workoutType ?? "Workout")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(GQColors.textPrimary)

                        HStack(spacing: 6) {
                            if let d = duration, d > 0 {
                                Text("\(d) min")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(GQColors.textSecondary)
                            }
                            if let s = setCount, s > 0 {
                                Text("\u{00B7}")
                                    .foregroundColor(GQColors.textSecondary)
                                Text("\(s) sets")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(GQColors.textSecondary)
                            }
                            if let subType = cardioSubType, let machine = subType.machineLabel {
                                Text("\u{00B7}")
                                    .foregroundColor(GQColors.textSecondary)
                                Text(machine)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(GQColors.textSecondary)
                            }
                        }
                    }

                    Spacer()
                }
                .padding(16)
            }
        }
        .gqCard(cornerRadius: 16)
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

    // MARK: - Exercise Table

    @ViewBuilder
    private var exerciseTable: some View {
        if let exercises = workout?.exercises {
            let displayExercises = Array(exercises.prefix(4))
            let remaining = exercises.count - 4

            VStack(spacing: 6) {
                ForEach(displayExercises) { ex in
                    exerciseRow(ex)
                }

                if remaining > 0 {
                    Text("+\(remaining) more")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(GQColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func setsAreUniform(_ sets: [SharedWorkoutData.SharedExercise.SharedSet]) -> Bool {
        guard let first = sets.first else { return true }
        return sets.allSatisfy { $0.reps == first.reps && $0.weight == first.weight }
    }

    private func setsSummary(_ sets: [SharedWorkoutData.SharedExercise.SharedSet]) -> String {
        let capped = Array(sets.prefix(4))
        let parts = capped.map { s in
            if s.weight > 0 {
                return "\(Int(s.weight))\u{00D7}\(s.reps)"
            } else {
                return "BW\u{00D7}\(s.reps)"
            }
        }
        let joined = parts.joined(separator: " \u{00B7} ")
        if sets.count > 4 {
            return joined + " +\(sets.count - 4)"
        }
        return joined
    }

    @ViewBuilder
    private func exerciseRow(_ ex: SharedWorkoutData.SharedExercise) -> some View {
        let uniform = setsAreUniform(ex.sets)

        HStack(spacing: 6) {
            if FeatureFlags.shared.exerciseGifsEnabled, ExerciseGifService.shared.hasGif(for: ex.name) {
                ExerciseGifView(exerciseName: ex.name, size: .thumbnail, showFallback: false)
                    .scaleEffect(0.6)
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: equipmentIcon(for: ex.name))
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textSecondary)
                    .frame(width: 16)
            }

            Text(ex.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(GQColors.textPrimary)
                .lineLimit(1)

            Spacer()

            if uniform {
                let setCount = ex.sets.count
                let reps = ex.sets.first?.reps ?? 0
                let weight = ex.sets.first?.weight ?? 0

                Text("\(setCount)\u{00D7}\(reps)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)

                if weight > 0 {
                    Text("\(Int(weight)) lbs")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(GQColors.textSecondary)
                        .frame(width: 60, alignment: .trailing)
                } else {
                    Text("BW")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(GQColors.textSecondary)
                        .frame(width: 60, alignment: .trailing)
                }
            } else {
                Text(setsSummary(ex.sets))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Copy Button

    @ViewBuilder
    private var copyButton: some View {
        if let onCopy {
            Button {
                onCopy()
                withAnimation(.spring(response: 0.3)) {
                    showCopied = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { showCopied = false }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11, weight: .semibold))
                    Text(showCopied ? "Saved" : "Copy")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(gradientColors.first ?? GQColors.deepBlue)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background((gradientColors.first ?? GQColors.deepBlue).opacity(0.1))
                .cornerRadius(14)
            }
            .buttonStyle(.plain)
            .disabled(showCopied)
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
    var realRoutePoints: [RoutePoint]? = nil

    @State private var showRoute = false

    private var routeCoordinates: [CLLocationCoordinate2D] {
        // Use real GPS data when available
        if let points = realRoutePoints, !points.isEmpty {
            return points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        }

        // Fall back to seeded random for demo posts
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
    @State private var sentReactionEmoji: String? = nil
    @State private var showSentReaction = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Inline reaction emojis
                reactionEmojiRow

                compactCommentButton

                Spacer()

                if hasWorkout {
                    compactSaveButton
                }

                compactShareButton
            }
            .padding(.top, 4)
        }
        .onAppear {
            displayedLikeCount = post.likeCount
            displayedCommentCount = post.commentCount
            checkIfLiked()
        }
    }

    @State private var tappedReaction: ReactionType? = nil

    @ViewBuilder
    private var reactionEmojiRow: some View {
        HStack(spacing: 6) {
            ForEach(ReactionType.allCases, id: \.self) { reaction in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                        tappedReaction = reaction
                    }
                    addReaction(reaction)
                    if !isLiked { performLikeAnimation() }
                    sentReactionEmoji = reaction.emoji
                    withAnimation(.spring(response: 0.3)) { showSentReaction = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        withAnimation(.easeOut(duration: 0.2)) { tappedReaction = nil }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation { showSentReaction = false }
                    }
                } label: {
                    Text(reaction.emoji)
                        .font(.system(size: 22))
                        .scaleEffect(tappedReaction == reaction ? 1.3 : 1.0)
                }
                .buttonStyle(.plain)
            }

            if displayedLikeCount > 0 {
                AnimatedCounter(value: displayedLikeCount)
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textTertiary)
                    .padding(.leading, 2)
            }
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
        .foregroundColor(GQColors.textPrimary)
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
                .foregroundColor(isSaved ? GQColors.cyanSpark : GQColors.textTertiary)
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
        .foregroundColor(GQColors.textPrimary)
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

        sentReactionEmoji = type.emoji
        showSentReaction = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(2200))
            showSentReaction = false
            sentReactionEmoji = nil
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

// MARK: - Widget Size

enum WidgetSize {
    case large, half, third

    var numberFont: Font {
        switch self {
        case .large: .system(size: 36, weight: .bold, design: .rounded)
        case .half: .system(size: 28, weight: .bold, design: .rounded)
        case .third: .system(size: 20, weight: .bold, design: .rounded)
        }
    }

    var goalFont: Font {
        switch self {
        case .large: .system(size: 18, weight: .semibold, design: .rounded)
        case .half: .system(size: 14, weight: .semibold, design: .rounded)
        case .third: .system(size: 11, weight: .semibold, design: .rounded)
        }
    }

    var ringSize: CGFloat {
        switch self {
        case .large: 48
        case .half: 36
        case .third: 24
        }
    }
}

// MARK: - Weekly Hero Section

struct WeeklyHeroSection: View {
    let completed: Int
    let goal: Int
    var profile: UserProfile
    var workouts: [Workout] = []
    var size: WidgetSize = .large

    @Environment(\.modelContext) private var modelContext
    @State private var isEditingGoal = false

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(completed) / Double(goal), 1.0)
    }

    /// Workout count per weekday (1=Sun..7=Sat) this week
    private var workoutCountsByWeekday: [Int: Int] {
        let cal = Calendar.current
        guard let startOfWeek = cal.dateInterval(of: .weekOfYear, for: Date())?.start else { return [:] }
        let thisWeek = workouts.filter { $0.date >= startOfWeek }
        var counts: [Int: Int] = [:]
        for w in thisWeek {
            let wd = cal.component(.weekday, from: w.date)
            counts[wd, default: 0] += 1
        }
        return counts
    }

    var body: some View {
        Group {
            switch size {
            case .third:
                compactThirdBody
            case .half:
                halfBody
            case .large:
                largeBody
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditingGoal {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isEditingGoal = false
                }
            }
        }
    }

    // MARK: - Large (full-width)
    @ViewBuilder
    private var largeBody: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("This Week")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(GQColors.textSecondary)

                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(completed)")
                            .font(size.numberFont)
                            .foregroundColor(GQColors.textPrimary)
                            .contentTransition(.numericText())

                        if isEditingGoal {
                            goalEditor
                        } else {
                            goalLabel
                        }
                    }
                }

                Spacer()

                HeroProgressRing(
                    progress: progress,
                    completed: completed >= goal
                )
            }

            weekDayDots
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Half
    @ViewBuilder
    private var halfBody: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("This Week")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(completed)")
                        .font(size.numberFont)
                        .foregroundColor(GQColors.textPrimary)
                        .contentTransition(.numericText())

                    Text("/ \(goal)")
                        .font(size.goalFont)
                        .foregroundColor(GQColors.textTertiary)
                }
            }

            Spacer()

            HeroProgressRing(
                progress: progress,
                completed: completed >= goal,
                size: size.ringSize
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    // MARK: - Third (compact ring + number + goal)
    @ViewBuilder
    private var compactThirdBody: some View {
        VStack(spacing: 4) {
            HeroProgressRing(
                progress: progress,
                completed: completed >= goal,
                size: size.ringSize
            )

            Text("\(completed)")
                .font(size.numberFont)
                .foregroundColor(GQColors.textPrimary)
                .contentTransition(.numericText())

            Text("/ \(goal) workouts")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    // MARK: - Shared subviews
    @ViewBuilder
    private var goalEditor: some View {
        HStack(spacing: 2) {
            Text("/")
                .font(size.goalFont)
                .foregroundColor(GQColors.textTertiary)

            Button {
                if profile.daysPerWeek > 1 {
                    profile.daysPerWeek -= 1
                    try? modelContext.save()
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.textTertiary)
            }
            .buttonStyle(.plain)

            Text("\(profile.daysPerWeek)")
                .font(size.goalFont)
                .foregroundColor(GQColors.textPrimary)
                .contentTransition(.numericText())

            Button {
                profile.daysPerWeek += 1
                try? modelContext.save()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.textTertiary)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var goalLabel: some View {
        Text("/ \(goal)")
            .font(size.goalFont)
            .foregroundColor(GQColors.textTertiary)

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isEditingGoal = true
            }
        } label: {
            Image(systemName: "pencil")
                .font(.system(size: 10))
                .foregroundColor(GQColors.textTertiary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var weekDayDots: some View {
        let cal = Calendar.current
        let symbols = cal.veryShortWeekdaySymbols
        // Mon=2 through Sun=1
        let mondayFirst = [2, 3, 4, 5, 6, 7, 1]
        let labelsReordered = [symbols[1], symbols[2], symbols[3],
                               symbols[4], symbols[5], symbols[6],
                               symbols[0]]

        HStack(spacing: 0) {
            ForEach(Array(zip(mondayFirst, labelsReordered).enumerated()), id: \.offset) { _, pair in
                let (weekday, label) = pair
                let count = workoutCountsByWeekday[weekday] ?? 0
                VStack(spacing: 2) {
                    Text(label)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)
                    HStack(spacing: 1.5) {
                        if count == 0 {
                            Circle()
                                .fill(GQColors.adaptiveOverlay(0.08))
                                .frame(width: 6, height: 6)
                        } else {
                            ForEach(0..<min(count, 3), id: \.self) { _ in
                                Circle()
                                    .fill(GQColors.textSecondary)
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Hero Progress Ring (Reusable)

struct HeroProgressRing: View {
    let progress: Double
    let completed: Bool
    var color: Color = GQColors.textSecondary
    var size: CGFloat = 48

    private var lineWidth: CGFloat { size >= 48 ? 5 : 4 }
    private var iconSize: CGFloat { size >= 48 ? 16 : 12 }
    private var percentSize: CGFloat { size >= 48 ? 12 : 10 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(GQColors.borderDefault, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)

            if completed {
                Image(systemName: "checkmark")
                    .font(.system(size: iconSize, weight: .bold))
                    .foregroundColor(color)
            } else {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: percentSize, weight: .bold, design: .rounded))
                    .foregroundColor(GQColors.textSecondary)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Hero Calories Widget

struct HeroCaloriesWidget: View {
    var profile: UserProfile
    var size: WidgetSize = .large

    @StateObject private var nutritionService = NutritionService.shared

    private var todaysMeals: [MealLog] {
        nutritionService.getTodaysMeals(userId: profile.id)
    }

    private var totalCalories: Int {
        todaysMeals.compactMap(\.estimatedCalories).reduce(0, +)
    }

    private var progress: Double {
        guard profile.dailyCalorieGoal > 0 else { return 0 }
        return min(Double(totalCalories) / Double(profile.dailyCalorieGoal), 1.0)
    }

    private var weeklyCalories: [Int] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        guard let monday = cal.date(byAdding: .day, value: -daysFromMonday, to: today) else {
            return Array(repeating: 0, count: 7)
        }

        var daily = [Int](repeating: 0, count: 7)
        for i in 0..<7 {
            guard let dayStart = cal.date(byAdding: .day, value: i, to: monday),
                  let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else { continue }
            let meals = nutritionService.getMeals(userId: profile.id, from: dayStart, to: dayEnd)
            daily[i] = meals.compactMap(\.estimatedCalories).reduce(0, +)
        }
        return daily
    }

    var body: some View {
        Group {
            switch size {
            case .third:
                compactThirdBody
            case .half:
                halfBody
            case .large:
                largeBody
            }
        }
    }

    @ViewBuilder
    private var largeBody: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today's Calories")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(GQColors.textSecondary)

                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(totalCalories)")
                            .font(size.numberFont)
                            .foregroundColor(GQColors.textPrimary)
                            .contentTransition(.numericText())

                        Text("/ \(profile.dailyCalorieGoal)")
                            .font(size.goalFont)
                            .foregroundColor(GQColors.textTertiary)
                    }
                }

                Spacer()

                HeroProgressRing(
                    progress: progress,
                    completed: totalCalories >= profile.dailyCalorieGoal
                )
            }

            weeklyBars
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var halfBody: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Calories")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(totalCalories)")
                        .font(size.numberFont)
                        .foregroundColor(GQColors.textPrimary)
                        .contentTransition(.numericText())

                    Text("/ \(profile.dailyCalorieGoal)")
                        .font(size.goalFont)
                        .foregroundColor(GQColors.textTertiary)
                }
            }

            Spacer()

            HeroProgressRing(
                progress: progress,
                completed: totalCalories >= profile.dailyCalorieGoal,
                size: size.ringSize
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var compactThirdBody: some View {
        VStack(spacing: 4) {
            HeroProgressRing(
                progress: progress,
                completed: totalCalories >= profile.dailyCalorieGoal,
                size: size.ringSize
            )

            Text("\(totalCalories)")
                .font(size.numberFont)
                .foregroundColor(GQColors.textPrimary)
                .contentTransition(.numericText())

            Text("/ \(profile.dailyCalorieGoal) cal")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var weeklyBars: some View {
        let maxCal = max(weeklyCalories.max() ?? 1, 1)
        let labels = ["M", "T", "W", "T", "F", "S", "S"]

        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { i in
                VStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < currentDayIndex ? GQColors.textSecondary : GQColors.adaptiveOverlay(0.08))
                        .frame(height: max(4, CGFloat(weeklyCalories[i]) / CGFloat(maxCal) * 24))

                    Text(labels[i])
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var currentDayIndex: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return (weekday + 5) % 7 + 1
    }
}

// MARK: - Hero Steps Widget

struct HeroStepsWidget: View {
    var size: WidgetSize = .large

    @StateObject private var healthKit = HealthKitService.shared

    private let stepGoal = 10_000

    private var progress: Double {
        guard stepGoal > 0 else { return 0 }
        return min(Double(healthKit.steps) / Double(stepGoal), 1.0)
    }

    var body: some View {
        Group {
            switch size {
            case .third:
                compactThirdBody
            case .half:
                halfBody
            case .large:
                largeBody
            }
        }
    }

    @ViewBuilder
    private var largeBody: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Steps Today")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(healthKit.steps)")
                        .font(size.numberFont)
                        .foregroundColor(GQColors.textPrimary)
                        .contentTransition(.numericText())

                    Text("/ \(stepGoal / 1000)K")
                        .font(size.goalFont)
                        .foregroundColor(GQColors.textTertiary)
                }
            }

            Spacer()

            HeroProgressRing(
                progress: progress,
                completed: healthKit.steps >= stepGoal
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var halfBody: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Steps")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(healthKit.steps)")
                        .font(size.numberFont)
                        .foregroundColor(GQColors.textPrimary)
                        .contentTransition(.numericText())

                    Text("/ \(stepGoal / 1000)K")
                        .font(size.goalFont)
                        .foregroundColor(GQColors.textTertiary)
                }
            }

            Spacer()

            HeroProgressRing(
                progress: progress,
                completed: healthKit.steps >= stepGoal,
                size: size.ringSize
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var compactThirdBody: some View {
        VStack(spacing: 4) {
            HeroProgressRing(
                progress: progress,
                completed: healthKit.steps >= stepGoal,
                size: size.ringSize
            )

            Text("\(healthKit.steps)")
                .font(size.numberFont)
                .foregroundColor(GQColors.textPrimary)
                .contentTransition(.numericText())

            Text("/ \(stepGoal / 1000)K")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

// MARK: - Hero Macros Widget

struct HeroMacrosWidget: View {
    var profile: UserProfile
    var size: WidgetSize = .large

    @StateObject private var nutritionService = NutritionService.shared

    private var todaysMeals: [MealLog] {
        nutritionService.getTodaysMeals(userId: profile.id)
    }

    private var protein: Int { todaysMeals.compactMap(\.estimatedProtein).reduce(0, +) }
    private var carbs: Int { todaysMeals.compactMap(\.estimatedCarbs).reduce(0, +) }
    private var fat: Int { todaysMeals.compactMap(\.estimatedFat).reduce(0, +) }

    var body: some View {
        Group {
            switch size {
            case .third:
                compactThirdBody
            case .half:
                halfBody
            case .large:
                largeBody
            }
        }
    }

    @ViewBuilder
    private var largeBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's Macros")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(GQColors.textSecondary)

            macroBar(label: "Protein", current: protein, goal: profile.proteinGoalGrams, color: GQColors.textSecondary)
            macroBar(label: "Carbs", current: carbs, goal: profile.carbsGoalGrams, color: GQColors.textTertiary)
            macroBar(label: "Fat", current: fat, goal: profile.fatGoalGrams, color: GQColors.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var halfBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Macros")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(GQColors.textSecondary)

            macroBarCompact(label: "P", current: protein, goal: profile.proteinGoalGrams, color: GQColors.textSecondary)
            macroBarCompact(label: "C", current: carbs, goal: profile.carbsGoalGrams, color: GQColors.textTertiary)
            macroBarCompact(label: "F", current: fat, goal: profile.fatGoalGrams, color: GQColors.textTertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var compactThirdBody: some View {
        VStack(spacing: 6) {
            Text("Macros")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(GQColors.textSecondary)

            HStack(spacing: 2) {
                Text("P").font(.system(size: 9, weight: .bold)).foregroundColor(GQColors.textSecondary)
                Text("\(protein)").font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundColor(GQColors.textPrimary)
                Text("·").foregroundColor(GQColors.textTertiary)
                Text("C").font(.system(size: 9, weight: .bold)).foregroundColor(GQColors.textTertiary)
                Text("\(carbs)").font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundColor(GQColors.textPrimary)
                Text("·").foregroundColor(GQColors.textTertiary)
                Text("F").font(.system(size: 9, weight: .bold)).foregroundColor(GQColors.textTertiary)
                Text("\(fat)").font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundColor(GQColors.textPrimary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func macroBar(label: String, current: Int, goal: Int, color: Color) -> some View {
        VStack(spacing: 3) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(GQColors.textSecondary)
                Spacer()
                Text("\(current)g / \(goal)g")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(GQColors.textTertiary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(GQColors.adaptiveOverlay(0.08))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * min(CGFloat(current) / max(CGFloat(goal), 1), 1.0), height: 6)
                        .animation(.spring(response: 0.5), value: current)
                }
            }
            .frame(height: 6)
        }
    }

    @ViewBuilder
    private func macroBarCompact(label: String, current: Int, goal: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(GQColors.textSecondary)
                .frame(width: 10)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(GQColors.adaptiveOverlay(0.08))
                        .frame(height: 5)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * min(CGFloat(current) / max(CGFloat(goal), 1), 1.0), height: 5)
                        .animation(.spring(response: 0.5), value: current)
                }
            }
            .frame(height: 5)

            Text("\(current)/\(goal)g")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(GQColors.textTertiary)
                .fixedSize()
        }
    }
}

// MARK: - Hero Active Calories Widget

struct HeroActiveCaloriesWidget: View {
    var size: WidgetSize = .large
    var activeCalGoal: Int = 600

    @StateObject private var healthKit = HealthKitService.shared

    private var progress: Double {
        guard activeCalGoal > 0 else { return 0 }
        return min(Double(healthKit.activeCalories) / Double(activeCalGoal), 1.0)
    }

    var body: some View {
        Group {
            switch size {
            case .third: thirdBody
            case .half: halfBody
            case .large: largeBody
            }
        }
    }

    @ViewBuilder private var largeBody: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Active Calories")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(healthKit.activeCalories)")
                        .font(size.numberFont)
                        .foregroundColor(GQColors.textPrimary)
                        .contentTransition(.numericText())
                    Text("/ \(activeCalGoal)")
                        .font(size.goalFont)
                        .foregroundColor(GQColors.textTertiary)
                }
            }
            Spacer()
            HeroProgressRing(progress: progress, completed: healthKit.activeCalories >= activeCalGoal, color: GQColors.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder private var halfBody: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Burned")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(healthKit.activeCalories)")
                        .font(size.numberFont)
                        .foregroundColor(GQColors.textPrimary)
                        .contentTransition(.numericText())
                    Text("cal")
                        .font(size.goalFont)
                        .foregroundColor(GQColors.textTertiary)
                }
            }
            Spacer()
            HeroProgressRing(progress: progress, completed: healthKit.activeCalories >= activeCalGoal, color: GQColors.textSecondary, size: size.ringSize)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    @ViewBuilder private var thirdBody: some View {
        VStack(spacing: 4) {
            HeroProgressRing(
                progress: progress,
                completed: healthKit.activeCalories >= activeCalGoal,
                color: GQColors.textSecondary,
                size: size.ringSize
            )
            Text("\(healthKit.activeCalories)")
                .font(size.numberFont)
                .foregroundColor(GQColors.textPrimary)
                .contentTransition(.numericText())
            Text("/ \(activeCalGoal) cal")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

// MARK: - Hero Sleep Widget

struct HeroSleepWidget: View {
    var size: WidgetSize = .large

    @StateObject private var healthKit = HealthKitService.shared

    private let sleepGoal: Double = 8.0

    private var progress: Double {
        guard sleepGoal > 0 else { return 0 }
        return min(healthKit.sleepHours / sleepGoal, 1.0)
    }

    private var hoursText: String {
        let h = Int(healthKit.sleepHours)
        let m = Int((healthKit.sleepHours - Double(h)) * 60)
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }

    var body: some View {
        Group {
            switch size {
            case .third: thirdBody
            case .half: halfBody
            case .large: largeBody
            }
        }
    }

    @ViewBuilder private var largeBody: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Last Night's Sleep")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(hoursText)
                        .font(size.numberFont)
                        .foregroundColor(GQColors.textPrimary)
                    Text("/ \(Int(sleepGoal))h")
                        .font(size.goalFont)
                        .foregroundColor(GQColors.textTertiary)
                }
            }
            Spacer()
            HeroProgressRing(progress: progress, completed: healthKit.sleepHours >= sleepGoal, color: GQColors.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder private var halfBody: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Sleep")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)
                Text(hoursText)
                    .font(size.numberFont)
                    .foregroundColor(GQColors.textPrimary)
            }
            Spacer()
            HeroProgressRing(progress: progress, completed: healthKit.sleepHours >= sleepGoal, color: GQColors.textSecondary, size: size.ringSize)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    @ViewBuilder private var thirdBody: some View {
        VStack(spacing: 4) {
            HeroProgressRing(
                progress: progress,
                completed: healthKit.sleepHours >= sleepGoal,
                color: GQColors.textSecondary,
                size: size.ringSize
            )
            Text(hoursText)
                .font(size.numberFont)
                .foregroundColor(GQColors.textPrimary)
            Text("/ \(Int(sleepGoal))h")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

// MARK: - Hero Streak Widget

struct HeroStreakWidget: View {
    var workouts: [Workout] = []
    var size: WidgetSize = .large

    private var streakDays: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let sortedDates = Set(workouts.map { cal.startOfDay(for: $0.date) }).sorted(by: >)
        guard let latest = sortedDates.first else { return 0 }

        // Only count streak if latest workout is today or yesterday
        let daysSinceLast = cal.dateComponents([.day], from: latest, to: today).day ?? 0
        guard daysSinceLast <= 1 else { return 0 }

        var streak = 1
        for i in 1..<sortedDates.count {
            let diff = cal.dateComponents([.day], from: sortedDates[i], to: sortedDates[i - 1]).day ?? 0
            if diff == 1 {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    var body: some View {
        Group {
            switch size {
            case .third: thirdBody
            case .half: halfBody
            case .large: largeBody
            }
        }
    }

    @ViewBuilder private var largeBody: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Workout Streak")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(streakDays)")
                        .font(size.numberFont)
                        .foregroundColor(GQColors.textPrimary)
                        .contentTransition(.numericText())
                    Text(streakDays == 1 ? "day" : "days")
                        .font(size.goalFont)
                        .foregroundColor(GQColors.textTertiary)
                }
            }
            Spacer()
            Image(systemName: "trophy.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(GQColors.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder private var halfBody: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Streak")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(GQColors.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(streakDays)")
                    .font(size.numberFont)
                    .foregroundColor(GQColors.textPrimary)
                    .contentTransition(.numericText())
                Text(streakDays == 1 ? "day" : "days")
                    .font(size.goalFont)
                    .foregroundColor(GQColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    @ViewBuilder private var thirdBody: some View {
        VStack(spacing: 4) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(GQColors.textTertiary)
            Text("\(streakDays)")
                .font(size.numberFont)
                .foregroundColor(GQColors.textPrimary)
                .contentTransition(.numericText())
            Text("Streak")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(GQColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

// MARK: - Hero Heart Rate Widget

struct HeroHeartRateWidget: View {
    var size: WidgetSize = .large

    @StateObject private var healthKit = HealthKitService.shared

    var body: some View {
        Group {
            switch size {
            case .third: thirdBody
            case .half: halfBody
            case .large: largeBody
            }
        }
    }

    @ViewBuilder private var largeBody: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Resting Heart Rate")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(healthKit.restingHeartRate)")
                        .font(size.numberFont)
                        .foregroundColor(GQColors.textPrimary)
                        .contentTransition(.numericText())
                    Text("bpm")
                        .font(size.goalFont)
                        .foregroundColor(GQColors.textTertiary)
                }
            }
            Spacer()
            Image(systemName: "heart.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(GQColors.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder private var halfBody: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Heart Rate")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(GQColors.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(healthKit.restingHeartRate)")
                    .font(size.numberFont)
                    .foregroundColor(GQColors.textPrimary)
                    .contentTransition(.numericText())
                Text("bpm")
                    .font(size.goalFont)
                    .foregroundColor(GQColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    @ViewBuilder private var thirdBody: some View {
        VStack(spacing: 4) {
            Image(systemName: "heart.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(GQColors.textTertiary)
            Text("\(healthKit.restingHeartRate)")
                .font(size.numberFont)
                .foregroundColor(GQColors.textPrimary)
                .contentTransition(.numericText())
            Text("bpm")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(GQColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

// MARK: - Hero Recovery Widget

struct HeroRecoveryWidget: View {
    var size: WidgetSize = .large

    @StateObject private var integration = IntegrationManager.shared

    private var recoveryColor: Color {
        switch integration.readinessLevel {
        case .optimal: GQColors.textSecondary
        case .good: GQColors.textSecondary
        case .moderate: GQColors.textTertiary
        case .low: GQColors.textTertiary
        }
    }

    var body: some View {
        Group {
            switch size {
            case .third: thirdBody
            case .half: halfBody
            case .large: largeBody
            }
        }
    }

    @ViewBuilder private var largeBody: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Recovery")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(Int(integration.recoveryScore))%")
                        .font(size.numberFont)
                        .foregroundColor(GQColors.textPrimary)
                        .contentTransition(.numericText())
                    Text(integration.readinessLevel.rawValue)
                        .font(size.goalFont)
                        .foregroundColor(recoveryColor)
                }
            }
            Spacer()
            HeroProgressRing(progress: integration.recoveryScore / 100, completed: integration.recoveryScore >= 67, color: recoveryColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder private var halfBody: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Recovery")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)
                Text("\(Int(integration.recoveryScore))%")
                    .font(size.numberFont)
                    .foregroundColor(GQColors.textPrimary)
                    .contentTransition(.numericText())
            }
            Spacer()
            HeroProgressRing(progress: integration.recoveryScore / 100, completed: integration.recoveryScore >= 67, color: recoveryColor, size: size.ringSize)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    @ViewBuilder private var thirdBody: some View {
        VStack(spacing: 4) {
            Image(systemName: "battery.100.bolt")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(recoveryColor)
            Text("\(Int(integration.recoveryScore))%")
                .font(size.numberFont)
                .foregroundColor(GQColors.textPrimary)
                .contentTransition(.numericText())
            Text("Recovery")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(GQColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

// MARK: - Social Hero Widget (Grid Dispatcher + Jiggle Edit Mode)

struct SocialHeroWidget: View {
    var profile: UserProfile
    var workoutsCompleted: Int
    var allWorkouts: [Workout]

    @Environment(\.modelContext) private var modelContext
    @State private var isEditing = false
    @State private var pickerSlotIndex: Int? = nil
    @State private var showHint = false
    @AppStorage("hasSeenWidgetHint") private var hasSeenHint = false

    private var config: WidgetGridConfig { profile.widgetGridConfig }

    var body: some View {
        VStack(spacing: 8) {
            if config.allEmpty && !isEditing {
                addWidgetButton
            } else {
                if isEditing {
                    layoutPickerRow
                }

                widgetGrid
                    .overlay(alignment: .bottom) {
                        if showHint && !isEditing {
                            Text("Hold to customize")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(GQColors.textTertiary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.ultraThinMaterial, in: Capsule())
                                .offset(y: 24)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }

                if isEditing {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isEditing = false
                        }
                    } label: {
                        Text("Done")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(GQColors.vividPurple)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                            .background(GQColors.adaptiveOverlay(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .sheet(item: $pickerSlotIndex) { slotIndex in
            WidgetSlotPicker(profile: profile, slotIndex: slotIndex)
                .environment(\.modelContext, modelContext)
        }
        .onAppear {
            guard !hasSeenHint, !config.allEmpty else { return }
            withAnimation(.easeOut(duration: 0.4).delay(1.0)) {
                showHint = true
            }
            withAnimation(.easeIn(duration: 0.4).delay(4.0)) {
                showHint = false
            }
            hasSeenHint = true
        }
    }

    // MARK: - Add Widget Button (all slots empty)

    @ViewBuilder
    private var addWidgetButton: some View {
        Button {
            enterEditMode()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                Text("Add widget")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(GQColors.textTertiary)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Layout Picker Row

    @ViewBuilder
    private var layoutPickerRow: some View {
        HStack(spacing: 2) {
            ForEach(WidgetLayout.allCases, id: \.self) { layout in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        var newConfig = config
                        newConfig.layout = layout
                        newConfig.adjustSlots()
                        profile.widgetGridConfig = newConfig
                        try? modelContext.save()
                    }
                } label: {
                    layoutIcon(for: layout)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            config.layout == layout
                                ? GQColors.adaptiveOverlay(0.12)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(GQColors.adaptiveOverlay(0.06), in: RoundedRectangle(cornerRadius: 9))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    @ViewBuilder
    private func layoutIcon(for layout: WidgetLayout) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<layout.slotCount, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 2)
                    .fill(config.layout == layout ? GQColors.textPrimary : GQColors.textTertiary)
                    .frame(width: layout == .single ? 16 : 8, height: 12)
            }
        }
    }

    // MARK: - Widget Grid

    @ViewBuilder
    private var widgetGrid: some View {
        switch config.layout {
        case .single:
            slotView(index: 0, size: .large)
        case .double:
            HStack(spacing: 8) {
                slotView(index: 0, size: .half)
                slotView(index: 1, size: .half)
            }
        case .triple:
            HStack(spacing: 8) {
                slotView(index: 0, size: .third)
                slotView(index: 1, size: .third)
                slotView(index: 2, size: .third)
            }
        }
    }

    // MARK: - Slot View (wraps widget content + edit chrome)

    @ViewBuilder
    private func slotView(index: Int, size: WidgetSize) -> some View {
        let widgetType = index < config.slots.count ? config.slots[index] : .none

        Group {
            if widgetType == .none {
                emptySlotView(index: index)
            } else {
                widgetContentView(type: widgetType, size: size)
            }
        }
        .homeSocialCard()
        .frame(minHeight: size == .third ? 80 : nil)
        .overlay {
            if isEditing && widgetType != .none {
                // Tap-to-change overlay
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black.opacity(0.35))
                    .overlay {
                        VStack(spacing: 4) {
                            Image(systemName: "pencil")
                                .font(.system(size: size == .third ? 16 : 20, weight: .semibold))
                            if size != .third {
                                Text("Tap to change")
                                    .font(.system(size: 11, weight: .medium))
                            }
                        }
                        .foregroundColor(GQColors.textSecondary)
                    }
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .topLeading) {
            if isEditing && widgetType != .none {
                Button {
                    clearSlot(index)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white, Color.black.opacity(0.4))
                }
                .buttonStyle(.plain)
                .offset(x: -6, y: -6)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .scaleEffect(isEditing ? 0.96 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isEditing)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    if !isEditing {
                        enterEditMode()
                    }
                }
        )
        .onTapGesture {
            if isEditing {
                pickerSlotIndex = index
            }
        }
    }

    // MARK: - Empty Slot

    @ViewBuilder
    private func emptySlotView(index: Int) -> some View {
        Button {
            if isEditing {
                pickerSlotIndex = index
            } else {
                enterEditMode()
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(GQColors.textTertiary)
                if config.layout != .triple {
                    Text("Add")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 60)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Widget Content Router

    @ViewBuilder
    private func widgetContentView(type: SocialWidgetType, size: WidgetSize) -> some View {
        switch type {
        case .workouts:
            WeeklyHeroSection(
                completed: workoutsCompleted,
                goal: profile.daysPerWeek,
                profile: profile,
                workouts: allWorkouts,
                size: size
            )
        case .calories:
            HeroCaloriesWidget(profile: profile, size: size)
        case .steps:
            HeroStepsWidget(size: size)
        case .macros:
            HeroMacrosWidget(profile: profile, size: size)
        case .activeCalories:
            HeroActiveCaloriesWidget(size: size)
        case .sleep:
            HeroSleepWidget(size: size)
        case .streak:
            HeroStreakWidget(workouts: allWorkouts, size: size)
        case .heartRate:
            HeroHeartRateWidget(size: size)
        case .recovery:
            HeroRecoveryWidget(size: size)
        case .none:
            EmptyView()
        }
    }

    // MARK: - Actions

    private func enterEditMode() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isEditing = true
        }
    }

    private func clearSlot(_ index: Int) {
        var newConfig = config
        if index < newConfig.slots.count {
            newConfig.slots[index] = .none
        }
        profile.widgetGridConfig = newConfig
        try? modelContext.save()
    }
}

// MARK: - Int Identifiable for sheet(item:)

extension Int: @retroactive Identifiable {
    public var id: Int { self }
}

// MARK: - Widget Slot Picker

struct WidgetSlotPicker: View {
    var profile: UserProfile
    let slotIndex: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private var currentType: SocialWidgetType {
        let config = profile.widgetGridConfig
        return slotIndex < config.slots.count ? config.slots[slotIndex] : .none
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(SocialWidgetType.allCases.filter { $0 != .none }, id: \.self) { type in
                    Button {
                        setSlot(to: type)
                    } label: {
                        pickerRow(type: type)
                    }
                }

                Section {
                    Button {
                        setSlot(to: .none)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "trash")
                                .font(.system(size: 16))
                                .foregroundColor(.red)
                                .frame(width: 28, height: 28)

                            Text("Remove")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.red)

                            Spacer()

                            if currentType == .none {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Choose Widget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func pickerRow(type: SocialWidgetType) -> some View {
        HStack(spacing: 12) {
            Image(systemName: type.iconName)
                .font(.system(size: 16))
                .foregroundColor(type.accentColor)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(type.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)
                Text(type.subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textSecondary)
            }

            Spacer()

            if currentType == type {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(type.accentColor)
            }
        }
        .padding(.vertical, 4)
    }

    private func setSlot(to type: SocialWidgetType) {
        var newConfig = profile.widgetGridConfig
        while newConfig.slots.count <= slotIndex {
            newConfig.slots.append(.workouts)
        }
        newConfig.slots[slotIndex] = type
        profile.widgetGridConfig = newConfig
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Working Out Now Row

struct WorkingOutNowRow: View {
    @EnvironmentObject var appState: AppState
    var recentFriendCount: Int = 0

    private let socialService = SocialActivityService.shared

    @State private var selectedFriend: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 7, height: 7)
                Text("ACTIVE NOW")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(GQColors.textTertiary)
                Text("\u{00B7}")
                    .foregroundColor(GQColors.textTertiary)
                Text("\(socialService.friendsActiveToday) friends today")
                    .font(.system(size: 11))
                    .foregroundColor(GQColors.textTertiary)
            }

            // Friend avatars
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(socialService.activeFriends) { friend in
                        Button {
                            selectedFriend = friend.name
                        } label: {
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle()
                                        .fill(GQGradients.primary)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Text(friend.avatarInitial)
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundColor(.white)
                                        )

                                    if friend.isLive {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 10, height: 10)
                                            .overlay(Circle().stroke(GQColors.surfaceBase, lineWidth: 2))
                                            .offset(x: 14, y: 14)
                                    }
                                }

                                Text(friend.name)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(GQColors.textPrimary)

                                Text(friend.workoutType)
                                    .font(.system(size: 10))
                                    .foregroundColor(GQColors.textTertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 2)
            }
        }
        .padding(.vertical, 8)
        .sheet(item: Binding<WorkoutStoryItem?>(
            get: {
                guard let name = selectedFriend,
                      let friend = socialService.activeFriends.first(where: { $0.name == name })
                else { return nil }
                return WorkoutStoryItem(name: friend.name, type: friend.workoutType, minutes: friend.minutesElapsed, workout: "\(friend.workoutType) Day", exercises: friend.exercise, gymName: friend.gymName, gymArea: friend.gymArea, gymCoordinate: friend.gymCoordinate)
            },
            set: { item in
                selectedFriend = item?.name
            }
        )) { friend in
            WorkoutStorySheet(friend: friend)
                .presentationDetents([.medium, .large])
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
    let gymName: String?
    let gymArea: String?
    let gymCoordinate: (lat: Double, lng: Double)?
}

struct WorkoutStorySheet: View {
    let friend: WorkoutStoryItem
    @Environment(\.dismiss) private var dismiss
    @State private var showJoinToast = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    workoutInfoCard
                    if friend.gymName != nil {
                        locationSection
                    }
                    Spacer(minLength: 40)
                }
            }

            joinConfirmationToast
        }
        .gqPageBackground()
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
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
                if let gymName = friend.gymName {
                    HStack(spacing: 4) {
                        Text("📍")
                            .font(.system(size: 11))
                        Text(gymName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(GQColors.cyanSpark)
                        if let area = friend.gymArea {
                            Text("·")
                                .font(.system(size: 12))
                                .foregroundColor(GQColors.textTertiary)
                            Text(area)
                                .font(.system(size: 12))
                                .foregroundColor(GQColors.textTertiary)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    // MARK: - Workout Info Card

    @ViewBuilder
    private var workoutInfoCard: some View {
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
    }

    // MARK: - Location Section

    @ViewBuilder
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gym Location")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text("\(friend.name) is sharing")
                        .font(.system(size: 12))
                        .foregroundColor(GQColors.textTertiary)
                }
                Spacer()
            }

            if let coord = friend.gymCoordinate {
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: coord.lat, longitude: coord.lng),
                    span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
                ))) {
                    Marker(friend.gymName ?? "Gym", coordinate: CLLocationCoordinate2D(latitude: coord.lat, longitude: coord.lng))
                        .tint(GQColors.cyanSpark)
                }
                .frame(height: 140)
                .cornerRadius(12)
                .allowsHitTesting(false)
            }

            Button {
                #if canImport(UIKit)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                #endif
                withAnimation(.spring(response: 0.4)) {
                    showJoinToast = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    dismiss()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 15, weight: .semibold))
                    Text("On my way!")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [GQColors.deepBlue, GQColors.cyanSpark],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
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
        .padding(.top, 16)
    }

    // MARK: - Join Confirmation Toast

    @ViewBuilder
    private var joinConfirmationToast: some View {
        if showJoinToast {
            VStack {
                Spacer()
                Text("🏃 On my way! \(friend.name) was notified")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                            .overlay(
                                Capsule()
                                    .stroke(GQColors.cyanSpark.opacity(0.3), lineWidth: 0.5)
                            )
                    )
                    .padding(.bottom, 30)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: - Enhanced Post Header

struct PostHeaderEnhanced: View {
    let post: Post
    let activityType: DetectedActivity?
    var locationName: String? = nil
    var onTapUser: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            // Simple avatar (tappable)
            Button {
                onTapUser?()
            } label: {
                Circle()
                    .fill(GQGradients.primary)
                    .frame(width: 42, height: 42)
                    .overlay(
                        Text(String(post.authorName.prefix(1)).uppercased())
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Button {
                    onTapUser?()
                } label: {
                    HStack(spacing: 4) {
                        Text(post.authorName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(GQColors.textPrimary)

                        Text("@\(post.authorUsername)")
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textTertiary)
                    }
                }
                .buttonStyle(.plain)

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
                    .foregroundColor(GQColors.vividPurple)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(GQColors.vividPurple.opacity(0.12))
                    .cornerRadius(12)
            }
        }
    }
}

struct PostMediaView: View {
    let post: Post
    @Binding var showVideoPlayer: Bool
    #if canImport(UIKit)
    @State private var cachedImage: UIImage?
    #elseif canImport(AppKit)
    @State private var cachedImage: NSImage?
    #endif
    var body: some View {
        Group {
            if post.photoData != nil {
                #if canImport(UIKit)
                if let uiImage = cachedImage {
                    Color.clear
                        .aspectRatio(4.0/4.5, contentMode: .fit)
                        .overlay(
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        )
                        .clipShape(Rectangle())
                }
                #elseif canImport(AppKit)
                if let nsImage = cachedImage {
                    Color.clear
                        .aspectRatio(4.0/4.5, contentMode: .fit)
                        .overlay(
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        )
                        .clipShape(Rectangle())
                }
                #endif
            } else if post.videoData != nil {
                InlineFeedVideoPlayer(videoData: post.videoData!, showVideoPlayer: $showVideoPlayer)
            }
        }
        .task {
            guard cachedImage == nil, let data = post.photoData else { return }
            #if canImport(UIKit)
            cachedImage = UIImage(data: data)
            #elseif canImport(AppKit)
            cachedImage = NSImage(data: data)
            #endif
        }
    }
}

struct InlineFeedVideoPlayer: View {
    let videoData: Data
    @Binding var showVideoPlayer: Bool
    @State private var player: AVPlayer?
    @State private var isMuted = true

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.clear
                .aspectRatio(4.0/4.5, contentMode: .fit)
                .overlay(
                    VideoPlayer(player: player)
                        .aspectRatio(contentMode: .fill)
                )
                .clipped()
                .disabled(true)
                .onTapGesture {
                    showVideoPlayer = true
                }

            Button {
                isMuted.toggle()
                player?.isMuted = isMuted
            } label: {
                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .clipShape(Circle())
            }
            .padding(12)
        }
        .onAppear { setupAndPlay() }
        .onDisappear { player?.pause() }
    }

    private func setupAndPlay() {
        guard player == nil else { player?.play(); return }
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mov")
        try? videoData.write(to: tempURL)
        let p = AVPlayer(url: tempURL)
        p.isMuted = true
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: p.currentItem, queue: .main
        ) { _ in p.seek(to: .zero); p.play() }
        player = p
        p.play()
    }
}

struct WorkoutStatsBar: View {
    let duration: Int?
    let setCount: Int?

    var body: some View {
        HStack(spacing: 16) {
            if let duration = duration, duration > 0 {
                Label("\(duration) min", systemImage: "clock")
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textTertiary)
            }

            if let sets = setCount, sets > 0 {
                Label("\(sets) sets", systemImage: "flame")
                    .font(.system(size: 13))
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
                        .font(.system(size: 20))
                        .foregroundColor(isLiked ? .red : GQColors.textPrimary)
                    if post.likeCount > 0 {
                        Text("\(post.likeCount)")
                            .font(.system(size: 13))
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
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textTertiary)
                    }
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(GQColors.textPrimary)

            // Learn This (if workout post)
            if let onLearn = onLearnThis {
                Button(action: onLearn) {
                    HStack(spacing: 4) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 13))
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
            .foregroundColor(GQColors.textPrimary)
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
    @State private var sentReactionEmoji: String? = nil
    @State private var showSentReaction = false

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

                if showSentReaction, let emoji = sentReactionEmoji {
                    SentReactionOverlay(emoji: emoji)
                        .zIndex(11)
                }

                Button {
                    performLikeAnimation()
                } label: {
                    HStack(spacing: 6) {
                        ZStack {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 22))
                                .foregroundColor(isLiked ? .red : GQColors.textPrimary)
                                .scaleEffect(heartScale)

                            if showParticles {
                                HeartBurstOverlay(isActive: showParticles)
                            }
                        }

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
            .foregroundColor(GQColors.textPrimary)

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
            .foregroundColor(GQColors.textPrimary)
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

        sentReactionEmoji = type.emoji
        showSentReaction = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(2200))
            showSentReaction = false
            sentReactionEmoji = nil
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
    let profile: UserProfile
    let onAddToPlan: (LearningItem) -> Void
    let onClose: () -> Void

    @Query(sort: \LearningItem.createdAt, order: .reverse) private var allLearningItems: [LearningItem]
    private var learningItems: [LearningItem] {
        allLearningItems.filter { $0.exerciseName == exerciseName }
    }

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
            if FeatureFlags.shared.exerciseGifsEnabled {
                ExerciseGifView(exerciseName: exerciseName, size: .large, showFallback: false)
            }

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
                        .textFieldStyle(LiftAITextFieldStyle())

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
                .fill(GQGradients.primary)
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(comment.authorName.prefix(1)).uppercased())
                        .font(.system(size: 13, weight: .bold))
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

struct EmptyFeedState: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 80)

            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(GQGradients.primary)

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(GQColors.textPrimary)

                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundColor(GQColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
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

                Text("Share your first post with the club")
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
                    Color.clear
                        .aspectRatio(4.0/4.5, contentMode: .fit)
                        .overlay(
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        )
                        .clipped()
                        .cornerRadius(12)
                }
                #elseif canImport(AppKit)
                if let nsImage = NSImage(data: photoData) {
                    Color.clear
                        .aspectRatio(4.0/4.5, contentMode: .fit)
                        .overlay(
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        )
                        .clipped()
                        .cornerRadius(12)
                }
                #endif
            } else if let videoData = post.videoData {
                InlineFeedVideoPlayer(videoData: videoData, showVideoPlayer: $showVideoPlayer)
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

// MARK: - Club Seeder

struct ClubSeeder {
    static func seedIfNeeded(modelContext: ModelContext, userId: UUID) {
        let descriptor = FetchDescriptor<Club>(predicate: #Predicate { $0.parentClubId == nil })
        let existing = (try? modelContext.fetchCount(descriptor)) ?? 0

        let users = SocialSeeder.fakeUsers

        // Seed clubs + posts + challenges if first run
        if existing == 0 {
            seedClubs(modelContext: modelContext, userId: userId, users: users)
        }

        // Seed events separately so existing installs get them without data wipe
        let eventDescriptor = FetchDescriptor<ClubEvent>()
        let existingEvents = (try? modelContext.fetchCount(eventDescriptor)) ?? 0
        if existingEvents == 0 {
            seedEvents(modelContext: modelContext, userId: userId, users: users)
        }

        try? modelContext.save()
    }

    private static func seedClubs(modelContext: ModelContext, userId: UUID, users: [(id: UUID, name: String, username: String)]) {
        let cal = Calendar.current

        // Queen's Run Club
        let runClub = Club(
            name: "Queen's Run Club",
            clubDescription: "Weekly group runs around Kingston. All paces welcome.",
            location: "Kingston, ON",
            latitude: 44.2253,
            longitude: -76.4951,
            creatorId: users[0].id,
            memberIds: [userId] + users.prefix(6).map(\.id),
            joinType: .open,
            memberCount: 178,
            isVerified: true,
            tags: ["running", "cardio", "kingston"],
            category: .running
        )
        modelContext.insert(runClub)

        // Run Club channels
        for name in ["5K Group", "Long Distance", "Trail Runners"] {
            let channel = Club(
                name: name,
                clubDescription: "",
                creatorId: users[0].id,
                memberIds: [userId] + users.prefix(3).map(\.id),
                memberCount: Int.random(in: 20...60),
                parentClubId: runClub.id
            )
            modelContext.insert(channel)
        }

        // Kingston Pickup Basketball
        let basketball = Club(
            name: "Kingston Pickup Basketball",
            clubDescription: "Pickup games around Kingston. Drop in anytime.",
            location: "Kingston, ON",
            latitude: 44.2312,
            longitude: -76.4860,
            creatorId: users[1].id,
            memberIds: [userId] + users.prefix(5).map(\.id),
            joinType: .open,
            memberCount: 124,
            tags: ["basketball", "pickup", "kingston"],
            category: .basketball
        )
        modelContext.insert(basketball)

        for name in ["West End Courts", "Queen's Gym"] {
            let channel = Club(
                name: name,
                clubDescription: "",
                creatorId: users[1].id,
                memberIds: [userId] + users.prefix(2).map(\.id),
                memberCount: Int.random(in: 20...50),
                parentClubId: basketball.id
            )
            modelContext.insert(channel)
        }

        // Queen's Powerlifting
        let powerlifting = Club(
            name: "Queen's Powerlifting",
            clubDescription: "Squat, bench, deadlift. Compete or just train with us.",
            location: "Kingston, ON",
            latitude: 44.2280,
            longitude: -76.4935,
            creatorId: users[2].id,
            memberIds: [userId] + users.prefix(6).map(\.id),
            joinType: .open,
            memberCount: 156,
            isVerified: true,
            tags: ["powerlifting", "strength", "kingston"],
            category: .weightlifting
        )
        modelContext.insert(powerlifting)

        // Kingston Cycling Group
        let cycling = Club(
            name: "Kingston Cycling Group",
            clubDescription: "Road rides and gravel routes around the Kingston area.",
            location: "Kingston, ON",
            latitude: 44.2300,
            longitude: -76.4800,
            creatorId: users[3].id,
            memberIds: users.prefix(4).map(\.id),
            joinType: .open,
            memberCount: 92,
            tags: ["cycling", "road", "kingston"],
            category: .cycling
        )
        modelContext.insert(cycling)

        // Campus Yoga
        let yoga = Club(
            name: "Campus Yoga",
            clubDescription: "Free flow sessions on campus. Mats provided.",
            location: "Kingston, ON",
            latitude: 44.2260,
            longitude: -76.4970,
            creatorId: users[4].id,
            memberIds: users.prefix(5).map(\.id),
            joinType: .open,
            memberCount: 210,
            tags: ["yoga", "mindfulness", "kingston"],
            category: .yoga
        )
        modelContext.insert(yoga)

        // Queen's Intramural Soccer
        let soccer = Club(
            name: "Queen's Intramural Soccer",
            clubDescription: "Co-ed intramural soccer. Scrimmages every Thursday.",
            location: "Kingston, ON",
            latitude: 44.2240,
            longitude: -76.5010,
            creatorId: users[5].id,
            memberIds: users.prefix(4).map(\.id),
            joinType: .open,
            memberCount: 86,
            isVerified: true,
            tags: ["soccer", "intramural", "kingston"],
            category: .soccer
        )
        modelContext.insert(soccer)

        // Global clubs
        let homeGym = Club(
            name: "Home Gym Heroes",
            clubDescription: "For everyone training at home",
            creatorId: users[2].id,
            memberIds: users.prefix(4).map(\.id),
            joinType: .open,
            memberCount: 1420,
            tags: ["global"],
            category: .generalFitness
        )
        modelContext.insert(homeGym)

        let beginnerGains = Club(
            name: "Beginner Gains",
            clubDescription: "New to lifting? Start here",
            creatorId: users[6].id,
            memberIds: users.prefix(4).map(\.id),
            joinType: .open,
            memberCount: 3200,
            tags: ["global"],
            category: .weightlifting
        )
        modelContext.insert(beginnerGains)

        let prChasers = Club(
            name: "PR Chasers",
            clubDescription: "Chasing personal records every week",
            creatorId: users[7].id,
            memberIds: users.prefix(4).map(\.id),
            joinType: .open,
            memberCount: 890,
            tags: ["global"],
            category: .weightlifting
        )
        modelContext.insert(prChasers)

        // Seed memberships for user's clubs
        let userClubs = [runClub, basketball, powerlifting]
        for comm in userClubs {
            let userMembership = ClubMembership(
                userId: userId,
                clubId: comm.id,
                role: .member
            )
            modelContext.insert(userMembership)

            for (i, user) in users.prefix(6).enumerated() {
                guard comm.memberIds.contains(user.id) else { continue }
                let membership = ClubMembership(
                    userId: user.id,
                    clubId: comm.id,
                    role: i == 0 ? .admin : .member,
                    workoutPartnerStatus: [1, 2, 4].contains(i) ? .available : .notLooking
                )
                modelContext.insert(membership)
            }
        }

        // Seed challenges
        let runChallenge = ClubChallenge(
            clubId: runClub.id,
            title: "50km This Week",
            challengeDescription: "Log 50km of running before Sunday. Every km counts.",
            goalType: .distance,
            goalTarget: 50,
            currentProgress: 32,
            startDate: cal.date(byAdding: .day, value: -4, to: Date()) ?? Date(),
            endDate: cal.date(byAdding: .day, value: 3, to: Date()) ?? Date(),
            participantIds: [userId] + users.prefix(4).map(\.id)
        )
        modelContext.insert(runChallenge)

        let plChallenge = ClubChallenge(
            clubId: powerlifting.id,
            title: "Complete 20 Sets",
            challengeDescription: "Hit 20 total sets of squat, bench, or deadlift this week",
            goalType: .sets,
            goalTarget: 20,
            currentProgress: 13,
            startDate: cal.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
            endDate: cal.date(byAdding: .day, value: 4, to: Date()) ?? Date(),
            participantIds: [userId] + users.prefix(5).map(\.id)
        )
        modelContext.insert(plChallenge)

        let bbChallenge = ClubChallenge(
            clubId: basketball.id,
            title: "5 Pickup Games This Month",
            challengeDescription: "Show up to 5 pickup sessions this month",
            goalType: .games,
            goalTarget: 5,
            currentProgress: 2,
            startDate: cal.date(byAdding: .day, value: -10, to: Date()) ?? Date(),
            endDate: cal.date(byAdding: .day, value: 20, to: Date()) ?? Date(),
            participantIds: [userId] + users.prefix(3).map(\.id)
        )
        modelContext.insert(bbChallenge)

        // Seed club posts
        let samplePosts: [(UUID, Int, String, ClubPostType)] = [
            (runClub.id, 0, "New 5K PR this morning! 22:14. The waterfront route hits different at sunrise", .achievement),
            (runClub.id, 2, "Anyone want to pace me for a 10K this weekend?", .lookingForPartner),
            (basketball.id, 1, "Last night's pickup game was insane. That buzzer-beater shot was unreal", .general),
            (basketball.id, 3, "Looking for a 5th for Tuesday evening games at the ARC", .lookingForPartner),
            (powerlifting.id, 4, "Hit 315 deadlift today. New PR by 10 lbs!", .achievement),
            (powerlifting.id, 5, "The platform was empty at 6am. Rare W", .general),
            (soccer.id, 7, "Thursday scrimmage was a 4-3 thriller. See everyone next week", .general),
        ]

        for (cid, userIdx, content, ptype) in samplePosts {
            let user = users[userIdx]
            let post = ClubPost(
                clubId: cid,
                authorId: user.id,
                authorName: user.name,
                authorUsername: user.username,
                postType: ptype,
                content: content,
                likeCount: Int.random(in: 2...18),
                commentCount: Int.random(in: 0...5),
                timestamp: Date().addingTimeInterval(Double.random(in: -86400...0))
            )
            modelContext.insert(post)
        }

        // Posts for global clubs
        let globalClubs = [homeGym, beginnerGains, prChasers]
        let globalPosts: [(String, Int, String, ClubPostType)] = [
            ("Home Gym Heroes", 8, "Finally got a squat rack in my garage. Game changer", .achievement),
            ("Home Gym Heroes", 6, "Resistance bands + bodyweight = underrated combo", .workout),
            ("Beginner Gains", 9, "Just finished my first ever full week of training!", .achievement),
            ("Beginner Gains", 3, "What's the difference between sumo and conventional deadlift?", .question),
            ("PR Chasers", 4, "315 squat at 165 bodyweight. PR by 10 lbs!", .achievement),
        ]

        for (commName, userIdx, content, ptype) in globalPosts {
            if let comm = globalClubs.first(where: { $0.name == commName }) {
                let user = users[userIdx]
                let post = ClubPost(
                    clubId: comm.id,
                    authorId: user.id,
                    authorName: user.name,
                    authorUsername: user.username,
                    postType: ptype,
                    content: content,
                    likeCount: Int.random(in: 3...22),
                    commentCount: Int.random(in: 0...4),
                    timestamp: Date().addingTimeInterval(Double.random(in: -86400...0))
                )
                modelContext.insert(post)
            }
        }
    }

    private static func seedEvents(modelContext: ModelContext, userId: UUID, users: [(id: UUID, name: String, username: String)]) {
        let cal = Calendar.current
        let now = Date()

        let allComms = (try? modelContext.fetch(FetchDescriptor<Club>(predicate: #Predicate { $0.parentClubId == nil }))) ?? []
        guard let runClub = allComms.first(where: { $0.name == "Queen's Run Club" }),
              let basketball = allComms.first(where: { $0.name == "Kingston Pickup Basketball" }),
              let powerlifting = allComms.first(where: { $0.name == "Queen's Powerlifting" }),
              let cycling = allComms.first(where: { $0.name == "Kingston Cycling Group" }),
              let soccer = allComms.first(where: { $0.name == "Queen's Intramural Soccer" }) else { return }

        // Helper: next occurrence of a weekday at a given hour
        func nextWeekday(_ weekday: Int, hour: Int, minute: Int = 0) -> Date {
            var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear, .weekday], from: now)
            comps.weekday = weekday
            comps.hour = hour
            comps.minute = minute
            var target = cal.date(from: comps) ?? now
            if target <= now { target = cal.date(byAdding: .weekOfYear, value: 1, to: target) ?? target }
            return target
        }

        // Wednesday 5K Loop (Run Club, recurring weekly)
        let e1 = ClubEvent(
            clubId: runClub.id,
            creatorId: users[0].id,
            creatorName: users[0].name,
            title: "Wednesday 5K Loop",
            eventDescription: "Meet at the waterfront for a 5K group run. All paces welcome.",
            location: "Kingston Waterfront",
            date: nextWeekday(4, hour: 18),
            endDate: nextWeekday(4, hour: 19),
            maxAttendees: 30,
            attendeeIds: [userId, users[0].id, users[2].id, users[4].id],
            eventType: .groupRun,
            isRecurring: true,
            recurrenceRule: "weekly"
        )

        // Friday Night Hoops (Basketball, recurring weekly)
        let e2 = ClubEvent(
            clubId: basketball.id,
            creatorId: users[1].id,
            creatorName: users[1].name,
            title: "Friday Night Hoops",
            eventDescription: "Pickup basketball at the ARC. First 10 play, winners stay on.",
            location: "The ARC - Gymnasium",
            date: nextWeekday(6, hour: 19),
            endDate: nextWeekday(6, hour: 21),
            maxAttendees: 20,
            attendeeIds: [userId, users[1].id, users[3].id, users[5].id, users[7].id],
            eventType: .pickupGame,
            isRecurring: true,
            recurrenceRule: "weekly"
        )

        // Powerlifting Mock Meet
        let e3 = ClubEvent(
            clubId: powerlifting.id,
            creatorId: users[2].id,
            creatorName: users[2].name,
            title: "Powerlifting Mock Meet",
            eventDescription: "Squat, bench, deadlift. 3 attempts each. Friendly competition — all levels.",
            location: "The ARC - Platform Area",
            date: cal.date(byAdding: .day, value: 5, to: cal.startOfDay(for: now))!.addingTimeInterval(10 * 3600),
            endDate: cal.date(byAdding: .day, value: 5, to: cal.startOfDay(for: now))!.addingTimeInterval(14 * 3600),
            maxAttendees: 20,
            attendeeIds: [users[0].id, users[2].id, users[4].id, users[6].id, users[8].id],
            eventType: .competition
        )

        // Saturday Morning Ride (Cycling, recurring weekly)
        let e4 = ClubEvent(
            clubId: cycling.id,
            creatorId: users[3].id,
            creatorName: users[3].name,
            title: "Saturday Morning Ride",
            eventDescription: "50km road ride out to Gananoque and back. Moderate pace.",
            location: "Kingston City Hall",
            date: nextWeekday(7, hour: 7, minute: 30),
            endDate: nextWeekday(7, hour: 10),
            attendeeIds: [users[3].id, users[6].id],
            eventType: .groupRide,
            isRecurring: true,
            recurrenceRule: "weekly"
        )

        // Thursday Scrimmage (Soccer, recurring weekly)
        let e5 = ClubEvent(
            clubId: soccer.id,
            creatorId: users[5].id,
            creatorName: users[5].name,
            title: "Thursday Scrimmage",
            eventDescription: "Co-ed scrimmage on the turf field. Bring cleats.",
            location: "Queen's Turf Field",
            date: nextWeekday(5, hour: 18),
            endDate: nextWeekday(5, hour: 19, minute: 30),
            maxAttendees: 22,
            attendeeIds: [users[5].id, users[7].id, users[9].id],
            eventType: .scrimmage,
            isRecurring: true,
            recurrenceRule: "weekly"
        )

        // Past events
        let e6 = ClubEvent(
            clubId: runClub.id,
            creatorId: users[0].id,
            creatorName: users[0].name,
            title: "Sunrise 10K",
            eventDescription: "Early morning 10K along the waterfront trail.",
            location: "Kingston Waterfront",
            date: cal.date(byAdding: .day, value: -3, to: cal.startOfDay(for: now))!.addingTimeInterval(6 * 3600),
            endDate: cal.date(byAdding: .day, value: -3, to: cal.startOfDay(for: now))!.addingTimeInterval(7.5 * 3600),
            attendeeIds: [userId, users[0].id, users[2].id, users[4].id, users[6].id],
            eventType: .groupRun
        )

        let e7 = ClubEvent(
            clubId: basketball.id,
            creatorId: users[1].id,
            creatorName: users[1].name,
            title: "3v3 Tournament",
            eventDescription: "Single elimination 3v3 tournament. Prizes for winners.",
            location: "The ARC - Gymnasium",
            date: cal.date(byAdding: .day, value: -5, to: cal.startOfDay(for: now))!.addingTimeInterval(14 * 3600),
            attendeeIds: [users[1].id, users[3].id, users[5].id, users[7].id, users[9].id],
            eventType: .tournament
        )

        for event in [e1, e2, e3, e4, e5, e6, e7] {
            modelContext.insert(event)
        }
    }
}

// MARK: - Club Feed View (embedded in Feed tab)

private enum ClubViewMode: String, CaseIterable {
    case list = "List"
    case map = "Map"
}

struct ClubFeedView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allClubs: [Club]
    @Query private var allClubPosts: [ClubPost]

    let profile: UserProfile

    @State private var showingCreateClub = false
    @State private var selectedClub: Club?
    @State private var selectedCategory: ClubCategory? = nil
    @State private var clubViewMode: ClubViewMode = .list
    @State private var searchText: String = ""
    @State private var selectedMapClub: Club? = nil

    // MARK: - Computed Properties

    private var topLevelClubs: [Club] {
        allClubs.filter { $0.parentClubId == nil }
    }

    private var yourClubs: [Club] {
        topLevelClubs.filter { $0.memberIds.contains(profile.id) }
    }

    private var recommendedClubs: [Club] {
        topLevelClubs.filter { !$0.memberIds.contains(profile.id) }
    }

    private var activeCategories: [ClubCategory] {
        let cats = Set(topLevelClubs.map { $0.resolvedCategory })
        return ClubCategory.allCases.filter { cats.contains($0) }
    }

    private func matchesSearch(_ club: Club) -> Bool {
        guard !searchText.isEmpty else { return true }
        let q = searchText.lowercased()
        return club.name.lowercased().contains(q)
            || (club.location?.lowercased().contains(q) ?? false)
            || club.resolvedCategory.rawValue.lowercased().contains(q)
    }

    private var searchFilteredYourClubs: [Club] {
        let clubs = yourClubs.filter { matchesSearch($0) }
        if let cat = selectedCategory {
            return clubs.filter { $0.resolvedCategory == cat }
        }
        return clubs
    }

    private var searchFilteredRecommended: [Club] {
        let clubs = recommendedClubs.filter { matchesSearch($0) }
        let filtered = selectedCategory == nil ? clubs : clubs.filter { $0.resolvedCategory == selectedCategory }
        return filtered.sorted { ($0.location != nil ? 0 : 1) < ($1.location != nil ? 0 : 1) }
    }

    private var allVisibleClubs: [Club] {
        topLevelClubs.filter { matchesSearch($0) }
    }

    private var clubsWithCoordinates: [Club] {
        let filtered = selectedCategory == nil ? allVisibleClubs : allVisibleClubs.filter { $0.resolvedCategory == selectedCategory }
        return filtered.filter { $0.latitude != nil && $0.longitude != nil }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                searchBar

                categoryAndToggleRow

                if clubViewMode == .list {
                    listModeContent
                } else {
                    mapModeContent
                }

                Spacer(minLength: 100)
            }
            .padding(.top, 8)
        }
        .scrollContentBackground(.hidden)
        .background(GQColors.background.ignoresSafeArea())
        .refreshable {
            // Pull-to-refresh triggers SwiftData @Query re-evaluation
            try? await Task.sleep(for: .milliseconds(300))
        }
        .onAppear {
            ClubSeeder.seedIfNeeded(modelContext: modelContext, userId: profile.id)
        }
        .sheet(isPresented: $showingCreateClub) {
            CreateClubSheet(profile: profile)
        }
        .sheet(item: $selectedClub) { club in
            ClubDetailView(club: club, profile: profile)
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.textTertiary)
                TextField("Search clubs...", text: $searchText)
                    .font(.system(size: 15))
                    .foregroundColor(GQColors.textPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(GQColors.adaptiveOverlay(0.08))
            .cornerRadius(12)

            viewModeToggle
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Category Pills + Toggle Row

    private var categoryAndToggleRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryPill(label: "All", icon: nil, isSelected: selectedCategory == nil) {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedCategory = nil }
                }
                ForEach(activeCategories, id: \.self) { cat in
                    categoryPill(label: cat.rawValue, icon: cat.icon, isSelected: selectedCategory == cat) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = selectedCategory == cat ? nil : cat
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var viewModeToggle: some View {
        HStack(spacing: 0) {
            viewModeButton(icon: "list.bullet", mode: .list)
            viewModeButton(icon: "map", mode: .map)
        }
        .background(GQColors.adaptiveOverlay(0.06))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func viewModeButton(icon: String, mode: ClubViewMode) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { clubViewMode = mode }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(clubViewMode == mode ? GQColors.textPrimary : GQColors.textTertiary)
                .frame(width: 32, height: 30)
                .background(clubViewMode == mode ? GQColors.adaptiveOverlay(0.12) : Color.clear)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - List Mode

    @ViewBuilder
    private var listModeContent: some View {
        myClubsSection
        nearbySection
        createClubButton
    }

    // MARK: - My Clubs Section

    @ViewBuilder
    private var myClubsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "person.3.fill")
                    .foregroundStyle(GQGradients.primary)
                    .font(.system(size: 12))
                Text("MY CLUBS")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .tracking(1)

                Text("\(yourClubs.count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(GQColors.adaptiveOverlay(0.15))
                    .cornerRadius(10)

                Spacer()
            }
            .padding(.horizontal, 16)

            if searchFilteredYourClubs.isEmpty && !yourClubs.isEmpty {
                Text("No matching clubs")
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else if yourClubs.isEmpty {
                emptyClubsState
            } else {
                ForEach(searchFilteredYourClubs) { club in
                    clubCard(club)
                        .onTapGesture { selectedClub = club }
                }
            }
        }
    }

    @ViewBuilder
    private var emptyClubsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 30))
                .foregroundStyle(GQGradients.primary)
            Text("No Clubs Yet")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(GQColors.textPrimary)
            Text("Join a club to connect with your gym community")
                .font(.system(size: 13))
                .foregroundColor(GQColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .homeSocialCard(cornerRadius: 14, subtle: true)
        .padding(.horizontal, 16)
    }

    // MARK: - Nearby / Discover Section

    @ViewBuilder
    private var nearbySection: some View {
        let hasNearby = searchFilteredRecommended.contains { $0.location != nil }
        let header = hasNearby ? "NEARBY" : "DISCOVER"

        if !searchFilteredRecommended.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: hasNearby ? "mappin.and.ellipse" : "sparkles")
                        .foregroundColor(GQColors.cyanSpark)
                        .font(.system(size: 12))
                    Text(header)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(GQColors.textTertiary)
                        .tracking(1)
                    Spacer()
                }
                .padding(.horizontal, 16)

                ForEach(searchFilteredRecommended) { club in
                    recommendedClubCard(club)
                }
            }
        }
    }

    // MARK: - Map Mode

    @ViewBuilder
    private var mapModeContent: some View {
        ZStack(alignment: .bottom) {
            Map(initialPosition: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 44.225, longitude: -76.490),
                span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
            ))) {
                ForEach(clubsWithCoordinates) { club in
                    if let lat = club.latitude, let lng = club.longitude {
                        Annotation(club.name, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng)) {
                            mapPin(for: club)
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .preferredColorScheme(.dark)
            .frame(height: 420)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) { selectedMapClub = nil }
            }

            if let club = selectedMapClub {
                mapClubOverlay(club)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
        }
        .padding(.horizontal, 16)
        .animation(.easeInOut(duration: 0.25), value: selectedMapClub?.id)

        if clubsWithCoordinates.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "map")
                    .font(.system(size: 24))
                    .foregroundColor(GQColors.textTertiary)
                Text("No clubs with locations")
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }

    @ViewBuilder
    private func mapPin(for club: Club) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedMapClub = club }
        } label: {
            Circle()
                .fill(club.resolvedCategory.color)
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: club.resolvedCategory.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                )
                .shadow(color: club.resolvedCategory.color.opacity(0.4), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func mapClubOverlay(_ club: Club) -> some View {
        let isMember = club.memberIds.contains(profile.id)
        HStack(spacing: 12) {
            categoryIcon(for: club, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(club.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                        .lineLimit(1)
                    if club.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                            .foregroundColor(GQColors.cyanSpark)
                    }
                }
                HStack(spacing: 6) {
                    Text(club.resolvedCategory.rawValue)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(club.resolvedCategory.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(club.resolvedCategory.color.opacity(0.15))
                        .cornerRadius(4)
                    if let loc = club.location {
                        Text(loc)
                            .font(.system(size: 11))
                            .foregroundColor(GQColors.textTertiary)
                    }
                    Text("•")
                        .font(.system(size: 10))
                        .foregroundColor(GQColors.textTertiary)
                    Text("\(club.memberCount)")
                        .font(.system(size: 11))
                        .foregroundColor(GQColors.textTertiary)
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 9))
                        .foregroundColor(GQColors.textTertiary)
                }
            }

            Spacer(minLength: 0)

            if isMember {
                Button { selectedClub = club } label: {
                    Text("View")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(GQColors.cyanSpark)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(GQColors.cyanSpark.opacity(0.12))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    withAnimation {
                        club.memberIds.append(profile.id)
                        try? modelContext.save()
                    }
                } label: {
                    Text("Join")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(GQColors.cyanSpark)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(GQColors.cyanSpark.opacity(0.12))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(14)
    }

    // MARK: - Shared Card Components

    private func accentedCard<Content: View>(
        accent: Color, @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accent)
                .frame(width: 3)
                .padding(.vertical, 8)
            content()
        }
        .homeSocialCard(cornerRadius: 14, subtle: true)
    }

    @ViewBuilder
    private func clubCard(_ club: Club) -> some View {
        accentedCard(accent: club.resolvedCategory.color) {
            HStack(spacing: 12) {
                #if canImport(UIKit)
                if let imageData = club.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                } else {
                    categoryIcon(for: club, size: 48)
                }
                #else
                categoryIcon(for: club, size: 48)
                #endif

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Text(club.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(GQColors.textPrimary)
                            .lineLimit(1)
                        if club.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                                .foregroundColor(GQColors.cyanSpark)
                        }
                    }
                    HStack(spacing: 6) {
                        if let location = club.location {
                            Label(location, systemImage: "mappin")
                        } else {
                            Label("Online", systemImage: "globe")
                        }
                        Text("•")
                        Text("\(club.memberCount) members")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textTertiary)
            }
            .padding(14)
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func recommendedClubCard(_ club: Club) -> some View {
        HStack(spacing: 12) {
            categoryIcon(for: club, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(club.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                        .lineLimit(1)
                    if club.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11))
                            .foregroundColor(GQColors.cyanSpark)
                    }
                }
                HStack(spacing: 6) {
                    if let location = club.location {
                        Label(location, systemImage: "mappin")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(GQColors.cyanSpark)
                    } else {
                        Label("Online", systemImage: "globe")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(GQColors.textTertiary)
                    }
                    Text("•")
                        .font(.system(size: 10))
                        .foregroundColor(GQColors.textTertiary)
                    Text("\(club.memberCount) members")
                        .font(.system(size: 11))
                        .foregroundColor(GQColors.textTertiary)
                }
            }

            Spacer()

            Button(action: {
                withAnimation {
                    club.memberIds.append(profile.id)
                    try? modelContext.save()
                }
            }) {
                Text("Join")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(GQColors.cyanSpark)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(GQColors.cyanSpark.opacity(0.12))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .homeSocialCard(cornerRadius: 12, subtle: true)
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func categoryPill(label: String, icon: String?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                }
                Text(label)
            }
            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            .foregroundColor(isSelected ? GQColors.textPrimary : GQColors.textTertiary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(GQColors.adaptiveOverlay(isSelected ? 0.12 : 0.06))
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }

    private func categoryIcon(for club: Club, size: CGFloat) -> some View {
        let cat = club.resolvedCategory
        return Circle()
            .fill(GQColors.adaptiveOverlay(0.08))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: cat.icon)
                    .font(.system(size: size * 0.4))
                    .foregroundColor(GQColors.cyanSpark.opacity(0.8))
            )
    }

    @ViewBuilder
    private var createClubButton: some View {
        Button(action: { showingCreateClub = true }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Create a Club")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(GQColors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(GQColors.adaptiveOverlay(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(GQColors.adaptiveOverlay(0.15), lineWidth: 1)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }
}

// MARK: - Club Preview Card (for empty state)

struct ClubPreviewCard: View {
    let name: String
    let members: Int
    let location: String
    let isVerified: Bool
    var category: ClubCategory = .generalFitness
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Circle()
                    .fill(category.color.opacity(0.15))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: category.icon)
                            .font(.system(size: 20))
                            .foregroundColor(category.color)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(GQColors.textPrimary)
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
            .homeSocialCard(cornerRadius: 12, subtle: true)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }
}

// MARK: - Club Card (for joined clubs)

struct ClubCard: View {
    let club: Club
    let profile: UserProfile

    var body: some View {
        let cat = club.resolvedCategory
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                if let imageData = club.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(cat.color.opacity(0.15))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: cat.icon)
                                .font(.system(size: 20))
                                .foregroundColor(cat.color)
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(club.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(GQColors.textPrimary)
                            .lineLimit(1)

                        if club.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                                .foregroundColor(GQColors.cyanSpark)
                        }
                    }

                    HStack(spacing: 8) {
                        Label("\(club.memberCount)", systemImage: "person.2.fill")
                        if let location = club.location {
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
        .homeSocialCard(cornerRadius: 12, subtle: true)
        .padding(.horizontal, 16)
    }
}

// MARK: - Create Club Sheet

struct CreateClubSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let profile: UserProfile

    @State private var name = ""
    @State private var description = ""
    @State private var location = ""
    @State private var joinType: ClubJoinType = .open
    @State private var category: ClubCategory = .generalFitness
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var clubImageData: Data?

    var body: some View {
        NavigationStack {
            Form {
                Section("Club Image") {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Group {
                                #if canImport(UIKit)
                                if let clubImageData, let uiImage = UIImage(data: clubImageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(GQColors.adaptiveOverlay(0.08))
                                        .frame(width: 80, height: 80)
                                        .overlay(
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(GQColors.textTertiary)
                                        )
                                }
                                #else
                                Circle()
                                    .fill(GQColors.adaptiveOverlay(0.08))
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(GQColors.textTertiary)
                                    )
                                #endif
                            }
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                .onChange(of: selectedPhotoItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            clubImageData = data
                        }
                    }
                }

                Section("Club Info") {
                    TextField("Name (e.g., Queen's Run Club)", text: $name)
                    TextField("Location (optional)", text: $location)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Category") {
                    Picker("Activity Type", selection: $category) {
                        ForEach(ClubCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                        }
                    }
                }

                Section("Privacy") {
                    Picker("Who can join?", selection: $joinType) {
                        Text("Anyone (Open)").tag(ClubJoinType.open)
                        Text("Request to Join").tag(ClubJoinType.request)
                    }
                }

                Section {
                    Text("Clubs are great for running groups, pickup sports, lifting crews, and more. Members can share activity, find partners, and join meetups.")
                        .font(.footnote)
                        .foregroundColor(GQColors.textTertiary)
                }
            }
            .navigationTitle("Create Club")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createClub()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func createClub() {
        let club = Club(
            name: name,
            clubDescription: description,
            location: location.isEmpty ? nil : location,
            imageData: clubImageData,
            creatorId: profile.id,
            joinType: joinType,
            category: category
        )
        modelContext.insert(club)

        let membership = ClubMembership(
            userId: profile.id,
            clubId: club.id,
            role: .owner
        )
        modelContext.insert(membership)

        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Search Clubs Sheet

struct SearchClubsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allClubs: [Club]

    let profile: UserProfile

    @State private var searchText = ""
    @State private var filterCategory: ClubCategory? = nil

    var filteredClubs: [Club] {
        var clubs = allClubs.filter { $0.parentClubId == nil }
        if let cat = filterCategory {
            clubs = clubs.filter { $0.resolvedCategory == cat }
        }
        if !searchText.isEmpty {
            clubs = clubs.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.location?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                $0.resolvedCategory.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }
        return clubs
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button {
                            filterCategory = nil
                        } label: {
                            Text("All")
                                .font(.system(size: 12, weight: filterCategory == nil ? .bold : .medium))
                                .foregroundColor(filterCategory == nil ? .white : GQColors.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(filterCategory == nil ? GQColors.vividPurple.opacity(0.4) : GQColors.adaptiveOverlay(0.08))
                                .cornerRadius(16)
                        }
                        .buttonStyle(.plain)

                        ForEach(ClubCategory.allCases, id: \.self) { cat in
                            Button {
                                filterCategory = filterCategory == cat ? nil : cat
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: cat.icon)
                                        .font(.system(size: 10))
                                    Text(cat.rawValue)
                                }
                                .font(.system(size: 12, weight: filterCategory == cat ? .bold : .medium))
                                .foregroundColor(filterCategory == cat ? .white : GQColors.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(filterCategory == cat ? cat.color.opacity(0.35) : GQColors.adaptiveOverlay(0.08))
                                .cornerRadius(16)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }

                List {
                    if filteredClubs.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(GQColors.textTertiary)
                            Text("No clubs found")
                                .font(.headline)
                                .foregroundColor(GQColors.textPrimary)
                            Text("Try a different search or create your own")
                                .font(.subheadline)
                                .foregroundColor(GQColors.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(filteredClubs) { club in
                            ClubSearchRow(
                                club: club,
                                isMember: club.memberIds.contains(profile.id),
                                onJoin: { joinClub(club) }
                            )
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search by name, location, or category")
            .navigationTitle("Find Clubs")
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

    private func joinClub(_ club: Club) {
        if club.joinType == .open {
            club.memberIds.append(profile.id)
            club.memberCount += 1

            let membership = ClubMembership(
                userId: profile.id,
                clubId: club.id,
                role: .member
            )
            modelContext.insert(membership)
        } else {
            club.pendingRequestIds.append(profile.id)
        }
        try? modelContext.save()
    }
}

struct ClubSearchRow: View {
    let club: Club
    let isMember: Bool
    let onJoin: () -> Void

    var body: some View {
        let cat = club.resolvedCategory
        HStack(spacing: 12) {
            Circle()
                .fill(cat.color.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: cat.icon)
                        .font(.system(size: 18))
                        .foregroundColor(cat.color)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(club.name)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)

                    if club.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11))
                            .foregroundColor(GQColors.cyanSpark)
                    }
                }

                HStack(spacing: 6) {
                    Text("\(club.memberCount) members")
                    if let location = club.location {
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
                    Text(club.joinType == .open ? "Join" : "Request")
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

// MARK: - Club Detail View

enum ClubSection: String, CaseIterable {
    case feed = "Feed"
    case challenges = "Challenges"
    case events = "Events"
    case leaderboard = "Leaderboard"
    case members = "Members"
}

struct ClubDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var clubPosts: [ClubPost]
    @Query private var allClubs: [Club]
    @Query private var allChallenges: [ClubChallenge]
    @Query private var allMemberships: [ClubMembership]
    @Query private var allEvents: [ClubEvent]

    let club: Club
    let profile: UserProfile

    @State private var showingNewPost = false
    @State private var showingCreateEvent = false
    @State private var showingLeaveAlert = false
    @State private var selectedSection: ClubSection = .feed
    @State private var showPartnerOnly = false
    @State private var selectedChannelId: UUID? = nil

    private var isMember: Bool {
        club.memberIds.contains(profile.id)
    }

    private var posts: [ClubPost] {
        clubPosts
            .filter { post in
                post.clubId == club.id &&
                (selectedChannelId == nil || post.channelId == selectedChannelId)
            }
            .sorted { $0.timestamp > $1.timestamp }
    }

    private var channels: [Club] {
        allClubs.filter { $0.parentClubId == club.id }
    }

    private var activeChallenges: [ClubChallenge] {
        allChallenges.filter { $0.clubId == club.id && $0.isActive }
    }

    private var memberships: [ClubMembership] {
        allMemberships.filter { $0.clubId == club.id }
    }

    private var clubEvents: [ClubEvent] {
        allEvents.filter { $0.clubId == club.id }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    detailHeader
                    joinButton
                    clubSectionPicker
                    sectionContent
                    Spacer(minLength: 40)
                }
            }
            .gqPageBackground()
            .preferredColorScheme(.dark)
            .navigationTitle("Club")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingNewPost) {
                NewClubPostSheet(club: club, profile: profile)
            }
            .alert("Leave Club", isPresented: $showingLeaveAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Leave", role: .destructive) {
                    leaveClub()
                }
            } message: {
                Text("Are you sure you want to leave \(club.name)?")
            }
            .sheet(isPresented: $showingCreateEvent) {
                CreateEventSheet(club: club, profile: profile)
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var detailHeader: some View {
        let cat = club.resolvedCategory
        VStack(spacing: 12) {
            #if canImport(UIKit)
            if let imageData = club.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 88, height: 88)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(cat.color, lineWidth: 3)
                    )
            } else {
                Circle()
                    .fill(cat.color.opacity(0.15))
                    .frame(width: 88, height: 88)
                    .overlay(
                        Image(systemName: cat.icon)
                            .font(.system(size: 36))
                            .foregroundColor(cat.color)
                    )
                    .overlay(
                        Circle()
                            .stroke(cat.color.opacity(0.3), lineWidth: 2)
                    )
            }
            #else
            Circle()
                .fill(cat.color.opacity(0.15))
                .frame(width: 88, height: 88)
                .overlay(
                    Image(systemName: cat.icon)
                        .font(.system(size: 36))
                        .foregroundColor(cat.color)
                )
                .overlay(
                    Circle()
                        .stroke(cat.color.opacity(0.3), lineWidth: 2)
                )
            #endif

            HStack(spacing: 4) {
                Text(club.name)
                    .font(.title2)
                    .fontWeight(.bold)

                if club.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(GQColors.cyanSpark)
                }
            }

            if !club.clubDescription.isEmpty {
                Text(club.clubDescription)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            HStack(spacing: 20) {
                VStack {
                    Text("\(club.memberCount)")
                        .font(.headline)
                    Text("Members")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                if let location = club.location {
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

    // MARK: - Join Button

    @ViewBuilder
    private var joinButton: some View {
        if !isMember {
            Button {
                if club.isOpen {
                    club.memberIds.append(profile.id)
                    club.memberCount += 1
                    let m = ClubMembership(userId: profile.id, clubId: club.id, role: .member)
                    modelContext.insert(m)
                } else {
                    club.pendingRequestIds.append(profile.id)
                }
                try? modelContext.save()
            } label: {
                Text(club.isOpen ? "Join Club" : "Request to Join")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [GQColors.vividPurple.opacity(0.6), GQColors.cyanSpark.opacity(0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
        } else if club.pendingRequestIds.contains(profile.id) {
            Text("Request Pending")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
                .padding(.horizontal, 16)
        } else if isMember && club.creatorId != profile.id {
            Button {
                showingLeaveAlert = true
            } label: {
                Text("Leave Club")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(GQColors.coralRed)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(GQColors.coralRed.opacity(0.1))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(GQColors.coralRed.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Who's Working Out

    @ViewBuilder
    private var workingOutNowRow: some View {
        let users = SocialSeeder.fakeUsers
        let activeNames: [String] = club.memberIds.compactMap { memberId in
            guard let user = users.first(where: { $0.id == memberId }) else { return nil }
            let hash = abs(memberId.hashValue)
            guard hash % 3 == 0 else { return nil }
            return user.name
        }.prefix(4).map { $0 }
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
                                .fill(Color.white.opacity(0.1))
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
                        // "All" pill to clear channel filter
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                selectedChannelId = nil
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "rectangle.grid.2x2")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(selectedChannelId == nil ? .white : GQColors.cyanSpark)
                                Text("All")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(selectedChannelId == nil ? .white : .white.opacity(0.7))
                                    .lineLimit(1)
                                Text("\(posts.count) posts")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 110, height: 80)
                            .background(selectedChannelId == nil ? GQColors.vividPurple.opacity(0.3) : Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedChannelId == nil ? GQColors.vividPurple.opacity(0.5) : GQColors.cyanSpark.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)

                        ForEach(channels) { channel in
                            let isSelected = selectedChannelId == channel.id
                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    selectedChannelId = isSelected ? nil : channel.id
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: "number")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(isSelected ? .white : GQColors.cyanSpark)
                                    Text(channel.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                                        .lineLimit(1)
                                    Text("\(channel.memberCount) members")
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray)
                                }
                                .frame(width: 110, height: 80)
                                .background(isSelected ? GQColors.vividPurple.opacity(0.3) : Color.white.opacity(0.06))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isSelected ? GQColors.vividPurple.opacity(0.5) : GQColors.cyanSpark.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
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
            challengeCardView(challenge: challenge)
        }
    }

    @ViewBuilder
    private func challengeCardView(challenge: ClubChallenge) -> some View {
        let isJoined = challenge.participantIds.contains(profile.id)

        VStack(alignment: .leading, spacing: 12) {
            challengeCardHeader(challenge: challenge)
            challengeCardProgress(challenge: challenge)
            challengeJoinButton(challenge: challenge, isJoined: isJoined)
        }
        .padding(14)
        .homeSocialCard(cornerRadius: 14, subtle: true)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func challengeCardHeader(challenge: ClubChallenge) -> some View {
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
    }

    @ViewBuilder
    private func challengeCardProgress(challenge: ClubChallenge) -> some View {
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

    @ViewBuilder
    private func challengeJoinButton(challenge: ClubChallenge, isJoined: Bool) -> some View {
        if isMember {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    if isJoined {
                        challenge.participantIds.removeAll { $0 == profile.id }
                    } else {
                        challenge.participantIds.append(profile.id)
                    }
                    try? modelContext.save()
                }
                #if canImport(UIKit)
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                #endif
            } label: {
                challengeJoinButtonLabel(isJoined: isJoined)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func challengeJoinButtonLabel(isJoined: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: isJoined ? "checkmark.circle.fill" : "flame.fill")
                .font(.system(size: 13))
            Text(isJoined ? "Joined" : "Join Challenge")
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            isJoined
                ? AnyShapeStyle(GQColors.elevatedSurface)
                : AnyShapeStyle(LinearGradient(colors: [GQColors.vividPurple, GQColors.cyanSpark], startPoint: .leading, endPoint: .trailing))
        )
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isJoined ? GQColors.borderDefault : Color.clear, lineWidth: 1)
        )
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
    private var clubSectionPicker: some View {
        HStack(spacing: 0) {
            ForEach(ClubSection.allCases, id: \.self) { section in
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
            VStack(spacing: 16) {
                workingOutNowRow
                channelCards
                actionButtons
                clubFeedSection
            }
        case .challenges:
            clubChallengesSection
        case .events:
            clubEventsSection
        case .leaderboard:
            clubLeaderboardSection
        case .members:
            clubMembersSection
        }
    }

    // MARK: - Challenges Tab Section

    @ViewBuilder
    private var clubChallengesSection: some View {
        if activeChallenges.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "trophy")
                    .font(.system(size: 30))
                    .foregroundColor(GQColors.textTertiary)
                Text("No active challenges")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)
                Text("Check back soon for new challenges")
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
        } else {
            challengeCards
        }
    }

    // MARK: - Events Section

    @ViewBuilder
    private var clubEventsSection: some View {
        VStack(spacing: 12) {
            if isMember {
                Button {
                    showingCreateEvent = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Create Event")
                    }
                    .font(.system(size: 14, weight: .semibold))
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
            }

            let upcoming = clubEvents.filter { $0.date > Date() }
            if upcoming.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 30))
                        .foregroundColor(GQColors.textTertiary)
                    Text("No upcoming events")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(GQColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                ForEach(upcoming) { event in
                    ClubEventCard(event: event, userId: profile.id, modelContext: modelContext)
                }
                .padding(.horizontal, 16)
            }

            let past = clubEvents.filter { $0.date <= Date() }
            if !past.isEmpty {
                Text("PAST EVENTS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(0.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                ForEach(past.reversed().prefix(5)) { event in
                    ClubEventCard(event: event, userId: profile.id, modelContext: modelContext)
                        .opacity(0.6)
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Feed Section

    @ViewBuilder
    private var clubFeedSection: some View {
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
                    ClubPostCard(post: post)
                }
            }
        }
    }

    // MARK: - Leaderboard Section

    @ViewBuilder
    private var clubLeaderboardSection: some View {
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

            // Exercise Leaderboard link
            NavigationLink {
                LeaderboardView(clubId: club.id)
            } label: {
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(GQColors.electricGold)
                    Text("Exercise Leaderboard")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.06))
                .cornerRadius(12)
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Members Section

    @ViewBuilder
    private var clubMembersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(club.memberCount) MEMBERS")
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
        let users = SocialSeeder.fakeUsers
        return club.memberIds.compactMap { memberId in
            guard let user = users.first(where: { $0.id == memberId }) else { return nil }
            // Deterministic stats from UUID hash
            let hash = abs(memberId.hashValue)
            let sets = 20 + (hash % 30)
            let workouts = 2 + (hash % 5)
            let points = sets * 5
            return (name: user.name, sets: sets, workouts: workouts, points: points)
        }
        .sorted { $0.points > $1.points }
    }

    private var memberData: [(name: String, role: String, isOnline: Bool, lookingForPartner: Bool)] {
        let users = SocialSeeder.fakeUsers
        return club.memberIds.compactMap { memberId in
            guard let user = users.first(where: { $0.id == memberId }) else { return nil }
            let membership = memberships.first(where: { $0.userId == memberId })
            let role = membership?.role ?? .member
            let hash = abs(memberId.hashValue)
            let isOnline = hash % 3 != 0
            let lookingForPartner = membership?.workoutPartnerStatus == .available
            return (name: user.name, role: role.rawValue.capitalized, isOnline: isOnline, lookingForPartner: lookingForPartner)
        }
    }

    private func medalColor(for index: Int) -> Color {
        switch index {
        case 0: return .yellow
        case 1: return Color(white: 0.75)
        case 2: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return .gray
        }
    }

    private func leaveClub() {
        club.memberIds.removeAll { $0 == profile.id }
        club.memberCount = max(0, club.memberCount - 1)

        // Delete membership
        if let membership = memberships.first(where: { $0.userId == profile.id }) {
            modelContext.delete(membership)
        }

        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Club Post Card

struct ClubPostCard: View {
    let post: ClubPost
    @State private var liked: Bool = false

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
                    liked.toggle()
                    post.likeCount += liked ? 1 : -1
                    #if canImport(UIKit)
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    #endif
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: liked ? "heart.fill" : "heart")
                        if post.likeCount > 0 {
                            Text("\(post.likeCount)")
                        }
                    }
                    .font(.system(size: 13))
                    .foregroundColor(liked ? .red : GQColors.textTertiary)
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

// MARK: - New Club Post Sheet

struct NewClubPostSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let club: Club
    let profile: UserProfile

    @State private var content = ""
    @State private var postType: ClubPostType = .general

    var body: some View {
        NavigationStack {
            Form {
                Section("Post Type") {
                    Picker("Type", selection: $postType) {
                        ForEach(ClubPostType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                }

                Section("What's on your mind?") {
                    TextField("Share with the club...", text: $content, axis: .vertical)
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
        let post = ClubPost(
            clubId: club.id,
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
                                    .clipShape(Rectangle())
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
                .aspectRatio(4.0/4.5, contentMode: .fit)

            }
        }
    }
}

// MARK: - Club Event Card

struct ClubEventCard: View {
    let event: ClubEvent
    let userId: UUID
    let modelContext: ModelContext

    private var isAttending: Bool {
        event.attendeeIds.contains(userId)
    }

    private var isFull: Bool {
        if let max = event.maxAttendees {
            return event.attendeeIds.count >= max
        }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: event.eventType.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(event.eventType.color)
                    .frame(width: 32, height: 32)
                    .background(event.eventType.color.opacity(0.15))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text(event.eventType.rawValue)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(event.eventType.color)
                }

                Spacer()

                Button {
                    toggleRSVP()
                } label: {
                    Text(isAttending ? "Going" : (isFull ? "Full" : "RSVP"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(isAttending ? .white : GQColors.cyanSpark)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(isAttending ? GQColors.cyanSpark : GQColors.cyanSpark.opacity(0.15))
                        .cornerRadius(16)
                }
                .buttonStyle(.plain)
                .disabled(isFull && !isAttending)
            }

            if !event.eventDescription.isEmpty {
                Text(event.eventDescription)
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textSecondary)
                    .lineLimit(2)
            }

            // Recurring indicator
            if event.isRecurring, let rule = event.recurrenceRule {
                HStack(spacing: 4) {
                    Image(systemName: "repeat")
                        .font(.system(size: 10))
                    Text("Repeats \(rule)")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(GQColors.mint)
            }

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                    Text(event.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(GQColors.textTertiary)

                if let location = event.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.system(size: 11))
                        Text(location)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(GQColors.textTertiary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 11))
                    if let max = event.maxAttendees {
                        Text("\(event.attendeeIds.count)/\(max)")
                    } else {
                        Text("\(event.attendeeIds.count)")
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func toggleRSVP() {
        if isAttending {
            event.attendeeIds.removeAll { $0 == userId }
        } else {
            event.attendeeIds.append(userId)
        }
        try? modelContext.save()
    }
}

// MARK: - Create Event Sheet

struct CreateEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let club: Club
    let profile: UserProfile

    @State private var title = ""
    @State private var eventDescription = ""
    @State private var location = ""
    @State private var eventDate = Date().addingTimeInterval(86400)
    @State private var eventType: ClubEventType = .workout
    @State private var maxAttendeesText = ""
    @State private var isRecurring = false
    @State private var recurrenceRule = "weekly"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("EVENT TYPE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                            .tracking(0.5)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(ClubEventType.allCases, id: \.self) { type in
                                    Button {
                                        eventType = type
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: type.icon)
                                            Text(type.rawValue)
                                        }
                                        .font(.system(size: 13, weight: eventType == type ? .bold : .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(eventType == type ? type.color.opacity(0.3) : Color.white.opacity(0.08))
                                        .cornerRadius(20)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(eventType == type ? type.color.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("TITLE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                            .tracking(0.5)
                        TextField("Event name", text: $title)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("DESCRIPTION")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                            .tracking(0.5)
                        TextField("What's the event about?", text: $eventDescription, axis: .vertical)
                            .lineLimit(3...5)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("LOCATION")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                            .tracking(0.5)
                        TextField("Where? (optional)", text: $location)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("DATE & TIME")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                            .tracking(0.5)
                        DatePicker("", selection: $eventDate, in: Date()...)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(GQColors.cyanSpark)
                    }

                    // Recurring toggle
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(isOn: $isRecurring) {
                            HStack(spacing: 6) {
                                Image(systemName: "repeat")
                                    .font(.system(size: 13))
                                    .foregroundColor(GQColors.mint)
                                Text("Recurring Event")
                                    .font(.system(size: 14, weight: .medium))
                            }
                        }
                        .tint(GQColors.mint)

                        if isRecurring {
                            Picker("Frequency", selection: $recurrenceRule) {
                                Text("Weekly").tag("weekly")
                                Text("Biweekly").tag("biweekly")
                                Text("Monthly").tag("monthly")
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("MAX ATTENDEES")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                            .tracking(0.5)
                        TextField("Leave empty for unlimited", text: $maxAttendeesText)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                    }

                    Button {
                        createEvent()
                    } label: {
                        HStack {
                            Image(systemName: "calendar.badge.plus")
                            Text("Create Event")
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
                    .buttonStyle(.plain)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("New Event")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func createEvent() {
        let event = ClubEvent(
            clubId: club.id,
            creatorId: profile.id,
            creatorName: profile.name,
            title: title.trimmingCharacters(in: .whitespaces),
            eventDescription: eventDescription.trimmingCharacters(in: .whitespaces),
            location: location.isEmpty ? nil : location.trimmingCharacters(in: .whitespaces),
            date: eventDate,
            maxAttendees: Int(maxAttendeesText),
            attendeeIds: [profile.id],
            eventType: eventType,
            isRecurring: isRecurring,
            recurrenceRule: isRecurring ? recurrenceRule : nil
        )

        modelContext.insert(event)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Emoji Burst Overlay

struct SentReactionOverlay: View {
    let emoji: String

    @State private var animate = false

    var body: some View {
        ZStack {
            Text(emoji)
                .font(.system(size: 26))
                .scaleEffect(animate ? 0.75 : 1.1)
                .opacity(animate ? 0 : 1)
                .offset(y: animate ? -50 : 0)

            Text(emoji)
                .font(.system(size: 18))
                .scaleEffect(animate ? 0.6 : 0.8)
                .opacity(animate ? 0 : 0.6)
                .offset(x: 14, y: animate ? -40 : 5)
                .animation(.easeOut(duration: 2.0).delay(0.5), value: animate)
        }
        .animation(.easeOut(duration: 2.0), value: animate)
        .allowsHitTesting(false)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                animate = true
            }
        }
    }
}

struct EmojiBurstOverlay: View {
    let emoji: String
    let isActive: Bool

    private struct FloatingEmoji: Identifiable {
        let id = UUID()
        let xPosition: CGFloat
        let startY: CGFloat
        let size: CGFloat
        let delay: Double
        let driftX: CGFloat
    }

    @State private var emojis: [FloatingEmoji] = []
    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(emojis) { e in
                    Text(emoji)
                        .font(.system(size: e.size))
                        .opacity(appeared ? 0.35 : 0)
                        .offset(
                            x: e.xPosition * geo.size.width - geo.size.width / 2 + (appeared ? e.driftX : 0),
                            y: e.startY * geo.size.height - geo.size.height / 2 + (appeared ? -20 : 0)
                        )
                        .animation(
                            .easeOut(duration: 2.5).delay(e.delay),
                            value: appeared
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            guard isActive else { return }
            emojis = (0..<3).map { _ in
                FloatingEmoji(
                    xPosition: CGFloat.random(in: 0.15...0.85),
                    startY: CGFloat.random(in: 0.3...0.7),
                    size: CGFloat.random(in: 18...24),
                    delay: Double.random(in: 0...0.6),
                    driftX: CGFloat.random(in: -8...8)
                )
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                appeared = true
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    FeedView(profile: UserProfile())
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
