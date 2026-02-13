//
//  ProgressView.swift
//  GymQuest
//
//  Created by Benjamin Hilderman
//
//  Bold & Energetic progress tracking with glass cards
//  Animated progress bars, weekly chart, and full calendar
//

import SwiftUI
import SwiftData

private let progressNeutralAccent = Color.white.opacity(0.20)
private let progressFireAccent = GQColors.coralRed

struct TrainingProgressView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var featureFlags: FeatureFlags
    @Environment(\.modelContext) private var modelContext
    let profile: UserProfile
    let workouts: [Workout]
    @ObservedObject var aiService: AIService

    @State private var showingCalendar = false
    @State private var showingMealLog = false
    @State private var prMoments: [PRMoment] = []
    @State private var metricsSummary: AnalyticsService.MetricsSummary?
    @State private var activeQuest: (quest: Quest, progress: QuestProgress)?
    @State private var selectedWorkoutForReview: Workout?

    var streak: Int {
        aiService.calculateStreak(workouts: workouts)
    }

    var sessionsThisWeek: Int {
        let start = mondayOfCurrentWeek()
        return workouts.filter { $0.date >= start }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: GQLayout.sectionSpacing) {
                    // Recovery Card
                    RecoveryCard(streak: streak, sessionsThisWeek: sessionsThisWeek)
                        .gqScreenHorizontalPadding()
                        .padding(.top, GQLayout.pageTop)

                    HealthDashboardView(profile: profile, workouts: workouts)
                        .gqScreenHorizontalPadding()

                    HStack(spacing: 12) {
                        QuickActionButton(
                            icon: "calendar",
                            title: "Calendar",
                            color: Color.white.opacity(0.82)
                        ) {
                            showingCalendar = true
                        }

                        QuickActionButton(
                            icon: "fork.knife",
                            title: "Meals",
                            color: GQColors.coralRed
                        ) {
                            showingMealLog = true
                        }
                    }
                    .gqScreenHorizontalPadding()

                    WeekChartV2(workouts: workouts)
                        .gqScreenHorizontalPadding()

                    // Health Stats
                    healthStatsSection
                        .padding(.horizontal, 16)

                    // Personal Records
                    prSection

                    // All-Time Stats
                    allTimeStatsSection

                    // Daily Quest
                    questSection

                    // Recent Workouts
                    recentWorkoutsSection
                }
                .padding(.bottom, GQLayout.pageBottom)
            }
            .scrollContentBackground(.hidden)
            .gqPageBackground()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavBarLogo()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { loadProgressData() }
            .sheet(isPresented: $showingCalendar) {
                FullCalendarView(workouts: workouts)
            }
            .sheet(isPresented: $showingMealLog) {
                MealLogView(profile: profile)
            }
            .sheet(item: $selectedWorkoutForReview) { workout in
                WorkoutReviewSheet(workout: workout)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Extracted View Builders

    @ViewBuilder
    private var healthStatsSection: some View {
        HealthStatsSection()
    }

    @ViewBuilder
    private var prSection: some View {
        if !prMoments.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("PERSONAL RECORDS")
                    .font(GQTypography.sectionHeader)
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(1)
                    .padding(.horizontal, 16)

                ForEach(prMoments.prefix(5)) { pr in
                    PRRow(pr: pr)
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    @ViewBuilder
    private var allTimeStatsSection: some View {
        if let summary = metricsSummary {
            VStack(alignment: .leading, spacing: 12) {
                Text("ALL-TIME STATS")
                    .font(GQTypography.sectionHeader)
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(1)
                    .padding(.horizontal, 16)

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ], spacing: 10) {
                    AllTimeStatCard(icon: "dumbbell.fill", value: "\(summary.totalWorkouts)", label: "Workouts", color: GQColors.vividPurple)
                    AllTimeStatCard(icon: "trophy.fill", value: "\(summary.totalPRs)", label: "PRs Hit", color: GQColors.cyanSpark)
                    AllTimeStatCard(icon: "flag.checkered", value: "\(summary.totalQuestsCompleted)", label: "Quests", color: GQColors.success)
                    AllTimeStatCard(icon: "fork.knife", value: "\(summary.mealsLogged)", label: "Meals", color: GQColors.sunsetOrange)
                    AllTimeStatCard(icon: "square.and.arrow.up", value: "\(summary.totalShares)", label: "Shares", color: GQColors.electricBlue)
                    AllTimeStatCard(icon: "flame.fill", value: "\(summary.workoutsThisWeek)", label: "This Week", color: GQColors.success)
                }
                .padding(.horizontal, 16)
            }
        }
    }

    @ViewBuilder
    private var questSection: some View {
        if let quest = activeQuest {
            VStack(alignment: .leading, spacing: 12) {
                ActiveQuestCard(quest: quest.quest, progress: quest.progress)
                    .homeSocialCard()
                    .padding(.horizontal, 16)
            }
        }
    }

    @ViewBuilder
    private var recentWorkoutsSection: some View {
        if !workouts.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent Workouts")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)

                ForEach(workouts.prefix(4)) { workout in
                    CompactWorkoutRow(workout: workout)
                        .padding(.horizontal, 16)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedWorkoutForReview = workout
                        }
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadProgressData() {
        // Load PRMoments
        let prDescriptor = FetchDescriptor<PRMoment>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        prMoments = (try? modelContext.fetch(prDescriptor)) ?? []

        // Load metrics summary
        let analytics = AnalyticsService.shared
        metricsSummary = analytics.getMetricsSummary(userId: profile.id)

        // Load active quest
        if featureFlags.questsEnabled {
            let questService = QuestService.shared
            questService.configure(modelContext: modelContext)
            questService.seedDefaultQuests()
            activeQuest = questService.getTodaysQuest(userId: profile.id)
        }
    }

    func mondayOfCurrentWeek() -> Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        return cal.date(byAdding: .day, value: -daysFromMonday, to: today) ?? today
    }
}

// MARK: - PR Row

struct PRRow: View {
    let pr: PRMoment

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(GQColors.cyanSpark.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: "trophy.fill")
                    .font(.system(size: 16))
                    .foregroundColor(GQColors.cyanSpark)
            }

            VStack(alignment: .leading, spacing: 2) {
                if let name = pr.exerciseName {
                    Text(name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }

                Text(pr.value)
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let improvement = pr.improvement {
                    Text(improvement)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(GQColors.success)
                }

                Text(pr.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 11))
                    .foregroundColor(GQColors.textTertiary)
            }
        }
        .padding(14)
        .homeSocialCard(cornerRadius: 14, subtle: true)
    }
}

// MARK: - All-Time Stat Card

struct AllTimeStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .homeSocialCard(cornerRadius: 14, subtle: true)
    }
}

struct StatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(GQTypography.stat)
                .foregroundColor(.white)
            Text(label)
                .font(GQTypography.statLabel)
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Recovery Card (Bevel-inspired)

struct RecoveryCard: View {
    let streak: Int
    let sessionsThisWeek: Int
    @State private var animatedProgress: CGFloat = 0

    // Simulated recovery score based on workout frequency
    var recoveryScore: Int {
        // Simple calculation - could be enhanced with real HRV data
        let baseScore = 70
        let streakBonus = min(streak * 2, 15)
        let restPenalty = sessionsThisWeek > 5 ? 10 : 0
        return min(100, max(50, baseScore + streakBonus - restPenalty))
    }

    var recoveryMessage: String {
        switch recoveryScore {
        case 85...100: return "Fully recovered"
        case 70...84: return "Ready to train"
        case 60...69: return "Moderate recovery"
        default: return "Consider rest day"
        }
    }

    var recoveryColor: Color {
        switch recoveryScore {
        case 85...100: return GQColors.success
        case 70...84: return Color.white.opacity(0.82)
        case 60...69: return GQColors.coralRed.opacity(0.9)
        default: return GQColors.error
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recovery")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)

                    Text(recoveryMessage)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(.white)
                }

                Spacer()

                Text("\(recoveryScore)%")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 7)
                        .frame(width: 76, height: 76)

                    Circle()
                        .trim(from: 0, to: animatedProgress)
                        .stroke(recoveryColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .frame(width: 76, height: 76)
                        .rotationEffect(.degrees(-90))

                    Text("\(recoveryScore)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 8) {
                    WorkoutFlowMetricChip(
                        icon: "flame.fill",
                        value: "\(streak)",
                        label: "Day Streak",
                        color: progressFireAccent
                    )
                    WorkoutFlowMetricChip(
                        icon: "calendar",
                        value: "\(sessionsThisWeek)",
                        label: "Sessions This Week",
                        color: GQColors.textSecondary
                    )
                }

                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .homeSocialCard(accent: GQColors.cyanSpark, emphasized: true)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
                animatedProgress = CGFloat(recoveryScore) / 100
            }
        }
    }
}

// MARK: - Health Stats Section (Apple Health Data)

struct HealthStatsSection: View {
    @ObservedObject private var healthKit = HealthKitService.shared

    var caloriesFromSteps: Int {
        Int(Double(healthKit.steps) * 0.04)
    }

    var sleepQuality: String {
        if healthKit.sleepHours <= 0 { return "No data" }
        if healthKit.sleepHours >= 7 { return "Good rest" }
        if healthKit.sleepHours >= 5 { return "Could use more" }
        return "Sleep deprived"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Health")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                HealthStatCard(
                    icon: "figure.walk",
                    title: "Steps",
                    value: healthKit.steps > 0 ? "\(healthKit.steps.formatted())" : "--",
                    subtitle: healthKit.steps > 0 ? "~\(caloriesFromSteps) cal burned" : "No data",
                    color: GQColors.vividPurple
                )

                HealthStatCard(
                    icon: "moon.fill",
                    title: "Sleep",
                    value: healthKit.sleepHours > 0 ? String(format: "%.1fh", healthKit.sleepHours) : "--",
                    subtitle: sleepQuality,
                    color: GQColors.textSecondary
                )

                HealthStatCard(
                    icon: "flame.fill",
                    title: "Active Cal",
                    value: healthKit.activeCalories > 0 ? "\(healthKit.activeCalories)" : "--",
                    subtitle: healthKit.activeCalories > 0 ? "burned today" : "No data",
                    color: GQColors.success
                )

                HealthStatCard(
                    icon: "heart.fill",
                    title: "Resting HR",
                    value: healthKit.restingHeartRate > 0 ? "\(healthKit.restingHeartRate)" : "--",
                    subtitle: healthKit.restingHeartRate > 0 ? "bpm" : "No data",
                    color: GQColors.success
                )
            }
        }
        .onAppear {
            healthKit.requestAuthorizationSync()
            healthKit.fetchTodayData()
        }
    }
}

struct HealthStatCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(GQColors.textTertiary)
            }

            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            Text(subtitle)
                .font(.system(size: 11))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(GQColors.surfaceBase)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Today's Stats Row

struct TodayStatsRow: View {
    @State private var steps: Int = 0
    @State private var calories: Int = 0
    @State private var sleep: Double = 0

    var body: some View {
        HStack(spacing: 12) {
            // Steps
            TodayStatCard(
                icon: "figure.walk",
                value: steps > 0 ? "\(steps)" : "--",
                label: "Steps",
                color: GQColors.success
            )

            // Active Calories
            TodayStatCard(
                icon: "flame.fill",
                value: calories > 0 ? "\(calories)" : "--",
                label: "Calories",
                color: GQColors.coralRed
            )

            // Sleep
            TodayStatCard(
                icon: "moon.fill",
                value: sleep > 0 ? String(format: "%.1f", sleep) : "--",
                label: "Sleep hrs",
                color: GQColors.textSecondary
            )
        }
        .onAppear {
            loadHealthData()
        }
    }

    private func loadHealthData() {
        let healthKit = HealthKitService.shared
        healthKit.requestAuthorizationSync()
        healthKit.fetchTodayData()

        // Update after a delay to allow fetch to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            steps = healthKit.steps
            calories = healthKit.activeCalories
            sleep = healthKit.sleepHours
        }
    }
}

struct TodayStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(GQColors.surfaceBase)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.18))
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(color)
                    )

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(GQColors.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .homeSocialCard(accent: color)
        }
        .buttonStyle(GQInteractiveStyle())
    }
}

// MARK: - Health Metrics Grid (Bevel-inspired)

struct HealthMetricsGrid: View {
    @ObservedObject private var healthKit = HealthKitService.shared

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            HealthMetricCard(
                icon: "figure.walk",
                value: "\(healthKit.steps)",
                label: "Steps",
                color: GQColors.success
            )

            HealthMetricCard(
                icon: "flame.fill",
                value: "\(healthKit.activeCalories)",
                label: "Active Cal",
                color: GQColors.coralRed
            )

            HealthMetricCard(
                icon: "bed.double.fill",
                value: healthKit.sleepHours > 0 ? String(format: "%.1fh", healthKit.sleepHours) : "--",
                label: "Sleep",
                color: GQColors.textSecondary
            )

            HealthMetricCard(
                icon: "heart.fill",
                value: healthKit.restingHeartRate > 0 ? "\(healthKit.restingHeartRate)" : "--",
                label: "Resting HR",
                color: GQColors.coralRed
            )
        }
        .onAppear {
            healthKit.requestAuthorizationSync()
            healthKit.fetchTodayData()
        }
    }
}

struct HealthMetricCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Spacer()
            }

            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            Text(label)
                .font(.system(size: 13))
                .foregroundColor(GQColors.textTertiary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(GQColors.surfaceBase)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Compact Workout Row

struct CompactWorkoutRow: View {
    let workout: Workout
    private var iconAccent: Color {
        GQGradients.workoutGradientColors(for: workout.type).first ?? GQColors.cyanSpark
    }
    private var accent: Color {
        progressNeutralAccent
    }

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 10)
                .fill(iconAccent.opacity(0.16))
                .frame(width: 42, height: 42)
                .overlay(
                    Image(systemName: workout.type.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(iconAccent)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(workout.title ?? workout.type.rawValue)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 10) {
                    if workout.totalSets > 0 {
                        Label("\(workout.totalSets) sets", systemImage: "flame.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(GQColors.textSecondary)
                    }
                    if workout.duration > 0 {
                        Label("\(workout.duration) min", systemImage: "clock")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(GQColors.textSecondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(GQColors.textTertiary)
        }
        .padding(14)
        .homeSocialCard(accent: accent)
    }
}

// MARK: - Week Chart V2 (Glass style with animated bars)

struct WeekChartV2: View {
    let workouts: [Workout]
    @State private var barsAppeared = false

    var weekDates: [Date] {
        let cal = Calendar.current
        let monday = cal.startOfWeek(for: Date())
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
    }

    var weekData: [Int] {
        let cal = Calendar.current
        return weekDates.map { date in
            workouts
                .filter { cal.isDate($0.date, inSameDayAs: date) }
                .reduce(0) { $0 + $1.totalSets }
        }
    }

    var maxVolume: Int { max(weekData.max() ?? 1, 1) }

    let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("THIS WEEK")
                        .font(GQTypography.sectionHeader)
                        .foregroundColor(GQColors.textTertiary)
                        .tracking(1)

                    Text("Volume Overview")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                Spacer()
                Image(systemName: "calendar")
                    .font(.system(size: 16))
                    .foregroundColor(GQColors.textTertiary)
            }

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<7, id: \.self) { index in
                    let isToday = Calendar.current.isDateInToday(weekDates[index])
                    let hasWorkout = weekData[index] > 0
                    let barHeight = hasWorkout ? max(CGFloat(weekData[index]) / CGFloat(maxVolume) * 56, 12) : 8

                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                hasWorkout
                                    ? LinearGradient(
                                        colors: [GQColors.deepBlue, progressFireAccent],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                    : LinearGradient(
                                        colors: [Color.white.opacity(0.11), Color.white.opacity(0.07)],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(hasWorkout ? 0.2 : 0.08), lineWidth: 1)
                            )
                            .frame(width: 30, height: barsAppeared ? barHeight : 4)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.08), value: barsAppeared)

                        Text(dayLabels[index])
                            .font(.system(size: 11, weight: isToday ? .bold : .medium))
                            .foregroundColor(isToday ? .white : GQColors.textTertiary)

                        Text("\(Calendar.current.component(.day, from: weekDates[index]))")
                            .font(.system(size: 10))
                            .foregroundColor(isToday ? .white : GQColors.textTertiary.opacity(0.6))
                    }
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(
                        isToday
                            ? RoundedRectangle(cornerRadius: 10)
                                .fill(GQColors.cyanSpark.opacity(0.15))
                            : nil
                    )
                    .overlay(
                        isToday
                            ? RoundedRectangle(cornerRadius: 10)
                                .stroke(GQColors.cyanSpark.opacity(0.4), lineWidth: 1)
                            : nil
                    )
                }
            }
            .frame(height: 110)
        }
        .padding(16)
        .homeSocialCard(accent: progressNeutralAccent)
        .onAppear {
            barsAppeared = true
        }
    }
}

// Legacy support
struct WeekChart: View {
    let workouts: [Workout]

    var body: some View {
        WeekChartV2(workouts: workouts)
    }
}

// shows all months with workout days highlighted
struct FullCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    let workouts: [Workout]

    @State private var selectedMonth = Date()

    var workoutDates: Set<String> {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return Set(workouts.map { formatter.string(from: $0.date) }) // set for fast lookup
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: GQLayout.sectionSpacing) {
                    GQScreenTitleBlock(
                        title: "Workout Calendar",
                        subtitle: selectedMonth.formatted(.dateTime.month(.wide).year()),
                        accent: GQColors.cyanSpark
                    )
                    .gqScreenHorizontalPadding()
                    .padding(.top, GQLayout.pageTop)

                    HStack {
                        Button {
                            selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 34, height: 34)
                                .background(Color.white.opacity(0.07))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Text(selectedMonth.formatted(.dateTime.month(.wide).year()))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)

                        Spacer()

                        Button {
                            selectedMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 34, height: 34)
                                .background(Color.white.opacity(0.07))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .gqScreenHorizontalPadding()
                    .padding(.vertical, 10)
                    .homeSocialCard(accent: progressNeutralAccent)
                    .gqScreenHorizontalPadding()

                    MonthGrid(month: selectedMonth, workoutDates: workoutDates)

                    HStack(spacing: 16) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(GQColors.success)
                                .frame(width: 12, height: 12)
                            Text("Workout complete")
                                .font(.caption)
                                .foregroundColor(GQColors.textSecondary)
                        }
                        HStack(spacing: 6) {
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [GQColors.deepBlue, progressFireAccent],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                                .frame(width: 12, height: 12)
                            Text("Today")
                                .font(.caption)
                                .foregroundColor(GQColors.textSecondary)
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, GQLayout.cardHorizontal)
                    .homeSocialCard(accent: progressNeutralAccent)
                    .gqScreenHorizontalPadding()

                    MonthStats(month: selectedMonth, workouts: workouts)

                    Spacer().frame(height: 40)
                }
            }
            .gqPageBackground()
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct MonthGrid: View {
    let month: Date
    let workoutDates: Set<String>

    let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    let dayHeaders = ["M", "T", "W", "T", "F", "S", "S"]

    // builds array of dates for the month grid (nil = empty cell)
    var days: [Date?] {
        let cal = Calendar.current
        let range = cal.range(of: .day, in: .month, for: month)!
        let firstOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: month))!

        let firstWeekday = cal.component(.weekday, from: firstOfMonth) // 1=Sun, 2=Mon
        let offset = (firstWeekday + 5) % 7 // empty cells before 1st

        var result: [Date?] = Array(repeating: nil, count: offset)
        for day in range {
            if let date = cal.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                result.append(date)
            }
        }
        while result.count % 7 != 0 { result.append(nil) } // pad last row
        return result
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(dayHeaders, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        DayCell(date: date, hasWorkout: isWorkoutDay(date))
                    } else {
                        Color.clear
                            .frame(height: 40)
                    }
                }
            }
        }
        .padding(14)
        .homeSocialCard(accent: progressNeutralAccent)
        .padding(.horizontal, 16)
    }

    func isWorkoutDay(_ date: Date) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return workoutDates.contains(formatter.string(from: date))
    }
}

struct DayCell: View {
    let date: Date
    let hasWorkout: Bool

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var isFuture: Bool {
        date > Date()
    }

    var body: some View {
        ZStack {
            if hasWorkout {
                Circle()
                    .fill(GQColors.success.opacity(0.9))
                Circle()
                    .stroke(GQColors.success.opacity(0.45), lineWidth: 1.5)
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            } else if isToday {
                Circle()
                    .fill(Color.white.opacity(0.05))
                Circle()
                    .stroke(GQColors.cyanSpark, lineWidth: 1.5)

                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(GQColors.cyanSpark)
            } else {
                Circle()
                    .fill(Color.white.opacity(0.05))
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)

                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(isFuture ? GQColors.textTertiary : .white)
            }
        }
        .frame(height: 40)
    }
}

struct MonthStats: View {
    let month: Date
    let workouts: [Workout]

    var monthWorkouts: [Workout] {
        let cal = Calendar.current
        return workouts.filter { cal.isDate($0.date, equalTo: month, toGranularity: .month) }
    }

    var totalSets: Int {
        monthWorkouts.reduce(0) { $0 + $1.totalSets }
    }

    var totalMinutes: Int {
        monthWorkouts.reduce(0) { $0 + $1.duration }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MONTH SUMMARY")
                .font(.system(size: 12, weight: .bold))
                .tracking(1)
                .foregroundColor(GQColors.textTertiary)

            HStack(spacing: 10) {
                WorkoutFlowMetricChip(
                    icon: "figure.strengthtraining.traditional",
                    value: "\(monthWorkouts.count)",
                    label: "Workouts",
                    color: GQColors.cyanSpark
                )
                WorkoutFlowMetricChip(
                    icon: "flame.fill",
                    value: "\(totalSets)",
                    label: "Sets",
                    color: progressFireAccent
                )
                WorkoutFlowMetricChip(
                    icon: "clock",
                    value: "\(totalMinutes)",
                    label: "Minutes",
                    color: GQColors.cyanSpark
                )
            }
        }
        .padding(16)
        .homeSocialCard(accent: progressNeutralAccent)
        .padding(.horizontal, 16)
    }
}

struct MonthStatItem: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(GQTypography.stat)
                .foregroundColor(color)
            Text(label)
                .font(GQTypography.statLabel)
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Animated Checkmark (Celebratory)

struct CelebratoryCheckmark: View {
    @State private var isAnimated = false
    @State private var glowPulse = false

    var body: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            GQColors.success.opacity(0.4),
                            GQColors.cyanSpark.opacity(0.2),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 25
                    )
                )
                .frame(width: 50, height: 50)
                .scaleEffect(glowPulse ? 1.1 : 0.9)

            // Main circle with gradient
            Circle()
                .fill(
                    LinearGradient(
                        colors: [GQColors.success, GQColors.cyanSpark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .shadow(color: GQColors.success.opacity(0.5), radius: 8, x: 0, y: 2)

            // Inner highlight
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.4), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .frame(width: 36, height: 36)
                .offset(y: -2)

            // Checkmark with animation
            Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .black))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                .scaleEffect(isAnimated ? 1.0 : 0.5)
                .rotationEffect(.degrees(isAnimated ? 0 : -20))
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                isAnimated = true
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }
}

// MARK: - Workout Row V2 (Glass style)

struct WorkoutRowV2: View {
    let workout: Workout

    var body: some View {
        HStack(spacing: 12) {
            // Animated celebratory checkmark
            CelebratoryCheckmark()

            VStack(alignment: .leading, spacing: 4) {
                Text(workout.type.rawValue)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(workout.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textTertiary)
            }

            Spacer()

            HStack(spacing: 12) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(workout.duration)m")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(GQColors.textSecondary)
                    Text("duration")
                        .font(.system(size: 9))
                        .foregroundColor(GQColors.textTertiary)
                }

                Text("\(workout.totalSets)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [GQColors.deepBlue, progressFireAccent],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [GQColors.deepBlue.opacity(0.24), progressFireAccent.opacity(0.14)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(progressFireAccent.opacity(0.28), lineWidth: 1)
                    )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(GQColors.surfaceOverlay.opacity(0.74))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    LinearGradient(
                        colors: [GQColors.success.opacity(0.2), Color.white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// Legacy support
struct WorkoutRow: View {
    let workout: Workout

    var body: some View {
        WorkoutRowV2(workout: workout)
    }
}

#Preview {
    TrainingProgressView(
        profile: UserProfile(),
        workouts: [],
        aiService: AIService()
    )
    .environmentObject(AppState())
    .environmentObject(FeatureFlags.shared)
    .preferredColorScheme(.dark)
}
