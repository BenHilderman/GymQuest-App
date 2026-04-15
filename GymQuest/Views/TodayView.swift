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
                .presentationDetents([.large])
        }
        .task {
            checkForDraft()
            MockDataSeeder.seedIfNeeded(modelContext: modelContext, profile: profile)
            MockDataSeeder.fillCurrentWeek(modelContext: modelContext)
            MockDataSeeder.resetProfilePosts(modelContext: modelContext, profile: profile)
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
        case .rest: return GQColors.textTertiary
        default: return GQColors.vividPurple
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

    private var tapHintChevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(GQColors.textTertiary.opacity(0.55))
            .padding(.top, 12)
            .padding(.trailing, 14)
    }

    @ViewBuilder
    private var weeklyCalendarCard: some View {
        let completed = workoutsThisWeek
        let target = profile.daysPerWeek
        let flame = dailyStreak
        let weeks = weeklyStreak
        let flameGrad = LinearGradient(colors: [.orange, .red.opacity(0.8)], startPoint: .bottom, endPoint: .top)

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("THIS WEEK").font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundColor(GQColors.textTertiary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(completed)").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(GQGradients.primary).opacity(1)
                        Text("/ \(target)").font(.system(size: 13, weight: .medium)).foregroundColor(GQColors.textTertiary)
                    }
                    Text("workouts").font(.system(size: 11, weight: .medium)).foregroundColor(GQColors.textTertiary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("STREAK").font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundColor(GQColors.textTertiary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Image(systemName: "flame.fill").font(.system(size: 15)).foregroundStyle(flameGrad)
                        Text("\(flame)").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(GQColors.textPrimary)
                    }
                    Text("\(weeks) week streak").font(.system(size: 11, weight: .medium)).foregroundColor(GQColors.textTertiary)
                }
            }
            calAlignWeekRow()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .homeSocialCard(cornerRadius: 14)
    }

    // MARK: - 20 Activity design alternatives

    @ViewBuilder
    private var activityVariantsPreview: some View {
        let mins = weeklyWorkoutMinutes
        let minGoal = 150
        let sets = weeklyTotalSets
        let setGoal = max(profile.daysPerWeek * 15, 60)
        let days = dailyStreak
        let dayGoal = 7
        let moveP = min(Double(mins) / Double(max(minGoal, 1)), 1.0)
        let setP = min(Double(sets) / Double(max(setGoal, 1)), 1.0)
        let dayP = min(Double(days) / Double(max(dayGoal, 1)), 1.0)


        let ringSize: CGFloat = 96
        let lineW: CGFloat = 7.5
        let gap: CGFloat = 4.5
        let rowH = ringSize / 3


        let chevron = Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundColor(GQColors.textTertiary.opacity(0.7))
        let header = AnyView(
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("Activity").font(.system(size: 15, weight: .semibold)).foregroundColor(GQColors.textPrimary)
                Spacer()
                Text("This week").font(.system(size: 11, weight: .medium)).foregroundColor(GQColors.textTertiary)
                chevron
            }
        )

        let moveGrad = LinearGradient(colors: [GQColors.deepBlue, GQColors.vividPurple], startPoint: .topLeading, endPoint: .bottomTrailing)
        let setGrad = LinearGradient(colors: [GQColors.cyanSpark, GQColors.deepBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
        let dayGrad = LinearGradient(colors: [Color(hex: "5EEAD4"), Color(hex: "10B981")], startPoint: .topLeading, endPoint: .bottomTrailing)

        let rings = ZStack {
            Circle().fill(moveGrad.opacity(0.08)).frame(width: ringSize + 10, height: ringSize + 10).blur(radius: 8)
            ringPair(progress: moveP, grad: moveGrad, diameter: ringSize, lineWidth: lineW)
            ringPair(progress: setP, grad: setGrad, diameter: ringSize - 2 * (lineW + gap), lineWidth: lineW)
            ringPair(progress: dayP, grad: dayGrad, diameter: ringSize - 4 * (lineW + gap), lineWidth: lineW)
        }
        .frame(width: ringSize, height: ringSize)

        let stats = VStack(spacing: 0) {
            tightStatRow(grad: moveGrad, value: "\(mins)", goal: minGoal, unit: "min").frame(height: rowH)
            tightStatRow(grad: setGrad, value: "\(sets)", goal: setGoal, unit: "sets").frame(height: rowH)
            tightStatRow(grad: dayGrad, value: "\(days)", goal: dayGoal, unit: "days").frame(height: rowH)
        }

        // Caps-style header matching THIS WEEK / CHALLENGES / TODAY'S PLAN
        let capsHeader = AnyView(
            HStack(alignment: .firstTextBaseline) {
                Text("ACTIVITY").font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundColor(GQColors.textTertiary)
                Spacer()
                Text("THIS WEEK").font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundColor(GQColors.textTertiary)
            }
        )

        VStack(alignment: .leading, spacing: 10) {
            capsHeader
            HStack(spacing: 0) {
                labellessRingE(progress: moveP, grad: moveGrad, value: mins, goal: minGoal, unit: "min")
                labellessRingE(progress: setP, grad: setGrad, value: sets, goal: setGoal, unit: "sets")
                labellessRingE(progress: dayP, grad: dayGrad, value: days, goal: dayGoal, unit: "days")
            }
        }
        .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 14)
        .frame(maxWidth: .infinity)
        .homeSocialCard(cornerRadius: 14)
    }

    private func labellessRingA(progress: Double, grad: LinearGradient, value: Int, goal: Int, unit: String) -> some View {
        VStack(spacing: 8) {
            minRingBase(progress: progress, grad: grad) {
                Text("\(Int(progress * 100))%").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(GQColors.textPrimary)
            }
            Text("\(value) / \(goal) \(unit)").font(.system(size: 11, weight: .medium)).foregroundColor(GQColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func labellessRingB(progress: Double, grad: LinearGradient, value: Int, goal: Int, unit: String) -> some View {
        VStack(spacing: 8) {
            minRingBase(progress: progress, grad: grad) {
                Text("\(value)").font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(GQColors.textPrimary)
            }
            Text("/ \(goal) \(unit)").font(.system(size: 11, weight: .medium)).foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func labellessRingC(progress: Double, grad: LinearGradient, value: Int, goal: Int, unit: String) -> some View {
        VStack(spacing: 8) {
            minRingBase(progress: progress, grad: grad) {
                VStack(spacing: -1) {
                    Text("\(value)").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(GQColors.textPrimary)
                    Text(unit).font(.system(size: 9, weight: .medium)).foregroundColor(GQColors.textTertiary)
                }
            }
            Text("of \(goal)").font(.system(size: 11, weight: .medium)).foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func minRingBaseLarge(progress: Double, grad: LinearGradient, @ViewBuilder center: () -> some View) -> some View {
        ZStack {
            Circle().fill(grad.opacity(0.08)).frame(width: 80, height: 80).blur(radius: 8)
            Circle().stroke(GQColors.deepBlue.opacity(0.08), lineWidth: 7).frame(width: 70, height: 70)
            Circle().trim(from: 0, to: progress)
                .stroke(grad, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 70, height: 70)
            center()
        }
    }

    private func labellessRingD(progress: Double, grad: LinearGradient, value: Int, goal: Int, unit: String) -> some View {
        VStack(spacing: 8) {
            minRingBaseLarge(progress: progress, grad: grad) {
                Text("\(value)").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(GQColors.textPrimary)
            }
            Text("of \(goal) \(unit)").font(.system(size: 11, weight: .medium)).foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func labellessRingE(progress: Double, grad: LinearGradient, value: Int, goal: Int, unit: String) -> some View {
        VStack(spacing: 8) {
            minRingBase(progress: progress, grad: grad) {
                Text("\(Int(progress * 100))%").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(GQColors.textPrimary)
            }
            Text("\(value)/\(goal) \(unit)").font(.system(size: 10, weight: .medium)).foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func minRingColMerged(progress: Double, grad: LinearGradient, value: Int, goal: Int, unit: String, label: String) -> some View {
        VStack(spacing: 8) {
            minRingBase(progress: progress, grad: grad) {
                VStack(spacing: -1) {
                    Text("\(value)").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(GQColors.textPrimary)
                    Text("/\(goal) \(unit)").font(.system(size: 9, weight: .medium)).foregroundColor(GQColors.textTertiary)
                }
            }
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundColor(GQColors.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    // Shared ring visual (58pt, 6pt stroke, halo + faded blue track)
    @ViewBuilder
    private func minRingBase(progress: Double, grad: LinearGradient, @ViewBuilder center: () -> some View) -> some View {
        ZStack {
            Circle().fill(grad.opacity(0.08)).frame(width: 68, height: 68).blur(radius: 8)
            Circle().stroke(GQColors.deepBlue.opacity(0.08), lineWidth: 6).frame(width: 58, height: 58)
            Circle().trim(from: 0, to: progress)
                .stroke(grad, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 58, height: 58)
            center()
        }
    }

    private func minRingColA(progress: Double, grad: LinearGradient, value: Int, goal: Int, unit: String, label: String) -> some View {
        VStack(spacing: 8) {
            minRingBase(progress: progress, grad: grad) {
                Text("\(Int(progress * 100))%").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(GQColors.textPrimary)
            }
            VStack(spacing: 1) {
                Text(label).font(.system(size: 11, weight: .semibold)).foregroundColor(GQColors.textPrimary)
                Text("\(value) / \(goal) \(unit)").font(.system(size: 10, weight: .medium)).foregroundColor(GQColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func minRingColB(progress: Double, grad: LinearGradient, value: Int, goal: Int, label: String) -> some View {
        VStack(spacing: 8) {
            minRingBase(progress: progress, grad: grad) {
                VStack(spacing: -1) {
                    Text("\(value)").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(GQColors.textPrimary)
                    Text("/\(goal)").font(.system(size: 9, weight: .medium)).foregroundColor(GQColors.textTertiary)
                }
            }
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundColor(GQColors.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    private func minRingColC(progress: Double, grad: LinearGradient, value: Int, goal: Int, label: String) -> some View {
        VStack(spacing: 8) {
            minRingBase(progress: progress, grad: grad) {
                Text("\(Int(progress * 100))%").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(GQColors.textPrimary)
            }
            Text("\(label) · \(value)/\(goal)").font(.system(size: 11, weight: .medium)).foregroundColor(GQColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func minRingColD(progress: Double, grad: LinearGradient, value: Int, unit: String, label: String) -> some View {
        VStack(spacing: 8) {
            minRingBase(progress: progress, grad: grad) {
                VStack(spacing: -1) {
                    Text("\(value)").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(GQColors.textPrimary)
                    Text(unit).font(.system(size: 9, weight: .medium)).foregroundColor(GQColors.textTertiary)
                }
            }
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundColor(GQColors.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    private func compactRingColumn(progress: Double, grad: LinearGradient, value: String, unit: String, label: String) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(grad.opacity(0.08)).frame(width: 62, height: 62).blur(radius: 8)
                Circle().stroke(GQColors.deepBlue.opacity(0.08), lineWidth: 6).frame(width: 54, height: 54)
                Circle().trim(from: 0, to: progress)
                    .stroke(grad, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 54, height: 54)
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(GQColors.textPrimary)
            }
            VStack(spacing: 1) {
                Text(label).font(.system(size: 11, weight: .semibold)).foregroundColor(GQColors.textPrimary)
                Text("\(value) \(unit)").font(.system(size: 10, weight: .medium)).foregroundColor(GQColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func cleanRingColumn(progress: Double, grad: LinearGradient, value: String, unit: String, sub: String, label: String, goal: Int) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(grad.opacity(0.08)).frame(width: 68, height: 68).blur(radius: 8)
                Circle().stroke(GQColors.deepBlue.opacity(0.08), lineWidth: 6).frame(width: 58, height: 58)
                Circle().trim(from: 0, to: progress)
                    .stroke(grad, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 58, height: 58)
                VStack(spacing: -1) {
                    Text(value).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(GQColors.textPrimary)
                    Text(sub).font(.system(size: 9, weight: .medium)).foregroundColor(GQColors.textTertiary)
                }
            }
            VStack(spacing: 1) {
                Text(label).font(.system(size: 11, weight: .semibold)).foregroundColor(GQColors.textPrimary)
                Text("of \(goal)").font(.system(size: 10, weight: .medium)).foregroundColor(GQColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func separateRingColumn(progress: Double, grad: LinearGradient, value: String, unit: String, label: String) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(grad.opacity(0.08)).frame(width: 70, height: 70).blur(radius: 8)
                Circle().stroke(GQColors.deepBlue.opacity(0.08), lineWidth: 7).frame(width: 62, height: 62)
                Circle().trim(from: 0, to: progress)
                    .stroke(grad, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 62, height: 62)
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(GQColors.textPrimary)
            }
            VStack(spacing: 1) {
                Text(label).font(.system(size: 11, weight: .semibold)).foregroundColor(GQColors.textPrimary)
                Text("\(value) \(unit)").font(.system(size: 10, weight: .medium)).foregroundColor(GQColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func statPill(grad: LinearGradient, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Circle().fill(grad).frame(width: 8, height: 8)
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundColor(GQColors.textSecondary)
            Spacer(minLength: 4)
            Text(value).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundColor(GQColors.textPrimary)
        }
    }

    private func rightAlignStatRow(grad: LinearGradient, value: String, goal: Int, unit: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Circle().fill(grad).frame(width: 8, height: 8)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(GQColors.textPrimary)
                .frame(width: 46, alignment: .trailing)
            Text("/ \(goal) \(unit)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
                .frame(width: 92, alignment: .leading)
        }
    }

    @ViewBuilder
    private func appleActivityCardFixedHeight<S: View, R: View>(header: AnyView, stats: S, rings: R, mirrored: Bool, cardHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 8)
            HStack(spacing: 20) {
                Spacer(minLength: 0)
                if mirrored {
                    rings; stats
                } else {
                    stats; rings
                }
                Spacer(minLength: 0)
            }
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .frame(height: cardHeight)
        .homeSocialCard(cornerRadius: 14)
    }


    private func tightStatRow(grad: LinearGradient, value: String, goal: Int, unit: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Circle().fill(grad).frame(width: 8, height: 8)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(GQColors.textPrimary)
                .frame(minWidth: 32, alignment: .leading)
            Text("/ \(goal) \(unit)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
        }
    }

    private enum ContentAlign { case leading, center, trailing }

    @ViewBuilder
    private func appleActivityCard<S: View, R: View>(
        header: AnyView,
        stats: S,
        rings: R,
        alignment: ContentAlign = .center,
        mirrored: Bool = false,
        verticalPad: CGFloat = 14,
        horizontalPad: CGFloat = 14,
        headerSpacing: CGFloat = 14
    ) -> some View {
        VStack(alignment: .leading, spacing: headerSpacing) {
            header

            HStack(spacing: 20) {
                if alignment == .center || alignment == .trailing {
                    Spacer(minLength: 0)
                }
                if mirrored {
                    rings
                    stats
                } else {
                    stats
                    rings
                }
                if alignment == .center || alignment == .leading {
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, horizontalPad)
        .padding(.vertical, verticalPad)
        .frame(maxWidth: .infinity)
        .homeSocialCard(cornerRadius: 14)
    }

    // MARK: - Activity variant helpers

    @ViewBuilder
    private func activityCurrent(mins: Int, minGoal: Int, sets: Int, setGoal: Int, days: Int, dayGoal: Int, moveGrad: LinearGradient, setGrad: LinearGradient, dayGrad: LinearGradient, moveP: Double, setP: Double, dayP: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ACTIVITY").font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundColor(GQColors.textTertiary)
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle().stroke(GQColors.adaptiveOverlay(0.04), lineWidth: 6.5).frame(width: 80, height: 80)
                    Circle().trim(from: 0, to: moveP).stroke(moveGrad, style: StrokeStyle(lineWidth: 6.5, lineCap: .round)).rotationEffect(.degrees(-90)).frame(width: 80, height: 80)
                    Circle().stroke(GQColors.adaptiveOverlay(0.04), lineWidth: 6.5).frame(width: 60, height: 60)
                    Circle().trim(from: 0, to: setP).stroke(setGrad, style: StrokeStyle(lineWidth: 6.5, lineCap: .round)).rotationEffect(.degrees(-90)).frame(width: 60, height: 60)
                    Circle().stroke(GQColors.adaptiveOverlay(0.04), lineWidth: 6.5).frame(width: 40, height: 40)
                    Circle().trim(from: 0, to: dayP).stroke(dayGrad, style: StrokeStyle(lineWidth: 6.5, lineCap: .round)).rotationEffect(.degrees(-90)).frame(width: 40, height: 40)
                }
                .frame(width: 88, height: 88)
                VStack(alignment: .leading, spacing: 8) {
                    statLine(grad: moveGrad, value: "\(mins)", unit: "/ \(minGoal) min")
                    statLine(grad: setGrad, value: "\(sets)", unit: "/ \(setGoal) sets")
                    statLine(grad: dayGrad, value: "\(days)", unit: "/ \(dayGoal) days")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func statLine(grad: LinearGradient, value: String, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle().fill(grad).frame(width: 8, height: 8).alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
            Text(value).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(GQColors.textPrimary)
            Text(unit).font(.system(size: 11, weight: .medium)).foregroundColor(GQColors.textTertiary)
        }
    }

    // Concentric-ring variant helpers

    @ViewBuilder
    private func ringPair(progress: Double, grad: LinearGradient, diameter: CGFloat, lineWidth: CGFloat) -> some View {
        Circle().stroke(GQColors.deepBlue.opacity(0.08), lineWidth: lineWidth).frame(width: diameter, height: diameter)
        Circle().trim(from: 0, to: progress).stroke(grad, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)).rotationEffect(.degrees(-90)).frame(width: diameter, height: diameter)
    }

    @ViewBuilder
    private func ringPairDotted(progress: Double, grad: LinearGradient, diameter: CGFloat, lineWidth: CGFloat) -> some View {
        Circle()
            .stroke(GQColors.adaptiveOverlay(0.12), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: [1, 4]))
            .frame(width: diameter, height: diameter)
        Circle()
            .trim(from: 0, to: progress)
            .stroke(grad, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .frame(width: diameter, height: diameter)
    }

    private func legendCol(grad: LinearGradient, value: String, unit: String, goal: Int) -> some View {
        VStack(spacing: 2) {
            Circle().fill(grad).frame(width: 8, height: 8)
            Text(value).font(.system(size: 17, weight: .bold, design: .rounded)).foregroundColor(GQColors.textPrimary)
            Text("/ \(goal) \(unit)").font(.system(size: 10, weight: .medium)).foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func bigStatRow(grad: LinearGradient, value: String, unit: String, goal: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(grad)
            Text(unit).font(.system(size: 11, weight: .medium)).foregroundColor(GQColors.textTertiary)
            Spacer()
            Text("of \(goal)").font(.system(size: 10, weight: .medium)).foregroundColor(GQColors.textTertiary)
        }
    }

    private func premStatRow(grad: LinearGradient, label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle().fill(grad).frame(width: 6, height: 6).alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
            Text(label).font(.system(size: 11, weight: .medium)).foregroundColor(GQColors.textTertiary)
            Spacer()
            Text(value).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundColor(GQColors.textPrimary)
        }
    }

    private func actBar(icon: String, label: String, value: String, unit: String, progress: Double, grad: LinearGradient) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(grad)
                    Text(label).font(.system(size: 12, weight: .semibold)).foregroundColor(GQColors.textPrimary)
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(GQColors.textPrimary)
                    Text(unit).font(.system(size: 11, weight: .medium)).foregroundColor(GQColors.textTertiary)
                }
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(GQColors.adaptiveOverlay(0.06))
                    Capsule().fill(grad).frame(width: g.size.width * CGFloat(progress))
                }
            }
            .frame(height: 6)
        }
    }

    private func actTile(title: String, value: String, goal: String, progress: Double, grad: LinearGradient) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased()).font(.system(size: 9, weight: .semibold)).tracking(1.0).foregroundColor(GQColors.textTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(grad)
                Text(goal).font(.system(size: 11, weight: .medium)).foregroundColor(GQColors.textTertiary)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(GQColors.adaptiveOverlay(0.06))
                    Capsule().fill(grad).frame(width: g.size.width * CGFloat(progress))
                }
            }
            .frame(height: 4)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(GQColors.adaptiveOverlay(0.03)))
    }

    private func heroRing(progress: Double, grad: LinearGradient, big: String, small: String) -> some View {
        ZStack {
            Circle().stroke(GQColors.adaptiveOverlay(0.05), lineWidth: 10).frame(width: 96, height: 96)
            Circle().trim(from: 0, to: progress).stroke(grad, style: StrokeStyle(lineWidth: 10, lineCap: .round)).rotationEffect(.degrees(-90)).frame(width: 96, height: 96)
            VStack(spacing: 0) {
                Text(big).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(GQColors.textPrimary)
                Text(small).font(.system(size: 9, weight: .medium)).foregroundColor(GQColors.textTertiary)
            }
        }
        .frame(width: 96, height: 96)
    }

    private func miniRingRow(progress: Double, grad: LinearGradient, value: String, unit: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().stroke(GQColors.adaptiveOverlay(0.05), lineWidth: 4).frame(width: 28, height: 28)
                Circle().trim(from: 0, to: progress).stroke(grad, style: StrokeStyle(lineWidth: 4, lineCap: .round)).rotationEffect(.degrees(-90)).frame(width: 28, height: 28)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(GQColors.textPrimary)
                Text(unit).font(.system(size: 11, weight: .medium)).foregroundColor(GQColors.textTertiary)
            }
        }
    }

    private func actPercentRow(label: String, percent: Int, detail: String, grad: LinearGradient, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.system(size: 12, weight: .semibold)).foregroundColor(GQColors.textPrimary)
                Spacer()
                Text("\(percent)%").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(grad)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(GQColors.adaptiveOverlay(0.06))
                    Capsule().fill(grad).frame(width: g.size.width * CGFloat(progress))
                }
            }
            .frame(height: 5)
            Text(detail).font(.system(size: 10, weight: .medium)).foregroundColor(GQColors.textTertiary)
        }
    }

    private func actGradRow(icon: String, title: String, value: String, progress: Double, grad: LinearGradient) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(grad.opacity(0.15)).frame(width: 32, height: 32)
                Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(grad)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(title).font(.system(size: 12, weight: .semibold)).foregroundColor(GQColors.textPrimary)
                    Spacer()
                    Text(value).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundColor(GQColors.textSecondary)
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(GQColors.adaptiveOverlay(0.06))
                        Capsule().fill(grad).frame(width: g.size.width * CGFloat(progress))
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(GQColors.adaptiveOverlay(0.03)))
    }

    private func actVertBar(progress: Double, grad: LinearGradient, value: String, goal: String, label: String) -> some View {
        VStack(spacing: 6) {
            GeometryReader { g in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 6).fill(GQColors.adaptiveOverlay(0.05))
                    RoundedRectangle(cornerRadius: 6).fill(grad).frame(height: g.size.height * CGFloat(progress))
                }
            }
            .frame(maxWidth: .infinity)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(GQColors.textPrimary)
                Text(goal).font(.system(size: 9, weight: .medium)).foregroundColor(GQColors.textTertiary)
            }
            Text(label).font(.system(size: 9, weight: .semibold)).tracking(1.0).foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func watchRing(progress: Double, grad: LinearGradient, diameter: CGFloat, lineWidth: CGFloat) -> some View {
        ZStack {
            Circle().stroke(GQColors.adaptiveOverlay(0.05), lineWidth: lineWidth).frame(width: diameter, height: diameter)
            Circle().trim(from: 0, to: progress).stroke(grad, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)).rotationEffect(.degrees(-90)).frame(width: diameter, height: diameter)
        }
    }

    private func watchLegend(grad: LinearGradient, value: String, unit: String, goal: Int) -> some View {
        HStack(spacing: 6) {
            Circle().fill(grad).frame(width: 8, height: 8)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(GQColors.textPrimary)
                Text("/ \(goal) \(unit)").font(.system(size: 10, weight: .medium)).foregroundColor(GQColors.textTertiary)
            }
        }
    }

    private func metricPill(icon: String, text: String, grad: LinearGradient) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 10, weight: .semibold)).foregroundStyle(grad)
            Text(text).font(.system(size: 12, weight: .semibold)).foregroundColor(GQColors.textPrimary)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(GQColors.adaptiveOverlay(0.06)))
    }

    private func legendDot(grad: LinearGradient, text: String, sub: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Circle().fill(grad).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 0) {
                Text(text).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundColor(GQColors.textPrimary)
                Text(sub).font(.system(size: 10, weight: .medium)).foregroundColor(GQColors.textTertiary)
            }
        }
    }

    private func bigMetric(value: String, unit: String, grad: LinearGradient) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(grad)
            Text(unit).font(.system(size: 10, weight: .medium)).foregroundColor(GQColors.textTertiary)
        }
    }

    private func thinTrack(progress: Double, grad: LinearGradient) -> some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(GQColors.adaptiveOverlay(0.06))
                Capsule().fill(grad).frame(width: g.size.width * CGFloat(progress))
            }
        }
        .frame(height: 4)
    }

    private func dashTile(big: Bool, title: String, value: String, goal: String, progress: Double, grad: LinearGradient) -> some View {
        VStack(alignment: .leading, spacing: big ? 6 : 2) {
            Text(title.uppercased()).font(.system(size: 9, weight: .semibold)).tracking(1.0).foregroundColor(GQColors.textTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.system(size: big ? 30 : 16, weight: .bold, design: .rounded)).foregroundStyle(grad)
                Text(goal).font(.system(size: big ? 12 : 10, weight: .medium)).foregroundColor(GQColors.textTertiary)
            }
            if big { Spacer(minLength: 0) }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(GQColors.adaptiveOverlay(0.06))
                    Capsule().fill(grad).frame(width: g.size.width * CGFloat(progress))
                }
            }
            .frame(height: big ? 5 : 3)
        }
        .padding(big ? 12 : 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: big ? 120 : 56)
        .background(RoundedRectangle(cornerRadius: 12).fill(GQColors.adaptiveOverlay(0.03)))
    }

    private func accentRow(title: String, value: String, unit: String, progress: Double, grad: LinearGradient) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2).fill(grad).frame(width: 3, height: 36)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(title).font(.system(size: 12, weight: .semibold)).foregroundColor(GQColors.textPrimary)
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(value).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(GQColors.textPrimary)
                        Text(unit).font(.system(size: 10, weight: .medium)).foregroundColor(GQColors.textTertiary)
                    }
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(GQColors.adaptiveOverlay(0.06))
                        Capsule().fill(grad).frame(width: g.size.width * CGFloat(progress))
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(GQColors.adaptiveOverlay(0.03)))
    }

    private func dottedTrackRow(title: String, value: String, progress: Double, grad: LinearGradient) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title).font(.system(size: 11, weight: .semibold)).tracking(0.8).foregroundColor(GQColors.textSecondary)
                Spacer()
                Text(value).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundColor(GQColors.textPrimary)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    HStack(spacing: 3) {
                        ForEach(0..<20, id: \.self) { _ in
                            Capsule().fill(GQColors.adaptiveOverlay(0.08)).frame(height: 4)
                        }
                    }
                    Capsule().fill(grad).frame(width: g.size.width * CGFloat(progress), height: 4)
                    Circle().fill(grad).frame(width: 10, height: 10).offset(x: max(0, g.size.width * CGFloat(progress) - 5))
                }
            }
            .frame(height: 10)
        }
    }

    private func gaugeTile(progress: Double, grad: LinearGradient, value: String, sub: String) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(GQColors.adaptiveOverlay(0.05), lineWidth: 6).frame(width: 60, height: 60)
                Circle().trim(from: 0, to: progress).stroke(grad, style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90)).frame(width: 60, height: 60)
                Text(value).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(GQColors.textPrimary)
            }
            Text(sub).font(.system(size: 10, weight: .semibold)).tracking(1.0).foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func pillListRow(icon: String, label: String, value: String, progress: Double, grad: LinearGradient) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(grad).frame(width: 18)
            Text(label).font(.system(size: 12, weight: .semibold)).foregroundColor(GQColors.textPrimary).frame(width: 50, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(GQColors.adaptiveOverlay(0.06))
                    Capsule().fill(grad).frame(width: g.size.width * CGFloat(progress))
                }
            }
            .frame(height: 4)
            Text(value).font(.system(size: 11, weight: .medium, design: .rounded)).foregroundColor(GQColors.textSecondary)
        }
        .padding(.vertical, 4)
    }

    private func ringPill(progress: Double, grad: LinearGradient, title: String, detail: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().stroke(GQColors.adaptiveOverlay(0.05), lineWidth: 4).frame(width: 28, height: 28)
                Circle().trim(from: 0, to: progress).stroke(grad, style: StrokeStyle(lineWidth: 4, lineCap: .round)).rotationEffect(.degrees(-90)).frame(width: 28, height: 28)
                Text("\(Int(progress * 100))").font(.system(size: 9, weight: .bold, design: .rounded)).foregroundColor(GQColors.textPrimary)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.system(size: 12, weight: .semibold)).foregroundColor(GQColors.textPrimary)
                Text(detail).font(.system(size: 10, weight: .medium)).foregroundColor(GQColors.textTertiary)
            }
            Spacer()
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(GQColors.adaptiveOverlay(0.04)))
    }

    private func denseCell(value: String, unit: String, progress: Double, grad: LinearGradient) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(grad)
            Text(unit).font(.system(size: 9, weight: .semibold)).tracking(1.0).foregroundColor(GQColors.textTertiary)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(GQColors.adaptiveOverlay(0.06))
                    Capsule().fill(grad).frame(width: g.size.width * CGFloat(progress))
                }
            }
            .frame(height: 3)
            .padding(.horizontal, 6)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func calAlignWeekRow() -> some View {
        let labels = ["S", "M", "T", "W", "T", "F", "S"]
        let todayIdx = Calendar.current.component(.weekday, from: Date()) - 1
        let today = Calendar.current.startOfDay(for: Date())
        let weekStart = Calendar.current.date(byAdding: .day, value: -todayIdx, to: today)!
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { i in
                let isToday = i == todayIdx
                let dayDate = Calendar.current.date(byAdding: .day, value: i, to: weekStart)!
                let dayNum = Calendar.current.component(.day, from: dayDate)
                VStack(spacing: 5) {
                    Text(labels[i])
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .tracking(1.2)
                        .foregroundColor(isToday ? GQColors.textPrimary : GQColors.textTertiary)
                    ZStack {
                        if isToday {
                            Circle().fill(GQGradients.primary.opacity(0.06))
                            Circle().strokeBorder(GQGradients.primary.opacity(0.85), lineWidth: 1.5)
                        } else {
                            Circle().fill(GQColors.adaptiveOverlay(0.045))
                        }
                        Text("\(dayNum)")
                            .font(.system(size: 15, weight: isToday ? .semibold : .medium, design: .rounded))
                            .foregroundColor(isToday ? GQColors.textPrimary : GQColors.textTertiary)
                    }
                    .frame(width: 36, height: 36)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func workoutTypeFor(_ label: String) -> WorkoutType? {
        if let exact = WorkoutType(rawValue: label) { return exact }
        switch label {
        case "Upper": return .upper
        case "Lower": return .lower
        case "Full": return .fullBody
        case "Recovery", "Rest": return .rest
        default: return nil
        }
    }

    @ViewBuilder
    private func planCardShell(icon: String, title: String, action: (label: String, onTap: () -> Void)?) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(GQGradients.primary.opacity(0.08))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(GQGradients.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("TODAY'S PLAN")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(GQColors.textTertiary)
                Text(title)
                    .font(.system(size: 15.8, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)
            }

            Spacer()

            if let action {
                Button(action: action.onTap) {
                    Text(action.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(GQGradients.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(GQGradients.primary.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .homeSocialCard(cornerRadius: 14)
    }

    @ViewBuilder
    private var todayPlanCard: some View {
        let planned = todayPlannedLabel
        let isRest = planned == "Rest"

        if let planned, !isRest {
            let plannedType = workoutTypeFor(planned)
            planCardShell(
                icon: plannedType?.icon ?? "figure.strengthtraining.traditional",
                title: planned,
                action: ("Start", { appState.showingWorkoutStartOptions = true })
            )
            .sheet(item: $selectedPlanDay) { item in
                DayOverrideSheet(weekday: item.value, date: Date(), profile: profile)
                    .presentationDetents([.height(280)])
            }
        } else if isRest {
            planCardShell(
                icon: "moon.fill",
                title: "Rest day",
                action: nil
            )
        } else if !profile.weeklySchedule.isEmpty {
            planCardShell(
                icon: "plus.circle.fill",
                title: "Nothing scheduled",
                action: ("Start", { appState.showingWorkoutStartOptions = true })
            )
        } else {
            planCardShell(
                icon: "calendar.badge.plus",
                title: "No plan yet",
                action: ("Customize", { showWeeklyScheduleEditor = true })
            )
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
        VStack(spacing: 12) {
            dateHeader

            if showDraftBanner {
                resumeDraftBanner
            }

            Button { showWeeklyScheduleEditor = true } label: {
                weeklyCalendarCard
            }
            .buttonStyle(.plain)

            // Today's plan — compact companion to calendar
            todayPlanCard

            // Activity — taps through to Activity tab
            Button { appState.selectedTab = .activity } label: {
                activityVariantsPreview
            }
            .buttonStyle(.plain)

            // Progressive challenges (3 at a time, tier-based)
            TodayChallengesSection(profile: profile)

            TodayDashboardSection(
                profile: profile,
                workoutsThisWeek: workoutsThisWeek,
                allWorkouts: allWorkouts
            )
            .environment(\.modelContext, modelContext)

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
        // Context-aware noticing, not just clock
        if consistencyState == .comeback || consistencyState == .atRisk {
            let workedOutToday = nonRestWorkouts.contains { Calendar.current.isDateInToday($0.date) }
            if workedOutToday { return "You came back." }
            return "Day one is available."
        }
        if dailyStreak >= 7 { return "Day \(dailyStreak)." }
        let target = profile.daysPerWeek
        if workoutsThisWeek == target - 1 && target > 1 { return "One more this week." }
        if workoutsThisWeek >= target && target > 0 { return "Weekly goal hit." }
        if let last = nonRestWorkouts.first, Calendar.current.isDateInYesterday(last.date) { return "Back again." }
        // Default: time-based
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
            podPromptRow(title: "Join a Club", subtitle: "Train with others")
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

    private var moveProgress: CGFloat { min(CGFloat(workoutMinutes) / CGFloat(max(minuteGoal, 1)), 1.0) }
    private var exerciseProgress: CGFloat { min(CGFloat(totalSets) / CGFloat(max(setGoal, 1)), 1.0) }
    private var streakProgress: CGFloat { min(CGFloat(streak) / CGFloat(max(streakGoal, 1)), 1.0) }

    // Gradients matching Progress page ring style
    private let moveGradient = GQGradients.primary
    private let exerciseGradient = LinearGradient(colors: [GQColors.cyanSpark, GQColors.deepBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
    private let streakGradient = LinearGradient(colors: [GQColors.deepBlue.opacity(0.8), GQColors.vividPurple.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ACTIVITY")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(GQColors.textTertiary)

            HStack(alignment: .center, spacing: 16) {
                // Concentric rings — the unified "fill it up" visual
                ZStack {
                    Circle()
                        .fill(moveGradient.opacity(0.06))
                        .frame(width: 88, height: 88)
                        .blur(radius: 10)

                    Circle()
                        .stroke(GQColors.adaptiveOverlay(0.04), lineWidth: 6.5)
                        .frame(width: 80, height: 80)
                    Circle()
                        .trim(from: 0, to: animate ? moveProgress : 0)
                        .stroke(moveGradient, style: StrokeStyle(lineWidth: 6.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 80, height: 80)

                    Circle()
                        .stroke(GQColors.adaptiveOverlay(0.04), lineWidth: 6.5)
                        .frame(width: 60, height: 60)
                    Circle()
                        .trim(from: 0, to: animate ? exerciseProgress : 0)
                        .stroke(exerciseGradient, style: StrokeStyle(lineWidth: 6.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 60, height: 60)

                    Circle()
                        .stroke(GQColors.adaptiveOverlay(0.04), lineWidth: 6.5)
                        .frame(width: 40, height: 40)
                    Circle()
                        .trim(from: 0, to: animate ? streakProgress : 0)
                        .stroke(streakGradient, style: StrokeStyle(lineWidth: 6.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 40, height: 40)
                }
                .frame(width: 88, height: 88)

                VStack(alignment: .leading, spacing: 8) {
                    statRow(gradient: moveGradient, value: "\(workoutMinutes)", goal: minuteGoal, unit: "min")
                    statRow(gradient: exerciseGradient, value: "\(totalSets)", goal: setGoal, unit: "sets")
                    statRow(gradient: streakGradient, value: "\(streak)", goal: streakGoal, unit: "days")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .homeSocialCard(cornerRadius: 14)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                animate = true
            }
        }
    }

    private func statRow(gradient: LinearGradient, value: String, goal: Int, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(gradient)
                .frame(width: 8, height: 8)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(GQColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .layoutPriority(1)

            Text("/ \(goal) \(unit)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
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
                .init(icon: "person.3.fill", title: "Join a Club", description: "Join your first club.", current: squads.contains(where: { $0.memberIds.contains(profile.id) }) ? 1 : 0, target: 1, category: "General"),
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
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(GQColors.textTertiary)
                Spacer()
                Text("Tier \(profile.currentChallengeTier + 1)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(GQGradients.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(GQGradients.primary.opacity(0.1))
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
                            Text("All 3 complete")
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
                                        .foregroundStyle(c.isComplete ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(GQGradients.primary))
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(c.title)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(c.isComplete ? GQColors.textTertiary : GQColors.textPrimary)
                                        if c.category != "General" {
                                            Text(c.category)
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundColor(GQColors.textTertiary)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(Capsule().fill(GQColors.adaptiveOverlay(0.05)))
                                        }
                                    }
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(GQColors.adaptiveOverlay(0.08)).frame(height: 3)
                                            Capsule()
                                                .fill(c.isComplete
                                                      ? AnyShapeStyle(GQColors.textTertiary.opacity(0.4))
                                                      : AnyShapeStyle(GQGradients.primary))
                                                .frame(width: max(geo.size.width * c.progress, 3), height: 3)
                                        }
                                    }
                                    .frame(height: 3)
                                }

                                Text("\(c.current)/\(c.target)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(GQColors.textSecondary)
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .homeSocialCard(cornerRadius: 14)
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
    @State private var showCustomSplitBuilder = false

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
                        Button { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { changeMonth(-1) } } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(GQColors.textPrimary.opacity(0.6))
                                .frame(width: 36, height: 36)
                                .background(GQColors.adaptiveOverlay(0.06))
                                .clipShape(Circle())
                        }
                        Spacer()
                        Text(monthLabel)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(GQColors.textPrimary)
                            .contentTransition(.numericText())
                        Spacer()
                        Button { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { changeMonth(1) } } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(GQColors.textPrimary.opacity(0.6))
                                .frame(width: 36, height: 36)
                                .background(GQColors.adaptiveOverlay(0.06))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 16)

                    // Day headers
                    HStack(spacing: 0) {
                        ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { h in
                            Text(h)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .tracking(0.5)
                                .foregroundColor(GQColors.textTertiary.opacity(0.7))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 8)

                    // Calendar grid — THE view. Colors tell the story.
                    let cols = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
                    LazyVGrid(columns: cols, spacing: 4) {
                        ForEach(0..<gridOffset, id: \.self) { _ in
                            Color.clear.frame(height: 62)
                        }

                        ForEach(Array(monthDays.enumerated()), id: \.element.day) { idx, item in
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
                                            .foregroundColor(
                                                p == "Rest"
                                                    ? GQColors.textTertiary.opacity(isPast ? 0.3 : 0.6)
                                                    : (isPast ? GQColors.textTertiary.opacity(0.4) : GQColors.textSecondary)
                                            )
                                            .lineLimit(1)
                                    } else {
                                        Color.clear.frame(height: 5)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 62)
                                .background(cellBackground(planned: planned, isToday: isToday, done: done, isPast: isPast))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .conditionalAnimatedBorder(
                                    enabled: isToday,
                                    cornerRadius: 12,
                                    lineWidth: 1.5,
                                    colors: [GQColors.deepBlue, GQColors.vividPurple, GQColors.deepBlue],
                                    duration: 6.0
                                )
                                .staggeredAppear(index: idx, stagger: 0.015)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 6)

                    // Presets
                    HStack(spacing: 8) {
                        ForEach(presets, id: \.name) { preset in
                            let isActive = profile.weeklySchedule == preset.schedule
                            Button { applyPreset(preset.schedule, order: presetOrder(preset.name)) } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: preset.icon)
                                        .font(.system(size: 16, weight: .semibold))
                                    Text(preset.name)
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundColor(isActive ? .white : GQColors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    isActive
                                        ? AnyShapeStyle(GQGradients.primary)
                                        : AnyShapeStyle(GQColors.surfaceSecondary)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: isActive ? GQColors.vividPurple.opacity(0.2) : .clear, radius: 6, y: 2)
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
                            .foregroundColor(GQColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(GQColors.adaptiveOverlay(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)

                        Button { showCustomSplitBuilder = true } label: {
                            let isCustomActive = !profile.weeklySchedule.isEmpty && !presets.contains(where: { $0.schedule == profile.weeklySchedule })
                            VStack(spacing: 4) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Custom")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(isCustomActive ? .white : GQColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                isCustomActive
                                    ? AnyShapeStyle(GQGradients.primary)
                                    : AnyShapeStyle(GQColors.adaptiveOverlay(0.05))
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: isCustomActive ? GQColors.vividPurple.opacity(0.2) : .clear, radius: 6, y: 2)
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
                                    let isSelected = current == n
                                    Button { setDaysPerWeek(n) } label: {
                                        Text("\(n)")
                                            .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
                                            .foregroundColor(isSelected ? GQColors.textPrimary : GQColors.textSecondary)
                                            .frame(width: 34, height: 34)
                                            .background(isSelected ? AnyShapeStyle(GQGradients.primary.opacity(0.08)) : AnyShapeStyle(GQColors.adaptiveOverlay(0.05)))
                                            .clipShape(Circle())
                                            .overlay(
                                                Circle().strokeBorder(isSelected ? AnyShapeStyle(GQGradients.primary.opacity(0.85)) : AnyShapeStyle(Color.clear), lineWidth: 1.5)
                                            )
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
                                    let isTraining = !isRest
                                    Button { toggleRestDay(wd) } label: {
                                        Text(label)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(isTraining ? GQColors.textPrimary : GQColors.textTertiary)
                                            .frame(width: 34, height: 34)
                                            .background(isTraining ? AnyShapeStyle(GQGradients.primary.opacity(0.08)) : AnyShapeStyle(GQColors.adaptiveOverlay(0.05)))
                                            .clipShape(Circle())
                                            .overlay(
                                                Circle().strokeBorder(isTraining ? AnyShapeStyle(GQGradients.primary.opacity(0.85)) : AnyShapeStyle(Color.clear), lineWidth: 1.5)
                                            )
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
                                let sameSelected = !profile.isRollingSplit
                                Button {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        profile.isRollingSplit = false
                                        rebuildCalendar()
                                    }
                                } label: {
                                    Text("Same weekly")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(sameSelected ? GQColors.textPrimary : GQColors.textSecondary)
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(sameSelected ? AnyShapeStyle(GQGradients.primary.opacity(0.08)) : AnyShapeStyle(GQColors.adaptiveOverlay(0.05)))
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule().strokeBorder(sameSelected ? AnyShapeStyle(GQGradients.primary.opacity(0.85)) : AnyShapeStyle(Color.clear), lineWidth: 1.5)
                                        )
                                }
                                .buttonStyle(.plain)

                                let rollingSelected = profile.isRollingSplit
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
                                        .foregroundColor(rollingSelected ? GQColors.textPrimary : GQColors.textSecondary)
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(rollingSelected ? AnyShapeStyle(GQGradients.primary.opacity(0.08)) : AnyShapeStyle(GQColors.adaptiveOverlay(0.05)))
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule().strokeBorder(rollingSelected ? AnyShapeStyle(GQGradients.primary.opacity(0.85)) : AnyShapeStyle(Color.clear), lineWidth: 1.5)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(14)
                    .homeSocialCard(cornerRadius: 16)
                    .padding(.horizontal, 16)

                    VStack(spacing: 6) {
                        Text("Tap any day to change it")
                            .font(.system(size: 10))
                            .foregroundColor(GQColors.textTertiary)
                            .opacity(0.6)
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
                    .padding(.top, 4)
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
                    Button("Done") { dismiss() }.fontWeight(.semibold).foregroundColor(GQColors.textPrimary)
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
            .sheet(isPresented: $showCustomSplitBuilder) {
                CustomSplitBuilderSheet(profile: profile, onApply: { order in
                    applyCustomSplit(order)
                })
                .presentationDetents([.medium])
            }
        }
    }

    private func applyCustomSplit(_ order: [String]) {
        guard !order.isEmpty else { return }
        // Keep current training day count if set, otherwise default to split length (capped at 7)
        let currentTrainingDays = profile.weeklySchedule.values.filter { $0 != "Rest" }.count
        let days = currentTrainingDays > 0 ? currentTrainingDays : min(order.count, 7)
        let restCount = 7 - days
        let defaultRestDays: [Int] = [1, 4, 7, 3, 6, 2, 5]
        let restDays = Set(defaultRestDays.prefix(max(0, restCount)))

        var schedule: [Int: String] = [:]
        var orderIdx = 0
        for wd in [2, 3, 4, 5, 6, 7, 1] {
            if restDays.contains(wd) {
                schedule[wd] = "Rest"
            } else {
                schedule[wd] = order[orderIdx % order.count]
                orderIdx += 1
            }
        }
        withAnimation(.easeInOut(duration: 0.15)) {
            profile.weeklySchedule = schedule
            profile.splitOrder = order
            profile.restWeekdays = restDays
            try? modelContext.save()
        }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    @ViewBuilder
    private func selectionStylePreviewCard(styleIndex: Int) -> some View {
        let labels: [String] = [
            "V1 · Solid purple",
            "V2 · Subtle tint + brand text",
            "V3 · Outlined gradient ring",
            "V4 · Today-card mimic",
            "V5 · Tinted bg + dot indicator",
            "V6 · White elevated + gradient text",
            "V7 · Gradient text only",
            "V8 · Solid deepBlue",
            "V9 · Soft halo behind circle",
            "V10 · Thin gradient border, clear fill",
        ]
        VStack(alignment: .leading, spacing: 8) {
            Text(labels[styleIndex])
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundColor(GQColors.textTertiary)
            HStack(spacing: 6) {
                ForEach([2, 3, 4, 5, 6, 7], id: \.self) { n in
                    let isSelected = (n == 4)
                    styledDayCircle(number: n, isSelected: isSelected, style: styleIndex)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .homeSocialCard(cornerRadius: 14)
    }

    @ViewBuilder
    private func styledDayCircle(number: Int, isSelected: Bool, style: Int) -> some View {
        let size: CGFloat = 34
        let gradient = GQGradients.primary
        let unselectedBg = AnyShapeStyle(GQColors.adaptiveOverlay(0.05))
        let unselectedText = GQColors.textSecondary
        let numberText = Text("\(number)").font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))

        switch style {
        case 0: // V1 · Solid flat purple
            numberText
                .foregroundColor(isSelected ? .white : unselectedText)
                .frame(width: size, height: size)
                .background(isSelected ? AnyShapeStyle(GQColors.vividPurple) : unselectedBg)
                .clipShape(Circle())

        case 1: // V2 · Subtle tint + brand text
            numberText
                .foregroundColor(isSelected ? GQColors.vividPurple : unselectedText)
                .frame(width: size, height: size)
                .background(isSelected ? AnyShapeStyle(gradient.opacity(0.14)) : unselectedBg)
                .clipShape(Circle())

        case 2: // V3 · Outlined gradient ring
            numberText
                .foregroundColor(isSelected ? GQColors.vividPurple : unselectedText)
                .frame(width: size, height: size)
                .background(isSelected ? AnyShapeStyle(Color.clear) : unselectedBg)
                .clipShape(Circle())
                .overlay(
                    Circle().strokeBorder(isSelected ? AnyShapeStyle(gradient) : AnyShapeStyle(Color.clear), lineWidth: 1.5)
                )

        case 3: // V4 · Today-card mimic (thin gradient outline + tint)
            numberText
                .foregroundColor(isSelected ? GQColors.textPrimary : unselectedText)
                .frame(width: size, height: size)
                .background(isSelected ? AnyShapeStyle(gradient.opacity(0.08)) : unselectedBg)
                .clipShape(Circle())
                .overlay(
                    Circle().strokeBorder(isSelected ? AnyShapeStyle(gradient.opacity(0.85)) : AnyShapeStyle(Color.clear), lineWidth: 1.5)
                )

        case 4: // V5 · Tinted bg + small dot indicator
            VStack(spacing: 2) {
                numberText
                    .foregroundColor(isSelected ? GQColors.textPrimary : unselectedText)
                Circle()
                    .fill(isSelected ? AnyShapeStyle(gradient) : AnyShapeStyle(Color.clear))
                    .frame(width: 4, height: 4)
            }
            .frame(width: size, height: size)
            .background(isSelected ? AnyShapeStyle(gradient.opacity(0.08)) : unselectedBg)
            .clipShape(Circle())

        case 5: // V6 · White elevated + gradient text
            numberText
                .foregroundStyle(isSelected ? AnyShapeStyle(gradient) : AnyShapeStyle(unselectedText))
                .frame(width: size, height: size)
                .background(isSelected ? AnyShapeStyle(Color.white) : unselectedBg)
                .clipShape(Circle())
                .shadow(color: isSelected ? Color.black.opacity(0.08) : .clear, radius: 3, y: 1.5)

        case 6: // V7 · Gradient text only, transparent fill
            numberText
                .foregroundStyle(isSelected ? AnyShapeStyle(gradient) : AnyShapeStyle(unselectedText))
                .frame(width: size, height: size)
                .background(unselectedBg)
                .clipShape(Circle())

        case 7: // V8 · Solid deepBlue
            numberText
                .foregroundColor(isSelected ? .white : unselectedText)
                .frame(width: size, height: size)
                .background(isSelected ? AnyShapeStyle(GQColors.deepBlue) : unselectedBg)
                .clipShape(Circle())

        case 8: // V9 · Soft halo behind circle
            ZStack {
                if isSelected {
                    Circle().fill(gradient.opacity(0.15)).frame(width: size + 10, height: size + 10).blur(radius: 8)
                }
                numberText
                    .foregroundColor(isSelected ? .white : unselectedText)
                    .frame(width: size, height: size)
                    .background(isSelected ? AnyShapeStyle(gradient) : unselectedBg)
                    .clipShape(Circle())
            }
            .frame(width: size, height: size)

        case 9: // V10 · Thin gradient border, clear fill
            numberText
                .foregroundStyle(isSelected ? AnyShapeStyle(gradient) : AnyShapeStyle(unselectedText))
                .frame(width: size, height: size)
                .overlay(
                    Circle().strokeBorder(isSelected ? AnyShapeStyle(gradient) : AnyShapeStyle(Color.clear), lineWidth: 1)
                )

        default:
            numberText.foregroundColor(unselectedText).frame(width: size, height: size).background(unselectedBg).clipShape(Circle())
        }
    }

    private func cellBackground(planned: String?, isToday: Bool, done: Bool, isPast: Bool) -> some ShapeStyle {
        if isToday {
            return AnyShapeStyle(GQGradients.primary.opacity(0.12))
        }
        if done {
            return AnyShapeStyle(GQGradients.primary.opacity(0.06))
        }
        if let p = planned, p != "Rest" {
            return AnyShapeStyle(GQGradients.primary.opacity(isPast ? 0.03 : 0.07))
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
                    .foregroundColor(GQColors.textSecondary)
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
                                            .foregroundColor(GQColors.textSecondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(GQColors.adaptiveOverlay(0.06))
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

// MARK: - Custom Split Builder

struct CustomSplitBuilderSheet: View {
    @Bindable var profile: UserProfile
    let onApply: ([String]) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var splitOrder: [String] = []
    @State private var customName: String = ""

    private let allTypes = ["Push", "Pull", "Legs", "Upper", "Lower", "Full Body", "Cardio", "HIIT", "Yoga", "Glutes", "Abs"]

    var body: some View {
        VStack(spacing: 16) {
            splitHeader
            splitOrderRow
            typeGrid
            customNameField
            Spacer()
            actionButtons
        }
        .background(GQColors.background.ignoresSafeArea())
        .onAppear {
            if !profile.splitOrder.isEmpty {
                splitOrder = profile.splitOrder
            }
        }
    }

    @ViewBuilder
    private var splitHeader: some View {
        VStack(spacing: 4) {
            Text("Build Your Split")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(GQColors.textPrimary)
            Text("Tap types in the order you train them.")
                .font(.system(size: 13))
                .foregroundColor(GQColors.textTertiary)
        }
        .padding(.top, 20)
    }

    @ViewBuilder
    private var splitOrderRow: some View {
        if !splitOrder.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(splitOrder.enumerated()), id: \.offset) { idx, type in
                        splitChip(type: type, index: idx)
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 34)
        } else {
            Text("No types selected yet")
                .font(.system(size: 12))
                .foregroundColor(GQColors.textTertiary)
                .frame(height: 34)
        }
    }

    private func splitChip(type: String, index: Int) -> some View {
        HStack(spacing: 4) {
            Text(type)
                .font(.system(size: 12, weight: .semibold))
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    let i: Int = index
                    splitOrder.remove(at: i)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.6))
            }
        }
        .foregroundColor(Color.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(GQGradients.primary)
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var typeGrid: some View {
        let columns = [GridItem(.adaptive(minimum: 80), spacing: 8)]
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(allTypes, id: \.self) { type in
                typeButton(type)
            }
            ForEach(profile.recentCustomLabels.filter { $0.count >= 2 }, id: \.self) { label in
                typeButton(label)
            }
        }
        .padding(.horizontal, 20)
    }

    private func typeButton(_ type: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                splitOrder.append(type)
            }
            #if canImport(UIKit)
            UISelectionFeedbackGenerator().selectionChanged()
            #endif
        } label: {
            Text(type)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(GQColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(GQColors.adaptiveOverlay(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var customNameField: some View {
        HStack(spacing: 8) {
            TextField("Custom name (e.g. Chest & Tri, Run)", text: $customName)
                .font(.system(size: 13))
                .foregroundColor(GQColors.textPrimary)
                .tint(Color(white: 0.25))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(GQColors.adaptiveOverlay(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .submitLabel(.done)
                .onSubmit { addCustomName() }

            Button {
                addCustomName()
            } label: {
                Text("Add")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(customName.trimmingCharacters(in: .whitespaces).isEmpty ? AnyShapeStyle(GQColors.adaptiveOverlay(0.1)) : AnyShapeStyle(GQGradients.primary))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(customName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 20)
    }

    private func addCustomName() {
        let trimmed = customName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            splitOrder.append(trimmed)
        }
        customName = ""
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 12) {
            if !splitOrder.isEmpty {
                Button {
                    withAnimation { splitOrder = [] }
                } label: {
                    Text("Clear")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(GQColors.adaptiveOverlay(0.05))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Button {
                onApply(splitOrder)
                dismiss()
            } label: {
                Text("Apply")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(splitOrder.isEmpty ? AnyShapeStyle(GQColors.adaptiveOverlay(0.1)) : AnyShapeStyle(GQGradients.primary))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(splitOrder.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
}

// MARK: - Calendar Variant Previews (unused - preview removed)
#if false
private func calendarVariantWeekRow() -> some View {
    let labels = ["S", "M", "T", "W", "T", "F", "S"]
    let todayIdx = Calendar.current.component(.weekday, from: Date()) - 1
    let today = Calendar.current.startOfDay(for: Date())
    let weekStart = Calendar.current.date(byAdding: .day, value: -todayIdx, to: today)!
    return HStack(spacing: 0) {
        ForEach(0..<7, id: \.self) { i in
            let isToday = i == todayIdx
            let dayDate = Calendar.current.date(byAdding: .day, value: i, to: weekStart)!
            let dayNum = Calendar.current.component(.day, from: dayDate)
            VStack(spacing: 6) {
                Text(labels[i])
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(1.2)
                    .foregroundColor(isToday ? GQColors.textPrimary : GQColors.textTertiary)
                ZStack {
                    if isToday {
                        Circle().fill(GQGradients.primary.opacity(0.06))
                        Circle().strokeBorder(GQGradients.primary.opacity(0.85), lineWidth: 1.5)
                    } else {
                        Circle().fill(GQColors.adaptiveOverlay(0.045))
                    }
                    Text("\(dayNum)")
                        .font(.system(size: 15, weight: isToday ? .semibold : .medium, design: .rounded))
                        .foregroundColor(isToday ? GQColors.textPrimary : GQColors.textTertiary)
                }
                .frame(width: 36, height: 36)
                Color.clear.frame(height: 10)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private func calendarVariantStreak(dailyStreak: Int, weeklyStreak: Int) -> some View {
    VStack(alignment: .trailing, spacing: 2) {
        HStack(spacing: 5) {
            Image(systemName: "flame.fill")
                .font(.system(size: 13))
                .foregroundStyle(LinearGradient(colors: [.orange, .red.opacity(0.8)], startPoint: .bottom, endPoint: .top))
            Text("\(dailyStreak)")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(GQColors.textPrimary)
        }
        if weeklyStreak > 0 {
            Text("\(weeklyStreak) week streak")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
        }
    }
}

// Variant A — current
struct CalVariantA: View {
    let completed: Int
    let target: Int
    let dailyStreak: Int
    let weeklyStreak: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("THIS WEEK")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.2)
                        .foregroundColor(GQColors.textTertiary)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(completed)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(GQGradients.primary)
                        Text("/ \(target)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(GQColors.textTertiary)
                    }
                }
                Spacer()
                calendarVariantStreak(dailyStreak: dailyStreak, weeklyStreak: weeklyStreak)
            }
            calendarVariantWeekRow()
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .homeSocialCard(cornerRadius: 14)
    }
}

// Variant B — inline progress bar under header
struct CalVariantB: View {
    let completed: Int
    let target: Int
    let dailyStreak: Int
    let weeklyStreak: Int
    var progress: CGFloat { target > 0 ? min(CGFloat(completed)/CGFloat(target), 1) : 0 }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("THIS WEEK")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.2)
                        .foregroundColor(GQColors.textTertiary)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(completed)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(GQGradients.primary)
                        Text("/ \(target)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(GQColors.textTertiary)
                    }
                }
                Spacer()
                calendarVariantStreak(dailyStreak: dailyStreak, weeklyStreak: weeklyStreak)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(GQColors.adaptiveOverlay(0.06)).frame(height: 4)
                    Capsule().fill(GQGradients.primary).frame(width: max(geo.size.width * progress, 4), height: 4)
                }
            }
            .frame(height: 4)
            calendarVariantWeekRow()
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .homeSocialCard(cornerRadius: 14)
    }
}

// Variant C — hero stat, bigger number + softer secondary
struct CalVariantC: View {
    let completed: Int
    let target: Int
    let dailyStreak: Int
    let weeklyStreak: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(completed)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(GQGradients.primary)
                    Text("of \(target) workouts")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(GQColors.textSecondary)
                }
                Spacer()
                calendarVariantStreak(dailyStreak: dailyStreak, weeklyStreak: weeklyStreak)
            }
            calendarVariantWeekRow()
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .homeSocialCard(cornerRadius: 14)
    }
}

// Variant D — mini progress ring
struct CalVariantD: View {
    let completed: Int
    let target: Int
    let dailyStreak: Int
    let weeklyStreak: Int
    var progress: CGFloat { target > 0 ? min(CGFloat(completed)/CGFloat(target), 1) : 0 }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle().stroke(GQColors.adaptiveOverlay(0.08), lineWidth: 3.5)
                        .frame(width: 34, height: 34)
                    Circle().trim(from: 0, to: progress)
                        .stroke(GQGradients.primary, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 34, height: 34)
                    Text("\(completed)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(GQColors.textPrimary)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("This Week")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                    Text("\(completed) of \(target) workouts")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)
                }
                Spacer()
                calendarVariantStreak(dailyStreak: dailyStreak, weeklyStreak: weeklyStreak)
            }
            calendarVariantWeekRow()
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .homeSocialCard(cornerRadius: 14)
    }
}

#endif

struct CalAlignShell<Content: View>: View {
    let tag: String
    let content: Content
    init(tag: String, @ViewBuilder content: () -> Content) {
        self.tag = tag
        self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(tag)
                .font(.system(size: 9, weight: .bold))
                .tracking(1.0)
                .foregroundColor(GQColors.textTertiary.opacity(0.7))
                .padding(.leading, 4)
            content
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .homeSocialCard(cornerRadius: 14)
        }
    }
}

struct SemiGauge: View {
    let progress: Double
    let grad: LinearGradient
    let value: String
    let unit: String
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .trim(from: 0.5, to: 1.0)
                    .stroke(GQColors.adaptiveOverlay(0.06), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(180))
                    .frame(width: 96, height: 96)
                Circle()
                    .trim(from: 0.5, to: 0.5 + 0.5 * progress)
                    .stroke(grad, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(180))
                    .frame(width: 96, height: 96)
                VStack(spacing: 0) {
                    Text(value).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(GQColors.textPrimary)
                    Text(unit).font(.system(size: 9, weight: .medium)).foregroundColor(GQColors.textTertiary)
                }
                .offset(y: 10)
            }
            .frame(width: 96, height: 56, alignment: .top)
            .clipped()
        }
    }
}

struct SegmentedRing: View {
    let progress: Double
    let grad: LinearGradient
    let diameter: CGFloat
    let segments: Int
    let lineWidth: CGFloat
    var body: some View {
        let gap = 0.02
        let per = (1.0 - Double(segments) * gap) / Double(segments)
        let filled = Int(Double(segments) * progress)
        ZStack {
            ForEach(0..<segments, id: \.self) { i in
                let start = Double(i) * (per + gap)
                let end = start + per
                Circle()
                    .trim(from: start, to: end)
                    .stroke(i < filled ? AnyShapeStyle(grad) : AnyShapeStyle(GQColors.adaptiveOverlay(0.08)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
                    .frame(width: diameter, height: diameter)
            }
            Text("\(Int(progress * 100))%").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(GQColors.textPrimary)
        }
    }
}

