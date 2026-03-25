//
//  WatchHomeView.swift
//  GymQuestWatch
//

import SwiftUI

struct WatchHomeView: View {
    @Environment(WatchConnectivityManager.self) var connectivity
    @State private var workoutHistory: [WatchCompletedWorkout] = []
    @State private var activeWorkout: ActiveWorkoutState?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                quickStartGrid

                if !workoutHistory.isEmpty {
                    recentSection
                }
            }
        }
        .navigationTitle("Lift AI")
        .onAppear { workoutHistory = WorkoutHistory.load() }
        .fullScreenCover(item: $activeWorkout) { state in
            WatchActiveWorkoutView(
                workoutType: state.type,
                exercises: state.exercises,
                onFinish: { _ in
                    activeWorkout = nil
                    workoutHistory = WorkoutHistory.load()
                }
            )
            .environment(connectivity)
        }
    }

    private var quickStartGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(WorkoutTypeInfo.all) { type in
                Button {
                    let exercises = buildExercises(for: type.id)
                    activeWorkout = ActiveWorkoutState(type: type.name, exercises: exercises)
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: type.icon)
                            .font(.system(size: 22, weight: .light, design: .rounded))
                            .foregroundStyle(WatchGradients.primary)
                        Text(type.name)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(WatchColors.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(WatchColors.border, lineWidth: 0.5)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 2)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            NavigationLink(destination: WatchHistoryView()) {
                HStack {
                    Text("Recent")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(WatchColors.textSecondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(WatchColors.textTertiary)
                }
            }
            .buttonStyle(.plain)

            ForEach(workoutHistory.prefix(3)) { workout in
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(WatchGradients.primary)
                        .frame(width: 3, height: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(workout.type)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                        Text(workout.date.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(WatchColors.textTertiary)
                    }
                    Spacer()
                    Text(formatDuration(workout.durationSeconds))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(WatchColors.textTertiary)
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

struct ActiveWorkoutState: Identifiable {
    let id = UUID()
    let type: String
    let exercises: [WatchActiveExercise]
}
