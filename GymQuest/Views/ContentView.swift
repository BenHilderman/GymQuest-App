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
            // All views rendered simultaneously, visibility controlled by opacity
            // This prevents the black flash by keeping views pre-rendered
            ZStack {
                FeedView(profile: profile)
                    .opacity(appState.selectedTab == .feed ? 1 : 0)
                    .allowsHitTesting(appState.selectedTab == .feed)

                ProfileView(profile: profile)
                    .opacity(appState.selectedTab == .profile ? 1 : 0)
                    .allowsHitTesting(appState.selectedTab == .profile)
            }
            .transaction { transaction in
                // Keep tab changes deterministic with no implicit crossfade animations.
                transaction.animation = nil
            }
            .ignoresSafeArea(.keyboard)

            // Now playing + active workout mini-bar + tab bar
            VStack(spacing: 0) {
                NowPlayingBar()
                    .padding(.bottom, 4)

                // Mini-bar when workout is active and not on home tab
                if appState.isWorkoutActive && appState.selectedTab != .home {
                    ActiveWorkoutMiniBar()
                }

                // Custom floating tab bar overlay
                FloatingTabBar()
            }

            // Active workout view — kept alive outside the switch so state persists across tab changes
            if let workout = appState.activeWorkout {
                ActiveWorkoutView(profile: profile, workoutType: workout.workoutType, exercises: workout.exercises, customTitle: workout.customTitle)
                    .opacity(appState.selectedTab == .home && !appState.isWorkoutPaused ? 1 : 0)
                    .allowsHitTesting(appState.selectedTab == .home && !appState.isWorkoutPaused)
            }

            // Mini workout bar on non-Home tabs (positioned at bottom above tab bar)
            if appState.isWorkoutActive && appState.selectedTab != .home {
                VStack {
                    Spacer()
                    MiniWorkoutBar(workoutType: appState.activeWorkout?.workoutType ?? .push) {
                        appState.selectedTab = .home
                    }
                }
            }

            // Resume bar when paused on Home tab
            if appState.isWorkoutActive && appState.isWorkoutPaused && appState.selectedTab == .home {
                VStack {
                    Spacer()
                    MiniWorkoutBar(workoutType: appState.activeWorkout?.workoutType ?? .push) {
                        appState.resumeWorkout()
                    }
                }
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
        .sheet(isPresented: $appState.showingQuickActions) {
            QuickActionSheet()
                .presentationDetents([.height(340)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $appState.showingLogEntry) {
            LogView(profile: profile)
        }
        .onAppear {
            AnalyticsService.shared.configure(modelContext: modelContext)
        }
    }
}

// MARK: - Tab Bar Notch Shape

struct TabBarNotchShape: Shape {
    let notchRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let midX = rect.midX
        let transition: CGFloat = 8
        let notchLeft = midX - notchRadius - transition
        let notchRight = midX + notchRadius + transition

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: notchLeft, y: rect.minY))

        // Smooth entry curve into notch
        path.addQuadCurve(
            to: CGPoint(x: midX - notchRadius, y: rect.minY + notchRadius * 0.35),
            control: CGPoint(x: midX - notchRadius - transition * 0.15, y: rect.minY)
        )

        // Semicircular scoop
        path.addArc(
            center: CGPoint(x: midX, y: rect.minY + notchRadius * 0.35),
            radius: notchRadius,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: true
        )

        // Smooth exit curve out of notch
        path.addQuadCurve(
            to: CGPoint(x: notchRight, y: rect.minY),
            control: CGPoint(x: midX + notchRadius + transition * 0.15, y: rect.minY)
        )

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Floating Glass Tab Bar

struct FloatingTabBar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    FloatingTabButton(tab: .feed, icon: "house", selectedIcon: "house.fill", label: "Home")

                    if SocialActivityService.shared.hasLiveFriends {
                        SocialActivityBadge()
                            .offset(x: -14, y: 2)
                    }
                }

                // Center add button
                Button {
                    appState.showingQuickActions = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(GQGradients.primary)
                            .frame(width: 46, height: 46)

                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(GQInteractiveStyle(scaleAmount: 0.90, hapticStyle: .medium))
                .frame(maxWidth: .infinity)
                .offset(y: -6)
                .accessibilityLabel("Quick actions")
                .accessibilityHint("Double tap to start a workout, log entry, or create a post")

                FloatingTabButton(tab: .profile, icon: "person", selectedIcon: "person.fill", label: "You")
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 2)
        }
        .padding(.bottom, 4)
        .background(
            ZStack(alignment: .top) {
                TabBarNotchShape(notchRadius: 17)
                    .fill(GQColors.surfaceBase.opacity(0.82))
                TabBarNotchShape(notchRadius: 17)
                    .fill(.ultraThinMaterial)
                TabBarNotchShape(notchRadius: 17)
                    .stroke(GQColors.borderSubtle.opacity(0.4), lineWidth: 0.5)
                // Top divider
                Rectangle()
                    .fill(GQColors.borderSubtle)
                    .frame(height: 0.5)
            }
            .ignoresSafeArea(.container, edges: .bottom)
        )
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
                    .foregroundColor(GQColors.cyanSpark)

                Text("Return")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(GQColors.vividPurple)
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
                    .fill(GQColors.vividPurple)
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
                                GQColors.vividPurple.opacity(0.4),
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
            .padding(.bottom, 14)

            VStack(spacing: 10) {
                quickActionCard(
                    icon: "figure.strengthtraining.traditional",
                    title: "Start Workout",
                    subtitle: "Begin a live session",
                    accent: GQColors.vividPurple,
                    emphasized: true
                ) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        appState.showingWorkoutStartOptions = true
                    }
                }

                quickActionCard(
                    icon: "square.and.pencil",
                    title: "Log Workout",
                    subtitle: "Log a past session manually",
                    accent: GQColors.cyanSpark
                ) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        appState.showingLogEntry = true
                    }
                }

                quickActionCard(
                    icon: "camera.fill",
                    title: "New Post",
                    subtitle: "Share with friends",
                    accent: GQColors.sunsetOrange
                ) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        appState.showingCreatePost = true
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .gqPageBackground()
    }

    @ViewBuilder
    private func quickActionCard(
        icon: String,
        title: String,
        subtitle: String,
        accent: Color,
        emphasized: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(accent.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(GQColors.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .homeSocialCard(accent: accent, emphasized: emphasized)
        }
        .buttonStyle(GQInteractiveStyle())
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

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(FeatureFlags.shared)
        .modelContainer(for: [Workout.self, UserProfile.self], inMemory: true)
}
