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
                        .font(.system(size: 24))
                        .foregroundStyle(WatchColors.textTertiary)
                    Text("No workouts yet")
                        .font(.system(size: 13))
                        .foregroundStyle(WatchColors.textTertiary)
                }
            } else {
                List {
                    ForEach(history) { workout in
                        NavigationLink(destination: historyDetail(workout)) {
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(workout.type)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.white)
                                    Text(workout.date.formatted(.dateTime.month(.abbreviated).day()))
                                        .font(.system(size: 10))
                                        .foregroundStyle(WatchColors.textTertiary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(formatDuration(workout.durationSeconds))
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        .foregroundStyle(WatchColors.textSecondary)
                                    Text(formatVolume(workout.totalVolume))
                                        .font(.system(size: 10))
                                        .foregroundStyle(WatchColors.textTertiary)
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
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(formatDuration(workout.durationSeconds))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(WatchColors.textSecondary)
                }

                Text(workout.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.system(size: 11))
                    .foregroundStyle(WatchColors.textTertiary)

                Rectangle()
                    .fill(WatchColors.border)
                    .frame(height: 0.5)

                ForEach(workout.exercises) { exercise in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(exercise.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)

                        ForEach(exercise.sets.indices, id: \.self) { i in
                            let set = exercise.sets[i]
                            HStack {
                                Text("Set \(i + 1)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(WatchColors.textTertiary)
                                Spacer()
                                if set.weight > 0 {
                                    Text("\(Int(set.weight)) lbs x \(set.reps)")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(WatchColors.textSecondary)
                                } else {
                                    Text("\(set.reps) reps")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(WatchColors.textSecondary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }

                HStack {
                    Text("Total Volume")
                        .font(.system(size: 11))
                        .foregroundStyle(WatchColors.textTertiary)
                    Spacer()
                    Text(formatVolume(workout.totalVolume))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, WatchLayout.horizontalPadding)
        }
        .navigationTitle("Detail")
    }
}
