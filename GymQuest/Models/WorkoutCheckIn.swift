import Foundation
import SwiftData

/// Lightweight "I just trained" signal. Cheaper to produce than a full Post
/// — one-line status, optional note — and renders as a compact tile in
/// feeds. Powers the "feel like we're training together" vibe because
/// everyone posts check-ins but not everyone writes full posts.
@Model
final class WorkoutCheckIn {
    var id: UUID
    var userId: UUID
    var userName: String
    var userUsername: String
    var workoutType: String           // e.g. "Push", "Legs", "Cardio"
    var durationMinutes: Int
    var note: String?                 // optional 1-liner
    var timestamp: Date
    /// Comma-joined list of friends the user trained alongside. Read-only
    /// for now; future phase can offer tag-a-friend at check-in time.
    var withFriends: String

    init(
        id: UUID = UUID(),
        userId: UUID,
        userName: String,
        userUsername: String,
        workoutType: String,
        durationMinutes: Int,
        note: String? = nil,
        timestamp: Date = Date(),
        withFriends: String = ""
    ) {
        self.id = id
        self.userId = userId
        self.userName = userName
        self.userUsername = userUsername
        self.workoutType = workoutType
        self.durationMinutes = durationMinutes
        self.note = note
        self.timestamp = timestamp
        self.withFriends = withFriends
    }
}
