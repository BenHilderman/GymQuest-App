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
import MediaPlayer

// MARK: - Music Source

enum MusicSource: String, CaseIterable, Codable {
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

struct Song: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let artist: String
    let albumArtURL: String?
    let previewURL: String?
    let source: MusicSource
    let playlistId: String?
    let spotifyURL: String?
    let appleMusicURL: String?

    var albumArt: URL? {
        albumArtURL.flatMap { URL(string: $0) }
    }

    init(
        id: String = UUID().uuidString,
        title: String,
        artist: String,
        albumArt: URL? = nil,
        previewURL: URL? = nil,
        source: MusicSource = .manual,
        playlistId: String? = nil,
        spotifyURL: String? = nil,
        appleMusicURL: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.albumArtURL = albumArt?.absoluteString
        self.previewURL = previewURL?.absoluteString
        self.source = source
        self.playlistId = playlistId
        self.spotifyURL = spotifyURL
        self.appleMusicURL = appleMusicURL
    }
}

// MARK: - Playlist Model

struct MusicPlaylist: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let ownerName: String?
    let trackCount: Int
    let imageURL: String?
    let source: MusicSource
    let externalURL: String?

    var image: URL? {
        imageURL.flatMap { URL(string: $0) }
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
    @Published var recentPlaylists: [MusicPlaylist] = []

    private let recentSongsKey = "LiftAI.recentSongs"
    private let recentPlaylistsKey = "LiftAI.recentPlaylists"

    private init() {
        loadRecentSongs()
        loadRecentPlaylists()
        generateAISuggestions()
        checkAppleMusicAuthorization()
    }

    // MARK: - Connection Status

    private func checkAppleMusicAuthorization() {
        #if canImport(MusicKit)
        Task {
            let status = MusicAuthorization.currentStatus
            await MainActor.run {
                isAppleMusicConnected = status == .authorized
            }
        }
        #endif
    }

    func connectSpotify() {
        // Spotify requires OAuth with client credentials
        // Users can paste Spotify URLs directly without full OAuth
        // Full OAuth would require registering an app at developer.spotify.com
        isSpotifyConnected = true
    }

    func connectAppleMusic() async {
        #if canImport(MusicKit)
        let status = await MusicAuthorization.request()
        await MainActor.run {
            isAppleMusicConnected = status == .authorized
        }
        #endif
    }

    // MARK: - Song Search

    func searchSongs(query: String) async -> [Song] {
        guard !query.isEmpty else { return [] }

        var results: [Song] = []

        // Search Apple Music if authorized
        #if canImport(MusicKit)
        if isAppleMusicConnected {
            let appleMusicResults = await searchAppleMusic(query: query)
            results.append(contentsOf: appleMusicResults)
        }
        #endif

        // If no results from Apple Music, return curated workout songs
        if results.isEmpty {
            results = getWorkoutSongsMatching(query: query)
        }

        return results
    }

    #if canImport(MusicKit)
    private func searchAppleMusic(query: String) async -> [Song] {
        do {
            var request = MusicCatalogSearchRequest(term: query, types: [MusicKit.Song.self])
            request.limit = 10
            let response = try await request.response()

            return response.songs.map { song in
                Song(
                    id: song.id.rawValue,
                    title: song.title,
                    artist: song.artistName,
                    albumArt: song.artwork?.url(width: 300, height: 300),
                    previewURL: song.previewAssets?.first?.url,
                    source: .appleMusic,
                    appleMusicURL: song.url?.absoluteString
                )
            }
        } catch {
            print("Apple Music search error: \(error)")
            return []
        }
    }
    #endif

    private func getWorkoutSongsMatching(query: String) -> [Song] {
        let workoutSongs = [
            Song(title: "Eye of the Tiger", artist: "Survivor", source: .manual),
            Song(title: "Stronger", artist: "Kanye West", source: .manual),
            Song(title: "Lose Yourself", artist: "Eminem", source: .manual),
            Song(title: "Till I Collapse", artist: "Eminem", source: .manual),
            Song(title: "Can't Hold Us", artist: "Macklemore", source: .manual),
            Song(title: "Power", artist: "Kanye West", source: .manual),
            Song(title: "Remember The Name", artist: "Fort Minor", source: .manual),
            Song(title: "Run Boy Run", artist: "Woodkid", source: .manual),
            Song(title: "Blinding Lights", artist: "The Weeknd", source: .manual),
            Song(title: "Don't Stop Me Now", artist: "Queen", source: .manual),
            Song(title: "Thunderstruck", artist: "AC/DC", source: .manual),
            Song(title: "Pump It", artist: "Black Eyed Peas", source: .manual),
            Song(title: "Work Out", artist: "J. Cole", source: .manual),
            Song(title: "Levels", artist: "Avicii", source: .manual),
            Song(title: "Titanium", artist: "David Guetta", source: .manual)
        ]

        return workoutSongs.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.artist.localizedCaseInsensitiveContains(query)
        }
    }

    // MARK: - Playlist Search

    func searchPlaylists(query: String) async -> [MusicPlaylist] {
        guard !query.isEmpty else { return [] }

        #if canImport(MusicKit)
        if isAppleMusicConnected {
            return await searchAppleMusicPlaylists(query: query)
        }
        #endif

        return []
    }

    #if canImport(MusicKit)
    private func searchAppleMusicPlaylists(query: String) async -> [MusicPlaylist] {
        do {
            var request = MusicCatalogSearchRequest(term: query, types: [Playlist.self])
            request.limit = 10
            let response = try await request.response()

            return response.playlists.map { playlist in
                MusicPlaylist(
                    id: playlist.id.rawValue,
                    name: playlist.name,
                    ownerName: playlist.curatorName,
                    trackCount: playlist.tracks?.count ?? 0,
                    imageURL: playlist.artwork?.url(width: 300, height: 300)?.absoluteString,
                    source: .appleMusic,
                    externalURL: playlist.url?.absoluteString
                )
            }
        } catch {
            print("Apple Music playlist search error: \(error)")
            return []
        }
    }
    #endif

    // MARK: - AI Suggestions

    func generateAISuggestions(for activityType: String? = nil) {
        // Generate workout-appropriate song suggestions based on activity
        let workoutSongs: [Song]

        // Songs with real iTunes album art and 30s preview URLs
        let loseYourself = Song(title: "Lose Yourself", artist: "Eminem", albumArt: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/08/23/fc/0823fcd9-cb44-695b-32bf-b3bf51d9f800/00606949351229.rgb.jpg/300x300bb.jpg"), previewURL: URL(string: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview125/v4/53/82/26/53822699-a05f-8fd1-e498-1a5e4e498695/mzaf_13223030825880804498.plus.aac.p.m4a"), source: .aiSuggestion)
        let tillICollapse = Song(title: "Till I Collapse", artist: "Eminem", albumArt: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/08/23/fc/0823fcd9-cb44-695b-32bf-b3bf51d9f800/00606949351229.rgb.jpg/300x300bb.jpg"), previewURL: URL(string: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview115/v4/1e/3f/e4/1e3fe4d8-02e1-69e1-db3a-e18ce4a6bbbc/mzaf_14301754578498079498.plus.aac.p.m4a"), source: .aiSuggestion)
        let power = Song(title: "Power", artist: "Kanye West", albumArt: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/c2/5d/86/c25d8658-6598-8dd5-ea0e-c5351ebe51e2/8fa68e79-a8ee-4460-bf14-2bf109a421fc.jpg/300x300bb.jpg"), source: .aiSuggestion)
        let stronger = Song(title: "Stronger", artist: "Kanye West", albumArt: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Music128/v4/39/25/2d/39252d65-2d50-b991-0962-f7a98a761271/00602517483507.rgb.jpg/300x300bb.jpg"), source: .aiSuggestion)
        let eyeOfTheTiger = Song(title: "Eye of the Tiger", artist: "Survivor", albumArt: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/f9/02/8f/f9028f63-7a55-235e-f789-1e8946430fa2/614223201122.jpg/300x300bb.jpg"), source: .aiSuggestion)
        let blindingLights = Song(title: "Blinding Lights", artist: "The Weeknd", albumArt: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/a6/6e/bf/a66ebf79-5008-8948-b352-a790fc87446b/19UM1IM04638.rgb.jpg/300x300bb.jpg"), previewURL: URL(string: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview122/v4/63/67/0b/63670b6d-0712-4fbc-c07b-7615a2e7836e/mzaf_6682622363498498562.plus.aac.p.m4a"), source: .aiSuggestion)
        let humble = Song(title: "HUMBLE.", artist: "Kendrick Lamar", albumArt: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Music112/v4/ab/16/ef/ab16efe9-e7f1-66ec-021c-5592a23f0f9e/17UMGIM88793.rgb.jpg/300x300bb.jpg"), source: .aiSuggestion)
        let sickoMode = Song(title: "SICKO MODE", artist: "Travis Scott", albumArt: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/e7/49/8f/e7498f65-df8f-bead-d6e3-2a8d4d642a79/886447235317.jpg/300x300bb.jpg"), source: .aiSuggestion)
        let levitating = Song(title: "Levitating", artist: "Dua Lipa", albumArt: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/6c/11/d6/6c11d681-aa3a-d59e-4c2e-f77e181026ab/190295092665.jpg/300x300bb.jpg"), source: .aiSuggestion)
        let starboy = Song(title: "Starboy", artist: "The Weeknd", albumArt: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/b5/92/bb/b592bb72-52e3-e756-9b26-9f56d08f47ab/16UMGIM67864.rgb.jpg/300x300bb.jpg"), source: .aiSuggestion)

        switch activityType?.lowercased() {
        case "weightlifting", "weights", "push", "pull", "legs", "upper", "lower":
            workoutSongs = [loseYourself, tillICollapse, power, humble, stronger]
        case "running", "cardio":
            workoutSongs = [blindingLights, eyeOfTheTiger, levitating, starboy, sickoMode]
        case "yoga", "stretching":
            workoutSongs = [
                Song(title: "Weightless", artist: "Marconi Union", source: .aiSuggestion),
                Song(title: "Clair de Lune", artist: "Debussy", source: .aiSuggestion),
                Song(title: "Sunset Lover", artist: "Petit Biscuit", source: .aiSuggestion),
                Song(title: "Intro", artist: "The xx", source: .aiSuggestion),
                Song(title: "Breathe", artist: "Télépopmusik", source: .aiSuggestion)
            ]
        default:
            workoutSongs = [eyeOfTheTiger, stronger, loseYourself, blindingLights, sickoMode]
        }

        suggestedSongs = workoutSongs
    }

    // MARK: - Recent Songs

    private func loadRecentSongs() {
        if let data = UserDefaults.standard.data(forKey: recentSongsKey),
           let songs = try? JSONDecoder().decode([Song].self, from: data) {
            recentSongs = songs
        } else {
            // Default workout songs for new users
            recentSongs = [
                Song(title: "Lose Yourself", artist: "Eminem", source: .manual),
                Song(title: "Blinding Lights", artist: "The Weeknd", source: .manual),
                Song(title: "Levitating", artist: "Dua Lipa", source: .manual)
            ]
        }
    }

    private func saveRecentSongs() {
        if let data = try? JSONEncoder().encode(recentSongs) {
            UserDefaults.standard.set(data, forKey: recentSongsKey)
        }
    }

    func addToRecent(_ song: Song) {
        recentSongs.removeAll { $0.id == song.id }
        recentSongs.insert(song, at: 0)
        if recentSongs.count > 10 {
            recentSongs = Array(recentSongs.prefix(10))
        }
        saveRecentSongs()
    }

    // MARK: - Recent Playlists

    private func loadRecentPlaylists() {
        if let data = UserDefaults.standard.data(forKey: recentPlaylistsKey),
           let playlists = try? JSONDecoder().decode([MusicPlaylist].self, from: data) {
            recentPlaylists = playlists
        }
    }

    private func saveRecentPlaylists() {
        if let data = try? JSONEncoder().encode(recentPlaylists) {
            UserDefaults.standard.set(data, forKey: recentPlaylistsKey)
        }
    }

    func addToRecentPlaylists(_ playlist: MusicPlaylist) {
        recentPlaylists.removeAll { $0.id == playlist.id }
        recentPlaylists.insert(playlist, at: 0)
        if recentPlaylists.count > 10 {
            recentPlaylists = Array(recentPlaylists.prefix(10))
        }
        saveRecentPlaylists()
    }

    // MARK: - Now Playing Detection

    func detectNowPlaying() async -> Song? {
        // Try Apple Music / Music app first
        #if canImport(MusicKit)
        if isAppleMusicConnected {
            if let song = await detectAppleMusicNowPlaying() {
                return song
            }
        }
        #endif

        // Try system now playing info (works with any music app)
        return detectSystemNowPlaying()
    }

    #if canImport(MusicKit)
    private func detectAppleMusicNowPlaying() async -> Song? {
        // MusicKit doesn't directly provide "now playing" but we can use ApplicationMusicPlayer
        let player = ApplicationMusicPlayer.shared
        guard let nowPlayingItem = player.queue.currentEntry else { return nil }

        // Extract song info from the queue entry
        if case .song(let song) = nowPlayingItem.item {
            return Song(
                id: song.id.rawValue,
                title: song.title,
                artist: song.artistName,
                albumArt: song.artwork?.url(width: 300, height: 300),
                source: .appleMusic,
                appleMusicURL: song.url?.absoluteString
            )
        }

        return nil
    }
    #endif

    private func detectSystemNowPlaying() -> Song? {
        // Use MPNowPlayingInfoCenter to get currently playing media
        let nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo

        guard let title = nowPlayingInfo?[MPMediaItemPropertyTitle] as? String,
              let artist = nowPlayingInfo?[MPMediaItemPropertyArtist] as? String else {
            return nil
        }

        return Song(
            title: title,
            artist: artist,
            source: .manual
        )
    }

    // MARK: - URL Parsing

    /// Parse a Spotify URL to extract track/playlist info
    func parseSpotifyURL(_ urlString: String) -> (type: String, id: String)? {
        // Spotify URLs: https://open.spotify.com/track/xxx or spotify:track:xxx
        // Also: https://open.spotify.com/playlist/xxx

        if urlString.contains("spotify.com") || urlString.starts(with: "spotify:") {
            let patterns = [
                "open.spotify.com/track/([a-zA-Z0-9]+)",
                "open.spotify.com/playlist/([a-zA-Z0-9]+)",
                "spotify:track:([a-zA-Z0-9]+)",
                "spotify:playlist:([a-zA-Z0-9]+)"
            ]

            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: urlString, range: NSRange(urlString.startIndex..., in: urlString)),
                   let idRange = Range(match.range(at: 1), in: urlString) {
                    let id = String(urlString[idRange])
                    let type = pattern.contains("playlist") ? "playlist" : "track"
                    return (type, id)
                }
            }
        }

        return nil
    }

    /// Parse an Apple Music URL
    func parseAppleMusicURL(_ urlString: String) -> (type: String, id: String)? {
        // Apple Music URLs: https://music.apple.com/us/album/song-name/123456789?i=123456789
        // Also: https://music.apple.com/us/playlist/name/pl.xxx

        if urlString.contains("music.apple.com") {
            if urlString.contains("/playlist/") {
                if let regex = try? NSRegularExpression(pattern: "/playlist/[^/]+/(pl\\.[a-zA-Z0-9]+)"),
                   let match = regex.firstMatch(in: urlString, range: NSRange(urlString.startIndex..., in: urlString)),
                   let idRange = Range(match.range(at: 1), in: urlString) {
                    return ("playlist", String(urlString[idRange]))
                }
            } else if urlString.contains("/album/") {
                // Song within album has ?i= parameter
                if let url = URL(string: urlString),
                   let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let songId = components.queryItems?.first(where: { $0.name == "i" })?.value {
                    return ("track", songId)
                }
            }
        }

        return nil
    }

    /// Create a Song from a pasted URL
    func songFromURL(_ urlString: String) -> Song? {
        if let spotify = parseSpotifyURL(urlString), spotify.type == "track" {
            return Song(
                id: spotify.id,
                title: "Spotify Track",
                artist: "Tap to play",
                source: .spotify,
                spotifyURL: urlString
            )
        }

        if let appleMusic = parseAppleMusicURL(urlString), appleMusic.type == "track" {
            return Song(
                id: appleMusic.id,
                title: "Apple Music Track",
                artist: "Tap to play",
                source: .appleMusic,
                appleMusicURL: urlString
            )
        }

        return nil
    }

    /// Create a Playlist from a pasted URL
    func playlistFromURL(_ urlString: String) -> MusicPlaylist? {
        if let spotify = parseSpotifyURL(urlString), spotify.type == "playlist" {
            return MusicPlaylist(
                id: spotify.id,
                name: "Spotify Playlist",
                ownerName: nil,
                trackCount: 0,
                imageURL: nil,
                source: .spotify,
                externalURL: urlString
            )
        }

        if let appleMusic = parseAppleMusicURL(urlString), appleMusic.type == "playlist" {
            return MusicPlaylist(
                id: appleMusic.id,
                name: "Apple Music Playlist",
                ownerName: nil,
                trackCount: 0,
                imageURL: nil,
                source: .appleMusic,
                externalURL: urlString
            )
        }

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
