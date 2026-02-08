//
//  NotificationSettingsView.swift
//  GymQuest
//
//  Settings view for workout reminder notifications.
//

import SwiftUI

struct NotificationSettingsView: View {
    @StateObject private var notificationService = NotificationService.shared

    @State private var showingTimePicker = false

    var body: some View {
        Form {
            Section {
                if !notificationService.isAuthorized {
                    // Authorization needed
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "bell.badge")
                                .font(.title2)
                                .foregroundColor(GQColors.sunsetOrange)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Enable Notifications")
                                    .font(.headline)
                                Text("Get reminded to work out")
                                    .font(.caption)
                                    .foregroundColor(GQColors.textTertiary)
                            }
                        }

                        Button {
                            Task {
                                _ = await notificationService.requestAuthorization()
                            }
                        } label: {
                            Text("Allow Notifications")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(GQColors.vividPurple)
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 8)
                } else {
                    Toggle(isOn: $notificationService.reminderEnabled) {
                        Label("Workout Reminders", systemImage: "bell.fill")
                    }
                    .onChange(of: notificationService.reminderEnabled) { _, _ in
                        notificationService.saveSettings()
                    }
                }
            } header: {
                Text("Reminders")
            } footer: {
                Text("Get a daily reminder to keep your training consistent.")
            }

            if notificationService.isAuthorized && notificationService.reminderEnabled {
                Section {
                    // Time picker
                    DatePicker(
                        "Reminder Time",
                        selection: $notificationService.reminderTime,
                        displayedComponents: .hourAndMinute
                    )
                    .onChange(of: notificationService.reminderTime) { _, _ in
                        notificationService.saveSettings()
                    }
                } header: {
                    Text("Time")
                }

                Section {
                    // Day selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Remind me on these days:")
                            .font(.subheadline)
                            .foregroundColor(GQColors.textTertiary)

                        HStack(spacing: 8) {
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
                    .padding(.vertical, 8)
                } header: {
                    Text("Days")
                }

                Section {
                    Button {
                        notificationService.scheduleReminders()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Update Reminders")
                        }
                    }
                } footer: {
                    let daysText = notificationService.reminderDays.isEmpty
                        ? "No days selected"
                        : "\(notificationService.reminderDays.count) day(s) per week"
                    let timeText = notificationService.reminderTime.formatted(date: .omitted, time: .shortened)
                    Text("Currently set: \(daysText) at \(timeText)")
                }
            }
        }
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
                .foregroundColor(isSelected ? .white : .gray)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(isSelected ? GQColors.vividPurple : Color.white.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
    .preferredColorScheme(.dark)
}
