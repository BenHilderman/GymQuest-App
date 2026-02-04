//
//  MusicService.swift
//  GymQuest
//
//  Music integration service for posts
//  Supports Spotify, Apple Music, and AI suggestions
//

import Foundation
import SwiftUI
#if canImport(MusicKit)
import MusicKit
#endif

// MARK: - Music Source

enum MusicSource: String, CaseIterable {
    case spotify = "Spotify"
    case appleMusic = "Apple Music"
    case aiSuggestion = "AI Suggested"
    case manual = "Manual"

    var icon: String {
        switch self {
        case .spotify: return "music.note"
        case .appleMusic: return "music.note.list"
        case .aiSuggestion: return "sparkles"
        case .manual: return "pencil"
        }
    }

    var color: Color {
        switch self {
        case .spotify: return Color(red: 0.12, green: 0.84, blue: 0.38)
        case .appleMusic: return Color(red: 0.98, green: 0.34, blue: 0.45)
        case .aiSuggestion: return GQColors.neonPurple
        case .manual: return GQColors.electricBlue
        }
    }
}

// MARK: - Song Model

struct Song: Identifiable, Hashable {
    let id: String
    let title: String
    let artist: String
    let albumArt: URL?
    let previewURL: URL?
    let source: MusicSource
    let playlistId: String?

    init(
        id: String = UUID().uuidString,
        title: String,
        artist: String,
        albumArt: URL? = nil,
        previewURL: URL? = nil,
        source: MusicSource = .manual,
        playlistId: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.albumArt = albumArt
        self.previewURL = previewURL
        self.source = source
        self.playlistId = playlistId
    }
}

// MARK: - Music Service

class MusicService: ObservableObject {
    static let shared = MusicService()

    @Published var isSpotifyConnected = false
    @Published var isAppleMusicConnected = false
    @Published var currentlyPlaying: Song?
    @Published var recentSongs: [Song] = []
    @Published var suggestedSongs: [Song] = []

    private init() {
        loadRecentSongs()
        generateAISuggestions()
    }

    // MARK: - Connection Status

    func connectSpotify() {
        // TODO: Implement Spotify OAuth flow
        // For now, simulate connection
        isSpotifyConnected = true
    }

    func connectAppleMusic() async {
        #if canImport(MusicKit)
        let status = await MusicAuthorization.request()
        isAppleMusicConnected = status == .authorized
        #endif
    }

    // MARK: - Song Search

    func searchSongs(query: String) async -> [Song] {
        // TODO: Implement actual search via Spotify/Apple Music APIs
        // For now, return mock results
        guard !query.isEmpty else { return [] }

        return [
            Song(title: "Eye of the Tiger", artist: "Survivor", source: .manual),
            Song(title: "Stronger", artist: "Kanye West", source: .manual),
            Song(title: "Lose Yourself", artist: "Eminem", source: .manual),
            Song(title: "Till I Collapse", artist: "Eminem", source: .manual),
            Song(title: "Can't Hold Us", artist: "Macklemore", source: .manual)
        ].filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.artist.localizedCaseInsensitiveContains(query)
        }
    }

    // MARK: - AI Suggestions

    func generateAISuggestions(for activityType: String? = nil) {
        // Generate workout-appropriate song suggestions based on activity
        let workoutSongs: [Song]

        switch activityType?.lowercased() {
        case "weightlifting", "weights":
            workoutSongs = [
                Song(title: "Lose Yourself", artist: "Eminem", source: .aiSuggestion),
                Song(title: "Till I Collapse", artist: "Eminem", source: .aiSuggestion),
                Song(title: "Power", artist: "Kanye West", source: .aiSuggestion),
                Song(title: "Remember The Name", artist: "Fort Minor", source: .aiSuggestion),
                Song(title: "Stronger", artist: "Kanye West", source: .aiSuggestion)
            ]
        case "running":
            workoutSongs = [
                Song(title: "Run Boy Run", artist: "Woodkid", source: .aiSuggestion),
                Song(title: "Eye of the Tiger", artist: "Survivor", source: .aiSuggestion),
                Song(title: "Can't Hold Us", artist: "Macklemore", source: .aiSuggestion),
                Song(title: "Blinding Lights", artist: "The Weeknd", source: .aiSuggestion),
                Song(title: "Don't Stop Me Now", artist: "Queen", source: .aiSuggestion)
            ]
        case "yoga":
            workoutSongs = [
                Song(title: "Weightless", artist: "Marconi Union", source: .aiSuggestion),
                Song(title: "Clair de Lune", artist: "Debussy", source: .aiSuggestion),
                Song(title: "Sunset Lover", artist: "Petit Biscuit", source: .aiSuggestion),
                Song(title: "Intro", artist: "The xx", source: .aiSuggestion),
                Song(title: "Breathe", artist: "Télépopmusik", source: .aiSuggestion)
            ]
        case "cycling":
            workoutSongs = [
                Song(title: "Sandstorm", artist: "Darude", source: .aiSuggestion),
                Song(title: "Levels", artist: "Avicii", source: .aiSuggestion),
                Song(title: "Wake Me Up", artist: "Avicii", source: .aiSuggestion),
                Song(title: "Titanium", artist: "David Guetta", source: .aiSuggestion),
                Song(title: "Animals", artist: "Martin Garrix", source: .aiSuggestion)
            ]
        default:
            workoutSongs = [
                Song(title: "Eye of the Tiger", artist: "Survivor", source: .aiSuggestion),
                Song(title: "Stronger", artist: "Kanye West", source: .aiSuggestion),
                Song(title: "Work Out", artist: "J. Cole", source: .aiSuggestion),
                Song(title: "Pump It", artist: "Black Eyed Peas", source: .aiSuggestion),
                Song(title: "Thunderstruck", artist: "AC/DC", source: .aiSuggestion)
            ]
        }

        suggestedSongs = workoutSongs
    }

    // MARK: - Recent Songs

    private func loadRecentSongs() {
        // Load from UserDefaults or local storage
        // For now, mock data
        recentSongs = [
            Song(title: "Lose Yourself", artist: "Eminem", source: .manual),
            Song(title: "Blinding Lights", artist: "The Weeknd", source: .manual),
            Song(title: "Levitating", artist: "Dua Lipa", source: .manual)
        ]
    }

    func addToRecent(_ song: Song) {
        recentSongs.removeAll { $0.id == song.id }
        recentSongs.insert(song, at: 0)
        if recentSongs.count > 10 {
            recentSongs = Array(recentSongs.prefix(10))
        }
        // TODO: Persist to UserDefaults
    }

    // MARK: - Now Playing Detection

    func detectNowPlaying() async -> Song? {
        #if canImport(MusicKit)
        // Try to get currently playing from Apple Music
        // This requires proper MusicKit setup
        #endif

        // For now, return nil
        return nil
    }
}

// MARK: - Activity Detection Service

class ActivityDetectionService {
    static let shared = ActivityDetectionService()

    private init() {}

    /// Detect activity type from image using Vision framework
    func detectActivity(from imageData: Data) async -> DetectedActivity? {
        #if canImport(UIKit)
        guard let image = UIImage(data: imageData),
              let cgImage = image.cgImage else { return nil }

        // TODO: Implement actual Vision framework image classification
        // For now, use simple keyword-based detection from any text/labels

        // Mock implementation - in production, use VNClassifyImageRequest
        // or a custom ML model trained on workout images
        return nil
        #else
        return nil
        #endif
    }

    /// Detect activity from caption text
    func detectActivityFromText(_ text: String) -> DetectedActivity? {
        let lowercased = text.lowercased()

        for activity in DetectedActivity.allCases {
            for keyword in activity.keywords {
                if lowercased.contains(keyword) {
                    return activity
                }
            }
        }

        return nil
    }

    /// Combined detection from image and text
    func detectActivity(imageData: Data?, caption: String) async -> DetectedActivity? {
        // First try text detection (faster)
        if let textDetected = detectActivityFromText(caption) {
            return textDetected
        }

        // Then try image detection if available
        if let data = imageData {
            return await detectActivity(from: data)
        }

        return nil
    }
}
