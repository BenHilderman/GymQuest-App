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

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(workoutTypes) { option in
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
                        }
                        .padding(.horizontal, 20)

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
                                            .stroke(GQColors.vividPurple.opacity(0.3), lineWidth: 1)
                                    )

                                Button {
                                    startWorkout()
                                } label: {
                                    Text("Go")
                                }
                                .buttonStyle(HomeSocialPrimaryButtonStyle(accent: GQColors.vividPurple))
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
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(option.accent.opacity(0.16))
                        .frame(width: 36, height: 36)

                    Image(systemName: option.type.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(option.accent)
                }

                Text(option.type.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .homeSocialCard(accent: option.accent)
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
