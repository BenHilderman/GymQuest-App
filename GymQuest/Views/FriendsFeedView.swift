import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// The cozy friends-only scroll — exact same rendering as the original
/// Friends tab (PostCardV2 + FeedCurator). Presented as a sheet from
/// Explore. Every ~6 posts a workout suggestion card appears.
struct FriendsFeedView: View {
    let profile: UserProfile

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState

    @Query(sort: \Post.timestamp, order: .reverse) private var allPosts: [Post]
    @Query private var follows: [Friend]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if friendPosts.isEmpty {
                    emptyState
                } else {
                    ForEach(Array(friendPosts.enumerated()), id: \.element.id) { index, post in
                        PostCardV2(
                            post: post,
                            currentUserId: profile.id,
                            currentUserName: profile.name,
                            profile: profile
                        )

                        Rectangle()
                            .fill(GQColors.borderSubtle)
                            .frame(height: 1)

                        // Clean scroll — no interrupts
                    }

                    backToTrainingFooter
                }
            }
            .padding(.bottom, 100)
        }
        .scrollContentBackground(.hidden)
        .gqPageBackground()
        .navigationTitle("Friends")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(GQColors.background, for: .navigationBar)
    }

    // MARK: - Data

    private var friendPosts: [Post] {
        let followedIds = Set(follows.filter { $0.userId == profile.id }.map(\.odId))
        return allPosts.filter {
            followedIds.contains($0.authorId) &&
            ($0.photoData != nil || $0.videoData != nil || !$0.mediaItems.isEmpty)
        }
    }

    private var bestSuggestion: Post? {
        allPosts
            .filter { $0.sharedWorkoutData != nil }
            .max(by: { $0.doabilityScore < $1.doabilityScore })
    }

    // MARK: - Workout suggestion

    private func workoutSuggestionCard(_ post: Post) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(GQGradients.primary.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(GQGradients.primary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(suggestionTitle(post))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(GQColors.textPrimary)
                    .lineLimit(1)
                if let dur = post.duration, dur > 0 {
                    Text("\(dur) min · \(post.workoutType?.capitalized ?? "Workout")")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(GQColors.textSecondary)
                }
            }

            Spacer()

            Button {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if let data = post.sharedWorkoutData,
                       let shared = try? JSONDecoder().decode(SharedWorkoutData.self, from: data) {
                        let type = WorkoutType(rawValue: shared.workoutType) ?? .push
                        appState.startWorkout(type: type, exercises: shared.toActiveExercises(), customTitle: shared.title)
                    }
                }
            } label: {
                Text("Try it →")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(GQGradients.primary))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .homeSocialCard(cornerRadius: 14)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private func suggestionTitle(_ post: Post) -> String {
        if let data = post.sharedWorkoutData,
           let shared = try? JSONDecoder().decode(SharedWorkoutData.self, from: data),
           !shared.title.isEmpty { return shared.title }
        return post.exerciseHighlight ?? post.workoutType?.capitalized ?? "Workout"
    }

    // MARK: - Weekly prompt (from original socialFeedContent)

    private func weeklyPromptRow(label: String, icon: String) -> some View {
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
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(GQColors.borderDefault, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // MARK: - Empty + footer

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2")
                .font(.system(size: 40))
                .foregroundColor(GQColors.textTertiary)
            Text("No friend posts yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(GQColors.textSecondary)
            Text("Follow people to see their workouts here")
                .font(.system(size: 14))
                .foregroundColor(GQColors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 60)
    }

    private var backToTrainingFooter: some View {
        VStack(spacing: 10) {
            Text("You've seen your crew's latest")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
            Button { dismiss() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 13, weight: .bold))
                    Text("Back to training")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Capsule().fill(GQGradients.primary))
                .padding(.horizontal, 40)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 16)
    }
}
