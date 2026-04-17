import SwiftUI
import SwiftData

// MARK: - Activity Item (in-memory, computed from models)

struct ActivityItem: Identifiable {
    let id: UUID
    let userId: UUID
    let userName: String
    let username: String
    let action: ActivityAction
    let timestamp: Date
    let postId: UUID?
    let post: Post?

    enum ActivityAction {
        case like
        case comment(text: String)
        case follow
        case reaction(type: ReactionType)
        case checkIn(workoutType: String, minutes: Int)
        case startedTraining(workoutType: String)
        case duoDay
        case crewMilestone(days: Int)

        var description: String {
            switch self {
            case .like: return "liked your post"
            case .comment(let text): return "commented: \"\(text)\""
            case .follow: return "started following you"
            case .reaction(let type): return "reacted \(type.emoji) to your post"
            case .checkIn(let type, let mins): return "checked in · \(type.lowercased()) · \(mins) min"
            case .startedTraining(let type): return "started \(type.lowercased())"
            case .duoDay: return "trained with you today ✨"
            case .crewMilestone(let days): return "crew hit \(days) of 7 days this week 🔥"
            }
        }

        var icon: String {
            switch self {
            case .like: return "heart.fill"
            case .comment: return "bubble.right.fill"
            case .follow: return "person.badge.plus"
            case .reaction: return "face.smiling"
            case .checkIn: return "checkmark.circle.fill"
            case .startedTraining: return "figure.run"
            case .duoDay: return "sparkles"
            case .crewMilestone: return "flame.fill"
            }
        }

        var iconColor: Color {
            switch self {
            case .like: return GQColors.textSecondary
            case .comment: return GQColors.textSecondary
            case .follow: return GQColors.vividPurple
            case .reaction: return GQColors.textSecondary
            case .checkIn: return GQColors.success
            case .startedTraining: return GQColors.success
            case .duoDay: return GQColors.vividPurple
            case .crewMilestone: return .orange
            }
        }
    }
}

// MARK: - Identifiable UUID Wrapper

struct IdentifiableUUID: Identifiable {
    let id: UUID
}

// MARK: - Activity View

struct SocialActivityView: View {
    let profile: UserProfile

    @Environment(\.modelContext) private var modelContext
    @Query private var likes: [Like]
    @Query private var comments: [Comment]
    @Query private var friends: [Friend]
    @Query private var reactions: [Reaction]
    @Query(sort: \Post.timestamp, order: .reverse) private var posts: [Post]
    @Query private var userProfiles: [UserProfile]
    @Query private var checkIns: [WorkoutCheckIn]
    @Query private var presenceStates: [UserPresenceState]

    @State private var activityItems: [ActivityItem] = []
    @State private var isSearchMode = false
    @State private var profileUserId: IdentifiableUUID?
    @State private var lastDataHash: Int = 0

    var body: some View {
        NavigationStack {
            ZStack {
                GQColors.background.ignoresSafeArea()

                if isSearchMode {
                    UserSearchView(
                        profile: profile,
                        userProfiles: userProfiles,
                        friends: friends,
                        onSelectUser: { userId in
                            profileUserId = IdentifiableUUID(id: userId)
                        }
                    )
                } else {
                    activityList
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSearchMode.toggle()
                        }
                    } label: {
                        Image(systemName: isSearchMode ? "xmark" : "magnifyingglass")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(GQColors.textPrimary)
                    }
                }
            }
            .onAppear { buildActivityItems() }
            .sheet(item: $profileUserId) { wrapped in
                UserProfileSheet(userId: wrapped.id, currentProfile: profile)
            }
        }
    }

    // MARK: - Activity List

    @ViewBuilder
    private var activityList: some View {
        if activityItems.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "heart")
                    .font(.system(size: 40))
                    .foregroundColor(GQColors.textTertiary)
                Text("No activity yet")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)
                Text("When people interact with your posts, you'll see it here.")
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    let grouped = groupedActivity
                    ForEach(grouped, id: \.title) { section in
                        sectionHeader(section.title)
                        ForEach(section.items) { item in
                            ActivityRow(
                                item: item,
                                isFollowingBack: followedIds.contains(item.userId),
                                onTap: {
                                    profileUserId = IdentifiableUUID(id: item.userId)
                                },
                                onFollowBack: {
                                    followUser(item.userId, name: item.userName, username: item.username)
                                }
                            )
                        }
                    }
                }
                .padding(.bottom, 100)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(GQColors.textTertiary)
            .textCase(.uppercase)
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 8)
    }

    private var followedIds: Set<UUID> {
        Set(friends.filter { $0.userId == profile.id }.map { $0.odId })
    }

    private func followUser(_ userId: UUID, name: String, username: String) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        let friend = Friend(userId: profile.id, odId: userId, odName: name, odUsername: username)
        modelContext.insert(friend)
        profile.followingCount += 1

        let descriptor = FetchDescriptor<UserProfile>(predicate: #Predicate { $0.id == userId })
        if let targetProfile = try? modelContext.fetch(descriptor).first {
            targetProfile.followerCount += 1
        }
        try? modelContext.save()
    }

    // MARK: - Grouping

    private struct ActivitySection {
        let title: String
        let items: [ActivityItem]
    }

    private var groupedActivity: [ActivitySection] {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfWeek = calendar.date(byAdding: .day, value: -7, to: startOfToday) ?? startOfToday

        let today = activityItems.filter { $0.timestamp >= startOfToday }
        let thisWeek = activityItems.filter { $0.timestamp >= startOfWeek && $0.timestamp < startOfToday }
        let earlier = activityItems.filter { $0.timestamp < startOfWeek }

        var sections: [ActivitySection] = []
        if !today.isEmpty { sections.append(ActivitySection(title: "Today", items: today)) }
        if !thisWeek.isEmpty { sections.append(ActivitySection(title: "This Week", items: thisWeek)) }
        if !earlier.isEmpty { sections.append(ActivitySection(title: "Earlier", items: earlier)) }
        return sections
    }

    // MARK: - Build Activity Items

    private func buildActivityItems() {
        // Hash-based change check — skip rebuild if data hasn't changed
        var hasher = Hasher()
        hasher.combine(likes.count)
        hasher.combine(comments.count)
        hasher.combine(friends.count)
        hasher.combine(reactions.count)
        hasher.combine(posts.count)
        let dataHash = hasher.finalize()
        guard dataHash != lastDataHash else { return }
        lastDataHash = dataHash

        let myId = profile.id
        let myPostIds = Set(posts.filter { $0.authorId == myId }.map { $0.id })

        var items: [ActivityItem] = []
        let myPosts = posts.filter { $0.authorId == myId }
        let postLookup = Dictionary(uniqueKeysWithValues: myPosts.map { ($0.id, $0) })

        // Pre-build user lookup dictionary instead of repeated O(n) .first calls
        let userLookup = Dictionary(uniqueKeysWithValues: userProfiles.map { ($0.id, $0) })

        // Likes on my posts
        for like in likes where myPostIds.contains(like.postId) && like.userId != myId {
            let username = userLookup[like.userId]?.username ?? ""
            items.append(ActivityItem(
                id: like.id,
                userId: like.userId,
                userName: like.userName,
                username: username,
                action: .like,
                timestamp: like.timestamp,
                postId: like.postId,
                post: postLookup[like.postId]
            ))
        }

        // Comments on my posts
        for comment in comments where myPostIds.contains(comment.postId) && comment.authorId != myId {
            items.append(ActivityItem(
                id: comment.id,
                userId: comment.authorId,
                userName: comment.authorName,
                username: comment.authorUsername,
                action: .comment(text: String(comment.content.prefix(40))),
                timestamp: comment.timestamp,
                postId: comment.postId,
                post: postLookup[comment.postId]
            ))
        }

        // Followers (people who follow me)
        for friend in friends where friend.odId == myId && friend.userId != myId {
            let followerProfile = userLookup[friend.userId]
            items.append(ActivityItem(
                id: friend.id,
                userId: friend.userId,
                userName: followerProfile?.name ?? friend.odName,
                username: followerProfile?.username ?? friend.odUsername,
                action: .follow,
                timestamp: friend.followedAt,
                postId: nil,
                post: nil
            ))
        }

        // Reactions on my posts
        for reaction in reactions where myPostIds.contains(reaction.targetId) && reaction.odId != myId {
            let reactorProfile = userLookup[reaction.odId]
            items.append(ActivityItem(
                id: reaction.id,
                userId: reaction.odId,
                userName: reactorProfile?.name ?? reaction.odUsername,
                username: reaction.odUsername,
                action: .reaction(type: reaction.reactionType),
                timestamp: reaction.createdAt,
                postId: reaction.targetId,
                post: postLookup[reaction.targetId]
            ))
        }

        // Community events: friend check-ins (last 7 days)
        let weekAgo = Date().addingTimeInterval(-7 * 86_400)
        for ci in checkIns where ci.userId != myId && ci.timestamp >= weekAgo {
            let ciProfile = userLookup[ci.userId]
            items.append(ActivityItem(
                id: ci.id,
                userId: ci.userId,
                userName: ciProfile?.name ?? ci.userName,
                username: ciProfile?.username ?? ci.userUsername,
                action: .checkIn(workoutType: ci.workoutType, minutes: ci.durationMinutes),
                timestamp: ci.timestamp,
                postId: nil,
                post: nil
            ))
        }

        // Community events: friends currently/recently training
        let liveFollowedIds = Set(friends.filter { $0.userId == myId }.map(\.odId))
        for state in presenceStates where liveFollowedIds.contains(state.userId) {
            if state.status == .training || state.status == .resting,
               let started = state.startedAt {
                let stateProfile = userLookup[state.userId]
                items.append(ActivityItem(
                    id: state.userId,
                    userId: state.userId,
                    userName: stateProfile?.name ?? "A friend",
                    username: stateProfile?.username ?? "",
                    action: .startedTraining(workoutType: state.workoutTypeRaw ?? "workout"),
                    timestamp: started,
                    postId: nil,
                    post: nil
                ))
            }
        }

        activityItems = items.sorted { $0.timestamp > $1.timestamp }
    }
}

// MARK: - Activity Row

struct ActivityRow: View {
    let item: ActivityItem
    var isFollowingBack: Bool = false
    var onTap: () -> Void
    var onFollowBack: (() -> Void)? = nil

    @State private var didFollowBack = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(GQGradients.primary)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(item.userName.prefix(1)).uppercased())
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                    )

                // Content
                VStack(alignment: .leading, spacing: 2) {
                    (Text(item.userName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                     + Text(" ")
                     + Text(item.action.description)
                        .font(.system(size: 14))
                        .foregroundColor(GQColors.textSecondary))
                    .lineLimit(2)

                    Text(item.timestamp.timeAgoDisplay())
                        .font(.system(size: 12))
                        .foregroundColor(GQColors.textTertiary)
                }

                Spacer()

                // Follow back button for follow actions
                if case .follow = item.action, !isFollowingBack, !didFollowBack, let followBack = onFollowBack {
                    Button {
                        didFollowBack = true
                        followBack()
                    } label: {
                        Text("Follow")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(GQGradients.primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                } else if case .follow = item.action, isFollowingBack || didFollowBack {
                    Text("Following")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(GQColors.adaptiveOverlay(0.06))
                        .clipShape(Capsule())
                } else if let post = item.post {
                    activityPostThumbnail(post: post)
                } else {
                    Image(systemName: item.action.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(GQGradients.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func activityPostThumbnail(post: Post) -> some View {
        ZStack {
            #if canImport(UIKit)
            if let data = post.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipped()
                    .cornerRadius(6)
            } else {
                postPlaceholderThumbnail(post: post)
            }
            #else
            postPlaceholderThumbnail(post: post)
            #endif
        }
    }

    @ViewBuilder
    private func postPlaceholderThumbnail(post: Post) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(GQColors.surfaceElevated)
            .frame(width: 44, height: 44)
            .overlay(
                Group {
                    if let type = post.workoutType, let wt = WorkoutType(rawValue: type) {
                        Image(systemName: wt.icon)
                            .font(.system(size: 16))
                            .foregroundColor(GQColors.textTertiary)
                    } else {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 16))
                            .foregroundColor(GQColors.textTertiary)
                    }
                }
            )
    }
}

// MARK: - User Search View

struct UserSearchView: View {
    let profile: UserProfile
    let userProfiles: [UserProfile]
    let friends: [Friend]
    var onSelectUser: (UUID) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""

    private var filteredProfiles: [UserProfile] {
        let others = userProfiles.filter { $0.id != profile.id }
        if searchText.isEmpty {
            return others
        }
        let query = searchText.lowercased()
        return others.filter {
            $0.name.lowercased().contains(query) || $0.username.lowercased().contains(query)
        }
    }

    private var followedIds: Set<UUID> {
        Set(friends.filter { $0.userId == profile.id }.map { $0.odId })
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundColor(GQColors.textTertiary)

                TextField("Search users", text: $searchText)
                    .font(.system(size: 15))
                    .foregroundColor(GQColors.textPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(GQColors.textTertiary)
                    }
                }
            }
            .padding(10)
            .background(GQColors.surfaceElevated)
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Header
            if searchText.isEmpty {
                Text("SUGGESTED")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(GQColors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredProfiles) { userProfile in
                        UserSearchRow(
                            userProfile: userProfile,
                            isFollowing: followedIds.contains(userProfile.id),
                            currentProfile: profile,
                            onTap: { onSelectUser(userProfile.id) }
                        )
                    }
                }
                .padding(.bottom, 100)
            }
        }
    }
}

// MARK: - User Search Row

struct UserSearchRow: View {
    let userProfile: UserProfile
    let isFollowing: Bool
    let currentProfile: UserProfile
    var onTap: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var following: Bool = false
    @State private var showingUnfollowConfirm = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(GQGradients.primary)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(userProfile.name.prefix(1)).uppercased())
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(userProfile.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                    Text("@\(userProfile.username)")
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textSecondary)
                }

                Spacer()

                // Follow button
                Button {
                    if following {
                        showingUnfollowConfirm = true
                    } else {
                        toggleFollow()
                    }
                } label: {
                    Text(following ? "Following" : "Follow")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(following ? GQColors.textSecondary : .white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(
                            Group {
                                if following {
                                    Capsule().fill(GQColors.surfaceElevated)
                                } else {
                                    Capsule().fill(GQGradients.primary)
                                }
                            }
                        )
                        .overlay(
                            Capsule()
                                .stroke(following ? GQColors.borderSubtle : Color.clear, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .onAppear { following = isFollowing }
        .confirmationDialog("Unfollow @\(userProfile.username)?", isPresented: $showingUnfollowConfirm, titleVisibility: .visible) {
            Button("Unfollow", role: .destructive) {
                toggleFollow()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func toggleFollow() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        let targetId = userProfile.id
        let myId = currentProfile.id

        if following {
            following = false
            currentProfile.followingCount = max(0, currentProfile.followingCount - 1)
            let descriptor = FetchDescriptor<Friend>(predicate: #Predicate {
                $0.userId == myId && $0.odId == targetId
            })
            if let records = try? modelContext.fetch(descriptor) {
                for record in records { modelContext.delete(record) }
            }
        } else {
            following = true
            currentProfile.followingCount += 1
            let friend = Friend(userId: myId, odId: targetId, odName: userProfile.name, odUsername: userProfile.username)
            modelContext.insert(friend)
        }

        // Update target's follower count
        let descriptor = FetchDescriptor<UserProfile>(predicate: #Predicate { $0.id == targetId })
        if let targetProfile = try? modelContext.fetch(descriptor).first {
            targetProfile.followerCount += following ? 1 : -1
        }
        try? modelContext.save()
    }
}
