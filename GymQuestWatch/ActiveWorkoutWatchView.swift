//
//  ActiveWorkoutWatchView.swift
//  GymQuestWatch
//
//  Enhanced workout view with three tabs:
//  Tab 1: Current exercise with weight/reps steppers and "Complete Set" button
//  Tab 2: Circular rest timer with skip button
//  Tab 3: Workout overview (elapsed time, total sets, heart rate)
//

import SwiftUI

struct ActiveWorkoutWatchView: View {
    @EnvironmentObject var connectivity: WatchConnectivityManager
    @State private var showingEndConfirmation = false
    @State private var selectedTab = 0
    @State private var currentWeight: Double = 135
    @State private var currentReps: Int = 8

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Current Exercise + Controls
            exerciseTab
                .tag(0)

            // Tab 2: Rest Timer
            restTimerTab
                .tag(1)

            // Tab 3: Workout Overview
            overviewTab
                .tag(2)
        }
        .tabViewStyle(.verticalPage)
        .onChange(of: connectivity.restTimeRemaining) { _, newValue in
            if newValue > 0 {
                selectedTab = 1
            }
        }
    }

    // MARK: - Tab 1: Exercise

    private var exerciseTab: some View {
        VStack(spacing: 6) {
            Text(connectivity.workoutType.uppercased())
                .font(.caption2.bold())
                .foregroundColor(.cyan)
                .tracking(1)

            Text(connectivity.currentExerciseName.isEmpty ? "Warming Up" : connectivity.currentExerciseName)
                .font(.subheadline.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            // Weight stepper (Digital Crown adjustable)
            HStack {
                Text("Weight")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(currentWeight)) lbs")
                    .font(.headline.monospacedDigit())
            }
            .focusable()
            .digitalCrownRotation($currentWeight, from: 0, through: 1000, by: 5, sensitivity: .medium)

            // Reps stepper
            HStack {
                Button {
                    currentReps = max(1, currentReps - 1)
                } label: {
                    Image(systemName: "minus")
                        .font(.caption2)
                }
                .buttonStyle(.borderless)

                Text("\(currentReps) reps")
                    .font(.headline.monospacedDigit())
                    .frame(maxWidth: .infinity)

                Button {
                    currentReps += 1
                } label: {
                    Image(systemName: "plus")
                        .font(.caption2)
                }
                .buttonStyle(.borderless)
            }

            // Complete Set button
            Button {
                connectivity.sendSetComplete(
                    exerciseName: connectivity.currentExerciseName,
                    setNumber: connectivity.currentSetNumber + 1,
                    weight: currentWeight,
                    reps: currentReps
                )
            } label: {
                Text("Complete Set")
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)

            Text("Set \(connectivity.currentSetNumber)/\(connectivity.totalSets)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Tab 2: Rest Timer

    private var restTimerTab: some View {
        VStack(spacing: 8) {
            if connectivity.restTimeRemaining > 0 {
                // Circular timer
                ZStack {
                    Circle()
                        .stroke(Color.orange.opacity(0.2), lineWidth: 6)

                    Circle()
                        .trim(from: 0, to: restProgress)
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: connectivity.restTimeRemaining)

                    VStack(spacing: 2) {
                        Text("\(connectivity.restTimeRemaining)")
                            .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundColor(.orange)
                        Text("seconds")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 120, height: 120)

                Button {
                    // Skip rest — go back to exercise tab
                    selectedTab = 0
                } label: {
                    Text("Skip Rest")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    Text("Ready!")
                        .font(.headline)
                    Text("Swipe up for next set")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Tab 3: Overview

    private var overviewTab: some View {
        VStack(spacing: 10) {
            Text("WORKOUT")
                .font(.caption2.bold())
                .foregroundColor(.cyan)
                .tracking(1)

            // Elapsed time
            VStack(spacing: 2) {
                Text(elapsedTimeString)
                    .font(.title.bold().monospacedDigit())
                Text("Elapsed")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Divider()

            HStack(spacing: 20) {
                VStack(spacing: 2) {
                    Text("\(connectivity.currentSetNumber)")
                        .font(.title3.bold().monospacedDigit())
                    Text("Sets")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if connectivity.heartRate > 0 {
                    VStack(spacing: 2) {
                        HStack(spacing: 2) {
                            Image(systemName: "heart.fill")
                                .font(.caption2)
                                .foregroundColor(.red)
                            Text("\(Int(connectivity.heartRate))")
                                .font(.title3.bold().monospacedDigit())
                        }
                        Text("BPM")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // End workout button
            Button(role: .destructive) {
                showingEndConfirmation = true
            } label: {
                Label("End", systemImage: "stop.fill")
                    .font(.caption)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red.opacity(0.3))
        }
        .padding(.horizontal, 4)
        .confirmationDialog("End Workout?", isPresented: $showingEndConfirmation) {
            Button("End Workout", role: .destructive) {
                connectivity.sendWorkoutEnd()
                Task {
                    await connectivity.endHealthKitWorkout()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Helpers

    private var elapsedTimeString: String {
        let minutes = connectivity.elapsedSeconds / 60
        let seconds = connectivity.elapsedSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var restProgress: CGFloat {
        guard connectivity.restTimeRemaining > 0 else { return 0 }
        // Assume 90s default rest
        let total = max(connectivity.restTimeRemaining, 90)
        return CGFloat(connectivity.restTimeRemaining) / CGFloat(total)
    }
}
