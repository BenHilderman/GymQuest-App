//
//  WeeklyProgressRing.swift
//  GymQuest
//
//  Created by Benjamin Hilderman
//
//  Circular progress ring showing weekly workout completion.
//

import SwiftUI

struct WeeklyProgressRing: View {
    let completed: Int
    let target: Int

    @State private var animatedProgress: CGFloat = 0

    private var progress: CGFloat {
        guard target > 0 else { return 0 }
        return min(CGFloat(completed) / CGFloat(target), 1.0)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(GQColors.borderDefault, lineWidth: 10)
                    .frame(width: 150, height: 150)

                // Foreground progress ring
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        GQGradients.primary,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))

                // Center content
                VStack(spacing: 2) {
                    Text("\(completed)")
                        .font(GQTypography.heroMetric)
                        .foregroundStyle(GQColors.textPrimary)
                    Text("of \(target)")
                        .font(GQTypography.caption)
                        .foregroundStyle(GQColors.textTertiary)
                }
            }

            Text("workouts this week")
                .font(GQTypography.cardBody)
                .foregroundStyle(GQColors.textSecondary)
        }
        .padding(.vertical, 12)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animatedProgress = progress
            }
        }
        .onChange(of: completed) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animatedProgress = progress
            }
        }
    }
}
