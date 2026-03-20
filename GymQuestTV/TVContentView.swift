import SwiftUI

#if os(tvOS)

struct TVContentView: View {
    @State private var selectedTab = 0
    @FocusState private var focusedTab: Int?

    private let offWhite = Color(white: 0.93)

    private let tabs: [(String, String)] = [
        ("Dashboard", "house.fill"),
        ("Feed", "person.2.fill"),
        ("Workout", "dumbbell.fill"),
        ("Progress", "chart.line.uptrend.xyaxis")
    ]

    private var isTabBarFocused: Bool {
        focusedTab != nil
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Content
            Group {
                switch selectedTab {
                case 0: TVDashboardView()
                case 1: TVFeedView()
                case 2: TVWorkoutView()
                case 3: TVProgressView()
                default: TVDashboardView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 64)

            // Tab bar — always visible, all tabs shown equally
            HStack(spacing: 36) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    HStack(spacing: 8) {
                        Image(systemName: tabs[index].1)
                            .font(.system(size: 20, weight: .medium))
                        Text(tabs[index].0)
                            .font(.system(size: 22, weight: focusedTab == index ? .semibold : .medium, design: .rounded))
                    }
                    .foregroundColor(offWhite.opacity(focusedTab == index ? 1.0 : 0.5))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(focusedTab == index ? Color.white.opacity(0.15) : Color.clear)
                    )
                    .scaleEffect(focusedTab == index ? 1.04 : 1.0)
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
        }
        .background(Color(white: 0.11).ignoresSafeArea())
    }
}

#endif
