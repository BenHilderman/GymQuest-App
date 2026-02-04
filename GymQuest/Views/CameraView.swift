//
//  CameraView.swift
//  GymQuest
//
//  In-app camera for capturing photos and videos directly.
//  Supports switching between photo/video modes, front/back camera.
//

import SwiftUI
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)

// MARK: - Camera View

struct InAppCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraModel()

    let onCapture: (Data, Bool) -> Void  // (data, isVideo)

    @State private var isVideoMode = false
    @State private var flashEnabled = false
    @State private var showingPreview = false
    @State private var capturedImageData: Data?
    @State private var capturedVideoURL: URL?

    var body: some View {
        ZStack {
            // Camera preview
            CameraPreview(camera: camera)
                .ignoresSafeArea()

            // Dark overlay at top/bottom for controls
            VStack {
                // Top controls
                HStack {
                    // Close button
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }

                    Spacer()

                    // Flash toggle
                    Button {
                        flashEnabled.toggle()
                        camera.toggleFlash(flashEnabled)
                    } label: {
                        Image(systemName: flashEnabled ? "bolt.fill" : "bolt.slash.fill")
                            .font(.title2)
                            .foregroundColor(flashEnabled ? .yellow : .white)
                            .padding(12)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }

                    // Flip camera
                    Button {
                        camera.flipCamera()
                    } label: {
                        Image(systemName: "camera.rotate")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)

                Spacer()

                // Mode selector
                HStack(spacing: 40) {
                    Button {
                        withAnimation {
                            isVideoMode = false
                        }
                    } label: {
                        Text("Photo")
                            .font(.system(size: 15, weight: isVideoMode ? .regular : .bold))
                            .foregroundColor(isVideoMode ? .gray : .white)
                    }

                    Button {
                        withAnimation {
                            isVideoMode = true
                        }
                    } label: {
                        Text("Video")
                            .font(.system(size: 15, weight: isVideoMode ? .bold : .regular))
                            .foregroundColor(isVideoMode ? .white : .gray)
                    }
                }
                .padding(.bottom, 20)

                // Capture button
                HStack {
                    // Gallery button (placeholder)
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "photo.on.rectangle")
                                .foregroundColor(.white)
                        )

                    Spacer()

                    // Main capture button
                    Button {
                        if isVideoMode {
                            if camera.isRecording {
                                camera.stopRecording()
                            } else {
                                camera.startRecording()
                            }
                        } else {
                            camera.takePhoto()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .strokeBorder(Color.white, lineWidth: 4)
                                .frame(width: 80, height: 80)

                            if isVideoMode {
                                if camera.isRecording {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.red)
                                        .frame(width: 32, height: 32)
                                } else {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 60, height: 60)
                                }
                            } else {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 60, height: 60)
                            }
                        }
                    }

                    Spacer()

                    // Spacer for symmetry
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 50, height: 50)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)

                // Recording indicator
                if camera.isRecording {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                        Text(camera.recordingDuration)
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.black.opacity(0.6)))
                    .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            camera.checkPermissions()
        }
        .onChange(of: camera.capturedPhoto) { _, newData in
            if let data = newData {
                capturedImageData = data
                showingPreview = true
            }
        }
        .onChange(of: camera.capturedVideoURL) { _, newURL in
            if let url = newURL {
                capturedVideoURL = url
                showingPreview = true
            }
        }
        .fullScreenCover(isPresented: $showingPreview) {
            if let imageData = capturedImageData {
                CapturePreviewView(
                    imageData: imageData,
                    isVideo: false,
                    onRetake: {
                        capturedImageData = nil
                        showingPreview = false
                    },
                    onUse: {
                        onCapture(imageData, false)
                        dismiss()
                    }
                )
            } else if let videoURL = capturedVideoURL, let videoData = try? Data(contentsOf: videoURL) {
                CapturePreviewView(
                    imageData: videoData,
                    isVideo: true,
                    onRetake: {
                        capturedVideoURL = nil
                        showingPreview = false
                    },
                    onUse: {
                        onCapture(videoData, true)
                        dismiss()
                    }
                )
            }
        }
    }
}

// MARK: - Capture Preview

struct CapturePreviewView: View {
    let imageData: Data
    let isVideo: Bool
    let onRetake: () -> Void
    let onUse: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isVideo {
                // Video preview would go here
                VStack {
                    Image(systemName: "video.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.5))
                    Text("Video captured")
                        .foregroundColor(.gray)
                }
            } else if let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }

            VStack {
                Spacer()

                HStack(spacing: 60) {
                    Button {
                        onRetake()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.title)
                            Text("Retake")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                    }

                    Button {
                        onUse()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 50))
                            Text("Use")
                                .font(.caption)
                        }
                        .foregroundColor(.green)
                    }
                }
                .padding(.bottom, 60)
            }
        }
    }
}

// MARK: - Camera Model

class CameraModel: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var isRecording = false
    @Published var capturedPhoto: Data?
    @Published var capturedVideoURL: URL?
    @Published var recordingDuration = "0:00"

    private var photoOutput = AVCapturePhotoOutput()
    private var videoOutput = AVCaptureMovieFileOutput()
    private var currentCameraPosition: AVCaptureDevice.Position = .back
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?

    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.setupCamera()
                    }
                }
            }
        default:
            break
        }

        // Also request audio for video
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
    }

    func setupCamera() {
        session.beginConfiguration()
        session.sessionPreset = .high

        // Add video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            return
        }

        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        }

        // Add audio input
        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }

        // Add photo output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        // Add video output
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        session.commitConfiguration()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func takePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func startRecording() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
        videoOutput.startRecording(to: tempURL, recordingDelegate: self)
        isRecording = true
        recordingStartTime = Date()

        // Start timer for duration display
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let start = self?.recordingStartTime else { return }
            let elapsed = Int(Date().timeIntervalSince(start))
            let mins = elapsed / 60
            let secs = elapsed % 60
            DispatchQueue.main.async {
                self?.recordingDuration = String(format: "%d:%02d", mins, secs)
            }
        }
    }

    func stopRecording() {
        videoOutput.stopRecording()
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    func flipCamera() {
        session.beginConfiguration()

        // Remove current input
        session.inputs.forEach { input in
            if let deviceInput = input as? AVCaptureDeviceInput,
               deviceInput.device.hasMediaType(.video) {
                session.removeInput(deviceInput)
            }
        }

        // Switch position
        currentCameraPosition = currentCameraPosition == .back ? .front : .back

        // Add new input
        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition),
              let newInput = try? AVCaptureDeviceInput(device: newDevice) else {
            session.commitConfiguration()
            return
        }

        if session.canAddInput(newInput) {
            session.addInput(newInput)
        }

        session.commitConfiguration()
    }

    func toggleFlash(_ enabled: Bool) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition),
              device.hasTorch else { return }

        try? device.lockForConfiguration()
        device.torchMode = enabled ? .on : .off
        device.unlockForConfiguration()
    }
}

extension CameraModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation() else { return }
        DispatchQueue.main.async {
            self.capturedPhoto = data
        }
    }
}

extension CameraModel: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        DispatchQueue.main.async {
            self.capturedVideoURL = outputFileURL
        }
    }
}

// MARK: - Camera Preview UIViewRepresentable

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var camera: CameraModel

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)

        let previewLayer = AVCaptureVideoPreviewLayer(session: camera.session)
        previewLayer.frame = view.frame
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.frame
        }
    }
}

#else

// macOS placeholder
struct InAppCameraView: View {
    let onCapture: (Data, Bool) -> Void

    var body: some View {
        Text("Camera not available on macOS")
    }
}

#endif
