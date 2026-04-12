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

        #if canImport(Supabase)
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
        #endif
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

    // MARK: - Unprompted Return Rate (memo v1 metric)
    //
    // "A new user logs their second workout within 7 days of their first,
    // without receiving any system-generated reminder." The gold metric for
    // whether the compounding loop is actually firing. External motivation
    // (a reminder push) doesn't count — only unprompted return.

    /// Record that a system-authored push has been sent to this user.
    func recordSystemPushSent(userId: UUID, pushType: String) {
        track(.systemPushSent, userId: userId, metadata: ["push_type": pushType])
    }

    /// Record that the user opened the app from a push notification.
    /// This marks the session as "prompted" for URR purposes.
    func recordAppOpenedFromPush(userId: UUID) {
        track(.appOpenedFromPush, userId: userId)
    }

    /// Compute whether this user's v1 activation loop fired:
    /// did their 2nd workout happen within 7 days of their 1st, with zero
    /// system pushes sent in between?
    func didFireUnpromptedReturn(userId: UUID) -> Bool {
        guard let context = modelContext else { return false }

        let workoutCompletedType = AnalyticsEventType.workoutCompleted.rawValue
        let descriptor = FetchDescriptor<AnalyticsEvent>(
            predicate: #Predicate {
                $0.odId == userId && $0.eventType.rawValue == workoutCompletedType
            },
            sortBy: [SortDescriptor(\.timestamp)]
        )

        guard let workouts = try? context.fetch(descriptor), workouts.count >= 2 else { return false }

        let first = workouts[0].timestamp
        let second = workouts[1].timestamp
        let hoursBetween = second.timeIntervalSince(first) / 3600.0

        // Must be within 7 days (168 hours)
        guard hoursBetween <= 168 else { return false }

        // Check for any system pushes sent to this user between workout #1 and #2
        let pushType = AnalyticsEventType.systemPushSent.rawValue
        let pushDescriptor = FetchDescriptor<AnalyticsEvent>(
            predicate: #Predicate {
                $0.odId == userId &&
                $0.eventType.rawValue == pushType &&
                $0.timestamp > first &&
                $0.timestamp < second
            }
        )

        let pushCount = (try? context.fetch(pushDescriptor).count) ?? 0
        return pushCount == 0
    }

    /// Cohort-level URR — what fraction of new users in a date range returned
    /// unprompted. Takes the pool of users whose first workout was logged in
    /// the window, and computes the rate.
    func unpromptedReturnRate(since: Date, until: Date = Date()) -> Double {
        guard let context = modelContext else { return 0 }

        let workoutCompletedType = AnalyticsEventType.workoutCompleted.rawValue
        let descriptor = FetchDescriptor<AnalyticsEvent>(
            predicate: #Predicate {
                $0.eventType.rawValue == workoutCompletedType &&
                $0.timestamp >= since &&
                $0.timestamp <= until
            }
        )
        guard let events = try? context.fetch(descriptor) else { return 0 }

        // Group by user, find each user's first workout in the window
        var firstByUser: [UUID: Date] = [:]
        for event in events {
            guard let uid = event.odId else { continue }
            if let existing = firstByUser[uid] {
                if event.timestamp < existing { firstByUser[uid] = event.timestamp }
            } else {
                firstByUser[uid] = event.timestamp
            }
        }

        guard !firstByUser.isEmpty else { return 0 }
        let returned = firstByUser.keys.filter { didFireUnpromptedReturn(userId: $0) }.count
        return Double(returned) / Double(firstByUser.count)
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

    // MARK: - Memo 5 KPI Computations (A24, W→P, D7)
    //
    // The three gold metrics from the 7-leverage-patterns memo:
    //   A24: % of new users who log a workout within 24h of first app open
    //   W→P: % of completed workouts that produce a shared Proof Card
    //   D7:  % of new users with ≥2 workouts in their first 7 days
    //
    // Targets: A24 ≥ 40%, W→P ≥ 50%, D7 ≥ 25%.

    /// A24: Activation within 24 hours.
    /// Numerator: users whose first workoutCompleted event is within 24h of their
    /// first event of any type. Denominator: all users with at least 1 event.
    func computeA24(since: Date = .distantPast) -> (rate: Double, total: Int, activated: Int) {
        guard let context = modelContext else { return (0, 0, 0) }
        let descriptor = FetchDescriptor<AnalyticsEvent>(
            predicate: #Predicate { $0.timestamp >= since },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        guard let events = try? context.fetch(descriptor) else { return (0, 0, 0) }

        // Group by user
        var firstAny: [UUID: Date] = [:]
        var firstWorkout: [UUID: Date] = [:]
        for e in events {
            guard let uid = e.odId else { continue }
            if firstAny[uid] == nil || e.timestamp < firstAny[uid]! { firstAny[uid] = e.timestamp }
            if e.eventType == .workoutCompleted {
                if firstWorkout[uid] == nil || e.timestamp < firstWorkout[uid]! { firstWorkout[uid] = e.timestamp }
            }
        }
        let total = firstAny.count
        guard total > 0 else { return (0, 0, 0) }
        let activated = firstAny.filter { uid, firstDate in
            guard let wDate = firstWorkout[uid] else { return false }
            return wDate.timeIntervalSince(firstDate) <= 24 * 3600
        }.count
        return (Double(activated) / Double(total), total, activated)
    }

    /// W→P: Workout-to-post rate.
    /// Numerator: workoutCompleted events followed by a shareExported or
    /// workoutCardCreated event within 10 minutes. Denominator: all workoutCompleted.
    func computeWtoP(since: Date = .distantPast) -> (rate: Double, workouts: Int, posted: Int) {
        guard let context = modelContext else { return (0, 0, 0) }
        let wcType = AnalyticsEventType.workoutCompleted.rawValue
        let wcDescriptor = FetchDescriptor<AnalyticsEvent>(
            predicate: #Predicate { $0.eventType.rawValue == wcType && $0.timestamp >= since },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        guard let workouts = try? context.fetch(wcDescriptor), !workouts.isEmpty else { return (0, 0, 0) }

        // For each workout event, check if there's a share/card within 10 minutes
        let shareType = AnalyticsEventType.shareExported.rawValue
        let cardType = AnalyticsEventType.workoutCardCreated.rawValue
        let allSharesDescriptor = FetchDescriptor<AnalyticsEvent>(
            predicate: #Predicate {
                ($0.eventType.rawValue == shareType || $0.eventType.rawValue == cardType) && $0.timestamp >= since
            },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        let allShares = (try? context.fetch(allSharesDescriptor)) ?? []

        var posted = 0
        for wc in workouts {
            let uid = wc.odId
            let after = wc.timestamp
            let cutoff = after.addingTimeInterval(600) // 10 minutes
            if allShares.contains(where: { $0.odId == uid && $0.timestamp >= after && $0.timestamp <= cutoff }) {
                posted += 1
            }
        }
        return (workouts.isEmpty ? 0 : Double(posted) / Double(workouts.count), workouts.count, posted)
    }

    /// D7: Day-7 retention with ≥2 workouts.
    /// Numerator: users whose first workoutCompleted is in the window AND who have
    /// ≥2 workoutCompleted events within 7 days of their first.
    /// Denominator: users whose first workoutCompleted is in the window.
    func computeD7(since: Date = .distantPast) -> (rate: Double, cohort: Int, retained: Int) {
        guard let context = modelContext else { return (0, 0, 0) }
        let wcType = AnalyticsEventType.workoutCompleted.rawValue
        let descriptor = FetchDescriptor<AnalyticsEvent>(
            predicate: #Predicate { $0.eventType.rawValue == wcType && $0.timestamp >= since },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        guard let events = try? context.fetch(descriptor) else { return (0, 0, 0) }

        // Group by user, find first workout date, count workouts within 7 days
        var userWorkouts: [UUID: [Date]] = [:]
        for e in events {
            guard let uid = e.odId else { continue }
            userWorkouts[uid, default: []].append(e.timestamp)
        }

        var cohort = 0
        var retained = 0
        for (_, dates) in userWorkouts {
            let sorted = dates.sorted()
            guard let first = sorted.first else { continue }
            cohort += 1
            let sevenDaysLater = first.addingTimeInterval(7 * 24 * 3600)
            let countInWindow = sorted.filter { $0 <= sevenDaysLater }.count
            if countInWindow >= 2 { retained += 1 }
        }
        return (cohort == 0 ? 0 : Double(retained) / Double(cohort), cohort, retained)
    }

    // MARK: - Founder Dashboard Summary
    //
    // All the memo-directed metrics in one struct so the founder debug screen
    // can render them without separate calls.

    struct FounderDashboard {
        // Memo 5 KPIs
        let a24Rate: Double           // target ≥ 40%
        let a24Total: Int
        let a24Activated: Int
        let wtopRate: Double          // target ≥ 50%
        let wtopWorkouts: Int
        let wtopPosted: Int
        let d7Rate: Double            // target ≥ 25%
        let d7Cohort: Int
        let d7Retained: Int
        // Memo 2 metric
        let urrRate: Double           // target > 50%
        // Action-from-feed
        let totalUsedWorkouts: Int
        // Engagement
        let totalWorkouts: Int
        let totalPosts: Int
    }

    func getFounderDashboard() -> FounderDashboard {
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 3600)
        let a24 = computeA24(since: thirtyDaysAgo)
        let wtop = computeWtoP(since: thirtyDaysAgo)
        let d7 = computeD7(since: thirtyDaysAgo)
        let urr = unpromptedReturnRate(since: thirtyDaysAgo)

        // Total used-workout events
        var totalUsed = 0
        if let ctx = modelContext {
            let desc = FetchDescriptor<UsedWorkoutEvent>()
            totalUsed = (try? ctx.fetch(desc).count) ?? 0
        }

        // Summary counts
        let summary = getMetricsSummary(userId: UUID()) // fallback
        return FounderDashboard(
            a24Rate: a24.rate, a24Total: a24.total, a24Activated: a24.activated,
            wtopRate: wtop.rate, wtopWorkouts: wtop.workouts, wtopPosted: wtop.posted,
            d7Rate: d7.rate, d7Cohort: d7.cohort, d7Retained: d7.retained,
            urrRate: urr,
            totalUsedWorkouts: totalUsed,
            totalWorkouts: summary.totalWorkouts,
            totalPosts: summary.totalShares
        )
    }

    // MARK: - Dashboard Summary (original)

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
