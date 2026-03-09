//
//  StatsFeedView.swift
//  GymQuest
//
//  Created by Benjamin Hilderman
//
//  Stats dashboard — summary row, weekly progress, activity rings,
//  health data, body weight trends, volume charts, PRs, exercise
//  progression, and AI coach.
//

import SwiftUI
import SwiftData
import Charts

struct StatsFeedView: View {
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @Query(sort: \PREvent.date, order: .reverse) private var prEvents: [PREvent]
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var bodyMeasurements: [BodyMeasurement]
    @Environment(\.modelContext) private var modelContext

    let profile: UserProfile
    var inline: Bool = false

    @StateObject private var healthKit = HealthKitService.shared
    @State private var showingHealthDashboard = false
    @State private var showingIntegrations = false
    @State private var showingBodyMeasurements = false
    @State private var showAllPRs = false
    @State private var selectedExerciseName = ""
    @State private var showingExerciseTrend = false
    @State private var ringsAnimated = false

    // Progress elements (from ProfileView)
    @State private var weeklyProgress: (completed: Int, target: Int) = (0, 0)
    @State private var readinessLevel: ReadinessLevel = .good
    @State private var showingCoach = false
    @State private var showingCalendarHistory = false

    // MARK: - Computed Properties

    private var validWorkouts: [Workout] {
        workouts.filter { $0.type != .rest }
    }

    private var currentStreak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let uniqueDates = Array(Set(validWorkouts.map { calendar.startOfDay(for: $0.date) })).sorted(by: >)
        guard let first = uniqueDates.first else { return 0 }
        let daysSince = calendar.dateComponents([.day], from: first, to: today).day ?? 0
        guard daysSince <= 1 else { return 0 }
        var streak = 1
        for i in 1..<uniqueDates.count {
            let diff = calendar.dateComponents([.day], from: uniqueDates[i], to: uniqueDates[i - 1]).day ?? 0
            if diff == 1 { streak += 1 } else { break }
        }
        return streak
    }

    private var weeklyWorkoutCount: Int {
        let weekStart = Calendar.current.startOfWeek(for: Date())
        return workouts.filter { $0.date >= weekStart && $0.type != .rest }.count
    }

    private var weeklyVolumePercent: Double {
        let calendar = Calendar.current
        let weekStart = calendar.startOfWeek(for: Date())
        let thisWeek = workouts.filter { $0.date >= weekStart }.reduce(0.0) { $0 + $1.totalVolume }
        var priorTotal: Double = 0
        var priorWeeks = 0
        for w in 1...4 {
            guard let start = calendar.date(byAdding: .weekOfYear, value: -w, to: weekStart),
                  let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) else { continue }
            let vol = workouts.filter { $0.date >= start && $0.date < end }.reduce(0.0) { $0 + $1.totalVolume }
            if vol > 0 { priorTotal += vol; priorWeeks += 1 }
        }
        let avg = priorWeeks > 0 ? priorTotal / Double(priorWeeks) : thisWeek
        guard avg > 0 else { return 0 }
        return min(thisWeek / avg, 1.5)
    }

    private var weeklyVolumeFormatted: String {
        let weekStart = Calendar.current.startOfWeek(for: Date())
        let vol = workouts.filter { $0.date >= weekStart }.reduce(0.0) { $0 + $1.totalVolume }
        if vol >= 1_000 { return String(format: "%.1fk", vol / 1_000) }
        return "\(Int(vol))"
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

    private var weightMeasurements: [BodyMeasurement] {
        Array(bodyMeasurements.filter { $0.type == .weight }.sorted { $0.date < $1.date }.suffix(30))
    }

    private var weightDelta: Double? {
        guard weightMeasurements.count >= 2,
              let latest = weightMeasurements.last,
              let earliest = weightMeasurements.first else { return nil }
        return latest.value - earliest.value
    }

    private var weeklyVolumes: [(weekLabel: String, volume: Double)] {
        let calendar = Calendar.current
        let now = Date()
        var result: [(String, Double)] = []
        for weeksAgo in (0..<8).reversed() {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: now) else { continue }
            let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? now
            let weekWorkouts = workouts.filter { $0.date >= weekStart && $0.date < weekEnd }
            let totalVolume = weekWorkouts.reduce(0.0) { $0 + $1.totalVolume }
            let label = weekStart.formatted(.dateTime.month(.abbreviated).day())
            result.append((label, totalVolume))
        }
        return result
    }

    private var recentPRs: [PREvent] {
        Array(prEvents.prefix(showAllPRs ? 20 : 5))
    }

    private var allExerciseNames: [String] {
        var names = Set<String>()
        for w in workouts { for ex in w.exercises { names.insert(ex.name) } }
        return names.sorted()
    }

    // MARK: - Body

    var body: some View {
        if inline {
            statsContent
        } else {
            ScrollView {
                statsContent
            }
            .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder
    private var statsContent: some View {
        VStack(spacing: 8) {
            progressSummaryRow
            profileWeeklyProgress
            activityRingsCard
            healthStatsCard
            bodyWeightTrendCard
            weeklyVolumeChart
            recentPRsSection
            exerciseTrendsSection
            aiCoachCard
        }
        .padding(.horizontal, inline ? 0 : 16)
        .padding(.top, inline ? 0 : GQLayout.pageTop)
        .padding(.bottom, inline ? 0 : GQLayout.pageBottom)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3)) {
                ringsAnimated = true
            }
            loadProfileActivityData()
        }
        .sheet(isPresented: $showingCoach) {
            CoachView(profile: profile, workouts: Array(workouts), aiService: AIService())
        }
    }

    // MARK: - Progress Summary Row

    @ViewBuilder
    private var progressSummaryRow: some View {
        HStack(spacing: 0) {
            summaryStatItem(value: "\(validWorkouts.count)", label: "Workouts")

            Rectangle()
                .fill(GQColors.borderSubtle)
                .frame(width: 1, height: 32)

            summaryStatItem(value: "\(currentStreak)", label: "Day Streak")

            Rectangle()
                .fill(GQColors.borderSubtle)
                .frame(width: 1, height: 32)

            summaryStatItem(value: homeTotalVolumeFormatted, label: "Volume")
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

    // MARK: - Weekly Progress Card

    @ViewBuilder
    private var profileWeeklyProgress: some View {
        WeeklyProgressCard(
            weeklyProgress: weeklyProgress,
            readinessLevel: readinessLevel,
            workouts: workouts,
            targetDays: profile.daysPerWeek,
            onTodayTap: nil,
            onRestTap: {
                logRestDay()
            },
            onTargetChanged: { newTarget in
                profile.daysPerWeek = newTarget
                try? modelContext.save()
                loadProfileActivityData()
            }
        )
        .onTapGesture {
            showingCalendarHistory = true
        }
        .sheet(isPresented: $showingCalendarHistory) {
            CalendarHistoryView(workouts: workouts)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
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
                        .fill(GQColors.cyanSpark.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(GQColors.cyanSpark)
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

    // MARK: - 1. Activity Rings Card (compact)

    @ViewBuilder
    private var activityRingsCard: some View {
        HStack(spacing: 14) {
            ringsView
                .frame(width: 80, height: 80)

            VStack(alignment: .leading, spacing: 6) {
                ringLabel(color: GQColors.vividPurple, value: "\(weeklyWorkoutCount)/\(profile.daysPerWeek)", label: "Workouts")
                ringLabel(color: GQColors.cyanSpark, value: weeklyVolumeFormatted, label: "Volume")
                ringLabel(color: GQColors.success, value: "\(currentStreak)d", label: "Streak")
            }
            Spacer()
        }
        .padding(12)
        .homeSocialCard(cornerRadius: 14)
    }

    @ViewBuilder
    private var ringsView: some View {
        let workoutProgress = profile.daysPerWeek > 0
            ? min(Double(weeklyWorkoutCount) / Double(profile.daysPerWeek), 1.0) : 0
        let volumeProgress = min(weeklyVolumePercent, 1.0)
        let streakProgress = min(Double(currentStreak) / 7.0, 1.0)

        ZStack {
            Circle().stroke(GQColors.vividPurple.opacity(0.15), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .frame(width: 72, height: 72)
            Circle().stroke(GQColors.cyanSpark.opacity(0.15), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .frame(width: 54, height: 54)
            Circle().stroke(GQColors.success.opacity(0.15), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .frame(width: 38, height: 38)

            Circle()
                .trim(from: 0, to: ringsAnimated ? workoutProgress : 0)
                .stroke(
                    AngularGradient(colors: [GQColors.deepBlue, GQColors.vividPurple], center: .center),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 72, height: 72)

            Circle()
                .trim(from: 0, to: ringsAnimated ? volumeProgress : 0)
                .stroke(GQColors.cyanSpark, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 54, height: 54)

            Circle()
                .trim(from: 0, to: ringsAnimated ? streakProgress : 0)
                .stroke(GQColors.success, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 38, height: 38)
        }
    }

    private func ringLabel(color: Color, value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(GQColors.textPrimary)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
        }
    }

    // MARK: - 2. Health Stats Card

    @ViewBuilder
    private var healthStatsCard: some View {
        if healthKit.isAuthorized {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("TODAY")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(GQColors.sectionLabel)
                        .tracking(0.6)
                    Spacer()
                    Button { showingHealthDashboard = true } label: {
                        Text("See All")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(GQColors.cyanSpark)
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    healthStatPill(icon: "figure.walk", value: "\(healthKit.steps)", label: "Steps", color: .green)
                    healthStatPill(icon: "flame.fill", value: "\(healthKit.activeCalories)", label: "Active Cal", color: .orange)
                    healthStatPill(icon: "bed.double.fill", value: String(format: "%.1fh", healthKit.sleepHours), label: "Sleep", color: .indigo)
                    healthStatPill(icon: "figure.run", value: "\(healthKit.exerciseMinutes)m", label: "Exercise", color: GQColors.cyanSpark)
                }
            }
            .padding(10)
            .homeSocialCard(cornerRadius: 14)
            .sheet(isPresented: $showingHealthDashboard) {
                NavigationStack { HealthDashboardView(profile: profile, workouts: Array(workouts)) }
            }
        } else {
            healthConnectPrompt
        }
    }

    @ViewBuilder
    private var healthConnectPrompt: some View {
        Button { showingIntegrations = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                Text("Connect Apple Health")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)
                Spacer()
                Text("Track health data")
                    .font(.system(size: 11))
                    .foregroundColor(GQColors.textTertiary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(GQColors.textTertiary)
            }
            .padding(10)
            .homeSocialCard(cornerRadius: 14)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingIntegrations) {
            NavigationStack { IntegrationsView(profile: profile) }
        }
    }

    private func healthStatPill(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(GQColors.textPrimary)
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(GQColors.textTertiary)
            }
            Spacer()
        }
        .padding(6)
        .background(GQColors.adaptiveOverlay(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - 3. Body Weight Trend Card (compact)

    @ViewBuilder
    private var bodyWeightTrendCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("BODY WEIGHT")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(GQColors.sectionLabel)
                    .tracking(0.6)
                if let latest = weightMeasurements.last {
                    Text(String(format: "%.1f lbs", latest.value))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(GQColors.textPrimary)
                }
                if let delta = weightDelta {
                    Text(String(format: "%+.1f", delta))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(delta >= 0 ? GQColors.success : GQColors.error)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background((delta >= 0 ? GQColors.success : GQColors.error).opacity(0.12))
                        .clipShape(Capsule())
                }
                Spacer()
                Button { showingBodyMeasurements = true } label: {
                    Text("See All")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(GQColors.cyanSpark)
                }
            }
            bodyWeightChart
        }
        .padding(10)
        .homeSocialCard(cornerRadius: 14)
        .sheet(isPresented: $showingBodyMeasurements) {
            NavigationStack { BodyMeasurementsView(profile: profile) }
        }
    }

    @ViewBuilder
    private var bodyWeightChart: some View {
        if weightMeasurements.count >= 2 {
            Chart(weightMeasurements, id: \.id) { m in
                LineMark(x: .value("Date", m.date), y: .value("Weight", m.value))
                    .foregroundStyle(GQColors.vividPurple)
                    .interpolationMethod(.catmullRom)
                AreaMark(x: .value("Date", m.date), y: .value("Weight", m.value))
                    .foregroundStyle(
                        LinearGradient(colors: [GQColors.vividPurple.opacity(0.3), .clear],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .interpolationMethod(.catmullRom)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text("\(Int(v))")
                                .font(.system(size: 9))
                                .foregroundColor(GQColors.textTertiary)
                        }
                    }
                }
            }
            .chartXAxis(.hidden)
            .frame(height: 100)
        } else {
            HStack(spacing: 6) {
                Image(systemName: "scalemass")
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.textTertiary)
                Text("Log body weight to see trends")
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    // MARK: - 4. Weekly Volume Chart (compact)

    @ViewBuilder
    private var weeklyVolumeChart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WEEKLY VOLUME")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(GQColors.sectionLabel)
                .tracking(0.6)

            Chart(weeklyVolumes, id: \.weekLabel) { item in
                BarMark(
                    x: .value("Week", item.weekLabel),
                    y: .value("Volume", item.volume)
                )
                .foregroundStyle(GQGradients.primary)
                .cornerRadius(3)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(v >= 1000 ? "\(Int(v / 1000))k" : "\(Int(v))")
                                .font(.system(size: 9))
                                .foregroundColor(GQColors.textTertiary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(.system(size: 8))
                                .foregroundColor(GQColors.textTertiary)
                        }
                    }
                }
            }
            .frame(height: 140)
        }
        .padding(10)
        .homeSocialCard(cornerRadius: 14)
    }

    // MARK: - 5. Recent PRs Section (compact)

    @ViewBuilder
    private var recentPRsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RECENT PRs")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(GQColors.sectionLabel)
                .tracking(0.6)

            if recentPRs.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "trophy")
                        .font(.system(size: 14))
                        .foregroundColor(GQColors.textTertiary)
                    Text("No PRs yet — complete workouts to track records")
                        .font(.system(size: 12))
                        .foregroundColor(GQColors.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
            } else {
                prList
            }
        }
        .padding(10)
        .homeSocialCard(cornerRadius: 14)
    }

    @ViewBuilder
    private var prList: some View {
        ForEach(recentPRs, id: \.id) { pr in
            prRow(pr)
            if pr.id != recentPRs.last?.id {
                Divider()
            }
        }

        if !showAllPRs && prEvents.count > 5 {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showAllPRs = true }
            } label: {
                Text("See All")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(GQColors.vividPurple)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .buttonStyle(.plain)
        }
    }

    private func prRow(_ pr: PREvent) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 12))
                .foregroundColor(GQColors.prGold)

            if FeatureFlags.shared.exerciseGifsEnabled {
                ExerciseGifView(exerciseName: pr.exerciseName, size: .thumbnail, showFallback: false)
                    .scaleEffect(0.7)
                    .frame(width: 26, height: 26)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(pr.exerciseName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)
                    .lineLimit(1)
                Text(pr.prType.rawValue)
                    .font(.system(size: 10))
                    .foregroundColor(GQColors.textTertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(String(format: "%.0f", pr.newValue))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(GQColors.textPrimary)
                if let delta = pr.deltaDisplay {
                    Text(delta)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(GQColors.success)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - 6. Exercise Trends Section (compact)

    @ViewBuilder
    private var exerciseTrendsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("EXERCISE TRENDS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(GQColors.sectionLabel)
                .tracking(0.6)

            if allExerciseNames.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 14))
                        .foregroundColor(GQColors.textTertiary)
                    Text("Log exercises to see progression charts")
                        .font(.system(size: 12))
                        .foregroundColor(GQColors.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
            } else {
                exercisePillPicker
                if showingExerciseTrend && !selectedExerciseName.isEmpty {
                    ExerciseTrendChart(exerciseName: selectedExerciseName, workouts: Array(validWorkouts))
                        .transition(.opacity)
                }
            }
        }
        .padding(10)
        .homeSocialCard(cornerRadius: 14)
    }

    @ViewBuilder
    private var exercisePillPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(allExerciseNames.prefix(8), id: \.self) { name in
                    let isSelected = selectedExerciseName == name
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedExerciseName = name
                            showingExerciseTrend = true
                        }
                    } label: {
                        Text(name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(isSelected ? .white : GQColors.vividPurple)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(isSelected ? GQColors.vividPurple : GQColors.vividPurple.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear {
            if selectedExerciseName.isEmpty, let first = allExerciseNames.first {
                selectedExerciseName = first
                showingExerciseTrend = true
            }
        }
    }
}
