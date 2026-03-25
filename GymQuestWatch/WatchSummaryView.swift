//
//  WatchSummaryView.swift
//  GymQuestWatch
//
//  Post-workout summary displayed after ending a workout.
//

import SwiftUI

struct WatchSummaryView: View {
    let workout: WatchCompletedWorkout

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(WatchGradients.primary)

                Text("Complete!")
                    .font(.headline)

                Text(workout.type)
                    .font(.caption)
                    .foregroundStyle(WatchColors.textSecondary)

                Divider()
                    .overlay(WatchColors.surface)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    summaryMetric(
                        value: formatDuration(workout.durationSeconds),
                        label: "Duration",
                        icon: "clock"
                    )
                    summaryMetric(
                        value: "\(workout.exercises.count)",
                        label: "Exercises",
                        icon: "figure.strengthtraining.traditional"
                    )
                    summaryMetric(
                        value: "\(workout.totalSets)",
                        label: "Sets",
                        icon: "checkmark.circle"
                    )
                    summaryMetric(
                        value: formatVolume(workout.totalVolume),
                        label: "Volume",
                        icon: "scalemass"
                    )
                }

                if workout.prsAchieved > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(WatchColors.gold)
                        Text("\(workout.prsAchieved) PRs")
                            .font(.caption.bold())
                            .foregroundStyle(WatchColors.gold)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, WatchLayout.horizontalPadding)
        }
    }

    @ViewBuilder
    private func summaryMetric(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(WatchColors.vividPurple)
            Text(value)
                .font(.caption.bold().monospacedDigit())
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(WatchColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(WatchColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
