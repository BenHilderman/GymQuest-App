//
//  LeaderboardView.swift
//  GymQuest
//
//  Exercise-specific leaderboard within clubs. Shows ranked e1RM entries
//  with exercise picker, time filter, and weight class filtering.
//

import SwiftUI
import SwiftData

struct LeaderboardView: View {
    @Environment(\.modelContext) private var modelContext
    let clubId: UUID

    @State private var selectedExercise = "Bench Press"
    @State private var selectedTimeFilter: LeaderboardTimeFilter = .allTime
    @State private var selectedWeightClass: String? = nil
    @State private var entries: [ExerciseLeaderboardEntry] = []

    private let exercises = ["Bench Press", "Squat", "Deadlift", "Overhead Press", "Barbell Row"]
    private let weightClasses = ["< 60kg", "60-75kg", "75-90kg", "90-105kg", "105-120kg", "120kg+"]

    var body: some View {
        VStack(spacing: 0) {
            // Exercise picker
            exercisePicker

            // Time filter
            timeFilterPicker

            // Weight class filter
            weightClassFilter

            // Leaderboard list
            if entries.isEmpty {
                emptyState
            } else {
                leaderboardList
            }
        }
        .navigationTitle("Leaderboard")
        .onAppear { loadEntries() }
        .onChange(of: selectedExercise) { _, _ in loadEntries() }
        .onChange(of: selectedTimeFilter) { _, _ in loadEntries() }
        .onChange(of: selectedWeightClass) { _, _ in loadEntries() }
    }

    // MARK: - Exercise Picker

    private var exercisePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(exercises, id: \.self) { exercise in
                    Button {
                        selectedExercise = exercise
                    } label: {
                        Text(exercise)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                selectedExercise == exercise
                                ? AnyShapeStyle(GQGradients.primary)
                                : AnyShapeStyle(GQColors.cardBackground)
                            )
                            .foregroundColor(selectedExercise == exercise ? .white : GQColors.textPrimary)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(selectedExercise == exercise ? Color.clear : GQColors.borderDefault, lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Time Filter

    private var timeFilterPicker: some View {
        Picker("Time", selection: $selectedTimeFilter) {
            ForEach(LeaderboardTimeFilter.allCases, id: \.self) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Weight Class Filter

    private var weightClassFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Button {
                    selectedWeightClass = nil
                } label: {
                    Text("All")
                        .font(.caption2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(selectedWeightClass == nil ? GQColors.deepBlue.opacity(0.2) : Color.clear)
                        .foregroundColor(selectedWeightClass == nil ? GQColors.deepBlue : GQColors.textSecondary)
                        .clipShape(Capsule())
                }

                ForEach(weightClasses, id: \.self) { wc in
                    Button {
                        selectedWeightClass = wc
                    } label: {
                        Text(wc)
                            .font(.caption2)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(selectedWeightClass == wc ? GQColors.deepBlue.opacity(0.2) : Color.clear)
                            .foregroundColor(selectedWeightClass == wc ? GQColors.deepBlue : GQColors.textSecondary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Leaderboard List

    private var leaderboardList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    leaderboardRow(rank: index + 1, entry: entry)
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func leaderboardRow(rank: Int, entry: ExerciseLeaderboardEntry) -> some View {
        HStack(spacing: 12) {
            // Rank with medal
            ZStack {
                if rank <= 3 {
                    Image(systemName: "medal.fill")
                        .foregroundColor(medalColor(for: rank))
                        .font(.title3)
                }
                Text("\(rank)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(rank <= 3 ? .white : GQColors.textSecondary)
            }
            .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.userName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(GQColors.textPrimary)

                if let weightClass = entry.weightClass {
                    Text(weightClass)
                        .font(.caption2)
                        .foregroundColor(GQColors.textSecondary)
                }
            }

            Spacer()

            Text("\(Int(entry.estimated1RM)) lbs")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(rank <= 3 ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(GQColors.textPrimary))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(rank <= 3 ? GQColors.deepBlue.opacity(0.05) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "trophy")
                .font(.system(size: 48))
                .foregroundColor(GQColors.textSecondary.opacity(0.5))
            Text("No entries yet")
                .font(.headline)
                .foregroundColor(GQColors.textSecondary)
            Text("Log workouts with \(selectedExercise) to appear on the leaderboard.")
                .font(.subheadline)
                .foregroundColor(GQColors.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    // MARK: - Helpers

    private func loadEntries() {
        entries = LeaderboardService.shared.buildExerciseLeaderboard(
            clubId: clubId,
            exerciseName: selectedExercise,
            timeFilter: selectedTimeFilter,
            weightClass: selectedWeightClass,
            modelContext: modelContext
        )
    }

    private func medalColor(for rank: Int) -> Color {
        switch rank {
        case 1: return GQColors.textSecondary
        case 2: return GQColors.textSecondary
        case 3: return GQColors.textSecondary
        default: return .clear
        }
    }
}
