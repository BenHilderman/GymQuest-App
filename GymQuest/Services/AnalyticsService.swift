//
//  AnalyticsService.swift
//  GymQuest
//
//  Local analytics service for tracking key metrics.
//  Supports event tracking and success metrics as per GymQuest 2.0 spec.
//

import Foundation
import SwiftData

@MainActor
class AnalyticsService: ObservableObject {
    static let shared = AnalyticsService()

    private var modelContext: ModelContext?

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Event Tracking

    /// Track an analytics event
    func track(
        _ eventType: AnalyticsEventType,
        userId: UUID? = nil,
        metadata: [String: Any]? = nil
    ) {
        guard let context = modelContext else {
            #if DEBUG
            print("AnalyticsService: ModelContext not configured")
            #endif
            return
        }

        let metadataString = metadata.flatMap { dict -> String? in
            guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
            return String(data: data, encoding: .utf8)
        }

        let event = AnalyticsEvent(
            odId: userId,
            eventType: eventType,
            metadata: metadataString,
            timestamp: Date()
        )

        context.insert(event)
        try? context.save()

        if FeatureFlags.shared.supabaseSyncEnabled {
            Task {
                do {
                    let dto = AnalyticsEventDTO(
                        userId: SupabaseAuthService.shared.currentUserId ?? userId,
                        eventType: eventType.rawValue,
                        metadata: metadataString
                    )
                    try await SupabaseSyncService.shared.insert(dto, table: "analytics_events")
                } catch {
                    print("[AnalyticsService] Supabase sync failed: \(error)")
                }
            }
        }
    }

    /// Generic event tracking with string event name and properties
    func trackEvent(eventName: String, properties: [String: String]) {
        guard let context = modelContext else { return }

        let metadataString: String?
        if let data = try? JSONSerialization.data(withJSONObject: properties),
           let jsonString = String(data: data, encoding: .utf8) {
            metadataString = jsonString
        } else {
            metadataString = nil
        }

        // Map common event names to AnalyticsEventType
        let eventType: AnalyticsEventType
        switch eventName {
        case "squad_created": eventType = .squadCreated
        case "squad_invite_sent": eventType = .squadInviteSent
        case "quest_completed": eventType = .questCompleted
        case "meal_logged": eventType = .mealLogged
        default: eventType = .workoutStarted // fallback
        }

        let event = AnalyticsEvent(
            eventType: eventType,
            metadata: metadataString,
            timestamp: Date()
        )

        context.insert(event)
        try? context.save()
    }

    // MARK: - Convenience Methods

    func trackWorkoutStarted(userId: UUID, workoutType: String) {
        track(.workoutStarted, userId: userId, metadata: ["workout_type": workoutType])
    }

    func trackSetAdded(userId: UUID, exerciseName: String, weight: Double, reps: Int) {
        track(.setAdded, userId: userId, metadata: [
            "exercise": exerciseName,
            "weight": weight,
            "reps": reps
        ])
    }

    func trackWorkoutCompleted(userId: UUID, duration: Int, totalSets: Int, xpEarned: Int) {
        track(.workoutCompleted, userId: userId, metadata: [
            "duration": duration,
            "total_sets": totalSets,
            "xp_earned": xpEarned
        ])
    }

    func trackPRDetected(userId: UUID, prType: String, exerciseName: String?, improvement: String?) {
        var metadata: [String: Any] = ["pr_type": prType]
        if let exercise = exerciseName { metadata["exercise"] = exercise }
        if let imp = improvement { metadata["improvement"] = imp }
        track(.prDetected, userId: userId, metadata: metadata)
    }

    func trackWorkoutCardCreated(userId: UUID, hasPRs: Bool, hasCoachTakeaway: Bool) {
        track(.workoutCardCreated, userId: userId, metadata: [
            "has_prs": hasPRs,
            "has_coach_takeaway": hasCoachTakeaway
        ])
    }

    func trackShareExported(userId: UUID, shareType: String) {
        track(.shareExported, userId: userId, metadata: ["share_type": shareType])
    }

    func trackSquadCreated(userId: UUID, squadId: UUID, memberCount: Int) {
        track(.squadCreated, userId: userId, metadata: [
            "squad_id": squadId.uuidString,
            "member_count": memberCount
        ])
    }

    func trackSquadInviteSent(userId: UUID, squadId: UUID) {
        track(.squadInviteSent, userId: userId, metadata: ["squad_id": squadId.uuidString])
    }

    func trackQuestCompleted(userId: UUID, questId: UUID, questType: String, xpEarned: Int) {
        track(.questCompleted, userId: userId, metadata: [
            "quest_id": questId.uuidString,
            "quest_type": questType,
            "xp_earned": xpEarned
        ])
    }

    func trackLearningItemViewed(userId: UUID, itemId: UUID, exerciseName: String?) {
        var metadata: [String: Any] = ["item_id": itemId.uuidString]
        if let name = exerciseName { metadata["exercise"] = name }
        track(.learningItemViewed, userId: userId, metadata: metadata)
    }

    func trackLearningItemShared(userId: UUID, itemId: UUID) {
        track(.learningItemShared, userId: userId, metadata: ["item_id": itemId.uuidString])
    }

    func trackHealthKitImportSuccess(userId: UUID, workoutCount: Int) {
        track(.healthkitImportSuccess, userId: userId, metadata: ["workout_count": workoutCount])
    }

    func trackStravaImportSuccess(userId: UUID, activityCount: Int) {
        track(.stravaImportSuccess, userId: userId, metadata: ["activity_count": activityCount])
    }

    func trackMealLogged(userId: UUID, tags: [String], hasPhoto: Bool) {
        track(.mealLogged, userId: userId, metadata: [
            "tags": tags,
            "has_photo": hasPhoto
        ])
    }

    // MARK: - Metrics Calculation

    /// Calculate time to first win (first PR or quest completion)
    func timeToFirstWin(userId: UUID) -> TimeInterval? {
        guard let context = modelContext else { return nil }

        // Get user's first event
        let firstEventDescriptor = FetchDescriptor<AnalyticsEvent>(
            predicate: #Predicate { $0.odId == userId },
            sortBy: [SortDescriptor(\.timestamp)]
        )

        guard let events = try? context.fetch(firstEventDescriptor),
              let firstEvent = events.first else { return nil }

        // Find first win (PR detected or quest completed)
        let firstWin = events.first { event in
            event.eventType == .prDetected || event.eventType == .questCompleted
        }

        guard let win = firstWin else { return nil }

        return win.timestamp.timeIntervalSince(firstEvent.timestamp)
    }

    /// Calculate workouts per week (median over last 4 weeks)
    func medianWorkoutsPerWeek(userId: UUID) -> Double {
        guard let context = modelContext else { return 0 }

        let fourWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -4, to: Date()) ?? Date()
        let workoutCompletedType = AnalyticsEventType.workoutCompleted.rawValue

        let descriptor = FetchDescriptor<AnalyticsEvent>(
            predicate: #Predicate {
                $0.odId == userId &&
                $0.eventType.rawValue == workoutCompletedType &&
                $0.timestamp >= fourWeeksAgo
            }
        )

        guard let events = try? context.fetch(descriptor) else { return 0 }

        // Group by week
        var weekCounts: [Int: Int] = [:]
        let calendar = Calendar.current

        for event in events {
            let weekOfYear = calendar.component(.weekOfYear, from: event.timestamp)
            weekCounts[weekOfYear, default: 0] += 1
        }

        guard !weekCounts.isEmpty else { return 0 }

        // Calculate median
        let sorted = weekCounts.values.sorted()
        let mid = sorted.count / 2

        if sorted.count % 2 == 0 {
            return Double(sorted[mid - 1] + sorted[mid]) / 2.0
        } else {
            return Double(sorted[mid])
        }
    }

    /// Calculate shares per workout
    func sharesPerWorkout(userId: UUID) -> Double {
        guard let context = modelContext else { return 0 }

        let workoutCompletedType = AnalyticsEventType.workoutCompleted.rawValue
        let shareExportedType = AnalyticsEventType.shareExported.rawValue

        let workoutDescriptor = FetchDescriptor<AnalyticsEvent>(
            predicate: #Predicate {
                $0.odId == userId && $0.eventType.rawValue == workoutCompletedType
            }
        )

        let shareDescriptor = FetchDescriptor<AnalyticsEvent>(
            predicate: #Predicate {
                $0.odId == userId && $0.eventType.rawValue == shareExportedType
            }
        )

        guard let workouts = try? context.fetch(workoutDescriptor),
              let shares = try? context.fetch(shareDescriptor),
              !workouts.isEmpty else { return 0 }

        return Double(shares.count) / Double(workouts.count)
    }

    /// Calculate invites per user
    func invitesPerUser(userId: UUID) -> Int {
        guard let context = modelContext else { return 0 }

        let inviteSentType = AnalyticsEventType.squadInviteSent.rawValue
        let descriptor = FetchDescriptor<AnalyticsEvent>(
            predicate: #Predicate {
                $0.odId == userId && $0.eventType.rawValue == inviteSentType
            }
        )

        guard let events = try? context.fetch(descriptor) else { return 0 }
        return events.count
    }

    /// Calculate week-1 retention (returned within 7 days of first event)
    func week1Retention(userId: UUID) -> Bool {
        guard let context = modelContext else { return false }

        let descriptor = FetchDescriptor<AnalyticsEvent>(
            predicate: #Predicate { $0.odId == userId },
            sortBy: [SortDescriptor(\.timestamp)]
        )

        guard let events = try? context.fetch(descriptor),
              events.count >= 2,
              let firstEvent = events.first else { return false }

        let sevenDaysLater = Calendar.current.date(byAdding: .day, value: 7, to: firstEvent.timestamp) ?? Date()

        // Check if there's activity after day 1 but within week 1
        let dayAfterFirst = Calendar.current.date(byAdding: .day, value: 1, to: firstEvent.timestamp) ?? Date()

        return events.contains { event in
            event.timestamp > dayAfterFirst && event.timestamp <= sevenDaysLater
        }
    }

    /// Calculate learning completion rate (demo watched → exercise logged)
    func learningCompletionRate(userId: UUID) -> Double {
        guard let context = modelContext else { return 0 }

        let learningViewedType = AnalyticsEventType.learningItemViewed.rawValue
        let viewedDescriptor = FetchDescriptor<AnalyticsEvent>(
            predicate: #Predicate {
                $0.odId == userId && $0.eventType.rawValue == learningViewedType
            }
        )

        guard let viewedEvents = try? context.fetch(viewedDescriptor),
              !viewedEvents.isEmpty else { return 0 }

        // Count how many viewed items led to a workout
        var conversionCount = 0
        let setAddedType = AnalyticsEventType.setAdded.rawValue

        for event in viewedEvents {
            // Check if there's a workout within 24 hours that includes this exercise
            if let metadata = event.metadata,
               let data = metadata.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let exerciseName = json["exercise"] as? String {

                let dayAfter = Calendar.current.date(byAdding: .day, value: 1, to: event.timestamp) ?? Date()
                let eventTimestamp = event.timestamp

                let workoutDescriptor = FetchDescriptor<AnalyticsEvent>(
                    predicate: #Predicate {
                        $0.odId == userId &&
                        $0.eventType.rawValue == setAddedType &&
                        $0.timestamp > eventTimestamp &&
                        $0.timestamp <= dayAfter
                    }
                )

                if let workoutEvents = try? context.fetch(workoutDescriptor) {
                    for workoutEvent in workoutEvents {
                        if let wMetadata = workoutEvent.metadata,
                           wMetadata.contains(exerciseName) {
                            conversionCount += 1
                            break
                        }
                    }
                }
            }
        }

        return Double(conversionCount) / Double(viewedEvents.count)
    }

    // MARK: - Dashboard Summary

    struct MetricsSummary {
        let totalWorkouts: Int
        let totalPRs: Int
        let totalShares: Int
        let totalQuestsCompleted: Int
        let learningItemsViewed: Int
        let mealsLogged: Int
        let workoutsThisWeek: Int
        let sharesThisWeek: Int
    }

    func getMetricsSummary(userId: UUID) -> MetricsSummary {
        guard let context = modelContext else {
            return MetricsSummary(
                totalWorkouts: 0, totalPRs: 0, totalShares: 0,
                totalQuestsCompleted: 0, learningItemsViewed: 0, mealsLogged: 0,
                workoutsThisWeek: 0, sharesThisWeek: 0
            )
        }

        let weekStart = Calendar.current.startOfWeek(for: Date())

        func count(_ type: AnalyticsEventType, since: Date? = nil) -> Int {
            let descriptor: FetchDescriptor<AnalyticsEvent>

            if let since = since {
                descriptor = FetchDescriptor<AnalyticsEvent>(
                    predicate: #Predicate {
                        $0.odId == userId && $0.eventType == type && $0.timestamp >= since
                    }
                )
            } else {
                descriptor = FetchDescriptor<AnalyticsEvent>(
                    predicate: #Predicate {
                        $0.odId == userId && $0.eventType == type
                    }
                )
            }

            return (try? context.fetch(descriptor))?.count ?? 0
        }

        return MetricsSummary(
            totalWorkouts: count(.workoutCompleted),
            totalPRs: count(.prDetected),
            totalShares: count(.shareExported),
            totalQuestsCompleted: count(.questCompleted),
            learningItemsViewed: count(.learningItemViewed),
            mealsLogged: count(.mealLogged),
            workoutsThisWeek: count(.workoutCompleted, since: weekStart),
            sharesThisWeek: count(.shareExported, since: weekStart)
        )
    }
}

// MARK: - Calendar Extension (if not already defined)

extension Calendar {
    func startOfWeekForAnalytics(for date: Date) -> Date {
        var cal = self
        cal.firstWeekday = 2 // Monday
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: components) ?? date
    }
}
