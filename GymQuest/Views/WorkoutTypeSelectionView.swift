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
    @State private var showingLogWorkout = false
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
            Color.black.ignoresSafeArea()

            // Gradient overlay
            LinearGradient(
                colors: [
                    (selectedType?.color ?? GQColors.vividPurple).opacity(0.15),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.4), value: selectedType)

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

                    // Time indicator
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                        Text(Date().formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(GQColors.textSecondary)
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
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                        selectedType = item.type
                                    }
                                    // Auto-start after brief delay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                        showingLogWorkout = true
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
        .fullScreenCover(isPresented: $showingLogWorkout) {
            if let type = selectedType {
                ActiveWorkoutView(profile: profile, workoutType: type)
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

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon with colored background
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [type.color, type.color.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)

                    Image(systemName: type.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.rawValue)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                // Arrow indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(type.color)
                    .frame(width: 32, height: 32)
                    .background(type.color.opacity(0.15))
                    .clipShape(Circle())
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(white: 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ?
                            type.color.opacity(0.8) :
                            Color.white.opacity(0.08),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

#Preview {
    WorkoutTypeSelectionView(profile: UserProfile(name: "Ben", username: "ben"))
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
