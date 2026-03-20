import SwiftUI

#if os(tvOS)

// Environment key for navigating to Workout tab from Dashboard
private struct SwitchToWorkoutKey: EnvironmentKey {
    static let defaultValue: (WorkoutType) -> Void = { _ in }
}

extension EnvironmentValues {
    var switchToWorkout: (WorkoutType) -> Void {
        get { self[SwitchToWorkoutKey.self] }
        set { self[SwitchToWorkoutKey.self] = newValue }
    }
}

struct TVContentView: View {
    @State private var selectedTab = 0
    @State private var pendingWorkoutType: WorkoutType?
    @FocusState private var focusedTab: Int?

    private let offWhite = Color(white: 0.93)

    private let tabs: [(String, String)] = [
        ("Dashboard", "house.fill"),
        ("Feed", "person.2.fill"),
        ("Workout", "dumbbell.fill"),
        ("Progress", "chart.line.uptrend.xyaxis")
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 36) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    let isFocused = focusedTab == index
                    let isSelected = selectedTab == index

                    HStack(spacing: 8) {
                        Image(systemName: tabs[index].1)
                            .font(.system(size: 20, weight: .medium))
                        Text(tabs[index].0)
                            .font(.system(size: 22, weight: isFocused || isSelected ? .semibold : .medium, design: .rounded))
                    }
                    .foregroundColor(
                        isFocused ? offWhite :
                        isSelected ? offWhite.opacity(0.7) :
                        offWhite.opacity(0.4)
                    )
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(isFocused ? Color.white.opacity(0.15) : Color.clear)
                    )
                    .scaleEffect(isFocused ? 1.04 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: focusedTab)
                    .focusable()
                    .focused($focusedTab, equals: index)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.5
                            )
                    )
            )
            .padding(.top, 20)
            .padding(.bottom, 12)
            .onChange(of: focusedTab) { _, newValue in
                if let tab = newValue {
                    selectedTab = tab
                }
            }

            // Content
            Group {
                switch selectedTab {
                case 0:
                    TVDashboardView()
                        .environment(\.switchToWorkout, { type in
                            pendingWorkoutType = type
                            selectedTab = 2
                            focusedTab = 2
                        })
                case 1: TVFeedView()
                case 2: TVWorkoutView(quickStartType: pendingWorkoutType)
                case 3: TVProgressView()
                default: TVDashboardView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(white: 0.11).ignoresSafeArea())
    }
}

#endif
