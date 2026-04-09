import SwiftUI

struct ProfilePostBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    let profile: UserProfile
    let photoPosts: [Post]
    let clipPosts: [Post]
    let taggedPosts: [Post]
    let initialTab: PostGridTab
    let initialPostId: UUID

    @State private var currentTab: PostGridTab

    init(profile: UserProfile, photoPosts: [Post], clipPosts: [Post],
         taggedPosts: [Post], initialTab: PostGridTab, initialPostId: UUID) {
        self.profile = profile
        self.photoPosts = photoPosts
        self.clipPosts = clipPosts
        self.taggedPosts = taggedPosts
        self.initialTab = initialTab
        self.initialPostId = initialPostId
        self._currentTab = State(initialValue: initialTab)
    }

    var body: some View {
        ZStack(alignment: .top) {
            GQColors.background
                .ignoresSafeArea()

            TabView(selection: $currentTab) {
                VerticalPostFeed(
                    posts: photoPosts,
                    initialPostId: initialTab == .photos ? initialPostId : nil,
                    profile: profile
                )
                .tag(PostGridTab.photos)

                VerticalPostFeed(
                    posts: clipPosts,
                    initialPostId: initialTab == .clips ? initialPostId : nil,
                    profile: profile
                )
                .tag(PostGridTab.clips)

                VerticalPostFeed(
                    posts: taggedPosts,
                    initialPostId: initialTab == .tagged ? initialPostId : nil,
                    profile: profile
                )
                .tag(PostGridTab.tagged)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(edges: .bottom)

            // Top bar: tab indicator + dismiss
            HStack {
                HStack(spacing: 16) {
                    ForEach([PostGridTab.photos, .clips, .tagged], id: \.self) { tab in
                        VStack(spacing: 4) {
                            Image(systemName: tab == .photos ? "square.grid.3x3" : tab == .clips ? "play.rectangle" : "at")
                                .font(.system(size: 14, weight: currentTab == tab ? .semibold : .regular))
                                .foregroundStyle(currentTab == tab ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(GQColors.textTertiary))
                        }
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                currentTab = tab
                            }
                        }
                    }
                }

                Spacer()

                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                        .frame(width: 32, height: 32)
                        .background(GQColors.surfaceSecondary, in: Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }
}

// MARK: - Vertical Post Feed (paging scroll within a tab)

private struct VerticalPostFeed: View {
    let posts: [Post]
    let initialPostId: UUID?
    let profile: UserProfile

    @EnvironmentObject var appState: AppState
    @State private var scrolledPostId: UUID?

    var body: some View {
        if posts.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(GQGradients.primary.opacity(0.4))
                Text("No posts")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(GQColors.textTertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(posts) { post in
                        PostCardV2(
                            post: post,
                            currentUserId: profile.id,
                            currentUserName: profile.username,
                            profile: profile
                        )
                        .id(post.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrolledPostId)
            .onAppear {
                if let initialPostId {
                    scrolledPostId = initialPostId
                }
            }
        }
    }
}
