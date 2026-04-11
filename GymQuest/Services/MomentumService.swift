//
//  MomentumService.swift
//  GymQuest
//
//  Consistency Engine — 5-state machine that tracks workout
//  momentum, drives nudges, milestones, and comeback plans.
//

import Foundation
import SwiftData

@MainActor
class MomentumService: ObservableObject {
    static let shared = MomentumService()
    private var modelContext: ModelContext?

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - State Machine

    /// Central state evaluator. Reads momentum fields and returns
    /// the correct `ConsistencyState`, applying the transition if changed.
    @discardableResult
    func evaluateState(userId: UUID) -> ConsistencyState {
        guard let ctx = modelContext else { return .onTrack }

        let momentum = fetchOrCreateMomentum(userId: userId, context: ctx)

        // Beginner grace period — no degradation for 7 days
        if momentum.beginnerPhaseActive,
           let graceEnd = momentum.beginnerGraceEndDate,
           Date() < graceEnd {
            return momentum.consistencyState
        }

        let previous = momentum.consistencyState
        let dayIndex = dayOfWeekIndex()
        let expectedByNow = max(1, momentum.effectiveWeeklyTarget * dayIndex / 7)
        let deficit = expectedByNow - momentum.currentWeekCompleted
        let daysSinceWorkout = daysSinceLastWorkout(momentum)

        let next: ConsistencyState

        switch previous {
        case .rebuilding:
            // Stay in rebuilding until 2 consecutive on-target weeks
            if momentum.rebuildingWeekCount >= 2 {
                next = .onTrack
            } else if daysSinceWorkout >= 7 || momentum.missedDaysInRow >= 5 {
                next = .comeback
            } else {
                next = .rebuilding
            }

        case .comeback:
            // Any workout while in comeback transitions to rebuilding
            // (handled by recordWorkoutCompleted setting the flag).
            // If still no workout, stay in comeback.
            next = .comeback

        default:
            if daysSinceWorkout >= 7 || momentum.missedDaysInRow >= 5 {
                next = .comeback
            } else if deficit >= 2 || (momentum.missedDaysInRow >= 3 && momentum.missedDaysInRow <= 4) {
                next = .atRisk
            } else if deficit == 1 || (momentum.missedDaysInRow >= 1 && momentum.missedDaysInRow <= 2) {
                next = .slipping
            } else {
                next = .onTrack
            }
        }

        if next != previous {
            momentum.consistencyState = next
            momentum.lastStateTransition = Date()
            handleStateTransition(userId: userId, from: previous, to: next)
        }

        momentum.weeklyVelocity = computeVelocity(userId: userId)
        try? ctx.save()

        return next
    }

    // MARK: - Velocity

    /// Rolling pace: workouts completed this week divided by days elapsed.
    func computeVelocity(userId: UUID) -> Double {
        guard let ctx = modelContext else { return 0 }
        let momentum = fetchOrCreateMomentum(userId: userId, context: ctx)
        let dayIndex = max(1, dayOfWeekIndex())
        return Double(momentum.currentWeekCompleted) / Double(dayIndex)
    }

    // MARK: - State Transition Side Effects

    func handleStateTransition(userId: UUID, from: ConsistencyState, to: ConsistencyState) {
        guard let ctx = modelContext else { return }

        // Memo directive: no guilt loops. No "at risk", no "falling behind",
        // no "we miss you" — these are loss-aversion levers that spike DAU in
        // week 2 and kill retention by month 3. Noticing-style copy only.
        switch to {
        case .slipping:
            let nudge = AccountabilityNudge(
                userId: userId,
                sourceType: .ai,
                nudgeType: .streakRisk,
                title: "Rest day?",
                message: "No pressure — a light session or a walk both count.",
                actionLabel: "See Options"
            )
            ctx.insert(nudge)

        case .atRisk:
            let nudge = AccountabilityNudge(
                userId: userId,
                sourceType: .ai,
                nudgeType: .missedWorkout,
                title: "Here when you're ready.",
                message: "Show up however you can today.",
                actionLabel: "Open Workout"
            )
            ctx.insert(nudge)

        case .comeback:
            // Reset streak on entering comeback
            let momentum = fetchOrCreateMomentum(userId: userId, context: ctx)
            momentum.streak = 0
            momentum.comebackEligible = true

            let daysSince = daysSinceLastWorkout(momentum)

            let nudge = AccountabilityNudge(
                userId: userId,
                sourceType: .ai,
                nudgeType: .comeback,
                title: "Welcome back.",
                message: "Whenever you're ready, a short session is waiting.",
                actionLabel: "Open Workout"
            )
            ctx.insert(nudge)

            let plan = ComebackPlan(
                userId: userId,
                reason: daysSince >= 7 ? "long_break" : "missed_days",
                suggestedWorkoutType: "Full Body",
                suggestedDuration: daysSince >= 7 ? 20 : 30,
                encouragement: daysSince >= 7
                    ? "No judgment. Rest was rest. A short session is a soft landing."
                    : "Pick up wherever. Short sessions count just as much."
            )
            ctx.insert(plan)

        case .rebuilding:
            let momentum = fetchOrCreateMomentum(userId: userId, context: ctx)
            momentum.rebuildingWeekCount = 0

            let nudge = AccountabilityNudge(
                userId: userId,
                sourceType: .ai,
                nudgeType: .weeklyGoal,
                title: "Soft return.",
                message: "Lighter week. Show up how you can.",
                actionLabel: "Open Workout"
            )
            ctx.insert(nudge)

        case .onTrack:
            if from == .rebuilding {
                createMilestone(
                    userId: userId,
                    type: .comebackComplete,
                    title: "Noticed.",
                    description: "Two weeks in a row after a break.",
                    context: ctx
                )
            }
        }

        try? ctx.save()
    }

    // MARK: - Record Workout

    func recordWorkoutCompleted(userId: UUID) {
        guard let ctx = modelContext else { return }

        let momentum = fetchOrCreateMomentum(userId: userId, context: ctx)

        let previousState = momentum.consistencyState

        momentum.currentWeekCompleted += 1
        momentum.missedDaysInRow = 0
        momentum.lastWorkoutDate = Date()
        momentum.streak += 1

        // First workout milestone
        if !momentum.firstWorkoutCompleted {
            momentum.firstWorkoutCompleted = true
            momentum.beginnerPhaseActive = true
            momentum.beginnerGraceEndDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())
            createMilestone(
                userId: userId,
                type: .firstWorkout,
                title: "First Workout Complete!",
                description: "You showed up. That's the hardest part.",
                context: ctx
            )
        }

        // First full week milestone
        if momentum.currentWeekCompleted >= momentum.currentWeekTarget && !momentum.firstWeekCompleted {
            momentum.firstWeekCompleted = true
            createMilestone(
                userId: userId,
                type: .firstFullWeek,
                title: "First Full Week!",
                description: "You hit your weekly target. Consistency is building.",
                context: ctx
            )
        }

        // Streak milestones
        if momentum.streak == 7 {
            createMilestone(
                userId: userId,
                type: .consistencyStreak7,
                title: "7-Day Streak!",
                description: "A full week of consistency. You're building a habit.",
                context: ctx
            )
        }
        if momentum.streak == 30 {
            createMilestone(
                userId: userId,
                type: .consistencyStreak30,
                title: "30-Day Streak!",
                description: "A month of consistent training. You're unstoppable.",
                context: ctx
            )
        }

        // Transition from comeback → rebuilding on first workout back
        if previousState == .comeback {
            momentum.consistencyState = .rebuilding
            momentum.comebackEligible = false
            momentum.lastStateTransition = Date()
            handleStateTransition(userId: userId, from: .comeback, to: .rebuilding)
        }

        try? ctx.save()

        // Run the state machine to catch any further transitions
        evaluateState(userId: userId)
    }

    // MARK: - Inactivity Check

    func checkInactivity(userId: UUID) {
        guard let ctx = modelContext else { return }

        let momentum = fetchOrCreateMomentum(userId: userId, context: ctx)

        guard momentum.lastWorkoutDate != nil else { return }

        let daysSince = daysSinceLastWorkout(momentum)

        // Increment missed days counter
        if daysSince > 0 {
            momentum.missedDaysInRow = daysSince
        }

        // Weekly reset check
        let calendar = Calendar.current
        if let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start,
           let lastDate = momentum.lastWorkoutDate,
           let lastWeekStart = calendar.dateInterval(of: .weekOfYear, for: lastDate)?.start,
           weekStart != lastWeekStart {
            // New week — reset weekly counter
            let previousWeekCompleted = momentum.currentWeekCompleted
            momentum.currentWeekCompleted = 0

            // If rebuilding and previous week was on-target, count it
            if momentum.consistencyState == .rebuilding,
               previousWeekCompleted >= momentum.effectiveWeeklyTarget {
                momentum.rebuildingWeekCount += 1
            }

            // End beginner grace if the week has passed
            if momentum.beginnerPhaseActive,
               let graceEnd = momentum.beginnerGraceEndDate,
               Date() >= graceEnd {
                momentum.beginnerPhaseActive = false
            }

            try? ctx.save()
        }

        // Evaluate the state machine
        evaluateState(userId: userId)
    }

    // MARK: - Helpers

    private func fetchOrCreateMomentum(userId: UUID, context: ModelContext) -> UserMomentumState {
        let descriptor = FetchDescriptor<UserMomentumState>(
            predicate: #Predicate { $0.userId == userId }
        )
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }

        let momentum = UserMomentumState(userId: userId)
        context.insert(momentum)
        return momentum
    }

    private func createMilestone(userId: UUID, type: MilestoneType, title: String, description: String, context: ModelContext) {
        let milestone = MilestoneEvent(
            userId: userId,
            type: type.rawValue,
            title: title,
            milestoneDescription: description
        )
        context.insert(milestone)
    }

    /// 1-based day of week with Monday = 1, Sunday = 7.
    private func dayOfWeekIndex() -> Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        // Calendar.current weekday: 1 = Sunday … 7 = Saturday
        // Convert to Monday = 1 … Sunday = 7
        return weekday == 1 ? 7 : weekday - 1
    }

    /// Days elapsed since the user's last workout, or 0 if none recorded.
    private func daysSinceLastWorkout(_ momentum: UserMomentumState) -> Int {
        guard let lastDate = momentum.lastWorkoutDate else { return 0 }
        return max(0, Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0)
    }
}
