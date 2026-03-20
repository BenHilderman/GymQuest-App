#if os(tvOS)
//
//  TVWorkoutView.swift
//  GymQuestTV
//
//  Guided workout screen for the tvOS companion app.
//  Phase 1: Workout type selection grid
//  Phase 2: Active workout with Siri Remote controls
//

import SwiftUI
import SwiftData
import Combine

// MARK: - Fitness+ Palette

private let offWhite = Color(white: 0.93)

// MARK: - Active Workout Models (TV-local, matching iOS definitions)

struct ActiveExercise: Identifiable {
    let id = UUID()
    var name: String
    var muscleGroup: MuscleGroup
    var sets: [ActiveSet]
    var notes: String = ""
}

struct ActiveSet: Identifiable {
    let id = UUID()
    var reps: Int
    var weight: Double
    var isCompleted: Bool = false
    var rpe: Int? = nil

    var volume: Double {
        weight * Double(reps)
    }
}

// MARK: - Workout Templates

private struct ExerciseTemplate {
    let name: String
    let muscleGroup: MuscleGroup
    let sets: Int
    let reps: Int
    let weight: Double
}

private let workoutTemplates: [WorkoutType: [ExerciseTemplate]] = [
    .push: [
        ExerciseTemplate(name: "Bench Press", muscleGroup: .chest, sets: 3, reps: 10, weight: 135),
        ExerciseTemplate(name: "Overhead Press", muscleGroup: .shoulders, sets: 3, reps: 8, weight: 95),
        ExerciseTemplate(name: "Incline Dumbbell Press", muscleGroup: .chest, sets: 3, reps: 10, weight: 50),
        ExerciseTemplate(name: "Lateral Raises", muscleGroup: .shoulders, sets: 3, reps: 12, weight: 20),
        ExerciseTemplate(name: "Tricep Pushdowns", muscleGroup: .triceps, sets: 3, reps: 12, weight: 40),
    ],
    .pull: [
        ExerciseTemplate(name: "Barbell Rows", muscleGroup: .back, sets: 3, reps: 10, weight: 135),
        ExerciseTemplate(name: "Pull-Ups", muscleGroup: .back, sets: 3, reps: 8, weight: 0),
        ExerciseTemplate(name: "Face Pulls", muscleGroup: .shoulders, sets: 3, reps: 15, weight: 30),
        ExerciseTemplate(name: "Barbell Curls", muscleGroup: .biceps, sets: 3, reps: 10, weight: 65),
        ExerciseTemplate(name: "Hammer Curls", muscleGroup: .biceps, sets: 3, reps: 12, weight: 30),
    ],
    .legs: [
        ExerciseTemplate(name: "Barbell Squat", muscleGroup: .quads, sets: 4, reps: 8, weight: 185),
        ExerciseTemplate(name: "Romanian Deadlift", muscleGroup: .hamstrings, sets: 3, reps: 10, weight: 135),
        ExerciseTemplate(name: "Leg Press", muscleGroup: .quads, sets: 3, reps: 12, weight: 270),
        ExerciseTemplate(name: "Leg Curls", muscleGroup: .hamstrings, sets: 3, reps: 12, weight: 90),
        ExerciseTemplate(name: "Calf Raises", muscleGroup: .calves, sets: 4, reps: 15, weight: 135),
    ],
    .upper: [
        ExerciseTemplate(name: "Bench Press", muscleGroup: .chest, sets: 3, reps: 8, weight: 155),
        ExerciseTemplate(name: "Barbell Rows", muscleGroup: .back, sets: 3, reps: 8, weight: 135),
        ExerciseTemplate(name: "Overhead Press", muscleGroup: .shoulders, sets: 3, reps: 10, weight: 85),
        ExerciseTemplate(name: "Lat Pulldown", muscleGroup: .back, sets: 3, reps: 10, weight: 120),
        ExerciseTemplate(name: "Dumbbell Curls", muscleGroup: .biceps, sets: 3, reps: 12, weight: 30),
    ],
    .lower: [
        ExerciseTemplate(name: "Barbell Squat", muscleGroup: .quads, sets: 4, reps: 8, weight: 185),
        ExerciseTemplate(name: "Hip Thrusts", muscleGroup: .glutes, sets: 3, reps: 10, weight: 185),
        ExerciseTemplate(name: "Walking Lunges", muscleGroup: .quads, sets: 3, reps: 12, weight: 50),
        ExerciseTemplate(name: "Leg Curls", muscleGroup: .hamstrings, sets: 3, reps: 12, weight: 90),
        ExerciseTemplate(name: "Calf Raises", muscleGroup: .calves, sets: 4, reps: 15, weight: 135),
    ],
    .fullBody: [
        ExerciseTemplate(name: "Deadlift", muscleGroup: .back, sets: 3, reps: 5, weight: 225),
        ExerciseTemplate(name: "Bench Press", muscleGroup: .chest, sets: 3, reps: 8, weight: 155),
        ExerciseTemplate(name: "Barbell Squat", muscleGroup: .quads, sets: 3, reps: 8, weight: 185),
        ExerciseTemplate(name: "Overhead Press", muscleGroup: .shoulders, sets: 3, reps: 8, weight: 95),
        ExerciseTemplate(name: "Barbell Rows", muscleGroup: .back, sets: 3, reps: 8, weight: 135),
    ],
    .cardio: [
        ExerciseTemplate(name: "Jump Rope", muscleGroup: .cardio, sets: 5, reps: 60, weight: 0),
        ExerciseTemplate(name: "Burpees", muscleGroup: .fullBody, sets: 4, reps: 15, weight: 0),
        ExerciseTemplate(name: "Mountain Climbers", muscleGroup: .core, sets: 4, reps: 30, weight: 0),
        ExerciseTemplate(name: "Box Jumps", muscleGroup: .quads, sets: 4, reps: 12, weight: 0),
    ],
    .custom: [
        ExerciseTemplate(name: "Bench Press", muscleGroup: .chest, sets: 3, reps: 10, weight: 135),
        ExerciseTemplate(name: "Barbell Rows", muscleGroup: .back, sets: 3, reps: 10, weight: 135),
        ExerciseTemplate(name: "Barbell Squat", muscleGroup: .quads, sets: 3, reps: 10, weight: 135),
    ],
]

// MARK: - Rest Time Defaults

private func defaultRestSeconds(for exerciseName: String) -> Int {
    let compoundLifts = ["Bench Press", "Barbell Squat", "Deadlift", "Overhead Press",
                         "Barbell Rows", "Hip Thrusts", "Leg Press"]
    let isolationLifts = ["Lateral Raises", "Tricep Pushdowns", "Barbell Curls",
                          "Hammer Curls", "Dumbbell Curls", "Calf Raises", "Face Pulls",
                          "Leg Curls"]
    if compoundLifts.contains(exerciseName) { return 120 }
    if isolationLifts.contains(exerciseName) { return 60 }
    return 90 // accessory default
}

// MARK: - TVStepperControl

struct TVStepperControl: View {
    let label: String
    @Binding var value: Double
    let step: Double
    let range: ClosedRange<Double>
    let format: (Double) -> String

    var body: some View {
        HStack(spacing: TVLayout.spacingLarge) {
            Button {
                let newValue = max(value - step, range.lowerBound)
                value = newValue
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: TVTypography.Size.stat * 0.45, weight: .bold, design: .rounded))
                    .foregroundStyle(offWhite)
                    .frame(width: 56, height: 56)
                    .background(Color(white: 0.22))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
            }
            .buttonStyle(.plain)

            VStack(spacing: 4) {
                Text(format(value))
                    .font(.system(size: TVTypography.Size.stat, weight: .bold, design: .rounded))
                    .foregroundStyle(GQGradients.primary)
                    .monospacedDigit()
                Text(label)
                    .font(.system(size: TVTypography.Size.caption, weight: .medium, design: .rounded))
                    .foregroundStyle(offWhite.opacity(0.6))
            }
            .frame(minWidth: 120)

            Button {
                let newValue = min(value + step, range.upperBound)
                value = newValue
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: TVTypography.Size.stat * 0.45, weight: .bold, design: .rounded))
                    .foregroundStyle(offWhite)
                    .frame(width: 56, height: 56)
                    .background(Color(white: 0.22))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Rest Timer Overlay

private struct RestTimerOverlay: View {
    let totalSeconds: Int
    let remainingSeconds: Int
    var onSkip: () -> Void = {}

    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(remainingSeconds) / Double(totalSeconds)
    }

    private var timerColor: Color {
        if progress > 0.5 { return .green }
        if progress > 0.2 { return Color(red: 0.75, green: 0.65, blue: 0.45) }
        return .red
    }

    private var timeString: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    var body: some View {
        VStack(spacing: TVLayout.spacingMedium) {
            Text("REST")
                .font(.system(size: TVTypography.Size.caption, weight: .bold, design: .rounded))
                .foregroundStyle(offWhite.opacity(0.6))
                .tracking(2)

            ZStack {
                Circle()
                    .stroke(.white.opacity(0.1), lineWidth: 8)
                    .frame(width: 200, height: 200)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [GQColors.deepBlue, GQColors.vividPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                Text(timeString)
                    .font(.system(size: TVTypography.Size.hero, weight: .bold, design: .rounded))
                    .foregroundStyle(offWhite)
                    .monospacedDigit()
            }

            Button {
                onSkip()
            } label: {
                Text("Skip Rest")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 16)
                    .background(Color(white: 0.25))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)

            Text("Press select to skip")
                .font(.system(size: 20, design: .rounded))
                .foregroundStyle(offWhite.opacity(0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.08).opacity(0.95))
    }
}

// MARK: - PR Banner

private struct PRBannerView: View {
    let exerciseName: String
    let weight: Double
    let reps: Int

    var body: some View {
        HStack(spacing: TVLayout.spacingMedium) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 32))
                .foregroundStyle(Color(red: 0.75, green: 0.65, blue: 0.45))

            VStack(alignment: .leading, spacing: 4) {
                Text("NEW PERSONAL RECORD!")
                    .font(.system(size: TVTypography.Size.body, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.75, green: 0.65, blue: 0.45))
                Text("\(exerciseName): \(Int(weight)) lbs x \(reps)")
                    .font(.system(size: TVTypography.Size.caption, weight: .semibold, design: .rounded))
                    .foregroundStyle(offWhite)
            }

            Spacer()

            Image(systemName: "trophy.fill")
                .font(.system(size: 32))
                .foregroundStyle(Color(red: 0.75, green: 0.65, blue: 0.45))
        }
        .padding(.horizontal, TVLayout.spacingLarge)
        .padding(.vertical, TVLayout.spacingMedium)
        .background(Color(white: 0.22))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color(red: 0.75, green: 0.65, blue: 0.45).opacity(0.4), radius: 12, y: 4)
    }
}

// MARK: - Exercise List Panel

private struct ExerciseListPanel: View {
    let exercises: [ActiveExercise]
    let currentIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: TVLayout.spacingSmall) {
            Text("EXERCISES")
                .font(.system(size: TVTypography.Size.caption, weight: .bold, design: .rounded))
                .foregroundStyle(offWhite.opacity(0.5))
                .tracking(2)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                        exerciseRow(exercise: exercise, index: index)
                    }
                }
            }
        }
        .padding(TVLayout.spacingMedium)
        .background(Color(white: 0.16))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private func exerciseRow(exercise: ActiveExercise, index: Int) -> some View {
        let isCompleted = index < currentIndex
        let isCurrent = index == currentIndex
        let completedSets = exercise.sets.filter(\.isCompleted).count
        let totalSets = exercise.sets.count

        HStack(spacing: 12) {
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 22))
            } else if isCurrent {
                Image(systemName: "play.circle.fill")
                    .foregroundStyle(GQColors.primary)
                    .font(.system(size: 22))
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(offWhite.opacity(0.3))
                    .font(.system(size: 22))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.system(size: TVTypography.Size.caption, weight: isCurrent ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isCompleted ? offWhite.opacity(0.4) : offWhite)

                Text("\(completedSets)/\(totalSets) sets")
                    .font(.system(size: 20, weight: .regular, design: .rounded))
                    .foregroundStyle(offWhite.opacity(0.4))
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isCurrent ? GQColors.primary.opacity(0.15) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Workout Selection Grid

private struct WorkoutSelectionGrid: View {
    let onSelect: (WorkoutType) -> Void

    private let selectableTypes: [WorkoutType] = [
        .push, .pull, .legs, .upper, .lower, .fullBody, .cardio, .custom
    ]

    private let columns = [
        GridItem(.flexible(), spacing: TVLayout.cardSpacing),
        GridItem(.flexible(), spacing: TVLayout.cardSpacing),
        GridItem(.flexible(), spacing: TVLayout.cardSpacing),
        GridItem(.flexible(), spacing: TVLayout.cardSpacing),
    ]

    var body: some View {
        VStack(spacing: TVLayout.spacingLarge * 2) {
            VStack(spacing: TVLayout.spacingSmall) {
                Text("Choose Your Workout")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(offWhite)

                Text("Select a split to start your guided session")
                    .font(.system(size: 29, design: .rounded))
                    .foregroundStyle(offWhite.opacity(0.5))
            }

            LazyVGrid(columns: columns, spacing: TVLayout.cardSpacing) {
                ForEach(selectableTypes, id: \.self) { type in
                    workoutTypeButton(type)
                }
            }
            .padding(.horizontal, TVLayout.edgeInsets)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.11))
    }

    @ViewBuilder
    private func workoutTypeButton(_ type: WorkoutType) -> some View {
        Button {
            onSelect(type)
        } label: {
            VStack(spacing: 0) {
                // Gradient header area with icon
                ZStack {
                    GQGradients.primary
                        .opacity(0.25)

                    Image(systemName: type.icon)
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(GQGradients.primary)
                }
                .frame(height: 110)

                // Name + info below
                VStack(spacing: 6) {
                    Text(type.rawValue.uppercased())
                        .font(.system(size: TVTypography.Size.body, weight: .bold, design: .rounded))
                        .foregroundStyle(offWhite)

                    if let templates = workoutTemplates[type] {
                        Text("\(templates.count) exercises")
                            .font(.system(size: 20, design: .rounded))
                            .foregroundStyle(offWhite.opacity(0.5))
                    }
                }
                .padding(.vertical, 14)
            }
            .frame(maxWidth: .infinity)
            .background(Color(white: 0.16))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.4), radius: 10, y: 5)
        }
        .buttonStyle(TVCardButtonStyle(cornerRadius: 20))
        .hoverEffect(.lift)
    }
}

// MARK: - Active Workout View

private struct ActiveWorkoutContent: View {
    @Environment(\.modelContext) private var modelContext
    let workoutType: WorkoutType
    @Binding var exercises: [ActiveExercise]
    let startTime: Date
    let onFinish: () -> Void

    @State private var currentExerciseIndex: Int = 0
    @State private var currentSetIndex: Int = 0
    @State private var elapsedSeconds: Int = 0
    @State private var isResting: Bool = false
    @State private var restTotalSeconds: Int = 90
    @State private var restRemainingSeconds: Int = 90
    @State private var showExitConfirmation: Bool = false
    @State private var prBanner: (name: String, weight: Double, reps: Int)? = nil
    @State private var prBannerTimer: Timer? = nil
    @State private var timerCancellable: AnyCancellable? = nil
    @State private var restTimerCancellable: AnyCancellable? = nil

    // Stepper bindings need local state because ActiveSet uses Double for weight
    @State private var currentWeight: Double = 0
    @State private var currentReps: Double = 0

    private var totalVolume: Double {
        exercises.flatMap(\.sets).filter(\.isCompleted).reduce(0) { $0 + $1.volume }
    }

    private var completedSetsCount: Int {
        exercises.flatMap(\.sets).filter(\.isCompleted).count
    }

    private var totalSetsCount: Int {
        exercises.flatMap(\.sets).count
    }

    private var elapsedString: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private var currentExercise: ActiveExercise? {
        guard currentExerciseIndex < exercises.count else { return nil }
        return exercises[currentExerciseIndex]
    }

    private var currentSet: ActiveSet? {
        guard let exercise = currentExercise,
              currentSetIndex < exercise.sets.count else { return nil }
        return exercise.sets[currentSetIndex]
    }

    private var upNextExercises: [ActiveExercise] {
        guard currentExerciseIndex + 1 < exercises.count else { return [] }
        return Array(exercises[(currentExerciseIndex + 1)...].prefix(2))
    }

    var body: some View {
        ZStack {
            Color(white: 0.11).ignoresSafeArea()

            if let exercise = currentExercise {
                activeLayout(exercise: exercise)
            } else {
                workoutCompletePrompt
            }

            if let pr = prBanner {
                VStack {
                    PRBannerView(exerciseName: pr.name, weight: pr.weight, reps: pr.reps)
                        .padding(.horizontal, 80)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
                .animation(.spring(response: 0.4), value: prBanner != nil)
            }

            if isResting {
                RestTimerOverlay(
                    totalSeconds: restTotalSeconds,
                    remainingSeconds: restRemainingSeconds,
                    onSkip: { endRest() }
                )
                .transition(.opacity)
            }
        }
        .onPlayPauseCommand { completeCurrentSet() }
        .onExitCommand { showExitConfirmation = true }
        .confirmationDialog("End Workout?", isPresented: $showExitConfirmation) {
            Button("Finish & Save", role: .destructive) { finishWorkout() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Save your progress and end the workout?")
        }
        .onAppear { startElapsedTimer(); syncStepperValues() }
        .onDisappear { stopAllTimers() }
        .onChange(of: currentExerciseIndex) { _, _ in syncStepperValues() }
        .onChange(of: currentSetIndex) { _, _ in syncStepperValues() }
    }

    // MARK: - Active Layout (two-panel card design)

    @ViewBuilder
    private func activeLayout(exercise: ActiveExercise) -> some View {
        VStack(spacing: 0) {
            // Top bar — workout name + timer + stats
            HStack(alignment: .center) {
                Text(workoutType.rawValue)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(offWhite)

                Spacer()

                // Live stats
                HStack(spacing: 32) {
                    statPill(value: elapsedString, label: "TIME", icon: "clock")
                    statPill(value: formatVolume(totalVolume), label: "VOLUME", icon: "scalemass")
                    statPill(value: "\(completedSetsCount)/\(totalSetsCount)", label: "SETS", icon: "checkmark.circle")
                }
            }
            .padding(.horizontal, 80)
            .padding(.top, 40)
            .padding(.bottom, 24)

            // Two-panel main area
            HStack(alignment: .top, spacing: TVLayout.cardSpacing) {
                // LEFT — Current exercise card
                VStack(spacing: 20) {
                    // Exercise header with GIF
                    HStack(spacing: 24) {
                        ExerciseGifView(exerciseName: exercise.name, size: .medium)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(exercise.name)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(offWhite)
                                .lineLimit(1)

                            Text("Set \(currentSetIndex + 1) of \(exercise.sets.count)")
                                .font(.system(size: 24, weight: .medium, design: .rounded))
                                .foregroundStyle(offWhite.opacity(0.5))
                        }

                        Spacer()

                        // Add/remove set buttons
                        HStack(spacing: 12) {
                            Button {
                                removeSet()
                            } label: {
                                Image(systemName: "minus")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(offWhite.opacity(0.6))
                                    .frame(width: 44, height: 44)
                                    .background(Color(white: 0.22))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)

                            Text("\(exercise.sets.count)")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(offWhite.opacity(0.5))

                            Button {
                                addSet()
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(offWhite.opacity(0.6))
                                    .frame(width: 44, height: 44)
                                    .background(Color(white: 0.22))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Weight + Reps steppers
                    HStack(spacing: 80) {
                        TVStepperControl(
                            label: "lbs",
                            value: $currentWeight,
                            step: 5,
                            range: 0...999,
                            format: { "\(Int($0))" }
                        )

                        TVStepperControl(
                            label: "reps",
                            value: $currentReps,
                            step: 1,
                            range: 1...100,
                            format: { "\(Int($0))" }
                        )
                    }

                    // Complete button
                    Button {
                        completeCurrentSet()
                    } label: {
                        Text("COMPLETE SET")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .tracking(2)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .background(GQGradients.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                    .buttonStyle(CompleteSetButtonStyle())
                }
                .padding(36)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(white: 0.16))
                .clipShape(RoundedRectangle(cornerRadius: 24))

                // RIGHT — Exercise list + add exercise
                VStack(alignment: .leading, spacing: 16) {
                    Text("Exercises")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(offWhite)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(exercises.enumerated()), id: \.element.id) { index, ex in
                                exerciseRow(exercise: ex, index: index)
                            }
                        }
                    }

                    // Add exercise button
                    Button {
                        addExercise()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                            Text("Add Exercise")
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(GQGradients.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(white: 0.22))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
                .padding(24)
                .frame(width: 380)
                .frame(maxHeight: .infinity)
                .background(Color(white: 0.16))
                .clipShape(RoundedRectangle(cornerRadius: 24))
            }
            .padding(.horizontal, 80)
            .padding(.bottom, 40)
        }
    }

    @ViewBuilder
    private func statPill(value: String, label: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(offWhite.opacity(0.4))
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(offWhite)
                    .monospacedDigit()
                Text(label)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(offWhite.opacity(0.3))
                    .tracking(1)
            }
        }
    }

    @ViewBuilder
    private func exerciseRow(exercise: ActiveExercise, index: Int) -> some View {
        let isCompleted = index < currentExerciseIndex
        let isCurrent = index == currentExerciseIndex
        let completedSets = exercise.sets.filter(\.isCompleted).count
        let totalSets = exercise.sets.count

        HStack(spacing: 14) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : (isCurrent ? "play.circle.fill" : "circle"))
                .font(.system(size: 22))
                .foregroundStyle(isCompleted ? .green : (isCurrent ? GQColors.deepBlue : offWhite.opacity(0.2)))

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.system(size: 22, weight: isCurrent ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isCompleted ? offWhite.opacity(0.35) : offWhite)
                Text("\(completedSets)/\(totalSets) sets")
                    .font(.system(size: 18, weight: .regular, design: .rounded))
                    .foregroundStyle(offWhite.opacity(0.3))
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isCurrent ? Color(white: 0.22) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var workoutCompletePrompt: some View {
        VStack(spacing: 32) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundStyle(GQGradients.primary)

            Text("Workout Complete")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(offWhite)

            HStack(spacing: 48) {
                statPill(value: elapsedString, label: "DURATION", icon: "clock")
                statPill(value: formatVolume(totalVolume), label: "VOLUME", icon: "scalemass")
                statPill(value: "\(completedSetsCount)", label: "SETS", icon: "checkmark.circle")
            }

            Button {
                finishWorkout()
            } label: {
                Text("Save Workout")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 60)
                    .padding(.vertical, 20)
                    .background(GQGradients.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: GQColors.deepBlue.opacity(0.5), radius: 16, y: 8)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Stats helpers

    private var restProgress: Double {
        guard restTotalSeconds > 0 else { return 0 }
        return Double(restRemainingSeconds) / Double(restTotalSeconds)
    }

    private var restTimerColor: Color {
        if restProgress > 0.5 { return .green }
        if restProgress > 0.2 { return Color(red: 0.75, green: 0.65, blue: 0.45) }
        return .red
    }

    // MARK: - Timer Logic

    private func startElapsedTimer() {
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                elapsedSeconds += 1
            }
    }

    private func startRestTimer() {
        guard let exercise = currentExercise else { return }
        restTotalSeconds = defaultRestSeconds(for: exercise.name)
        restRemainingSeconds = restTotalSeconds
        isResting = true

        restTimerCancellable?.cancel()
        restTimerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if restRemainingSeconds > 0 {
                    restRemainingSeconds -= 1
                } else {
                    endRest()
                }
            }
    }

    private func endRest() {
        isResting = false
        restTimerCancellable?.cancel()
        restTimerCancellable = nil
    }

    private func stopAllTimers() {
        timerCancellable?.cancel()
        timerCancellable = nil
        restTimerCancellable?.cancel()
        restTimerCancellable = nil
        prBannerTimer?.invalidate()
        prBannerTimer = nil
    }

    // MARK: - Set Completion

    private func completeCurrentSet() {
        guard currentExerciseIndex < exercises.count else { return }
        guard currentSetIndex < exercises[currentExerciseIndex].sets.count else { return }
        if isResting { endRest(); return }

        // Write stepper values back to the active set
        exercises[currentExerciseIndex].sets[currentSetIndex].weight = currentWeight
        exercises[currentExerciseIndex].sets[currentSetIndex].reps = Int(currentReps)
        exercises[currentExerciseIndex].sets[currentSetIndex].isCompleted = true

        let completedWeight = currentWeight
        let completedReps = Int(currentReps)
        let exerciseName = exercises[currentExerciseIndex].name

        // PR detection: simple check against other completed sets of the same exercise
        checkForPR(exerciseName: exerciseName, weight: completedWeight, reps: completedReps)

        // Advance to next set or next exercise
        if currentSetIndex + 1 < exercises[currentExerciseIndex].sets.count {
            currentSetIndex += 1
            syncStepperValues()
            startRestTimer()
        } else if currentExerciseIndex + 1 < exercises.count {
            currentExerciseIndex += 1
            currentSetIndex = 0
            syncStepperValues()
            startRestTimer()
        } else {
            // All exercises done
            currentExerciseIndex = exercises.count
        }
    }

    // MARK: - Add/Remove Sets & Exercises

    private func addSet() {
        guard currentExerciseIndex < exercises.count else { return }
        let lastSet = exercises[currentExerciseIndex].sets.last
        let newSet = ActiveSet(
            reps: lastSet?.reps ?? 10,
            weight: lastSet?.weight ?? 0
        )
        exercises[currentExerciseIndex].sets.append(newSet)
    }

    private func removeSet() {
        guard currentExerciseIndex < exercises.count else { return }
        guard exercises[currentExerciseIndex].sets.count > 1 else { return }
        // Only remove uncompleted sets from the end
        if let lastSet = exercises[currentExerciseIndex].sets.last, !lastSet.isCompleted {
            exercises[currentExerciseIndex].sets.removeLast()
            // If we were on the removed set, clamp the index
            if currentSetIndex >= exercises[currentExerciseIndex].sets.count {
                currentSetIndex = exercises[currentExerciseIndex].sets.count - 1
                syncStepperValues()
            }
        }
    }

    private func addExercise() {
        // Add a generic custom exercise at the end
        let newExercise = ActiveExercise(
            name: "Custom Exercise",
            muscleGroup: .fullBody,
            sets: [
                ActiveSet(reps: 10, weight: 0),
                ActiveSet(reps: 10, weight: 0),
                ActiveSet(reps: 10, weight: 0)
            ]
        )
        exercises.append(newExercise)
    }

    private func syncStepperValues() {
        guard let set = currentSet else { return }
        currentWeight = set.weight
        currentReps = Double(set.reps)
    }

    // MARK: - PR Detection

    private func checkForPR(exerciseName: String, weight: Double, reps: Int) {
        // Compare against all other completed sets of the same exercise in this workout
        let previousBestVolume = exercises
            .filter { $0.name == exerciseName }
            .flatMap(\.sets)
            .filter { $0.isCompleted && $0.id != exercises[currentExerciseIndex].sets[currentSetIndex].id }
            .map(\.volume)
            .max() ?? 0

        let currentVolume = weight * Double(reps)

        // Only trigger PR if this is a meaningful set and beats previous
        if currentVolume > previousBestVolume && weight > 0 && reps > 0 && previousBestVolume > 0 {
            showPRBanner(exerciseName: exerciseName, weight: weight, reps: reps)
        }
    }

    private func showPRBanner(exerciseName: String, weight: Double, reps: Int) {
        withAnimation {
            prBanner = (name: exerciseName, weight: weight, reps: reps)
        }
        prBannerTimer?.invalidate()
        prBannerTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
            Task { @MainActor in
                withAnimation { prBanner = nil }
            }
        }
    }

    // MARK: - Save & Finish

    private func finishWorkout() {
        let durationMinutes = max(1, elapsedSeconds / 60)

        let workout = Workout(
            date: startTime,
            type: workoutType,
            duration: durationMinutes,
            rpe: 7,
            notes: "Completed via Apple TV",
            exercises: [],
            source: .manual,
            privacy: .friends
        )

        for (exerciseIndex, activeExercise) in exercises.enumerated() {
            let completedSets = activeExercise.sets.filter(\.isCompleted)
            guard !completedSets.isEmpty else { continue }

            let exercise = Exercise(
                name: activeExercise.name,
                muscleGroup: activeExercise.muscleGroup,
                order: exerciseIndex,
                sets: []
            )

            for (setIndex, activeSet) in completedSets.enumerated() {
                let exerciseSet = ExerciseSet(
                    reps: activeSet.reps,
                    weight: activeSet.weight,
                    rpe: activeSet.rpe,
                    order: setIndex
                )
                exerciseSet.exercise = exercise
                exercise.sets.append(exerciseSet)
            }

            exercise.workout = workout
            workout.exercises.append(exercise)
        }

        modelContext.insert(workout)
        try? modelContext.save()

        onFinish()
    }

    // MARK: - Helpers

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk lbs", volume / 1000)
        }
        return "\(Int(volume)) lbs"
    }
}

// MARK: - TVWorkoutView (Root)

struct TVWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedWorkoutType: WorkoutType? = nil
    @State private var exercises: [ActiveExercise] = []
    @State private var workoutStartTime: Date = Date()
    @State private var isWorkoutActive: Bool = false

    var body: some View {
        Group {
            if isWorkoutActive, let type = selectedWorkoutType {
                ActiveWorkoutContent(
                    workoutType: type,
                    exercises: $exercises,
                    startTime: workoutStartTime,
                    onFinish: { resetToSelection() }
                )
                .transition(.move(edge: .trailing))
            } else {
                WorkoutSelectionGrid(onSelect: { type in
                    startWorkout(type: type)
                })
                .transition(.move(edge: .leading))
            }
        }
        .animation(.easeInOut(duration: 0.4), value: isWorkoutActive)
    }

    private func startWorkout(type: WorkoutType) {
        selectedWorkoutType = type
        workoutStartTime = Date()

        guard let templates = workoutTemplates[type] else {
            exercises = []
            isWorkoutActive = true
            return
        }

        exercises = templates.map { template in
            ActiveExercise(
                name: template.name,
                muscleGroup: template.muscleGroup,
                sets: (0..<template.sets).map { _ in
                    ActiveSet(
                        reps: template.reps,
                        weight: template.weight
                    )
                }
            )
        }

        isWorkoutActive = true
    }

    private func resetToSelection() {
        isWorkoutActive = false
        selectedWorkoutType = nil
        exercises = []
    }
}

// MARK: - Complete Set Button Style

private struct CompleteSetButtonStyle: ButtonStyle {
    @Environment(\.isFocused) var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : (isFocused ? 1.04 : 1.0))
            .shadow(
                color: isFocused ? GQColors.deepBlue.opacity(0.6) : .clear,
                radius: isFocused ? 24 : 0,
                y: isFocused ? 12 : 0
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    TVWorkoutView()
}
#endif
