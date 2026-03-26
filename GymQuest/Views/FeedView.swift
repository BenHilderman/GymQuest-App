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
import SDWebImage
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
    @Query(sort: \Workout.date, order: .reverse) private var allWorkouts: [Workout]
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
                fetchRemotePosts()
                Task {
                    refreshSocialGraph()
                    refreshFriendsPosts()
                }
                prefetchAlbumArt()
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

    private var thisWeekRecapWorkouts: [Workout] {
        let calendar = Calendar.current
        guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return [] }
        return allWorkouts.filter { $0.date >= startOfWeek && $0.type != .rest }
    }

    // MARK: - Prefetch Album Art

    private func prefetchAlbumArt() {
        let urls = posts.compactMap { $0.albumArtURL }
            .compactMap { URL(string: $0) }
        SDWebImagePrefetcher.shared.prefetchURLs(urls)
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

    // MARK: - Remote Post Fetch

    private func fetchRemotePosts() {
        guard FeatureFlags.shared.supabaseSyncEnabled else { return }
        Task {
            do {
                let remotePosts: [PostDTO] = try await SupabaseSyncService.shared.fetch(from: "posts") { query in
                    query.order("created_at", ascending: false).limit(30)
                }
                for dto in remotePosts {
                    await upsertLocalPost(from: dto)
                }
            } catch {
                print("[FeedView] Failed to fetch remote posts: \(error)")
            }
        }
    }

    @MainActor
    private func upsertLocalPost(from dto: PostDTO) {
        let dtoId = dto.id
        let descriptor = FetchDescriptor<Post>(predicate: #Predicate<Post> { $0.id == dtoId })
        let existing = try? modelContext.fetch(descriptor)
        if existing?.isEmpty ?? true {
            let post = Post(
                id: dto.id,
                authorId: dto.authorId,
                authorName: dto.authorName,
                authorUsername: dto.authorUsername,
                caption: dto.caption ?? "",
                workoutType: dto.workoutType,
                duration: dto.duration,
                setCount: dto.setCount,
                exerciseHighlight: dto.exerciseHighlight,
                songTitle: dto.songTitle,
                artistName: dto.artistName,
                likeCount: dto.likeCount,
                commentCount: dto.commentCount
            )
            modelContext.insert(post)
        }
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
                            selectedTab = tab
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

// MARK: - Weekly Recap Card (Apple Photos Memories style)

struct WeeklyRecapCard: View {
    let workouts: [Workout]
    let profile: UserProfile

    private var workoutCount: Int { workouts.count }
    private var totalMinutes: Int { workouts.reduce(0) { $0 + $1.duration } }
    private var totalVolume: Double { workouts.reduce(0) { $0 + $1.totalVolume } }
    private var totalSets: Int { workouts.reduce(0) { $0 + $1.totalSets } }

    private var topExercise: String {
        let all = workouts.flatMap(\.exercises)
        let grouped = Dictionary(grouping: all, by: \.name)
        return grouped.max { $0.value.count < $1.value.count }?.key ?? "Rest"
    }

    private var prCount: Int {
        workouts.flatMap(\.prEvents).count
    }

    private var dayNames: [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return workouts.prefix(5).map { formatter.string(from: $0.date) }
    }

    var body: some View {
        if workoutCount > 0 {
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("YOUR WEEK")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(GQColors.textTertiary)
                            .tracking(0.5)
                        Text(weekRangeText)
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundStyle(GQGradients.primary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

                // Stats row
                HStack(spacing: 0) {
                    recapStat(value: "\(workoutCount)", label: "workouts")
                    divider
                    recapStat(value: "\(totalMinutes)", label: "min")
                    divider
                    recapStat(value: formatVolume(totalVolume), label: "volume")
                    divider
                    recapStat(value: "\(totalSets)", label: "sets")
                }
                .padding(.bottom, 12)

                // Workout type pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(workouts.prefix(6)) { w in
                            HStack(spacing: 4) {
                                Image(systemName: w.type.icon)
                                    .font(.system(size: 10))
                                Text(w.type.rawValue)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(GQColors.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(GQColors.overlayLight)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 10)

                // Highlights
                VStack(spacing: 6) {
                    if !topExercise.isEmpty && topExercise != "Rest" {
                        highlightRow(icon: "star.fill", text: "Most trained: \(topExercise)")
                    }
                    if prCount > 0 {
                        highlightRow(icon: "trophy.fill", text: "\(prCount) new PR\(prCount > 1 ? "s" : "") this week!")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
            .homeSocialCard(cornerRadius: 16)
        }
    }

    private var divider: some View {
        Rectangle().fill(GQColors.borderSubtle).frame(width: 1, height: 28)
    }

    private func recapStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(GQGradients.primary)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func highlightRow(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(GQGradients.primary)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(GQColors.textSecondary)
            Spacer()
        }
    }

    private var weekRangeText: String {
        let calendar = Calendar.current
        guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: startOfWeek)) – \(formatter.string(from: Date()))"
    }

    private func formatVolume(_ v: Double) -> String {
        if v >= 1000 { return String(format: "%.1fk", v / 1000) }
        return "\(Int(v))"
    }
}

#Preview {
    FeedView(profile: UserProfile())
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
