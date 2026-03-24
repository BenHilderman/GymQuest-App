import SwiftUI
import SwiftData
import Supabase

struct UserProfileSheet: View {
    let userId: UUID
    let currentProfile: UserProfile

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allProfiles: [UserProfile]
    @Query private var allPosts: [Post]
    @Query private var allFriends: [Friend]

    @State private var isFollowing = false

    private var userProfile: UserProfile? {
        allProfiles.first { $0.id == userId }
    }

    private var userPosts: [Post] {
        allPosts.filter { $0.authorId == userId }
            .sorted { $0.timestamp > $1.timestamp }
    }

    private var followerCount: Int {
        userProfile?.followerCount ?? 0
    }

    private var followingCount: Int {
        userProfile?.followingCount ?? 0
    }

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileHeader
                    statsRow
                    followButton
                    postsGrid
                }
                .padding(.top, 20)
            }
            .background(GQColors.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(GQColors.textTertiary)
                    }
                }
            }
            .onAppear { loadFollowState() }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var profileHeader: some View {
        VStack(spacing: 8) {
            // Avatar
            #if canImport(UIKit)
            if let data = userProfile?.profilePhotoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
            } else {
                avatarCircle
            }
            #else
            avatarCircle
            #endif

            Text(userProfile?.name ?? "Unknown")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(GQColors.textPrimary)

            Text("@\(userProfile?.username ?? "")")
                .font(.system(size: 14))
                .foregroundColor(GQColors.textSecondary)
        }
    }

    private var avatarCircle: some View {
        Circle()
            .fill(GQGradients.primary)
            .frame(width: 80, height: 80)
            .overlay(
                Text(String((userProfile?.name ?? "?").prefix(1)).uppercased())
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            )
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 0) {
            statColumn(value: "\(userPosts.count)", label: "Posts")
            statColumn(value: "\(followerCount)", label: "Followers")
            statColumn(value: "\(followingCount)", label: "Following")
        }
        .padding(.horizontal, 16)
    }

    private func statColumn(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(GQColors.textPrimary)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(GQColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Follow Button

    @ViewBuilder
    private var followButton: some View {
        if userId != currentProfile.id {
            Button {
                toggleFollow()
            } label: {
                Text(isFollowing ? "Following" : "Follow")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isFollowing ? GQColors.textPrimary : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Group {
                            if isFollowing {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.clear)
                            } else {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(GQGradients.primary)
                            }
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isFollowing ? GQColors.borderSubtle : Color.clear, lineWidth: 1)
                    )
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Posts Grid

    @ViewBuilder
    private var postsGrid: some View {
        if userPosts.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "camera")
                    .font(.system(size: 32))
                    .foregroundColor(GQColors.textTertiary)
                Text("No posts yet")
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.textSecondary)
            }
            .padding(.top, 40)
        } else {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(userPosts) { post in
                    ProfilePostThumbnail(post: post)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Follow Logic

    private func loadFollowState() {
        let myId = currentProfile.id
        let targetId = userId
        let descriptor = FetchDescriptor<Friend>(predicate: #Predicate {
            $0.userId == myId && $0.odId == targetId
        })
        isFollowing = ((try? modelContext.fetchCount(descriptor)) ?? 0) > 0
    }

    private func toggleFollow() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        let targetId = userId
        let myId = currentProfile.id

        if isFollowing {
            isFollowing = false
            currentProfile.followingCount = max(0, currentProfile.followingCount - 1)
            let descriptor = FetchDescriptor<Friend>(predicate: #Predicate {
                $0.userId == myId && $0.odId == targetId
            })
            if let records = try? modelContext.fetch(descriptor) {
                for record in records { modelContext.delete(record) }
            }

            // Sync unfollow to Supabase
            if FeatureFlags.shared.supabaseSyncEnabled {
                Task {
                    do {
                        try await SupabaseConfig.client.from("follows")
                            .delete()
                            .eq("follower_id", value: myId.uuidString)
                            .eq("following_id", value: targetId.uuidString)
                            .execute()
                    } catch {
                        print("[UserProfileSheet] Supabase unfollow sync failed: \(error)")
                    }
                }
            }
        } else {
            isFollowing = true
            currentProfile.followingCount += 1
            let name = userProfile?.name ?? ""
            let username = userProfile?.username ?? ""
            let friend = Friend(userId: myId, odId: targetId, odName: name, odUsername: username)
            modelContext.insert(friend)

            // Sync follow to Supabase
            if FeatureFlags.shared.supabaseSyncEnabled {
                Task {
                    do {
                        let dto = FollowDTO(followerId: myId, followingId: targetId)
                        try await SupabaseSyncService.shared.insert(dto, table: "follows")
                    } catch {
                        print("[UserProfileSheet] Supabase follow sync failed: \(error)")
                    }
                }
            }
        }

        // Update target's follower count
        if let target = userProfile {
            target.followerCount += isFollowing ? 1 : -1
        }
        try? modelContext.save()
    }
}
