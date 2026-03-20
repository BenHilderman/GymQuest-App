//
//  WorkoutStartOptionsView.swift
//  GymQuest
//
//  Workout start hub — tap "+" → hub sheet → pick a route → navigates to dedicated page.
//

import SwiftUI
import SwiftData

// MARK: - Workout Start Options View

struct WorkoutStartOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Workout.date, order: .reverse) private var recentWorkouts: [Workout]
    @Query(sort: \WorkoutTemplate.createdAt, order: .reverse) private var savedTemplates: [WorkoutTemplate]

    let profile: UserProfile

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        heroSection
                            .padding(.top, 8)

                        sectionLabel("CHOOSE YOUR PATH")

                        VStack(spacing: 14) {
                            routeCard(
                                icon: "figure.strengthtraining.traditional",
                                title: "Custom Workout",
                                subtitle: "Choose your split and go",
                                accent: GQColors.deepBlue,
                                useGradient: true
                            ) {
                                WorkoutTypeSelectionView(profile: profile)
                            }

                            routeCard(
                                icon: "clock.arrow.circlepath",
                                title: "Follow Previous",
                                subtitle: previousWorkoutSubtitle,
                                accent: GQColors.deepBlue,
                                useGradient: true
                            ) {
                                PreviousWorkoutsListView(profile: profile, workouts: nonRestWorkouts)
                            }

                            routeCard(
                                icon: "bookmark.fill",
                                title: "Saved Workouts",
                                subtitle: savedWorkoutsSubtitle,
                                accent: GQColors.deepBlue,
                                badgeText: savedTemplates.isEmpty ? nil : "\(savedTemplates.count)",
                                useGradient: true
                            ) {
                                SavedWorkoutsListView(profile: profile, templates: savedTemplates)
                            }

                            routeCard(
                                icon: "brain.head.profile",
                                title: "AI Generated",
                                subtitle: "Smart recommendation",
                                accent: GQColors.deepBlue,
                                badgeText: "AI",
                                useGradient: true
                            ) {
                                AIGeneratedPlaceholderView()
                            }
                        }

                        motivationalStats

                        Spacer(minLength: 34)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .gqPageBackground()
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(GQColors.textPrimary)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)
                    .frame(width: 34, height: 34)
                    .background(GQColors.adaptiveOverlay(0.04))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Start Workout")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(GQGradients.primary)

            Text("Pick how you want to train today.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(GQColors.textSecondary)
        }
    }

    // MARK: - Section Label

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(GQTypography.sectionHeader)
            .foregroundColor(GQColors.textTertiary)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    // MARK: - Route Card

    private func routeCard<Destination: View>(
        icon: String,
        title: String,
        subtitle: String,
        accent: Color,
        badgeText: String? = nil,
        useGradient: Bool = false,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 14) {
                Circle()
                    .fill(useGradient ? GQColors.deepBlue.opacity(0.08) : accent.opacity(0.10))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(useGradient ? GQGradients.primary : LinearGradient(colors: [accent, accent], startPoint: .leading, endPoint: .trailing))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(GQColors.textPrimary)

                        if let badgeText {
                            Text(badgeText)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(accent.opacity(0.80))
                                .clipShape(Capsule())
                        }
                    }

                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(GQColors.textTertiary)
            }
            .padding(14)
            .homeSocialCard(cornerRadius: 14)
        }
        .buttonStyle(GQInteractiveStyle())
    }

    // MARK: - Motivational Stats

    private var motivationalStats: some View {
        VStack(spacing: 0) {
            sectionLabel("YOUR PROGRESS")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 10)

            HStack(spacing: 0) {
                statItem(value: "\(streakDays)", label: "Day Streak")
                Divider()
                    .frame(height: 28)
                    .overlay(GQColors.borderSubtle)
                statItem(value: "\(workoutsThisWeek)", label: "This Week")
                Divider()
                    .frame(height: 28)
                    .overlay(GQColors.borderSubtle)
                statItem(value: "Lv \(profile.level)", label: "Level")
            }
            .padding(.vertical, 14)
            .homeSocialCard(cornerRadius: 14)
        }
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(GQColors.textPrimary)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Computed Properties

    private var nonRestWorkouts: [Workout] {
        recentWorkouts.filter { $0.type != .rest }
    }

    private var previousWorkoutSubtitle: String {
        if let last = nonRestWorkouts.first {
            return "Last: \(last.type.rawValue) — \(last.date.formatted(.dateTime.month(.abbreviated).day()))"
        }
        return "Repeat a recent workout"
    }

    private var savedWorkoutsSubtitle: String {
        let count = savedTemplates.count
        if count > 0 {
            return "\(count) saved template\(count == 1 ? "" : "s")"
        }
        return "No saved templates yet"
    }

    private var workoutsThisWeek: Int {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return nonRestWorkouts.filter { $0.date >= weekStart }.count
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
}

// MARK: - Previous Workouts List View

struct PreviousWorkoutsListView: View {
    @EnvironmentObject var appState: AppState

    let profile: UserProfile
    let workouts: [Workout]

    var body: some View {
        Group {
            if workouts.isEmpty {
                emptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: "No previous workouts",
                    body: "Complete a workout first, then come back to repeat it."
                )
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        ForEach(workouts.prefix(20)) { workout in
                            workoutRow(workout)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 34)
                }
            }
        }
        .gqPageBackground()
        .navigationTitle("Previous Workouts")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func workoutRow(_ workout: Workout) -> some View {
        HStack(spacing: 12) {
            Button {
                startFromPrevious(workout)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: workout.type.icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(GQGradients.workoutGradient(for: workout.type))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(workout.title ?? workout.type.rawValue)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(GQColors.textPrimary)
                        Text("\(workout.exercises.count) exercises · \(workout.date.formatted(.dateTime.month(.abbreviated).day()))")
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textSecondary)
                    }

                    Spacer()
                }
            }
            .buttonStyle(.plain)

            WorkoutFavoriteButton(workout: workout)

            Button {
                startFromPrevious(workout)
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(GQGradients.primary)
                    .frame(width: 40, height: 40)
                    .background(GQColors.deepBlue.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .homeSocialCard(cornerRadius: 14)
    }

    private func startFromPrevious(_ workout: Workout) {
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

// MARK: - Saved Workouts List View

struct SavedWorkoutsListView: View {
    @EnvironmentObject var appState: AppState

    let profile: UserProfile
    let templates: [WorkoutTemplate]

    var body: some View {
        Group {
            if templates.isEmpty {
                emptyStateView(
                    icon: "bookmark",
                    title: "No saved workouts",
                    body: "Save workout templates from the feed to use them here."
                )
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        ForEach(templates) { template in
                            templateRow(template)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 34)
                }
            }
        }
        .gqPageBackground()
        .navigationTitle("Saved Workouts")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func templateRow(_ template: WorkoutTemplate) -> some View {
        Button {
            startFromTemplate(template)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: template.workoutType.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(GQGradients.workoutGradient(for: template.workoutType))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(template.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                    Text("\(template.estimatedDuration) min · Used \(template.useCount) times")
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textSecondary)
                }

                Spacer()

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(GQGradients.primary)
                    .frame(width: 40, height: 40)
                    .background(GQColors.deepBlue.opacity(0.08))
                    .clipShape(Circle())
            }
            .padding(14)
            .homeSocialCard(cornerRadius: 14)
        }
        .buttonStyle(GQInteractiveStyle())
    }

    private func startFromTemplate(_ template: WorkoutTemplate) {
        var activeExercises: [ActiveExercise] = []
        if let data = template.exerciseData,
           let decoded = try? JSONDecoder().decode([SharedWorkoutData.SharedExercise].self, from: data) {
            activeExercises = decoded.map { shared in
                ActiveExercise(
                    name: shared.name,
                    muscleGroup: MuscleGroup(rawValue: shared.muscleGroup) ?? .chest,
                    sets: shared.sets.map { s in
                        ActiveSet(reps: s.reps, weight: s.weight)
                    }
                )
            }
        }

        appState.startWorkout(type: template.workoutType, exercises: activeExercises)

        template.useCount += 1
        template.lastUsedAt = Date()
    }
}

// MARK: - AI Generated Placeholder

struct AIGeneratedPlaceholderView: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Circle()
                    .fill(GQColors.deepBlue.opacity(0.08))
                    .frame(width: 72, height: 72)
                    .overlay(
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 40))
                            .foregroundColor(GQColors.textTertiary)
                    )

                Text("Coming Soon")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(GQColors.textSecondary)

                Text("AI-powered workout recommendations are on the way.")
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
            }
            .padding(24)
            .homeSocialCard(cornerRadius: 14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: [GQColors.deepBlue.opacity(0.3), GQColors.deepBlue.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .padding(.horizontal, 16)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .gqPageBackground()
        .navigationTitle("AI Generated")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Empty State Helper

private func emptyStateView(icon: String, title: String, body: String) -> some View {
    VStack(spacing: 0) {
        Spacer()

        VStack(spacing: 16) {
            Circle()
                .fill(GQColors.deepBlue.opacity(0.08))
                .frame(width: 72, height: 72)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 40))
                        .foregroundColor(GQColors.textTertiary)
                )

            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(GQColors.textSecondary)

            Text(body)
                .font(.system(size: 13))
                .foregroundColor(GQColors.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
        }

        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}

// MARK: - Workout Favorite Button

struct WorkoutFavoriteButton: View {
    @Bindable var workout: Workout
    @State private var heartScale: CGFloat = 1.0

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                workout.isFavorite.toggle()
                heartScale = 1.3
            }
            HapticManager.shared.impact(.light)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    heartScale = 1.0
                }
            }
        } label: {
            Image(systemName: workout.isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 20))
                .foregroundColor(workout.isFavorite ? GQColors.textSecondary : GQColors.textTertiary)
                .scaleEffect(heartScale)
        }
        .buttonStyle(.plain)
    }
}
