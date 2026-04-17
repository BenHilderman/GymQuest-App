import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Full-screen interrupt slotted between Shorts clips every ~8 cards.
/// Pulls the user back to a runnable workout without leaving the scroll —
/// the bridge that prevents Shorts from feeling like infinite candy.
struct WorkoutInterruptCard: View {
    let post: Post
    let onStart: () -> Void
    let onSkip: () -> Void

    var body: some View {
        ZStack {
            // Backdrop: subtle brand gradient so this card reads as
            // qualitatively different from a Shorts clip.
            LinearGradient(
                colors: [GQColors.accent.opacity(0.85), .black],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                Text("READY TO TRAIN?")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.white.opacity(0.7))
                    .tracking(2.0)

                Text(displayTitle)
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                metaRow
                    .padding(.top, 4)

                Spacer()

                Button(action: onStart) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill").font(.system(size: 16, weight: .bold))
                        Text("Start workout").font(.system(size: 17, weight: .heavy))
                    }
                    .foregroundColor(GQColors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(.white))
                    .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)

                Button("Keep scrolling", action: onSkip)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 120)
            }
        }
        .background(Color.black)
    }

    private var displayTitle: String {
        if let data = post.sharedWorkoutData,
           let shared = try? JSONDecoder().decode(SharedWorkoutData.self, from: data),
           !shared.title.isEmpty {
            return shared.title
        }
        if let highlight = post.exerciseHighlight { return highlight }
        if let type = post.workoutType { return "\(type.capitalized) Session" }
        return "Today's Pick"
    }

    private var metaRow: some View {
        HStack(spacing: 8) {
            if let dur = post.duration, dur > 0 {
                metaChip(icon: "clock.fill", text: "\(dur) min")
            }
            if let type = post.workoutType {
                metaChip(icon: "tag.fill", text: type.capitalized)
            }
        }
    }

    private func metaChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold))
            Text(text).font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Capsule().fill(.white.opacity(0.22)))
    }
}
