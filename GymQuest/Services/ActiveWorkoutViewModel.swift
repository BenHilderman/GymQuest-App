//
//  ActiveWorkoutViewModel.swift
//  GymQuest
//
//  Central state management for the active workout experience.
//  Coordinates rest timers, live PR detection, volume tracking,
//  milestone celebrations, and RPE capture.
//

import SwiftUI
import SwiftData

// MARK: - Set Effort Rating

enum SetEffort: String, CaseIterable {
    case easy = "Easy"
    case justRight = "Just Right"
    case hard = "Hard"
    case failed = "Failed"

    var toRPE: Int {
        switch self {
        case .easy: return 5
        case .justRight: return 7
        case .hard: return 9
        case .failed: return 10
        }
    }

    var icon: String {
        switch self {
        case .easy: return "wind"
        case .justRight: return "checkmark.seal.fill"
        case .hard: return "flame.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .easy: return GQColors.cyanSpark
        case .justRight: return GQColors.success
        case .hard: return GQColors.sunsetOrange
        case .failed: return GQColors.coralRed
        }
    }
}

// MARK: - Live PR Event

struct LivePREvent: Identifiable {
    let id = UUID()
    let exerciseName: String
    let type: PRType
    let newValue: Double
    let previousValue: Double
    let delta: Double
    let timestamp = Date()

    enum PRType {
        case weight, rep, estimated1RM

        var label: String {
            switch self {
            case .weight: return "WEIGHT PR"
            case .rep: return "REP PR"
            case .estimated1RM: return "e1RM PR"
            }
        }
    }

    var displayDelta: String {
        switch type {
        case .weight: return "+\(Int(delta)) lbs"
        case .rep: return "+\(Int(delta)) reps"
        case .estimated1RM: return "+\(Int(delta)) lbs e1RM"
        }
    }
}

// MARK: - Previous Exercise Data

struct PreviousExerciseData {
    let lastWeight: Double
    let lastReps: Int
    let lastVolume: Double
    let bestWeight: Double
    let bestReps: Int
    let best1RM: Double?
    let lastDate: Date
    let suggestedWeight: Double
    let lastRPE: Int?
}

// MARK: - Milestone

struct WorkoutMilestone: Identifiable {
    let id = UUID()
    let percentage: Double
    let message: String
    let icon: String
}

// MARK: - ViewModel

@Observable
@MainActor
class ActiveWorkoutViewModel {

    // MARK: - Core Workout State

    var exercises: [ActiveExercise] = []
    var workoutType: WorkoutType
    var workoutStartTime = Date()
    var elapsedTime: Int = 0

    // MARK: - Rest Timer

    var isResting: Bool = false
    var restTimeRemaining: Int = 0
    var restTimerTotal: Int = 60
    var selectedRestDuration: Int = 0 // 0 = auto (smart defaults), once user picks one it sticks
    var restTimerHidden: Bool = false // user can hide the rest bar
    var currentRestExerciseName: String = ""
    var currentRestFormCue: String? = nil

    // MARK: - Live Performance

    var liveVolume: Double = 0
    var livePRs: [LivePREvent] = []
    var activePRBanner: LivePREvent? = nil
    var previousPerformance: [String: PreviousExerciseData] = [:]

    // MARK: - RPE Capture

    var pendingRPESetId: UUID? = nil

    // MARK: - Milestones

    var lastCelebratedMilestone: Double = 0
    var activeMilestone: WorkoutMilestone? = nil

    // MARK: - First-Time Tracking

    var firstTimePRShown: Set<String> = []
    var firstExerciseMilestoneShown = false
    var firstSetMilestoneShown = false

    // MARK: - Progressive Overload

    var overloadSuggestions: [String: OverloadSuggestion] = [:]

    // MARK: - Sheets / Navigation

    var showingAddExercise = false
    var showingFormDemo: ActiveExercise? = nil
    var showingCompletion = false
    var showingRestSettings = false

    // MARK: - References

    let profile: UserProfile
    let modelContext: ModelContext

    // MARK: - Timers

    private var workoutTimer: Timer?
    private var restTimer: Timer?
    private var prBannerTimer: Timer?
    private var milestoneTimer: Timer?

    // MARK: - Computed Properties

    var completedSetsCount: Int {
        exercises.reduce(0) { $0 + $1.sets.filter { $0.isCompleted }.count }
    }

    var totalSetsCount: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }

    var progressPercentage: Double {
        guard totalSetsCount > 0 else { return 0 }
        return Double(completedSetsCount) / Double(totalSetsCount)
    }

    var averageRPE: Double {
        let completedWithRPE = exercises.flatMap { $0.sets }.filter { $0.isCompleted && $0.rpe != nil }
        guard !completedWithRPE.isEmpty else { return 0 }
        return Double(completedWithRPE.compactMap { $0.rpe }.reduce(0, +)) / Double(completedWithRPE.count)
    }

    // MARK: - Init

    init(profile: UserProfile, workoutType: WorkoutType, modelContext: ModelContext) {
        self.profile = profile
        self.workoutType = workoutType
        self.modelContext = modelContext
    }

    // MARK: - Timer Management

    func startWorkoutTimer() {
        workoutStartTime = Date()
        workoutTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.elapsedTime = Int(Date().timeIntervalSince(self?.workoutStartTime ?? Date()))
            }
        }
    }

    func stopWorkoutTimer() {
        workoutTimer?.invalidate()
        workoutTimer = nil
    }

    // MARK: - Set Completion Chain

    func onSetCompleted(exerciseId: UUID, set: ActiveSet) {
        // 1. Update live volume
        if set.isCompleted {
            liveVolume += set.volume
        } else {
            liveVolume = max(0, liveVolume - set.volume)
        }

        guard set.isCompleted else { return }

        // 2. Check for live PR
        if let exercise = exercises.first(where: { $0.id == exerciseId }) {
            checkForLivePR(exercise: exercise, set: set)
        }

        // 3. Show RPE capture
        pendingRPESetId = set.id

        // 4. Start rest timer
        if let exercise = exercises.first(where: { $0.id == exerciseId }) {
            startRestTimer(for: exercise)
        }

        // 5. Check milestones (including first-set)
        if !firstSetMilestoneShown {
            firstSetMilestoneShown = true
            showEarlyMilestone(message: "First set in the books!", icon: "checkmark.seal.fill")
        } else {
            checkMilestone()
        }
    }

    // MARK: - Rest Timer

    func startRestTimer(for exercise: ActiveExercise) {
        // Don't start if all sets of this exercise are already done and it's the last exercise
        let allDone = exercise.sets.allSatisfy { $0.isCompleted }
        let isLastExercise = exercises.last?.id == exercise.id
        if allDone && isLastExercise { return }

        restTimer?.invalidate()

        let duration: Int
        if selectedRestDuration > 0 {
            duration = selectedRestDuration
        } else {
            duration = suggestRestTime(for: exercise.name)
        }

        restTimerTotal = duration
        restTimeRemaining = duration
        isResting = true
        currentRestExerciseName = exercise.name

        // Pick a random form cue for between-set tips
        if let metadata = ExtendedExerciseDatabase.find(exercise.name), !metadata.cues.isEmpty {
            currentRestFormCue = metadata.cues.randomElement()
        } else {
            currentRestFormCue = nil
        }

        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.restTimeRemaining -= 1

                switch self.restTimeRemaining {
                case 10, 5:
                    HapticManager.shared.restTimerWarning()
                case 1...3:
                    HapticManager.shared.restTimerCountdown()
                case 0:
                    HapticManager.shared.restTimerDone()
                    self.endRestTimer()
                default:
                    break
                }
            }
        }
    }

    func skipRest() {
        HapticManager.shared.buttonTap()
        endRestTimer()
    }

    func adjustRestDuration(_ seconds: Int) {
        let delta = seconds - restTimerTotal
        restTimerTotal = seconds
        restTimeRemaining = max(0, restTimeRemaining + delta)
        // Persist choice for all future rest timers this workout
        selectedRestDuration = seconds
    }

    private func endRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
        isResting = false
    }

    private func suggestRestTime(for exerciseName: String) -> Int {
        guard let metadata = ExtendedExerciseDatabase.find(exerciseName) else { return 60 }
        switch metadata.category {
        case .compound: return 120
        case .push, .pull: return 90
        case .isolation: return 60
        case .core: return 45
        case .cardio: return 30
        default: return 60
        }
    }

    // MARK: - Live PR Detection

    func checkForLivePR(exercise: ActiveExercise, set: ActiveSet) {
        guard set.weight > 0, set.reps > 0 else { return }

        // First-time exercise: fire a baseline PR on first completed set
        if previousPerformance[exercise.name] == nil && !firstTimePRShown.contains(exercise.name) {
            firstTimePRShown.insert(exercise.name)
            let pr = LivePREvent(
                exerciseName: exercise.name,
                type: .weight,
                newValue: set.weight,
                previousValue: 0,
                delta: set.weight
            )
            showPR(pr)
            return
        }

        guard let previous = previousPerformance[exercise.name] else { return }

        // Weight PR: higher weight at same or more reps
        if set.weight > previous.bestWeight && set.reps >= previous.lastReps {
            let pr = LivePREvent(
                exerciseName: exercise.name,
                type: .weight,
                newValue: set.weight,
                previousValue: previous.bestWeight,
                delta: set.weight - previous.bestWeight
            )
            showPR(pr)
            return
        }

        // e1RM PR
        if set.reps >= 1 && set.reps <= 12 {
            let currentE1RM = set.weight * (1 + Double(set.reps) / 30.0)
            if let bestE1RM = previous.best1RM, currentE1RM > bestE1RM + 5 {
                let pr = LivePREvent(
                    exerciseName: exercise.name,
                    type: .estimated1RM,
                    newValue: currentE1RM,
                    previousValue: bestE1RM,
                    delta: currentE1RM - bestE1RM
                )
                showPR(pr)
            }
        }
    }

    private func showPR(_ pr: LivePREvent) {
        livePRs.append(pr)
        activePRBanner = pr
        HapticManager.shared.prDetected()

        prBannerTimer?.invalidate()
        prBannerTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.activePRBanner = nil
            }
        }
    }

    // MARK: - Milestone Detection

    func checkMilestone() {
        let progress = progressPercentage
        let milestones: [(Double, String, String)] = [
            (0.25, "Getting warmed up!", "flame"),
            (0.50, "Halfway there!", "bolt.fill"),
            (0.75, "Final push!", "star.fill"),
        ]

        for (threshold, message, icon) in milestones {
            if progress >= threshold && lastCelebratedMilestone < threshold {
                lastCelebratedMilestone = threshold
                let milestone = WorkoutMilestone(percentage: threshold, message: message, icon: icon)
                activeMilestone = milestone
                HapticManager.shared.milestoneReached()

                milestoneTimer?.invalidate()
                milestoneTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
                    Task { @MainActor in
                        self?.activeMilestone = nil
                    }
                }
                break
            }
        }
    }

    private func showEarlyMilestone(message: String, icon: String) {
        let milestone = WorkoutMilestone(percentage: 0, message: message, icon: icon)
        activeMilestone = milestone
        HapticManager.shared.milestoneReached()

        milestoneTimer?.invalidate()
        milestoneTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.activeMilestone = nil
            }
        }
    }

    // MARK: - Previous Performance Loading

    func loadPreviousPerformance() {
        let descriptor = FetchDescriptor<Workout>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let allWorkouts = try? modelContext.fetch(descriptor) else { return }

        for exercise in exercises {
            var lastWeight: Double = 0
            var lastReps: Int = 0
            var lastVolume: Double = 0
            var bestWeight: Double = 0
            var bestReps: Int = 0
            var bestE1RM: Double = 0
            var lastDate: Date?
            var lastRPE: Int?

            for workout in allWorkouts {
                for ex in workout.exercises where ex.name == exercise.name {
                    if lastDate == nil {
                        lastDate = workout.date
                        let topSet = ex.sets.max(by: { $0.weight < $1.weight })
                        lastWeight = topSet?.weight ?? 0
                        lastReps = topSet?.reps ?? 0
                        lastVolume = ex.totalVolume
                        lastRPE = topSet?.rpe
                    }

                    for set in ex.sets {
                        if set.weight > bestWeight { bestWeight = set.weight }
                        if set.reps > bestReps { bestReps = set.reps }
                        if set.reps >= 1 && set.reps <= 12 {
                            let e1rm = set.weight * (1 + Double(set.reps) / 30.0)
                            if e1rm > bestE1RM { bestE1RM = e1rm }
                        }
                    }
                }
            }

            guard lastDate != nil else { continue }

            // Progressive overload suggestion
            let suggested: Double
            if let rpe = lastRPE, rpe >= 10 {
                suggested = lastWeight // Same weight — last time was a grind
            } else if let rpe = lastRPE, rpe >= 8 {
                suggested = lastWeight // Same weight, aim for +1 rep
            } else {
                suggested = lastWeight + 5 // Bump up 5 lbs
            }

            previousPerformance[exercise.name] = PreviousExerciseData(
                lastWeight: lastWeight,
                lastReps: lastReps,
                lastVolume: lastVolume,
                bestWeight: bestWeight,
                bestReps: bestReps,
                best1RM: bestE1RM > 0 ? bestE1RM : nil,
                lastDate: lastDate!,
                suggestedWeight: suggested,
                lastRPE: lastRPE
            )
        }
    }

    // MARK: - Exercise Management

    func addExercise(_ metadata: ExerciseMetadata) {
        // Fire first-exercise milestone
        if exercises.isEmpty && !firstExerciseMilestoneShown {
            firstExerciseMilestoneShown = true
            showEarlyMilestone(message: "First exercise loaded!", icon: "figure.strengthtraining.traditional")
        }

        // Load history first so we can auto-fill weights
        loadPreviousPerformanceForExercise(metadata.name)
        let prev = previousPerformance[metadata.name]

        let prefillWeight = prev?.suggestedWeight ?? 0
        let prefillReps = prev?.lastReps ?? 10

        let exercise = ActiveExercise(
            name: metadata.name,
            muscleGroup: metadata.muscleGroup,
            sets: [
                ActiveSet(reps: prefillReps, weight: prefillWeight),
                ActiveSet(reps: prefillReps, weight: prefillWeight),
                ActiveSet(reps: prefillReps, weight: prefillWeight)
            ]
        )
        exercises.append(exercise)
    }

    private func loadPreviousPerformanceForExercise(_ name: String) {
        guard previousPerformance[name] == nil else { return }

        let descriptor = FetchDescriptor<Workout>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let allWorkouts = try? modelContext.fetch(descriptor) else { return }

        var lastWeight: Double = 0
        var lastReps: Int = 0
        var lastVolume: Double = 0
        var bestWeight: Double = 0
        var bestReps: Int = 0
        var bestE1RM: Double = 0
        var lastDate: Date?
        var lastRPE: Int?

        for workout in allWorkouts {
            for ex in workout.exercises where ex.name == name {
                if lastDate == nil {
                    lastDate = workout.date
                    let topSet = ex.sets.max(by: { $0.weight < $1.weight })
                    lastWeight = topSet?.weight ?? 0
                    lastReps = topSet?.reps ?? 0
                    lastVolume = ex.totalVolume
                    lastRPE = topSet?.rpe
                }
                for set in ex.sets {
                    if set.weight > bestWeight { bestWeight = set.weight }
                    if set.reps > bestReps { bestReps = set.reps }
                    if set.reps >= 1 && set.reps <= 12 {
                        let e1rm = set.weight * (1 + Double(set.reps) / 30.0)
                        if e1rm > bestE1RM { bestE1RM = e1rm }
                    }
                }
            }
        }

        guard let date = lastDate else { return }

        let suggested: Double
        if let rpe = lastRPE, rpe >= 10 {
            suggested = lastWeight
        } else if let rpe = lastRPE, rpe >= 8 {
            suggested = lastWeight
        } else {
            suggested = lastWeight + 5
        }

        previousPerformance[name] = PreviousExerciseData(
            lastWeight: lastWeight,
            lastReps: lastReps,
            lastVolume: lastVolume,
            bestWeight: bestWeight,
            bestReps: bestReps,
            best1RM: bestE1RM > 0 ? bestE1RM : nil,
            lastDate: date,
            suggestedWeight: suggested,
            lastRPE: lastRPE
        )
    }

    // MARK: - Helpers

    func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk", volume / 1000)
        }
        return "\(Int(volume))"
    }

    func finishWorkout() {
        stopWorkoutTimer()
        endRestTimer()
        showingCompletion = true
    }

    func cleanup() {
        stopWorkoutTimer()
        endRestTimer()
        prBannerTimer?.invalidate()
        milestoneTimer?.invalidate()
    }

    func currentNextSetInfo() -> String {
        guard let exercise = exercises.first(where: { $0.name == currentRestExerciseName }) else {
            return ""
        }
        return nextSetInfo(for: exercise)
    }

    func nextSetInfo(for exercise: ActiveExercise) -> String {
        let nextIncomplete = exercise.sets.first(where: { !$0.isCompleted })
        if nextIncomplete != nil {
            let setNum = (exercise.sets.firstIndex(where: { $0.id == nextIncomplete!.id }) ?? 0) + 1
            return "\(exercise.name) — Set \(setNum)"
        }
        // Find next exercise with incomplete sets
        if let currentIdx = exercises.firstIndex(where: { $0.id == exercise.id }),
           currentIdx + 1 < exercises.count {
            return exercises[currentIdx + 1].name
        }
        return "Almost done!"
    }

    // MARK: - Progressive Overload

    /// Load overload suggestions for all current exercises
    func loadOverloadSuggestions() {
        let descriptor = FetchDescriptor<Workout>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let allWorkouts = try? modelContext.fetch(descriptor) else { return }

        overloadSuggestions = ProgressiveOverloadService.shared.getSuggestions(
            exercises: exercises,
            allWorkouts: allWorkouts,
            profile: profile
        )
    }
}
