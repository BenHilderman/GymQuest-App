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
