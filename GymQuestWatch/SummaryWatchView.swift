//
//  SummaryWatchView.swift
//  GymQuestWatch
//
//  Post-workout summary displayed after ending a workout.
//

import SwiftUI

struct SummaryWatchView: View {
    let duration: Int // seconds
    let exerciseCount: Int
    let totalSets: Int
    let workoutType: String

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.green)

                Text("Workout Complete!")
                    .font(.headline)

                Text(workoutType)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()

                HStack(spacing: 20) {
                    summaryMetric(value: durationString, label: "Duration")
                    summaryMetric(value: "\(exerciseCount)", label: "Exercises")
                    summaryMetric(value: "\(totalSets)", label: "Sets")
                }
            }
            .padding(.horizontal, 4)
        }
    }

    @ViewBuilder
    private func summaryMetric(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.body.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var durationString: String {
        let minutes = duration / 60
        return "\(minutes)m"
    }
}
