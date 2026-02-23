//
//  FormCheckView.swift
//  GymQuest
//
//  Form check progression gate UI with confidence ratings.
//

import SwiftUI

struct FormCheckView: View {
    @Bindable var mastery: ExerciseMastery
    @State private var rating: Double = 4
    var onAddRating: ((Double) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "checkmark.seal")
                    .font(.title2)
                    .foregroundColor(mastery.canUnlockNextVariation ? .green : GQColors.primary)

                Text("Form Check")
                    .font(.headline)
                    .foregroundColor(GQColors.textPrimary)
            }

            Text("Complete all gates to unlock the next variation.")
                .font(.subheadline)
                .foregroundColor(GQColors.textSecondary)

            Divider()
                .background(Color.black.opacity(0.06))

            // Progress Gates
            progressGates

            Divider()
                .background(Color.black.opacity(0.06))

            // Confidence Rating
            confidenceRatingSection

            // Unlock Status
            unlockStatus
        }
        .padding(16)
        .background(GQColors.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Progress Gates

    private var progressGates: some View {
        VStack(spacing: 12) {
            GateRow(
                title: "Setup Checklist",
                isComplete: mastery.setupChecklistCompleted,
                icon: "checklist"
            )

            GateRow(
                title: "Watched Breakdown",
                isComplete: mastery.watchedBreakdownCompleted,
                icon: "play.rectangle"
            )

            GateRow(
                title: "2+ Sessions Logged",
                isComplete: mastery.sessionsCount >= 2,
                icon: "figure.strengthtraining.traditional",
                detail: "\(mastery.sessionsCount)/2"
            )

            GateRow(
                title: "2+ High Confidence",
                isComplete: mastery.hasTwoHighConfidenceRatings,
                icon: "star.fill",
                detail: "\(mastery.ratings.filter { $0.value >= 4 }.count)/2"
            )
        }
    }

    // MARK: - Confidence Rating

    private var confidenceRatingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How controlled did it feel?")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(GQColors.textPrimary)

            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        rating = Double(value)
                    } label: {
                        Image(systemName: value <= Int(rating) ? "star.fill" : "star")
                            .font(.title2)
                            .foregroundColor(value <= Int(rating) ? .yellow : GQColors.textTertiary)
                    }
                }

                Spacer()

                Text("\(Int(rating))/5")
                    .font(.headline)
                    .foregroundColor(GQColors.textPrimary)
                    .frame(width: 44, alignment: .trailing)
            }

            Button {
                onAddRating?(rating)
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Rating")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(GQColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(GQColors.primary)
                .cornerRadius(10)
            }

            // Recent ratings
            if !mastery.ratings.isEmpty {
                recentRatings
            }
        }
    }

    private var recentRatings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Ratings")
                .font(.caption.weight(.semibold))
                .foregroundColor(GQColors.textSecondary)

            HStack(spacing: 8) {
                ForEach(mastery.ratings.suffix(5).reversed()) { r in
                    RatingBadge(value: r.value)
                }
            }
        }
    }

    // MARK: - Unlock Status

    private var unlockStatus: some View {
        HStack(spacing: 12) {
            Image(systemName: mastery.canUnlockNextVariation ? "lock.open.fill" : "lock.fill")
                .font(.title2)
                .foregroundColor(mastery.canUnlockNextVariation ? .green : GQColors.textSecondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(mastery.canUnlockNextVariation ? "Next Variation Unlocked!" : "Not Unlocked Yet")
                    .font(.headline)
                    .foregroundColor(mastery.canUnlockNextVariation ? .green : .white)

                Text("Progress: \(Int(mastery.progressPercentage))%")
                    .font(.caption)
                    .foregroundColor(GQColors.textSecondary)
            }

            Spacer()
        }
        .padding(12)
        .background(mastery.canUnlockNextVariation ? Color.green.opacity(0.15) : Color.black.opacity(0.03))
        .cornerRadius(10)
    }
}

// MARK: - Gate Row

struct GateRow: View {
    let title: String
    let isComplete: Bool
    let icon: String
    var detail: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundColor(isComplete ? .green : GQColors.textTertiary)

            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(GQColors.textSecondary)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)
                .foregroundColor(isComplete ? .white : GQColors.textSecondary)

            Spacer()

            if let detail = detail {
                Text(detail)
                    .font(.caption.weight(.medium))
                    .foregroundColor(GQColors.textTertiary)
            }
        }
    }
}

// MARK: - Rating Badge

struct RatingBadge: View {
    let value: Double

    var color: Color {
        if value >= 4 { return .green }
        if value >= 3 { return .yellow }
        return .red
    }

    var body: some View {
        Text("\(Int(value))")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(GQColors.textPrimary)
            .frame(width: 24, height: 24)
            .background(color)
            .clipShape(Circle())
    }
}
