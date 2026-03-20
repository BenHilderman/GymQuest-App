//
//  TVProgressView.swift
//  GymQuestTV
//
//  Created by Benjamin Hilderman
//
//  Progress and analytics screen for the tvOS companion app.
//

#if os(tvOS)

import SwiftUI
import SwiftData
import Charts

// MARK: - Constants

private let offWhite = Color(white: 0.93)
// Glass material used for cards

// MARK: - TVProgressView

struct TVProgressView: View {
    @Query(sort: \Workout.date, order: .reverse) private var allWorkouts: [Workout]

    // MARK: - Computed Properties

    private var nonRestWorkouts: [Workout] {
        allWorkouts.filter { $0.type != .rest }
    }

    private var weeklyVolumeData: [WeeklyVolume] {
        let calendar = Calendar.current
        let today = Date()
        var weeks: [WeeklyVolume] = []

        for weekOffset in (0..<8).reversed() {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: today),
                  let interval = calendar.dateInterval(of: .weekOfYear, for: weekStart) else { continue }

            let volume = nonRestWorkouts
                .filter { $0.date >= interval.start && $0.date < interval.end }
                .reduce(0.0) { $0 + $1.totalVolume }

            let label = interval.start.formatted(.dateTime.month(.abbreviated).day())
            weeks.append(WeeklyVolume(weekLabel: label, weekStart: interval.start, volume: volume))
        }
        return weeks
    }

    private var workoutSplitData: [SplitSlice] {
        var counts: [WorkoutType: Int] = [:]
        for workout in nonRestWorkouts {
            counts[workout.type, default: 0] += 1
        }
        return counts.map { SplitSlice(type: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    private var totalWorkouts: Int {
        nonRestWorkouts.count
    }

    private var totalPRs: Int {
        allWorkouts.flatMap { $0.prEvents }.count
    }

    private var bestStreak: Int {
        let calendar = Calendar.current
        let sortedDates = nonRestWorkouts
            .map { calendar.startOfDay(for: $0.date) }
            .sorted()

        guard !sortedDates.isEmpty else { return 0 }

        var uniqueDays: [Date] = [sortedDates[0]]
        for date in sortedDates.dropFirst() {
            if date != uniqueDays.last {
                uniqueDays.append(date)
            }
        }

        var maxStreak = 1
        var currentStreak = 1
        for i in 1..<uniqueDays.count {
            let diff = calendar.dateComponents([.day], from: uniqueDays[i - 1], to: uniqueDays[i]).day ?? 0
            if diff == 1 {
                currentStreak += 1
                maxStreak = max(maxStreak, currentStreak)
            } else {
                currentStreak = 1
            }
        }
        return maxStreak
    }

    private var totalVolume: Double {
        nonRestWorkouts.reduce(0) { $0 + $1.totalVolume }
    }

    private var recentPRs: [PREvent] {
        Array(
            allWorkouts
                .flatMap { $0.prEvents }
                .sorted { $0.date > $1.date }
                .prefix(20)
        )
    }

    private var hasWorkouts: Bool {
        !nonRestWorkouts.isEmpty
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            if hasWorkouts {
                VStack(spacing: 70) {
                    chartsRow
                    statsRow
                    prTimelineSection
                }
                .padding(TVLayout.safeAreaInset)
            } else {
                emptyStateView
            }
        }
        .background(Color(white: 0.11).ignoresSafeArea())
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "chart.bar.xaxis.ascending")
                .font(.system(size: 72, weight: .medium))
                .foregroundStyle(GQGradients.primary)

            Text("No Workouts Yet")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(offWhite)

            Text("Complete your first workout to see progress analytics here.")
                .font(.system(size: 22, weight: .regular))
                .foregroundColor(offWhite.opacity(0.6))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)
        }
        .frame(maxWidth: .infinity, minHeight: 600)
        .padding(TVLayout.safeAreaInset)
    }

    // MARK: - Charts Row (two-column)

    @ViewBuilder
    private var chartsRow: some View {
        HStack(alignment: .top, spacing: TVLayout.gridSpacing) {
            volumeChart
            splitChart
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Weekly Volume Line Chart

    @ViewBuilder
    private var volumeChart: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Weekly Volume")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(offWhite)

            TVGlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    if weeklyVolumeData.isEmpty {
                        Text("No workout data yet")
                            .font(TVTypography.body)
                            .foregroundColor(offWhite.opacity(0.5))
                            .frame(maxWidth: .infinity, minHeight: 280, alignment: .center)
                    } else {
                        Chart(weeklyVolumeData) { week in
                            LineMark(
                                x: .value("Week", week.weekLabel),
                                y: .value("Volume", week.volume)
                            )
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            .foregroundStyle(GQGradients.primary)
                            .interpolationMethod(.catmullRom)

                            AreaMark(
                                x: .value("Week", week.weekLabel),
                                y: .value("Volume", week.volume)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [GQColors.deepBlue.opacity(0.3), GQColors.vividPurple.opacity(0.05)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("Week", week.weekLabel),
                                y: .value("Volume", week.volume)
                            )
                            .symbolSize(60)
                            .foregroundStyle(GQColors.cyanSpark)
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisValueLabel {
                                    if let v = value.as(Double.self) {
                                        Text(formattedVolume(v))
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundColor(offWhite.opacity(0.6))
                                    }
                                }
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                                    .foregroundStyle(offWhite.opacity(0.1))
                            }
                        }
                        .chartXAxis {
                            AxisMarks { value in
                                AxisValueLabel {
                                    if let label = value.as(String.self) {
                                        Text(label)
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundColor(offWhite.opacity(0.6))
                                    }
                                }
                            }
                        }
                        .frame(height: 280)
                    }
                }
                .padding(TVLayout.cardInset)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Workout Split Donut Chart

    @ViewBuilder
    private var splitChart: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Workout Split")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(offWhite)

            TVGlassCard {
                if workoutSplitData.isEmpty {
                    Text("No workout data yet")
                        .font(TVTypography.body)
                        .foregroundColor(offWhite.opacity(0.5))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .padding(TVLayout.cardInset)
                } else {
                    HStack(spacing: 32) {
                        Chart(workoutSplitData) { slice in
                            SectorMark(
                                angle: .value("Count", slice.count),
                                innerRadius: .ratio(0.55),
                                angularInset: 2
                            )
                            .foregroundStyle(sliceColor(for: slice.type))
                            .cornerRadius(4)
                        }
                        .frame(width: 240, height: 240)

                        // Legend
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(workoutSplitData) { slice in
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(sliceColor(for: slice.type))
                                        .frame(width: 14, height: 14)
                                    Text(slice.type.rawValue)
                                        .font(TVTypography.caption)
                                        .foregroundColor(offWhite)
                                    Spacer()
                                    Text("\(slice.count)")
                                        .font(TVTypography.caption)
                                        .foregroundColor(offWhite.opacity(0.6))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: .infinity)
                    .padding(TVLayout.cardInset)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Stats Summary Row

    @ViewBuilder
    private var statsRow: some View {
        HStack(spacing: 24) {
            TVStatCard(
                title: "Total Workouts",
                value: "\(totalWorkouts)",
                icon: "figure.strengthtraining.traditional",
                color: GQColors.deepBlue
            )
            TVStatCard(
                title: "Total PRs",
                value: "\(totalPRs)",
                icon: "trophy.fill",
                color: Color(red: 0.75, green: 0.65, blue: 0.45)
            )
            TVStatCard(
                title: "Best Streak",
                value: "\(bestStreak) days",
                icon: "flame.fill",
                color: GQColors.success
            )
            TVStatCard(
                title: "Total Volume",
                value: formattedVolume(totalVolume),
                icon: "scalemass.fill",
                color: GQColors.cyanSpark
            )
        }
    }

    // MARK: - PR Timeline

    @ViewBuilder
    private var prTimelineSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("PR Timeline")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(offWhite)

            if recentPRs.isEmpty {
                Text("No PRs recorded yet")
                    .font(TVTypography.body)
                    .foregroundColor(offWhite.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 24) {
                        ForEach(Array(recentPRs.enumerated()), id: \.offset) { _, pr in
                            prCard(pr)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }

    @ViewBuilder
    private func prCard(_ pr: PREvent) -> some View {
        Button(action: {}) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color(red: 0.75, green: 0.65, blue: 0.45))

                    Text(pr.prType.rawValue)
                        .font(TVTypography.caption)
                        .foregroundColor(Color(red: 0.75, green: 0.65, blue: 0.45))
                        .textCase(.uppercase)

                    Spacer()
                }

                Text(pr.exerciseName)
                    .font(TVTypography.cardTitle)
                    .foregroundColor(offWhite)
                    .lineLimit(1)

                Text("\(Int(pr.newValue)) lbs")
                    .font(TVTypography.stat)
                    .foregroundColor(offWhite)

                if let delta = pr.delta, delta > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 20, weight: .bold))
                        Text("+\(Int(delta)) lbs")
                            .font(TVTypography.caption)
                    }
                    .foregroundColor(GQColors.success)
                }

                Text(pr.date.formatted(.dateTime.month(.abbreviated).day()))
                    .font(TVTypography.caption)
                    .foregroundColor(offWhite.opacity(0.5))
            }
            .padding(24)
            .frame(width: 220, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: TVLayout.cornerRadius)
                    .fill(Color(white: 0.18))
            )
            .clipShape(RoundedRectangle(cornerRadius: TVLayout.cornerRadius))
            .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .tvFocusCard()
    }

    // MARK: - Helpers

    private func formattedVolume(_ volume: Double) -> String {
        if volume >= 1_000_000 {
            return String(format: "%.1fM", volume / 1_000_000)
        } else if volume >= 1000 {
            return String(format: "%.1fk", volume / 1000)
        }
        return "\(Int(volume)) lbs"
    }

    private func sliceColor(for type: WorkoutType) -> Color {
        switch type {
        case .push: return GQColors.deepBlue
        case .pull: return GQColors.vividPurple
        case .legs: return GQColors.success
        case .upper: return GQColors.cyanSpark
        case .cardio: return Color(red: 0.75, green: 0.65, blue: 0.45)
        default: return GQColors.textSecondary
        }
    }
}

// MARK: - Chart Data Models

private struct WeeklyVolume: Identifiable {
    let id = UUID()
    let weekLabel: String
    let weekStart: Date
    let volume: Double
}

private struct SplitSlice: Identifiable {
    let id = UUID()
    let type: WorkoutType
    let count: Int
}

#endif
