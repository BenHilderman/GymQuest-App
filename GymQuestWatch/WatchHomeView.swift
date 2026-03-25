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
            VStack(spacing: WatchLayout.spacingMedium) {
                header
                quickStartGrid
                if !workoutHistory.isEmpty {
                    recentSection
                }
            }
            .padding(.horizontal, WatchLayout.horizontalPadding)
        }
        .navigationTitle("Lift AI")
        .onAppear { workoutHistory = WorkoutHistory.load() }
        .fullScreenCover(item: $activeWorkout) { state in
            WatchActiveWorkoutView(
                workoutType: state.type,
                exercises: state.exercises,
                onFinish: { completed in
                    activeWorkout = nil
                    if let completed {
                        workoutHistory = WorkoutHistory.load()
                    }
                }
            )
            .environment(connectivity)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            if connectivity.streak > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text("\(connectivity.streak)d")
                        .font(.caption2.bold())
                        .foregroundStyle(WatchColors.textSecondary)
                }
            }
            Spacer()
        }
    }

    // MARK: - Quick Start Grid

    private var quickStartGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(WorkoutTypeInfo.all) { type in
                Button {
                    let exercises = buildExercises(for: type.id)
                    activeWorkout = ActiveWorkoutState(type: type.name, exercises: exercises)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: type.icon)
                            .font(.title3)
                            .foregroundStyle(WatchGradients.primary)
                        Text(type.name)
                            .font(.caption2.bold())
                            .foregroundStyle(WatchColors.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(WatchColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: WatchLayout.cornerRadius))
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
                        .font(.caption2.bold())
                        .foregroundStyle(WatchColors.textSecondary)
                    Spacer()
                    Text("All")
                        .font(.caption2)
                        .foregroundStyle(WatchColors.deepBlue)
                }
            }
            .buttonStyle(.plain)

            ForEach(workoutHistory.prefix(3)) { workout in
                HStack(spacing: 6) {
                    Circle()
                        .fill(WatchGradients.primary)
                        .frame(width: 6, height: 6)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(workout.type)
                            .font(.caption.bold())
                            .foregroundStyle(WatchColors.textPrimary)
                        Text(workout.date.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.system(size: 10))
                            .foregroundStyle(WatchColors.textSecondary)
                    }
                    Spacer()
                    Text(formatDuration(workout.durationSeconds))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(WatchColors.textSecondary)
                }
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
