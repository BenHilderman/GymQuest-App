//
//  AlbumArtService.swift
//  GymQuest
//
//  Fetches album artwork URLs from the iTunes Search API.
//

import Foundation

actor AlbumArtService {
    static let shared = AlbumArtService()

    private var cache: [String: URL] = [:]
    private var inFlight: [String: Task<URL?, Never>] = [:]

    func artworkURL(song: String, artist: String) async -> URL? {
        let key = "\(song)|\(artist)"

        if let cached = cache[key] {
            return cached
        }

        if let existing = inFlight[key] {
            return await existing.value
        }

        let task = Task<URL?, Never> {
            guard let query = "\(song) \(artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "https://itunes.apple.com/search?term=\(query)&media=music&limit=1") else {
                return nil
            }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let results = json?["results"] as? [[String: Any]]
                if let artworkString = results?.first?["artworkUrl100"] as? String {
                    // Get higher res: replace 100x100 with 300x300
                    let hiRes = artworkString.replacingOccurrences(of: "100x100", with: "300x300")
                    return URL(string: hiRes)
                }
            } catch {
                // Fail silently — fallback to placeholder
            }
            return nil
        }

        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil

        if let result {
            cache[key] = result
        }
        return result
    }
}
