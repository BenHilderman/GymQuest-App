//
//  TVLeaderboardView.swift
//  GymQuestTV
//
//  Created by Benjamin Hilderman
//
//  Leaderboard screen for the tvOS companion app.
//

#if os(tvOS)

import SwiftUI
import SwiftData

// MARK: - TVLeaderboardView

struct TVLeaderboardView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ExerciseLeaderboardEntry.estimated1RM, order: .reverse)
    private var allEntries: [ExerciseLeaderboardEntry]

    @Query private var profiles: [UserProfile]

    @State private var selectedExercise: String = "Bench Press"
    @State private var selectedTimeFilter: TimeFilter = .allTime

    private let exercises = ["Bench Press", "Squat", "Deadlift", "Overhead Press", "Barbell Row"]

    private var currentUserId: UUID? {
        profiles.first?.id
    }

    // MARK: - Filtering

    private var filteredEntries: [ExerciseLeaderboardEntry] {
        let byExercise = allEntries.filter { $0.exerciseName == selectedExercise }
        let byTime: [ExerciseLeaderboardEntry]

        switch selectedTimeFilter {
        case .allTime:
            byTime = byExercise
        case .thisMonth:
            let start = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date.distantPast
            byTime = byExercise.filter { $0.updatedAt >= start }
        case .thisWeek:
            let start = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date.distantPast
            byTime = byExercise.filter { $0.updatedAt >= start }
        }

        // Deduplicate by userId, keeping the highest e1RM per user
        var bestByUser: [UUID: ExerciseLeaderboardEntry] = [:]
        for entry in byTime {
            if let existing = bestByUser[entry.userId] {
                if entry.estimated1RM > existing.estimated1RM {
                    bestByUser[entry.userId] = entry
                }
            } else {
                bestByUser[entry.userId] = entry
            }
        }

        return bestByUser.values.sorted { $0.estimated1RM > $1.estimated1RM }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: TVLayout.sectionSpacing) {
                exerciseFilters
                timeFilters
                leaderboardList
            }
            .padding(TVLayout.safeAreaInset)
        }
        .background(GQColors.background.ignoresSafeArea())
    }

    // MARK: - Exercise Filter Buttons

    @ViewBuilder
    private var exerciseFilters: some View {
        VStack(alignment: .leading, spacing: 16) {
            TVSectionHeader("Leaderboard", icon: "trophy.fill")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(exercises, id: \.self) { exercise in
                        Button {
                            selectedExercise = exercise
                        } label: {
                            Text(exercise)
                                .font(TVTypography.buttonLabel)
                                .foregroundColor(
                                    selectedExercise == exercise ? .white : GQColors.textSecondary
                                )
                                .padding(.horizontal, 32)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(
                                            selectedExercise == exercise
                                                ? AnyShapeStyle(GQGradients.primary)
                                                : AnyShapeStyle(GQColors.cardBackground)
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(
                                            selectedExercise == exercise
                                                ? Color.clear
                                                : GQColors.borderDefault,
                                            lineWidth: 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .tvFocusCard()
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Time Filter Buttons

    @ViewBuilder
    private var timeFilters: some View {
        HStack(spacing: 16) {
            ForEach(TimeFilter.allCases) { filter in
                Button {
                    selectedTimeFilter = filter
                } label: {
                    Text(filter.label)
                        .font(TVTypography.caption)
                        .foregroundColor(
                            selectedTimeFilter == filter ? .white : GQColors.textSecondary
                        )
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(
                                selectedTimeFilter == filter
                                    ? AnyShapeStyle(GQColors.vividPurple)
                                    : AnyShapeStyle(GQColors.cardBackground)
                            )
                        )
                        .overlay(
                            Capsule().stroke(
                                selectedTimeFilter == filter
                                    ? Color.clear
                                    : GQColors.borderDefault,
                                lineWidth: 1
                            )
                        )
                }
                .buttonStyle(.plain)
                .tvFocusCard()
            }
            Spacer()
        }
        .padding(.horizontal, TVLayout.safeAreaInset)
    }

    // MARK: - Ranked List

    @ViewBuilder
    private var leaderboardList: some View {
        if filteredEntries.isEmpty {
            emptyState
        } else {
            VStack(spacing: 12) {
                ForEach(Array(filteredEntries.enumerated()), id: \.element.id) { index, entry in
                    leaderboardRow(rank: index + 1, entry: entry)
                }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy")
                .font(.system(size: 64))
                .foregroundColor(GQColors.textSecondary.opacity(0.5))
            Text("No entries yet")
                .font(TVTypography.cardTitle)
                .foregroundColor(GQColors.textSecondary)
            Text("Complete workouts to appear on the leaderboard")
                .font(TVTypography.body)
                .foregroundColor(GQColors.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    @ViewBuilder
    private func leaderboardRow(rank: Int, entry: ExerciseLeaderboardEntry) -> some View {
        let isCurrentUser = entry.userId == currentUserId

        Button(action: {}) {
            HStack(spacing: 20) {
                // Rank
                rankBadge(rank)

                // User avatar circle
                Circle()
                    .fill(avatarColor(for: rank))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Text(String(entry.userName.prefix(1)).uppercased())
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    )

                // Name
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.userName)
                        .font(TVTypography.cardTitle)
                        .foregroundColor(GQColors.textPrimary)

                    Text(entry.updatedAt.formatted(.dateTime.month(.abbreviated).day()))
                        .font(TVTypography.caption)
                        .foregroundColor(GQColors.textSecondary)
                }

                Spacer()

                // Estimated 1RM
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(entry.estimated1RM))")
                        .font(TVTypography.stat)
                        .foregroundColor(rank <= 3 ? GQColors.prGold : GQColors.textPrimary)
                    Text("e1RM lbs")
                        .font(TVTypography.caption)
                        .foregroundColor(GQColors.textSecondary)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: TVLayout.cornerRadius)
                    .fill(isCurrentUser ? AnyShapeStyle(GQGradients.primary.opacity(0.15)) : AnyShapeStyle(GQColors.cardBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: TVLayout.cornerRadius)
                    .stroke(
                        isCurrentUser ? GQColors.deepBlue.opacity(0.5) : GQColors.borderDefault,
                        lineWidth: isCurrentUser ? 2 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: TVLayout.cornerRadius))
        }
        .buttonStyle(.plain)
        .tvFocusCard()
    }

    // MARK: - Rank Badge

    @ViewBuilder
    private func rankBadge(_ rank: Int) -> some View {
        if rank <= 3 {
            Image(systemName: "trophy.fill")
                .font(.system(size: 28))
                .foregroundColor(trophyColor(for: rank))
                .frame(width: 48)
        } else {
            Text("#\(rank)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(GQColors.textSecondary)
                .frame(width: 48)
        }
    }

    // MARK: - Helpers

    private func trophyColor(for rank: Int) -> Color {
        switch rank {
        case 1: return GQColors.prGold
        case 2: return Color.gray.opacity(0.8)
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return GQColors.textSecondary
        }
    }

    private func avatarColor(for rank: Int) -> Color {
        switch rank {
        case 1: return GQColors.prGold
        case 2: return GQColors.vividPurple
        case 3: return GQColors.cyanSpark
        default: return GQColors.deepBlue
        }
    }
}

// MARK: - Time Filter

private enum TimeFilter: String, CaseIterable, Identifiable {
    case allTime = "all"
    case thisMonth = "month"
    case thisWeek = "week"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .allTime: return "All Time"
        case .thisMonth: return "This Month"
        case .thisWeek: return "This Week"
        }
    }
}

#endif
