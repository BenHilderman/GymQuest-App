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

            WeeklyProgressRing(
                completed: workoutsThisWeek,
                target: $profile.daysPerWeek,
                workoutDates: thisWeekWorkoutDates,
                workoutIcons: thisWeekWorkoutIcons,
                dailyStreak: dailyStreak,
                weeklyStreak: weeklyStreak,
                totalMinutes: weeklyWorkoutMinutes,
                totalSets: weeklyTotalSets,
                totalVolume: weeklyTotalVolume
            )

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

            TodayDashboardSection(
                profile: profile,
                workoutsThisWeek: workoutsThisWeek,
                allWorkouts: allWorkouts
            )
            .environment(\.modelContext, modelContext)

            sectionDivider

            startWorkoutHeroButton

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
