import XCTest
import SwiftUI
import SnapshotTesting
@testable import GymQuest

final class DesignSystemSnapshotTests: SnapshotTestCase {

    // MARK: - GlassCard

    func testGlassCard_snapshot() {
        // record = true  // Uncomment to record reference images

        let view = GlassCard {
            VStack(spacing: 8) {
                Text("Test Card")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("This is a glass card component")
                    .font(.caption)
                    .foregroundStyle(GQColors.textSecondary)
            }
            .padding()
        }
        .frame(width: 300, height: 150)
        .padding()
        .background(GQColors.deepBlack)

        assertSnapshot(of: view, named: "GlassCard")
    }

    // MARK: - StatPill

    func testStatPill_snapshot() {
        // record = true

        let view = HStack(spacing: 12) {
            StatPill(icon: "flame.fill", value: "5", label: "Streak")
            StatPill(icon: "dumbbell.fill", value: "12", label: "Sets")
            StatPill(icon: "chart.bar.fill", value: "2.5k", label: "Volume")
        }
        .padding()
        .background(GQColors.deepBlack)

        assertSnapshot(of: view, named: "StatPills")
    }

    // MARK: - AnimatedProgressBar

    func testAnimatedProgressBar_variousProgress() {
        // record = true

        let view = VStack(spacing: 16) {
            AnimatedProgressBar(progress: 0.0)
            AnimatedProgressBar(progress: 0.25)
            AnimatedProgressBar(progress: 0.50)
            AnimatedProgressBar(progress: 0.75)
            AnimatedProgressBar(progress: 1.0)
        }
        .frame(width: 300)
        .padding()
        .background(GQColors.deepBlack)

        assertSnapshot(of: view, named: "AnimatedProgressBar")
    }

    // MARK: - Button Styles

    func testButtonStyles_snapshot() {
        // record = true

        let view = VStack(spacing: 16) {
            Button("Primary Button") {}
                .buttonStyle(PrimaryButtonStyle())

            Button("Secondary Button") {}
                .buttonStyle(SecondaryButtonStyle())
        }
        .frame(width: 300)
        .padding()
        .background(GQColors.deepBlack)

        assertSnapshot(of: view, named: "ButtonStyles")
    }
}
