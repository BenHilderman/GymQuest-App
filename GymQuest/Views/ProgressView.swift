//
//  ProgressView.swift
//  GymQuest
//
//  Analytics hub — PR history, exercise trends, volume analytics,
//  and body composition at a glance.
//

import SwiftUI
import SwiftData
import Charts

struct ProgressAnalyticsView: View {
    @Query(sort: \PREvent.date, order: .reverse) private var prEvents: [PREvent]
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]

    let profile: UserProfile

    @State private var selectedExerciseName: String = ""
    @State private var showingExerciseTrend = false
    @State private var showingPaywall = false

    private var recentPRs: [PREvent] {
        Array(prEvents.prefix(10))
    }

    private var validWorkouts: [Workout] {
        workouts.filter { $0.type != .rest }
    }

    // Volume per week for last 8 weeks
    private var weeklyVolumes: [(weekLabel: String, volume: Double)] {
        let calendar = Calendar.current
        let now = Date()
        var result: [(String, Double)] = []

        for weeksAgo in (0..<8).reversed() {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: now) else { continue }
            let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? now

            let weekWorkouts = validWorkouts.filter { $0.date >= weekStart && $0.date < weekEnd }
            var totalVolume: Double = 0
            for w in weekWorkouts {
                for ex in w.exercises {
                    for s in ex.sets {
                        totalVolume += Double(s.weight) * Double(s.reps)
                    }
                }
            }

            let label = weekStart.formatted(.dateTime.month(.abbreviated).day())
            result.append((label, totalVolume))
        }
        return result
    }

    // Muscle group distribution from recent workouts
    private var muscleGroupSplit: [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        for w in Array(validWorkouts.prefix(30)) {
            let name = w.type.rawValue
            counts[name, default: 0] += 1
        }
        return counts.map { (name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    // Exercise names for picker
    private var allExerciseNames: [String] {
        var names = Set<String>()
        for w in workouts {
            for ex in w.exercises {
                names.insert(ex.name)
            }
        }
        return names.sorted()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: GQLayout.sectionSpacing) {
                // MARK: - Personal Records
                prHistorySection

                // MARK: - Weekly Volume Chart
                weeklyVolumeSection

                // MARK: - Workout Type Distribution
                workoutSplitSection

                // MARK: - Exercise Trends
                exerciseTrendSection

                // MARK: - Body Composition Mini
                bodyCompositionMini
            }
            .padding(.horizontal, GQLayout.screenHorizontal)
            .padding(.top, GQLayout.pageTop)
            .padding(.bottom, GQLayout.pageBottom)
        }
        .gqPageBackground()
        .navigationTitle("Progress")
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
                .environmentObject(SubscriptionService.shared)
        }
    }

    // MARK: - PR History

    @ViewBuilder
    private var prHistorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PERSONAL RECORDS")
                .font(GQTypography.sectionHeader)
                .foregroundColor(GQColors.sectionLabel)
                .tracking(1)

            if recentPRs.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "trophy")
                            .font(.system(size: 28))
                            .foregroundColor(GQColors.textTertiary)
                        Text("No PRs yet")
                            .font(.system(size: 14))
                            .foregroundColor(GQColors.textTertiary)
                        Text("Complete workouts to start tracking records")
                            .font(.system(size: 12))
                            .foregroundColor(GQColors.textTertiary.opacity(0.7))
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                ForEach(recentPRs, id: \.id) { pr in
                    HStack(spacing: 12) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 14))
                            .foregroundColor(GQColors.prGold)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(pr.exerciseName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(GQColors.textPrimary)
                            Text(pr.prType.rawValue)
                                .font(.system(size: 11))
                                .foregroundColor(GQColors.textTertiary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "%.0f", pr.newValue))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(GQColors.textPrimary)
                            if let delta = pr.deltaDisplay {
                                Text(delta)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(GQColors.success)
                            }
                        }

                        Text(pr.date.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.system(size: 11))
                            .foregroundColor(GQColors.textTertiary)
                            .frame(width: 50, alignment: .trailing)
                    }
                    .padding(.vertical, 6)

                    if pr.id != recentPRs.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(GQLayout.cardHorizontal)
        .homeSocialCard()
    }

    // MARK: - Weekly Volume Chart

    @ViewBuilder
    private var weeklyVolumeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WEEKLY VOLUME")
                .font(GQTypography.sectionHeader)
                .foregroundColor(GQColors.sectionLabel)
                .tracking(1)

            if weeklyVolumes.allSatisfy({ $0.volume == 0 }) {
                Text("Log workouts to see volume trends")
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else {
                Chart(weeklyVolumes, id: \.weekLabel) { item in
                    BarMark(
                        x: .value("Week", item.weekLabel),
                        y: .value("Volume", item.volume)
                    )
                    .foregroundStyle(GQGradients.primary)
                    .cornerRadius(4)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(v >= 1000 ? "\(Int(v / 1000))k" : "\(Int(v))")
                                    .font(.system(size: 10))
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
                                    .font(.system(size: 9))
                                    .foregroundColor(GQColors.textTertiary)
                            }
                        }
                    }
                }
                .frame(height: 180)
            }
        }
        .padding(GQLayout.cardHorizontal)
        .homeSocialCard()
    }

    // MARK: - Workout Split

    @ViewBuilder
    private var workoutSplitSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WORKOUT SPLIT")
                .font(GQTypography.sectionHeader)
                .foregroundColor(GQColors.sectionLabel)
                .tracking(1)

            if muscleGroupSplit.isEmpty {
                Text("No workout data yet")
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                let total = muscleGroupSplit.reduce(0) { $0 + $1.count }

                VStack(spacing: 8) {
                    ForEach(muscleGroupSplit, id: \.name) { item in
                        HStack(spacing: 10) {
                            Text(item.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(GQColors.textPrimary)
                                .frame(width: 80, alignment: .leading)

                            GeometryReader { geo in
                                let fraction = total > 0 ? CGFloat(item.count) / CGFloat(total) : 0
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(GQGradients.primary)
                                    .frame(width: geo.size.width * fraction)
                            }
                            .frame(height: 8)

                            Text("\(item.count)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(GQColors.textSecondary)
                                .frame(width: 24, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding(GQLayout.cardHorizontal)
        .homeSocialCard()
    }

    // MARK: - Exercise Trend

    @ViewBuilder
    private var exerciseTrendSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("EXERCISE TRENDS")
                .font(GQTypography.sectionHeader)
                .foregroundColor(GQColors.sectionLabel)
                .tracking(1)

            if allExerciseNames.isEmpty {
                Text("Log exercises to see progression charts")
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                // Exercise picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(allExerciseNames.prefix(8), id: \.self) { name in
                            Button {
                                selectedExerciseName = name
                                showingExerciseTrend = true
                            } label: {
                                Text(name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(GQColors.vividPurple)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(GQColors.vividPurple.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if showingExerciseTrend && !selectedExerciseName.isEmpty {
                    ExerciseTrendChart(exerciseName: selectedExerciseName, workouts: Array(validWorkouts))
                        .transition(.opacity)
                }
            }
        }
        .padding(GQLayout.cardHorizontal)
        .homeSocialCard()
    }

    // MARK: - Body Composition Mini

    @ViewBuilder
    private var bodyCompositionMini: some View {
        NavigationLink {
            BodyMeasurementsView(profile: profile)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "figure.stand")
                    .font(.system(size: 20))
                    .foregroundColor(GQColors.cyanSpark)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Body Measurements")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                    Text("Track weight, body fat & measurements")
                        .font(.system(size: 12))
                        .foregroundColor(GQColors.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(GQColors.textTertiary)
            }
            .padding(GQLayout.cardHorizontal)
        }
        .buttonStyle(.plain)
        .homeSocialCard()
    }
}

// MARK: - Exercise Trend Chart

struct ExerciseTrendChart: View {
    let exerciseName: String
    let workouts: [Workout]

    private var dataPoints: [(date: Date, weight: Double)] {
        var points: [(Date, Double)] = []
        for w in workouts.reversed() {
            for ex in w.exercises where ex.name == exerciseName {
                let maxWeight = ex.sets.map { $0.weight }.max() ?? 0
                if maxWeight > 0 {
                    points.append((w.date, maxWeight))
                }
            }
        }
        return points
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(exerciseName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(GQColors.textPrimary)

            if dataPoints.count < 2 {
                Text("Need at least 2 sessions to show trend")
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textTertiary)
                    .padding(.vertical, 10)
            } else {
                Chart(dataPoints, id: \.date) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.weight)
                    )
                    .foregroundStyle(GQColors.vividPurple)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.weight)
                    )
                    .foregroundStyle(GQColors.vividPurple)
                    .symbolSize(30)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(Int(v))")
                                    .font(.system(size: 10))
                                    .foregroundColor(GQColors.textTertiary)
                            }
                        }
                    }
                }
                .frame(height: 150)
            }
        }
        .padding(.top, 8)
    }
}
