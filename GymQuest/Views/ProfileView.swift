//
//  ProfileView.swift
//  GymQuest
//
//  Created by Benjamin Hilderman
//
//  Bold & Energetic profile with glass morphism
//  Posts feed, level/XP stats, settings
//

import SwiftUI
import SwiftData
import AVKit
import PhotosUI
import Supabase

private let profileNeutralAccent = GQColors.overlayMedium
private let profilePrimaryAccent = GQColors.adaptiveOverlay(0.42)
private let profileFireAccent = GQColors.textSecondary

enum PostGridTab: Hashable { case photos, clips, tagged }

struct ProfileView: View {
    @Query(sort: \Post.timestamp, order: .reverse) private var posts: [Post]
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @Query(sort: \PREvent.date, order: .reverse) private var prEvents: [PREvent]

    @Environment(\.modelContext) private var modelContext

    let profile: UserProfile

    @StateObject private var healthKit = HealthKitService.shared
    @State private var showingSettings = false
    @State private var selectedPost: Post?
    @State private var emotionInsightsExpanded = false
    @State private var postTab: PostGridTab = .photos
    @State private var showingCoach = false
    @State private var showingCalendarHistory = false
    @State private var showingHealthDashboard = false
    @State private var showingIntegrations = false

    // Activity stats state
    @State private var weeklyProgress: (completed: Int, target: Int) = (0, 0)
    @State private var readinessLevel: ReadinessLevel = .good

    // Profile photo picker
    @State private var selectedPhotoItem: PhotosPickerItem?

    // Cached computed stats (refreshed on appear and data change)
    @State private var cachedStreak: Int = 0
    @State private var cachedVolume: String = "0"
    @State private var cachedDuration: String = "0h"
    @State private var cachedWorkoutCount: Int = 0
    /// Total reactions received across all of this user's posts. The memo's
    /// "social proof that others saw it" signal — the witness count.
    @State private var cachedWitnessCount: Int = 0
    /// Count of distinct calendar days the user has logged a workout.
    /// This is the "days shown up" metric the memo names explicitly.
    @State private var cachedDaysShownUp: Int = 0
    /// Count of times other users have copied this user's workouts into a live session.
    @State private var cachedUsedCount: Int = 0

    private var profileAccent: Color {
        profileNeutralAccent
    }

    private var userPosts: [Post] {
        let targetUsername = profile.username.lowercased()
        let targetName = profile.name.lowercased()

        return posts.filter { post in
            (post.authorId == profile.id ||
            post.authorUsername.lowercased() == targetUsername ||
            post.authorName.lowercased() == targetName) &&
            (post.photoData != nil || post.videoData != nil || !post.mediaItems.isEmpty)
        }
        .sorted { $0.timestamp > $1.timestamp }
    }

    private func postHasVideo(_ post: Post) -> Bool {
        post.videoData != nil || post.mediaItems.contains { $0.mediaType == .video }
    }

    /// A post is "multi" only when it holds more than one PostMedia item — a
    /// carousel in the modern sense. Legacy photoData used as a cover for a
    /// single video does NOT count as a second media.
    private func postIsMulti(_ post: Post) -> Bool {
        post.mediaItems.count > 1
    }

    /// True when the post's primary content is a video (videoData set, or a
    /// single video PostMedia item), even if photoData holds a cover
    /// thumbnail.
    private func postIsSingleVideo(_ post: Post) -> Bool {
        guard !postIsMulti(post) else { return false }
        return post.videoData != nil || post.mediaItems.contains(where: { $0.mediaType == .video })
    }

    private var photoPosts: [Post] {
        userPosts.filter { post in
            post.photoData != nil ||
            post.mediaItems.contains { $0.mediaType == .photo }
        }
    }

    private var clipPosts: [Post] {
        userPosts.filter { postIsSingleVideo($0) }
    }

    private var taggedPosts: [Post] {
        let targetUsername = profile.username.lowercased()
        return posts.filter { post in
            post.authorUsername.lowercased() != targetUsername &&
            post.authorId != profile.id &&
            (post.taggedUsernames.contains(where: { $0.lowercased() == targetUsername }) ||
             post.taggedUsernames.contains(where: { $0.lowercased() == profile.name.lowercased() })) &&
            (post.photoData != nil || post.videoData != nil || !post.mediaItems.isEmpty)
        }
        .sorted { $0.timestamp > $1.timestamp }
    }

    private var totalWorkoutCount: Int { cachedWorkoutCount }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 12) {
                        profileHeader
                        if isOwnProfile { profileCompletionBanner }
                        achievementBadgesSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, GQLayout.pageTop)

                    // Posts grid — edge-to-edge like Instagram
                    postsContent
                        .padding(.top, 4)
                        .padding(.bottom, GQLayout.pageBottom)
                }
            }
            .scrollContentBackground(.hidden)
            .gqPageBackground()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 4) {
                        Text("@\(profile.username)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(GQColors.textPrimary)
                        if profile.isPremium {
                            PremiumBadge(size: 16)
                        }
                    }
                }
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(GQColors.textPrimary)
                            .frame(width: 34, height: 34)
                            .background(GQColors.overlayLight)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                #endif
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showingSettings) {
                SettingsView(profile: profile)
            }
            .tint(GQColors.textPrimary)
            .fullScreenCover(
                isPresented: Binding(
                    get: { selectedPost != nil },
                    set: { isPresented in
                        if !isPresented { selectedPost = nil }
                    }
                )
            ) {
                if let selectedPost {
                    ProfilePostBrowserView(
                        profile: profile,
                        photoPosts: photoPosts,
                        clipPosts: clipPosts,
                        taggedPosts: taggedPosts,
                        initialTab: postTab,
                        initialPostId: selectedPost.id
                    )
                }
            }
            .sheet(isPresented: $showingCoach) {
                CoachView(profile: profile, workouts: Array(workouts), aiService: AIService())
            }
            .onAppear {
                refreshProfileStats()
                loadProfileActivityData()
            }
            .onChange(of: workouts.count) { _, _ in
                refreshProfileStats()
            }
        }
    }

    // MARK: - AI Coach Card

    private var aiCoachCard: some View {
        Button {
            showingCoach = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(GQColors.textSecondary.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(GQColors.textSecondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Coach")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                    Text("Chat, plans & form analysis")
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(GQColors.textTertiary)
            }
            .padding(12)
            .homeSocialCard(cornerRadius: 14)
        }
        .buttonStyle(GQInteractiveStyle())
    }

    // MARK: - Activity Stats (merged from ActivityView)

    @ViewBuilder
    private var profileWeeklyProgress: some View {
        Button {
            showingCalendarHistory = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(GQColors.deepBlue)
                    .frame(width: 36, height: 36)
                    .background(GQColors.deepBlue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Workout Calendar")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                    Text("\(weeklyProgress.completed) of \(weeklyProgress.target) this week")
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(GQColors.textTertiary)
            }
            .padding(14)
            .homeSocialCard(cornerRadius: 14)
        }
        .buttonStyle(GQInteractiveStyle())
        .sheet(isPresented: $showingCalendarHistory) {
            CalendarHistoryView(workouts: workouts)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var progressSummaryRow: some View {
        HStack(spacing: 0) {
            summaryStatItem(value: "\(cachedWorkoutCount)", label: "Workouts")

            Rectangle()
                .fill(GQColors.borderSubtle)
                .frame(width: 1, height: 32)

            summaryStatItem(value: cachedVolume, label: "Volume")

            Rectangle()
                .fill(GQColors.borderSubtle)
                .frame(width: 1, height: 32)

            summaryStatItem(value: cachedDuration, label: "Duration")
        }
        .padding(.vertical, 14)
        .homeSocialCard(cornerRadius: 14)
    }

    private func summaryStatItem(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(GQColors.textPrimary)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Cached Stats Refresh

    private func refreshProfileStats() {
        let nonRest = workouts.filter { $0.type != .rest }
        cachedWorkoutCount = nonRest.count

        // Streak calculation — mercy-aware (memo 4 directive).
        // A streak continues through gaps of 1 day (grace day). A gap of 2+ breaks it.
        // This means: Mon/Tue/Thu/Fri is a 4-day streak (Wed was a grace day),
        // but Mon/Tue/Fri is broken at Wed→Thu (2-day gap).
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let sortedDates = nonRest
            .map { calendar.startOfDay(for: $0.date) }

        let uniqueDates = Array(Set(sortedDates)).sorted(by: >)
        if let first = uniqueDates.first {
            let daysSinceFirst = calendar.dateComponents([.day], from: first, to: today).day ?? 0
            if daysSinceFirst <= 2 {  // allow 1-day grace gap
                var streak = 1
                for i in 1..<uniqueDates.count {
                    let diff = calendar.dateComponents([.day], from: uniqueDates[i], to: uniqueDates[i - 1]).day ?? 0
                    if diff <= 2 {  // consecutive (1) or one grace day (2)
                        streak += 1
                    } else {
                        break
                    }
                }
                cachedStreak = streak
            } else {
                cachedStreak = 0
            }
        } else {
            cachedStreak = 0
        }

        // Volume
        let volume = workouts.reduce(0.0) { $0 + $1.totalVolume }
        if volume >= 1_000_000 {
            cachedVolume = String(format: "%.1fM", volume / 1_000_000)
        } else if volume >= 1_000 {
            cachedVolume = String(format: "%.1fk", volume / 1_000)
        } else {
            cachedVolume = "\(Int(volume))"
        }

        // Duration
        let totalMinutes = workouts.reduce(0) { $0 + $1.duration }
        let hours = totalMinutes / 60
        if hours >= 1000 {
            cachedDuration = String(format: "%.1fk", Double(hours) / 1000)
        } else {
            cachedDuration = "\(hours)h"
        }

        // Days shown up — distinct calendar days with at least one logged workout.
        // Unlike "total workouts," this naturally caps at 1 per day and matches
        // the memo's consistency framing.
        let distinctDays = Set(nonRest.map { Calendar.current.startOfDay(for: $0.date) })
        cachedDaysShownUp = distinctDays.count

        // Witness count — total reactions received across all of this user's posts.
        // This is the "social proof that others saw it" signal the memo names.
        cachedWitnessCount = userPosts.reduce(0) { $0 + $1.likeCount }

        // Used count — sum of times any of this user's workouts has been copied
        // into another user's session. The highest-signal recognition.
        cachedUsedCount = userPosts.reduce(0) { $0 + $1.timesUsed }
    }

    private var recentPRs: [PREvent] {
        Array(prEvents.prefix(3))
    }

    private func prValueFormatted(_ pr: PREvent) -> String {
        switch pr.prType {
        case .weightPR:
            return "\(Int(pr.newValue)) lbs"
        case .repPR:
            return "\(Int(pr.newValue)) reps"
        case .volumePR:
            if pr.newValue >= 1000 {
                return String(format: "%.1fk", pr.newValue / 1000)
            }
            return "\(Int(pr.newValue))"
        case .estimated1RMPR:
            return "\(Int(pr.newValue)) lbs"
        }
    }

    // MARK: - Activity Data Loading

    private func loadProfileActivityData() {
        let calendar = Calendar.current
        let weekStart = calendar.startOfWeek(for: Date())
        let weeklyWorkouts = workouts.filter { $0.date >= weekStart }
        weeklyProgress = (weeklyWorkouts.count, profile.daysPerWeek)

        readinessLevel = determineReadiness()
    }

    private func determineReadiness() -> ReadinessLevel {
        let integration = IntegrationManager.shared
        if integration.hasAnyConnection && integration.recoveryScore > 0 {
            return integration.readinessLevel
        }

        let calendar = Calendar.current
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: Date()) ?? Date()
        let recentWorkouts = workouts.filter { $0.date >= threeDaysAgo }

        if recentWorkouts.count >= 3 {
            let avgRPE = Double(recentWorkouts.reduce(0) { $0 + $1.rpe }) / Double(recentWorkouts.count)
            if avgRPE >= 8 { return .low }
        }

        if recentWorkouts.isEmpty { return .optimal }

        return .good
    }

    private func logRestDay() {
        let restWorkout = Workout(
            date: Date(),
            type: .rest,
            duration: 0,
            rpe: 1,
            notes: "Rest day",
            exercises: [],
            title: "Rest Day",
            source: .manual,
            privacy: .privateOnly
        )
        modelContext.insert(restWorkout)
        try? modelContext.save()
        loadProfileActivityData()
    }

    // MARK: - Profile Completion

    private var profileCompletionFields: [(String, Bool)] {
        [
            ("Photo", profile.profilePhotoData != nil),
            ("Gym Name", !profile.gymName.isEmpty),
            ("Equipment", !profile.availableEquipment.isEmpty),
            ("Experience", profile.experienceLevel != nil)
        ]
    }

    private var profileCompletionPercent: Int {
        let fields = profileCompletionFields
        let completed = fields.filter(\.1).count
        return Int(Double(completed) / Double(fields.count) * 100)
    }

    private var isProfileComplete: Bool {
        profileCompletionPercent >= 100
    }

    @ViewBuilder
    private var profileCompletionBanner: some View {
        if !isProfileComplete {
            Button {
                showingSettings = true
            } label: {
                HStack(spacing: 12) {
                    // Progress ring
                    ZStack {
                        Circle()
                            .stroke(GQColors.overlayLight, lineWidth: 3)
                            .frame(width: 38, height: 38)
                        Circle()
                            .trim(from: 0, to: Double(profileCompletionPercent) / 100.0)
                            .stroke(GQGradients.primary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 38, height: 38)
                            .rotationEffect(.degrees(-90))
                        Text("\(profileCompletionPercent)%")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(GQColors.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Complete your profile")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(GQColors.textPrimary)
                        let missing = profileCompletionFields.filter { !$0.1 }.map(\.0)
                        Text("Add: \(missing.joined(separator: ", "))")
                            .font(.system(size: 11))
                            .foregroundColor(GQColors.textTertiary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(GQColors.textTertiary)
                }
                .padding(12)
                .homeSocialCard(accent: GQColors.deepBlue, subtle: true)
            }
            .buttonStyle(GQInteractiveStyle())
        }
    }

    // MARK: - Profile Header

    // MARK: - Today Health Stats Card

    @ViewBuilder
    private var todayHealthStatsCard: some View {
        if healthKit.isAuthorized {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("TODAY")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(GQColors.sectionLabel)
                        .tracking(0.6)

                    Spacer()

                    Button {
                        showingHealthDashboard = true
                    } label: {
                        Text("See All")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(GQColors.textSecondary)
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    healthStatPill(icon: "figure.walk", value: "\(healthKit.steps)", label: "Steps", color: GQColors.textSecondary)
                    healthStatPill(icon: "flame.fill", value: "\(healthKit.activeCalories)", label: "Active Cal", color: GQColors.textSecondary)
                    healthStatPill(icon: "bed.double.fill", value: String(format: "%.1fh", healthKit.sleepHours), label: "Sleep", color: GQColors.textSecondary)
                    healthStatPill(icon: "figure.run", value: "\(healthKit.exerciseMinutes)m", label: "Exercise", color: GQColors.textSecondary)
                }
            }
            .padding(12)
            .homeSocialCard(cornerRadius: 14)
            .sheet(isPresented: $showingHealthDashboard) {
                NavigationStack {
                    HealthDashboardView(profile: profile, workouts: Array(workouts))
                }
            }
        } else {
            Button {
                showingIntegrations = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 16))
                        .foregroundColor(GQColors.textSecondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Connect Apple Health")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(GQColors.textPrimary)
                        Text("Track steps, sleep, calories & more")
                            .font(.system(size: 11))
                            .foregroundColor(GQColors.textTertiary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(GQColors.textTertiary)
                }
                .padding(12)
                .homeSocialCard(cornerRadius: 14)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingIntegrations) {
                NavigationStack {
                    IntegrationsView(profile: profile)
                }
            }
        }
    }

    @ViewBuilder
    private func healthStatPill(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(GQColors.textPrimary)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(GQColors.textTertiary)
            }
            Spacer()
        }
        .padding(8)
        .background(GQColors.adaptiveOverlay(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - 50 Header Variants Preview

    private var profileHeaderVariantsPreview: some View {
        VStack(spacing: 10) {
            ForEach(1...50, id: \.self) { n in
                VStack(alignment: .leading, spacing: 6) {
                    Text("V\(n) · \(variantLabel(n))")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.5)
                        .foregroundColor(GQColors.textTertiary)
                        .padding(.leading, 4)
                    headerVariant(n)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(GQColors.surfaceBase))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(GQColors.borderSubtle, lineWidth: 0.5))
                }
            }
        }
    }

    private func variantLabel(_ n: Int) -> String {
        let labels: [String] = [
            "Baseline IG-style",
            "Mirrored (avatar right)",
            "Avatar top-center, stats below",
            "Avatar top-left alone, name+stats under",
            "Inline row — avatar+name+stats",
            "Centered stack (avatar > name > stats)",
            "Avatar card + stats card",
            "Hero avatar with name overlay",
            "Compact avatar+name, stats below",
            "Hero size avatar (120pt)",
            "Tiny 36pt avatar, big name",
            "56pt avatar + large name",
            "72pt avatar + medium name",
            "100pt avatar + small name",
            "128pt avatar, name below",
            "No border avatar",
            "Thin 1pt gradient border",
            "Thick 3pt gradient border",
            "Double concentric ring",
            "Halo glow backing",
            "Streak progress ring on avatar",
            "Shadow only, no border",
            "Dashed gradient stroke",
            "Solid brand color ring",
            "Metallic gradient shine",
            "Standard 3 IG columns",
            "4 stats columns",
            "Stats with SF icons",
            "Stats as capsule pills",
            "Stats as 2×2 mini cards",
            "Stats with caps labels on top",
            "Stats with progress bars",
            "Stats stacked vertically",
            "Single-line stats summary",
            "2×2 stats grid card",
            "Large 24pt bold title name",
            "Small 13pt caption name",
            "Gradient text on name",
            "Name inline with flame pill",
            "Name + @username below",
            "Name + level badge inline",
            "Name centered under avatar",
            "Name in its own tinted card",
            "Mission-line quote under name",
            "Name + bio preview",
            "Full-width Edit button",
            "Inline 'edit' chip next to name",
            "Pencil icon top-right",
            "Tap-avatar-to-edit (no button)",
            "Split actions bar (Edit · Share)",
        ]
        return labels[n - 1]
    }

    // Shared compact helpers
    private func miniAvatar(size: CGFloat, borderStyle: Int = 1) -> some View {
        ZStack {
            Circle()
                .fill(GQGradients.primary.opacity(0.12))
                .frame(width: size, height: size)
                .overlay(avatarBorder(size: size, style: borderStyle))
            if let d = profile.profilePhotoData, let img = uiImageFromData(d) {
                Image(uiImage: img).resizable().scaledToFill().frame(width: size, height: size).clipShape(Circle())
            } else {
                Text(String(profile.name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.40, weight: .bold, design: .rounded))
                    .foregroundStyle(GQGradients.primary)
            }
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private func avatarBorder(size: CGFloat, style: Int) -> some View {
        switch style {
        case 0: EmptyView()
        case 1: Circle().stroke(GQGradients.primary, lineWidth: 1)
        case 2: Circle().stroke(GQGradients.primary, lineWidth: 2.5)
        case 3:
            Circle().stroke(GQGradients.primary, lineWidth: 1.5).overlay(Circle().stroke(GQGradients.primary.opacity(0.3), lineWidth: 0.5).padding(4))
        case 4:
            Circle().stroke(GQGradients.primary, lineWidth: 2).background(Circle().fill(GQGradients.primary.opacity(0.22)).blur(radius: 10).frame(width: size + 10, height: size + 10))
        case 5:
            Circle().trim(from: 0, to: min(Double(cachedStreak) / 7.0, 1.0)).stroke(GQGradients.primary, style: StrokeStyle(lineWidth: 2.5, lineCap: .round)).rotationEffect(.degrees(-90)).overlay(Circle().stroke(GQColors.deepBlue.opacity(0.08), lineWidth: 2.5))
        case 6:
            Circle().stroke(Color.clear, lineWidth: 0).shadow(color: GQColors.vividPurple.opacity(0.25), radius: 8, y: 3)
        case 7:
            Circle().stroke(GQGradients.primary, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
        case 8:
            Circle().stroke(GQColors.vividPurple, lineWidth: 2)
        case 9:
            Circle().stroke(LinearGradient(colors: [.white.opacity(0.6), GQColors.vividPurple, GQColors.deepBlue], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
        default: Circle().stroke(GQGradients.primary, lineWidth: 1.5)
        }
    }

    private func statCol(_ value: String, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(value).font(.system(size: 15, weight: .bold)).foregroundColor(GQColors.textPrimary)
            Text(label).font(.system(size: 10)).foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func capsStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(label.uppercased()).font(.system(size: 9, weight: .semibold)).tracking(0.8).foregroundColor(GQColors.textTertiary)
            Text(value).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(GQColors.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    private var flamePill: some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill").font(.system(size: 11)).foregroundStyle(LinearGradient(colors: [.orange, .red.opacity(0.85)], startPoint: .bottom, endPoint: .top))
            Text("\(cachedStreak)").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(GQColors.textPrimary)
        }
        .padding(.horizontal, 7).padding(.vertical, 2)
        .background(Capsule().fill(GQColors.adaptiveOverlay(0.05)))
    }

    private func pill(_ text: String) -> some View {
        Text(text).font(.system(size: 11, weight: .medium)).foregroundColor(GQColors.textSecondary).padding(.horizontal, 8).padding(.vertical, 4).background(Capsule().fill(GQColors.adaptiveOverlay(0.05)))
    }

    private func smallEditButton() -> some View {
        Text("Edit Profile").font(.system(size: 13, weight: .semibold)).foregroundColor(GQColors.textPrimary).frame(maxWidth: .infinity).padding(.vertical, 8).background(RoundedRectangle(cornerRadius: 8).fill(GQColors.adaptiveOverlay(0.05)))
    }

    private func uiImageFromData(_ data: Data) -> UIImage? {
        #if canImport(UIKit)
        return UIImage(data: data)
        #else
        return nil
        #endif
    }

    @ViewBuilder
    private func headerVariant(_ n: Int) -> some View {
        let name = profile.name
        let username = profile.username
        let days = "\(cachedDaysShownUp)"
        let followers = "\(profile.followerCount)"
        let following = "\(profile.followingCount)"
        let level = "Lv.\(profile.level)"

        switch n {
        case 1:
            HStack(spacing: 16) {
                miniAvatar(size: 72)
                HStack(spacing: 0) { statCol(days, "Days"); statCol(following, "Following"); statCol(followers, "Followers") }
            }
        case 2:
            HStack(spacing: 16) {
                HStack(spacing: 0) { statCol(days, "Days"); statCol(following, "Following"); statCol(followers, "Followers") }
                miniAvatar(size: 72)
            }
        case 3:
            VStack(spacing: 10) {
                miniAvatar(size: 72)
                HStack(spacing: 0) { statCol(days, "Days"); statCol(following, "Following"); statCol(followers, "Followers") }
            }
        case 4:
            VStack(alignment: .leading, spacing: 10) {
                miniAvatar(size: 72)
                Text(name).font(.system(size: 17, weight: .bold))
                HStack(spacing: 0) { statCol(days, "Days"); statCol(following, "Following"); statCol(followers, "Followers") }
            }
        case 5:
            HStack(spacing: 10) {
                miniAvatar(size: 44)
                Text(name).font(.system(size: 14, weight: .semibold))
                Spacer()
                HStack(spacing: 10) {
                    Text(days).font(.system(size: 12, weight: .bold)) + Text(" days").font(.system(size: 11)).foregroundColor(GQColors.textTertiary)
                    Text(followers).font(.system(size: 12, weight: .bold)) + Text(" flw").font(.system(size: 11)).foregroundColor(GQColors.textTertiary)
                }
            }
        case 6:
            VStack(spacing: 8) {
                miniAvatar(size: 80)
                Text(name).font(.system(size: 18, weight: .bold))
                HStack(spacing: 16) { statCol(days, "Days"); statCol(following, "Following"); statCol(followers, "Followers") }
            }.frame(maxWidth: .infinity)
        case 7:
            HStack(spacing: 10) {
                miniAvatar(size: 60).padding(10).background(RoundedRectangle(cornerRadius: 12).fill(GQColors.adaptiveOverlay(0.03)))
                VStack(spacing: 4) {
                    Text(name).font(.system(size: 14, weight: .bold))
                    HStack(spacing: 12) { statCol(days, "Days"); statCol(followers, "Flw") }
                }.padding(8).background(RoundedRectangle(cornerRadius: 12).fill(GQColors.adaptiveOverlay(0.03)))
            }
        case 8:
            ZStack {
                miniAvatar(size: 110)
                VStack(spacing: 0) {
                    Text(name).font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                    Text("@\(username)").font(.system(size: 10)).foregroundColor(.white.opacity(0.85))
                }.padding(6).background(Capsule().fill(Color.black.opacity(0.45)))
            }.frame(maxWidth: .infinity)
        case 9:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) { miniAvatar(size: 44); Text(name).font(.system(size: 14, weight: .bold)); flamePill; Spacer() }
                HStack(spacing: 0) { statCol(days, "Days"); statCol(following, "Following"); statCol(followers, "Followers") }
            }
        case 10:
            VStack(spacing: 8) { miniAvatar(size: 120); Text(name).font(.system(size: 18, weight: .bold)) }.frame(maxWidth: .infinity)
        case 11:
            HStack(spacing: 12) { miniAvatar(size: 36); Text(name).font(.system(size: 22, weight: .bold)); Spacer() }
        case 12:
            HStack(spacing: 12) { miniAvatar(size: 56); Text(name).font(.system(size: 20, weight: .bold)); Spacer() }
        case 13:
            HStack(spacing: 14) { miniAvatar(size: 72); VStack(alignment: .leading) { Text(name).font(.system(size: 17, weight: .bold)); Text(level).font(.system(size: 11)).foregroundColor(GQColors.textTertiary) }; Spacer() }
        case 14:
            HStack(spacing: 14) { miniAvatar(size: 100); VStack(alignment: .leading) { Text(name).font(.system(size: 14, weight: .bold)); flamePill }; Spacer() }
        case 15:
            VStack(spacing: 8) { miniAvatar(size: 128); Text(name).font(.system(size: 20, weight: .bold)) }.frame(maxWidth: .infinity)
        case 16:
            HStack(spacing: 12) { miniAvatar(size: 72, borderStyle: 0); statCol(days, "Days"); statCol(followers, "Followers") }
        case 17:
            HStack(spacing: 12) { miniAvatar(size: 72, borderStyle: 1); statCol(days, "Days"); statCol(followers, "Followers") }
        case 18:
            HStack(spacing: 12) { miniAvatar(size: 72, borderStyle: 2); statCol(days, "Days"); statCol(followers, "Followers") }
        case 19:
            HStack(spacing: 12) { miniAvatar(size: 72, borderStyle: 3); statCol(days, "Days"); statCol(followers, "Followers") }
        case 20:
            HStack(spacing: 12) { miniAvatar(size: 72, borderStyle: 4); statCol(days, "Days"); statCol(followers, "Followers") }
        case 21:
            HStack(spacing: 12) { miniAvatar(size: 72, borderStyle: 5); VStack(alignment: .leading) { Text(name).font(.system(size: 14, weight: .bold)); Text("streak \(cachedStreak)/7").font(.system(size: 10)).foregroundColor(GQColors.textTertiary) }; Spacer() }
        case 22:
            HStack(spacing: 12) { miniAvatar(size: 72, borderStyle: 6); statCol(days, "Days"); statCol(followers, "Followers") }
        case 23:
            HStack(spacing: 12) { miniAvatar(size: 72, borderStyle: 7); statCol(days, "Days"); statCol(followers, "Followers") }
        case 24:
            HStack(spacing: 12) { miniAvatar(size: 72, borderStyle: 8); statCol(days, "Days"); statCol(followers, "Followers") }
        case 25:
            HStack(spacing: 12) { miniAvatar(size: 72, borderStyle: 9); statCol(days, "Days"); statCol(followers, "Followers") }
        case 26:
            HStack(spacing: 14) { miniAvatar(size: 72); HStack(spacing: 0) { statCol(days, "Days"); statCol(following, "Following"); statCol(followers, "Followers") } }
        case 27:
            HStack(spacing: 14) { miniAvatar(size: 64); HStack(spacing: 0) { statCol(days, "Days"); statCol("\(cachedStreak)", "Streak"); statCol(following, "Flwg"); statCol(followers, "Flwrs") } }
        case 28:
            HStack(spacing: 14) {
                miniAvatar(size: 64)
                HStack(spacing: 14) {
                    HStack(spacing: 4) { Image(systemName: "calendar").font(.system(size: 11)).foregroundStyle(GQGradients.primary); Text(days).font(.system(size: 13, weight: .semibold)) }
                    HStack(spacing: 4) { Image(systemName: "person.2.fill").font(.system(size: 11)).foregroundStyle(GQGradients.primary); Text(followers).font(.system(size: 13, weight: .semibold)) }
                }
                Spacer()
            }
        case 29:
            HStack(spacing: 10) { miniAvatar(size: 60); pill("\(days) days"); pill("\(followers) flwrs"); Spacer() }
        case 30:
            VStack(spacing: 8) {
                miniAvatar(size: 64)
                HStack(spacing: 8) {
                    VStack { Text(days).font(.system(size: 14, weight: .bold)); Text("Days").font(.system(size: 9)).foregroundColor(GQColors.textTertiary) }.padding(8).frame(maxWidth: .infinity).background(RoundedRectangle(cornerRadius: 10).fill(GQColors.adaptiveOverlay(0.03)))
                    VStack { Text(followers).font(.system(size: 14, weight: .bold)); Text("Flwrs").font(.system(size: 9)).foregroundColor(GQColors.textTertiary) }.padding(8).frame(maxWidth: .infinity).background(RoundedRectangle(cornerRadius: 10).fill(GQColors.adaptiveOverlay(0.03)))
                }
            }.frame(maxWidth: .infinity)
        case 31:
            HStack(spacing: 14) { miniAvatar(size: 72); HStack(spacing: 0) { capsStat(days, "Days"); capsStat(following, "Flwg"); capsStat(followers, "Flwrs") } }
        case 32:
            VStack(spacing: 8) {
                HStack { miniAvatar(size: 56); Text(name).font(.system(size: 16, weight: .bold)); Spacer() }
                HStack(spacing: 8) {
                    progressStatPill(label: "Streak", value: cachedStreak, goal: 7)
                    progressStatPill(label: "Days", value: cachedDaysShownUp, goal: 30)
                }
            }
        case 33:
            HStack(spacing: 16) {
                miniAvatar(size: 88)
                VStack(alignment: .leading, spacing: 2) {
                    Text(days).font(.system(size: 14, weight: .bold)) + Text(" days").font(.system(size: 11)).foregroundColor(GQColors.textTertiary)
                    Text(following).font(.system(size: 14, weight: .bold)) + Text(" following").font(.system(size: 11)).foregroundColor(GQColors.textTertiary)
                    Text(followers).font(.system(size: 14, weight: .bold)) + Text(" followers").font(.system(size: 11)).foregroundColor(GQColors.textTertiary)
                }
                Spacer()
            }
        case 34:
            HStack(spacing: 12) { miniAvatar(size: 72); Text("\(days) days · \(following) flwg · \(followers) flwrs").font(.system(size: 12)).foregroundColor(GQColors.textSecondary); Spacer() }
        case 35:
            VStack(spacing: 8) {
                miniAvatar(size: 64)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    statCol(days, "Days"); statCol("\(cachedStreak)", "Streak"); statCol(following, "Following"); statCol(followers, "Followers")
                }
            }
        case 36:
            HStack(spacing: 14) { miniAvatar(size: 72); VStack(alignment: .leading) { Text(name).font(.system(size: 24, weight: .bold)); Text("@\(username)").font(.system(size: 12)).foregroundColor(GQColors.textTertiary) }; Spacer() }
        case 37:
            HStack(spacing: 14) { miniAvatar(size: 80); VStack(alignment: .leading) { Text(name).font(.system(size: 13, weight: .medium)); Text("@\(username)").font(.system(size: 11)).foregroundColor(GQColors.textTertiary) }; Spacer() }
        case 38:
            HStack(spacing: 14) { miniAvatar(size: 72); Text(name).font(.system(size: 20, weight: .bold)).foregroundStyle(GQGradients.primary); Spacer() }
        case 39:
            HStack(spacing: 10) { miniAvatar(size: 60); Text(name).font(.system(size: 16, weight: .bold)); flamePill; Spacer() }
        case 40:
            HStack(spacing: 12) { miniAvatar(size: 64); VStack(alignment: .leading, spacing: 0) { Text(name).font(.system(size: 16, weight: .bold)); Text("@\(username)").font(.system(size: 11)).foregroundColor(GQColors.textTertiary) }; Spacer() }
        case 41:
            HStack(spacing: 10) { miniAvatar(size: 60); Text(name).font(.system(size: 15, weight: .bold)); pill(level); Spacer() }
        case 42:
            VStack(spacing: 6) { miniAvatar(size: 72); Text(name).font(.system(size: 16, weight: .bold)); Text("@\(username)").font(.system(size: 11)).foregroundColor(GQColors.textTertiary) }.frame(maxWidth: .infinity)
        case 43:
            VStack(spacing: 10) {
                miniAvatar(size: 72)
                HStack { Text(name).font(.system(size: 15, weight: .bold)); Spacer(); flamePill }.padding(10).frame(maxWidth: .infinity).background(RoundedRectangle(cornerRadius: 12).fill(GQColors.adaptiveOverlay(0.03)))
            }
        case 44:
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) { miniAvatar(size: 60); Text(name).font(.system(size: 15, weight: .bold)); Spacer() }
                Text("Showing up for \(profile.showUpFor.isEmpty ? "my goals" : profile.showUpFor)").font(.system(size: 12)).italic().foregroundColor(GQColors.textSecondary)
            }
        case 45:
            HStack(spacing: 12) { miniAvatar(size: 60); VStack(alignment: .leading) { Text(name).font(.system(size: 15, weight: .bold)); Text(profile.showUpFor.isEmpty ? "Add a bio…" : profile.showUpFor).font(.system(size: 11)).foregroundColor(GQColors.textTertiary).lineLimit(2) }; Spacer() }
        case 46:
            VStack(spacing: 10) { HStack { miniAvatar(size: 64); VStack(alignment: .leading) { Text(name).font(.system(size: 15, weight: .bold)); Text(level).font(.system(size: 11)).foregroundColor(GQColors.textTertiary) }; Spacer() }; smallEditButton() }
        case 47:
            HStack(spacing: 10) { miniAvatar(size: 60); HStack(spacing: 6) { Text(name).font(.system(size: 15, weight: .bold)); Text("edit").font(.system(size: 10, weight: .medium)).foregroundColor(GQColors.vividPurple).padding(.horizontal, 6).padding(.vertical, 2).background(Capsule().fill(GQColors.vividPurple.opacity(0.1))) }; Spacer() }
        case 48:
            HStack(spacing: 12) { miniAvatar(size: 64); Text(name).font(.system(size: 15, weight: .bold)); Spacer(); Image(systemName: "pencil").font(.system(size: 13, weight: .semibold)).foregroundColor(GQColors.textSecondary).frame(width: 30, height: 30).background(Circle().fill(GQColors.adaptiveOverlay(0.05))) }
        case 49:
            HStack(spacing: 12) { miniAvatar(size: 64).overlay(Circle().stroke(GQColors.vividPurple.opacity(0.3), lineWidth: 1).padding(-4)); VStack(alignment: .leading) { Text(name).font(.system(size: 15, weight: .bold)); Text("Tap avatar to edit").font(.system(size: 10)).foregroundColor(GQColors.textTertiary) }; Spacer() }
        case 50:
            VStack(spacing: 10) {
                HStack { miniAvatar(size: 64); VStack(alignment: .leading) { Text(name).font(.system(size: 15, weight: .bold)); flamePill }; Spacer() }
                HStack(spacing: 8) {
                    Text("Edit").font(.system(size: 12, weight: .semibold)).foregroundColor(GQColors.textPrimary).frame(maxWidth: .infinity).padding(.vertical, 7).background(RoundedRectangle(cornerRadius: 8).fill(GQColors.adaptiveOverlay(0.05)))
                    Text("Share").font(.system(size: 12, weight: .semibold)).foregroundColor(GQColors.textPrimary).frame(maxWidth: .infinity).padding(.vertical, 7).background(RoundedRectangle(cornerRadius: 8).fill(GQColors.adaptiveOverlay(0.05)))
                }
            }
        default:
            EmptyView()
        }
    }

    private func progressStatPill(label: String, value: Int, goal: Int) -> some View {
        let p = min(Double(value) / Double(max(goal, 1)), 1.0)
        return VStack(spacing: 3) {
            HStack { Text(label).font(.system(size: 10, weight: .semibold)).foregroundColor(GQColors.textSecondary); Spacer(); Text("\(value)/\(goal)").font(.system(size: 11, weight: .bold, design: .rounded)) }
            GeometryReader { g in ZStack(alignment: .leading) { Capsule().fill(GQColors.adaptiveOverlay(0.06)); Capsule().fill(GQGradients.primary).frame(width: g.size.width * CGFloat(p)) } }.frame(height: 4)
        }.padding(8).background(RoundedRectangle(cornerRadius: 10).fill(GQColors.adaptiveOverlay(0.03)))
    }

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Row 1: avatar (subtle camera) + Friends · Followers · Streak
            HStack(spacing: 16) {
                if isOwnProfile {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        profileAvatar
                            .overlay(alignment: .bottomTrailing) {
                                ZStack {
                                    Circle()
                                        .fill(GQColors.surfaceBase)
                                        .frame(width: 24, height: 24)
                                        .overlay(Circle().stroke(GQColors.borderSubtle, lineWidth: 0.5))
                                        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(GQColors.textSecondary)
                                }
                                .offset(x: 2, y: 2)
                            }
                    }
                    .buttonStyle(.plain)
                    .onChange(of: selectedPhotoItem) { _, newItem in
                        handleProfilePhotoSelection(newItem)
                    }
                } else {
                    profileAvatar
                }

                HStack(spacing: 0) {
                    igStatColumn(value: "\(profile.followingCount)", label: "Friends")
                    igStatColumn(value: "\(profile.followerCount)", label: "Followers")
                    streakStatColumn
                }
            }

            // Row 2: name + level + inline edit pencil
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(profile.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(GQColors.textPrimary)
                    if profile.isPremium {
                        PremiumBadge(size: 14)
                    }
                    Spacer(minLength: 0)
                }
            }

            // Row 3: mission line (promoted to 13pt medium, not italic)
            if !profile.showUpFor.trimmingCharacters(in: .whitespaces).isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "figure.2.arms.open")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(GQColors.vividPurple)
                    Text("Showing up for \(profile.showUpFor)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(GQColors.textSecondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                }
            }

            // Row 4: 30-day proof strip
            thirtyDayProofStrip

            // Used-by signal (if applicable)
            if cachedUsedCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(GQColors.success)
                    Text("\(cachedUsedCount) workout\(cachedUsedCount == 1 ? "" : "s") used by others")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(GQColors.textSecondary)
                }
            }

            // Equipment badges
            if !profile.availableEquipment.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(profile.availableEquipment, id: \.self) { eq in
                            Text(eq.rawValue)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(GQColors.deepBlue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(GQColors.deepBlue.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            // Visitor-only action row (Follow / Message)
            if !isOwnProfile {
                HStack(spacing: 8) {
                    Button { } label: {
                        Text("Follow")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(GQGradients.primary))
                    }
                    .buttonStyle(GQInteractiveStyle())
                    Button { } label: {
                        Text("Message")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(GQColors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(GQColors.borderDefault, lineWidth: 1))
                    }
                    .buttonStyle(GQInteractiveStyle())
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Identity computed props

    /// True when the viewer owns this profile. Currently derived from the
    /// app-level authenticated user id; defaults to true when no auth (single
    /// user shell, or dev mode).
    private var isOwnProfile: Bool {
        guard let currentId = SupabaseAuthService.shared.currentUserId else { return true }
        return currentId == profile.id
    }

    /// Top three signature-lift strings, e.g. "225 Bench". Computed from
    /// `prEvents` filtered to the user, grouped by exercise name, taking the
    /// heaviest recorded weight. Hidden entirely when the user has no PRs.
    private var signatureLifts: [String] {
        let targets: [(key: String, short: String)] = [
            ("Squat", "Squat"),
            ("Bench Press", "Bench"),
            ("Deadlift", "Deadlift"),
        ]
        var out: [String] = []
        for t in targets {
            let pr = prEvents
                .filter { $0.exerciseName.lowercased().contains(t.key.lowercased()) }
                .max(by: { $0.newValue < $1.newValue })
            if let pr, pr.newValue > 0 {
                out.append("\(Int(pr.newValue)) \(t.short)")
            }
        }
        return out
    }

    /// Boolean array length 30, newest day last, true when user has a non-rest
    /// workout logged on that calendar day.
    private var thirtyDayTraining: [Bool] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let coveredDays: Set<Date> = Set(
            workouts
                .filter { $0.type != .rest }
                .map { calendar.startOfDay(for: $0.date) }
        )
        return (0..<30).reversed().compactMap { offset -> Bool? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return coveredDays.contains(day)
        }
    }

    @ViewBuilder
    private var thirtyDayProofStrip: some View {
        let days = thirtyDayTraining
        let trained = days.filter { $0 }.count
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("LAST 30 DAYS")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.8)
                    .foregroundColor(GQColors.textTertiary)
                Spacer(minLength: 0)
                Text("\(trained)/30")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.4)
                    .foregroundColor(GQColors.textSecondary)
            }
            HStack(spacing: 3) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, trainedDay in
                    Capsule()
                        .fill(trainedDay ? AnyShapeStyle(GQGradients.primary.opacity(0.75)) : AnyShapeStyle(GQColors.adaptiveOverlay(0.06)))
                        .frame(height: 8)
                }
            }
        }
        .padding(.top, 2)
    }

    // MARK: - Achievement Badges (all visible, completed bright, locked greyed)

    @State private var selectedAchievement: ActiveChallenge? = nil

    struct ActiveChallenge: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let description: String
        let current: Int
        let target: Int
        let category: String
        var isComplete: Bool { current >= target }
        var progress: Double { target > 0 ? min(Double(current) / Double(target), 1.0) : 0 }
    }

    private var allAchievements: [ActiveChallenge] {
        [
            ActiveChallenge(icon: "figure.walk", title: "First Workout", description: "Log your first workout.", current: min(totalWorkoutCount, 1), target: 1, category: "General"),
            ActiveChallenge(icon: "dumbbell.fill", title: "10 Workouts", description: "Log 10 total workouts.", current: min(totalWorkoutCount, 10), target: 10, category: "General"),
            ActiveChallenge(icon: "trophy.fill", title: "100 Workouts", description: "Log 100 total workouts.", current: min(totalWorkoutCount, 100), target: 100, category: "General"),
            ActiveChallenge(icon: "flame.fill", title: "7-Day Streak", description: "Maintain a 7-day training streak.", current: min(cachedStreak, 7), target: 7, category: "General"),
            ActiveChallenge(icon: "flame.circle.fill", title: "30-Day Streak", description: "Maintain a 30-day streak.", current: min(cachedStreak, 30), target: 30, category: "General"),
            ActiveChallenge(icon: "star.fill", title: "PR Machine", description: "Hit 10 personal records.", current: min(prEvents.count, 10), target: 10, category: "General"),
            ActiveChallenge(icon: "bubble.left.and.bubble.right.fill", title: "Social Butterfly", description: "Share 10 workout posts.", current: min(userPosts.count, 10), target: 10, category: "General"),
            ActiveChallenge(icon: "person.2.fill", title: "Spotter", description: "Have 5 workouts used by others.", current: min(cachedUsedCount, 5), target: 5, category: "General"),
            ActiveChallenge(icon: "calendar.badge.checkmark", title: "Month Strong", description: "Show up on 20 distinct days.", current: min(cachedDaysShownUp, 20), target: 20, category: "General"),
        ].sorted { $0.isComplete && !$1.isComplete }
    }

    private var achievementBadgesSection: some View {
        let earned = allAchievements.filter { $0.isComplete }
        return Group {
            if !earned.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("ACHIEVEMENTS")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(0.8)
                            .foregroundColor(GQColors.textTertiary)
                        Text("\(earned.count)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(GQColors.textTertiary.opacity(0.7))
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 4)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(earned) { badge in
                                Button {
                                    selectedAchievement = badge
                                } label: {
                                    VStack(spacing: 6) {
                                        ZStack {
                                            Circle()
                                                .fill(GQGradients.primary.opacity(0.15))
                                                .frame(width: 40, height: 40)
                                            Image(systemName: badge.icon)
                                                .font(.system(size: 17))
                                                .foregroundStyle(GQGradients.primary)
                                        }
                                        Text(badge.title)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(GQColors.textPrimary)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.9)
                                    }
                                    .frame(width: 72)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
        }
        .sheet(item: $selectedAchievement) { badge in
            AchievementDetailSheet(badge: badge)
                .presentationDetents([.medium])
        }
    }

    // MARK: - (Top tab picker removed — single-level tabs now)

    private var streakStatColumn: some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(LinearGradient(colors: [.orange, .red.opacity(0.85)], startPoint: .bottom, endPoint: .top))
                Text("\(cachedStreak)")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(GQColors.textPrimary)
            }
            Text("Streak")
                .font(.system(size: 12))
                .foregroundColor(GQColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func igStatColumn(value: String, label: String) -> some View {
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

    private var profileAvatar: some View {
        ZStack {
            Circle()
                .stroke(GQGradients.primary, lineWidth: 2.5)
                .frame(width: 88, height: 88)

            Group {
                #if canImport(UIKit)
                if let photoData = profile.profilePhotoData, let image = UIImage(data: photoData) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    avatarInitial
                }
                #elseif canImport(AppKit)
                if let photoData = profile.profilePhotoData, let image = NSImage(data: photoData) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    avatarInitial
                }
                #else
                avatarInitial
                #endif
            }
            .frame(width: 82, height: 82)
            .clipShape(Circle())
        }
    }

    private var avatarInitial: some View {
        ZStack {
            Circle()
                .fill(GQColors.overlayLight)
            Text(String(profile.name.prefix(1)).uppercased())
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(GQColors.textPrimary)
        }
    }

    private func handleProfilePhotoSelection(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            await MainActor.run {
                profile.profilePhotoData = data
                try? modelContext.save()
            }

            // Upload to Supabase
            if FeatureFlags.shared.supabaseSyncEnabled,
               let userId = SupabaseAuthService.shared.currentUserId {
                do {
                    let url = try await SupabaseStorageService.shared.uploadProfilePhoto(userId: userId, imageData: data)
                    try await SupabaseConfig.client.from("profiles")
                        .update(["profile_photo_url": url])
                        .eq("id", value: userId.uuidString)
                        .execute()
                } catch {
                    print("[ProfileView] Profile photo upload failed: \(error)")
                }
            }
        }
    }

    @ViewBuilder
    private func collapsibleEmotionCard(insights: EmotionInsights) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    emotionInsightsExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 16))
                        .foregroundColor(GQColors.textSecondary)
                    Text("EMOTION JOURNEY")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(GQColors.textTertiary)
                        .tracking(1)
                    Spacer()
                    Text("\(insights.totalPostsWithEmotion) workouts")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(GQColors.textTertiary)
                        .rotationEffect(.degrees(emotionInsightsExpanded ? 90 : 0))
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            // Distribution bar always visible
            EmotionDistributionBar(
                distribution: insights.distribution,
                total: insights.totalPostsWithEmotion
            )
            .padding(.horizontal, 14)
            .padding(.bottom, emotionInsightsExpanded ? 8 : 14)

            if emotionInsightsExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    if insights.resilienceStreak >= 2 {
                        HStack(spacing: 8) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 14))
                                .foregroundColor(GQColors.textSecondary)
                            Text("\(insights.resilienceStreak) workouts showing up when it's hard")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(GQColors.textPrimary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(GQColors.surfaceSecondary))
                    }

                    let columns = [GridItem(.adaptive(minimum: 80), spacing: 8)]
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                        ForEach(insights.distribution) { item in
                            HStack(spacing: 4) {
                                Text(item.emotion.emoji)
                                    .font(.system(size: 12))
                                Text("\(item.count)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(item.emotion.color)
                            }
                        }
                    }

                    Text(insights.encouragementMessage)
                        .font(.system(size: 13, weight: .medium))
                        .italic()
                        .foregroundColor(GQColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .homeSocialCard()
    }

    @ViewBuilder
    private var postsContent: some View {
        VStack(spacing: 0) {
                // Tab bar (same sliding underline as Feed tabs)
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(GQColors.borderSubtle)
                        .frame(height: 0.5)

                    HStack(spacing: 0) {
                        ForEach([PostGridTab.photos, .clips, .tagged], id: \.self) { tab in
                            Image(systemName: tabIcon(tab))
                                .font(.system(size: 17, weight: postTab == tab ? .semibold : .regular))
                                .foregroundColor(postTab == tab ? GQColors.textPrimary : GQColors.textTertiary.opacity(0.35))
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .contentShape(Rectangle())
                                .scaleEffect(postTab == tab ? 1.0 : 0.92)
                                .animation(.spring(response: 0.25, dampingFraction: 0.75), value: postTab)
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        postTab = tab
                                    }
                                    #if canImport(UIKit)
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    #endif
                                }
                        }
                    }

                    // Background line + sliding gradient underline
                    ZStack(alignment: .leading) {
                        // Full-width faded grey line
                        Rectangle()
                            .fill(GQColors.borderSubtle)
                            .frame(height: 0.5)

                        // Sliding gradient underline (narrower, centered per tab)
                        GeometryReader { geometry in
                            let tabs: [PostGridTab] = [.photos, .clips, .tagged]
                            let tabWidth = geometry.size.width / CGFloat(tabs.count)
                            let tabIndex = tabs.firstIndex(of: postTab) ?? 0
                            Rectangle()
                                .fill(GQGradients.primary)
                                .frame(width: tabWidth, height: 1.5)
                                .clipShape(RoundedRectangle(cornerRadius: 0.75))
                                .offset(x: tabWidth * CGFloat(tabIndex))
                                .animation(.easeInOut(duration: 0.3), value: tabIndex)
                        }
                    }
                    .frame(height: 1.5)
                }

                // Filtered grid
                let activePosts: [Post] = {
                    switch postTab {
                    case .photos: return photoPosts
                    case .clips: return clipPosts
                    case .tagged: return taggedPosts
                    }
                }()

                if activePosts.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: emptyStateIcon(postTab))
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(GQGradients.primary.opacity(0.4))
                        Text(emptyStateTitle(postTab))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(GQColors.textTertiary)
                        Text(emptyStateSubtitle(postTab))
                            .font(.system(size: 12))
                            .foregroundColor(GQColors.textTertiary.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 56)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
                        ForEach(activePosts) { post in
                            tapThumb(post) {
                                VStack(spacing: 0) {
                                    ProfilePostThumbnail(post: post)
                                    HStack {
                                        if let t = post.workoutType {
                                            Text(t).font(.system(size: 9, weight: .semibold)).foregroundColor(GQColors.textSecondary).lineLimit(1)
                                        }
                                        Spacer(minLength: 2)
                                        Text(shortDate(post.timestamp)).font(.system(size: 9, weight: .medium)).foregroundColor(GQColors.textTertiary)
                                    }
                                    .padding(.horizontal, 6).padding(.vertical, 4)
                                    .background(GQColors.surfaceBase)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(GQColors.borderSubtle.opacity(0.7), lineWidth: 0.5))
                            }
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

extension ProfileView {
    // MARK: - Tab helpers (icons, empty state, records list)

    fileprivate func tabIcon(_ tab: PostGridTab) -> String {
        switch tab {
        case .photos: return "square.grid.3x3"
        case .clips: return "play.rectangle"
        case .tagged: return "at"
        }
    }

    private func emptyStateIcon(_ tab: PostGridTab) -> String {
        switch tab {
        case .photos: return "photo.on.rectangle.angled"
        case .clips: return "play.circle"
        case .tagged: return "at"
        }
    }

    private func emptyStateTitle(_ tab: PostGridTab) -> String {
        switch tab {
        case .photos: return "No photos yet"
        case .clips: return "No clips yet"
        case .tagged: return "No tagged posts"
        }
    }

    private func emptyStateSubtitle(_ tab: PostGridTab) -> String {
        switch tab {
        case .photos, .clips: return "Share a workout to get started"
        case .tagged: return "When people tag you, it shows here"
        }
    }

    /// Top records list — one row per exercise, the heaviest logged set.
    @ViewBuilder
    private var recordsList: some View {
        let byExercise: [(name: String, weight: Double, reps: Int?, date: Date)] = {
            let grouped = Dictionary(grouping: prEvents.filter { $0.prType == .weightPR && $0.newValue > 0 }, by: { $0.exerciseName })
            return grouped.compactMap { (name, events) -> (String, Double, Int?, Date)? in
                guard let top = events.max(by: { $0.newValue < $1.newValue }) else { return nil }
                return (name, top.newValue, nil, top.date)
            }
            .sorted { $0.1 > $1.1 }
        }()

        if byExercise.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "trophy")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(GQGradients.primary.opacity(0.4))
                Text("No records yet")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(GQColors.textTertiary)
                Text("Hit a PR in a workout to see it here")
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textTertiary.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 56)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(Array(byExercise.enumerated()), id: \.offset) { idx, rec in
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(GQGradients.primary.opacity(0.12))
                                .frame(width: 36, height: 36)
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(GQGradients.primary)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(rec.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(GQColors.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Text(shortDate(rec.date))
                                .font(.system(size: 11))
                                .foregroundColor(GQColors.textTertiary)
                        }
                        Spacer(minLength: 6)
                        Text("\(Int(rec.weight)) lb")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(GQColors.textPrimary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    if idx < byExercise.count - 1 {
                        Rectangle().fill(GQColors.borderSubtle).frame(height: 0.5)
                    }
                }
            }
        }
    }
}

extension ProfileView {
    fileprivate func gridVariantLabel(_ i: Int) -> String {
        [
            "Combined: type+date + likes/comments",
            "Floating heart pill (bottom-right)",
            "Gradient type-color bar",
            "Tap-heart burst animation",
            "Video duration chip",
            "NEW badge on fresh posts",
            "PR star badge",
            "Caption peek (1 line below)",
            "Relative date '2h ago'",
            "Multi-photo stack '1/5'",
            "Streak flame tag",
            "Top reaction emoji pill",
            "Hover-scale grow",
            "Play icon + duration for clips",
            "Muscle group tag",
            "Big like count centered bottom",
            "Engagement glow (hot posts)",
            "Split: type-bar top, stats bottom",
            "Premium combined (everything)",
            "Hero-first (big top) + 3-col rest",
        ][i - 1]
    }

    @ViewBuilder
    fileprivate func gridVariant(_ i: Int, posts: [Post]) -> some View {
        let p = Array(posts.prefix(9))
        let cols3 = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)
        switch i {
        case 1: // Combined: type+date + likes/comments
            LazyVGrid(columns: cols3, spacing: 6) {
                ForEach(p) { post in
                    tapThumb(post) {
                        VStack(spacing: 0) {
                            ProfilePostThumbnail(post: post)
                            HStack(spacing: 4) {
                                if let t = post.workoutType { Text(t.prefix(4)).font(.system(size: 9, weight: .semibold)).foregroundColor(GQColors.textSecondary) }
                                Spacer()
                                Text(shortDate(post.timestamp)).font(.system(size: 9)).foregroundColor(GQColors.textTertiary)
                            }.padding(.horizontal, 6).padding(.vertical, 4).background(GQColors.surfaceBase)
                            HStack(spacing: 6) {
                                Image(systemName: "heart.fill").font(.system(size: 9)).foregroundColor(.pink); Text("\(post.likeCount)").font(.system(size: 9, weight: .semibold)).foregroundColor(GQColors.textSecondary)
                                Image(systemName: "bubble.left.fill").font(.system(size: 9)).foregroundColor(GQColors.textTertiary); Text("\(post.commentCount)").font(.system(size: 9, weight: .semibold)).foregroundColor(GQColors.textSecondary); Spacer()
                            }.padding(.horizontal, 6).padding(.vertical, 4).background(GQColors.surfaceSecondary)
                        }.clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }.padding(.horizontal, 6)
        case 2: // Floating heart pill bottom-right
            LazyVGrid(columns: cols3, spacing: 6) {
                ForEach(p) { post in
                    tapThumb(post) {
                        ProfilePostThumbnail(post: post)
                            .overlay(alignment: .bottomTrailing) {
                                HStack(spacing: 3) { Image(systemName: "heart.fill").font(.system(size: 8)); Text("\(post.likeCount)").font(.system(size: 9, weight: .bold)) }
                                .foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 3).background(Capsule().fill(.black.opacity(0.55))).padding(5)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }.padding(.horizontal, 6)
        case 3: // Gradient workout-type-color bar
            LazyVGrid(columns: cols3, spacing: 6) {
                ForEach(p) { post in
                    tapThumb(post) {
                        VStack(spacing: 0) {
                            ProfilePostThumbnail(post: post)
                            HStack(spacing: 4) {
                                Text(post.workoutType ?? "Post").font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                                Spacer()
                                Text(relDate(post.timestamp)).font(.system(size: 9)).foregroundColor(.white.opacity(0.85))
                            }.padding(.horizontal, 6).padding(.vertical, 4).background(GQGradients.primary)
                        }.clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }.padding(.horizontal, 6)
        case 4: // Tap-heart burst (heart icon center on tap)
            LazyVGrid(columns: cols3, spacing: 6) {
                ForEach(p) { post in
                    tapThumb(post) {
                        ProfilePostThumbnail(post: post)
                            .overlay(alignment: .bottomLeading) {
                                HStack(spacing: 3) { Image(systemName: "heart.fill").font(.system(size: 9)).foregroundColor(.pink); Text("\(post.likeCount)").font(.system(size: 9, weight: .semibold)).foregroundColor(.white) }
                                .padding(.horizontal, 6).padding(.vertical, 3).background(Capsule().fill(.ultraThinMaterial)).padding(5)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }.padding(.horizontal, 6)
        case 5: // Video duration chip
            LazyVGrid(columns: cols3, spacing: 6) {
                ForEach(p) { post in
                    tapThumb(post) {
                        ProfilePostThumbnail(post: post)
                            .overlay(alignment: .bottomTrailing) {
                                if post.videoData != nil || post.mediaItems.contains(where: { $0.mediaType == .video }) {
                                    HStack(spacing: 3) { Image(systemName: "play.fill").font(.system(size: 7)); Text("0:45").font(.system(size: 9, weight: .bold)) }
                                    .foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 3).background(Capsule().fill(.black.opacity(0.55))).padding(5)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }.padding(.horizontal, 6)
        case 6: // NEW badge on fresh posts
            LazyVGrid(columns: cols3, spacing: 6) {
                ForEach(p) { post in
                    tapThumb(post) {
                        ProfilePostThumbnail(post: post)
                            .overlay(alignment: .topLeading) {
                                if isRecent(post.timestamp) {
                                    Text("NEW").font(.system(size: 8, weight: .bold)).tracking(0.5).foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 2).background(Capsule().fill(GQGradients.primary)).padding(5)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }.padding(.horizontal, 6)
        case 7: // PR star badge (fake — uses post index as stand-in)
            LazyVGrid(columns: cols3, spacing: 6) {
                ForEach(Array(p.enumerated()), id: \.offset) { idx, post in
                    tapThumb(post) {
                        ProfilePostThumbnail(post: post)
                            .overlay(alignment: .topTrailing) {
                                if idx % 3 == 0 {
                                    Image(systemName: "star.fill").font(.system(size: 11)).foregroundColor(.yellow).shadow(color: .black.opacity(0.4), radius: 2).padding(6)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }.padding(.horizontal, 6)
        case 8: // Caption peek below
            LazyVGrid(columns: cols3, spacing: 8) {
                ForEach(p) { post in
                    tapThumb(post) {
                        VStack(alignment: .leading, spacing: 4) {
                            ProfilePostThumbnail(post: post).clipShape(RoundedRectangle(cornerRadius: 8))
                            Text(post.caption.isEmpty ? "Workout" : post.caption).font(.system(size: 10, weight: .medium)).foregroundColor(GQColors.textSecondary).lineLimit(1)
                        }
                    }
                }
            }.padding(.horizontal, 6)
        case 9: // Relative date '2h ago'
            LazyVGrid(columns: cols3, spacing: 6) {
                ForEach(p) { post in
                    tapThumb(post) {
                        ProfilePostThumbnail(post: post)
                            .overlay(alignment: .bottomLeading) {
                                Text(relDate(post.timestamp)).font(.system(size: 9, weight: .bold)).foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 3).background(Capsule().fill(.black.opacity(0.45))).padding(5)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }.padding(.horizontal, 6)
        case 10: // Multi-photo stack "1/5"
            LazyVGrid(columns: cols3, spacing: 6) {
                ForEach(p) { post in
                    tapThumb(post) {
                        ProfilePostThumbnail(post: post)
                            .overlay(alignment: .topTrailing) {
                                if post.mediaItems.count > 1 {
                                    HStack(spacing: 3) { Image(systemName: "rectangle.stack.fill").font(.system(size: 8)); Text("\(post.mediaItems.count)").font(.system(size: 9, weight: .bold)) }
                                    .foregroundColor(.white).padding(.horizontal, 5).padding(.vertical, 2).background(Capsule().fill(.black.opacity(0.55))).padding(5)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }.padding(.horizontal, 6)
        case 11: // Streak flame tag
            LazyVGrid(columns: cols3, spacing: 6) {
                ForEach(Array(p.enumerated()), id: \.offset) { idx, post in
                    tapThumb(post) {
                        ProfilePostThumbnail(post: post)
                            .overlay(alignment: .topLeading) {
                                if idx % 2 == 0 {
                                    HStack(spacing: 2) { Image(systemName: "flame.fill").font(.system(size: 9)).foregroundStyle(LinearGradient(colors: [.orange, .red.opacity(0.9)], startPoint: .bottom, endPoint: .top)); Text("\(idx + 3)").font(.system(size: 9, weight: .bold)).foregroundColor(.white) }
                                    .padding(.horizontal, 5).padding(.vertical, 2).background(Capsule().fill(.black.opacity(0.5))).padding(5)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }.padding(.horizontal, 6)
        case 12: // Top reaction emoji pill
            LazyVGrid(columns: cols3, spacing: 6) {
                ForEach(Array(p.enumerated()), id: \.offset) { idx, post in
                    let emojis = ["🔥", "💪", "❤️", "👏", "🤯"]
                    tapThumb(post) {
                        ProfilePostThumbnail(post: post)
                            .overlay(alignment: .bottomTrailing) {
                                HStack(spacing: 3) { Text(emojis[idx % emojis.count]).font(.system(size: 10)); Text("\(post.likeCount)").font(.system(size: 9, weight: .bold)).foregroundColor(.white) }
                                .padding(.horizontal, 5).padding(.vertical, 2).background(Capsule().fill(.black.opacity(0.55))).padding(5)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }.padding(.horizontal, 6)
        case 13: // Hover scale grow (spring on appear)
            LazyVGrid(columns: cols3, spacing: 6) {
                ForEach(p) { post in
                    Button { selectedPost = post } label: {
                        ProfilePostThumbnail(post: post).clipShape(RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(PressScaleStyle())
                }
            }.padding(.horizontal, 6)
        case 14: // Play icon + duration for video
            LazyVGrid(columns: cols3, spacing: 6) {
                ForEach(p) { post in
                    let isVideo = post.videoData != nil || post.mediaItems.contains(where: { $0.mediaType == .video })
                    tapThumb(post) {
                        ProfilePostThumbnail(post: post)
                            .overlay(alignment: .center) {
                                if isVideo {
                                    Image(systemName: "play.circle.fill").font(.system(size: 28)).foregroundColor(.white.opacity(0.92)).shadow(color: .black.opacity(0.4), radius: 3)
                                }
                            }
                            .overlay(alignment: .bottomLeading) {
                                if isVideo { Text("0:42").font(.system(size: 9, weight: .bold)).foregroundColor(.white).padding(.horizontal, 5).padding(.vertical, 2).background(Capsule().fill(.black.opacity(0.55))).padding(5) }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }.padding(.horizontal, 6)
        case 15: // Muscle group tag
            LazyVGrid(columns: cols3, spacing: 6) {
                ForEach(Array(p.enumerated()), id: \.offset) { idx, post in
                    let muscles = ["Chest", "Back", "Legs", "Core", "Arms"]
                    tapThumb(post) {
                        ProfilePostThumbnail(post: post)
                            .overlay(alignment: .bottomLeading) {
                                Text(muscles[idx % muscles.count]).font(.system(size: 9, weight: .bold)).foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 2).background(Capsule().fill(GQGradients.primary)).padding(5)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }.padding(.horizontal, 6)
        case 16: // Big like count centered bottom
            LazyVGrid(columns: cols3, spacing: 6) {
                ForEach(p) { post in
                    tapThumb(post) {
                        ZStack(alignment: .bottom) {
                            ProfilePostThumbnail(post: post)
                            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom).frame(height: 34)
                            HStack(spacing: 4) { Image(systemName: "heart.fill").font(.system(size: 12)).foregroundColor(.pink); Text("\(post.likeCount)").font(.system(size: 13, weight: .bold)).foregroundColor(.white) }.padding(6)
                        }.clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }.padding(.horizontal, 6)
        case 17: // Engagement glow (hot posts)
            LazyVGrid(columns: cols3, spacing: 8) {
                ForEach(p) { post in
                    let hot = post.likeCount > 5
                    tapThumb(post) {
                        ProfilePostThumbnail(post: post)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(color: hot ? GQColors.vividPurple.opacity(0.3) : .black.opacity(0.05), radius: hot ? 6 : 2, y: 2)
                            .overlay(alignment: .topTrailing) {
                                if hot { Image(systemName: "flame.fill").font(.system(size: 10)).foregroundStyle(LinearGradient(colors: [.orange, .red.opacity(0.9)], startPoint: .bottom, endPoint: .top)).padding(6) }
                            }
                    }
                }
            }.padding(.horizontal, 8).padding(.vertical, 4)
        case 18: // Split: type bar top (gradient), stats bar bottom
            LazyVGrid(columns: cols3, spacing: 6) {
                ForEach(p) { post in
                    tapThumb(post) {
                        VStack(spacing: 0) {
                            Text(post.workoutType ?? "Post").font(.system(size: 9, weight: .bold)).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 4).background(GQGradients.primary)
                            ProfilePostThumbnail(post: post)
                            HStack(spacing: 6) {
                                Image(systemName: "heart.fill").font(.system(size: 9)).foregroundColor(.pink); Text("\(post.likeCount)").font(.system(size: 9, weight: .semibold)).foregroundColor(GQColors.textSecondary)
                                Spacer()
                                Text(relDate(post.timestamp)).font(.system(size: 9)).foregroundColor(GQColors.textTertiary)
                            }.padding(.horizontal, 6).padding(.vertical, 4).background(GQColors.surfaceBase)
                        }.clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }.padding(.horizontal, 6)
        case 19: // Premium combined — everything
            LazyVGrid(columns: cols3, spacing: 8) {
                ForEach(Array(p.enumerated()), id: \.offset) { idx, post in
                    let hot = post.likeCount > 5
                    let isVideo = post.videoData != nil || post.mediaItems.contains(where: { $0.mediaType == .video })
                    tapThumb(post) {
                        VStack(spacing: 0) {
                            ProfilePostThumbnail(post: post)
                                .overlay(alignment: .topLeading) {
                                    if isRecent(post.timestamp) {
                                        Text("NEW").font(.system(size: 8, weight: .bold)).tracking(0.5).foregroundColor(.white).padding(.horizontal, 5).padding(.vertical, 2).background(Capsule().fill(GQGradients.primary)).padding(5)
                                    }
                                }
                                .overlay(alignment: .topTrailing) {
                                    if idx % 3 == 0 { Image(systemName: "star.fill").font(.system(size: 11)).foregroundColor(.yellow).shadow(color: .black.opacity(0.4), radius: 2).padding(5) }
                                }
                                .overlay(alignment: .bottomTrailing) {
                                    if isVideo { Text("0:42").font(.system(size: 9, weight: .bold)).foregroundColor(.white).padding(.horizontal, 5).padding(.vertical, 2).background(Capsule().fill(.black.opacity(0.55))).padding(5) }
                                }
                            HStack(spacing: 4) {
                                if let t = post.workoutType { Text(t.prefix(6)).font(.system(size: 9, weight: .bold)).foregroundColor(GQColors.textSecondary) }
                                Spacer()
                                Image(systemName: "heart.fill").font(.system(size: 9)).foregroundColor(.pink); Text("\(post.likeCount)").font(.system(size: 9, weight: .semibold)).foregroundColor(GQColors.textSecondary)
                            }.padding(.horizontal, 6).padding(.vertical, 4).background(GQColors.surfaceBase)
                        }.clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: hot ? GQColors.vividPurple.opacity(0.25) : .black.opacity(0.05), radius: hot ? 5 : 2, y: 2)
                    }
                }
            }.padding(.horizontal, 8).padding(.vertical, 4)
        case 20: // Hero-first (big top) + 3-col rest
            VStack(spacing: 6) {
                if let hero = p.first {
                    tapThumb(hero) {
                        ZStack(alignment: .bottomLeading) {
                            ProfilePostThumbnail(post: hero).aspectRatio(16/9, contentMode: .fill)
                            LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .top, endPoint: .bottom).frame(height: 60)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) { if let t = hero.workoutType { Text(t).font(.system(size: 10, weight: .bold)).foregroundColor(.white) }; Spacer(); Image(systemName: "heart.fill").font(.system(size: 10)).foregroundColor(.pink); Text("\(hero.likeCount)").font(.system(size: 10, weight: .bold)).foregroundColor(.white) }
                                Text(hero.caption.isEmpty ? "Latest workout" : hero.caption).font(.system(size: 11)).foregroundColor(.white.opacity(0.9)).lineLimit(1)
                            }.padding(10)
                        }.clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                LazyVGrid(columns: cols3, spacing: 6) {
                    ForEach(Array(p.dropFirst())) { post in
                        tapThumb(post) {
                            ProfilePostThumbnail(post: post)
                                .overlay(alignment: .bottomTrailing) {
                                    HStack(spacing: 3) { Image(systemName: "heart.fill").font(.system(size: 8)); Text("\(post.likeCount)").font(.system(size: 9, weight: .bold)) }
                                    .foregroundColor(.white).padding(.horizontal, 5).padding(.vertical, 2).background(Capsule().fill(.black.opacity(0.55))).padding(4)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }.padding(.horizontal, 6)
        default: EmptyView()
        }
    }

    // MARK: - Attach-strip alternatives (info clearly tied to image)

    fileprivate func attachVariantLabel(_ v: Int) -> String {
        [
            "Bottom-corners rounded only",
            "All-4 corners rounded (full tile)",
            "Subtle card shadow per tile",
            "Thin border around tile",
            "Tinted strip (adaptive overlay)",
            "Gradient overlay on image bottom",
            "Strip + hairline top border",
            "Rounded strip only, image square",
            "Left-bar accent (vertical stripe)",
            "Premium: rounded tile + shadow + accent",
        ][v - 1]
    }

    @ViewBuilder
    fileprivate func attachVariantGrid(_ v: Int, posts: [Post]) -> some View {
        let cols3 = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)
        LazyVGrid(columns: cols3, spacing: 2) {
            ForEach(posts) { post in
                tapThumb(post) { attachCard(v, post: post) }
            }
        }
    }

    @ViewBuilder
    fileprivate func attachCard(_ v: Int, post: Post) -> some View {
        let base = ProfilePostThumbnail(post: post)
        let strip = HStack {
            if let t = post.workoutType {
                Text(t).font(.system(size: 9, weight: .semibold)).foregroundColor(GQColors.textSecondary).lineLimit(1)
            }
            Spacer(minLength: 2)
            Text(shortDate(post.timestamp)).font(.system(size: 9, weight: .medium)).foregroundColor(GQColors.textTertiary)
        }
        switch v {
        case 1: // bottom corners only rounded
            VStack(spacing: 0) {
                base
                strip.padding(.horizontal, 6).padding(.vertical, 4).background(GQColors.surfaceBase)
            }.clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 8, bottomTrailingRadius: 8, topTrailingRadius: 0))
        case 2: // all 4 corners rounded
            VStack(spacing: 0) {
                base
                strip.padding(.horizontal, 6).padding(.vertical, 4).background(GQColors.surfaceBase)
            }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 3: // card shadow per tile
            VStack(spacing: 0) {
                base
                strip.padding(.horizontal, 6).padding(.vertical, 4).background(GQColors.surfaceBase)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
        case 4: // thin border
            VStack(spacing: 0) {
                base
                strip.padding(.horizontal, 6).padding(.vertical, 4).background(GQColors.surfaceBase)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(GQColors.borderSubtle, lineWidth: 0.5))
        case 5: // tinted strip
            VStack(spacing: 0) {
                base
                strip.padding(.horizontal, 6).padding(.vertical, 4).background(GQColors.adaptiveOverlay(0.08))
            }
        case 6: // gradient overlay on image bottom, no separate strip
            base.overlay(alignment: .bottom) {
                HStack {
                    if let t = post.workoutType {
                        Text(t).font(.system(size: 9, weight: .semibold)).foregroundColor(.white).lineLimit(1)
                    }
                    Spacer(minLength: 2)
                    Text(shortDate(post.timestamp)).font(.system(size: 9, weight: .medium)).foregroundColor(.white.opacity(0.85))
                }
                .padding(.horizontal, 6).padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .bottom, endPoint: .top))
            }
        case 7: // hairline border between image and strip
            VStack(spacing: 0) {
                base
                Rectangle().fill(GQColors.borderSubtle).frame(height: 0.5)
                strip.padding(.horizontal, 6).padding(.vertical, 4).background(GQColors.surfaceBase)
            }
        case 8: // strip rounded bottom corners; image square on top
            VStack(spacing: 0) {
                base
                strip
                    .padding(.horizontal, 6).padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .background(
                        UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 8, bottomTrailingRadius: 8, topTrailingRadius: 0)
                            .fill(GQColors.surfaceBase)
                    )
            }
        case 9: // left vertical accent bar
            HStack(spacing: 0) {
                Rectangle().fill(GQGradients.primary).frame(width: 2)
                VStack(spacing: 0) {
                    base
                    strip.padding(.horizontal, 6).padding(.vertical, 4).background(GQColors.surfaceBase)
                }
            }.clipShape(RoundedRectangle(cornerRadius: 4))
        case 10: // Premium: rounded + shadow + left accent
            HStack(spacing: 0) {
                Rectangle().fill(GQGradients.primary).frame(width: 2)
                VStack(spacing: 0) {
                    base
                    strip.padding(.horizontal, 6).padding(.vertical, 4).background(GQColors.surfaceBase)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
        default: EmptyView()
        }
    }

    // MARK: - 100 Premium variants (no play/likes, stat-focused)

    fileprivate func premiumVariantLabel(_ i: Int) -> String {
        let labels: [String] = [
            "Duration bottom pill",
            "Duration top-right chip",
            "Duration gradient footer",
            "Duration center hero",
            "Duration + type split bar",
            "Volume bottom-right pill",
            "Volume top gradient bar",
            "Volume + lbs icon",
            "Volume hero bottom",
            "Volume muted corner",
            "Sets count chip",
            "Sets + reps combined",
            "Sets bottom gradient",
            "Sets as number badge",
            "Sets + type stacked",
            "Top lift overlay",
            "Top lift + weight×reps",
            "Top lift centered hero",
            "Top lift footer bar",
            "Top lift PR combo",
            "Muscle tag bottom-left",
            "Muscle + type pills",
            "Muscle gradient top bar",
            "Muscle icon + label",
            "Muscle full-width banner",
            "RPE badge corner",
            "RPE + duration combo",
            "RPE gradient dot",
            "RPE fire gradient",
            "Cal burned chip",
            "Cal + duration pair",
            "Cal gradient footer",
            "Avg HR chip",
            "HR + cal combo",
            "HR bottom pill",
            "Exercise count badge",
            "Exercises + sets combo",
            "Exercises hero",
            "Progress delta (+5 lb)",
            "Progress delta + PR",
            "Workout phase tag",
            "Phase gradient strip",
            "Phase + type combo",
            "Phase hero bottom",
            "Date relative pill",
            "Date + type combo",
            "Date gradient footer",
            "Time of day chip",
            "Time + duration combo",
            "Frosted glass stat pill",
            "Frosted + type color",
            "Frosted duration + PR",
            "Material stat bar",
            "Dark gradient stat",
            "Light gradient stat",
            "Neumorphic stat card",
            "Glass volume + duration",
            "Solid color type bar",
            "Gradient border accent",
            "Inner stroke gradient",
            "Diagonal stat strip",
            "Corner ribbon tag",
            "Full-width caption bar",
            "Hero top-lift card",
            "Sets+volume dual-pill",
            "Duration+RPE dual-pill",
            "Muscle+type dual-pill",
            "Triple stat bar",
            "Quad stat micro-bar",
            "Vertical stat strip left",
            "Vertical stat strip right",
            "Top + bottom dual bars",
            "Stacked 2-line footer",
            "Split 3-zone card",
            "Hero stat overlay",
            "Watermark stat behind",
            "Scaled type letter BG",
            "Large icon watermark",
            "Gradient watermark",
            "Diagonal gradient wash",
            "Corner PR star",
            "PR ribbon top-left",
            "Crown achievement icon",
            "Gold star PR badge",
            "Medal circle overlay",
            "NEW pill + duration",
            "NEW pill + volume",
            "NEW + PR combo",
            "Streak flame badge",
            "Streak + PR duo",
            "Hot glow + stat",
            "Engagement glow minimal",
            "Pulsing NEW indicator",
            "Weekly top badge",
            "Personal best banner",
            "Detailed stats trio",
            "Detailed stats quartet",
            "Ultra-minimal duration",
            "Ultra-minimal volume",
            "Ultra-minimal PR",
            "Tinted background fade",
            "Dark bottom fade + stat",
            "Premium V2 (refined)",
        ]
        return labels[max(0, min(i - 1, labels.count - 1))]
    }

    // Stat generation helpers (deterministic per post for preview)
    fileprivate func pseudoDuration(_ post: Post) -> String {
        let mins = 30 + (abs(post.id.hashValue) % 60)
        return "\(mins)m"
    }
    fileprivate func pseudoVolume(_ post: Post) -> String {
        let v = 3500 + (abs(post.id.hashValue) % 9500)
        return "\(v/1000).\((v % 1000)/100)k lb"
    }
    fileprivate func pseudoSets(_ post: Post) -> Int { 8 + (abs(post.id.hashValue) % 18) }
    fileprivate func pseudoReps(_ post: Post) -> Int { 40 + (abs(post.id.hashValue) % 80) }
    fileprivate func pseudoRPE(_ post: Post) -> Int { 6 + (abs(post.id.hashValue) % 4) }
    fileprivate func pseudoCal(_ post: Post) -> Int { 180 + (abs(post.id.hashValue) % 320) }
    fileprivate func pseudoHR(_ post: Post) -> Int { 110 + (abs(post.id.hashValue) % 55) }
    fileprivate func pseudoExercises(_ post: Post) -> Int { 4 + (abs(post.id.hashValue) % 7) }
    fileprivate func pseudoTopLift(_ post: Post) -> String {
        let lifts = ["Bench 225×8", "Squat 315×5", "Deadlift 405×3", "OHP 135×6", "Row 185×8"]
        return lifts[abs(post.id.hashValue) % lifts.count]
    }
    fileprivate func pseudoMuscle(_ post: Post) -> String {
        let m = ["Chest", "Back", "Legs", "Arms", "Core", "Shoulders"]
        return m[abs(post.id.hashValue) % m.count]
    }
    fileprivate func pseudoPhase(_ post: Post) -> String {
        let ph = ["Push", "Pull", "Legs", "Upper", "Lower"]
        return ph[abs(post.id.hashValue) % ph.count]
    }
    fileprivate func pseudoDelta(_ post: Post) -> String {
        let d = 2 + (abs(post.id.hashValue) % 15)
        return "+\(d) lb"
    }
    fileprivate func pseudoTimeOfDay(_ post: Post) -> String {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f.string(from: post.timestamp)
    }

    // Small reusable overlays
    fileprivate func cornerChip(_ text: String, icon: String? = nil, bg: AnyShapeStyle = AnyShapeStyle(Color.black.opacity(0.55)), fg: Color = .white) -> some View {
        HStack(spacing: 3) {
            if let icon { Image(systemName: icon).font(.system(size: 8, weight: .semibold)) }
            Text(text).font(.system(size: 9, weight: .bold))
        }
        .foregroundColor(fg)
        .padding(.horizontal, 5).padding(.vertical, 2)
        .background(Capsule().fill(bg))
    }

    fileprivate func gradientChip(_ text: String, icon: String? = nil) -> some View {
        HStack(spacing: 3) {
            if let icon { Image(systemName: icon).font(.system(size: 8, weight: .semibold)) }
            Text(text).font(.system(size: 9, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(Capsule().fill(GQGradients.primary))
    }

    fileprivate func fullBar(_ text: String, icon: String? = nil, gradient: Bool = false) -> some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.system(size: 9, weight: .semibold)) }
            Text(text).font(.system(size: 10, weight: .bold))
            Spacer()
        }
        .foregroundColor(gradient ? .white : GQColors.textSecondary)
        .padding(.horizontal, 6).padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(gradient ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(GQColors.surfaceBase))
    }

    @ViewBuilder
    fileprivate func premiumVariant(_ i: Int, posts: [Post]) -> some View {
        let p = Array(posts.prefix(9))
        let cols3 = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)
        LazyVGrid(columns: cols3, spacing: 8) {
            ForEach(p) { post in
                tapThumb(post) {
                    premiumCard(style: i, post: post)
                }
            }
        }.padding(.horizontal, 6)
    }

    @ViewBuilder
    fileprivate func premiumCard(style: Int, post: Post) -> some View {
        let base = ProfilePostThumbnail(post: post)
        let muted = AnyShapeStyle(Color.black.opacity(0.55))
        let frost = AnyShapeStyle(.ultraThinMaterial)
        switch style {
        case 1:
            base.overlay(alignment: .bottom) { cornerChip(pseudoDuration(post), icon: "clock").padding(6) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 2:
            base.overlay(alignment: .topTrailing) { cornerChip(pseudoDuration(post), icon: "clock").padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 3:
            VStack(spacing: 0) { base; HStack { Image(systemName: "clock").font(.system(size: 9, weight: .semibold)); Text(pseudoDuration(post)).font(.system(size: 10, weight: .bold)); Spacer() }.foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 4).background(GQGradients.primary) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 4:
            base.overlay(alignment: .center) { Text(pseudoDuration(post)).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(.white).shadow(color: .black.opacity(0.4), radius: 3) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 5:
            VStack(spacing: 0) { base; HStack { Text(post.workoutType ?? "Post").font(.system(size: 9, weight: .bold)); Spacer(); Text(pseudoDuration(post)).font(.system(size: 9, weight: .bold)) }.foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 4).background(GQGradients.primary) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 6:
            base.overlay(alignment: .bottomTrailing) { cornerChip(pseudoVolume(post)).padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 7:
            VStack(spacing: 0) { HStack { Text(pseudoVolume(post)).font(.system(size: 9, weight: .bold)); Spacer() }.foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 3).background(GQGradients.primary); base }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 8:
            base.overlay(alignment: .bottomLeading) { cornerChip(pseudoVolume(post), icon: "scalemass").padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 9:
            base.overlay(alignment: .bottom) { Text(pseudoVolume(post)).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.white).padding(.bottom, 8).shadow(color: .black.opacity(0.5), radius: 3) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 10:
            base.overlay(alignment: .topLeading) { Text(pseudoVolume(post)).font(.system(size: 9, weight: .medium)).foregroundColor(.white.opacity(0.9)).padding(6) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 11:
            base.overlay(alignment: .bottomLeading) { cornerChip("\(pseudoSets(post)) sets", icon: "square.stack.3d.up").padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 12:
            base.overlay(alignment: .bottomLeading) { cornerChip("\(pseudoSets(post))×\(pseudoReps(post))").padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 13:
            VStack(spacing: 0) { base; HStack { Text("\(pseudoSets(post)) SETS").font(.system(size: 9, weight: .bold)).tracking(0.8); Spacer() }.foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 3).background(GQGradients.primary) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 14:
            base.overlay(alignment: .topLeading) { Text("\(pseudoSets(post))").font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(.white).shadow(color: .black.opacity(0.5), radius: 2).padding(8) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 15:
            VStack(alignment: .leading, spacing: 0) { base; HStack { Text(post.workoutType ?? "Post").font(.system(size: 9, weight: .bold)); Spacer(); Text("\(pseudoSets(post)) sets").font(.system(size: 9)) }.foregroundColor(GQColors.textSecondary).padding(6).background(GQColors.surfaceBase) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 16:
            base.overlay(alignment: .bottom) { Text(pseudoTopLift(post)).font(.system(size: 10, weight: .bold)).foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 3).background(Capsule().fill(muted)).padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 17:
            base.overlay(alignment: .bottomLeading) { cornerChip(pseudoTopLift(post), icon: "trophy.fill", bg: AnyShapeStyle(GQGradients.primary)).padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 18:
            base.overlay(alignment: .center) { Text(pseudoTopLift(post)).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(.white).padding(.horizontal, 8).padding(.vertical, 5).background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.5))) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 19:
            VStack(spacing: 0) { base; HStack { Image(systemName: "trophy.fill").font(.system(size: 9)); Text(pseudoTopLift(post)).font(.system(size: 10, weight: .bold)); Spacer() }.foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 4).background(GQGradients.primary) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 20:
            base.overlay(alignment: .topTrailing) { Image(systemName: "star.fill").font(.system(size: 12)).foregroundColor(.yellow).padding(6) }.overlay(alignment: .bottom) { cornerChip(pseudoTopLift(post)).padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 21:
            base.overlay(alignment: .bottomLeading) { gradientChip(pseudoMuscle(post)).padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 22:
            base.overlay(alignment: .bottomLeading) { HStack(spacing: 4) { cornerChip(post.workoutType ?? "Post"); cornerChip(pseudoMuscle(post)) }.padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 23:
            VStack(spacing: 0) { HStack { Text(pseudoMuscle(post).uppercased()).font(.system(size: 9, weight: .bold)).tracking(0.8); Spacer() }.foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 3).background(GQGradients.primary); base }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 24:
            base.overlay(alignment: .bottomLeading) { HStack(spacing: 3) { Image(systemName: "figure.strengthtraining.traditional").font(.system(size: 9)); Text(pseudoMuscle(post)).font(.system(size: 9, weight: .bold)) }.foregroundColor(.white).padding(5).background(Capsule().fill(muted)).padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 25:
            VStack(spacing: 0) { base; Text(pseudoMuscle(post).uppercased()).font(.system(size: 10, weight: .bold)).tracking(1).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 5).background(GQGradients.primary) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 26:
            base.overlay(alignment: .topTrailing) { cornerChip("RPE \(pseudoRPE(post))").padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 27:
            base.overlay(alignment: .bottomLeading) { HStack(spacing: 4) { cornerChip("RPE \(pseudoRPE(post))"); cornerChip(pseudoDuration(post)) }.padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 28:
            base.overlay(alignment: .topTrailing) { ZStack { Circle().fill(GQGradients.primary).frame(width: 24, height: 24); Text("\(pseudoRPE(post))").font(.system(size: 11, weight: .bold)).foregroundColor(.white) }.padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 29:
            base.overlay(alignment: .topTrailing) { HStack(spacing: 3) { Image(systemName: "flame.fill").font(.system(size: 9)); Text("\(pseudoRPE(post))").font(.system(size: 10, weight: .bold)) }.foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 2).background(Capsule().fill(LinearGradient(colors: [.orange, .red.opacity(0.9)], startPoint: .bottom, endPoint: .top))).padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 30:
            base.overlay(alignment: .bottomTrailing) { cornerChip("\(pseudoCal(post)) cal", icon: "flame").padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 31:
            base.overlay(alignment: .bottomLeading) { HStack(spacing: 4) { cornerChip("\(pseudoCal(post)) cal", icon: "flame"); cornerChip(pseudoDuration(post), icon: "clock") }.padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 32:
            VStack(spacing: 0) { base; HStack { Image(systemName: "flame.fill").font(.system(size: 9)); Text("\(pseudoCal(post)) cal").font(.system(size: 10, weight: .bold)); Spacer() }.foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 4).background(GQGradients.primary) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 33:
            base.overlay(alignment: .topTrailing) { cornerChip("\(pseudoHR(post)) bpm", icon: "heart").padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 34:
            base.overlay(alignment: .bottomLeading) { HStack(spacing: 4) { cornerChip("\(pseudoHR(post))bpm", icon: "heart"); cornerChip("\(pseudoCal(post))c") }.padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 35:
            base.overlay(alignment: .bottom) { cornerChip("♥ \(pseudoHR(post)) bpm avg").padding(6) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 36:
            base.overlay(alignment: .topLeading) { ZStack { Circle().fill(muted).frame(width: 22, height: 22); Text("\(pseudoExercises(post))").font(.system(size: 11, weight: .bold)).foregroundColor(.white) }.padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 37:
            base.overlay(alignment: .bottomLeading) { cornerChip("\(pseudoExercises(post)) exs · \(pseudoSets(post)) sets").padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 38:
            base.overlay(alignment: .center) { VStack(spacing: -2) { Text("\(pseudoExercises(post))").font(.system(size: 26, weight: .bold, design: .rounded)); Text("EXERCISES").font(.system(size: 8, weight: .bold)).tracking(1) }.foregroundColor(.white).shadow(color: .black.opacity(0.4), radius: 3) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 39:
            base.overlay(alignment: .bottomLeading) { HStack(spacing: 2) { Image(systemName: "arrow.up.right").font(.system(size: 8, weight: .bold)); Text(pseudoDelta(post)).font(.system(size: 9, weight: .bold)) }.foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 2).background(Capsule().fill(Color.green)).padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 40:
            base.overlay(alignment: .topTrailing) { Image(systemName: "star.fill").font(.system(size: 11)).foregroundColor(.yellow).padding(5) }.overlay(alignment: .bottomLeading) { cornerChip(pseudoDelta(post), bg: AnyShapeStyle(Color.green)).padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 41:
            base.overlay(alignment: .topLeading) { cornerChip(pseudoPhase(post), bg: AnyShapeStyle(GQGradients.primary)).padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 42:
            VStack(spacing: 0) { HStack { Text(pseudoPhase(post).uppercased()).font(.system(size: 9, weight: .bold)).tracking(1); Spacer() }.foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 3).background(GQGradients.primary); base }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 43:
            base.overlay(alignment: .bottomLeading) { HStack(spacing: 3) { cornerChip(pseudoPhase(post)); cornerChip(pseudoDuration(post)) }.padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 44:
            base.overlay(alignment: .bottom) { Text(pseudoPhase(post)).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(.white).padding(.bottom, 8).shadow(radius: 3) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 45:
            base.overlay(alignment: .bottomTrailing) { cornerChip(relDate(post.timestamp)).padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 46:
            base.overlay(alignment: .bottomLeading) { HStack(spacing: 4) { cornerChip(post.workoutType ?? "Post"); cornerChip(relDate(post.timestamp)) }.padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 47:
            VStack(spacing: 0) { base; HStack { Text(relDate(post.timestamp)).font(.system(size: 10, weight: .bold)); Spacer(); if let t = post.workoutType { Text(t).font(.system(size: 10)) } }.foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 4).background(GQGradients.primary) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 48:
            base.overlay(alignment: .topTrailing) { cornerChip(pseudoTimeOfDay(post), icon: "sunrise").padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 49:
            base.overlay(alignment: .bottomLeading) { HStack(spacing: 3) { cornerChip(pseudoTimeOfDay(post)); cornerChip(pseudoDuration(post)) }.padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 50:
            base.overlay(alignment: .bottom) { HStack(spacing: 3) { Image(systemName: "clock").font(.system(size: 9, weight: .semibold)); Text(pseudoDuration(post)).font(.system(size: 10, weight: .bold)) }.foregroundColor(.white).padding(.horizontal, 8).padding(.vertical, 4).background(Capsule().fill(frost)).padding(6) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 51:
            base.overlay(alignment: .bottomLeading) { HStack(spacing: 3) { Image(systemName: "figure.strengthtraining.traditional").font(.system(size: 9)); Text(pseudoMuscle(post)).font(.system(size: 9, weight: .bold)) }.foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 3).background(Capsule().fill(frost)).padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 52:
            base.overlay(alignment: .bottom) { HStack(spacing: 4) { cornerChip(pseudoDuration(post), bg: AnyShapeStyle(frost)); Image(systemName: "star.fill").font(.system(size: 9)).foregroundColor(.yellow) }.padding(6) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 53:
            VStack(spacing: 0) { base; HStack(spacing: 4) { Image(systemName: "clock").font(.system(size: 9)); Text(pseudoDuration(post)).font(.system(size: 10, weight: .semibold)); Spacer() }.foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 4).background(frost) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 54:
            VStack(spacing: 0) { base; HStack { Text(post.workoutType ?? "Post").font(.system(size: 10, weight: .bold)); Spacer(); Text(pseudoDuration(post)).font(.system(size: 10)) }.foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 4).background(LinearGradient(colors: [.black.opacity(0.75), .black.opacity(0.4)], startPoint: .bottom, endPoint: .top)) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 55:
            VStack(spacing: 0) { base; HStack { Text(post.workoutType ?? "Post").font(.system(size: 10, weight: .bold)); Spacer(); Text(pseudoDuration(post)).font(.system(size: 10)) }.foregroundColor(GQColors.textPrimary).padding(.horizontal, 6).padding(.vertical, 4).background(GQColors.surfaceBase) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 56:
            VStack(spacing: 0) { base; HStack { Text(pseudoDuration(post)).font(.system(size: 10, weight: .bold)); Spacer() }.foregroundColor(GQColors.textPrimary).padding(8).background(RoundedRectangle(cornerRadius: 0).fill(GQColors.surfaceBase).shadow(color: .black.opacity(0.05), radius: 2, y: -1)) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 57:
            base.overlay(alignment: .bottomLeading) { HStack(spacing: 4) { Image(systemName: "scalemass"); Text(pseudoVolume(post)).font(.system(size: 9, weight: .bold)); Text("·").opacity(0.5); Image(systemName: "clock"); Text(pseudoDuration(post)).font(.system(size: 9, weight: .bold)) }.foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 3).background(Capsule().fill(frost)).padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 58:
            VStack(spacing: 0) { HStack { Text(post.workoutType ?? "Post").font(.system(size: 10, weight: .bold)); Spacer() }.foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 3).background(GQColors.vividPurple); base }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 59:
            base.clipShape(RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(GQGradients.primary, lineWidth: 1.5)).overlay(alignment: .bottom) { cornerChip(pseudoDuration(post)).padding(6) }
        case 60:
            base.overlay(RoundedRectangle(cornerRadius: 8).inset(by: 1).stroke(GQGradients.primary.opacity(0.6), lineWidth: 0.8)).overlay(alignment: .bottomLeading) { cornerChip(pseudoTopLift(post)).padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 61:
            base.overlay(alignment: .topLeading) { Text(pseudoDuration(post)).font(.system(size: 10, weight: .bold)).foregroundColor(.white).rotationEffect(.degrees(-12)).padding(8) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 62:
            base.overlay(alignment: .topLeading) { Text(pseudoPhase(post).uppercased()).font(.system(size: 8, weight: .bold)).tracking(1).foregroundColor(.white).padding(.horizontal, 7).padding(.vertical, 2).background(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 6, bottomTrailingRadius: 6, topTrailingRadius: 0).fill(GQGradients.primary)) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 63:
            base.overlay(alignment: .bottom) { Text(post.caption.isEmpty ? pseudoTopLift(post) : post.caption).font(.system(size: 9, weight: .medium)).foregroundColor(.white).lineLimit(1).padding(.horizontal, 6).padding(.vertical, 4).frame(maxWidth: .infinity, alignment: .leading).background(LinearGradient(colors: [.black.opacity(0.7), .clear], startPoint: .bottom, endPoint: .top)) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 64:
            VStack(spacing: 0) { base; VStack(alignment: .leading, spacing: 1) { Text(pseudoTopLift(post)).font(.system(size: 10, weight: .bold)); Text(pseudoDuration(post) + " · " + pseudoMuscle(post)).font(.system(size: 9)).foregroundColor(GQColors.textTertiary) }.padding(6).frame(maxWidth: .infinity, alignment: .leading).background(GQColors.surfaceBase) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 65:
            base.overlay(alignment: .bottomLeading) { HStack(spacing: 4) { cornerChip("\(pseudoSets(post))×\(pseudoReps(post))"); cornerChip(pseudoVolume(post)) }.padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 66:
            base.overlay(alignment: .bottomLeading) { HStack(spacing: 4) { cornerChip(pseudoDuration(post), icon: "clock"); cornerChip("RPE \(pseudoRPE(post))") }.padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 67:
            base.overlay(alignment: .bottomLeading) { HStack(spacing: 4) { cornerChip(pseudoMuscle(post)); cornerChip(pseudoPhase(post), bg: AnyShapeStyle(GQGradients.primary)) }.padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 68:
            VStack(spacing: 0) { base; HStack(spacing: 6) { Label(pseudoDuration(post), systemImage: "clock").font(.system(size: 9, weight: .semibold)); Spacer(); Label("\(pseudoSets(post))", systemImage: "square.stack.3d.up").font(.system(size: 9, weight: .semibold)); Spacer(); Label(pseudoVolume(post), systemImage: "scalemass").font(.system(size: 9, weight: .semibold)) }.foregroundColor(GQColors.textSecondary).padding(.horizontal, 6).padding(.vertical, 4).background(GQColors.surfaceBase) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 69:
            VStack(spacing: 0) { base; HStack(spacing: 4) { statCell("Time", pseudoDuration(post)); statCell("Sets", "\(pseudoSets(post))"); statCell("RPE", "\(pseudoRPE(post))"); statCell("Vol", pseudoVolume(post)) }.padding(.horizontal, 6).padding(.vertical, 4).background(GQColors.surfaceBase) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 70:
            HStack(spacing: 0) { VStack(spacing: 4) { Text("\(pseudoSets(post))").font(.system(size: 10, weight: .bold)); Text("SETS").font(.system(size: 7)).foregroundColor(GQColors.textTertiary); Text(pseudoDuration(post)).font(.system(size: 10, weight: .bold)); Text("TIME").font(.system(size: 7)).foregroundColor(GQColors.textTertiary) }.frame(width: 40).frame(maxHeight: .infinity).background(GQColors.surfaceBase); base }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 71:
            HStack(spacing: 0) { base; VStack(spacing: 4) { Text("\(pseudoSets(post))").font(.system(size: 10, weight: .bold)); Text("SETS").font(.system(size: 7)).foregroundColor(GQColors.textTertiary); Text(pseudoDuration(post)).font(.system(size: 10, weight: .bold)); Text("TIME").font(.system(size: 7)).foregroundColor(GQColors.textTertiary) }.frame(width: 40).frame(maxHeight: .infinity).background(GQColors.surfaceBase) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 72:
            VStack(spacing: 0) { HStack { Text(pseudoPhase(post)).font(.system(size: 9, weight: .bold)); Spacer() }.foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 3).background(GQGradients.primary); base; HStack { Text(pseudoTopLift(post)).font(.system(size: 9, weight: .semibold)); Spacer() }.foregroundColor(GQColors.textSecondary).padding(.horizontal, 6).padding(.vertical, 3).background(GQColors.surfaceBase) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 73:
            VStack(spacing: 0) { HStack { Text(pseudoTimeOfDay(post)).font(.system(size: 9, weight: .bold)); Spacer(); Text(pseudoDuration(post)).font(.system(size: 9, weight: .bold)) }.foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 3).background(LinearGradient(colors: [GQColors.deepBlue.opacity(0.9), GQColors.vividPurple.opacity(0.9)], startPoint: .leading, endPoint: .trailing)); base }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 74:
            VStack(spacing: 0) { base.aspectRatio(4/3, contentMode: .fill); HStack { VStack(alignment: .leading, spacing: 0) { Text(pseudoTopLift(post)).font(.system(size: 10, weight: .bold)); Text(post.workoutType ?? "Workout").font(.system(size: 9)).foregroundColor(GQColors.textTertiary) }; Spacer() }.padding(6).background(GQColors.surfaceBase) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 75:
            base.overlay(alignment: .center) { Text(post.workoutType?.prefix(1).uppercased() ?? "W").font(.system(size: 60, weight: .black, design: .rounded)).foregroundColor(.white.opacity(0.18)) }.overlay(alignment: .bottomLeading) { cornerChip(pseudoTopLift(post)).padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 76:
            base.overlay(alignment: .topTrailing) { Image(systemName: "figure.strengthtraining.traditional").font(.system(size: 50)).foregroundColor(.white.opacity(0.12)).offset(x: 5, y: -5) }.overlay(alignment: .bottom) { cornerChip(pseudoDuration(post)).padding(6) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 77:
            base.overlay(LinearGradient(colors: [GQColors.vividPurple.opacity(0.35), .clear], startPoint: .bottom, endPoint: .center)).overlay(alignment: .bottomLeading) { cornerChip(pseudoTopLift(post)).padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 78:
            base.overlay(LinearGradient(colors: [.clear, GQColors.deepBlue.opacity(0.45)], startPoint: .topLeading, endPoint: .bottomTrailing)).overlay(alignment: .topTrailing) { Text(pseudoDuration(post)).font(.system(size: 10, weight: .bold)).foregroundColor(.white).padding(6) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 79:
            base.overlay(alignment: .topTrailing) { Image(systemName: "star.fill").font(.system(size: 14)).foregroundColor(.yellow).shadow(color: .black.opacity(0.4), radius: 2).padding(5) }.overlay(alignment: .bottom) { cornerChip(pseudoTopLift(post)).padding(6) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 80:
            base.overlay(alignment: .topLeading) { Text("PR").font(.system(size: 10, weight: .bold)).foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 2).background(Color.yellow).clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 6, bottomTrailingRadius: 6, topTrailingRadius: 0)) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 81:
            base.overlay(alignment: .topTrailing) { Image(systemName: "crown.fill").font(.system(size: 13)).foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)).padding(5) }.overlay(alignment: .bottom) { cornerChip(pseudoTopLift(post)).padding(6) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 82:
            base.overlay(alignment: .topTrailing) { ZStack { Circle().fill(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)).frame(width: 20, height: 20); Image(systemName: "star.fill").font(.system(size: 11)).foregroundColor(.white) }.padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 83:
            base.overlay(alignment: .topLeading) { ZStack { Circle().fill(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 24, height: 24); Text("1").font(.system(size: 11, weight: .black)).foregroundColor(.white) }.padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 84:
            base.overlay(alignment: .topLeading) { isRecent(post.timestamp) ? AnyView(cornerChip("NEW", bg: AnyShapeStyle(GQGradients.primary))) : AnyView(EmptyView()) }.overlay(alignment: .bottom) { cornerChip(pseudoDuration(post)).padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 85:
            base.overlay(alignment: .topLeading) { isRecent(post.timestamp) ? AnyView(cornerChip("NEW", bg: AnyShapeStyle(GQGradients.primary))) : AnyView(EmptyView()) }.overlay(alignment: .bottom) { cornerChip(pseudoVolume(post)).padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 86:
            base.overlay(alignment: .topLeading) { cornerChip("NEW", bg: AnyShapeStyle(GQGradients.primary)).padding(5) }.overlay(alignment: .topTrailing) { Image(systemName: "star.fill").font(.system(size: 12)).foregroundColor(.yellow).padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 87:
            base.overlay(alignment: .topLeading) { HStack(spacing: 2) { Image(systemName: "flame.fill").font(.system(size: 9)).foregroundStyle(LinearGradient(colors: [.orange, .red.opacity(0.9)], startPoint: .bottom, endPoint: .top)); Text("7").font(.system(size: 9, weight: .bold)).foregroundColor(.white) }.padding(.horizontal, 5).padding(.vertical, 2).background(Capsule().fill(.black.opacity(0.5))).padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 88:
            base.overlay(alignment: .topLeading) { HStack(spacing: 2) { Image(systemName: "flame.fill").font(.system(size: 9)).foregroundStyle(LinearGradient(colors: [.orange, .red.opacity(0.9)], startPoint: .bottom, endPoint: .top)); Text("7").font(.system(size: 9, weight: .bold)).foregroundColor(.white) }.padding(.horizontal, 5).padding(.vertical, 2).background(Capsule().fill(.black.opacity(0.5))).padding(5) }.overlay(alignment: .topTrailing) { Image(systemName: "star.fill").font(.system(size: 11)).foregroundColor(.yellow).padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 89:
            base.clipShape(RoundedRectangle(cornerRadius: 8)).shadow(color: GQColors.vividPurple.opacity(0.35), radius: 6, y: 2).overlay(alignment: .bottomLeading) { cornerChip(pseudoTopLift(post)).padding(5) }
        case 90:
            base.clipShape(RoundedRectangle(cornerRadius: 8)).shadow(color: GQColors.vividPurple.opacity(0.2), radius: 3, y: 1)
        case 91:
            base.overlay(alignment: .topLeading) { ZStack { Circle().fill(GQGradients.primary).frame(width: 6, height: 6) }.padding(6) }.overlay(alignment: .bottom) { cornerChip(pseudoDuration(post)).padding(6) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 92:
            base.overlay(alignment: .topLeading) { Text("WEEK BEST").font(.system(size: 7, weight: .bold)).tracking(0.8).foregroundColor(.white).padding(.horizontal, 5).padding(.vertical, 2).background(Capsule().fill(GQGradients.primary)).padding(5) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 93:
            base.overlay(alignment: .top) { Text("PERSONAL BEST").font(.system(size: 7, weight: .bold)).tracking(0.8).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 2).background(GQGradients.primary) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 94:
            VStack(spacing: 0) { base; HStack(spacing: 0) { statCell("TIME", pseudoDuration(post)); Divider().frame(height: 18); statCell("SETS", "\(pseudoSets(post))"); Divider().frame(height: 18); statCell("RPE", "\(pseudoRPE(post))") }.padding(.vertical, 4).background(GQColors.surfaceBase) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 95:
            VStack(spacing: 0) { base; HStack(spacing: 0) { statCell("TIME", pseudoDuration(post)); Divider().frame(height: 18); statCell("SETS", "\(pseudoSets(post))"); Divider().frame(height: 18); statCell("RPE", "\(pseudoRPE(post))"); Divider().frame(height: 18); statCell("VOL", pseudoVolume(post)) }.padding(.vertical, 4).background(GQColors.surfaceBase) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 96:
            base.overlay(alignment: .bottomTrailing) { Text(pseudoDuration(post)).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(.white).shadow(color: .black.opacity(0.6), radius: 2).padding(6) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 97:
            base.overlay(alignment: .bottomTrailing) { Text(pseudoVolume(post)).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(.white).shadow(color: .black.opacity(0.6), radius: 2).padding(6) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 98:
            base.overlay(alignment: .topTrailing) { Image(systemName: "star.fill").font(.system(size: 12)).foregroundColor(.yellow).padding(6) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 99:
            base.overlay(LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom).frame(height: 40).frame(maxHeight: .infinity, alignment: .bottom)).overlay(alignment: .bottomLeading) { VStack(alignment: .leading, spacing: 1) { Text(pseudoTopLift(post)).font(.system(size: 10, weight: .bold)).foregroundColor(.white); Text("\(pseudoDuration(post)) · \(pseudoMuscle(post))").font(.system(size: 9)).foregroundColor(.white.opacity(0.85)) }.padding(6) }.clipShape(RoundedRectangle(cornerRadius: 8))
        case 100:
            base.overlay(LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)).overlay(alignment: .topLeading) { isRecent(post.timestamp) ? AnyView(cornerChip("NEW", bg: AnyShapeStyle(GQGradients.primary)).padding(5)) : AnyView(EmptyView()) }.overlay(alignment: .topTrailing) { Image(systemName: "star.fill").font(.system(size: 12)).foregroundColor(.yellow).padding(5) }.overlay(alignment: .bottomLeading) { VStack(alignment: .leading, spacing: 1) { Text(pseudoTopLift(post)).font(.system(size: 10, weight: .bold)).foregroundColor(.white); HStack(spacing: 6) { Label(pseudoDuration(post), systemImage: "clock").font(.system(size: 8, weight: .semibold)); Label(pseudoMuscle(post), systemImage: "figure.strengthtraining.traditional").font(.system(size: 8, weight: .semibold)) }.foregroundColor(.white.opacity(0.85)) }.padding(6) }.clipShape(RoundedRectangle(cornerRadius: 8))
        default: base.clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    fileprivate func statCell(_ label: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            Text(value).font(.system(size: 10, weight: .bold)).foregroundColor(GQColors.textPrimary)
            Text(label).font(.system(size: 7, weight: .semibold)).tracking(0.6).foregroundColor(GQColors.textTertiary)
        }.frame(maxWidth: .infinity)
    }

    fileprivate func isRecent(_ d: Date) -> Bool {
        Date().timeIntervalSince(d) < 24 * 3600
    }

    fileprivate func relDate(_ d: Date) -> String {
        let s = Int(Date().timeIntervalSince(d))
        if s < 3600 { return "\(max(s/60, 1))m" }
        if s < 86400 { return "\(s/3600)h" }
        return "\(s/86400)d"
    }

    @ViewBuilder
    fileprivate func tapThumb<Content: View>(_ post: Post, @ViewBuilder _ content: () -> Content) -> some View {
        Button { selectedPost = post } label: { content() }
            .buttonStyle(GQInteractiveStyle())
    }

    fileprivate func shortDate(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f.string(from: d)
    }
}

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

private struct ProfileEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(GQColors.textTertiary)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(GQColors.textPrimary)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundColor(GQColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
    }
}


// MARK: - Profile Lifetime Stat Item

struct ProfileLifetimeStatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(GQColors.textPrimary)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Workout History Row (from Workout model)

struct WorkoutHistoryRowV2: View {
    let workout: Workout
    private var iconAccent: Color {
        GQGradients.workoutGradientColors(for: workout.type).first ?? profilePrimaryAccent
    }
    private var accent: Color {
        profileNeutralAccent
    }

    var body: some View {
        HStack(spacing: 10) {
            WorkoutTypeBadge(type: workout.type, size: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text(workout.title ?? workout.type.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    if workout.duration > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                                .foregroundColor(GQColors.adaptiveOverlay(0.30))
                            Text("\(workout.duration) min")
                                .font(.system(size: 13))
                                .foregroundColor(GQColors.textSecondary)
                        }
                    }
                    if workout.totalSets > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 11))
                                .foregroundColor(GQColors.textSecondary)
                            Text("\(workout.totalSets) sets")
                                .font(.system(size: 13))
                                .foregroundColor(GQColors.textSecondary)
                        }
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(GQColors.textTertiary)
        }
        .padding(14)
        .homeSocialCard(accent: accent, subtle: true)
    }
}

// MARK: - Workout History Row (legacy - from Post model)

struct WorkoutHistoryRow: View {
    let post: Post

    var body: some View {
        HStack(spacing: 14) {
            // Date circle
            VStack(spacing: 2) {
                Text(post.timestamp.formatted(.dateTime.day()))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(GQColors.textPrimary)
                Text(post.timestamp.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.system(size: 11))
                    .foregroundColor(GQColors.textTertiary)
            }
            .frame(width: 44)

            // Workout info
            VStack(alignment: .leading, spacing: 4) {
                Text(post.workoutType ?? "Workout")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    if let duration = post.duration, duration > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                                .foregroundColor(GQColors.adaptiveOverlay(0.30))
                            Text("\(duration) min")
                                .font(.system(size: 13))
                                .foregroundColor(GQColors.textSecondary)
                        }
                    }
                    if let sets = post.setCount, sets > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 11))
                                .foregroundColor(GQColors.textSecondary)
                            Text("\(sets) sets")
                                .font(.system(size: 13))
                                .foregroundColor(GQColors.textSecondary)
                        }
                    }
                }
            }

            Spacer()

            // Thumbnail if has photo
            #if canImport(UIKit)
            if let data = post.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)
            }
            #endif

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(GQColors.textTertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(GQColors.surfaceBase)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                LinearGradient(
                    colors: [GQColors.overlayLight, GQColors.overlaySubtle],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
        )
    }
}

// MARK: - Post Thumbnail (Grid style)

struct ProfilePostThumbnail: View {
    let post: Post
    #if canImport(UIKit)
    @State private var cachedImage: UIImage?
    #elseif canImport(AppKit)
    @State private var cachedImage: NSImage?
    #endif

    private var hasVideo: Bool {
        post.videoData != nil || post.mediaItems.contains { $0.mediaType == .video }
    }

    /// "Multi" == a carousel of more than one `PostMedia`. A single video that
    /// also has a cover `photoData` is NOT multi.
    private var hasMultipleMedia: Bool {
        post.mediaItems.count > 1
    }

    /// True when the post's primary content is a video (even if photoData
    /// holds a cover thumbnail) and it isn't a carousel.
    private var isSingleVideo: Bool {
        guard !hasMultipleMedia else { return false }
        return hasVideo
    }

    private var thumbnailIcon: String? {
        if let type = post.workoutType, let wt = WorkoutType(rawValue: type) {
            return wt.icon
        }
        return nil
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                #if canImport(UIKit)
                if let image = cachedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.width)
                        .clipped()
                } else if hasVideo {
                    GQColors.surfaceElevated
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.6))
                        )
                } else {
                    GQColors.surfaceSecondary
                        .overlay(
                            VStack(spacing: 3) {
                                if let type = post.workoutType {
                                    WorkoutTypeBadgeFromString(typeName: type, size: 26)
                                    Text(type)
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(GQColors.textTertiary)
                                } else {
                                    Image(systemName: "text.quote")
                                        .font(.system(size: 18))
                                        .foregroundColor(GQColors.textTertiary)
                                }
                            }
                        )
                }
                #elseif canImport(AppKit)
                if let image = cachedImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.width)
                        .clipped()
                } else {
                    GQColors.surfaceSecondary
                        .overlay(
                            Image(systemName: "text.quote")
                                .font(.system(size: 18))
                                .foregroundColor(GQColors.textTertiary)
                        )
                }
                #endif
            }
            .frame(width: geo.size.width, height: geo.size.width)
        }
        .aspectRatio(1, contentMode: .fit)
        .task {
            if cachedImage != nil { return }
            // Try photoData first, then first media item thumbnail
            if let data = post.photoData {
                #if canImport(UIKit)
                cachedImage = UIImage(data: data)
                #elseif canImport(AppKit)
                cachedImage = NSImage(data: data)
                #endif
            } else if let first = post.mediaItems.first {
                let imgData = first.thumbnailData ?? first.data
                if let imgData = imgData {
                    #if canImport(UIKit)
                    cachedImage = UIImage(data: imgData)
                    #elseif canImport(AppKit)
                    cachedImage = NSImage(data: imgData)
                    #endif
                }
            }
        }
        // Top-right badge:
        //   · multi-media post (photos, or mixed photos+videos) → carousel icon
        //   · single video → camcorder icon (not a play triangle)
        //   · single photo → no badge
        .overlay(alignment: .topTrailing) {
            if hasMultipleMedia {
                Image(systemName: "square.on.square")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                    .padding(6)
            } else if isSingleVideo {
                Image(systemName: "video.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                    .padding(6)
            }
        }
        // Bottom-left: subtle workout type icon
        .overlay(alignment: .bottomLeading) {
            if let icon = thumbnailIcon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                    .padding(5)
            }
        }
    }
}

// MARK: - Profile Post Card (Grid card with stats)

struct ProfilePostCard: View {
    let post: Post

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image/Media area
            ZStack(alignment: .bottomLeading) {
                #if canImport(UIKit)
                if let data = post.photoData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 140)
                        .clipped()
                } else if post.videoData != nil {
                    GQColors.surfaceElevated
                        .frame(height: 140)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white.opacity(0.8))
                        )
                } else {
                    // No media - gradient background with icon
                    LinearGradient(
                        colors: [GQColors.deepBlue.opacity(0.22), profileFireAccent.opacity(0.16)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 140)
                    .overlay(
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.4))
                    )
                }
                #elseif canImport(AppKit)
                if let data = post.photoData, let image = NSImage(data: data) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 140)
                        .clipped()
                } else {
                    LinearGradient(
                        colors: [GQColors.deepBlue.opacity(0.22), profileFireAccent.opacity(0.16)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 140)
                    .overlay(
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.4))
                    )
                }
                #endif

                // Workout type badge overlay
                if let workoutType = post.workoutType {
                    Text(workoutType)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(GQColors.surfaceOverlay.opacity(0.90))
                        )
                        .padding(8)
                }
            }

            // Stats below image
            HStack(spacing: 12) {
                if let duration = post.duration, duration > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                            .foregroundColor(GQColors.textSecondary)
                        Text("\(duration)m")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(GQColors.textPrimary)
                    }
                }

                if let sets = post.setCount, sets > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11))
                            .foregroundColor(profileFireAccent)
                        Text("\(sets)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(GQColors.textPrimary)
                    }
                }

                Spacer()

                // Time ago
                Text(post.timestamp.timeAgoDisplay())
                    .font(.system(size: 11))
                    .foregroundColor(GQColors.textTertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(GQColors.surfaceBase)
        }
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(GQColors.surfaceSecondary, lineWidth: 1)
        )
    }
}

// shown when post has no photo/video - displays workout info visually
struct WorkoutStatsCard: View {
    let post: Post

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 40))
                .foregroundStyle(GQGradients.primary)
                .opacity(0.6)

            if let type = post.workoutType {
                Text(type)
                    .font(.headline)
                    .foregroundColor(GQColors.textPrimary)
            }

            HStack(spacing: 32) {
                if let duration = post.duration {
                    VStack(spacing: 4) {
                        Text("\(duration)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(GQColors.textSecondary)
                        Text("min")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(GQColors.textTertiary)
                    }
                }
                if let sets = post.setCount {
                    VStack(spacing: 4) {
                        Text("\(sets)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(profileFireAccent)
                        Text("sets")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(GQColors.textTertiary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .background(GQColors.surfaceBase)
    }
}

// full screen view of a post with all details
struct PostDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let post: Post
    let profile: UserProfile

    @State private var showVideoPlayer = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // header
                    HStack(spacing: 12) {
                        Circle()
                            .fill(GQGradients.primary)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Text(String(post.authorName.prefix(1)).uppercased())
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(post.authorName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(GQColors.textPrimary)
                            Text(post.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 13))
                                .foregroundColor(GQColors.textTertiary)
                        }

                        Spacer()

                        if let workoutType = post.workoutType {
                            Text(workoutType)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(GQColors.textPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            Capsule()
                                                .stroke(GQColors.adaptiveOverlay(0.13), lineWidth: 1)
                                        )
                                )
                        }
                    }
                    .padding(.horizontal)

                    // media
                    #if canImport(UIKit)
                    if let data = post.photoData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .cornerRadius(12)
                            .padding(.horizontal)
                    } else if post.videoData != nil {
                        Button {
                            showVideoPlayer = true
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .frame(height: 250)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(GQGradients.glassBorder, lineWidth: 1)
                                    )
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundStyle(GQGradients.primary)
                            }
                        }
                        .padding(.horizontal)
                    }
                    #endif

                    // caption
                    if !post.caption.isEmpty {
                        Text(post.caption)
                            .font(.system(size: 16))
                            .foregroundColor(GQColors.textPrimary)
                            .lineSpacing(4)
                            .padding(.horizontal)
                    }

                    // workout stats
                    if post.duration != nil || post.setCount != nil {
                        GlassCard(accentColor: profileNeutralAccent, cornerRadius: 16, showGlow: false) {
                            HStack(spacing: 32) {
                                if let duration = post.duration {
                                    VStack(spacing: 4) {
                                        Text("\(duration)")
                                            .font(.system(size: 28, weight: .bold))
                                            .foregroundColor(GQColors.textSecondary)
                                        Text("minutes")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(GQColors.textTertiary)
                                    }
                                }
                                if let sets = post.setCount {
                                    VStack(spacing: 4) {
                                        Text("\(sets)")
                                            .font(.system(size: 28, weight: .bold))
                                            .foregroundColor(profileFireAccent)
                                        Text("sets")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(GQColors.textTertiary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .padding(.horizontal)
                    }

                    // engagement
                    HStack(spacing: 24) {
                        Label("\(post.likeCount) likes", systemImage: "heart.fill")
                            .foregroundColor(profileFireAccent)
                        Label("\(post.commentCount) comments", systemImage: "bubble.right")
                            .foregroundColor(GQColors.textTertiary)
                        Spacer()
                    }
                    .font(.subheadline)
                    .padding(.horizontal)

                    Spacer().frame(height: 40)
                }
                .padding(.top)
            }
            .gqPageBackground()
            .navigationTitle("Post")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(GQColors.textSecondary)
                }
            }
            #if canImport(UIKit)
            .fullScreenCover(isPresented: $showVideoPlayer) {
                if let videoData = post.videoData {
                    ProfileVideoPlayerView(videoData: videoData, isPresented: $showVideoPlayer)
                }
            }
            #endif
        }
    }
}

#if canImport(UIKit)
struct ProfileVideoPlayerView: View {
    let videoData: Data
    @Binding var isPresented: Bool
    @State private var player: AVPlayer?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                ProgressView()
                    .tint(.white)
            }

            Button {
                player?.pause()
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
                    .padding()
            }
        }
        .onAppear {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
            do {
                try videoData.write(to: tempURL)
                player = AVPlayer(url: tempURL)
                player?.play()
            } catch {
                print("Error creating video: \(error)")
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}
#endif

// account settings - name, ai provider, api keys, logout
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState

    let profile: UserProfile

    @State private var name: String = ""
    @State private var username: String = ""
    @State private var aiProvider: AIProvider = .demo
    @State private var apiKey: String = ""
    @State private var ollamaModel: String = "llama3.2"
    @State private var ollamaHost: String = "localhost"
    @State private var showingLogoutAlert = false
    @State private var isTestingConnection = false
    @State private var connectionStatus: String?
    @State private var showingConnectionAlert = false
    @State private var showingSaveError = false
    @State private var gymName: String = ""
    @State private var preferredDuration: Int = 60
    @State private var experienceLevel: ExperienceLevel = .intermediate
    @State private var selectedEquipment: Set<EquipmentType> = []

    @StateObject private var authService = AuthService()
    @AppStorage("appAppearance") private var appAppearance: String = AppAppearance.light.rawValue
    @AppStorage("hapticFeedbackEnabled") private var hapticEnabled = true

    private var settingsDivider: some View {
        Rectangle()
            .fill(GQColors.adaptiveOverlay(0.08))
            .frame(height: 0.33)
            .padding(.vertical, 1)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {

                // MARK: Account
                VStack(alignment: .leading, spacing: 6) {
                    Text("Account")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                    settingsTextField(title: "Name", text: $name)
                    settingsTextField(title: "Username", text: $username)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .homeSocialCard(cornerRadius: 16)

                settingsDivider

                // MARK: Preferences
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preferences")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Theme")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(GQColors.textPrimary)
                        settingsPillPicker(
                            items: AppAppearance.allCases.map { $0.rawValue },
                            selection: $appAppearance
                        )
                    }

                    #if canImport(UIKit)
                    settingsToggleRow(
                        title: "Haptic Feedback",
                        subtitle: "Vibration on taps and actions",
                        isOn: $hapticEnabled
                    )
                    #endif

                    settingsToggleRow(
                        title: "Public Profile",
                        subtitle: profile.isProfilePublic ? "Anyone can see your posts" : "Only mutual friends",
                        isOn: Binding(
                            get: { profile.isProfilePublic },
                            set: { newValue in
                                profile.isProfilePublic = newValue
                                try? modelContext.save()
                            }
                        )
                    )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .homeSocialCard(cornerRadius: 16)

                settingsDivider

                // MARK: Links

                VStack(spacing: 0) {
                    settingsNavRow(icon: "figure.arms.open", title: "Body Measurements", subtitle: "Track weight, body fat & more", color: GQColors.textSecondary) {
                        BodyMeasurementsView(profile: profile)
                    }
                    Divider().padding(.leading, 70)
                    settingsNavRow(icon: "heart.fill", title: "Apple Health & Watch", subtitle: "Sync data & integrations", color: GQColors.textSecondary) {
                        IntegrationsView(profile: profile)
                    }
                    Divider().padding(.leading, 70)
                    settingsNavRow(icon: "waveform", title: "Music", subtitle: "Spotify & Apple Music", color: GQColors.textSecondary) {
                        IntegrationsView(profile: profile)
                    }
                    Divider().padding(.leading, 70)
                    settingsNavRow(icon: "person.2.fill", title: "Squads", subtitle: "Teams & challenges", color: GQColors.textSecondary) {
                        SquadView(profile: profile)
                    }
                    Divider().padding(.leading, 70)
                    settingsNavRow(icon: "bell.badge", title: "Notifications", subtitle: "Reminders & alerts", color: GQColors.textSecondary) {
                        NotificationSettingsView()
                    }
                }
                .homeSocialCard(cornerRadius: 16)

                settingsDivider

                // MARK: Founder Dashboard
                //
                // Memo 5 KPI surface. The three gold metrics (A24, W→P, D7)
                // plus Unprompted Return Rate and action-from-feed count.
                // Visible in Settings so you can check the numbers on-device
                // without needing a backend dashboard.
                FounderDashboardSection()
                    .homeSocialCard(cornerRadius: 16)

                settingsDivider

                // Sign Out
                Button {
                    showingLogoutAlert = true
                } label: {
                    Text("Sign Out")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
        .scrollContentBackground(.hidden)
        .gqPageBackground()
        .navigationTitle("Settings")
        .navigationBarBackButtonHidden(true)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 17))
                    }
                    .foregroundColor(GQColors.textPrimary)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    profile.name = name
                    profile.username = username.isEmpty ? name.lowercased().replacingOccurrences(of: " ", with: "") : username
                    profile.aiProvider = aiProvider
                    profile.apiKey = apiKey
                    if !apiKey.isEmpty {
                        AIKeychain.save(key: apiKey, userId: profile.id.uuidString)
                    }
                    profile.ollamaModel = ollamaModel
                    profile.ollamaHost = ollamaHost
                    profile.gymName = gymName
                    profile.preferredWorkoutDuration = preferredDuration
                    profile.experienceLevel = experienceLevel
                    profile.availableEquipment = Array(selectedEquipment)
                    do {
                        try modelContext.save()
                        dismiss()
                    } catch {
                        showingSaveError = true
                    }
                } label: {
                    Text("Save")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(GQGradients.primary)
                }
            }
        }
        .alert("Sign Out", isPresented: $showingLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                authService.setModelContext(modelContext)
                authService.logout(profile: profile)
                dismiss()
                appState.authState = .notAuthenticated
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Ollama Connection", isPresented: $showingConnectionAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(connectionStatus ?? "Unknown status")
        }
        .alert("Save Failed", isPresented: $showingSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Could not save settings. Please try again.")
        }
        .onAppear {
            name = profile.name
            username = profile.username
            aiProvider = profile.aiProvider
            apiKey = profile.apiKey
            ollamaModel = profile.ollamaModel
            ollamaHost = profile.ollamaHost
            gymName = profile.gymName
            preferredDuration = profile.preferredWorkoutDuration
            experienceLevel = profile.experienceLevel ?? .intermediate
            selectedEquipment = Set(profile.availableEquipment)
        }
    }

    @ViewBuilder
    private func settingsStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(GQColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var settingsStatDivider: some View {
        Rectangle()
            .fill(GQColors.borderSubtle)
            .frame(width: 0.5, height: 28)
    }

    @ViewBuilder
    private func settingsInfoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(GQColors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13))
                .foregroundColor(GQColors.textTertiary)
        }
    }

    @ViewBuilder
    private func settingsNavRow<Destination: View>(icon: String, title: String, subtitle: String = "", color: Color = GQColors.textSecondary, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(GQGradients.primary.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 17))
                        .foregroundStyle(GQGradients.primary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(GQColors.textPrimary)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(GQColors.textTertiary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(GQColors.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func settingsToggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(GQColors.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textTertiary)
            }
            Spacer()
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    isOn.wrappedValue.toggle()
                }
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
            } label: {
                ZStack(alignment: isOn.wrappedValue ? .trailing : .leading) {
                    Capsule()
                        .fill(isOn.wrappedValue ? AnyShapeStyle(GQGradients.primary.opacity(0.35)) : AnyShapeStyle(GQColors.adaptiveOverlay(0.12)))
                        .frame(width: 44, height: 26)
                    Circle()
                        .fill(isOn.wrappedValue ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(Color(white: 0.75)))
                        .frame(width: 22, height: 22)
                        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                        .padding(.horizontal, 2)
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func settingsPillPicker(items: [String], selection: Binding<String>) -> some View {
        HStack(spacing: 6) {
            ForEach(items, id: \.self) { item in
                let isSelected = selection.wrappedValue == item
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        selection.wrappedValue = item
                    }
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                } label: {
                    Text(item)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .foregroundColor(isSelected ? GQColors.textPrimary : GQColors.textSecondary)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? GQColors.adaptiveOverlay(0.15) : GQColors.adaptiveOverlay(0.05))
                        )
                }
                .buttonStyle(GQInteractiveStyle())
            }
        }
    }

    @ViewBuilder
    private func settingsTextField(
        title: String,
        text: Binding<String>,
        placeholder: String? = nil,
        isURL: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
            TextField(placeholder ?? title, text: text)
                .autocorrectionDisabled(isURL)
                #if os(iOS)
                .keyboardType(isURL ? .URL : .default)
                .textInputAutocapitalization(isURL ? .never : .sentences)
                #endif
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(GQColors.surfaceSecondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(GQColors.overlayMedium, lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    private func settingsSecureField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(GQColors.textSecondary)
            SecureField(title, text: text)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(GQColors.surfaceSecondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(GQColors.overlayMedium, lineWidth: 1)
                )
        }
    }

    // settingsRow removed — replaced by settingsNavRow

    // pings local ollama server to verify connection works
    private func testOllamaConnection() {
        isTestingConnection = true

        Task {
            let host = ollamaHost.isEmpty ? "localhost" : ollamaHost
            let urlString = "http://\(host):11434/api/tags"

            guard let url = URL(string: urlString) else {
                await MainActor.run {
                    connectionStatus = "Invalid URL"
                    showingConnectionAlert = true
                    isTestingConnection = false
                }
                return
            }

            var request = URLRequest(url: url)
            request.timeoutInterval = 10

            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    await MainActor.run {
                        connectionStatus = "No response from Ollama"
                        showingConnectionAlert = true
                        isTestingConnection = false
                    }
                    return
                }

                if httpResponse.statusCode == 200 {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let models = json["models"] as? [[String: Any]] {
                        let modelNames = models.compactMap { $0["name"] as? String }
                        await MainActor.run {
                            if modelNames.isEmpty {
                                connectionStatus = "Connected! No models installed. Run: ollama pull llama3.2"
                            } else {
                                connectionStatus = "Connected! Available models: \(modelNames.joined(separator: ", "))"
                            }
                            showingConnectionAlert = true
                            isTestingConnection = false
                        }
                    } else {
                        await MainActor.run {
                            connectionStatus = "Connected to Ollama!"
                            showingConnectionAlert = true
                            isTestingConnection = false
                        }
                    }
                } else {
                    await MainActor.run {
                        connectionStatus = "Ollama returned error: \(httpResponse.statusCode)"
                        showingConnectionAlert = true
                        isTestingConnection = false
                    }
                }
            } catch {
                await MainActor.run {
                    connectionStatus = "Connection failed: \(error.localizedDescription)\n\nMake sure Ollama is running with:\nOLLAMA_HOST=0.0.0.0 ollama serve"
                    showingConnectionAlert = true
                    isTestingConnection = false
                }
            }
        }
    }
}

// MARK: - Profile Post Browser (scrollable feed from thumbnail tap)

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

    private func postsForTab(_ tab: PostGridTab) -> [Post] {
        switch tab {
        case .photos: return photoPosts
        case .clips: return clipPosts
        case .tagged: return taggedPosts
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            GQColors.background.ignoresSafeArea()

            // Scrollable post feed
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    // Spacer for top bar
                    Color.clear.frame(height: 50)

                    ForEach(postsForTab(currentTab)) { post in
                        PostCardV2(
                            post: post,
                            currentUserId: profile.id,
                            currentUserName: profile.name,
                            profile: profile
                        )
                        .id(post.id)
                        Rectangle()
                            .fill(GQColors.borderSubtle)
                            .frame(height: 1)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: Binding<UUID?>(
                get: { nil },
                set: { _ in }
            ))

            // Top bar
            HStack {
                HStack(spacing: 0) {
                    ForEach([PostGridTab.photos, .clips, .tagged], id: \.self) { tab in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                currentTab = tab
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: tab == .photos ? "square.grid.3x3" : tab == .clips ? "play.rectangle" : "at")
                                    .font(.system(size: 16, weight: currentTab == tab ? .semibold : .regular))
                                    .foregroundColor(currentTab == tab ? GQColors.textPrimary : GQColors.textTertiary.opacity(0.45))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 36)
                                Rectangle()
                                    .fill(GQColors.textPrimary)
                                    .frame(height: 0.5)
                                    .opacity(currentTab == tab ? 1 : 0)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)

                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                        .frame(width: 28, height: 28)
                        .background(GQColors.surfaceSecondary, in: Circle())
                }
                .padding(.trailing, 4)
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .background(GQColors.background)
        }
    }
}

#Preview {
    ProfileView(profile: UserProfile())
        .environmentObject(AppState())
}

// MARK: - Achievement Detail Sheet

struct AchievementDetailSheet: View {
    let badge: ProfileView.ActiveChallenge
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(badge.isComplete ? AnyShapeStyle(GQGradients.primary.opacity(0.15)) : AnyShapeStyle(GQColors.surfaceSecondary))
                    .frame(width: 72, height: 72)
                Image(systemName: badge.isComplete ? "checkmark" : badge.icon)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(badge.isComplete ? AnyShapeStyle(GQColors.success) : AnyShapeStyle(GQGradients.primary))
            }

            // Title + status + category
            VStack(spacing: 4) {
                Text(badge.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(GQColors.textPrimary)
                HStack(spacing: 8) {
                    Text(badge.isComplete ? "Complete" : "In progress")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(badge.isComplete ? GQColors.success : GQColors.textTertiary)
                    Text(badge.category)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(badge.category == "For You" ? GQColors.vividPurple : GQColors.textTertiary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(
                                badge.category == "For You" ? GQColors.vividPurple.opacity(0.12) : GQColors.adaptiveOverlay(0.05)
                            )
                        )
                }
            }

            // Description
            Text(badge.description)
                .font(.system(size: 13))
                .foregroundColor(GQColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Progress bar + count
            VStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(GQColors.adaptiveOverlay(0.08))
                            .frame(height: 8)
                        Capsule()
                            .fill(badge.isComplete ? AnyShapeStyle(GQColors.success) : AnyShapeStyle(GQGradients.primary))
                            .frame(width: max(geo.size.width * badge.progress, 4), height: 8)
                    }
                }
                .frame(height: 8)
                .padding(.horizontal, 40)

                Text("\(badge.current) / \(badge.target)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(GQColors.textPrimary)
            }

            Spacer()
        }
        .padding(.top, 28)
        .frame(maxWidth: .infinity)
        .background(GQColors.background.ignoresSafeArea())
    }
}

// MARK: - Founder Dashboard Section
//
// The memo-5 KPI scorecard, rendered in Settings as a developer-grade
// metrics surface. Shows A24, W→P, D7, URR, and action-from-feed count
// with target thresholds and color-coded pass/fail.
//
// This is NOT a user-facing feature — it's a founder-grade instrument
// panel so you can check the numbers on-device without infrastructure.

struct FounderDashboardSection: View {
    @State private var dashboard: AnalyticsService.FounderDashboard? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "gauge.with.needle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(GQGradients.primary)
                Text("Founder Dashboard")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(GQColors.textPrimary)
                Spacer()
                Button {
                    dashboard = AnalyticsService.shared.getFounderDashboard()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(GQColors.textTertiary)
                }
            }

            if let d = dashboard {
                VStack(spacing: 8) {
                    kpiRow(label: "A24 (activation <24h)", rate: d.a24Rate, target: 0.40,
                           detail: "\(d.a24Activated)/\(d.a24Total) users")
                    kpiRow(label: "W→P (workout→post)", rate: d.wtopRate, target: 0.50,
                           detail: "\(d.wtopPosted)/\(d.wtopWorkouts) sessions")
                    kpiRow(label: "D7 (≥2 workouts in 7d)", rate: d.d7Rate, target: 0.25,
                           detail: "\(d.d7Retained)/\(d.d7Cohort) cohort")
                    kpiRow(label: "URR (unprompted return)", rate: d.urrRate, target: 0.50,
                           detail: "30-day window")

                    Divider().background(GQColors.borderDefault)

                    HStack(spacing: 16) {
                        miniStat(label: "Used", value: "\(d.totalUsedWorkouts)")
                        miniStat(label: "Workouts", value: "\(d.totalWorkouts)")
                        miniStat(label: "Posts", value: "\(d.totalPosts)")
                    }
                }
            } else {
                Button {
                    dashboard = AnalyticsService.shared.getFounderDashboard()
                } label: {
                    Text("Load metrics")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(GQColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(GQColors.adaptiveOverlay(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func kpiRow(label: String, rate: Double, target: Double, detail: String) -> some View {
        let pct = Int(rate * 100)
        let targetPct = Int(target * 100)
        let passing = rate >= target
        HStack(spacing: 8) {
            Image(systemName: passing ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(passing ? GQColors.success : Color.orange)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)
                Text("\(pct)% / \(targetPct)% target · \(detail)")
                    .font(.system(size: 10))
                    .foregroundColor(GQColors.textTertiary)
            }
            Spacer()
            Text("\(pct)%")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(passing ? GQColors.success : Color.orange)
        }
    }

    private func miniStat(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(GQColors.textPrimary)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(GQColors.textTertiary)
        }
    }
}
