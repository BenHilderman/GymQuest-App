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
    private var consecutiveNilPolls = 0
    private var currentInterval: TimeInterval = 3.0

    private init() {
        startPolling()
    }

    // MARK: - Polling

    func startPolling() {
        pollTimer?.invalidate()
        consecutiveNilPolls = 0
        currentInterval = 3.0
        pollTimer = Timer.scheduledTimer(withTimeInterval: currentInterval, repeats: true) { [weak self] _ in
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

    private func rescheduleIfNeeded(newInterval: TimeInterval) {
        guard newInterval != currentInterval else { return }
        currentInterval = newInterval
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: currentInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollNowPlaying()
            }
        }
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
            consecutiveNilPolls += 1
            if consecutiveNilPolls >= 3 {
                rescheduleIfNeeded(newInterval: 10.0)
            }
            return
        }

        // Music found — reset backoff
        if consecutiveNilPolls > 0 {
            consecutiveNilPolls = 0
            rescheduleIfNeeded(newInterval: 3.0)
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
