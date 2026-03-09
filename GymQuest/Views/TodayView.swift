//
//  TodayView.swift
//  GymQuest
//
//  Created by Benjamin Hilderman
//
//  Hero home screen — progress ring, start workout CTA, streak,
//  daily dashboard stats, and last workout quick-repeat.
//

import SwiftUI
import SwiftData

struct TodayView: View {
    let profile: UserProfile

    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workout.date, order: .reverse) private var allWorkouts: [Workout]

    @State private var showDraftBanner = false
    @State private var draftWorkoutType: String = ""
    @State private var draftStartTime: Date = Date()

    private var nonRestWorkouts: [Workout] {
        allWorkouts.filter { $0.type != .rest }
    }

    private var workoutsThisWeek: Int {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }
        return nonRestWorkouts.filter { $0.date >= startOfWeek }.count
    }

    private var streakDays: Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        let todayWorkouts = nonRestWorkouts.filter { calendar.isDate($0.date, inSameDayAs: checkDate) }
        if todayWorkouts.isEmpty {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }

        while true {
            let dayWorkouts = nonRestWorkouts.filter { calendar.isDate($0.date, inSameDayAs: checkDate) }
            if dayWorkouts.isEmpty { break }
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }

        return streak
    }

    private var lastNonRestWorkout: Workout? {
        nonRestWorkouts.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    dateHeader

                    if showDraftBanner {
                        resumeDraftBanner
                    }

                    WeeklyProgressRing(
                        completed: workoutsThisWeek,
                        target: profile.daysPerWeek
                    )

                    startWorkoutHeroButton

                    if streakDays > 0 {
                        streakBanner
                    }

                    TodayDashboardSection(
                        profile: profile,
                        workoutsThisWeek: workoutsThisWeek,
                        allWorkouts: allWorkouts
                    )
                    .environment(\.modelContext, modelContext)

                    if let workout = lastNonRestWorkout {
                        lastWorkoutQuickRepeatCard(workout)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .scrollContentBackground(.hidden)
            .gqPageBackground()
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { checkForDraft() }
        }
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
                    .foregroundStyle(GQColors.sunsetOrange)

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
                        .foregroundColor(GQColors.sunsetOrange)
                    Text("Log Food")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(GQColors.sunsetOrange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(GQColors.sunsetOrange.opacity(0.3), lineWidth: 1)
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

    // MARK: - Streak Banner

    @State private var flameScale: CGFloat = 1.0

    private var streakBanner: some View {
        HStack(spacing: 10) {
            ZStack {
                Image(systemName: "flame.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .scaleEffect(flameScale)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                            flameScale = 1.15
                        }
                    }
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(streakDays) day streak!")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(GQColors.textPrimary)
                Text("Keep it going!")
                    .font(.system(size: 13))
                    .foregroundStyle(GQColors.textSecondary)
            }

            Spacer()

            Text("\(streakDays)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .homeSocialCard(cornerRadius: 14)
    }

    // MARK: - Last Workout Quick Repeat

    @ViewBuilder
    private func lastWorkoutQuickRepeatCard(_ workout: Workout) -> some View {
        HStack(spacing: 12) {
            Image(systemName: workout.type.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(GQGradients.workoutGradient(for: workout.type))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(workout.title ?? workout.type.rawValue)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)
                Text("\(workout.exercises.count) exercises \u{00B7} \(workout.date.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textSecondary)
            }

            Spacer()

            Button {
                repeatWorkout(workout)
            } label: {
                Text("Repeat")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(GQGradients.primary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .homeSocialCard(cornerRadius: 14)
    }

    private func repeatWorkout(_ workout: Workout) {
        let exercises = workout.exercises.sorted(by: { $0.order < $1.order }).map { exercise in
            ActiveExercise(
                name: exercise.name,
                muscleGroup: exercise.muscleGroup,
                sets: exercise.sets.sorted(by: { $0.order < $1.order }).map { set in
                    ActiveSet(reps: set.reps, weight: set.weight)
                }
            )
        }
        appState.startWorkout(type: workout.type, exercises: exercises)
    }
}
