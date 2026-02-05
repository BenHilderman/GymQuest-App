//
//  FormVideoPlayerView.swift
//  GymQuest
//
//  AVKit video player wrapper for Form Studio.
//

import SwiftUI
import AVKit

struct FormVideoPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer
    var showsPlaybackControls: Bool = true

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = player
        vc.showsPlaybackControls = showsPlaybackControls
        vc.videoGravity = .resizeAspect
        vc.allowsPictureInPicturePlayback = false
        return vc
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
        uiViewController.showsPlaybackControls = showsPlaybackControls
    }
}

// MARK: - Player Time Observer

class PlayerTimeObserver: ObservableObject {
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isPlaying: Bool = false

    private var timeObserver: Any?
    private var player: AVPlayer?

    func observe(_ player: AVPlayer) {
        self.player = player
        removeObserver()

        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.currentTime = time.seconds

            if let duration = player.currentItem?.duration.seconds, duration.isFinite {
                self?.duration = duration
            }

            self?.isPlaying = player.rate > 0
        }
    }

    func removeObserver() {
        if let observer = timeObserver, let player = player {
            player.removeTimeObserver(observer)
        }
        timeObserver = nil
    }

    deinit {
        removeObserver()
    }
}

// MARK: - Looping Player

class LoopingPlayerManager: ObservableObject {
    @Published var player: AVPlayer

    private var loopObserver: NSObjectProtocol?

    init(url: URL) {
        self.player = AVPlayer(url: url)
        setupLooping()
    }

    func setupLooping() {
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.player.seek(to: .zero)
            self?.player.play()
        }
    }

    func replaceURL(_ url: URL) {
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        setupLooping()
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    deinit {
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
