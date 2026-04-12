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

    private var photoPosts: [Post] {
        userPosts.filter { post in
            post.photoData != nil ||
            post.mediaItems.contains { $0.mediaType == .photo }
        }
    }

    private var clipPosts: [Post] {
        userPosts.filter { postHasVideo($0) }
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
                    VStack(spacing: 8) {
                        profileHeader
                        profileCompletionBanner
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

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Avatar + stat columns row
            HStack(spacing: 16) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    profileAvatar
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "camera.circle.fill")
                                .font(.system(size: 24))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color(white: 0.4))
                                .offset(x: 2, y: 2)
                        }
                }
                .buttonStyle(.plain)
                .onChange(of: selectedPhotoItem) { _, newItem in
                    handleProfilePhotoSelection(newItem)
                }

                // Living-record stats. Memo 4 directive: contribution signals
                // outrank performance signals. "Workouts used" goes first when
                // available. Then days shown up, then streak, then witnesses.
                HStack(spacing: 0) {
                    if cachedUsedCount > 0 {
                        igStatColumn(value: "\(cachedUsedCount)", label: cachedUsedCount == 1 ? "Used" : "Used")
                    }
                    igStatColumn(value: "\(cachedDaysShownUp)", label: cachedDaysShownUp == 1 ? "Day" : "Days")
                    igStatColumn(value: "\(cachedStreak)", label: "Streak")
                    if cachedUsedCount == 0 {
                        igStatColumn(value: "\(cachedWitnessCount)", label: cachedWitnessCount == 1 ? "Witness" : "Witnesses")
                    }
                }
            }

            // "Show up for" anchor — the mission-aligned identity statement.
            // Set during onboarding, surfaced here as a quiet line under the name.
            if !profile.showUpFor.trimmingCharacters(in: .whitespaces).isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "figure.2.arms.open")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(GQColors.vividPurple)
                    Text("Showing up for \(profile.showUpFor)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(GQColors.textSecondary)
                }
                .padding(.top, 2)
            }

            // Used-by signal — only shows if someone has actually copied one of
            // this user's workouts. The highest-potency recognition line in the app.
            if cachedUsedCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(GQColors.success)
                    Text("\(cachedUsedCount) workout\(cachedUsedCount == 1 ? "" : "s") used by others")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(GQColors.textSecondary)
                }
                .padding(.top, 1)
            }

            // Name + level + member since
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(profile.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(GQColors.textPrimary)
                    if profile.isPremium {
                        PremiumBadge(size: 14)
                    }
                }
                HStack(spacing: 6) {
                    Text("\(UserProfile.levelTitle(for: profile.level)) · Lv.\(profile.level)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)

                    if healthKit.isAuthorized {
                        Text(readinessLevel.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(GQColors.textTertiary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(GQColors.adaptiveOverlay(0.05))
                            .clipShape(Capsule())
                    }
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

            // Edit Profile button
            Button {
                showingSettings = true
            } label: {
                Text("Edit Profile")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(GQColors.borderDefault, lineWidth: 1)
                    )
            }
            .buttonStyle(GQInteractiveStyle())
        }
        .padding(12)
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
        VStack(alignment: .leading, spacing: 8) {
            Text("ACHIEVEMENTS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(GQColors.textSecondary)
                .tracking(0.6)
                .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(allAchievements) { badge in
                        Button {
                            selectedAchievement = badge
                        } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(badge.isComplete ? AnyShapeStyle(GQGradients.primary.opacity(0.15)) : AnyShapeStyle(GQColors.surfaceSecondary))
                                        .frame(width: 48, height: 48)
                                    Image(systemName: badge.icon)
                                        .font(.system(size: 20))
                                        .foregroundStyle(badge.isComplete ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(GQColors.textTertiary.opacity(0.5)))
                                }
                                Text(badge.title)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(badge.isComplete ? GQColors.textPrimary : GQColors.textTertiary)
                                    .lineLimit(1)
                            }
                            .frame(width: 72)
                            .opacity(badge.isComplete ? 1 : 0.5)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 4)
        .sheet(item: $selectedAchievement) { badge in
            AchievementDetailSheet(badge: badge)
                .presentationDetents([.medium])
        }
    }

    // MARK: - (Top tab picker removed — single-level tabs now)

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
                            Image(systemName: tab == .photos ? "square.grid.3x3" : tab == .clips ? "play.rectangle" : "at")
                                .font(.system(size: 18))
                                .foregroundColor(postTab == tab ? GQColors.textPrimary : GQColors.textTertiary.opacity(0.45))
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.3)) {
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
                        Image(systemName: postTab == .photos ? "photo.on.rectangle.angled" : postTab == .clips ? "play.circle" : "at")
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(GQGradients.primary.opacity(0.4))
                        Text(postTab == .photos ? "No photos yet" : postTab == .clips ? "No clips yet" : "No tagged posts")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(GQColors.textTertiary)
                        Text(postTab == .tagged ? "When people tag you, it shows here" : "Share a workout to get started")
                            .font(.system(size: 12))
                            .foregroundColor(GQColors.textTertiary.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 56)
                } else {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 3),
                        spacing: 1
                    ) {
                        ForEach(activePosts) { post in
                            Button {
                                selectedPost = post
                            } label: {
                                ProfilePostThumbnail(post: post)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 2)
                }
            }
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

    private var hasMultipleMedia: Bool {
        post.mediaItems.count > 1
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
        // Top-right badge: carousel or video (Instagram style)
        .overlay(alignment: .topTrailing) {
            if hasMultipleMedia {
                Image(systemName: "square.on.square")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                    .padding(6)
            } else if hasVideo {
                Image(systemName: "play.fill")
                    .font(.system(size: 10))
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
