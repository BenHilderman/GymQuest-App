//
//  WorkoutLaunchOverlay.swift
//  GymQuest
//
//  Full-screen 3-2-1-GO countdown before a workout begins.
//  Animated numbers with expanding pulse rings and haptics.
//

import SwiftUI

struct WorkoutLaunchOverlay: View {
    let workoutType: WorkoutType
    let onComplete: () -> Void

    @State private var currentNumber: Int = 3
    @State private var numberScale: CGFloat = 0.3
    @State private var numberOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.5
    @State private var ringOpacity: Double = 0
    @State private var showGo: Bool = false
    @State private var goScale: CGFloat = 0.3
    @State private var goOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Workout type label at top
            VStack {
                Text(workoutType.rawValue.uppercased())
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(6)
                    .padding(.top, 80)
                Spacer()
            }

            // Expanding pulse ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [GQColors.vividPurple, GQColors.cyanSpark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: 200, height: 200)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)

            // Countdown numbers
            if !showGo {
                Text("\(currentNumber)")
                    .font(.system(size: 120, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .scaleEffect(numberScale)
                    .opacity(numberOpacity)
            } else {
                Text("GO!")
                    .font(.system(size: 100, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [GQColors.vividPurple, GQColors.cyanSpark],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .scaleEffect(goScale)
                    .opacity(goOpacity)
            }
        }
        .onAppear {
            startCountdown()
        }
    }

    private func startCountdown() {
        // Beat 3
        animateBeat()
        HapticManager.shared.countdownBeat()

        // Beat 2
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            currentNumber = 2
            animateBeat()
            HapticManager.shared.countdownBeat()
        }

        // Beat 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            currentNumber = 1
            animateBeat()
            HapticManager.shared.countdownBeat()
        }

        // GO!
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.7) {
            showGo = true
            HapticManager.shared.countdownGo()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                goScale = 1.0
                goOpacity = 1.0
            }
            // Expand ring on GO
            withAnimation(.easeOut(duration: 0.6)) {
                ringScale = 3.0
                ringOpacity = 0.0
            }
        }

        // Dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.3) {
            withAnimation(.easeOut(duration: 0.2)) {
                goOpacity = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            onComplete()
        }
    }

    private func animateBeat() {
        // Reset
        numberScale = 0.3
        numberOpacity = 0
        ringScale = 0.5
        ringOpacity = 0.6

        // Animate number in
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            numberScale = 1.0
            numberOpacity = 1.0
        }

        // Expand pulse ring
        withAnimation(.easeOut(duration: 0.7)) {
            ringScale = 2.0
            ringOpacity = 0.0
        }

        // Fade number out
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                numberOpacity = 0.3
            }
        }
    }
}

#Preview {
    WorkoutLaunchOverlay(workoutType: .push, onComplete: {})
}
