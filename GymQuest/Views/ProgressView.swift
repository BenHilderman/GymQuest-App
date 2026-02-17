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

    @State private var showingHealthDashboard = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    // 1. Three-Ring Header
                    StatsRingHeader(sessionsThisWeek: sessionsThisWeek)
                        .gqScreenHorizontalPadding()
                        .padding(.top, GQLayout.pageTop)

                    // 2. Progress Trend Chart
                    ProgressTrendChart(workouts: workouts)
                        .gqScreenHorizontalPadding()

                    // 3. Week Chart
                    WeekChartV2(workouts: workouts)
                        .gqScreenHorizontalPadding()

                    // 4. Compact Health Strip
                    compactHealthStrip
                        .gqScreenHorizontalPadding()

                    // 5. Quick Actions
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
                            color: Color.white.opacity(0.82)
                        ) {
                            showingMealLog = true
                        }
                    }
                    .gqScreenHorizontalPadding()

                    // 6. Merged Stats + PRs
                    mergedStatsPRSection
                        .gqScreenHorizontalPadding()

                    // 7. Daily Quest
                    questSection

                    // 8. Recent Workouts (capped at 3)
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
            .sheet(isPresented: $showingHealthDashboard) {
                NavigationStack {
                    ScrollView {
                        HealthDashboardView(profile: profile, workouts: workouts)
                            .gqScreenHorizontalPadding()
                            .padding(.top, GQLayout.pageTop)
                            .padding(.bottom, GQLayout.pageBottom)
                    }
                    .gqPageBackground()
                    .navigationTitle("Health Details")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingHealthDashboard = false }
                        }
                    }
                }
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
    private var compactHealthStrip: some View {
        let hk = HealthKitService.shared
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                MiniHealthStat(
                    icon: "figure.walk",
                    value: hk.steps > 0 ? hk.steps.formatted() : "--",
                    label: "Steps",
                    color: Color(hex: "007AFF")
                )
                MiniHealthStat(
                    icon: "moon.fill",
                    value: hk.sleepHours > 0 ? String(format: "%.1fh", hk.sleepHours) : "--",
                    label: "Sleep",
                    color: Color(hex: "5E5CE6")
                )
                MiniHealthStat(
                    icon: "flame.fill",
                    value: hk.activeCalories > 0 ? "\(hk.activeCalories)" : "--",
                    label: "Active Cal",
                    color: Color(hex: "FF9500")
                )
                MiniHealthStat(
                    icon: "heart.fill",
                    value: hk.restingHeartRate > 0 ? "\(hk.restingHeartRate)" : "--",
                    label: "Resting HR",
                    color: Color(hex: "FF3B30")
                )
            }

            Button {
                showingHealthDashboard = true
            } label: {
                HStack(spacing: 4) {
                    Text("See All")
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(Color.white.opacity(0.72))
                .padding(.top, 8)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .homeSocialCard(accent: progressNeutralAccent)
        .onAppear {
            hk.requestAuthorizationSync()
            hk.fetchTodayData()
        }
    }

    @ViewBuilder
    private var mergedStatsPRSection: some View {
        VStack(spacing: 12) {
            // Inline 3-column stats
            if let summary = metricsSummary {
                HStack(spacing: 0) {
                    MergedStatColumn(value: "\(summary.totalWorkouts)", label: "Workouts", color: GQColors.vividPurple)
                    Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1, height: 28)
                    MergedStatColumn(value: "\(summary.totalPRs)", label: "PRs", color: GQColors.cyanSpark)
                    Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1, height: 28)
                    MergedStatColumn(value: "\(summary.totalQuestsCompleted)", label: "Quests", color: GQColors.success)
                }
            }

            // Top 2 PRs
            if !prMoments.isEmpty {
                VStack(spacing: 6) {
                    ForEach(prMoments.prefix(2)) { pr in
                        CompactPRRow(pr: pr)
                    }
                    if prMoments.count > 2 {
                        Button {
                            // Could present a sheet with all PRs
                        } label: {
                            Text("See All PRs (\(prMoments.count))")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(GQColors.cyanSpark)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                    }
                }
            }
        }
        .padding(14)
        .homeSocialCard(accent: progressNeutralAccent)
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

                ForEach(workouts.prefix(3)) { workout in
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

// MARK: - Mini Health Stat (for compact health strip)

private struct MiniHealthStat: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Merged Stat Column

private struct MergedStatColumn: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Compact PR Row

private struct CompactPRRow: View {
    let pr: PRMoment

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 12))
                .foregroundColor(GQColors.cyanSpark)

            if let name = pr.exerciseName {
                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

            Text(pr.value)
                .font(.system(size: 12))
                .foregroundColor(GQColors.textSecondary)
                .lineLimit(1)

            Spacer()

            if let improvement = pr.improvement {
                Text(improvement)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(GQColors.success)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
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

// MARK: - Stats Ring Header (3 rings)

private struct StatsRingHeader: View {
    let sessionsThisWeek: Int
    @StateObject private var integration = IntegrationManager.shared
    @State private var animatedRecovery: CGFloat = 0
    @State private var animatedStrain: CGFloat = 0
    @State private var animatedWeekly: CGFloat = 0

    private let weeklyGoal: Int = 5

    private var weeklyProgress: Double {
        min(Double(sessionsThisWeek) / Double(weeklyGoal), 1.0)
    }

    var body: some View {
        HStack(spacing: 0) {
            ringColumn(
                progress: animatedRecovery,
                value: "\(Int(integration.recoveryScore))",
                unit: "%",
                label: "Recovery",
                sublabel: integration.readinessLevel.rawValue,
                ringColor: integration.readinessLevel.color,
                sublabelColor: integration.readinessLevel.color
            )

            ringColumn(
                progress: animatedStrain,
                value: String(format: "%.1f", integration.strainScore),
                unit: "/21",
                label: "Strain",
                sublabel: strainLabel,
                ringColor: strainColor,
                sublabelColor: strainColor,
                isArc: true
            )

            ringColumn(
                progress: animatedWeekly,
                value: "\(sessionsThisWeek)",
                unit: "/\(weeklyGoal)",
                label: "Weekly",
                sublabel: sessionsThisWeek >= weeklyGoal ? "Goal hit!" : "\(weeklyGoal - sessionsThisWeek) to go",
                ringColor: GQColors.vividPurple,
                sublabelColor: sessionsThisWeek >= weeklyGoal ? GQColors.success : GQColors.textTertiary
            )
        }
        .padding(.vertical, 14)
        .homeSocialCard()
        .onAppear {
            integration.computeUnifiedMetrics()
            withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
                animatedRecovery = CGFloat(integration.recoveryScore / 100)
                animatedStrain = CGFloat(integration.strainScore / 21)
                animatedWeekly = CGFloat(weeklyProgress)
            }
        }
    }

    @ViewBuilder
    private func ringColumn(
        progress: CGFloat,
        value: String,
        unit: String,
        label: String,
        sublabel: String,
        ringColor: Color,
        sublabelColor: Color,
        isArc: Bool = false
    ) -> some View {
        VStack(spacing: 8) {
            ZStack {
                if isArc {
                    StrainArcShape(progress: 1.0)
                        .stroke(Color.white.opacity(0.06), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 52, height: 52)
                    StrainArcShape(progress: Double(progress))
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 52, height: 52)
                } else {
                    Circle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 5)
                        .frame(width: 52, height: 52)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 52, height: 52)
                        .rotationEffect(.degrees(-90))
                }

                VStack(spacing: 0) {
                    Text(value)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text(unit)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)
                }
            }

            VStack(spacing: 1) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                Text(sublabel)
                    .font(.system(size: 10))
                    .foregroundColor(sublabelColor)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var strainColor: Color {
        if integration.strainScore >= 18 { return GQColors.coralRed }
        if integration.strainScore >= 14 { return GQColors.sunsetOrange }
        if integration.strainScore >= 10 { return GQColors.electricGold }
        if integration.strainScore >= 6 { return GQColors.cyanSpark }
        return GQColors.success
    }

    private var strainLabel: String {
        if integration.strainScore >= 18 { return "Overreaching" }
        if integration.strainScore >= 14 { return "High" }
        if integration.strainScore >= 10 { return "Moderate" }
        if integration.strainScore >= 6 { return "Light" }
        return "Minimal"
    }
}

private struct StrainArcShape: Shape {
    let progress: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(135),
            endAngle: .degrees(135 + 270 * progress),
            clockwise: false
        )
        return path
    }
}

// MARK: - Progress Trend Chart

private enum TrendMetric: String, CaseIterable {
    case volume = "Volume"
    case sets = "Sets"
    case duration = "Duration"
}

private struct ProgressTrendChart: View {
    let workouts: [Workout]
    @State private var selectedMetric: TrendMetric = .volume
    @State private var drawProgress: CGFloat = 0

    private var weeklyData: [(label: String, value: Double)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var weeks: [(label: String, value: Double)] = []

        for i in (0..<8).reversed() {
            guard let weekStart = cal.date(byAdding: .weekOfYear, value: -i, to: today) else { continue }
            let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
            let weekWorkouts = workouts.filter { $0.date >= weekStart && $0.date < weekEnd }

            let value: Double
            switch selectedMetric {
            case .volume:
                value = weekWorkouts.reduce(0.0) { $0 + $1.totalVolume }
            case .sets:
                value = Double(weekWorkouts.reduce(0) { $0 + $1.totalSets })
            case .duration:
                value = Double(weekWorkouts.reduce(0) { $0 + $1.duration })
            }

            let month = cal.component(.month, from: weekStart)
            let day = cal.component(.day, from: weekStart)
            weeks.append((label: "\(month)/\(day)", value: value))
        }
        return weeks
    }

    private var maxValue: Double {
        max(weeklyData.map(\.value).max() ?? 1, 1)
    }

    private var trendPercentage: Double? {
        let data = weeklyData.map(\.value)
        guard data.count >= 2 else { return nil }
        let recent = data.suffix(2).reduce(0, +) / 2
        let earlier = data.prefix(2).reduce(0, +) / 2
        guard earlier > 0 else { return recent > 0 ? 100 : nil }
        return ((recent - earlier) / earlier) * 100
    }

    private var hasData: Bool {
        weeklyData.contains { $0.value > 0 }
    }

    var body: some View {
        VStack(spacing: 12) {
            trendHeader
            metricPicker
            if hasData {
                chartBody
                xAxisLabels
            } else {
                emptyChartState
            }
        }
        .padding(14)
        .homeSocialCard(accent: progressNeutralAccent)
        .onChange(of: selectedMetric) { _, _ in
            drawProgress = 0
            withAnimation(.easeOut(duration: 0.8)) {
                drawProgress = 1
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                drawProgress = 1
            }
        }
    }

    @ViewBuilder
    private var emptyChartState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 28))
                .foregroundColor(GQColors.textTertiary.opacity(0.5))
            Text("Complete workouts to see trends")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
    }

    @ViewBuilder
    private var trendHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("PROGRESS TREND")
                    .font(GQTypography.sectionHeader)
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(1)
                Text("8-Week Overview")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            Spacer()
            if let trend = trendPercentage, abs(trend) >= 1 {
                HStack(spacing: 3) {
                    Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 10, weight: .bold))
                    Text(String(format: "%.0f%%", abs(trend)))
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(trend >= 0 ? GQColors.success : GQColors.coralRed)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill((trend >= 0 ? GQColors.success : GQColors.coralRed).opacity(0.15))
                )
            }
        }
    }

    @ViewBuilder
    private var metricPicker: some View {
        HStack(spacing: 4) {
            ForEach(TrendMetric.allCases, id: \.self) { metric in
                Button {
                    selectedMetric = metric
                } label: {
                    Text(metric.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(selectedMetric == metric ? .white : GQColors.textTertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(selectedMetric == metric ? Color.white.opacity(0.08) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.white.opacity(0.06)))
    }

    @ViewBuilder
    private var chartBody: some View {
        let data = weeklyData
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let stepX = data.count > 1 ? w / CGFloat(data.count - 1) : w
            let points: [CGPoint] = data.enumerated().map { i, item in
                let x = CGFloat(i) * stepX
                let y = h - (CGFloat(item.value / maxValue) * (h - 8)) - 4
                return CGPoint(x: x, y: y)
            }

            ZStack {
                // Area fill
                if points.count >= 2 {
                    Path { path in
                        path.move(to: CGPoint(x: points[0].x, y: h))
                        path.addLine(to: points[0])
                        for i in 1..<points.count {
                            path.addLine(to: points[i])
                        }
                        path.addLine(to: CGPoint(x: points.last!.x, y: h))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.08), Color.white.opacity(0.01)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(Double(drawProgress))
                }

                // Line
                if points.count >= 2 {
                    Path { path in
                        path.move(to: points[0])
                        for i in 1..<points.count {
                            path.addLine(to: points[i])
                        }
                    }
                    .trim(from: 0, to: drawProgress)
                    .stroke(
                        Color.white.opacity(0.55),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )
                }

                // Data dots
                ForEach(Array(points.enumerated()), id: \.offset) { i, pt in
                    let isLast = i == points.count - 1
                    Circle()
                        .fill(Color.white)
                        .frame(width: isLast ? 8 : 6, height: isLast ? 8 : 6)
                        .shadow(color: isLast ? Color.white.opacity(0.5) : .clear, radius: 4)
                        .position(pt)
                        .opacity(Double(drawProgress))
                }
            }
        }
        .frame(height: 100)
    }

    @ViewBuilder
    private var xAxisLabels: some View {
        HStack {
            ForEach(Array(weeklyData.enumerated()), id: \.offset) { _, item in
                Text(item.label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(GQColors.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
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
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 5)
                    .frame(width: 48, height: 48)

                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(recoveryColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(-90))

                Text("\(recoveryScore)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(recoveryMessage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text("Recovery · \(recoveryScore)%")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(GQColors.textTertiary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                RecoveryPill(icon: "flame.fill", value: "\(streak)d", color: progressFireAccent)
                RecoveryPill(icon: "calendar", value: "\(sessionsThisWeek)x", color: GQColors.textSecondary)
            }
        }
        .padding(14)
        .homeSocialCard(accent: GQColors.cyanSpark, emphasized: true)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
                animatedProgress = CGFloat(recoveryScore) / 100
            }
        }
    }
}

private struct RecoveryPill: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.white.opacity(0.08)))
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
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.18))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(color)
                    )

                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(GQColors.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
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
                                        colors: [Color.white.opacity(0.25), Color.white.opacity(0.50)],
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
                                .fill(Color.white.opacity(0.10))
                            : nil
                    )
                    .overlay(
                        isToday
                            ? RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                            : nil
                    )
                }
            }
            .frame(height: 90)
        }
        .padding(14)
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
                VStack(spacing: 10) {
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
