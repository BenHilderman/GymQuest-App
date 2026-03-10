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

    @State private var showDraftBanner = false
    @State private var draftWorkoutType: String = ""
    @State private var draftStartTime: Date = Date()
    @State private var showingPlanOptions = false
    @State private var selectedSubTab: TodaySubTab = .today

    private enum TodaySubTab: String, CaseIterable {
        case today = "Today"
        case progress = "Progress"
    }

    private var nonRestWorkouts: [Workout] {
        allWorkouts.filter { $0.type != .rest }
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

    private var lastNonRestWorkout: Workout? {
        nonRestWorkouts.first
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab bar matching Feed style
                todayTabBar

                ScrollView {
                    switch selectedSubTab {
                    case .today:
                        todayContent
                    case .progress:
                        ProgressAnalyticsView(profile: profile, inline: true)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .gqPageBackground()
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { checkForDraft() }
        }
    }

    private var todayContent: some View {
        VStack(spacing: 16) {
            dateHeader

            if showDraftBanner {
                resumeDraftBanner
            }

            WeeklyProgressRing(
                completed: workoutsThisWeek,
                target: $profile.daysPerWeek,
                workoutDates: thisWeekWorkoutDates
            )

            startWorkoutHeroButton

            TodayDashboardSection(
                profile: profile,
                workoutsThisWeek: workoutsThisWeek,
                allWorkouts: allWorkouts
            )
            .environment(\.modelContext, modelContext)

            if let todayPlan = todaysPlanDay {
                plannedWorkoutCard(todayPlan)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
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
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(GQColors.textSecondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Resume last workout?")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                    Text("\(draftWorkoutType) \u{00B7} Started \(draftStartTime, format: .dateTime.month(.abbreviated).day().hour().minute())")
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()
            }

            HStack(spacing: 12) {
                Button {
                    discardDraft()
                } label: {
                    Text("Discard")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(GQColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(GQColors.textSecondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button {
                    resumeDraft()
                } label: {
                    Text("Resume")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(GQGradients.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .homeSocialCard(cornerRadius: 14)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Quick Log Section

    private var quickLogSection: some View {
        HStack(spacing: 12) {
            Button {
                appState.showingAddMeasurement = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "scalemass.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(GQColors.success)
                    Text("Log Weight")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(GQColors.success.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(GQColors.success.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Button {
                appState.showingMealLog = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(GQColors.textSecondary)
                    Text("Log Food")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(GQColors.textSecondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(GQColors.textSecondary.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Date Header

    private var dateHeader: some View {
        HStack {
            Text(Date(), format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(GQColors.textPrimary)
            Spacer()
        }
        .padding(.top, 4)
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
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedSubTab = tab
                            }
                        }
                }
            }
            .padding(.bottom, 6)

            GeometryReader { geometry in
                let tabWidth = geometry.size.width / CGFloat(TodaySubTab.allCases.count)
                let underlineWidth: CGFloat = 40
                Rectangle()
                    .fill(GQGradients.primary)
                    .frame(width: underlineWidth, height: 1.5)
                    .clipShape(RoundedRectangle(cornerRadius: 0.75))
                    .offset(x: tabWidth * CGFloat(subTabIndex) + (tabWidth - underlineWidth) / 2)
                    .animation(.easeInOut(duration: 0.3), value: subTabIndex)
            }
            .frame(height: 1.5)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 6)
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
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 18, weight: .semibold))
                Text("Start Workout")
                    .font(.system(size: 18, weight: .semibold))
            }
        }
        .buttonStyle(PrimaryButtonStyle())
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

        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: wType.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(GQGradients.workoutGradient(for: wType))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Today's Plan")
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textSecondary)
                    Text(day.label)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                }

                Spacer()

                Text("\(day.exercises.count) exercises")
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 12)

            Divider()
                .overlay(GQColors.borderDefault)

            // Options
            HStack(spacing: 8) {
                planOptionButton(label: "Same as Last", icon: "clock.arrow.circlepath") {
                    startPlannedFromLast(wType)
                }
                planOptionButton(label: "AI", icon: "brain.head.profile") {
                    startPlannedAI(wType)
                }
                planOptionButton(label: "Fresh", icon: "plus") {
                    startPlannedFresh(wType)
                }
            }
            .padding(14)
        }
        .homeSocialCard(cornerRadius: 14)
    }

    private func planOptionButton(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(GQColors.deepBlue)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(GQColors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
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
            // No previous workout of this type, start fresh
            appState.startWorkout(type: type, exercises: [])
        }
    }

    private func startPlannedAI(_ type: WorkoutType) {
        // Opens the workout start flow which has AI option
        appState.showingWorkoutStartOptions = true
    }

    private func startPlannedFresh(_ type: WorkoutType) {
        appState.startWorkout(type: type, exercises: [])
    }
}
