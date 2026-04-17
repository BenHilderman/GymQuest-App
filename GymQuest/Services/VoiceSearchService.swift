import Foundation
#if os(iOS) && canImport(Speech) && canImport(AVFoundation)
import Speech
import AVFoundation

/// Live dictation for the search bar. Streams partial transcripts to the
/// caller via `onTranscript`. Permission denial / unavailable hardware are
/// surfaced as `.error` state, not exceptions.
@MainActor
final class VoiceSearchService: ObservableObject {

    enum State: Equatable {
        case idle
        case listening
        case error(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var transcript: String = ""

    private let recognizer = SFSpeechRecognizer()
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    /// Begin listening. Caller passes a closure that fires for each partial
    /// result (so the search field updates live as the user speaks).
    func start(onTranscript: @escaping (String) -> Void) {
        guard let recognizer, recognizer.isAvailable else {
            state = .error("Voice search isn't available right now.")
            return
        }

        SFSpeechRecognizer.requestAuthorization { [weak self] auth in
            DispatchQueue.main.async {
                guard let self else { return }
                guard auth == .authorized else {
                    self.state = .error("Speech permission denied — enable it in Settings to use voice search.")
                    return
                }
                self.requestMicAndStart(onTranscript: onTranscript)
            }
        }
    }

    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        state = .idle
    }

    // MARK: - Private

    private func requestMicAndStart(onTranscript: @escaping (String) -> Void) {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                guard granted else {
                    self.state = .error("Mic permission denied — enable it in Settings to use voice search.")
                    return
                }
                self.beginRecording(onTranscript: onTranscript)
            }
        }
    }

    private func beginRecording(onTranscript: @escaping (String) -> Void) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let req = SFSpeechAudioBufferRecognitionRequest()
            req.shouldReportPartialResults = true
            request = req

            let input = audioEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                req.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()

            task = recognizer?.recognitionTask(with: req) { [weak self] result, error in
                guard let self else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    Task { @MainActor in
                        self.transcript = text
                        onTranscript(text)
                        if result.isFinal { self.stop() }
                    }
                }
                if error != nil {
                    Task { @MainActor in self.stop() }
                }
            }

            state = .listening
        } catch {
            state = .error("Couldn't start microphone — try again.")
            stop()
        }
    }
}
#endif
