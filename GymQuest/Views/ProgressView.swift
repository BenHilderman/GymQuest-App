//
//  ProgressView.swift
//  GymQuest
//
//  Visual analytics — rings, charts, and trends.
//

import SwiftUI
import SwiftData
import Charts

struct ProgressAnalyticsView: View {
    @Query(sort: \PREvent.date, order: .reverse) private var prEvents: [PREvent]
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var measurements: [BodyMeasurement]

    let profile: UserProfile
    var inline: Bool = false

    @State private var selectedExerciseName: String = ""
    @State private var showingExerciseTrend = false

    private var validWorkouts: [Workout] {
        workouts.filter { $0.type != .rest }
    }

    private var recentPRs: [PREvent] { Array(prEvents.prefix(5)) }

    private var weeklyVolumes: [(weekLabel: String, volume: Double)] {
        let calendar = Calendar.current
        let now = Date()
        var result: [(String, Double)] = []
        for weeksAgo in (0..<6).reversed() {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: now) else { continue }
            let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? now
            let weekWorkouts = validWorkouts.filter { $0.date >= weekStart && $0.date < weekEnd }
            var vol: Double = 0
            for w in weekWorkouts { for ex in w.exercises { for s in ex.sets { vol += Double(s.weight) * Double(s.reps) } } }
            result.append((weekStart.formatted(.dateTime.month(.abbreviated).day()), vol))
        }
        return result
    }

    private var workoutSplit: [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        for w in Array(validWorkouts.prefix(30)) { counts[w.type.rawValue, default: 0] += 1 }
        return counts.map { (name: $0.key, count: $0.value) }.sorted { $0.count > $1.count }
    }

    private var allExerciseNames: [String] {
        var names = Set<String>()
        for w in workouts { for ex in w.exercises { names.insert(ex.name) } }
        return names.sorted()
    }

    private var totalWorkouts: Int { validWorkouts.count }
    private var totalPRs: Int { prEvents.count }

    private var thisWeekWorkouts: Int {
        let calendar = Calendar.current
        guard let start = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
        return validWorkouts.filter { $0.date >= start }.count
    }

    private var volumeTrend: Double {
        guard weeklyVolumes.count >= 2 else { return 0 }
        let last = weeklyVolumes.last?.volume ?? 0
        let prev = weeklyVolumes[weeklyVolumes.count - 2].volume
        guard prev > 0 else { return 0 }
        return ((last - prev) / prev) * 100
    }

    // Body measurement helpers
    private var weightMeasurements: [BodyMeasurement] {
        measurements.filter { $0.type == .weight }.sorted { $0.date < $1.date }
    }

    private var latestWeight: Double? { weightMeasurements.last?.value }

    private var weightChange: Double? {
        guard weightMeasurements.count >= 2 else { return nil }
        return weightMeasurements.last!.value - weightMeasurements[weightMeasurements.count - 2].value
    }

    var body: some View {
        if inline {
            analyticsContent
        } else {
            ScrollView { analyticsContent }
                .gqPageBackground()
                .navigationTitle("Progress")
        }
    }

    private var analyticsContent: some View {
        VStack(spacing: 16) {
            // Ring stats row
            ringStatsRow

            // Volume trend chart
            volumeCard

            // Workout split donut
            splitCard

            // Body progress
            bodyProgressCard

            // PRs
            if !recentPRs.isEmpty { prsCard }

            // Exercise trends
            exerciseTrendCard
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 100)
    }

    // MARK: - Ring Stats

    private var ringStatsRow: some View {
        HStack(spacing: 12) {
            ringStatCard(
                icon: "flame.fill",
                value: thisWeekWorkouts,
                target: profile.daysPerWeek,
                title: "This Week",
                detail: "\(thisWeekWorkouts) of \(profile.daysPerWeek) days",
                gradient: GQGradients.primary
            )

            ringStatCard(
                icon: "trophy.fill",
                value: min(totalPRs, 10),
                target: 10,
                title: "PRs Hit",
                detail: "\(totalPRs) total",
                gradient: GQGradients.primary
            )

            // Volume trend card
            VStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(GQGradients.primary)

                ZStack {
                    Circle()
                        .stroke(GQColors.adaptiveOverlay(0.06), lineWidth: 4.5)
                        .frame(width: 52, height: 52)
                    Circle()
                        .trim(from: 0, to: min(abs(volumeTrend) / 100, 1.0))
                        .stroke(
                            volumeTrend >= 0 ? GQGradients.primary : LinearGradient(colors: [GQColors.textSecondary, GQColors.textTertiary], startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 52, height: 52)

                    HStack(spacing: 1) {
                        Image(systemName: volumeTrend >= 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: 9, weight: .bold))
                        Text(String(format: "%.0f%%", abs(volumeTrend)))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(GQColors.textPrimary)
                }

                VStack(spacing: 1) {
                    Text("Volume")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                    Text("vs last week")
                        .font(.system(size: 9))
                        .foregroundColor(GQColors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .homeSocialCard(cornerRadius: 14)
        }
    }

    private func ringStatCard(icon: String, value: Int, target: Int, title: String, detail: String, gradient: LinearGradient) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(gradient)

            ZStack {
                Circle()
                    .stroke(GQColors.adaptiveOverlay(0.06), lineWidth: 4.5)
                    .frame(width: 52, height: 52)
                Circle()
                    .trim(from: 0, to: target > 0 ? min(CGFloat(value) / CGFloat(target), 1.0) : 0)
                    .stroke(gradient, style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 52, height: 52)
                Text("\(value)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(GQColors.textPrimary)
            }

            VStack(spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)
                Text(detail)
                    .font(.system(size: 9))
                    .foregroundColor(GQColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .homeSocialCard(cornerRadius: 14)
    }

    // MARK: - Volume Card

    private var volumeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weekly Volume")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                    Text("Total weight lifted per week")
                        .font(.system(size: 11))
                        .foregroundColor(GQColors.textTertiary)
                }
                Spacer()
                if let lastVol = weeklyVolumes.last?.volume, lastVol > 0 {
                    Text(lastVol >= 1000 ? String(format: "%.1fk lbs", lastVol / 1000) : "\(Int(lastVol)) lbs")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(GQGradients.primary)
                }
            }

            if weeklyVolumes.allSatisfy({ $0.volume == 0 }) {
                Text("Log workouts to see volume trends")
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                Chart(weeklyVolumes, id: \.weekLabel) { item in
                    AreaMark(
                        x: .value("Week", item.weekLabel),
                        y: .value("Volume", item.volume)
                    )
                    .foregroundStyle(GQGradients.primary.opacity(0.12))
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Week", item.weekLabel),
                        y: .value("Volume", item.volume)
                    )
                    .foregroundStyle(GQGradients.primary)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.catmullRom)
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
                .frame(height: 130)
            }
        }
        .padding(14)
        .homeSocialCard(cornerRadius: 14)
    }

    // MARK: - Split Card (Visual)

    private var splitCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workout Split")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(GQColors.textPrimary)

            if workoutSplit.isEmpty {
                Text("No workout data yet")
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                let total = workoutSplit.reduce(0) { $0 + $1.count }

                HStack(alignment: .center, spacing: 20) {
                    // Donut with gradient strokes
                    ZStack {
                        // Background track
                        Circle()
                            .stroke(GQColors.adaptiveOverlay(0.04), lineWidth: 12)
                            .frame(width: 90, height: 90)

                        ForEach(Array(workoutSplit.enumerated()), id: \.element.name) { index, item in
                            let fraction = total > 0 ? CGFloat(item.count) / CGFloat(total) : 0
                            let startAngle = workoutSplit.prefix(index).reduce(0.0) { acc, s in
                                acc + (total > 0 ? CGFloat(s.count) / CGFloat(total) : 0)
                            }
                            Circle()
                                .trim(from: startAngle + 0.005, to: startAngle + fraction - 0.005)
                                .stroke(
                                    splitGradient(for: index),
                                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                        }

                        VStack(spacing: 0) {
                            Text("\(total)")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(GQColors.textPrimary)
                            Text("workouts")
                                .font(.system(size: 9))
                                .foregroundColor(GQColors.textTertiary)
                        }
                    }
                    .frame(width: 90, height: 90)

                    // Legend
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(workoutSplit.enumerated()), id: \.element.name) { index, item in
                            let pct = total > 0 ? Int(round(Double(item.count) / Double(total) * 100)) : 0
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(splitGradient(for: index))
                                    .frame(width: 12, height: 12)
                                Text(item.name.capitalized)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(GQColors.textPrimary)
                                Spacer()
                                Text("\(pct)%")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(GQColors.textSecondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(14)
        .homeSocialCard(cornerRadius: 14)
    }

    private func splitGradient(for index: Int) -> LinearGradient {
        let gradients: [LinearGradient] = [
            LinearGradient(colors: [GQColors.deepBlue, GQColors.vividPurple], startPoint: .topLeading, endPoint: .bottomTrailing),
            LinearGradient(colors: [GQColors.vividPurple, GQColors.coralRed], startPoint: .topLeading, endPoint: .bottomTrailing),
            LinearGradient(colors: [GQColors.cyanSpark, GQColors.deepBlue], startPoint: .topLeading, endPoint: .bottomTrailing),
            LinearGradient(colors: [GQColors.sunsetOrange, GQColors.coralRed], startPoint: .topLeading, endPoint: .bottomTrailing),
            LinearGradient(colors: [GQColors.success, GQColors.cyanSpark], startPoint: .topLeading, endPoint: .bottomTrailing),
            LinearGradient(colors: [GQColors.deepBlue, GQColors.cyanSpark], startPoint: .topLeading, endPoint: .bottomTrailing),
        ]
        return gradients[index % gradients.count]
    }

    // MARK: - Body Progress

    private var bodyProgressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Body Progress")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)
                Spacer()
                if latestWeight != nil {
                    NavigationLink {
                        BodyMeasurementsView(profile: profile)
                    } label: {
                        Text("All")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(GQColors.textTertiary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(GQColors.textTertiary)
                    }
                }
            }

            if weightMeasurements.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "scalemass")
                            .font(.system(size: 24))
                            .foregroundColor(GQColors.textTertiary)
                        Text("No measurements logged")
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textTertiary)
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
            } else {
                HStack(spacing: 16) {
                    // Current weight ring
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .stroke(GQColors.adaptiveOverlay(0.08), lineWidth: 5)
                                .frame(width: 64, height: 64)
                            Circle()
                                .trim(from: 0, to: 0.75)
                                .stroke(GQGradients.primary, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .frame(width: 64, height: 64)

                            VStack(spacing: 0) {
                                if let w = latestWeight {
                                    Text(String(format: "%.0f", w))
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(GQColors.textPrimary)
                                    Text("lbs")
                                        .font(.system(size: 9))
                                        .foregroundColor(GQColors.textTertiary)
                                }
                            }
                        }

                        if let change = weightChange {
                            HStack(spacing: 2) {
                                Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                                    .font(.system(size: 9, weight: .bold))
                                Text(String(format: "%.1f", abs(change)))
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(GQColors.textSecondary)
                        }
                    }

                    // Weight sparkline
                    if weightMeasurements.count >= 2 {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Weight Trend")
                                .font(.system(size: 11))
                                .foregroundColor(GQColors.textTertiary)

                            Chart(weightMeasurements.suffix(10), id: \.id) { m in
                                AreaMark(
                                    x: .value("Date", m.date),
                                    y: .value("Weight", m.value)
                                )
                                .foregroundStyle(GQGradients.primary.opacity(0.1))
                                .interpolationMethod(.catmullRom)

                                LineMark(
                                    x: .value("Date", m.date),
                                    y: .value("Weight", m.value)
                                )
                                .foregroundStyle(GQGradients.primary)
                                .lineStyle(StrokeStyle(lineWidth: 2))
                                .interpolationMethod(.catmullRom)
                            }
                            .chartXAxis(.hidden)
                            .chartYAxis(.hidden)
                            .frame(height: 50)
                        }
                    }
                }
            }
        }
        .padding(14)
        .homeSocialCard(cornerRadius: 14)
    }

    // MARK: - PRs Card

    private var prsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent PRs")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(GQColors.textPrimary)

            ForEach(recentPRs, id: \.id) { pr in
                HStack(spacing: 10) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(GQGradients.primary)

                    Text(pr.exerciseName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(GQColors.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Text(String(format: "%.0f", pr.newValue))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(GQColors.textPrimary)

                    if let delta = pr.deltaDisplay {
                        Text(delta)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(GQColors.success)
                    }
                }
                .padding(.vertical, 4)

                if pr.id != recentPRs.last?.id {
                    Divider().overlay(GQColors.borderDefault)
                }
            }
        }
        .padding(14)
        .homeSocialCard(cornerRadius: 14)
    }

    // MARK: - Exercise Trend Card

    private var exerciseTrendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Exercise Trends")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(GQColors.textPrimary)

            if allExerciseNames.isEmpty {
                Text("Log exercises to see progression")
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(allExerciseNames.prefix(8), id: \.self) { name in
                            let isSelected = selectedExerciseName == name
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedExerciseName = name
                                    showingExerciseTrend = true
                                }
                            } label: {
                                Text(name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(isSelected ? .white : GQColors.textPrimary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        isSelected ?
                                        AnyShapeStyle(GQGradients.primary) :
                                        AnyShapeStyle(GQColors.adaptiveOverlay(0.06))
                                    )
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(isSelected ? AnyShapeStyle(Color.clear) : AnyShapeStyle(GQColors.borderDefault), lineWidth: 1)
                                    )
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

                if showingExerciseTrend && !selectedExerciseName.isEmpty {
                    ExerciseTrendChart(exerciseName: selectedExerciseName, workouts: Array(validWorkouts))
                        .transition(.opacity)
                }
            }
        }
        .padding(14)
        .homeSocialCard(cornerRadius: 14)
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
                if maxWeight > 0 { points.append((w.date, maxWeight)) }
            }
        }
        return points
    }

    var body: some View {
        if dataPoints.count < 2 {
            Text("Need at least 2 sessions to show trend")
                .font(.system(size: 12))
                .foregroundColor(GQColors.textTertiary)
                .padding(.vertical, 10)
        } else {
            Chart(dataPoints, id: \.date) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", point.weight)
                )
                .foregroundStyle(GQGradients.primary.opacity(0.1))
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", point.weight)
                )
                .foregroundStyle(GQGradients.primary)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", point.weight)
                )
                .foregroundStyle(GQGradients.primary)
                .symbolSize(20)
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
            .frame(height: 130)
        }
    }
}
