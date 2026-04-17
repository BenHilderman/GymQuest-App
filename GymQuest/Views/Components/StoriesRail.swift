import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// One person's recent activity, summarized as a circular avatar with a
/// brand-gradient ring (matches Instagram Stories pattern). Tapping any
/// story opens Shorts filtered to that person's recent clips — fast,
/// social, no separate Friends tab needed.
struct StoryItem: Identifiable {
    let id: UUID
    let displayName: String
    let username: String
    let avatarData: Data?
    let mostRecentPostId: UUID
    let isSelf: Bool
}

struct StoriesRail: View {
    let items: [StoryItem]
    let onTap: (StoryItem) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 14) {
                ForEach(items) { item in
                    storyButton(item)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func storyButton(_ item: StoryItem) -> some View {
        Button {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            onTap(item)
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(GQGradients.primary, lineWidth: 2.5)
                        .frame(width: 60, height: 60)

                    avatar(item)
                        .frame(width: 52, height: 52)
                        .clipShape(Circle())
                }
                Text(item.isSelf ? "You" : item.displayName.split(separator: " ").first.map(String.init) ?? item.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(GQColors.textSecondary)
                    .lineLimit(1)
                    .frame(maxWidth: 64)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func avatar(_ item: StoryItem) -> some View {
        #if canImport(UIKit)
        if let data = item.avatarData, let img = UIImage(data: data) {
            Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                Circle().fill(GQGradients.primary)
                Text(String(item.displayName.prefix(1)).uppercased())
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        #else
        Circle().fill(GQColors.surfaceSecondary)
        #endif
    }
}
