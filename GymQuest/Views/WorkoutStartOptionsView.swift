//
//  WorkoutStartOptionsView.swift
//  GymQuest
//
//  Workout start options sheet - 4 ways to begin a workout:
//  Custom, AI Generated, Follow Previous, Saved Workouts
//

import SwiftUI
import SwiftData

struct WorkoutStartOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Workout.date, order: .reverse) private var recentWorkouts: [Workout]
    @Query(sort: \WorkoutTemplate.createdAt, order: .reverse) private var savedTemplates: [WorkoutTemplate]

    let profile: UserProfile

    @State private var showingTypePicker = false
    @State private var showingPreviousWorkouts = false
    @State private var showingSavedWorkouts = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: GQLayout.sectionSpacing) {
                        heroSection
                            .padding(.top, 8)

                        VStack(spacing: 10) {
                            optionCard(
                                icon: "figure.strengthtraining.traditional",
                                title: "Custom Workout",
                                subtitle: "Choose your split and build your session",
                                accent: GQColors.vividPurple,
                                emphasized: true
                            ) {
                                showingTypePicker = true
                            }

                            optionCard(
                                icon: "brain.head.profile",
                                title: "AI Generated",
                                subtitle: "Start from a smart recommendation",
                                accent: GQColors.cyanSpark,
                                badgeText: "AI"
                            ) {
                                showingTypePicker = true
                            }

                            optionCard(
                                icon: "clock.arrow.circlepath",
                                title: "Follow Previous",
                                subtitle: previousWorkoutSubtitle,
                                accent: GQColors.deepBlue
                            ) {
                                showingPreviousWorkouts = true
                            }

                            optionCard(
                                icon: "bookmark.fill",
                                title: "Saved Workouts",
                                subtitle: savedWorkoutsSubtitle,
                                accent: GQColors.success,
                                badgeText: savedTemplates.isEmpty ? nil : "\(savedTemplates.count)"
                            ) {
                                showingSavedWorkouts = true
                            }
                        }

                        motivationalStats

                        Spacer(minLength: 34)
                    }
                    .gqScreenHorizontalPadding()
                }
            }
            .gqPageBackground()
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingTypePicker) {
                WorkoutTypeSelectionView(profile: profile)
            }
            .sheet(isPresented: $showingPreviousWorkouts) {
                PreviousWorkoutsSheet(profile: profile, workouts: nonRestWorkouts)
            }
            .sheet(isPresented: $showingSavedWorkouts) {
                SavedWorkoutsSheet(profile: profile, templates: savedTemplates)
            }
        }
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, GQLayout.screenHorizontal)
        .padding(.top, 16)
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Start Workout")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)

            Text("Pick a flow that matches your day.")
                .font(.system(size: 15))
                .foregroundColor(GQColors.textSecondary)
        }
    }

    private func optionCard(
        icon: String,
        title: String,
        subtitle: String,
        accent: Color,
        badgeText: String? = nil,
        emphasized: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(accent.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)

                        if let badgeText {
                            Text(badgeText)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(accent.opacity(0.85))
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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(GQColors.textTertiary)
            }
            .padding(.horizontal, GQLayout.cardHorizontal)
            .padding(.vertical, GQLayout.cardVertical)
            .homeSocialCard(accent: accent, emphasized: emphasized)
        }
        .buttonStyle(GQInteractiveStyle())
    }

    private var motivationalStats: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                WorkoutFlowMetricChip(
                    icon: "flame.fill",
                    value: "\(streakDays)",
                    label: "Streak",
                    color: GQColors.success
                )
                WorkoutFlowMetricChip(
                    icon: "dumbbell.fill",
                    value: "\(workoutsThisWeek)",
                    label: "This Week",
                    color: GQColors.vividPurple
                )
                WorkoutFlowMetricChip(
                    icon: "star.fill",
                    value: "Lv \(profile.level)",
                    label: "Level",
                    color: GQColors.cyanSpark
                )
            }
            .padding(.vertical, 6)
        }
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
        // Compute consecutive days with workouts
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        // Check if today has a workout, if not start from yesterday
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

// MARK: - Previous Workouts Sheet

struct PreviousWorkoutsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    let profile: UserProfile
    let workouts: [Workout]

    var body: some View {
        NavigationStack {
            Group {
                if workouts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 48))
                            .foregroundColor(GQColors.textTertiary)
                        Text("No previous workouts")
                            .font(.headline)
                            .foregroundColor(GQColors.textSecondary)
                        Text("Complete a workout first, then come back to repeat it.")
                            .font(.subheadline)
                            .foregroundColor(GQColors.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(32)
                } else {
                    List {
                        ForEach(workouts.prefix(20)) { workout in
                            HStack(spacing: 12) {
                                Button {
                                    startFromPrevious(workout)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: workout.type.icon)
                                            .font(.system(size: 20))
                                            .foregroundColor(.white)
                                            .frame(width: 40, height: 40)
                                            .background(GQGradients.workoutGradient(for: workout.type))
                                            .clipShape(RoundedRectangle(cornerRadius: 10))

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(workout.title ?? workout.type.rawValue)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(.white)
                                            Text("\(workout.exercises.count) exercises · \(workout.date.formatted(.dateTime.month(.abbreviated).day()))")
                                                .font(.system(size: 13))
                                                .foregroundColor(GQColors.textSecondary)
                                        }

                                        Spacer()
                                    }
                                }

                                WorkoutFavoriteButton(workout: workout)

                                Button {
                                    startFromPrevious(workout)
                                } label: {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(GQColors.vividPurple)
                                }
                                .buttonStyle(.plain)
                            }
                            .listRowBackground(GQColors.cardBackground)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .gqPageBackground()
            .navigationTitle("Previous Workouts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(GQColors.cyanSpark)
                }
            }
        }
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
        dismiss()
    }
}

// MARK: - Saved Workouts Sheet

struct SavedWorkoutsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    let profile: UserProfile
    let templates: [WorkoutTemplate]

    var body: some View {
        NavigationStack {
            Group {
                if templates.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 48))
                            .foregroundColor(GQColors.textTertiary)
                        Text("No saved workouts")
                            .font(.headline)
                            .foregroundColor(GQColors.textSecondary)
                        Text("Save workout templates from the feed to use them here.")
                            .font(.subheadline)
                            .foregroundColor(GQColors.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(32)
                } else {
                    List {
                        ForEach(templates) { template in
                            Button {
                                startFromTemplate(template)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: template.workoutType.icon)
                                        .font(.system(size: 20))
                                        .foregroundColor(.white)
                                        .frame(width: 40, height: 40)
                                        .background(GQGradients.workoutGradient(for: template.workoutType))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(template.name)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.white)
                                        Text("\(template.estimatedDuration) min · Used \(template.useCount) times")
                                            .font(.system(size: 13))
                                            .foregroundColor(GQColors.textSecondary)
                                    }

                                    Spacer()

                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(GQColors.success)
                                }
                            }
                            .listRowBackground(GQColors.cardBackground)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .gqPageBackground()
            .navigationTitle("Saved Workouts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(GQColors.cyanSpark)
                }
            }
        }
    }

    private func startFromTemplate(_ template: WorkoutTemplate) {
        // Decode template exercises if available
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

        // Increment use count
        template.useCount += 1
        template.lastUsedAt = Date()

        dismiss()
    }
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
                .foregroundColor(workout.isFavorite ? GQColors.coralRed : GQColors.textTertiary)
                .scaleEffect(heartScale)
        }
        .buttonStyle(.plain)
    }
}
