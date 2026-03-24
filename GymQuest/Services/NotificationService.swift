//
//  NotificationService.swift
//  GymQuest
//
//  Handles local notifications for workout reminders.
//  Supports daily reminders at user-specified times.
//

import Foundation
import SwiftData
import UserNotifications

@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published var isAuthorized = false
    @Published var reminderEnabled = false
    @Published var reminderTime: Date = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @Published var reminderDays: Set<Int> = [1, 2, 3, 4, 5] // Mon-Fri by default

    private let defaults = UserDefaults.standard
    private let reminderEnabledKey = "workout_reminder_enabled"
    private let reminderTimeKey = "workout_reminder_time"
    private let reminderDaysKey = "workout_reminder_days"

    private init() {
        loadSettings()
        checkAuthorizationStatus()
    }

    func configure(modelContext: ModelContext) {
        // No-op: NotificationService uses UserDefaults, not SwiftData
    }

    // MARK: - Authorization

    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            await MainActor.run {
                self.isAuthorized = granted
            }
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }

    // MARK: - Settings

    private func loadSettings() {
        reminderEnabled = defaults.bool(forKey: reminderEnabledKey)

        if let savedTime = defaults.object(forKey: reminderTimeKey) as? Date {
            reminderTime = savedTime
        }

        if let savedDays = defaults.array(forKey: reminderDaysKey) as? [Int] {
            reminderDays = Set(savedDays)
        }
    }

    func saveSettings() {
        defaults.set(reminderEnabled, forKey: reminderEnabledKey)
        defaults.set(reminderTime, forKey: reminderTimeKey)
        defaults.set(Array(reminderDays), forKey: reminderDaysKey)

        if reminderEnabled {
            scheduleReminders()
        } else {
            cancelAllReminders()
        }
    }

    // MARK: - Scheduling

    func scheduleReminders() {
        // Cancel existing reminders first
        cancelAllReminders()

        guard isAuthorized && reminderEnabled else { return }

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: reminderTime)
        let minute = calendar.component(.minute, from: reminderTime)

        let motivationalMessages = [
            "Time to crush your workout! 💪",
            "Your body is ready. Let's go!",
            "Champions train when they don't feel like it.",
            "Today's workout = Tomorrow's results.",
            "Your future self will thank you.",
            "No excuses. Just gains.",
            "Consistency beats intensity. Show up!",
            "Another day, another opportunity to grow."
        ]

        for weekday in reminderDays {
            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = minute
            dateComponents.weekday = weekday

            let content = UNMutableNotificationContent()
            content.title = "Workout Reminder"
            content.body = motivationalMessages.randomElement() ?? "Time to train!"
            content.sound = .default
            content.badge = 1

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: "workout_reminder_\(weekday)",
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Failed to schedule notification: \(error)")
                }
            }
        }
    }

    func cancelAllReminders() {
        let identifiers = (1...7).map { "workout_reminder_\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: - Immediate Notifications

    func sendWorkoutCompleteNotification(workoutTitle: String, xpEarned: Int) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Workout Complete! 🎉"
        content.body = "Great job on \(workoutTitle)! You earned \(xpEarned) XP."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "workout_complete_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func sendStreakNotification(streakDays: Int) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Streak Alert! 🔥"
        content.body = "You're on a \(streakDays)-day streak! Keep it going!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "streak_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Supabase Realtime Notifications

    func startSupabaseNotificationListener() {
        guard FeatureFlags.shared.supabaseSyncEnabled,
              let userId = SupabaseAuthService.shared.currentUserId else { return }

        SupabaseSyncService.shared.subscribeToNotifications(userId: userId) { notification in
            self.sendLocalNotification(
                title: "Lift AI",
                body: notification.message ?? "\(notification.fromName ?? "Someone") interacted with your post",
                identifier: notification.id?.uuidString ?? UUID().uuidString
            )
        }
    }

    private func sendLocalNotification(title: String, body: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func sendPRNotification(exerciseName: String, improvement: String) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "New PR! 🏆"
        content.body = "You hit a new \(exerciseName) PR: \(improvement)"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "pr_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Day Picker Helper

extension NotificationService {
    static let weekdayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    func toggleDay(_ day: Int) {
        if reminderDays.contains(day) {
            reminderDays.remove(day)
        } else {
            reminderDays.insert(day)
        }
        saveSettings()
    }

    func isDayEnabled(_ day: Int) -> Bool {
        reminderDays.contains(day)
    }
}
