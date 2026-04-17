import Foundation
import SwiftData

/// Lightweight "what are you doing right now" signal. One record per user;
/// updated when they start/stop a workout. Drives the LiveNowStrip and the
/// green-dot avatar overlays that make the app feel like a group workout
/// instead of a solo log.
enum PresenceStatus: String, Codable, CaseIterable {
    case idle        // not training
    case training    // actively in a workout
    case resting     // between sets
    case done        // finished recently (last 10 min) — cue for crew support
}

@Model
final class UserPresenceState {
    @Attribute(.unique) var userId: UUID
    var statusRaw: String
    var workoutTypeRaw: String?
    var startedAt: Date?
    var updatedAt: Date

    init(
        userId: UUID,
        status: PresenceStatus = .idle,
        workoutType: String? = nil,
        startedAt: Date? = nil,
        updatedAt: Date = Date()
    ) {
        self.userId = userId
        self.statusRaw = status.rawValue
        self.workoutTypeRaw = workoutType
        self.startedAt = startedAt
        self.updatedAt = updatedAt
    }

    var status: PresenceStatus {
        get { PresenceStatus(rawValue: statusRaw) ?? .idle }
        set { statusRaw = newValue.rawValue }
    }

    /// Minutes elapsed since the current workout started. Rendered as
    /// "22 min in" under a live avatar.
    var minutesIn: Int {
        guard status == .training || status == .resting, let start = startedAt else { return 0 }
        return max(0, Int(Date().timeIntervalSince(start) / 60))
    }
}
