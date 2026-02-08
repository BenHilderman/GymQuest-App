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
    @State private var appearAnimation = false

    var body: some View {
        NavigationStack {
            ZStack {
                GQColors.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Hero
                        VStack(spacing: 8) {
                            Text("Start Workout")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)

                            Text("How do you want to train?")
                                .font(.system(size: 16))
                                .foregroundColor(GQColors.textSecondary)
                        }
                        .padding(.top, 16)
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 15)

                        // Options
                        VStack(spacing: 12) {
                            StartOptionCard(
                                icon: "figure.strengthtraining.traditional",
                                title: "Custom",
                                subtitle: "Pick your workout type and exercises",
                                accentColor: GQColors.vividPurple
                            ) {
                                showingTypePicker = true
                            }
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(x: appearAnimation ? 0 : 40)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: appearAnimation)

                            StartOptionCard(
                                icon: "brain.head.profile",
                                title: "AI Generated",
                                subtitle: "Smart workout based on your history",
                                accentColor: GQColors.cyanSpark,
                                badge: "AI"
                            ) {
                                // AI flow — opens type picker for now, future: full AI generation
                                showingTypePicker = true
                            }
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(x: appearAnimation ? 0 : 40)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: appearAnimation)

                            StartOptionCard(
                                icon: "clock.arrow.circlepath",
                                title: "Follow Previous",
                                subtitle: previousWorkoutSubtitle,
                                accentColor: GQColors.sunsetOrange
                            ) {
                                showingPreviousWorkouts = true
                            }
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(x: appearAnimation ? 0 : 40)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: appearAnimation)

                            StartOptionCard(
                                icon: "bookmark.fill",
                                title: "Saved Workouts",
                                subtitle: savedWorkoutsSubtitle,
                                accentColor: GQColors.success
                            ) {
                                showingSavedWorkouts = true
                            }
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(x: appearAnimation ? 0 : 40)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: appearAnimation)
                        }
                        .padding(.horizontal, 20)

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
            }
            .onAppear {
                withAnimation { appearAnimation = true }
            }
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
}

// MARK: - Start Option Card

struct StartOptionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let accentColor: Color
    var badge: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(accentColor)
                }

                // Text
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)

                        if let badge = badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    LinearGradient(
                                        colors: [GQColors.vividPurple, GQColors.cyanSpark],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(4)
                        }
                    }

                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(GQColors.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(GQColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
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

                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(GQColors.vividPurple)
                                }
                            }
                            .listRowBackground(GQColors.cardBackground)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(GQColors.background.ignoresSafeArea())
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
            .background(GQColors.background.ignoresSafeArea())
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
