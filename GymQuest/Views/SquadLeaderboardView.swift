//
//  SquadLeaderboardView.swift
//  GymQuest
//
//  Weekly volume leaderboard within squads. Features streak multiplier badges,
//  squad vs squad comparison, and create challenge functionality.
//

import SwiftUI
import SwiftData

struct SquadLeaderboardView: View {
    @Environment(\.modelContext) private var modelContext
    let squad: Squad
    let profile: UserProfile

    @State private var volumes: [SquadMemberVolume] = []
    @State private var showingCreateChallenge = false
    @State private var opponentVolume: Double? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Streak multiplier badge
                streakMultiplierBadge

                // Weekly leaderboard
                weeklyLeaderboardSection

                // Squad vs Squad (if active)
                if squad.squadVsSquadOpponentId != nil {
                    squadVsSquadCard
                }

                // Active challenge
                activeChallengeCard

                // Create challenge button
                Button {
                    showingCreateChallenge = true
                } label: {
                    Label("Create Challenge", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(GQGradients.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .navigationTitle("Squad Leaderboard")
        .onAppear { loadLeaderboard() }
        .sheet(isPresented: $showingCreateChallenge) {
            createChallengeSheet
        }
    }

    // MARK: - Streak Multiplier Badge

    private var streakMultiplierBadge: some View {
        HStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundColor(GQColors.textSecondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(squad.streakWeeks) Week Streak")
                    .font(.headline)
                    .foregroundColor(GQColors.textPrimary)
                Text("XP Multiplier: \(String(format: "%.1f", squad.xpMultiplier))x")
                    .font(.caption)
                    .foregroundColor(GQColors.textSecondary)
            }

            Spacer()

            Text("\(squad.streakWeeks)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(GQGradients.primary)
        }
        .padding()
        .background(GQColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(GQColors.borderDefault, lineWidth: 1)
        )
    }

    // MARK: - Weekly Leaderboard

    private var weeklyLeaderboardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("THIS WEEK")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(GQColors.textSecondary)

            ForEach(Array(volumes.enumerated()), id: \.element.id) { index, member in
                HStack(spacing: 12) {
                    // Rank
                    Text("#\(index + 1)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(index < 3 ? GQColors.deepBlue : GQColors.textSecondary)
                        .frame(width: 32)

                    // Avatar placeholder
                    Circle()
                        .fill(GQGradients.primary)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text(String(member.userName.prefix(1)).uppercased())
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(member.userName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(GQColors.textPrimary)
                        Text("\(member.workoutCount) workouts · \(member.totalSets) sets")
                            .font(.caption2)
                            .foregroundColor(GQColors.textSecondary)
                    }

                    Spacer()

                    Text("\(Int(member.totalVolume)) lbs")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(GQColors.textPrimary)
                }
                .padding(.vertical, 6)
            }
        }
        .padding()
        .background(GQColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(GQColors.borderDefault, lineWidth: 1)
        )
    }

    // MARK: - Squad vs Squad

    private var squadVsSquadCard: some View {
        VStack(spacing: 12) {
            Text("SQUAD VS SQUAD")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(GQColors.textSecondary)

            HStack {
                VStack(spacing: 4) {
                    Text(squad.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(GQColors.textPrimary)
                    let myVolume = volumes.reduce(0) { $0 + $1.totalVolume }
                    Text("\(Int(myVolume)) lbs")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(GQGradients.primary)
                }

                Spacer()

                Image(systemName: "bolt.fill")
                    .font(.title2)
                    .foregroundColor(GQColors.textSecondary)

                Spacer()

                VStack(spacing: 4) {
                    Text("Opponent")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(GQColors.textPrimary)
                    Text("\(Int(opponentVolume ?? 0)) lbs")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(GQColors.textSecondary)
                }
            }
        }
        .padding()
        .background(GQColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(GQColors.borderDefault, lineWidth: 1)
        )
    }

    // MARK: - Active Challenge Card

    @ViewBuilder
    private var activeChallengeCard: some View {
        if let challengeId = squad.activeChallengeId {
            let challenges = (try? modelContext.fetch(FetchDescriptor<SquadChallenge>())) ?? []
            if let challenge = challenges.first(where: { $0.id == challengeId }) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ACTIVE CHALLENGE")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(GQColors.textSecondary)

                    Text(challenge.title)
                        .font(.headline)
                        .foregroundColor(GQColors.textPrimary)

                    ProgressView(value: Double(challenge.currentValue), total: Double(challenge.targetValue))
                        .tint(GQColors.deepBlue)

                    HStack {
                        Text("\(challenge.currentValue)/\(challenge.targetValue)")
                            .font(.caption)
                            .foregroundColor(GQColors.textSecondary)
                        Spacer()
                        Text("\(challenge.xpReward) XP")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(GQColors.textSecondary)
                    }
                }
                .padding()
                .background(GQColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(GQColors.borderDefault, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Create Challenge Sheet

    private var createChallengeSheet: some View {
        NavigationStack {
            CreateSquadChallengeView(squad: squad)
        }
        .presentationDetents([.medium])
    }

    // MARK: - Data Loading

    private func loadLeaderboard() {
        let weekStart = Calendar.current.startOfWeek(for: Date())
        let descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let allWorkouts = (try? modelContext.fetch(descriptor)) ?? []

        volumes = LeaderboardService.shared.buildSquadLeaderboard(
            squad: squad,
            allWorkouts: allWorkouts,
            weekStart: weekStart
        )
    }
}

// MARK: - Create Challenge View

struct CreateSquadChallengeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let squad: Squad

    @State private var title = ""
    @State private var targetValue = 50
    @State private var durationDays = 7
    @State private var xpReward = 100

    var body: some View {
        Form {
            Section("Challenge Details") {
                TextField("Challenge Title", text: $title)

                Stepper("Target: \(targetValue) sets", value: $targetValue, in: 10...500, step: 10)

                Picker("Duration", selection: $durationDays) {
                    Text("1 Week").tag(7)
                    Text("2 Weeks").tag(14)
                    Text("1 Month").tag(30)
                }

                Stepper("Reward: \(xpReward) XP", value: $xpReward, in: 50...1000, step: 50)
            }
        }
        .navigationTitle("New Challenge")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    createChallenge()
                    dismiss()
                }
                .disabled(title.isEmpty)
            }
        }
    }

    private func createChallenge() {
        let challenge = SquadChallenge(
            squadId: squad.id,
            title: title,
            endDate: Date().addingTimeInterval(TimeInterval(durationDays * 86400)),
            targetValue: targetValue,
            xpReward: xpReward
        )
        modelContext.insert(challenge)
        squad.activeChallengeId = challenge.id
        try? modelContext.save()
    }
}

// Calendar.startOfWeek(for:) is defined in Models.swift
