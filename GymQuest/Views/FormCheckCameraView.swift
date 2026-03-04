//
//  FormCheckCameraView.swift
//  GymQuest
//
//  Real-time form checking using camera and Vision body pose detection.
//  Shows live skeleton overlay and form feedback badges.
//

#if canImport(UIKit)
import SwiftUI
import AVFoundation
import Vision

struct FormCheckCameraView: View {
    @StateObject private var poseService = PoseDetectionService.shared
    @State private var selectedExercise = "Squat"
    @Environment(\.dismiss) private var dismiss

    private let exercises = ["Squat", "Bench Press", "Deadlift", "Overhead Press"]

    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(onFrame: { buffer in
                poseService.processFrame(buffer)
            })
            .ignoresSafeArea()

            // Pose overlay
            PoseOverlayView(points: poseService.detectedPoints)
                .ignoresSafeArea()

            VStack {
                // Top bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Text("Form Check")
                        .font(.headline)
                        .foregroundColor(.white)

                    Spacer()

                    Color.clear.frame(width: 32)
                }
                .padding()
                .background(.ultraThinMaterial.opacity(0.8))

                // Exercise picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(exercises, id: \.self) { exercise in
                            Button {
                                selectedExercise = exercise
                                poseService.setExercise(exercise)
                            } label: {
                                Text(exercise)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(selectedExercise == exercise ? Color.white : Color.white.opacity(0.2))
                                    .foregroundColor(selectedExercise == exercise ? .black : .white)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()

                // Form feedback badges
                VStack(spacing: 8) {
                    ForEach(poseService.formFeedback) { feedback in
                        FormFeedbackBadge(feedback: feedback)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            poseService.setExercise(selectedExercise)
        }
    }
}

// MARK: - Form Feedback Badge

struct FormFeedbackBadge: View {
    let feedback: FormFeedbackItem

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: badgeIcon)
                .foregroundColor(badgeColor)

            Text(feedback.message)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(badgeColor.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(badgeColor.opacity(0.6), lineWidth: 1)
        )
    }

    private var badgeIcon: String {
        switch feedback.severity {
        case .good: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.circle.fill"
        }
    }

    private var badgeColor: Color {
        switch feedback.severity {
        case .good: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Camera Preview (UIViewRepresentable)

struct CameraPreviewView: UIViewRepresentable {
    let onFrame: (CMSampleBuffer) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let session = AVCaptureSession()
        session.sessionPreset = .medium

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return view
        }

        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(context.coordinator, queue: DispatchQueue(label: "camera.frame.queue"))
        session.addOutput(output)

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = UIScreen.main.bounds
        view.layer.addSublayer(previewLayer)

        context.coordinator.previewLayer = previewLayer

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFrame: onFrame)
    }

    class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        let onFrame: (CMSampleBuffer) -> Void
        var previewLayer: AVCaptureVideoPreviewLayer?

        init(onFrame: @escaping (CMSampleBuffer) -> Void) {
            self.onFrame = onFrame
        }

        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            onFrame(sampleBuffer)
        }
    }
}

// MARK: - Pose Overlay View

struct PoseOverlayView: View {
    let points: [VNHumanBodyPoseObservation.JointName: CGPoint]

    private let connections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.neck, .leftShoulder), (.neck, .rightShoulder),
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.neck, .root),
        (.root, .leftHip), (.root, .rightHip),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
    ]

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                // Draw connections
                for (from, to) in connections {
                    guard let p1 = points[from], let p2 = points[to] else { continue }
                    let start = CGPoint(x: p1.x * size.width, y: p1.y * size.height)
                    let end = CGPoint(x: p2.x * size.width, y: p2.y * size.height)

                    var path = Path()
                    path.move(to: start)
                    path.addLine(to: end)
                    context.stroke(path, with: .color(.green.opacity(0.8)), lineWidth: 3)
                }

                // Draw joint points
                for (_, point) in points {
                    let center = CGPoint(x: point.x * size.width, y: point.y * size.height)
                    let rect = CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10)
                    context.fill(Path(ellipseIn: rect), with: .color(.green))
                }
            }
        }
    }
}
#endif
