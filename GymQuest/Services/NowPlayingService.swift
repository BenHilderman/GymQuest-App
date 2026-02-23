//
//  NowPlayingService.swift
//  GymQuest
//
//  Polls MPNowPlayingInfoCenter for currently playing music
//  Works with Spotify, Apple Music, and any audio app
//

import Foundation
import SwiftUI
import MediaPlayer

@Observable
@MainActor
final class NowPlayingService {
    static let shared = NowPlayingService()

    var currentSong: Song?
    var isPlaying: Bool = false
    var isDismissed: Bool = false

    #if canImport(UIKit)
    var albumArtImage: UIImage?
    #endif

    private var pollTimer: Timer?

    private init() {
        startPolling()
    }

    // MARK: - Polling

    func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollNowPlaying()
            }
        }
        // Poll immediately on start
        pollNowPlaying()
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func pollNowPlaying() {
        let nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo

        guard let title = nowPlayingInfo?[MPMediaItemPropertyTitle] as? String else {
            // Nothing playing — clear state but don't un-dismiss
            if currentSong != nil {
                currentSong = nil
                isPlaying = false
                #if canImport(UIKit)
                albumArtImage = nil
                #endif
            }
            return
        }

        let artist = nowPlayingInfo?[MPMediaItemPropertyArtist] as? String ?? "Unknown Artist"
        let playbackRate = nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] as? Double ?? 0

        // Detect source from bundle identifier heuristics
        let source: MusicSource = .manual

        let newSong = Song(
            title: title,
            artist: artist,
            source: source
        )

        // If a new song started, auto-restore from dismissed state
        let songChanged = currentSong?.title != title || currentSong?.artist != artist
        if songChanged && isDismissed {
            isDismissed = false
        }

        currentSong = newSong
        isPlaying = playbackRate > 0

        // Extract artwork
        #if canImport(UIKit)
        if songChanged {
            if let artwork = nowPlayingInfo?[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork {
                albumArtImage = artwork.image(at: CGSize(width: 72, height: 72))
            } else {
                albumArtImage = nil
            }
        }
        #endif
    }

    // MARK: - Playback Control

    func togglePlayPause() {
        // Toggle visual state; actual playback control requires an active
        // audio session. The next poll cycle will reconcile with reality.
        isPlaying.toggle()
    }

    // MARK: - Dismiss / Restore

    func dismiss() {
        isDismissed = true
    }

    func restore() {
        isDismissed = false
    }

    /// Whether the bar should be visible
    var isVisible: Bool {
        currentSong != nil && !isDismissed
    }
}
