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

// MARK: - Coach Insight

struct CoachInsight: Identifiable {
    let id = UUID()
    let message: String
    let icon: String
    let tintColor: Color

    enum InsightType {
        case progress, suggestion, warning, celebration
    }
}

// MARK: - Workout Insight Engine

struct WorkoutInsightEngine {
    static func generateSetInsight(
        exerciseName: String,
        currentWeight: Double,
        currentReps: Int,
        previousWeight: Double?,
        previousReps: Int?,
        overloadSuggestion: OverloadSuggestion?
    ) -> CoachInsight? {
        guard currentWeight > 0, currentReps > 0 else { return nil }

        // Weight increase detection
        if let prevW = previousWeight, prevW > 0, currentWeight > prevW {
            let delta = Int(currentWeight - prevW)
            return CoachInsight(
                message: "You're lifting \(delta) lbs more than last session on \(exerciseName)!",
                icon: "flame.fill",
                tintColor: GQColors.deepBlue
            )
        }

        // Volume increase detection
        if let prevW = previousWeight, let prevR = previousReps, prevW > 0, prevR > 0 {
            let currentVol = currentWeight * Double(currentReps)
            let previousVol = prevW * Double(prevR)
            if currentVol > previousVol {
                let pctIncrease = Int(((currentVol - previousVol) / previousVol) * 100)
                if pctIncrease >= 5 {
                    return CoachInsight(
                        message: "Set volume up \(pctIncrease)% vs last session. Keep pushing!",
                        icon: "chart.line.uptrend.xyaxis",
                        tintColor: GQColors.deepBlue
                    )
                }
            }
        }

        // Same weight, encourage progression
        if let prevW = previousWeight, prevW > 0, currentWeight == prevW {
            if let suggestion = overloadSuggestion, suggestion.direction == .increase {
                return CoachInsight(
                    message: "Matching last session. Try \(Int(suggestion.suggestedWeight)) lbs next set?",
                    icon: "arrow.up.right",
                    tintColor: GQColors.deepBlue
                )
            }
        }

        return nil
    }
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
    @State private var showingCompletionChoice = false
    @State private var showingPostEditor = false
    @State private var savedWorkout: Workout?
    @State private var workoutMedia: [PostMedia] = []
    @State private var showingWorkoutCamera = false
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
    @State private var showingGymLocationPrompt = false
    @State private var partyService = WorkoutPartyService()
    @State private var locationService = LocationTrackingService.shared
    @State private var isTrackingLocation = false
    @State private var overloadSuggestions: [String: OverloadSuggestion] = [:]
    @State private var showingPostWorkoutPaywall = false
    @AppStorage("hasSeenPostWorkoutPaywall") private var hasSeenPostWorkoutPaywall = false

    // PR celebration state
    @State private var activePRBanner: LivePREvent?
    @State private var showPRConfetti = false
    @State private var livePRsDetected: [LivePREvent] = []
    @State private var prBannerTimer: Timer?

    // Completion experience state
    @State private var showingCompletionExperience = false
    @State private var detectedPRMoments: [PRMoment] = []
    @State private var didLevelUp = false
    @State private var previousLevel: Int = 0
    @State private var xpEarned: Int = 0

    // Coach insight state
    @State private var activeCoachInsight: CoachInsight?

    let customTitle: String?

    /// Display name: uses custom title for ".custom" workouts, otherwise the enum rawValue.
    var displayTitle: String {
        customTitle ?? workoutType.rawValue
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
        [GQColors.deepBlue, GQColors.vividPurple]
    }

    private var workoutAccentColor: Color {
        GQColors.deepBlue
    }

    private var workoutProgress: Double {
        guard totalSetsCount > 0 else { return 0 }
        return Double(completedSetsCount) / Double(totalSetsCount)
    }

    private func formatVolume(_ vol: Double) -> String {
        if vol >= 1000 {
            return String(format: "%.1fk", vol / 1000)
        }
        return "\(Int(vol))"
    }

    var body: some View {
        ZStack {
            // Visual distinction: subtle accent gradient (Apple HIG workout indicator)
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [workoutAccentColor.opacity(0.12), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 200)
                .ignoresSafeArea(edges: .top)
                Spacer()
            }

            VStack(spacing: 0) {
                // Header with timer and progress
                workoutHeader
                    .padding(.horizontal, GQLayout.screenHorizontal)

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
                        onAdjust: { seconds in adjustRestDuration(seconds) },
                        accentColor: workoutAccentColor
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Coach insight card during rest
                if isResting, let insight = activeCoachInsight {
                    CoachInsightCard(message: insight.message, icon: insight.icon, tintColor: insight.tintColor)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Live GPS stats bar for cardio tracking
                if isTrackingLocation {
                    LiveGPSStatsBar(
                        distance: locationService.currentDistance,
                        pace: locationService.currentPace
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
                                onShowDemo: { showFormPeek(for: exercise.name) },
                                onSetCompleted: { exerciseName in
                                    startRestTimer(exerciseName: exerciseName)
                                    WorkoutDraft.save(workoutType: workoutType, customTitle: customTitle, startTime: workoutStartTime, exercises: exercises)
                                },
                                overloadSuggestion: overloadSuggestions[exercise.name],
                                onPRDetected: { pr in
                                    handleLivePR(pr)
                                }
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
                    .zIndex(1)
            }

            // Floating reactions overlay
            if isSharingLive && partyService.isActive {
                FloatingReactionsOverlay(reactions: partyService.activeReactions)
                    .allowsHitTesting(false)
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

            // PR celebration banner overlay
            if let pr = activePRBanner {
                VStack {
                    LivePRBanner(
                        exerciseName: pr.exerciseName,
                        prType: pr.type.label,
                        delta: pr.displayDelta
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
                .padding(.top, 60)
            }

            // Mini confetti burst for PRs
            if showPRConfetti {
                MiniConfettiBurst()
                    .allowsHitTesting(false)
            }

            #if canImport(UIKit)
            // Floating buttons (camera + voice coach)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        // Camera button
                        Button { showingWorkoutCamera = true } label: {
                            ZStack {
                                Circle()
                                    .fill(GQColors.surfaceBase)
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        Circle().stroke(GQColors.borderDefault, lineWidth: 1)
                                    )
                                    .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(GQGradients.primary)

                                // Badge
                                if !workoutMedia.isEmpty {
                                    Text("\(workoutMedia.count)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 18, height: 18)
                                        .background(GQColors.vividPurple)
                                        .clipShape(Circle())
                                        .offset(x: 16, y: -16)
                                }
                            }
                        }

                        // Voice coach
                        if FeatureFlags.shared.voiceCoachEnabled {
                            VoiceCoachButton(
                                exercises: exercises,
                                currentExerciseName: exercises.first(where: { !$0.sets.allSatisfy(\.isCompleted) })?.name,
                                profile: profile,
                                allWorkouts: (try? modelContext.fetch(FetchDescriptor<Workout>())) ?? []
                            )
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 100)
                }
            }
            #endif
        }
        .gqPageBackground()
        .onAppear {
            initializeFromAppState()
            startTimer()
            loadOverloadSuggestions()
            if !FeatureFlags.shared.hasSeenGymLocationPrompt {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    showingGymLocationPrompt = true
                }
            }
            // Auto-start GPS for cardio/HIIT workouts
            if workoutType.isGPSEligible {
                if locationService.hasPermission {
                    locationService.startTracking()
                    isTrackingLocation = true
                } else if locationService.needsPermission {
                    locationService.requestPermission()
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            restTimer?.invalidate()
            prBannerTimer?.invalidate()
            partyService.stopParty()
            if isTrackingLocation {
                locationService.stopTracking()
                isTrackingLocation = false
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isResting && !restTimerHidden)
        .sheet(isPresented: $showingAddExercise) {
            AddExerciseToSessionSheet(exercises: $exercises, workoutType: workoutType)
        }
        .onChange(of: exercises.count) {
            WorkoutDraft.save(workoutType: workoutType, customTitle: customTitle, startTime: workoutStartTime, exercises: exercises)
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
            WorkoutDraft.clear()
            if !hasSeenPostWorkoutPaywall {
                hasSeenPostWorkoutPaywall = true
                showingPostWorkoutPaywall = true
            } else {
                appState.selectedTab = .feed
                appState.endWorkout()
            }
        }) {
            if let workout = savedWorkout {
                EnhancedPostEditorView(
                    profile: profile,
                    workout: workout,
                    exercises: makeCompletedExercises(),
                    duration: elapsedTime / 60,
                    preloadedMedia: workoutMedia
                )
            }
        }
        .confirmationDialog(
            "Workout Options",
            isPresented: $showingCancelConfirmation,
            titleVisibility: .visible
        ) {
            Button("Pause Workout") {
                appState.pauseWorkout()
            }
            Button("End Workout", role: .destructive) {
                timer?.invalidate()
                WorkoutDraft.clear()
                appState.endWorkout()
            }
            Button("Keep Going", role: .cancel) {}
        } message: {
            Text("Pause to come back later, or end to discard this workout.")
        }
        .fullScreenCover(isPresented: $showingCompletionExperience) {
            if let workout = savedWorkout {
                WorkoutCompletionExperience(
                    workout: workout,
                    exercises: exercises,
                    duration: elapsedTime,
                    livePRs: livePRsDetected,
                    detectedPRMoments: detectedPRMoments,
                    didLevelUp: didLevelUp,
                    previousLevel: previousLevel,
                    newLevel: profile.level,
                    xpEarned: xpEarned,
                    profile: profile,
                    workoutType: workoutType,
                    onSharePost: {
                        showingCompletionExperience = false
                        showingPostEditor = true
                    },
                    onDone: {
                        WorkoutDraft.clear()
                        showingCompletionExperience = false
                        if !hasSeenPostWorkoutPaywall {
                            hasSeenPostWorkoutPaywall = true
                            showingPostWorkoutPaywall = true
                        } else {
                            appState.selectedTab = .feed
                            appState.endWorkout()
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showingPostWorkoutPaywall, onDismiss: {
            appState.selectedTab = .feed
            appState.endWorkout()
        }) {
            PaywallView()
                .environmentObject(SubscriptionService.shared)
        }
        .sheet(isPresented: $showingWorkoutCamera) {
            WorkoutCameraSheet(workoutMedia: $workoutMedia)
        }
        .alert("Share Gym Location?", isPresented: $showingGymLocationPrompt) {
            Button("Share Location") {
                FeatureFlags.shared.gymLocationSharing = true
                FeatureFlags.shared.hasSeenGymLocationPrompt = true
            }
            Button("Not Now", role: .cancel) {
                FeatureFlags.shared.gymLocationSharing = false
                FeatureFlags.shared.hasSeenGymLocationPrompt = true
            }
        } message: {
            Text("Let friends see which gym you're at during workouts. You can change this anytime in Settings.")
        }
    }

    // MARK: - Header

    private var workoutHeader: some View {
        VStack(spacing: 12) {
            // Row 1: Title + End
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayTitle)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(GQColors.textPrimary)

                    HStack(spacing: 8) {
                        Label(formatVolume(totalVolume), systemImage: "chart.bar.fill")
                        Text("·").foregroundColor(GQColors.textTertiary)
                        Label("\(completedSetsCount)/\(totalSetsCount) sets", systemImage: "checkmark.circle")
                        Text("·").foregroundColor(GQColors.textTertiary)
                        Label("\(exercises.count) exercises", systemImage: "dumbbell")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textSecondary)
                }

                Spacer()

                // Broadcast
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
                        .font(.system(size: 14))
                        .foregroundColor(isSharingLive ? GQColors.deepBlue : GQColors.textTertiary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)

                // End
                Button {
                    showingCancelConfirmation = true
                } label: {
                    Text("End")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(GQColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - Hero Timer Ring

    @ViewBuilder
    private var heroTimerRing: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(GQColors.borderDefault, lineWidth: 8)

            // Animated progress ring
            Circle()
                .trim(from: 0, to: workoutProgress)
                .stroke(
                    LinearGradient(
                        colors: workoutTypeColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: workoutProgress)

            // Timer text inside ring
            VStack(spacing: 2) {
                Text(formatTime(elapsedTime))
                    .font(GQTypography.heroNumber)
                    .monospacedDigit()
                    .foregroundColor(GQColors.textPrimary)
                    .contentTransition(.numericText())

                Text("\(completedSetsCount)/\(totalSetsCount) sets")
                    .font(GQTypography.micro)
                    .foregroundStyle(GQColors.textTertiary)
            }
        }
        .frame(width: 140, height: 140)
    }

    // MARK: - Type Badge

    @ViewBuilder
    private var typeBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: workoutType.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(GQGradients.primary)
            Text(displayTitle)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(GQColors.textPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            Capsule().fill(GQColors.surfaceBase)
        )
        .overlay(
            Capsule().stroke(GQColors.borderDefault, lineWidth: 1)
        )
        .contextMenu {
            ForEach(WorkoutType.allCases, id: \.self) { type in
                Button {
                    workoutType = type
                } label: {
                    Label(type.rawValue, systemImage: type.icon)
                }
            }
        }
    }

    // MARK: - Stat Chips

    @ViewBuilder
    private var statChips: some View {
        HStack(spacing: 8) {
            WorkoutFlowMetricChip(
                icon: "chart.bar.fill",
                value: formatVolume(totalVolume),
                label: "Volume",
                color: GQColors.deepBlue,
                compact: true
            )
            Circle()
                .fill(GQColors.textTertiary)
                .frame(width: 3, height: 3)
            WorkoutFlowMetricChip(
                icon: "checkmark.circle.fill",
                value: "\(completedSetsCount)/\(totalSetsCount)",
                label: "Sets",
                color: GQColors.deepBlue,
                compact: true
            )
            Circle()
                .fill(GQColors.textTertiary)
                .frame(width: 3, height: 3)
            WorkoutFlowMetricChip(
                icon: "dumbbell.fill",
                value: "\(exercises.count)",
                label: "Exercises",
                color: GQColors.deepBlue,
                compact: true
            )
        }
    }

    // MARK: - Add Exercise Button

    private var workoutEmptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: workoutType.icon)
                .font(.system(size: 48))
                .foregroundStyle(GQGradients.primary)
                .padding(.top, 40)
            Text("Ready to crush \(displayTitle)?")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(GQColors.textPrimary)
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
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(GQColors.deepBlue.opacity(0.10))
                        .frame(width: 32, height: 32)
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(GQGradients.primary)
                }
                Text("Add Exercise")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(GQColors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(GQColors.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .homeSocialCard(cornerRadius: 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(GQInteractiveStyle())
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        Button { finishWorkout() } label: {
            Text("Finish Workout")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Capsule().fill(GQGradients.primary))
        }
        .buttonStyle(GQInteractiveStyle())
        .padding(.horizontal, 32)
        .padding(.bottom, 80)
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

    private func loadOverloadSuggestions() {
        guard FeatureFlags.shared.progressiveOverloadEnabled else { return }
        let descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        guard let allWorkouts = try? modelContext.fetch(descriptor) else { return }
        overloadSuggestions = ProgressiveOverloadService.shared.getSuggestions(
            exercises: exercises,
            allWorkouts: allWorkouts,
            profile: profile
        )
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
                    rpe: activeSet.rpe,
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

        // Save GPS route data for cardio workouts
        if isTrackingLocation {
            let points = locationService.stopTracking()
            isTrackingLocation = false
            if !points.isEmpty {
                workout.routePoints = points
                workout.totalDistance = locationService.currentDistance
                workout.elevationGain = locationService.currentElevationGain
                let durationSec = Double(elapsedTime)
                let distKm = locationService.currentDistance / 1000.0
                workout.averagePace = distKm > 0 ? durationSec / distKm : nil
            }
        }

        modelContext.insert(workout)

        // Sync workout to Supabase
        if FeatureFlags.shared.supabaseSyncEnabled {
            Task {
                do {
                    try await SupabaseSyncService.shared.syncWorkout(workout)
                } catch {
                    print("[WorkoutSync] Failed to sync workout: \(error)")
                }
            }
        }

        // Track level before XP to detect level-up
        previousLevel = profile.level
        let earnedXP = 20 + (exercises.reduce(0) { $0 + $1.sets.filter { $0.isCompleted }.count } * 5)
        xpEarned = earnedXP
        didLevelUp = profile.addXP(earnedXP)

        try? modelContext.save()

        // Detect post-hoc PRs
        let allWorkouts = (try? modelContext.fetch(FetchDescriptor<Workout>())) ?? []
        let prResult = PRService.shared.detectAllPRs(
            workout: workout,
            allWorkouts: allWorkouts,
            profile: profile,
            modelContext: modelContext
        )
        detectedPRMoments = prResult.moments

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

        // Generate coach insight for this rest period
        if let activeExercise = exercises.first(where: { $0.name == exerciseName }),
           let lastCompletedSet = activeExercise.sets.last(where: { $0.isCompleted }) {
            let insight = WorkoutInsightEngine.generateSetInsight(
                exerciseName: exerciseName,
                currentWeight: lastCompletedSet.weight,
                currentReps: lastCompletedSet.reps,
                previousWeight: nil, // loaded per-card, use overload suggestion context
                previousReps: nil,
                overloadSuggestion: overloadSuggestions[exerciseName]
            )
            withAnimation(.easeInOut(duration: 0.3)) {
                activeCoachInsight = insight
            }
        }

        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                restTimeRemaining -= 1
                // Countdown haptic beats at 3, 2, 1
                if restTimeRemaining > 0 && restTimeRemaining <= 3 {
                    HapticManager.shared.countdownBeat()
                }
                if restTimeRemaining <= 0 {
                    endRest()
                    HapticManager.shared.restTimerDone()
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
        withAnimation(.easeOut(duration: 0.2)) {
            activeCoachInsight = nil
        }
    }

    // MARK: - Live PR Handling

    private func handleLivePR(_ pr: LivePREvent) {
        livePRsDetected.append(pr)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
            activePRBanner = pr
            showPRConfetti = true
        }
        HapticManager.shared.prDetected()

        prBannerTimer?.invalidate()
        prBannerTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { _ in
            Task { @MainActor in
                withAnimation(.easeOut(duration: 0.3)) {
                    activePRBanner = nil
                    showPRConfetti = false
                }
            }
        }
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

// MARK: - Exercise Notes Field

struct ExerciseNotesField: View {
    @Binding var notes: String
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "note.text")
                        .font(.system(size: 12))
                        .foregroundColor(notes.isEmpty ? GQColors.textTertiary : GQColors.textPrimary)
                    Text(notes.isEmpty ? "Add note" : "Note")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(notes.isEmpty ? GQColors.textTertiary : GQColors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                TextField("e.g., felt tight in left shoulder", text: $notes, axis: .vertical)
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.textPrimary)
                    .lineLimit(1...4)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(GQColors.surfaceOverlay))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(GQColors.borderDefault, lineWidth: 1))
                    .padding(.top, 8)
            }
        }
    }
}

// MARK: - Plate Calculator

struct PlateCalculatorView: View {
    let targetWeight: Double
    let barWeight: Double = 45.0

    private var plates: [(weight: Double, count: Int)] {
        let availablePlates: [Double] = [45, 25, 10, 5, 2.5]
        var remaining = max(0, (targetWeight - barWeight) / 2.0)
        var result: [(Double, Int)] = []

        for plate in availablePlates {
            let count = Int(remaining / plate)
            if count > 0 {
                result.append((plate, count))
                remaining -= Double(count) * plate
            }
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: "scalemass")
                    .font(.system(size: 13, weight: .semibold))
                Text("Plates per side")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(GQColors.textPrimary)

            if targetWeight <= barWeight {
                Text("Bar only (\(Int(barWeight)) lbs)")
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textSecondary)
            } else {
                HStack(spacing: 8) {
                    ForEach(plates, id: \.weight) { plate in
                        HStack(spacing: 3) {
                            Text("\(plate.count)\u{00D7}")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(GQColors.textSecondary)
                            Text(plate.weight.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(plate.weight))" : String(format: "%.1f", plate.weight))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(GQColors.textPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(GQColors.deepBlue.opacity(0.10))
                                )
                        }
                    }
                }

                Text("+ \(Int(barWeight)) lb bar")
                    .font(.system(size: 11))
                    .foregroundColor(GQColors.textTertiary)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(GQColors.surfaceOverlay))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(GQColors.borderDefault, lineWidth: 1))
    }
}

// MARK: - Active Exercise Card

struct ActiveExerciseCard: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var exercise: ActiveExercise
    let workoutTypeColors: [Color]
    let onShowDemo: () -> Void
    var onSetCompleted: ((String) -> Void)? = nil
    var overloadSuggestion: OverloadSuggestion? = nil
    var onPRDetected: ((LivePREvent) -> Void)? = nil

    @State private var previousWeight: Double?
    @State private var previousReps: Int?
    @State private var bestWeight: Double?
    @State private var bestReps: Int?
    @State private var best1RM: Double?
    @State private var showPlateCalculator = false
    @State private var prFiredForExercise = false
    @State private var showExerciseDemo = false

    var completedCount: Int {
        exercise.sets.filter { $0.isCompleted }.count
    }

    var allSetsComplete: Bool {
        completedCount == exercise.sets.count && completedCount > 0
    }

    private var workoutAccent: Color { GQColors.textSecondary }

    var body: some View {
        VStack(spacing: 0) {
            // Exercise header
            HStack(alignment: .center, spacing: 12) {
                Button { showExerciseDemo = true } label: {
                    if FeatureFlags.shared.exerciseGifsEnabled {
                        ExerciseGifView(exerciseName: exercise.name, size: .detail, showFallback: true)
                    } else {
                        ZStack {
                            Circle().fill(GQColors.deepBlue.opacity(0.10))
                                .frame(width: 40, height: 40)
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(GQGradients.primary)
                        }
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(GQColors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(exercise.muscleGroup.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(GQColors.textTertiary)

                        if let pw = previousWeight, pw > 0 {
                            Text("·")
                                .foregroundColor(GQColors.textTertiary)
                            Text("Last: \(Int(pw)) lbs")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(GQColors.textTertiary)
                        }
                    }
                }

                Spacer()

                Text("\(completedCount)/\(exercise.sets.count)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(allSetsComplete ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(GQColors.textTertiary))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            // Sets
            VStack(spacing: 0) {
                // Column headers
                HStack(spacing: 0) {
                    Text("SET")
                        .frame(width: 28)
                    Text("WEIGHT")
                        .frame(maxWidth: .infinity)
                    Text("REPS")
                        .frame(maxWidth: .infinity)
                    Text("")
                        .frame(width: 40)
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(GQColors.textTertiary)
                .tracking(0.5)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 4)

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

                    if exercise.sets.firstIndex(where: { $0.id == set.id }) != exercise.sets.count - 1 {
                        Divider().padding(.leading, 28).padding(.trailing, 40).opacity(0.5)
                    }
                }

                Rectangle()
                    .fill(GQColors.borderSubtle)
                    .frame(height: 1)
                    .padding(.horizontal, 16)

                Button {
                    let lastSet = exercise.sets.last
                    exercise.sets.append(
                        ActiveSet(
                            reps: lastSet?.reps ?? previousReps ?? 10,
                            weight: lastSet?.weight ?? previousWeight ?? 0
                        )
                    )
                } label: {
                    Text("Add Set")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(GQColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
        .homeSocialCard(cornerRadius: 14)
        .overlay(alignment: .topTrailing) {
            if allSetsComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(GQGradients.primary)
                    .padding(12)
            }
        }
        .onAppear {
            loadPreviousPerformance()
        }
        .sheet(isPresented: $showExerciseDemo) {
            ExerciseDemoSheet(exerciseName: exercise.name, muscleGroup: exercise.muscleGroup.rawValue)
        }
    }

    private func loadPreviousPerformance() {
        let descriptor = FetchDescriptor<Workout>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let workouts = try? modelContext.fetch(descriptor) else { return }

        var foundPrevious = false
        var overallBestWeight: Double = 0
        var overallBestReps: Int = 0
        var overallBest1RM: Double = 0

        for workout in workouts {
            for ex in workout.exercises where ex.name == exercise.name {
                // Set previous (most recent) performance
                if !foundPrevious {
                    if let topSet = ex.sets.sorted(by: { $0.weight > $1.weight }).first {
                        previousWeight = topSet.weight
                        previousReps = topSet.reps
                    }
                    foundPrevious = true
                }
                // Track all-time bests across all workouts
                for set in ex.sets where set.weight > 0 && set.reps > 0 {
                    if set.weight > overallBestWeight {
                        overallBestWeight = set.weight
                        overallBestReps = set.reps
                    }
                    // Epley e1RM formula
                    if set.reps >= 1 && set.reps <= 12 {
                        let e1rm = set.weight * (1 + Double(set.reps) / 30.0)
                        if e1rm > overallBest1RM {
                            overallBest1RM = e1rm
                        }
                    }
                }
            }
        }

        if overallBestWeight > 0 {
            bestWeight = overallBestWeight
            bestReps = overallBestReps
            best1RM = overallBest1RM > 0 ? overallBest1RM : nil
        }

        // Auto-populate empty sets with previous weight/reps
        if let pw = previousWeight, pw > 0 {
            for i in exercise.sets.indices {
                if exercise.sets[i].weight == 0 {
                    exercise.sets[i].weight = pw
                }
                if exercise.sets[i].reps == 0, let pr = previousReps, pr > 0 {
                    exercise.sets[i].reps = pr
                }
            }
        }
    }

    private func checkExerciseCompletion() {
        // Check if all sets just became complete
        let newCompletedCount = exercise.sets.filter { $0.isCompleted }.count
        if newCompletedCount == exercise.sets.count && newCompletedCount > 0 {
            HapticManager.shared.success()
        }

        // Live PR detection on each set completion
        if !prFiredForExercise {
            checkForPR()
        }

        // Auto-trigger rest timer on any set completion
        onSetCompleted?(exercise.name)
    }

    private func checkForPR() {
        guard let bw = bestWeight, bw > 0 else {
            // First time doing this exercise — fire baseline PR if meaningful weight
            if let topCompleted = exercise.sets.filter({ $0.isCompleted && $0.weight > 0 }).max(by: { $0.weight < $1.weight }) {
                prFiredForExercise = true
                let pr = LivePREvent(
                    exerciseName: exercise.name,
                    type: .weight,
                    newValue: topCompleted.weight,
                    previousValue: 0,
                    delta: topCompleted.weight
                )
                onPRDetected?(pr)
            }
            return
        }

        let completedSets = exercise.sets.filter { $0.isCompleted && $0.weight > 0 && $0.reps > 0 }
        guard let topSet = completedSets.max(by: { $0.weight < $1.weight }) else { return }

        // Weight PR: higher weight at same or more reps
        if topSet.weight > bw && topSet.reps >= (bestReps ?? 0) {
            prFiredForExercise = true
            let pr = LivePREvent(
                exerciseName: exercise.name,
                type: .weight,
                newValue: topSet.weight,
                previousValue: bw,
                delta: topSet.weight - bw
            )
            onPRDetected?(pr)
            return
        }

        // e1RM PR
        if topSet.reps >= 1 && topSet.reps <= 12 {
            let currentE1RM = topSet.weight * (1 + Double(topSet.reps) / 30.0)
            if let prevBest = best1RM, currentE1RM > prevBest + 5 {
                prFiredForExercise = true
                let pr = LivePREvent(
                    exerciseName: exercise.name,
                    type: .estimated1RM,
                    newValue: currentE1RM,
                    previousValue: prevBest,
                    delta: currentE1RM - prevBest
                )
                onPRDetected?(pr)
            }
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

// MARK: - Stepper Field (Double — for weight)

struct StepperField: View {
    @Binding var value: Double
    var unit: String = "lbs"
    var hint: String? = nil
    var accentColor: Color = GQColors.textSecondary

    var body: some View {
        VStack(spacing: 2) {
            TextField("0", value: $value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(GQColors.textPrimary)
                .frame(height: 32)

            Text(unit)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Int Stepper Field (Int — for reps)

struct IntStepperField: View {
    @Binding var value: Int
    var unit: String = "reps"
    var hint: String? = nil
    var accentColor: Color = GQColors.textSecondary

    var body: some View {
        VStack(spacing: 2) {
            TextField("0", value: $value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(GQColors.textPrimary)
                .frame(height: 32)

            Text(unit)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Active Set Row

// MARK: - Exercise Demo Sheet

struct ExerciseDemoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let exerciseName: String
    let muscleGroup: String

    private var metadata: ExerciseMetadata? {
        ExtendedExerciseDatabase.find(exerciseName)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Large GIF
                    ExerciseGifView(exerciseName: exerciseName, size: .large, showFallback: true)
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 16)

                    // Exercise info
                    VStack(alignment: .leading, spacing: 16) {
                        // Title + equipment
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exerciseName)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(GQColors.textPrimary)

                            HStack(spacing: 8) {
                                Text(muscleGroup)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(GQColors.textSecondary)
                                if let meta = metadata {
                                    Text("·")
                                        .foregroundColor(GQColors.textTertiary)
                                    Text(meta.equipment.rawValue)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(GQColors.textSecondary)
                                }
                            }
                        }

                        // Cues
                        if let meta = metadata, !meta.cues.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("HOW TO")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(GQColors.textTertiary)
                                    .tracking(0.5)

                                ForEach(Array(meta.cues.enumerated()), id: \.offset) { i, cue in
                                    HStack(alignment: .top, spacing: 10) {
                                        Text("\(i + 1)")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(GQGradients.primary)
                                            .frame(width: 20)
                                        Text(cue)
                                            .font(.system(size: 14))
                                            .foregroundColor(GQColors.textPrimary)
                                    }
                                }
                            }
                            .padding(14)
                            .homeSocialCard(cornerRadius: 14)
                        }

                        // Common mistakes
                        if let meta = metadata, !meta.commonMistakes.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("AVOID")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(GQColors.textTertiary)
                                    .tracking(0.5)

                                ForEach(meta.commonMistakes, id: \.self) { mistake in
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(GQColors.textTertiary)
                                            .frame(width: 20)
                                        Text(mistake)
                                            .font(.system(size: 14))
                                            .foregroundColor(GQColors.textSecondary)
                                    }
                                }
                            }
                            .padding(14)
                            .homeSocialCard(cornerRadius: 14)
                        }

                        // Muscles
                        if let meta = metadata {
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("PRIMARY")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(GQColors.textTertiary)
                                        .tracking(0.5)
                                    Text(meta.primaryMuscles.joined(separator: ", "))
                                        .font(.system(size: 13))
                                        .foregroundColor(GQColors.textPrimary)
                                }
                                if !meta.secondaryMuscles.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("SECONDARY")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(GQColors.textTertiary)
                                            .tracking(0.5)
                                        Text(meta.secondaryMuscles.joined(separator: ", "))
                                            .font(.system(size: 13))
                                            .foregroundColor(GQColors.textSecondary)
                                    }
                                }
                                Spacer()
                            }
                            .padding(14)
                            .homeSocialCard(cornerRadius: 14)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)
            .gqPageBackground()
            .navigationTitle(exerciseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(GQColors.textSecondary)
                }
            }
        }
    }
}

struct ActiveSetRow: View {
    @Binding var set: ActiveSet
    let setNumber: Int
    var totalSets: Int = 3
    let workoutTypeColors: [Color]
    var previousWeight: Double? = nil
    var previousReps: Int? = nil
    var onComplete: (() -> Void)? = nil

    @State private var checkScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 0) {
            // Set number
            Text("\(setNumber)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(set.isCompleted ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(GQColors.textTertiary))
                .frame(width: 28)

            // Weight input
            StepperField(value: $set.weight)

            // Divider
            Rectangle()
                .fill(GQColors.borderDefault)
                .frame(width: 0.5, height: 28)

            // Reps input
            IntStepperField(value: $set.reps)

            // Completion button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    set.isCompleted.toggle()
                    if set.isCompleted {
                        #if canImport(UIKit)
                        // Satisfying triple haptic: tap → success → light
                        let medium = UIImpactFeedbackGenerator(style: .medium)
                        medium.impactOccurred()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        #endif
                        onComplete?()
                        withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) {
                            checkScale = 1.35
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                                checkScale = 1.0
                            }
                        }
                    }
                }
            } label: {
                ZStack {
                    // Ripple effect on completion
                    if set.isCompleted {
                        Circle()
                            .fill(GQColors.deepBlue.opacity(0.08))
                            .frame(width: 36, height: 36)
                            .transition(.scale.combined(with: .opacity))
                    }

                    Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 26))
                        .foregroundStyle(set.isCompleted ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(GQColors.borderDefault))
                        .scaleEffect(checkScale)
                }
                .frame(width: 40)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .background(
            set.isCompleted
                ? AnyShapeStyle(LinearGradient(colors: [GQColors.deepBlue.opacity(0.04), GQColors.vividPurple.opacity(0.02)], startPoint: .leading, endPoint: .trailing))
                : AnyShapeStyle(Color.clear)
        )
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
    @State private var selectedEquipment: Equipment?
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
        if let equip = selectedEquipment {
            results = results.filter { $0.equipment == equip }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            results = results.filter {
                $0.name.lowercased().contains(query) ||
                $0.muscleGroup.rawValue.lowercased().contains(query) ||
                $0.aliases.contains { $0.lowercased().contains(query) } ||
                $0.equipment.rawValue.lowercased().contains(query) ||
                $0.category.rawValue.lowercased().contains(query) ||
                $0.primaryMuscles.contains { $0.lowercased().contains(query) }
            }
        }
        return results
    }

    /// Suggested exercises based on workout type when no search/filter is active
    private var suggestedExercises: [ExerciseMetadata] {
        let relevantGroups: [MuscleGroup]
        switch workoutType {
        case .push: relevantGroups = [.chest, .triceps, .shoulders]
        case .pull: relevantGroups = [.back, .biceps]
        case .legs: relevantGroups = [.quads, .hamstrings, .glutes, .calves]
        case .upper: relevantGroups = [.chest, .back, .shoulders, .biceps, .triceps]
        case .lower: relevantGroups = [.quads, .hamstrings, .glutes, .calves]
        case .fullBody: relevantGroups = [.chest, .back, .quads, .shoulders, .biceps]
        case .cardio: relevantGroups = [.cardio]
        case .rest: relevantGroups = [.core, .flexibility]
        case .glutes: relevantGroups = [.glutes, .hamstrings]
        case .abs: relevantGroups = [.core]
        case .hiit: relevantGroups = [.cardio]
        case .yoga: relevantGroups = [.core, .flexibility]
        case .custom: relevantGroups = MuscleGroup.allCases
        }
        return ExtendedExerciseDatabase.exercises
            .filter { relevantGroups.contains($0.muscleGroup) }
            .prefix(10)
            .map { $0 }
    }

    /// Autocomplete results when typing 2+ chars
    private var autocompleteResults: [ExerciseMetadata] {
        guard searchText.count >= 2 else { return [] }
        return allFiltered.prefix(5).map { $0 }
    }

    /// Equipment types present in the database for filter chips
    private var availableEquipment: [Equipment] {
        var seen = Set<Equipment>()
        return ExtendedExerciseDatabase.exercises.compactMap { ex in
            seen.insert(ex.equipment).inserted ? ex.equipment : nil
        }
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
                            .foregroundColor(GQColors.textPrimary)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(GQColors.surfaceOverlay)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(GQColors.borderDefault, lineWidth: 1)
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
                                if count > 0 {
                                    FilterChip(
                                        title: "\(muscle.rawValue) (\(count))",
                                        isSelected: selectedMuscleGroup == muscle
                                    ) {
                                        selectedMuscleGroup = muscle
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }

                    // Equipment filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(title: "Any Equipment", isSelected: selectedEquipment == nil) {
                                selectedEquipment = nil
                            }
                            ForEach(availableEquipment, id: \.self) { equip in
                                FilterChip(
                                    title: equip.rawValue,
                                    isSelected: selectedEquipment == equip
                                ) {
                                    selectedEquipment = equip
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                    }

                    // Exercise sections with autocomplete overlay
                    ZStack(alignment: .top) {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                // Suggested for workout type (when no search/filter active)
                                if searchText.isEmpty && selectedMuscleGroup == nil && selectedEquipment == nil {
                                    exerciseSection(
                                        title: "Suggested for \(workoutType.rawValue)",
                                        icon: "sparkles",
                                        accentColor: GQColors.textSecondary,
                                        exercises: suggestedExercises,
                                        startIndex: 0
                                    )
                                }

                                // Favorites section
                                if !favoriteExercises.isEmpty {
                                    exerciseSection(
                                        title: "Favorites",
                                        icon: "heart.fill",
                                        accentColor: GQColors.textSecondary,
                                        exercises: favoriteExercises,
                                        startIndex: 0
                                    )
                                }

                                // Recently Used section
                                if !recentFiltered.isEmpty {
                                    exerciseSection(
                                        title: "Recently Used",
                                        icon: "clock.fill",
                                        accentColor: GQColors.textSecondary,
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

                        // Inline autocomplete dropdown
                        if !autocompleteResults.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(autocompleteResults) { exercise in
                                    Button {
                                        addExercise(exercise)
                                    } label: {
                                        HStack(spacing: 10) {
                                            if FeatureFlags.shared.exerciseGifsEnabled {
                                                ExerciseGifView(exerciseName: exercise.name, size: .thumbnail, showFallback: true)
                                                    .scaleEffect(0.6)
                                                    .frame(width: 24, height: 24)
                                            } else {
                                                Image(systemName: exercise.equipment.icon)
                                                    .font(.system(size: 14))
                                                    .foregroundStyle(GQGradients.primary)
                                                    .frame(width: 24)
                                            }
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(exercise.name)
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(GQColors.textPrimary)
                                                Text(exercise.muscleGroup.rawValue)
                                                    .font(.system(size: 11))
                                                    .foregroundColor(GQColors.textTertiary)
                                            }
                                            Spacer()
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 18))
                                                .foregroundColor(GQColors.textSecondary)
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                    }
                                    .buttonStyle(.plain)

                                    if exercise.id != autocompleteResults.last?.id {
                                        Divider()
                                            .background(GQColors.borderDefault)
                                    }
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(GQColors.cardBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(GQColors.borderDefault, lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)
                            .padding(.horizontal, 16)
                            .zIndex(10)
                        }
                    }
                }
            }
            .gqPageBackground()
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(GQColors.textPrimary)
                }
            }
        }
        .tint(GQColors.textPrimary)
    }

    // MARK: - Section Builder

    @ViewBuilder
    private func exerciseSection(title: String, icon: String, accentColor: Color, exercises: [ExerciseMetadata], startIndex: Int) -> some View {
        if !exercises.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(GQColors.textTertiary)
                    Text(title.uppercased())
                        .font(GQTypography.sectionHeader)
                        .foregroundColor(GQColors.textTertiary)
                        .tracking(0.5)
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

    @State private var lastData: (weight: Double, reps: Int, date: Date)?
    @State private var prData: (weight: Double, reps: Int)?
    @State private var didLoadHistory = false

    private var muscleColor: Color { GQColors.textSecondary }
    private var difficultyColor: Color { GQColors.textTertiary }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Top row: icon, name, heart, chevron
                HStack(spacing: 10) {
                    // Exercise GIF or equipment icon
                    if FeatureFlags.shared.exerciseGifsEnabled {
                        ExerciseGifView(exerciseName: exercise.name, size: .thumbnail, showFallback: true)
                    } else {
                        ZStack {
                            Circle()
                                .fill(GQColors.deepBlue.opacity(0.08))
                                .frame(width: 38, height: 38)
                            Image(systemName: exercise.equipment.icon)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(GQGradients.primary)
                        }
                    }

                    Text(exercise.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    // Heart button
                    Button(action: onToggleFavorite) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 18))
                            .foregroundStyle(isFavorite ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(GQColors.textTertiary))
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
                                .foregroundColor(GQColors.textSecondary)
                        }
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(GQColors.cardBackground)
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
                        .stroke(GQColors.borderDefault, lineWidth: 1)
                }
            )
        }
        .buttonStyle(GQInteractiveStyle())
        .onAppear {
            guard !didLoadHistory else { return }
            didLoadHistory = true
            lastData = historyService.lastPerformed(exercise.name)
            prData = historyService.personalBest(exercise.name)
        }
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
                                .fill(GQGradients.primary)
                                .shadow(color: GQColors.deepBlue.opacity(0.09), radius: 6, y: 2)
                        } else {
                            Capsule()
                                .fill(GQColors.surfaceOverlay)
                        }
                    }
                )
                .overlay(
                    Group {
                        if !isSelected {
                            Capsule()
                                .stroke(GQColors.borderDefault, lineWidth: 1)
                        }
                    }
                )
                .clipShape(Capsule())
        }
        .buttonStyle(GQInteractiveStyle())
    }
}

// MARK: - Workout Completion Experience

struct WorkoutCompletionExperience: View {
    let workout: Workout
    let exercises: [ActiveExercise]
    let duration: Int
    let livePRs: [LivePREvent]
    let detectedPRMoments: [PRMoment]
    let didLevelUp: Bool
    let previousLevel: Int
    let newLevel: Int
    let xpEarned: Int
    let profile: UserProfile
    let workoutType: WorkoutType
    let onSharePost: () -> Void
    let onDone: () -> Void

    @State private var phase: Int = 0
    @State private var showConfetti = false
    @State private var darkOverlayOpacity: Double = 1.0
    @State private var checkmarkTrim: CGFloat = 0
    @State private var animatedDuration: Int = 0
    @State private var animatedSets: Int = 0
    @State private var animatedExercises: Int = 0
    @State private var animatedVolume: Int = 0
    @State private var animatedXP: Int = 0
    @State private var shareButtonScale: CGFloat = 1.0

    private var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets.filter { $0.isCompleted }.count }
    }

    private var totalVolume: Double {
        exercises.reduce(0.0) { total, ex in
            total + ex.sets.filter { $0.isCompleted }.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
        }
    }

    private var exerciseCount: Int {
        exercises.filter { $0.sets.contains(where: { $0.isCompleted }) }.count
    }

    private var allPRs: [LivePREvent] { livePRs }

    /// Post-hoc PRs that weren't already caught live
    private var uniquePostHocPRs: [PRMoment] {
        let liveExerciseNames = Set(livePRs.map(\.exerciseName))
        return detectedPRMoments.filter { moment in
            guard let name = moment.exerciseName else { return true }
            return !liveExerciseNames.contains(name)
        }
    }

    private var hasPRs: Bool { !allPRs.isEmpty || !uniquePostHocPRs.isEmpty }

    var body: some View {
        ZStack {
            GQColors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    completionHeaderSection
                    statsSection
                    if hasPRs { prSection }
                    if didLevelUp { levelUpSection }
                    actionsSection
                }
                .padding(.horizontal, GQLayout.screenHorizontal)
                .padding(.vertical, 20)
                .padding(.top, 40)
            }

            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
            }

            // Dark entry overlay
            Color.black
                .ignoresSafeArea()
                .opacity(darkOverlayOpacity)
                .allowsHitTesting(false)
        }
        .onAppear {
            // Dark fade-in
            withAnimation(.easeOut(duration: 0.3)) {
                darkOverlayOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    phase = 1
                }
                withAnimation(.easeInOut(duration: 0.5)) {
                    checkmarkTrim = 1.0
                }
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                #endif
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { phase = 2 }
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    animatedDuration = duration / 60
                    animatedSets = totalSets
                    animatedExercises = exerciseCount
                    animatedVolume = Int(totalVolume)
                    animatedXP = xpEarned
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { phase = 3 }
                if hasPRs {
                    showConfetti = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { phase = 4 }
                if !hasPRs {
                    showConfetti = true
                }
                #if canImport(UIKit)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                #endif
            }
        }
    }

    // MARK: - Completion Header

    @ViewBuilder
    private var completionHeaderSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(GQColors.deepBlue.opacity(0.10))
                    .frame(width: 72, height: 72)
                Circle()
                    .stroke(GQColors.deepBlue.opacity(0.15), lineWidth: 3)
                    .frame(width: 72, height: 72)
                    .opacity(checkmarkTrim)
                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(GQGradients.primary)
            }
            .scaleEffect(phase >= 1 ? 1.0 : 0.3)
            .opacity(phase >= 1 ? 1.0 : 0)

            Text("Workout Complete!")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(GQColors.textPrimary)
                .opacity(phase >= 1 ? 1.0 : 0)

            Text(workoutType.rawValue)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(GQColors.textSecondary)
                .opacity(phase >= 1 ? 1.0 : 0)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .homeSocialCard(cornerRadius: 14)
    }

    // MARK: - Stats Section

    @ViewBuilder
    private var statsSection: some View {
        if phase >= 2 {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    completionStatCard(
                        icon: "clock.fill",
                        animatedValue: animatedDuration,
                        unit: "min",
                        label: "Duration",
                        index: 0
                    )
                    completionStatCard(
                        icon: "checkmark.circle.fill",
                        animatedValue: animatedSets,
                        unit: "sets",
                        label: "Total Sets",
                        index: 1
                    )
                }
                HStack(spacing: 16) {
                    completionStatCard(
                        icon: "dumbbell.fill",
                        animatedValue: animatedExercises,
                        unit: "",
                        label: "Exercises",
                        index: 2
                    )
                    completionStatCardVolume(index: 3)
                }

                // XP earned
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(GQGradients.primary)
                    Text("+\(animatedXP) XP")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(GQGradients.primary)
                        .contentTransition(.numericText())
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Capsule().fill(GQColors.deepBlue.opacity(0.08)))
                .staggeredAppear(index: 4, stagger: 0.3)
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    @ViewBuilder
    private func completionStatCard(icon: String, animatedValue: Int, unit: String, label: String, index: Int) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(GQColors.deepBlue.opacity(0.10))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(GQGradients.primary)
            }
            HStack(spacing: 2) {
                Text("\(animatedValue)")
                    .font(GQTypography.stat)
                    .foregroundColor(GQColors.textPrimary)
                    .contentTransition(.numericText())
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)
                }
            }
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .homeSocialCard(cornerRadius: 14)
        .staggeredAppear(index: index, stagger: 0.3)
    }

    @ViewBuilder
    private func completionStatCardVolume(index: Int) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(GQColors.deepBlue.opacity(0.10))
                    .frame(width: 32, height: 32)
                Image(systemName: "scalemass.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(GQGradients.primary)
            }
            HStack(spacing: 2) {
                Text(animatedVolume >= 1000 ? String(format: "%.1fk", Double(animatedVolume) / 1000) : "\(animatedVolume)")
                    .font(GQTypography.stat)
                    .foregroundColor(GQColors.textPrimary)
                    .contentTransition(.numericText())
                Text("lbs")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(GQColors.textTertiary)
            }
            Text("Volume")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .homeSocialCard(cornerRadius: 14)
        .staggeredAppear(index: index, stagger: 0.3)
    }

    // MARK: - PR Section

    @ViewBuilder
    private var prSection: some View {
        if phase >= 3 {
            VStack(spacing: 12) {
                Text("PERSONAL RECORDS")
                    .font(GQTypography.sectionHeader)
                    .foregroundColor(GQColors.textTertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                ForEach(allPRs) { pr in
                    PRBadgeCard(
                        exerciseName: pr.exerciseName,
                        prType: pr.type.label,
                        delta: pr.displayDelta
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
                }

                ForEach(uniquePostHocPRs) { moment in
                    PRBadgeCard(
                        exerciseName: moment.exerciseName ?? "Exercise",
                        prType: moment.prType.rawValue.uppercased(),
                        delta: moment.improvement ?? moment.value
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .onAppear {
                HapticManager.shared.prDetected()
            }
        }
    }

    // MARK: - Level Up Section

    @ViewBuilder
    private var levelUpSection: some View {
        if phase >= 3 {
            LevelUpBanner(newLevel: newLevel)
                .transition(.scale.combined(with: .opacity))
                .onAppear {
                    HapticManager.shared.milestoneReached()
                }
        }
    }

    // MARK: - Actions Section

    @ViewBuilder
    private var actionsSection: some View {
        if phase >= 4 {
            VStack(spacing: 12) {
                Button(action: onSharePost) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Customize & Share")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(GQGradients.primary)
                    )
                    .contentShape(Rectangle())
                }
                .scaleEffect(shareButtonScale)
                .buttonStyle(GQInteractiveStyle())
                .onAppear {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.2)) {
                        shareButtonScale = 1.03
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            shareButtonScale = 1.0
                        }
                    }
                }

                Button(action: onDone) {
                    Text("Skip Post")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(GQColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(RoundedRectangle(cornerRadius: 16).fill(GQColors.surfaceBase))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(GQColors.borderDefault, lineWidth: 1))
                        .contentShape(Rectangle())
                }
                .buttonStyle(GQInteractiveStyle())
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    private func formatVolume(_ vol: Double) -> String {
        if vol >= 1000 {
            return String(format: "%.1fk", vol / 1000)
        }
        return "\(Int(vol))"
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
                    // Exercise GIF demo
                    ExerciseGifView(exerciseName: exerciseName, size: .large, showFallback: true)
                        .featureGated(FeatureFlags.shared.exerciseGifsEnabled)
                        .gqScreenHorizontalPadding()

                    // Form cues
                    if let metadata = exerciseMetadata {
                        GlassCard(accentColor: GQColors.primary) {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("FORM CUES")
                                    .font(GQTypography.sectionHeader)
                                    .foregroundColor(GQColors.sectionLabel)
                                    .tracking(1)

                                ForEach(metadata.cues, id: \.self) { cue in
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(GQColors.primary)
                                        Text(cue)
                                            .font(.system(size: 15))
                                            .foregroundColor(GQColors.textPrimary)
                                    }
                                }
                            }
                            .padding()
                        }
                        .gqScreenHorizontalPadding()

                        // Common mistakes
                        if !metadata.commonMistakes.isEmpty {
                            GlassCard(accentColor: GQColors.textSecondary) {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("COMMON MISTAKES")
                                        .font(GQTypography.sectionHeader)
                                        .foregroundColor(GQColors.sectionLabel)
                                        .tracking(1)

                                    ForEach(metadata.commonMistakes, id: \.self) { mistake in
                                        HStack(alignment: .top, spacing: 12) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 16))
                                                .foregroundColor(GQColors.textTertiary)
                                            Text(mistake)
                                                .font(.system(size: 15))
                                                .foregroundColor(GQColors.textPrimary)
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
    @State private var shareToClub = false
    @State private var taggedFriends: Set<String> = []

    // Legacy media state (single-photo picker)
    @State private var photoData: Data?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var mediaIsVideo = false
    @State private var videoData: Data?

    private var workoutTypeColors: [Color] {
        [GQColors.deepBlue, GQColors.vividPurple]
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
                            .fill(GQColors.deepBlue.opacity(0.15))
                            .frame(width: 120, height: 120)
                            .blur(radius: 30)

                        AnimatedGradientCircle(
                            size: 90,
                            lineWidth: 3,
                            colors: [GQColors.deepBlue, GQColors.deepBlue, GQColors.deepBlue]
                        )

                        Image(systemName: workoutType.icon)
                            .font(.system(size: 36, weight: .medium))
                            .foregroundStyle(GQGradients.primary)
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
                        .foregroundStyle(isFavoriteWorkout ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(GQColors.textTertiary))
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
                    .foregroundColor(GQColors.sectionLabel)
                    .tracking(1)
                Spacer()
            }

            GlassCard(accentColor: GQColors.textSecondary) {
                VStack(spacing: 16) {
                    HStack(spacing: 24) {
                        CompletionStatItem(
                            icon: "clock.fill",
                            iconColor: GQColors.textSecondary,
                            value: "\(duration)",
                            label: "min"
                        )
                        CompletionStatItem(
                            icon: "checkmark.circle.fill",
                            iconColor: GQColors.textSecondary,
                            value: "\(totalSets)",
                            label: "sets"
                        )
                        CompletionStatItem(
                            icon: "figure.strengthtraining.traditional",
                            iconColor: GQColors.textSecondary,
                            value: "\(exercises.count)",
                            label: "exercises"
                        )
                    }

                    // Enhanced metrics row
                    HStack(spacing: 24) {
                        CompletionStatItem(
                            icon: "scalemass.fill",
                            iconColor: GQColors.textSecondary,
                            value: totalVolume >= 1000 ? String(format: "%.1fk", totalVolume / 1000) : "\(Int(totalVolume))",
                            label: "lbs vol"
                        )
                        if let top = topSetDisplay {
                            VStack(spacing: 4) {
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(GQColors.textSecondary)
                                Text("Top Set")
                                    .font(.caption)
                                    .foregroundColor(GQColors.textSecondary)
                                Text(top)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(GQColors.textSecondary)
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
                    .foregroundColor(GQColors.sectionLabel)
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
            .homeSocialCard(accent: GQColors.textSecondary)
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
                        .fill(GQColors.deepBlue.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(GQGradients.primary)
                }

                Text("Customize Post")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(GQColors.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .homeSocialCard(accent: GQColors.textSecondary, cornerRadius: 12)
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
        .buttonStyle(HomeSocialPrimaryButtonStyle(accent: GQColors.deepBlue, cornerRadius: 18))
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
                .font(GQTypography.sectionHeader)
                .foregroundColor(GQColors.sectionLabel)
                .tracking(1)

            TextField("What's on your mind?", text: $caption, axis: .vertical)
                .lineLimit(3...6)
                .padding(12)
                .background(GQColors.surfaceOverlay)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(GQColors.borderDefault, lineWidth: 0.5)
                )
        }
    }

    // MARK: - Media

    @ViewBuilder
    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MEDIA")
                .font(GQTypography.sectionHeader)
                .foregroundColor(GQColors.sectionLabel)
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
                            .foregroundStyle(GQGradients.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add Photo or Video")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(GQColors.textPrimary)
                            Text("Show off your workout")
                                .font(.system(size: 12))
                                .foregroundColor(GQColors.textTertiary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textTertiary)
                    }
                    .padding(14)
                    .background(GQColors.surfaceOverlay)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(GQColors.borderDefault, lineWidth: 0.5)
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
                .font(GQTypography.sectionHeader)
                .foregroundColor(GQColors.sectionLabel)
                .tracking(1)

            if let song = selectedSong {
                HStack(spacing: 10) {
                    Image(systemName: "music.note")
                        .font(.system(size: 14))
                        .foregroundStyle(GQGradients.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(GQColors.textPrimary)
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
                            .foregroundStyle(GQGradients.primary)
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
                .background(GQColors.deepBlue.opacity(0.08))
                .cornerRadius(12)
            } else {
                Button { showMusicPicker = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 20))
                            .foregroundStyle(GQGradients.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add a Song or Playlist")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(GQColors.textPrimary)
                            Text("What did you listen to?")
                                .font(.system(size: 12))
                                .foregroundColor(GQColors.textTertiary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textTertiary)
                    }
                    .padding(14)
                    .background(GQColors.surfaceOverlay)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(GQColors.borderDefault, lineWidth: 0.5)
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
                .font(GQTypography.sectionHeader)
                .foregroundColor(GQColors.sectionLabel)
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
                                        .fill(isTagged ? GQGradients.primary : LinearGradient(colors: [GQColors.borderDefault], startPoint: .top, endPoint: .bottom))
                                        .frame(width: 48, height: 48)
                                        .overlay(
                                            Text(String(friend.name.prefix(1)))
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(.white)
                                        )

                                    if isTagged {
                                        Circle()
                                            .stroke(GQGradients.primary, lineWidth: 2)
                                            .frame(width: 52, height: 52)
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(GQGradients.primary)
                                            .background(Circle().fill(Color.black).frame(width: 12, height: 12))
                                            .offset(x: 18, y: 18)
                                    }
                                }
                                Text(friend.name.split(separator: " ").first.map(String.init) ?? friend.name)
                                    .font(.system(size: 11))
                                    .foregroundColor(isTagged ? .white : GQColors.textTertiary)
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

    // MARK: - Club Toggle

    @ViewBuilder
    private var clubToggle: some View {
        Toggle(isOn: $shareToClub) {
            HStack(spacing: 10) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(GQGradients.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Post to Club")
                        .font(.system(size: 14, weight: .medium))
                    Text("Share with your club")
                        .font(.system(size: 12))
                        .foregroundColor(GQColors.textTertiary)
                }
            }
        }
        .tint(GQColors.textSecondary)
        .padding(14)
        .background(GQColors.surfaceOverlay)
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
                        colors: [GQColors.deepBlue, GQColors.deepBlue],
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
                    .foregroundColor(GQColors.textTertiary)
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
                    rpe: activeSet.rpe,
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

        // Sync workout to Supabase
        if FeatureFlags.shared.supabaseSyncEnabled {
            Task {
                do {
                    try await SupabaseSyncService.shared.syncWorkout(workout)
                } catch {
                    print("[WorkoutSync] Failed to sync workout: \(error)")
                }
            }
        }

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
        FeedContentService.shared.syncPostToSupabase(post)

        // Add XP (bonus for sharing)
        let xpEarned = 25 + (totalSets * 5)
        _ = profile.addXP(xpEarned)

        // Post-save hooks
        MomentumService.shared.recordWorkoutCompleted(userId: profile.id)
        ChallengeService.shared.updateProgress(userId: profile.id, workout: workout)
        if let pod = PodService.shared.getPrimaryPod(userId: profile.id) {
            PodService.shared.checkIn(podId: pod.id, userId: profile.id, type: .done, workoutId: workout.id)
        }
        PremiumGateService.shared.decrementFreeTrial(userId: profile.id)

        try? modelContext.save()

        withAnimation {
            hasCompleted = true
        }

        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    private func saveOnly() {
        WorkoutDraft.clear()
        let workoutExercises = exercises.map { activeExercise -> Exercise in
            let sets = activeExercise.sets.filter { $0.isCompleted }.enumerated().map { index, activeSet in
                ExerciseSet(
                    reps: activeSet.reps,
                    weight: activeSet.weight,
                    rpe: activeSet.rpe,
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

        // Sync workout to Supabase
        if FeatureFlags.shared.supabaseSyncEnabled {
            Task {
                do {
                    try await SupabaseSyncService.shared.syncWorkout(workout)
                } catch {
                    print("[WorkoutSync] Failed to sync workout: \(error)")
                }
            }
        }

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
            FeedContentService.shared.syncPostToSupabase(post)
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
        WorkoutDraft.clear()
        let workoutExercises = exercises.map { activeExercise -> Exercise in
            let sets = activeExercise.sets.filter { $0.isCompleted }.enumerated().map { index, activeSet in
                ExerciseSet(
                    reps: activeSet.reps,
                    weight: activeSet.weight,
                    rpe: activeSet.rpe,
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

        // Sync workout to Supabase
        if FeatureFlags.shared.supabaseSyncEnabled {
            Task {
                do {
                    try await SupabaseSyncService.shared.syncWorkout(workout)
                } catch {
                    print("[WorkoutSync] Failed to sync workout: \(error)")
                }
            }
        }

        // Post-save hooks
        MomentumService.shared.recordWorkoutCompleted(userId: profile.id)
        ChallengeService.shared.updateProgress(userId: profile.id, workout: workout)
        if let pod = PodService.shared.getPrimaryPod(userId: profile.id) {
            PodService.shared.checkIn(podId: pod.id, userId: profile.id, type: .done, workoutId: workout.id)
        }
        PremiumGateService.shared.decrementFreeTrial(userId: profile.id)

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
                .foregroundColor(GQColors.textPrimary)
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
                .foregroundColor(GQColors.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundColor(GQColors.textSecondary)
        }
    }
}

// MARK: - Live GPS Stats Bar

struct LiveGPSStatsBar: View {
    let distance: Double  // meters
    let pace: Double      // seconds per kilometer

    private var distanceKm: String {
        String(format: "%.2f", distance / 1000.0)
    }

    private var paceString: String {
        guard pace > 0 && pace < 3600 else { return "--:--" }
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        HStack(spacing: 20) {
            HStack(spacing: 6) {
                Image(systemName: "map")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(GQGradients.primary)
                Text("\(distanceKm) km")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 1, height: 16)

            HStack(spacing: 6) {
                Image(systemName: "speedometer")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(GQGradients.primary)
                Text("\(paceString) /km")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            Spacer()

            // Live indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(GQGradients.primary)
                    .frame(width: 6, height: 6)
                Text("GPS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(GQColors.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.3))
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
    var accentColor: Color = GQColors.textTertiary

    @State private var showPills = false

    var progress: CGFloat {
        guard restTimerTotal > 0 else { return 0 }
        return CGFloat(restTimeRemaining) / CGFloat(restTimerTotal)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Text("\(restTimeRemaining)s")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(GQColors.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .frame(minWidth: 50, alignment: .leading)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(GQColors.borderDefault)
                        Capsule()
                            .fill(GQColors.textTertiary)
                            .frame(width: geo.size.width * progress)
                            .animation(.linear(duration: 1), value: progress)
                    }
                }
                .frame(height: 4)

                Button {
                    withAnimation(.spring(response: 0.25)) { showPills.toggle() }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12))
                        .foregroundColor(GQColors.textTertiary)
                }
                .buttonStyle(.plain)

                Button { onSkip() } label: {
                    Text("Skip")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(GQColors.textSecondary)
                }
                .buttonStyle(.plain)

                Button { onHide() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if showPills {
                HStack(spacing: 6) {
                    ForEach([30, 45, 60, 90, 120, 180], id: \.self) { seconds in
                        Button { onAdjust(seconds) } label: {
                            Text(seconds < 60 ? "\(seconds)s" : "\(seconds / 60)m")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(selectedRestDuration == seconds ? GQColors.textPrimary : GQColors.textTertiary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(selectedRestDuration == seconds ? GQColors.overlayMedium : Color.clear)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .homeSocialCard(cornerRadius: 14)
        .padding(.horizontal, 16)
        .onChange(of: restTimeRemaining) { _, newValue in
            if newValue == 0 {
                #if canImport(UIKit)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                #endif
            } else if newValue <= 3 && newValue > 0 {
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
            }
        }
    }
}

// MARK: - Overload Suggestion Pill

struct OverloadSuggestionPill: View {
    let suggestion: OverloadSuggestion

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: directionIcon)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(directionColor)

            Text("Try \(Int(suggestion.suggestedWeight)) lbs x \(suggestion.suggestedReps)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(directionColor)

            if suggestion.confidence == .high {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 10))
                    .foregroundColor(directionColor.opacity(0.7))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(directionColor.opacity(0.1))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(directionColor.opacity(0.3), lineWidth: 1))
    }

    private var directionIcon: String {
        switch suggestion.direction {
        case .increase: return "arrow.up.right"
        case .hold: return "equal"
        case .decrease: return "arrow.down.right"
        }
    }

    private var directionColor: Color {
        switch suggestion.direction {
        case .increase: return GQColors.textSecondary
        case .hold: return GQColors.textSecondary
        case .decrease: return GQColors.textSecondary
        }
    }
}

// MARK: - Workout Camera Sheet

#if canImport(UIKit)
struct WorkoutCameraSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var workoutMedia: [PostMedia]
    @StateObject private var cameraVM = CameraViewModel()
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ZStack {
                GQColors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Camera viewfinder
                    ZStack {
                        PostCameraPreviewView(cameraVM: cameraVM)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(GQColors.borderDefault, lineWidth: 1)
                    )
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                    // Media count indicator
                    if !workoutMedia.isEmpty {
                        Text("\(workoutMedia.count) captured")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(GQColors.textSecondary)
                            .padding(.top, 8)
                    }

                    Spacer()

                    // Controls
                    HStack(alignment: .center) {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .any(of: [.images, .videos])) {
                            VStack(spacing: 6) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 22))
                                    .foregroundColor(GQColors.textPrimary)
                                Text("Library")
                                    .font(.system(size: 11))
                                    .foregroundColor(GQColors.textSecondary)
                            }
                            .frame(width: 56, height: 56)
                        }

                        Spacer()

                        ShutterButton(isRecording: cameraVM.isRecording) {
                            guard workoutMedia.count < EnhancedPostEditorView.maxMediaItems else { return }
                            cameraVM.capturePhoto { data in
                                guard let data = data,
                                      let img = UIImage(data: data)?.fixedOrientation(),
                                      let compressed = img.jpegData(compressionQuality: 0.8) else { return }
                                let enhanced = cameraVM.applySubtleEnhancement(to: compressed)
                                let media = PostMedia(exerciseName: nil, exerciseIndex: nil, mediaType: .photo, data: enhanced, thumbnailData: enhanced)
                                workoutMedia.append(media)
                                dismiss()
                            }
                        } onHoldStart: {
                            guard workoutMedia.count < EnhancedPostEditorView.maxMediaItems else { return }
                            cameraVM.startRecording()
                        } onHoldEnd: {
                            cameraVM.stopRecording { url in
                                guard let url = url, let data = try? Data(contentsOf: url) else { return }
                                let thumb = VideoThumbnailGenerator.generate(from: url)
                                let thumbData = thumb?.jpegData(compressionQuality: 0.7)
                                let media = PostMedia(exerciseName: nil, exerciseIndex: nil, mediaType: .video, data: data, thumbnailData: thumbData)
                                workoutMedia.append(media)
                                try? FileManager.default.removeItem(at: url)
                                dismiss()
                            }
                        }

                        Spacer()

                        Button {
                            cameraVM.flipCamera()
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "camera.rotate")
                                    .font(.system(size: 22))
                                    .foregroundColor(GQColors.textPrimary)
                                Text("Flip")
                                    .font(.system(size: 11))
                                    .foregroundColor(GQColors.textSecondary)
                            }
                            .frame(width: 56, height: 56)
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 32)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(GQColors.textSecondary)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newValue in
                loadFromLibrary(newValue)
            }
        }
        .tint(GQColors.textPrimary)
    }

    private func loadFromLibrary(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                if let uiImage = UIImage(data: data)?.fixedOrientation() {
                    let compressed = uiImage.jpegData(compressionQuality: 0.8) ?? data
                    let enhanced = cameraVM.applySubtleEnhancement(to: compressed)
                    let media = PostMedia(exerciseName: nil, exerciseIndex: nil, mediaType: .photo, data: enhanced, thumbnailData: enhanced)
                    await MainActor.run {
                        workoutMedia.append(media)
                        dismiss()
                    }
                }
            }
        }
    }
}
#endif

// MARK: - Preview

#Preview {
    ActiveWorkoutView(profile: UserProfile(), workoutType: .push)
        .environmentObject(AppState())
}
