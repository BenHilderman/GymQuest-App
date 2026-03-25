//
//  WatchHomeView.swift
//  GymQuestWatch
//
//  Home screen with workout type selection and recent history.
//

import SwiftUI

struct WatchHomeView: View {
    @Environment(WatchConnectivityManager.self) var connectivity
    @State private var workoutHistory: [WatchCompletedWorkout] = []
    @State private var activeWorkout: ActiveWorkoutState?

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                quickStartGrid

                if !workoutHistory.isEmpty {
                    recentSection
                }
            }
            .padding(.horizontal, 2)
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

    // MARK: - Quick Start Grid

    private var quickStartGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(WorkoutTypeInfo.all) { type in
                Button {
                    let exercises = buildExercises(for: type.id)
                    activeWorkout = ActiveWorkoutState(type: type.name, exercises: exercises)
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: type.icon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(WatchGradients.primary)
                        Text(type.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(WatchColors.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .watchGlass()
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Recent Workouts

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            NavigationLink(destination: WatchHistoryView()) {
                HStack {
                    Text("Recent")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(WatchColors.textSecondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9))
                        .foregroundStyle(WatchColors.textTertiary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)

            ForEach(workoutHistory.prefix(3)) { workout in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(WatchGradients.primary)
                        .frame(width: 3, height: 24)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(workout.type)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(WatchColors.textPrimary)
                        Text(workout.date.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.system(size: 10))
                            .foregroundStyle(WatchColors.textTertiary)
                    }
                    Spacer()
                    Text(formatDuration(workout.durationSeconds))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(WatchColors.textSecondary)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Active Workout State

struct ActiveWorkoutState: Identifiable {
    let id = UUID()
    let type: String
    let exercises: [WatchActiveExercise]
}
