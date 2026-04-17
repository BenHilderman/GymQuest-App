import Foundation
import SwiftData

/// Infers whether the user is on Explore in lean-forward (Train) or lean-back
/// (Watch) mode. The visible toggle on ExploreView overrides for the session.
@MainActor
final class IntentInferenceService: ObservableObject {

    static let shared = IntentInferenceService()

    /// Session-sticky override set by the toggle pill. `nil` = use inferred.
    @Published var sessionOverride: ExploreIntent?

    private init() {}

    /// Resolve the current intent. If the user has explicitly toggled this
    /// session, that wins. Otherwise infer from time-of-day and recent
    /// workout activity.
    func currentIntent(recentWorkouts: [Workout], now: Date = Date()) -> ExploreIntent {
        if let override = sessionOverride { return override }
        return inferred(recentWorkouts: recentWorkouts, now: now)
    }

    /// Pure inference function. Exposed for tests.
    func inferred(recentWorkouts: [Workout], now: Date = Date()) -> ExploreIntent {
        // 1. Recent workout in last 4 hours → likely actively training, lean Train.
        let fourHoursAgo = now.addingTimeInterval(-4 * 3600)
        if recentWorkouts.contains(where: { $0.date >= fourHoursAgo }) {
            return .train
        }

        // 2. Time of day. Late evening (after 9pm) and very early morning are
        //    couch-leaning hours; gym hours (5-8am, 11am-1pm, 4-8pm) are Train.
        let hour = Calendar.current.component(.hour, from: now)
        switch hour {
        case 21..., 0..<5:
            return .watch
        case 5..<9, 11..<14, 16..<21:
            return .train
        default:
            return tieBreaker(workouts: recentWorkouts, now: now)
        }
    }

    /// Tie-breaker for ambiguous hours. Defaults to Train — the app's
    /// front-door identity is action, not entertainment, so when there's
    /// no clear signal we lean toward the workout-focused shelves.
    private func tieBreaker(workouts: [Workout], now: Date) -> ExploreIntent {
        return .train
    }

    /// Toggle override from the UI. Pass `nil` to clear and re-infer.
    func setOverride(_ intent: ExploreIntent?) {
        sessionOverride = intent
    }
}
