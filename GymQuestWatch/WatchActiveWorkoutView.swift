//
//  WatchActiveWorkoutView.swift
//  GymQuestWatch
//
//  Core workout experience. Apple-native design with gradient accents only.
//

import SwiftUI
import Combine

struct WatchActiveWorkoutView: View {
    @Environment(WatchConnectivityManager.self) var connectivity
    let workoutType: String
    @State var exercises: [WatchActiveExercise]
    let onFinish: (WatchCompletedWorkout?) -> Void

    @State private var currentExerciseIndex = 0
    @State private var currentSetIndex = 0
    @State private var selectedTab = 0
    @State private var elapsedSeconds = 0
    @State private var isResting = false
    @State private var restSecondsRemaining = 0
    @State private var restSecondsTotal = 0
    @State private var showEndConfirmation = false
    @State private var showPR = false
    @State private var currentWeight: Double = 135
    @State private var currentReps: Int = 8
    @State private var startDate = Date()

    @State private var elapsedTimer: AnyCancellable?
    @State private var restTimer: AnyCancellable?

    private var currentExercise: WatchActiveExercise? {
        guard exercises.indices.contains(currentExerciseIndex) else { return nil }
        return exercises[currentExerciseIndex]
    }

    private var totalVolume: Double {
        exercises.flatMap(\.sets).filter(\.isCompleted).reduce(0) { $0 + $1.volume }
    }

    private var completedSets: Int {
        exercises.flatMap(\.sets).filter(\.isCompleted).count
    }

    private var totalSetsCount: Int {
        exercises.flatMap(\.sets).count
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            exerciseTab.tag(0)
            restTimerTab.tag(1)
            exerciseListTab.tag(2)
            overviewTab.tag(3)
        }
        .tabViewStyle(.verticalPage)
        .onAppear { startWorkout() }
        .onDisappear { stopTimers() }
    }

    // MARK: - Tab 0: Exercise

    private var exerciseTab: some View {
        VStack(spacing: 6) {
            if let exercise = currentExercise {
                // GIF + Name
                HStack(spacing: 8) {
                    WatchGifView(exercise.name)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.white)
                        Text("Set \(currentSetIndex + 1) of \(exercise.sets.count)")
                            .font(.system(size: 11))
                            .foregroundStyle(WatchColors.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Weight (Digital Crown)
                HStack {
                    Text("lbs")
                        .font(.system(size: 12))
                        .foregroundStyle(WatchColors.textTertiary)
                    Spacer()
                    Text("\(Int(currentWeight))")
                        .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                }
                .focusable()
                .digitalCrownRotation($currentWeight, from: 0, through: 999, by: 5, sensitivity: .medium)

                // Reps
                HStack {
                    Button { currentReps = max(1, currentReps - 1) } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(WatchColors.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(WatchColors.surface)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Text("\(currentReps)")
                        .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.white)

                    Button { currentReps = min(100, currentReps + 1) } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(WatchColors.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(WatchColors.surface)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                // Complete Set
                Button { completeSet() } label: {
                    Text("Done")
                        .font(.system(size: 15, weight: .semibold))
                }
                .buttonStyle(WatchPrimaryButtonStyle())

                // PR banner
                if showPR {
                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 10))
                        Text("PR")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(WatchColors.gold)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(.horizontal, WatchLayout.horizontalPadding)
        .animation(.easeInOut(duration: 0.3), value: showPR)
    }

    // MARK: - Tab 1: Rest Timer

    private var restTimerTab: some View {
        VStack(spacing: 10) {
            if isResting {
                ZStack {
                    Circle()
                        .stroke(Color(white: 0.18), lineWidth: 5)

                    Circle()
                        .trim(from: 0, to: restProgress)
                        .stroke(
                            WatchGradients.primary,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: restSecondsRemaining)

                    VStack(spacing: 2) {
                        Text("\(restSecondsRemaining)")
                            .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white)
                        Text("rest")
                            .font(.system(size: 12))
                            .foregroundStyle(WatchColors.textTertiary)
                    }
                }
                .frame(width: 120, height: 120)

                Button { skipRest() } label: {
                    Text("Skip")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(WatchColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(WatchColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: WatchLayout.cornerRadius))
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(WatchColors.success)
                    Text("Ready")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Swipe up for next set")
                        .font(.system(size: 10))
                        .foregroundStyle(WatchColors.textTertiary)
                }
            }
        }
    }

    // MARK: - Tab 2: Exercise List

    private var exerciseListTab: some View {
        ScrollView {
            VStack(spacing: 3) {
                Text("EXERCISES")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(WatchColors.textTertiary)
                    .tracking(0.5)
                    .padding(.bottom, 4)

                ForEach(exercises.indices, id: \.self) { index in
                    let exercise = exercises[index]
                    let completedCount = exercise.sets.filter(\.isCompleted).count
                    let isCurrent = index == currentExerciseIndex
                    let isDone = completedCount == exercise.sets.count

                    Button {
                        jumpToExercise(index)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: isDone ? "checkmark.circle.fill" : (isCurrent ? "circle.inset.filled" : "circle"))
                                .font(.system(size: 12))
                                .foregroundStyle(isDone ? WatchColors.success : (isCurrent ? .white : WatchColors.textTertiary))

                            VStack(alignment: .leading, spacing: 1) {
                                Text(exercise.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                                    .foregroundStyle(.white)
                                Text("\(completedCount)/\(exercise.sets.count) sets")
                                    .font(.system(size: 9))
                                    .foregroundStyle(WatchColors.textTertiary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(isCurrent ? WatchColors.surfaceElevated : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    addExercise()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10))
                        Text("Add")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(WatchColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, WatchLayout.horizontalPadding)
        }
    }

    // MARK: - Tab 3: Overview

    private var overviewTab: some View {
        VStack(spacing: 10) {
            Text(workoutType.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(WatchColors.textTertiary)
                .tracking(0.5)

            Text(formatDuration(elapsedSeconds))
                .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)

            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text("\(completedSets)/\(totalSetsCount)")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("Sets")
                        .font(.system(size: 9))
                        .foregroundStyle(WatchColors.textTertiary)
                }
                VStack(spacing: 2) {
                    Text(formatVolume(totalVolume))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("Volume")
                        .font(.system(size: 9))
                        .foregroundStyle(WatchColors.textTertiary)
                }
                if connectivity.heartRate > 0 {
                    VStack(spacing: 2) {
                        HStack(spacing: 2) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.red)
                            Text("\(Int(connectivity.heartRate))")
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white)
                        }
                        Text("BPM")
                            .font(.system(size: 9))
                            .foregroundStyle(WatchColors.textTertiary)
                    }
                }
            }

            Button(role: .destructive) {
                showEndConfirmation = true
            } label: {
                Text("End Workout")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.red.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: WatchLayout.cornerRadius))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, WatchLayout.horizontalPadding)
        .confirmationDialog("End Workout?", isPresented: $showEndConfirmation) {
            Button("End Workout", role: .destructive) { endWorkout() }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Actions

    private func startWorkout() {
        startDate = Date()
        syncCurrentSet()
        connectivity.sendWorkoutStart(type: workoutType)
        Task { await connectivity.startHealthKitWorkout() }
        elapsedTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in elapsedSeconds = Int(Date().timeIntervalSince(startDate)) }
    }

    private func completeSet() {
        guard exercises.indices.contains(currentExerciseIndex) else { return }
        let exercise = exercises[currentExerciseIndex]
        guard exercise.sets.indices.contains(currentSetIndex) else { return }

        exercises[currentExerciseIndex].sets[currentSetIndex].weight = currentWeight
        exercises[currentExerciseIndex].sets[currentSetIndex].reps = currentReps
        exercises[currentExerciseIndex].sets[currentSetIndex].isCompleted = true

        connectivity.sendSetComplete(
            exerciseName: exercise.name,
            setNumber: currentSetIndex + 1,
            weight: currentWeight,
            reps: currentReps
        )

        checkPR()

        let nextSetIndex = currentSetIndex + 1
        if nextSetIndex < exercises[currentExerciseIndex].sets.count {
            currentSetIndex = nextSetIndex
            startRest(for: exercise.name)
        } else {
            let nextExerciseIndex = currentExerciseIndex + 1
            if nextExerciseIndex < exercises.count {
                currentExerciseIndex = nextExerciseIndex
                currentSetIndex = 0
                syncCurrentSet()
                startRest(for: exercise.name)
            } else {
                endWorkout()
            }
        }
    }

    private func startRest(for exerciseName: String) {
        let seconds = defaultRestSeconds(for: exerciseName)
        restSecondsTotal = seconds
        restSecondsRemaining = seconds
        isResting = true
        selectedTab = 1
        restTimer?.cancel()
        restTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if restSecondsRemaining > 0 {
                    restSecondsRemaining -= 1
                } else {
                    skipRest()
                }
            }
    }

    private func skipRest() {
        isResting = false
        restTimer?.cancel()
        restSecondsRemaining = 0
        selectedTab = 0
        syncCurrentSet()
    }

    private func jumpToExercise(_ index: Int) {
        currentExerciseIndex = index
        let firstIncomplete = exercises[index].sets.firstIndex(where: { !$0.isCompleted }) ?? 0
        currentSetIndex = firstIncomplete
        syncCurrentSet()
        selectedTab = 0
    }

    private func addExercise() {
        let newExercise = WatchActiveExercise(
            name: "Custom Exercise",
            muscleGroup: "General",
            sets: (0..<3).map { _ in WatchActiveSet(reps: 10, weight: 0) }
        )
        exercises.append(newExercise)
    }

    private func syncCurrentSet() {
        guard let exercise = currentExercise,
              exercise.sets.indices.contains(currentSetIndex) else { return }
        let set = exercise.sets[currentSetIndex]
        currentWeight = set.weight
        currentReps = set.reps
    }

    private func checkPR() {
        guard exercises.indices.contains(currentExerciseIndex) else { return }
        let exercise = exercises[currentExerciseIndex]
        let completedSets = exercise.sets.filter(\.isCompleted)
        guard completedSets.count >= 2 else { return }
        let currentVolume = completedSets.last?.volume ?? 0
        let previousBest = completedSets.dropLast().map(\.volume).max() ?? 0
        if currentVolume > previousBest && currentVolume > 0 {
            showPR = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showPR = false }
        }
    }

    private func endWorkout() {
        stopTimers()
        connectivity.sendWorkoutEnd()
        Task { await connectivity.endHealthKitWorkout() }
        let completed = WatchCompletedWorkout(
            type: workoutType,
            date: startDate,
            durationSeconds: elapsedSeconds,
            exercises: exercises.map { exercise in
                WatchCompletedWorkout.CompletedExercise(
                    name: exercise.name,
                    sets: exercise.sets.filter(\.isCompleted).map {
                        WatchCompletedWorkout.CompletedSet(reps: $0.reps, weight: $0.weight)
                    }
                )
            },
            prsAchieved: 0
        )
        WorkoutHistory.save(completed)
        connectivity.sendCompletedWorkout(completed)
        onFinish(completed)
    }

    private func stopTimers() {
        elapsedTimer?.cancel()
        restTimer?.cancel()
    }

    private var restProgress: CGFloat {
        guard restSecondsTotal > 0 else { return 0 }
        return CGFloat(restSecondsRemaining) / CGFloat(restSecondsTotal)
    }
}
