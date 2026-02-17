//
//  HealthDashboardView.swift
//  GymQuest
//
//  Unified health dashboard showing recovery, strain, sleep, vitals,
//  and strength score from all connected sources.
//  Interactive cards that expand for detail. Non-overwhelming layout.
//

import SwiftUI
import SwiftData

struct HealthDashboardView: View {
    let profile: UserProfile
    let workouts: [Workout]

    @StateObject private var integration = IntegrationManager.shared

    var body: some View {
        VStack(spacing: 16) {
            // Top row: Recovery + Strain
            HStack(spacing: 12) {
                RecoveryRingCard(
                    score: integration.recoveryScore,
                    level: integration.readinessLevel,
                    source: integration.whoop.isConnected ? "WHOOP" : "Estimated"
                )

                StrainGaugeCard(
                    strain: integration.strainScore,
                    source: integration.whoop.isConnected ? "WHOOP" : "Estimated"
                )
            }

            // Sleep breakdown
            SleepBreakdownCard(
                totalHours: integration.healthKit.sleepHours,
                stages: integration.healthKit.sleepStages,
                efficiency: integration.healthKit.sleepEfficiency,
                whoopSleep: integration.whoop.latestSleep
            )

            // Vitals grid
            if integration.hasAnyConnection {
                VitalsGridCard(
                    rhr: integration.healthKit.restingHeartRate,
                    hrv: integration.healthKit.hrvMs,
                    spo2: integration.healthKit.spo2Percentage,
                    respRate: integration.healthKit.respiratoryRate,
                    vo2Max: integration.healthKit.vo2Max,
                    wristTemp: integration.healthKit.wristTemperature,
                    whoopMonitor: integration.whoop.healthMonitor
                )
            }

            // Strength Score
            if integration.strengthScore > 0 {
                StrengthScoreCard(
                    score: integration.strengthScore,
                    workoutCount: workouts.count
                )
            }
        }
        .onAppear {
            integration.computeUnifiedMetrics()
            integration.computeStrengthScore(workouts: workouts)
        }
    }
}

// MARK: - Recovery Ring Card

private struct RecoveryRingCard: View {
    let score: Double
    let level: ReadinessLevel
    let source: String

    var body: some View {
        VStack(spacing: 10) {
            // Ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 6)
                    .frame(width: 64, height: 64)

                Circle()
                    .trim(from: 0, to: score / 100)
                    .stroke(level.color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(Int(score))")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text("%")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)
                }
            }

            VStack(spacing: 2) {
                Text("Recovery")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text(level.rawValue)
                    .font(.system(size: 11))
                    .foregroundColor(level.color)
            }

            Text(source)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Capsule().fill(GQColors.surfaceOverlay))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(GQColors.surfaceBase)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

// MARK: - Strain Gauge Card

private struct StrainGaugeCard: View {
    let strain: Double
    let source: String

    private var strainColor: Color {
        if strain >= 18 { return GQColors.coralRed }
        if strain >= 14 { return GQColors.sunsetOrange }
        if strain >= 10 { return GQColors.electricGold }
        if strain >= 6 { return GQColors.cyanSpark }
        return GQColors.success
    }

    private var strainLabel: String {
        if strain >= 18 { return "Overreaching" }
        if strain >= 14 { return "High" }
        if strain >= 10 { return "Moderate" }
        if strain >= 6 { return "Light" }
        return "Minimal"
    }

    var body: some View {
        VStack(spacing: 10) {
            // Gauge arc
            ZStack {
                // Background arc
                StrainArc(progress: 1.0)
                    .stroke(Color.white.opacity(0.06), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 64, height: 64)

                // Filled arc
                StrainArc(progress: strain / 21.0)
                    .stroke(strainColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 64, height: 64)

                VStack(spacing: 0) {
                    Text(String(format: "%.1f", strain))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text("/21")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)
                }
            }

            VStack(spacing: 2) {
                Text("Strain")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text(strainLabel)
                    .font(.system(size: 11))
                    .foregroundColor(strainColor)
            }

            Text(source)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Capsule().fill(GQColors.surfaceOverlay))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(GQColors.surfaceBase)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

// Custom arc shape for strain gauge
private struct StrainArc: Shape {
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

// MARK: - Sleep Breakdown Card

private struct SleepBreakdownCard: View {
    let totalHours: Double
    let stages: SleepStageBreakdown
    let efficiency: Double
    let whoopSleep: WhoopSleep?

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 12) {
            // Header
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "bed.double.fill")
                        .font(.system(size: 14))
                        .foregroundColor(GQColors.textSecondary)
                    Text("Sleep")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Text(totalHours > 0 ? String(format: "%.1fh", totalHours) : "--")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .buttonStyle(GQInteractiveStyle())

            // Stage bars (always visible)
            if totalHours > 0 {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        if stages.lightPercentage > 0 {
                            Rectangle()
                                .fill(GQColors.cyanSpark.opacity(0.6))
                                .frame(width: geo.size.width * stages.lightPercentage / 100)
                        }
                        if stages.deepPercentage > 0 {
                            Rectangle()
                                .fill(GQColors.deepBlue)
                                .frame(width: geo.size.width * stages.deepPercentage / 100)
                        }
                        if stages.remPercentage > 0 {
                            Rectangle()
                                .fill(GQColors.coralRed.opacity(0.72))
                                .frame(width: geo.size.width * stages.remPercentage / 100)
                        }
                    }
                    .clipShape(Capsule())
                }
                .frame(height: 6)
            }

            // Expanded detail
            if isExpanded && totalHours > 0 {
                VStack(spacing: 8) {
                    SleepStageRow(label: "Light", hours: stages.lightHours, pct: stages.lightPercentage, color: GQColors.cyanSpark.opacity(0.6))
                    SleepStageRow(label: "Deep", hours: stages.deepHours, pct: stages.deepPercentage, color: GQColors.deepBlue)
                    SleepStageRow(label: "REM", hours: stages.remHours, pct: stages.remPercentage, color: GQColors.coralRed.opacity(0.72))
                    SleepStageRow(label: "Awake", hours: stages.awakeHours, pct: 0, color: GQColors.textTertiary)

                    if efficiency > 0 {
                        HStack {
                            Text("Efficiency")
                                .font(.system(size: 12))
                                .foregroundColor(GQColors.textTertiary)
                            Spacer()
                            Text("\(Int(efficiency))%")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(efficiency >= 85 ? GQColors.success : GQColors.electricGold)
                        }
                    }

                    if let whoopSleep = whoopSleep, let score = whoopSleep.score {
                        if let perf = score.sleepPerformancePercentage {
                            HStack {
                                Text("Sleep Performance")
                                    .font(.system(size: 12))
                                    .foregroundColor(GQColors.textTertiary)
                                Spacer()
                                Text("\(Int(perf))%")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(perf >= 85 ? GQColors.success : GQColors.electricGold)
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(GQColors.surfaceBase)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

private struct SleepStageRow: View {
    let label: String
    let hours: Double
    let pct: Double
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(GQColors.textSecondary)
            Spacer()
            Text(String(format: "%.1fh", hours))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
            if pct > 0 {
                Text("(\(Int(pct))%)")
                    .font(.system(size: 11))
                    .foregroundColor(GQColors.textTertiary)
                    .frame(width: 40, alignment: .trailing)
            }
        }
    }
}

// MARK: - Vitals Grid Card

private struct VitalsGridCard: View {
    let rhr: Int
    let hrv: Double
    let spo2: Double
    let respRate: Double
    let vo2Max: Double
    let wristTemp: Double
    let whoopMonitor: WhoopHealthMonitor?

    @State private var isExpanded = false

    // Use WHOOP data if available, otherwise HealthKit
    private var displayRHR: Double {
        whoopMonitor?.restingHeartRate ?? Double(rhr)
    }
    private var displayHRV: Double {
        whoopMonitor?.hrvRmssd ?? hrv
    }
    private var displaySpO2: Double {
        whoopMonitor?.spo2Percentage ?? spo2
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 14))
                        .foregroundColor(GQColors.coralRed)
                    Text("Health Monitor")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .buttonStyle(GQInteractiveStyle())

            // Primary vitals (always visible)
            HStack(spacing: 0) {
                if displayRHR > 0 {
                    VitalItem(icon: "heart.fill", value: "\(Int(displayRHR))", unit: "bpm", label: "RHR", color: .red)
                }
                if displayHRV > 0 {
                    VitalItem(icon: "waveform.path.ecg", value: "\(Int(displayHRV))", unit: "ms", label: "HRV", color: GQColors.cyanSpark)
                }
                if displaySpO2 > 0 {
                    VitalItem(icon: "lungs.fill", value: "\(Int(displaySpO2))", unit: "%", label: "SpO2", color: GQColors.deepBlue)
                }
            }

            // Expanded vitals
            if isExpanded {
                VStack(spacing: 8) {
                    Divider().background(Color.white.opacity(0.06))

                    HStack(spacing: 0) {
                        if respRate > 0 {
                            VitalItem(icon: "wind", value: String(format: "%.1f", respRate), unit: "/min", label: "Resp", color: GQColors.success)
                        }
                        if vo2Max > 0 {
                            VitalItem(icon: "figure.run", value: String(format: "%.1f", vo2Max), unit: "ml", label: "VO2", color: GQColors.sunsetOrange)
                        }
                        if wristTemp != 0 {
                            let sign = wristTemp >= 0 ? "+" : ""
                            VitalItem(icon: "thermometer.medium", value: "\(sign)\(String(format: "%.1f", wristTemp))", unit: "°C", label: "Temp", color: GQColors.electricGold)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(GQColors.surfaceBase)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

private struct VitalItem: View {
    let icon: String
    let value: String
    let unit: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            HStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text(unit)
                    .font(.system(size: 10))
                    .foregroundColor(GQColors.textTertiary)
            }
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Strength Score Card

private struct StrengthScoreCard: View {
    let score: Double
    let workoutCount: Int

    private var scoreColor: Color {
        if score >= 80 { return GQColors.success }
        if score >= 60 { return GQColors.cyanSpark }
        if score >= 40 { return GQColors.electricGold }
        return GQColors.sunsetOrange
    }

    private var scoreLabel: String {
        if score >= 80 { return "Elite" }
        if score >= 60 { return "Advanced" }
        if score >= 40 { return "Intermediate" }
        if score >= 20 { return "Developing" }
        return "Beginner"
    }

    var body: some View {
        HStack(spacing: 16) {
            // Score ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 5)
                    .frame(width: 52, height: 52)
                Circle()
                    .trim(from: 0, to: score / 100)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(-90))
                Text("\(Int(score))")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Strength Score")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(scoreLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(scoreColor)
                Text("Based on \(workoutCount) workouts")
                    .font(.system(size: 11))
                    .foregroundColor(GQColors.textTertiary)
            }

            Spacer()

            Image(systemName: "dumbbell.fill")
                .font(.system(size: 20))
                .foregroundColor(scoreColor.opacity(0.4))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(GQColors.surfaceBase)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

// MARK: - Activity Summary Card (for Home view)

struct ActivitySummaryCard: View {
    @StateObject private var integration = IntegrationManager.shared
    @Environment(\.modelContext) private var modelContext
    @State private var recentWorkoutTypes: [WorkoutType] = []

    var body: some View {
        VStack(spacing: 12) {
            // Readiness indicator
            HStack(spacing: 10) {
                Image(systemName: integration.readinessLevel.icon)
                    .font(.system(size: 14))
                    .foregroundColor(integration.readinessLevel.color)
                Text(integration.readinessLevel.message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
                if integration.recoveryScore > 0 {
                    Text("\(Int(integration.recoveryScore))%")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(integration.readinessLevel.color)
                }
            }

            // Next workout suggestion
            nextWorkoutRow

            // Quick stats row
            if integration.hasAnyConnection {
                HStack(spacing: 0) {
                    if integration.healthKit.steps > 0 {
                        MiniStat(icon: "figure.walk", value: formatNumber(integration.healthKit.steps), label: "Steps")
                    }
                    if integration.healthKit.activeCalories > 0 {
                        MiniStat(icon: "flame.fill", value: "\(integration.healthKit.activeCalories)", label: "Cal")
                    }
                    if integration.healthKit.sleepHours > 0 {
                        MiniStat(icon: "bed.double.fill", value: String(format: "%.1f", integration.healthKit.sleepHours), label: "Sleep")
                    }
                    if integration.healthKit.exerciseMinutes > 0 {
                        MiniStat(icon: "timer", value: "\(integration.healthKit.exerciseMinutes)", label: "Min")
                    }
                }
            }
        }
        .padding(14)
        .homeSocialCard(accent: integration.readinessLevel.color, cornerRadius: 14, sweepDelay: 3.5)
        .onAppear { loadRecentWorkoutTypes() }
    }

    @ViewBuilder
    private var nextWorkoutRow: some View {
        let suggestion = suggestNextWorkout(from: recentWorkoutTypes)
        HStack(spacing: 8) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 12))
                .foregroundColor(GQColors.vividPurple)
            Text("Next up: ")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            + Text(suggestion.rawValue)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(GQColors.vividPurple)
            Spacer()
        }
    }

    private func loadRecentWorkoutTypes() {
        var descriptor = FetchDescriptor<Workout>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 3
        guard let workouts = try? modelContext.fetch(descriptor) else { return }
        recentWorkoutTypes = workouts
            .filter { $0.type != .rest }
            .map(\.type)
    }

    private func suggestNextWorkout(from recentTypes: [WorkoutType]) -> WorkoutType {
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

    private func formatNumber(_ n: Int) -> String {
        if n >= 1000 {
            return String(format: "%.1fk", Double(n) / 1000)
        }
        return "\(n)"
    }
}

private struct MiniStat: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(GQColors.textTertiary)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ScrollView {
        HealthDashboardView(
            profile: UserProfile(name: "Ben", username: "ben"),
            workouts: []
        )
        .padding(.horizontal, 16)
    }
    .gqPageBackground()
    .preferredColorScheme(.dark)
}
