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
                            .tint(.white)
                            .scaleEffect(1.2)
                        Text("Loading...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(GQColors.textSecondary)
                    }
                }
            }
        }
    }

    private var allTabs: [AppState.Tab] { AppState.Tab.allCases }

    @ViewBuilder
    private func mainContent(profile: UserProfile) -> some View {
        ZStack(alignment: .bottom) {
            // All views rendered simultaneously, visibility controlled by opacity
            // This prevents the black flash by keeping views pre-rendered
            ZStack {
                HomeView(profile: profile)
                    .opacity(appState.selectedTab == .home ? 1 : 0)
                    .allowsHitTesting(appState.selectedTab == .home)

                FeedView(profile: profile)
                    .opacity(appState.selectedTab == .feed ? 1 : 0)
                    .allowsHitTesting(appState.selectedTab == .feed)

                CoachView(profile: profile, workouts: workouts, aiService: aiService)
                    .opacity(appState.selectedTab == .coach ? 1 : 0)
                    .allowsHitTesting(appState.selectedTab == .coach)

                TrainingProgressView(profile: profile, workouts: workouts, aiService: aiService)
                    .opacity(appState.selectedTab == .progress ? 1 : 0)
                    .allowsHitTesting(appState.selectedTab == .progress)

                ProfileView(profile: profile)
                    .opacity(appState.selectedTab == .profile ? 1 : 0)
                    .allowsHitTesting(appState.selectedTab == .profile)
            }
            .transaction { transaction in
                // Keep tab changes deterministic with no implicit crossfade animations.
                transaction.animation = nil
            }
            .ignoresSafeArea(.keyboard)

            // Active workout mini-bar + tab bar
            VStack(spacing: 0) {
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
                    .opacity(appState.selectedTab == .home ? 1 : 0)
                    .allowsHitTesting(appState.selectedTab == .home)
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
                FloatingTabButton(tab: .home, icon: "house", selectedIcon: "house.fill", label: "Home")

                ZStack(alignment: .topTrailing) {
                    FloatingTabButton(tab: .feed, icon: "person.2", selectedIcon: "person.2.fill", label: "Social")

                    if SocialActivityService.shared.hasLiveFriends {
                        SocialActivityBadge()
                            .offset(x: -14, y: 2)
                    }
                }

                // Center add button - with animated gradient border
                Button {
                    appState.showingWorkoutStartOptions = true
                } label: {
                    ZStack {
                        // Subtle glow
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [GQColors.vividPurple.opacity(0.3), Color.clear],
                                    center: .center,
                                    startRadius: 15,
                                    endRadius: 30
                                )
                            )
                            .frame(width: 54, height: 54)

                        // Dark solid fill
                        Circle()
                            .fill(GQColors.surfaceBase)
                            .frame(width: 46, height: 46)

                        // Animated gradient border
                        AnimatedGradientCircle(
                            size: 46,
                            lineWidth: 2,
                            colors: [GQColors.vividPurple, GQColors.cyanSpark, GQColors.vividPurple],
                            duration: 4.0
                        )

                        // Plus icon
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(GQInteractiveStyle(scaleAmount: 0.90, hapticStyle: .medium))
                .frame(maxWidth: .infinity)
                .offset(y: -6)
                .accessibilityLabel("Log workout")
                .accessibilityHint("Double tap to start logging a new workout")

                FloatingTabButton(tab: .progress, icon: "chart.bar", selectedIcon: "chart.bar.fill", label: "Stats")

                FloatingTabButton(tab: .profile, icon: "person", selectedIcon: "person.fill", label: "Profile")
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 2)
        }
        .background(
            ZStack(alignment: .top) {
                TabBarNotchShape(notchRadius: 17)
                    .fill(GQColors.deepBlack)
                TabBarNotchShape(notchRadius: 17)
                    .stroke(GQColors.borderSubtle.opacity(0.4), lineWidth: 0.5)
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
                        .foregroundColor(.white)

                    Text(workout.workoutType.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
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
                            .fill(
                                LinearGradient(
                                    colors: [GQColors.vividPurple.opacity(0.3), Color.clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
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
        return .white
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
                    .foregroundColor(.white)

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
                    .fill(Color(white: 0.1))
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
        .preferredColorScheme(.dark)
}
