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

enum FeedFilter: String, CaseIterable {
    case discover = "Discover"
    case friends = "Friends"
    case clubs = "Clubs"
}

typealias FeedTab = FeedFilter

// MARK: - Feed Item Types

enum FeedItem: Identifiable {
    case post(Post)
    case workoutSuggestion(SharedWorkoutData, suggestedBy: String)
    case communityPulse(activeCount: Int, recentPRs: Int, topExercise: String)
    case motivationPrompt(message: String, type: MotivationType)
    case inspirationChain(original: Post, followers: [String])
    case streakMilestone(userName: String, days: Int, workouts: Int)

    var id: String {
        switch self {
        case .post(let p): return "post-\(p.id)"
        case .workoutSuggestion(let w, _): return "suggest-\(w.id)"
        case .communityPulse(let c, let p, let e): return "pulse-\(c)-\(p)-\(e)"
        case .motivationPrompt(let m, let t): return "motive-\(t.rawValue)-\(m.prefix(10))"
        case .inspirationChain(let p, _): return "chain-\(p.id)"
        case .streakMilestone(let n, let d, _): return "streak-\(n)-\(d)"
        }
    }
}

// MARK: - Feed Curator

struct FeedCurator {
    static func curate(posts: [Post], currentUserId: UUID) -> [FeedItem] {
        guard !posts.isEmpty else { return [] }

        var items: [FeedItem] = []
        var prPosts: [FeedItem] = []
        var workoutPosts: [FeedItem] = []
        var generalPosts: [FeedItem] = []
        var seenWorkoutTypes: Set<String> = []
        var inspirationChains: [FeedItem] = []

        // Categorize posts
        for post in posts {
            // Inspiration chain detection
            if post.inspiredByUsername != nil {
                let followers = posts
                    .filter { $0.inspiredByUsername == post.authorUsername }
                    .map(\.authorName)
                if !followers.isEmpty {
                    inspirationChains.append(.inspirationChain(original: post, followers: followers))
                    continue
                }
            }

            // Posts with PRs get priority but stay as normal posts (PR shown inline)
            let hasPR = !post.getFeedPRs().isEmpty

            // Posts with workout data
            if post.workoutType != nil || post.getSharedWorkout() != nil {
                if hasPR {
                    prPosts.append(.post(post))
                } else {
                    workoutPosts.append(.post(post))
                }
                if let wt = post.workoutType {
                    seenWorkoutTypes.insert(wt)
                }
            } else {
                generalPosts.append(.post(post))
            }
        }

        // Build curated feed: PR posts first, then workout posts, then general
        items.append(contentsOf: prPosts)
        items.append(contentsOf: inspirationChains)
        items.append(contentsOf: workoutPosts)

        items.append(contentsOf: generalPosts)

        return items
    }

    private static func generateWorkoutSuggestions(from posts: [Post], seenTypes: Set<String>) -> [FeedItem] {
        var suggestions: [FeedItem] = []
        for post in posts {
            guard let workout = post.getSharedWorkout(),
                  !workout.exercises.isEmpty else { continue }
            suggestions.append(.workoutSuggestion(workout, suggestedBy: post.authorName))
            if suggestions.count >= 2 { break }
        }
        return suggestions
    }

    private static func generateCommunityPulse(from posts: [Post]) -> FeedItem {
        let today = Date()
        let recentPosts = posts.filter { today.timeIntervalSince($0.timestamp) < 86400 }
        let activeCount = Set(recentPosts.map(\.authorId)).count
        let prCount = posts.filter { !($0.getFeedPRs().isEmpty) }.count

        // Find most popular exercise
        let exerciseCounts = posts.compactMap(\.exerciseHighlight)
            .reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        let topExercise = exerciseCounts.max(by: { $0.value < $1.value })?.key ?? "Bench Press"

        return .communityPulse(
            activeCount: max(activeCount, 8),
            recentPRs: max(prCount, 3),
            topExercise: topExercise
        )
    }

    private static func generateMotivationPrompt() -> FeedItem {
        let prompts: [(String, MotivationType)] = [
            ("Consistency beats intensity. Show up today.", .general),
            ("Your friends crushed 47 workouts this week. Join them.", .streak),
            ("The only bad workout is the one that didn't happen.", .general),
            ("You're closer to your next PR than you think.", .milestone),
            ("Rest day? Perfect. Recovery is part of the process.", .comeback),
        ]
        let selected = prompts[Int.random(in: 0..<prompts.count)]
        return .motivationPrompt(message: selected.0, type: selected.1)
    }

    private static func generateStreakMilestones(from posts: [Post]) -> [FeedItem] {
        // Group posts by author and detect consistent posting streaks
        let authorPosts = Dictionary(grouping: posts, by: \.authorId)
        var milestones: [FeedItem] = []

        // Streak thresholds: days -> label
        let thresholds: [(days: Int, workouts: Int)] = [
            (7, 4), (14, 8), (21, 12), (30, 16), (60, 30)
        ]

        for (_, userPosts) in authorPosts {
            guard let recent = userPosts.first else { continue }
            let sortedDates = userPosts.map(\.timestamp).sorted(by: >)
            guard sortedDates.count >= 3 else { continue }

            // Check how many days span the user's posts
            let daySpan = Calendar.current.dateComponents([.day], from: sortedDates.last!, to: sortedDates.first!).day ?? 0

            // Find the highest threshold they've hit
            if let best = thresholds.last(where: { daySpan >= $0.days && sortedDates.count >= $0.workouts }) {
                milestones.append(.streakMilestone(
                    userName: recent.authorName,
                    days: best.days,
                    workouts: sortedDates.count
                ))
            }
        }

        // Show max 2 streak cards
        return Array(milestones.prefix(2))
    }
}

struct FeedView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var featureFlags: FeatureFlags
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Post.timestamp, order: .reverse) private var posts: [Post]
    @Query private var allFriendRecords: [Friend]
    @Query private var allUserProfiles: [UserProfile]

    let profile: UserProfile

    @State private var selectedFeedTab: FeedFilter = .discover
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
            guard post.photoData != nil || post.videoData != nil else { return false }
            let authorId = post.authorId
            if cachedMutualIds.contains(authorId) { return true }
            if cachedFollowingIds.contains(authorId) && isUserPublic(authorId) { return true }
            return false
        }
    }

    /// All posts that have media (photo or video)
    private var postsWithMedia: [Post] {
        posts.filter { $0.photoData != nil || $0.videoData != nil }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab switcher pinned at top
                FeedTabsView(selectedTab: $selectedFeedTab)

                // Tab content
                switch selectedFeedTab {
                case .discover:
                    discoverFeedContent
                case .friends:
                    socialFeedContent
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
                if let tab = notification.object as? FeedFilter {
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

    // MARK: - Discover Feed Content (all posts, algorithmically ranked)

    @ViewBuilder
    private var discoverFeedContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                if !SocialActivityService.shared.activeFriends.isEmpty {
                    Rectangle()
                        .fill(GQColors.borderSubtle)
                        .frame(height: 1)
                        .padding(.horizontal, 4)

                    WorkingOutNowRow(recentFriendCount: cachedFriendsPosts.filter { $0.timestamp > Date().addingTimeInterval(-86400) }.count)
                }

                if featureFlags.squadsEnabled, let squad = activeSquad, let challenge = squadChallenge {
                    SquadChallengeCard(squad: squad, challenge: challenge)
                        .padding(.bottom, 4)
                }
            }
            .padding(.horizontal, 16)

            LazyVStack(spacing: 0) {
                if postsWithMedia.isEmpty {
                    socialEmptyState
                } else {
                    let curatedFeed = FeedCurator.curate(posts: postsWithMedia, currentUserId: profile.id)
                    ForEach(curatedFeed) { item in
                        switch item {
                        case .post(let post):
                            PostCardV2(
                                post: post,
                                currentUserId: profile.id,
                                currentUserName: profile.name,
                                profile: profile
                            )
                        case .workoutSuggestion, .communityPulse, .motivationPrompt, .inspirationChain, .streakMilestone:
                            EmptyView()
                        }

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

    // MARK: - Social Feed Content (friends only)

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

            LazyVStack(spacing: 0) {
                if cachedFriendsPosts.isEmpty {
                    socialEmptyState
                } else {
                    let curatedFeed = FeedCurator.curate(posts: cachedFriendsPosts, currentUserId: profile.id)
                    ForEach(curatedFeed) { item in
                        switch item {
                        case .post(let post):
                            PostCardV2(
                                post: post,
                                currentUserId: profile.id,
                                currentUserName: profile.name,
                                profile: profile
                            )
                        case .workoutSuggestion, .communityPulse, .motivationPrompt, .inspirationChain, .streakMilestone:
                            EmptyView()
                        }

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
    @Binding var selectedTab: FeedFilter

    private var tabIndex: Int {
        FeedFilter.allCases.firstIndex(of: selectedTab) ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(FeedFilter.allCases, id: \.self) { tab in
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
                let tabWidth = geometry.size.width / CGFloat(FeedFilter.allCases.count)
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
    @State private var visibilityDebounce: DispatchWorkItem?
    @State private var albumArtworkURL: URL?
    @State private var imageIsLight = false // true = light image, use dark text
    @State private var showWorkoutDetail = false
    @State private var showFullCaption = false
    @State private var showingCopySheet = false
    @State private var copySheetWorkout: SharedWorkoutData?
    @State private var cachedTopComment: Comment?
    // Emoji reactions handled via action bar reaction picker
    @State private var showFullRouteMap = false
    @State private var profileUserId: IdentifiableUUID?
    @State private var cachedWorkout: SharedWorkoutData?
    @State private var cachedPRs: [FeedPR] = []
    @State private var cachedChallenge: PostChallengeData?
    @State private var hasJoinedChallenge = false
    @State private var showDoubleTapHeart = false
    @State private var doubleTapLocation: CGPoint = .zero
    @State private var gradientPhase: CGFloat = 0

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
                workoutIdentityBadge
                heroSection
                inlineMusicRow
                captionSection
                challengeSection
                compactBottomBar
                inlineCommentPreview
            }
        }
        .background(GQColors.surfaceBase)
        .opacity(hasAppeared ? 1 : 0)
        .task {
            cachedWorkout = post.getSharedWorkout()
            cachedPRs = post.getFeedPRs()
            cachedChallenge = post.getPostChallenge()
            if let song = post.songTitle, let artist = post.artistName {
                albumArtworkURL = await AlbumArtService.shared.artworkURL(song: song, artist: artist)
            }
            #if canImport(UIKit)
            if let data = post.photoData, let img = UIImage(data: data) {
                imageIsLight = img.averageBrightness() > 0.55
            }
            #endif
        }
        .onAppear {
            hasAppeared = true
            fetchTopComment()
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: true)) {
                gradientPhase = .pi * 2
            }
            // Auto-play music preview after debounce
            if let song = post.songTitle, let artist = post.artistName {
                visibilityDebounce?.cancel()
                let work = DispatchWorkItem { [postId = post.id, fallback = post.songPreviewURL, snippetStart = post.musicSnippetStart] in
                    MusicPreviewService.shared.play(postId: postId, song: song, artist: artist, fallbackURL: fallback, snippetStart: snippetStart ?? 0)
                }
                visibilityDebounce = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
            }
        }
        .onDisappear {
            // Stop if this post is currently playing
            visibilityDebounce?.cancel()
            visibilityDebounce = nil
            let previewService = MusicPreviewService.shared
            if previewService.currentPostId == post.id {
                previewService.stop()
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

                if !post.caption.isEmpty {
                    Text(post.caption)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .lineSpacing(2)
                        .lineLimit(3)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            ChatBubbleShape(isFromCurrentUser: true)
                                .fill(GQGradients.primary)
                                .shadow(color: GQColors.deepBlue.opacity(0.4), radius: 8, x: 0, y: 4)
                        )
                }

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
                        .foregroundColor(isLiked ? GQColors.deepBlue : GQColors.textTertiary)
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
    private var workoutIdentityBadge: some View {
        EmptyView()
    }

    @ViewBuilder
    private var inlineMusicRow: some View {
        EmptyView()
    }

    @ViewBuilder
    private var heroSection: some View {
        if post.photoData != nil || post.videoData != nil {
            photoHero
        }
    }

    // Workout type accent color for tinting
    private var workoutAccent: Color {
        if let type = post.workoutType, let wt = WorkoutType(rawValue: type) {
            return GQGradients.workoutColor(for: wt)
        }
        return GQColors.deepBlue
    }

    @ViewBuilder
    private var photoHero: some View {
        ZStack(alignment: .bottom) {
            // The image/video — breathes when music is playing
            Group {
                if post.mediaItems.count > 1 {
                    ExerciseMediaCarousel(mediaItems: post.mediaItems)
                } else {
                    PostMediaView(post: post, showVideoPlayer: $showVideoPlayer)
                }
            }

            // Top gradient — subtle consistent fade
            VStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.06, blue: 0.18).opacity(0.35),
                        Color(red: 0.1, green: 0.08, blue: 0.2).opacity(0.12),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 70)
                .allowsHitTesting(false)
                Spacer()
            }

            // Bottom gradient — subtle animated fade
            VStack {
                Spacer()
                ZStack {
                    // Base layer
                    LinearGradient(
                        colors: [
                            .clear,
                            Color(red: 0.1, green: 0.08, blue: 0.2).opacity(0.2),
                            Color(red: 0.08, green: 0.06, blue: 0.18).opacity(0.5)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    // Shifting accent layer
                    LinearGradient(
                        colors: [
                            .clear,
                            Color(red: 0.12, green: 0.06, blue: 0.22).opacity(0.15),
                            Color(red: 0.06, green: 0.08, blue: 0.2).opacity(0.3)
                        ],
                        startPoint: UnitPoint(x: 0.3 + 0.2 * sin(gradientPhase), y: 0),
                        endPoint: UnitPoint(x: 0.7 + 0.2 * cos(gradientPhase), y: 1)
                    )
                }
                .frame(height: 120)
                .allowsHitTesting(false)
            }

            // Top: music row
            photoTopMusicRow

            // Bottom: stats + exercises
            photoBottomInfo
                .padding(.horizontal, 14)
                .padding(.bottom, 16)

            // Double-tap heart burst
            if showDoubleTapHeart {
                DoubleTapHeartBurst(isActive: true, location: doubleTapLocation)
            }
        }
        .clipShape(Rectangle())
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { location in
            doubleTapLocation = location
            showDoubleTapHeart = true
            #if canImport(UIKit)
            let heavy = UIImpactFeedbackGenerator(style: .heavy)
            heavy.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            #endif
            if !isLiked {
                isLiked = true
                post.likeCount += 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showDoubleTapHeart = false
            }
        }
        .onTapGesture(count: 1) {
            if sharedWorkout != nil {
                showWorkoutDetail = true
            }
        }
    }

    // MARK: - Top Music Row

    @ViewBuilder
    private var photoTopMusicRow: some View {
        let hasMusic = post.songTitle != nil && post.artistName != nil

        if hasMusic, let song = post.songTitle, let artist = post.artistName {
            VStack {
                HStack {
                    Spacer()
                    HStack(spacing: 8) {
                        albumArtView
                        photoMusicLine(song: song, artist: artist)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                Spacer()
            }
        }
    }

    // MARK: - Bottom Info (title + exercises)

    @ViewBuilder
    private var photoBottomInfo: some View {
        let hasExercises = sharedWorkout != nil && !(sharedWorkout?.exercises.isEmpty ?? true)
        let hasRoute = isCardioWithRoute

        VStack(alignment: .leading, spacing: 6) {
            Spacer()

            // Exercise GIFs or route map
            if hasRoute, let points = sharedWorkout?.routePoints {
                PostRouteMapView(
                    routePoints: points,
                    distance: post.duration.map { _ in "5.00 km" },
                    pace: "4:31 /km",
                    height: 60
                )
                .frame(height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 14)
                .onTapGesture { showFullRouteMap = true }
            } else if hasExercises {
                // Stats above GIFs
                if compactStatString.count > 0 {
                    Text(compactStatString)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .kerning(0.3)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 1)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }

                photoWorkoutGifs
            } else if compactStatString.count > 0 {
                Text(compactStatString)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.white.opacity(0.65))
                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var albumArtView: some View {
        let isSpotify = post.musicSource?.lowercased().contains("spotify") == true
        let serviceColor: Color = isSpotify ? Color(hex: "1DB954") : Color(hex: "FC3C44")

        return Group {
            if let url = albumArtworkURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        albumArtPlaceholder(serviceColor: serviceColor)
                    }
                }
            } else {
                albumArtPlaceholder(serviceColor: serviceColor)
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 1)
    }

    private func albumArtPlaceholder(serviceColor: Color) -> some View {
        ZStack {
            LinearGradient(
                colors: [serviceColor, serviceColor.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "music.note")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    private var workoutIconView: some View {
        let type = post.workoutType ?? ""
        let icon = WorkoutType(rawValue: type)?.icon ?? "dumbbell"

        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(0.15))
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(width: 36, height: 36)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.15), lineWidth: 0.5)
        )
    }

    private var isPlayingMusic: Bool {
        MusicPreviewService.shared.isPlayingPost(post.id)
    }

    private func photoMusicLine(song: String, artist: String) -> some View {
        let isSpotify = post.musicSource?.lowercased().contains("spotify") == true
        let serviceColor: Color = isSpotify ? Color(hex: "1DB954") : Color(hex: "FC3C44")
        let hasPlaylist = (isSpotify ? post.spotifyPlaylistURL : post.appleMusicPlaylistURL) != nil

        return HStack(spacing: 6) {
            if isSpotify {
                SpotifyIcon(size: 11)
            } else {
                AppleMusicIcon(size: 11)
            }

            Button {
                // Song tap — open in either service
                openMusicSearch(song: song, artist: artist, service: isSpotify ? .spotify : .appleMusic)
            } label: {
                Text("\(song) · \(artist)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 1)
                    .lineLimit(1)
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
                if hasPlaylist {
                    let playlistService: String = isSpotify ? "Spotify" : "Apple Music"
                    Button {
                        let urlStr = isSpotify ? post.spotifyPlaylistURL : post.appleMusicPlaylistURL
                        #if canImport(UIKit)
                        if let urlStr, let url = URL(string: urlStr) {
                            UIApplication.shared.open(url)
                        }
                        #endif
                    } label: {
                        Label("Open Playlist in \(playlistService)", systemImage: "music.note.list")
                    }
                }
            }

            AudioReactiveBars(
                barCount: 4,
                barWidth: 2.5,
                maxHeight: 16,
                color: serviceColor,
                isPlaying: isPlayingMusic,
                audioLevel: MusicPreviewService.shared.audioLevel
            )
            .frame(width: 18, height: 16)
        }
    }

    // MARK: - Music Overlay Option A (Floating Glassmorphic Pill)

    @ViewBuilder
    private var photoWorkoutGifs: some View {
        let hasExercises = sharedWorkout != nil && !(sharedWorkout?.exercises.isEmpty ?? true)

        if hasExercises, let workout = sharedWorkout {
            OverlayExerciseGifStrip(
                exercises: workout.exercises,
                totalCount: workout.exercises.count,
                onTapMore: { showWorkoutDetail = true }
            )
        }
    }

    private var compactStatString: String {
        var parts: [String] = []
        if let duration = post.duration, duration > 0 { parts.append("\(duration) min") }
        if let sets = post.setCount, sets > 0 { parts.append("\(sets) sets") }
        if let workout = sharedWorkout {
            let count = workout.exercises.count
            if count > 0 { parts.append("\(count) exercises") }
        }
        return parts.joined(separator: " · ")
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
            // Clean bottom-left map card for cardio posts
            HStack {
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

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        } else if hasStats {
            Button {
                if sharedWorkout != nil { showWorkoutDetail = true }
            } label: {
                HStack(spacing: 6) {
                    if let type = post.workoutType, let wt = WorkoutType(rawValue: type) {
                        Image(systemName: wt.icon)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(GQGradients.workoutColor(for: wt).opacity(0.9))
                    }

                    Text(compactStatString)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)

                    if sharedWorkout != nil {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.black.opacity(0.35))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var captionSection: some View {
        if !post.caption.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Button {
                        showComments = true
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(post.caption)
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                                .lineSpacing(2)
                                .lineLimit(showFullCaption ? nil : 2)
                                .multilineTextAlignment(.leading)

                            if !showFullCaption && post.caption.count > 140 {
                                Text("more")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            ChatBubbleShape(isFromCurrentUser: true)
                                .fill(GQGradients.primary)
                                .shadow(color: GQColors.deepBlue.opacity(0.4), radius: 8, x: 0, y: 4)
                        )
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showFullCaption = true
                        }
                    })

                    Spacer(minLength: 40)
                }

                HStack(spacing: 4) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.system(size: 9))
                    Text("tap to reply")
                        .font(.system(size: 11))
                }
                .foregroundColor(GQColors.textTertiary)
                .padding(.leading, 14)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
        }
    }

    @ViewBuilder
    private var challengeSection: some View {
        if let challenge = cachedChallenge {
            challengeCard(challenge)
        }
    }

    private func challengeCard(_ challenge: PostChallengeData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            challengeHeader(challenge)
            challengeStats(challenge)
            challengeJoinButton
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(GQColors.surfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    private func challengeHeader(_ challenge: PostChallengeData) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 14))
                .foregroundColor(.orange)

            Text(challenge.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(GQColors.textPrimary)

            Spacer()

            if let goalType = ChallengeGoalType(rawValue: challenge.goalType) {
                Image(systemName: goalType.icon)
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textSecondary)
            }
        }
    }

    private func challengeStats(_ challenge: PostChallengeData) -> some View {
        let daysLeft = max(0, Calendar.current.dateComponents([.day], from: Date(), to: challenge.endDate).day ?? 0)
        return HStack(spacing: 12) {
            Label("\(challenge.goalTarget) \(challenge.goalType)", systemImage: "target")
                .font(.system(size: 12))
                .foregroundColor(GQColors.textSecondary)

            Label("\(daysLeft)d left", systemImage: "clock")
                .font(.system(size: 12))
                .foregroundColor(GQColors.textSecondary)

            Spacer()

            Label("\(challenge.participantCount)", systemImage: "person.2.fill")
                .font(.system(size: 12))
                .foregroundColor(GQColors.textSecondary)
        }
    }

    @ViewBuilder
    private var challengeJoinButton: some View {
        if post.authorId != currentUserId {
            Button {
                joinChallenge()
            } label: {
                Text(hasJoinedChallenge ? "Joined" : "Join Challenge")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(hasJoinedChallenge ? .orange : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(challengeJoinBackground)
            }
            .buttonStyle(.plain)
            .disabled(hasJoinedChallenge)
        }
    }

    @ViewBuilder
    private var challengeJoinBackground: some View {
        if hasJoinedChallenge {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.orange, lineWidth: 1.5)
                )
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(GQGradients.primary)
        }
    }

    private func joinChallenge() {
        guard let challenge = cachedChallenge, !hasJoinedChallenge else { return }

        let enrollment = ChallengeEnrollment(
            challengeId: challenge.challengeId,
            userId: currentUserId
        )
        modelContext.insert(enrollment)

        // Update participant count in post's challenge data
        var updated = challenge
        updated.participantCount += 1
        post.challengeData = try? JSONEncoder().encode(updated)
        cachedChallenge = updated

        try? modelContext.save()
        hasJoinedChallenge = true

        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
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
                        let svc = MusicPreviewService.shared
                        if svc.currentPostId == post.id {
                            if svc.isPlaying { svc.pause() } else { svc.resume() }
                        } else if let song = post.songTitle, let artist = post.artistName {
                            svc.play(postId: post.id, song: song, artist: artist, fallbackURL: post.songPreviewURL, snippetStart: post.musicSnippetStart ?? 0)
                        }
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
                hasWorkout: sharedWorkout != nil,
                onFollowWorkout: sharedWorkout != nil ? {
                    showWorkoutDetail = true
                } : nil,
                currentUserId: currentUserId,
                currentUserName: currentUserName
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private var inlineCommentPreview: some View {
        if post.commentCount > 0, let comment = topComment {
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    showComments = true
                } label: {
                    HStack(alignment: .bottom, spacing: 6) {
                        Circle()
                            .fill(GQGradients.primary)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Text(String(comment.authorName.prefix(1)).uppercased())
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                            )

                        VStack(alignment: .leading, spacing: 1) {
                            Text(comment.authorName)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(GQColors.textSecondary)

                            Text(comment.content)
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "1C1C1E"))
                                .lineLimit(1)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    ChatBubbleShape(isFromCurrentUser: false)
                                        .fill(LinearGradient(colors: [Color(hex: "F5F5F7"), Color(hex: "E8E8ED")], startPoint: .top, endPoint: .bottom))
                                )
                        }

                        Spacer(minLength: 60)
                    }
                }
                .buttonStyle(.plain)

                if post.commentCount > 1 {
                    Button {
                        showComments = true
                    } label: {
                        Text("View conversation (\(post.commentCount - 1) \(post.commentCount == 2 ? "reply" : "replies"))")
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textTertiary)
                            .padding(.leading, 28)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Helpers

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

// MARK: - Audio Reactive Bars

struct AudioReactiveBars: View {
    var barCount: Int = 4
    var barWidth: CGFloat = 2.5
    var maxHeight: CGFloat = 16
    var color: Color = .white
    var isPlaying: Bool
    var audioLevel: Float  // 0...1

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<barCount, id: \.self) { i in
                let offset = Float(i) * 0.8
                let level = isPlaying ? CGFloat(audioLevel) : 0.2
                let barLevel = min(1.0, max(0.2, level + CGFloat(sin(Double(offset + audioLevel * 6))) * 0.3))
                RoundedRectangle(cornerRadius: barWidth / 2)
                    .fill(color)
                    .frame(width: barWidth, height: isPlaying ? barLevel * maxHeight : maxHeight * 0.25)
                    .animation(.easeOut(duration: 0.12), value: audioLevel)
            }
        }
    }
}

// MARK: - Streak Milestone Card

struct StreakMilestoneCard: View {
    let userName: String
    let days: Int
    let workouts: Int

    private var streakLabel: String {
        switch days {
        case ..<14: return "1 Week"
        case ..<21: return "2 Weeks"
        case ..<30: return "3 Weeks"
        case ..<60: return "1 Month"
        case ..<90: return "2 Months"
        case ..<180: return "3 Months"
        case ..<365: return "6 Months"
        default: return "1 Year"
        }
    }

    private var streakEmoji: String {
        switch days {
        case ..<14: return "🔥"
        case ..<30: return "🔥🔥"
        case ..<60: return "⚡️"
        case ..<90: return "💎"
        default: return "👑"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Streak ring
            ZStack {
                Circle()
                    .stroke(GQColors.textSecondary.opacity(0.2), lineWidth: 3)
                    .frame(width: 44, height: 44)
                Circle()
                    .trim(from: 0, to: min(CGFloat(days) / 30.0, 1.0))
                    .stroke(GQColors.textSecondary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
                Text(streakEmoji)
                    .font(.system(size: 18))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(userName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                    Text("\(streakLabel) streak")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(GQColors.textSecondary)
                }

                Text("\(workouts) workouts in \(days) days — showing up every week")
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(GQColors.surfaceBase)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(GQColors.textSecondary.opacity(0.5))
                .frame(width: 3)
                .padding(.vertical, 14)
        }
    }
}

// MARK: - Workout Suggestion Card

struct WorkoutSuggestionCard: View {
    let workout: SharedWorkoutData
    let suggestedBy: String
    var profile: UserProfile? = nil

    @EnvironmentObject var appState: AppState
    @State private var showWorkoutDetail = false
    @State private var showingCopySheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.primary)

                Text("Workout to Try")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(GQColors.primary)

                Spacer()

                Text("from \(suggestedBy)")
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textTertiary)
            }

            // Workout title + type badge
            HStack(spacing: 8) {
                Text(workout.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(GQColors.textPrimary)

                if let wt = WorkoutType(rawValue: workout.workoutType) {
                    Text(workout.workoutType)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(GQGradients.workoutColor(for: wt))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(GQGradients.workoutColor(for: wt).opacity(0.12))
                        .cornerRadius(6)
                }

                Spacer()
            }

            // Mini stats row
            HStack(spacing: 16) {
                Label("\(workout.estimatedDuration) min", systemImage: "clock")
                Label("\(workout.exercises.count) exercises", systemImage: "list.bullet")
                let totalSets = workout.exercises.reduce(0) { $0 + $1.sets.count }
                Label("\(totalSets) sets", systemImage: "flame")
            }
            .font(.system(size: 12))
            .foregroundColor(GQColors.textSecondary)

            // Exercise preview (first 3)
            VStack(spacing: 6) {
                ForEach(workout.exercises.prefix(3)) { exercise in
                    HStack(spacing: 8) {
                        ExerciseGifView(exerciseName: exercise.name, size: .thumbnail)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(exercise.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(GQColors.textPrimary)
                            Text("\(exercise.sets.count) sets • \(exercise.muscleGroup)")
                                .font(.system(size: 11))
                                .foregroundColor(GQColors.textTertiary)
                        }
                        Spacer()
                    }
                }
            }

            // CTA button
            Button {
                showingCopySheet = true
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12))
                    Text("Try This Workout")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(GQGradients.primary)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(GQColors.surfaceBase)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(GQColors.primary)
                .frame(width: 3)
                .padding(.vertical, 16)
        }
        .sheet(isPresented: $showingCopySheet) {
            if let userProfile = profile {
                WorkoutCopySheet(workoutData: workout, profile: userProfile)
            }
        }
    }
}

// MARK: - Community Pulse Card

struct CommunityPulseCard: View {
    let activeCount: Int
    let recentPRs: Int
    let topExercise: String

    var body: some View {
        HStack(spacing: 0) {
            pulseStat(value: "\(activeCount)", label: "friends active", icon: "person.2.fill")
            divider
            pulseStat(value: "\(recentPRs)", label: "new PRs", icon: "trophy.fill")
            divider
            pulseStat(value: topExercise, label: "trending", icon: "chart.line.uptrend.xyaxis")
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .background(GQColors.surfaceBase)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [GQColors.textSecondary.opacity(0.3), GQColors.primary.opacity(0.3)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
        }
    }

    @ViewBuilder
    private func pulseStat(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(GQColors.textSecondary)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(GQColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(GQColors.borderSubtle)
            .frame(width: 1, height: 40)
    }
}

// MARK: - Motivation Prompt Card

struct MotivationPromptCard: View {
    let message: String
    let type: MotivationType

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(.system(size: 18))
                .foregroundColor(type.accentColor)
                .frame(width: 36, height: 36)
                .background(type.accentColor.opacity(0.12))
                .cornerRadius(10)

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(GQColors.textPrimary)
                .lineSpacing(2)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(GQColors.surfaceBase)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(type.accentColor.opacity(0.5))
                .frame(width: 3)
                .padding(.vertical, 14)
        }
    }
}

// MARK: - Inspiration Chain Card

struct InspirationChainCard: View {
    let original: Post
    let followers: [String]
    var profile: UserProfile? = nil

    @State private var showingCopySheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.secondary)

                Text("Workout Chain")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(GQColors.secondary)

                Spacer()
            }

            // Chain visualization
            HStack(spacing: 0) {
                // Original author avatar
                chainAvatar(name: original.authorName, isOriginal: true)

                // Dotted connector
                chainConnector

                // Follower avatars
                ForEach(Array(followers.prefix(3).enumerated()), id: \.offset) { _, name in
                    chainAvatar(name: name, isOriginal: false)
                    if name != followers.prefix(3).last {
                        chainConnector
                    }
                }

                if followers.count > 3 {
                    Text("+\(followers.count - 3)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)
                        .padding(.leading, 6)
                }

                Spacer()
            }

            // Description
            Text("\(followers.first ?? "Someone") tried \(original.authorName)'s \(original.workoutType ?? "workout")")
                .font(.system(size: 14))
                .foregroundColor(GQColors.textPrimary)
            +
            Text(followers.count > 1 ? " — \(followers.count) others also tried it" : "")
                .font(.system(size: 14))
                .foregroundColor(GQColors.textSecondary)

            // CTA
            if let workout = original.getSharedWorkout() {
                Button {
                    showingCopySheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.system(size: 12))
                        Text("Join the chain")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(GQColors.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(GQColors.secondary.opacity(0.12))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showingCopySheet) {
                    if let userProfile = profile {
                        WorkoutCopySheet(workoutData: workout, profile: userProfile)
                    }
                }
            }
        }
        .padding(16)
        .background(GQColors.surfaceBase)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(GQColors.secondary.opacity(0.5))
                .frame(width: 3)
                .padding(.vertical, 16)
        }
    }

    @ViewBuilder
    private func chainAvatar(name: String, isOriginal: Bool) -> some View {
        Circle()
            .fill(isOriginal ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(GQColors.adaptiveOverlay(0.1)))
            .frame(width: 32, height: 32)
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isOriginal ? .white : GQColors.textSecondary)
            )
            .overlay(
                Circle()
                    .stroke(isOriginal ? GQColors.secondary : GQColors.borderSubtle, lineWidth: 1.5)
            )
    }

    private var chainConnector: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .fill(GQColors.textTertiary)
                    .frame(width: 3, height: 3)
            }
        }
        .padding(.horizontal, 4)
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
        return [GQColors.deepBlue, GQColors.textSecondary]
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
                    gradientColors: [subType.color, GQColors.textSecondary],
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
    var gradientColors: [Color] = [GQColors.textSecondary, GQColors.textSecondary]
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
                                .fill(GQColors.textSecondary)
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
                                .fill(GQColors.textSecondary)
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
                        .foregroundColor(gradientColors.first ?? GQColors.textSecondary)
                    Text(String(format: "%.1f km", distance))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }

                HStack(spacing: 4) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 11))
                        .foregroundColor(gradientColors.last ?? GQColors.textSecondary)
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
    var hasWorkout: Bool = false
    var onFollowWorkout: (() -> Void)?
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

    @State private var floatingEmoji: String? = nil
    @State private var floatingEmojiOffset: CGFloat = 0
    @State private var floatingEmojiOpacity: Double = 1

    var body: some View {
        ZStack(alignment: .top) {
            HStack(spacing: 10) {
                reactionEmojiRow
                compactCommentButton
                Spacer()
            }

            // Floating emoji that launches up on reaction
            if let emoji = floatingEmoji {
                Text(emoji)
                    .font(.system(size: 28))
                    .offset(y: floatingEmojiOffset)
                    .opacity(floatingEmojiOpacity)
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            displayedLikeCount = post.likeCount
            displayedCommentCount = post.commentCount
            checkIfLiked()
        }
    }

    @State private var tappedReaction: ReactionType? = nil
    @State private var rippleReaction: ReactionType? = nil

    private func launchFloatingEmoji(_ emoji: String) {
        floatingEmoji = emoji
        floatingEmojiOffset = 0
        floatingEmojiOpacity = 1
        withAnimation(.easeOut(duration: 0.7)) {
            floatingEmojiOffset = -60
            floatingEmojiOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            floatingEmoji = nil
        }
    }

    @ViewBuilder
    private var reactionEmojiRow: some View {
        HStack(spacing: 2) {
            ForEach(ReactionType.allCases, id: \.self) { reaction in
                Button {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                        tappedReaction = reaction
                    }
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    rippleReaction = reaction
                    addReaction(reaction)
                    if !isLiked { performLikeAnimation() }
                    launchFloatingEmoji(reaction.emoji)
                    sentReactionEmoji = reaction.emoji
                    withAnimation(.spring(response: 0.3)) { showSentReaction = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            tappedReaction = nil
                            rippleReaction = nil
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation { showSentReaction = false }
                    }
                } label: {
                    Text(reaction.emoji)
                        .font(.system(size: 18))
                        .scaleEffect(tappedReaction == reaction ? 1.4 : 1.0)
                        .padding(3)
                }
                .buttonStyle(.plain)
            }

            if displayedLikeCount > 0 {
                AnimatedCounter(value: displayedLikeCount)
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textTertiary)
                    .padding(.leading, 4)
            }
        }
    }

    @ViewBuilder
    private var compactCommentButton: some View {
        Button {
            showComments = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "bubble.right")
                    .font(.system(size: 15))

                if displayedCommentCount > 0 {
                    AnimatedCounter(value: displayedCommentCount)
                        .font(.system(size: 12))
                        .foregroundColor(GQColors.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .foregroundColor(GQColors.textSecondary)
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
            .foregroundColor(GQColors.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(GQColors.textSecondary.opacity(0.12))
            .cornerRadius(12)
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
        .foregroundColor(GQColors.textTertiary)
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
            .homeSocialCard(accent: GQColors.textSecondary, emphasized: true, cornerRadius: 12)
        }
        .buttonStyle(GQInteractiveStyle())
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
                .fill(LinearGradient(colors: [GQColors.deepBlue, GQColors.textSecondary], startPoint: .topLeading, endPoint: .bottomTrailing))
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
                    .foregroundColor(GQColors.deepBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(GQColors.deepBlue.opacity(0.12))
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
                .aspectRatio(4.0/5.2, contentMode: .fit)
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
                        .foregroundColor(isLiked ? GQColors.deepBlue : GQColors.textTertiary)
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
                    .foregroundColor(GQColors.deepBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(GQColors.deepBlue.opacity(0.12))
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
            .foregroundColor(GQColors.textTertiary)
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
                            .foregroundColor(GQColors.textSecondary.opacity(0.8))
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
                                .foregroundColor(isLiked ? GQColors.deepBlue : GQColors.textTertiary)
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
                    .foregroundColor(GQColors.deepBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(GQColors.deepBlue.opacity(0.12))
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
            .foregroundColor(GQColors.textTertiary)
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
            let colors: [Color] = [GQColors.deepBlue, GQColors.deepBlue.opacity(0.7), GQColors.deepBlue]
            let particle = ParticleData(
                id: UUID(),
                x: 0,
                y: 0,
                targetX: cos(angle) * distance,
                targetY: sin(angle) * distance,
                size: CGFloat.random(in: 6...10),
                color: colors.randomElement() ?? GQColors.deepBlue,
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

// MARK: - Coming Soon View

struct ComingSoonView: View {
    let feature: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)

            Image(systemName: "sparkles")
                .font(.system(size: 50))
                .foregroundColor(GQColors.deepBlue.opacity(0.5))

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
                    .fill(LinearGradient(colors: [GQColors.deepBlue, GQColors.textSecondary], startPoint: .topLeading, endPoint: .bottomTrailing))
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
                        .background(GQColors.deepBlue.opacity(0.3))
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
                            .foregroundColor(isLiked ? GQColors.deepBlue : .white)
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
                            color: GQColors.textSecondary
                        )
                    }

                    // Location
                    if let location = post.locationName {
                        PostTagBadge(
                            icon: "location.fill",
                            text: location,
                            color: GQColors.textSecondary
                        )
                    }

                    // Squads
                    ForEach(Array(zip(post.taggedSquadIds, post.taggedSquadNames)), id: \.0) { _, squadName in
                        PostTagBadge(
                            icon: "person.3.fill",
                            text: squadName,
                            color: GQColors.deepBlue
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
                .aspectRatio(4.0/5.2, contentMode: .fit)

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
                        .foregroundColor(isAttending ? .white : GQColors.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(isAttending ? GQColors.textSecondary : GQColors.textSecondary.opacity(0.15))
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
                .foregroundColor(GQColors.textSecondary)
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
                            .tint(GQColors.textSecondary)
                    }

                    // Recurring toggle
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(isOn: $isRecurring) {
                            HStack(spacing: 6) {
                                Image(systemName: "repeat")
                                    .font(.system(size: 13))
                                    .foregroundColor(GQColors.textSecondary)
                                Text("Recurring Event")
                                    .font(.system(size: 14, weight: .medium))
                            }
                        }
                        .tint(GQColors.textSecondary)

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
                                colors: [GQColors.deepBlue, GQColors.textSecondary],
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
                .font(.system(size: 36))
                .scaleEffect(animate ? 0.5 : 1.4)
                .opacity(animate ? 0 : 1)
                .offset(y: animate ? -80 : 0)

            Text(emoji)
                .font(.system(size: 24))
                .scaleEffect(animate ? 0.4 : 0.9)
                .opacity(animate ? 0 : 0.6)
                .offset(x: 16, y: animate ? -60 : 5)
                .animation(.easeOut(duration: 1.2).delay(0.15), value: animate)
        }
        .animation(.easeOut(duration: 1.2), value: animate)
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

// MARK: - Chat Bubble Shape

struct ChatBubbleShape: InsettableShape {
    let isFromCurrentUser: Bool

    func path(in rect: CGRect) -> Path {
        let corners: RectangleCornerRadii
        if isFromCurrentUser {
            corners = RectangleCornerRadii(topLeading: 18, bottomLeading: 18, bottomTrailing: 4, topTrailing: 18)
        } else {
            corners = RectangleCornerRadii(topLeading: 18, bottomLeading: 4, bottomTrailing: 18, topTrailing: 18)
        }
        return UnevenRoundedRectangle(cornerRadii: corners).path(in: rect)
    }

    func inset(by amount: CGFloat) -> some InsettableShape {
        self
    }
}

// MARK: - Image Brightness Analysis

#if canImport(UIKit)
extension UIImage {
    func averageBrightness() -> CGFloat {
        guard let cgImage = self.cgImage else { return 0.5 }

        // Sample a small thumbnail for performance
        let size = 40
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var rawData = [UInt8](repeating: 0, count: size * size * 4)

        guard let context = CGContext(
            data: &rawData,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return 0.5 }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))

        var totalBrightness: CGFloat = 0
        let pixelCount = size * size

        for i in 0..<pixelCount {
            let offset = i * 4
            let r = CGFloat(rawData[offset]) / 255.0
            let g = CGFloat(rawData[offset + 1]) / 255.0
            let b = CGFloat(rawData[offset + 2]) / 255.0
            // Perceived luminance
            totalBrightness += 0.299 * r + 0.587 * g + 0.114 * b
        }

        return totalBrightness / CGFloat(pixelCount)
    }
}
#endif

#Preview {
    FeedView(profile: UserProfile())
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
