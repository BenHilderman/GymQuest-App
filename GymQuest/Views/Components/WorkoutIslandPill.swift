import SwiftUI

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
                    appState.selectedTab = .home
                    if appState.isWorkoutPaused {
                        appState.resumeWorkout()
                    }
                }
            }
            .onLongPressGesture(minimumDuration: 0.3) {
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
