//
//  WatchActiveWorkoutView.swift
//  GymQuestWatch
//
//  Core workout experience with exercise tracking, rest timer,
//  exercise list, and workout overview.
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
        VStack(spacing: 4) {
            if let exercise = currentExercise {
                // GIF + Name
                HStack(spacing: 6) {
                    WatchGifView(exercise.name)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(exercise.name)
                            .font(.caption.bold())
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text("Set \(currentSetIndex + 1) of \(exercise.sets.count)")
                            .font(.system(size: 10))
                            .foregroundStyle(WatchColors.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Weight (Digital Crown)
                HStack {
                    Text("lbs")
                        .font(.caption2)
                        .foregroundStyle(WatchColors.textSecondary)
                    Spacer()
                    Text("\(Int(currentWeight))")
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(WatchColors.vividPurple)
                }
                .focusable()
                .digitalCrownRotation($currentWeight, from: 0, through: 999, by: 5, sensitivity: .medium)

                // Reps
                HStack {
                    Button { currentReps = max(1, currentReps - 1) } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(WatchColors.textSecondary)
                    }
                    .buttonStyle(.plain)

                    Text("\(currentReps)")
                        .font(.title3.bold().monospacedDigit())
                        .frame(maxWidth: .infinity)

                    Button { currentReps = min(100, currentReps + 1) } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(WatchColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                // Complete Set
                Button { completeSet() } label: {
                    Text("COMPLETE SET")
                }
                .buttonStyle(WatchPrimaryButtonStyle())

                // PR banner
                if showPR {
                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .font(.caption2)
                            .foregroundStyle(WatchColors.gold)
                        Text("PR!")
                            .font(.caption.bold())
                            .foregroundStyle(WatchColors.gold)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(.horizontal, WatchLayout.horizontalPadding)
        .animation(.easeInOut(duration: 0.3), value: showPR)
    }

    // MARK: - Tab 1: Rest Timer

    private var restTimerTab: some View {
        VStack(spacing: 8) {
            if isResting {
                ZStack {
                    Circle()
                        .stroke(WatchColors.deepBlue.opacity(0.2), lineWidth: 6)

                    Circle()
                        .trim(from: 0, to: restProgress)
                        .stroke(
                            WatchGradients.primary,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: restSecondsRemaining)

                    VStack(spacing: 2) {
                        Text("\(restSecondsRemaining)")
                            .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(WatchColors.vividPurple)
                        Text("rest")
                            .font(.caption2)
                            .foregroundStyle(WatchColors.textSecondary)
                    }
                }
                .frame(width: 110, height: 110)

                Button { skipRest() } label: {
                    Text("Skip")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(WatchColors.success)
                    Text("Ready")
                        .font(.headline)
                    Text("Swipe up for next set")
                        .font(.system(size: 10))
                        .foregroundStyle(WatchColors.textSecondary)
                }
            }
        }
    }

    // MARK: - Tab 2: Exercise List

    private var exerciseListTab: some View {
        ScrollView {
            VStack(spacing: 4) {
                Text("EXERCISES")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(WatchColors.textSecondary)
                    .tracking(0.5)

                ForEach(exercises.indices, id: \.self) { index in
                    let exercise = exercises[index]
                    let completedCount = exercise.sets.filter(\.isCompleted).count
                    let isCurrent = index == currentExerciseIndex
                    let isDone = completedCount == exercise.sets.count

                    Button {
                        jumpToExercise(index)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isDone ? "checkmark.circle.fill" : (isCurrent ? "play.circle.fill" : "circle"))
                                .font(.caption2)
                                .foregroundStyle(isDone ? WatchColors.success : (isCurrent ? WatchColors.vividPurple : WatchColors.textSecondary))

                            VStack(alignment: .leading, spacing: 1) {
                                Text(exercise.name)
                                    .font(.caption2.bold())
                                    .lineLimit(1)
                                    .foregroundStyle(WatchColors.textPrimary)
                                Text("\(completedCount)/\(exercise.sets.count) sets")
                                    .font(.system(size: 9))
                                    .foregroundStyle(WatchColors.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                        .background(isCurrent ? WatchColors.surface : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    addExercise()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                            .font(.caption2)
                        Text("Add Exercise")
                            .font(.caption2)
                    }
                    .foregroundStyle(WatchColors.deepBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, WatchLayout.horizontalPadding)
        }
    }

    // MARK: - Tab 3: Overview

    private var overviewTab: some View {
        VStack(spacing: 8) {
            Text(workoutType.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(WatchColors.vividPurple)
                .tracking(0.5)

            Text(formatDuration(elapsedSeconds))
                .font(.title2.bold().monospacedDigit())

            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text("\(completedSets)/\(totalSetsCount)")
                        .font(.caption.bold().monospacedDigit())
                    Text("Sets")
                        .font(.system(size: 9))
                        .foregroundStyle(WatchColors.textSecondary)
                }
                VStack(spacing: 2) {
                    Text(formatVolume(totalVolume))
                        .font(.caption.bold().monospacedDigit())
                    Text("Volume")
                        .font(.system(size: 9))
                        .foregroundStyle(WatchColors.textSecondary)
                }
                if connectivity.heartRate > 0 {
                    VStack(spacing: 2) {
                        HStack(spacing: 2) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.red)
                            Text("\(Int(connectivity.heartRate))")
                                .font(.caption.bold().monospacedDigit())
                        }
                        Text("BPM")
                            .font(.system(size: 9))
                            .foregroundStyle(WatchColors.textSecondary)
                    }
                }
            }

            Button(role: .destructive) {
                showEndConfirmation = true
            } label: {
                Label("End Workout", systemImage: "stop.fill")
                    .font(.caption2)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red.opacity(0.3))
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

        // Save values to set
        exercises[currentExerciseIndex].sets[currentSetIndex].weight = currentWeight
        exercises[currentExerciseIndex].sets[currentSetIndex].reps = currentReps
        exercises[currentExerciseIndex].sets[currentSetIndex].isCompleted = true

        // Send to iPhone
        connectivity.sendSetComplete(
            exerciseName: exercise.name,
            setNumber: currentSetIndex + 1,
            weight: currentWeight,
            reps: currentReps
        )

        // Check PR (simple: best volume for this exercise in this workout)
        checkPR()

        // Advance
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
                // All done
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showPR = false
            }
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
