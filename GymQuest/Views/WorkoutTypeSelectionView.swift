//
//  WorkoutTypeSelectionView.swift
//  GymQuest
//
//  Workout type selection screen - appears when tapping "Start Workout"
//  User picks their workout type before logging their session.
//

import SwiftUI
import SwiftData

private struct WorkoutTypeOption: Identifiable {
    let type: WorkoutType
    let description: String

    var id: WorkoutType { type }

    var accent: Color {
        GQGradients.workoutGradientColors(for: type).first ?? GQColors.deepBlue
    }
}

struct WorkoutTypeSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    let profile: UserProfile

    @State private var selectedType: WorkoutType?
    @State private var customName: String = ""

    private let splitTypes: [WorkoutTypeOption] = [
        .init(type: .push, description: "Chest, shoulders, triceps"),
        .init(type: .pull, description: "Back, biceps, rear delts"),
        .init(type: .legs, description: "Quads, hamstrings, glutes"),
        .init(type: .upper, description: "Full upper body focus"),
        .init(type: .lower, description: "Full lower body focus"),
        .init(type: .fullBody, description: "Complete full-body session"),
    ]

    private let activityTypes: [WorkoutTypeOption] = [
        .init(type: .glutes, description: "Glutes, hip thrusts, kickbacks"),
        .init(type: .abs, description: "Core, abs, obliques"),
        .init(type: .hiit, description: "High-intensity intervals"),
        .init(type: .yoga, description: "Yoga and stretching"),
        .init(type: .cardio, description: "Running, cycling, intervals"),
        .init(type: .rest, description: "Recovery and mobility"),
        .init(type: .custom, description: "Name your own workout"),
    ]

    private var selectedAccent: Color {
        guard let selectedType else { return GQColors.deepBlue }
        return GQGradients.workoutGradientColors(for: selectedType).first ?? GQColors.deepBlue
    }

    @State private var tapScale: WorkoutType? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Let's Workout")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(GQColors.textPrimary)

                            Text("Tap to start.")
                                .font(.system(size: 15))
                                .foregroundColor(GQColors.textSecondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                        // MARK: - Training Split
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Training Split")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(GQColors.textSecondary)
                                .padding(.horizontal, 20)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(splitTypes) { option in
                                    workoutCard(for: option)
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        // MARK: - Activity
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Activity")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(GQColors.textSecondary)
                                .padding(.horizontal, 20)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(activityTypes) { option in
                                    workoutCard(for: option)
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        // "Other" card with inline text field
                        if selectedType == .custom {
                            VStack(spacing: 8) {
                                TextField("Enter workout name...", text: $customName)
                                    .font(.system(size: 15))
                                    .foregroundColor(GQColors.textPrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.black.opacity(0.04))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(GQColors.deepBlue.opacity(0.3), lineWidth: 1)
                                    )

                                Button {
                                    startWorkout()
                                } label: {
                                    Text("Go")
                                }
                                .buttonStyle(HomeSocialPrimaryButtonStyle(accent: GQColors.deepBlue))
                            }
                            .padding(.horizontal, 20)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        Spacer(minLength: 40)
                    }
                }
            }
            .gqPageBackground()
        }
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)
                    .frame(width: 34, height: 34)
                    .background(Color.black.opacity(0.05))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    @ViewBuilder
    private func workoutCard(for option: WorkoutTypeOption) -> some View {
        CompactWorkoutTypeCard(
            option: option,
            isTapped: tapScale == option.type
        ) {
            HapticManager.shared.select()
            if option.type == .custom {
                selectedType = .custom
            } else {
                tapScale = option.type
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {}
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    selectedType = option.type
                    startWorkout()
                }
            }
        }
    }

    private func startWorkout() {
        guard let selectedType else { return }
        HapticManager.shared.impact(.medium)
        if selectedType == .custom {
            let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
            appState.startWorkout(type: selectedType, customTitle: trimmed.isEmpty ? nil : trimmed)
        } else {
            appState.startWorkout(type: selectedType)
        }
        dismiss()
    }
}

private struct CompactWorkoutTypeCard: View {
    let option: WorkoutTypeOption
    var isTapped: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: option.type.icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.white)

                Text(option.type.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(GQGradients.workoutCardGradient(for: option.type))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [GQColors.deepBlue.opacity(0.15), GQColors.deepBlue.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
            .scaleEffect(isTapped ? 0.92 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isTapped)
        }
        .buttonStyle(GQInteractiveStyle())
    }
}

#Preview {
    WorkoutTypeSelectionView(profile: UserProfile(name: "Ben", username: "ben"))
        .environmentObject(AppState())
}
