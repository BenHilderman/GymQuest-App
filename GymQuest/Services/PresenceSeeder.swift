import Foundation
import SwiftData

/// Populates a few "live now" demo records so the LiveNowStrip is never
/// empty in the seeded demo. Runs on each Explore appearance because
/// presence is time-sensitive — stale seed data would show friends who've
/// been "training" for 6 hours. Real deployments replace this with the
/// Supabase presence channel.
@MainActor
enum PresenceSeeder {

    /// Writes fresh presence for a few fake users so the strip shows 2-3
    /// friends currently training. Idempotent — won't pile up records.
    static func refreshDemoPresence(in modelContext: ModelContext) {
        // Only seed for well-known fake users so we don't overwrite a real
        // user's genuine presence.
        let liveUsers = SocialSeeder.fakeUsers.prefix(3)
        let workoutTypes = ["Push", "Legs", "Pull"]

        // Fetch all presence rows once, then filter in memory. Much cleaner
        // than one predicate per user (which trips the macro on tuple binds).
        let descriptor = FetchDescriptor<UserPresenceState>()
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        let existingByUser = Dictionary(uniqueKeysWithValues: existing.map { ($0.userId, $0) })

        for (i, user) in liveUsers.enumerated() {
            let type = workoutTypes[i % workoutTypes.count]
            let startedAt = Date().addingTimeInterval(-Double(Int.random(in: 5...25) * 60))

            if let current = existingByUser[user.id] {
                // Only refresh records that look stale — keeps any real
                // training state intact during dev testing.
                if current.status != .training || isStale(current) {
                    current.status = .training
                    current.workoutTypeRaw = type
                    current.startedAt = startedAt
                    current.updatedAt = Date()
                }
            } else {
                let fresh = UserPresenceState(
                    userId: user.id,
                    status: .training,
                    workoutType: type,
                    startedAt: startedAt
                )
                modelContext.insert(fresh)
            }
        }
        try? modelContext.save()
    }

    private static func isStale(_ state: UserPresenceState) -> Bool {
        guard let start = state.startedAt else { return true }
        return Date().timeIntervalSince(start) > 45 * 60   // >45 min implies stale
    }
}
