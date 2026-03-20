import SwiftUI
import SwiftData

// MARK: - Week Plan View

struct WeekPlanView: View {
    let planId: UUID
    let profile: UserProfile
    var workoutsCompleted: Int = 0
    var workoutsTarget: Int = 4
    var dailyStreak: Int = 0

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<TrainingPlan> { $0.isActive }) private var activePlans: [TrainingPlan]
    @Query private var allWorkouts: [Workout]

    private var allScheduledDays: [ScheduledPlanDay] {
        PlanScheduleService.shared.weekDays(planId: planId)
    }

    @State private var selectedDay: ScheduledPlanDay?
    @State private var showingDayDetail = false
    @State private var showingPlanEdit = false
    @State private var showingMonthCalendar = false

    private var weekDays: [WeekDayItem] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today) else { return [] }

        let scheduledDays = allScheduledDays.filter { $0.planId == planId }

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekInterval.start) else { return nil }
            let dayStart = calendar.startOfDay(for: date)
            let scheduledDay = scheduledDays.first { calendar.isDate($0.scheduledDate, inSameDayAs: dayStart) }
            return WeekDayItem(
                date: dayStart,
                isToday: calendar.isDateInToday(dayStart),
                scheduledDay: scheduledDay
            )
        }
    }

    private var weekSummary: PlanScheduleService.WeekSummary? {
        PlanScheduleService.shared.currentWeekSummary(planId: planId)
    }

    private var activePlan: TrainingPlan? {
        activePlans.first
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header
            weekHeader

            // Day cards
            HStack(spacing: 6) {
                ForEach(weekDays, id: \.date) { item in
                    WeekPlanDayCell(item: item) {
                        selectedDay = item.scheduledDay
                        if item.scheduledDay != nil {
                            showingDayDetail = true
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(GQColors.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(GQColors.borderSubtle, lineWidth: 1))
        .sheet(isPresented: $showingDayDetail) {
            if let day = selectedDay {
                PlanDayDetailSheet(planDay: day, profile: profile)
                    .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $showingPlanEdit) {
            if let plan = activePlan {
                PlanEditSheet(plan: plan)
                    .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $showingMonthCalendar) {
            CalendarHistoryView(workouts: allWorkouts)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var weekHeader: some View {
        HStack(spacing: 10) {
            // Mini progress ring (28px)
            ZStack {
                Circle()
                    .stroke(GQColors.adaptiveOverlay(0.08), lineWidth: 3)
                    .frame(width: 28, height: 28)
                Circle()
                    .trim(from: 0, to: workoutsTarget > 0 ? CGFloat(workoutsCompleted) / CGFloat(workoutsTarget) : 0)
                    .stroke(GQGradients.primary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 28, height: 28)
                Text("\(workoutsCompleted)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(GQColors.textPrimary)
            }

            Button {
                showingMonthCalendar = true
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("This Week")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(GQColors.textPrimary)
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                            .foregroundColor(GQColors.textTertiary)
                    }

                    HStack(spacing: 6) {
                        Text("\(workoutsCompleted)/\(workoutsTarget) done")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(workoutsCompleted > 0 ? GQColors.success : GQColors.textTertiary)

                        if let summary = weekSummary {
                            Text("· Week \(summary.planWeekNumber)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(GQColors.textTertiary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Streak badge
            if dailyStreak > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Text("\(dailyStreak)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.1), in: Capsule())
            }

            Button {
                showingPlanEdit = true
            } label: {
                Text("Edit")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(GQColors.deepBlue)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Week Day Item

struct WeekDayItem {
    let date: Date
    let isToday: Bool
    let scheduledDay: ScheduledPlanDay?

    var dayLabel: String {
        date.formatted(.dateTime.weekday(.narrow))
    }

    var dateNumber: String {
        date.formatted(.dateTime.day())
    }

    var status: PlanDayStatus {
        scheduledDay?.dayStatus ?? .rest
    }

    var hasWorkout: Bool {
        guard let day = scheduledDay else { return false }
        return !day.isRestDay
    }

    var statusColor: Color {
        switch status {
        case .completed, .shortened: return GQColors.success
        case .missed: return .orange
        case .moved, .swapped: return GQColors.deepBlue
        case .planned, .rebalanced: return GQColors.textTertiary
        case .rest, .recovery: return GQColors.textTertiary.opacity(0.5)
        case .comeback: return .orange
        }
    }

    var icon: String? {
        switch status {
        case .completed, .shortened: return "checkmark"
        case .missed: return "xmark"
        case .moved, .swapped: return "arrow.right"
        case .rest, .recovery: return "moon.fill"
        case .comeback: return "arrow.counterclockwise"
        default: return nil
        }
    }
}

// MARK: - Week Plan Day Cell

struct WeekPlanDayCell: View {
    let item: WeekDayItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                // Day label
                Text(item.dayLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(item.isToday ? GQColors.textPrimary : GQColors.textTertiary)

                // Status circle
                ZStack {
                    Circle()
                        .fill(cellBackground)
                        .frame(width: 36, height: 36)

                    if item.isToday && item.status == .planned {
                        Circle()
                            .strokeBorder(GQGradients.primary.opacity(0.6), lineWidth: 2)
                            .frame(width: 36, height: 36)
                    }

                    if let icon = item.icon {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(item.statusColor)
                    } else {
                        Text(item.dateNumber)
                            .font(.system(size: 14, weight: item.isToday ? .bold : .regular, design: .rounded))
                            .foregroundColor(item.isToday ? GQColors.textPrimary : GQColors.textSecondary)
                    }
                }

                // Workout type label
                if item.hasWorkout, let day = item.scheduledDay {
                    Text(shortLabel(day.label))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(item.statusColor)
                        .lineLimit(1)
                } else if item.status == .rest || item.status == .recovery {
                    Text("Rest")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(GQColors.textTertiary.opacity(0.6))
                } else {
                    Color.clear.frame(height: 10)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var cellBackground: Color {
        switch item.status {
        case .completed, .shortened:
            return GQColors.success.opacity(0.15)
        case .missed:
            return Color.orange.opacity(0.12)
        case .moved, .swapped:
            return GQColors.deepBlue.opacity(0.1)
        case .rest, .recovery:
            return GQColors.adaptiveOverlay(0.03)
        default:
            return item.isToday ? GQColors.adaptiveOverlay(0.04) : GQColors.adaptiveOverlay(0.03)
        }
    }

    private func shortLabel(_ label: String) -> String {
        let mapping: [String: String] = [
            "Push Day": "Push",
            "Pull Day": "Pull",
            "Leg Day": "Legs",
            "Upper Body": "Upper",
            "Lower Body": "Lower",
            "Full Body": "Full",
        ]
        return mapping[label] ?? String(label.prefix(5))
    }
}

// MARK: - Plan Day Detail Sheet

struct PlanDayDetailSheet: View {
    let planDay: ScheduledPlanDay
    let profile: UserProfile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Status badge
                    statusBadge

                    // Exercises list
                    if !planDay.exercises.isEmpty {
                        exercisesList
                    }

                    // Actions (only for future actionable days)
                    if planDay.dayStatus == .planned || planDay.dayStatus == .rebalanced {
                        actionButtons
                    }
                }
                .padding(20)
            }
            .navigationTitle(planDay.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .medium))
                }
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        let status = planDay.dayStatus
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor(status))
                .frame(width: 10, height: 10)
            Text(statusLabel(status))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(GQColors.textSecondary)

            if planDay.dayStatus == .moved, let original = planDay.originalDate {
                Text("· moved from \(original.formatted(.dateTime.weekday(.wide)))")
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textTertiary)
            }
        }
    }

    @ViewBuilder
    private var exercisesList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Exercises")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(GQColors.textSecondary)

            ForEach(planDay.exercises, id: \.id) { exercise in
                HStack {
                    Text(exercise.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(GQColors.textPrimary)
                    Spacer()
                    Text("\(exercise.sets) × \(exercise.reps)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(GQColors.textTertiary)
                }
                .padding(.vertical, 6)
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 10) {
            // Move to tomorrow
            let calendar = Calendar.current
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: planDay.scheduledDate) {
                Button {
                    PlanScheduleService.shared.moveDay(planDay.id, to: tomorrow)
                    dismiss()
                } label: {
                    Label("Move to Tomorrow", systemImage: "arrow.right")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(GQColors.deepBlue)
                        .padding(12)
                        .background(GQColors.deepBlue.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }

            // Mark as rest
            Button {
                PlanScheduleService.shared.markAsRest(planDay.id)
                dismiss()
            } label: {
                Label("Rest Here Instead", systemImage: "moon.fill")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)
                    .padding(12)
                    .background(GQColors.adaptiveOverlay(0.05), in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }

    private func statusColor(_ status: PlanDayStatus) -> Color {
        switch status {
        case .completed, .shortened: return GQColors.success
        case .missed: return .orange
        case .moved, .swapped: return GQColors.deepBlue
        case .planned, .rebalanced: return GQColors.textTertiary
        case .rest, .recovery: return GQColors.textTertiary.opacity(0.5)
        case .comeback: return .orange
        }
    }

    private func statusLabel(_ status: PlanDayStatus) -> String {
        switch status {
        case .planned: return "Planned"
        case .completed: return "Completed"
        case .missed: return "Missed"
        case .moved: return "Moved"
        case .shortened: return "Shortened"
        case .swapped: return "Swapped"
        case .rest: return "Rest Day"
        case .recovery: return "Recovery Day"
        case .comeback: return "Comeback Workout"
        case .rebalanced: return "Rebalanced"
        }
    }
}

// MARK: - Plan Edit Sheet

struct PlanEditSheet: View {
    let plan: TrainingPlan
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var daysPerWeek: Int
    @State private var applyToFuture = false

    init(plan: TrainingPlan) {
        self.plan = plan
        let trainingDays = plan.weeks.first?.days.filter { !$0.isRestDay }.count ?? 3
        _daysPerWeek = State(initialValue: trainingDays)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Days per week
                VStack(alignment: .leading, spacing: 8) {
                    Text("Training Days")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                    Text("How many days do you want to train this week?")
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textSecondary)

                    HStack(spacing: 8) {
                        ForEach(2...6, id: \.self) { day in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    daysPerWeek = day
                                }
                            } label: {
                                Text("\(day)")
                                    .font(.system(size: 17, weight: day == daysPerWeek ? .bold : .medium, design: .rounded))
                                    .foregroundStyle(day == daysPerWeek ? .white : GQColors.textPrimary)
                                    .frame(width: 44, height: 44)
                                    .background {
                                        if day == daysPerWeek {
                                            Circle().fill(GQGradients.primary)
                                        } else {
                                            Circle()
                                                .fill(GQColors.adaptiveOverlay(0.06))
                                                .overlay(Circle().stroke(GQColors.borderDefault, lineWidth: 1))
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Scope toggle
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $applyToFuture) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apply to future weeks too")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(GQColors.textPrimary)
                            Text("Otherwise, this change only affects this week")
                                .font(.system(size: 12))
                                .foregroundColor(GQColors.textTertiary)
                        }
                    }
                    .tint(GQColors.deepBlue)
                }

                // Rebalance button
                Button {
                    PlanScheduleService.shared.rebalanceCurrentWeek(planId: plan.id)
                    dismiss()
                } label: {
                    Label("Rebalance This Week", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(GQColors.deepBlue)
                        .padding(.vertical, 12)
                        .background(GQColors.deepBlue.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(GQGradients.primary, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .navigationTitle("Edit Plan")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
