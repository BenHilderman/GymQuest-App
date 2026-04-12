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

        // Warm, noticing-style copy only. Memo directive: no shame, no guilt,
        // no "future-self" moralizing, no "no excuses" drill-sergeant tone.
        // These are opt-in reminders — the app is a spotter, not a drill sergeant.
        let motivationalMessages = [
            "Your gym bag is by the door.",
            "Whenever you're ready.",
            "Show up however you can today.",
            "Even ten minutes counts.",
            "Lace up when you feel like it.",
            "Quiet nudge — no pressure."
        ]

        for weekday in reminderDays {
            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = minute
            dateComponents.weekday = weekday

            let content = UNMutableNotificationContent()
            content.title = "Lift AI"
            content.body = motivationalMessages.randomElement() ?? "Whenever you're ready."
            content.sound = .default
            content.badge = 1
            content.userInfo = ["type": "scheduled_reminder"]

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

    // MARK: - System Push Throttle
    //
    // Memo directive: maximum 1 system-authored push per 24 hours. Celebrations
    // tied directly to a user action (workout complete, PR hit) are human-triggered
    // and bypass the throttle. Scheduled or ambient pushes must respect it.

    private let lastSystemPushKey = "lastSystemPushAt"

    private func canSendAmbientPush() -> Bool {
        let last = UserDefaults.standard.object(forKey: lastSystemPushKey) as? Date ?? .distantPast
        return Date().timeIntervalSince(last) > 24 * 60 * 60
    }

    private func markAmbientPushSent() {
        UserDefaults.standard.set(Date(), forKey: lastSystemPushKey)
    }

    // MARK: - Immediate Notifications

    func sendWorkoutCompleteNotification(workoutTitle: String, xpEarned: Int) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Workout Complete"
        content.body = "Finished \(workoutTitle)."
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

        // Noticing language, past-tense. No loss-aversion "keep it going" nag.
        let content = UNMutableNotificationContent()
        content.title = "Noticed."
        content.body = "\(streakDays) days in a row."
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
        content.title = "New PR"
        content.body = "\(exerciseName): \(improvement)"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "pr_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// The most potent notification in the compounding loop: "X used your workout."
    /// Fires back to the original post author when someone copies their workout
    /// into a live session. This is recognition-in-action — the purest form of
    /// the "effort produced something that produced more effort" feedback.
    func sendUsedWorkoutNotification(actorName: String, workoutType: String, recipientId: UUID) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Noticed."
        content.body = "\(actorName) is using your \(workoutType.lowercased()) workout."
        content.sound = .default
        content.userInfo = ["recipientId": recipientId.uuidString, "type": "usedWorkout"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "usedWorkout_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Memo 4 streak mercy: when the system detects a user hasn't trained today
    /// but their streak is protected by a grace day, fire this instead of any
    /// "streak at risk" push. The user learns the system is their advocate.
    func sendGraceDayNotification(streakDays: Int) {
        guard isAuthorized else { return }
        let content = UNMutableNotificationContent()
        content.title = "Grace day."
        content.body = "Your \(streakDays)-day streak is safe. Rest is part of showing up."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "grace_\(UUID().uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    /// Atomic variant: someone took a specific exercise or set from your workout.
    /// Lighter than the full "used your workout" notification but still
    /// loop-closing — your effort produced another person's movement.
    func sendStolenSetNotification(actorName: String, exerciseLabel: String, recipientId: UUID) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Noticed."
        content.body = "\(actorName) took your \(exerciseLabel)."
        content.sound = .default
        content.userInfo = ["recipientId": recipientId.uuidString, "type": "stolenSet"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "stolenSet_\(UUID().uuidString)",
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
