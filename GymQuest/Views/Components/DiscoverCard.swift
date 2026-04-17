import SwiftUI

/// Option 4 — "Exercise Trends" style discover card. One full-width
/// `.homeSocialCard` with chip selectors and workout rows below. Exact
/// same chip styling as ProgressView and row layout as Recent PRs.
struct DiscoverCard: View {
    let posts: [Post]
    let onTapPost: (Post) -> Void

    @State private var selectedType: String = "All"

    private let types = ["All", "Push", "Pull", "Legs", "Cardio", "Core"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            chipSelector
            workoutRows
        }
        .padding(16)
        .homeSocialCard(cornerRadius: 16)
    }

    // MARK: - Header (matches PRs card)

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(GQGradients.primary)
            Text("Discover")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(GQColors.textPrimary)
            Spacer()
            Text("\(filteredPosts.count) workouts")
                .font(.system(size: 11))
                .foregroundColor(GQColors.textTertiary)
        }
    }

    // MARK: - Chips (exact ProgressView pattern)

    private var chipSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(types, id: \.self) { type in
                    let isSelected = selectedType == type
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedType = type
                        }
                    } label: {
                        Text(type)
                            .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                            .foregroundColor(isSelected ? .white : GQColors.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
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
        }
    }

    // MARK: - Workout rows (exact PR list pattern)

    @ViewBuilder
    private var workoutRows: some View {
        let visible = Array(filteredPosts.prefix(4))
        if visible.isEmpty {
            HStack {
                Spacer()
                Text("No workouts found")
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textTertiary)
                Spacer()
            }
            .padding(.vertical, 12)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(visible.enumerated()), id: \.element.id) { index, post in
                    Button { onTapPost(post) } label: {
                        workoutRow(post: post, rank: index + 1)
                    }
                    .buttonStyle(.plain)

                    if index < visible.count - 1 {
                        Divider().overlay(GQColors.adaptiveOverlay(0.04))
                    }
                }
            }
        }
    }

    private func workoutRow(post: Post, rank: Int) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(GQGradients.primary.opacity(rank == 1 ? 0.15 : 0.06))
                    .frame(width: 34, height: 34)
                Text("\(rank)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(rank == 1
                        ? AnyShapeStyle(GQGradients.primary)
                        : AnyShapeStyle(GQColors.textTertiary))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(displayTitle(post))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(GQColors.textPrimary)
                    .lineLimit(1)
                Text(displaySubtitle(post))
                    .font(.system(size: 11))
                    .foregroundColor(GQColors.textTertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let dur = post.duration, dur > 0 {
                    Text("\(dur) min")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(GQColors.textPrimary)
                }
                if post.doabilityScore >= 0.5 {
                    Text("ready")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(GQColors.success)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(GQColors.textTertiary)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private var filteredPosts: [Post] {
        if selectedType == "All" { return posts }
        return posts.filter { $0.workoutType?.lowercased() == selectedType.lowercased() }
    }

    private func displayTitle(_ post: Post) -> String {
        if let data = post.sharedWorkoutData,
           let shared = try? JSONDecoder().decode(SharedWorkoutData.self, from: data),
           !shared.title.isEmpty { return shared.title }
        if let highlight = post.exerciseHighlight { return highlight }
        if let type = post.workoutType { return type.capitalized }
        return post.caption.isEmpty ? "Workout" : post.caption
    }

    private func displaySubtitle(_ post: Post) -> String {
        var parts: [String] = []
        if let type = post.workoutType { parts.append(type.capitalized) }
        if let sets = post.setCount, sets > 0 { parts.append("\(sets) sets") }
        parts.append("@\(post.authorUsername)")
        return parts.joined(separator: " · ")
    }
}
