//
//  ShareService.swift
//  GymQuest
//
//  Handles workout card export and sharing for GymQuest 2.0.
//  Supports image export, share sheet, and consistent brand templates.
//

import Foundation
import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

@MainActor
class ShareService: ObservableObject {
    static let shared = ShareService()

    @Published var isExporting = false
    @Published var lastExportedImage: UIImage?

    // MARK: - Workout Card Export

    /// Export a workout card as a shareable image
    @MainActor
    func exportWorkoutCard(
        workout: Workout,
        profile: UserProfile,
        summary: WorkoutSummary,
        prMoments: [PRMoment],
        coachTakeaway: String?
    ) -> UIImage? {
        isExporting = true
        defer { isExporting = false }

        let cardView = ShareableWorkoutCardV2(
            workout: workout,
            profile: profile,
            summary: summary,
            prMoments: prMoments,
            coachTakeaway: coachTakeaway
        )

        let renderer = ImageRenderer(content: cardView.frame(width: 390))
        renderer.scale = 3.0

        if let image = renderer.uiImage {
            lastExportedImage = image
            trackEvent(.shareExported, metadata: ["type": "workout_card"])
            return image
        }

        return nil
    }

    /// Export a PR celebration card
    @MainActor
    func exportPRCard(
        prMoment: PRMoment,
        workout: Workout,
        profile: UserProfile
    ) -> UIImage? {
        isExporting = true
        defer { isExporting = false }

        let cardView = ShareablePRCard(
            prMoment: prMoment,
            workout: workout,
            profile: profile
        )

        let renderer = ImageRenderer(content: cardView.frame(width: 390))
        renderer.scale = 3.0

        if let image = renderer.uiImage {
            lastExportedImage = image
            trackEvent(.shareExported, metadata: ["type": "pr_card"])
            return image
        }

        return nil
    }

    /// Export a weekly recap card
    @MainActor
    func exportWeeklyRecap(
        recap: WeeklyRecap,
        profile: UserProfile
    ) -> UIImage? {
        isExporting = true
        defer { isExporting = false }

        let cardView = ShareableWeeklyRecapCard(
            recap: recap,
            profile: profile
        )

        let renderer = ImageRenderer(content: cardView.frame(width: 390))
        renderer.scale = 3.0

        if let image = renderer.uiImage {
            lastExportedImage = image
            trackEvent(.shareExported, metadata: ["type": "weekly_recap"])
            return image
        }

        return nil
    }

    // MARK: - Share Sheet

    #if canImport(UIKit)
    /// Present the iOS share sheet with an image
    func shareImage(_ image: UIImage, from viewController: UIViewController? = nil) {
        let activityVC = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )

        if let vc = viewController ?? UIApplication.shared.topViewController {
            // For iPad
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = vc.view
                popover.sourceRect = CGRect(x: vc.view.bounds.midX, y: vc.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }

            vc.present(activityVC, animated: true)
        }
    }
    #endif

    // MARK: - Analytics

    private func trackEvent(_ eventType: AnalyticsEventType, metadata: [String: Any]? = nil) {
        // Track event locally - would be expanded for real analytics
        let metadataString = metadata.flatMap { dict in
            try? JSONSerialization.data(withJSONObject: dict)
        }.flatMap { String(data: $0, encoding: .utf8) }

        // Note: In a real app, this would save to AnalyticsEvent model
        print("ShareService: \(eventType.rawValue) - \(metadataString ?? "")")
    }
}

// MARK: - Shareable Card Views

/// Enhanced shareable workout card with GymQuest 2.0 styling
struct ShareableWorkoutCardV2: View {
    let workout: Workout
    let profile: UserProfile
    let summary: WorkoutSummary
    let prMoments: [PRMoment]
    let coachTakeaway: String?

    var body: some View {
        VStack(spacing: 0) {
            // Brand header
            HStack {
                Text("GYMQUEST")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(3)

                Spacer()

                if summary.streak >= 3 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                        Text("\(summary.streak)")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Main card content
            VStack(spacing: 0) {
                // Header with user info
                CardHeaderV2(
                    workout: workout,
                    profile: profile,
                    summary: summary
                )

                // PR callouts
                if !prMoments.isEmpty {
                    PRCalloutV2(prMoments: prMoments)
                }

                // Top set highlight
                if let topSet = summary.topSet {
                    TopSetHighlight(topSet: topSet)
                }

                // Exercise list
                ExerciseListV2(workout: workout)

                // Coach insight
                if let takeaway = coachTakeaway, !takeaway.isEmpty {
                    CoachInsightSection(takeaway: takeaway)
                }

                // Stats footer
                StatsFooter(summary: summary)
            }
            .background(Color(white: 0.08))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: prMoments.isEmpty ? [.white.opacity(0.1)] : [.yellow.opacity(0.3), .orange.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .padding(.horizontal, 16)

            // Footer branding
            HStack {
                Spacer()
                Text("Track your gains")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))
                Spacer()
            }
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .background(Color.black)
    }
}

struct CardHeaderV2: View {
    let workout: Workout
    let profile: UserProfile
    let summary: WorkoutSummary

    var body: some View {
        HStack(spacing: 14) {
            // Workout type badge
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)

                Image(systemName: workout.type.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("@\(profile.username)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)

                    Text("·")
                        .foregroundColor(.gray)

                    Text(workout.type.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }

                Text("\(workout.date.formatted(date: .abbreviated, time: .omitted)) · \(workout.duration) min")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }

            Spacer()

            // XP badge
            VStack(alignment: .trailing, spacing: 2) {
                Text("+\(summary.xpEarned)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.green)
                Text("XP")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.green.opacity(0.7))
            }
        }
        .padding(18)
    }
}

struct PRCalloutV2: View {
    let prMoments: [PRMoment]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(prMoments.prefix(2)) { pr in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.yellow.opacity(0.2))
                            .frame(width: 36, height: 36)

                        Image(systemName: "trophy.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.yellow)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("NEW \(pr.prType.rawValue.uppercased())")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.yellow)

                        HStack(spacing: 6) {
                            if let exercise = pr.exerciseName {
                                Text(exercise)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                            }

                            Text(pr.value)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }

                    Spacer()

                    if let improvement = pr.improvement {
                        Text(improvement)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.green)
                    }
                }
                .padding(14)
                .background(
                    LinearGradient(
                        colors: [.yellow.opacity(0.15), .orange.opacity(0.08)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
    }
}

struct TopSetHighlight: View {
    let topSet: TopSetSummary

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("TOP SET")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.cyan.opacity(0.8))

                Text(topSet.displayString)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }

            Spacer()

            if let e1rm = topSet.estimated1RM {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("e1RM")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                    Text("\(Int(e1rm)) lbs")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding(12)
        .background(Color.cyan.opacity(0.08))
        .cornerRadius(10)
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
    }
}

struct ExerciseListV2: View {
    let workout: Workout
    let maxExercises = 5

    var sortedExercises: [Exercise] {
        workout.exercises.sorted { $0.order < $1.order }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(sortedExercises.prefix(maxExercises)) { exercise in
                HStack {
                    Text(exercise.name)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.85))

                    Spacer()

                    Text(exerciseDisplay(exercise))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            if sortedExercises.count > maxExercises {
                Text("+\(sortedExercises.count - maxExercises) more")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
    }

    func exerciseDisplay(_ exercise: Exercise) -> String {
        let sets = exercise.sets.sorted { $0.order < $1.order }
        guard !sets.isEmpty else { return "" }

        let avgReps = sets.map { $0.reps }.reduce(0, +) / sets.count
        let maxWeight = sets.map { $0.weight }.max() ?? 0

        if maxWeight > 0 {
            return "\(sets.count)×\(avgReps) @ \(Int(maxWeight))"
        }
        return "\(sets.count)×\(avgReps)"
    }
}

struct CoachInsightSection: View {
    let takeaway: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 14))
                .foregroundColor(.purple)
                .frame(width: 20)

            Text(takeaway)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.8))
                .lineSpacing(2)

            Spacer()
        }
        .padding(12)
        .background(Color.purple.opacity(0.08))
        .cornerRadius(10)
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
    }
}

struct StatsFooter: View {
    let summary: WorkoutSummary

    var body: some View {
        HStack(spacing: 20) {
            ShareStatItem(value: "\(summary.totalSets)", label: "sets")
            ShareStatItem(value: summary.formattedVolume, label: "volume")
            ShareStatItem(value: "\(summary.duration)", label: "min")

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.03))
    }
}

struct ShareStatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
    }
}

// MARK: - PR Card

struct ShareablePRCard: View {
    let prMoment: PRMoment
    let workout: Workout
    let profile: UserProfile

    var body: some View {
        VStack(spacing: 0) {
            // Brand header
            HStack {
                Text("GYMQUEST")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(3)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // PR celebration
            VStack(spacing: 16) {
                // Trophy icon
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.yellow, .orange],
                                center: .center,
                                startRadius: 0,
                                endRadius: 60
                            )
                        )
                        .frame(width: 80, height: 80)

                    Image(systemName: "trophy.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                }

                Text("NEW PR!")
                    .font(.system(size: 24, weight: .black))
                    .foregroundColor(.yellow)

                if let exercise = prMoment.exerciseName {
                    Text(exercise)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }

                Text(prMoment.value)
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundColor(.white)

                if let improvement = prMoment.improvement {
                    Text(improvement)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.green)
                }

                // User info
                HStack(spacing: 8) {
                    Text("@\(profile.username)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))

                    Text("·")
                        .foregroundColor(.gray)

                    Text(workout.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .padding(.top, 8)
            }
            .padding(30)
            .background(
                LinearGradient(
                    colors: [Color(white: 0.12), Color(white: 0.06)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.yellow.opacity(0.5), .orange.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color.black)
    }
}

// MARK: - Weekly Recap Card

struct ShareableWeeklyRecapCard: View {
    let recap: WeeklyRecap
    let profile: UserProfile

    var body: some View {
        VStack(spacing: 0) {
            // Brand header
            HStack {
                Text("GYMQUEST")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(3)
                Spacer()
                Text("WEEKLY RECAP")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(1)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Recap content
            VStack(spacing: 20) {
                // Week header
                Text(weekRangeText)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)

                // Main stats
                HStack(spacing: 24) {
                    RecapStat(value: "\(recap.workoutCount)", label: "workouts")
                    RecapStat(value: "\(recap.totalSets)", label: "sets")
                    RecapStat(value: formatVolume(recap.totalVolume), label: "volume")
                }

                Divider()
                    .background(Color.white.opacity(0.1))

                // Highlights
                VStack(spacing: 12) {
                    if let topExercise = recap.topExercise {
                        HStack {
                            Text("Top Exercise")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            Spacer()
                            Text(topExercise)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }

                    if recap.prCount > 0 {
                        HStack {
                            Text("PRs Hit")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.yellow)
                                Text("\(recap.prCount)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.yellow)
                            }
                        }
                    }

                    HStack {
                        Text("XP Earned")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("+\(recap.xpEarned)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.green)
                    }

                    if recap.streakDays >= 3 {
                        HStack {
                            Text("Streak")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.orange)
                                Text("\(recap.streakDays) days")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }

                // Insight
                if let insight = recap.insightText, !insight.isEmpty {
                    Text(insight)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }

                // User
                Text("@\(profile.username)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.top, 8)
            }
            .padding(24)
            .background(Color(white: 0.08))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color.black)
    }

    var weekRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: recap.weekStart)) - \(formatter.string(from: recap.weekEnd))"
    }

    func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk", volume / 1000)
        }
        return "\(Int(volume))"
    }
}

struct RecapStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.gray)
        }
    }
}

// MARK: - UIApplication Extension

#if canImport(UIKit)
extension UIApplication {
    var topViewController: UIViewController? {
        guard let windowScene = connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return nil
        }

        var topController = window.rootViewController
        while let presented = topController?.presentedViewController {
            topController = presented
        }
        return topController
    }
}
#endif
