//
//  WatchSummaryView.swift
//  GymQuestWatch
//
//  Post-workout summary.
//

import SwiftUI

struct WatchSummaryView: View {
    let workout: WatchCompletedWorkout

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(WatchColors.success)

                Text("Complete")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)

                Text(workout.type)
                    .font(.system(size: 12))
                    .foregroundStyle(WatchColors.textTertiary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    summaryMetric(
                        value: formatDuration(workout.durationSeconds),
                        label: "Duration"
                    )
                    summaryMetric(
                        value: "\(workout.exercises.count)",
                        label: "Exercises"
                    )
                    summaryMetric(
                        value: "\(workout.totalSets)",
                        label: "Sets"
                    )
                    summaryMetric(
                        value: formatVolume(workout.totalVolume),
                        label: "Volume"
                    )
                }

                if workout.prsAchieved > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(WatchColors.gold)
                        Text("\(workout.prsAchieved) PRs")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(WatchColors.gold)
                    }
                }
            }
            .padding(.horizontal, WatchLayout.horizontalPadding)
        }
    }

    @ViewBuilder
    private func summaryMetric(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(WatchColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .watchGlass()
    }
}
