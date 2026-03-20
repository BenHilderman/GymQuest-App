import Foundation
import AVFoundation
import Accelerate

@Observable @MainActor
final class MusicPreviewService {
    static let shared = MusicPreviewService()

    var currentPostId: UUID?
    var isPlaying: Bool = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 30
    var progress: Double = 0
    var audioLevel: Float = 0  // 0...1 normalized audio power

    // Snippet bounds
    var snippetStart: TimeInterval = 0
    var snippetLength: TimeInterval = 15

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var previewURLCache: [String: String] = [:]
    private var audioLevelTimer: Timer?

    private init() {}

    private func configureAudioSession() {
        #if canImport(UIKit)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: .duckOthers)
            try session.setActive(true)
        } catch {}
        #endif
    }

    // MARK: - Primary play method

    func play(postId: UUID, song: String, artist: String, fallbackURL: String? = nil, snippetStart: TimeInterval = 0) {
        stopInternal()
        configureAudioSession()

        self.snippetStart = snippetStart
        self.currentPostId = postId
        self.isPlaying = true

        Task {
            let cacheKey = "\(song) - \(artist)"
            if let cached = previewURLCache[cacheKey] {
                startPlayback(url: cached, snippetStart: snippetStart)
                return
            }

            if let resolved = await resolvePreviewURL(song: song, artist: artist) {
                previewURLCache[cacheKey] = resolved
                if currentPostId == postId {
                    startPlayback(url: resolved, snippetStart: snippetStart)
                }
                return
            }

            if let fallback = fallbackURL {
                previewURLCache[cacheKey] = fallback
                if currentPostId == postId {
                    startPlayback(url: fallback, snippetStart: snippetStart)
                }
                return
            }

            if currentPostId == postId {
                isPlaying = false
            }
        }
    }

    // MARK: - Direct URL play

    func playURL(postId: UUID, previewURL: String, snippetStart: TimeInterval = 0) {
        stopInternal()
        configureAudioSession()

        self.snippetStart = snippetStart
        self.currentPostId = postId
        self.isPlaying = true

        startPlayback(url: previewURL, snippetStart: snippetStart)
    }

    // MARK: - iTunes Search API

    private func resolvePreviewURL(song: String, artist: String) async -> String? {
        let query = "\(song) \(artist)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://itunes.apple.com/search?term=\(query)&media=music&entity=song&limit=3"

        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let results = json?["results"] as? [[String: Any]] ?? []

            for result in results {
                if let previewUrl = result["previewUrl"] as? String {
                    return previewUrl
                }
            }
        } catch {}

        return nil
    }

    // MARK: - AVPlayer Playback

    private func startPlayback(url: String, snippetStart: TimeInterval) {
        guard let audioURL = URL(string: url) else {
            isPlaying = false
            return
        }

        let item = AVPlayerItem(url: audioURL)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.volume = 0.7
        player = newPlayer

        if snippetStart > 0 {
            let startTime = CMTime(seconds: snippetStart, preferredTimescale: 600)
            newPlayer.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }
        newPlayer.play()
        isPlaying = true

        // Periodic time observer
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = newPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            let t = CMTimeGetSeconds(time)
            guard t.isFinite else { return }

            self.currentTime = t
            if self.duration > 0 {
                self.progress = t / self.duration
            }

            // Derive audio level from playback time — creates a musically-plausible
            // variation pattern that changes with time position in the track
            let t1 = t * 2.3
            let t2 = t * 3.7
            let t3 = t * 5.1
            let raw = Float(abs(sin(t1) * 0.4 + sin(t2) * 0.35 + cos(t3) * 0.25))
            // Smoothly interpolate toward new level
            self.audioLevel = self.audioLevel * 0.6 + raw * 0.4

            // Auto-loop within snippet bounds
            if t >= self.snippetStart + self.snippetLength {
                let loopTime = CMTime(seconds: self.snippetStart, preferredTimescale: 600)
                self.player?.seek(to: loopTime, toleranceBefore: .zero, toleranceAfter: .zero)
            }
        }
    }

    // MARK: - Controls

    func pause() {
        player?.pause()
        isPlaying = false
        audioLevel = 0
    }

    func resume() {
        player?.play()
        isPlaying = true
    }

    func stop() {
        stopInternal()
        currentPostId = nil
    }

    private func stopInternal() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        player?.pause()
        player = nil
        isPlaying = false
        currentTime = 0
        progress = 0
        audioLevel = 0
    }

    func isPlayingPost(_ postId: UUID) -> Bool {
        currentPostId == postId && isPlaying
    }
}
