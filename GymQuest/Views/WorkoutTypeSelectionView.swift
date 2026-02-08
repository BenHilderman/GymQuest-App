//
//  WorkoutTypeSelectionView.swift
//  GymQuest
//
//  Workout type selection screen - appears when tapping "Start Workout"
//  User picks their workout type before logging their session.
//

import SwiftUI
import SwiftData

struct WorkoutTypeSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    let profile: UserProfile

    @State private var selectedType: WorkoutType?
    @State private var appearAnimation = false

    let workoutTypes: [(type: WorkoutType, description: String, icon: String)] = [
        (.push, "Chest, Shoulders, Triceps", "arrow.up.circle.fill"),
        (.pull, "Back, Biceps, Rear Delts", "arrow.down.circle.fill"),
        (.legs, "Quads, Hamstrings, Glutes", "figure.walk"),
        (.upper, "Full Upper Body", "figure.arms.open"),
        (.lower, "Full Lower Body", "figure.stand"),
        (.fullBody, "Complete Full Body", "figure.strengthtraining.traditional"),
        (.cardio, "Running, Cycling, HIIT", "heart.fill"),
        (.rest, "Active Recovery Day", "leaf.fill")
    ]

    var body: some View {
        ZStack {
            // Background
            GQColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom Header
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }

                    Spacer()

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        // Hero Section
                        VStack(spacing: 12) {
                            Text("Let's train")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)

                            Text("What are you working on today?")
                                .font(.system(size: 16))
                                .foregroundColor(GQColors.textSecondary)
                        }
                        .padding(.top, 24)
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 20)

                        // Workout Type Cards - Vertical List
                        VStack(spacing: 12) {
                            ForEach(Array(workoutTypes.enumerated()), id: \.element.type) { index, item in
                                WorkoutTypeCardNew(
                                    type: item.type,
                                    description: item.description,
                                    isSelected: selectedType == item.type
                                ) {
                                    HapticManager.shared.impact(.medium)
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                        selectedType = item.type
                                    }
                                    // Start workout via appState after brief animation
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        appState.startWorkout(type: item.type)
                                        dismiss()
                                    }
                                }
                                .opacity(appearAnimation ? 1 : 0)
                                .offset(x: appearAnimation ? 0 : 50)
                                .animation(
                                    .spring(response: 0.5, dampingFraction: 0.8)
                                    .delay(Double(index) * 0.05),
                                    value: appearAnimation
                                )
                            }
                        }
                        .padding(.horizontal, 20)

                        Spacer(minLength: 50)
                    }
                }
            }
        }
        .onAppear {
            withAnimation {
                appearAnimation = true
            }
        }
    }
}

// MARK: - New Workout Type Card (Horizontal Style)

struct WorkoutTypeCardNew: View {
    let type: WorkoutType
    let description: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Icon - clean flat style
                Image(systemName: type.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)

                // Text content
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                // Arrow indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(GQColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? GQColors.primary.opacity(0.6) : Color.clear, lineWidth: 1.5)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

#Preview {
    WorkoutTypeSelectionView(profile: UserProfile(name: "Ben", username: "ben"))
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
