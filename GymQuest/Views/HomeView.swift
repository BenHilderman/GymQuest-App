//
//  HomeView.swift
//  GymQuest
//
//  Home tab — weekly progress, quick stats, and recent workouts.
//

import SwiftUI
import SwiftData

struct ActivityView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var featureFlags: FeatureFlags
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]

    let profile: UserProfile

    @State private var todayWorkout: Workout?
    @State private var streak: Int = 0
    @State private var weeklyProgress: (completed: Int, target: Int) = (0, 0)
    @State private var readinessLevel: ReadinessLevel = .good
    @Query(sort: \WorkoutTemplate.createdAt, order: .reverse) private var savedTemplates: [WorkoutTemplate]

    @Query(sort: \PREvent.date, order: .reverse) private var prEvents: [PREvent]

    private var recoveryData: (score: Double?, hrv: Double?, sleep: Double?, source: String) {
        RecoveryAdvisorCard.buildRecommendation(
            whoopService: WhoopService.shared,
            healthKitService: HealthKitService.shared
        )
    }

    @State private var showingWorkoutTypePicker = false
    @State private var showingMealLog = false

    var body: some View {
        Group {
            if appState.isWorkoutActive {
                ActiveWorkoutView(profile: profile)
            } else {
                activityContent
            }
        }
    }

    // MARK: - Activity Content

    @ViewBuilder
    private var activityContent: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: GQSpacing.xxl) {
                    // GREETING HEADER
                    greetingHeader

                    // HERO METRIC
                    heroMetricCard

                    // WEEK OVERVIEW
                    WeeklyProgressCard(
                        weeklyProgress: weeklyProgress,
                        readinessLevel: readinessLevel,
                        workouts: workouts,
                        targetDays: profile.daysPerWeek,
                        onTodayTap: {
                            showingWorkoutTypePicker = true
                        },
                        onRestTap: {
                            logRestDay()
                        },
                        onTargetChanged: { newTarget in
                            profile.daysPerWeek = newTarget
                            try? modelContext.save()
                            loadHomeData()
                        }
                    )
                    .padding(.horizontal, 16)

                    // RECOVERY ADVISOR
                    if FeatureFlags.shared.recoveryAdvisorEnabled {
                        RecoveryAdvisorCard(
                            recoveryScore: recoveryData.score,
                            hrvMs: recoveryData.hrv,
                            sleepHours: recoveryData.sleep,
                            source: recoveryData.source
                        )
                        .padding(.horizontal, 16)
                    }

                    // TRAINING PLAN QUICK ACCESS
                    if FeatureFlags.shared.trainingPlanEnabled {
                        TrainingPlanQuickCard(profile: profile)
                            .padding(.horizontal, 16)
                    }

                    // MAIN ACTIONS
                    VStack(spacing: 12) {
                        HomeActionCard(
                            icon: "figure.strengthtraining.traditional",
                            title: "Start Workout",
                            subtitle: todayWorkout != nil ? "Completed today" : "Begin a live session",
                            accentColor: GQColors.deepBlue,
                            isPrimary: true
                        ) {
                            showingWorkoutTypePicker = true
                        }
                        .bounceAppear(delay: 0.1)

                        HomeActionCard(
                            icon: "fork.knife",
                            title: "Log Food",
                            subtitle: "Track nutrition",
                            accentColor: GQColors.textSecondary,
                            isPrimary: false
                        ) {
                            showingMealLog = true
                        }
                        .bounceAppear(delay: 0.2)

                        HomeActionCard(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "View Progress",
                            subtitle: "\(streak) day streak",
                            accentColor: GQColors.textSecondary,
                            isPrimary: false
                        ) {
                            appState.showingLogEntry = true
                        }
                        .bounceAppear(delay: 0.3)
                    }
                    .padding(.horizontal, 16)

                    // STATS & PROGRESS
                    statsAndProgressSection

                    // RECENT WORKOUTS
                    recentWorkoutsSection

                    Spacer(minLength: 40)
                }
                .padding(.top, 12)
            }
            .scrollContentBackground(.hidden)
            .gqHomePageBackground()
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavBarLogo()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        appState.selectedTab = .profile
                    } label: {
                        ProfileAvatarButton(profile: profile)
                    }
                }
            }
            .onAppear {
                loadHomeData()
            }
            .sheet(isPresented: $showingWorkoutTypePicker) {
                StartWorkoutSheet(selectedType: .constant(.push)) {
                    showingWorkoutTypePicker = false
                }
            }
            .sheet(isPresented: $showingMealLog) {
                MealLogView(profile: profile)
            }
        }
    }

    // MARK: - Greeting Header

    @ViewBuilder
    private var greetingHeader: some View {
        VStack(spacing: 4) {
            Text("Hi, \(profile.name.components(separatedBy: " ").first ?? profile.name)!")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(GQColors.textPrimary)

            Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(GQColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
    }

    // MARK: - Hero Metric

    private var heroMetricCard: some View {
        VStack(spacing: 4) {
            if streak > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(GQColors.textSecondary)
                    Text("\(streak)")
                        .font(GQTypography.heroMetric)
                        .foregroundStyle(GQColors.textPrimary)
                }
                Text("day streak")
                    .font(GQTypography.caption)
                    .foregroundStyle(GQColors.textSecondary)
            } else {
                Text("\(weeklyProgress.completed)")
                    .font(GQTypography.heroMetric)
                    .foregroundStyle(GQColors.textPrimary)
                Text("workouts this week")
                    .font(GQTypography.caption)
                    .foregroundStyle(GQColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, GQSpacing.xxl)
        .gqCard(shadow: .elevated)
        .padding(.horizontal, 16)
    }

    // MARK: - Stats & Progress

    @ViewBuilder
    private var statsAndProgressSection: some View {
        VStack(spacing: 10) {
            // Section header
            Text("STATS & PROGRESS")
                .font(GQTypography.sectionHeader)
                .foregroundColor(GQColors.sectionLabel)
                .tracking(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Metric chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    WorkoutFlowMetricChip(
                        icon: "flame.fill",
                        value: "\(streak)",
                        label: "Streak",
                        color: GQColors.textSecondary
                    )
                    WorkoutFlowMetricChip(
                        icon: "dumbbell.fill",
                        value: "\(workoutsThisWeek)",
                        label: "This Week",
                        color: GQColors.deepBlue
                    )
                    WorkoutFlowMetricChip(
                        icon: "star.fill",
                        value: "Lv \(profile.level)",
                        label: "Level",
                        color: GQColors.textSecondary
                    )
                }
                .padding(.vertical, 6)
            }

            // Lifetime Stats Card
            lifetimeStatsCard

            // Recent PRs Card
            recentPRsCard
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var lifetimeStatsCard: some View {
        VStack(spacing: 10) {
            Text("LIFETIME")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(GQColors.sectionLabel)
                .tracking(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)

            VStack {
                Text("\(nonRestWorkouts.count)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Workouts Tracked")
                    .font(.caption)
                    .foregroundColor(GQColors.textSecondary)
            }
        }
        .padding(.vertical, 12)
        .homeSocialCard()
    }

    @ViewBuilder
    private var recentPRsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECENT PRs")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(GQColors.sectionLabel)
                .tracking(1)
                .padding(.horizontal, 16)

            if recentPRs.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "trophy")
                            .font(.system(size: 24))
                            .foregroundColor(GQColors.textTertiary)
                        Text("No PRs yet — keep pushing!")
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textSecondary)
                    }
                    .padding(.vertical, 12)
                    Spacer()
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(recentPRs, id: \.id) { pr in
                        HStack(spacing: 12) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 16))
                                .foregroundColor(GQColors.textSecondary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(pr.exerciseName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(GQColors.textPrimary)
                                    .lineLimit(1)
                                Text(pr.prType.rawValue)
                                    .font(.system(size: 11))
                                    .foregroundColor(GQColors.textTertiary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(prValueFormatted(pr))
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(GQColors.textPrimary)

                                if let delta = pr.delta, delta > 0 {
                                    Text("+\(Int(delta)) lbs")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(GQColors.textSecondary)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .homeSocialCard()
    }

    // MARK: - Recent Workouts

    @ViewBuilder
    private var recentWorkoutsSection: some View {
        let recentWorkouts = Array(workouts.filter { $0.type != .rest }.prefix(3))
        if !recentWorkouts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("RECENT WORKOUTS")
                    .font(GQTypography.sectionHeader)
                    .foregroundColor(GQColors.sectionLabel)
                    .tracking(1)
                    .padding(.horizontal, 16)

                VStack(spacing: 8) {
                    ForEach(recentWorkouts) { workout in
                        recentWorkoutRow(workout)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    @ViewBuilder
    private func recentWorkoutRow(_ workout: Workout) -> some View {
        Button {
            appState.selectedSession = workout
        } label: {
            HStack(spacing: 12) {
                WorkoutTypeBadge(type: workout.type, size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.title ?? workout.type.rawValue)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                    Text(workout.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        .font(.system(size: 12))
                        .foregroundColor(GQColors.textTertiary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(workout.duration) min")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(GQColors.textPrimary)
                    Text("\(workout.totalSets) sets")
                        .font(.system(size: 11))
                        .foregroundColor(GQColors.textTertiary)
                }
            }
            .padding(12)
            .homeSocialCard(cornerRadius: 12)
        }
        .buttonStyle(GQInteractiveStyle())
    }

    // MARK: - Computed Properties

    private var nonRestWorkouts: [Workout] {
        workouts.filter { $0.type != .rest }
    }

    private var homeTotalVolumeFormatted: String {
        let volume = workouts.reduce(0.0) { $0 + $1.totalVolume }
        if volume >= 1_000_000 {
            return String(format: "%.1fM", volume / 1_000_000)
        } else if volume >= 1_000 {
            return String(format: "%.1fk", volume / 1_000)
        }
        return "\(Int(volume))"
    }

    private var homeTotalDurationFormatted: String {
        let totalMinutes = workouts.reduce(0) { $0 + $1.duration }
        let hours = totalMinutes / 60
        if hours >= 1000 {
            return String(format: "%.1fk", Double(hours) / 1000)
        }
        return "\(hours)h"
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

    private var workoutsThisWeek: Int {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return nonRestWorkouts.filter { $0.date >= weekStart }.count
    }

    // MARK: - Data Loading

    private func loadHomeData() {
        try? FormContentSeeder.seedIfNeeded(modelContext: modelContext)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        todayWorkout = workouts.first { calendar.isDate($0.date, inSameDayAs: today) }
        streak = calculateStreak()

        let weekStart = calendar.startOfWeek(for: Date())
        let weeklyWorkouts = workouts.filter { $0.date >= weekStart }
        weeklyProgress = (weeklyWorkouts.count, profile.daysPerWeek)

        readinessLevel = determineReadiness()
    }

    private func calculateStreak() -> Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        for _ in 0..<365 {
            let hasSession = workouts.contains { calendar.isDate($0.date, inSameDayAs: checkDate) }
            if hasSession {
                streak += 1
            } else if streak > 0 {
                break
            }
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }
        return streak
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
        loadHomeData()
    }

}

// MARK: - Home Action Card

struct HomeActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let accentColor: Color
    let isPrimary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(GQColors.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(GQColors.textTertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
            )
            .overlay(
                Group {
                    if isPrimary {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.clear)
                            .animatedGradientBorder(
                                cornerRadius: 16,
                                lineWidth: 1.5,
                                colors: [GQColors.deepBlue, GQColors.textSecondary, GQColors.deepBlue],
                                duration: 4.0
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(GQColors.adaptiveOverlay(0.05), lineWidth: 1)
                    }
                }
            )
        }
        .buttonStyle(GQInteractiveStyle())
    }
}

// MARK: - Readiness Level

// ReadinessLevel is defined in IntegrationManager.swift

// MARK: - Day Tile View (for weekly calendar)

struct DayTileView: View {
    let dayNumber: Int
    let isToday: Bool
    let isPast: Bool
    let workout: Workout?
    let workoutTypeLabel: (WorkoutType) -> String
    var onTap: (() -> Void)? = nil

    var hasWorkout: Bool { workout != nil }
    var isRest: Bool { workout?.type == .rest }
    var isCompletedWorkout: Bool { hasWorkout && !isRest }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(tileBackground)
                    .frame(height: 44)
                    .shadow(
                        color: isCompletedWorkout ? Color.black.opacity(0.09) : Color.clear,
                        radius: 4,
                        y: 2
                    )

                if isToday && !hasWorkout {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.clear)
                        .frame(height: 44)
                        .animatedGradientBorder(
                            cornerRadius: 10,
                            lineWidth: 2,
                            colors: [GQColors.deepBlue, GQColors.textSecondary, GQColors.deepBlue],
                            duration: 4.0
                        )
                }

                if hasWorkout {
                    if isRest {
                        VStack(spacing: 2) {
                            Image(systemName: "moon.zzz.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                            Text("Rest")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    } else {
                        VStack(spacing: 2) {
                            ZStack {
                                Image(systemName: workout!.type.icon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)

                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 14, height: 14)
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(GQColors.textSecondary)
                                }
                                .offset(x: 10, y: -8)
                            }
                            Text(workoutTypeLabel(workout!.type))
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                    }
                } else if isPast {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(GQColors.adaptiveOverlay(0.09))
                } else if isToday {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [GQColors.deepBlue, GQColors.textSecondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                } else {
                    Circle()
                        .fill(GQColors.adaptiveOverlay(0.06))
                        .frame(width: 6, height: 6)
                }
            }
            .frame(height: 44)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap?()
            }

            Text("\(dayNumber)")
                .font(.system(size: 11, weight: isToday ? .bold : .medium))
                .foregroundColor(isToday ? GQColors.textPrimary : isCompletedWorkout ? .white : GQColors.textTertiary)
        }
    }

    private var tileBackground: AnyShapeStyle {
        if hasWorkout {
            if isRest {
                return AnyShapeStyle(GQGradients.workoutGradient(for: .rest))
            } else {
                return AnyShapeStyle(GQGradients.workoutGradient(for: workout!.type))
            }
        } else if isToday {
            return AnyShapeStyle(Color.clear)
        } else {
            return AnyShapeStyle(GQColors.adaptiveOverlay(isPast ? 0.02 : 0.04))
        }
    }
}

// MARK: - Weekly Progress Card

struct WeeklyProgressCard: View {
    let weeklyProgress: (completed: Int, target: Int)
    let readinessLevel: ReadinessLevel
    let workouts: [Workout]
    var targetDays: Int = 4
    var onTodayTap: (() -> Void)? = nil
    var onRestTap: (() -> Void)? = nil
    var onTargetChanged: ((Int) -> Void)? = nil

    @State private var circleAnimated = false
    @State private var showingDayOptions = false
    @State private var selectedWorkoutForReview: Workout? = nil
    @State private var showingWorkoutReview = false
    @State private var showingTargetPicker = false

    var weekDates: [Date] {
        let cal = Calendar.current
        let monday = cal.startOfWeek(for: Date())
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
    }

    func workoutForDate(_ date: Date) -> Workout? {
        let cal = Calendar.current
        return workouts.first { cal.isDate($0.date, inSameDayAs: date) }
    }

    var completedWorkouts: Int {
        weekDates.filter { date in
            guard let workout = workoutForDate(date) else { return false }
            return workout.type != .rest
        }.count
    }

    var progressPercentage: Double {
        guard targetDays > 0 else { return 0 }
        return min(1.0, Double(completedWorkouts) / Double(targetDays))
    }

    let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    func workoutTypeLabel(_ type: WorkoutType) -> String {
        switch type {
        case .push: return "Push"
        case .pull: return "Pull"
        case .legs: return "Legs"
        case .upper: return "Upper"
        case .lower: return "Lower"
        case .fullBody: return "Full"
        case .cardio: return "Cardio"
        case .rest: return "Rest"
        case .glutes: return "Glutes"
        case .abs: return "Abs"
        case .hiit: return "HIIT"
        case .yoga: return "Yoga"
        case .custom: return "Other"
        }
    }

    private var suggestedNextWorkout: WorkoutType {
        let recentTypes = workouts
            .sorted { $0.date > $1.date }
            .prefix(3)
            .filter { $0.type != .rest }
            .map(\.type)
        guard let lastType = recentTypes.first else { return .push }
        switch lastType {
        case .push: return .pull
        case .pull: return .legs
        case .legs: return .push
        case .upper: return .lower
        case .lower: return .upper
        case .fullBody, .cardio, .rest, .glutes, .abs, .hiit, .yoga, .custom: return .push
        }
    }

    @ViewBuilder
    private var nextUpRow: some View {
        if workouts.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.deepBlue)
                Text("Start your first workout!")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(GQColors.deepBlue)
                Spacer()
            }
        } else {
            HStack(spacing: 8) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.deepBlue)
                Text("Next up: ")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(GQColors.textPrimary.opacity(0.7))
                + Text(suggestedNextWorkout.rawValue)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(GQColors.deepBlue)
                Spacer()
            }
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("THIS WEEK")
                        .font(GQTypography.sectionHeader)
                        .foregroundColor(GQColors.sectionLabel)
                        .tracking(1)

                    Button {
                        showingTargetPicker = true
                    } label: {
                        HStack(spacing: 6) {
                            Text("\(completedWorkouts) of \(targetDays) days")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(GQColors.textPrimary)

                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(GQColors.deepBlue.opacity(0.6))
                        }
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(GQColors.adaptiveOverlay(0.06), lineWidth: 4)
                        .frame(width: 44, height: 44)

                    Circle()
                        .trim(from: 0, to: circleAnimated ? progressPercentage : 0)
                        .stroke(
                            LinearGradient(
                                colors: [GQColors.deepBlue, GQColors.textSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(progressPercentage * 100))%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(GQColors.textPrimary)
                }
            }

            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { index in
                    let isToday = Calendar.current.isDateInToday(weekDates[index])
                    let isPast = weekDates[index] < Calendar.current.startOfDay(for: Date())
                    let workout = workoutForDate(weekDates[index])
                    let hasWorkout = workout != nil
                    let dayNumber = Calendar.current.component(.day, from: weekDates[index])

                    VStack(spacing: 2) {
                        Text(dayLabels[index])
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(GQColors.textTertiary)

                        DayTileView(
                            dayNumber: dayNumber,
                            isToday: isToday,
                            isPast: isPast,
                            workout: workout,
                            workoutTypeLabel: workoutTypeLabel,
                            onTap: {
                                if isToday && !hasWorkout {
                                    showingDayOptions = true
                                } else if hasWorkout && workout?.type != .rest {
                                    selectedWorkoutForReview = workout
                                    showingWorkoutReview = true
                                }
                            }
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .staggeredAppear(index: index)
                }
            }

            nextUpRow
        }
        .padding(18)
        .homeSocialCard(sweepDelay: 0.0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                circleAnimated = true
            }
        }
        .confirmationDialog("What would you like to do?", isPresented: $showingDayOptions, titleVisibility: .visible) {
            Button("Start Workout") {
                onTodayTap?()
            }
            Button("Log Rest Day") {
                onRestTap?()
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingWorkoutReview) {
            if let workout = selectedWorkoutForReview {
                WorkoutReviewSheet(workout: workout)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .confirmationDialog("Weekly Goal", isPresented: $showingTargetPicker, titleVisibility: .visible) {
            ForEach(1...7, id: \.self) { days in
                Button("\(days) day\(days == 1 ? "" : "s") per week\(days == targetDays ? " (current)" : "")") {
                    onTargetChanged?(days)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("How many days per week do you want to train?")
        }
    }
}

// MARK: - Workout Review Sheet

struct WorkoutReviewSheet: View {
    let workout: Workout
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if workout.hasRoute {
            RunSummaryView(workout: workout)
        } else {
            genericWorkoutReview
        }
    }

    private var genericWorkoutReview: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(GQGradients.workoutGradient(for: workout.type))
                                .frame(width: 56, height: 56)

                            Image(systemName: workout.type.icon)
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(workout.title ?? workout.type.rawValue)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(GQColors.textPrimary)

                            Text(workout.date.formatted(.dateTime.weekday(.wide).month().day()))
                                .font(.system(size: 14))
                                .foregroundColor(GQColors.textSecondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal)

                    HStack(spacing: 12) {
                        WorkoutStatBadge(icon: "clock.fill", value: "\(workout.duration)", label: "min", color: GQColors.textSecondary)
                        WorkoutStatBadge(icon: "number", value: "\(workout.totalSets)", label: "sets", color: GQColors.deepBlue)
                        WorkoutStatBadge(icon: "scalemass.fill", value: formatVolume(workout.totalVolume), label: "lbs", color: GQColors.textSecondary)
                        WorkoutStatBadge(icon: "gauge.high", value: "\(workout.rpe)", label: "RPE", color: workout.rpe >= 8 ? GQColors.textSecondary : GQColors.textSecondary)
                    }
                    .padding(.horizontal)

                    if !workout.exercises.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("EXERCISES")
                                .font(GQTypography.sectionHeader)
                                .foregroundColor(GQColors.sectionLabel)
                                .tracking(1)
                                .padding(.horizontal)

                            VStack(spacing: 8) {
                                ForEach(workout.exercises.sorted(by: { $0.order < $1.order })) { exercise in
                                    ExerciseReviewRow(exercise: exercise)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    if !workout.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NOTES")
                                .font(GQTypography.sectionHeader)
                                .foregroundColor(GQColors.sectionLabel)
                                .tracking(1)

                            Text(workout.notes)
                                .font(.system(size: 14))
                                .foregroundColor(GQColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top, 20)
            }
            .scrollContentBackground(.hidden)
            .gqPageBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(GQColors.textSecondary)
                }
            }
        }
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk", volume / 1000)
        }
        return "\(Int(volume))"
    }
}

// MARK: - Workout Stat Badge

struct WorkoutStatBadge: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(GQColors.textPrimary)

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.15))
        )
    }
}

// MARK: - Exercise Review Row

struct ExerciseReviewRow: View {
    let exercise: Exercise

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                if FeatureFlags.shared.exerciseGifsEnabled {
                    ExerciseGifView(exerciseName: exercise.name, size: .thumbnail, showFallback: false)
                }

                Text(exercise.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)

                Spacer()

                Text("\(exercise.sets.count) sets")
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textSecondary)
            }

            HStack(spacing: 8) {
                ForEach(exercise.sets.sorted(by: { $0.order < $1.order })) { set in
                    Text(setDisplayString(set))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(GQColors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(GQColors.adaptiveOverlay(0.05))
                        )
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(GQColors.adaptiveOverlay(0.03))
        )
    }

    private func setDisplayString(_ set: ExerciseSet) -> String {
        if set.weight > 0 {
            return "\(set.reps)×\(Int(set.weight))"
        }
        return "\(set.reps) reps"
    }
}

// MARK: - Active Quest Card

struct ActiveQuestCard: View {
    let quest: Quest
    let progress: QuestProgress

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: quest.category.icon)
                    .font(.title3)
                    .foregroundColor(Color(quest.category.color))

                VStack(alignment: .leading, spacing: 2) {
                    Text("ACTIVE QUEST")
                        .font(GQTypography.sectionHeader)
                        .foregroundColor(GQColors.sectionLabel)
                        .tracking(1)

                    Text(quest.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10))
                    Text("+\(quest.xpReward)")
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(GQColors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(GQColors.textSecondary.opacity(0.15))
                .cornerRadius(8)
            }

            VStack(spacing: 8) {
                AnimatedProgressBar(
                    progress: progress.progressPercentage,
                    height: 8,
                    colors: [GQColors.deepBlue, GQColors.deepBlue]
                )

                HStack {
                    Text("\(progress.progressValue)/\(progress.targetValue)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(GQColors.textSecondary)

                    Spacer()

                    if progress.isComplete {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Complete!")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(GQColors.textSecondary)
                    }
                }
            }
        }
        .padding(18)
    }
}

// MARK: - Profile Avatar Button

struct ProfileAvatarButton: View {
    let profile: UserProfile

    var body: some View {
        if let photoData = profile.profilePhotoData,
           let uiImage = UIImage(data: photoData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(GQGradients.glassBorder, lineWidth: 1)
                )
        } else {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 32, height: 32)
                .overlay(
                    Group {
                        if let firstChar = profile.name.first {
                            Text(String(firstChar).uppercased())
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(GQColors.textPrimary)
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 14))
                                .foregroundColor(GQColors.textPrimary)
                        }
                    }
                )
                .overlay(
                    Circle()
                        .stroke(GQGradients.glassBorder, lineWidth: 1)
                )
        }
    }
}

// MARK: - Scale Button Style (Satisfying press feedback)

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    #if canImport(UIKit)
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    #endif
                }
            }
    }
}

// MARK: - Workout Launch Mode

enum WorkoutLaunchMode: String, CaseIterable {
    case scratch = "From Scratch"
    case aiGenerated = "AI Generated"
    case repeatLast = "Repeat Last"
    case template = "Saved Template"

    var icon: String {
        switch self {
        case .scratch: return "square.and.pencil"
        case .aiGenerated: return "sparkles"
        case .repeatLast: return "arrow.counterclockwise"
        case .template: return "bookmark"
        }
    }

    var subtitle: String {
        switch self {
        case .scratch: return "Build your own workout"
        case .aiGenerated: return "Smart workout for you"
        case .repeatLast: return "Load your last session"
        case .template: return "Use a saved template"
        }
    }
}

// MARK: - Start Workout Sheet

struct StartWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @Binding var selectedType: WorkoutType
    let onStart: () -> Void

    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @Query(sort: \WorkoutTemplate.lastUsedAt, order: .reverse) private var templates: [WorkoutTemplate]

    @State private var launchMode: WorkoutLaunchMode = .scratch
    @State private var isGenerating = false

    private var lastWorkoutOfType: Workout? {
        workouts.first(where: { $0.type == selectedType })
    }

    private var templatesForType: [WorkoutTemplate] {
        templates.filter { $0.workoutType == selectedType }
    }

    @State private var selectedTemplate: WorkoutTemplate?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Text("What are you training today?")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.top, 8)

                    typeGrid
                    modeSelection
                    templatePickerSection
                    repeatLastSection

                    Spacer(minLength: 20)
                }
                .padding(.horizontal)

                Spacer()

                Button {
                    onStart()
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start \(selectedType.rawValue) Workout")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [GQColors.deepBlue, GQColors.textSecondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                }
                .buttonStyle(GQInteractiveStyle())
                .padding(.horizontal)
                .padding(.bottom)
            }
            .gqPageBackground()
            .navigationTitle("Start Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Type Grid

    @ViewBuilder
    private var typeGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(WorkoutType.allCases, id: \.self) { type in
                WorkoutTypeCard(
                    type: type,
                    isSelected: selectedType == type,
                    onSelect: {
                        selectedType = type
                        if launchMode == .repeatLast && lastWorkoutOfType == nil {
                            launchMode = .scratch
                        }
                        if launchMode == .template && templatesForType.isEmpty {
                            launchMode = .scratch
                        }
                        selectedTemplate = nil
                    }
                )
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Mode Selection

    @ViewBuilder
    private var modeSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How do you want to train?")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(GQColors.textSecondary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(WorkoutLaunchMode.allCases, id: \.self) { mode in
                        let available = modeAvailable(mode)
                        LaunchModeCard(
                            mode: mode,
                            isSelected: launchMode == mode,
                            isAvailable: available,
                            detail: modeDetail(mode)
                        ) {
                            if available {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    launchMode = mode
                                    if mode != .template { selectedTemplate = nil }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Template Picker

    @ViewBuilder
    private var templatePickerSection: some View {
        if launchMode == .template && !templatesForType.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Pick a template")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)
                    .padding(.horizontal)

                ForEach(templatesForType) { tmpl in
                    templateRow(tmpl)
                }
            }
            .padding(.horizontal)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    @ViewBuilder
    private func templateRow(_ tmpl: WorkoutTemplate) -> some View {
        let isSelected = selectedTemplate?.id == tmpl.id
        Button { selectedTemplate = tmpl } label: {
            HStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .white : GQColors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(
                        (isSelected ? GQColors.deepBlue : GQColors.adaptiveOverlay(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(tmpl.name.isEmpty ? "Untitled Template" : tmpl.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                    Text("\(tmpl.exercises.count) exercises")
                        .font(.system(size: 12))
                        .foregroundColor(GQColors.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(GQColors.deepBlue)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(GQColors.adaptiveOverlay(isSelected ? 0.05 : 0.02)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? GQColors.deepBlue.opacity(0.6) : GQColors.adaptiveOverlay(0.04), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Repeat Last Summary

    @ViewBuilder
    private var repeatLastSection: some View {
        if launchMode == .repeatLast, let last = lastWorkoutOfType {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your last \(selectedType.rawValue) workout")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(last.exercises.count) exercises")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(GQColors.textPrimary)
                        Text(last.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 12))
                            .foregroundColor(GQColors.textTertiary)
                    }
                    Spacer()
                    Text("\(last.totalSets) sets")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(GQColors.textSecondary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(GQColors.adaptiveOverlay(0.02))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(GQColors.textSecondary.opacity(0.3), lineWidth: 1))
                )
            }
            .padding(.horizontal)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - Start Button

    @ViewBuilder
    private var startButton: some View {
        Button { handleStart() } label: {
            HStack(spacing: 8) {
                if isGenerating {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: startButtonIcon)
                }
                Text(startButtonText)
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: startButtonEnabled ? [GQColors.deepBlue, GQColors.textSecondary] : [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
        .disabled(!startButtonEnabled || isGenerating)
        .padding(.horizontal)
        .padding(.bottom, 8)
        .background(Color.white)
    }

    // MARK: - Helpers

    private var startButtonText: String {
        switch launchMode {
        case .scratch: return "Start from Scratch"
        case .aiGenerated: return isGenerating ? "Generating..." : "Generate Workout"
        case .repeatLast: return "Repeat Last \(selectedType.rawValue)"
        case .template: return selectedTemplate != nil ? "Use Template" : "Pick a Template"
        }
    }

    private var startButtonIcon: String {
        switch launchMode {
        case .scratch: return "play.fill"
        case .aiGenerated: return "sparkles"
        case .repeatLast: return "arrow.counterclockwise"
        case .template: return "bookmark.fill"
        }
    }

    private var startButtonEnabled: Bool {
        switch launchMode {
        case .scratch: return true
        case .aiGenerated: return true
        case .repeatLast: return lastWorkoutOfType != nil
        case .template: return selectedTemplate != nil
        }
    }

    private func modeAvailable(_ mode: WorkoutLaunchMode) -> Bool {
        switch mode {
        case .scratch, .aiGenerated: return true
        case .repeatLast: return lastWorkoutOfType != nil
        case .template: return !templatesForType.isEmpty
        }
    }

    private func modeDetail(_ mode: WorkoutLaunchMode) -> String? {
        switch mode {
        case .repeatLast:
            if let last = lastWorkoutOfType {
                return last.date.formatted(date: .abbreviated, time: .omitted)
            }
            return "No history"
        case .template:
            let count = templatesForType.count
            return count > 0 ? "\(count) saved" : "None saved"
        default: return nil
        }
    }

    private func handleStart() {
        switch launchMode {
        case .scratch:
            appState.startWorkout(type: selectedType)
            onStart()

        case .aiGenerated:
            isGenerating = true
            Task {
                let generated = generateRuleBasedWorkout(type: selectedType)
                appState.startWorkout(type: selectedType, exercises: generated)
                isGenerating = false
                onStart()
            }

        case .repeatLast:
            if let last = lastWorkoutOfType {
                appState.startWorkout(type: selectedType, exercises: convertWorkoutToActive(last))
                onStart()
            }

        case .template:
            if let tmpl = selectedTemplate {
                appState.startWorkout(type: selectedType, exercises: convertTemplateToActive(tmpl))
                onStart()
            }
        }
    }

    private func convertWorkoutToActive(_ workout: Workout) -> [ActiveExercise] {
        workout.exercises.map { exercise in
            ActiveExercise(
                name: exercise.name,
                muscleGroup: exercise.muscleGroup,
                sets: exercise.sets.map { set in
                    ActiveSet(reps: set.reps, weight: set.weight)
                }
            )
        }
    }

    private func convertTemplateToActive(_ template: WorkoutTemplate) -> [ActiveExercise] {
        template.exercises.map { tmplEx in
            let muscleGroup = MuscleGroup(rawValue: tmplEx.muscleGroup) ?? .chest
            let repCount = parseReps(tmplEx.suggestedReps)
            let sets = (0..<tmplEx.suggestedSets).map { _ in
                ActiveSet(reps: repCount, weight: tmplEx.suggestedWeight ?? 0)
            }
            return ActiveExercise(name: tmplEx.name, muscleGroup: muscleGroup, sets: sets)
        }
    }

    private func parseReps(_ repString: String) -> Int {
        let parts = repString.components(separatedBy: "-")
        if parts.count == 2, let low = Int(parts[0]), let high = Int(parts[1]) {
            return (low + high) / 2
        }
        return Int(repString) ?? 10
    }

    private func generateRuleBasedWorkout(type: WorkoutType) -> [ActiveExercise] {
        let muscleGroups: [MuscleGroup]
        switch type {
        case .push: muscleGroups = [.chest, .shoulders, .triceps]
        case .pull: muscleGroups = [.back, .biceps]
        case .legs: muscleGroups = [.quads, .hamstrings, .glutes, .calves]
        case .upper: muscleGroups = [.chest, .back, .shoulders, .biceps, .triceps]
        case .lower: muscleGroups = [.quads, .hamstrings, .glutes, .calves]
        case .fullBody: muscleGroups = [.chest, .back, .quads, .shoulders, .biceps]
        case .cardio: muscleGroups = [.cardio]
        case .rest: muscleGroups = [.core]
        case .glutes: muscleGroups = [.glutes, .hamstrings]
        case .abs: muscleGroups = [.core]
        case .hiit: muscleGroups = [.cardio, .chest, .quads]
        case .yoga: muscleGroups = [.core, .flexibility]
        case .custom: muscleGroups = [.chest, .back, .shoulders]
        }

        let allExercises = ExtendedExerciseDatabase.exercises
        var selected: [ActiveExercise] = []

        for group in muscleGroups {
            let matching = allExercises.filter { $0.muscleGroup == group }
            if let pick = matching.randomElement() {
                let sets = (0..<3).map { _ in ActiveSet(reps: 10, weight: 0) }
                selected.append(ActiveExercise(name: pick.name, muscleGroup: group, sets: sets))
            }
        }

        if selected.count < 4 {
            let remaining = allExercises.filter { ex in
                muscleGroups.contains(ex.muscleGroup) && !selected.contains(where: { $0.name == ex.name })
            }
            for extra in remaining.shuffled().prefix(4 - selected.count) {
                let sets = (0..<3).map { _ in ActiveSet(reps: 10, weight: 0) }
                selected.append(ActiveExercise(name: extra.name, muscleGroup: extra.muscleGroup, sets: sets))
            }
        }

        return selected
    }
}

// MARK: - Launch Mode Card

struct LaunchModeCard: View {
    let mode: WorkoutLaunchMode
    let isSelected: Bool
    let isAvailable: Bool
    var detail: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: mode.icon)
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .white : (isAvailable ? GQColors.textSecondary : GQColors.textTertiary))

                Text(mode.rawValue)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? .white : (isAvailable ? GQColors.textSecondary : GQColors.textTertiary))
                    .lineLimit(1)

                if let detail = detail {
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundColor(isSelected ? .white.opacity(0.7) : GQColors.textTertiary)
                        .lineLimit(1)
                }
            }
            .frame(width: 95, height: 85)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ?
                        LinearGradient(colors: [GQColors.deepBlue.opacity(0.4), GQColors.textSecondary.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                        LinearGradient(colors: [GQColors.adaptiveOverlay(0.04), GQColors.adaptiveOverlay(0.02)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? GQColors.deepBlue.opacity(0.8) : GQColors.adaptiveOverlay(isAvailable ? 0.05 : 0.02), lineWidth: isSelected ? 1.5 : 1)
            )
            .opacity(isAvailable ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
    }
}

struct WorkoutTypeCard: View {
    let type: WorkoutType
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 12) {
                Image(systemName: type.icon)
                    .font(.system(size: 28))
                    .foregroundColor(isSelected ? .white : GQColors.textSecondary)

                Text(type.rawValue)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .white : GQColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                isSelected ?
                    LinearGradient(colors: [GQColors.deepBlue, GQColors.textSecondary], startPoint: .topLeading, endPoint: .bottomTrailing) :
                    LinearGradient(colors: [GQColors.adaptiveOverlay(0.05), GQColors.adaptiveOverlay(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.clear : GQColors.adaptiveOverlay(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(GQInteractiveStyle())
    }
}

// MARK: - Squad Challenge Card

struct SquadChallengeCard: View {
    let squad: Squad
    let challenge: SquadChallenge

    private var progress: Double {
        guard challenge.targetValue > 0 else { return 0 }
        return min(1.0, Double(challenge.currentValue) / Double(challenge.targetValue))
    }

    private var daysRemaining: Int {
        max(0, Calendar.current.dateComponents([.day], from: Date(), to: challenge.endDate).day ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.textSecondary)
                Text(squad.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary.opacity(0.7))
                Spacer()
                Text("\(daysRemaining)d left")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(GQColors.textTertiary)
            }

            Text(challenge.title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(GQColors.textPrimary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(GQColors.adaptiveOverlay(0.05))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [GQColors.deepBlue, GQColors.textSecondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)

            HStack {
                Text("\(challenge.currentValue)/\(challenge.targetValue)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(GQColors.textPrimary.opacity(0.6))
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(GQColors.textSecondary)
                    Text("+\(challenge.xpReward) XP")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(GQColors.textSecondary)
                }
            }
        }
        .padding(14)
        .homeSocialCard(accent: GQColors.deepBlue, emphasized: false, sweepDelay: 2.5)
    }
}

// MARK: - Nutrition Pill

struct NutritionPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(GQColors.textPrimary)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(GQColors.textTertiary)
        }
    }
}

// MARK: - Training Plan Quick Card

struct TrainingPlanQuickCard: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrainingPlan.createdAt, order: .reverse) private var plans: [TrainingPlan]
    let profile: UserProfile

    private var activePlan: TrainingPlan? {
        plans.first { $0.isActive }
    }

    var body: some View {
        NavigationLink {
            TrainingPlanView(profile: profile)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: activePlan != nil ? "calendar.badge.checkmark" : "brain.head.profile")
                    .font(.title3)
                    .foregroundStyle(GQGradients.primary)

                VStack(alignment: .leading, spacing: 2) {
                    if let plan = activePlan {
                        Text("Week \(plan.currentWeek) of \(plan.totalWeeks)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(GQColors.textPrimary)
                        Text(plan.title)
                            .font(.caption)
                            .foregroundColor(GQColors.textSecondary)
                    } else {
                        Text("Generate AI Plan")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(GQColors.textPrimary)
                        Text("Periodized training tailored to you")
                            .font(.caption)
                            .foregroundColor(GQColors.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(GQColors.textSecondary)
            }
            .padding()
            .background(GQColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(GQColors.borderDefault, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ActivityView(profile: UserProfile(name: "Ben", username: "ben"))
        .environmentObject(AppState())
        .environmentObject(FeatureFlags.shared)
}
