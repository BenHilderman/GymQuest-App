import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

/// Schedules local push notifications for crew events so the app feels
/// alive even when closed. "Jake just started training" when your phone
/// is in your pocket is the single biggest adoption lever for the
/// community layer — it makes the crew feel *real*.
///
/// MVP uses UNUserNotificationCenter (no server). Real deployment adds
/// Supabase Edge Functions → APNs for cross-device delivery.
@MainActor
final class CommunityNotificationService {
    static let shared = CommunityNotificationService()
    private init() {}

    /// Set of event IDs already scheduled this session — prevents duplicate
    /// notifications when data refreshes trigger the same event again.
    private var scheduledIds: Set<String> = []

    // MARK: - Authorization

    func requestAuthorizationIfNeeded() {
        #if canImport(UserNotifications) && os(iOS)
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
            }
        }
        #endif
    }

    // MARK: - Crew Events

    /// "🟢 Jake just started training — join in?"
    func notifyFriendStartedTraining(friendName: String, workoutType: String?, eventId: String) {
        guard shouldSchedule(eventId) else { return }
        let type = workoutType?.lowercased() ?? "a workout"
        schedule(
            id: eventId,
            title: "\(friendName) just started training",
            body: "They're doing \(type) — tap to cheer them on",
            delay: 0
        )
    }

    /// "💪 Sarah just finished Push — drop a reaction"
    func notifyFriendFinished(friendName: String, workoutType: String, eventId: String) {
        guard shouldSchedule(eventId) else { return }
        schedule(
            id: eventId,
            title: "\(friendName) just finished \(workoutType.lowercased())",
            body: "Drop a quick 💪 — they'll feel it instantly",
            delay: 0
        )
    }

    /// "🔥 Your crew trained 5 of 7 days this week"
    func notifyCrewMilestone(crewDays: Int, totalDays: Int, eventId: String) {
        guard shouldSchedule(eventId) else { return }
        guard crewDays >= 5 else { return }
        schedule(
            id: eventId,
            title: "Your crew trained \(crewDays) of \(totalDays) days",
            body: crewDays == totalDays
                ? "Perfect week — the squad came through"
                : "One more day and it's a perfect week",
            delay: 0
        )
    }

    /// "✨ You and Liam both trained today — duo day!"
    func notifyDuoDay(friendName: String, eventId: String) {
        guard shouldSchedule(eventId) else { return }
        schedule(
            id: eventId,
            title: "Duo day with \(friendName) ✨",
            body: "You both trained today. That's the stuff.",
            delay: 0
        )
    }

    // MARK: - Private

    private func shouldSchedule(_ eventId: String) -> Bool {
        scheduledIds.insert(eventId).inserted
    }

    private func schedule(id: String, title: String, body: String, delay: TimeInterval) {
        #if canImport(UserNotifications) && os(iOS)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "community"

        let trigger = delay > 0
            ? UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            : nil

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { _ in }
        #endif
    }

    /// Reset session state (e.g. on app background → foreground cycle).
    func resetSession() {
        scheduledIds.removeAll()
    }
}
