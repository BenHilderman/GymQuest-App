//
//  FormDemo3DView.swift
//  GymQuest
//
//  SwiftUI view wrapping SceneKit for 3D workout form demonstrations.
//  Includes angle selector, playback controls, and phase indicator.
//

import SwiftUI
import SceneKit

// MARK: - Form Demo 3D View

struct FormDemo3DView: View {
    let demo: ExerciseDemo

    @State private var selectedAngle: FormViewAngle = .front
    @State private var isPlaying = true
    @State private var currentPhase: KeyframePosition = .start
    @State private var currentKeyframeIndex = 0
    @State private var scene: SCNScene?

    @StateObject private var sceneService = FormDemoSceneService.shared

    private let animationTimer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 16) {
            // 3D Scene View
            ZStack {
                // SceneKit view
                if let scene = scene {
                    SceneKitView(
                        scene: scene,
                        angle: selectedAngle,
                        onAngleChange: { newAngle in
                            sceneService.updateCameraAngle(newAngle, animated: true)
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                } else {
                    // Loading placeholder
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [GQColors.vividPurple.opacity(0.3), GQColors.cyanSpark.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            ProgressView()
                                .tint(.white)
                        )
                }

                // Overlay controls
                VStack {
                    HStack {
                        // Phase indicator
                        PhaseIndicator(phase: currentPhase)

                        Spacer()

                        // Play/Pause button
                        Button {
                            isPlaying.toggle()
                        } label: {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Circle())
                        }
                    }
                    .padding(12)

                    Spacer()

                    // Angle selector
                    AngleSelector(selectedAngle: $selectedAngle)
                        .padding(.bottom, 12)
                }
            }
            .frame(height: 280)

            // Current phase cues
            if !demo.keyframes.isEmpty {
                CurrentPhaseCues(
                    cues: demo.keyframes[currentKeyframeIndex].cues,
                    phase: currentPhase
                )
            }

            // Key joints legend and tempo
            HStack(spacing: 16) {
                ForEach(demo.keyJoints, id: \.self) { joint in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green) // Key joints glow green
                            .frame(width: 10, height: 10)
                        Text(joint.rawValue)
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                Text("Tempo: \(demo.tempo)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(GQColors.cyanSpark)
            }
        }
        .onAppear {
            setupScene()
        }
        .onReceive(animationTimer) { _ in
            guard isPlaying else { return }
            advanceKeyframe()
        }
        .onChange(of: selectedAngle) { _, newAngle in
            sceneService.updateCameraAngle(newAngle, animated: true)
        }
    }

    private func setupScene() {
        scene = sceneService.createScene(for: demo, angle: selectedAngle)
    }

    private func advanceKeyframe() {
        currentKeyframeIndex = (currentKeyframeIndex + 1) % demo.keyframes.count
        let keyframe = demo.keyframes[currentKeyframeIndex]
        currentPhase = keyframe.position

        if let humanoid = scene?.rootNode.childNode(withName: "humanoid", recursively: true) {
            sceneService.applyPose(keyframe: keyframe, to: humanoid, animated: true)
        }
    }
}

// MARK: - SceneKit View Wrapper

struct SceneKitView: UIViewRepresentable {
    let scene: SCNScene
    let angle: FormViewAngle
    let onAngleChange: (FormViewAngle) -> Void

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = scene
        scnView.backgroundColor = .clear
        scnView.antialiasingMode = .multisampling4X
        scnView.autoenablesDefaultLighting = false
        scnView.allowsCameraControl = true // Allow user to rotate/zoom
        scnView.showsStatistics = false
        scnView.defaultCameraController.interactionMode = .orbitTurntable
        scnView.defaultCameraController.inertiaEnabled = true

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // Scene updates handled by the service
    }
}

// MARK: - Phase Indicator

struct PhaseIndicator: View {
    let phase: KeyframePosition

    var phaseColor: Color {
        switch phase {
        case .start: return GQColors.cyanSpark
        case .mid: return GQColors.vividPurple
        case .end: return GQColors.success
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(phaseColor)
                .frame(width: 8, height: 8)

            Text(phase.rawValue)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.5))
        .clipShape(Capsule())
    }
}

// MARK: - Angle Selector

struct AngleSelector: View {
    @Binding var selectedAngle: FormViewAngle

    var body: some View {
        HStack(spacing: 0) {
            ForEach(FormViewAngle.allCases, id: \.self) { angle in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedAngle = angle
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: angle == .front ? "person.fill" : "person.fill.turn.right")
                            .font(.system(size: 12))
                        Text(angle.rawValue)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(selectedAngle == angle ? .white : .gray)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        selectedAngle == angle ?
                        GQGradients.primary : LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
                }
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.5))
        .clipShape(Capsule())
    }
}

// MARK: - Current Phase Cues

struct CurrentPhaseCues: View {
    let cues: [String]
    let phase: KeyframePosition

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(phase.rawValue.uppercased()) POSITION")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
                    .tracking(0.5)

                Spacer()

                // Animated indicator dots
                HStack(spacing: 4) {
                    ForEach(KeyframePosition.allCases, id: \.self) { pos in
                        Circle()
                            .fill(pos == phase ? GQColors.success : Color.gray.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                }
            }

            ForEach(cues, id: \.self) { cue in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(GQColors.success)
                        .padding(.top, 1)
                    Text(cue)
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textPrimary.opacity(0.9))
                }
            }
        }
        .padding(12)
        .background(Color(white: 0.96))
        .cornerRadius(12)
    }
}

// MARK: - KeyframePosition CaseIterable

extension KeyframePosition: CaseIterable {
    static var allCases: [KeyframePosition] = [.start, .mid, .end]
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        ScrollView {
            FormDemo3DView(demo: ExerciseDemo(
                name: "Squat",
                category: .legs,
                keyframes: [
                    DemoKeyframe(
                        position: .start,
                        joints: [
                            .shoulder: JointPosition(x: 0.5, y: 0.3, angle: 0),
                            .hip: JointPosition(x: 0.5, y: 0.5, angle: 175),
                            .knee: JointPosition(x: 0.5, y: 0.7, angle: 175),
                            .ankle: JointPosition(x: 0.5, y: 0.9, angle: 90)
                        ],
                        cues: ["Stand tall", "Feet shoulder-width", "Toes slightly out"]
                    ),
                    DemoKeyframe(
                        position: .mid,
                        joints: [
                            .shoulder: JointPosition(x: 0.55, y: 0.35, angle: 15),
                            .hip: JointPosition(x: 0.5, y: 0.55, angle: 120),
                            .knee: JointPosition(x: 0.55, y: 0.7, angle: 120),
                            .ankle: JointPosition(x: 0.5, y: 0.9, angle: 75)
                        ],
                        cues: ["Knees track over toes", "Weight on midfoot", "Core braced"]
                    ),
                    DemoKeyframe(
                        position: .end,
                        joints: [
                            .shoulder: JointPosition(x: 0.6, y: 0.45, angle: 30),
                            .hip: JointPosition(x: 0.5, y: 0.65, angle: 80),
                            .knee: JointPosition(x: 0.6, y: 0.75, angle: 70),
                            .ankle: JointPosition(x: 0.5, y: 0.9, angle: 60)
                        ],
                        cues: ["Parallel or below", "Chest stays up", "Drive through heels"]
                    )
                ],
                keyJoints: [.hip, .knee],
                tempo: "3-1-2-0"
            ))
            .padding()
        }
    }
}
