//
//  WatchHistoryView.swift
//  GymQuestWatch
//
//  Local workout history stored on the watch.
//

import SwiftUI

struct WatchHistoryView: View {
    @State private var history: [WatchCompletedWorkout] = []

    var body: some View {
        Group {
            if history.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title2)
                        .foregroundStyle(WatchColors.textSecondary)
                    Text("No workouts yet")
                        .font(.caption)
                        .foregroundStyle(WatchColors.textSecondary)
                }
            } else {
                List {
                    ForEach(history) { workout in
                        NavigationLink(destination: historyDetail(workout)) {
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(workout.type)
                                        .font(.caption.bold())
                                    Text(workout.date.formatted(.dateTime.month(.abbreviated).day()))
                                        .font(.system(size: 10))
                                        .foregroundStyle(WatchColors.textSecondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(formatDuration(workout.durationSeconds))
                                        .font(.caption2.monospacedDigit())
                                    Text(formatVolume(workout.totalVolume))
                                        .font(.system(size: 10))
                                        .foregroundStyle(WatchColors.vividPurple)
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        WorkoutHistory.delete(at: offsets)
                        history = WorkoutHistory.load()
                    }
                }
            }
        }
        .navigationTitle("History")
        .onAppear { history = WorkoutHistory.load() }
    }

    @ViewBuilder
    private func historyDetail(_ workout: WatchCompletedWorkout) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(workout.type)
                        .font(.headline)
                    Spacer()
                    Text(formatDuration(workout.durationSeconds))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(WatchColors.textSecondary)
                }

                Text(workout.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.caption2)
                    .foregroundStyle(WatchColors.textSecondary)

                Divider().overlay(WatchColors.surface)

                ForEach(workout.exercises) { exercise in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(exercise.name)
                            .font(.caption.bold())
                            .foregroundStyle(WatchColors.vividPurple)

                        ForEach(exercise.sets.indices, id: \.self) { i in
                            let set = exercise.sets[i]
                            HStack {
                                Text("Set \(i + 1)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(WatchColors.textSecondary)
                                Spacer()
                                if set.weight > 0 {
                                    Text("\(Int(set.weight)) lbs x \(set.reps)")
                                        .font(.system(size: 10, design: .monospaced))
                                } else {
                                    Text("\(set.reps) reps")
                                        .font(.system(size: 10, design: .monospaced))
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }

                HStack {
                    Text("Total Volume")
                        .font(.caption2)
                        .foregroundStyle(WatchColors.textSecondary)
                    Spacer()
                    Text(formatVolume(workout.totalVolume))
                        .font(.caption.bold())
                        .foregroundStyle(WatchGradients.primary)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, WatchLayout.horizontalPadding)
        }
        .navigationTitle("Detail")
    }
}
