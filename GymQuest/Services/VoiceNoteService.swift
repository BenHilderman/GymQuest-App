//
//  VoiceNoteService.swift
//  GymQuest
//
//  Core audio infrastructure for voice notes (recording & playback)
//  and speech-to-text meal dictation.
//

import Foundation
import SwiftUI
import AVFoundation
import Speech

// MARK: - Recording State

enum RecordingState: Equatable {
    case idle
    case recording
    case recorded
}

// MARK: - VoiceNoteService

@MainActor
final class VoiceNoteService: NSObject, ObservableObject {
    static let shared = VoiceNoteService()

    // MARK: - Recording State
    @Published var recordingState: RecordingState = .idle
    @Published var recordingDuration: TimeInterval = 0
    @Published var recordedData: Data?

    // MARK: - Playback State
    @Published var isPlaying: Bool = false
    @Published var playbackProgress: Double = 0
    @Published var playbackCurrentTime: TimeInterval = 0

    // MARK: - Transcription State
    @Published var isTranscribing: Bool = false
    @Published var transcribedText: String = ""

    // MARK: - Permissions
    @Published var micPermissionGranted: Bool = false
    @Published var speechPermissionGranted: Bool = false

    // MARK: - Private
    private let maxRecordingDuration: TimeInterval = 60

    #if canImport(UIKit)
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingTimer: Timer?
    private var playbackTimer: Timer?
    private var recordingStartTime: Date?

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    #endif

    private var tempRecordingURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("gymquest_voice_note.m4a")
    }

    private var tempPlaybackURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("gymquest_playback.m4a")
    }

    private override init() {
        super.init()
        #if canImport(UIKit)
        speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
        #endif
        checkPermissions()
    }

    // MARK: - Permissions

    func requestMicPermission() {
        #if canImport(UIKit)
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                self?.micPermissionGranted = granted
            }
        }
        #endif
    }

    func requestSpeechPermission() {
        #if canImport(UIKit)
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                self?.speechPermissionGranted = (status == .authorized)
            }
        }
        #endif
    }

    private func checkPermissions() {
        #if canImport(UIKit)
        micPermissionGranted = AVAudioApplication.shared.recordPermission == .granted
        speechPermissionGranted = SFSpeechRecognizer.authorizationStatus() == .authorized
        #endif
    }

    // MARK: - Recording

    func startRecording() {
        #if canImport(UIKit)
        guard recordingState == .idle else { return }

        if !micPermissionGranted {
            requestMicPermission()
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
            try session.setActive(true)

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            // Remove existing temp file
            try? FileManager.default.removeItem(at: tempRecordingURL)

            audioRecorder = try AVAudioRecorder(url: tempRecordingURL, settings: settings)
            audioRecorder?.record()

            recordingState = .recording
            recordingDuration = 0
            recordingStartTime = Date()

            // Timer for duration display + 60s auto-stop
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, let start = self.recordingStartTime else { return }
                    self.recordingDuration = Date().timeIntervalSince(start)
                    if self.recordingDuration >= self.maxRecordingDuration {
                        self.stopRecording()
                    }
                }
            }
        } catch {
            recordingState = .idle
        }
        #endif
    }

    @discardableResult
    func stopRecording() -> Data? {
        #if canImport(UIKit)
        guard recordingState == .recording else { return nil }

        audioRecorder?.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil

        // Read recorded data
        if let data = try? Data(contentsOf: tempRecordingURL) {
            recordedData = data
            recordingState = .recorded
            return data
        }

        recordingState = .idle
        return nil
        #else
        return nil
        #endif
    }

    func deleteRecording() {
        #if canImport(UIKit)
        stopPlayback()
        audioRecorder?.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordedData = nil
        recordingDuration = 0
        recordingState = .idle
        try? FileManager.default.removeItem(at: tempRecordingURL)
        #endif
    }

    // MARK: - Playback

    func playAudio(from data: Data) {
        #if canImport(UIKit)
        stopPlayback()

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            // Write data to temp file for playback
            try data.write(to: tempPlaybackURL)

            audioPlayer = try AVAudioPlayer(contentsOf: tempPlaybackURL)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            isPlaying = true
            playbackProgress = 0
            playbackCurrentTime = 0

            playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, let player = self.audioPlayer else { return }
                    if player.duration > 0 {
                        self.playbackProgress = player.currentTime / player.duration
                        self.playbackCurrentTime = player.currentTime
                    }
                }
            }
        } catch {
            isPlaying = false
        }
        #endif
    }

    func stopPlayback() {
        #if canImport(UIKit)
        audioPlayer?.stop()
        audioPlayer = nil
        playbackTimer?.invalidate()
        playbackTimer = nil
        isPlaying = false
        playbackProgress = 0
        playbackCurrentTime = 0
        try? FileManager.default.removeItem(at: tempPlaybackURL)
        #endif
    }

    // MARK: - Live Transcription (for meal logging)

    func startLiveTranscription(appendTo binding: Binding<String>) {
        #if canImport(UIKit)
        guard !isTranscribing else { return }

        if !micPermissionGranted {
            requestMicPermission()
            return
        }
        if !speechPermissionGranted {
            requestSpeechPermission()
            return
        }

        guard let speechRecognizer, speechRecognizer.isAvailable else { return }

        do {
            // Stop any existing transcription
            stopLiveTranscription()

            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            recognitionRequest = request

            let engine = AVAudioEngine()
            audioEngine = engine

            let inputNode = engine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                request.append(buffer)
            }

            engine.prepare()
            try engine.start()

            isTranscribing = true
            transcribedText = ""

            recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }

                    if let result {
                        let text = result.bestTranscription.formattedString
                        self.transcribedText = text
                        binding.wrappedValue = text
                    }

                    if error != nil || (result?.isFinal ?? false) {
                        self.stopLiveTranscription()
                    }
                }
            }
        } catch {
            isTranscribing = false
        }
        #endif
    }

    func stopLiveTranscription() {
        #if canImport(UIKit)
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        isTranscribing = false
        #endif
    }
}

// MARK: - AVAudioPlayerDelegate

#if canImport(UIKit)
extension VoiceNoteService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.stopPlayback()
        }
    }
}
#endif
