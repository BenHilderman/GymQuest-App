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

// Home-tab filters. Memo directive: Friends (your people) is the default.
// Discover/algorithmic feed is a secondary "Explore" surface — inspiration only.
enum FeedFilter: String, CaseIterable {
    case friends = "Friends"
    case clubs = "Clubs"
    case discover = "Explore"
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
    /// Memo 4 "Reddit recurring thread" mechanic — a weekly prompt that invites users
    /// to post their session. Shows at the top of the Friends feed once per day.
    case weeklyPrompt(label: String, icon: String)

    var id: String {
        switch self {
        case .post(let p): return "post-\(p.id)"
        case .workoutSuggestion(let w, _): return "suggest-\(w.id)"
        case .communityPulse(let c, let p, let e): return "pulse-\(c)-\(p)-\(e)"
        case .motivationPrompt(let m, let t): return "motive-\(t.rawValue)-\(m.prefix(10))"
        case .inspirationChain(let p, _): return "chain-\(p.id)"
        case .streakMilestone(let n, let d, _): return "streak-\(n)-\(d)"
        case .weeklyPrompt(let label, _): return "prompt-\(label)"
        }
    }
}

// MARK: - Weekly Prompt Generator
//
// Memo 4 "Reddit recurring thread" mechanic. Each day of the week has a
// specific prompt that surfaces at the top of the Friends feed as a gentle
// invitation to post. Not a demand — just a nudge in spotter-culture voice.

enum WeeklyPromptGenerator {
    /// Day-of-week prompt. Returns a FeedItem.weeklyPrompt.
    static func todayPrompt() -> FeedItem {
        let weekday = Calendar.current.component(.weekday, from: Date())
        // 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat
        switch weekday {
        case 2: return .weeklyPrompt(label: "Monday push day — who's showing up?", icon: "figure.strengthtraining.traditional")
        case 3: return .weeklyPrompt(label: "Pull day check-in — post your session.", icon: "figure.strengthtraining.functional")
        case 4: return .weeklyPrompt(label: "Midweek legs — share your sets.", icon: "figure.walk")
        case 5: return .weeklyPrompt(label: "Thursday upper — log what you did.", icon: "dumbbell.fill")
        case 6: return .weeklyPrompt(label: "Friday finisher — how'd the week go?", icon: "flame.fill")
        case 7: return .weeklyPrompt(label: "Weekend session — rest or train?", icon: "figure.mind.and.body")
        default: return .weeklyPrompt(label: "Sunday reset — rest counts too.", icon: "moon.fill")
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

        // Weekly prompt thread at the top — memo 4 "Reddit recurring thread" mechanic
        items.append(WeeklyPromptGenerator.todayPrompt())

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
        // Noticing-style prompts only. No comparison, no "your friends are ahead",
        // no "only bad workout" guilt, no "crush" drill-sergeant tone.
        let prompts: [(String, MotivationType)] = [
            ("Show up however you can today.", .general),
            ("Rest days count too.", .comeback),
            ("Whenever you're ready.", .general),
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

    @State private var selectedFeedTab: FeedFilter = .friends
    @State private var catalogSearchQuery: String = ""
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
    // MARK: - Workout Catalog (Explore)
    //
    // Replaces the TikTok-style vertical pager with a Spotify Browse-style
    // catalog. Intent-based horizontal rails + search bar. Every card has a
    // "Use this" action — the feed converts viewing into doing.
    //
    // Design rationale (from memos 2-6):
    // - Reels is wrong: optimizes dwell time, violates "not a scroll trap"
    // - Pure search is wrong: requires user to already know what they want
    // - Catalog with smart rails: intent-based discovery + search utility +
    //   action-from-feed conversion on every card

    private var discoverFeedContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Search bar
                catalogSearchBar
                    .padding(.horizontal, 16)

                if !catalogSearchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                    // Search results
                    catalogSearchResults
                } else {
                    // Rails
                    catalogRail(
                        title: "Most Used This Week",
                        icon: "play.circle.fill",
                        posts: catalogMostUsed
                    )
                    catalogRail(
                        title: "Quick Sessions",
                        icon: "bolt.fill",
                        posts: catalogQuickSessions
                    )
                    catalogRail(
                        title: "Try Something New",
                        icon: "sparkles",
                        posts: catalogNovelTopics
                    )
                    catalogRail(
                        title: "Popular Push",
                        icon: "figure.strengthtraining.traditional",
                        posts: catalogByType("Push")
                    )
                    catalogRail(
                        title: "Popular Pull",
                        icon: "figure.strengthtraining.functional",
                        posts: catalogByType("Pull")
                    )
                    catalogRail(
                        title: "Leg Day",
                        icon: "figure.walk",
                        posts: catalogByType("Legs")
                    )
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .scrollContentBackground(.hidden)
        .gqPageBackground()
    }

    // MARK: - Catalog Search Bar

    private var catalogSearchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(GQColors.textTertiary)
            TextField("Search workouts, exercises, people...", text: $catalogSearchQuery)
                .font(.system(size: 14))
                .foregroundColor(GQColors.textPrimary)
                .autocorrectionDisabled()
            if !catalogSearchQuery.isEmpty {
                Button {
                    catalogSearchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(GQColors.textTertiary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(GQColors.surfaceBase)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(GQColors.borderDefault, lineWidth: 1)
        )
    }

    // MARK: - Catalog Rails

    @ViewBuilder
    private func catalogRail(title: String, icon: String, posts: [Post]) -> some View {
        if !posts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(GQGradients.primary)
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(GQColors.textPrimary)
                    Spacer()
                    Text("\(posts.count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(GQColors.textTertiary)
                }
                .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(posts.prefix(10)) { post in
                            WorkoutCatalogCard(
                                post: post,
                                currentUserId: profile.id,
                                profile: profile
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Catalog Search Results

    private var catalogSearchResults: some View {
        let query = catalogSearchQuery.lowercased()
        let results = workoutPosts.filter { post in
            (post.exerciseHighlight?.lowercased().contains(query) ?? false) ||
            (post.workoutType?.lowercased().contains(query) ?? false) ||
            post.authorName.lowercased().contains(query) ||
            post.caption.lowercased().contains(query)
        }.prefix(20)

        return VStack(alignment: .leading, spacing: 10) {
            Text("\(results.count) result\(results.count == 1 ? "" : "s")")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(GQColors.textTertiary)
                .padding(.horizontal, 16)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Array(results)) { post in
                    WorkoutCatalogCard(
                        post: post,
                        currentUserId: profile.id,
                        profile: profile
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Catalog Data Sources

    /// All posts that have serialized workout data (the actionable ones)
    private var workoutPosts: [Post] {
        posts.filter { $0.sharedWorkoutData != nil }
    }

    private var catalogMostUsed: [Post] {
        let weekAgo = Date().addingTimeInterval(-7 * 86400)
        return workoutPosts
            .filter { $0.timestamp > weekAgo }
            .sorted { $0.timesUsed > $1.timesUsed }
    }

    private var catalogQuickSessions: [Post] {
        workoutPosts.filter { ($0.duration ?? 999) <= 20 }
    }

    private var catalogNovelTopics: [Post] {
        // Posts with workout types the current user hasn't trained recently
        let userTypes = Set(allWorkouts.prefix(20).map { $0.type.rawValue })
        return workoutPosts.filter { post in
            guard let wt = post.workoutType else { return false }
            return !userTypes.contains(wt)
        }
    }

    private func catalogByType(_ type: String) -> [Post] {
        workoutPosts
            .filter { $0.workoutType?.lowercased() == type.lowercased() }
            .sorted { $0.timesUsed > $1.timesUsed }
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
                        case .weeklyPrompt(let label, let icon):
                            HStack(spacing: 12) {
                                Image(systemName: icon)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(GQGradients.primary)
                                    .frame(width: 40, height: 40)
                                    .background(GQColors.deepBlue.opacity(0.12))
                                    .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(label)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(GQColors.textPrimary)
                                    Text("Tap to log your session")
                                        .font(.system(size: 11))
                                        .foregroundColor(GQColors.textTertiary)
                                }
                                Spacer()
                            }
                            .padding(14)
                            .background(GQColors.surfaceBase)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(GQColors.borderDefault, lineWidth: 1)
                            )
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
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

// MARK: - Workout Catalog Card
//
// Compact card for the Explore catalog rails. Shows workout type, exercise
// highlight, duration, author, timesUsed, and a primary "Use this" action.
// Tapping the card body shows a detail sheet; tapping the button starts
// the workout immediately via UseWorkoutService.

struct WorkoutCatalogCard: View {
    let post: Post
    let currentUserId: UUID
    let profile: UserProfile

    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext

    @State private var showDetail = false

    private var workout: SharedWorkoutData? { post.getSharedWorkout() }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: workout type icon + type name
            HStack(spacing: 8) {
                Image(systemName: workoutIcon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(GQGradients.primary)
                    .frame(width: 32, height: 32)
                    .background(GQColors.deepBlue.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 1) {
                    Text(post.workoutType ?? "Workout")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(GQColors.textPrimary)
                        .lineLimit(1)
                    if let highlight = post.exerciseHighlight {
                        Text(highlight)
                            .font(.system(size: 10))
                            .foregroundColor(GQColors.textTertiary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }

            // Stats row
            HStack(spacing: 8) {
                if let d = post.duration {
                    statChip(icon: "clock.fill", text: "\(d)m")
                }
                if let s = post.setCount {
                    statChip(icon: "list.bullet", text: "\(s) sets")
                }
            }

            // Author + used count
            HStack(spacing: 4) {
                Text(post.authorName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(GQColors.textTertiary)
                    .lineLimit(1)
                Spacer()
                if post.timesUsed > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 7))
                        Text("\(post.timesUsed)")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(GQColors.success)
                }
            }

            // Primary CTA
            if post.authorId != currentUserId {
                Button {
                    UseWorkoutService.use(
                        post: post,
                        currentUserId: currentUserId,
                        appState: appState,
                        modelContext: modelContext
                    )
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text("Use this")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(GQGradients.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(width: 165)
        .background(GQColors.surfaceBase)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(GQColors.borderDefault, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 6, y: 3)
        .onTapGesture { showDetail = true }
        .sheet(isPresented: $showDetail) {
            if let workout {
                WorkoutDetailSheet(
                    workoutData: workout,
                    onFollow: {
                        showDetail = false
                        UseWorkoutService.use(
                            post: post,
                            currentUserId: currentUserId,
                            appState: appState,
                            modelContext: modelContext
                        )
                    },
                    onAddExercise: { _ in }
                )
            }
        }
    }

    private func statChip(icon: String, text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .semibold))
            Text(text)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(GQColors.textTertiary)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(GQColors.adaptiveOverlay(0.05))
        .clipShape(Capsule())
    }

    private var workoutIcon: String {
        switch post.workoutType?.lowercased() {
        case "push": return "figure.strengthtraining.traditional"
        case "pull": return "figure.strengthtraining.functional"
        case "legs": return "figure.walk"
        case "cardio": return "figure.run"
        case "hiit": return "bolt.heart.fill"
        case "full body": return "figure.cross.training"
        default: return "dumbbell.fill"
        }
    }
}
