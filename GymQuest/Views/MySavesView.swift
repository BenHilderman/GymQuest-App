import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// Power-user browse surface for saved posts. Segmented tabs for built-in
/// collections (Do soon / Watch later) plus one tab per user-named custom
/// collection. Presented as a fullscreen sheet from Explore.
struct MySavesView: View {
    let profile: UserProfile

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Post.timestamp, order: .reverse) private var allPosts: [Post]
    @Query private var saves: [SavedWorkout]

    @State private var selectedTab: String = "train"   // "train" | "watch" | custom name
    @State private var sheetForFollow: Post?
    @State private var sheetForDetail: Post?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabsBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                if currentPosts.isEmpty {
                    emptyState
                } else {
                    grid
                }
            }
            .gqPageBackground()
            .navigationTitle("Your saves")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .sheet(item: $sheetForFollow) { post in
                if let data = post.sharedWorkoutData,
                   let shared = try? JSONDecoder().decode(SharedWorkoutData.self, from: data) {
                    FollowWorkoutView(workoutData: shared, profile: profile)
                }
            }
            .fullScreenCover(item: $sheetForDetail) { post in
                PostDetailView(post: post, profile: profile)
            }
        }
    }

    // MARK: - Tabs

    private var tabsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                tabChip(id: "train", label: "Do soon", count: count(in: .train, name: nil))
                tabChip(id: "watch", label: "Watch later", count: count(in: .watch, name: nil))
                ForEach(customNames, id: \.self) { name in
                    tabChip(id: name, label: name, count: count(in: .custom, name: name))
                }
            }
        }
    }

    private func tabChip(id: String, label: String, count: Int) -> some View {
        let active = selectedTab == id
        return Button {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            selectedTab = id
        } label: {
            HStack(spacing: 5) {
                Text(label)
                    .font(.system(size: 13, weight: active ? .heavy : .semibold))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(active ? .white.opacity(0.25) : GQColors.accent.opacity(0.15)))
                }
            }
            .foregroundColor(active ? .white : GQColors.textSecondary)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(
                Capsule().fill(active ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(GQColors.surfaceSecondary))
            )
            .overlay(Capsule().stroke(GQColors.borderDefault.opacity(0.5), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Grid

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                ForEach(currentPosts, id: \.id) { post in
                    savedCard(post)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    private func savedCard(_ post: Post) -> some View {
        Button {
            if post.sharedWorkoutData != nil {
                sheetForFollow = post
            } else {
                sheetForDetail = post
            }
        } label: {
            ZStack(alignment: .bottomLeading) {
                #if canImport(UIKit)
                if let data = thumb(for: post), let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    LinearGradient(
                        colors: [GQColors.accent.opacity(0.5), .black],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
                #endif
                LinearGradient(
                    colors: [.clear, .clear, .black.opacity(0.7)],
                    startPoint: .top, endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title(for: post))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.5), radius: 2)
                    if let dur = post.duration, dur > 0 {
                        Text("\(dur) min · @\(post.authorUsername)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
                .padding(10)
            }
        }
        .buttonStyle(.plain)
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(GQColors.borderDefault.opacity(0.5), lineWidth: 0.5))
        .contextMenu {
            Button(role: .destructive) { remove(post) } label: {
                Label("Remove from saves", systemImage: "trash")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bookmark")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(GQColors.textTertiary)
            Text(emptyTitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(GQColors.textSecondary)
            Text("Long-press any save button to add posts to a collection.")
                .font(.system(size: 12))
                .foregroundColor(GQColors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Derived

    private var mySaves: [SavedWorkout] {
        saves.filter { $0.userId == profile.id }
    }

    private var customNames: [String] {
        let names = Set(mySaves.filter { $0.collection == .custom }.compactMap(\.customCollectionName))
        return names.sorted()
    }

    private var currentPosts: [Post] {
        let matchingSaves: [SavedWorkout]
        switch selectedTab {
        case "train":
            matchingSaves = mySaves.filter { $0.collection == .train }
        case "watch":
            matchingSaves = mySaves.filter { $0.collection == .watch }
        default:
            matchingSaves = mySaves.filter { $0.collection == .custom && $0.customCollectionName == selectedTab }
        }
        let postIds = Set(matchingSaves.map(\.postId))
        return allPosts.filter { postIds.contains($0.id) }
            .sorted { lhs, rhs in
                let lAt = matchingSaves.first(where: { $0.postId == lhs.id })?.savedAt ?? .distantPast
                let rAt = matchingSaves.first(where: { $0.postId == rhs.id })?.savedAt ?? .distantPast
                return lAt > rAt
            }
    }

    private var emptyTitle: String {
        switch selectedTab {
        case "train": return "Nothing saved to do yet"
        case "watch": return "No Watch-later clips yet"
        default: return "\(selectedTab) is empty"
        }
    }

    private func count(in collection: SavedCollection, name: String?) -> Int {
        mySaves.filter {
            $0.collection == collection && (name == nil || $0.customCollectionName == name)
        }.count
    }

    private func title(for post: Post) -> String {
        if let data = post.sharedWorkoutData,
           let shared = try? JSONDecoder().decode(SharedWorkoutData.self, from: data),
           !shared.title.isEmpty {
            return shared.title
        }
        if let highlight = post.exerciseHighlight { return highlight }
        if let type = post.workoutType { return type.capitalized + " session" }
        return post.caption.isEmpty ? "Saved post" : post.caption
    }

    private func thumb(for post: Post) -> Data? {
        if let first = post.mediaItems.first { return first.thumbnailData ?? first.data }
        return post.photoData
    }

    private func remove(_ post: Post) {
        let matching = mySaves.filter { $0.postId == post.id }
        matching.forEach { modelContext.delete($0) }
        try? modelContext.save()
    }
}
