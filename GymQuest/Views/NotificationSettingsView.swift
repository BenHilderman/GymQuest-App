//
//  NotificationSettingsView.swift
//  GymQuest
//
//  Settings view for workout reminder notifications.
//

import SwiftUI

struct NotificationSettingsView: View {
    @StateObject private var notificationService = NotificationService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if !notificationService.isAuthorized {
                    // Authorization needed
                    VStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(GQColors.deepBlue.opacity(0.1))
                                .frame(width: 40, height: 40)
                            Image(systemName: "bell.badge")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(GQColors.deepBlue.opacity(0.7))
                        }

                        VStack(spacing: 4) {
                            Text("Enable Notifications")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(GQColors.textPrimary)
                            Text("Get reminded to work out and stay consistent")
                                .font(.system(size: 13))
                                .foregroundColor(GQColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }

                        Button {
                            Task {
                                _ = await notificationService.requestAuthorization()
                            }
                        } label: {
                            Text("Allow Notifications")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(20)
                    .workoutFlowCard()
                    .gqScreenHorizontalPadding()
                } else {
                    // MARK: Reminders
                    VStack(alignment: .leading, spacing: 10) {
                        Text("REMINDERS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(GQColors.textTertiary)
                            .tracking(0.8)

                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Workout Reminders")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(GQColors.textPrimary)
                                Text("Daily reminder to keep training")
                                    .font(.system(size: 11))
                                    .foregroundColor(GQColors.textTertiary)
                            }
                            Spacer()
                            Toggle("", isOn: $notificationService.reminderEnabled)
                                .labelsHidden()
                                .tint(GQColors.deepBlue)
                                .onChange(of: notificationService.reminderEnabled) { _, _ in
                                    notificationService.saveSettings()
                                }
                        }
                    }
                    .padding(14)
                    .workoutFlowCard()
                    .gqScreenHorizontalPadding()

                    if notificationService.reminderEnabled {
                        // MARK: Time
                        VStack(alignment: .leading, spacing: 10) {
                            Text("TIME")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(GQColors.textTertiary)
                                .tracking(0.8)

                            DatePicker(
                                "Reminder Time",
                                selection: $notificationService.reminderTime,
                                displayedComponents: .hourAndMinute
                            )
                            .font(.system(size: 14))
                            .onChange(of: notificationService.reminderTime) { _, _ in
                                notificationService.saveSettings()
                            }
                        }
                        .padding(14)
                        .workoutFlowCard()
                        .gqScreenHorizontalPadding()

                        // MARK: Days
                        VStack(alignment: .leading, spacing: 10) {
                            Text("DAYS")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(GQColors.textTertiary)
                                .tracking(0.8)

                            Text("Remind me on these days:")
                                .font(.system(size: 13))
                                .foregroundColor(GQColors.textSecondary)

                            HStack(spacing: 6) {
                                ForEach(1...7, id: \.self) { day in
                                    DayButton(
                                        day: day,
                                        isSelected: notificationService.isDayEnabled(day),
                                        action: {
                                            notificationService.toggleDay(day)
                                        }
                                    )
                                }
                            }
                        }
                        .padding(14)
                        .workoutFlowCard()
                        .gqScreenHorizontalPadding()

                        // MARK: Update
                        Button {
                            notificationService.scheduleReminders()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Update Reminders")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .gqScreenHorizontalPadding()

                        // Summary
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                                .foregroundColor(GQColors.textTertiary)
                            let daysText = notificationService.reminderDays.isEmpty
                                ? "No days selected"
                                : "\(notificationService.reminderDays.count) day\(notificationService.reminderDays.count > 1 ? "s" : "") per week"
                            let timeText = notificationService.reminderTime.formatted(date: .omitted, time: .shortened)
                            Text("\(daysText) at \(timeText)")
                                .font(.system(size: 11))
                                .foregroundColor(GQColors.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.top, 12)
            .padding(.bottom, GQLayout.pageBottom)
        }
        .scrollContentBackground(.hidden)
        .gqPageBackground()
        .navigationTitle("Notifications")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            notificationService.checkAuthorizationStatus()
        }
    }
}

struct DayButton: View {
    let day: Int
    let isSelected: Bool
    let action: () -> Void

    var dayName: String {
        NotificationService.weekdayNames[day - 1]
    }

    var body: some View {
        Button(action: action) {
            Text(String(dayName.prefix(1)))
                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : GQColors.textSecondary)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(
                    Circle()
                        .fill(isSelected ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(GQColors.surfaceSecondary))
                )
        }
        .buttonStyle(GQInteractiveStyle())
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
