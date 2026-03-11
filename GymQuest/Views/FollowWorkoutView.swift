//
//  FollowWorkoutView.swift
//  GymQuest
//
//  Interactive workout following view.
//  When someone posts a workout, others can "Follow" it step-by-step.
//  Includes rest timers, exercise progression, and visual guides.
//

import SwiftUI
import SwiftData

// MARK: - Workout Detail Sheet (Preview mode)

struct WorkoutDetailSheet: View {
    let workoutData: SharedWorkoutData
    let onFollow: () -> Void
    var onAddExercise: ((SharedWorkoutData.SharedExercise) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @State private var savedAsTemplate = false

    private var totalVolume: Int {
        Int(workoutData.exercises.reduce(0.0) { total, ex in
            total + ex.sets.reduce(0.0) { $0 + Double($1.reps) * $1.weight }
        })
    }

    private var totalSets: Int {
        workoutData.exercises.reduce(0) { $0 + $1.sets.count }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    statsSection
                    exercisesSection
                    actionsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(GQColors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(GQColors.textTertiary)
                    }
                }
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 14) {
            // Profile picture
            Circle()
                .fill(GQGradients.primary)
                .frame(width: 56, height: 56)
                .overlay(
                    Text(String(workoutData.authorName.prefix(1)).uppercased())
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                )

            VStack(spacing: 4) {
                Text(workoutData.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(GQColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(workoutData.authorName + "  ·  @" + workoutData.authorUsername)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(GQColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    // MARK: - Stats

    @ViewBuilder
    private var statsSection: some View {
        HStack(spacing: 0) {
            workoutStat(value: "\(workoutData.exercises.count)", label: "Exercises", icon: "dumbbell.fill")
            workoutStat(value: "\(totalSets)", label: "Sets", icon: "repeat")
            workoutStat(value: "\(workoutData.estimatedDuration)", label: "Minutes", icon: "clock.fill")
            if totalVolume > 0 {
                workoutStat(value: formatVolume(totalVolume), label: "Volume", icon: "scalemass.fill")
            }
        }
        .padding(.vertical, 16)
        .background(GQColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(GQColors.borderDefault, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }

    // MARK: - Exercises

    @ViewBuilder
    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("EXERCISES")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(GQColors.textTertiary)
                .tracking(0.5)
                .padding(.leading, 4)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach(Array(workoutData.exercises.enumerated()), id: \.element.id) { index, exercise in
                    ExercisePreviewCard(
                        index: index + 1,
                        exercise: exercise,
                        isLast: index == workoutData.exercises.count - 1,
                        onAddExercise: onAddExercise
                    )
                }
            }
            .background(GQColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(GQColors.borderDefault, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button {
                startWorkoutDirectly()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14))
                    Text("Start Workout")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(GQGradients.primary)
                )
            }
            .buttonStyle(WorkoutDetailButtonStyle())

            Button {
                saveAsTemplate()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: savedAsTemplate ? "checkmark.circle.fill" : "square.and.arrow.down")
                        .font(.system(size: 14))
                    Text(savedAsTemplate ? "Saved to Workouts" : "Save to My Workouts")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .foregroundColor(savedAsTemplate ? GQColors.success : GQColors.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(GQColors.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(GQColors.borderDefault, lineWidth: 1)
                )
            }
            .buttonStyle(WorkoutDetailButtonStyle())
            .disabled(savedAsTemplate)
        }
    }

    // MARK: - Helpers

    private func workoutStat(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(GQColors.textTertiary)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(GQColors.textPrimary)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatVolume(_ vol: Int) -> String {
        if vol >= 1000 {
            return String(format: "%.1fk", Double(vol) / 1000.0)
        }
        return "\(vol)"
    }

    private func startWorkoutDirectly() {
        let exercises = workoutData.toActiveExercises()
        let workoutType = WorkoutType(rawValue: workoutData.workoutType) ?? .push
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            appState.startWorkout(type: workoutType, exercises: exercises, customTitle: workoutData.title)
        }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    private func saveAsTemplate() {
        let exercises = workoutData.exercises.enumerated().map { index, ex in
            TemplateExercise(
                name: ex.name,
                muscleGroup: ex.muscleGroup,
                suggestedSets: ex.sets.count,
                suggestedReps: "\(ex.sets.first?.reps ?? 10)",
                suggestedWeight: ex.sets.first?.weight,
                order: index
            )
        }
        let wt = WorkoutType(rawValue: workoutData.workoutType) ?? .custom
        let template = WorkoutTemplate(
            name: workoutData.title,
            workoutType: wt,
            exercises: exercises
        )
        modelContext.insert(template)
        withAnimation(.spring(response: 0.3)) {
            savedAsTemplate = true
        }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }
}

// MARK: - Button Style

private struct WorkoutDetailButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

// MARK: - Exercise Preview Card

struct ExercisePreviewCard: View {
    let index: Int
    let exercise: SharedWorkoutData.SharedExercise
    var isLast: Bool = false
    var onAddExercise: ((SharedWorkoutData.SharedExercise) -> Void)? = nil

    @State private var isExpanded = false
    @State private var showAddedCheck = false

    private var topWeight: Double {
        exercise.sets.map(\.weight).max() ?? 0
    }

    private var bestSetSummary: String {
        let sets = exercise.sets
        if topWeight > 0 {
            return "\(sets.count) sets · \(Int(topWeight)) lbs"
        }
        let topReps = sets.map(\.reps).max() ?? 0
        return "\(sets.count) sets · \(topReps) reps"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                exerciseRow
            }
            .buttonStyle(.plain)

            // Expanded sets
            if isExpanded {
                expandedSets
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if !isLast {
                Divider()
                    .padding(.leading, FeatureFlags.shared.exerciseGifsEnabled ? 68 : 52)
            }
        }
        .padding(.horizontal, 14)
    }

    @ViewBuilder
    private var exerciseRow: some View {
        HStack(spacing: 12) {
            // GIF thumbnail or index number
            if FeatureFlags.shared.exerciseGifsEnabled {
                ExerciseGifView(exerciseName: exercise.name, size: .detail, showFallback: true)
            } else {
                Text("\(index)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(GQColors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(GQColors.adaptiveOverlay(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(GQColors.textPrimary)
                    .lineLimit(1)

                Text(bestSetSummary)
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textTertiary)
            }

            Spacer(minLength: 8)

            if onAddExercise != nil {
                addButton
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(GQColors.textTertiary.opacity(0.6))
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
        }
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var addButton: some View {
        Button {
            onAddExercise?(exercise)
            withAnimation(.spring(response: 0.3)) {
                showAddedCheck = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation { showAddedCheck = false }
            }
        } label: {
            Image(systemName: showAddedCheck ? "checkmark" : "plus")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(showAddedCheck ? GQColors.success : GQColors.textTertiary)
                .frame(width: 26, height: 26)
                .background(GQColors.adaptiveOverlay(0.04))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(showAddedCheck)
    }

    @ViewBuilder
    private var expandedSets: some View {
        let leadingPad: CGFloat = FeatureFlags.shared.exerciseGifsEnabled ? 56 : 48

        VStack(spacing: 0) {
            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { setIndex, set in
                HStack(spacing: 0) {
                    Text("\(setIndex + 1)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(GQColors.textTertiary)
                        .frame(width: 24, alignment: .center)

                    if set.weight > 0 {
                        Text("\(set.reps) reps")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(GQColors.textPrimary)
                        Text(" × ")
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textTertiary)
                        Text("\(Int(set.weight)) lbs")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(GQColors.textPrimary)
                    } else {
                        Text("\(set.reps) reps")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(GQColors.textPrimary)
                    }

                    Spacer()

                    if set.restSeconds > 0 {
                        Label("\(set.restSeconds)s", systemImage: "timer")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(GQColors.textTertiary)
                    }
                }
                .padding(.vertical, 8)

                if setIndex < exercise.sets.count - 1 {
                    Divider()
                        .opacity(0.5)
                }
            }
        }
        .padding(.leading, leadingPad)
        .padding(.bottom, 8)
    }
}

// MARK: - Active Workout Following View

struct FollowWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let workoutData: SharedWorkoutData
    let profile: UserProfile

    @State private var currentExerciseIndex = 0
    @State private var currentSetIndex = 0
    @State private var isResting = false
    @State private var restTimeRemaining = 0
    @State private var restDuration = 0
    @State private var workoutStartTime = Date()
    @State private var completedSets: Set<String> = []
    @State private var showingCompletionSheet = false
    @State private var timer: Timer?

    var currentExercise: SharedWorkoutData.SharedExercise? {
        guard currentExerciseIndex < workoutData.exercises.count else { return nil }
        return workoutData.exercises[currentExerciseIndex]
    }

    var currentSet: SharedWorkoutData.SharedExercise.SharedSet? {
        guard let exercise = currentExercise,
              currentSetIndex < exercise.sets.count else { return nil }
        return exercise.sets[currentSetIndex]
    }

    var progressPercentage: Double {
        let totalSets = workoutData.exercises.reduce(0) { $0 + $1.sets.count }
        guard totalSets > 0 else { return 0 }
        return Double(completedSets.count) / Double(totalSets)
    }

    var body: some View {
        ZStack {
            Color.clear

            VStack(spacing: 0) {
                WorkoutProgressHeader(
                    workoutTitle: workoutData.title,
                    progress: progressPercentage,
                    elapsedTime: elapsedTimeString,
                    onClose: { dismiss() }
                )

                if isResting {
                    RestTimerView(
                        timeRemaining: restTimeRemaining,
                        totalSeconds: restDuration,
                        nextExercise: getNextExerciseName(),
                        onSkip: { skipRest() }
                    )
                } else if let exercise = currentExercise, let set = currentSet {
                    ActiveSetView(
                        exercise: exercise,
                        setNumber: currentSetIndex + 1,
                        totalSets: exercise.sets.count,
                        targetReps: set.reps,
                        targetWeight: set.weight,
                        onComplete: { completeSet() }
                    )
                } else {
                    WorkoutCompleteView(
                        onFinish: { finishWorkout() }
                    )
                }

                Spacer()

                ExerciseOverviewBar(
                    exercises: workoutData.exercises,
                    currentIndex: currentExerciseIndex,
                    completedSets: completedSets
                )
            }
        }
        .gqPageBackground()
        .onAppear {
            workoutStartTime = Date()
        }
        .onDisappear {
            timer?.invalidate()
        }
        .sheet(isPresented: $showingCompletionSheet) {
            WorkoutCompletionSummary(
                workoutData: workoutData,
                duration: Int(Date().timeIntervalSince(workoutStartTime) / 60),
                profile: profile,
                onDismiss: { dismiss() }
            )
        }
    }

    var elapsedTimeString: String {
        let elapsed = Int(Date().timeIntervalSince(workoutStartTime))
        let mins = elapsed / 60
        let secs = elapsed % 60
        return String(format: "%d:%02d", mins, secs)
    }

    func completeSet() {
        guard let exercise = currentExercise, let set = currentSet else { return }

        // Mark set as complete
        let setKey = "\(exercise.id)-\(currentSetIndex)"
        completedSets.insert(setKey)

        // Check if more sets in this exercise
        if currentSetIndex + 1 < exercise.sets.count {
            // Start rest timer, then move to next set
            startRestTimer(seconds: set.restSeconds)
            currentSetIndex += 1
        } else if currentExerciseIndex + 1 < workoutData.exercises.count {
            // Move to next exercise
            startRestTimer(seconds: set.restSeconds)
            currentExerciseIndex += 1
            currentSetIndex = 0
        } else {
            // Workout complete
            showingCompletionSheet = true
        }
    }

    func startRestTimer(seconds: Int) {
        isResting = true
        restTimeRemaining = seconds
        restDuration = seconds

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if restTimeRemaining > 0 {
                restTimeRemaining -= 1
            } else {
                timer?.invalidate()
                isResting = false
            }
        }
    }

    func skipRest() {
        timer?.invalidate()
        isResting = false
    }

    func getNextExerciseName() -> String {
        if let exercise = currentExercise {
            if currentSetIndex < exercise.sets.count {
                return "\(exercise.name) - Set \(currentSetIndex + 1)"
            }
        }
        if currentExerciseIndex + 1 < workoutData.exercises.count {
            return workoutData.exercises[currentExerciseIndex + 1].name
        }
        return "Done!"
    }

    func finishWorkout() {
        showingCompletionSheet = true
    }
}

// MARK: - Progress Header

struct WorkoutProgressHeader: View {
    let workoutTitle: String
    let progress: Double
    let elapsedTime: String
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                        .frame(width: 32, height: 32)
                        .background(GQColors.adaptiveOverlay(0.05))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Text(workoutTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text(elapsedTime)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .homeSocialCard(accent: GQColors.deepBlue, emphasized: true, cornerRadius: 10)
            }

            AnimatedProgressBar(
                progress: progress,
                height: 7,
                colors: [GQColors.deepBlue]
            )
            .frame(height: 7)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(GQColors.surfaceOverlay.opacity(0.86))
    }
}

// MARK: - Rest Timer View

struct RestTimerView: View {
    let timeRemaining: Int
    let totalSeconds: Int
    let nextExercise: String
    let onSkip: () -> Void

    private var progress: CGFloat {
        guard totalSeconds > 0 else { return 0 }
        return CGFloat(timeRemaining) / CGFloat(totalSeconds)
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Rest")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(GQColors.textSecondary)

            ZStack {
                Circle()
                    .stroke(GQColors.adaptiveOverlay(0.06), lineWidth: 12)
                    .frame(width: 196, height: 196)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [GQColors.deepBlue, GQColors.textSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 196, height: 196)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text("\(timeRemaining)")
                        .font(.system(size: 66, weight: .bold, design: .rounded))
                        .foregroundColor(GQColors.textPrimary)
                    Text("seconds")
                        .font(.subheadline)
                        .foregroundColor(GQColors.textSecondary)
                }
            }

            VStack(spacing: 8) {
                Text("UP NEXT")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(1)

                Text(nextExercise)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(GQColors.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .padding(14)
            .homeSocialCard(accent: GQColors.textSecondary, cornerRadius: 12)
            .padding(.horizontal, GQLayout.screenHorizontal)

            Button {
                onSkip()
            } label: {
                Text("Skip Rest")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)
            }
            .buttonStyle(HomeSocialSecondaryButtonStyle())
            .padding(.horizontal, 60)

            Spacer()
        }
    }
}

// MARK: - Active Set View

struct ActiveSetView: View {
    let exercise: SharedWorkoutData.SharedExercise
    let setNumber: Int
    let totalSets: Int
    let targetReps: Int
    let targetWeight: Double
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            if FeatureFlags.shared.exerciseGifsEnabled {
                ExerciseGifView(exerciseName: exercise.name, size: .medium, showFallback: false)
            }

            Text(exercise.name)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(GQColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, GQLayout.screenHorizontal)

            Text("SET \(setNumber) of \(totalSets)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(GQColors.deepBlue)
                .tracking(1)

            VStack(spacing: 8) {
                HStack(spacing: 40) {
                    VStack(spacing: 4) {
                        Text("TARGET REPS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(GQColors.textTertiary)
                        Text("\(targetReps)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(GQColors.textPrimary)
                        Text("reps")
                            .font(.caption)
                            .foregroundColor(GQColors.textSecondary)
                    }

                    if targetWeight > 0 {
                        VStack(spacing: 4) {
                            Text("WEIGHT")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(GQColors.textTertiary)
                            Text("\(Int(targetWeight))")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(GQColors.textSecondary)
                            Text("lbs")
                                .font(.caption)
                                .foregroundColor(GQColors.textSecondary)
                        }
                    }
                }
            }
            .padding(24)
            .homeSocialCard(accent: GQColors.deepBlue, emphasized: true, cornerRadius: 20)
            .padding(.horizontal, GQLayout.screenHorizontal)

            if !exercise.demoTips.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(exercise.demoTips.prefix(2), id: \.self) { tip in
                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 12))
                                .foregroundColor(GQColors.textSecondary)
                            Text(tip)
                                .font(.system(size: 13))
                                .foregroundColor(GQColors.textSecondary)
                        }
                    }
                }
                .padding(12)
                .homeSocialCard(accent: GQColors.textSecondary, cornerRadius: 12)
                .padding(.horizontal, GQLayout.screenHorizontal)
            }

            Spacer()

            Button {
                onComplete()
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Complete Set")
                }
            }
            .buttonStyle(HomeSocialPrimaryButtonStyle(accent: GQColors.textSecondary))
            .padding(.horizontal, 32)
            .padding(.bottom, 20)
        }
        .padding()
    }
}

// MARK: - Exercise Overview Bar

struct ExerciseOverviewBar: View {
    let exercises: [SharedWorkoutData.SharedExercise]
    let currentIndex: Int
    let completedSets: Set<String>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                    ExercisePill(
                        name: exercise.name,
                        setsCount: exercise.sets.count,
                        completedCount: countCompletedSets(for: exercise),
                        isCurrent: index == currentIndex,
                        isPast: index < currentIndex
                    )
                }
            }
            .gqScreenHorizontalPadding()
            .padding(.vertical, 12)
        }
        .background(
            Rectangle()
                .fill(Color.white)
                .overlay(
                    Rectangle()
                        .fill(GQColors.adaptiveOverlay(0.06))
                        .frame(height: 1),
                    alignment: .top
                )
        )
    }

    func countCompletedSets(for exercise: SharedWorkoutData.SharedExercise) -> Int {
        var count = 0
        for i in 0..<exercise.sets.count {
            let key = "\(exercise.id)-\(i)"
            if completedSets.contains(key) {
                count += 1
            }
        }
        return count
    }
}

struct ExercisePill: View {
    let name: String
    let setsCount: Int
    let completedCount: Int
    let isCurrent: Bool
    let isPast: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(name)
                .font(.system(size: 12, weight: isCurrent ? .bold : .medium))
                .foregroundColor(isCurrent ? GQColors.textPrimary : (isPast ? GQColors.textSecondary : GQColors.textSecondary))
                .lineLimit(1)

            // Set indicators
            HStack(spacing: 4) {
                ForEach(0..<setsCount, id: \.self) { i in
                    Circle()
                        .fill(i < completedCount ? GQColors.textSecondary : (isCurrent ? GQColors.coral : GQColors.adaptiveOverlay(0.12)))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .homeSocialCard(
            accent: isCurrent ? GQColors.deepBlue : GQColors.textSecondary,
            emphasized: isCurrent,
            cornerRadius: 20
        )
    }
}

// MARK: - Workout Complete Views

struct WorkoutCompleteView: View {
    let onFinish: () -> Void
    @State private var checkScale: CGFloat = 0.85

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 82))
                .foregroundColor(GQColors.textSecondary)
                .scaleEffect(checkScale)

            Text("Workout Complete")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(GQColors.textPrimary)

            Text("Nice work. Ready to review and share it?")
                .font(.system(size: 15))
                .foregroundColor(GQColors.textSecondary)
                .multilineTextAlignment(.center)

            Button("Continue") {
                onFinish()
            }
            .buttonStyle(HomeSocialPrimaryButtonStyle(accent: GQColors.textSecondary))
            .padding(.horizontal, 56)

            Spacer()
        }
        .padding(.horizontal, GQLayout.screenHorizontal)
        .onAppear {
            HapticManager.shared.workoutComplete()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) {
                checkScale = 1.0
            }
        }
    }
}

struct WorkoutCompletionSummary: View {
    let workoutData: SharedWorkoutData
    let duration: Int
    let profile: UserProfile
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var caption = ""
    @State private var showShareOptions = false
    @State private var hasShared = false

    var totalSets: Int {
        workoutData.exercises.reduce(0) { $0 + $1.sets.count }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Success icon
                    ZStack {
                        Circle()
                            .fill(GQColors.textSecondary.opacity(0.2))
                            .frame(width: 100, height: 100)

                        Image(systemName: "trophy.fill")
                            .font(.system(size: 40))
                            .foregroundColor(GQColors.textSecondary)
                    }
                    .padding(.top, 20)

                    Text("Workout Complete!")
                        .font(.title2)
                        .fontWeight(.bold)

                    // Stats
                    HStack(spacing: 30) {
                        WorkoutStatBlock(value: "\(duration)", label: "Minutes")
                        WorkoutStatBlock(value: "\(totalSets)", label: "Sets")
                        WorkoutStatBlock(value: "\(workoutData.exercises.count)", label: "Exercises")
                    }
                    .padding()
                    .homeSocialCard()

                    // Attribution badge
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14))
                        Text("Inspired by @\(workoutData.authorUsername)")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(GQColors.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(GQColors.textSecondary.opacity(0.15))
                    .cornerRadius(20)

                    // Share section
                    VStack(spacing: 16) {
                        Text("SHARE YOUR WORKOUT")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(GQColors.textTertiary)
                            .tracking(1)

                        TextField("Add a caption...", text: $caption, axis: .vertical)
                            .lineLimit(2...4)
                            .padding(12)
                            .homeSocialCard(cornerRadius: 12)

                        Button {
                            shareToFeed()
                        } label: {
                            HStack {
                                Image(systemName: hasShared ? "checkmark.circle.fill" : "square.and.arrow.up")
                                Text(hasShared ? "Shared!" : "Share to Feed")
                            }
                        }
                        .buttonStyle(HomeSocialPrimaryButtonStyle(accent: hasShared ? GQColors.success : GQColors.textSecondary))
                        .disabled(hasShared)

                        // Save for later option
                        Button {
                            saveWorkoutTemplate()
                        } label: {
                            HStack {
                                Image(systemName: "bookmark")
                                Text("Save Workout for Later")
                            }
                        }
                        .buttonStyle(HomeSocialSecondaryButtonStyle(cornerRadius: 12))
                    }
                    .padding()
                    .homeSocialCard()

                    Spacer().frame(height: 20)
                }
                .padding()
            }
            .gqPageBackground()
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                        onDismiss()
                    }
                }
            }
        }
    }

    private func shareToFeed() {
        let post = Post(
            authorId: profile.id,
            authorName: profile.name,
            authorUsername: profile.username,
            caption: caption.isEmpty ? "Just crushed this workout!" : caption,
            workoutType: workoutData.workoutType,
            duration: duration,
            setCount: totalSets,
            sharedWorkoutData: workoutData.encode(),
            inspiredByUsername: workoutData.authorUsername,
            inspiredByWorkoutId: workoutData.id,
            inspiredByName: workoutData.authorName
        )

        modelContext.insert(post)
        try? modelContext.save()

        withAnimation {
            hasShared = true
        }
    }

    private func saveWorkoutTemplate() {
        // Convert to WorkoutTemplate for saving
        let templateExercises = workoutData.exercises.enumerated().map { index, exercise in
            TemplateExercise(
                name: exercise.name,
                muscleGroup: exercise.muscleGroup,
                suggestedSets: exercise.sets.count,
                suggestedReps: "\(exercise.sets.first?.reps ?? 10)",
                suggestedWeight: exercise.sets.first?.weight,
                order: index
            )
        }

        let template = WorkoutTemplate(
            odId: profile.id,
            name: "\(workoutData.title) (from @\(workoutData.authorUsername))",
            workoutType: WorkoutType(rawValue: workoutData.workoutType) ?? .push,
            exercises: templateExercises,
            estimatedDuration: workoutData.estimatedDuration
        )

        modelContext.insert(template)
        try? modelContext.save()
    }
}

struct WorkoutStatBlock: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(GQColors.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundColor(GQColors.textSecondary)
        }
    }
}

// MARK: - Workout Copy Sheet

struct WorkoutCopySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState

    let workoutData: SharedWorkoutData
    let profile: UserProfile

    @State private var showingSaved = false
    @State private var showingExercisePicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Workout preview header
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 16))
                            .foregroundColor(GQColors.textSecondary)
                        Text(workoutData.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(GQColors.textPrimary)
                        Spacer()
                    }

                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                            Text("~\(workoutData.estimatedDuration)m")
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 11))
                            Text("\(workoutData.exercises.count) exercises")
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 11))
                            Text("@\(workoutData.authorUsername)")
                        }
                        Spacer()
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)
                }
                .padding(16)
                .background(GQColors.adaptiveOverlay(0.03))

                // Exercises list
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(workoutData.exercises) { exercise in
                            HStack(spacing: 10) {
                                if FeatureFlags.shared.exerciseGifsEnabled {
                                    ExerciseGifView(exerciseName: exercise.name, size: .thumbnail, showFallback: true)
                                } else {
                                    Circle()
                                        .fill(GQColors.textSecondary.opacity(0.15))
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Image(systemName: "figure.strengthtraining.traditional")
                                                .font(.system(size: 14))
                                                .foregroundColor(GQColors.textSecondary)
                                        )
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(GQColors.textPrimary)
                                    Text("\(exercise.sets.count) sets • \(exercise.muscleGroup)")
                                        .font(.system(size: 12))
                                        .foregroundColor(GQColors.textTertiary)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Action buttons
                VStack(spacing: 10) {
                    // Start Now
                    Button {
                        startWorkoutNow()
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start Now")
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [GQColors.deepBlue, GQColors.textSecondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 10) {
                        // Save for Later
                        Button {
                            saveForLater()
                        } label: {
                            HStack {
                                Image(systemName: showingSaved ? "checkmark.circle.fill" : "bookmark")
                                Text(showingSaved ? "Saved!" : "Save for Later")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(showingSaved ? GQColors.success : GQColors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(GQColors.adaptiveOverlay(0.05))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(GQColors.adaptiveOverlay(0.06), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(showingSaved)

                        // Copy Single Exercise
                        Button {
                            showingExercisePicker = true
                        } label: {
                            HStack {
                                Image(systemName: "list.bullet.clipboard")
                                Text("Pick Exercise")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(GQColors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(GQColors.adaptiveOverlay(0.05))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(GQColors.adaptiveOverlay(0.06), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .background(Color(hex: "F8F8FA"))
            }
            .background(Color(hex: "F2F2F7").ignoresSafeArea())
            .navigationTitle("Copy Workout")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerSheet(exercises: workoutData.exercises, profile: profile)
            }
        }
    }

    private func startWorkoutNow() {
        let exercises = workoutData.toActiveExercises()
        let workoutType = WorkoutType(rawValue: workoutData.workoutType) ?? .push
        appState.startWorkout(type: workoutType, exercises: exercises)
        appState.selectedTab = .home
        dismiss()
    }

    private func saveForLater() {
        let template = WorkoutTemplate.fromSharedWorkout(workoutData, userId: profile.id)
        modelContext.insert(template)
        try? modelContext.save()
        withAnimation {
            showingSaved = true
        }
    }
}

// MARK: - Exercise Picker Sheet

struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState

    let exercises: [SharedWorkoutData.SharedExercise]
    let profile: UserProfile

    @State private var savedExercises: Set<UUID> = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(exercises) { exercise in
                    HStack(spacing: 12) {
                        if FeatureFlags.shared.exerciseGifsEnabled {
                            ExerciseGifView(exerciseName: exercise.name, size: .thumbnail, showFallback: false)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(GQColors.textPrimary)
                            Text("\(exercise.sets.count) sets • \(exercise.muscleGroup)")
                                .font(.system(size: 12))
                                .foregroundColor(GQColors.textTertiary)
                        }

                        Spacer()

                        if savedExercises.contains(exercise.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(GQColors.success)
                        } else {
                            HStack(spacing: 8) {
                                Button {
                                    addToCurrentWorkout(exercise)
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(GQColors.textSecondary)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    saveExerciseAsTemplate(exercise)
                                } label: {
                                    Image(systemName: "bookmark")
                                        .font(.system(size: 18))
                                        .foregroundColor(GQColors.deepBlue)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .listRowBackground(Color.white)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(hex: "F2F2F7").ignoresSafeArea())
            .navigationTitle("Pick Exercises")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func addToCurrentWorkout(_ exercise: SharedWorkoutData.SharedExercise) {
        let mg = MuscleGroup(rawValue: exercise.muscleGroup) ?? .chest
        let sets = exercise.sets.map { ActiveSet(reps: $0.reps, weight: $0.weight) }
        let active = ActiveExercise(name: exercise.name, muscleGroup: mg, sets: sets)

        if appState.activeWorkout != nil {
            appState.activeWorkout?.exercises.append(active)
        }

        withAnimation {
            savedExercises.insert(exercise.id)
        }
    }

    private func saveExerciseAsTemplate(_ exercise: SharedWorkoutData.SharedExercise) {
        let tmplExercise = TemplateExercise(
            name: exercise.name,
            muscleGroup: exercise.muscleGroup,
            suggestedSets: exercise.sets.count,
            suggestedReps: "\(exercise.sets.first?.reps ?? 10)",
            suggestedWeight: exercise.sets.first?.weight,
            order: 0
        )

        let template = WorkoutTemplate(
            odId: profile.id,
            name: exercise.name,
            workoutType: WorkoutType(rawValue: exercise.muscleGroup) ?? .push,
            exercises: [tmplExercise],
            estimatedDuration: exercise.sets.count * 3
        )

        modelContext.insert(template)
        try? modelContext.save()

        withAnimation {
            savedExercises.insert(exercise.id)
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleWorkout = SharedWorkoutData(
        title: "Push Day",
        workoutType: "Push",
        estimatedDuration: 45,
        exercises: [
            SharedWorkoutData.SharedExercise(
                name: "Bench Press",
                muscleGroup: "Chest",
                sets: [
                    .init(reps: 8, weight: 135, restSeconds: 90),
                    .init(reps: 8, weight: 155, restSeconds: 90),
                    .init(reps: 6, weight: 175, restSeconds: 120)
                ],
                demoTips: ["Keep shoulder blades retracted", "Control the descent"]
            ),
            SharedWorkoutData.SharedExercise(
                name: "Overhead Press",
                muscleGroup: "Shoulders",
                sets: [
                    .init(reps: 10, weight: 85, restSeconds: 60),
                    .init(reps: 10, weight: 85, restSeconds: 60),
                    .init(reps: 8, weight: 95, restSeconds: 90)
                ],
                demoTips: ["Brace your core", "Lock out at the top"]
            )
        ],
        authorName: "Test User",
        authorUsername: "testuser"
    )

    WorkoutDetailSheet(workoutData: sampleWorkout) {
        print("Follow tapped")
    }
}
