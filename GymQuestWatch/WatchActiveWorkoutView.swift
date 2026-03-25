//
//  WatchActiveWorkoutView.swift
//  GymQuestWatch
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
        .interactiveDismissDisabled()
        .onAppear { startWorkout() }
    }

    // MARK: - Exercise Tab

    private var exerciseTab: some View {
        VStack(spacing: 8) {
            if let exercise = currentExercise {
                HStack(spacing: 10) {
                    WatchGifView(exercise.name)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(exercise.name)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.white)
                        Text("Set \(currentSetIndex + 1) of \(exercise.sets.count)")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(WatchColors.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Weight
                HStack(alignment: .firstTextBaseline) {
                    Text("\(Int(currentWeight))")
                        .font(.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                    Text("lbs")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(WatchColors.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .focusable()
                .digitalCrownRotation($currentWeight, from: 0, through: 999, by: 5, sensitivity: .medium)

                // Reps
                HStack(spacing: 0) {
                    Button { currentReps = max(1, currentReps - 1) } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 36, height: 36)
                            .background(WatchColors.surfaceElevated)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Text("\(currentReps)")
                        .font(.system(size: 22, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)

                    Button { currentReps = min(100, currentReps + 1) } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 36, height: 36)
                            .background(WatchColors.surfaceElevated)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                Button { completeSet() } label: {
                    Text("Done")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                .buttonStyle(WatchPrimaryButtonStyle())

                if showPR {
                    Text("New PR")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(WatchColors.gold)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(.horizontal, 6)
        .animation(.easeInOut(duration: 0.3), value: showPR)
    }

    // MARK: - Rest Timer

    private var restTimerTab: some View {
        VStack(spacing: 14) {
            if isResting {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 6)

                    Circle()
                        .trim(from: 0, to: restProgress)
                        .stroke(
                            WatchGradients.primary,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: restSecondsRemaining)

                    VStack(spacing: 0) {
                        Text("\(restSecondsRemaining)")
                            .font(.system(size: 44, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 130, height: 130)

                Button { skipRest() } label: {
                    Text("Skip")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(WatchColors.surface)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Spacer()
                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .light, design: .rounded))
                    .foregroundStyle(WatchColors.success)
                Text("Ready")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
            }
        }
    }

    // MARK: - Exercise List

    private var exerciseListTab: some View {
        ScrollView {
            VStack(spacing: 2) {
                ForEach(exercises.indices, id: \.self) { index in
                    let exercise = exercises[index]
                    let completedCount = exercise.sets.filter(\.isCompleted).count
                    let isCurrent = index == currentExerciseIndex
                    let isDone = completedCount == exercise.sets.count

                    Button { jumpToExercise(index) } label: {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(isDone ? WatchColors.success : (isCurrent ? .white : Color.white.opacity(0.15)))
                                .frame(width: 7, height: 7)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name)
                                    .font(.system(size: 13, weight: isCurrent ? .semibold : .regular, design: .rounded))
                                    .lineLimit(1)
                                    .foregroundStyle(isCurrent ? .white : .white.opacity(0.7))
                                Text("\(completedCount)/\(exercise.sets.count)")
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundStyle(WatchColors.textTertiary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(isCurrent ? WatchColors.surface : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Overview

    private var overviewTab: some View {
        VStack(spacing: 12) {
            Text(formatDuration(elapsedSeconds))
                .font(.system(size: 36, weight: .light, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)

            HStack(spacing: 20) {
                statPill("\(completedSets)/\(totalSetsCount)", "sets")
                statPill(formatVolume(totalVolume), "vol")
                if connectivity.heartRate > 0 {
                    statPill("\(Int(connectivity.heartRate))", "bpm")
                }
            }

            Button(role: .destructive) {
                showEndConfirmation = true
            } label: {
                Text("End")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .confirmationDialog("End Workout?", isPresented: $showEndConfirmation) {
            Button("End Workout", role: .destructive) { endWorkout() }
            Button("Cancel", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func statPill(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(WatchColors.textTertiary)
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
            exerciseName: exercise.name, setNumber: currentSetIndex + 1,
            weight: currentWeight, reps: currentReps
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
                if restSecondsRemaining > 0 { restSecondsRemaining -= 1 }
                else { skipRest() }
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
        currentSetIndex = exercises[index].sets.firstIndex(where: { !$0.isCompleted }) ?? 0
        syncCurrentSet()
        selectedTab = 0
    }

    private func addExercise() {
        exercises.append(WatchActiveExercise(
            name: "Custom Exercise", muscleGroup: "General",
            sets: (0..<3).map { _ in WatchActiveSet(reps: 10, weight: 0) }
        ))
    }

    private func syncCurrentSet() {
        guard let exercise = currentExercise,
              exercise.sets.indices.contains(currentSetIndex) else { return }
        currentWeight = exercise.sets[currentSetIndex].weight
        currentReps = exercise.sets[currentSetIndex].reps
    }

    private func checkPR() {
        guard exercises.indices.contains(currentExerciseIndex) else { return }
        let completed = exercises[currentExerciseIndex].sets.filter(\.isCompleted)
        guard completed.count >= 2,
              let current = completed.last?.volume,
              let best = completed.dropLast().map(\.volume).max(),
              current > best, current > 0 else { return }
        showPR = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showPR = false }
    }

    private func endWorkout() {
        stopTimers()
        connectivity.sendWorkoutEnd()
        Task { await connectivity.endHealthKitWorkout() }
        let completed = WatchCompletedWorkout(
            type: workoutType, date: startDate, durationSeconds: elapsedSeconds,
            exercises: exercises.map { ex in
                WatchCompletedWorkout.CompletedExercise(
                    name: ex.name,
                    sets: ex.sets.filter(\.isCompleted).map {
                        WatchCompletedWorkout.CompletedSet(reps: $0.reps, weight: $0.weight)
                    }
                )
            }
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
