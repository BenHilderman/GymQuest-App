//
//  ExerciseGifService.swift
//  GymQuest
//
//  Loads the bundled exercisedb_mapping.json and provides
//  local GIF file URLs for exercises from the app bundle.
//

import Foundation

@MainActor
final class ExerciseGifService {
    static let shared = ExerciseGifService()

    private var mappings: [String: String] = [:]          // exact-case lookup
    private var lowercaseMappings: [String: String] = [:]  // case-insensitive fallback

    private init() {
        loadMappings()
    }

    // MARK: - Public API

    /// Returns the local bundle URL for this exercise's animated GIF, or nil if unavailable.
    func gifURL(for exerciseName: String) -> URL? {
        guard let id = exerciseDbId(for: exerciseName) else { return nil }
        return Bundle.main.url(forResource: id, withExtension: "gif")
    }

    /// Whether a bundled GIF exists for this exercise name.
    func hasGif(for exerciseName: String) -> Bool {
        gifURL(for: exerciseName) != nil
    }

    // MARK: - Private

    private func exerciseDbId(for name: String) -> String? {
        mappings[name] ?? lowercaseMappings[name.lowercased()]
    }

    private func loadMappings() {
        guard let url = Bundle.main.url(forResource: "exercisedb_mapping", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            #if DEBUG
            print("[ExerciseGifService] Failed to load exercisedb_mapping.json from bundle")
            #endif
            return
        }

        struct MappingFile: Decodable {
            let mappings: [String: String]
        }

        guard let file = try? JSONDecoder().decode(MappingFile.self, from: data) else {
            #if DEBUG
            print("[ExerciseGifService] Failed to decode exercisedb_mapping.json")
            #endif
            return
        }

        self.mappings = file.mappings
        self.lowercaseMappings = Dictionary(
            file.mappings.map { ($0.key.lowercased(), $0.value) },
            uniquingKeysWith: { first, _ in first }
        )

        #if DEBUG
        print("[ExerciseGifService] Loaded \(mappings.count) exercise GIF mappings")
        #endif
    }
}
