//
//  FormSetupChecklistView.swift
//  GymQuest
//
//  Setup checklist for exercise form progression gate.
//

import SwiftUI

struct FormSetupChecklistView: View {
    @Bindable var mastery: ExerciseMastery
    var exercise: FormExercise?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "checklist")
                    .font(.title2)
                    .foregroundColor(GQColors.primary)

                Text("Setup Checklist")
                    .font(.headline)
                    .foregroundColor(GQColors.textPrimary)
            }

            Text("Complete the setup checklist to unlock progression.")
                .font(.subheadline)
                .foregroundColor(GQColors.textSecondary)

            Divider()
                .background(Color.black.opacity(0.06))

            // Main toggle
            Toggle(isOn: $mastery.setupChecklistCompleted) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("I can set up the equipment correctly")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(GQColors.textPrimary)

                    Text("Seat height, grip width, safety pins, etc.")
                        .font(.caption)
                        .foregroundColor(GQColors.textSecondary)
                }
            }
            .tint(GQColors.primary)
            .padding(.vertical, 8)

            // Equipment-specific tips
            if let exercise = exercise {
                equipmentTips(for: exercise)
            }

            // Quality gate reminder
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundColor(GQColors.textTertiary)

                Text("Keep this strict. This is your quality gate.")
                    .font(.caption)
                    .foregroundColor(GQColors.textTertiary)
            }
            .padding(.top, 8)
        }
        .padding(16)
        .background(GQColors.cardBackground)
        .cornerRadius(16)
    }

    @ViewBuilder
    private func equipmentTips(for exercise: FormExercise) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Setup Tips for \(exercise.equipment.capitalized)")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(GQColors.textPrimary)

            ForEach(setupTips(for: exercise.equipment), id: \.self) { tip in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.caption)
                        .foregroundColor(GQColors.textSecondary)

                    Text(tip)
                        .font(.caption)
                        .foregroundColor(GQColors.textSecondary)
                }
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.03))
        .cornerRadius(10)
    }

    private func setupTips(for equipment: String) -> [String] {
        switch equipment.lowercased() {
        case "barbell":
            return [
                "Check collar clips are secure",
                "Confirm rack height suits your unrack position",
                "Set safety pins at appropriate height"
            ]
        case "dumbbell", "dumbbells":
            return [
                "Select matching weight dumbbells",
                "Position bench at correct angle if needed",
                "Clear space around your workout area"
            ]
        case "cable", "machine":
            return [
                "Adjust seat/pad height for your body",
                "Set weight pin at appropriate load",
                "Check cable/pulley moves smoothly"
            ]
        case "bodyweight":
            return [
                "Clear floor space",
                "Use mat if needed for comfort",
                "Ensure stable surface"
            ]
        default:
            return [
                "Check equipment is in good condition",
                "Adjust settings for your body",
                "Ensure stable setup before starting"
            ]
        }
    }
}
