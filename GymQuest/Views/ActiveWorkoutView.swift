//
//  ActiveWorkoutView.swift
//  GymQuest
//
//  Live workout session - track exercises and sets in real-time.
//  Add exercises, complete sets, view form demos, and save when done.
//

import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Live Workout Status

struct LiveWorkoutStatus {
    let workoutType: WorkoutType
    let startTime: Date
    var currentExercise: String
    var completedSets: Int
    var totalSets: Int
}
// MARK: - Active Workout Session

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState

    let profile: UserProfile

    @State private var workoutType: WorkoutType
    @State private var exercises: [ActiveExercise]
    @State private var workoutStartTime = Date()
    @State private var showingAddExercise = false
    @State private var showingFormDemo: ActiveExercise?
    @State private var showingFormPeek = false
    @State private var formPeekExercise: FormExercise?
    @State private var showingCancelConfirmation = false
    @State private var showingPostEditor = false
    @State private var savedWorkout: Workout?
    @State private var elapsedTime = 0
    @State private var timer: Timer?
    @State private var restTimer: Timer?
    @State private var isResting = false
    @State private var restTimerHidden = false
    @State private var restTimeRemaining: Int = 0
    @State private var restTimerTotal: Int = 90
    @State private var selectedRestDuration: Int = 90
    @State private var showMusicPicker = false
    @State private var workoutSong: Song?
    @State private var isSharingLive = false
    @State private var partyService = WorkoutPartyService()

    let customTitle: String?

    /// Display name: uses custom title for ".other" workouts, otherwise the enum rawValue.
    var displayTitle: String {
        customTitle ?? displayTitle
    }

    init(profile: UserProfile, workoutType: WorkoutType = .push, exercises: [ActiveExercise] = [], customTitle: String? = nil) {
        self.profile = profile
        self.customTitle = customTitle
        self._workoutType = State(initialValue: workoutType)
        self._exercises = State(initialValue: exercises)
    }

    init(profile: UserProfile) {
        self.profile = profile
        self.customTitle = nil
        self._workoutType = State(initialValue: .push)
        self._exercises = State(initialValue: [])
    }

    var completedSetsCount: Int {
        exercises.reduce(0) { $0 + $1.sets.filter { $0.isCompleted }.count }
    }

    var totalSetsCount: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }

    var totalVolume: Double {
        exercises.reduce(0.0) { total, ex in
            total + ex.sets.filter { $0.isCompleted }.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
        }
    }

    private var workoutTypeColors: [Color] {
        GQGradients.workoutGradientColors(for: workoutType)
    }

    private var workoutAccentColor: Color {
        workoutTypeColors.first ?? GQColors.primary
    }

    var body: some View {
        ZStack {
            // Solid dark background
            Color(white: 0.05).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with timer and progress
                workoutHeader

                // Workout Party bar (visible when broadcasting)
                if isSharingLive && partyService.isActive && FeatureFlags.shared.workoutPartyEnabled {
                    WorkoutPartyBar(
                        partyService: partyService,
                        accentColors: workoutTypeColors,
                        onSendReaction: { emoji in partyService.sendReaction(emoji) },
                        onSendHype: { hype in partyService.sendHype(hype) }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Compact rest timer bar
                if isResting && !restTimerHidden {
                    CompactRestTimerBar(
                        restTimeRemaining: $restTimeRemaining,
                        restTimerTotal: $restTimerTotal,
                        selectedRestDuration: $selectedRestDuration,
                        onSkip: { skipRest() },
                        onHide: { withAnimation(.easeOut(duration: 0.2)) { restTimerHidden = true } },
                        onAdjust: { seconds in adjustRestDuration(seconds) }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Exercise list
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(Array($exercises.enumerated()), id: \.element.id) { index, $exercise in
                            ActiveExerciseCard(
                                exercise: $exercise,
                                workoutTypeColors: workoutTypeColors,
                                onShowDemo: { showFormPeek(for: exercise.name) }
                            )
                            .staggeredAppear(index: index, stagger: 0.06)
                        }

                        // Add exercise button
                        addExerciseButton
                    }
                    .padding(16)
                    .padding(.bottom, 16)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: exercises.count)
                }

                // Bottom bar
                bottomBar
            }

            // Floating reactions overlay
            if isSharingLive && partyService.isActive {
                FloatingReactionsOverlay(reactions: partyService.activeReactions)
            }

            // Incoming hype banner
            if let hype = partyService.activeHypeBanner {
                VStack {
                    HypeToastBanner(message: hype)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
                .padding(.top, 60)
            }
        }
        .gqPageBackground()
        .onAppear {
            initializeFromAppState()
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
            restTimer?.invalidate()
            partyService.stopParty()
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isResting && !restTimerHidden)
        .sheet(isPresented: $showingAddExercise) {
            AddExerciseToSessionSheet(exercises: $exercises, workoutType: workoutType)
        }
        .sheet(isPresented: $showMusicPicker) {
            MusicPickerSheet(selectedSong: $workoutSong, activityType: displayTitle)
        }
        .sheet(item: $showingFormDemo) { exercise in
            ExerciseFormDemoSheet(exerciseName: exercise.name)
        }
        .sheet(isPresented: $showingFormPeek) {
            if let exercise = formPeekExercise {
                FormPeekSheet(exercise: exercise)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .fullScreenCover(isPresented: $showingPostEditor, onDismiss: {
            appState.endWorkout()
        }) {
            if let workout = savedWorkout {
                EnhancedPostEditorView(
                    profile: profile,
                    workout: workout,
                    exercises: makeCompletedExercises(),
                    duration: elapsedTime / 60
                )
            }
        }
        .confirmationDialog(
            "Cancel Workout?",
            isPresented: $showingCancelConfirmation,
            titleVisibility: .visible
        ) {
            Button("Cancel Workout", role: .destructive) {
                timer?.invalidate()
                appState.endWorkout()
            }
            Button("Keep Going", role: .cancel) {}
        } message: {
            Text("Your progress will be lost.")
        }
    }

    // MARK: - Header

    private var workoutHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    showingCancelConfirmation = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Live Workout")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)
                    Text(displayTitle)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                // Broadcast toggle
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isSharingLive.toggle()
                        if isSharingLive {
                            updateLiveStatus()
                            partyService.startParty()
                        } else {
                            appState.liveWorkoutStatus = nil
                            partyService.stopParty()
                        }
                    }
                } label: {
                    Image(systemName: isSharingLive ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isSharingLive ? GQColors.success : GQColors.textTertiary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(isSharingLive ? GQColors.success.opacity(0.15) : Color.white.opacity(0.08))
                        )
                        .overlay(
                            Circle()
                                .stroke(isSharingLive ? GQColors.success.opacity(0.4) : Color.clear, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                if isSharingLive {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 10))
                        Text("\(SocialActivityService.shared.liveCount) active")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(GQColors.success)
                    .transition(.opacity)
                }

                Spacer()

                Text(formatTime(elapsedTime))
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .homeSocialCard(
                        accent: workoutTypeColors.first ?? GQColors.vividPurple,
                        emphasized: false,
                        cornerRadius: 12
                    )
            }

            HStack(spacing: 8) {
                Menu {
                    ForEach(WorkoutType.allCases, id: \.self) { type in
                        Button(type.rawValue) { workoutType = type }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: workoutType.icon)
                        Text("Type")
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(workoutAccentColor.opacity(0.2))
                    )
                    .overlay(
                        Capsule().stroke(workoutAccentColor.opacity(0.3), lineWidth: 0.5)
                    )
                }

                Spacer()

                Text(totalSetsCount == 0 ? "No sets yet" : "\(completedSetsCount)/\(totalSetsCount) sets complete")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)
            }

            AnimatedProgressBar(
                progress: totalSetsCount == 0 ? 0 : Double(completedSetsCount) / Double(totalSetsCount),
                height: 7,
                colors: [workoutTypeColors.first ?? GQColors.vividPurple]
            )
            .frame(height: 7)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    WorkoutFlowMetricChip(
                        icon: "figure.strengthtraining.traditional",
                        value: "\(exercises.count)",
                        label: "Exercises",
                        color: workoutTypeColors.first ?? GQColors.vividPurple
                    )

                    WorkoutFlowMetricChip(
                        icon: "checkmark.circle",
                        value: "\(completedSetsCount)",
                        label: "Done Sets",
                        color: workoutTypeColors.last ?? GQColors.cyanSpark
                    )

                    WorkoutFlowMetricChip(
                        icon: "scalemass.fill",
                        value: totalVolume >= 1000
                            ? String(format: "%.1fk", totalVolume / 1000)
                            : "\(Int(totalVolume))",
                        label: "Volume",
                        color: GQColors.cyanSpark
                    )

                    WorkoutFlowMetricChip(
                        icon: "flame.fill",
                        value: "\(completedSetsCount * 8)",
                        label: "Est. Cal",
                        color: GQColors.success
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(GQColors.surfaceOverlay.opacity(0.86))
    }

    // MARK: - Add Exercise Button

    private var workoutEmptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: workoutType.icon)
                .font(.system(size: 48))
                .foregroundStyle(GQGradients.workoutGradient(for: workoutType))
                .padding(.top, 40)
            Text("Ready to crush \(displayTitle)?")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            Text("Add your first exercise to get started")
                .font(.system(size: 14))
                .foregroundColor(GQColors.textSecondary)
            Button {
                showingAddExercise = true
            } label: {
                HStack { Image(systemName: "plus.circle.fill"); Text("Add Exercise") }
                    .font(.system(size: 16, weight: .semibold))
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var addExerciseButton: some View {
        Button {
            showingAddExercise = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(workoutAccentColor)
                Text("Add Exercise")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                    .foregroundColor(Color.white.opacity(0.12))
            )
        }
        .buttonStyle(GQInteractiveStyle())
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 16) {
            if let lastExercise = exercises.last {
                Button {
                    if let last = exercises.last { addSetToExercise(last) }
                } label: {
                    Label("Add Set", systemImage: "plus")
                }
                .buttonStyle(HomeSocialSecondaryButtonStyle())
                .frame(maxWidth: 150)
            }
            Spacer()
            Button { finishWorkout() } label: {
                Text("Finish")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(workoutAccentColor)
                    )
            }
            .buttonStyle(
                HomeSocialPrimaryButtonStyle(
                    accent: workoutTypeColors.first ?? GQColors.vividPurple
                )
            )
            .frame(maxWidth: 220)
        }
        .padding(16)
        .background(
            Color(white: 0.08)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 0.5)
                }
        )
    }

    // MARK: - Helpers

    private func initializeFromAppState() {
        guard let state = appState.activeWorkout else { return }
        workoutType = state.workoutType
        if !state.exercises.isEmpty {
            exercises = state.exercises
        }
        workoutStartTime = state.startTime
    }

    private func startTimer() {
        workoutStartTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedTime = Int(Date().timeIntervalSince(workoutStartTime))
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func addSetToExercise(_ exercise: ActiveExercise) {
        if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
            let lastSet = exercises[index].sets.last
            let newSet = ActiveSet(
                reps: lastSet?.reps ?? 10,
                weight: lastSet?.weight ?? 0
            )
            exercises[index].sets.append(newSet)
        }
    }

    private func finishWorkout() {
        timer?.invalidate()

        // Save workout immediately and go straight to post editor
        let workoutExercises = exercises.map { activeExercise -> Exercise in
            let sets = activeExercise.sets.filter { $0.isCompleted }.enumerated().map { index, activeSet in
                ExerciseSet(
                    reps: activeSet.reps,
                    weight: activeSet.weight,
                    order: index
                )
            }
            return Exercise(
                name: activeExercise.name,
                muscleGroup: activeExercise.muscleGroup,
                sets: sets
            )
        }

        let workout = Workout(
            type: workoutType,
            duration: elapsedTime / 60,
            exercises: workoutExercises
        )
        modelContext.insert(workout)

        let xpEarned = 20 + (exercises.reduce(0) { $0 + $1.sets.filter { $0.isCompleted }.count } * 5)
        _ = profile.addXP(xpEarned)

        try? modelContext.save()
        savedWorkout = workout
        showingPostEditor = true
    }

    private func makeCompletedExercises() -> [CompletedExercise] {
        exercises.enumerated().map { idx, activeEx in
            CompletedExercise(
                name: activeEx.name,
                sets: activeEx.sets.filter { $0.isCompleted }.count,
                index: idx
            )
        }
    }

    // MARK: - Rest Timer

    private func startRestTimer(exerciseName: String) {
        restTimer?.invalidate()
        restTimerHidden = false

        let duration: Int
        if selectedRestDuration > 0 {
            duration = selectedRestDuration
        } else {
            // Smart default based on exercise type
            if let metadata = ExtendedExerciseDatabase.find(exerciseName) {
                switch metadata.category {
                case .compound: duration = 120
                case .push, .pull: duration = 90
                case .isolation: duration = 60
                case .core: duration = 45
                case .cardio: duration = 30
                default: duration = 60
                }
            } else {
                duration = 60
            }
        }

        restTimerTotal = duration
        restTimeRemaining = duration
        isResting = true

        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                restTimeRemaining -= 1
                if restTimeRemaining <= 0 {
                    endRest()
                    #if canImport(UIKit)
                    let gen = UINotificationFeedbackGenerator()
                    gen.notificationOccurred(.success)
                    #endif
                }
            }
        }
    }

    private func skipRest() {
        endRest()
    }

    private func endRest() {
        restTimer?.invalidate()
        restTimer = nil
        isResting = false
    }

    private func updateLiveStatus() {
        let currentEx = exercises.first(where: { ex in
            ex.sets.contains(where: { !$0.isCompleted })
        })?.name ?? "Starting..."
        appState.liveWorkoutStatus = LiveWorkoutStatus(
            workoutType: workoutType,
            startTime: workoutStartTime,
            currentExercise: currentEx,
            completedSets: completedSetsCount,
            totalSets: totalSetsCount
        )
    }

    private func cleanupAndExit() {
        timer?.invalidate()
        restTimer?.invalidate()
        appState.liveWorkoutStatus = nil
    }

    private func adjustRestDuration(_ seconds: Int) {
        let delta = seconds - restTimerTotal
        restTimerTotal = seconds
        restTimeRemaining = max(0, restTimeRemaining + delta)
        // Persist for all future rest periods this workout
        selectedRestDuration = seconds
    }

    private func showFormPeek(for exerciseName: String) {
        // Seed Form Studio content if needed
        FormContentSeeder.seedIfNeeded(modelContext: modelContext)

        let repo = FormRepository(modelContext: modelContext)
        var allExercises = repo.allExercises()

        // If no exercises found, force seed sample data
        if allExercises.isEmpty {
            FormContentSeeder.seedSampleData(modelContext: modelContext)
            allExercises = repo.allExercises()
            print("Form Peek fallback: seeded \(allExercises.count) exercises")
        }

        // Try to find matching FormExercise by name (fuzzy match)
        let searchName = exerciseName.lowercased()
        let searchWords = searchName.split(separator: " ").map { String($0) }

        if let found = allExercises.first(where: { formEx in
            let formName = formEx.name.lowercased()
            // Check if search name is contained in form name or vice versa
            if formName.contains(searchName) || searchName.contains(formName) {
                return true
            }
            // Check if key words match (e.g., "bench" matches "barbell bench press")
            for word in searchWords {
                if word.count >= 4 && formName.contains(word) {
                    return true
                }
            }
            return false
        }) {
            formPeekExercise = found
            showingFormPeek = true
            print("Form Peek: showing '\(found.name)' for '\(exerciseName)'")
        } else {
            // Fall back to old demo sheet
            print("Form Peek: no match for '\(exerciseName)', falling back to demo")
            if let activeEx = exercises.first(where: { $0.name == exerciseName }) {
                showingFormDemo = activeEx
            }
        }
    }
}

// MARK: - Active Exercise Model

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

// MARK: - Active Exercise Card

struct ActiveExerciseCard: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var exercise: ActiveExercise
    let workoutTypeColors: [Color]
    let onShowDemo: () -> Void
    var onSetCompleted: ((String) -> Void)? = nil

    @State private var previousWeight: Double?
    @State private var previousReps: Int?

    var completedCount: Int {
        exercise.sets.filter { $0.isCompleted }.count
    }

    var allSetsComplete: Bool {
        completedCount == exercise.sets.count && completedCount > 0
    }

    private var workoutAccent: Color {
        workoutTypeColors.first ?? GQColors.vividPurple
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    Text(exercise.muscleGroup.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)
                }

                Spacer()

                Button(action: onShowDemo) {
                    Label("Form", systemImage: "play.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(workoutAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .homeSocialCard(accent: workoutAccent, cornerRadius: 999)
                }
                .buttonStyle(.plain)

                Text("\(completedCount)/\(exercise.sets.count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(allSetsComplete ? workoutAccent : GQColors.textSecondary)
                    .padding(.leading, 4)
            }

            VStack(spacing: 8) {
                ForEach($exercise.sets) { $set in
                    ActiveSetRow(
                        set: $set,
                        setNumber: exercise.sets.firstIndex(where: { $0.id == set.id })! + 1,
                        totalSets: exercise.sets.count,
                        workoutTypeColors: workoutTypeColors,
                        previousWeight: previousWeight,
                        previousReps: previousReps,
                        onComplete: {
                            checkExerciseCompletion()
                        }
                    )
                }

                Button {
                    let lastSet = exercise.sets.last
                    exercise.sets.append(
                        ActiveSet(
                            reps: lastSet?.reps ?? 10,
                            weight: lastSet?.weight ?? 0
                        )
                    )
                } label: {
                    Label("Add Set", systemImage: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(workoutAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .homeSocialCard(accent: workoutAccent, cornerRadius: 10)
                }
            }
            .padding(16)
        }
        .padding(14)
        .homeSocialCard(accent: workoutAccent, emphasized: allSetsComplete)
        .opacity(allSetsComplete ? 0.9 : 1.0)
        .overlay(
            Group {
                if !allSetsComplete {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(workoutAccent.opacity(0.5), lineWidth: 1)
                }
            }
        )
    }

    private func checkExerciseCompletion() {
        // Check if all sets just became complete
        let newCompletedCount = exercise.sets.filter { $0.isCompleted }.count
        if newCompletedCount == exercise.sets.count && newCompletedCount > 0 {
            HapticManager.shared.success()
        }
    }
}

// MARK: - Conditional View Modifier

extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Active Set Row

struct ActiveSetRow: View {
    @Binding var set: ActiveSet
    let setNumber: Int
    var totalSets: Int = 3
    let workoutTypeColors: [Color]
    var previousWeight: Double? = nil
    var previousReps: Int? = nil
    var onComplete: (() -> Void)? = nil

    @State private var checkScale: CGFloat = 1.0
    @State private var justCompleted = false
    @State private var showCheckParticles = false

    private var workoutColor: Color {
        workoutTypeColors.first ?? GQColors.primary
    }

    var body: some View {
        HStack(spacing: 10) {
            Text("\(setNumber)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(set.isCompleted ? workoutColor : GQColors.textSecondary)
                .frame(width: 22)

            VStack(spacing: 2) {
                HStack(spacing: 5) {
                    TextField("0", value: $set.weight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 62)
                        .padding(.vertical, 8)
                        .homeSocialCard(accent: workoutColor, cornerRadius: 8)
                    Text("lb")
                        .font(.system(size: 11))
                        .foregroundColor(GQColors.textTertiary)
                }

                if let prev = previousWeight, prev > 0, set.weight == 0 {
                    Text("prev \(Int(prev))")
                        .font(.system(size: 9))
                        .foregroundColor(GQColors.textTertiary)
                }
            }

            VStack(spacing: 2) {
                HStack(spacing: 5) {
                    TextField("0", value: $set.reps, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 56)
                        .padding(.vertical, 8)
                        .homeSocialCard(accent: workoutColor, cornerRadius: 8)
                    Text("reps")
                        .font(.system(size: 11))
                        .foregroundColor(GQColors.textTertiary)
                }

                if let prev = previousReps, prev > 0, set.reps == 0 {
                    Text("prev \(prev)")
                        .font(.system(size: 9))
                        .foregroundColor(GQColors.textTertiary)
                }
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    set.isCompleted.toggle()
                    if set.isCompleted {
                        justCompleted = true
                        showCheckParticles = true
                        #if canImport(UIKit)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        #endif
                        onComplete?()
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(600))
                            justCompleted = false
                            showCheckParticles = false
                        }
                    }
                }

                if set.isCompleted {
                    HapticManager.shared.setComplete(setNumber: setNumber, totalSets: totalSets)
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.45)) {
                        checkScale = 1.28
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) {
                            checkScale = 1.0
                        }
                    }
                    onComplete?()
                }
            } label: {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 27))
                    .foregroundColor(set.isCompleted ? workoutColor : Color.white.opacity(0.35))
                    .scaleEffect(checkScale)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .homeSocialCard(
            accent: workoutColor,
            emphasized: set.isCompleted,
            cornerRadius: 10
        )
        .opacity(set.isCompleted ? 0.82 : 1.0)
    }
}

// MARK: - Add Exercise Sheet

struct AddExerciseToSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Binding var exercises: [ActiveExercise]
    let workoutType: WorkoutType

    @Query(sort: \FavoriteExercise.createdAt, order: .reverse) private var favorites: [FavoriteExercise]

    @State private var searchText = ""
    @State private var selectedMuscleGroup: MuscleGroup?
    @State private var heartScales: [String: CGFloat] = [:]

    private var historyService: ExerciseHistoryService {
        ExerciseHistoryService(modelContext: modelContext)
    }

    private var favoriteNames: Set<String> {
        Set(favorites.map(\.name))
    }

    private var recentlyUsedNames: [String] {
        historyService.recentlyUsedExercises(limit: 10)
    }

    private var recentlyUsed: [ExerciseMetadata] {
        recentlyUsedNames.compactMap { name in
            ExtendedExerciseDatabase.find(name)
        }
    }

    private var allFiltered: [ExerciseMetadata] {
        var results = ExtendedExerciseDatabase.exercises
        if let muscle = selectedMuscleGroup {
            results = results.filter { $0.muscleGroup == muscle }
        }
        if !searchText.isEmpty {
            results = results.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.muscleGroup.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }
        return results
    }

    private var favoriteExercises: [ExerciseMetadata] {
        let filtered = allFiltered
        let names = favoriteNames
        return filtered.filter { names.contains($0.name) }
    }

    private var recentFiltered: [ExerciseMetadata] {
        let filtered = allFiltered
        let names = favoriteNames
        let recentNames = Set(recentlyUsedNames)
        return filtered.filter { recentNames.contains($0.name) && !names.contains($0.name) }
    }

    private var remainingExercises: [ExerciseMetadata] {
        let favNames = favoriteNames
        let recentNames = Set(recentlyUsedNames)
        return allFiltered.filter { !favNames.contains($0.name) && !recentNames.contains($0.name) }
    }

    private var muscleGroupCounts: [MuscleGroup: Int] {
        var counts: [MuscleGroup: Int] = [:]
        for exercise in ExtendedExerciseDatabase.exercises {
            counts[exercise.muscleGroup, default: 0] += 1
        }
        return counts
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear

                VStack(spacing: 0) {
                    // Custom search bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16))
                            .foregroundColor(GQColors.textTertiary)
                        TextField("Search exercises...", text: $searchText)
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                                .environment(\.colorScheme, .dark)
                            RoundedRectangle(cornerRadius: 12)
                                .fill(GQColors.surfaceOverlay.opacity(0.78))
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(GQGradients.glassBorder, lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // Muscle group filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(title: "All", isSelected: selectedMuscleGroup == nil) {
                                selectedMuscleGroup = nil
                            }
                            ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                                let count = muscleGroupCounts[muscle] ?? 0
                                FilterChip(
                                    title: "\(muscle.rawValue) (\(count))",
                                    isSelected: selectedMuscleGroup == muscle
                                ) {
                                    selectedMuscleGroup = muscle
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }

                    // Exercise sections
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            // Favorites section
                            if !favoriteExercises.isEmpty {
                                exerciseSection(
                                    title: "Favorites",
                                    icon: "heart.fill",
                                    accentColor: GQColors.coralRed,
                                    exercises: favoriteExercises,
                                    startIndex: 0
                                )
                            }

                            // Recently Used section
                            if !recentFiltered.isEmpty {
                                exerciseSection(
                                    title: "Recently Used",
                                    icon: "clock.fill",
                                    accentColor: GQColors.cyanSpark,
                                    exercises: recentFiltered,
                                    startIndex: favoriteExercises.count
                                )
                            }

                            // All Exercises section
                            exerciseSection(
                                title: "All Exercises",
                                icon: "dumbbell.fill",
                                accentColor: GQColors.textSecondary,
                                exercises: remainingExercises,
                                startIndex: favoriteExercises.count + recentFiltered.count
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 40)
                    }
                }
            }
            .gqPageBackground()
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Section Builder

    @ViewBuilder
    private func exerciseSection(title: String, icon: String, accentColor: Color, exercises: [ExerciseMetadata], startIndex: Int) -> some View {
        if !exercises.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(accentColor)
                    Text(title.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(GQColors.textTertiary)
                        .tracking(1)
                }
                .padding(.leading, 4)
                .padding(.top, 8)

                ForEach(Array(exercises.enumerated()), id: \.element.id) { idx, exercise in
                    ExercisePickerCard(
                        exercise: exercise,
                        isFavorite: favoriteNames.contains(exercise.name),
                        historyService: historyService,
                        heartScale: heartScales[exercise.name] ?? 1.0,
                        onTap: { addExercise(exercise) },
                        onToggleFavorite: { toggleFavorite(exercise) }
                    )
                    .staggeredAppear(index: startIndex + idx, stagger: 0.04)
                }
            }
        }
    }

    // MARK: - Actions

    private func addExercise(_ metadata: ExerciseMetadata) {
        let lastData = historyService.lastPerformed(metadata.name)
        let sets: [ActiveSet]
        if let data = lastData {
            sets = (0..<3).map { _ in ActiveSet(reps: data.reps, weight: data.weight) }
        } else {
            sets = (0..<3).map { _ in ActiveSet(reps: 10, weight: 0) }
        }

        let exercise = ActiveExercise(
            name: metadata.name,
            muscleGroup: metadata.muscleGroup,
            sets: sets
        )
        exercises.append(exercise)
        dismiss()
    }

    private func toggleFavorite(_ metadata: ExerciseMetadata) {
        if let existing = favorites.first(where: { $0.name == metadata.name }) {
            modelContext.delete(existing)
        } else {
            let fav = FavoriteExercise(name: metadata.name, muscleGroup: metadata.muscleGroup.rawValue)
            modelContext.insert(fav)
        }

        // Spring scale animation
        heartScales[metadata.name] = 1.3
        HapticManager.shared.impact(.light)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                heartScales[metadata.name] = 1.0
            }
        }
    }
}

// MARK: - Exercise Picker Card

struct ExercisePickerCard: View {
    let exercise: ExerciseMetadata
    let isFavorite: Bool
    let historyService: ExerciseHistoryService
    let heartScale: CGFloat
    let onTap: () -> Void
    let onToggleFavorite: () -> Void

    private var lastData: (weight: Double, reps: Int, date: Date)? {
        historyService.lastPerformed(exercise.name)
    }

    private var prData: (weight: Double, reps: Int)? {
        historyService.personalBest(exercise.name)
    }

    private var muscleColor: Color {
        switch exercise.muscleGroup {
        case .chest: return GQColors.coralRed
        case .back: return GQColors.deepBlue
        case .shoulders: return GQColors.sunsetOrange
        case .biceps: return GQColors.vividPurple
        case .triceps: return Color.pink
        case .quads: return GQColors.success
        case .hamstrings: return Color.teal
        case .glutes: return Color.indigo
        case .calves: return GQColors.mint
        case .core: return GQColors.electricGold
        case .cardio: return GQColors.coralRed
        }
    }

    private var difficultyColor: Color {
        switch exercise.difficulty {
        case .beginner: return GQColors.success
        case .intermediate: return GQColors.electricGold
        case .advanced: return GQColors.sunsetOrange
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Top row: icon, name, heart, chevron
                HStack(spacing: 10) {
                    // Equipment icon in colored circle
                    ZStack {
                        Circle()
                            .fill(muscleColor.opacity(0.15))
                            .frame(width: 38, height: 38)
                        Image(systemName: exercise.equipment.icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(muscleColor)
                    }

                    Text(exercise.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()

                    // Heart button
                    Button(action: onToggleFavorite) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 18))
                            .foregroundColor(isFavorite ? GQColors.coralRed : GQColors.textTertiary)
                            .scaleEffect(heartScale)
                    }
                    .buttonStyle(.plain)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)
                }

                // Tags row: muscle group, equipment, difficulty
                HStack(spacing: 6) {
                    TagPill(text: exercise.muscleGroup.rawValue, color: muscleColor)
                    TagPill(text: exercise.equipment.rawValue, color: GQColors.textSecondary)
                    Circle()
                        .fill(difficultyColor)
                        .frame(width: 6, height: 6)
                    Text(exercise.difficulty.rawValue)
                        .font(.system(size: 11))
                        .foregroundColor(GQColors.textTertiary)
                }

                // History row (only if data exists)
                if let last = lastData {
                    HStack(spacing: 12) {
                        Text("Last: \(Int(last.weight)) lbs x \(last.reps)")
                            .font(.system(size: 12))
                            .foregroundColor(GQColors.textTertiary)

                        if let pr = prData, pr.weight > 0 {
                            Text("PR: \(Int(pr.weight)) lbs")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(GQColors.electricGold)
                        }
                    }
                }
            }
            .padding(12)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                    RoundedRectangle(cornerRadius: 12)
                        .fill(GQColors.surfaceOverlay.opacity(0.78))
                }
            )
            .overlay(
                ZStack {
                    // Left-edge muscle-color tint
                    LinearGradient(
                        colors: [muscleColor.opacity(0.06), .clear],
                        startPoint: .leading,
                        endPoint: .center
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    RoundedRectangle(cornerRadius: 12)
                        .stroke(GQGradients.glassBorder, lineWidth: 1)
                }
            )
        }
        .buttonStyle(GQInteractiveStyle())
    }
}

// MARK: - Tag Pill

struct TagPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .cornerRadius(6)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? .white : GQColors.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if isSelected {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [GQColors.primary, GQColors.primary.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: GQColors.primary.opacity(0.3), radius: 6, y: 2)
                        } else {
                            ZStack {
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .environment(\.colorScheme, .dark)
                                Capsule()
                                    .fill(Color.white.opacity(0.04))
                            }
                        }
                    }
                )
                .overlay(
                    Group {
                        if !isSelected {
                            Capsule()
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        }
                    }
                )
                .clipShape(Capsule())
        }
        .buttonStyle(GQInteractiveStyle())
    }
}

// MARK: - Exercise Form Demo Sheet

struct ExerciseFormDemoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let exerciseName: String

    var exerciseMetadata: ExerciseMetadata? {
        ExtendedExerciseDatabase.find(exerciseName)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Robot demo placeholder
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [GQColors.surfaceElevated, GQColors.surfaceBase],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(GQGradients.glassBorder, lineWidth: 1)
                            )
                            .frame(height: 250)

                        VStack(spacing: 16) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.8))

                            Text("AI Form Demo")
                                .font(.headline)
                                .foregroundColor(.white)

                            Text("Coming soon - animated form guide")
                                .font(.caption)
                                .foregroundColor(GQColors.textTertiary)
                        }
                    }
                    .gqScreenHorizontalPadding()

                    // Form cues
                    if let metadata = exerciseMetadata {
                        GlassCard(accentColor: GQColors.primary) {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("FORM CUES")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(GQColors.textTertiary)
                                    .tracking(1)

                                ForEach(metadata.cues, id: \.self) { cue in
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(GQColors.primary)
                                        Text(cue)
                                            .font(.system(size: 15))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .padding()
                        }
                        .gqScreenHorizontalPadding()

                        // Common mistakes
                        if !metadata.commonMistakes.isEmpty {
                            GlassCard(accentColor: GQColors.error) {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("COMMON MISTAKES")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(GQColors.textTertiary)
                                        .tracking(1)

                                    ForEach(metadata.commonMistakes, id: \.self) { mistake in
                                        HStack(alignment: .top, spacing: 12) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 16))
                                                .foregroundColor(.red)
                                            Text(mistake)
                                                .font(.system(size: 15))
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                                .padding()
                            }
                            .gqScreenHorizontalPadding()
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top)
            }
            .gqPageBackground()
            .navigationTitle(exerciseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Workout Completion Sheet

struct WorkoutSessionCompletionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState

    let exercises: [ActiveExercise]
    let duration: Int
    let workoutType: WorkoutType
    let profile: UserProfile
    let onDismiss: () -> Void
    var customTitle: String?

    var displayTitle: String {
        customTitle ?? workoutType.rawValue
    }

    @State private var caption = ""
    @State private var hasCompleted = false
    @State private var savedWorkout: Workout?
    @State private var showConfetti = false
    @State private var selectedEmotion: WorkoutEmotion? = nil

    // Media state
    @State private var mediaItems: [LocalMediaItem] = []
    @State private var selectedItems: [PhotosPickerItem] = []

    // Music state
    @State private var selectedSong: Song?
    @State private var showMusicPicker = false

    // Favorite state
    @State private var isFavoriteWorkout = false
    @State private var heartScale: CGFloat = 1.0

    // Share state
    @State private var shareToFeed = true
    @State private var showEnhancedEditor = false
    @State private var shareToCommunity = false
    @State private var taggedFriends: Set<String> = []

    // Legacy media state (single-photo picker)
    @State private var photoData: Data?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var mediaIsVideo = false
    @State private var videoData: Data?

    private var workoutTypeColors: [Color] {
        GQGradients.workoutGradientColors(for: workoutType)
    }

    private var workoutGradient: LinearGradient {
        GQGradients.workoutGradient(for: workoutType)
    }

    var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets.filter { $0.isCompleted }.count }
    }

    var totalVolume: Double {
        var volume: Double = 0
        for exercise in exercises {
            for set in exercise.sets where set.isCompleted {
                volume += set.weight * Double(set.reps)
            }
        }
        return volume
    }

    var topSetDisplay: String? {
        var best: (name: String, weight: Double, reps: Int)?
        for exercise in exercises {
            for set in exercise.sets where set.isCompleted && set.weight > 0 {
                if best == nil || set.weight > best!.weight {
                    best = (name: exercise.name, weight: set.weight, reps: set.reps)
                }
            }
        }
        guard let b = best else { return nil }
        return "\(b.name): \(Int(b.weight)) lbs x \(b.reps)"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear

                ScrollView {
                    VStack(spacing: 20) {
                        completionHeader
                            .staggeredAppear(index: 0, stagger: 0.1)
                        completionStats
                            .staggeredAppear(index: 1, stagger: 0.1)
                        WorkoutEmotionPicker(selectedEmotion: $selectedEmotion)
                            .padding(.horizontal, 16)
                            .staggeredAppear(index: 2, stagger: 0.1)
                        shareSection
                            .staggeredAppear(index: 3, stagger: 0.1)
                        saveButton
                            .staggeredAppear(index: 4, stagger: 0.1)

                        Spacer(minLength: 40)
                    }
                    .padding()
                }

                if showConfetti {
                    ConfettiView()
                        .allowsHitTesting(false)
                }
            }
            .gqPageBackground()
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss(); onDismiss() }
                }
            }
            .fullScreenCover(isPresented: $showEnhancedEditor) {
                enhancedEditorContent
            }
            .sheet(isPresented: $showMusicPicker) {
                MusicPickerSheet(selectedSong: $selectedSong, activityType: displayTitle)
            }
            .onAppear {
                showConfetti = true
                HapticManager.shared.workoutComplete()
            }
        }
    }

    // MARK: - Completion Sub-Views

    private var completionHeader: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                Spacer()

                VStack(spacing: 12) {
                    // Animated gradient circle with workout type icon
                    ZStack {
                        // Glow behind icon
                        Circle()
                            .fill((workoutTypeColors.first ?? GQColors.primary).opacity(0.15))
                            .frame(width: 120, height: 120)
                            .blur(radius: 30)

                        AnimatedGradientCircle(
                            size: 90,
                            lineWidth: 3,
                            colors: workoutTypeColors + [workoutTypeColors.first ?? GQColors.primary]
                        )

                        Image(systemName: workoutType.icon)
                            .font(.system(size: 36, weight: .medium))
                            .foregroundColor(workoutTypeColors.first ?? GQColors.primary)
                    }
                    .breathingFloat(intensity: 0.5)

                    GradientText(
                        "Workout Complete!",
                        gradient: workoutGradient,
                        font: .system(size: 28, weight: .bold)
                    )

                    Text(displayTitle)
                        .font(.system(size: 15))
                        .foregroundColor(GQColors.textSecondary)
                }

                Spacer()

                // Favorite toggle
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        isFavoriteWorkout.toggle()
                        heartScale = 1.3
                    }
                    HapticManager.shared.impact(.light)
                    savedWorkout?.isFavorite = isFavoriteWorkout
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                            heartScale = 1.0
                        }
                    }
                } label: {
                    Image(systemName: isFavoriteWorkout ? "heart.fill" : "heart")
                        .font(.system(size: 22))
                        .foregroundColor(isFavoriteWorkout ? GQColors.coralRed : GQColors.textTertiary)
                        .scaleEffect(heartScale)
                        .frame(width: 44, height: 44)
                }
            }
        }
        .padding(.top, 12)
    }

    private var completionStats: some View {
        VStack(spacing: 16) {
            // Section header
            HStack {
                Text("WORKOUT SUMMARY")
                    .font(GQTypography.sectionHeader)
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(1)
                Spacer()
            }

            GlassCard(accentColor: workoutTypeColors.first ?? GQColors.primary) {
                VStack(spacing: 16) {
                    HStack(spacing: 24) {
                        CompletionStatItem(
                            icon: "clock.fill",
                            iconColor: GQColors.cyanSpark,
                            value: "\(duration)",
                            label: "min"
                        )
                        CompletionStatItem(
                            icon: "checkmark.circle.fill",
                            iconColor: GQColors.success,
                            value: "\(totalSets)",
                            label: "sets"
                        )
                        CompletionStatItem(
                            icon: "figure.strengthtraining.traditional",
                            iconColor: workoutTypeColors.first ?? GQColors.primary,
                            value: "\(exercises.count)",
                            label: "exercises"
                        )
                    }

                    // Enhanced metrics row
                    HStack(spacing: 24) {
                        CompletionStatItem(
                            icon: "scalemass.fill",
                            iconColor: GQColors.sunsetOrange,
                            value: totalVolume >= 1000 ? String(format: "%.1fk", totalVolume / 1000) : "\(Int(totalVolume))",
                            label: "lbs vol"
                        )
                        if let top = topSetDisplay {
                            VStack(spacing: 4) {
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(GQColors.electricGold)
                                Text("Top Set")
                                    .font(.caption)
                                    .foregroundColor(GQColors.textSecondary)
                                Text(top)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(GQColors.electricGold)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
    }

    @ViewBuilder
    private var shareSection: some View {
        VStack(spacing: 16) {
            // Section header
            HStack {
                Text("SHARE")
                    .font(GQTypography.sectionHeader)
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(1)
                Spacer()
            }

            VStack(spacing: 16) {
                shareToggle
                if shareToFeed {
                    shareContent
                }
            }
            .padding(16)
            .homeSocialCard(accent: workoutTypeColors.first ?? GQColors.cyanSpark)
        }
    }

    private var shareToggle: some View {
        Toggle(isOn: $shareToFeed) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Share to Feed")
            }
        }
        .tint(GQColors.primary)
    }

    private var shareContent: some View {
        VStack(spacing: 16) {
            TextField("Add a caption...", text: $caption, axis: .vertical)
                .lineLimit(2...4)
                .padding(14)
                .homeSocialCard(cornerRadius: 12)

            MediaSection(
                mediaItems: $mediaItems,
                selectedItems: $selectedItems
            )

            MusicSelectorSection(
                selectedSong: $selectedSong,
                showMusicPicker: $showMusicPicker,
                activityType: displayTitle
            )

            customizePostButton
        }
        .onChange(of: selectedItems) { _, newItems in
            loadMedia(from: newItems)
        }
    }

    @ViewBuilder
    private var enhancedEditorContent: some View {
        if let workout = savedWorkout {
            EnhancedPostEditorView(
                profile: profile,
                workout: workout,
                exercises: makeCompletedExercises(),
                duration: duration
            )
        }
    }

    private func makeCompletedExercises() -> [CompletedExercise] {
        exercises.enumerated().map { idx, activeEx in
            CompletedExercise(
                name: activeEx.name,
                sets: activeEx.sets.filter { $0.isCompleted }.count,
                index: idx
            )
        }
    }

    private var customizePostButton: some View {
        Button {
            saveWorkoutOnly()
            showEnhancedEditor = true
        } label: {
            HStack(spacing: 12) {
                // Icon in circle
                ZStack {
                    Circle()
                        .fill(GQColors.cyanSpark.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(GQColors.cyanSpark)
                }

                Text("Customize Post")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(GQColors.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .homeSocialCard(accent: GQColors.cyanSpark, cornerRadius: 12)
        }
        .buttonStyle(GQInteractiveStyle())
    }

    private var saveButton: some View {
        Button {
            saveWorkout()
        } label: {
            HStack {
                Image(systemName: hasCompleted ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                Text(hasCompleted ? "Saved!" : "Quick Save")
            }
            .font(.system(size: 16, weight: .bold))
        }
        .disabled(hasCompleted)
        .buttonStyle(HomeSocialPrimaryButtonStyle(accent: workoutTypeColors.first ?? GQColors.cyanSpark, cornerRadius: 18))
        .gqScreenHorizontalPadding()
    }

    private func loadMedia(from items: [PhotosPickerItem]) {
        guard !items.isEmpty else {
            mediaItems = []
            return
        }
        Task {
            var newMedia: [LocalMediaItem] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    #if canImport(UIKit)
                    if let image = UIImage(data: data) {
                        newMedia.append(LocalMediaItem(data: data, image: image, isVideo: false))
                    } else {
                        newMedia.append(LocalMediaItem(data: data, image: nil, isVideo: true))
                    }
                    #endif
                }
            }
            await MainActor.run {
                mediaItems = newMedia
            }
        }
    }

    // MARK: - Caption

    @ViewBuilder
    private var captionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CAPTION")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(GQColors.textTertiary)
                .tracking(1)

            TextField("What's on your mind?", text: $caption, axis: .vertical)
                .lineLimit(3...6)
                .padding(12)
                .background(Color.white.opacity(0.06))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        }
    }

    // MARK: - Media

    @ViewBuilder
    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MEDIA")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(GQColors.textTertiary)
                .tracking(1)

            if let photo = photoData {
                #if canImport(UIKit)
                mediaThumbnail(photo)
                #endif
            } else {
                PhotosPicker(selection: $selectedPhotoItem, matching: .any(of: [.images, .videos])) {
                    HStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 20))
                            .foregroundColor(GQColors.cyanSpark)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add Photo or Video")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                            Text("Show off your workout")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    #if canImport(UIKit)
    @ViewBuilder
    private func mediaThumbnail(_ data: Data) -> some View {
        ZStack(alignment: .topTrailing) {
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 180)
                    .clipped()
                    .cornerRadius(12)
            }

            if mediaIsVideo {
                Image(systemName: "video.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(6)
                    .padding(8)
            }

            // Remove button
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    photoData = nil
                    videoData = nil
                    selectedPhotoItem = nil
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .background(Circle().fill(Color.black.opacity(0.5)))
            }
            .buttonStyle(.plain)
            .padding(8)
        }
    }
    #endif

    // MARK: - Music

    @ViewBuilder
    private var musicSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MUSIC")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(GQColors.textTertiary)
                .tracking(1)

            if let song = selectedSong {
                HStack(spacing: 10) {
                    Image(systemName: "music.note")
                        .font(.system(size: 14))
                        .foregroundColor(GQColors.cyanSpark)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        Text(song.artist)
                            .font(.system(size: 11))
                            .foregroundColor(GQColors.textSecondary)
                    }
                    Spacer()
                    Button {
                        showMusicPicker = true
                    } label: {
                        Text("Change")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(GQColors.cyanSpark)
                    }
                    .buttonStyle(.plain)
                    Button {
                        withAnimation { selectedSong = nil }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(GQColors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(GQColors.cyanSpark.opacity(0.08))
                .cornerRadius(12)
            } else {
                Button { showMusicPicker = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 20))
                            .foregroundColor(GQColors.cyanSpark)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add a Song or Playlist")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                            Text("What did you listen to?")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Tag Friends

    @ViewBuilder
    private var tagFriendsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TAG FRIENDS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(GQColors.textTertiary)
                .tracking(1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recentFriends, id: \.name) { friend in
                        let isTagged = taggedFriends.contains(friend.name)
                        Button {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                if isTagged {
                                    taggedFriends.remove(friend.name)
                                } else {
                                    taggedFriends.insert(friend.name)
                                }
                            }
                        } label: {
                            VStack(spacing: 5) {
                                ZStack {
                                    Circle()
                                        .fill(isTagged ? GQGradients.primary : LinearGradient(colors: [Color.white.opacity(0.1)], startPoint: .top, endPoint: .bottom))
                                        .frame(width: 48, height: 48)
                                        .overlay(
                                            Text(String(friend.name.prefix(1)))
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(.white)
                                        )

                                    if isTagged {
                                        Circle()
                                            .stroke(GQColors.cyanSpark, lineWidth: 2)
                                            .frame(width: 52, height: 52)
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(GQColors.cyanSpark)
                                            .background(Circle().fill(Color.black).frame(width: 12, height: 12))
                                            .offset(x: 18, y: 18)
                                    }
                                }
                                Text(friend.name.split(separator: " ").first.map(String.init) ?? friend.name)
                                    .font(.system(size: 11))
                                    .foregroundColor(isTagged ? .white : .gray)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var recentFriends: [(name: String, id: UUID)] {
        [
            (name: "Alex K.", id: UUID()),
            (name: "Jordan M.", id: UUID()),
            (name: "Sam R.", id: UUID()),
            (name: "Taylor W.", id: UUID()),
        ]
    }

    // MARK: - Community Toggle

    @ViewBuilder
    private var communityToggle: some View {
        Toggle(isOn: $shareToCommunity) {
            HStack(spacing: 10) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 16))
                    .foregroundColor(GQColors.vividPurple)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Post to Community")
                        .font(.system(size: 14, weight: .medium))
                    Text("Share with your gym community")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
        }
        .tint(GQColors.vividPurple)
        .padding(14)
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Primary: Share & Save
            Button { shareAndSave() } label: {
                HStack(spacing: 8) {
                    Image(systemName: hasCompleted ? "checkmark.circle.fill" : "paperplane.fill")
                    Text(hasCompleted ? "Shared!" : "Share & Save")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [GQColors.vividPurple, GQColors.cyanSpark],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(22)
            }
            .disabled(hasCompleted)
            .buttonStyle(.plain)

            // Secondary: Save without sharing
            Button { saveOnly() } label: {
                Text("Save Without Sharing")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
            }
            .disabled(hasCompleted)
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }

    // MARK: - Media Loading

    private func loadSelectedMedia(from item: PhotosPickerItem?) {
        guard let item = item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await MainActor.run {
                    #if canImport(UIKit)
                    if UIImage(data: data) != nil {
                        photoData = data
                        mediaIsVideo = false
                    } else {
                        videoData = data
                        photoData = data // thumbnail placeholder
                        mediaIsVideo = true
                    }
                    #endif
                }
            }
        }
    }

    // MARK: - Save Actions

    private func shareAndSave() {
        let workoutExercises = exercises.map { activeExercise -> Exercise in
            let sets = activeExercise.sets.filter { $0.isCompleted }.enumerated().map { index, activeSet in
                ExerciseSet(
                    reps: activeSet.reps,
                    weight: activeSet.weight,
                    order: index
                )
            }
            return Exercise(
                name: activeExercise.name,
                muscleGroup: activeExercise.muscleGroup,
                sets: sets
            )
        }

        let workout = Workout(
            type: workoutType,
            duration: duration,
            exercises: workoutExercises,
            isFavorite: isFavoriteWorkout
        )
        modelContext.insert(workout)

        let captionText = caption.isEmpty
            ? "Just finished a \(displayTitle) workout!"
            : caption

        // Create post with all the rich data
        let post = Post(
            authorId: profile.id,
            authorName: profile.name,
            authorUsername: profile.username,
            caption: captionText,
            photoData: photoData,
            videoData: videoData,
            workoutType: displayTitle,
            duration: duration,
            setCount: totalSets,
            songTitle: selectedSong?.title,
            artistName: selectedSong?.artist,
            taggedUsernames: Array(taggedFriends),
            workoutEmotion: selectedEmotion?.rawValue
        )
        modelContext.insert(post)

        // Add XP (bonus for sharing)
        let xpEarned = 25 + (totalSets * 5)
        _ = profile.addXP(xpEarned)

        try? modelContext.save()

        withAnimation {
            hasCompleted = true
        }

        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    private func saveOnly() {
        let workoutExercises = exercises.map { activeExercise -> Exercise in
            let sets = activeExercise.sets.filter { $0.isCompleted }.enumerated().map { index, activeSet in
                ExerciseSet(
                    reps: activeSet.reps,
                    weight: activeSet.weight,
                    order: index
                )
            }
            return Exercise(
                name: activeExercise.name,
                muscleGroup: activeExercise.muscleGroup,
                sets: sets
            )
        }

        let workout = Workout(
            type: workoutType,
            duration: duration,
            exercises: workoutExercises,
            isFavorite: isFavoriteWorkout
        )
        modelContext.insert(workout)

        // Create post if sharing
        if shareToFeed {
            let post = Post(
                authorId: profile.id,
                authorName: profile.name,
                authorUsername: profile.username,
                caption: caption.isEmpty ? "Just finished a \(displayTitle) workout!" : caption,
                workoutType: displayTitle,
                duration: duration,
                setCount: totalSets,
                songTitle: selectedSong?.title,
                artistName: selectedSong?.artist
            )
            modelContext.insert(post)
        }

        // Add XP
        let xpEarned = 20 + (totalSets * 5)
        _ = profile.addXP(xpEarned)

        try? modelContext.save()

        withAnimation {
            hasCompleted = true
        }
    }

    /// Save workout to SwiftData without creating a post (used before opening enhanced editor).
    private func saveWorkoutOnly() {
        guard savedWorkout == nil else { return }
        let workoutExercises = exercises.map { activeExercise -> Exercise in
            let sets = activeExercise.sets.filter { $0.isCompleted }.enumerated().map { index, activeSet in
                ExerciseSet(
                    reps: activeSet.reps,
                    weight: activeSet.weight,
                    order: index
                )
            }
            return Exercise(
                name: activeExercise.name,
                muscleGroup: activeExercise.muscleGroup,
                sets: sets
            )
        }

        let workout = Workout(
            type: workoutType,
            duration: duration,
            exercises: workoutExercises,
            isFavorite: isFavoriteWorkout
        )
        modelContext.insert(workout)
        try? modelContext.save()
        savedWorkout = workout
    }

    /// Quick-save action (saves workout and optionally shares to feed).
    private func saveWorkout() {
        saveOnly()
    }
}

// MARK: - Completion Stat Item (with colored icon)

struct CompletionStatItem: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                    .blur(radius: 6)

                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
            }
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.caption)
                .foregroundColor(GQColors.textSecondary)
        }
    }
}

struct WorkoutStatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.caption)
                .foregroundColor(GQColors.textSecondary)
        }
    }
}

// MARK: - Compact Rest Timer Bar

struct CompactRestTimerBar: View {
    @Binding var restTimeRemaining: Int
    @Binding var restTimerTotal: Int
    @Binding var selectedRestDuration: Int
    let onSkip: () -> Void
    let onHide: () -> Void
    let onAdjust: (Int) -> Void

    @State private var showPills = false

    var progress: CGFloat {
        guard restTimerTotal > 0 else { return 0 }
        return CGFloat(restTimeRemaining) / CGFloat(restTimerTotal)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                // Mini circular progress
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 2.5)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(GQColors.primary, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: progress)
                }
                .frame(width: 28, height: 28)

                // Countdown
                Text("\(restTimeRemaining)s")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                    .monospacedDigit()

                Text("Rest")
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textTertiary)

                // Expand/collapse duration pills
                Button {
                    withAnimation(.spring(response: 0.25)) {
                        showPills.toggle()
                    }
                } label: {
                    Image(systemName: showPills ? "chevron.up" : "slider.horizontal.3")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(GQColors.textSecondary)
                        .padding(6)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Spacer()

                // Skip
                Button {
                    onSkip()
                } label: {
                    Text("Skip")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(GQColors.textSecondary)
                }
                .buttonStyle(.plain)

                // Hide
                Button {
                    onHide()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(GQColors.textTertiary)
                        .padding(6)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Duration pills — expandable
            if showPills {
                HStack(spacing: 6) {
                    ForEach([30, 45, 60, 90, 120, 180], id: \.self) { seconds in
                        Button {
                            onAdjust(seconds)
                        } label: {
                            Text(seconds < 60 ? "\(seconds)s" : "\(seconds / 60):\(String(format: "%02d", seconds % 60))")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(selectedRestDuration == seconds ? .white : GQColors.textTertiary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    selectedRestDuration == seconds
                                    ? GQColors.primary.opacity(0.4)
                                    : Color.white.opacity(0.06)
                                )
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Thin progress bar at the bottom
            GeometryReader { geo in
                Rectangle()
                    .fill(GQColors.primary.opacity(0.5))
                    .frame(width: geo.size.width * progress, height: 2)
                    .animation(.linear(duration: 1), value: progress)
            }
            .frame(height: 2)
        }
        .background(Color.white.opacity(0.03))
    }
}

// MARK: - Preview

#Preview {
    ActiveWorkoutView(profile: UserProfile(), workoutType: .push)
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
