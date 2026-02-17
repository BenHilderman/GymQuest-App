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
        GQGradients.workoutGradientColors(for: type).first ?? GQColors.vividPurple
    }
}

struct WorkoutTypeSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    let profile: UserProfile

    @State private var selectedType: WorkoutType?
    @State private var customName: String = ""

    private let workoutTypes: [WorkoutTypeOption] = [
        .init(type: .push, description: "Chest, shoulders, triceps"),
        .init(type: .pull, description: "Back, biceps, rear delts"),
        .init(type: .legs, description: "Quads, hamstrings, glutes"),
        .init(type: .upper, description: "Full upper body focus"),
        .init(type: .lower, description: "Full lower body focus"),
        .init(type: .fullBody, description: "Complete full-body session"),
        .init(type: .cardio, description: "Running, cycling, intervals"),
        .init(type: .rest, description: "Active recovery and mobility"),
        .init(type: .glutes, description: "Glutes, hip thrusts, kickbacks"),
        .init(type: .abs, description: "Core, abs, obliques")
    ]

    private var selectedAccent: Color {
        guard let selectedType else { return GQColors.vividPurple }
        return GQGradients.workoutGradientColors(for: selectedType).first ?? GQColors.vividPurple
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Let's Workout")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)

                            Text("Choose your session type and start when you're ready.")
                                .font(.system(size: 15))
                                .foregroundColor(GQColors.textSecondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                        VStack(spacing: 10) {
                            ForEach(workoutTypes) { option in
                                WorkoutTypeSelectionCard(
                                    option: option,
                                    isSelected: selectedType == option.type
                                ) {
                                    HapticManager.shared.select()
                                    selectedType = option.type
                                }
                            }

                            // "Other" card with custom name input
                            otherWorkoutCard
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                    }
                }

                bottomBar
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
                    .foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            Button {
                startWorkout()
            } label: {
                Text(startButtonLabel)
            }
            .buttonStyle(HomeSocialPrimaryButtonStyle(accent: selectedAccent))
            .disabled(selectedType == nil)
            .opacity(selectedType == nil ? 0.55 : 1.0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 20)
        .background(
            Rectangle()
                .fill(GQColors.surfaceOverlay.opacity(0.86))
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var startButtonLabel: String {
        guard let selectedType else { return "Select a Workout Type" }
        if selectedType == .other {
            let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Start Other" : "Start \(trimmed)"
        }
        return "Start \(selectedType.rawValue)"
    }

    private var otherWorkoutCard: some View {
        let otherOption = WorkoutTypeOption(type: .other, description: "Custom workout type")
        let isSelected = selectedType == .other

        return VStack(spacing: 0) {
            WorkoutTypeSelectionCard(
                option: otherOption,
                isSelected: isSelected
            ) {
                HapticManager.shared.select()
                selectedType = .other
            }

            if isSelected {
                TextField("Enter workout name...", text: $customName)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(otherOption.accent.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }

    private func startWorkout() {
        guard let selectedType else { return }
        HapticManager.shared.impact(.medium)
        if selectedType == .other {
            let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
            appState.startWorkout(type: selectedType, customTitle: trimmed.isEmpty ? nil : trimmed)
        } else {
            appState.startWorkout(type: selectedType)
        }
        dismiss()
    }
}

private struct WorkoutTypeSelectionCard: View {
    let option: WorkoutTypeOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(option.accent.opacity(0.16))
                        .frame(width: 44, height: 44)

                    Image(systemName: option.type.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(option.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.type.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text(option.description)
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textSecondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isSelected ? option.accent : GQColors.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .homeSocialCard(accent: option.accent, emphasized: isSelected)
        }
        .buttonStyle(GQInteractiveStyle())
    }
}

#Preview {
    WorkoutTypeSelectionView(profile: UserProfile(name: "Ben", username: "ben"))
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
