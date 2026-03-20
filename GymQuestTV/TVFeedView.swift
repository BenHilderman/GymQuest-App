//
//  TVFeedView.swift
//  GymQuestTV
//
//  Social feed for tvOS — Apple Fitness+ inspired.
//  Clean horizontal rows, large cards, details on select.
//

#if os(tvOS)

import SwiftUI
import SwiftData

// MARK: - TV Feed View

struct TVFeedView: View {
    @Query(sort: \Post.timestamp, order: .reverse) private var posts: [Post]
    @Query private var friends: [Friend]
    @Query private var profiles: [UserProfile]

    @State private var selectedPost: Post?
    @State private var showDetail = false

    private let offWhite = Color(white: 0.93)

    // MARK: Computed Filters

    private var featuredPost: Post? {
        posts.first { $0.photoData != nil || $0.workoutType != nil }
    }

    private var workoutPosts: [Post] {
        posts.filter { $0.workoutType != nil }
    }

    private var prPosts: [Post] {
        posts.filter { !$0.getFeedPRs().isEmpty }
    }

    private var recentPosts: [Post] {
        Array(posts.prefix(20))
    }

    // MARK: Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 80) {
                // Hero
                if let hero = featuredPost {
                    heroCard(hero)
                }

                // Workouts row
                if !workoutPosts.isEmpty {
                    feedRow(title: "Trending Workouts", posts: workoutPosts) { post in
                        workoutCard(post)
                    }
                }

                // PRs row
                if !prPosts.isEmpty {
                    feedRow(title: "PR Celebrations", posts: prPosts) { post in
                        prCard(post)
                    }
                }

                // Community row
                if !recentPosts.isEmpty {
                    feedRow(title: "Community", posts: recentPosts) { post in
                        communityCard(post)
                    }
                }

                // Empty
                if posts.isEmpty {
                    emptyState
                }
            }
            .padding(.horizontal, 80)
            .padding(.top, 40)
            .padding(.bottom, 100)
        }
        .background(Color(white: 0.11).ignoresSafeArea())
        .sheet(isPresented: $showDetail) {
            if let post = selectedPost {
                TVPostDetailView(post: post)
            }
        }
    }

    // MARK: - Hero Card (full-width featured post)

    @ViewBuilder
    private func heroCard(_ post: Post) -> some View {
        Button {
            selectedPost = post
            showDetail = true
        } label: {
            ZStack(alignment: .bottomLeading) {
                // Background
                heroBackground(for: post)
                    .frame(height: 520)

                // Gradient scrim
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .clear, location: 0.35),
                        .init(color: .black.opacity(0.5), location: 0.7),
                        .init(color: .black.opacity(0.9), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Content
                VStack(alignment: .leading, spacing: 12) {
                    Text("FEATURED")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .tracking(5)
                        .foregroundStyle(GQGradients.primary)

                    Text(post.authorName)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(offWhite)

                    HStack(spacing: 20) {
                        if let workoutType = post.workoutType {
                            Label(workoutType, systemImage: "dumbbell.fill")
                        }
                        if let duration = post.duration {
                            Label(formatDuration(duration), systemImage: "clock.fill")
                        }
                        Label(timeAgo(post.timestamp), systemImage: "clock")
                    }
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .foregroundColor(offWhite.opacity(0.6))

                    if !post.caption.isEmpty {
                        Text(post.caption)
                            .font(.system(size: 28, weight: .regular, design: .rounded))
                            .foregroundColor(offWhite.opacity(0.8))
                            .lineLimit(2)
                            .frame(maxWidth: 800, alignment: .leading)
                    }
                }
                .padding(48)
            }
            .frame(height: 520)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        LinearGradient(
                            colors: [GQColors.deepBlue.opacity(0.5), GQColors.vividPurple.opacity(0.3), GQColors.deepBlue.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: .black.opacity(0.4), radius: 30, y: 15)
        }
        .buttonStyle(TVCardButtonStyle())
    }

    @ViewBuilder
    private func heroBackground(for post: Post) -> some View {
        #if canImport(UIKit)
        if let data = post.photoData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            gradientPlaceholder
        }
        #else
        gradientPlaceholder
        #endif
    }

    private var gradientPlaceholder: some View {
        LinearGradient(
            colors: [GQColors.deepBlue, GQColors.vividPurple.opacity(0.6), GQColors.deepBlue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 100, weight: .ultraLight))
                .foregroundColor(.white.opacity(0.08))
        )
    }

    // MARK: - Feed Row

    @ViewBuilder
    private func feedRow<Content: View>(
        title: String,
        posts: [Post],
        @ViewBuilder cardBuilder: @escaping (Post) -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(offWhite)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 40) {
                    ForEach(posts) { post in
                        Button {
                            selectedPost = post
                            showDetail = true
                        } label: {
                            cardBuilder(post)
                        }
                        .buttonStyle(TVCardButtonStyle())
                    }
                }
                .padding(.vertical, 20)
            }
        }
    }

    // MARK: - Workout Card (simple: gradient + type + author + time)

    @ViewBuilder
    private func workoutCard(_ post: Post) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Gradient header with workout type overlay
            ZStack(alignment: .bottomLeading) {
                cardImage(for: post, height: 180)

                // Scrim for text legibility
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black.opacity(0.6), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 180)

                if let workoutType = post.workoutType {
                    Text(workoutType.uppercased())
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundColor(.white)
                        .padding(20)
                }
            }

            // Content — author + meta
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    authorDot(post.authorName)
                    Text(post.authorName)
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .foregroundColor(offWhite)
                }

                HStack(spacing: 8) {
                    Text(timeAgo(post.timestamp))
                    if let duration = post.duration {
                        Text("·")
                        Text(formatDuration(duration))
                    }
                }
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundColor(offWhite.opacity(0.4))

                if !post.caption.isEmpty {
                    Text(post.caption)
                        .font(.system(size: 22, weight: .regular, design: .rounded))
                        .foregroundColor(offWhite.opacity(0.5))
                        .lineLimit(2)
                }
            }
            .padding(24)
        }
        .frame(width: 440, height: 360)
        .background(Color(white: 0.16))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    }

    // MARK: - PR Card (trophy + name + best lift)

    @ViewBuilder
    private func prCard(_ post: Post) -> some View {
        let prs = post.getFeedPRs()
        let topPR = prs.first

        VStack(alignment: .leading, spacing: 0) {
            // Gold gradient header
            ZStack {
                LinearGradient(
                    colors: [GQColors.deepBlue.opacity(0.4), GQColors.vividPurple.opacity(0.15), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(GQGradients.primary)

                    Text("\(prs.count) PR\(prs.count == 1 ? "" : "s")")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(GQGradients.primary)
                }
            }
            .frame(height: 130)

            // Content
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    authorDot(post.authorName)
                    Text(post.authorName)
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .foregroundColor(offWhite)
                }

                if let pr = topPR {
                    HStack {
                        Text(pr.exerciseName)
                            .font(.system(size: 24, weight: .medium, design: .rounded))
                            .foregroundColor(offWhite.opacity(0.6))
                        Spacer()
                        Text(pr.value)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(GQGradients.primary)
                    }
                }

                Text(timeAgo(post.timestamp))
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundColor(offWhite.opacity(0.35))
            }
            .padding(24)
        }
        .frame(width: 420, height: 380)
        .background(Color(white: 0.16))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    }

    // MARK: - Community Card (simple: author + caption)

    @ViewBuilder
    private func communityCard(_ post: Post) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Optional image or gradient strip
            if post.photoData != nil {
                cardImage(for: post, height: 120)
            } else {
                LinearGradient(
                    colors: [GQColors.deepBlue.opacity(0.4), GQColors.vividPurple.opacity(0.2)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 6)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    authorDot(post.authorName)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(post.authorName)
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                            .foregroundColor(offWhite)
                        HStack(spacing: 6) {
                            Text(timeAgo(post.timestamp))
                            if let type = post.workoutType {
                                Text("·")
                                Text(type)
                            }
                        }
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundColor(offWhite.opacity(0.35))
                    }
                }

                if !post.caption.isEmpty {
                    Text(post.caption)
                        .font(.system(size: 24, weight: .regular, design: .rounded))
                        .foregroundColor(offWhite.opacity(0.7))
                        .lineLimit(3)
                }

                // One-line stats
                let prs = post.getFeedPRs()
                if !prs.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(GQGradients.primary)
                        Text("\(prs.count) PR\(prs.count == 1 ? "" : "s")")
                            .foregroundStyle(GQGradients.primary)
                    }
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                }

                HStack(spacing: 20) {
                    if post.likeCount > 0 {
                        Label(formatCount(post.likeCount), systemImage: "heart.fill")
                    }
                    if post.commentCount > 0 {
                        Label(formatCount(post.commentCount), systemImage: "bubble.left.fill")
                    }
                }
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundColor(offWhite.opacity(0.3))
            }
            .padding(24)
        }
        .frame(width: 480)
        .background(Color(white: 0.16))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    }

    // MARK: - Shared Components

    @ViewBuilder
    private func cardImage(for post: Post, height: CGFloat) -> some View {
        #if canImport(UIKit)
        if let data = post.photoData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: height)
                .clipped()
        } else {
            LinearGradient(
                colors: [GQColors.deepBlue.opacity(0.5), GQColors.vividPurple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: height)
        }
        #else
        LinearGradient(
            colors: [GQColors.deepBlue.opacity(0.5), GQColors.vividPurple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(height: height)
        #endif
    }

    private func authorDot(_ name: String) -> some View {
        let initial = String(name.prefix(1)).uppercased()
        return ZStack {
            Circle()
                .fill(GQGradients.primary)
                .frame(width: 36, height: 36)
            Text(initial)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundStyle(GQGradients.primary)

            Text("No Activity Yet")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(offWhite)

            Text("Workout posts from your community will appear here.")
                .font(.system(size: 26, weight: .regular, design: .rounded))
                .foregroundColor(offWhite.opacity(0.4))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 120)
    }

    // MARK: - Helpers

    private func formatDuration(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(minutes)m"
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)
        let hours = minutes / 60
        let days = hours / 24

        if minutes < 1 { return "Just now" }
        if minutes < 60 { return "\(minutes)m ago" }
        if hours < 24 { return "\(hours)h ago" }
        if days < 7 { return "\(days)d ago" }
        if days < 30 { return "\(days / 7)w ago" }
        return "\(days / 30)mo ago"
    }
}

// MARK: - Post Detail View

struct TVPostDetailView: View {
    let post: Post
    @Environment(\.dismiss) private var dismiss

    private let offWhite = Color(white: 0.93)

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 32) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(post.authorName)
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundColor(offWhite)
                        Text("@\(post.authorUsername)")
                            .font(.system(size: 26, weight: .regular, design: .rounded))
                            .foregroundColor(offWhite.opacity(0.4))
                        Text(timeAgoLong(post.timestamp))
                            .font(.system(size: 22, weight: .medium, design: .rounded))
                            .foregroundColor(offWhite.opacity(0.3))
                    }
                    Spacer()
                    if let workoutType = post.workoutType {
                        Text(workoutType)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(GQGradients.primary))
                    }
                }

                // Photo
                #if canImport(UIKit)
                if let data = post.photoData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 500)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                #endif

                // Caption
                if !post.caption.isEmpty {
                    Text(post.caption)
                        .font(.system(size: 29, weight: .regular, design: .rounded))
                        .foregroundColor(offWhite)
                }

                // Workout stats
                if post.workoutType != nil {
                    HStack(spacing: 48) {
                        if let duration = post.duration {
                            detailStat(value: formatDuration(duration), label: "Duration")
                        }
                        if let sets = post.setCount, sets > 0 {
                            detailStat(value: "\(sets)", label: "Sets")
                        }
                        if let highlight = post.exerciseHighlight {
                            detailStat(value: highlight, label: "Highlight")
                        }
                    }
                    .padding(32)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color(white: 0.18)))
                    .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
                }

                // PRs
                let prs = post.getFeedPRs()
                if !prs.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Personal Records")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(offWhite)

                        ForEach(prs) { pr in
                            HStack {
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(GQGradients.primary)

                                Text(pr.exerciseName)
                                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                                    .foregroundColor(offWhite)

                                Spacer()

                                Text(pr.value)
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundStyle(GQGradients.primary)
                            }
                            .padding(20)
                            .background(RoundedRectangle(cornerRadius: 18).fill(Color(white: 0.18)))
                        }
                    }
                }

                // Shared workout
                if let workout = post.getSharedWorkout() {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(workout.title)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(offWhite)

                        ForEach(workout.exercises) { exercise in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(exercise.name)
                                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                                    .foregroundColor(offWhite)

                                ForEach(Array(exercise.sets.enumerated()), id: \.offset) { index, set in
                                    HStack {
                                        Text("Set \(index + 1)")
                                            .foregroundColor(offWhite.opacity(0.4))
                                            .frame(width: 80, alignment: .leading)
                                        Text("\(set.reps) reps")
                                            .foregroundColor(offWhite)
                                        Text("\u{00d7}")
                                            .foregroundColor(offWhite.opacity(0.3))
                                        Text("\(Int(set.weight)) lbs")
                                            .foregroundStyle(GQGradients.primary)
                                        Spacer()
                                    }
                                    .font(.system(size: 24, weight: .medium, design: .rounded))
                                }
                            }
                            .padding(20)
                            .background(RoundedRectangle(cornerRadius: 18).fill(Color(white: 0.18)))
                        }
                    }
                }

                // Engagement
                HStack(spacing: 40) {
                    engagementBlock(icon: "heart.fill", count: post.likeCount, label: "Likes", color: offWhite.opacity(0.6))
                    engagementBlock(icon: "bubble.left.fill", count: post.commentCount, label: "Comments", color: offWhite.opacity(0.6))
                    engagementBlock(icon: "eye.fill", count: post.viewCount, label: "Views", color: offWhite.opacity(0.6))
                    engagementBlock(icon: "arrow.turn.up.right", count: post.shareCount, label: "Shares", color: offWhite.opacity(0.6))
                }
                .padding(.top, 16)
            }
            .padding(80)
        }
        .background(Color(white: 0.11).ignoresSafeArea())
    }

    @ViewBuilder
    private func detailStat(value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(offWhite)
            Text(label.uppercased())
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(offWhite.opacity(0.35))
                .tracking(1)
        }
    }

    @ViewBuilder
    private func engagementBlock(icon: String, count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            Text(formatCount(count))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(offWhite)
            Text(label)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundColor(offWhite.opacity(0.4))
        }
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(minutes)m"
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    private func timeAgoLong(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    TVFeedView()
        .modelContainer(for: [Post.self, Friend.self, UserProfile.self], inMemory: true)
}

#endif
