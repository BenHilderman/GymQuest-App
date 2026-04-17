import Foundation
import SwiftData

/// Reads/writes per-user presence. Phase 8A is local-only — future phase
/// will sync through Supabase presence channels so real friends can light
/// up live. The public API is designed so swapping the backing store later
/// (keep SwiftData cache + stream from server) is a one-file change.
@MainActor
enum PresenceService {

    // MARK: - Public API

    /// Broadcast that the current user just started a workout. Updates the
    /// single UserPresenceState record for this user (creating it if the
    /// user has never been in one before).
    static func setTraining(
        userId: UUID,
        workoutType: String?,
        in modelContext: ModelContext,
        startedAt: Date = Date()
    ) {
        upsert(userId: userId, in: modelContext) { state in
            state.status = .training
            state.workoutTypeRaw = workoutType
            state.startedAt = startedAt
            state.updatedAt = Date()
        }
    }

    static func setResting(userId: UUID, in modelContext: ModelContext) {
        upsert(userId: userId, in: modelContext) { state in
            state.status = .resting
            state.updatedAt = Date()
        }
    }

    /// Mark workout done. Keeps the record in `.done` for a window so peers
    /// see a subtle "just finished" cue; later transitions to `.idle`.
    static func setDone(userId: UUID, in modelContext: ModelContext) {
        upsert(userId: userId, in: modelContext) { state in
            state.status = .done
            state.updatedAt = Date()
            // Keep startedAt for "trained 47 min" summary rendering.
        }
    }

    static func setIdle(userId: UUID, in modelContext: ModelContext) {
        upsert(userId: userId, in: modelContext) { state in
            state.status = .idle
            state.startedAt = nil
            state.updatedAt = Date()
        }
    }

    // MARK: - Queries

    /// Filter a candidate list of presence records down to the ones the
    /// current user actually cares about (themselves + people they follow)
    /// that are currently training or resting.
    static func liveNow(
        from all: [UserPresenceState],
        selfId: UUID,
        followedIds: Set<UUID>,
        now: Date = Date()
    ) -> [UserPresenceState] {
        let audience = followedIds.union([selfId])
        return all.filter { state in
            guard audience.contains(state.userId) else { return false }
            guard state.status == .training || state.status == .resting else { return false }
            // Stale records guard: if a session has been "training" for more
            // than 3 hours, the app was probably killed. Treat as stale.
            if let started = state.startedAt,
               now.timeIntervalSince(started) > 3 * 3600 {
                return false
            }
            return true
        }
        .sorted { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) }
    }

    /// Just-finished workouts (last 10 min) — cue for crew to send a reaction.
    static func justFinished(
        from all: [UserPresenceState],
        followedIds: Set<UUID>,
        now: Date = Date()
    ) -> [UserPresenceState] {
        let window: TimeInterval = 10 * 60
        return all.filter { state in
            guard followedIds.contains(state.userId) else { return false }
            guard state.status == .done else { return false }
            return now.timeIntervalSince(state.updatedAt) <= window
        }
    }

    // MARK: - Private

    private static func upsert(
        userId: UUID,
        in modelContext: ModelContext,
        mutate: (UserPresenceState) -> Void
    ) {
        let descriptor = FetchDescriptor<UserPresenceState>(
            predicate: #Predicate { $0.userId == userId }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            mutate(existing)
        } else {
            let fresh = UserPresenceState(userId: userId)
            mutate(fresh)
            modelContext.insert(fresh)
        }
        try? modelContext.save()
    }
}
