//
//  WorkoutTypeSelectionView.swift
//  GymQuest
//
//  Type grid page — pushed from the workout start hub.
//  Tap a split/activity card to start a workout.
//

import SwiftUI

// MARK: - Workout Type Option

private struct WorkoutTypeOption: Identifiable {
    let type: WorkoutType
    let description: String
    var id: WorkoutType { type }
    var accent: Color {
        GQGradients.workoutGradientColors(for: type).first ?? GQColors.textTertiary
    }
}

// MARK: - Compact Workout Type Card

private struct CompactWorkoutTypeCard: View {
    let option: WorkoutTypeOption
    var isTapped: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon circle
                Circle()
                    .fill(GQColors.deepBlue.opacity(0.08))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: option.type.icon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(GQGradients.primary)
                    )

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.type.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                        .lineLimit(1)

                    Text(option.description)
                        .font(.system(size: 11))
                        .foregroundColor(GQColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .homeSocialCard(cornerRadius: 14)
            .scaleEffect(isTapped ? 0.92 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isTapped)
        }
        .buttonStyle(GQInteractiveStyle())
    }
}

// MARK: - Workout Type Selection View

struct WorkoutTypeSelectionView: View {
    @EnvironmentObject var appState: AppState

    let profile: UserProfile

    @State private var selectedType: WorkoutType?
    @State private var customName: String = ""
    @State private var tapScale: WorkoutType?
    @State private var showCardioSubTypePicker = false

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

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                // TRAINING SPLIT
                sectionLabel("TRAINING SPLIT")

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(splitTypes) { option in
                        workoutCard(for: option)
                    }
                }

                // ACTIVITY
                sectionLabel("ACTIVITY")

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(activityTypes) { option in
                        workoutCard(for: option)
                    }
                }

                // Custom name inline field
                if selectedType == .custom {
                    HStack(spacing: 10) {
                        TextField("Workout name", text: $customName)
                            .textFieldStyle(LiftAITextFieldStyle())

                        Button {
                            startWorkout()
                        } label: {
                            Text("Go")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(GQGradients.primary)
                                )
                        }
                        .buttonStyle(GQInteractiveStyle())
                    }
                    .padding(14)
                    .homeSocialCard(cornerRadius: 14)
                }

                Spacer(minLength: 34)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .gqPageBackground()
        .navigationTitle("Custom Workout")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCardioSubTypePicker) {
            CardioSubTypePickerSheet { subType in
                startCardioWorkout(subType: subType)
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Section Label

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(GQTypography.sectionHeader)
            .foregroundColor(GQColors.textTertiary)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    // MARK: - Workout Card

    @ViewBuilder
    private func workoutCard(for option: WorkoutTypeOption) -> some View {
        CompactWorkoutTypeCard(
            option: option,
            isTapped: tapScale == option.type
        ) {
            HapticManager.shared.select()
            if option.type == .custom {
                selectedType = .custom
            } else if option.type == .cardio {
                showCardioSubTypePicker = true
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

    // MARK: - Start Workout

    private func startWorkout() {
        guard let selectedType else { return }
        HapticManager.shared.impact(.medium)
        if selectedType == .custom {
            let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
            appState.startWorkout(type: selectedType, customTitle: trimmed.isEmpty ? nil : trimmed)
        } else {
            appState.startWorkout(type: selectedType)
        }
    }

    private func startCardioWorkout(subType: CardioSubType) {
        HapticManager.shared.impact(.medium)
        appState.startWorkout(type: .cardio, customTitle: subType.rawValue)
    }
}

// MARK: - Cardio Sub-Type Picker

struct CardioSubTypePickerSheet: View {
    let onSelect: (CardioSubType) -> Void
    @Environment(\.dismiss) private var dismiss

    private let outdoorTypes: [CardioSubType] = [.outdoorRun, .cycling, .hiking]
    private let indoorTypes: [CardioSubType] = [.treadmill, .rowing, .stairClimber, .elliptical, .jumpRope, .swimming]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Outdoor (GPS)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 9))
                                .foregroundColor(GQColors.textTertiary)
                            Text("OUTDOOR · GPS")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(GQColors.textTertiary)
                                .tracking(0.5)
                        }

                        ForEach(outdoorTypes, id: \.self) { subType in
                            cardioRow(subType)
                        }
                    }

                    // Indoor
                    VStack(alignment: .leading, spacing: 8) {
                        Text("INDOOR")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(GQColors.textTertiary)
                            .tracking(0.5)

                        ForEach(indoorTypes, id: \.self) { subType in
                            cardioRow(subType)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .gqPageBackground()
            .navigationTitle("Cardio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(GQColors.textTertiary)
                    }
                }
            }
        }
    }

    private func cardioRow(_ subType: CardioSubType) -> some View {
        Button {
            onSelect(subType)
            dismiss()
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(GQGradients.primary.opacity(0.06))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: subType.icon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(GQGradients.primary)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(subType.rawValue)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                    if subType.isOutdoor {
                        Text("Route tracking enabled")
                            .font(.system(size: 11))
                            .foregroundColor(GQColors.textTertiary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(GQColors.textTertiary)
            }
            .padding(14)
            .homeSocialCard(cornerRadius: 14)
        }
        .buttonStyle(GQInteractiveStyle())
    }
}
