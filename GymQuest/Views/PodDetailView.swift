//
//  PodDetailView.swift
//  GymQuest
//
//  Pod detail screen showing members, check-ins, and lifecycle state.
//

import SwiftUI
import SwiftData

struct PodDetailView: View {
    let podId: UUID
    let profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var allPods: [Pod]
    @Query private var allPodMemberships: [PodMembership]
    @Query(sort: \PodCheckIn.createdAt, order: .reverse) private var allCheckIns: [PodCheckIn]
    @Query private var allMomentumStates: [UserMomentumState]
    @Query private var allProfiles: [UserProfile]

    @State private var showLeaveConfirmation = false

    // MARK: - Computed Properties

    private var pod: Pod? {
        allPods.first { $0.id == podId }
    }

    private var memberships: [PodMembership] {
        allPodMemberships.filter { $0.podId == podId }
    }

    private var recentCheckIns: [PodCheckIn] {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return allCheckIns.filter { $0.podId == podId && $0.createdAt >= sevenDaysAgo }
    }

    private var memberProfiles: [UserProfile] {
        let memberUserIds = Set(memberships.map(\.userId))
        return allProfiles.filter { memberUserIds.contains($0.id) }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if let pod {
                ScrollView {
                    VStack(spacing: GQSpacing.lg) {
                        podHeader(pod)
                        checkInButtons(pod)
                        memberList(pod)
                        checkInHistory
                        lifecycleSection(pod)
                        leaveButton(pod)
                    }
                    .padding(.horizontal, GQSpacing.lg)
                    .padding(.vertical, GQSpacing.md)
                }
                .gqPageBackground()
                .navigationTitle(pod.name)
                .navigationBarTitleDisplayMode(.inline)
            } else {
                ContentUnavailableView(
                    "Pod Not Found",
                    systemImage: "person.3.fill",
                    description: Text("This pod may have been removed.")
                )
            }
        }
        .alert("Leave Pod", isPresented: $showLeaveConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Leave", role: .destructive) {
                PodService.shared.leavePod(podId: podId, userId: profile.id)
                dismiss()
            }
        } message: {
            Text("Are you sure you want to leave this pod? You can rejoin later if there's space.")
        }
    }

    // MARK: - Pod Header

    @ViewBuilder
    private func podHeader(_ pod: Pod) -> some View {
        VStack(spacing: GQSpacing.sm) {
            HStack(spacing: GQSpacing.md) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(GQGradients.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(pod.name)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(GQColors.textPrimary)

                    Text("\(pod.memberCount) members")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(GQColors.textSecondary)
                }

                Spacer()

                lifecycleBadge(pod.lifecycleState)
            }

            HStack(spacing: GQSpacing.lg) {
                statPill(icon: "flame.fill", value: "\(pod.streakWeeks)w", label: "Streak")
                statPill(icon: "target", value: "\(pod.weeklyWorkoutTarget)/wk", label: "Target")
                statPill(icon: "calendar", value: pod.schedulePreference, label: "Schedule")
            }
        }
        .padding(GQSpacing.lg)
        .homeSocialCard()
    }

    @ViewBuilder
    private func lifecycleBadge(_ state: PodLifecycleState) -> some View {
        let (color, icon): (Color, String) = {
            switch state {
            case .forming: return (GQColors.deepBlue, "sparkle")
            case .active: return (GQColors.success, "checkmark.circle.fill")
            case .stale: return (GQColors.warning, "exclamationmark.triangle.fill")
            case .dead: return (GQColors.error, "xmark.circle.fill")
            }
        }()

        Label(state.rawValue, systemImage: icon)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
    }

    @ViewBuilder
    private func statPill(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundColor(GQColors.textPrimary)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Check-In Buttons

    @ViewBuilder
    private func checkInButtons(_ pod: Pod) -> some View {
        VStack(alignment: .leading, spacing: GQSpacing.sm) {
            Text("Check In")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(GQColors.textPrimary)

            HStack(spacing: GQSpacing.sm) {
                ForEach(PodCheckInType.allCases, id: \.rawValue) { type in
                    Button {
                        HapticManager.shared.impact(.medium)
                        PodService.shared.checkIn(podId: pod.id, userId: profile.id, type: type)
                    } label: {
                        VStack(spacing: 4) {
                            Text(type.emoji)
                                .font(.system(size: 20))
                            Text(type.rawValue)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(GQColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(GQColors.surfaceElevated, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(GQSpacing.lg)
        .homeSocialCard()
    }

    // MARK: - Member List

    @ViewBuilder
    private func memberList(_ pod: Pod) -> some View {
        VStack(alignment: .leading, spacing: GQSpacing.sm) {
            Text("Members")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(GQColors.textPrimary)

            ForEach(memberProfiles, id: \.id) { memberProfile in
                memberRow(memberProfile)
            }
        }
        .padding(GQSpacing.lg)
        .homeSocialCard()
    }

    @ViewBuilder
    private func memberRow(_ memberProfile: UserProfile) -> some View {
        let membership = memberships.first { $0.userId == memberProfile.id }
        let momentum = allMomentumStates.first { $0.userId == memberProfile.id }

        HStack(spacing: GQSpacing.md) {
            // Avatar
            Circle()
                .fill(GQGradients.primary)
                .frame(width: 36, height: 36)
                .overlay {
                    Text(String(memberProfile.name.prefix(1)).uppercased())
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(memberProfile.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)

                    if membership?.podRole == .leader {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                    }
                }

                HStack(spacing: GQSpacing.sm) {
                    if let completed = momentum?.currentWeekCompleted {
                        Label("\(completed) this week", systemImage: "dumbbell.fill")
                            .font(.system(size: 11))
                            .foregroundColor(GQColors.textSecondary)
                    }

                    if let lastDate = momentum?.lastWorkoutDate {
                        Text(lastDate, style: .relative)
                            .font(.system(size: 11))
                            .foregroundColor(GQColors.textTertiary)
                    }
                }
            }

            Spacer()

            if let weeklyCount = membership?.weeklyCompletedWorkouts {
                Text("\(weeklyCount)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(GQGradients.primary)
            }
        }
        .padding(.vertical, GQSpacing.xs)
    }

    // MARK: - Check-In History

    @ViewBuilder
    private var checkInHistory: some View {
        if !recentCheckIns.isEmpty {
            VStack(alignment: .leading, spacing: GQSpacing.sm) {
                Text("Recent Activity")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)

                ForEach(recentCheckIns.prefix(15), id: \.id) { checkIn in
                    checkInRow(checkIn)
                }
            }
            .padding(GQSpacing.lg)
            .homeSocialCard()
        }
    }

    @ViewBuilder
    private func checkInRow(_ checkIn: PodCheckIn) -> some View {
        let memberName = allProfiles.first { $0.id == checkIn.userId }?.name ?? "Unknown"
        let checkInType = PodCheckInType(rawValue: checkIn.type)

        HStack(spacing: GQSpacing.sm) {
            Text(checkInType?.emoji ?? "")
                .font(.system(size: 16))

            Text(memberName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(GQColors.textPrimary)

            Text(checkInType?.rawValue ?? checkIn.type)
                .font(.system(size: 12))
                .foregroundColor(GQColors.textSecondary)

            Spacer()

            Text(checkIn.createdAt, style: .relative)
                .font(.system(size: 11))
                .foregroundColor(GQColors.textTertiary)
        }
        .padding(.vertical, GQSpacing.xs)
    }

    // MARK: - Lifecycle Section

    @ViewBuilder
    private func lifecycleSection(_ pod: Pod) -> some View {
        switch pod.lifecycleState {
        case .stale:
            VStack(spacing: GQSpacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.orange)

                Text("Your pod has been quiet")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)

                Text("Check in or complete a workout to keep your pod's streak alive. Inactive pods eventually dissolve.")
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(GQSpacing.lg)
            .homeSocialCard()

        case .dead:
            VStack(spacing: GQSpacing.sm) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(GQColors.error)

                Text("Time for a fresh start")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)

                Text("Life happens — this pod went quiet. No worries, let's find you a new team.")
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textSecondary)
                    .multilineTextAlignment(.center)

                Button {
                    // Navigate to clubs to find a new pod
                    NotificationCenter.default.post(name: .navigateToFeedTab, object: FeedTab.clubs)
                } label: {
                    Text("Find a New Pod")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(GQGradients.primary, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            .padding(GQSpacing.lg)
            .homeSocialCard()

        default:
            EmptyView()
        }
    }

    // MARK: - Leave Button

    @ViewBuilder
    private func leaveButton(_ pod: Pod) -> some View {
        Button {
            showLeaveConfirmation = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 13))
                Text("Leave Pod")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(GQColors.error)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(GQColors.error.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .padding(.bottom, GQSpacing.lg)
    }
}
