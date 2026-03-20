//
//  FeedSocialView.swift
//  GymQuest
//
//  Extracted from FeedView.swift for modularization.
//

import SwiftUI
import SwiftData
import AVKit
import MapKit
import PhotosUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Working Out Now Row

struct WorkingOutNowRow: View {
    @EnvironmentObject var appState: AppState
    var recentFriendCount: Int = 0

    private let socialService = SocialActivityService.shared

    @State private var selectedFriend: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Section header
            HStack(spacing: 6) {
                Circle()
                    .fill(GQColors.success)
                    .frame(width: 7, height: 7)
                Text("ACTIVE NOW")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(GQColors.textTertiary)
                Text("\u{00B7}")
                    .foregroundColor(GQColors.textTertiary)
                Text("\(socialService.friendsActiveToday) friends today")
                    .font(.system(size: 11))
                    .foregroundColor(GQColors.textTertiary)
            }

            // Friend avatars
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(socialService.activeFriends) { friend in
                        Button {
                            selectedFriend = friend.name
                        } label: {
                            VStack(spacing: 3) {
                                ZStack {
                                    Circle()
                                        .fill(GQGradients.primary)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Text(friend.avatarInitial)
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white)
                                        )

                                    if friend.isLive {
                                        Circle()
                                            .fill(GQColors.success)
                                            .frame(width: 8, height: 8)
                                            .overlay(Circle().stroke(GQColors.surfaceBase, lineWidth: 1.5))
                                            .offset(x: 11, y: 11)
                                    }
                                }

                                Text(friend.name)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(GQColors.textPrimary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 2)
            }
        }
        .padding(.vertical, 4)
        .sheet(item: Binding<WorkoutStoryItem?>(
            get: {
                guard let name = selectedFriend,
                      let friend = socialService.activeFriends.first(where: { $0.name == name })
                else { return nil }
                return WorkoutStoryItem(name: friend.name, type: friend.workoutType, minutes: friend.minutesElapsed, workout: "\(friend.workoutType) Day", exercises: friend.exercise, gymName: friend.gymName, gymArea: friend.gymArea, gymCoordinate: friend.gymCoordinate)
            },
            set: { item in
                selectedFriend = item?.name
            }
        )) { friend in
            WorkoutStorySheet(friend: friend)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Workout Story Sheet

struct WorkoutStoryItem: Identifiable {
    let id = UUID()
    let name: String
    let type: String
    let minutes: Int
    let workout: String
    let exercises: String
    let gymName: String?
    let gymArea: String?
    let gymCoordinate: (lat: Double, lng: Double)?
}

struct WorkoutStorySheet: View {
    let friend: WorkoutStoryItem
    @Environment(\.dismiss) private var dismiss
    @State private var showJoinToast = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    workoutInfoCard
                    if friend.gymName != nil {
                        locationSection
                    }
                    Spacer(minLength: 40)
                }
            }

            joinConfirmationToast
        }
        .gqPageBackground()
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(GQColors.textSecondary.opacity(0.5), lineWidth: 2)
                    .frame(width: 52, height: 52)

                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(friend.name.prefix(1)))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(friend.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                HStack(spacing: 6) {
                    Circle()
                        .fill(GQColors.deepBlue)
                        .frame(width: 7, height: 7)
                    Text("Working out now · \(friend.minutes)m")
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textTertiary)
                }
                if let gymName = friend.gymName {
                    HStack(spacing: 4) {
                        Text("📍")
                            .font(.system(size: 11))
                        Text(gymName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(GQColors.textSecondary)
                        if let area = friend.gymArea {
                            Text("·")
                                .font(.system(size: 12))
                                .foregroundColor(GQColors.textTertiary)
                            Text(area)
                                .font(.system(size: 12))
                                .foregroundColor(GQColors.textTertiary)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    // MARK: - Workout Info Card

    @ViewBuilder
    private var workoutInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "figure.run")
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.textSecondary)
                Text(friend.workout)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            Divider()
                .overlay(Color.white.opacity(0.08))

            VStack(alignment: .leading, spacing: 8) {
                ForEach(friend.exercises.components(separatedBy: ", "), id: \.self) { exercise in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 5, height: 5)
                        Text(exercise)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }

            Divider()
                .overlay(Color.white.opacity(0.08))

            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textSecondary)
                    Text("\(friend.minutes) min")
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textTertiary)
                }
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textSecondary)
                    Text(friend.type)
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textTertiary)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Location Section

    @ViewBuilder
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gym Location")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text("\(friend.name) is sharing")
                        .font(.system(size: 12))
                        .foregroundColor(GQColors.textTertiary)
                }
                Spacer()
            }

            if let coord = friend.gymCoordinate {
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: coord.lat, longitude: coord.lng),
                    span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
                ))) {
                    Marker(friend.gymName ?? "Gym", coordinate: CLLocationCoordinate2D(latitude: coord.lat, longitude: coord.lng))
                        .tint(GQColors.textSecondary)
                }
                .frame(height: 140)
                .cornerRadius(12)
                .allowsHitTesting(false)
            }

            Button {
                #if canImport(UIKit)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                #endif
                withAnimation(.spring(response: 0.4)) {
                    showJoinToast = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    dismiss()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 15, weight: .semibold))
                    Text("On my way!")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [GQColors.deepBlue, GQColors.textSecondary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Join Confirmation Toast

    @ViewBuilder
    private var joinConfirmationToast: some View {
        if showJoinToast {
            VStack {
                Spacer()
                Text("🏃 On my way! \(friend.name) was notified")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                            .overlay(
                                Capsule()
                                    .stroke(GQColors.textSecondary.opacity(0.3), lineWidth: 0.5)
                            )
                    )
                    .padding(.bottom, 30)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}


// MARK: - PR Feed View

struct PRFeedView: View {
    let prMoments: [PRMoment]
    let profile: UserProfile

    var body: some View {
        if prMoments.isEmpty {
            VStack(spacing: 16) {
                Spacer().frame(height: 60)
                Image(systemName: "trophy")
                    .font(.system(size: 50))
                    .foregroundColor(GQColors.textSecondary.opacity(0.5))

                Text("No PRs yet")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("Keep training and your PRs will show up here")
                    .font(.subheadline)
                    .foregroundColor(GQColors.textTertiary)
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .padding()
        } else {
            LazyVStack(spacing: 12) {
                ForEach(prMoments) { pr in
                    PRFeedCard(prMoment: pr)
                }
            }
            .padding(16)
        }
    }
}

struct PRFeedCard: View {
    let prMoment: PRMoment

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(GQColors.textSecondary.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: "trophy.fill")
                    .font(.title2)
                    .foregroundColor(GQColors.textSecondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(prMoment.prType.rawValue.uppercased())
                    .font(GQTypography.sectionHeader)
                    .foregroundColor(GQColors.textSecondary.opacity(0.8))
                    .tracking(0.5)

                if let exercise = prMoment.exerciseName {
                    Text(exercise)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }

                Text(prMoment.value)
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.textSecondary)

                Text(prMoment.createdAt.timeAgoDisplay())
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textTertiary)
            }

            Spacer()

            if let improvement = prMoment.improvement {
                Text(improvement)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(GQColors.textSecondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}


