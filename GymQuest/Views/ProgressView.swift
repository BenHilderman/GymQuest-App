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

struct TrainingProgressView: View {
    @EnvironmentObject var appState: AppState
    let profile: UserProfile
    let workouts: [Workout]
    @ObservedObject var aiService: AIService

    @State private var showingCalendar = false // full calendar sheet

    var streak: Int {
        aiService.calculateStreak(workouts: workouts) // consecutive days with a workout
    }

    var sessionsThisWeek: Int {
        let start = mondayOfCurrentWeek()
        return workouts.filter { $0.date >= start }.count // count workouts since monday
    }

    @State private var showingMealLog = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Recovery Card - Bevel inspired
                    RecoveryCard(streak: streak, sessionsThisWeek: sessionsThisWeek)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    // Health Dashboard (integrations data)
                    HealthDashboardView(profile: profile, workouts: workouts)
                        .padding(.horizontal, 16)

                    // Quick Actions
                    HStack(spacing: 12) {
                        QuickActionButton(
                            icon: "calendar",
                            title: "Calendar",
                            color: GQColors.vividPurple
                        ) {
                            showingCalendar = true
                        }

                        QuickActionButton(
                            icon: "fork.knife",
                            title: "Meals",
                            color: GQColors.cyanSpark
                        ) {
                            showingMealLog = true
                        }
                    }
                    .padding(.horizontal, 16)

                    // Weekly Activity Chart
                    WeekChartV2(workouts: workouts)
                        .padding(.horizontal, 16)

                    // Recent Activity
                    if !workouts.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Workouts")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)

                            ForEach(workouts.prefix(4)) { workout in
                                CompactWorkoutRow(workout: workout)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                }
                .padding(.bottom, 120)
            }
            .scrollContentBackground(.hidden)
            .background(EnergyBackground())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavBarLogo()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingCalendar) {
                FullCalendarView(workouts: workouts)
            }
            .sheet(isPresented: $showingMealLog) {
                MealLogView(profile: profile)
            }
        }
    }

    // get monday of current week
    func mondayOfCurrentWeek() -> Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today) // 1=Sun, 2=Mon, etc
        let daysFromMonday = (weekday + 5) % 7 // math trick to get days since monday
        return cal.date(byAdding: .day, value: -daysFromMonday, to: today) ?? today
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
        case 85...100: return GQColors.cyanSpark
        case 70...84: return GQColors.cyanSpark.opacity(0.8)
        case 60...69: return GQColors.vividPurple
        default: return GQColors.vividPurple.opacity(0.7)
        }
    }

    var body: some View {
        HStack(spacing: 20) {
            // Recovery circle
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 8)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(recoveryColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(recoveryScore)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    Text("%")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)
                }
            }

            // Info
            VStack(alignment: .leading, spacing: 8) {
                Text("Recovery")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(GQColors.textTertiary)

                Text(recoveryMessage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                            .foregroundColor(GQColors.cyanSpark)
                        Text("\(streak) day streak")
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textSecondary)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(GQColors.vividPurple)
                        Text("\(sessionsThisWeek) this week")
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textSecondary)
                    }
                }
            }

            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.08))
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
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
                animatedProgress = CGFloat(recoveryScore) / 100
            }
        }
    }
}

// MARK: - Health Stats Section (Apple Health Data)

struct HealthStatsSection: View {
    @State private var steps: Int = 0
    @State private var calories: Int = 0
    @State private var sleepHours: Double = 0
    @State private var restingHR: Int = 0

    // Estimate calories burned from steps (rough: ~0.04 cal per step)
    var caloriesFromSteps: Int {
        Int(Double(steps) * 0.04)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Health")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            // Main stats grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                // Steps
                HealthStatCard(
                    icon: "figure.walk",
                    title: "Steps",
                    value: steps > 0 ? "\(steps.formatted())" : "--",
                    subtitle: steps > 0 ? "~\(caloriesFromSteps) cal burned" : "No data",
                    color: GQColors.vividPurple
                )

                // Sleep
                HealthStatCard(
                    icon: "moon.fill",
                    title: "Sleep",
                    value: sleepHours > 0 ? String(format: "%.1fh", sleepHours) : "--",
                    subtitle: sleepQuality,
                    color: GQColors.vividPurple
                )

                // Active Calories
                HealthStatCard(
                    icon: "flame.fill",
                    title: "Active Cal",
                    value: calories > 0 ? "\(calories)" : "--",
                    subtitle: calories > 0 ? "burned today" : "No data",
                    color: GQColors.coralRed
                )

                // Resting HR
                HealthStatCard(
                    icon: "heart.fill",
                    title: "Resting HR",
                    value: restingHR > 0 ? "\(restingHR)" : "--",
                    subtitle: restingHR > 0 ? "bpm" : "No data",
                    color: GQColors.coralRed
                )
            }
        }
        .onAppear {
            loadHealthData()
        }
    }

    var sleepQuality: String {
        if sleepHours <= 0 { return "No data" }
        if sleepHours >= 7 { return "Good rest" }
        if sleepHours >= 5 { return "Could use more" }
        return "Sleep deprived"
    }

    private func loadHealthData() {
        let healthKit = HealthKitService.shared
        healthKit.requestAuthorizationSync()
        healthKit.fetchTodayData()

        // Update after fetch completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            steps = healthKit.steps
            calories = healthKit.activeCalories
            sleepHours = healthKit.sleepHours
            restingHR = healthKit.restingHeartRate
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
                .fill(Color(white: 0.08))
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
                color: GQColors.vividPurple
            )

            // Active Calories
            TodayStatCard(
                icon: "flame.fill",
                value: calories > 0 ? "\(calories)" : "--",
                label: "Calories",
                color: GQColors.cyanSpark
            )

            // Sleep
            TodayStatCard(
                icon: "moon.fill",
                value: sleep > 0 ? String(format: "%.1f", sleep) : "--",
                label: "Sleep hrs",
                color: GQColors.vividPurple
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
                .fill(Color(white: 0.08))
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
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)

                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(white: 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
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
        .buttonStyle(.plain)
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
                color: GQColors.cyanSpark
            )

            HealthMetricCard(
                icon: "flame.fill",
                value: "\(healthKit.activeCalories)",
                label: "Active Cal",
                color: GQColors.cyanSpark
            )

            HealthMetricCard(
                icon: "bed.double.fill",
                value: healthKit.sleepHours > 0 ? String(format: "%.1fh", healthKit.sleepHours) : "--",
                label: "Sleep",
                color: GQColors.vividPurple
            )

            HealthMetricCard(
                icon: "heart.fill",
                value: healthKit.restingHeartRate > 0 ? "\(healthKit.restingHeartRate)" : "--",
                label: "Resting HR",
                color: GQColors.vividPurple
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
                .fill(Color(white: 0.08))
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

    var body: some View {
        HStack(spacing: 14) {
            // Date circle
            VStack(spacing: 2) {
                Text(workout.date.formatted(.dateTime.day()))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Text(workout.date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.system(size: 11))
                    .foregroundColor(GQColors.textTertiary)
            }
            .frame(width: 44)

            // Workout info
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.title ?? workout.type.rawValue)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    if workout.totalSets > 0 {
                        Text("\(workout.totalSets) sets")
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textSecondary)
                    }
                    if workout.duration > 0 {
                        Text("\(workout.duration) min")
                            .font(.system(size: 13))
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
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.06))
        )
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
            // Header
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

            // Chart bars
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(0..<7, id: \.self) { index in
                    let isToday = Calendar.current.isDateInToday(weekDates[index])
                    let hasWorkout = weekData[index] > 0
                    let barHeight = hasWorkout ? max(CGFloat(weekData[index]) / CGFloat(maxVolume) * 60, 12) : 6

                    VStack(spacing: 6) {
                        // Animated bar with glow for workouts
                        ZStack {
                            if hasWorkout {
                                // Subtle glow behind bar
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(GQColors.cyanSpark.opacity(0.3))
                                    .frame(width: 40, height: barsAppeared ? barHeight + 4 : 4)
                                    .blur(radius: 4)
                            }

                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    hasWorkout
                                        ? LinearGradient(
                                            colors: [GQColors.vividPurple, GQColors.cyanSpark],
                                            startPoint: .bottom,
                                            endPoint: .top
                                          )
                                        : LinearGradient(
                                            colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                                            startPoint: .bottom,
                                            endPoint: .top
                                          )
                                )
                                .frame(width: 36, height: barsAppeared ? barHeight : 4)
                                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.08), value: barsAppeared)
                                .shadow(color: hasWorkout ? GQColors.cyanSpark.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
                        }

                        // Day label
                        Text(dayLabels[index])
                            .font(.system(size: 11, weight: isToday ? .bold : .medium))
                            .foregroundColor(isToday ? .white : GQColors.textTertiary)

                        // Date
                        Text("\(Calendar.current.component(.day, from: weekDates[index]))")
                            .font(.system(size: 10))
                            .foregroundColor(isToday ? .white : GQColors.textTertiary.opacity(0.6))
                    }
                    .padding(.vertical, 6)
                    .background(
                        isToday
                            ? RoundedRectangle(cornerRadius: 10)
                                .fill(GQColors.vividPurple.opacity(0.15))
                            : nil
                    )
                    .overlay(
                        isToday
                            ? RoundedRectangle(cornerRadius: 10)
                                .stroke(GQColors.vividPurple.opacity(0.4), lineWidth: 1)
                            : nil
                    )
                }
            }
            .frame(height: 110)
        }
        .padding(18)
        .onAppear {
            barsAppeared = true
        }
    }
}

// Legacy support
struct WeekChart: View {
    let workouts: [Workout]

    var body: some View {
        GlassCard(accentColor: GQColors.deepBlue, showGlow: false) {
            WeekChartV2(workouts: workouts)
        }
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
                VStack(spacing: 24) {
                    // month navigation
                    HStack {
                        Button {
                            selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                                .foregroundColor(.white)
                        }

                        Spacer()

                        Text(selectedMonth.formatted(.dateTime.month(.wide).year()))
                            .font(.title3)
                            .fontWeight(.semibold)

                        Spacer()

                        Button {
                            selectedMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal)

                    // calendar grid
                    MonthGrid(month: selectedMonth, workoutDates: workoutDates)

                    // legend
                    HStack(spacing: 16) {
                        HStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [GQColors.success, GQColors.cyanSpark],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 12, height: 12)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 6, weight: .black))
                                    .foregroundColor(.white)
                            }
                            Text("Workout complete")
                                .font(.caption)
                                .foregroundColor(GQColors.textSecondary)
                        }
                        HStack(spacing: 6) {
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [GQColors.vividPurple, GQColors.cyanSpark],
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

                    // stats for selected month
                    MonthStats(month: selectedMonth, workouts: workouts)

                    Spacer().frame(height: 40)
                }
                .padding(.top)
            }
            .background(GQColors.background.ignoresSafeArea())
            .navigationTitle("Workout Calendar")
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
            // day headers
            HStack(spacing: 4) {
                ForEach(dayHeaders, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            // calendar grid
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
        .padding(.horizontal)
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

    @State private var showCheckmark = false

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var isFuture: Bool {
        date > Date()
    }

    var body: some View {
        ZStack {
            if hasWorkout {
                // Glow effect
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [GQColors.success.opacity(0.5), Color.clear],
                            center: .center,
                            startRadius: 5,
                            endRadius: 22
                        )
                    )
                    .frame(width: 44, height: 44)

                // Main circle - solid green
                Circle()
                    .fill(GQColors.success)
                    .shadow(color: GQColors.success.opacity(0.5), radius: 6, x: 0, y: 2)

                // Shine highlight
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.35), Color.clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .frame(width: 36, height: 36)
                    .offset(y: -1)

                // Checkmark instead of number for workout days
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                    .scaleEffect(showCheckmark ? 1.0 : 0.3)
                    .onAppear {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.1)) {
                            showCheckmark = true
                        }
                    }

            } else if isToday {
                Circle()
                    .stroke(GQColors.cyanSpark, lineWidth: 2)
                    .shadow(color: GQColors.cyanSpark.opacity(0.4), radius: 4, x: 0, y: 0)

                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(GQColors.cyanSpark)
            } else {
                Circle()
                    .fill(Color.white.opacity(0.05))

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
        VStack(spacing: 16) {
            Text("MONTH SUMMARY")
                .font(GQTypography.sectionHeader)
                .foregroundColor(GQColors.textTertiary)
                .tracking(1)

            HStack(spacing: 0) {
                MonthStatItem(value: "\(monthWorkouts.count)", label: "workouts", color: GQColors.vividPurple)
                Divider()
                    .frame(height: 40)
                    .background(Color.white.opacity(0.1))
                MonthStatItem(value: "\(totalSets)", label: "sets", color: GQColors.vividPurple)
                Divider()
                    .frame(height: 40)
                    .background(Color.white.opacity(0.1))
                MonthStatItem(value: "\(totalMinutes)", label: "minutes", color: GQColors.cyanSpark)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.3))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal)
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
                            colors: [GQColors.vividPurple, GQColors.cyanSpark],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [GQColors.vividPurple.opacity(0.25), GQColors.cyanSpark.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(GQColors.vividPurple.opacity(0.3), lineWidth: 1)
                    )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.black.opacity(0.3))
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
    .preferredColorScheme(.dark)
}
