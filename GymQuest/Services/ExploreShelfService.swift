import Foundation
import SwiftData

// MARK: - Shelf model

/// One curated row on the Explore page. The hero is also a shelf (with one post).
struct ExploreShelf: Identifiable {
    /// String id so multiple custom-named shelves can coexist with the same `kind`.
    let id: String
    let kind: ExploreShelfKind
    let title: String
    let rationale: String?       // e.g. "Because you trained Push yesterday"
    let intent: ExploreIntent
    let posts: [Post]

    init(
        id: String? = nil,
        kind: ExploreShelfKind,
        title: String,
        rationale: String?,
        intent: ExploreIntent,
        posts: [Post]
    ) {
        self.id = id ?? kind.rawValue
        self.kind = kind
        self.title = title
        self.rationale = rationale
        self.intent = intent
        self.posts = posts
    }
}

// MARK: - Context

/// Snapshot of everything the shelf service needs. Built once per render so
/// each shelf draws from the same view of the world.
struct ExploreContext {
    let profile: UserProfile
    let recentWorkouts: [Workout]    // sorted desc by date
    let allPosts: [Post]
    let saved: [SavedWorkout]
    /// User ids the current user follows. Powers "Squad is doing X" shelf.
    /// Empty array is fine — the shelf simply won't render.
    let followedUserIds: Set<UUID>
    let intent: ExploreIntent
    let now: Date

    init(
        profile: UserProfile,
        recentWorkouts: [Workout],
        allPosts: [Post],
        saved: [SavedWorkout],
        followedUserIds: Set<UUID> = [],
        intent: ExploreIntent,
        now: Date = Date()
    ) {
        self.profile = profile
        self.recentWorkouts = recentWorkouts
        self.allPosts = allPosts
        self.saved = saved
        self.followedUserIds = followedUserIds
        self.intent = intent
        self.now = now
    }

    /// Most-recent workout type the user trained, used for "Because you trained X" rationale.
    var lastWorkoutType: WorkoutType? { recentWorkouts.first?.type }
}

// MARK: - Service

@MainActor
final class ExploreShelfService {

    static let shared = ExploreShelfService()
    private init() {}

    // MARK: - Public

    /// Pick a single workout-y post for the Hero card. Prefers high doability,
    /// matches the user's preferred duration window, then breaks ties by
    /// recency. `excluding` lets callers skip recently-shown heroes when the
    /// user pulls to refresh — pass the last 1–3 hero ids.
    /// Returns nil if the corpus has nothing runnable.
    func heroPick(for ctx: ExploreContext, excluding: Set<UUID> = []) -> Post? {
        let pool = ctx.allPosts.filter { !excluding.contains($0.id) }
        let candidates = pool.filter { $0.doabilityScore >= 0.5 }
        guard !candidates.isEmpty else {
            // If everything runnable is excluded, fall back to the broader pool;
            // if that's also empty, allow excluded posts to come back.
            if let fallback = pool.sorted(by: { $0.timestamp > $1.timestamp }).first {
                return fallback
            }
            return ctx.allPosts.sorted { $0.timestamp > $1.timestamp }.first
        }
        let preferred = ctx.profile.preferredWorkoutDuration
        return candidates.max(by: { lhs, rhs in
            heroFitScore(lhs, preferredMinutes: preferred, now: ctx.now) <
            heroFitScore(rhs, preferredMinutes: preferred, now: ctx.now)
        })
    }

    /// Max shelves rendered below the hero. Keeps the page Apple-clean
    /// instead of overwhelming with 8+ identically-shaped rows.
    private static let maxShelves = 3

    /// Build the ordered list of shelves for the page. Priority-ranked and
    /// capped so the page never feels like a wall of cards.
    func shelves(for ctx: ExploreContext) -> [ExploreShelf] {
        let savedShelves: [ExploreShelf] = [
            savedToDoShelf(ctx),
            savedToWatchShelf(ctx)
        ].compactMap { $0 }

        let contentShelves: [ExploreShelf] = [
            calendarShelf(ctx),         // highest priority: user's own plan
            becauseYouTrainedShelf(ctx),
            squadIsDoingShelf(ctx),
            quickWinsShelf(ctx),
            editorsPickShelf(ctx),
            watchTutorialsShelf(ctx)
        ].compactMap { $0 }

        // Saved always lead; content shelves fill remaining slots up to max.
        let remaining = max(0, Self.maxShelves - savedShelves.count)
        return savedShelves + Array(contentShelves.prefix(remaining))
            + customCollectionShelves(ctx)
    }

    // MARK: - Hero scoring

    private func heroFitScore(_ post: Post, preferredMinutes: Int, now: Date) -> Double {
        var score = post.doabilityScore  // 0..1

        // Duration fit: full credit when within 25% of preferred minutes,
        // tapering linearly to zero at 2× off.
        if let dur = post.duration, dur > 0, preferredMinutes > 0 {
            let delta = abs(Double(dur - preferredMinutes)) / Double(preferredMinutes)
            score += max(0, 0.4 * (1 - min(delta / 1.0, 1)))
        }

        // Recency: 0.2 if posted in last 7 days, decaying to 0 at 60 days.
        let ageDays = now.timeIntervalSince(post.timestamp) / 86_400
        score += max(0, 0.2 * (1 - min(ageDays / 60, 1)))

        return score
    }

    // MARK: - Shelves

    private func becauseYouTrainedShelf(_ ctx: ExploreContext) -> ExploreShelf? {
        guard let lastWorkout = ctx.recentWorkouts.first else { return nil }
        let typeRaw = lastWorkout.type.rawValue
        let matching = ctx.allPosts
            .filter { $0.workoutType?.lowercased() == typeRaw.lowercased() }
            .filter { $0.authorId != ctx.profile.id }
            .sorted { $0.doabilityScore > $1.doabilityScore }
            .prefix(4)

        guard !matching.isEmpty else { return nil }

        let when = RelativeDateString.short(from: lastWorkout.date, to: ctx.now)
        return ExploreShelf(
            kind: .becauseYouTrained,
            title: "Because you trained \(typeRaw.capitalized) \(when)",
            rationale: "Similar sessions from the community",
            intent: .train,
            posts: Array(matching)
        )
    }

    private func quickWinsShelf(_ ctx: ExploreContext) -> ExploreShelf? {
        let cap = max(15, Int(Double(ctx.profile.preferredWorkoutDuration) * 0.6))
        let matching = ctx.allPosts
            .filter { ($0.duration ?? .max) <= cap && $0.doabilityScore >= 0.4 }
            .sorted { $0.doabilityScore > $1.doabilityScore }
            .prefix(4)

        guard !matching.isEmpty else { return nil }

        return ExploreShelf(
            kind: .quickWins,
            title: "Quick wins",
            rationale: "Under \(cap) minutes — fits a tight day",
            intent: .train,
            posts: Array(matching)
        )
    }

    private func watchTutorialsShelf(_ ctx: ExploreContext) -> ExploreShelf? {
        let videos = ctx.allPosts.filter { post in
            let hasVideo = post.videoData != nil ||
                post.mediaItems.contains(where: { $0.mediaType == .video })
            let isInstructional = post.exerciseHighlight != nil ||
                post.mediaItems.contains(where: { $0.exerciseIndex != nil })
            return hasVideo && isInstructional
        }
        .sorted { lhs, rhs in
            (lhs.likeCount + lhs.commentCount * 3) > (rhs.likeCount + rhs.commentCount * 3)
        }
        .prefix(4)

        guard !videos.isEmpty else { return nil }

        return ExploreShelf(
            kind: .watchTutorials,
            title: "Watch · Form & technique",
            rationale: "Short clips for the lifts you already do",
            intent: .watch,
            posts: Array(videos)
        )
    }

    private func savedToDoShelf(_ ctx: ExploreContext) -> ExploreShelf? {
        let trainSaves = ctx.saved.filter { $0.collection == .train }
        guard !trainSaves.isEmpty else { return nil }
        let postIds = Set(trainSaves.map(\.postId))
        let posts = ctx.allPosts.filter { postIds.contains($0.id) }
            .sorted { lhs, rhs in
                (savedAt(lhs, in: trainSaves) ?? .distantPast) >
                (savedAt(rhs, in: trainSaves) ?? .distantPast)
            }
        guard !posts.isEmpty else { return nil }
        let mostRecent = trainSaves.map(\.savedAt).max() ?? ctx.now
        let rationale = "Saved \(RelativeDateString.short(from: mostRecent, to: ctx.now)) · \(posts.count) workout\(posts.count == 1 ? "" : "s")"
        return ExploreShelf(
            kind: .savedToDo,
            title: "Your playlist",
            rationale: rationale,
            intent: .train,
            posts: posts
        )
    }

    private func savedToWatchShelf(_ ctx: ExploreContext) -> ExploreShelf? {
        let watchSaves = ctx.saved.filter { $0.collection == .watch }
        guard !watchSaves.isEmpty else { return nil }
        let postIds = Set(watchSaves.map(\.postId))
        let posts = ctx.allPosts.filter { postIds.contains($0.id) }
            .sorted { lhs, rhs in
                (savedAt(lhs, in: watchSaves) ?? .distantPast) >
                (savedAt(rhs, in: watchSaves) ?? .distantPast)
            }
        guard !posts.isEmpty else { return nil }
        let mostRecent = watchSaves.map(\.savedAt).max() ?? ctx.now
        let rationale = "\(posts.count) clip\(posts.count == 1 ? "" : "s") · added \(RelativeDateString.short(from: mostRecent, to: ctx.now))"
        return ExploreShelf(
            kind: .savedToWatch,
            title: "Watch later",
            rationale: rationale,
            intent: .watch,
            posts: posts
        )
    }

    private func savedAt(_ post: Post, in saves: [SavedWorkout]) -> Date? {
        saves.first(where: { $0.postId == post.id })?.savedAt
    }

    // MARK: - Phase 3 shelves

    /// "Today: Push day" or "Tomorrow is Pull day" — driven by the user's
    /// weekly schedule (with per-day overrides). Only renders when the user
    /// has actually configured a schedule for that day.
    private func calendarShelf(_ ctx: ExploreContext) -> ExploreShelf? {
        let cal = Calendar.current
        // Try today first, then tomorrow.
        let candidates: [(Date, String)] = [
            (ctx.now, "Today"),
            (cal.date(byAdding: .day, value: 1, to: ctx.now) ?? ctx.now, "Tomorrow")
        ]

        for (date, label) in candidates {
            guard let typeRaw = scheduledType(for: date, profile: ctx.profile, calendar: cal) else { continue }
            let matching = ctx.allPosts
                .filter { $0.workoutType?.lowercased() == typeRaw.lowercased() }
                .sorted { $0.doabilityScore > $1.doabilityScore }
                .prefix(4)
            guard !matching.isEmpty else { continue }
            return ExploreShelf(
                kind: .onTheCalendar,
                title: "\(label) is \(typeRaw.capitalized) day",
                rationale: "Picks lined up to your plan",
                intent: .train,
                posts: Array(matching)
            )
        }
        return nil
    }

    /// Aggregates posts from followed users in the last 7 days, finds the
    /// dominant workoutType, and surfaces matching posts. Anchors the user's
    /// next session in social proof.
    private func squadIsDoingShelf(_ ctx: ExploreContext) -> ExploreShelf? {
        guard !ctx.followedUserIds.isEmpty else { return nil }
        let weekAgo = ctx.now.addingTimeInterval(-7 * 86_400)
        let recentSquadPosts = ctx.allPosts.filter {
            ctx.followedUserIds.contains($0.authorId) && $0.timestamp >= weekAgo
        }
        guard recentSquadPosts.count >= 2 else { return nil }
        // Tally by workoutType (lowercased), pick the dominant one.
        var counts: [String: Int] = [:]
        for post in recentSquadPosts {
            guard let raw = post.workoutType?.lowercased(), !raw.isEmpty else { continue }
            counts[raw, default: 0] += 1
        }
        guard let (dominant, _) = counts.max(by: { $0.value < $1.value }) else { return nil }
        let posts = recentSquadPosts
            .filter { $0.workoutType?.lowercased() == dominant }
            .sorted { $0.doabilityScore > $1.doabilityScore }
            .prefix(4)
        guard !posts.isEmpty else { return nil }
        return ExploreShelf(
            kind: .squadIsDoing,
            title: "Your squad is doing \(dominant.capitalized) this week",
            rationale: "\(posts.count) session\(posts.count == 1 ? "" : "s") from people you follow",
            intent: .train,
            posts: Array(posts)
        )
    }

    /// Lighter version of editorial curation: combines the top quartile of
    /// engagement with the top quartile of doability. Stand-in until human
    /// curation exists.
    private func editorsPickShelf(_ ctx: ExploreContext) -> ExploreShelf? {
        let pool = ctx.allPosts.filter { $0.doabilityScore >= 0.4 }
        guard pool.count >= 3 else { return nil }
        // Engagement = likes + 3*comments (matches FeedRankingService weighting).
        let scored = pool.map { post -> (Post, Double) in
            let engagement = Double(post.likeCount + post.commentCount * 3)
            return (post, engagement * post.doabilityScore)
        }
        let top = scored.sorted { $0.1 > $1.1 }.prefix(8).map(\.0)
        guard !top.isEmpty else { return nil }
        return ExploreShelf(
            kind: .editorsPick,
            title: "Editor's picks",
            rationale: "High quality + ready to follow",
            intent: .train,
            posts: top
        )
    }

    private func scheduledType(for date: Date, profile: UserProfile, calendar: Calendar) -> String? {
        // Per-day overrides win over the weekly template.
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let key = formatter.string(from: date)
        if let override = profile.dayOverrides[key], !override.isEmpty { return override }

        let weekday = calendar.component(.weekday, from: date)
        let scheduled = profile.weeklySchedule[weekday]
        return (scheduled?.isEmpty == false) ? scheduled : nil
    }

    // MARK: - Custom collections

    /// One shelf per user-named custom collection. Train intent so they
    /// surface in the do-mode order; the user can long-press to recategorize.
    private func customCollectionShelves(_ ctx: ExploreContext) -> [ExploreShelf] {
        let customSaves = ctx.saved.filter { $0.collection == .custom && $0.customCollectionName != nil }
        let names = Set(customSaves.compactMap { $0.customCollectionName }).sorted()
        return names.compactMap { name in
            let saves = customSaves.filter { $0.customCollectionName == name }
            let postIds = Set(saves.map(\.postId))
            let posts = ctx.allPosts.filter { postIds.contains($0.id) }
                .sorted { lhs, rhs in
                    (savedAt(lhs, in: saves) ?? .distantPast) >
                    (savedAt(rhs, in: saves) ?? .distantPast)
                }
            guard !posts.isEmpty else { return nil }
            return ExploreShelf(
                id: "custom-\(name)",
                kind: .savedToDo,         // shape is the same as a Saved shelf; title carries the user-given name
                title: name,
                rationale: "\(posts.count) saved",
                intent: .train,
                posts: posts
            )
        }
    }
}
