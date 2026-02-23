//
//  WorkoutStartWatchView.swift
//  GymQuestWatch
//
//  Quick-start workout type selection on Apple Watch.
//

import SwiftUI

struct WorkoutStartWatchView: View {
    @EnvironmentObject var connectivity: WatchConnectivityManager

    var body: some View {
        if connectivity.isWorkoutActive {
            ActiveWorkoutWatchView()
        } else {
            workoutTypeSelection
        }
    }

    private var workoutTypeSelection: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("GymQuest")
                    .font(.headline)
                    .foregroundColor(.cyan)

                if connectivity.streak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                            .font(.caption2)
                        Text("\(connectivity.streak) day streak")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                ForEach(workoutTypes, id: \.name) { type in
                    Button {
                        connectivity.sendWorkoutStart(type: type.name)
                        Task {
                            await connectivity.startHealthKitWorkout()
                        }
                    } label: {
                        HStack {
                            Image(systemName: type.icon)
                                .font(.body)
                                .frame(width: 24)
                            Text(type.name)
                                .font(.body)
                            Spacer()
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(type.color.opacity(0.3))
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Start")
    }

    private var workoutTypes: [(name: String, icon: String, color: Color)] {
        [
            ("Push", "arrow.up.circle.fill", .blue),
            ("Pull", "arrow.down.circle.fill", .purple),
            ("Legs", "figure.walk", .green),
            ("Upper", "figure.arms.open", .orange),
            ("Lower", "figure.run", .cyan),
            ("Full Body", "figure.strengthtraining.traditional", .pink)
        ]
    }
}
