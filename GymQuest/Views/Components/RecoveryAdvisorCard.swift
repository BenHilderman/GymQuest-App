//
//  RecoveryAdvisorCard.swift
//  GymQuest
//
//  Recovery advisor card that displays readiness based on Whoop/HealthKit data.
//  Shows recovery score, recommendation, HRV, and sleep stats.
//

import SwiftUI

struct RecoveryAdvisorCard: View {
    let recoveryScore: Double?
    let hrvMs: Double?
    let sleepHours: Double?
    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: zoneIcon)
                    .font(.title3)
                    .foregroundColor(zoneColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Recovery Advisor")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(GQColors.textPrimary)

                    Text(sourceLabel)
                        .font(.caption2)
                        .foregroundColor(GQColors.textSecondary)
                }

                Spacer()

                if let score = recoveryScore {
                    Text("\(Int(score))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(zoneColor)
                }
            }

            // Recommendation text
            Text(recommendation)
                .font(.subheadline)
                .foregroundColor(GQColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            // Secondary stats
            if hrvMs != nil || sleepHours != nil {
                HStack(spacing: 16) {
                    if let hrv = hrvMs {
                        Label("\(Int(hrv))ms HRV", systemImage: "heart.text.square")
                            .font(.caption)
                            .foregroundColor(GQColors.textSecondary)
                    }
                    if let sleep = sleepHours {
                        Label(String(format: "%.1fh sleep", sleep), systemImage: "moon.fill")
                            .font(.caption)
                            .foregroundColor(GQColors.textSecondary)
                    }
                }
            }

            // Zone indicator bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(GQColors.borderDefault)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(zoneColor)
                        .frame(width: geo.size.width * (recoveryScore ?? 50) / 100, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding()
        .background(GQColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(GQColors.borderDefault, lineWidth: 1)
        )
    }

    // MARK: - Computed Properties

    private var zoneColor: Color {
        guard let score = recoveryScore else { return GQColors.textSecondary }
        if score >= 67 { return GQColors.success }
        if score >= 34 { return GQColors.electricGold }
        return GQColors.coralRed
    }

    private var zoneIcon: String {
        guard let score = recoveryScore else { return "questionmark.circle" }
        if score >= 67 { return "bolt.fill" }
        if score >= 34 { return "minus.circle.fill" }
        return "bed.double.fill"
    }

    private var recommendation: String {
        guard let score = recoveryScore else {
            return "No recovery data available. Connect Whoop or enable HealthKit for personalized recommendations."
        }
        if score >= 67 {
            return "Push Hard — You're fully recovered. Great day for heavy compounds or PR attempts."
        }
        if score >= 34 {
            return "Maintain — Moderate recovery. Stick to your plan but don't chase PRs today."
        }
        return "Take It Easy — Low recovery. Consider a deload session, mobility work, or active recovery."
    }

    private var sourceLabel: String {
        switch source {
        case "whoop": return "via WHOOP"
        case "healthkit": return "via Apple Health"
        default: return "No Data Source"
        }
    }

    // MARK: - Builder

    /// Build recovery data from available services
    @MainActor
    static func buildRecommendation(
        whoopService: WhoopService?,
        healthKitService: HealthKitService?
    ) -> (score: Double?, hrv: Double?, sleep: Double?, source: String) {
        // Priority: Whoop > HealthKit > no data
        if let whoop = whoopService, whoop.isConnected,
           let recovery = whoop.latestRecovery {
            let sleep = whoop.latestSleep
            let sleepHours = sleep?.score?.stageSummary.totalSleepHours
            return (
                score: recovery.score.recoveryScore,
                hrv: recovery.score.hrvRmssdMilli,
                sleep: sleepHours,
                source: "whoop"
            )
        }

        if let hk = healthKitService, hk.isAuthorized {
            // HealthKit doesn't have a native "recovery score" — estimate from HRV
            let hrv = hk.hrvMs > 0 ? hk.hrvMs : nil
            let sleep = hk.sleepHours > 0 ? hk.sleepHours : nil
            // Simple recovery estimate: HRV-based if available
            var score: Double? = nil
            if let hrv = hrv {
                // Rough estimate: 50ms HRV = ~50% recovery, scales linearly
                score = min(100, max(0, hrv * 1.0))
            }
            return (
                score: score,
                hrv: hrv,
                sleep: sleep,
                source: "healthkit"
            )
        }

        return (score: nil, hrv: nil, sleep: nil, source: "none")
    }
}
