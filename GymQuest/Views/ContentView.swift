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
        ZStack {
            // Background extends to all edges
            Color(white: 0.05)
                .ignoresSafeArea(.all)

            // main content
            switch appState.selectedTab {
            case .home:
                if appState.activeWorkoutType == nil {
                    HomeView(profile: profile)
                }
            case .feed:
                FeedView(profile: profile)
            case .coach:
                CoachView(profile: profile, workouts: workouts, aiService: aiService)
            case .progress:
                TrainingProgressView(profile: profile, workouts: workouts, aiService: aiService)
            case .profile:
                ProfileView(profile: profile)
            }

            // Active workout view — kept alive outside the switch so state persists across tab changes
            if let workoutType = appState.activeWorkoutType {
                ActiveWorkoutView(profile: profile, workoutType: workoutType)
                    .opacity(appState.selectedTab == .home ? 1 : 0)
                    .allowsHitTesting(appState.selectedTab == .home)
            }

            // Mini workout bar on non-Home tabs (positioned at bottom above tab bar)
            if appState.activeWorkoutType != nil && appState.selectedTab != .home {
                VStack {
                    Spacer()
                    MiniWorkoutBar(workoutType: appState.activeWorkoutType ?? .push) {
                        appState.selectedTab = .home
                    }
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .gesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { value in
                    let horizontal = value.translation.width
                    let vertical = value.translation.height
                    // Only trigger on mostly-horizontal swipes
                    guard abs(horizontal) > abs(vertical) * 1.5 else { return }
                    guard let currentIndex = allTabs.firstIndex(of: appState.selectedTab) else { return }
                    if horizontal < -50, currentIndex < allTabs.count - 1 {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            appState.selectedTab = allTabs[currentIndex + 1]
                        }
                    } else if horizontal > 50, currentIndex > 0 {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            appState.selectedTab = allTabs[currentIndex - 1]
                        }
                    }
                }
        )
        .safeAreaInset(edge: .bottom) {
            FloatingTabBar()
        }
        .sheet(isPresented: $appState.showingLogWorkout) {
            LogWorkoutView(profile: profile)
        }
        .sheet(item: $appState.selectedSession) { session in
            SessionDetailView(session: session)
        }
        .onAppear {
            AnalyticsService.shared.configure(modelContext: modelContext)
        }
    }
}

// MARK: - Floating Glass Tab Bar

struct FloatingTabBar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                FloatingTabButton(tab: .home, icon: "house", selectedIcon: "house.fill", label: "Home")

                FloatingTabButton(tab: .feed, icon: "person.2", selectedIcon: "person.2.fill", label: "Social")

                // Center add button - with animated gradient border
                Button {
                    #if canImport(UIKit)
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    #endif
                    appState.showingLogWorkout = true
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
                            .fill(Color(white: 0.05))
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
                .buttonStyle(.plain)
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
            Color(white: 0.05)
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 0.5),
                    alignment: .top
                )
        )
        .ignoresSafeArea(.container, edges: .bottom)
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
                } else {
                    Image(systemName: displayIcon)
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? tabColor : GQColors.textTertiary)
                }

                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? tabColor : GQColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
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

                // Show rest countdown when resting
                if appState.isResting && appState.restTimeRemaining > 0 {
                    HStack(spacing: 5) {
                        Image(systemName: "pause.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(GQColors.cyanSpark)
                        Text("Rest \(appState.restTimeRemaining)s")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(GQColors.cyanSpark)
                            .contentTransition(.numericText())
                            .monospacedDigit()
                    }
                } else {
                    Text("Tap to return")
                        .font(.system(size: 12))
                        .foregroundColor(GQColors.textSecondary)
                }

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
                                appState.isResting ? GQColors.cyanSpark.opacity(0.4) : GQColors.vividPurple.opacity(0.4),
                                lineWidth: 1
                            )
                    )
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .animation(.easeInOut(duration: 0.3), value: appState.isResting)
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

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(FeatureFlags.shared)
        .modelContainer(for: [Workout.self, UserProfile.self], inMemory: true)
        .preferredColorScheme(.dark)
}
