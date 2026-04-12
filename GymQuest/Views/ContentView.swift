//
//  ContentView.swift
//  GymQuest
//
//  created by Benjamin Hilderman
//
//  Main app container with floating glass tab bar
//  Bold & Energetic design with animated gradient accents
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var featureFlags: FeatureFlags
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @Query(filter: #Predicate<UserProfile> { $0.isAuthenticated == true }) private var authenticatedProfiles: [UserProfile]
    @StateObject private var aiService = AIService()

    // Weekly Recap Proof Card — memo 4 "anticipated cadence" driver.
    @State private var showWeeklyRecap = false
    @State private var weeklyRecapMeta: ProofCardMeta? = nil

    // First-time app tour
    @AppStorage("hasSeenAppTour") private var hasSeenAppTour = false
    @State private var showAppTour = false
    @State private var tourStep = 0

    private var profile: UserProfile? {
        authenticatedProfiles.first
    }

    var body: some View {
        Group {
            if let profile = profile {
                mainContent(profile: profile)
            } else {
                // Loading state while profile loads
                ZStack {
                    EnergyBackground()
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(GQColors.textPrimary)
                            .scaleEffect(1.2)
                        Text("Loading...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(GQColors.textSecondary)
                    }
                }
            }
        }
    }

    private var allTabs: [AppState.Tab] { AppState.Tab.visibleTabs }

    private func advanceTour() {
        if tourStep < 4 {
            withAnimation(.easeInOut(duration: 0.25)) {
                tourStep += 1
            }
        } else {
            dismissTour()
        }
    }

    private func dismissTour() {
        withAnimation(.easeOut(duration: 0.25)) {
            showAppTour = false
        }
        hasSeenAppTour = true
    }

    @ViewBuilder
    private func mainContent(profile: UserProfile) -> some View {
        ZStack(alignment: .bottom) {
            Group {
                switch appState.selectedTab {
                case .feed: FeedView(profile: profile)
                case .today: TodayView(profile: profile)
                case .activity: SocialActivityView(profile: profile)
                case .profile: ProfileView(profile: profile)
                case .home: Color.clear
                }
            }
            .transaction { transaction in
                transaction.animation = nil
            }
            .ignoresSafeArea(.keyboard)

            // Active workout view — kept alive outside the switch so state persists across tab changes
            if let workout = appState.activeWorkout {
                ActiveWorkoutView(profile: profile, workoutType: workout.workoutType, exercises: workout.exercises, customTitle: workout.customTitle)
                    .opacity(appState.selectedTab == .home && !appState.isWorkoutPaused ? 1 : 0)
                    .allowsHitTesting(appState.selectedTab == .home && !appState.isWorkoutPaused)
            }

            // Now playing + tab bar (on top of everything)
            VStack(spacing: 0) {
                NowPlayingBar()
                    .padding(.bottom, 4)

                FloatingTabBar()
            }
        }
        .gqPageBackground()
        .overlay {
            if showAppTour {
                AppTourOverlay(
                    step: $tourStep,
                    onNext: { advanceTour() },
                    onSkip: { dismissTour() }
                )
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $appState.showingLogWorkout) {
            LogWorkoutView(profile: profile)
        }
        .sheet(isPresented: $appState.showingWorkoutStartOptions) {
            WorkoutStartOptionsView(profile: profile)
        }
        .sheet(item: $appState.selectedSession) { session in
            SessionDetailView(session: session)
        }
        // QuickActionSheet removed — center button now goes directly to workout start
        .sheet(isPresented: $appState.showingLogEntry) {
            LogView(profile: profile)
        }
        .sheet(isPresented: $appState.showingMealLog) {
            MealLogView(profile: profile)
        }
        .sheet(isPresented: $appState.showingAddMeasurement) {
            AddMeasurementSheet(profile: profile, measurementType: .weight)
        }
        .onAppear {
            let ctx = modelContext
            AnalyticsService.shared.configure(modelContext: ctx)
            MomentumService.shared.configure(modelContext: ctx)
            PodService.shared.configure(modelContext: ctx)
            ChallengeService.shared.configure(modelContext: ctx)
            PermissionsService.shared.configure(modelContext: ctx)
            NotificationService.shared.configure(modelContext: ctx)
            ClubService.shared.configure(modelContext: ctx)
            FeedContentService.shared.configure(modelContext: ctx)
            WorkoutAdaptationService.shared.configure(modelContext: ctx)
            PremiumGateService.shared.configure(modelContext: ctx)
            PlanScheduleService.shared.configure(modelContext: ctx)
            QuestService.shared.configure(modelContext: ctx)
            QuestService.shared.seedDefaultQuests()
            SquadService.shared.configure(modelContext: ctx)
            LearningService.shared.configure(modelContext: ctx)
            ProductionSeeder.seedIfNeeded(modelContext: ctx)

            if FeatureFlags.shared.supabaseSyncEnabled {
                SupabaseSyncService.shared.configure(modelContext: ctx)
                if let userId = SupabaseAuthService.shared.currentUserId {
                    SupabaseSyncService.shared.startSync(userId: userId)
                }
            }

            // First-time app tour — show after 1s delay on first launch
            if !hasSeenAppTour {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showAppTour = true
                    }
                }
            }

            // Weekly Recap Proof Card trigger
            if let p = self.profile {
                let meta = WeeklyRecapService.checkAndBuild(
                    profile: p,
                    workouts: workouts,
                    modelContext: ctx
                )
                if let meta {
                    weeklyRecapMeta = meta
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showWeeklyRecap = true
                    }
                }
            }
        }
        .onChange(of: tourStep) { _, newStep in
            // Switch tabs as the tour progresses
            withAnimation(.easeInOut(duration: 0.2)) {
                switch newStep {
                case 0, 1: appState.selectedTab = .today
                case 2: appState.selectedTab = .feed
                case 3: appState.selectedTab = .activity
                case 4: appState.selectedTab = .profile
                default: break
                }
            }
        }
        .fullScreenCover(isPresented: $showWeeklyRecap) {
            if let meta = weeklyRecapMeta, let p = self.profile {
                WeeklyRecapView(
                    meta: meta,
                    profile: p,
                    onDismiss: {
                        p.lastWeeklyRecapSeen = Date()
                        try? modelContext.save()
                        showWeeklyRecap = false
                    }
                )
            }
        }
    }
}

// MARK: - Floating Glass Tab Bar

struct FloatingTabBar: View {
    @EnvironmentObject var appState: AppState
    @State private var workoutSeconds: Int = 0
    @State private var workoutTimer: Timer?

    private var workoutProgress: CGFloat {
        guard let status = appState.liveWorkoutStatus, status.totalSets > 0 else { return 0 }
        return CGFloat(status.completedSets) / CGFloat(status.totalSets)
    }

    private var workoutTimerText: String {
        let m = workoutSeconds / 60
        let s = workoutSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    FloatingTabButton(tab: .feed, icon: "person.2", selectedIcon: "person.2.fill", label: "Feed")

                    if SocialActivityService.shared.hasLiveFriends {
                        SocialActivityBadge()
                            .offset(x: -14, y: 2)
                    }
                }

                FloatingTabButton(tab: .today, icon: "chart.bar", selectedIcon: "chart.bar.fill", label: "Today")

                // Center button — workout indicator when active, "+" when idle
                if appState.isWorkoutActive {
                    Button {
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        #endif
                        if appState.selectedTab != .home {
                            appState.selectedTab = .home
                        }
                        if appState.isWorkoutPaused { appState.resumeWorkout() }
                    } label: {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(GQColors.success)
                                .frame(width: 5, height: 5)

                            Text(workoutTimerText)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(GQColors.textPrimary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(GQColors.surfaceBase)
                                .overlay(
                                    Capsule()
                                        .strokeBorder(GQColors.borderDefault, lineWidth: 0.5)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .offset(y: -4)
                } else {
                    Button {
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        #endif
                        appState.showingWorkoutStartOptions = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(GQGradients.primary)
                                .frame(width: 44, height: 44)
                                .shadow(color: GQColors.vividPurple.opacity(0.3), radius: 6, y: 2)

                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .medium, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .offset(y: -6)
                    .accessibilityLabel("Start workout")
                }

                FloatingTabButton(tab: .activity, icon: "heart", selectedIcon: "heart.fill", label: "Activity")

                FloatingTabButton(tab: .profile, icon: "person", selectedIcon: "person.fill", label: "You")
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 2)
        }
        .padding(.bottom, 4)
        .background(
            ZStack(alignment: .top) {
                UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16)
                    .fill(GQColors.surfaceBase.opacity(0.82))
                UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16)
                    .fill(.ultraThinMaterial)
                UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16)
                    .stroke(GQColors.borderSubtle.opacity(0.4), lineWidth: 0.5)
                // Top divider
                Rectangle()
                    .fill(GQColors.borderSubtle)
                    .frame(height: 0.5)
            }
            .ignoresSafeArea(.container, edges: .bottom)
        )
        .onChange(of: appState.isWorkoutActive) { _, active in
            if active {
                startWorkoutTimer()
            } else {
                stopWorkoutTimer()
            }
        }
        .onAppear {
            if appState.isWorkoutActive { startWorkoutTimer() }
        }
    }

    private func startWorkoutTimer() {
        guard let start = appState.activeWorkout?.startTime else { return }
        workoutSeconds = Int(Date().timeIntervalSince(start))
        workoutTimer?.invalidate()
        workoutTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            workoutSeconds = Int(Date().timeIntervalSince(start))
        }
    }

    private func stopWorkoutTimer() {
        workoutTimer?.invalidate()
        workoutTimer = nil
        workoutSeconds = 0
    }
}

// MARK: - Active Workout Mini Bar

struct ActiveWorkoutMiniBar: View {
    @EnvironmentObject var appState: AppState
    @State private var elapsedTime = 0
    @State private var timer: Timer?
    @State private var pulseOpacity: Double = 1.0

    var body: some View {
        Button {
            appState.selectedTab = .home
        } label: {
            HStack(spacing: 10) {
                // Pulsing dot
                Circle()
                    .fill(GQColors.success)
                    .frame(width: 8, height: 8)
                    .opacity(pulseOpacity)

                if let workout = appState.activeWorkout {
                    Image(systemName: workout.workoutType.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)

                    Text(workout.workoutType.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                }

                Spacer()

                Text(formatTime(elapsedTime))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(GQColors.textSecondary)

                Text("Return")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(GQColors.deepBlue)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                GQColors.surfaceBase
                    .overlay(
                        Rectangle()
                            .fill(GQGradients.primary)
                            .frame(height: 2),
                        alignment: .top
                    )
            )
        }
        .buttonStyle(GQInteractiveStyle())
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                if let start = appState.activeWorkout?.startTime {
                    elapsedTime = Int(Date().timeIntervalSince(start))
                }
            }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulseOpacity = 0.3
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Floating Tab Button

struct FloatingTabButton: View {
    @EnvironmentObject var appState: AppState
    let tab: AppState.Tab
    let icon: String
    var selectedIcon: String? = nil
    let label: String
    var isCustomIcon: Bool = false

    var isSelected: Bool { appState.selectedTab == tab }

    var tabColor: Color {
        return GQColors.textPrimary
    }

    var displayIcon: String {
        if isSelected {
            return selectedIcon ?? "\(icon).fill"
        }
        return icon
    }

    var body: some View {
        Button {
            HapticManager.shared.select()
            appState.selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                if isCustomIcon {
                    Image(displayIcon)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 22, height: 22)
                        .foregroundColor(isSelected ? tabColor : GQColors.textTertiary)
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                        .animation(GQMotion.micro, value: isSelected)
                } else {
                    Image(systemName: displayIcon)
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? tabColor : GQColors.textTertiary)
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                        .animation(GQMotion.micro, value: isSelected)
                }

                Text(label)
                    .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? tabColor : GQColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(GQInteractiveStyle())
        .accessibilityLabel("\(label) tab")
        .accessibilityHint(isSelected ? "Currently selected" : "Double tap to switch to \(label)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Mini Workout Bar

struct MiniWorkoutBar: View {
    @EnvironmentObject var appState: AppState
    let workoutType: WorkoutType
    let onTap: () -> Void

    @State private var pulse = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Circle()
                    .fill(GQColors.deepBlue)
                    .frame(width: 8, height: 8)
                    .scaleEffect(pulse ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulse)

                Text("\(workoutType.rawValue) Workout")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)

                Spacer()

                Text("Tap to return")
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textSecondary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(GQColors.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                GQColors.deepBlue.opacity(0.4),
                                lineWidth: 1
                            )
                    )
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .animation(.easeInOut(duration: 0.3), value: appState.isWorkoutActive)
        }
        .buttonStyle(.plain)
        .onAppear { pulse = true }
    }
}

// MARK: - Legacy Tab Bar (for backwards compatibility)

struct TabBar: View {
    var body: some View {
        FloatingTabBar()
    }
}

struct TabButton: View {
    @EnvironmentObject var appState: AppState
    let tab: AppState.Tab
    let icon: String
    var selectedIcon: String? = nil
    let label: String

    var body: some View {
        FloatingTabButton(tab: tab, icon: icon, selectedIcon: selectedIcon, label: label)
    }
}

// MARK: - Quick Action Sheet

struct QuickActionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Quick Actions")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(GQColors.textPrimary)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(GQColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 24)

            HStack(spacing: 32) {
                quickActionCircle(
                    icon: "figure.strengthtraining.traditional",
                    label: "Start Workout",
                    accent: GQColors.deepBlue
                ) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        appState.showingWorkoutStartOptions = true
                    }
                }

                quickActionCircle(
                    icon: "fork.knife",
                    label: "Log Food",
                    accent: GQColors.textSecondary
                ) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        appState.showingMealLog = true
                    }
                }

                quickActionCircle(
                    icon: "scalemass.fill",
                    label: "Log Weight",
                    accent: GQColors.success
                ) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        appState.showingAddMeasurement = true
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .gqPageBackground()
    }

    @ViewBuilder
    private func quickActionCircle(
        icon: String,
        label: String,
        accent: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(accent)
                    )
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Social Activity Badge

struct SocialActivityBadge: View {
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(GQColors.success)
            .frame(width: 8, height: 8)
            .scaleEffect(pulse ? 1.3 : 1.0)
            .opacity(pulse ? 1.0 : 0.7)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
    }
}

// MARK: - Dynamic Island-Style Workout Pill

struct WorkoutIslandPill: View {
    @EnvironmentObject var appState: AppState

    @State private var isExpanded = false
    @State private var elapsedSeconds: Int = 0
    @State private var timer: Timer?
    @State private var pulseAnimation = false

    private var status: LiveWorkoutStatus? { appState.liveWorkoutStatus }
    private var workout: ActiveWorkoutState? { appState.activeWorkout }

    @Environment(\.colorScheme) private var colorScheme

    private var pillBackground: Color {
        colorScheme == .dark ? .black : .white
    }
    private var pillTextStyle: AnyShapeStyle {
        colorScheme == .dark ? AnyShapeStyle(.white) : AnyShapeStyle(GQGradients.primary)
    }
    private var pillTextSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.7) : GQColors.textTertiary
    }
    private var pillShadow: Color {
        colorScheme == .dark ? .black.opacity(0.25) : .black.opacity(0.1)
    }

    var body: some View {
        if appState.isWorkoutActive && appState.selectedTab != .home {
            VStack(spacing: 0) {
                if isExpanded {
                    expandedView
                } else {
                    compactView
                }
            }
            .background(pillBackground)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(colorScheme == .dark ? .white.opacity(0.08) : GQColors.borderDefault, lineWidth: 0.5)
            )
            .shadow(color: pillShadow, radius: 6, y: 2)
            .padding(.horizontal, isExpanded ? 24 : 90)
            .onTapGesture {
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
                if isExpanded {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        isExpanded = false
                    }
                } else {
                    // Single tap on compact → return to workout immediately
                    appState.selectedTab = .home
                    if appState.isWorkoutPaused {
                        appState.resumeWorkout()
                    }
                }
            }
            .onLongPressGesture(minimumDuration: 0.3) {
                // Long press → expand for details
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    isExpanded = true
                }
            }
            .onAppear { startTimer() }
            .onDisappear { stopTimer() }
            .transition(.asymmetric(
                insertion: .scale(scale: 0.8).combined(with: .opacity),
                removal: .scale(scale: 0.8).combined(with: .opacity)
            ))
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: appState.isWorkoutActive)
        }
    }

    // MARK: - Compact

    private var compactView: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(GQColors.success)
                .frame(width: 6, height: 6)
                .scaleEffect(pulseAnimation ? 1.4 : 1.0)
                .opacity(pulseAnimation ? 0.5 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseAnimation)
                .onAppear { pulseAnimation = true }

            Image(systemName: workout?.workoutType.icon ?? "dumbbell.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(pillTextStyle)

            Text(status?.currentExercise ?? workout?.workoutType.rawValue ?? "Workout")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(pillTextStyle)
                .lineLimit(1)

            Text(formatTime(elapsedSeconds))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(pillTextSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Expanded

    private var expandedView: some View {
        VStack(spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(GQColors.success)
                        .frame(width: 7, height: 7)
                        .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                        .opacity(pulseAnimation ? 0.6 : 1.0)

                    Image(systemName: workout?.workoutType.icon ?? "dumbbell.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(pillTextStyle)

                    Text(workout?.customTitle ?? workout?.workoutType.rawValue ?? "Workout")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(pillTextStyle)
                }
                Spacer()
                Text(formatTime(elapsedSeconds))
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(pillTextStyle)
            }

            if let status = status, status.totalSets > 0 {
                VStack(spacing: 6) {
                    HStack {
                        Text(status.currentExercise)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(pillTextSecondary)
                        Spacer()
                        Text("\(status.completedSets)/\(status.totalSets) sets")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(pillTextSecondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(GQColors.overlayMedium)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(GQGradients.primary)
                                .frame(width: geo.size.width * CGFloat(status.completedSets) / CGFloat(max(status.totalSets, 1)))
                                .animation(.spring(response: 0.4), value: status.completedSets)
                        }
                    }
                    .frame(height: 4)
                }
            }

            Button {
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded = false
                }
                appState.selectedTab = .home
                if appState.isWorkoutPaused {
                    appState.resumeWorkout()
                }
            } label: {
                Text("Return to Workout")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(GQGradients.primary)
                    )
            }
        }
        .padding(16)
    }

    // MARK: - Timer

    private func startTimer() {
        guard let start = workout?.startTime else { return }
        elapsedSeconds = Int(Date().timeIntervalSince(start))
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedSeconds = Int(Date().timeIntervalSince(start))
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func formatTime(_ total: Int) -> String {
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(FeatureFlags.shared)
        .modelContainer(for: [Workout.self, UserProfile.self], inMemory: true)
}

// MARK: - App Tour Overlay (Callout-style)
//
// Gradient ring precisely on each tab bar icon + a frosted tooltip card
// with a triangular pointer seamlessly connected. The triangle is part of
// the card — same fill, -1pt overlap, zero visual gap.
//
// Positions are computed from the actual FloatingTabBar HStack math, not
// approximated fractions, so the ring sits exactly on each icon.

struct AppTourOverlay: View {
    @Binding var step: Int
    let onNext: () -> Void
    let onSkip: () -> Void

    private struct TourStep {
        let title: String
        let description: String
        let tabIndex: Int       // 0-4 in the HStack (0=feed,1=today,2=+,3=activity,4=you), or -1 for content
        let ringSize: CGFloat
        let cardAbove: Bool
        let contentY: CGFloat?  // if tabIndex == -1, use this Y fraction for content spotlight
    }

    private let steps: [TourStep] = [
        // 0: + button
        TourStep(title: "Start a Workout", description: "Tap + to log a workout. When you\nfinish, you'll get a Proof Card to share.", tabIndex: 2, ringSize: 55, cardAbove: true, contentY: nil),
        // 1: Today bottom tab
        TourStep(title: "Today", description: "Your daily challenges, progress\nrings, and what to do next.", tabIndex: 1, ringSize: 52, cardAbove: true, contentY: nil),
        // 2: Feed bottom tab — circle the Feed icon, explain the three sub-tabs
        TourStep(title: "Feed", description: "Friends — your people's workouts\nClubs — gym communities & challenges\nExplore — discover & use any workout", tabIndex: 0, ringSize: 52, cardAbove: true, contentY: nil),
        // 3: Activity bottom tab
        TourStep(title: "Activity", description: "Reactions, follows, and when\nsomeone uses your workout.", tabIndex: 3, ringSize: 52, cardAbove: true, contentY: nil),
        // 4: You bottom tab
        TourStep(title: "Your Profile", description: "Your training record. Complete\nyour profile to get started.", tabIndex: 4, ringSize: 52, cardAbove: true, contentY: nil),
    ]

    private var current: TourStep { steps[min(step, steps.count - 1)] }
    private var isLastStep: Bool { step >= steps.count - 1 }
    @State private var ringPulse = false

    var body: some View {
        GeometryReader { geo in
            let screenW = geo.size.width
            let screenH = geo.size.height
            let bottomSafe = geo.safeAreaInsets.bottom

            // Compute exact tab positions from the FloatingTabBar HStack layout:
            // HStack(spacing:0) with .padding(.horizontal, 16), 5 equal-width items.
            let tabBarPadding: CGFloat = 16
            let itemWidth = (screenW - tabBarPadding * 2) / 5.0
            let tabCenters: [CGFloat] = (0..<5).map { i in
                tabBarPadding + itemWidth * (CGFloat(i) + 0.5)
            }
            // Tab icon Y: empirically measured from device screenshots.
            // Using fractions of full screen height (with .ignoresSafeArea).
            let tabIconY = screenH * 0.929
            let plusY = screenH * 0.923

            // Ring center for current step
            let topSafe = geo.safeAreaInsets.top
            // Top tab picker positions (Friends | Clubs | Explore row in FeedView)
            let topTabY = topSafe + 92
            let friendsTabX = screenW * 0.17
            let clubsTabX = screenW * 0.50
            let exploreTabX = screenW * 0.80

            // -5 = wide ring spanning all three Feed top tabs
            let feedTabsWidth = screenW * 0.88  // spans Friends + Clubs + Explore

            let ringX: CGFloat = {
                if current.tabIndex == -5 { return screenW / 2 }
                if current.tabIndex == -3 { return friendsTabX }
                if current.tabIndex == -4 { return clubsTabX }
                if current.tabIndex == -2 { return exploreTabX }
                if current.tabIndex >= 0 && current.tabIndex < 5 { return tabCenters[current.tabIndex] }
                return screenW / 2
            }()
            let ringY: CGFloat = {
                if current.tabIndex == -5 || current.tabIndex == -3 || current.tabIndex == -4 || current.tabIndex == -2 { return topTabY }
                if current.tabIndex == 2 { return plusY }
                if current.tabIndex >= 0 { return tabIconY }
                return screenH * (current.contentY ?? 0.2)
            }()
            let isWideRing = current.tabIndex == -5
            let ringCenter = CGPoint(x: ringX, y: ringY)

            ZStack {
                // Subtle dim with cutout inside the ring so the highlighted
                // element shows through at full brightness
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                    .reverseMask {
                        if isWideRing {
                            RoundedRectangle(cornerRadius: current.ringSize / 2)
                                .frame(width: feedTabsWidth - 4, height: current.ringSize - 4)
                                .position(ringCenter)
                        } else {
                            Circle()
                                .frame(width: current.ringSize - 4, height: current.ringSize - 4)
                                .position(ringCenter)
                        }
                    }
                    .animation(.spring(response: 0.7, dampingFraction: 0.85), value: step)
                    .allowsHitTesting(false)

                // Gradient ring — circle for tabs, wide rounded rect for feed tabs
                Group {
                    if isWideRing {
                        RoundedRectangle(cornerRadius: current.ringSize / 2)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [GQColors.deepBlue, GQColors.vividPurple],
                                    startPoint: .leading, endPoint: .trailing
                                ),
                                lineWidth: 2.5
                            )
                            .frame(width: feedTabsWidth, height: current.ringSize)
                    } else {
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [GQColors.deepBlue, GQColors.vividPurple],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 2.5
                            )
                            .frame(width: current.ringSize, height: current.ringSize)
                    }
                }
                .scaleEffect(ringPulse ? 1.04 : 1.0)
                .opacity(ringPulse ? 0.75 : 1.0)
                .position(ringCenter)
                .animation(.spring(response: 0.7, dampingFraction: 0.85), value: step)
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: ringPulse)

                // Callout: card + connected triangle
                // Card is clamped horizontally; triangle offsets to always point at ring
                let cardWidth: CGFloat = 270
                let cardX = Swift.min(Swift.max(ringX, cardWidth / 2 + 12), screenW - cardWidth / 2 - 12)
                let triangleOffset = ringX - cardX  // horizontal offset so triangle tip meets ring

                let triangleH: CGFloat = 18
                let gap: CGFloat = current.ringSize / 2 + 2  // tight to the ring
                let cardCenterOffset: CGFloat = 68

                let cardY = current.cardAbove
                    ? ringY - gap - cardCenterOffset
                    : ringY + gap + cardCenterOffset

                VStack(spacing: -1) {  // -1pt overlap = seamless connection
                    if !current.cardAbove {
                        TourPointerTriangle(pointsUp: true)
                            .fill(Color(UIColor.secondarySystemBackground))
                            .frame(width: 18, height: triangleH)
                            .offset(x: triangleOffset)
                    }

                    tourCardContent
                        .frame(width: cardWidth)

                    if current.cardAbove {
                        TourPointerTriangle(pointsUp: false)
                            .fill(Color(UIColor.secondarySystemBackground))
                            .frame(width: 18, height: triangleH)
                            .offset(x: triangleOffset)
                    }
                }
                .position(x: cardX, y: cardY)
                .animation(.spring(response: 0.7, dampingFraction: 0.85), value: step)
            }
            .contentShape(Rectangle())
            .onTapGesture { onNext() }
            .onAppear { ringPulse = true }
        }
        .ignoresSafeArea()
    }

    private var tourCardContent: some View {
        VStack(spacing: 8) {
            Text(current.title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(GQColors.textPrimary)

            Text(current.description)
                .font(.system(size: 12))
                .foregroundColor(GQColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    ForEach(0..<steps.count, id: \.self) { i in
                        Circle()
                            .fill(i == step
                                  ? AnyShapeStyle(GQGradients.primary)
                                  : AnyShapeStyle(GQColors.textTertiary.opacity(0.35)))
                            .frame(width: i == step ? 6 : 4, height: i == step ? 6 : 4)
                    }
                }
                Spacer()
                Button(action: onSkip) {
                    Text("Skip")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)
                }
                Button(action: onNext) {
                    Text(isLastStep ? "Done" : "Next")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(GQGradients.primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.thickMaterial)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 10, y: 4)
    }
}

// MARK: - Reverse Mask

extension View {
    func reverseMask<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        self.mask(
            Rectangle()
                .ignoresSafeArea()
                .overlay(
                    content()
                        .blendMode(.destinationOut)
                )
                .compositingGroup()
        )
    }
}

// MARK: - Tour Pointer Triangle

struct TourPointerTriangle: Shape {
    let pointsUp: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if pointsUp {
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Weekly Recap Service
//
// Memo 4 "anticipated cadence" driver. Every Sunday evening, a Weekly Recap
// Proof Card fires. It summarizes the week's work — days trained, total
// volume, top moment — and uses the same Proof Card visual system for
// brand consistency. This is the first product surface that fires on a
// *predictable cadence* independent of workout completion, making it
// the BeReal-equivalent "anticipated moment" for Lift AI.

@MainActor
enum WeeklyRecapService {
    /// Check if the recap is due and build the ProofCardMeta for it.
    /// Returns nil if the user has already seen this week's recap or
    /// if it's not yet past Sunday 6pm.
    static func checkAndBuild(
        profile: UserProfile,
        workouts: [Workout],
        modelContext: ModelContext
    ) -> ProofCardMeta? {
        let calendar = Calendar.current

        // Find "this week's Sunday 6pm" as the trigger point.
        // If today is before Sunday 6pm, no recap yet.
        let now = Date()
        let weekday = calendar.component(.weekday, from: now) // 1=Sun, 7=Sat
        let hour = calendar.component(.hour, from: now)

        // Only fire if it's Sunday (weekday==1) after 6pm, or if it's Monday+
        // and the user still hasn't seen it.
        let isSundayEvening = weekday == 1 && hour >= 18
        let isPastSunday = weekday >= 2  // Mon-Sat means last Sunday is passed

        guard isSundayEvening || isPastSunday else { return nil }

        // Compute the start of "this week" (Monday)
        var cal = calendar
        cal.firstWeekday = 2  // Monday
        guard let weekInterval = cal.dateInterval(of: .weekOfYear, for: now) else { return nil }
        let weekStart = weekInterval.start

        // Check if the user already saw this week's recap
        if let lastSeen = profile.lastWeeklyRecapSeen, lastSeen >= weekStart {
            return nil
        }

        // Gather this week's workouts
        let thisWeekWorkouts = workouts.filter {
            $0.date >= weekStart && $0.date <= now && $0.type != .rest
        }

        let daysTrainedSet = Set(thisWeekWorkouts.map { calendar.startOfDay(for: $0.date) })
        let daysShownUp = daysTrainedSet.count
        let totalVolume = thisWeekWorkouts.reduce(0.0) { $0 + $1.totalVolume }
        let totalSets = thisWeekWorkouts.reduce(0) { $0 + $1.totalSets }

        // Build the headline noticing — past tense, concrete, no emotion
        let headline: String
        if daysShownUp == 0 {
            headline = "Rest week. That counts too."
        } else if daysShownUp == 1 {
            headline = "One day this week. One more than zero."
        } else if daysShownUp >= 5 {
            headline = "\(daysShownUp) days this week. Consistency locked."
        } else {
            headline = "\(daysShownUp) days shown up."
        }

        // Top moment: the heaviest set or biggest volume workout
        var topMoment: String? = nil
        var heaviestWeight: Double = 0
        for workout in thisWeekWorkouts {
            for exercise in workout.exercises {
                for set in exercise.sets where set.weight > heaviestWeight {
                    heaviestWeight = set.weight
                    topMoment = "\(exercise.name) · \(Int(set.weight)) × \(set.reps)"
                }
            }
        }

        // Volume formatting
        let volumeStr: String
        if totalVolume >= 10_000 {
            volumeStr = String(format: "%.1fk lb", totalVolume / 1000.0)
        } else {
            volumeStr = "\(Int(totalVolume)) lb"
        }

        let weekNumber = calendar.component(.weekOfYear, from: now)
        let summary = "Week \(weekNumber) · \(daysShownUp) days · \(volumeStr) · \(totalSets) sets"

        return ProofCardMeta(
            headline: headline,
            hardestMoment: topMoment,
            summaryLine: summary,
            workoutTypeRaw: "Weekly",
            signedName: profile.name,
            createdAt: now,
            variant: "weeklyRecap",
            verificationStatus: "verified",
            styleVariant: ProofCardVariantPicker.pick(for: UUID())
        )
    }
}

// MARK: - Weekly Recap View

struct WeeklyRecapView: View {
    let meta: ProofCardMeta
    let profile: UserProfile
    let onDismiss: () -> Void

    @State private var hasAppeared = false
    @State private var showShareSheet = false
    @State private var shareImage: UIImage? = nil

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, GQColors.deepBlue.opacity(0.3), Color.black],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("WEEKLY RECAP")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.55))
                    Spacer()
                    Color.clear.frame(width: 36, height: 36) // balance
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                ProofCardBody(meta: meta)
                    .padding(.horizontal, 28)
                    .scaleEffect(hasAppeared ? 1.0 : 0.85)
                    .opacity(hasAppeared ? 1.0 : 0)

                Spacer()

                VStack(spacing: 12) {
                    #if canImport(UIKit)
                    Button {
                        let renderer = ImageRenderer(content: ProofCardBody(meta: meta).frame(width: 380).padding(24).background(Color.black))
                        renderer.scale = 3.0
                        renderer.isOpaque = true
                        if let image = renderer.uiImage {
                            shareImage = image
                            showShareSheet = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .bold))
                            Text("Share your week")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(GQGradients.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: GQColors.vividPurple.opacity(0.3), radius: 14, y: 8)
                    }
                    #endif

                    // Gentle monetization touchpoint — memo 5 rank 7. A soft Pro
                    // badge that shows what premium unlocks without gating the free
                    // recap. No urgency, no "limited time," no pressure.
                    if !profile.isPremium {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10, weight: .bold))
                            Text("Pro unlocks deeper analytics + AI plans")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.vertical, 6)
                    }

                    Button(action: onDismiss) {
                        Text("Dismiss")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                hasAppeared = true
            }
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            #endif
        }
        #if canImport(UIKit)
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ShareSheetView(items: [image])
            }
        }
        #endif
    }
}
