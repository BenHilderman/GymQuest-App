//
//  ActiveWorkoutWatchView.swift
//  GymQuestWatch
//
//  Displays current exercise, set counter, rest timer, and elapsed time
//  during an active workout on Apple Watch.
//

import SwiftUI

struct ActiveWorkoutWatchView: View {
    @EnvironmentObject var connectivity: WatchConnectivityManager
    @State private var showingEndConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Workout type
                Text(connectivity.workoutType.uppercased())
                    .font(.caption2.bold())
                    .foregroundColor(.cyan)
                    .tracking(1)

                // Current exercise
                Text(connectivity.currentExerciseName.isEmpty ? "Warming Up" : connectivity.currentExerciseName)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                // Set counter
                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text("\(connectivity.currentSetNumber)/\(connectivity.totalSets)")
                            .font(.title2.bold().monospacedDigit())
                        Text("Set")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Divider()
                        .frame(height: 30)

                    VStack(spacing: 2) {
                        Text(elapsedTimeString)
                            .font(.title2.bold().monospacedDigit())
                        Text("Time")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // Rest timer
                if connectivity.restTimeRemaining > 0 {
                    VStack(spacing: 4) {
                        Text("REST")
                            .font(.caption2.bold())
                            .foregroundColor(.orange)
                        Text("\(connectivity.restTimeRemaining)s")
                            .font(.title.bold().monospacedDigit())
                            .foregroundColor(.orange)
                    }
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(10)
                }

                // Heart rate
                if connectivity.heartRate > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                        Text("\(Int(connectivity.heartRate)) BPM")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.red)
                    }
                }

                // End workout button
                Button(role: .destructive) {
                    showingEndConfirmation = true
                } label: {
                    Label("End Workout", systemImage: "stop.fill")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red.opacity(0.3))
            }
            .padding(.horizontal, 4)
        }
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

    private var elapsedTimeString: String {
        let minutes = connectivity.elapsedSeconds / 60
        let seconds = connectivity.elapsedSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
