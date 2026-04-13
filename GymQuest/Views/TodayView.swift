//
//  TodayView.swift
//  GymQuest
//
//  Created by Benjamin Hilderman
//
//  Hero home screen — week calendar, start workout CTA,
//  daily dashboard stats, and last workout quick-repeat.
//

import SwiftUI
import SwiftData

struct TodayView: View {
    @Bindable var profile: UserProfile

    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workout.date, order: .reverse) private var allWorkouts: [Workout]

    @Query(filter: #Predicate<TrainingPlan> { $0.isActive }) private var activePlans: [TrainingPlan]

    // Pod & accountability data
    @Query private var allPodMemberships: [PodMembership]
    @Query private var allPods: [Pod]
    @Query private var allMomentumStates: [UserMomentumState]
    @Query private var allClubs: [Club]

    // Challenge data
    @Query(sort: \ChallengeEnrollment.enrolledAt, order: .reverse) private var allChallengeEnrollments: [ChallengeEnrollment]
    @Query(sort: \Challenge.startDate, order: .reverse) private var allChallenges: [Challenge]

    @State private var showDraftBanner = false
    @State private var draftWorkoutType: String = ""
    @State private var draftStartTime: Date = Date()
    @State private var showingPlanOptions = false
    @State private var selectedSubTab: TodaySubTab = .today
    @State private var consistencyState: ConsistencyState = .onTrack
    @State private var showWeeklyScheduleEditor = false
    @State private var selectedPlanDay: IdentifiableInt? = nil

    private enum TodaySubTab: String, CaseIterable {
        case today = "Today"
        case progress = "Progress"
    }

    // MARK: - Pod / Challenge Computed Props

    private var primaryPodMembership: PodMembership? {
        allPodMemberships.first { $0.userId == profile.id && $0.isPrimaryPod }
    }

    private var primaryPod: Pod? {
        guard let membership = primaryPodMembership else { return nil }
        return allPods.first { $0.id == membership.podId }
    }

    private var userMomentum: UserMomentumState? {
        allMomentumStates.first { $0.userId == profile.id }
    }


    private var primaryClub: Club? {
        guard let clubId = primaryPod?.clubId else { return nil }
        return allClubs.first { $0.id == clubId }
    }


    private var activeChallengeEnrollments: [ChallengeEnrollment] {
        allChallengeEnrollments.filter { enrollment in
            enrollment.userId == profile.id &&
            !enrollment.isCompleted &&
            allChallenges.contains { $0.id == enrollment.challengeId && $0.isActive }
        }
    }

    // MARK: - Workout Data

    private var nonRestWorkouts: [Workout] {
        allWorkouts.filter { $0.type != .rest }
    }

    private var weeklyWorkoutMinutes: Int {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }
        return nonRestWorkouts.filter { $0.date >= startOfWeek }.reduce(0) { $0 + $1.duration }
    }

    private var weeklyTotalVolume: Double {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }
        return nonRestWorkouts.filter { $0.date >= startOfWeek }.reduce(0) { $0 + $1.totalVolume }
    }

    private var weeklyTotalSets: Int {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }
        return nonRestWorkouts.filter { $0.date >= startOfWeek }.reduce(0) { $0 + $1.totalSets }
    }

    private var workoutsThisWeek: Int {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }
        return nonRestWorkouts.filter { $0.date >= startOfWeek }.count
    }

    private var thisWeekWorkoutDates: [Date] {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }
        return nonRestWorkouts.filter { $0.date >= startOfWeek }.map(\.date)
    }

    private var thisWeekWorkoutIcons: [Date: String] {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return [:] }
        var icons: [Date: String] = [:]
        for w in nonRestWorkouts where w.date >= startOfWeek {
            icons[w.date] = w.type.icon
        }
        return icons
    }

    private var lastNonRestWorkout: Workout? {
        nonRestWorkouts.first
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                todayTabBar

                ScrollView {
                    switch selectedSubTab {
                    case .today:
                        todayContent
                    case .progress:
                        ProgressAnalyticsView(profile: profile, inline: true)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .gqPageBackground()
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showWeeklyScheduleEditor) {
            WeeklyScheduleEditorSheet(profile: profile)
                .presentationDetents([.medium, .large])
        }
        .task {
            checkForDraft()
            MockDataSeeder.seedIfNeeded(modelContext: modelContext, profile: profile)
            MomentumService.shared.checkInactivity(userId: profile.id)
            consistencyState = MomentumService.shared.evaluateState(userId: profile.id)
            ChallengeService.shared.autoEnroll(userId: profile.id, consistencyState: consistencyState)
            PodService.shared.evaluateLifecycles()

            if let activePlan = activePlans.first {
                PlanScheduleService.shared.resolveMissedDays(planId: activePlan.id)
            }

            // Give @Query time to pick up new enrollments from autoEnroll
            try? await Task.sleep(for: .milliseconds(100))
            consistencyState = MomentumService.shared.evaluateState(userId: profile.id)
        }
    }

    // MARK: - Interactive Week Plan Row
    //
    // Tap any day to set its type. Shows colored labels under each day.
    // The calendar IS the planner.

    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]
    // Ordered as: Sun=1, Mon=2, ..., Sat=7

    @ViewBuilder
    private var weekPlanRow: some View {
        VStack(spacing: 8) {
            // Row of tappable plan chips — one per day
            HStack(spacing: 0) {
                ForEach(1...7, id: \.self) { weekday in
                    let planned = profile.weeklySchedule[weekday]
                    let type = planned.flatMap { WorkoutType(rawValue: $0) }
                    let isToday = weekday == todayWeekday

                    Button {
                        selectedPlanDay = IdentifiableInt(value: weekday)
                        #if canImport(UIKit)
                        UISelectionFeedbackGenerator().selectionChanged()
                        #endif
                    } label: {
                        VStack(spacing: 3) {
                            if let type {
                                Text(shortLabel(type))
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(isToday ? .white : typeColor(type))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 3)
                                    .background(
                                        isToday
                                            ? AnyShapeStyle(GQGradients.primary)
                                            : AnyShapeStyle(typeColor(type).opacity(0.12))
                                    )
                                    .clipShape(Capsule())
                            } else {
                                Text("—")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(GQColors.textTertiary.opacity(0.4))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 3)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Suggest + Templates row
            if profile.weeklySchedule.isEmpty {
                HStack(spacing: 8) {
                    Button {
                        applySuggestedPlan()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 9, weight: .bold))
                            Text("Suggest a plan")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(GQColors.vividPurple)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(GQColors.vividPurple.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button { showWeeklyScheduleEditor = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 9, weight: .bold))
                            Text("Templates")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(GQColors.textTertiary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(GQColors.adaptiveOverlay(0.05))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
        }
    }

    private func shortLabel(_ type: WorkoutType) -> String {
        switch type {
        case .push: return "Push"
        case .pull: return "Pull"
        case .legs: return "Legs"
        case .upper: return "Upper"
        case .lower: return "Lower"
        case .fullBody: return "Full"
        case .cardio: return "Cardio"
        case .hiit: return "HIIT"
        case .yoga: return "Yoga"
        case .rest: return "Rest"
        case .glutes: return "Glutes"
        case .abs: return "Abs"
        case .custom: return "Custom"
        }
    }

    private func typeColor(_ type: WorkoutType) -> Color {
        switch type {
        case .push: return GQColors.deepBlue
        case .pull: return GQColors.vividPurple
        case .legs: return Color(red: 1.0, green: 0.55, blue: 0.2)
        case .cardio: return GQColors.success
        case .hiit: return Color.red
        case .rest: return GQColors.textTertiary
        case .upper: return Color(red: 0.3, green: 0.7, blue: 1.0)
        case .lower: return Color(red: 0.9, green: 0.6, blue: 0.2)
        default: return GQColors.deepBlue
        }
    }

    /// AI plan suggestion — deterministic, based on daysPerWeek + experience.
    /// Not a premium feature — just smart defaults.
    private func applySuggestedPlan() {
        let days = profile.daysPerWeek
        var plan: [Int: String] = [:]

        switch days {
        case 1...2:
            // Full body
            plan = [2: "Full Body", 5: "Full Body"]
        case 3:
            // Full body 3x
            plan = [2: "Full Body", 4: "Full Body", 6: "Full Body"]
        case 4:
            // Upper/Lower
            plan = [2: "Upper", 3: "Lower", 5: "Upper", 6: "Lower"]
        case 5:
            // PPL + Upper/Lower
            plan = [2: "Push", 3: "Pull", 4: "Legs", 5: "Upper", 6: "Lower"]
        default:
            // PPL x2
            plan = [2: "Push", 3: "Pull", 4: "Legs", 5: "Push", 6: "Pull", 7: "Legs"]
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            profile.weeklySchedule = plan
            try? modelContext.save()
        }
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    // MARK: - Today's Plan Card

    private var todayWeekday: Int { Calendar.current.component(.weekday, from: Date()) }

    private var todayPlannedType: WorkoutType? {
        guard let rawValue = profile.weeklySchedule[todayWeekday] else { return nil }
        return WorkoutType(rawValue: rawValue)
    }

    @State private var showTodayOverride = false

    /// Did the user miss yesterday's planned workout?
    private var missedYesterday: Bool {
        let cal = Calendar.current
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: Date()) else { return false }
        let yd = cal.component(.weekday, from: yesterday)
        guard profile.weeklySchedule[yd] != nil else { return false }
        let yesterdayType = profile.weeklySchedule[yd]
        if yesterdayType == "Rest" { return false }
        // Check if yesterday was logged
        let yesterdayStart = cal.startOfDay(for: yesterday)
        let hasWorkout = nonRestWorkouts.contains { cal.isDate($0.date, inSameDayAs: yesterday) }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let manualDone = profile.dayOverrides[f.string(from: yesterday)] == "_done"
        return !hasWorkout && !manualDone
    }

    /// What's planned for today — checks override first, then template
    private var todayPlannedLabel: String? {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let key = f.string(from: Date())
        if let override = profile.dayOverrides[key] {
            if override == "_skip" || override == "_done" { return nil }
            return override
        }
        return profile.weeklySchedule[todayWeekday]
    }

    @ViewBuilder
    private var todayPlanCard: some View {
        let planned = todayPlannedLabel
        let plannedType = planned.flatMap { WorkoutType(rawValue: $0) }
        let isRest = planned == "Rest"

        if let planned, !isRest {
            // Today has a planned workout
            VStack(spacing: 10) {
                HStack(spacing: 14) {
                    Image(systemName: plannedType?.icon ?? "dumbbell.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AnyShapeStyle(GQGradients.primary))
                        .frame(width: 44, height: 44)
                        .background(GQColors.deepBlue.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today: \(planned)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(GQColors.textPrimary)
                        Text("From your schedule")
                            .font(.system(size: 11))
                            .foregroundColor(GQColors.textTertiary)
                    }

                    Spacer()

                    Button {
                        appState.showingWorkoutStartOptions = true
                    } label: {
                        Text("Start")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(GQGradients.primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                // Quick actions: Change today + Shift if missed yesterday
                HStack(spacing: 10) {
                    Button {
                        selectedPlanDay = IdentifiableInt(value: todayWeekday)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.swap")
                                .font(.system(size: 9, weight: .bold))
                            Text("Change")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(GQColors.textTertiary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(GQColors.adaptiveOverlay(0.05))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    if missedYesterday {
                        Button { shiftScheduleOnToday(by: 1) } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 9, weight: .bold))
                                Text("Missed yesterday? Shift forward")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(GQColors.vividPurple)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(GQColors.vividPurple.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
            }
            .padding(14)
            .background(GQColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(GQColors.borderDefault, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.06), radius: 8, y: 3)
            .sheet(item: $selectedPlanDay) { item in
                DayOverrideSheet(weekday: item.value, date: Date(), profile: profile)
                    .presentationDetents([.height(280)])
            }
        } else if isRest {
            HStack(spacing: 12) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 16))
                    .foregroundColor(GQColors.textTertiary)
                Text("Rest day. You've earned it.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)
                Spacer()
                Button {
                    appState.showingWorkoutStartOptions = true
                } label: {
                    Text("Train anyway")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(GQColors.textTertiary)
                }
            }
            .padding(14)
            .background(GQColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(GQColors.borderDefault, lineWidth: 1))
        } else if !profile.weeklySchedule.isEmpty {
            // Has a schedule but today isn't in it (Off day)
            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.system(size: 16))
                    .foregroundColor(GQColors.textTertiary)
                Text("No workout planned today.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)
                Spacer()
                Button {
                    appState.showingWorkoutStartOptions = true
                } label: {
                    Text("Start one")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(GQColors.vividPurple)
                }
            }
            .padding(14)
            .background(GQColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(GQColors.borderDefault, lineWidth: 1))
        }
    }

    private func shiftScheduleOnToday(by offset: Int) {
        let current = profile.weeklySchedule
        guard !current.isEmpty else { return }
        var shifted: [Int: String] = [:]
        for (wd, type) in current {
            var newWd = wd + offset
            if newWd < 1 { newWd = 7 }
            if newWd > 7 { newWd = 1 }
            shifted[newWd] = type
        }
        withAnimation(.easeInOut(duration: 0.15)) {
            profile.weeklySchedule = shifted
            try? modelContext.save()
        }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(GQColors.adaptiveOverlay(0.08))
            .frame(height: 0.33)
            .padding(.vertical, 1)
    }

    private var todayContent: some View {
        VStack(spacing: 6) {
            dateHeader

            if showDraftBanner {
                resumeDraftBanner
                sectionDivider
            }

            // Tap the calendar to open the full weekly schedule editor
            Button { showWeeklyScheduleEditor = true } label: {
                WeeklyProgressRing(
                    completed: workoutsThisWeek,
                    target: $profile.daysPerWeek,
                    workoutDates: thisWeekWorkoutDates,
                    workoutIcons: thisWeekWorkoutIcons,
                    dailyStreak: dailyStreak,
                    weeklyStreak: weeklyStreak,
                    totalMinutes: weeklyWorkoutMinutes,
                    totalSets: weeklyTotalSets,
                    totalVolume: weeklyTotalVolume,
                    plannedTypes: profile.weeklySchedule
                )
            }
            .buttonStyle(.plain)

            // Interactive plan row — tap any day to set its type
            weekPlanRow

            // Today's planned workout
            todayPlanCard

            sectionDivider

            // Apple Fitness-style activity rings
            ActivityRingsCard(
                workoutMinutes: weeklyWorkoutMinutes,
                minuteGoal: 150,
                totalSets: weeklyTotalSets,
                setGoal: max(profile.daysPerWeek * 15, 60),
                streak: dailyStreak,
                streakGoal: 7
            )

            sectionDivider

            // Progressive challenges (3 at a time, tier-based)
            TodayChallengesSection(profile: profile)

            sectionDivider

            TodayDashboardSection(
                profile: profile,
                workoutsThisWeek: workoutsThisWeek,
                allWorkouts: allWorkouts
            )
            .environment(\.modelContext, modelContext)

            sectionDivider

            // Pod / Find a Pod card
            podOrOnboardingCard
                .featureGated(FeatureFlags.shared.podSystemEnabled)

            if let milestone = nextMilestone {
                sectionDivider
                milestoneRow(milestone)
            }

            if let todayPlan = todaysPlanDay {
                sectionDivider
                plannedWorkoutCard(todayPlan)
            }

            // Challenge card (e.g. Set Slayer)
            if let firstEnrollment = activeChallengeEnrollments.first,
               let challenge = allChallenges.first(where: { $0.id == firstEnrollment.challengeId }),
               FeatureFlags.shared.challengeEngineEnabled {
                sectionDivider
                challengeCard(enrollment: firstEnrollment, challenge: challenge)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 100)
    }

    // MARK: - Draft Recovery

    private func checkForDraft() {
        guard !appState.isWorkoutActive else {
            showDraftBanner = false
            return
        }
        if let draft = WorkoutDraft.load() {
            draftWorkoutType = draft.customTitle ?? draft.workoutTypeRaw
            draftStartTime = draft.startTime
            showDraftBanner = true
        } else {
            showDraftBanner = false
        }
    }

    private func resumeDraft() {
        guard let draft = WorkoutDraft.load(),
              let type = draft.workoutType else {
            WorkoutDraft.clear()
            showDraftBanner = false
            return
        }
        let exercises = draft.toActiveExercises()
        appState.startWorkout(type: type, exercises: exercises, customTitle: draft.customTitle)
        showDraftBanner = false
    }

    private func discardDraft() {
        WorkoutDraft.clear()
        withAnimation { showDraftBanner = false }
    }

    private var resumeDraftBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(GQGradients.primary.opacity(0.08))
                    .frame(width: 40, height: 40)
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(GQGradients.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(draftWorkoutType)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)
                Text(draftStartTime, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textTertiary)
            }

            Spacer()

            Button {
                discardDraft()
            } label: {
                Text("Dismiss")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(GQColors.textTertiary)
            }
            .buttonStyle(.plain)

            Button {
                resumeDraft()
            } label: {
                Text("Resume")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(GQGradients.primary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .homeSocialCard(cornerRadius: 14)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Streak & Milestone

    private var dailyStreak: Int {
        let calendar = Calendar.current
        let activePlan = activePlans.first
        let planDays: [TrainingPlanDay]? = activePlan?.weeks.flatMap(\.days)
        let planLength = planDays?.count ?? 7
        var streak = 0
        var dayOffset = 0

        while true {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: calendar.startOfDay(for: Date())) else { break }

            let hasWorkout = nonRestWorkouts.contains { calendar.isDate($0.date, inSameDayAs: date) }

            if hasWorkout {
                streak += 1
            } else if let days = planDays {
                let dayIndex = dayOffset % planLength
                let reversedIndex = (planLength - dayIndex) % planLength
                if reversedIndex < days.count && days[reversedIndex].isRestDay {
                    streak += 1
                } else if dayOffset == 0 {
                    break
                } else {
                    break
                }
            } else {
                if dayOffset == 0 { break }
                else { break }
            }
            dayOffset += 1
            if dayOffset > 365 { break }
        }
        return streak
    }

    private var weeklyStreak: Int {
        let calendar = Calendar.current
        let target = profile.daysPerWeek
        guard target > 0 else { return 0 }
        var streak = 0
        var weeksAgo = 1

        while true {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: Date()),
                  let interval = calendar.dateInterval(of: .weekOfYear, for: weekStart) else { break }
            let count = nonRestWorkouts.filter { $0.date >= interval.start && $0.date < interval.end }.count
            if count >= target {
                streak += 1
            } else {
                break
            }
            weeksAgo += 1
            if weeksAgo > 52 { break }
        }
        return streak
    }

    private var nextMilestone: (label: String, current: Int, target: Int)? {
        let total = nonRestWorkouts.count
        let milestones = [10, 25, 50, 75, 100, 150, 200, 250, 300, 365, 500, 750, 1000]
        if let next = milestones.first(where: { $0 > total }) {
            return ("\(next) workouts", total, next)
        }
        return nil
    }

    private func milestoneRow(_ milestone: (label: String, current: Int, target: Int)) -> some View {
        let fraction = CGFloat(milestone.current) / CGFloat(milestone.target)
        let remaining = milestone.target - milestone.current

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(GQGradients.primary.opacity(0.06))
                    .frame(width: 46, height: 46)
                    .blur(radius: 5)

                Circle()
                    .stroke(GQColors.adaptiveOverlay(0.06), lineWidth: 4)
                    .frame(width: 38, height: 38)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(GQGradients.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 38, height: 38)

                Text("\(milestone.current)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(GQColors.textPrimary)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text("Next: \(milestone.target) workouts")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)
                Text("\(remaining) more to go")
                    .font(.system(size: 11))
                    .foregroundColor(GQColors.textTertiary)
            }

            Spacer()

            Text("\(Int(fraction * 100))%")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(GQGradients.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(GQGradients.primary.opacity(0.08))
                )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Date Header

    private var dateHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text(greeting)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(GQColors.textTertiary)
                Text(Date(), format: .dateTime.weekday(.wide).month(.abbreviated).day())
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(GQColors.textPrimary)
            }
            Spacer()
        }
        .padding(.top, 16)
        .padding(.bottom, 6)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    // MARK: - Tab Bar (Feed-style)

    private var subTabIndex: Int {
        TodaySubTab.allCases.firstIndex(of: selectedSubTab) ?? 0
    }

    private var todayTabBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(TodaySubTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue)
                        .font(.system(size: 13, weight: selectedSubTab == tab ? .semibold : .regular))
                        .foregroundColor(selectedSubTab == tab ? GQColors.textPrimary : GQColors.textTertiary)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedSubTab = tab
                        }
                }
            }
            .padding(.bottom, 6)

            ZStack(alignment: .leading) {
                // Full-width grey baseline
                Rectangle()
                    .fill(GQColors.borderSubtle)
                    .frame(height: 0.5)

                // Active tab accent underline
                GeometryReader { geometry in
                    let tabWidth = geometry.size.width / CGFloat(TodaySubTab.allCases.count)
                    Rectangle()
                        .fill(GQGradients.primary)
                        .frame(width: tabWidth, height: 1.5)
                        .clipShape(RoundedRectangle(cornerRadius: 0.75))
                        .offset(x: tabWidth * CGFloat(subTabIndex))
                        .animation(.easeInOut(duration: 0.3), value: subTabIndex)
                }
                .frame(height: 1.5)
            }
            .frame(height: 1.5)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 2)
        .background(
            GQColors.background
                .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: - Start Workout Hero Button

    private var startWorkoutHeroButton: some View {
        Button {
            appState.showingWorkoutStartOptions = true
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 32, height: 32)
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                Text("Start Workout")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .opacity(0.6)
            }
            .foregroundColor(.white)
            .padding(.leading, 10)
            .padding(.trailing, 16)
            .padding(.vertical, 10)
            .background(GQGradients.primary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Planned Workout Card

    private var todaysPlanDay: TrainingPlanDay? {
        guard let plan = activePlans.first else { return nil }
        guard let day = plan.currentDayPlan, !day.isRestDay else { return nil }
        return day
    }

    private var plannedWorkoutType: WorkoutType? {
        guard let day = todaysPlanDay else { return nil }
        return WorkoutType(rawValue: day.workoutType)
    }

    @ViewBuilder
    private func plannedWorkoutCard(_ day: TrainingPlanDay) -> some View {
        let wType = WorkoutType(rawValue: day.workoutType) ?? .push

        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(GQGradients.primary.opacity(0.08))
                        .frame(width: 40, height: 40)
                    Image(systemName: wType.icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(GQGradients.primary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(day.label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                    Text("\(day.exercises.count) exercises · Today's plan")
                        .font(.system(size: 12))
                        .foregroundColor(GQColors.textTertiary)
                }

                Spacer()
            }

            HStack(spacing: 8) {
                planOptionButton(label: "Repeat Last", icon: "clock.arrow.circlepath") {
                    startPlannedFromLast(wType)
                }
                planOptionButton(label: "AI Assist", icon: "sparkles") {
                    startPlannedAI(wType)
                }
                planOptionButton(label: "Empty", icon: "plus") {
                    startPlannedFresh(wType)
                }
            }
        }
        .padding(14)
        .homeSocialCard(cornerRadius: 14)
    }

    private func planOptionButton(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(GQColors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(GQColors.adaptiveOverlay(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Plan Start Actions

    private func startPlannedFromLast(_ type: WorkoutType) {
        if let last = nonRestWorkouts.first(where: { $0.type == type }) {
            let exercises = last.exercises.sorted(by: { $0.order < $1.order }).map { exercise in
                ActiveExercise(
                    name: exercise.name,
                    muscleGroup: exercise.muscleGroup,
                    sets: exercise.sets.sorted(by: { $0.order < $1.order }).map { set in
                        ActiveSet(reps: set.reps, weight: set.weight)
                    }
                )
            }
            appState.startWorkout(type: type, exercises: exercises)
        } else {
            appState.startWorkout(type: type, exercises: [])
        }
    }

    private func startPlannedAI(_ type: WorkoutType) {
        appState.showingWorkoutStartOptions = true
    }

    private func startPlannedFresh(_ type: WorkoutType) {
        appState.startWorkout(type: type, exercises: [])
    }

    // MARK: - Pod Row

    @ViewBuilder
    private var podOrOnboardingCard: some View {
        if let pod = primaryPod {
            podRow(pod)
        } else if allClubs.isEmpty {
            podPromptRow(title: "Join a Club", subtitle: "Train with others")
        } else {
            podPromptRow(title: "Find a Pod", subtitle: "Accountability group")
        }
    }

    private func podPromptRow(title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(GQGradients.primary.opacity(0.06))
                    .frame(width: 46, height: 46)
                    .blur(radius: 5)
                Circle()
                    .stroke(GQColors.adaptiveOverlay(0.06), lineWidth: 4)
                    .frame(width: 38, height: 38)
                Image(systemName: "person.3")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(GQGradients.primary)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(GQColors.textTertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(GQColors.textTertiary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(GQColors.adaptiveOverlay(0.04)))
        }
        .padding(14)
        .homeSocialCard(cornerRadius: 14)
        .onTapGesture {
            appState.selectedTab = .feed
            NotificationCenter.default.post(name: .navigateToFeedTab, object: FeedTab.clubs)
        }
    }

    private func podRow(_ pod: Pod) -> some View {
        let completed = userMomentum?.currentWeekCompleted ?? workoutsThisWeek
        let target = pod.weeklyWorkoutTarget
        let fraction = CGFloat(completed) / CGFloat(max(target, 1))
        let remaining = max(target - completed, 0)

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(GQGradients.primary.opacity(0.06))
                    .frame(width: 46, height: 46)
                    .blur(radius: 5)
                Circle()
                    .stroke(GQColors.adaptiveOverlay(0.06), lineWidth: 4)
                    .frame(width: 38, height: 38)
                Circle()
                    .trim(from: 0, to: min(fraction, 1.0))
                    .stroke(GQGradients.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 38, height: 38)
                Text("\(completed)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(GQColors.textPrimary)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(pod.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)
                Text(remaining > 0 ? "\(remaining) more this week" : "Goal complete")
                    .font(.system(size: 11))
                    .foregroundColor(GQColors.textTertiary)
            }

            Spacer()

            Text(fraction >= 1.0 ? "Done" : "\(Int(min(fraction, 1.0) * 100))%")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(fraction >= 1.0 ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(GQGradients.primary))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(AnyShapeStyle(fraction >= 1.0 ? AnyShapeStyle(GQGradients.primary.opacity(0.08)) : AnyShapeStyle(GQGradients.primary.opacity(0.08))))
                )
        }
        .padding(14)
        .homeSocialCard(cornerRadius: 14)
        .onTapGesture {
            appState.selectedTab = .feed
            NotificationCenter.default.post(name: .navigateToFeedTab, object: FeedTab.clubs)
        }
    }

    // MARK: - Challenge Row

    private func challengeCard(enrollment: ChallengeEnrollment, challenge: Challenge) -> some View {
        let fraction = CGFloat(enrollment.progress) / CGFloat(max(challenge.goalTarget, 1))
        let remaining = challenge.goalTarget - enrollment.progress

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(GQGradients.primary.opacity(0.06))
                    .frame(width: 46, height: 46)
                    .blur(radius: 5)
                Circle()
                    .stroke(GQColors.adaptiveOverlay(0.06), lineWidth: 4)
                    .frame(width: 38, height: 38)
                Circle()
                    .trim(from: 0, to: min(fraction, 1.0))
                    .stroke(GQGradients.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 38, height: 38)
                Text("\(enrollment.progress)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(GQColors.textPrimary)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(challenge.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)
                Text(remaining > 0 ? "\(remaining) more to go" : "Challenge complete")
                    .font(.system(size: 11))
                    .foregroundColor(GQColors.textTertiary)
            }

            Spacer()

            Text(fraction >= 1.0 ? "Done" : "\(Int(min(fraction, 1.0) * 100))%")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(fraction >= 1.0 ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(GQGradients.primary))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(AnyShapeStyle(fraction >= 1.0 ? AnyShapeStyle(GQGradients.primary.opacity(0.08)) : AnyShapeStyle(GQGradients.primary.opacity(0.08))))
                )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

}

// MARK: - Apple Fitness-Style Activity Rings

struct ActivityRingsCard: View {
    let workoutMinutes: Int
    let minuteGoal: Int
    let totalSets: Int
    let setGoal: Int
    let streak: Int
    let streakGoal: Int

    @State private var animate = false

    private var moveProgress: CGFloat { min(CGFloat(workoutMinutes) / CGFloat(max(minuteGoal, 1)), 1.5) }
    private var exerciseProgress: CGFloat { min(CGFloat(totalSets) / CGFloat(max(setGoal, 1)), 1.5) }
    private var streakProgress: CGFloat { min(CGFloat(streak) / CGFloat(max(streakGoal, 1)), 1.5) }

    private let moveColor = Color(hex: "FF2D55")       // Apple red
    private let exerciseColor = Color(hex: "A8FF04")    // Apple green
    private let streakColor = Color(hex: "00D4FF")      // Apple cyan

    var body: some View {
        HStack(spacing: 20) {
            // Rings
            ZStack {
                // Move (outer)
                ringTrack(size: 90)
                ringArc(progress: animate ? moveProgress : 0, color: moveColor, size: 90, lineWidth: 10)

                // Exercise (middle)
                ringTrack(size: 66)
                ringArc(progress: animate ? exerciseProgress : 0, color: exerciseColor, size: 66, lineWidth: 10)

                // Streak (inner)
                ringTrack(size: 42)
                ringArc(progress: animate ? streakProgress : 0, color: streakColor, size: 42, lineWidth: 10)
            }
            .frame(width: 100, height: 100)

            // Labels
            VStack(alignment: .leading, spacing: 10) {
                ringLabel(color: moveColor, value: "\(workoutMinutes)", unit: "min", label: "Move", goal: minuteGoal)
                ringLabel(color: exerciseColor, value: "\(totalSets)", unit: "sets", label: "Exercise", goal: setGoal)
                ringLabel(color: streakColor, value: "\(streak)", unit: "days", label: "Streak", goal: streakGoal)
            }

            Spacer()
        }
        .padding(16)
        .homeSocialCard(cornerRadius: 16)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                animate = true
            }
        }
    }

    private func ringTrack(size: CGFloat) -> some View {
        Circle()
            .stroke(GQColors.overlayLight, lineWidth: 10)
            .frame(width: size, height: size)
    }

    private func ringArc(progress: CGFloat, color: Color, size: CGFloat, lineWidth: CGFloat) -> some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(-90))
            .shadow(color: color.opacity(0.4), radius: 3, y: 1)
    }

    private func ringLabel(color: Color, value: String, unit: String, label: String, goal: Int) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(GQColors.textPrimary)
            Text("/\(goal) \(unit)")
                .font(.system(size: 12))
                .foregroundColor(GQColors.textTertiary)
        }
    }
}

// MARK: - Today Challenges Section (Progressive 3-at-a-time)

struct TodayChallengesSection: View {
    @Bindable var profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @Query(sort: \PREvent.date, order: .reverse) private var prEvents: [PREvent]
    @Query(sort: \Post.timestamp, order: .reverse) private var posts: [Post]
    @Query private var squads: [Squad]

    @State private var selectedChallenge: ProfileView.ActiveChallenge? = nil

    private var totalWorkouts: Int { workouts.filter { $0.type != .rest }.count }
    private var userPosts: [Post] { posts.filter { $0.authorId == profile.id } }
    private var usedCount: Int { userPosts.reduce(0) { $0 + $1.timesUsed } }

    private var streak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dates = Array(Set(workouts.filter { $0.type != .rest }.map { calendar.startOfDay(for: $0.date) })).sorted(by: >)
        guard let first = dates.first else { return 0 }
        let gap = calendar.dateComponents([.day], from: first, to: today).day ?? 0
        guard gap <= 2 else { return 0 }
        var s = 1
        for i in 1..<dates.count {
            let diff = calendar.dateComponents([.day], from: dates[i], to: dates[i - 1]).day ?? 0
            if diff <= 2 { s += 1 } else { break }
        }
        return s
    }

    private var daysShownUp: Int {
        Set(workouts.filter { $0.type != .rest }.map { Calendar.current.startOfDay(for: $0.date) }).count
    }

    private var currentChallenges: [ProfileView.ActiveChallenge] {
        let tier = profile.currentChallengeTier
        let favType = workouts.first?.type.rawValue ?? "Push"
        let favExercise = workouts.first?.exercises.first?.name ?? "Bench Press"

        switch tier {
        case 0:
            return [
                .init(icon: "figure.walk", title: "First Workout", description: "Log your first workout.", current: min(totalWorkouts, 1), target: 1, category: "General"),
                .init(icon: "hand.thumbsup.fill", title: "First Reaction", description: "React or comment on a post.", current: min(userPosts.isEmpty ? 0 : 1, 1), target: 1, category: "General"),
                .init(icon: "person.3.fill", title: "Join a Squad", description: "Join your first squad.", current: squads.contains(where: { $0.memberIds.contains(profile.id) }) ? 1 : 0, target: 1, category: "General"),
            ]
        case 1:
            return [
                .init(icon: "dumbbell.fill", title: "3 Workouts", description: "Log 3 total workouts.", current: min(totalWorkouts, 3), target: 3, category: "General"),
                .init(icon: "star.fill", title: "\(favType) Session", description: "Do a \(favType.lowercased()) workout.", current: min(workouts.filter { $0.type.rawValue == favType }.count, 1), target: 1, category: "For You"),
                .init(icon: "paperplane.fill", title: "Share Proof", description: "Send a Proof Card.", current: min(userPosts.filter { $0.proofCardData != nil }.count, 1), target: 1, category: "Mixed"),
            ]
        case 2:
            return [
                .init(icon: "flame.fill", title: "3-Day Streak", description: "Train 3 days with grace.", current: min(streak, 3), target: 3, category: "General"),
                .init(icon: "trophy.fill", title: "\(favExercise) PR", description: "Hit a PR on \(favExercise.lowercased()).", current: min(prEvents.filter { $0.exerciseName == favExercise }.count, 1), target: 1, category: "For You"),
                .init(icon: "person.2.fill", title: "Get Used", description: "Have someone use your workout.", current: min(usedCount, 1), target: 1, category: "Mixed"),
            ]
        case 3:
            return [
                .init(icon: "calendar.badge.checkmark", title: "10 Days", description: "Show up on 10 distinct days.", current: min(daysShownUp, 10), target: 10, category: "General"),
                .init(icon: "bolt.fill", title: "5 \(favType) Days", description: "Complete 5 \(favType.lowercased()) sessions.", current: min(workouts.filter { $0.type.rawValue == favType }.count, 5), target: 5, category: "For You"),
                .init(icon: "bubble.left.and.bubble.right.fill", title: "Social 5", description: "Share 5 posts.", current: min(userPosts.count, 5), target: 5, category: "Mixed"),
            ]
        case 4:
            return [
                .init(icon: "flame.circle.fill", title: "7-Day Streak", description: "Maintain a 7-day streak.", current: min(streak, 7), target: 7, category: "General"),
                .init(icon: "trophy.fill", title: "5 PRs", description: "Hit 5 personal records.", current: min(prEvents.count, 5), target: 5, category: "For You"),
                .init(icon: "person.2.fill", title: "Spotter ×3", description: "Have 3 workouts used.", current: min(usedCount, 3), target: 3, category: "Mixed"),
            ]
        default:
            let n = 5 + (tier - 5)
            return [
                .init(icon: "star.circle.fill", title: "\(10 + n * 5) Workouts", description: "Keep showing up.", current: min(totalWorkouts, 10 + n * 5), target: 10 + n * 5, category: "General"),
                .init(icon: "trophy.fill", title: "\(n * 2) PRs", description: "Keep pushing.", current: min(prEvents.count, n * 2), target: n * 2, category: "For You"),
                .init(icon: "person.2.fill", title: "Spotter ×\(n)", description: "Help others train.", current: min(usedCount, n), target: n, category: "Mixed"),
            ]
        }
    }

    private var allComplete: Bool { currentChallenges.allSatisfy(\.isComplete) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("CHALLENGES")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(GQColors.textSecondary)
                    .tracking(0.6)
                Spacer()
                Text("Tier \(profile.currentChallengeTier + 1)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(GQColors.vividPurple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(GQColors.vividPurple.opacity(0.12))
                    .clipShape(Capsule())
            }

            if allComplete {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        profile.currentChallengeTier += 1
                        try? modelContext.save()
                    }
                    #if canImport(UIKit)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    #endif
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .bold))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("All 3 complete!")
                                .font(.system(size: 14, weight: .bold))
                            Text("Tap to reveal next challenges")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(14)
                    .background(GQGradients.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 6) {
                    ForEach(currentChallenges) { c in
                        Button { selectedChallenge = c } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(c.isComplete ? AnyShapeStyle(GQGradients.primary.opacity(0.15)) : AnyShapeStyle(GQColors.surfaceSecondary))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: c.isComplete ? "checkmark" : c.icon)
                                        .font(.system(size: c.isComplete ? 13 : 15, weight: .bold))
                                        .foregroundStyle(c.isComplete ? AnyShapeStyle(GQColors.success) : AnyShapeStyle(GQGradients.primary))
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(c.title)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(c.isComplete ? GQColors.textTertiary : GQColors.textPrimary)
                                            .strikethrough(c.isComplete)
                                        Text(c.category)
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundColor(c.category == "For You" ? GQColors.vividPurple : GQColors.textTertiary)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(c.category == "For You" ? GQColors.vividPurple.opacity(0.12) : GQColors.adaptiveOverlay(0.05)))
                                    }
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(GQColors.adaptiveOverlay(0.08)).frame(height: 4)
                                            Capsule().fill(c.isComplete ? AnyShapeStyle(GQColors.success) : AnyShapeStyle(GQGradients.primary))
                                                .frame(width: max(geo.size.width * c.progress, 4), height: 4)
                                        }
                                    }
                                    .frame(height: 4)
                                }

                                Text("\(c.current)/\(c.target)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(c.isComplete ? GQColors.success : GQColors.textSecondary)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .background(GQColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(GQColors.borderDefault, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 3)
        .sheet(item: $selectedChallenge) { c in
            AchievementDetailSheet(badge: c)
                .presentationDetents([.medium])
        }
    }
}

struct IdentifiableInt: Identifiable {
    let id = UUID()
    let value: Int
}

// MARK: - Day Planner Sheet (compact, tap a type)
//
// The small bottom sheet that appears when you tap a day on the plan row.
// Shows the day name + a grid of workout type chips. Tap one → saves
// immediately, sheet dismisses. No "Save" button needed.

struct DayPlannerSheet: View {
    let weekday: Int
    @Bindable var profile: UserProfile
    var onSuggest: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let dayNames = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    private let types: [WorkoutType?] = [
        .push, .pull, .legs, .upper, .lower, .fullBody, .cardio, .hiit, .yoga, .rest, nil
    ]

    var body: some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                Text(dayNames[weekday])
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(GQColors.textPrimary)
                Spacer()
                if let onSuggest, profile.weeklySchedule.isEmpty {
                    Button {
                        onSuggest()
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10, weight: .bold))
                            Text("Suggest")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(GQColors.vividPurple)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            // Type grid
            let columns = [GridItem(.adaptive(minimum: 70), spacing: 8)]
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(types, id: \.self) { type in
                    let current = profile.weeklySchedule[weekday]
                    let isSelected = (type == nil && current == nil) ||
                        (type != nil && type?.rawValue == current)

                    Button {
                        withAnimation(.easeInOut(duration: 0.12)) {
                            if let type {
                                profile.weeklySchedule[weekday] = type.rawValue
                            } else {
                                profile.weeklySchedule.removeValue(forKey: weekday)
                            }
                            try? modelContext.save()
                        }
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        dismiss()
                    } label: {
                        Text(type?.rawValue ?? "Clear")
                            .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                            .foregroundColor(isSelected ? .white : GQColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                isSelected
                                    ? AnyShapeStyle(GQGradients.primary)
                                    : AnyShapeStyle(GQColors.surfaceSecondary)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .background(GQColors.background.ignoresSafeArea())
    }
}

// MARK: - Calendar Planner (visual-first)

struct WeeklyScheduleEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var profile: UserProfile
    @Query(sort: \Workout.date, order: .reverse) private var allWorkouts: [Workout]

    @State private var displayedMonth = Date()
    @State private var selectedDay: IdentifiableInt? = nil
    @State private var selectedDayDate: Date? = nil

    private var calendar: Calendar { Calendar.current }

    private var monthLabel: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    private let presets: [(name: String, icon: String, schedule: [Int: String])] = [
        ("PPL", "figure.strengthtraining.traditional", [2: "Push", 3: "Pull", 4: "Legs", 5: "Push", 6: "Pull", 7: "Legs", 1: "Rest"]),
        ("U / L", "arrow.up.arrow.down", [2: "Upper", 3: "Lower", 4: "Rest", 5: "Upper", 6: "Lower", 7: "Rest", 1: "Rest"]),
        ("Full", "figure.cross.training", [2: "Full Body", 3: "Rest", 4: "Full Body", 5: "Rest", 6: "Full Body", 7: "Rest", 1: "Rest"]),
    ]

    // Month grid
    private var monthDays: [(day: Int, date: Date, weekday: Int)] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let first = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else { return [] }
        return range.map { d in
            let date = calendar.date(byAdding: .day, value: d - 1, to: first)!
            return (day: d, date: date, weekday: calendar.component(.weekday, from: date))
        }
    }

    private var gridOffset: Int {
        guard let first = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else { return 0 }
        return calendar.component(.weekday, from: first) - 1
    }

    private var completedDates: Set<Int> {
        let comps = calendar.dateComponents([.year, .month], from: displayedMonth)
        return Set(allWorkouts.filter { w in
            let wc = calendar.dateComponents([.year, .month], from: w.date)
            return wc.year == comps.year && wc.month == comps.month && w.type != .rest
        }.map { calendar.component(.day, from: $0.date) })
    }

    private func plannedFor(date: Date, weekday: Int) -> String? {
        let key = dateKey(date)
        if let ov = profile.dayOverrides[key] {
            return (ov == "_skip" || ov == "_done") ? nil : ov
        }
        if let end = profile.planEndDate, date > end { return nil }
        if profile.isRollingSplit {
            return rollingPlanFor(date: date)
        }
        return profile.weeklySchedule[weekday]
    }

    private func dateKey(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: d)
    }

    private func manualDone(_ date: Date) -> Bool {
        profile.dayOverrides[dateKey(date)] == "_done"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    // Month nav
                    HStack {
                        Button { changeMonth(-1) } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(GQColors.textSecondary)
                                .frame(width: 36, height: 36)
                        }
                        Spacer()
                        Text(monthLabel)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(GQColors.textPrimary)
                        Spacer()
                        Button { changeMonth(1) } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(GQColors.textSecondary)
                                .frame(width: 36, height: 36)
                        }
                    }
                    .padding(.horizontal, 16)

                    // Day headers
                    HStack(spacing: 0) {
                        ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { h in
                            Text(h)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(GQColors.textTertiary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 8)

                    // Calendar grid — THE view. Colors tell the story.
                    let cols = Array(repeating: GridItem(.flexible(), spacing: 3), count: 7)
                    LazyVGrid(columns: cols, spacing: 3) {
                        ForEach(0..<gridOffset, id: \.self) { _ in
                            Color.clear.frame(height: 62)
                        }

                        ForEach(monthDays, id: \.day) { item in
                            let planned = plannedFor(date: item.date, weekday: item.weekday)
                            let logged = completedDates.contains(item.day)
                            let manual = manualDone(item.date)
                            let done = logged || manual
                            let isToday = calendar.isDateInToday(item.date)
                            let isPast = item.date < calendar.startOfDay(for: Date())

                            Button {
                                selectedDayDate = item.date
                                selectedDay = IdentifiableInt(value: item.weekday)
                            } label: {
                                VStack(spacing: 3) {
                                    Text("\(item.day)")
                                        .font(.system(size: 14, weight: isToday ? .bold : .regular, design: .rounded))
                                        .foregroundColor(
                                            isToday ? .white :
                                            done ? GQColors.textPrimary :
                                            isPast ? GQColors.textTertiary :
                                            GQColors.textSecondary
                                        )

                                    if logged {
                                        Circle()
                                            .fill(AnyShapeStyle(GQGradients.primary))
                                            .frame(width: 5, height: 5)
                                    } else if manual {
                                        Circle()
                                            .strokeBorder(AnyShapeStyle(GQGradients.primary), lineWidth: 1.5)
                                            .frame(width: 5, height: 5)
                                    } else if let p = planned {
                                        Text(shortType(p))
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundColor(isPast ? typeCol(p).opacity(0.35) : .white.opacity(0.9))
                                            .lineLimit(1)
                                    } else {
                                        Color.clear.frame(height: 5)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 62)
                                .background(cellBackground(planned: planned, isToday: isToday, done: done, isPast: isPast))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    isToday
                                        ? RoundedRectangle(cornerRadius: 10).strokeBorder(AnyShapeStyle(GQGradients.primary), lineWidth: 2)
                                        : nil
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 6)

                    // Presets
                    HStack(spacing: 8) {
                        ForEach(presets, id: \.name) { preset in
                            Button { applyPreset(preset.schedule, order: presetOrder(preset.name)) } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: preset.icon)
                                        .font(.system(size: 16, weight: .semibold))
                                    Text(preset.name)
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundColor(profile.weeklySchedule == preset.schedule ? .white : GQColors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    profile.weeklySchedule == preset.schedule
                                        ? AnyShapeStyle(GQGradients.primary)
                                        : AnyShapeStyle(GQColors.surfaceSecondary)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }

                        Button { suggestPlan() } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Auto")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(GQColors.vividPurple)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(GQColors.vividPurple.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)

                    // 3 visual controls
                    VStack(spacing: 14) {
                        // Days per week
                        HStack {
                            Text("Days")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(GQColors.textSecondary)
                                .frame(width: 38, alignment: .leading)
                            HStack(spacing: 6) {
                                ForEach([2, 3, 4, 5, 6, 7], id: \.self) { n in
                                    let current = profile.weeklySchedule.values.filter { $0 != "Rest" }.count
                                    Button { setDaysPerWeek(n) } label: {
                                        Text("\(n)")
                                            .font(.system(size: 13, weight: current == n ? .bold : .medium, design: .rounded))
                                            .foregroundColor(current == n ? .white : GQColors.textSecondary)
                                            .frame(width: 34, height: 34)
                                            .background(current == n ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(GQColors.adaptiveOverlay(0.05)))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Rest days
                        HStack {
                            Text("Rest")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(GQColors.textSecondary)
                                .frame(width: 38, alignment: .leading)
                            HStack(spacing: 6) {
                                ForEach([(1,"S"), (2,"M"), (3,"T"), (4,"W"), (5,"T"), (6,"F"), (7,"S")], id: \.0) { wd, label in
                                    let isRest = profile.weeklySchedule[wd] == nil || profile.weeklySchedule[wd] == "Rest"
                                    Button { toggleRestDay(wd) } label: {
                                        Text(label)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(isRest ? GQColors.textTertiary : .white)
                                            .frame(width: 34, height: 34)
                                            .background(isRest ? AnyShapeStyle(GQColors.adaptiveOverlay(0.05)) : AnyShapeStyle(GQGradients.primary.opacity(0.7)))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Mode
                        HStack {
                            Text("Mode")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(GQColors.textSecondary)
                                .frame(width: 38, alignment: .leading)
                            HStack(spacing: 6) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        profile.isRollingSplit = false
                                        rebuildCalendar()
                                    }
                                } label: {
                                    Text("Same weekly")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(!profile.isRollingSplit ? .white : GQColors.textSecondary)
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(!profile.isRollingSplit ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(GQColors.adaptiveOverlay(0.05)))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)

                                Button {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        profile.isRollingSplit = true
                                        if profile.splitStartDate == nil { profile.splitStartDate = Date() }
                                        if profile.splitOrder.isEmpty { profile.splitOrder = extractSplitOrder() }
                                        try? modelContext.save()
                                    }
                                } label: {
                                    Text("Rolling")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(profile.isRollingSplit ? .white : GQColors.textSecondary)
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(profile.isRollingSplit ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(GQColors.adaptiveOverlay(0.05)))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(14)
                    .background(GQColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(GQColors.borderDefault, lineWidth: 1))
                    .padding(.horizontal, 16)

                    VStack(spacing: 6) {
                        Text("Tap any day to change it")
                            .font(.system(size: 11))
                            .foregroundColor(GQColors.textTertiary)
                        if !profile.weeklySchedule.isEmpty {
                            Button {
                                applySplit([:])
                                profile.dayOverrides = [:]
                                profile.splitOrder = []
                                profile.isRollingSplit = false
                                try? modelContext.save()
                            } label: {
                                Text("Clear plan")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(GQColors.textTertiary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)
            .gqPageBackground()
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
            .sheet(item: $selectedDay) { item in
                DayOverrideSheet(
                    weekday: item.value,
                    date: selectedDayDate ?? Date(),
                    profile: profile
                )
                .presentationDetents([.height(320)])
            }
        }
    }

    private func cellBackground(planned: String?, isToday: Bool, done: Bool, isPast: Bool) -> some ShapeStyle {
        if isToday {
            return AnyShapeStyle(GQGradients.primary.opacity(0.15))
        }
        if done {
            return AnyShapeStyle(GQColors.success.opacity(0.08))
        }
        if let p = planned {
            let opacity = isPast ? 0.06 : 0.12
            return AnyShapeStyle(typeCol(p).opacity(opacity))
        }
        return AnyShapeStyle(GQColors.adaptiveOverlay(0.02))
    }

    private func applyPreset(_ schedule: [Int: String], order: [String]) {
        applySplit(schedule)
        profile.splitOrder = order
        profile.restWeekdays = Set(schedule.filter { $0.value == "Rest" }.map(\.key))
        try? modelContext.save()
    }

    private func presetOrder(_ name: String) -> [String] {
        switch name {
        case "PPL": return ["Push", "Pull", "Legs"]
        case "U / L": return ["Upper", "Lower"]
        case "Full": return ["Full Body"]
        default: return []
        }
    }

    private func setDaysPerWeek(_ n: Int) {
        let order = profile.splitOrder.isEmpty ? extractSplitOrder() : profile.splitOrder
        guard !order.isEmpty else { return }
        let restCount = 7 - n
        // Default rest days: distribute from Sunday backward
        let defaultRestDays: [Int] = [1, 4, 7, 3, 6, 2, 5]  // Sun, Wed, Sat...
        let restDays = Set(defaultRestDays.prefix(restCount))

        var schedule: [Int: String] = [:]
        var orderIdx = 0
        for wd in [2, 3, 4, 5, 6, 7, 1] { // Mon-Sun
            if restDays.contains(wd) {
                schedule[wd] = "Rest"
            } else {
                schedule[wd] = order[orderIdx % order.count]
                orderIdx += 1
            }
        }
        withAnimation(.easeInOut(duration: 0.15)) {
            profile.weeklySchedule = schedule
            profile.restWeekdays = restDays
            try? modelContext.save()
        }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    private func toggleRestDay(_ weekday: Int) {
        let current = profile.weeklySchedule[weekday]
        let isRest = current == nil || current == "Rest"
        if isRest {
            // Make it a training day — assign next in split order
            let order = profile.splitOrder.isEmpty ? extractSplitOrder() : profile.splitOrder
            let nextType = order.first ?? "Push"
            profile.weeklySchedule[weekday] = nextType
        } else {
            profile.weeklySchedule[weekday] = "Rest"
        }
        try? modelContext.save()
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    private func extractSplitOrder() -> [String] {
        let trainingTypes = [2, 3, 4, 5, 6, 7, 1].compactMap { wd -> String? in
            guard let type = profile.weeklySchedule[wd], type != "Rest" else { return nil }
            return type
        }
        // Deduplicate while preserving order
        var seen = Set<String>()
        return trainingTypes.filter { seen.insert($0).inserted }
    }

    private func rebuildCalendar() {
        try? modelContext.save()
    }

    /// For rolling mode: compute what workout falls on a specific date
    func rollingPlanFor(date: Date) -> String? {
        guard profile.isRollingSplit,
              !profile.splitOrder.isEmpty,
              let start = profile.splitStartDate else { return nil }

        let wd = calendar.component(.weekday, from: date)
        let isRest = profile.weeklySchedule[wd] == nil || profile.weeklySchedule[wd] == "Rest"
        if isRest { return "Rest" }

        // Count training days from start to this date
        var trainingDayCount = 0
        var current = calendar.startOfDay(for: start)
        let target = calendar.startOfDay(for: date)

        while current < target {
            let cwd = calendar.component(.weekday, from: current)
            let cIsRest = profile.weeklySchedule[cwd] == nil || profile.weeklySchedule[cwd] == "Rest"
            if !cIsRest { trainingDayCount += 1 }
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }

        return profile.splitOrder[trainingDayCount % profile.splitOrder.count]
    }

    private func changeMonth(_ by: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            displayedMonth = calendar.date(byAdding: .month, value: by, to: displayedMonth) ?? displayedMonth
        }
    }

    private func applySplit(_ schedule: [Int: String]) {
        withAnimation(.easeInOut(duration: 0.15)) {
            profile.weeklySchedule = schedule
            try? modelContext.save()
        }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    private func suggestPlan() {
        let d = profile.daysPerWeek
        switch d {
        case 1...2: applySplit([2: "Full Body", 5: "Full Body"])
        case 3: applySplit([2: "Full Body", 4: "Full Body", 6: "Full Body"])
        case 4: applySplit([2: "Upper", 3: "Lower", 5: "Upper", 6: "Lower"])
        case 5: applySplit([2: "Push", 3: "Pull", 4: "Legs", 5: "Upper", 6: "Lower"])
        default: applySplit([2: "Push", 3: "Pull", 4: "Legs", 5: "Push", 6: "Pull", 7: "Legs"])
        }
    }

    private func shortType(_ raw: String) -> String {
        switch raw {
        case "Full Body": return "Full"
        case "Cardio": return "Crdio"
        default: return String(raw.prefix(5))
        }
    }

    private func typeCol(_ raw: String) -> Color {
        switch raw {
        case "Push": return GQColors.deepBlue
        case "Pull": return GQColors.vividPurple
        case "Legs": return Color(red: 1.0, green: 0.55, blue: 0.2)
        case "Cardio": return GQColors.success
        case "HIIT": return Color.red
        case "Rest": return GQColors.textTertiary
        case "Upper": return Color(red: 0.3, green: 0.7, blue: 1.0)
        case "Lower": return Color(red: 0.9, green: 0.6, blue: 0.2)
        case "Full Body": return Color(red: 0.4, green: 0.8, blue: 0.5)
        default: return GQColors.vividPurple
        }
    }
}

struct DayOverrideSheet: View {
    let weekday: Int
    let date: Date
    @Bindable var profile: UserProfile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var customText: String = ""
    @State private var showCustomField = false

    private let dayNames = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    private let types: [WorkoutType] = [.push, .pull, .legs, .upper, .lower, .fullBody, .cardio, .hiit, .yoga, .glutes, .abs, .rest]

    private var dateLabel: String {
        date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private var currentPlan: String? {
        let key = dateKey(date)
        if let override = profile.dayOverrides[key] {
            return override == "_skip" ? nil : override
        }
        return profile.weeklySchedule[weekday]
    }

    private func dateKey(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }

    private func saveCustomOverride() {
        let trimmed = customText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        profile.dayOverrides[dateKey(date)] = trimmed
        profile.addRecentCustomLabel(trimmed)
        try? modelContext.save()
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        dismiss()
    }

    var body: some View {
        VStack(spacing: 14) {
            // Header
            VStack(spacing: 4) {
                Text(dateLabel)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(GQColors.textPrimary)
                if let current = currentPlan {
                    Text("Planned: \(current)")
                        .font(.system(size: 12))
                        .foregroundColor(GQColors.textSecondary)
                }
            }
            .padding(.top, 16)

            // Type grid — changes ONLY this day
            let columns = [GridItem(.adaptive(minimum: 70), spacing: 8)]
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(types, id: \.self) { type in
                    let isSelected = type.rawValue == currentPlan
                    Button {
                        profile.dayOverrides[dateKey(date)] = type.rawValue
                        try? modelContext.save()
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        dismiss()
                    } label: {
                        Text(type.rawValue)
                            .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                            .foregroundColor(isSelected ? .white : GQColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                isSelected
                                    ? AnyShapeStyle(GQGradients.primary)
                                    : AnyShapeStyle(GQColors.surfaceSecondary)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            // Custom label option
            VStack(spacing: 8) {
                Button { withAnimation { showCustomField.toggle() } } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 10, weight: .bold))
                        Text("Custom label")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(GQColors.vividPurple)
                }

                if showCustomField {
                    HStack(spacing: 8) {
                        TextField("e.g. Chest & Tri, Easy Run", text: $customText)
                            .font(.system(size: 12))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(GQColors.surfaceSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .submitLabel(.done)
                            .onSubmit { saveCustomOverride() }

                        Button { saveCustomOverride() } label: {
                            Text("Set")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(GQGradients.primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)

                    // Recent custom labels
                    if !profile.recentCustomLabels.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(profile.recentCustomLabels, id: \.self) { label in
                                    Button {
                                        profile.dayOverrides[dateKey(date)] = label
                                        try? modelContext.save()
                                        dismiss()
                                    } label: {
                                        Text(label)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(GQColors.vividPurple)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(GQColors.vividPurple.opacity(0.1))
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
            }

            Text("Changes only this day, not your weekly repeat.")
                .font(.system(size: 10))
                .foregroundColor(GQColors.textTertiary)
                .padding(.top, 2)

            // Mark as done (past days only — "I trained but didn't log")
            if date < Calendar.current.startOfDay(for: Date()) {
                Button {
                    profile.dayOverrides[dateKey(date)] = "_done"
                    try? modelContext.save()
                    #if canImport(UIKit)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    #endif
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 12, weight: .semibold))
                        Text("I trained, just didn't log it")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(GQColors.success)
                }
            }

            // Skip / Reset
            HStack(spacing: 16) {
                Button {
                    profile.dayOverrides[dateKey(date)] = "_skip"
                    try? modelContext.save()
                    dismiss()
                } label: {
                    Text("Skip this day")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)
                }

                if profile.dayOverrides[dateKey(date)] != nil {
                    Button {
                        profile.dayOverrides.removeValue(forKey: dateKey(date))
                        try? modelContext.save()
                        dismiss()
                    } label: {
                        Text("Reset to template")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(GQColors.vividPurple)
                    }
                }
            }
            .padding(.top, 4)

            Spacer()
        }
        .background(GQColors.background.ignoresSafeArea())
    }
}

