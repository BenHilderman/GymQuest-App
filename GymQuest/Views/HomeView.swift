//
//  HomeView.swift
//  GymQuest
//
//  GymQuest 2.0 - Bold & Energetic Home Screen
//  Hero card dominates, horizontal stat pills, minimal cards
//  Inspired by: Nike Training Club, Peloton, Strava
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var featureFlags: FeatureFlags
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @Query(sort: \QuestProgress.updatedAt, order: .reverse) private var questProgress: [QuestProgress]

    let profile: UserProfile

    @State private var todayWorkout: Workout?
    @State private var streak: Int = 0
    @State private var weeklyProgress: (completed: Int, target: Int) = (0, 0)
    @State private var readinessLevel: ReadinessLevel = .good
    @State private var latestPR: PRMoment?
    @State private var activeQuest: (quest: Quest, progress: QuestProgress)?
    @State private var activeSquad: Squad?
    @State private var squadChallenge: SquadChallenge?
    @State private var showingSquadView = false
    @State private var showingMealLog = false
    @State private var showingWorkoutTypePicker = false
    @State private var totalSets: Int = 0
    @State private var totalXP: Int = 0
    @State private var headerAppeared = true
    @State private var showingVideoGenerator = false
    @State private var selectedWorkoutType: WorkoutType = .push

    // Extract first name from full name
    var firstName: String {
        profile.name.components(separatedBy: " ").first ?? profile.name
    }

    var body: some View {
        Group {
            if appState.isWorkoutActive {
                ActiveWorkoutView(profile: profile)
            } else {
                homeContent
            }
        }
    }

    @ViewBuilder
    private var homeContent: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    // DATE HEADER WITH GREETING
                    VStack(spacing: 4) {
                        Text("Hi, \(firstName)!")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)

                        HStack(spacing: 6) {
                            Text(Date().formatted(.dateTime.weekday(.wide)))
                            Text("•")
                            Text(Date().formatted(.dateTime.month(.abbreviated).day()))
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .offset(y: headerAppeared ? 0 : -20)
                    .opacity(headerAppeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.5), value: headerAppeared)

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

                    // FRIENDS ACTIVE TODAY
                    FriendsActiveTodayRow()
                        .padding(.horizontal, 16)

                    // SQUAD CHALLENGE (if active)
                    if FeatureFlags.shared.squadsEnabled, let squad = activeSquad, let challenge = squadChallenge {
                        SquadChallengeCard(squad: squad, challenge: challenge)
                            .padding(.horizontal, 16)
                    }


                    // MAIN ACTIONS - 3 Big Buttons
                    VStack(spacing: 12) {
                        // Start Workout - Primary
                        HomeActionButton(
                            icon: "figure.strengthtraining.traditional",
                            title: "Start Workout",
                            subtitle: todayWorkout != nil ? "Completed today" : "Begin a live session",
                            accentColor: GQColors.vividPurple,
                            isPrimary: true
                        ) {
                            showingWorkoutTypePicker = true
                        }
                        .bounceAppear(delay: 0.1)

                        // Log Food
                        HomeActionButton(
                            icon: "fork.knife",
                            title: "Log Food",
                            subtitle: "Track nutrition",
                            accentColor: GQColors.coralRed,
                            isPrimary: false
                        ) {
                            showingMealLog = true
                        }
                        .bounceAppear(delay: 0.2)

                        // View Progress
                        HomeActionButton(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "View Progress",
                            subtitle: "\(streak) day streak",
                            accentColor: GQColors.success,
                            isPrimary: false
                        ) {
                            appState.selectedTab = .progress
                        }
                        .bounceAppear(delay: 0.3)

                        // View Progress has context menu for Form Studio & Video Gen

                    }
                    .padding(.horizontal, 16)

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
            .sheet(isPresented: $showingSquadView) {
                SquadView(profile: profile)
            }
            .sheet(isPresented: $showingMealLog) {
                MealLogView(profile: profile)
            }
            .sheet(isPresented: $showingWorkoutTypePicker) {
                StartWorkoutSheet(selectedType: $selectedWorkoutType) {
                    showingWorkoutTypePicker = false
                }
            }
            .sheet(isPresented: $showingVideoGenerator) {
                VideoGeneratorView()
            }
            // Active workout is now shown inline on the Home tab via ContentView
        }
    }

    private func loadHomeData() {
        // Seed Form Studio content if needed
        try? FormContentSeeder.seedIfNeeded(modelContext: modelContext)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Check for today's workout
        todayWorkout = workouts.first { calendar.isDate($0.date, inSameDayAs: today) }

        // Calculate streak
        streak = calculateStreak()

        // Calculate weekly progress
        let weekStart = calendar.startOfWeek(for: Date())
        let weeklyWorkouts = workouts.filter { $0.date >= weekStart }
        weeklyProgress = (weeklyWorkouts.count, profile.daysPerWeek)

        // Calculate total sets
        totalSets = workouts.reduce(0) { $0 + $1.totalSets }

        // Determine readiness
        readinessLevel = determineReadiness()

        // Get latest PR
        loadLatestPR()

        // Get active quest
        loadActiveQuest()

        // Get active squad
        loadActiveSquad()

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
        // Use IntegrationManager's computed readiness if integrations are active
        let integration = IntegrationManager.shared
        if integration.hasAnyConnection && integration.recoveryScore > 0 {
            return integration.readinessLevel
        }

        // Fallback: compute from workout data
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

    private func loadLatestPR() {
        let descriptor = FetchDescriptor<PRMoment>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        latestPR = (try? modelContext.fetch(descriptor))?.first
    }

    private func loadActiveQuest() {
        guard featureFlags.questsEnabled else { return }

        let questService = QuestService.shared
        questService.configure(modelContext: modelContext)
        questService.seedDefaultQuests()

        if let todaysQuest = questService.getTodaysQuest(userId: profile.id) {
            activeQuest = todaysQuest
        }

        let descriptor = FetchDescriptor<Reaction>()
        let reactions = (try? modelContext.fetch(descriptor)) ?? []

        let mealDescriptor = FetchDescriptor<MealLog>()
        let meals = (try? modelContext.fetch(mealDescriptor)) ?? []

        let learningDescriptor = FetchDescriptor<LearningProgress>()
        let learning = (try? modelContext.fetch(learningDescriptor)) ?? []

        questService.evaluateProgress(
            userId: profile.id,
            workouts: Array(workouts),
            reactions: reactions,
            mealLogs: meals,
            learningProgress: learning
        )

        if let updatedQuest = questService.getTodaysQuest(userId: profile.id) {
            activeQuest = updatedQuest
        }
    }

    private func loadActiveSquad() {
        guard featureFlags.squadsEnabled else { return }

        let squadService = SquadService.shared
        squadService.configure(modelContext: modelContext)

        let userSquads = squadService.getUserSquads(userId: profile.id)
        if let squad = userSquads.first {
            activeSquad = squad
            squadChallenge = squadService.getActiveChallenge(squadId: squad.id)
        }
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

// MARK: - Readiness Level

// ReadinessLevel is defined in IntegrationManager.swift

// MARK: - Hero Action Card

struct HeroActionCard: View {
    let todayWorkout: Workout?
    let weeklyProgress: (completed: Int, target: Int)
    let onLogWorkout: () -> Void

    @State private var gradientRotation: Double = 0

    var progressPercentage: Double {
        guard weeklyProgress.target > 0 else { return 0 }
        return min(1.0, Double(weeklyProgress.completed) / Double(weeklyProgress.target))
    }

    var body: some View {
        HeroCard {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TODAY")
                            .font(GQTypography.sectionHeader)
                            .foregroundColor(GQColors.textTertiary)
                            .tracking(1.5)

                        Text(Date().formatted(.dateTime.weekday(.wide).month().day()))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    if todayWorkout != nil {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(GQColors.success)
                            Text("Done")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(GQColors.success)
                        }
                    }
                }

                // CTA Button - Clear button with gradient border
                Button(action: onLogWorkout) {
                    HStack(spacing: 12) {
                        Image(systemName: todayWorkout == nil ? "plus" : "arrow.right")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))

                        Text(todayWorkout == nil ? "Start Workout" : "Log Another")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 18)
                    .background(
                        ZStack {
                            // Shadow for 3D
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.black)
                                .shadow(color: .black.opacity(0.5), radius: 10, y: 5)

                            // Dark fill
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(white: 0.16), Color(white: 0.08)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )

                            // Top highlight
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.1), Color.clear],
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                LinearGradient(
                                    colors: [GQColors.vividPurple, GQColors.cyanSpark],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                }
                .buttonStyle(GQInteractiveStyle())

                // Weekly progress mini bar
                VStack(spacing: 8) {
                    HStack {
                        Text("This Week")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(GQColors.textTertiary)

                        Spacer()

                        Text("\(weeklyProgress.completed)/\(weeklyProgress.target) sessions")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    AnimatedProgressBar(
                        progress: progressPercentage,
                        height: 5,
                        colors: [progressPercentage >= 1.0 ? GQColors.success : GQColors.accent]
                    )
                }
            }
            .padding(20)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Home Action Button

struct HomeActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let accentColor: Color
    let isPrimary: Bool
    let action: () -> Void
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(accentColor)
                        .scaleEffect(isPrimary ? pulseScale : 1.0)
                }

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(GQColors.textTertiary)
            }
            .padding(16)
            .modifier(HomeActionButtonSurface(isPrimary: isPrimary, accentColor: accentColor))
        }
        .buttonStyle(GQInteractiveStyle())
        .onAppear {
            guard isPrimary else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseScale = 1.15
            }
        }
    }
}

// Helper for conditional animated border
struct ConditionalAnimatedBorder: ViewModifier {
    let isActive: Bool
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if isActive {
            content.animatedGradientBorder(
                cornerRadius: cornerRadius,
                lineWidth: 2,
                colors: [GQColors.vividPurple, GQColors.cyanSpark, GQColors.vividPurple],
                duration: 4.0
            )
        } else {
            content
        }
    }
}

struct HomeActionButtonSurface: ViewModifier {
    let isPrimary: Bool
    let accentColor: Color

    func body(content: Content) -> some View {
        if isPrimary {
            content
                .homeSocialCard(accent: accentColor, emphasized: true, sweepDelay: 0.5)
        } else {
            content
                .homeSocialCard(accent: accentColor, sweepDelay: 2.0)
        }
    }
}

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
            // The tile box
            ZStack {
                // Base rectangle with gradient for completed workouts
                RoundedRectangle(cornerRadius: 10)
                    .fill(tileBackground)
                    .frame(height: 44)
                    .shadow(
                        color: isCompletedWorkout ? Color.black.opacity(0.3) : Color.clear,
                        radius: 4,
                        y: 2
                    )

                // Animated border only for today
                if isToday && !hasWorkout {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.clear)
                        .frame(height: 44)
                        .animatedGradientBorder(
                            cornerRadius: 10,
                            lineWidth: 2,
                            colors: [GQColors.vividPurple, GQColors.cyanSpark, GQColors.vividPurple],
                            duration: 4.0
                        )
                }

                // Content inside the box
                if hasWorkout {
                    if isRest {
                        // Sleep icon for rest day
                        VStack(spacing: 2) {
                            Image(systemName: "moon.zzz.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                            Text("Rest")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    } else {
                        // Workout type icon with checkmark and label - white for contrast
                        VStack(spacing: 2) {
                            ZStack {
                                Image(systemName: workout!.type.icon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)

                                // Larger checkmark badge with white background
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 14, height: 14)
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(GQColors.success)
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
                    // Missed day - subtle dash
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.15))
                } else if isToday {
                    // Today - plus icon
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [GQColors.vividPurple, GQColors.cyanSpark],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                } else {
                    // Future day - empty or subtle indicator
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 6, height: 6)
                }
            }
            .frame(height: 44)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap?()
            }

            // Date number below the box
            Text("\(dayNumber)")
                .font(.system(size: 11, weight: isToday ? .bold : .medium))
                .foregroundColor(isToday ? .white : isCompletedWorkout ? .white : GQColors.textTertiary)
        }
    }

    // Computed property for tile background
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
            return AnyShapeStyle(Color.white.opacity(isPast ? 0.03 : 0.06))
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

    // Get workout for a specific date
    func workoutForDate(_ date: Date) -> Workout? {
        let cal = Calendar.current
        return workouts.first { cal.isDate($0.date, inSameDayAs: date) }
    }

    // Count only actual workouts (not rest days)
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

    // Short label for workout type
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
        case .other: return "Other"
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
        case .fullBody, .cardio, .rest, .glutes, .abs, .other: return .push
        }
    }

    @ViewBuilder
    private var nextUpRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 12))
                .foregroundColor(GQColors.vividPurple)
            Text("Next up: ")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            + Text(suggestedNextWorkout.rawValue)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(GQColors.vividPurple)
            Spacer()
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header with count and progress circle
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("THIS WEEK")
                        .font(GQTypography.sectionHeader)
                        .foregroundColor(GQColors.textTertiary)
                        .tracking(1)

                    Button {
                        showingTargetPicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("\(completedWorkouts) of \(targetDays) days")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)

                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(GQColors.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // Progress circle
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 4)
                        .frame(width: 44, height: 44)

                    // Progress arc with animated gradient
                    Circle()
                        .trim(from: 0, to: circleAnimated ? progressPercentage : 0)
                        .stroke(
                            LinearGradient(
                                colors: [GQColors.vividPurple, GQColors.cyanSpark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))

                    // Percentage text
                    Text("\(Int(progressPercentage * 100))%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            // Week calendar - rectangle style
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { index in
                    let isToday = Calendar.current.isDateInToday(weekDates[index])
                    let isPast = weekDates[index] < Calendar.current.startOfDay(for: Date())
                    let workout = workoutForDate(weekDates[index])
                    let hasWorkout = workout != nil
                    let dayNumber = Calendar.current.component(.day, from: weekDates[index])

                    VStack(spacing: 2) {
                        // Day label (M, T, W...)
                        Text(dayLabels[index])
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(GQColors.textTertiary)

                        // Day tile - smooth rectangle with date below
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
                                    // Tap on completed workout - show review
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

            // Next up suggestion
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
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header with workout type and date
                    HStack(spacing: 16) {
                        // Workout type icon with gradient background
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
                                .foregroundColor(.white)

                            Text(workout.date.formatted(.dateTime.weekday(.wide).month().day()))
                                .font(.system(size: 14))
                                .foregroundColor(GQColors.textSecondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal)

                    // Stats row
                    HStack(spacing: 12) {
                        WorkoutStatBadge(
                            icon: "clock.fill",
                            value: "\(workout.duration)",
                            label: "min",
                            color: GQColors.cyanSpark
                        )

                        WorkoutStatBadge(
                            icon: "number",
                            value: "\(workout.totalSets)",
                            label: "sets",
                            color: GQColors.vividPurple
                        )

                        WorkoutStatBadge(
                            icon: "scalemass.fill",
                            value: formatVolume(workout.totalVolume),
                            label: "lbs",
                            color: GQColors.sunsetOrange
                        )

                        WorkoutStatBadge(
                            icon: "gauge.high",
                            value: "\(workout.rpe)",
                            label: "RPE",
                            color: workout.rpe >= 8 ? GQColors.coralRed : GQColors.success
                        )
                    }
                    .padding(.horizontal)

                    // Exercises list
                    if !workout.exercises.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("EXERCISES")
                                .font(GQTypography.sectionHeader)
                                .foregroundColor(GQColors.textTertiary)
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

                    // Notes section
                    if !workout.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NOTES")
                                .font(GQTypography.sectionHeader)
                                .foregroundColor(GQColors.textTertiary)
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
                        .foregroundColor(GQColors.cyanSpark)
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
                .foregroundColor(.white)

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
            HStack {
                Text(exercise.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Text("\(exercise.sets.count) sets")
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textSecondary)
            }

            // Sets summary
            HStack(spacing: 8) {
                ForEach(exercise.sets.sorted(by: { $0.order < $1.order })) { set in
                    Text(setDisplayString(set))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(GQColors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.08))
                        )
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
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
                        .foregroundColor(GQColors.textTertiary)
                        .tracking(1)

                    Text(quest.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }

                Spacer()

                // XP reward badge
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10))
                    Text("+\(quest.xpReward)")
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(GQColors.cyanSpark)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(GQColors.cyanSpark.opacity(0.15))
                .cornerRadius(8)
            }

            // Progress
            VStack(spacing: 8) {
                AnimatedProgressBar(
                    progress: progress.progressPercentage,
                    height: 8,
                    colors: [GQColors.vividPurple, GQColors.deepBlue]
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
                        .foregroundColor(GQColors.success)
                    }
                }
            }
        }
        .padding(18)
    }
}

// MARK: - Latest PR Card V2

struct LatestPRCardV2: View {
    let prMoment: PRMoment

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(GQColors.cyanSpark.opacity(0.2))
                    .frame(width: 48, height: 48)

                Image(systemName: "trophy.fill")
                    .font(.title3)
                    .foregroundColor(GQColors.cyanSpark)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("RECENT PR")
                    .font(GQTypography.sectionHeader)
                    .foregroundColor(GQColors.cyanSpark.opacity(0.8))
                    .tracking(1)

                if let exercise = prMoment.exerciseName {
                    Text(exercise)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }

                Text(prMoment.value)
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textSecondary)
            }

            Spacer()

            if let improvement = prMoment.improvement {
                Text(improvement)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(GQColors.success)
            }
        }
        .padding(16)
    }
}

// MARK: - Squad Highlight Card V2

struct SquadHighlightCardV2: View {
    let squad: Squad
    let challenge: SquadChallenge?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 14) {
                HStack {
                    Image(systemName: "person.3.fill")
                        .font(.title3)
                        .foregroundColor(GQColors.deepBlue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("YOUR SQUAD")
                            .font(GQTypography.sectionHeader)
                            .foregroundColor(GQColors.textTertiary)
                            .tracking(1)

                        Text(squad.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        if squad.streakWeeks > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(GQColors.success)
                                Text("\(squad.streakWeeks)w")
                                    .foregroundColor(GQColors.success)
                            }
                            .font(.system(size: 11, weight: .semibold))
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(GQColors.textTertiary)
                    }
                }

                // Challenge preview
                if let challenge = challenge {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(challenge.title)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))

                            AnimatedProgressBar(
                                progress: min(1.0, Double(challenge.currentValue) / Double(challenge.targetValue)),
                                height: 4,
                                colors: [GQColors.deepBlue, GQColors.cyanSpark]
                            )
                        }

                        Text("\(challenge.currentValue)/\(challenge.targetValue)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(GQColors.deepBlue)
                    }
                    .padding(12)
                    .background(GQColors.deepBlue.opacity(0.1))
                    .cornerRadius(10)
                }
            }
            .padding(16)
        }
        .buttonStyle(GQInteractiveStyle())
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
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
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

// MARK: - Legacy Support Cards

struct TodayActionCard: View {
    let todayWorkout: Workout?
    let onLogWorkout: () -> Void
    let onContinueSession: () -> Void

    var body: some View {
        HeroActionCard(
            todayWorkout: todayWorkout,
            weeklyProgress: (0, 0),
            onLogWorkout: todayWorkout == nil ? onLogWorkout : onContinueSession
        )
    }
}

struct InsightCard: View {
    let weeklyProgress: (completed: Int, target: Int)
    let readinessLevel: ReadinessLevel
    let streak: Int

    var body: some View {
        GlassCard(accentColor: GQColors.deepBlue, showGlow: false) {
            WeeklyProgressCard(
                weeklyProgress: weeklyProgress,
                readinessLevel: readinessLevel,
                workouts: []
            )
        }
    }
}

struct QuestCard: View {
    let quest: Quest
    let progress: QuestProgress

    var body: some View {
        GlassCard(accentColor: GQColors.vividPurple) {
            ActiveQuestCard(quest: quest, progress: progress)
        }
    }
}

struct LatestPRCard: View {
    let prMoment: PRMoment

    var body: some View {
        GlassCard(accentColor: GQColors.cyanSpark) {
            LatestPRCardV2(prMoment: prMoment)
        }
    }
}

struct QuickStatsRow: View {
    let totalWorkouts: Int
    let streak: Int
    let level: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                StatPill(icon: "dumbbell.fill", value: "\(totalWorkouts)", label: "Workouts", color: GQColors.vividPurple)
                StatPill(icon: "flame.fill", value: "\(streak)", label: "Streak", color: GQColors.success)
                StatPill(icon: "trophy.fill", value: "Lv.\(level)", label: "Level", color: GQColors.cyanSpark)
            }
        }
    }
}

struct SquadHighlightCard: View {
    let squad: Squad
    let challenge: SquadChallenge?
    let onTap: () -> Void

    var body: some View {
        GlassCard(accentColor: GQColors.deepBlue, showGlow: false) {
            SquadHighlightCardV2(squad: squad, challenge: challenge, onTap: onTap)
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

                // Start button
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
                            colors: [GQColors.vividPurple, GQColors.cyanSpark],
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
                        (isSelected ? GQColors.vividPurple : Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(tmpl.name.isEmpty ? "Untitled Template" : tmpl.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text("\(tmpl.exercises.count) exercises")
                        .font(.system(size: 12))
                        .foregroundColor(GQColors.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(GQColors.vividPurple)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(isSelected ? 0.08 : 0.04)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? GQColors.vividPurple.opacity(0.6) : Color.white.opacity(0.06), lineWidth: 1))
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
                            .foregroundColor(.white)
                        Text(last.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 12))
                            .foregroundColor(GQColors.textTertiary)
                    }
                    Spacer()
                    Text("\(last.totalSets) sets")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(GQColors.cyanSpark)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(GQColors.cyanSpark.opacity(0.3), lineWidth: 1))
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
                    colors: startButtonEnabled ? [GQColors.vividPurple, GQColors.cyanSpark] : [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
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
        .background(Color(white: 0.05))
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
        // "8-12" → 10, "15" → 15
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
        case .other: muscleGroups = [.chest, .back, .shoulders]
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

        // Ensure at least 4 exercises
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
                        LinearGradient(colors: [GQColors.vividPurple.opacity(0.4), GQColors.cyanSpark.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                        LinearGradient(colors: [Color.white.opacity(0.06), Color.white.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? GQColors.vividPurple.opacity(0.8) : Color.white.opacity(isAvailable ? 0.08 : 0.04), lineWidth: isSelected ? 1.5 : 1)
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
                    LinearGradient(colors: [GQColors.vividPurple, GQColors.cyanSpark], startPoint: .topLeading, endPoint: .bottomTrailing) :
                    LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.clear : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(GQInteractiveStyle())
    }
}

// MARK: - Friends Active Today Row

struct FriendsActiveTodayRow: View {
    private let socialService = SocialActivityService.shared
    @State private var pulseGreen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 8) {
                Circle()
                    .fill(GQColors.success)
                    .frame(width: 8, height: 8)
                    .opacity(pulseGreen ? 1.0 : 0.4)

                Text("Friends Active")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)

                Text("\(socialService.friendsActiveToday)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(GQColors.cyanSpark)

                Spacer()
            }

            // Horizontal avatar scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(socialService.activeFriends) { friend in
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .stroke(
                                        friend.isLive ? GQColors.success : Color.white.opacity(0.15),
                                        lineWidth: friend.isLive ? 2.5 : 1.5
                                    )
                                    .frame(width: 46, height: 46)

                                Circle()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 38, height: 38)
                                    .overlay(
                                        Text(friend.avatarInitial)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                            }

                            Text(friend.name)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(1)

                            Text(friend.workoutType)
                                .font(.system(size: 9))
                                .foregroundColor(GQColors.textTertiary)
                        }
                        .frame(width: 52)
                    }
                }
            }
        }
        .padding(14)
        .homeSocialCard(accent: GQColors.success, emphasized: false, sweepDelay: 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseGreen = true
            }
        }
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
                    .foregroundColor(GQColors.cyanSpark)
                Text(squad.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text("\(daysRemaining)d left")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(GQColors.textTertiary)
            }

            Text(challenge.title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [GQColors.vividPurple, GQColors.cyanSpark],
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
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(GQColors.cyanSpark)
                    Text("+\(challenge.xpReward) XP")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(GQColors.cyanSpark)
                }
            }
        }
        .padding(14)
        .homeSocialCard(accent: GQColors.vividPurple, emphasized: false, sweepDelay: 2.5)
    }
}

#Preview {
    HomeView(profile: UserProfile(name: "Ben", username: "ben"))
        .environmentObject(AppState())
        .environmentObject(FeatureFlags.shared)
        .preferredColorScheme(.dark)
}
