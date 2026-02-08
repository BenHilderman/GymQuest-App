//
//  IntegrationsView.swift
//  GymQuest
//
//  Central hub for managing fitness integrations: Apple Health, WHOOP, Strava.
//  Clean, non-overwhelming design with expandable cards for each service.
//

import SwiftUI
import SwiftData

struct IntegrationsView: View {
    @EnvironmentObject var featureFlags: FeatureFlags
    @Environment(\.modelContext) private var modelContext

    let profile: UserProfile

    @StateObject private var integrationManager = IntegrationManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Status header
                IntegrationStatusHeader(
                    activeCount: integrationManager.activeSourceCount
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Apple Health
                IntegrationCard(
                    icon: "heart.fill",
                    name: "Apple Health",
                    description: "Steps, heart rate, sleep, workouts",
                    iconColor: .red,
                    isConnected: integrationManager.healthKit.isAuthorized && featureFlags.healthKitImportEnabled,
                    isSyncing: integrationManager.healthKit.isSyncing,
                    lastSync: integrationManager.healthKit.lastSyncDate,
                    dataPoints: appleHealthDataPoints
                ) {
                    NavigationLink {
                        HealthKitSettingsView(profile: profile)
                    } label: {
                        Text(featureFlags.healthKitImportEnabled ? "Settings" : "Connect")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule().fill(featureFlags.healthKitImportEnabled ? Color(white: 0.15) : GQColors.vividPurple)
                            )
                    }
                }
                .padding(.horizontal, 16)

                // WHOOP
                IntegrationCard(
                    icon: "waveform.path.ecg",
                    name: "WHOOP",
                    description: "Recovery, strain, sleep quality",
                    iconColor: GQColors.cyanSpark,
                    isConnected: integrationManager.whoop.isConnected,
                    isSyncing: integrationManager.whoop.isSyncing,
                    lastSync: integrationManager.whoop.lastSyncDate,
                    dataPoints: whoopDataPoints
                ) {
                    Button {
                        if integrationManager.whoop.isConnected {
                            integrationManager.whoop.disconnect()
                            featureFlags.whoopEnabled = false
                        } else {
                            // Would trigger OAuth flow
                            featureFlags.whoopEnabled = true
                        }
                    } label: {
                        Text(integrationManager.whoop.isConnected ? "Disconnect" : "Connect")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(integrationManager.whoop.isConnected ? GQColors.coralRed : .white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule().fill(integrationManager.whoop.isConnected ? Color(white: 0.15) : GQColors.cyanSpark)
                            )
                    }
                }
                .padding(.horizontal, 16)

                // Strava
                IntegrationCard(
                    icon: "figure.run",
                    name: "Strava",
                    description: "Runs, rides, GPS activities",
                    iconColor: Color(hex: "FC4C02"),
                    isConnected: integrationManager.strava.isConnected,
                    isSyncing: integrationManager.strava.isSyncing,
                    lastSync: integrationManager.strava.lastSyncDate,
                    dataPoints: stravaDataPoints
                ) {
                    NavigationLink {
                        StravaSettingsView(profile: profile)
                    } label: {
                        Text(integrationManager.strava.isConnected ? "Settings" : "Connect")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule().fill(integrationManager.strava.isConnected ? Color(white: 0.15) : Color(hex: "FC4C02"))
                            )
                    }
                }
                .padding(.horizontal, 16)

                // Gravl info card
                GravlInfoCard()
                    .padding(.horizontal, 16)

                // Sync all button
                if integrationManager.hasAnyConnection {
                    Button {
                        Task {
                            await integrationManager.syncAll(userId: profile.id)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Sync All Sources")
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .padding(.horizontal, 16)
                }

                // Privacy notice
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 12))
                            .foregroundColor(GQColors.success)
                        Text("Your data stays on your device")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(GQColors.textSecondary)
                    }
                    Text("Health data is encrypted and never sold. You control which sources are connected.")
                        .font(.system(size: 11))
                        .foregroundColor(GQColors.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .padding(.top, 8)

                Spacer(minLength: 40)
            }
            .padding(.bottom, 120)
        }
        .scrollContentBackground(.hidden)
        .background(GQColors.background.ignoresSafeArea())
        .navigationTitle("Integrations")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Data Points

    private var appleHealthDataPoints: [IntegrationDataPoint] {
        guard integrationManager.healthKit.isAuthorized else { return [] }
        let hk = integrationManager.healthKit
        var points: [IntegrationDataPoint] = []
        if hk.steps > 0 { points.append(.init(label: "Steps", value: "\(hk.steps.formatted())")) }
        if hk.activeCalories > 0 { points.append(.init(label: "Calories", value: "\(hk.activeCalories) kcal")) }
        if hk.sleepHours > 0 { points.append(.init(label: "Sleep", value: String(format: "%.1fh", hk.sleepHours))) }
        if hk.restingHeartRate > 0 { points.append(.init(label: "RHR", value: "\(hk.restingHeartRate) bpm")) }
        return points
    }

    private var whoopDataPoints: [IntegrationDataPoint] {
        guard integrationManager.whoop.isConnected else { return [] }
        var points: [IntegrationDataPoint] = []
        if let recovery = integrationManager.whoop.latestRecovery {
            points.append(.init(label: "Recovery", value: "\(Int(recovery.score.recoveryScore))%"))
        }
        if let strain = integrationManager.whoop.latestStrain, let score = strain.score {
            points.append(.init(label: "Strain", value: String(format: "%.1f", score.strain)))
        }
        if let sleep = integrationManager.whoop.latestSleep, let score = sleep.score {
            points.append(.init(label: "Sleep", value: String(format: "%.1fh", score.stageSummary.totalSleepHours)))
        }
        return points
    }

    private var stravaDataPoints: [IntegrationDataPoint] {
        guard integrationManager.strava.isConnected else { return [] }
        var points: [IntegrationDataPoint] = []
        if integrationManager.strava.importedActivityCount > 0 {
            points.append(.init(label: "Activities", value: "\(integrationManager.strava.importedActivityCount)"))
        }
        if let athlete = integrationManager.strava.athleteProfile {
            points.append(.init(label: "Athlete", value: athlete.displayName))
        }
        return points
    }
}

// MARK: - Integration Data Point

struct IntegrationDataPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

// MARK: - Status Header

private struct IntegrationStatusHeader: View {
    let activeCount: Int

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(activeCount > 0 ? GQColors.success.opacity(0.15) : Color(white: 0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: activeCount > 0 ? "checkmark.circle.fill" : "link.badge.plus")
                    .font(.system(size: 20))
                    .foregroundColor(activeCount > 0 ? GQColors.success : GQColors.textTertiary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(activeCount > 0 ? "\(activeCount) Source\(activeCount > 1 ? "s" : "") Connected" : "No Sources Connected")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text(activeCount > 0 ? "Your data is syncing" : "Connect a device to get started")
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textSecondary)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

// MARK: - Integration Card

private struct IntegrationCard<Action: View>: View {
    let icon: String
    let name: String
    let description: String
    let iconColor: Color
    let isConnected: Bool
    let isSyncing: Bool
    let lastSync: Date?
    let dataPoints: [IntegrationDataPoint]
    @ViewBuilder let action: Action

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 14) {
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(iconColor.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundColor(iconColor)
                    }

                    // Name & status
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        Text(isConnected ? "Connected" : description)
                            .font(.system(size: 12))
                            .foregroundColor(isConnected ? GQColors.success : GQColors.textTertiary)
                    }

                    Spacer()

                    if isSyncing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        // Connection indicator
                        Circle()
                            .fill(isConnected ? GQColors.success : Color(white: 0.2))
                            .frame(width: 8, height: 8)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)
            .padding(16)

            // Expanded content
            if isExpanded {
                VStack(spacing: 12) {
                    Divider()
                        .background(Color.white.opacity(0.06))

                    // Data points
                    if !dataPoints.isEmpty {
                        HStack(spacing: 16) {
                            ForEach(dataPoints) { point in
                                VStack(spacing: 4) {
                                    Text(point.value)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                    Text(point.label)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(GQColors.textTertiary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // Last sync
                    if let lastSync = lastSync {
                        HStack {
                            Text("Last synced")
                                .font(.system(size: 12))
                                .foregroundColor(GQColors.textTertiary)
                            Spacer()
                            Text(lastSync, style: .relative)
                                .font(.system(size: 12))
                                .foregroundColor(GQColors.textSecondary)
                        }
                        .padding(.horizontal, 16)
                    }

                    // Action button
                    action
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                }
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isConnected ? iconColor.opacity(0.2) : Color.white.opacity(0.06),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - Gravl Info Card

private struct GravlInfoCard: View {
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(GQColors.electricGold.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 18))
                    .foregroundColor(GQColors.electricGold)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Gravl")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text("Sync via Apple Health")
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textTertiary)
            }

            Spacer()

            Text("Auto")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(GQColors.electricGold)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(GQColors.electricGold.opacity(0.15))
                )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

#Preview {
    NavigationStack {
        IntegrationsView(profile: UserProfile(name: "Ben", username: "ben"))
            .environmentObject(FeatureFlags.shared)
    }
    .preferredColorScheme(.dark)
}
