import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// First-launch walkthrough teaching the four pillars of the app:
/// Train, Shorts, Community, Rhythms. Presented as a fullscreen cover on
/// first run and replayable from Profile settings. Swipe-paging with a
/// "Let's go" CTA on the final page.
struct OnboardingFlow: View {
    @Binding var isPresented: Bool

    @State private var page: Int = 0

    private struct Page {
        let eyebrow: String
        let title: String
        let body: String
        let icon: String
        let accentColor: Color
    }

    private let pages: [Page] = [
        Page(
            eyebrow: "YOUR GYM HOME",
            title: "Train-first, always",
            body: "Open Feed and you land on Train: tonight's pick, your saved workouts, and shelves tailored to your week. Your crew's clips live one tap away — not in your face.",
            icon: "figure.strengthtraining.traditional",
            accentColor: .orange
        ),
        Page(
            eyebrow: "WHEN YOU WANT TO SCROLL",
            title: "Shorts are there for you",
            body: "Tap Shorts for a vertical scroll of real workout clips — form tutorials, PR moments, squad inspiration. Every eight clips, a workout you can start instantly.",
            icon: "play.rectangle.fill",
            accentColor: .purple
        ),
        Page(
            eyebrow: "NEVER ALONE",
            title: "Your crew is working out with you",
            body: "See who's training right now. Send support with one tap. Long-press the heart on any clip for 🔥💪👀🙌. Clubs bring the group back.",
            icon: "person.3.fill",
            accentColor: .pink
        ),
        Page(
            eyebrow: "CONSISTENCY TOGETHER",
            title: "Rhythms, not streaks",
            body: "Your week is collective. \"Your crew trained 5 of 7 days — you're in for 3.\" Missing a day feels like letting down a friend, not a counter.",
            icon: "sparkles",
            accentColor: .blue
        )
    ]

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                pager
                footer
            }
        }
    }

    // MARK: - Background

    private var background: some View {
        LinearGradient(
            colors: [
                pages[page].accentColor.opacity(0.28),
                Color.black
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.45), value: page)
    }

    // MARK: - Pager

    private var pager: some View {
        TabView(selection: $page) {
            ForEach(pages.indices, id: \.self) { idx in
                pageView(pages[idx])
                    .tag(idx)
            }
        }
        #if os(iOS)
        .tabViewStyle(.page(indexDisplayMode: .never))
        #endif
        .frame(maxHeight: .infinity)
    }

    private func pageView(_ p: Page) -> some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(p.accentColor.opacity(0.2))
                    .frame(width: 160, height: 160)
                Image(systemName: p.icon)
                    .font(.system(size: 72, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, p.accentColor.opacity(0.9)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            }

            VStack(spacing: 14) {
                Text(p.eyebrow)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.white.opacity(0.7))
                    .tracking(2.0)

                Text(p.title)
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(p.body)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 28)
            }

            Spacer()
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 18) {
            // Dots indicator
            HStack(spacing: 6) {
                ForEach(pages.indices, id: \.self) { idx in
                    Capsule()
                        .fill(idx == page ? Color.white : .white.opacity(0.3))
                        .frame(width: idx == page ? 20 : 6, height: 6)
                        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: page)
                }
            }

            HStack(spacing: 12) {
                if page > 0 {
                    Button("Back") {
                        withAnimation { page = max(0, page - 1) }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 80, height: 48)
                    .background(Capsule().fill(.white.opacity(0.1)))
                    .buttonStyle(.plain)
                }

                Button {
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    #endif
                    if page < pages.count - 1 {
                        withAnimation { page += 1 }
                    } else {
                        isPresented = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(page < pages.count - 1 ? "Next" : "Let's go")
                            .font(.system(size: 16, weight: .heavy))
                        if page == pages.count - 1 {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .foregroundColor(pages[page].accentColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Capsule().fill(Color.white))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)

            Button("Skip") {
                isPresented = false
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white.opacity(0.55))
            .buttonStyle(.plain)
        }
        .padding(.bottom, 32)
    }
}
