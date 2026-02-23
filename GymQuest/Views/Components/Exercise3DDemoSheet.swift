//
//  Exercise3DDemoSheet.swift
//  GymQuest
//
//  Interactive 3D exercise demonstration sheet
//  Displays 3D models with rotation controls and form cues
//

import SwiftUI

struct Exercise3DDemoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let exerciseName: String

    @State private var model: ExerciseDemo3D?
    @State private var currentAngle: ViewAngle = .side
    @State private var isPlaying = true
    @State private var playbackSpeed: Float = 1.0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 3D Viewer
                    Exercise3DViewer(
                        modelName: model?.modelFileName ?? exerciseName,
                        currentAngle: $currentAngle
                    )
                    .frame(height: 350)

                    // Rotation hint for beginners
                    HStack(spacing: 6) {
                        Image(systemName: "hand.draw")
                            .font(.system(size: 14))
                        Text("Drag to rotate view")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.secondary)
                    .padding(.top, -8)

                    // Quick angle buttons
                    quickAngleButtons

                    // Playback controls
                    playbackControlsSection

                    // Form cues
                    if let cues = model?.cues, !cues.isEmpty {
                        formCuesSection(cues: cues)
                    } else if let demo = RobotDemoService.shared.getDemoAnimation(for: exerciseName) {
                        // Fall back to 2D demo cues
                        let allCues = demo.keyframes.flatMap { $0.cues }
                        let uniqueCues = Array(Set(allCues))
                        if !uniqueCues.isEmpty {
                            formCuesSection(cues: uniqueCues)
                        }
                    }

                    // Key joints legend
                    if let joints = model?.keyJoints, !joints.isEmpty {
                        keyJointsLegend(joints: joints)
                    } else if let demo = RobotDemoService.shared.getDemoAnimation(for: exerciseName) {
                        keyJointsLegend(joints: demo.keyJoints)
                    }

                    // Tempo info
                    if let tempo = model?.tempo {
                        tempoSection(tempo: tempo)
                    } else if let demo = RobotDemoService.shared.getDemoAnimation(for: exerciseName) {
                        tempoSection(tempo: demo.tempo)
                    }

                    // Info section
                    infoSection
                }
                .padding(16)
            }
            .gqPageBackground()
            .navigationTitle(exerciseName)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                loadModel()
            }
        }
    }

    // MARK: - Quick Angle Buttons

    private var quickAngleButtons: some View {
        HStack(spacing: 12) {
            AngleButton(label: "Front", angle: .front, currentAngle: $currentAngle)
            AngleButton(label: "Side", angle: .side, currentAngle: $currentAngle)
            AngleButton(label: "Back", angle: .back, currentAngle: $currentAngle)
            AngleButton(label: "45°", angle: .angle45, currentAngle: $currentAngle)
        }
    }

    // MARK: - Playback Controls

    private var playbackControlsSection: some View {
        VStack(spacing: 12) {
            // Speed selector
            HStack(spacing: 8) {
                Text("PLAYBACK SPEED")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(0.5)

                Spacer()

                ForEach([0.5, 1.0, 1.5, 2.0], id: \.self) { speed in
                    Button {
                        playbackSpeed = Float(speed)
                    } label: {
                        Text("\(speed, specifier: speed == 1.0 || speed == 2.0 ? "%.0f" : "%.1f")x")
                            .font(.system(size: 12, weight: playbackSpeed == Float(speed) ? .bold : .medium))
                            .foregroundColor(playbackSpeed == Float(speed) ? .white : .gray)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                playbackSpeed == Float(speed)
                                    ? GQColors.vividPurple.opacity(0.3)
                                    : Color.black.opacity(0.03)
                            )
                            .cornerRadius(6)
                    }
                }
            }

            // Play/Pause button
            Button {
                isPlaying.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    Text(isPlaying ? "Pause Animation" : "Play Animation")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(GQColors.vividPurple.opacity(0.2))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(GQColors.vividPurple.opacity(0.4), lineWidth: 1)
                )
            }
        }
        .padding(16)
        .background(GQColors.surfaceBase)
        .cornerRadius(12)
    }

    // MARK: - Form Cues Section

    private func formCuesSection(cues: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FORM CUES")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(GQColors.textTertiary)
                .tracking(0.5)

            ForEach(cues, id: \.self) { cue in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(GQColors.success)
                        .font(.system(size: 14))
                    Text(cue)
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textPrimary.opacity(0.9))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GQColors.surfaceBase)
        .cornerRadius(12)
    }

    // MARK: - Key Joints Legend

    private func keyJointsLegend(joints: [JointType]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("KEY JOINTS TO WATCH")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(GQColors.textTertiary)
                .tracking(0.5)

            HStack(spacing: 16) {
                ForEach(joints, id: \.self) { joint in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(joint.color)
                            .frame(width: 12, height: 12)
                        Text(joint.rawValue.capitalized)
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textPrimary.opacity(0.8))
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GQColors.surfaceBase)
        .cornerRadius(12)
    }

    // MARK: - Tempo Section

    private func tempoSection(tempo: String) -> some View {
        HStack {
            Image(systemName: "metronome")
                .foregroundColor(GQColors.cyanSpark)

            VStack(alignment: .leading, spacing: 2) {
                Text("Recommended Tempo")
                    .font(.system(size: 11))
                    .foregroundColor(GQColors.textTertiary)
                Text(tempo)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(GQColors.cyanSpark)
            }

            Spacer()

            // Tempo explanation
            VStack(alignment: .trailing, spacing: 2) {
                Text("eccentric-pause-concentric-pause")
                    .font(.system(size: 10))
                    .foregroundColor(GQColors.textTertiary)
            }
        }
        .padding(16)
        .background(GQColors.surfaceBase)
        .cornerRadius(12)
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ABOUT THIS 3D DEMO")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(GQColors.textTertiary)
                .tracking(0.5)

            Text("This interactive 3D model shows the proper form for \(exerciseName). Rotate the model freely by dragging, or use the quick angle buttons to see the movement from different perspectives. The animation plays continuously to help you understand the full range of motion.")
                .font(.system(size: 13))
                .foregroundColor(GQColors.textPrimary.opacity(0.8))
                .lineSpacing(4)

            HStack(spacing: 16) {
                Label("Rotate freely", systemImage: "rotate.3d")
                Label("Watch key joints", systemImage: "eye")
            }
            .font(.system(size: 12))
            .foregroundColor(GQColors.cyanSpark)
        }
        .padding(16)
        .background(GQColors.surfaceBase)
        .cornerRadius(12)
    }

    // MARK: - Load Model

    private func loadModel() {
        model = RobotDemoService.shared.get3DModel(for: exerciseName)

        // Set initial angle based on exercise type
        if let model = model {
            currentAngle = model.preferredStartAngle
        } else {
            // Default to side view for 2D demos
            currentAngle = .side
        }
    }
}

// MARK: - Preview

#Preview {
    Exercise3DDemoSheet(exerciseName: "Squat")
        .preferredColorScheme(.light)
}
