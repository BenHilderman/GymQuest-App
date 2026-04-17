import Foundation

/// Per-clip dwell tracking for the vertical Scroll feed. Phase 4A keeps it
/// in-memory only; Phase 4B will feed `dwell(for:)` back into the ranker
/// (long-watch authors get a boost, sub-1s skips get a downrank).
@MainActor
final class WatchTimeTracker: ObservableObject {
    static let shared = WatchTimeTracker()
    private init() {}

    private struct Session {
        let postId: UUID
        let appearedAt: Date
    }

    /// The clip currently on screen. Closing it stops the timer; opening a
    /// new one auto-closes the prior so we never double-count.
    private var current: Session?

    /// Cumulative dwell in seconds, keyed by postId.
    private(set) var dwellByPost: [UUID: Double] = [:]

    func didAppear(_ postId: UUID, at now: Date = Date()) {
        if let c = current, c.postId != postId {
            close(c, at: now)
        }
        current = Session(postId: postId, appearedAt: now)
    }

    func didDisappear(_ postId: UUID, at now: Date = Date()) {
        if let c = current, c.postId == postId {
            close(c, at: now)
            current = nil
        }
    }

    func dwell(for postId: UUID) -> Double {
        dwellByPost[postId] ?? 0
    }

    func reset() {
        current = nil
        dwellByPost.removeAll()
    }

    private func close(_ session: Session, at now: Date) {
        let delta = max(0, now.timeIntervalSince(session.appearedAt))
        dwellByPost[session.postId, default: 0] += delta
    }
}
