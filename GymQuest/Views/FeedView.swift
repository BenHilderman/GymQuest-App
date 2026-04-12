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
        case 2: return .weeklyPrompt(label: "Monday push day. Who's showing up?", icon: "figure.strengthtraining.traditional")
        case 3: return .weeklyPrompt(label: "Pull day check-in. Post your session.", icon: "figure.strengthtraining.functional")
        case 4: return .weeklyPrompt(label: "Midweek legs. Share your sets.", icon: "figure.walk")
        case 5: return .weeklyPrompt(label: "Thursday upper. Log what you did.", icon: "dumbbell.fill")
        case 6: return .weeklyPrompt(label: "Friday finisher. How'd the week go?", icon: "flame.fill")
        case 7: return .weeklyPrompt(label: "Weekend session. Rest or train?", icon: "figure.mind.and.body")
        default: return .weeklyPrompt(label: "Sunday reset. Rest counts too.", icon: "moon.fill")
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

    // MARK: - Explore Page (People-first workout catalog)
    //
    // Organized around PEOPLE first, workouts second. The social graph IS the
    // recommendation engine. Comments are first-class content. Every element
    // ends in an action.
    //
    // Layout (top → bottom):
    //   1. Context observation (one-line noticing)
    //   2. Search bar + suggestion chips
    //   3. Community Pick (hero card — single most-used workout of the day)
    //   4. Squad Summary (aggregate crew activity this week)
    //   5. People Timeline (compact stream of friends' recent workouts)
    //   6. Trending in Your Circle (exercise bubbles)
    //   7. Discovery rails (Most Used, Quick Sessions, Try Something New)

    private var discoverFeedContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // 1. Context observation
                contextObservation
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                // 2. Search
                catalogSearchBar
                    .padding(.horizontal, 16)

                if !catalogSearchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                    catalogSearchResults
                } else {
                    // 2b. Suggestion chips (when not searching)
                    searchSuggestionChips
                        .padding(.horizontal, 16)

                    // 3. Community Pick
                    if let pick = communityPick {
                        communityPickCard(pick)
                            .padding(.horizontal, 16)
                    }

                    // 4. Squad Summary
                    squadSummaryCard
                        .padding(.horizontal, 16)

                    // 5. People Timeline
                    peopleTimeline
                        .padding(.horizontal, 16)

                    // 6. Trending
                    trendingBubbles

                    // 7. Visual explore grid (Instagram-style with workout data overlay)
                    exploreVisualGrid
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .scrollContentBackground(.hidden)
        .gqPageBackground()
    }

    // MARK: - 1. Context Observation

    @ViewBuilder
    private var contextObservation: some View {
        let obs = generateContextObservation()
        if !obs.isEmpty {
            HStack(spacing: 6) {
                Circle()
                    .fill(GQColors.vividPurple.opacity(0.6))
                    .frame(width: 5, height: 5)
                Text(obs)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(GQColors.textTertiary)
            }
        }
    }

    private func generateContextObservation() -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Check for workout-type gaps
        let recentTypes = Set(allWorkouts.prefix(10).map { $0.type.rawValue })
        let commonTypes = ["Push", "Pull", "Legs"]
        for type in commonTypes {
            let lastOfType = allWorkouts.first { $0.type.rawValue == type }
            if let last = lastOfType {
                let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: last.date), to: today).day ?? 0
                if days >= 7 {
                    return "\(days) days since \(type.lowercased())"
                }
            } else if !recentTypes.isEmpty {
                return "Haven't tried \(type.lowercased()) yet"
            }
        }
        return ""
    }

    // MARK: - 2b. Search Suggestions

    private var searchSuggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                let suggestions = generateSearchSuggestions()
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        catalogSearchQuery = suggestion
                    } label: {
                        Text(suggestion)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(GQColors.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .strokeBorder(GQColors.borderSubtle, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func generateSearchSuggestions() -> [String] {
        var suggestions: [String] = []
        // Most recent exercise
        if let recent = allWorkouts.first?.exercises.first?.name {
            suggestions.append(recent.lowercased())
        }
        suggestions.append(contentsOf: ["20-min finisher", "back day", "leg workout", "superset"])
        return Array(suggestions.prefix(5))
    }

    // MARK: - 3. Community Pick (Hero)

    private var communityPick: Post? {
        let dayAgo = Date().addingTimeInterval(-24 * 3600)
        return workoutPosts
            .filter { $0.timestamp > dayAgo && $0.authorId != profile.id }
            .sorted { $0.timesUsed > $1.timesUsed }
            .first ?? workoutPosts
            .filter { $0.authorId != profile.id }
            .sorted { ($0.likeCount + $0.commentCount) > ($1.likeCount + $1.commentCount) }
            .first
    }

    @ViewBuilder
    private func communityPickCard(_ post: Post) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section label
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(GQColors.vividPurple)
                Text("COMMUNITY PICK")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(GQColors.textTertiary)
            }

            // Author row
            HStack(spacing: 10) {
                Circle()
                    .fill(AnyShapeStyle(GQGradients.primary))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(post.authorName.prefix(1)).uppercased())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.authorName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(GQColors.textPrimary)
                    Text(post.workoutType ?? "Workout")
                        .font(.system(size: 12))
                        .foregroundColor(GQColors.textSecondary)
                }
                Spacer()
                if post.timesUsed > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 8))
                        Text("\(post.timesUsed) used today")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(GQColors.success)
                }
            }

            // Exercise highlight
            if let highlight = post.exerciseHighlight {
                Text(highlight)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(GQColors.textPrimary)
            }

            // Stats
            HStack(spacing: 8) {
                if let d = post.duration { statChipSmall(icon: "clock.fill", text: "\(d)m") }
                if let s = post.setCount { statChipSmall(icon: "list.bullet", text: "\(s) sets") }
                if post.likeCount > 0 { statChipSmall(icon: "hand.thumbsup.fill", text: "\(post.likeCount)") }
            }

            // CTA
            if post.authorId != profile.id {
                Button {
                    UseWorkoutService.use(post: post, currentUserId: profile.id, appState: appState, modelContext: modelContext)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("Use this workout")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(GQGradients.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(GQColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(GQColors.borderDefault, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 3)
    }

    // MARK: - 4. Squad Summary

    @ViewBuilder
    private var squadSummaryCard: some View {
        let mySquads = allSquads.filter { $0.memberIds.contains(profile.id) }
        if let squad = mySquads.first {
            let memberIds = Set(squad.memberIds.filter { $0 != profile.id })
            let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
            let squadWorkouts = workoutPosts.filter { memberIds.contains($0.authorId) && $0.timestamp >= weekStart }
            let sessionCount = squadWorkouts.count
            let topExercise = squadWorkouts.compactMap(\.exerciseHighlight).mostCommon() ?? "—"

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(GQColors.deepBlue)
                    Text(squad.name.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(GQColors.textTertiary)
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(sessionCount)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(GQColors.textPrimary)
                    Text(sessionCount == 1 ? "session this week" : "sessions this week")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(GQColors.textSecondary)
                }

                HStack(spacing: 4) {
                    Text("Top exercise:")
                        .font(.system(size: 11))
                        .foregroundColor(GQColors.textTertiary)
                    Text(topExercise)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(GQColors.textSecondary)
                }

                // Mini avatar row
                HStack(spacing: -6) {
                    ForEach(Array(memberIds.prefix(5)), id: \.self) { memberId in
                        if let member = allUserProfiles.first(where: { $0.id == memberId }) {
                            Circle()
                                .fill(AnyShapeStyle(GQGradients.primary))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Text(String(member.name.prefix(1)).uppercased())
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white)
                                )
                                .overlay(Circle().stroke(GQColors.cardBackground, lineWidth: 2))
                        }
                    }
                    if memberIds.count > 5 {
                        Circle()
                            .fill(GQColors.adaptiveOverlay(0.1))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Text("+\(memberIds.count - 5)")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(GQColors.textTertiary)
                            )
                            .overlay(Circle().stroke(GQColors.cardBackground, lineWidth: 2))
                    }
                }
            }
            .padding(14)
            .background(GQColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(GQColors.borderDefault, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 8, y: 3)
        }
    }

    // MARK: - 5. People Timeline

    @ViewBuilder
    private var peopleTimeline: some View {
        let recentFromFollowing = catalogFromFollowing.prefix(8)
        if !recentFromFollowing.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(GQColors.deepBlue)
                    Text("WHAT YOUR PEOPLE DID")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(GQColors.textTertiary)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)

                ForEach(Array(recentFromFollowing.enumerated()), id: \.element.id) { index, post in
                    PeopleTimelineRow(
                        post: post,
                        currentUserId: profile.id,
                        profile: profile
                    )

                    if index < recentFromFollowing.count - 1 {
                        Rectangle()
                            .fill(GQColors.borderSubtle)
                            .frame(height: 0.5)
                            .padding(.leading, 52)
                    }
                }
                .padding(.bottom, 8)
            }
            .background(GQColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(GQColors.borderDefault, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 8, y: 3)
        }
    }

    // MARK: - 6. Trending Bubbles

    @ViewBuilder
    private var trendingBubbles: some View {
        let trending = computeTrendingExercises()
        if !trending.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(GQColors.vividPurple)
                    Text("TRENDING IN YOUR CIRCLE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(GQColors.textTertiary)
                }
                .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(trending, id: \.name) { item in
                            HStack(spacing: 5) {
                                Text(item.name)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(GQColors.textPrimary)
                                Text("\(item.count) \(item.count == 1 ? "friend" : "friends")")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(GQColors.textTertiary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(GQColors.cardBackground)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(GQColors.borderDefault, lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private struct TrendingItem {
        let name: String
        let count: Int
    }

    private func computeTrendingExercises() -> [TrendingItem] {
        let weekAgo = Date().addingTimeInterval(-7 * 86400)
        let friendPosts = workoutPosts.filter {
            cachedFollowingIds.contains($0.authorId) && $0.timestamp > weekAgo
        }
        var exerciseCounts: [String: Set<UUID>] = [:]
        for post in friendPosts {
            if let highlight = post.exerciseHighlight {
                exerciseCounts[highlight, default: []].insert(post.authorId)
            }
        }
        return exerciseCounts
            .map { TrendingItem(name: $0.key, count: $0.value.count) }
            .filter { $0.count >= 1 }
            .sorted { $0.count > $1.count }
            .prefix(6)
            .map { $0 }
    }

    // MARK: - Helpers

    private func statChipSmall(icon: String, text: String) -> some View {
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

    // MARK: - 7. Visual Explore Grid
    //
    // Instagram Explore-style 3-column thumbnail grid, but each cell has
    // structured workout data overlaid and a "Use" action. The media layer
    // that makes browsing FUN — you look, not read.

    @State private var selectedGridFilter: String = "All"

    private let gridFilterOptions = ["All", "Push", "Pull", "Legs", "Cardio", "HIIT", "Full Body"]

    @ViewBuilder
    private var exploreVisualGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 6) {
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(GQColors.vividPurple)
                Text("EXPLORE WORKOUTS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(GQColors.textTertiary)
            }
            .padding(.horizontal, 16)

            // Filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(gridFilterOptions, id: \.self) { option in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedGridFilter = option
                            }
                        } label: {
                            Text(option)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(selectedGridFilter == option ? .white : GQColors.textSecondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(
                                    selectedGridFilter == option
                                        ? AnyShapeStyle(GQGradients.primary)
                                        : AnyShapeStyle(GQColors.cardBackground)
                                )
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(
                                        selectedGridFilter == option ? Color.clear : GQColors.borderDefault,
                                        lineWidth: 1
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }

            // Grid
            let filteredPosts = gridFilteredPosts
            if filteredPosts.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 28))
                        .foregroundColor(GQColors.textTertiary)
                    Text("No workouts yet")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(GQColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 3),
                        GridItem(.flexible(), spacing: 3),
                        GridItem(.flexible(), spacing: 3)
                    ],
                    spacing: 3
                ) {
                    ForEach(filteredPosts.prefix(30)) { post in
                        ExploreGridCell(
                            post: post,
                            currentUserId: profile.id,
                            profile: profile
                        )
                    }
                }
                .padding(.horizontal, 3)
            }
        }
    }

    private var gridFilteredPosts: [Post] {
        let base = workoutPosts.sorted { $0.timestamp > $1.timestamp }
        if selectedGridFilter == "All" { return base }
        return base.filter { $0.workoutType?.lowercased() == selectedGridFilter.lowercased() }
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

    /// Workouts from people the user follows — the social layer
    private var catalogFromFollowing: [Post] {
        workoutPosts
            .filter { cachedFollowingIds.contains($0.authorId) && $0.authorId != profile.id }
            .sorted { $0.timestamp > $1.timestamp }
    }

    /// Workouts from the user's squad members
    @Query private var allSquads: [Squad]

    private var catalogFromSquad: [Post] {
        let mySquadMemberIds: Set<UUID> = {
            var ids = Set<UUID>()
            for squad in allSquads where squad.memberIds.contains(profile.id) {
                for memberId in squad.memberIds where memberId != profile.id {
                    ids.insert(memberId)
                }
            }
            return ids
        }()
        return workoutPosts
            .filter { mySquadMemberIds.contains($0.authorId) }
            .sorted { ($0.likeCount + $0.commentCount) > ($1.likeCount + $1.commentCount) }
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
            title: "Nothing here yet",
            subtitle: "Log a workout or follow someone."
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

// MARK: - Explore Grid Cell
//
// Instagram Explore-style thumbnail cell with workout data overlay.
// Photo fills the cell as background; a gradient overlay at the bottom
// ensures text readability. Author name, workout type, and a "Use" pill
// are overlaid. Posts without photos get a variant-colored gradient
// placeholder with a large workout-type icon.

struct ExploreGridCell: View {
    let post: Post
    let currentUserId: UUID
    let profile: UserProfile

    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @State private var showDetail = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background: photo or gradient placeholder
            cellBackground
                .aspectRatio(0.82, contentMode: .fill)
                .clipped()

            // Bottom gradient for text readability
            LinearGradient(
                colors: [Color.black.opacity(0), Color.black.opacity(0.75)],
                startPoint: .center,
                endPoint: .bottom
            )

            // Overlay content
            VStack(alignment: .leading, spacing: 3) {
                Spacer()

                // Author + type
                HStack(spacing: 4) {
                    Circle()
                        .fill(AnyShapeStyle(GQGradients.primary))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Text(String(post.authorName.prefix(1)).uppercased())
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(.white)
                        )
                    Text(post.authorName)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                Text(post.exerciseHighlight ?? post.workoutType ?? "Workout")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)

                // Bottom row: stats + use
                HStack(spacing: 4) {
                    if let d = post.duration {
                        Text("\(d)m")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    if post.timesUsed > 0 {
                        HStack(spacing: 1) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 5))
                            Text("\(post.timesUsed)")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .foregroundStyle(GQColors.success)
                    }
                    Spacer()
                    if post.authorId != currentUserId {
                        Button {
                            UseWorkoutService.use(post: post, currentUserId: currentUserId, appState: appState, modelContext: modelContext)
                        } label: {
                            Text("Use")
                                .font(.system(size: 8, weight: .black))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(GQGradients.primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .contentShape(Rectangle())
        .onTapGesture { showDetail = true }
        .sheet(isPresented: $showDetail) {
            if let workout = post.getSharedWorkout() {
                WorkoutDetailSheet(
                    workoutData: workout,
                    onFollow: {
                        showDetail = false
                        UseWorkoutService.use(post: post, currentUserId: currentUserId, appState: appState, modelContext: modelContext)
                    },
                    onAddExercise: { _ in }
                )
            }
        }
    }

    @ViewBuilder
    private var cellBackground: some View {
        #if canImport(UIKit)
        if let photoData = post.photoData, let img = UIImage(data: photoData) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
        } else {
            gradientPlaceholder
        }
        #else
        gradientPlaceholder
        #endif
    }

    private var gradientPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [cellAccent.opacity(0.5), GQColors.deepBlue.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: cellIcon)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white.opacity(0.2))
        }
    }

    private var cellAccent: Color {
        switch post.workoutType?.lowercased() {
        case "push": return GQColors.deepBlue
        case "pull": return GQColors.vividPurple
        case "legs": return Color(red: 1.0, green: 0.55, blue: 0.2)
        case "cardio": return GQColors.success
        case "hiit": return Color.red
        default: return GQColors.vividPurple
        }
    }

    private var cellIcon: String {
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

// MARK: - People Timeline Row

struct PeopleTimelineRow: View {
    let post: Post
    let currentUserId: UUID
    let profile: UserProfile

    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext

    @State private var topComment: String? = nil

    private var hasPR: Bool {
        post.getProofCard()?.variant == "pr"
    }

    var body: some View {
        HStack(spacing: 10) {
            // Avatar with optional PR accent
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(AnyShapeStyle(GQGradients.primary))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(post.authorName.prefix(1)).uppercased())
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    )
                if hasPR {
                    Circle()
                        .fill(Color(red: 1.0, green: 0.78, blue: 0.2))
                        .frame(width: 10, height: 10)
                        .overlay(
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 5, weight: .black))
                                .foregroundStyle(.black)
                        )
                        .overlay(Circle().stroke(GQColors.cardBackground, lineWidth: 1.5))
                        .offset(x: 2, y: 2)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(post.authorName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(GQColors.textPrimary)
                    Text("·")
                        .foregroundColor(GQColors.textTertiary)
                    Text(post.workoutType ?? "Workout")
                        .font(.system(size: 12))
                        .foregroundColor(GQColors.textSecondary)
                    if let d = post.duration {
                        Text("· \(d)m")
                            .font(.system(size: 11))
                            .foregroundColor(GQColors.textTertiary)
                    }
                }

                if let comment = topComment {
                    Text("\"\(comment)\"")
                        .font(.system(size: 10))
                        .foregroundColor(GQColors.textTertiary)
                        .lineLimit(1)
                        .italic()
                } else if hasPR {
                    Text("NEW PR")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(Color(red: 1.0, green: 0.78, blue: 0.2))
                }
            }

            Spacer()

            // Use button
            if post.authorId != currentUserId {
                Button {
                    UseWorkoutService.use(post: post, currentUserId: currentUserId, appState: appState, modelContext: modelContext)
                } label: {
                    Text("Use")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(GQGradients.primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .task {
            let postId = post.id
            var descriptor = FetchDescriptor<Comment>(
                predicate: #Predicate { $0.postId == postId },
                sortBy: [SortDescriptor(\Comment.timestamp, order: .reverse)]
            )
            descriptor.fetchLimit = 1
            topComment = (try? modelContext.fetch(descriptor).first)?.content
        }
    }
}

// MARK: - Array Helper

extension Array where Element: Hashable {
    func mostCommon() -> Element? {
        var counts: [Element: Int] = [:]
        for item in self { counts[item, default: 0] += 1 }
        return counts.max(by: { $0.value < $1.value })?.key
    }
}

// MARK: - Workout Catalog Card

struct WorkoutCatalogCard: View {
    let post: Post
    let currentUserId: UUID
    let profile: UserProfile

    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext

    @State private var showDetail = false
    @State private var topComment: String? = nil
    @State private var topCommentAuthor: String? = nil

    private var workout: SharedWorkoutData? { post.getSharedWorkout() }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Author row — feel the person behind the workout
            HStack(spacing: 8) {
                Circle()
                    .fill(AnyShapeStyle(GQGradients.primary))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text(String(post.authorName.prefix(1)).uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: 0) {
                    Text(post.authorName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(GQColors.textPrimary)
                        .lineLimit(1)
                    Text(post.workoutType ?? "Workout")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(GQColors.textTertiary)
                }
                Spacer()
            }

            // Exercise highlight
            if let highlight = post.exerciseHighlight {
                Text(highlight)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(GQColors.textPrimary)
                    .lineLimit(1)
            }

            // Stats row
            HStack(spacing: 6) {
                if let d = post.duration {
                    statChip(icon: "clock.fill", text: "\(d)m")
                }
                if let s = post.setCount {
                    statChip(icon: "list.bullet", text: "\(s) sets")
                }
                if post.timesUsed > 0 {
                    statChip(icon: "play.fill", text: "\(post.timesUsed) used")
                }
            }

            // Social layer: top comment preview — feel the community
            if let comment = topComment, let author = topCommentAuthor {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 7))
                        .foregroundColor(GQColors.textTertiary)
                        .padding(.top, 3)
                    Text("\"\(comment)\" — \(author)")
                        .font(.system(size: 9))
                        .foregroundColor(GQColors.textSecondary)
                        .lineLimit(2)
                        .italic()
                }
                .padding(.top, 2)
            }

            // Reaction summary strip — social proof
            if post.likeCount > 0 || post.commentCount > 0 {
                HStack(spacing: 8) {
                    if post.likeCount > 0 {
                        HStack(spacing: 2) {
                            Text("💪")
                                .font(.system(size: 9))
                            Text("\(post.likeCount)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(GQColors.textTertiary)
                        }
                    }
                    if post.commentCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "bubble.left.fill")
                                .font(.system(size: 7))
                            Text("\(post.commentCount)")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(GQColors.textTertiary)
                    }
                    Spacer()
                }
                .padding(.top, 1)
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
        .frame(width: 185)
        .background(GQColors.surfaceBase)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(GQColors.borderDefault, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 6, y: 3)
        .onTapGesture { showDetail = true }
        .task { fetchTopComment() }
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

    private func fetchTopComment() {
        let postId = post.id
        var descriptor = FetchDescriptor<Comment>(
            predicate: #Predicate { $0.postId == postId },
            sortBy: [SortDescriptor(\Comment.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        if let comment = try? modelContext.fetch(descriptor).first {
            topComment = comment.content
            topCommentAuthor = comment.authorName
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
