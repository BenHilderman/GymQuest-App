import Foundation
import SwiftData

/// Thin SwiftData wrapper for SavedWorkout CRUD. Keeps view code free of
/// fetch descriptors and predicate boilerplate.
@MainActor
enum SavedWorkoutService {

    static func isSaved(postId: UUID, userId: UUID, in saves: [SavedWorkout]) -> Bool {
        saves.contains { $0.postId == postId && $0.userId == userId }
    }

    static func toggle(
        postId: UUID,
        userId: UUID,
        collection: SavedCollection,
        in modelContext: ModelContext,
        existing: [SavedWorkout]
    ) {
        if let match = existing.first(where: { $0.postId == postId && $0.userId == userId }) {
            modelContext.delete(match)
        } else {
            let saved = SavedWorkout(userId: userId, postId: postId, collection: collection)
            modelContext.insert(saved)
        }
        try? modelContext.save()
    }
}
