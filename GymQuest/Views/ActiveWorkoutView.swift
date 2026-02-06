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

// MARK: - Workout Mood

enum WorkoutMood: String, CaseIterable {
    case energized = "Energized"
    case satisfied = "Satisfied"
    case exhausted = "Exhausted"
    case proud = "Proud"

    var emoji: String {
        switch self {
        case .energized: return "⚡️"
        case .satisfied: return "😊"
        case .exhausted: return "😮‍💨"
        case .proud: return "💪"
        }
    }
}

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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState

    let profile: UserProfile
    let initialWorkoutType: WorkoutType

    @State private var workoutType: WorkoutType
    @State private var exercises: [ActiveExercise] = []
    @State private var workoutStartTime = Date()
    @State private var showingAddExercise = false
    @State private var showingFormDemo: ActiveExercise?
    @State private var showingFormPeek = false
    @State private var formPeekExercise: FormExercise?
    @State private var showingCompletion = false
    @State private var elapsedTime = 0
    @State private var timer: Timer?

    // Rest timer state
    @State private var isResting = false
    @State private var restTimeRemaining = 0
    @State private var restTimerTotal = 60
    @State private var selectedRestDuration = 0 // 0 = auto, once user picks it sticks
    @State private var restTimerHidden = false
    @State private var restTimer: Timer?

    // Music
    @State private var workoutSong: Song? = nil
    @State private var showMusicPicker = false

    // Live broadcast
    @State private var isSharingLive = false

    var preloadedExercises: [ActiveExercise]?

    init(profile: UserProfile, workoutType: WorkoutType = .push, preloadedExercises: [ActiveExercise]? = nil) {
        self.profile = profile
        self.initialWorkoutType = workoutType
        self._workoutType = State(initialValue: workoutType)
        self.preloadedExercises = preloadedExercises
    }

    var completedSetsCount: Int {
        exercises.reduce(0) { $0 + $1.sets.filter { $0.isCompleted }.count }
    }

    var totalSetsCount: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }

    private var workoutAccentColor: Color {
        switch workoutType {
        case .push: return GQColors.vividPurple
        case .pull: return GQColors.cyanSpark
        case .legs: return GQColors.sunsetOrange
        case .upper: return GQColors.deepBlue
        case .lower: return GQColors.coralRed
        case .fullBody: return GQColors.success
        case .cardio: return GQColors.success
        case .rest: return GQColors.textSecondary
        }
    }

    private func isCurrentExercise(_ exercise: ActiveExercise) -> Bool {
        guard let first = exercises.first(where: { ex in
            ex.sets.contains(where: { !$0.isCompleted })
        }) else { return false }
        return first.id == exercise.id
    }

    var body: some View {
        ZStack {
            // Background with workout-type glow
            Color.black.ignoresSafeArea()
            RadialGradient(
                colors: [workoutAccentColor.opacity(0.12), Color.clear],
                center: .top,
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with timer and progress
                workoutHeader

                // "Inspired by" banner when following a shared workout
                if let inspiration = appState.workoutInspiration {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                        Text("Inspired by \(inspiration)")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(GQColors.cyanSpark)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(GQColors.cyanSpark.opacity(0.12))
                            .overlay(Capsule().stroke(GQColors.cyanSpark.opacity(0.25), lineWidth: 0.5))
                    )
                    .padding(.top, 6)
                }

                // Music bar
                musicBar

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
                        if exercises.isEmpty {
                            workoutEmptyState
                        }

                        ForEach($exercises) { $exercise in
                            ActiveExerciseCard(
                                exercise: $exercise,
                                accentColor: workoutAccentColor,
                                isActiveExercise: isCurrentExercise(exercise),
                                onShowDemo: { showFormPeek(for: exercise.name) },
                                onSetCompleted: { name in startRestTimer(exerciseName: name) }
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95, anchor: .bottom)),
                                removal: .opacity
                            ))
                        }

                        // Add exercise button
                        addExerciseButton
                    }
                    .padding(16)
                    .padding(.bottom, 100)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: exercises.count)
                }

                // Bottom bar
                bottomBar
            }
        }
        .onAppear {
            startTimer()
            if let preloaded = preloadedExercises ?? appState.preloadedExercises, exercises.isEmpty {
                exercises = preloaded
                appState.preloadedExercises = nil
            }
        }
        .onDisappear {
            timer?.invalidate()
            restTimer?.invalidate()
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isResting && !restTimerHidden)
        .sheet(isPresented: $showingAddExercise) {
            AddExerciseToSessionSheet(exercises: $exercises, workoutType: workoutType)
        }
        .sheet(isPresented: $showMusicPicker) {
            MusicPickerSheet(selectedSong: $workoutSong, activityType: workoutType.rawValue)
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
        .sheet(isPresented: $showingCompletion) {
            WorkoutSessionCompletionSheet(
                exercises: exercises,
                duration: elapsedTime / 60,
                workoutType: workoutType,
                profile: profile,
                onDismiss: { cleanupAndExit() }
            )
        }
    }

    // MARK: - Header

    private var workoutHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Button { cleanupAndExit() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
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
                        } else {
                            appState.liveWorkoutStatus = nil
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

                Spacer()

                // Workout type — frosted glass pill
                Menu {
                    ForEach(WorkoutType.allCases, id: \.self) { type in
                        Button(type.rawValue) { workoutType = type }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: workoutType.icon)
                        Text(workoutType.rawValue)
                        Image(systemName: "chevron.down").font(.caption)
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        ZStack {
                            Capsule().fill(.ultraThinMaterial).environment(\.colorScheme, .dark)
                            Capsule().fill(workoutAccentColor.opacity(0.15))
                        }
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(
                            LinearGradient(colors: [workoutAccentColor.opacity(0.5), workoutAccentColor.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                    )
                }

                Spacer()

                // Timer — glass capsule
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { appState.workoutTimerHidden.toggle() }
                } label: {
                    Group {
                        if appState.workoutTimerHidden {
                            Image(systemName: "timer").font(.system(size: 16)).foregroundColor(GQColors.textTertiary)
                        } else {
                            Text(formatTime(elapsedTime))
                                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                .foregroundColor(workoutAccentColor)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(workoutAccentColor.opacity(0.1)))
                    .overlay(Capsule().stroke(workoutAccentColor.opacity(0.2), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)

            // Animated progress bar
            AnimatedProgressBar(
                progress: totalSetsCount > 0 ? Double(completedSetsCount) / Double(totalSetsCount) : 0,
                height: 5,
                colors: [workoutAccentColor]
            )
            .padding(.horizontal)

            // Stats — glass pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    StatPill(icon: "figure.strengthtraining.traditional", value: "\(exercises.count)", label: "Exercises", color: workoutAccentColor)
                    StatPill(icon: "checkmark.circle", value: "\(completedSetsCount)/\(totalSetsCount)", label: "Sets",
                             color: completedSetsCount == totalSetsCount && totalSetsCount > 0 ? GQColors.success : workoutAccentColor)
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 16)
        .background(
            Color.black.opacity(0.85)
                .background(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
    }

    // MARK: - Music Bar

    @ViewBuilder
    private var musicBar: some View {
        if let song = workoutSong {
            HStack(spacing: 10) {
                MusicBadge(
                    songTitle: song.title,
                    artistName: song.artist,
                    isPlaying: true,
                    onTap: { showMusicPicker = true }
                )

                Button {
                    withAnimation(.easeOut(duration: 0.2)) { workoutSong = nil }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(GQColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        } else {
            Button { showMusicPicker = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "music.note")
                        .font(.system(size: 13))
                    Text("Add Music")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(GQColors.cyanSpark)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(GQColors.cyanSpark.opacity(0.1))
                        .overlay(Capsule().stroke(GQColors.cyanSpark.opacity(0.2), lineWidth: 0.5))
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    // MARK: - Add Exercise Button

    private var workoutEmptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: workoutType.icon)
                .font(.system(size: 48))
                .foregroundStyle(GQGradients.workoutGradient(for: workoutType))
                .padding(.top, 40)
            Text("Ready to crush \(workoutType.rawValue)?")
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
                    .foregroundStyle(LinearGradient(colors: [workoutAccentColor, workoutAccentColor.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                Text("Add Exercise")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.04)))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                    .foregroundColor(Color.white.opacity(0.15))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 16) {
            if exercises.last != nil {
                Button {
                    if let last = exercises.last { addSetToExercise(last) }
                } label: {
                    HStack(spacing: 6) { Image(systemName: "plus"); Text("Add Set") }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Button { finishWorkout() } label: {
                Text("Finish")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 22).fill(
                                LinearGradient(colors: [GQColors.vividPurple, GQColors.cyanSpark.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                            )
                            RoundedRectangle(cornerRadius: 22).fill(
                                LinearGradient(colors: [Color.white.opacity(0.15), Color.clear], startPoint: .top, endPoint: .center)
                            )
                        }
                    )
                    .shadow(color: GQColors.vividPurple.opacity(0.3), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            ZStack {
                Color.black.opacity(0.9).background(.ultraThinMaterial).environment(\.colorScheme, .dark)
                VStack { Rectangle().fill(LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)], startPoint: .leading, endPoint: .trailing)).frame(height: 0.5); Spacer() }
            }
        )
    }

    // MARK: - Helpers

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
        appState.workoutSong = workoutSong
        showingCompletion = true
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
        appState.isResting = true
        appState.restTimerTotal = duration
        appState.restTimeRemaining = duration

        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                restTimeRemaining -= 1
                appState.restTimeRemaining = restTimeRemaining
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
        appState.isResting = false
        appState.restTimeRemaining = 0
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
        appState.isResting = false
        appState.restTimeRemaining = 0
        appState.workoutTimerHidden = false
        appState.workoutInspiration = nil
        appState.workoutSong = nil
        appState.activeWorkoutType = nil
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
}

// MARK: - Active Exercise Card

struct ActiveExerciseCard: View {
    @Binding var exercise: ActiveExercise
    var accentColor: Color = GQColors.vividPurple
    var isActiveExercise: Bool = false
    let onShowDemo: () -> Void
    var onSetCompleted: ((String) -> Void)? = nil

    var completedCount: Int { exercise.sets.filter { $0.isCompleted }.count }
    var allComplete: Bool { !exercise.sets.isEmpty && completedCount == exercise.sets.count }

    var body: some View {
        GlassCard(accentColor: accentColor, cornerRadius: 14) {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.name)
                            .font(.system(size: isActiveExercise ? 19 : 17, weight: .bold))
                            .foregroundColor(.white)
                        Text(exercise.muscleGroup.rawValue)
                            .font(.system(size: 12))
                            .foregroundColor(GQColors.textTertiary)
                    }
                    Spacer()
                    Button(action: onShowDemo) {
                        Text("Form")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.08))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                            .cornerRadius(14)
                    }
                    .buttonStyle(.plain)

                    // Progress ring
                    ZStack {
                        Circle().stroke(Color.white.opacity(0.1), lineWidth: 2.5).frame(width: 28, height: 28)
                        Circle()
                            .trim(from: 0, to: exercise.sets.isEmpty ? 0 : CGFloat(completedCount) / CGFloat(exercise.sets.count))
                            .stroke(allComplete ? GQColors.success : accentColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .frame(width: 28, height: 28)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: completedCount)
                        Text("\(completedCount)").font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                    }
                }

                VStack(spacing: 8) {
                    ForEach($exercise.sets) { $set in
                        ActiveSetRow(
                            set: $set,
                            setNumber: exercise.sets.firstIndex(where: { $0.id == set.id })! + 1,
                            accentColor: accentColor,
                            onCompleted: { onSetCompleted?(exercise.name) }
                        )
                    }
                    Button {
                        let lastSet = exercise.sets.last
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            exercise.sets.append(ActiveSet(reps: lastSet?.reps ?? 10, weight: lastSet?.weight ?? 0))
                        }
                    } label: {
                        HStack { Image(systemName: "plus"); Text("Add Set") }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(GQColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.03))
                                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(style: StrokeStyle(lineWidth: 0.5, dash: [4, 4])).foregroundColor(Color.white.opacity(0.08)))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .overlay(
            Group {
                if isActiveExercise && !allComplete {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.clear, lineWidth: 0)
                        .animatedGradientBorder(cornerRadius: 14, lineWidth: 1.5, colors: [accentColor, GQColors.cyanSpark, accentColor], duration: 6.0)
                }
            }
        )
    }
}

// MARK: - Active Set Row

struct ActiveSetRow: View {
    @Binding var set: ActiveSet
    let setNumber: Int
    var accentColor: Color = GQColors.vividPurple
    var onCompleted: (() -> Void)? = nil

    @State private var justCompleted = false
    @State private var showCheckParticles = false

    var body: some View {
        HStack(spacing: 12) {
            Text("\(setNumber)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(set.isCompleted ? GQColors.success : GQColors.textSecondary)
                .frame(width: 24)

            HStack(spacing: 4) {
                TextField("0", value: $set.weight, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 60)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(set.isCompleted ? 0.04 : 0.08))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                    )
                Text("lbs").font(.system(size: 12)).foregroundColor(GQColors.textTertiary)
            }

            HStack(spacing: 4) {
                TextField("0", value: $set.reps, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 50)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(set.isCompleted ? 0.04 : 0.08))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                    )
                Text("reps").font(.system(size: 12)).foregroundColor(GQColors.textTertiary)
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
                        onCompleted?()
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(600))
                            justCompleted = false
                            showCheckParticles = false
                        }
                    }
                }
            } label: {
                ZStack {
                    if showCheckParticles { SetCompleteParticles(color: GQColors.success) }
                    Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 28))
                        .foregroundColor(set.isCompleted ? GQColors.success : Color.white.opacity(0.2))
                        .scaleEffect(justCompleted ? 1.3 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.4), value: justCompleted)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(justCompleted ? GQColors.success.opacity(0.08) : Color.clear)
                .animation(.easeOut(duration: 0.4), value: justCompleted)
        )
        .overlay(alignment: .leading) {
            if set.isCompleted {
                RoundedRectangle(cornerRadius: 2).fill(GQColors.success.opacity(0.5)).frame(width: 3)
                    .transition(.opacity.combined(with: .scale(scale: 0.5)))
            }
        }
    }
}

// MARK: - Set Complete Particles

struct SetCompleteParticles: View {
    let color: Color
    @State private var particles: [ParticleData] = []

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle().fill(particle.color).frame(width: particle.size, height: particle.size)
                    .offset(x: particle.x, y: particle.y).opacity(particle.opacity)
            }
        }
        .onAppear { createParticles() }
    }

    private func createParticles() {
        for i in 0..<6 {
            let angle = Double(i) * 60.0 * .pi / 180.0
            let distance = CGFloat.random(in: 15...30)
            let colors: [Color] = [color, color.opacity(0.7), color.opacity(0.5)]
            particles.append(ParticleData(id: UUID(), x: 0, y: 0, targetX: cos(angle) * distance, targetY: sin(angle) * distance,
                                          size: CGFloat.random(in: 3...6), color: colors.randomElement() ?? color, opacity: 1.0))
        }
        withAnimation(.easeOut(duration: 0.4)) {
            for i in particles.indices { particles[i].x = particles[i].targetX; particles[i].y = particles[i].targetY; particles[i].opacity = 0 }
        }
    }
}

// MARK: - Add Exercise Sheet

struct AddExerciseToSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var exercises: [ActiveExercise]
    let workoutType: WorkoutType

    @State private var searchText = ""
    @State private var selectedMuscleGroup: MuscleGroup?

    var filteredExercises: [ExerciseMetadata] {
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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Muscle group filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "All", isSelected: selectedMuscleGroup == nil) {
                            selectedMuscleGroup = nil
                        }
                        ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                            FilterChip(title: muscle.rawValue, isSelected: selectedMuscleGroup == muscle) {
                                selectedMuscleGroup = muscle
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }

                // Exercise list
                List {
                    ForEach(filteredExercises) { exercise in
                        Button {
                            addExercise(exercise)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(exercise.name)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.white)
                                    Text(exercise.muscleGroup.rawValue)
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }

                                Spacer()

                                Image(systemName: "plus.circle")
                                    .foregroundColor(GQColors.primary)
                            }
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                }
                .listStyle(.plain)
                .searchable(text: $searchText, prompt: "Search exercises")
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func addExercise(_ metadata: ExerciseMetadata) {
        let exercise = ActiveExercise(
            name: metadata.name,
            muscleGroup: metadata.muscleGroup,
            sets: [
                ActiveSet(reps: 10, weight: 0),
                ActiveSet(reps: 10, weight: 0),
                ActiveSet(reps: 10, weight: 0)
            ]
        )
        exercises.append(exercise)
        dismiss()
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
                .background(isSelected ? GQColors.primary : GQColors.cardBackground)
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
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
                    // Robot demo placeholder - flat TikTok style
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(GQColors.cardBackground)
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
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)

                    // Form cues
                    if let metadata = exerciseMetadata {
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
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                        .padding(.horizontal)

                        // Common mistakes
                        if !metadata.commonMistakes.isEmpty {
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
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top)
            }
            .background(Color.black.ignoresSafeArea())
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

    @State private var caption = ""
    @State private var hasCompleted = false
    @State private var savedWorkout: Workout?
    @State private var selectedMood: WorkoutMood? = nil

    // Media
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var photoData: Data? = nil
    @State private var videoData: Data? = nil
    @State private var mediaIsVideo = false

    // Music
    @State private var selectedSong: Song? = nil
    @State private var showMusicPicker = false

    // Tags & sharing
    @State private var taggedFriends: Set<String> = []
    @State private var shareToCommunity = false

    var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets.filter { $0.isCompleted }.count }
    }

    var totalVolume: Double {
        exercises.reduce(0.0) { total, exercise in
            total + exercise.sets.filter { $0.isCompleted }.reduce(0.0) { $0 + $1.weight * Double($1.reps) }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    completionHeader
                    completionStats
                    moodSelector
                    captionSection
                    mediaSection
                    musicSection
                    tagFriendsSection
                    communityToggle
                    actionButtons
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss(); onDismiss() }
                }
            }
            .sheet(isPresented: $showMusicPicker) {
                MusicPickerSheet(selectedSong: $selectedSong, activityType: workoutType.rawValue)
            }
            .onChange(of: selectedPhotoItem) { _, newValue in
                loadSelectedMedia(from: newValue)
            }
            .onAppear {
                if let song = appState.workoutSong {
                    selectedSong = song
                }
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var completionHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [GQColors.vividPurple, GQColors.cyanSpark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text("Workout Complete!")
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding(.top, 12)
    }

    // MARK: - Stats

    @ViewBuilder
    private var completionStats: some View {
        HStack(spacing: 24) {
            WorkoutStatItem(value: "\(duration)", label: "min")
            WorkoutStatItem(value: "\(totalSets)", label: "sets")
            WorkoutStatItem(value: "\(exercises.count)", label: "exercises")
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    // MARK: - Mood

    @ViewBuilder
    private var moodSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HOW DO YOU FEEL?")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(GQColors.textTertiary)
                .tracking(1)

            HStack(spacing: 10) {
                ForEach(WorkoutMood.allCases, id: \.self) { mood in
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            selectedMood = selectedMood == mood ? nil : mood
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(mood.emoji)
                                .font(.system(size: 26))
                            Text(mood.rawValue)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(selectedMood == mood ? .white : .gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedMood == mood ? GQColors.vividPurple.opacity(0.25) : Color.white.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedMood == mood ? GQColors.vividPurple.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                        .scaleEffect(selectedMood == mood ? 1.05 : 1.0)
                    }
                    .buttonStyle(.plain)
                }
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
            exercises: workoutExercises
        )
        modelContext.insert(workout)

        // Build mood string for caption
        let moodSuffix = selectedMood.map { " Feeling \($0.emoji) \($0.rawValue.lowercased())." } ?? ""
        let captionText = caption.isEmpty
            ? "Just finished a \(workoutType.rawValue) workout!\(moodSuffix)"
            : caption + moodSuffix

        // Create post with all the rich data
        let post = Post(
            authorId: profile.id,
            authorName: profile.name,
            authorUsername: profile.username,
            caption: captionText,
            photoData: photoData,
            videoData: videoData,
            workoutType: workoutType.rawValue,
            duration: duration,
            setCount: totalSets,
            songTitle: selectedSong?.title,
            artistName: selectedSong?.artist,
            taggedUsernames: Array(taggedFriends)
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
            exercises: workoutExercises
        )
        modelContext.insert(workout)

        let xpEarned = 20 + (totalSets * 5)
        _ = profile.addXP(xpEarned)

        try? modelContext.save()

        withAnimation {
            hasCompleted = true
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
