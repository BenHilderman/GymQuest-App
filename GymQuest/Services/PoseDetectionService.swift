//
//  PoseDetectionService.swift
//  GymQuest
//
//  Real-time body pose detection using Vision framework.
//  Analyzes joint angles to provide form feedback for compound lifts.
//

#if canImport(UIKit)
import Foundation
import Vision
import CoreMedia
import Combine

// MARK: - Form Feedback

struct FormFeedbackItem: Identifiable {
    let id = UUID()
    let message: String
    let severity: FormSeverity
    let joint: String
}

enum FormSeverity: String {
    case good
    case warning
    case critical
}

// MARK: - Form Rules

struct AngleCheck {
    let jointA: VNHumanBodyPoseObservation.JointName
    let vertex: VNHumanBodyPoseObservation.JointName
    let jointC: VNHumanBodyPoseObservation.JointName
    let optimalRange: ClosedRange<Double>
    let warningMessage: String
    let criticalMessage: String
    let jointLabel: String
}

struct FormRule {
    let exerciseName: String
    let checks: [AngleCheck]
}

// MARK: - Service

@MainActor
class PoseDetectionService: ObservableObject {
    static let shared = PoseDetectionService()

    @Published var formFeedback: [FormFeedbackItem] = []
    @Published var detectedPoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]

    private var currentExercise: String = "Squat"

    // MARK: - Predefined Rules

    static let exerciseRules: [FormRule] = [
        FormRule(exerciseName: "Squat", checks: [
            AngleCheck(
                jointA: .rightHip, vertex: .rightKnee, jointC: .rightAnkle,
                optimalRange: 70...100,
                warningMessage: "Knees slightly past optimal range",
                criticalMessage: "Knee angle too acute — risk of injury",
                jointLabel: "Right Knee"
            ),
            AngleCheck(
                jointA: .rightShoulder, vertex: .rightHip, jointC: .rightKnee,
                optimalRange: 45...90,
                warningMessage: "Lean forward slightly less",
                criticalMessage: "Excessive forward lean — brace core",
                jointLabel: "Back Angle"
            ),
        ]),
        FormRule(exerciseName: "Bench Press", checks: [
            AngleCheck(
                jointA: .rightShoulder, vertex: .rightElbow, jointC: .rightWrist,
                optimalRange: 70...110,
                warningMessage: "Elbow angle slightly off",
                criticalMessage: "Elbows flaring too wide — tuck in",
                jointLabel: "Elbow"
            ),
        ]),
        FormRule(exerciseName: "Deadlift", checks: [
            AngleCheck(
                jointA: .rightShoulder, vertex: .rightHip, jointC: .rightKnee,
                optimalRange: 30...80,
                warningMessage: "Maintain neutral spine",
                criticalMessage: "Back rounding detected — reduce weight",
                jointLabel: "Back Angle"
            ),
            AngleCheck(
                jointA: .rightHip, vertex: .rightKnee, jointC: .rightAnkle,
                optimalRange: 120...170,
                warningMessage: "Hinge more at the hips",
                criticalMessage: "Too much knee bend — this is a hinge movement",
                jointLabel: "Hip Hinge"
            ),
        ]),
        FormRule(exerciseName: "Overhead Press", checks: [
            AngleCheck(
                jointA: .rightShoulder, vertex: .rightElbow, jointC: .rightWrist,
                optimalRange: 80...180,
                warningMessage: "Press path slightly off center",
                criticalMessage: "Bar drifting forward — keep over midfoot",
                jointLabel: "Press Path"
            ),
        ]),
    ]

    // MARK: - Exercise Selection

    func setExercise(_ name: String) {
        currentExercise = name
        formFeedback = []
    }

    // MARK: - Frame Processing

    func processFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectHumanBodyPoseRequest { [weak self] request, error in
            guard let self = self,
                  error == nil,
                  let observation = (request.results as? [VNHumanBodyPoseObservation])?.first else {
                return
            }
            Task { @MainActor in
                self.processObservation(observation)
            }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        try? handler.perform([request])
    }

    private func processObservation(_ observation: VNHumanBodyPoseObservation) {
        // Extract joint points
        var points: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        let allJoints: [VNHumanBodyPoseObservation.JointName] = [
            .nose, .neck, .leftShoulder, .rightShoulder, .leftElbow, .rightElbow,
            .leftWrist, .rightWrist, .leftHip, .rightHip, .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle, .root
        ]

        for joint in allJoints {
            if let point = try? observation.recognizedPoint(joint), point.confidence > 0.3 {
                points[joint] = CGPoint(x: point.location.x, y: 1 - point.location.y)
            }
        }
        detectedPoints = points

        // Apply form rules for current exercise
        guard let rule = Self.exerciseRules.first(where: {
            $0.exerciseName.lowercased() == currentExercise.lowercased()
        }) else {
            formFeedback = []
            return
        }

        var feedback: [FormFeedbackItem] = []

        for check in rule.checks {
            guard let pointA = points[check.jointA],
                  let vertex = points[check.vertex],
                  let pointC = points[check.jointC] else {
                continue
            }

            let angle = angleBetween(pointA: pointA, vertex: vertex, pointC: pointC)

            if check.optimalRange.contains(angle) {
                feedback.append(FormFeedbackItem(
                    message: "\(check.jointLabel): Good form",
                    severity: .good,
                    joint: check.jointLabel
                ))
            } else {
                let deviation = min(
                    abs(angle - check.optimalRange.lowerBound),
                    abs(angle - check.optimalRange.upperBound)
                )
                if deviation > 20 {
                    feedback.append(FormFeedbackItem(
                        message: check.criticalMessage,
                        severity: .critical,
                        joint: check.jointLabel
                    ))
                } else {
                    feedback.append(FormFeedbackItem(
                        message: check.warningMessage,
                        severity: .warning,
                        joint: check.jointLabel
                    ))
                }
            }
        }

        formFeedback = feedback
    }

    // MARK: - Angle Calculation

    /// Calculate angle between three points (in degrees)
    func angleBetween(pointA: CGPoint, vertex: CGPoint, pointC: CGPoint) -> Double {
        let v1 = CGPoint(x: pointA.x - vertex.x, y: pointA.y - vertex.y)
        let v2 = CGPoint(x: pointC.x - vertex.x, y: pointC.y - vertex.y)

        let dot = v1.x * v2.x + v1.y * v2.y
        let cross = v1.x * v2.y - v1.y * v2.x

        let angle = atan2(cross, dot)
        return abs(angle * 180 / .pi)
    }
}
#endif
