//
//  IntegrationManager.swift
//  GymQuest
//
//  Unified integration layer that coordinates Apple Health, WHOOP, Strava,
//  and computes derived metrics like Strength Score and Recovery.
//

import Foundation
import SwiftUI
import SwiftData

@MainActor
class IntegrationManager: ObservableObject {
    static let shared = IntegrationManager()

    @Published var healthKit = HealthKitService.shared
    @Published var whoop = WhoopService.shared
    @Published var strava = StravaService.shared

    // MARK: - Unified Metrics (merged from all sources)

    @Published var recoveryScore: Double = 0         // 0-100, from WHOOP or computed
    @Published var strainScore: Double = 0            // 0-21 scale (WHOOP-style)
    @Published var strengthScore: Double = 0          // 0-100 (Gravl-inspired)
    @Published var readinessLevel: ReadinessLevel = .good

    // Data sources that are currently active
    var activeSourceCount: Int {
        var count = 0
        if healthKit.isAuthorized { count += 1 }
        if whoop.isConnected { count += 1 }
        if strava.isConnected { count += 1 }
        return count
    }

    var hasAnyConnection: Bool {
        activeSourceCount > 0
    }

    // MARK: - Sync All

    func syncAll(userId: UUID) async {
        // Fetch HealthKit data
        if healthKit.isAuthorized {
            healthKit.fetchTodayData()
            await healthKit.syncWorkouts(userId: userId)
        }

        // Fetch WHOOP data
        if whoop.isConnected {
            await whoop.fetchAllData()
        }

        // Fetch Strava data
        if strava.isConnected {
            await strava.syncActivities(userId: userId)
        }

        // Compute unified metrics
        computeUnifiedMetrics()
    }

    // MARK: - Compute Unified Metrics

    func computeUnifiedMetrics() {
        computeRecoveryScore()
        computeStrainScore()
    }

    private func computeRecoveryScore() {
        // Priority: WHOOP recovery > computed from HealthKit
        if let whoopRecovery = whoop.latestRecovery {
            recoveryScore = whoopRecovery.score.recoveryScore
        } else if healthKit.isAuthorized {
            // Compute a recovery estimate from HealthKit vitals
            var score: Double = 50 // baseline

            // HRV contribution (higher HRV = better recovery)
            if healthKit.hrvMs > 0 {
                if healthKit.hrvMs >= 60 { score += 20 }
                else if healthKit.hrvMs >= 40 { score += 10 }
                else if healthKit.hrvMs < 30 { score -= 10 }
            }

            // RHR contribution (lower RHR = better recovery)
            if healthKit.restingHeartRate > 0 {
                if healthKit.restingHeartRate < 55 { score += 15 }
                else if healthKit.restingHeartRate < 65 { score += 5 }
                else if healthKit.restingHeartRate > 75 { score -= 10 }
            }

            // Sleep contribution
            if healthKit.sleepHours >= 7.5 { score += 15 }
            else if healthKit.sleepHours >= 6.5 { score += 5 }
            else if healthKit.sleepHours < 5 { score -= 15 }

            recoveryScore = min(100, max(0, score))
        }

        // Update readiness
        if recoveryScore >= 67 {
            readinessLevel = .optimal
        } else if recoveryScore >= 50 {
            readinessLevel = .good
        } else if recoveryScore >= 34 {
            readinessLevel = .moderate
        } else {
            readinessLevel = .low
        }
    }

    private func computeStrainScore() {
        // Priority: WHOOP strain > computed
        if let whoopStrain = whoop.latestStrain, let score = whoopStrain.score {
            strainScore = score.strain
        } else if healthKit.isAuthorized {
            // Estimate from activity data (scaled 0-21)
            let calorieStrain = min(10, Double(healthKit.activeCalories) / 100)
            let exerciseStrain = min(8, Double(healthKit.exerciseMinutes) / 10)
            let stepStrain = min(3, Double(healthKit.steps) / 5000)
            strainScore = min(21, calorieStrain + exerciseStrain + stepStrain)
        }
    }

    // MARK: - Strength Score (Gravl-inspired)

    func computeStrengthScore(workouts: [Workout]) {
        guard !workouts.isEmpty else {
            strengthScore = 0
            return
        }

        // Collect all exercises across recent workouts (last 30 days)
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recentWorkouts = workouts.filter { $0.date >= thirtyDaysAgo }

        guard !recentWorkouts.isEmpty else {
            strengthScore = 0
            return
        }

        // Calculate estimated 1RMs for key compound lifts
        var maxE1RMs: [String: Double] = [:]

        for workout in recentWorkouts {
            for exercise in workout.exercises {
                for set in exercise.sets where set.weight > 0 && set.reps > 0 {
                    let e1rm = set.estimated1RM ?? (set.weight * (1 + Double(set.reps) / 30))
                    let existing = maxE1RMs[exercise.name] ?? 0
                    maxE1RMs[exercise.name] = max(existing, e1rm)
                }
            }
        }

        guard !maxE1RMs.isEmpty else {
            strengthScore = 0
            return
        }

        // Score based on:
        // 1. Number of exercises tracked (variety)
        // 2. Average e1RM relative to bodyweight (if available)
        // 3. Total volume trend
        // 4. PR momentum

        let varietyScore = min(25, Double(maxE1RMs.count) * 2.5)  // up to 25 pts for 10+ exercises

        let avgE1RM = maxE1RMs.values.reduce(0, +) / Double(maxE1RMs.count)
        let bodyWeight = healthKit.bodyWeight > 0 ? healthKit.bodyWeight * 2.205 : 170  // convert kg to lbs, default 170
        let relativeStrength = min(25, (avgE1RM / bodyWeight) * 25)  // up to 25 pts

        let totalVolume = recentWorkouts.reduce(0.0) { $0 + $1.totalVolume }
        let volumeScore = min(25, totalVolume / 10000 * 25)  // up to 25 pts

        let consistency = min(25, Double(recentWorkouts.count) / 12 * 25)  // up to 25 pts for 12 sessions/month

        strengthScore = min(100, varietyScore + relativeStrength + volumeScore + consistency)
    }
}

// MARK: - Readiness Level

enum ReadinessLevel: String, CaseIterable {
    case optimal = "Optimal"
    case good = "Good"
    case moderate = "Moderate"
    case low = "Low"

    var color: Color {
        switch self {
        case .optimal: return GQColors.success
        case .good: return GQColors.textSecondary
        case .moderate: return GQColors.textSecondary
        case .low: return GQColors.textSecondary
        }
    }

    var icon: String {
        switch self {
        case .optimal: return "bolt.fill"
        case .good: return "checkmark.circle.fill"
        case .moderate: return "minus.circle.fill"
        case .low: return "exclamationmark.triangle.fill"
        }
    }

    var message: String {
        switch self {
        case .optimal: return "Fully recovered — go all out"
        case .good: return "Ready for a solid session"
        case .moderate: return "Consider a lighter workout"
        case .low: return "Low recovery — take it easy"
        }
    }
}
