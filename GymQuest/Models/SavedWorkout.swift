import Foundation
import SwiftData

/// User-saved post. Two implicit collections:
///   .train — workouts the user wants to run later (a "playlist")
///   .watch — clips the user wants to view later (a "watch later")
/// `customCollectionName` is reserved for Phase 2 (user-named playlists).
enum SavedCollection: String, Codable, CaseIterable {
    case train
    case watch
    case custom
}

@Model
final class SavedWorkout {
    var id: UUID
    var userId: UUID
    var postId: UUID
    var collectionRaw: String
    var customCollectionName: String?
    var note: String?
    var savedAt: Date
    var lastViewedAt: Date?

    init(
        id: UUID = UUID(),
        userId: UUID,
        postId: UUID,
        collection: SavedCollection,
        customCollectionName: String? = nil,
        note: String? = nil,
        savedAt: Date = Date(),
        lastViewedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.postId = postId
        self.collectionRaw = collection.rawValue
        self.customCollectionName = customCollectionName
        self.note = note
        self.savedAt = savedAt
        self.lastViewedAt = lastViewedAt
    }

    var collection: SavedCollection {
        get { SavedCollection(rawValue: collectionRaw) ?? .train }
        set { collectionRaw = newValue.rawValue }
    }
}
