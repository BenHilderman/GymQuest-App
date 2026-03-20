import Foundation
import SwiftData

@MainActor
final class PlanScheduleService: ObservableObject {

    static let shared = PlanScheduleService()

    private var modelContext: ModelContext?

    private init() {}

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Schedule Generation

    /// Creates ScheduledPlanDay records for every day in a TrainingPlan,
    /// starting from a given date. Called when a plan is first created or activated.
    func generateSchedule(
        for plan: TrainingPlan,
        startingFrom startDate: Date = Date(),
        preferredDays: [Int]? = nil // 1=Sun, 2=Mon, ... 7=Sat
    ) {
        guard let context = modelContext else { return }

        // Remove any existing schedule for this plan
        let planId = plan.id
        let existing = FetchDescriptor<ScheduledPlanDay>(
            predicate: #Predicate<ScheduledPlanDay> { $0.planId == planId }
        )
        if let old = try? context.fetch(existing) {
            for day in old { context.delete(day) }
        }

        let calendar = Calendar.current
        var currentDate = calendar.startOfDay(for: startDate)

        for week in plan.weeks {
            for day in week.days {
                // If user has preferred days and this is a training day, skip to next preferred day
                if !day.isRestDay, let preferred = preferredDays {
                    currentDate = nextPreferredDay(from: currentDate, preferred: preferred, calendar: calendar)
                }

                let scheduled = ScheduledPlanDay(
                    planId: plan.id,
                    planWeekNumber: week.weekNumber,
                    planDayNumber: day.dayNumber,
                    scheduledDate: currentDate,
                    status: day.isRestDay ? .rest : .planned,
                    label: day.label,
                    workoutType: day.workoutType,
                    isRestDay: day.isRestDay,
                    exercises: day.exercises
                )
                context.insert(scheduled)

                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
        }

        try? context.save()
    }

    // MARK: - Day Queries

    /// Returns today's scheduled plan day (if any).
    func todaysPlanDay(planId: UUID) -> ScheduledPlanDay? {
        guard let context = modelContext else { return nil }
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!

        let descriptor = FetchDescriptor<ScheduledPlanDay>(
            predicate: #Predicate<ScheduledPlanDay> {
                $0.planId == planId
                && $0.scheduledDate >= startOfToday
                && $0.scheduledDate < startOfTomorrow
            }
        )
        return try? context.fetch(descriptor).first
    }

    /// Returns all scheduled days for a given week (by calendar week containing the date).
    func weekDays(planId: UUID, containing date: Date = Date()) -> [ScheduledPlanDay] {
        guard let context = modelContext else { return [] }
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else { return [] }
        let weekStart = weekInterval.start
        let weekEnd = weekInterval.end

        let descriptor = FetchDescriptor<ScheduledPlanDay>(
            predicate: #Predicate<ScheduledPlanDay> {
                $0.planId == planId
                && $0.scheduledDate >= weekStart
                && $0.scheduledDate < weekEnd
            },
            sortBy: [SortDescriptor(\.scheduledDate)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Returns all scheduled days for a given month.
    func monthDays(planId: UUID, month: Date) -> [ScheduledPlanDay] {
        guard let context = modelContext else { return [] }
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else { return [] }
        let monthStart = monthInterval.start
        let monthEnd = monthInterval.end

        let descriptor = FetchDescriptor<ScheduledPlanDay>(
            predicate: #Predicate<ScheduledPlanDay> {
                $0.planId == planId
                && $0.scheduledDate >= monthStart
                && $0.scheduledDate < monthEnd
            },
            sortBy: [SortDescriptor(\.scheduledDate)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Returns the next upcoming actionable plan day (planned or rebalanced).
    func nextUpcomingDay(planId: UUID) -> ScheduledPlanDay? {
        guard let context = modelContext else { return nil }
        let now = Calendar.current.startOfDay(for: Date())
        let plannedStatus = PlanDayStatus.planned.rawValue
        let rebalancedStatus = PlanDayStatus.rebalanced.rawValue

        let descriptor = FetchDescriptor<ScheduledPlanDay>(
            predicate: #Predicate<ScheduledPlanDay> {
                $0.planId == planId
                && $0.scheduledDate >= now
                && !$0.isRestDay
                && ($0.status == plannedStatus || $0.status == rebalancedStatus)
            },
            sortBy: [SortDescriptor(\.scheduledDate)]
        )
        return try? context.fetch(descriptor).first
    }

    // MARK: - Status Updates

    /// Marks a plan day as completed and links it to a workout.
    func markCompleted(planDayId: UUID, workoutId: UUID) {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<ScheduledPlanDay>(
            predicate: #Predicate<ScheduledPlanDay> { $0.id == planDayId }
        )
        guard let day = try? context.fetch(descriptor).first else { return }

        day.dayStatus = .completed
        day.workoutId = workoutId
        try? context.save()
    }

    /// Scans past plan days and marks unworked ones as missed.
    func resolveMissedDays(planId: UUID) {
        guard let context = modelContext else { return }
        let now = Calendar.current.startOfDay(for: Date())
        let plannedStatus = PlanDayStatus.planned.rawValue

        let descriptor = FetchDescriptor<ScheduledPlanDay>(
            predicate: #Predicate<ScheduledPlanDay> {
                $0.planId == planId
                && $0.scheduledDate < now
                && $0.status == plannedStatus
                && !$0.isRestDay
            }
        )

        guard let overdue = try? context.fetch(descriptor) else { return }
        for day in overdue {
            day.dayStatus = .missed
        }
        if !overdue.isEmpty {
            try? context.save()
        }
    }

    // MARK: - Rescheduling

    /// Moves a plan day to a new date.
    func moveDay(_ planDayId: UUID, to newDate: Date) {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<ScheduledPlanDay>(
            predicate: #Predicate<ScheduledPlanDay> { $0.id == planDayId }
        )
        guard let day = try? context.fetch(descriptor).first else { return }

        if day.originalDate == nil {
            day.originalDate = day.scheduledDate
        }
        day.scheduledDate = Calendar.current.startOfDay(for: newDate)
        day.dayStatus = .moved
        try? context.save()
    }

    /// Swaps the scheduled dates of two plan days.
    func swapDays(_ dayA: UUID, _ dayB: UUID) {
        guard let context = modelContext else { return }
        let descA = FetchDescriptor<ScheduledPlanDay>(
            predicate: #Predicate<ScheduledPlanDay> { $0.id == dayA }
        )
        let descB = FetchDescriptor<ScheduledPlanDay>(
            predicate: #Predicate<ScheduledPlanDay> { $0.id == dayB }
        )
        guard let a = try? context.fetch(descA).first,
              let b = try? context.fetch(descB).first else { return }

        let tempDate = a.scheduledDate
        a.scheduledDate = b.scheduledDate
        b.scheduledDate = tempDate

        if a.originalDate == nil { a.originalDate = tempDate }
        if b.originalDate == nil { b.originalDate = b.scheduledDate }
        a.dayStatus = .swapped
        b.dayStatus = .swapped
        try? context.save()
    }

    /// Replaces a planned day with a rest/recovery day.
    func markAsRest(_ planDayId: UUID) {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<ScheduledPlanDay>(
            predicate: #Predicate<ScheduledPlanDay> { $0.id == planDayId }
        )
        guard let day = try? context.fetch(descriptor).first else { return }
        day.dayStatus = .recovery
        try? context.save()
    }

    // MARK: - Rebalancing

    /// After missed days, redistributes remaining planned workouts
    /// across the rest of the current week.
    func rebalanceCurrentWeek(planId: UUID) {
        guard let context = modelContext else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let weekEnd = calendar.dateInterval(of: .weekOfYear, for: today)?.end else { return }

        // Find missed days this week
        let missedStatus = PlanDayStatus.missed.rawValue
        let missedDesc = FetchDescriptor<ScheduledPlanDay>(
            predicate: #Predicate<ScheduledPlanDay> {
                $0.planId == planId
                && $0.scheduledDate >= today
                && $0.scheduledDate < weekEnd
                && $0.status == missedStatus
                && !$0.isRestDay
            },
            sortBy: [SortDescriptor(\.scheduledDate)]
        )
        // Actually we want to find future planned + missed days to redistribute
        let plannedStatus = PlanDayStatus.planned.rawValue
        let futureDesc = FetchDescriptor<ScheduledPlanDay>(
            predicate: #Predicate<ScheduledPlanDay> {
                $0.planId == planId
                && $0.scheduledDate >= today
                && $0.scheduledDate < weekEnd
                && ($0.status == plannedStatus || $0.status == missedStatus)
                && !$0.isRestDay
            },
            sortBy: [SortDescriptor(\.scheduledDate)]
        )

        guard let futureDays = try? context.fetch(futureDesc), !futureDays.isEmpty else { return }

        // Collect available dates from today to end of week
        var availableDates: [Date] = []
        var cursor = today
        while cursor < weekEnd {
            availableDates.append(cursor)
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? weekEnd
        }

        // Spread workouts evenly across available dates
        let workoutDays = futureDays
        guard availableDates.count >= workoutDays.count else { return }

        let spacing = max(1, availableDates.count / workoutDays.count)
        for (index, day) in workoutDays.enumerated() {
            let dateIndex = min(index * spacing, availableDates.count - 1)
            let newDate = availableDates[dateIndex]
            if newDate != day.scheduledDate {
                if day.originalDate == nil { day.originalDate = day.scheduledDate }
                day.scheduledDate = newDate
                day.dayStatus = .rebalanced
            }
        }

        try? context.save()
    }

    // MARK: - Plan Advancement

    /// Advances the TrainingPlan's currentWeek/currentDay to match
    /// the next incomplete plan day.
    func advancePlanPosition(plan: TrainingPlan) {
        guard let context = modelContext else { return }
        let planId = plan.id
        let plannedStatus = PlanDayStatus.planned.rawValue
        let rebalancedStatus = PlanDayStatus.rebalanced.rawValue

        let descriptor = FetchDescriptor<ScheduledPlanDay>(
            predicate: #Predicate<ScheduledPlanDay> {
                $0.planId == planId
                && !$0.isRestDay
                && ($0.status == plannedStatus || $0.status == rebalancedStatus)
            },
            sortBy: [SortDescriptor(\.scheduledDate)]
        )

        if let nextDay = try? context.fetch(descriptor).first {
            plan.currentWeek = nextDay.planWeekNumber
            plan.currentDay = nextDay.planDayNumber
        } else {
            // All days done — plan complete
            plan.completedAt = Date()
        }
        try? context.save()
    }

    // MARK: - Week Summary

    struct WeekSummary {
        let planWeekNumber: Int
        let focus: String
        let totalDays: Int
        let completedCount: Int
        let missedCount: Int
        let remainingCount: Int
        let restCount: Int
    }

    func currentWeekSummary(planId: UUID) -> WeekSummary? {
        let days = weekDays(planId: planId)
        guard !days.isEmpty else { return nil }

        let planWeek = days.first?.planWeekNumber ?? 1
        let completed = days.filter { $0.dayStatus == .completed }.count
        let missed = days.filter { $0.dayStatus == .missed }.count
        let remaining = days.filter { $0.dayStatus == .planned || $0.dayStatus == .rebalanced }.count
        let rest = days.filter { $0.isRestDay }.count

        // Try to get focus from the plan
        let focus: String
        if let context = modelContext {
            let desc = FetchDescriptor<TrainingPlan>(
                predicate: #Predicate<TrainingPlan> { $0.id == planId }
            )
            let plan = try? context.fetch(desc).first
            focus = plan?.weeks.first(where: { $0.weekNumber == planWeek })?.focus ?? ""
        } else {
            focus = ""
        }

        return WeekSummary(
            planWeekNumber: planWeek,
            focus: focus,
            totalDays: days.count,
            completedCount: completed,
            missedCount: missed,
            remainingCount: remaining,
            restCount: rest
        )
    }

    // MARK: - Helpers

    private func nextPreferredDay(from date: Date, preferred: [Int], calendar: Calendar) -> Date {
        var candidate = date
        for _ in 0..<7 {
            let weekday = calendar.component(.weekday, from: candidate)
            if preferred.contains(weekday) { return candidate }
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }
        return date // fallback to original if no match in 7 days
    }
}
