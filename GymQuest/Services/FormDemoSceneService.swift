//
//  FormDemoSceneService.swift
//  GymQuest
//
//  3D SceneKit service for rendering animated workout form demonstrations.
//  Features a clean robot humanoid design with visible joints and equipment tracking.
//

import Foundation
import SceneKit
import SwiftUI
import UIKit

// MARK: - View Angle

enum FormViewAngle: String, CaseIterable {
    case front = "Front"
    case side = "Side"

    var cameraPosition: SCNVector3 {
        switch self {
        case .front: return SCNVector3(0, 1.2, 3.5)
        case .side: return SCNVector3(3.5, 1.2, 0)
        }
    }
}

// MARK: - Exercise Type Detection

enum ExerciseType {
    case benchPress
    case squat
    case deadlift
    case overheadPress
    case bicepCurl
    case tricepPushdown
    case latPulldown
    case pullUp
    case row
    case legPress
    case legCurl
    case legExtension
    case chestFly
    case lunge
    case calfRaise
    case plank
    case generic

    static func from(name: String) -> ExerciseType {
        let lower = name.lowercased()
        if lower.contains("bench") && lower.contains("press") { return .benchPress }
        if lower.contains("squat") { return .squat }
        if lower.contains("deadlift") || lower.contains("rdl") || lower.contains("romanian") { return .deadlift }
        if lower.contains("overhead") && lower.contains("press") { return .overheadPress }
        if lower.contains("shoulder") && lower.contains("press") { return .overheadPress }
        if lower.contains("curl") && !lower.contains("leg") { return .bicepCurl }
        if lower.contains("tricep") || lower.contains("pushdown") { return .tricepPushdown }
        if lower.contains("lat") && lower.contains("pull") { return .latPulldown }
        if lower.contains("pull") && lower.contains("up") { return .pullUp }
        if lower.contains("row") { return .row }
        if lower.contains("leg") && lower.contains("press") { return .legPress }
        if lower.contains("leg") && lower.contains("curl") { return .legCurl }
        if lower.contains("leg") && lower.contains("extension") { return .legExtension }
        if lower.contains("fly") || lower.contains("flye") { return .chestFly }
        if lower.contains("lunge") { return .lunge }
        if lower.contains("calf") { return .calfRaise }
        if lower.contains("plank") { return .plank }
        return .generic
    }
}

// MARK: - Exercise Positioning

struct ExercisePositioning {
    let pelvisPosition: SCNVector3
    let pelvisRotation: SCNVector3
    let cameraLookAtY: Float

    static func positioning(for type: ExerciseType) -> ExercisePositioning {
        switch type {
        case .benchPress, .chestFly:
            // Lying on bench (bench top at Y=0.45)
            return ExercisePositioning(
                pelvisPosition: SCNVector3(0, 0.55, 0),
                pelvisRotation: SCNVector3(-Float.pi / 2, 0, 0),
                cameraLookAtY: 0.8
            )
        case .legCurl:
            // Lying face down on bench
            return ExercisePositioning(
                pelvisPosition: SCNVector3(0, 0.60, 0),
                pelvisRotation: SCNVector3(Float.pi / 2, 0, 0),
                cameraLookAtY: 0.6
            )
        case .legPress:
            // Reclined on leg press
            return ExercisePositioning(
                pelvisPosition: SCNVector3(0, 0.55, -0.2),
                pelvisRotation: SCNVector3(-0.6, 0, 0),
                cameraLookAtY: 0.7
            )
        case .latPulldown, .legExtension:
            // Seated
            return ExercisePositioning(
                pelvisPosition: SCNVector3(0, 0.55, 0),
                pelvisRotation: SCNVector3(0, 0, 0),
                cameraLookAtY: 1.0
            )
        case .pullUp:
            // Hanging from bar
            return ExercisePositioning(
                pelvisPosition: SCNVector3(0, 1.40, 0),
                pelvisRotation: SCNVector3(0, 0, 0),
                cameraLookAtY: 1.6
            )
        case .squat, .deadlift, .overheadPress, .bicepCurl, .row, .lunge, .calfRaise, .tricepPushdown, .plank, .generic:
            // Standing
            return ExercisePositioning(
                pelvisPosition: SCNVector3(0, 0.95, 0),
                pelvisRotation: SCNVector3(0, 0, 0),
                cameraLookAtY: 1.0
            )
        }
    }
}

// MARK: - Pose Keyframes

struct PoseKeyframe {
    // Upper body
    var leftShoulder: SCNVector3
    var rightShoulder: SCNVector3
    var leftElbow: Float
    var rightElbow: Float

    // Lower body
    var leftHip: SCNVector3
    var rightHip: SCNVector3
    var leftKnee: Float
    var rightKnee: Float

    // Spine and pelvis
    var spineForward: Float
    var chestForward: Float
    var pelvisOffset: SCNVector3

    static let neutral = PoseKeyframe(
        leftShoulder: SCNVector3(0, 0, 0.1),
        rightShoulder: SCNVector3(0, 0, -0.1),
        leftElbow: 0,
        rightElbow: 0,
        leftHip: SCNVector3(0, 0, 0),
        rightHip: SCNVector3(0, 0, 0),
        leftKnee: 0,
        rightKnee: 0,
        spineForward: 0,
        chestForward: 0,
        pelvisOffset: SCNVector3(0, 0, 0)
    )
}

// MARK: - Exercise Pose Data

struct BenchPressPoses {
    static let lockout = PoseKeyframe(
        leftShoulder: SCNVector3(0, 0, 0.4),
        rightShoulder: SCNVector3(0, 0, -0.4),
        leftElbow: -0.1,
        rightElbow: -0.1,
        leftHip: SCNVector3(0.8, 0, 0),
        rightHip: SCNVector3(0.8, 0, 0),
        leftKnee: -1.4,
        rightKnee: -1.4,
        spineForward: 0,
        chestForward: 0,
        pelvisOffset: SCNVector3(0, 0, 0)
    )

    static let barAtChest = PoseKeyframe(
        leftShoulder: SCNVector3(0.8, 0, 0.4),
        rightShoulder: SCNVector3(0.8, 0, -0.4),
        leftElbow: -1.57,
        rightElbow: -1.57,
        leftHip: SCNVector3(0.8, 0, 0),
        rightHip: SCNVector3(0.8, 0, 0),
        leftKnee: -1.4,
        rightKnee: -1.4,
        spineForward: 0,
        chestForward: 0,
        pelvisOffset: SCNVector3(0, 0, 0)
    )
}

struct SquatPoses {
    static let standing = PoseKeyframe(
        leftShoulder: SCNVector3(0, 0, 0.3),
        rightShoulder: SCNVector3(0, 0, -0.3),
        leftElbow: -0.8,
        rightElbow: -0.8,
        leftHip: SCNVector3(0, 0, 0),
        rightHip: SCNVector3(0, 0, 0),
        leftKnee: 0,
        rightKnee: 0,
        spineForward: 0,
        chestForward: 0,
        pelvisOffset: SCNVector3(0, 0, 0)
    )

    static let halfSquat = PoseKeyframe(
        leftShoulder: SCNVector3(-0.2, 0, 0.3),
        rightShoulder: SCNVector3(-0.2, 0, -0.3),
        leftElbow: -0.8,
        rightElbow: -0.8,
        leftHip: SCNVector3(0.7, 0, 0),
        rightHip: SCNVector3(0.7, 0, 0),
        leftKnee: -0.8,
        rightKnee: -0.8,
        spineForward: 0.2,
        chestForward: 0,
        pelvisOffset: SCNVector3(0, -0.20, -0.05)
    )

    static let deepSquat = PoseKeyframe(
        leftShoulder: SCNVector3(-0.4, 0, 0.3),
        rightShoulder: SCNVector3(-0.4, 0, -0.3),
        leftElbow: -0.8,
        rightElbow: -0.8,
        leftHip: SCNVector3(1.3, 0, 0),
        rightHip: SCNVector3(1.3, 0, 0),
        leftKnee: -1.5,
        rightKnee: -1.5,
        spineForward: 0.4,
        chestForward: 0,
        pelvisOffset: SCNVector3(0, -0.40, -0.10)
    )
}

struct DeadliftPoses {
    static let standing = PoseKeyframe(
        leftShoulder: SCNVector3(0, 0, 0.15),
        rightShoulder: SCNVector3(0, 0, -0.15),
        leftElbow: 0,
        rightElbow: 0,
        leftHip: SCNVector3(0, 0, 0),
        rightHip: SCNVector3(0, 0, 0),
        leftKnee: 0,
        rightKnee: 0,
        spineForward: 0,
        chestForward: 0,
        pelvisOffset: SCNVector3(0, 0, 0)
    )

    static let bentOver = PoseKeyframe(
        leftShoulder: SCNVector3(0, 0, 0.15),
        rightShoulder: SCNVector3(0, 0, -0.15),
        leftElbow: 0,
        rightElbow: 0,
        leftHip: SCNVector3(0.4, 0, 0),
        rightHip: SCNVector3(0.4, 0, 0),
        leftKnee: -0.5,
        rightKnee: -0.5,
        spineForward: 0.9,
        chestForward: 0.2,
        pelvisOffset: SCNVector3(0, -0.15, 0)
    )
}

struct PullUpPoses {
    static let hanging = PoseKeyframe(
        leftShoulder: SCNVector3(-Float.pi, 0, 0.4),
        rightShoulder: SCNVector3(-Float.pi, 0, -0.4),
        leftElbow: 0,
        rightElbow: 0,
        leftHip: SCNVector3(0, 0, 0),
        rightHip: SCNVector3(0, 0, 0),
        leftKnee: 0,
        rightKnee: 0,
        spineForward: 0,
        chestForward: 0,
        pelvisOffset: SCNVector3(0, 0, 0)
    )

    static let pulledUp = PoseKeyframe(
        leftShoulder: SCNVector3(-Float.pi + 1.2, 0, 0.4),
        rightShoulder: SCNVector3(-Float.pi + 1.2, 0, -0.4),
        leftElbow: 2.0,
        rightElbow: 2.0,
        leftHip: SCNVector3(0, 0, 0),
        rightHip: SCNVector3(0, 0, 0),
        leftKnee: 0,
        rightKnee: 0,
        spineForward: 0,
        chestForward: 0,
        pelvisOffset: SCNVector3(0, 0.5, 0)
    )
}

// MARK: - Robot Materials

struct RobotMaterials {
    let bodySegment: SCNMaterial
    let joint: SCNMaterial
    let keyJoint: SCNMaterial
    let floor: SCNMaterial
    let equipment: SCNMaterial

    static func create(keyJoints: [JointType] = []) -> RobotMaterials {
        // Body segments: Matte white/light gray
        let bodyMat = SCNMaterial()
        bodyMat.diffuse.contents = UIColor(white: 0.92, alpha: 1.0)
        bodyMat.roughness.contents = 0.8
        bodyMat.metalness.contents = 0.0

        // Joint spheres: Dark gray
        let jointMat = SCNMaterial()
        jointMat.diffuse.contents = UIColor(white: 0.25, alpha: 1.0)
        jointMat.roughness.contents = 0.6
        jointMat.metalness.contents = 0.2

        // Key joints: Green with glow
        let keyJointMat = SCNMaterial()
        keyJointMat.diffuse.contents = UIColor(red: 0.2, green: 0.85, blue: 0.4, alpha: 1.0)
        keyJointMat.emission.contents = UIColor(red: 0.1, green: 0.5, blue: 0.2, alpha: 1.0)
        keyJointMat.roughness.contents = 0.4
        keyJointMat.metalness.contents = 0.1

        // Floor: Dark
        let floorMat = SCNMaterial()
        floorMat.diffuse.contents = UIColor(white: 0.12, alpha: 1.0)
        floorMat.roughness.contents = 0.9

        // Equipment: Steel gray
        let equipMat = SCNMaterial()
        equipMat.diffuse.contents = UIColor(white: 0.4, alpha: 1.0)
        equipMat.metalness.contents = 0.8
        equipMat.roughness.contents = 0.3

        return RobotMaterials(
            bodySegment: bodyMat,
            joint: jointMat,
            keyJoint: keyJointMat,
            floor: floorMat,
            equipment: equipMat
        )
    }
}

// MARK: - Form Demo Scene Service

@MainActor
class FormDemoSceneService: ObservableObject {
    static let shared = FormDemoSceneService()

    private var scene: SCNScene?
    private var humanoidRoot: SCNNode?
    private var cameraNode: SCNNode?
    private var exerciseType: ExerciseType = .generic
    private var positioning: ExercisePositioning = .positioning(for: .generic)
    private var keyJoints: [JointType] = []

    // Equipment references for tracking
    private var barbellNode: SCNNode?
    private var leftDumbbellNode: SCNNode?
    private var rightDumbbellNode: SCNNode?

    @Published var currentPhase: KeyframePosition = .start

    // MARK: - Scene Creation

    func createScene(for demo: ExerciseDemo, angle: FormViewAngle) -> SCNScene {
        let scene = SCNScene()
        self.scene = scene
        self.exerciseType = ExerciseType.from(name: demo.name)
        self.positioning = ExercisePositioning.positioning(for: exerciseType)
        self.keyJoints = demo.keyJoints

        setupLighting(scene: scene)
        setupGymFloor(scene: scene)

        // Add equipment based on exercise type
        addEquipment(to: scene, for: exerciseType)

        // Create robot humanoid in starting pose
        let humanoid = createRobotHumanoid(for: exerciseType, keyJoints: keyJoints)
        scene.rootNode.addChildNode(humanoid)
        self.humanoidRoot = humanoid

        setupCamera(scene: scene, angle: angle)

        // Apply initial pose
        if let firstKeyframe = demo.keyframes.first {
            applyPose(keyframe: firstKeyframe, to: humanoid, animated: false)
        }

        return scene
    }

    // MARK: - Lighting

    private func setupLighting(scene: SCNScene) {
        scene.background.contents = UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1.0)

        // Ambient light
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = UIColor(white: 0.4, alpha: 1.0)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        // Main overhead light
        let mainLight = SCNLight()
        mainLight.type = .directional
        mainLight.color = UIColor.white
        mainLight.intensity = 1000
        mainLight.castsShadow = true
        mainLight.shadowRadius = 8
        mainLight.shadowSampleCount = 16
        let mainNode = SCNNode()
        mainNode.light = mainLight
        mainNode.position = SCNVector3(0, 5, 2)
        mainNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(mainNode)

        // Fill light from side
        let fillLight = SCNLight()
        fillLight.type = .omni
        fillLight.color = UIColor(white: 0.7, alpha: 1.0)
        fillLight.intensity = 300
        let fillNode = SCNNode()
        fillNode.light = fillLight
        fillNode.position = SCNVector3(-3, 2, 3)
        scene.rootNode.addChildNode(fillNode)
    }

    // MARK: - Gym Floor

    private func setupGymFloor(scene: SCNScene) {
        let floor = SCNFloor()
        floor.reflectivity = 0.05
        let floorMat = SCNMaterial()
        floorMat.diffuse.contents = UIColor(white: 0.12, alpha: 1.0)
        floorMat.roughness.contents = 0.9
        floor.materials = [floorMat]
        let floorNode = SCNNode(geometry: floor)
        scene.rootNode.addChildNode(floorNode)
    }

    // MARK: - Equipment

    private func addEquipment(to scene: SCNScene, for type: ExerciseType) {
        let metalMat = SCNMaterial()
        metalMat.diffuse.contents = UIColor(white: 0.4, alpha: 1.0)
        metalMat.metalness.contents = 0.8
        metalMat.roughness.contents = 0.3

        let padMat = SCNMaterial()
        padMat.diffuse.contents = UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1.0)
        padMat.roughness.contents = 0.8

        switch type {
        case .benchPress, .chestFly:
            // Flat bench
            let benchTop = SCNBox(width: 0.35, height: 0.08, length: 1.2, chamferRadius: 0.02)
            benchTop.materials = [padMat]
            let benchNode = SCNNode(geometry: benchTop)
            benchNode.position = SCNVector3(0, 0.45, 0)
            scene.rootNode.addChildNode(benchNode)

            // Bench legs
            for x: Float in [-0.12, 0.12] {
                for z: Float in [-0.45, 0.45] {
                    let leg = SCNCylinder(radius: 0.025, height: 0.42)
                    leg.materials = [metalMat]
                    let legNode = SCNNode(geometry: leg)
                    legNode.position = SCNVector3(x, 0.21, z)
                    scene.rootNode.addChildNode(legNode)
                }
            }

            // Barbell (tracked) for bench press
            if type == .benchPress {
                barbellNode = createBarbell(length: 1.8)
                barbellNode?.position = SCNVector3(0, 1.1, 0)
                scene.rootNode.addChildNode(barbellNode!)
            }

        case .squat:
            // Squat rack uprights
            for x: Float in [-0.5, 0.5] {
                let upright = SCNBox(width: 0.08, height: 2.2, length: 0.08, chamferRadius: 0.01)
                upright.materials = [metalMat]
                let uprightNode = SCNNode(geometry: upright)
                uprightNode.position = SCNVector3(x, 1.1, -0.3)
                scene.rootNode.addChildNode(uprightNode)

                // J-hooks
                let hook = SCNBox(width: 0.06, height: 0.04, length: 0.12, chamferRadius: 0.01)
                hook.materials = [metalMat]
                let hookNode = SCNNode(geometry: hook)
                hookNode.position = SCNVector3(x > 0 ? x - 0.06 : x + 0.06, 1.4, -0.24)
                scene.rootNode.addChildNode(hookNode)
            }

            // Barbell on shoulders (tracked)
            barbellNode = createBarbell(length: 2.0)
            barbellNode?.position = SCNVector3(0, 1.45, -0.15)
            scene.rootNode.addChildNode(barbellNode!)

        case .deadlift:
            // Barbell on floor with big plates (tracked)
            barbellNode = createBarbell(length: 2.0, withBigPlates: true)
            barbellNode?.position = SCNVector3(0, 0.22, 0.3)
            scene.rootNode.addChildNode(barbellNode!)

        case .overheadPress:
            // Barbell (tracked)
            barbellNode = createBarbell(length: 1.6)
            barbellNode?.position = SCNVector3(0, 1.35, 0.15)
            scene.rootNode.addChildNode(barbellNode!)

        case .bicepCurl:
            // Dumbbells (attached to hands)
            leftDumbbellNode = createDumbbell()
            rightDumbbellNode = createDumbbell()
            scene.rootNode.addChildNode(leftDumbbellNode!)
            scene.rootNode.addChildNode(rightDumbbellNode!)
            // Will be positioned by updateEquipmentPosition

        case .row:
            // Bench for support
            let benchTop = SCNBox(width: 0.35, height: 0.08, length: 1.0, chamferRadius: 0.02)
            benchTop.materials = [padMat]
            let benchNode = SCNNode(geometry: benchTop)
            benchNode.position = SCNVector3(-0.4, 0.45, 0)
            scene.rootNode.addChildNode(benchNode)

            // Single dumbbell
            rightDumbbellNode = createDumbbell()
            scene.rootNode.addChildNode(rightDumbbellNode!)

        case .latPulldown:
            // Cable machine frame
            let frame = SCNBox(width: 0.08, height: 2.5, length: 0.08, chamferRadius: 0.01)
            frame.materials = [metalMat]
            let frameNode = SCNNode(geometry: frame)
            frameNode.position = SCNVector3(0, 1.25, -0.5)
            scene.rootNode.addChildNode(frameNode)

            // Seat
            let seat = SCNBox(width: 0.4, height: 0.06, length: 0.35, chamferRadius: 0.02)
            seat.materials = [padMat]
            let seatNode = SCNNode(geometry: seat)
            seatNode.position = SCNVector3(0, 0.5, 0)
            scene.rootNode.addChildNode(seatNode)

            // Lat bar (static)
            let bar = SCNCylinder(radius: 0.015, height: 1.0)
            bar.materials = [metalMat]
            let barNode = SCNNode(geometry: bar)
            barNode.eulerAngles.z = Float.pi / 2
            barNode.position = SCNVector3(0, 2.0, -0.3)
            scene.rootNode.addChildNode(barNode)

        case .pullUp:
            // Pull-up bar (static - hands attach to it)
            let bar = SCNCylinder(radius: 0.02, height: 1.2)
            bar.materials = [metalMat]
            let barNode = SCNNode(geometry: bar)
            barNode.eulerAngles.z = Float.pi / 2
            barNode.position = SCNVector3(0, 2.3, 0)
            scene.rootNode.addChildNode(barNode)

            // Uprights
            for x: Float in [-0.65, 0.65] {
                let upright = SCNCylinder(radius: 0.03, height: 2.3)
                upright.materials = [metalMat]
                let uprightNode = SCNNode(geometry: upright)
                uprightNode.position = SCNVector3(x, 1.15, 0)
                scene.rootNode.addChildNode(uprightNode)
            }

        case .legPress:
            let backrest = SCNBox(width: 0.5, height: 0.1, length: 0.8, chamferRadius: 0.02)
            backrest.materials = [padMat]
            let backNode = SCNNode(geometry: backrest)
            backNode.position = SCNVector3(0, 0.4, -0.3)
            backNode.eulerAngles.x = -0.6
            scene.rootNode.addChildNode(backNode)

            let plate = SCNBox(width: 0.6, height: 0.08, length: 0.5, chamferRadius: 0.02)
            plate.materials = [metalMat]
            let plateNode = SCNNode(geometry: plate)
            plateNode.position = SCNVector3(0, 0.9, 0.4)
            plateNode.eulerAngles.x = -0.3
            scene.rootNode.addChildNode(plateNode)

        case .legCurl, .legExtension:
            let benchTop = SCNBox(width: 0.4, height: 0.1, length: 1.0, chamferRadius: 0.02)
            benchTop.materials = [padMat]
            let benchNode = SCNNode(geometry: benchTop)
            benchNode.position = SCNVector3(0, 0.5, 0)
            scene.rootNode.addChildNode(benchNode)

            let roller = SCNCylinder(radius: 0.05, height: 0.35)
            roller.materials = [padMat]
            let rollerNode = SCNNode(geometry: roller)
            rollerNode.eulerAngles.z = Float.pi / 2
            rollerNode.position = SCNVector3(0, 0.4, type == .legCurl ? 0.55 : -0.45)
            scene.rootNode.addChildNode(rollerNode)

        case .calfRaise:
            let step = SCNBox(width: 0.5, height: 0.15, length: 0.3, chamferRadius: 0.01)
            step.materials = [metalMat]
            let stepNode = SCNNode(geometry: step)
            stepNode.position = SCNVector3(0, 0.075, 0)
            scene.rootNode.addChildNode(stepNode)

        case .lunge:
            leftDumbbellNode = createDumbbell()
            rightDumbbellNode = createDumbbell()
            scene.rootNode.addChildNode(leftDumbbellNode!)
            scene.rootNode.addChildNode(rightDumbbellNode!)

        case .tricepPushdown:
            let frame = SCNBox(width: 0.08, height: 2.2, length: 0.08, chamferRadius: 0.01)
            frame.materials = [metalMat]
            let frameNode = SCNNode(geometry: frame)
            frameNode.position = SCNVector3(0, 1.1, -0.4)
            scene.rootNode.addChildNode(frameNode)

            let rope = SCNCylinder(radius: 0.015, height: 0.3)
            rope.materials = [padMat]
            let ropeNode = SCNNode(geometry: rope)
            ropeNode.position = SCNVector3(0, 1.3, -0.2)
            scene.rootNode.addChildNode(ropeNode)

        case .plank, .generic:
            break
        }
    }

    private func createBarbell(length: Float, withBigPlates: Bool = false) -> SCNNode {
        let barbellRoot = SCNNode()
        barbellRoot.name = "barbell"

        let metalMat = SCNMaterial()
        metalMat.diffuse.contents = UIColor(white: 0.6, alpha: 1.0)
        metalMat.metalness.contents = 0.9
        metalMat.roughness.contents = 0.2

        let plateMat = SCNMaterial()
        plateMat.diffuse.contents = UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)
        plateMat.roughness.contents = 0.5

        // Bar
        let bar = SCNCylinder(radius: 0.014, height: CGFloat(length))
        bar.materials = [metalMat]
        let barNode = SCNNode(geometry: bar)
        barNode.eulerAngles.z = Float.pi / 2
        barbellRoot.addChildNode(barNode)

        // Weight plates
        let plateRadius: CGFloat = withBigPlates ? 0.22 : 0.12
        let plateWidth: CGFloat = withBigPlates ? 0.04 : 0.025

        for side: Float in [-1, 1] {
            let plateX = side * (length / 2 - 0.15)

            let plate = SCNCylinder(radius: plateRadius, height: plateWidth)
            plate.materials = [plateMat]
            let plateNode = SCNNode(geometry: plate)
            plateNode.eulerAngles.z = Float.pi / 2
            plateNode.position = SCNVector3(plateX, 0, 0)
            barbellRoot.addChildNode(plateNode)

            // Inner plate
            let plate2 = SCNCylinder(radius: plateRadius * 0.85, height: plateWidth)
            plate2.materials = [plateMat]
            let plate2Node = SCNNode(geometry: plate2)
            plate2Node.eulerAngles.z = Float.pi / 2
            plate2Node.position = SCNVector3(plateX + side * 0.04, 0, 0)
            barbellRoot.addChildNode(plate2Node)
        }

        return barbellRoot
    }

    private func createDumbbell() -> SCNNode {
        let metalMat = SCNMaterial()
        metalMat.diffuse.contents = UIColor(white: 0.5, alpha: 1.0)
        metalMat.metalness.contents = 0.8
        metalMat.roughness.contents = 0.3

        let weightMat = SCNMaterial()
        weightMat.diffuse.contents = UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)

        let dbNode = SCNNode()
        dbNode.name = "dumbbell"

        // Handle
        let handle = SCNCylinder(radius: 0.015, height: 0.12)
        handle.materials = [metalMat]
        let handleNode = SCNNode(geometry: handle)
        handleNode.eulerAngles.z = Float.pi / 2
        dbNode.addChildNode(handleNode)

        // Weight ends
        for side: Float in [-1, 1] {
            let weight = SCNCylinder(radius: 0.045, height: 0.05)
            weight.materials = [weightMat]
            let weightNode = SCNNode(geometry: weight)
            weightNode.eulerAngles.z = Float.pi / 2
            weightNode.position = SCNVector3(side * 0.08, 0, 0)
            dbNode.addChildNode(weightNode)
        }

        return dbNode
    }

    // MARK: - Robot Humanoid Creation

    private func createRobotHumanoid(for type: ExerciseType, keyJoints: [JointType]) -> SCNNode {
        let root = SCNNode()
        root.name = "humanoid"

        let materials = RobotMaterials.create(keyJoints: keyJoints)

        // Determine which joints should glow
        let shouldHighlight: (JointType) -> Bool = { joint in
            keyJoints.contains(joint)
        }

        // Pelvis (root of skeleton) - positioned based on exercise
        let pelvis = SCNNode()
        pelvis.name = "pelvis"
        pelvis.position = positioning.pelvisPosition
        pelvis.eulerAngles = positioning.pelvisRotation
        root.addChildNode(pelvis)

        // Pelvis visual: rounded box
        let pelvisGeo = SCNBox(width: 0.28, height: 0.12, length: 0.15, chamferRadius: 0.03)
        pelvisGeo.materials = [materials.bodySegment]
        let pelvisVis = SCNNode(geometry: pelvisGeo)
        pelvis.addChildNode(pelvisVis)

        // Hip joints (visual spheres)
        for side: Float in [-1, 1] {
            let hipJoint = SCNSphere(radius: 0.05)
            let isKey = shouldHighlight(.hip)
            hipJoint.materials = [isKey ? materials.keyJoint : materials.joint]
            let hipJointVis = SCNNode(geometry: hipJoint)
            hipJointVis.position = SCNVector3(side * 0.1, -0.02, 0)
            pelvis.addChildNode(hipJointVis)
        }

        // Spine/Torso
        let spine = SCNNode()
        spine.name = "spine"
        spine.position = SCNVector3(0, 0.18, 0)
        pelvis.addChildNode(spine)

        // Torso visual: rounded box
        let torsoGeo = SCNBox(width: 0.30, height: 0.45, length: 0.18, chamferRadius: 0.05)
        torsoGeo.materials = [materials.bodySegment]
        let torsoVis = SCNNode(geometry: torsoGeo)
        torsoVis.position = SCNVector3(0, 0.12, 0)
        spine.addChildNode(torsoVis)

        // Chest (upper torso)
        let chest = SCNNode()
        chest.name = "chest"
        chest.position = SCNVector3(0, 0.30, 0)
        spine.addChildNode(chest)

        // Shoulder joints (visual spheres)
        for side: Float in [-1, 1] {
            let shoulderJoint = SCNSphere(radius: 0.05)
            let isKey = shouldHighlight(.shoulder)
            shoulderJoint.materials = [isKey ? materials.keyJoint : materials.joint]
            let shoulderJointVis = SCNNode(geometry: shoulderJoint)
            shoulderJointVis.position = SCNVector3(side * 0.18, 0.05, 0)
            chest.addChildNode(shoulderJointVis)
        }

        // Neck
        let neck = SCNNode()
        neck.name = "neck"
        neck.position = SCNVector3(0, 0.15, 0)
        chest.addChildNode(neck)

        let neckGeo = SCNCylinder(radius: 0.03, height: 0.06)
        neckGeo.materials = [materials.bodySegment]
        let neckVis = SCNNode(geometry: neckGeo)
        neckVis.position = SCNVector3(0, 0.03, 0)
        neck.addChildNode(neckVis)

        // Head
        let head = SCNNode()
        head.name = "head"
        head.position = SCNVector3(0, 0.09, 0)
        neck.addChildNode(head)

        let headGeo = SCNSphere(radius: 0.10)
        headGeo.materials = [materials.bodySegment]
        let headVis = SCNNode(geometry: headGeo)
        head.addChildNode(headVis)

        // Simple face indicator (front-facing dot)
        let faceIndicator = SCNCylinder(radius: 0.015, height: 0.01)
        let faceMat = SCNMaterial()
        faceMat.diffuse.contents = UIColor(white: 0.3, alpha: 1.0)
        faceIndicator.materials = [faceMat]
        let faceNode = SCNNode(geometry: faceIndicator)
        faceNode.position = SCNVector3(0, 0, 0.095)
        faceNode.eulerAngles.x = Float.pi / 2
        head.addChildNode(faceNode)

        // Arms
        createRobotArm(parent: chest, side: -1, materials: materials, shouldHighlight: shouldHighlight) // Left
        createRobotArm(parent: chest, side: 1, materials: materials, shouldHighlight: shouldHighlight)  // Right

        // Legs
        createRobotLeg(parent: pelvis, side: -1, materials: materials, shouldHighlight: shouldHighlight) // Left
        createRobotLeg(parent: pelvis, side: 1, materials: materials, shouldHighlight: shouldHighlight)  // Right

        return root
    }

    private func createRobotArm(parent: SCNNode, side: Float, materials: RobotMaterials, shouldHighlight: (JointType) -> Bool) {
        let prefix = side < 0 ? "l" : "r"

        // Shoulder joint (pivot point)
        let shoulder = SCNNode()
        shoulder.name = "\(prefix)_shoulder"
        shoulder.position = SCNVector3(side * 0.18, 0.05, 0)
        parent.addChildNode(shoulder)

        // Upper arm
        let upperArm = SCNNode()
        upperArm.name = "\(prefix)_upper_arm"
        shoulder.addChildNode(upperArm)

        let upperArmGeo = SCNCylinder(radius: 0.04, height: 0.28)
        upperArmGeo.materials = [materials.bodySegment]
        let upperArmVis = SCNNode(geometry: upperArmGeo)
        upperArmVis.position = SCNVector3(0, -0.14, 0)
        upperArm.addChildNode(upperArmVis)

        // Elbow joint
        let elbow = SCNNode()
        elbow.name = "\(prefix)_elbow"
        elbow.position = SCNVector3(0, -0.28, 0)
        upperArm.addChildNode(elbow)

        let elbowJoint = SCNSphere(radius: 0.045)
        let elbowIsKey = shouldHighlight(.elbow)
        elbowJoint.materials = [elbowIsKey ? materials.keyJoint : materials.joint]
        let elbowVis = SCNNode(geometry: elbowJoint)
        elbow.addChildNode(elbowVis)

        // Forearm
        let forearm = SCNNode()
        forearm.name = "\(prefix)_forearm"
        elbow.addChildNode(forearm)

        let forearmGeo = SCNCylinder(radius: 0.035, height: 0.25)
        forearmGeo.materials = [materials.bodySegment]
        let forearmVis = SCNNode(geometry: forearmGeo)
        forearmVis.position = SCNVector3(0, -0.125, 0)
        forearm.addChildNode(forearmVis)

        // Wrist joint
        let wrist = SCNNode()
        wrist.name = "\(prefix)_wrist"
        wrist.position = SCNVector3(0, -0.25, 0)
        forearm.addChildNode(wrist)

        let wristJoint = SCNSphere(radius: 0.035)
        wristJoint.materials = [materials.joint]
        let wristVis = SCNNode(geometry: wristJoint)
        wrist.addChildNode(wristVis)

        // Hand (paddle shape)
        let hand = SCNNode()
        hand.name = "\(prefix)_hand"
        hand.position = SCNVector3(0, -0.05, 0)
        wrist.addChildNode(hand)

        let handGeo = SCNBox(width: 0.08, height: 0.10, length: 0.03, chamferRadius: 0.015)
        handGeo.materials = [materials.bodySegment]
        let handVis = SCNNode(geometry: handGeo)
        hand.addChildNode(handVis)
    }

    private func createRobotLeg(parent: SCNNode, side: Float, materials: RobotMaterials, shouldHighlight: (JointType) -> Bool) {
        let prefix = side < 0 ? "l" : "r"

        // Hip joint (pivot point)
        let hip = SCNNode()
        hip.name = "\(prefix)_hip"
        hip.position = SCNVector3(side * 0.1, -0.02, 0)
        parent.addChildNode(hip)

        // Thigh
        let thigh = SCNNode()
        thigh.name = "\(prefix)_thigh"
        hip.addChildNode(thigh)

        let thighGeo = SCNCylinder(radius: 0.055, height: 0.42)
        thighGeo.materials = [materials.bodySegment]
        let thighVis = SCNNode(geometry: thighGeo)
        thighVis.position = SCNVector3(0, -0.21, 0)
        thigh.addChildNode(thighVis)

        // Knee joint
        let knee = SCNNode()
        knee.name = "\(prefix)_knee"
        knee.position = SCNVector3(0, -0.42, 0)
        thigh.addChildNode(knee)

        let kneeJoint = SCNSphere(radius: 0.055)
        let kneeIsKey = shouldHighlight(.knee)
        kneeJoint.materials = [kneeIsKey ? materials.keyJoint : materials.joint]
        let kneeVis = SCNNode(geometry: kneeJoint)
        knee.addChildNode(kneeVis)

        // Shin
        let shin = SCNNode()
        shin.name = "\(prefix)_shin"
        knee.addChildNode(shin)

        let shinGeo = SCNCylinder(radius: 0.045, height: 0.40)
        shinGeo.materials = [materials.bodySegment]
        let shinVis = SCNNode(geometry: shinGeo)
        shinVis.position = SCNVector3(0, -0.20, 0)
        shin.addChildNode(shinVis)

        // Ankle joint
        let ankle = SCNNode()
        ankle.name = "\(prefix)_ankle"
        ankle.position = SCNVector3(0, -0.40, 0)
        shin.addChildNode(ankle)

        let ankleJoint = SCNSphere(radius: 0.04)
        let ankleIsKey = shouldHighlight(.ankle)
        ankleJoint.materials = [ankleIsKey ? materials.keyJoint : materials.joint]
        let ankleVis = SCNNode(geometry: ankleJoint)
        ankle.addChildNode(ankleVis)

        // Foot (rounded block)
        let foot = SCNNode()
        foot.name = "\(prefix)_foot"
        ankle.addChildNode(foot)

        let footGeo = SCNBox(width: 0.10, height: 0.05, length: 0.20, chamferRadius: 0.02)
        footGeo.materials = [materials.bodySegment]
        let footVis = SCNNode(geometry: footGeo)
        footVis.position = SCNVector3(0, -0.025, 0.04)
        foot.addChildNode(footVis)
    }

    // MARK: - Camera

    private func setupCamera(scene: SCNScene, angle: FormViewAngle) {
        let camera = SCNCamera()
        camera.fieldOfView = 50
        camera.zNear = 0.1
        camera.zFar = 50

        let node = SCNNode()
        node.camera = camera
        node.position = angle.cameraPosition
        node.look(at: SCNVector3(0, positioning.cameraLookAtY, 0))

        self.cameraNode = node
        scene.rootNode.addChildNode(node)
    }

    func updateCameraAngle(_ angle: FormViewAngle, animated: Bool = true) {
        guard let cam = cameraNode else { return }

        if animated {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.4
            cam.position = angle.cameraPosition
            cam.look(at: SCNVector3(0, positioning.cameraLookAtY, 0))
            SCNTransaction.commit()
        } else {
            cam.position = angle.cameraPosition
            cam.look(at: SCNVector3(0, positioning.cameraLookAtY, 0))
        }
    }

    // MARK: - Equipment Position Update

    func updateEquipmentPosition() {
        guard let humanoid = humanoidRoot else { return }

        let lHand = humanoid.childNode(withName: "l_hand", recursively: true)
        let rHand = humanoid.childNode(withName: "r_hand", recursively: true)

        switch exerciseType {
        case .benchPress, .overheadPress:
            // Barbell tracks between hands
            if let barbell = barbellNode,
               let leftHand = lHand,
               let rightHand = rHand {
                let leftPos = leftHand.worldPosition
                let rightPos = rightHand.worldPosition
                let midpoint = SCNVector3(
                    (leftPos.x + rightPos.x) / 2,
                    (leftPos.y + rightPos.y) / 2,
                    (leftPos.z + rightPos.z) / 2
                )
                barbell.worldPosition = midpoint
            }

        case .squat:
            // Barbell on shoulders/upper back
            if let barbell = barbellNode,
               let pelvis = humanoid.childNode(withName: "pelvis", recursively: true),
               let chest = humanoid.childNode(withName: "chest", recursively: true) {
                // Position barbell at upper back
                let chestPos = chest.worldPosition
                barbell.worldPosition = SCNVector3(
                    chestPos.x,
                    chestPos.y + 0.12,
                    chestPos.z - 0.05
                )
            }

        case .deadlift:
            // Barbell tracks with hands (at hip level when standing)
            if let barbell = barbellNode,
               let leftHand = lHand,
               let rightHand = rHand {
                let leftPos = leftHand.worldPosition
                let rightPos = rightHand.worldPosition
                let midpoint = SCNVector3(
                    (leftPos.x + rightPos.x) / 2,
                    (leftPos.y + rightPos.y) / 2,
                    (leftPos.z + rightPos.z) / 2
                )
                barbell.worldPosition = midpoint
            }

        case .bicepCurl, .lunge:
            // Dumbbells follow each hand
            if let leftDB = leftDumbbellNode, let leftHand = lHand {
                leftDB.worldPosition = leftHand.worldPosition
            }
            if let rightDB = rightDumbbellNode, let rightHand = rHand {
                rightDB.worldPosition = rightHand.worldPosition
            }

        case .row:
            // Single dumbbell follows right hand
            if let rightDB = rightDumbbellNode, let rightHand = rHand {
                rightDB.worldPosition = rightHand.worldPosition
            }

        default:
            break
        }
    }

    // MARK: - Animation / Pose Application

    func applyPose(keyframe: DemoKeyframe, to humanoid: SCNNode, animated: Bool = true) {
        currentPhase = keyframe.position

        let duration: TimeInterval = animated ? 0.6 : 0

        SCNTransaction.begin()
        SCNTransaction.animationDuration = duration
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        // Get all body parts
        let pelvis = humanoid.childNode(withName: "pelvis", recursively: true)
        let spine = humanoid.childNode(withName: "spine", recursively: true)
        let chest = humanoid.childNode(withName: "chest", recursively: true)
        let lUpperArm = humanoid.childNode(withName: "l_upper_arm", recursively: true)
        let rUpperArm = humanoid.childNode(withName: "r_upper_arm", recursively: true)
        let lForearm = humanoid.childNode(withName: "l_forearm", recursively: true)
        let rForearm = humanoid.childNode(withName: "r_forearm", recursively: true)
        let lThigh = humanoid.childNode(withName: "l_thigh", recursively: true)
        let rThigh = humanoid.childNode(withName: "r_thigh", recursively: true)
        let lShin = humanoid.childNode(withName: "l_shin", recursively: true)
        let rShin = humanoid.childNode(withName: "r_shin", recursively: true)

        // Get pose based on exercise and phase
        let pose = getPoseForExercise(phase: keyframe.position)

        // Apply the pose
        applyPoseKeyframe(
            pose: pose,
            pelvis: pelvis, spine: spine, chest: chest,
            lUpperArm: lUpperArm, rUpperArm: rUpperArm,
            lForearm: lForearm, rForearm: rForearm,
            lThigh: lThigh, rThigh: rThigh,
            lShin: lShin, rShin: rShin
        )

        SCNTransaction.commit()

        // Update equipment position after animation
        if animated {
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                self?.updateEquipmentPosition()
            }
        } else {
            updateEquipmentPosition()
        }
    }

    private func getPoseForExercise(phase: KeyframePosition) -> PoseKeyframe {
        switch exerciseType {
        case .benchPress:
            switch phase {
            case .start, .end:
                return BenchPressPoses.lockout
            case .mid:
                return BenchPressPoses.barAtChest
            }

        case .squat:
            switch phase {
            case .start:
                return SquatPoses.standing
            case .mid:
                return SquatPoses.halfSquat
            case .end:
                return SquatPoses.deepSquat
            }

        case .deadlift:
            switch phase {
            case .start:
                return DeadliftPoses.bentOver
            case .mid:
                // Midway - interpolate
                return interpolatePose(from: DeadliftPoses.bentOver, to: DeadliftPoses.standing, t: 0.5)
            case .end:
                return DeadliftPoses.standing
            }

        case .pullUp:
            switch phase {
            case .start, .end:
                return PullUpPoses.hanging
            case .mid:
                return PullUpPoses.pulledUp
            }

        case .overheadPress:
            return getOverheadPressPose(phase: phase)

        case .bicepCurl:
            return getBicepCurlPose(phase: phase)

        case .latPulldown:
            return getLatPulldownPose(phase: phase)

        case .row:
            return getRowPose(phase: phase)

        case .lunge:
            return getLungePose(phase: phase)

        default:
            return PoseKeyframe.neutral
        }
    }

    private func getOverheadPressPose(phase: KeyframePosition) -> PoseKeyframe {
        switch phase {
        case .start, .end:
            // Bar at shoulders
            return PoseKeyframe(
                leftShoulder: SCNVector3(-Float.pi/2, 0, 0.3),
                rightShoulder: SCNVector3(-Float.pi/2, 0, -0.3),
                leftElbow: 1.5,
                rightElbow: 1.5,
                leftHip: SCNVector3(0, 0, 0),
                rightHip: SCNVector3(0, 0, 0),
                leftKnee: 0,
                rightKnee: 0,
                spineForward: 0,
                chestForward: 0,
                pelvisOffset: SCNVector3(0, 0, 0)
            )
        case .mid:
            // Bar overhead
            return PoseKeyframe(
                leftShoulder: SCNVector3(-Float.pi, 0, 0.1),
                rightShoulder: SCNVector3(-Float.pi, 0, -0.1),
                leftElbow: 0.1,
                rightElbow: 0.1,
                leftHip: SCNVector3(0, 0, 0),
                rightHip: SCNVector3(0, 0, 0),
                leftKnee: 0,
                rightKnee: 0,
                spineForward: 0,
                chestForward: 0,
                pelvisOffset: SCNVector3(0, 0, 0)
            )
        }
    }

    private func getBicepCurlPose(phase: KeyframePosition) -> PoseKeyframe {
        switch phase {
        case .start, .end:
            // Arms down
            return PoseKeyframe(
                leftShoulder: SCNVector3(0, 0, 0.1),
                rightShoulder: SCNVector3(0, 0, -0.1),
                leftElbow: 0,
                rightElbow: 0,
                leftHip: SCNVector3(0, 0, 0),
                rightHip: SCNVector3(0, 0, 0),
                leftKnee: 0,
                rightKnee: 0,
                spineForward: 0,
                chestForward: 0,
                pelvisOffset: SCNVector3(0, 0, 0)
            )
        case .mid:
            // Arms curled
            return PoseKeyframe(
                leftShoulder: SCNVector3(0, 0, 0.1),
                rightShoulder: SCNVector3(0, 0, -0.1),
                leftElbow: -2.5,
                rightElbow: -2.5,
                leftHip: SCNVector3(0, 0, 0),
                rightHip: SCNVector3(0, 0, 0),
                leftKnee: 0,
                rightKnee: 0,
                spineForward: 0,
                chestForward: 0,
                pelvisOffset: SCNVector3(0, 0, 0)
            )
        }
    }

    private func getLatPulldownPose(phase: KeyframePosition) -> PoseKeyframe {
        switch phase {
        case .start, .end:
            // Arms up reaching for bar
            return PoseKeyframe(
                leftShoulder: SCNVector3(-Float.pi, 0, 0.5),
                rightShoulder: SCNVector3(-Float.pi, 0, -0.5),
                leftElbow: 0,
                rightElbow: 0,
                leftHip: SCNVector3(1.57, 0, 0),
                rightHip: SCNVector3(1.57, 0, 0),
                leftKnee: -1.57,
                rightKnee: -1.57,
                spineForward: 0,
                chestForward: 0,
                pelvisOffset: SCNVector3(0, 0, 0)
            )
        case .mid:
            // Bar pulled to chest
            return PoseKeyframe(
                leftShoulder: SCNVector3(-Float.pi + 1.5, 0, 0.2),
                rightShoulder: SCNVector3(-Float.pi + 1.5, 0, -0.2),
                leftElbow: 2.2,
                rightElbow: 2.2,
                leftHip: SCNVector3(1.57, 0, 0),
                rightHip: SCNVector3(1.57, 0, 0),
                leftKnee: -1.57,
                rightKnee: -1.57,
                spineForward: 0,
                chestForward: 0,
                pelvisOffset: SCNVector3(0, 0, 0)
            )
        }
    }

    private func getRowPose(phase: KeyframePosition) -> PoseKeyframe {
        // Bent over row position
        switch phase {
        case .start, .end:
            return PoseKeyframe(
                leftShoulder: SCNVector3(0.3, 0, 0.2),
                rightShoulder: SCNVector3(0, 0, -0.2),
                leftElbow: 0,
                rightElbow: 0,
                leftHip: SCNVector3(0.6, 0, 0),
                rightHip: SCNVector3(0.2, 0, 0),
                leftKnee: -0.8,
                rightKnee: -0.3,
                spineForward: 0.8,
                chestForward: 0,
                pelvisOffset: SCNVector3(0, 0, 0)
            )
        case .mid:
            return PoseKeyframe(
                leftShoulder: SCNVector3(0.3, 0, 0.2),
                rightShoulder: SCNVector3(-0.8, 0, -0.2),
                leftElbow: 0,
                rightElbow: -1.8,
                leftHip: SCNVector3(0.6, 0, 0),
                rightHip: SCNVector3(0.2, 0, 0),
                leftKnee: -0.8,
                rightKnee: -0.3,
                spineForward: 0.8,
                chestForward: 0,
                pelvisOffset: SCNVector3(0, 0, 0)
            )
        }
    }

    private func getLungePose(phase: KeyframePosition) -> PoseKeyframe {
        switch phase {
        case .start:
            return PoseKeyframe(
                leftShoulder: SCNVector3(0, 0, 0.1),
                rightShoulder: SCNVector3(0, 0, -0.1),
                leftElbow: 0,
                rightElbow: 0,
                leftHip: SCNVector3(0, 0, 0),
                rightHip: SCNVector3(0, 0, 0),
                leftKnee: 0,
                rightKnee: 0,
                spineForward: 0,
                chestForward: 0,
                pelvisOffset: SCNVector3(0, 0, 0)
            )
        case .mid:
            return PoseKeyframe(
                leftShoulder: SCNVector3(0, 0, 0.1),
                rightShoulder: SCNVector3(0, 0, -0.1),
                leftElbow: 0,
                rightElbow: 0,
                leftHip: SCNVector3(-0.3, 0, 0),
                rightHip: SCNVector3(0.7, 0, 0),
                leftKnee: -0.5,
                rightKnee: -1.2,
                spineForward: 0,
                chestForward: 0,
                pelvisOffset: SCNVector3(0, -0.25, 0.1)
            )
        case .end:
            return PoseKeyframe(
                leftShoulder: SCNVector3(0, 0, 0.1),
                rightShoulder: SCNVector3(0, 0, -0.1),
                leftElbow: 0,
                rightElbow: 0,
                leftHip: SCNVector3(-0.5, 0, 0),
                rightHip: SCNVector3(1.0, 0, 0),
                leftKnee: -0.8,
                rightKnee: -1.57,
                spineForward: 0,
                chestForward: 0,
                pelvisOffset: SCNVector3(0, -0.35, 0.15)
            )
        }
    }

    private func interpolatePose(from: PoseKeyframe, to: PoseKeyframe, t: Float) -> PoseKeyframe {
        return PoseKeyframe(
            leftShoulder: lerpVector3(from.leftShoulder, to.leftShoulder, t),
            rightShoulder: lerpVector3(from.rightShoulder, to.rightShoulder, t),
            leftElbow: lerp(from.leftElbow, to.leftElbow, t),
            rightElbow: lerp(from.rightElbow, to.rightElbow, t),
            leftHip: lerpVector3(from.leftHip, to.leftHip, t),
            rightHip: lerpVector3(from.rightHip, to.rightHip, t),
            leftKnee: lerp(from.leftKnee, to.leftKnee, t),
            rightKnee: lerp(from.rightKnee, to.rightKnee, t),
            spineForward: lerp(from.spineForward, to.spineForward, t),
            chestForward: lerp(from.chestForward, to.chestForward, t),
            pelvisOffset: lerpVector3(from.pelvisOffset, to.pelvisOffset, t)
        )
    }

    private func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float {
        return a + (b - a) * t
    }

    private func lerpVector3(_ a: SCNVector3, _ b: SCNVector3, _ t: Float) -> SCNVector3 {
        return SCNVector3(
            lerp(a.x, b.x, t),
            lerp(a.y, b.y, t),
            lerp(a.z, b.z, t)
        )
    }

    private func applyPoseKeyframe(
        pose: PoseKeyframe,
        pelvis: SCNNode?, spine: SCNNode?, chest: SCNNode?,
        lUpperArm: SCNNode?, rUpperArm: SCNNode?,
        lForearm: SCNNode?, rForearm: SCNNode?,
        lThigh: SCNNode?, rThigh: SCNNode?,
        lShin: SCNNode?, rShin: SCNNode?
    ) {
        // Apply pelvis offset (relative to base position)
        if let p = pelvis {
            p.position = SCNVector3(
                positioning.pelvisPosition.x + pose.pelvisOffset.x,
                positioning.pelvisPosition.y + pose.pelvisOffset.y,
                positioning.pelvisPosition.z + pose.pelvisOffset.z
            )
        }

        // Spine forward lean
        spine?.eulerAngles.x = pose.spineForward
        chest?.eulerAngles.x = pose.chestForward

        // Arms
        lUpperArm?.eulerAngles = pose.leftShoulder
        rUpperArm?.eulerAngles = pose.rightShoulder
        lForearm?.eulerAngles.x = pose.leftElbow
        rForearm?.eulerAngles.x = pose.rightElbow

        // Legs
        lThigh?.eulerAngles = pose.leftHip
        rThigh?.eulerAngles = pose.rightHip
        lShin?.eulerAngles.x = pose.leftKnee
        rShin?.eulerAngles.x = pose.rightKnee
    }
}
