//
//  Exercise3DViewer.swift
//  GymQuest
//
//  3D Exercise Model Viewer using SceneKit
//  Displays interactive 3D models with animations that users can rotate freely
//

import SwiftUI
import SceneKit
#if canImport(UIKit)
import UIKit
#endif

// MARK: - View Angle

enum ViewAngle: String, CaseIterable {
    case front = "front"
    case side = "side"
    case back = "back"
    case angle45 = "45°"

    var displayName: String {
        switch self {
        case .front: return "Front View"
        case .side: return "Side View"
        case .back: return "Back View"
        case .angle45: return "45° Angle"
        }
    }

    var rotationY: Float {
        switch self {
        case .front: return 0
        case .side: return Float.pi / 2
        case .back: return Float.pi
        case .angle45: return Float.pi / 4
        }
    }
}

// MARK: - Exercise Demo 3D Model

struct ExerciseDemo3D {
    let modelFileName: String
    let cues: [String]
    let keyJoints: [JointType]
    let tempo: String
    let preferredStartAngle: ViewAngle

    init(
        modelFileName: String,
        cues: [String] = [],
        keyJoints: [JointType] = [],
        tempo: String = "3-0-2-0",
        preferredStartAngle: ViewAngle = .side
    ) {
        self.modelFileName = modelFileName
        self.cues = cues
        self.keyJoints = keyJoints
        self.tempo = tempo
        self.preferredStartAngle = preferredStartAngle
    }
}

// MARK: - Exercise 3D Viewer

struct Exercise3DViewer: View {
    let modelName: String
    @State private var isPlaying = true
    @State private var playbackSpeed: Float = 1.0
    @Binding var currentAngle: ViewAngle

    init(modelName: String, currentAngle: Binding<ViewAngle> = .constant(.front)) {
        self.modelName = modelName
        self._currentAngle = currentAngle
    }

    var body: some View {
        ZStack {
            // 3D Scene with background
            ZStack {
                LinearGradient(
                    colors: [GQColors.surfaceElevated, GQColors.surfaceBase],
                    startPoint: .top,
                    endPoint: .bottom
                )

                SceneKitViewWrapper(
                    modelName: modelName,
                    isPlaying: $isPlaying,
                    playbackSpeed: $playbackSpeed,
                    targetAngle: $currentAngle
                )
            }
            .cornerRadius(16)

            // Overlay controls
            VStack {
                HStack {
                    // Playback indicator
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isPlaying ? GQColors.success : GQColors.textTertiary)
                            .frame(width: 8, height: 8)
                        Text(isPlaying ? "Playing" : "Paused")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(GQColors.surfaceOverlay.opacity(0.84))
                    .cornerRadius(8)

                    Spacer()

                    // Play/Pause button
                    Button {
                        isPlaying.toggle()
                    } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
                .padding(12)

                Spacer()

                // Angle indicator
                HStack {
                    Image(systemName: "rotate.3d")
                        .font(.system(size: 12))
                    Text(currentAngle.displayName)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(GQColors.surfaceOverlay.opacity(0.84))
                .cornerRadius(8)
                .padding(.bottom, 12)
            }
        }
    }
}

// MARK: - SceneKit View Wrapper

#if canImport(UIKit)
struct SceneKitViewWrapper: UIViewRepresentable {
    let modelName: String
    @Binding var isPlaying: Bool
    @Binding var playbackSpeed: Float
    @Binding var targetAngle: ViewAngle

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .clear
        scnView.autoenablesDefaultLighting = false  // We'll set up custom cinematic lighting
        scnView.allowsCameraControl = true
        scnView.antialiasingMode = .multisampling4X

        // Create scene
        let scene = SCNScene()
        scnView.scene = scene

        // Enable HDR and physically-based rendering for cinematic look
        scene.background.contents = UIColor(white: 0.08, alpha: 1.0)

        // Add cinematic camera with depth of field
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 50  // Slightly wider for cinematic feel
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 100

        // Depth of Field settings for lens blur effect
        cameraNode.camera?.wantsDepthOfField = true
        cameraNode.camera?.focusDistance = 3.5  // Focus on the model
        cameraNode.camera?.fStop = 2.8  // Shallow depth of field (lower = more blur)
        cameraNode.camera?.apertureBladeCount = 7  // Heptagonal bokeh

        // HDR and bloom for cinematic glow
        cameraNode.camera?.wantsHDR = true
        cameraNode.camera?.bloomIntensity = 0.3
        cameraNode.camera?.bloomThreshold = 0.8
        cameraNode.camera?.bloomBlurRadius = 8

        // Color grading for cinematic color
        cameraNode.camera?.contrast = 1.1
        cameraNode.camera?.saturation = 1.05
        cameraNode.camera?.whitePoint = 5500  // Slightly warm

        // Motion blur for smooth movement
        cameraNode.camera?.motionBlurIntensity = 0.15

        // Vignette for cinematic framing
        cameraNode.camera?.vignettingIntensity = 0.3
        cameraNode.camera?.vignettingPower = 0.8

        cameraNode.position = SCNVector3(x: 0, y: 1.2, z: 3.8)
        cameraNode.name = "mainCamera"
        scene.rootNode.addChildNode(cameraNode)

        // Key Light - main dramatic lighting (3-point setup)
        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .spot
        keyLight.light?.intensity = 1200
        keyLight.light?.color = UIColor(white: 1.0, alpha: 1.0)
        keyLight.light?.temperature = 5600  // Daylight balanced
        keyLight.light?.spotInnerAngle = 30
        keyLight.light?.spotOuterAngle = 60
        keyLight.light?.castsShadow = true
        keyLight.light?.shadowRadius = 8
        keyLight.light?.shadowSampleCount = 16
        keyLight.light?.shadowMode = .deferred
        keyLight.light?.shadowColor = UIColor(white: 0, alpha: 0.5)
        keyLight.position = SCNVector3(x: 3, y: 4, z: 4)
        keyLight.look(at: SCNVector3(x: 0, y: 1, z: 0))
        scene.rootNode.addChildNode(keyLight)

        // Fill Light - softer, from opposite side
        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .directional
        fillLight.light?.intensity = 400
        fillLight.light?.color = UIColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0)  // Slightly cool
        fillLight.light?.temperature = 6500
        fillLight.position = SCNVector3(x: -3, y: 2, z: 2)
        fillLight.look(at: SCNVector3(x: 0, y: 1, z: 0))
        scene.rootNode.addChildNode(fillLight)

        // Rim/Back Light - for edge definition and separation
        let rimLight = SCNNode()
        rimLight.light = SCNLight()
        rimLight.light?.type = .spot
        rimLight.light?.intensity = 600
        rimLight.light?.color = UIColor(red: 1.0, green: 0.95, blue: 0.9, alpha: 1.0)  // Slightly warm
        rimLight.light?.spotInnerAngle = 25
        rimLight.light?.spotOuterAngle = 50
        rimLight.position = SCNVector3(x: -1, y: 3, z: -3)
        rimLight.look(at: SCNVector3(x: 0, y: 1, z: 0))
        scene.rootNode.addChildNode(rimLight)

        // Ambient fill for shadow areas
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 200
        ambientLight.light?.color = UIColor(red: 0.85, green: 0.88, blue: 0.95, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLight)

        // Environment map for reflections (simulated)
        scene.lightingEnvironment.contents = UIColor(white: 0.3, alpha: 1.0)
        scene.lightingEnvironment.intensity = 1.0

        // Load model
        loadModel(into: scene)

        // Store reference for coordinator
        context.coordinator.scnView = scnView
        context.coordinator.scene = scene

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // Update animation playback
        if isPlaying {
            uiView.scene?.rootNode.isPaused = false
            setAnimationSpeed(uiView.scene?.rootNode, speed: playbackSpeed)
        } else {
            uiView.scene?.rootNode.isPaused = true
        }

        // Update camera angle if needed
        if let modelNode = uiView.scene?.rootNode.childNode(withName: "modelRoot", recursively: false) {
            let currentY = modelNode.eulerAngles.y
            let targetY = targetAngle.rotationY

            // Only animate if significantly different
            if abs(currentY - targetY) > 0.1 {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.5
                modelNode.eulerAngles.y = targetY
                SCNTransaction.commit()
            }
        }
    }

    private func loadModel(into scene: SCNScene) {
        // Try to load USDZ model from bundle
        let modelFileName = modelName.lowercased().replacingOccurrences(of: " ", with: "_")

        // Check multiple possible locations
        let possiblePaths = [
            Bundle.main.path(forResource: modelFileName, ofType: "usdz"),
            Bundle.main.path(forResource: modelFileName, ofType: "usdz", inDirectory: "Models"),
            Bundle.main.path(forResource: modelFileName, ofType: "scn"),
            Bundle.main.path(forResource: modelFileName, ofType: "scn", inDirectory: "Models")
        ]

        var modelLoaded = false

        for path in possiblePaths {
            if let validPath = path {
                let url = URL(fileURLWithPath: validPath)
                if let loadedScene = try? SCNScene(url: url, options: [.checkConsistency: true]) {
                    // Create root node for the model
                    let modelRoot = SCNNode()
                    modelRoot.name = "modelRoot"

                    // Add all children from loaded scene
                    for child in loadedScene.rootNode.childNodes {
                        modelRoot.addChildNode(child.clone())
                    }

                    // Center and scale the model
                    let (min, max) = modelRoot.boundingBox
                    let center = SCNVector3(
                        x: (min.x + max.x) / 2,
                        y: (min.y + max.y) / 2,
                        z: (min.z + max.z) / 2
                    )
                    modelRoot.pivot = SCNMatrix4MakeTranslation(center.x, min.y, center.z)

                    // Scale to fit
                    let height = max.y - min.y
                    let targetHeight: Float = 2.0
                    let scale = targetHeight / height
                    modelRoot.scale = SCNVector3(scale, scale, scale)

                    scene.rootNode.addChildNode(modelRoot)

                    // Start animations
                    playAnimations(in: modelRoot)

                    modelLoaded = true
                    break
                }
            }
        }

        // If no model found, create a placeholder humanoid figure
        if !modelLoaded {
            createPlaceholderFigure(in: scene)
        }
    }

    private func playAnimations(in node: SCNNode) {
        // Play all animations found in the node hierarchy
        node.enumerateChildNodes { child, _ in
            for key in child.animationKeys {
                if let player = child.animationPlayer(forKey: key) {
                    player.animation.repeatCount = .infinity
                    player.animation.isRemovedOnCompletion = false
                    player.play()
                }
            }
        }
    }

    private func setAnimationSpeed(_ node: SCNNode?, speed: Float) {
        guard let node = node else { return }
        node.enumerateChildNodes { child, _ in
            for key in child.animationKeys {
                if let player = child.animationPlayer(forKey: key) {
                    player.speed = CGFloat(speed)
                }
            }
        }
    }

    private func createPlaceholderFigure(in scene: SCNScene) {
        let modelRoot = SCNNode()
        modelRoot.name = "modelRoot"

        // Create physically-based materials for cinematic look
        let bodyMaterial = SCNMaterial()
        bodyMaterial.lightingModel = .physicallyBased
        bodyMaterial.diffuse.contents = UIColor(white: 0.9, alpha: 1.0)
        bodyMaterial.metalness.contents = 0.1
        bodyMaterial.roughness.contents = 0.4
        bodyMaterial.normal.intensity = 0.5

        let jointMaterial = SCNMaterial()
        jointMaterial.lightingModel = .physicallyBased
        jointMaterial.diffuse.contents = UIColor.systemCyan
        jointMaterial.metalness.contents = 0.6
        jointMaterial.roughness.contents = 0.2
        jointMaterial.emission.contents = UIColor.systemCyan.withAlphaComponent(0.3)

        // Torso
        let torso = SCNCylinder(radius: 0.15, height: 0.5)
        torso.materials = [bodyMaterial]
        let torsoNode = SCNNode(geometry: torso)
        torsoNode.position = SCNVector3(0, 1.1, 0)
        modelRoot.addChildNode(torsoNode)

        // Head
        let head = SCNSphere(radius: 0.12)
        head.segmentCount = 48  // Higher detail for better quality
        head.materials = [bodyMaterial]
        let headNode = SCNNode(geometry: head)
        headNode.position = SCNVector3(0, 1.55, 0)
        modelRoot.addChildNode(headNode)

        // Arms
        for side in [-1.0, 1.0] as [Double] {
            // Upper arm
            let upperArm = SCNCylinder(radius: 0.05, height: 0.3)
            upperArm.materials = [bodyMaterial]
            let upperArmNode = SCNNode(geometry: upperArm)
            upperArmNode.position = SCNVector3(Float(side) * 0.25, 1.2, 0)
            upperArmNode.eulerAngles.z = Float(side) * Float.pi / 6
            modelRoot.addChildNode(upperArmNode)

            // Lower arm
            let lowerArm = SCNCylinder(radius: 0.04, height: 0.28)
            lowerArm.materials = [bodyMaterial]
            let lowerArmNode = SCNNode(geometry: lowerArm)
            lowerArmNode.position = SCNVector3(Float(side) * 0.38, 0.95, 0)
            modelRoot.addChildNode(lowerArmNode)

            // Shoulder joint
            let shoulder = SCNSphere(radius: 0.06)
            shoulder.segmentCount = 32
            shoulder.materials = [jointMaterial]
            let shoulderNode = SCNNode(geometry: shoulder)
            shoulderNode.position = SCNVector3(Float(side) * 0.18, 1.35, 0)
            modelRoot.addChildNode(shoulderNode)

            // Elbow joint
            let elbow = SCNSphere(radius: 0.05)
            elbow.segmentCount = 32
            elbow.materials = [jointMaterial]
            let elbowNode = SCNNode(geometry: elbow)
            elbowNode.position = SCNVector3(Float(side) * 0.35, 1.05, 0)
            modelRoot.addChildNode(elbowNode)
        }

        // Legs
        for side in [-1.0, 1.0] as [Double] {
            // Upper leg
            let upperLeg = SCNCylinder(radius: 0.07, height: 0.4)
            upperLeg.materials = [bodyMaterial]
            let upperLegNode = SCNNode(geometry: upperLeg)
            upperLegNode.position = SCNVector3(Float(side) * 0.1, 0.65, 0)
            modelRoot.addChildNode(upperLegNode)

            // Lower leg
            let lowerLeg = SCNCylinder(radius: 0.055, height: 0.4)
            lowerLeg.materials = [bodyMaterial]
            let lowerLegNode = SCNNode(geometry: lowerLeg)
            lowerLegNode.position = SCNVector3(Float(side) * 0.1, 0.25, 0)
            modelRoot.addChildNode(lowerLegNode)

            // Hip joint
            let hip = SCNSphere(radius: 0.06)
            hip.segmentCount = 32
            hip.materials = [jointMaterial]
            let hipNode = SCNNode(geometry: hip)
            hipNode.position = SCNVector3(Float(side) * 0.1, 0.85, 0)
            modelRoot.addChildNode(hipNode)

            // Knee joint
            let knee = SCNSphere(radius: 0.055)
            knee.segmentCount = 32
            knee.materials = [jointMaterial]
            let kneeNode = SCNNode(geometry: knee)
            kneeNode.position = SCNVector3(Float(side) * 0.1, 0.45, 0)
            modelRoot.addChildNode(kneeNode)

            // Foot
            let foot = SCNBox(width: 0.08, height: 0.04, length: 0.15, chamferRadius: 0.01)
            foot.materials = [bodyMaterial]
            let footNode = SCNNode(geometry: foot)
            footNode.position = SCNVector3(Float(side) * 0.1, 0.02, 0.03)
            modelRoot.addChildNode(footNode)
        }

        // Add subtle idle animation
        let breatheAction = SCNAction.sequence([
            SCNAction.moveBy(x: 0, y: 0.02, z: 0, duration: 1.5),
            SCNAction.moveBy(x: 0, y: -0.02, z: 0, duration: 1.5)
        ])
        modelRoot.runAction(SCNAction.repeatForever(breatheAction))

        scene.rootNode.addChildNode(modelRoot)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject {
        var scnView: SCNView?
        var scene: SCNScene?
    }
}
#else
// macOS fallback - simple placeholder
struct SceneKitViewWrapper: View {
    let modelName: String
    @Binding var isPlaying: Bool
    @Binding var playbackSpeed: Float
    @Binding var targetAngle: ViewAngle

    var body: some View {
        VStack {
            Image(systemName: "cube.transparent")
                .font(.system(size: 60))
                .foregroundColor(GQColors.textTertiary)
            Text("3D Preview")
                .foregroundColor(GQColors.textTertiary)
            Text("Available on iOS")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif

// MARK: - Playback Controls

struct PlaybackControls: View {
    @Binding var isPlaying: Bool
    @Binding var playbackSpeed: Float

    let speedOptions: [Float] = [0.5, 1.0, 1.5, 2.0]

    var body: some View {
        VStack(spacing: 12) {
            // Speed selector
            HStack(spacing: 8) {
                Text("Speed")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(GQColors.textTertiary)

                ForEach(speedOptions, id: \.self) { speed in
                    Button {
                        playbackSpeed = speed
                    } label: {
                        Text("\(speed, specifier: speed == 1.0 || speed == 2.0 ? "%.0f" : "%.1f")x")
                            .font(.system(size: 12, weight: playbackSpeed == speed ? .bold : .medium))
                            .foregroundColor(playbackSpeed == speed ? .white : .gray)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                playbackSpeed == speed
                                    ? GQColors.vividPurple.opacity(0.3)
                                    : Color.black.opacity(0.03)
                            )
                            .cornerRadius(6)
                    }
                }
            }

            // Main play/pause
            Button {
                isPlaying.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    Text(isPlaying ? "Pause" : "Play")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(GQColors.vividPurple.opacity(0.3))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(GQColors.vividPurple.opacity(0.5), lineWidth: 1)
                )
            }
        }
        .padding(12)
        .background(GQColors.surfaceBase)
        .cornerRadius(12)
    }
}

// MARK: - Angle Button

struct AngleButton: View {
    let label: String
    let angle: ViewAngle
    @Binding var currentAngle: ViewAngle

    var isSelected: Bool {
        currentAngle == angle
    }

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentAngle = angle
            }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : .gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    isSelected
                        ? GQColors.vividPurple.opacity(0.3)
                        : Color.black.opacity(0.03)
                )
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isSelected ? GQColors.vividPurple.opacity(0.5) : Color.clear,
                            lineWidth: 1
                        )
                )
        }
    }
}

// MARK: - Preview

#Preview {
    Exercise3DViewer(modelName: "squat")
        .frame(height: 350)
        .padding()
        .gqPageBackground()
}
