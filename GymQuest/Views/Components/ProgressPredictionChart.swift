//
//  ProgressPredictionChart.swift
//  GymQuest
//
//  Created by Benjamin Hilderman
//
//  Simple ascending line chart shown during onboarding to
//  visualize expected progress over the first 8 weeks.
//

import SwiftUI

struct ProgressPredictionChart: View {
    @State private var animatedProgress: CGFloat = 0

    // Normalized Y values for an ascending curve (0-1)
    private let dataPoints: [CGFloat] = [0.05, 0.12, 0.22, 0.35, 0.50, 0.65, 0.80, 0.92]

    var body: some View {
        VStack(spacing: 8) {
            // Chart
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let stepX = w / CGFloat(dataPoints.count - 1)

                ZStack(alignment: .bottomLeading) {
                    // Grid lines
                    ForEach(0..<4) { i in
                        let y = h * CGFloat(i) / 3.0
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: w, y: y))
                        }
                        .stroke(GQColors.borderSubtle, lineWidth: 0.5)
                    }

                    // Gradient fill under curve
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: h))
                        for (i, point) in dataPoints.enumerated() {
                            let x = stepX * CGFloat(i)
                            let y = h - (point * h * animatedProgress)
                            if i == 0 {
                                path.addLine(to: CGPoint(x: x, y: y))
                            } else {
                                let prevX = stepX * CGFloat(i - 1)
                                let prevY = h - (dataPoints[i - 1] * h * animatedProgress)
                                let midX = (prevX + x) / 2
                                path.addCurve(
                                    to: CGPoint(x: x, y: y),
                                    control1: CGPoint(x: midX, y: prevY),
                                    control2: CGPoint(x: midX, y: y)
                                )
                            }
                        }
                        path.addLine(to: CGPoint(x: w, y: h))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [GQColors.deepBlue.opacity(0.25), GQColors.vividPurple.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // Line curve
                    Path { path in
                        for (i, point) in dataPoints.enumerated() {
                            let x = stepX * CGFloat(i)
                            let y = h - (point * h * animatedProgress)
                            if i == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                let prevX = stepX * CGFloat(i - 1)
                                let prevY = h - (dataPoints[i - 1] * h * animatedProgress)
                                let midX = (prevX + x) / 2
                                path.addCurve(
                                    to: CGPoint(x: x, y: y),
                                    control1: CGPoint(x: midX, y: prevY),
                                    control2: CGPoint(x: midX, y: y)
                                )
                            }
                        }
                    }
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        GQGradients.primary,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )
                }
            }
            .frame(height: 100)

            // Week labels
            HStack {
                ForEach(1...8, id: \.self) { week in
                    Text("W\(week)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(GQColors.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 4)
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).delay(0.3)) {
                animatedProgress = 1.0
            }
        }
    }
}
