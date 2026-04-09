//
//  SquadView.swift
//  GymQuest
//
//  Squad system UI for GymQuest 2.0.
//  Create/join squads, view leaderboards, manage challenges.
//

import SwiftUI
import SwiftData

struct SquadView: View {
    @EnvironmentObject var featureFlags: FeatureFlags
    @Environment(\.modelContext) private var modelContext
    @Query private var squads: [Squad]

    let profile: UserProfile

    @State private var showingCreateSquad = false
    @State private var showingJoinSquad = false
    @State private var selectedSquad: Squad?

    var userSquads: [Squad] {
        squads.filter { $0.memberIds.contains(profile.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if userSquads.isEmpty {
                        EmptySquadView(
                            onCreateSquad: { showingCreateSquad = true },
                            onJoinSquad: { showingJoinSquad = true }
                        )
                    } else {
                        ForEach(userSquads) { squad in
                            SquadCardView(
                                squad: squad,
                                profile: profile
                            )
                            .onTapGesture {
                                selectedSquad = squad
                            }
                        }

                        // Add another squad button
                        if userSquads.count < 3 {
                            HStack(spacing: 12) {
                                Button {
                                    showingCreateSquad = true
                                } label: {
                                    Label("Create", systemImage: "plus.circle.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(GQColors.textPrimary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(GQColors.deepBlue.opacity(0.12))
                                        .cornerRadius(GQRadius.md)
                                }

                                Button {
                                    showingJoinSquad = true
                                } label: {
                                    Label("Join", systemImage: "person.badge.plus")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(GQColors.textPrimary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(GQColors.textSecondary.opacity(0.12))
                                        .cornerRadius(GQRadius.md)
                                }
                            }
                            .buttonStyle(GQInteractiveStyle())
                        }
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .gqPageBackground()
            .navigationTitle("Squads")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .sheet(isPresented: $showingCreateSquad) {
                CreateSquadSheet(profile: profile)
            }
            .sheet(isPresented: $showingJoinSquad) {
                JoinSquadSheet(profile: profile)
            }
            .sheet(item: $selectedSquad) { squad in
                SquadDetailView(squad: squad, profile: profile)
            }
        }
    }
}

// MARK: - Empty Squad View

struct EmptySquadView: View {
    let onCreateSquad: () -> Void
    let onJoinSquad: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(GQColors.textTertiary.opacity(0.08))
                    .frame(width: 52, height: 52)
                Image(systemName: "person.2.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)
            }
            .padding(.top, 8)

            VStack(spacing: 6) {
                Text("No Squads Yet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)

                Text("Train with friends and compete in weekly challenges")
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                Button(action: onCreateSquad) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 15))
                        Text("Create a Squad")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())

                Button(action: onJoinSquad) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 15))
                        Text("Join with Code")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(20)
        .workoutFlowCard()
        .gqScreenHorizontalPadding()
        .padding(.top, 40)
    }
}

// MARK: - Squad Card View

struct SquadCardView: View {
    @Environment(\.modelContext) private var modelContext
    let squad: Squad
    let profile: UserProfile

    @State private var leaderboard: [SquadMemberStats] = []
    @State private var activeChallenge: SquadChallenge?

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(squad.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(GQColors.textPrimary)

                    HStack(spacing: 8) {
                        Label("\(squad.memberCount)/6", systemImage: "person.2.fill")
                            .font(.system(size: 12))
                            .foregroundColor(GQColors.textTertiary)

                        if squad.streakWeeks > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(GQColors.textSecondary)
                                Text("\(squad.streakWeeks)w")
                            }
                            .font(.system(size: 12))
                            .foregroundColor(GQColors.textSecondary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.textTertiary)
            }

            // Active Challenge (if any)
            if let challenge = activeChallenge {
                VStack(spacing: 8) {
                    HStack {
                        Text(challenge.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(GQColors.textPrimary)

                        Spacer()

                        Text("+\(challenge.xpReward) XP")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(GQColors.textSecondary)
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(GQColors.overlayLight)
                                .frame(height: 6)

                            Capsule()
                                .fill(GQColors.deepBlue)
                                .frame(width: geo.size.width * min(1.0, Double(challenge.currentValue) / Double(challenge.targetValue)), height: 6)
                        }
                    }
                    .frame(height: 6)

                    HStack {
                        Text("\(challenge.currentValue)/\(challenge.targetValue)")
                            .font(.system(size: 11))
                            .foregroundColor(GQColors.textTertiary)

                        Spacer()

                        Text(challenge.endDate, style: .relative)
                            .font(.system(size: 11))
                            .foregroundColor(GQColors.textTertiary)
                    }
                }
                .padding(12)
                .background(GQColors.deepBlue.opacity(0.1))
                .cornerRadius(10)
            }

            // Mini Leaderboard (top 3)
            if !leaderboard.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(leaderboard.prefix(3).enumerated()), id: \.element.id) { index, stats in
                        HStack(spacing: 10) {
                            // Rank
                            Text("\(index + 1)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(index == 0 ? GQColors.textSecondary : GQColors.textTertiary)
                                .frame(width: 20)

                            // Avatar
                            if let photoData = stats.profilePhotoData,
                               let uiImage = UIImage(data: photoData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 28, height: 28)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(GQColors.overlayLight)
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Text(String(stats.username.prefix(1)))
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(GQColors.textPrimary)
                                    )
                            }

                            Text(stats.username)
                                .font(.system(size: 13))
                                .foregroundColor(stats.userId == profile.id ? GQColors.deepBlue : GQColors.textPrimary)

                            Spacer()

                            Text("\(stats.sessionsThisWeek) sessions")
                                .font(.system(size: 12))
                                .foregroundColor(GQColors.textTertiary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(GQColors.surfaceBase)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [GQColors.overlayLight, GQColors.overlaySubtle],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .onAppear {
            loadSquadData()
        }
    }

    private func loadSquadData() {
        let service = SquadService.shared
        service.configure(modelContext: modelContext)
        leaderboard = service.getSquadLeaderboard(squadId: squad.id)
        activeChallenge = service.getActiveChallenge(squadId: squad.id)
    }
}

// MARK: - Create Squad Sheet

struct CreateSquadSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let profile: UserProfile

    @State private var squadName = ""
    @State private var weeklyTarget = 3
    @State private var goalType: WeeklyGoalType = .sessionsPerWeek

    var body: some View {
        NavigationStack {
            Form {
                Section("Squad Info") {
                    TextField("Squad Name", text: $squadName)
                }

                Section("Weekly Goal") {
                    Picker("Goal Type", selection: $goalType) {
                        ForEach(WeeklyGoalType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    Stepper("Target: \(weeklyTarget) sessions", value: $weeklyTarget, in: 1...7)
                }

                Section {
                    Text("You can invite up to 5 friends using the invite code generated after creating the squad.")
                        .font(.footnote)
                        .foregroundColor(GQColors.textTertiary)
                }
            }
            .navigationTitle("Create Squad")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createSquad()
                    }
                    .disabled(squadName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func createSquad() {
        let service = SquadService.shared
        service.configure(modelContext: modelContext)

        let goal = WeeklyGoal(type: goalType, target: weeklyTarget)
        _ = service.createSquad(name: squadName, creatorId: profile.id, weeklyGoal: goal)

        dismiss()
    }
}

// MARK: - Join Squad Sheet

struct JoinSquadSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let profile: UserProfile

    @State private var inviteCode = ""
    @State private var errorMessage: String?
    @State private var joinedSquad: Squad?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Enter Invite Code")
                        .font(.headline)
                        .foregroundColor(GQColors.textPrimary)

                    Text("Ask your friend for their squad's 6-character code")
                        .font(.subheadline)
                        .foregroundColor(GQColors.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                TextField("CODE", text: $inviteCode)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding()
                    .background(GQColors.surfaceElevated)
                    .cornerRadius(12)
                    .padding(.horizontal, 40)
                    .onChange(of: inviteCode) { _, newValue in
                        inviteCode = String(newValue.prefix(6)).uppercased()
                    }

                if let error = errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.red)
                }

                if let squad = joinedSquad {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(GQColors.textSecondary)

                        Text("Joined \(squad.name)!")
                            .font(.headline)
                            .foregroundColor(GQColors.textPrimary)
                    }
                    .padding(.top, 20)
                }

                Spacer()

                Button {
                    joinSquad()
                } label: {
                    Text("Join Squad")
                        .font(.headline)
                        .foregroundColor(GQColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(inviteCode.count == 6 ? GQColors.cardBackground : GQColors.overlayMedium)
                        .cornerRadius(GQRadius.md)
                }
                .disabled(inviteCode.count != 6)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .buttonStyle(GQInteractiveStyle())
            .gqPageBackground()
            .navigationTitle("Join Squad")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func joinSquad() {
        let service = SquadService.shared
        service.configure(modelContext: modelContext)

        let result = service.joinSquad(inviteCode: inviteCode, userId: profile.id)

        if result.success {
            joinedSquad = result.squad
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1500))
                dismiss()
            }
        } else {
            errorMessage = result.error
        }
    }
}

// MARK: - Squad Detail View

struct SquadDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let squad: Squad
    let profile: UserProfile

    @State private var leaderboard: [SquadMemberStats] = []
    @State private var activeChallenge: SquadChallenge?
    @State private var showingCreateChallenge = false
    @State private var showingInviteCode = false
    @State private var showingLeaveConfirm = false

    var isCreator: Bool {
        squad.creatorId == profile.id
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Squad Header
                    VStack(spacing: 12) {
                        Text(squad.name)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(GQColors.textPrimary)

                        HStack(spacing: 16) {
                            StatBadge(value: "\(squad.memberCount)/6", label: "Members")
                            StatBadge(value: "\(squad.streakWeeks)w", label: "Streak")
                            StatBadge(value: "\(squad.weeklyGoal.target)", label: "Goal")
                        }
                    }
                    .padding(.top, 12)

                    // Invite Code Section
                    VStack(spacing: 8) {
                        Text("INVITE CODE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(GQColors.textTertiary)
                            .tracking(0.5)

                        Text(squad.inviteCode)
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundColor(GQColors.textPrimary)

                        Button {
                            UIPasteboard.general.string = squad.inviteCode
                            showingInviteCode = true
                        } label: {
                            Label("Copy Code", systemImage: "doc.on.doc")
                                .font(.system(size: 13))
                                .foregroundColor(GQColors.textSecondary)
                        }
                    }
                    .padding(20)
                    .background(GQColors.surfaceBase)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [GQColors.overlayLight, GQColors.overlaySubtle],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )

                    // Squad Leaderboard Link
                    NavigationLink {
                        SquadLeaderboardView(squad: squad, profile: profile)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(GQColors.deepBlue)
                            Text("Volume Leaderboard")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(GQColors.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(GQColors.textSecondary)
                        }
                        .padding(16)
                        .background(GQColors.surfaceBase)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(GQColors.borderDefault, lineWidth: 1)
                        )
                    }

                    // Active Challenge
                    if let challenge = activeChallenge {
                        ActiveChallengeCard(challenge: challenge)
                    } else if isCreator {
                        Button {
                            showingCreateChallenge = true
                        } label: {
                            HStack {
                                Image(systemName: "flag.fill")
                                Text("Start Weekly Challenge")
                            }
                            .font(.headline)
                            .foregroundColor(GQColors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(GQColors.deepBlue.opacity(0.12))
                            .cornerRadius(GQRadius.md)
                        }
                        .buttonStyle(GQInteractiveStyle())
                    }

                    // Leaderboard
                    VStack(alignment: .leading, spacing: 12) {
                        Text("THIS WEEK'S LEADERBOARD")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(GQColors.textTertiary)
                            .tracking(0.5)

                        ForEach(Array(leaderboard.enumerated()), id: \.element.id) { index, stats in
                            LeaderboardRow(
                                rank: index + 1,
                                stats: stats,
                                isCurrentUser: stats.userId == profile.id
                            )
                        }
                    }
                    .padding(16)
                    .background(GQColors.surfaceBase)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [GQColors.overlayLight, GQColors.overlaySubtle],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )

                    // Leave/Delete Squad
                    if isCreator {
                        Button(role: .destructive) {
                            showingLeaveConfirm = true
                        } label: {
                            Text("Delete Squad")
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                    } else {
                        Button(role: .destructive) {
                            showingLeaveConfirm = true
                        } label: {
                            Text("Leave Squad")
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
            }
            .gqPageBackground()
            .navigationTitle("Squad")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingCreateChallenge) {
                CreateChallengeSheet(squad: squad)
            }
            .alert("Code Copied!", isPresented: $showingInviteCode) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Share this code with friends to invite them to your squad.")
            }
            .alert(isCreator ? "Delete Squad?" : "Leave Squad?", isPresented: $showingLeaveConfirm) {
                Button("Cancel", role: .cancel) { }
                Button(isCreator ? "Delete" : "Leave", role: .destructive) {
                    leaveOrDeleteSquad()
                }
            } message: {
                Text(isCreator ? "This will permanently delete the squad for all members." : "You can rejoin later with the invite code.")
            }
            .onAppear {
                loadSquadData()
            }
        }
    }

    private func loadSquadData() {
        let service = SquadService.shared
        service.configure(modelContext: modelContext)
        leaderboard = service.getSquadLeaderboard(squadId: squad.id)
        activeChallenge = service.getActiveChallenge(squadId: squad.id)
    }

    private func leaveOrDeleteSquad() {
        let service = SquadService.shared
        service.configure(modelContext: modelContext)

        if isCreator {
            _ = service.deleteSquad(squadId: squad.id, userId: profile.id)
        } else {
            _ = service.leaveSquad(squadId: squad.id, userId: profile.id)
        }

        dismiss()
    }
}

// MARK: - Supporting Views

struct StatBadge: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(GQColors.textPrimary)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(width: 70)
    }
}

struct LeaderboardRow: View {
    let rank: Int
    let stats: SquadMemberStats
    let isCurrentUser: Bool

    var rankColor: Color {
        switch rank {
        case 1: return GQColors.textSecondary
        case 2: return GQColors.textTertiary
        case 3: return GQColors.textSecondary
        default: return GQColors.textPrimary.opacity(0.5)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Rank
            Text("\(rank)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(rankColor)
                .frame(width: 24)

            // Avatar
            if let photoData = stats.profilePhotoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(GQColors.overlayLight)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(stats.username.prefix(1)))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(GQColors.textPrimary)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(stats.username)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isCurrentUser ? GQColors.deepBlue : GQColors.textPrimary)

                Text("Lv. \(stats.level)")
                    .font(.system(size: 11))
                    .foregroundColor(GQColors.textTertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(stats.sessionsThisWeek)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(GQColors.textPrimary)

                Text("sessions")
                    .font(.system(size: 10))
                    .foregroundColor(GQColors.textTertiary)
            }
        }
        .padding(.vertical, 6)
    }
}

struct ActiveChallengeCard: View {
    let challenge: SquadChallenge

    var progress: Double {
        guard challenge.targetValue > 0 else { return 0 }
        return min(1.0, Double(challenge.currentValue) / Double(challenge.targetValue))
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ACTIVE CHALLENGE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(GQColors.deepBlue.opacity(0.8))
                        .tracking(0.5)

                    Text(challenge.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(GQColors.textPrimary)
                }

                Spacer()

                Text("+\(challenge.xpReward) XP")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(GQColors.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(GQColors.textSecondary.opacity(0.15))
                    .cornerRadius(8)
            }

            Text(challenge.challengeDescription)
                .font(.system(size: 13))
                .foregroundColor(GQColors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Progress
            VStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(GQColors.overlayLight)
                            .frame(height: 10)

                        Capsule()
                            .fill(GQGradients.primary)
                            .frame(width: geo.size.width * progress, height: 10)
                    }
                }
                .frame(height: 10)

                HStack {
                    Text("\(challenge.currentValue)/\(challenge.targetValue)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        Text(challenge.endDate, style: .relative)
                    }
                    .font(.system(size: 11))
                    .foregroundColor(GQColors.textTertiary)
                }
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [GQColors.deepBlue.opacity(0.2), GQColors.deepBlue.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(GQColors.deepBlue.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Create Challenge Sheet

struct CreateChallengeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let squad: Squad

    @State private var title = "Weekly Warrior"
    @State private var description = "Complete workouts together as a squad"
    @State private var targetValue = 15
    @State private var xpReward = 100

    var body: some View {
        NavigationStack {
            Form {
                Section("Challenge Info") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description)
                }

                Section("Goal") {
                    Stepper("Target: \(targetValue) total sessions", value: $targetValue, in: 5...50, step: 5)
                    Stepper("XP Reward: \(xpReward)", value: $xpReward, in: 50...500, step: 25)
                }

                Section {
                    Text("Challenge runs for 1 week. All squad members contribute to the shared goal.")
                        .font(.footnote)
                        .foregroundColor(GQColors.textTertiary)
                }
            }
            .navigationTitle("New Challenge")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        createChallenge()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func createChallenge() {
        let service = SquadService.shared
        service.configure(modelContext: modelContext)

        _ = service.startChallenge(
            squadId: squad.id,
            title: title,
            description: description,
            targetValue: targetValue,
            xpReward: xpReward
        )

        dismiss()
    }
}

#Preview {
    SquadView(profile: UserProfile(name: "Ben", username: "ben"))
        .environmentObject(FeatureFlags.shared)
}
