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

private let profileNeutralAccent = GQColors.overlayMedium
private let profilePrimaryAccent = GQColors.adaptiveOverlay(0.42)
private let profileFireAccent = GQColors.textSecondary

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
    @State private var showingCoach = false
    @State private var showingCalendarHistory = false
    @State private var showingHealthDashboard = false
    @State private var showingIntegrations = false

    // Activity stats state
    @State private var weeklyProgress: (completed: Int, target: Int) = (0, 0)
    @State private var readinessLevel: ReadinessLevel = .good

    // Cached computed stats (refreshed on appear and data change)
    @State private var cachedStreak: Int = 0
    @State private var cachedVolume: String = "0"
    @State private var cachedDuration: String = "0h"
    @State private var cachedWorkoutCount: Int = 0

    private var profileAccent: Color {
        profileNeutralAccent
    }

    private var userPosts: [Post] {
        let targetUsername = profile.username.lowercased()
        let targetName = profile.name.lowercased()

        return posts.filter { post in
            post.authorId == profile.id ||
            post.authorUsername.lowercased() == targetUsername ||
            post.authorName.lowercased() == targetName
        }
    }

    private var totalWorkoutCount: Int { cachedWorkoutCount }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    profileHeader
                    profileCompletionBanner
                    todayHealthStatsCard
                    achievementBadgesSection
                    VStack(spacing: 0) {
                        postsContent
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                    }
                    .homeSocialCard(cornerRadius: 14)
                }
                .padding(.horizontal, 16)
                .padding(.top, GQLayout.pageTop)
                .padding(.bottom, GQLayout.pageBottom)
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
            .sheet(isPresented: $showingSettings) {
                SettingsView(profile: profile)
            }
            .sheet(
                isPresented: Binding(
                    get: { selectedPost != nil },
                    set: { isPresented in
                        if !isPresented { selectedPost = nil }
                    }
                )
            ) {
                if let selectedPost {
                    PostDetailView(post: selectedPost, profile: profile)
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

        // Streak calculation
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let sortedDates = nonRest
            .map { calendar.startOfDay(for: $0.date) }

        let uniqueDates = Array(Set(sortedDates)).sorted(by: >)
        if let first = uniqueDates.first {
            let daysSinceFirst = calendar.dateComponents([.day], from: first, to: today).day ?? 0
            if daysSinceFirst <= 1 {
                var streak = 1
                for i in 1..<uniqueDates.count {
                    let diff = calendar.dateComponents([.day], from: uniqueDates[i], to: uniqueDates[i - 1]).day ?? 0
                    if diff == 1 {
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
            HStack(spacing: 20) {
                profileAvatar

                HStack(spacing: 0) {
                    igStatColumn(value: "\(userPosts.count)", label: "Posts")
                    igStatColumn(value: "\(profile.followerCount)", label: "Followers")
                    igStatColumn(value: "\(profile.followingCount)", label: "Following")
                }
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

    // MARK: - Achievement Badges

    private var achievementBadgesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ACHIEVEMENTS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(GQColors.textSecondary)
                .tracking(0.6)
                .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    achievementBadge(icon: "figure.walk", title: "First Workout", unlocked: totalWorkoutCount >= 1)
                    achievementBadge(icon: "flame.fill", title: "7-Day Streak", unlocked: profile.xp >= 500)
                    achievementBadge(icon: "flame.circle.fill", title: "30-Day Streak", unlocked: profile.xp >= 3000)
                    achievementBadge(icon: "trophy.fill", title: "100 Workouts", unlocked: totalWorkoutCount >= 100)
                    achievementBadge(icon: "star.fill", title: "PR Machine", unlocked: prEvents.count >= 10)
                    achievementBadge(icon: "bubble.left.and.bubble.right.fill", title: "Social Butterfly", unlocked: userPosts.count >= 10)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func achievementBadge(icon: String, title: String, unlocked: Bool) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(unlocked ? AnyShapeStyle(GQGradients.primary.opacity(0.15)) : AnyShapeStyle(GQColors.surfaceSecondary))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(unlocked ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(GQColors.textTertiary.opacity(0.5)))
            }
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(unlocked ? GQColors.textPrimary : GQColors.textTertiary)
                .lineLimit(1)
        }
        .frame(width: 72)
        .opacity(unlocked ? 1 : 0.5)
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
                .frame(width: 86, height: 86)

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
            .frame(width: 80, height: 80)
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
        if userPosts.isEmpty {
            ProfileEmptyState(
                icon: "camera.on.rectangle",
                title: "No posts yet",
                subtitle: "Share your sessions and progress here."
            )
        } else {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 2),
                    GridItem(.flexible(), spacing: 2),
                    GridItem(.flexible(), spacing: 2)
                ],
                spacing: 2
            ) {
                ForEach(userPosts) { post in
                    Button {
                        selectedPost = post
                    } label: {
                        ProfilePostThumbnail(post: post)
                    }
                    .buttonStyle(.plain)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
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

    var body: some View {
        ZStack {
            #if canImport(UIKit)
            if let image = cachedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [.black.opacity(0.4), .clear],
                            startPoint: .bottom,
                            endPoint: .center
                        )
                    )
            } else if post.videoData != nil {
                GQColors.surfaceElevated
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.8))
                    )
            } else {
                // No media - show workout type badge
                GQColors.surfaceBase
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        VStack(spacing: 6) {
                            if let type = post.workoutType {
                                WorkoutTypeBadgeFromString(typeName: type, size: 36)
                                Text(type)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(GQColors.textTertiary)
                            } else {
                                Image(systemName: "dumbbell.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(profilePrimaryAccent)
                            }
                        }
                    )
            }
            #elseif canImport(AppKit)
            if let image = cachedImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [.black.opacity(0.4), .clear],
                            startPoint: .bottom,
                            endPoint: .center
                        )
                    )
            } else {
                GQColors.surfaceBase
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 24))
                            .foregroundColor(profilePrimaryAccent)
                    )
            }
            #endif
        }
        .task {
            guard cachedImage == nil, let data = post.photoData else { return }
            #if canImport(UIKit)
            cachedImage = UIImage(data: data)
            #elseif canImport(AppKit)
            cachedImage = NSImage(data: data)
            #endif
        }
        .overlay(alignment: .bottomLeading) {
            if let type = post.workoutType {
                WorkoutTypeBadgeFromString(typeName: type, size: 24)
                    .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                    .padding(4)
            }
        }
        .cornerRadius(4)
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: GQLayout.sectionSpacing) {
                    GQScreenTitleBlock(
                        title: "Settings",
                        subtitle: "Profile, integrations, and preferences.",
                        accent: profileNeutralAccent
                    )
                    .gqScreenHorizontalPadding()
                    .padding(.top, GQLayout.pageTop)

                    // MARK: Account
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader("Account")
                        settingsTextField(title: "Name", text: $name)
                        settingsTextField(title: "Username", text: $username)

                        if let email = profile.email, !email.isEmpty {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Email")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(GQColors.textSecondary)
                                    Text(email)
                                        .font(.system(size: 14))
                                        .foregroundColor(GQColors.textPrimary)
                                }
                                Spacer()
                            }
                        }
                    }
                    .padding(16)
                    .homeSocialCard(accent: profileNeutralAccent)
                    .gqScreenHorizontalPadding()

                    // MARK: Preferences
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader("Preferences")

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Theme")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(GQColors.textSecondary)
                            Picker("Appearance", selection: $appAppearance) {
                                ForEach(AppAppearance.allCases, id: \.rawValue) { mode in
                                    Text(mode.rawValue).tag(mode.rawValue)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        #if canImport(UIKit)
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Haptic Feedback")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(GQColors.textPrimary)
                                Text("Vibration on taps and actions")
                                    .font(.system(size: 11))
                                    .foregroundColor(GQColors.textTertiary)
                            }
                            Spacer()
                            Toggle("", isOn: $hapticEnabled)
                                .labelsHidden()
                                .tint(GQColors.deepBlue)
                        }
                        #endif
                    }
                    .padding(16)
                    .homeSocialCard(accent: profileNeutralAccent)
                    .gqScreenHorizontalPadding()

                    // MARK: Gym Setup
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader("Gym Setup")

                        settingsTextField(title: "Gym Name", text: $gymName)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Experience Level")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(GQColors.textSecondary)
                            Picker("Experience", selection: $experienceLevel) {
                                ForEach(ExperienceLevel.allCases, id: \.self) { level in
                                    Text(level.rawValue).tag(level)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Workout Duration")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(GQColors.textSecondary)
                            Picker("Duration", selection: $preferredDuration) {
                                Text("30 min").tag(30)
                                Text("45 min").tag(45)
                                Text("60 min").tag(60)
                                Text("90 min").tag(90)
                            }
                            .pickerStyle(.segmented)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Equipment")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(GQColors.textSecondary)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                                ForEach(EquipmentType.allCases, id: \.self) { equipment in
                                    let isSelected = selectedEquipment.contains(equipment)
                                    Button {
                                        if isSelected {
                                            selectedEquipment.remove(equipment)
                                        } else {
                                            selectedEquipment.insert(equipment)
                                        }
                                    } label: {
                                        Text(equipment.rawValue)
                                            .font(.system(size: 12, weight: .medium))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 8)
                                            .frame(maxWidth: .infinity)
                                            .background(isSelected ? GQColors.deepBlue.opacity(0.15) : GQColors.overlaySubtle)
                                            .foregroundColor(isSelected ? GQColors.deepBlue : GQColors.textPrimary)
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(isSelected ? GQColors.deepBlue.opacity(0.5) : Color.clear, lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        NavigationLink {
                            BodyMeasurementsView(profile: profile)
                        } label: {
                            settingsRow(
                                icon: "ruler",
                                title: "Body Measurements",
                                subtitle: "Track physical changes over time",
                                color: GQColors.textSecondary
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                    .homeSocialCard(accent: profileNeutralAccent)
                    .gqScreenHorizontalPadding()

                    // MARK: Integrations
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader("Integrations")

                        NavigationLink {
                            IntegrationsView(profile: profile)
                        } label: {
                            settingsRow(
                                icon: "link.circle.fill",
                                title: "Connected Services",
                                subtitle: "Apple Health, WHOOP, Strava",
                                color: GQColors.textSecondary
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            SquadView(profile: profile)
                        } label: {
                            settingsRow(
                                icon: "person.3.fill",
                                title: "Squads",
                                subtitle: "Team challenges and accountability",
                                color: .blue
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                    .homeSocialCard(accent: profileNeutralAccent)
                    .gqScreenHorizontalPadding()

                    // MARK: Notifications
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader("Notifications")

                        NavigationLink {
                            NotificationSettingsView()
                        } label: {
                            settingsRow(
                                icon: "bell.fill",
                                title: "Notification Preferences",
                                subtitle: "Reminders and updates",
                                color: GQColors.textSecondary
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                    .homeSocialCard(accent: profileNeutralAccent)
                    .gqScreenHorizontalPadding()

                    // MARK: Privacy
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader("Privacy")

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Public Profile")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(GQColors.textPrimary)
                                Text(profile.isProfilePublic ? "Anyone can see your posts" : "Only mutual friends can see your posts")
                                    .font(.system(size: 11))
                                    .foregroundColor(GQColors.textTertiary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { profile.isProfilePublic },
                                set: { newValue in
                                    profile.isProfilePublic = newValue
                                    try? modelContext.save()
                                }
                            ))
                            .labelsHidden()
                            .tint(GQColors.deepBlue)
                        }
                    }
                    .padding(16)
                    .homeSocialCard(accent: profileNeutralAccent)
                    .gqScreenHorizontalPadding()

                    // MARK: AI
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader("AI")

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Provider")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(GQColors.textSecondary)
                            Picker("Provider", selection: $aiProvider) {
                                ForEach(AIProvider.allCases, id: \.self) { p in
                                    Text(p.rawValue).tag(p)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(GQColors.textPrimary)
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
                        .onChange(of: aiProvider) { _, newValue in
                            if newValue == .ollama {
                                testOllamaConnection()
                            }
                        }

                        if aiProvider == .ollama {
                            settingsTextField(
                                title: "Host IP",
                                text: $ollamaHost,
                                placeholder: "e.g. 192.168.1.100",
                                isURL: true
                            )
                            settingsTextField(
                                title: "Model Name",
                                text: $ollamaModel,
                                placeholder: "e.g. llama3.2"
                            )
                            Button {
                                testOllamaConnection()
                            } label: {
                                HStack(spacing: 8) {
                                    if isTestingConnection {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "network")
                                    }
                                    Text(isTestingConnection ? "Testing..." : "Test Connection")
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(isTestingConnection)
                        } else if aiProvider != .demo {
                            settingsSecureField(title: "API Key", text: $apiKey)
                        }
                    }
                    .padding(16)
                    .homeSocialCard(accent: profileNeutralAccent)
                    .gqScreenHorizontalPadding()

                    // MARK: Support & Legal
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader("Support & Legal")

                        HStack(spacing: 10) {
                            WorkoutFlowMetricChip(
                                icon: "star.fill",
                                value: "Lv \(profile.level)",
                                label: "Current Level",
                                color: GQColors.textSecondary
                            )
                            WorkoutFlowMetricChip(
                                icon: "bolt.fill",
                                value: "\(profile.xp)",
                                label: "XP",
                                color: GQColors.textSecondary
                            )
                        }

                        HStack {
                            Text("App Version")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(GQColors.textPrimary)
                            Spacer()
                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                                .font(.system(size: 14))
                                .foregroundColor(GQColors.textTertiary)
                        }
                    }
                    .padding(16)
                    .homeSocialCard(accent: profileNeutralAccent)
                    .gqScreenHorizontalPadding()

                    Button(role: .destructive) {
                        showingLogoutAlert = true
                    } label: {
                        Text("Sign Out")
                    }
                    .buttonStyle(HomeSocialSecondaryButtonStyle())
                    .gqScreenHorizontalPadding()

                    Spacer(minLength: 36)
                }
                .padding(.bottom, GQLayout.pageBottom)
            }
            .gqPageBackground()
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        profile.name = name
                        profile.username = username.isEmpty ? name.lowercased().replacingOccurrences(of: " ", with: "") : username
                        profile.aiProvider = aiProvider
                        profile.apiKey = apiKey
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
                    }
                    .fontWeight(.semibold)
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
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(GQColors.sectionLabel)
            .tracking(0.6)
    }

    @ViewBuilder
    private func settingsTextField(
        title: String,
        text: Binding<String>,
        placeholder: String? = nil,
        isURL: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(GQColors.textSecondary)
            TextField(placeholder ?? title, text: text)
                .autocorrectionDisabled(isURL)
                #if os(iOS)
                .keyboardType(isURL ? .URL : .default)
                .textInputAutocapitalization(isURL ? .never : .sentences)
                #endif
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

    @ViewBuilder
    private func settingsRow(
        icon: String,
        title: String,
        subtitle: String,
        color: Color
    ) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.18))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(color)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(GQColors.textTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .homeSocialCard(accent: color, subtle: true)
    }

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

#Preview {
    ProfileView(profile: UserProfile())
        .environmentObject(AppState())
}
