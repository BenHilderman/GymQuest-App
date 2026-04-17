import SwiftUI
import SwiftData

/// New Explore page (Phase 1).
///
/// Layout:
///   1. Sticky intent toggle (Train · Watch)
///   2. Smart search bar
///   3. Hero "Tonight's pick"
///   4. N shelves from ExploreShelfService, ordered by current intent
///
/// Hosted inside FeedView's `.discover` tab — does not change the tab bar.
struct ExploreView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState

    let profile: UserProfile

    @Query(sort: \Post.timestamp, order: .reverse) private var allPosts: [Post]
    @Query(sort: \Workout.date, order: .reverse) private var recentWorkouts: [Workout]
    @Query private var saved: [SavedWorkout]
    @Query private var follows: [Friend]
    @Query private var allUserProfiles: [UserProfile]
    @Query private var presenceStates: [UserPresenceState]
    @Query private var clubs: [Club]
    @Query private var checkIns: [WorkoutCheckIn]

    @StateObject private var intentService = IntentInferenceService.shared

    @State private var query: String = ""
    @State private var bodyPart: String?
    @State private var durationCap: Int?
    @State private var equipment: String?

    @State private var sheetPostForFollow: Post?
    @State private var sheetPostForDetail: Post?
    @State private var sheetPostForCollection: Post?

    // MARK: - Cached feed data (computed once in .task, not per-render)
    @State private var cachedCrewMembers: [CrewMember] = []
    @State private var cachedDiscoverItems: [DiscoverFeedItem] = []
    @State private var cachedHeroPick: Post?
    @State private var cachedShortsClips: [Post] = []
    @State private var cachedFeedLoaded: Bool = false

    /// Shorts entry: when set, the full-screen ScrollFeedView is presented
    /// starting at this post id. Tap any preview in the Shorts shelf or the
    /// top-bar Shorts pill to enter.
    @State private var shortsEntryPostId: UUID?
    @State private var presentingShorts: Bool = false
    @State private var presentingSaves: Bool = false
    @State private var presentingFriendsFeed: Bool = false
    @State private var showSearchOverlay: Bool = false
    @State private var discoverFilter: String = "For You"
    @State private var visibleVideoId: String?
    @State private var livePulse: Bool = false
    @State private var presentedClub: Club?

    /// Nudge IDs the user dismissed this session — suppressed from the
    /// banner. Day-keyed so "crewAhead-2-Jake" doesn't nag every open.
    @State private var dismissedNudgeIds: Set<String> = []

    /// Last 3 hero ids to skip on refresh — keeps the hero feeling fresh
    /// without ever showing the same pick twice in a row.
    @State private var heroSkipIds: [UUID] = []

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                // ── 1. Top bar (reads from cache, not computed per-render) ──
                topSection

                if showSearchOverlay {
                    SmartSearchBar(query: $query, bodyPart: $bodyPart, durationCap: $durationCap, equipment: $equipment, showsChips: isSearching).padding(.horizontal, 16).transition(.opacity.combined(with: .move(edge: .top)))
                }

                if let topNudge = activeNudges.first {
                    CommunityNudgeBanner(nudge: topNudge, onAction: { handleNudgeAction(topNudge) }, onDismiss: { dismissedNudgeIds.insert(topNudge.id) }).padding(.horizontal, 16)
                }

                // ── 4. Hero (the action CTA — above the fold) ─
                if isSearching {
                    searchResults
                } else if allPosts.isEmpty {
                    emptyExploreState
                } else {
                    if let hero = cachedHeroPick {
                        ExploreHeroCard(
                            post: hero,
                            rationale: heroRationale(for: hero),
                            isSaved: isSaved(hero, in: .train),
                            onStart: { startWorkout(from: hero) },
                            onPreview: { sheetPostForDetail = hero },
                            onToggleSave: { toggleSave(hero, collection: .train) },
                            onShuffle: { shuffleHero(currentId: hero.id); rebuildFeedCache() },
                            onLongPressSave: { sheetPostForCollection = hero }
                        )
                        .padding(.horizontal, 16)
                    }

                    // ── 5. Unified discover feed ────────────────
                    // Replaces: Shorts shelf + Next Session + Discover card.
                    // One algorithmically-ranked mixed feed of videos, photos,
                    // and workout suggestions.
                    discoverSection

                    // ── 8. Clubs (lower priority — below shelves) ──
                    if !myClubs.isEmpty {
                        ClubsShelf(
                            clubs: myClubs,
                            trainingThisWeekByClub: clubTrainingCounts,
                            onTap: { club in presentedClub = club }
                        )
                    }

                    // Search is in the top overlay (magnifying glass icon)
                }
            }
            .padding(.bottom, 100)
        }
        .scrollContentBackground(.hidden)
        .gqPageBackground()
        .refreshable {
            if let current = cachedHeroPick { shuffleHero(currentId: current.id) }
            PresenceSeeder.refreshDemoPresence(in: modelContext)
            rebuildFeedCache()
        }
        .task {
            if !cachedFeedLoaded {
                PresenceSeeder.refreshDemoPresence(in: modelContext)
                rebuildFeedCache()
                cachedFeedLoaded = true
            }
        }
        .onAppear {
            scheduleNotificationsForLiveState()
        }
        .sheet(item: $sheetPostForFollow) { post in
            if let data = post.sharedWorkoutData,
               let shared = try? JSONDecoder().decode(SharedWorkoutData.self, from: data) {
                FollowWorkoutView(workoutData: shared, profile: profile)
            }
        }
        .fullScreenCover(item: $sheetPostForDetail) { post in
            PostDetailView(post: post, profile: profile)
        }
        .sheet(item: $sheetPostForCollection) { post in
            CollectionPickerSheet(post: post, userId: profile.id)
                .presentationDetents([.medium, .large])
        }
        .fullScreenCover(isPresented: $presentingShorts) {
            ScrollFeedView(profile: profile, initialPostId: shortsEntryPostId)
        }
        .navigationDestination(isPresented: $presentingFriendsFeed) {
            FriendsFeedView(profile: profile)
        }
        .fullScreenCover(isPresented: $presentingSaves) {
            MySavesView(profile: profile)
        }
        .navigationDestination(item: $presentedClub) { _ in
            ClubFeedView(profile: profile)
        }
    }

    /// Bookmark icon next to the Shorts pill. Only renders when the user has
    /// at least one saved item — avoids the clutter of an orphan button.
    private var savesButton: some View {
        Button {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
            presentingSaves = true
        } label: {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(GQColors.accent)
                .frame(width: 36, height: 36)
                .background(Circle().fill(GQColors.surfaceSecondary))
                .overlay(Circle().stroke(GQColors.borderDefault.opacity(0.5), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private var hasAnySave: Bool {
        saved.contains { $0.userId == profile.id }
    }

    /// Unified crew row data: merges live presence + recent posts + inactive
    /// friends into one flat list of CrewMembers, sorted by status priority.
    private var crewMembers: [CrewMember] {
        let followedIds = Set(follows.filter { $0.userId == profile.id }.map(\.odId))
        guard !followedIds.isEmpty else { return [] }

        let liveIds = Set(liveNowStates.map(\.userId))
        let weekAgo = Date().addingTimeInterval(-7 * 86_400)
        let inactiveThreshold = Date().addingTimeInterval(-3 * 86_400)

        // Last post per friend
        var latestPost: [UUID: Post] = [:]
        for post in allPosts where followedIds.contains(post.authorId) {
            if let existing = latestPost[post.authorId], existing.timestamp >= post.timestamp { continue }
            latestPost[post.authorId] = post
        }

        return followedIds.compactMap { friendId -> CrewMember? in
            let profile = profilesById[friendId]
            let follow = follows.first(where: { $0.odId == friendId })
            let name = profile?.name ?? follow?.odName ?? "Friend"
            let username = profile?.username ?? follow?.odUsername ?? ""
            let avatarData = profile?.profilePhotoData

            if liveIds.contains(friendId) {
                let state = liveNowStates.first(where: { $0.userId == friendId })
                let type = state?.workoutTypeRaw?.capitalized ?? "Training"
                let mins = state?.minutesIn ?? 0
                return CrewMember(
                    id: friendId, name: name, username: username, avatarData: avatarData,
                    status: .live(workoutType: state?.workoutTypeRaw),
                    statusText: "\(type) · \(mins)m"
                )
            }

            if let post = latestPost[friendId], post.timestamp >= weekAgo {
                let warm = RelativeDateString.warm(from: post.timestamp)
                return CrewMember(
                    id: friendId, name: name, username: username, avatarData: avatarData,
                    status: .recent,
                    statusText: warm
                )
            }

            let lastDate = latestPost[friendId]?.timestamp
            if lastDate == nil || lastDate! < inactiveThreshold {
                let text = lastDate.map { RelativeDateString.warm(from: $0) } ?? "no posts"
                return CrewMember(
                    id: friendId, name: name, username: username, avatarData: avatarData,
                    status: .inactive,
                    statusText: text
                )
            }

            return nil
        }
        .sorted { lhs, rhs in
            statusPriority(lhs.status) < statusPriority(rhs.status)
        }
    }

    private func statusPriority(_ status: CrewMember.Status) -> Int {
        switch status {
        case .live: return 0
        case .recent: return 1
        case .inactive: return 2
        }
    }

    /// Friend feed items: recent friend posts + inactive nudges.
    private var friendFeedItems: [FriendFeedItem] {
        FriendActivityService.build(
            selfId: profile.id,
            allPosts: allPosts,
            checkIns: checkIns,
            follows: follows,
            profileLookup: profilesById
        ).items
    }

    /// Quick-react 💪 on a friend's post.
    private func quickReactToFriend(_ post: Post) {
        let reaction = Reaction(
            odId: profile.id,
            odUsername: profile.username,
            targetType: "post",
            targetId: post.id,
            reactionType: .strong
        )
        modelContext.insert(reaction)
        try? modelContext.save()
    }

    /// Send a motivational nudge to a friend who's been inactive.
    private func sendNudgeToInactive(_ userId: UUID) {
        let reaction = Reaction(
            odId: profile.id,
            odUsername: profile.username,
            targetType: "user",
            targetId: userId,
            reactionType: .strong
        )
        modelContext.insert(reaction)
        try? modelContext.save()

        let name = profilesById[userId]?.name ?? "A friend"
        CommunityNotificationService.shared.notifyFriendStartedTraining(
            friendName: "You",
            workoutType: "nudge from \(profile.name)",
            eventId: "nudge-\(userId)-\(Calendar.current.startOfDay(for: Date()))"
        )
        _ = name
    }

    /// Presence records for followed users + self who are currently training.
    /// Drives the LiveNowStrip above the Stories rail.
    private var liveNowStates: [UserPresenceState] {
        let followedIds = Set(follows.filter { $0.userId == profile.id }.map(\.odId))
        return PresenceService.liveNow(
            from: presenceStates,
            selfId: profile.id,
            followedIds: followedIds
        )
    }

    /// Profile lookup table for the LiveNowStrip to render names/avatars
    /// without spraying queries across subviews.
    private var profilesById: [UUID: UserProfile] {
        Dictionary(uniqueKeysWithValues: allUserProfiles.map { ($0.id, $0) })
    }

    /// Clubs the current user belongs to, sorted by most-recent activity.
    private var myClubs: [Club] {
        clubs.filter { $0.memberIds.contains(profile.id) }
            .sorted { ($0.lastActivityDate ?? .distantPast) > ($1.lastActivityDate ?? .distantPast) }
    }

    /// Count of club members who trained this week per club (via recent
    /// workouts or posts from those members). Drives the "X training this
    /// week" label on each club card.
    private var clubTrainingCounts: [UUID: Int] {
        let weekAgo = Date().addingTimeInterval(-7 * 86_400)
        var counts: [UUID: Int] = [:]
        for club in myClubs {
            let trainedMembers: Set<UUID> = Set(
                allPosts
                    .filter { $0.timestamp >= weekAgo }
                    .filter { club.memberIds.contains($0.authorId) }
                    .map(\.authorId)
            )
            counts[club.id] = trainedMembers.count
        }
        return counts
    }

    /// Current crew rhythm snapshot — drives the nudge engine and, on the
    /// Today page, the CrewRhythmCard.
    private var crewRhythm: CrewRhythm {
        let friendPosts = allPosts.filter { $0.authorId != profile.id }
        return CrewRhythmService.weekRhythm(
            selfId: profile.id,
            myWorkouts: recentWorkouts,
            friendPosts: friendPosts,
            follows: follows,
            profileLookup: profilesById
        )
    }

    /// Ordered nudges after rules + dismissal filter.
    private var activeNudges: [CommunityNudge] {
        let followedIds = Set(follows.filter { $0.userId == profile.id }.map(\.odId))
        let finished = PresenceService.justFinished(
            from: presenceStates,
            followedIds: followedIds
        )
        return CommunityNudgeService.nudges(
            rhythm: crewRhythm,
            justFinishedStates: finished,
            profileLookup: profilesById,
            dismissedIds: dismissedNudgeIds
        )
    }

    /// Routes the banner's action button — depends on nudge type.
    private func handleNudgeAction(_ nudge: CommunityNudge) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        switch nudge {
        case .justFinished(_, _, let userId):
            // Send a 💪 to the friend who just finished.
            let reaction = Reaction(
                odId: profile.id,
                odUsername: profile.username,
                targetType: "user",
                targetId: userId,
                reactionType: .strong
            )
            modelContext.insert(reaction)
            try? modelContext.save()
            dismissedNudgeIds.insert(nudge.id)
        case .crewAhead:
            // Jump the user into a workout — kicks off the flow.
            appState.showingLogWorkout = true
            dismissedNudgeIds.insert(nudge.id)
        case .duoDay, .friendOnStreak:
            // Lightweight cheer — dismiss after.
            dismissedNudgeIds.insert(nudge.id)
        }
    }

    /// Fires local notifications for crew events visible on this render:
    /// friends currently training, duo-day celebrations, rhythm milestones.
    /// Deduped per session by CommunityNotificationService.
    private func scheduleNotificationsForLiveState() {
        let notifier = CommunityNotificationService.shared
        notifier.requestAuthorizationIfNeeded()

        for state in liveNowStates where state.userId != profile.id {
            let name = profilesById[state.userId]?.name ?? "A friend"
            notifier.notifyFriendStartedTraining(
                friendName: name,
                workoutType: state.workoutTypeRaw,
                eventId: "started-\(state.userId)-\(Calendar.current.startOfDay(for: Date()))"
            )
        }

        let rhythm = crewRhythm
        if rhythm.daysTrainedByCrew >= 5 {
            notifier.notifyCrewMilestone(
                crewDays: rhythm.daysTrainedByCrew,
                totalDays: rhythm.totalDaysTracked,
                eventId: "crewMilestone-\(rhythm.daysTrainedByCrew)-\(Calendar.current.startOfDay(for: Date()))"
            )
        }

        if let companion = rhythm.todayCompanions.first {
            notifier.notifyDuoDay(
                friendName: companion.name,
                eventId: "duoDay-\(companion.username)-\(Calendar.current.startOfDay(for: Date()))"
            )
        }
    }

    /// "Send a 💪" tap on a live avatar — creates a lightweight Reaction
    /// targeting the other user so they feel the support instantly.
    private func sendSupport(to state: UserPresenceState) {
        guard state.userId != profile.id else { return }
        let reaction = Reaction(
            odId: profile.id,
            odUsername: profile.username,
            targetType: "user",
            targetId: state.userId,
            reactionType: .strong   // "Respect" — the gym-native 💪 in the catalogue
        )
        modelContext.insert(reaction)
        try? modelContext.save()
    }

    /// Stories: followed users (plus self) who have posted in the last 7
    /// days, sorted by recency. Tap → opens Shorts at that user's most
    /// recent clip.
    private var storyItems: [StoryItem] {
        let weekAgo = Date().addingTimeInterval(-7 * 86_400)
        let followedIds = Set(follows.filter { $0.userId == profile.id }.map(\.odId))
        let interestedIds = followedIds.union([profile.id])

        // Group recent posts by author, keep only authors of interest, take
        // the newest post per author.
        var newestByAuthor: [UUID: Post] = [:]
        for post in allPosts where post.timestamp >= weekAgo && interestedIds.contains(post.authorId) {
            if let existing = newestByAuthor[post.authorId], existing.timestamp >= post.timestamp { continue }
            newestByAuthor[post.authorId] = post
        }

        // Map to StoryItems, putting Self first.
        let items: [StoryItem] = newestByAuthor.values
            .sorted { $0.timestamp > $1.timestamp }
            .map { post -> StoryItem in
                let author = allUserProfiles.first(where: { $0.id == post.authorId })
                return StoryItem(
                    id: post.authorId,
                    displayName: author?.name ?? post.authorName,
                    username: author?.username ?? post.authorUsername,
                    avatarData: author?.profilePhotoData,
                    mostRecentPostId: post.id,
                    isSelf: post.authorId == profile.id
                )
            }
        // Pin self to the front when present.
        let pinnedSelf = items.first(where: { $0.isSelf })
        let others = items.filter { !$0.isSelf }
        return [pinnedSelf].compactMap { $0 } + others
    }

    /// Posts eligible for the Shorts experience: must have video media of a
    /// non-trivial length (the same 1KB guard ScrollFeedClip uses).
    private var shortsClips: [Post] {
        allPosts.filter { post in
            if let v = post.videoData, v.count >= 1024 { return true }
            if post.mediaItems.contains(where: { ($0.data?.count ?? 0) >= 1024 && $0.mediaType == .video }) {
                return true
            }
            return false
        }
    }

    /// Outlined nav button matching Today's secondary button style:
    /// surface fill + border + primary-color text. Reads unmistakably
    /// as tappable because it matches the established card language.
    private func navButton(icon: String, label: String?, action: @escaping () -> Void) -> some View {
        Button {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            action()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                if let label {
                    Text(label)
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .foregroundColor(GQColors.textPrimary)
            .padding(.horizontal, label != nil ? 14 : 10)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(GQColors.surfaceBase)
            )
            .overlay(
                Capsule().stroke(GQColors.borderDefault, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Intent toggle

    // Intent toggle removed — Train is always the default. Shorts pill is
    // the only secondary mode entry. Keeps the top bar clean.

    // MARK: - Derived state

    /// Always Train — the app's front-door intent.
    private var currentIntent: ExploreIntent { .train }

    /// Computes all expensive derived data ONCE and stores in @State.
    /// Called from .task (first load) and .refreshable (pull to refresh).
    /// This is the key perf fix — without it, 13 computed properties
    /// iterate all posts on every SwiftUI render pass.
    private func rebuildFeedCache() {
        cachedCrewMembers = crewMembers
        cachedHeroPick = heroPick
        cachedShortsClips = shortsClips
        cachedDiscoverItems = discoverGridItems
    }

    // MARK: - Top Section (Option 1: Today-style nav + spaced crew)

    private var topSection: some View {
        VStack(spacing: 8) {
            // Nav row: Today-style text links
            HStack(spacing: 20) {
                Spacer()
                Button("Friends", action: { presentingFriendsFeed = true })
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(GQGradients.primary)
                Button("Shorts", action: { shortsEntryPostId = shortsClips.first?.id; presentingShorts = true })
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(GQColors.textTertiary)
                Button("Clubs", action: { presentedClub = myClubs.first })
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(GQColors.textTertiary)
                Button(action: { withAnimation { showSearchOverlay.toggle() } }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(GQColors.textPrimary)
                }
                Spacer()
            }
            .buttonStyle(.plain)

            Divider().overlay(GQColors.adaptiveOverlay(0.04))

            // Crew row: properly spaced, no clipping, pulsing green dots
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(cachedCrewMembers.prefix(6)) { member in
                        Button {
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                            openFriendPost(member)
                        } label: {
                            topCrewCell(member)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)  // prevents circle stroke clipping
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .onAppear { livePulse = true }
    }

    private func topCrewCell(_ member: CrewMember) -> some View {
        VStack(spacing: 3) {
            ZStack {
                // Ring (green = live, purple = recent, gray = inactive)
                Circle()
                    .stroke(crewDotColor(member), lineWidth: 2)
                    .frame(width: 38, height: 38)

                // Avatar
                Circle()
                    .fill(GQGradients.primary)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Text(String(member.name.prefix(1)).uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    )

                // Pulsing green dot for live members
                if case .live = member.status {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(GQColors.background, lineWidth: 1.5))
                        .scaleEffect(livePulse ? 1.3 : 1.0)
                        .opacity(livePulse ? 0.6 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                            value: livePulse
                        )
                        .frame(width: 38, height: 38, alignment: .bottomTrailing)
                }
            }

            // Name
            Text(crewFirstName(member))
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(GQColors.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: 46)

            // Workout type + time
            Text(member.statusText)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
                .lineLimit(1)
                .frame(maxWidth: 46)
        }
    }

    private func crewDotColor(_ member: CrewMember) -> Color {
        switch member.status {
        case .live: return .green
        case .recent: return .purple
        case .inactive: return .gray.opacity(0.25)
        }
    }

    /// Tap a crew member → opens the full Friends feed so the user
    /// can scroll through all friends' posts comfortably.
    private func openFriendPost(_ member: CrewMember) {
        presentingFriendsFeed = true
    }

    // MARK: - Legacy (unused, kept for reference)

    /// One card: gradient bar + nav buttons + divider + crew with names/status.
    /// Matches the hero card's gradient-bar language.
    private var topCard: some View {
        VStack(spacing: 0) {
            // Gradient accent bar (from option 20, matching hero)
            RoundedRectangle(cornerRadius: 2)
                .fill(GQGradients.primary)
                .frame(height: 4)

            VStack(spacing: 10) {
                // Nav row (from option 2: inside the card)
                HStack(spacing: 8) {
                    navButton(icon: "person.2.fill", label: "Friends") {
                        presentingFriendsFeed = true
                    }
                    navButton(icon: "play.rectangle.fill", label: "Shorts") {
                        shortsEntryPostId = shortsClips.first?.id
                        presentingShorts = true
                    }
                    Spacer()
                    navButton(icon: "magnifyingglass", label: nil) {
                        withAnimation { showSearchOverlay.toggle() }
                    }
                    if hasAnySave { savesButton }
                }

                Divider().overlay(GQColors.adaptiveOverlay(0.04))

                // Crew row with names + status (from option 15)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(cachedCrewMembers.prefix(6)) { member in
                            Button { presentingFriendsFeed = true } label: {
                                VStack(spacing: 3) {
                                    crewAvatar(member, size: 38)
                                    Text(crewFirstName(member))
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(GQColors.textPrimary)
                                        .lineLimit(1)
                                        .frame(maxWidth: 44)
                                    Text(member.statusText)
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundColor(GQColors.textTertiary)
                                        .lineLimit(1)
                                        .frame(maxWidth: 44)
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        // Start workout cell
                        Button { appState.showingLogWorkout = true } label: {
                            VStack(spacing: 3) {
                                ZStack {
                                    Circle()
                                        .stroke(GQColors.borderDefault, lineWidth: 1.5)
                                        .frame(width: 38, height: 38)
                                    Image(systemName: "plus")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(GQGradients.primary)
                                }
                                Text("Start")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(GQColors.textSecondary)
                                Text("workout")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(GQColors.textTertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Live count if anyone's training
                if liveNowStates.count > 0 {
                    HStack(spacing: 4) {
                        Circle().fill(GQColors.success).frame(width: 6, height: 6)
                        Text("\(liveNowStates.count) training now")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(GQColors.success)
                        Spacer()
                    }
                }
            }
            .padding(12)
        }
        .background(GQColors.cardBackground)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(GQColors.borderDefault, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .gqShadow(.card)
    }

    private func crewAvatar(_ member: CrewMember, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(crewRingStyle(member), lineWidth: 2)
                .frame(width: size, height: size)
            Circle()
                .fill(GQGradients.primary)
                .frame(width: size - 8, height: size - 8)
                .overlay(
                    Text(String(member.name.prefix(1)).uppercased())
                        .font(.system(size: size * 0.28, weight: .bold))
                        .foregroundColor(.white)
                )
        }
    }

    private func crewRingStyle(_ member: CrewMember) -> some ShapeStyle {
        switch member.status {
        case .live: return AnyShapeStyle(GQColors.success)
        case .recent: return AnyShapeStyle(GQGradients.primary)
        case .inactive: return AnyShapeStyle(GQColors.adaptiveOverlay(0.12))
        }
    }

    private func crewFirstName(_ member: CrewMember) -> String {
        member.name.split(separator: " ").first.map(String.init) ?? member.name
    }

    /// Smart recommendation: what should the user train NEXT?
    private var nextRecommendation: NextWorkoutRecommendation {
        NextWorkoutService.recommend(
            profile: profile,
            recentWorkouts: recentWorkouts
        )
    }

    // MARK: - Unified Discover Feed

    private var discoverGridItems: [DiscoverFeedItem] {
        let followedIds = Set(follows.filter { $0.userId == profile.id }.map(\.odId))

        // "Following" chip: filter to just friends before building
        var postsPool = allPosts
        if discoverFilter == "Following" {
            postsPool = allPosts.filter { followedIds.contains($0.authorId) || $0.authorId == profile.id }
        }

        let ctx = DiscoverFeedBuilder.Context(
            allPosts: postsPool,
            profile: profile,
            recentWorkouts: recentWorkouts,
            followedIds: followedIds,
            watchDwell: WatchTimeTracker.shared.dwellByPost,
            nextRecommendation: nextRecommendation
        )

        let filter: String? = {
            switch discoverFilter {
            case "For You", "Following": return nil
            case "Videos": return "Video"
            default: return discoverFilter
            }
        }()

        return DiscoverFeedBuilder.build(from: ctx, typeFilter: filter)
    }

    private let discoverChips = ["For You", "Following", "Push", "Pull", "Legs", "Cardio", "Videos"]

    @ViewBuilder
    private var discoverSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(GQGradients.primary)
                Text("Discover")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)

            // Chip filters (exact ProgressView pattern)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(discoverChips, id: \.self) { chip in
                        let isSelected = discoverFilter == chip
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { discoverFilter = chip; cachedDiscoverItems = discoverGridItems }
                        } label: {
                            Text(chip)
                                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                                .foregroundColor(isSelected ? .white : GQColors.textSecondary)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(
                                    isSelected
                                        ? AnyShapeStyle(GQGradients.primary)
                                        : AnyShapeStyle(GQColors.adaptiveOverlay(0.05))
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }

        // IG Explore-style grid (reads from cache)
        DiscoverGrid(
            items: cachedDiscoverItems,
            onTapVideo: { post in
                shortsEntryPostId = post.id
                presentingShorts = true
            },
            onTapPhoto: { post in
                sheetPostForDetail = post
            },
            onStartWorkout: { post in
                startWorkout(from: post)
            }
        )
        .frame(minHeight: 600)
    }

    private func suggestionTitle(_ post: Post) -> String {
        if let data = post.sharedWorkoutData,
           let shared = try? JSONDecoder().decode(SharedWorkoutData.self, from: data),
           !shared.title.isEmpty { return shared.title }
        return post.exerciseHighlight ?? post.workoutType?.capitalized ?? "Workout"
    }

    private func suggestionSub(_ post: Post) -> String {
        var parts: [String] = []
        if let dur = post.duration, dur > 0 { parts.append("\(dur) min") }
        if let type = post.workoutType { parts.append(type.capitalized) }
        return parts.isEmpty ? nil ?? "" : parts.joined(separator: " · ")
    }

    private var context: ExploreContext {
        let followedIds = Set(follows.filter { $0.userId == profile.id }.map(\.odId))
        return ExploreContext(
            profile: profile,
            recentWorkouts: recentWorkouts,
            allPosts: allPosts,
            saved: saved.filter { $0.userId == profile.id },
            followedUserIds: followedIds,
            intent: currentIntent
        )
    }

    private var heroPick: Post? {
        ExploreShelfService.shared.heroPick(for: context, excluding: Set(heroSkipIds))
    }

    /// Push the current hero into the skip ring (max 3) and recompute. The
    /// view re-renders because heroSkipIds is @State and heroPick reads it.
    private func shuffleHero(currentId: UUID) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        var next = heroSkipIds
        next.append(currentId)
        if next.count > 3 { next.removeFirst(next.count - 3) }
        heroSkipIds = next
    }

    private var currentShelves: [ExploreShelf] {
        ExploreShelfService.shared.shelves(for: context)
    }

    /// One short, qualitative reason — never duplicates the meta chips
    /// (duration / exercise count / type), since those render below.
    /// Examples: "Picks up where your Push session left off",
    ///           "Fits your usual length", "Loved by your squad".
    private func heroRationale(for post: Post) -> String {
        let preferred = profile.preferredWorkoutDuration

        // Strongest signal: continuation from the most recent training session.
        if let lastWorkout = recentWorkouts.first,
           post.workoutType?.lowercased() == lastWorkout.type.rawValue.lowercased() {
            let when = RelativeDateString.short(from: lastWorkout.date)
            return "Picks up where your \(when) \(lastWorkout.type.rawValue.lowercased()) day left off"
        }

        // Duration-fit signal.
        if preferred > 0,
           let dur = post.duration, dur > 0,
           abs(dur - preferred) <= max(5, preferred / 5) {
            return "Fits your usual length"
        }

        // Runnable structure as fallback.
        if post.sharedWorkoutData != nil {
            return "Ready to follow set-by-set"
        }

        return "Picked for you"
    }

    // MARK: - Search

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty ||
        bodyPart != nil || durationCap != nil || equipment != nil
    }

    @ViewBuilder
    private var searchResults: some View {
        let results = filteredPosts
        VStack(alignment: .leading, spacing: 12) {
            Text("\(results.count) result\(results.count == 1 ? "" : "s")")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(GQColors.textSecondary)
                .padding(.horizontal, 16)

            if results.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                    ForEach(results, id: \.id) { post in
                        if currentIntent == .train {
                            TrainCard(
                                post: post,
                                isSaved: isSaved(post, in: .train),
                                onTap: { sheetPostForDetail = post },
                                onStart: { startWorkout(from: post) },
                                onToggleSave: { toggleSave(post, collection: .train) },
                                onLongPressSave: { sheetPostForCollection = post }
                            )
                        } else {
                            WatchCard(
                                post: post,
                                isSaved: isSaved(post, in: .watch),
                                onTap: { sheetPostForDetail = post },
                                onToggleSave: { toggleSave(post, collection: .watch) },
                                onLongPressSave: { sheetPostForCollection = post }
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 34, weight: .light))
                .foregroundColor(GQColors.textTertiary)
            Text("No matching workouts")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(GQColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    /// Shown on first launch before any social posts exist locally — picks
    /// up where the rest of the app's empty states leave off (warm tone,
    /// gradient call to action) instead of looking like a broken page.
    private var emptyExploreState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(GQGradients.primary.opacity(0.18)).frame(width: 96, height: 96)
                Image(systemName: currentIntent == .train ? "figure.strengthtraining.traditional" : "play.rectangle.fill")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(GQGradients.primary)
            }

            VStack(spacing: 4) {
                Text(currentIntent == .train ? "Your gym, personalized" : "Watch room — coming alive")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(GQColors.textPrimary)
                Text("Log a workout or follow a few friends and the picks here will start tailoring to you.")
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var filteredPosts: [Post] {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        return allPosts.filter { post in
            if let bp = bodyPart, post.workoutType?.lowercased() != bp.lowercased() {
                return false
            }
            if let cap = durationCap, (post.duration ?? .max) > cap {
                return false
            }
            if !q.isEmpty {
                let haystack = [
                    post.caption,
                    post.workoutType ?? "",
                    post.exerciseHighlight ?? "",
                    post.authorUsername,
                    post.authorName
                ].joined(separator: " ").lowercased()
                if !haystack.contains(q) { return false }
            }
            // Equipment filter is best-effort: matches only if hint is in caption.
            if let eq = equipment {
                if !post.caption.lowercased().contains(eq.lowercased()) { return false }
            }
            return true
        }
    }

    // MARK: - Actions

    private func isSaved(_ post: Post, in collection: SavedCollection) -> Bool {
        saved.contains { $0.postId == post.id && $0.userId == profile.id && $0.collection == collection }
    }

    private func toggleSave(_ post: Post, collection: SavedCollection) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        SavedWorkoutService.toggle(
            postId: post.id,
            userId: profile.id,
            collection: collection,
            in: modelContext,
            existing: saved.filter { $0.postId == post.id && $0.userId == profile.id }
        )
    }

    private func startWorkout(from post: Post) {
        guard let data = post.sharedWorkoutData,
              let shared = try? JSONDecoder().decode(SharedWorkoutData.self, from: data) else {
            // No structured workout — open detail so the user can explore the post.
            sheetPostForDetail = post
            return
        }
        sheetPostForFollow = post
        // Phase 2 will let the user skip the FollowWorkoutView and start directly:
        //   appState.startWorkout(type: WorkoutType(rawValue: shared.workoutType) ?? .push,
        //                         exercises: shared.toActiveExercises(),
        //                         customTitle: shared.title)
        _ = shared
    }
}
