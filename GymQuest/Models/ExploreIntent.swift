import Foundation

/// User intent on the Explore page. Watch is lean-back (entertainment); Train
/// is lean-forward (do a workout). Inferred by IntentInferenceService and may
/// be overridden by the visible toggle.
enum ExploreIntent: String, Codable, CaseIterable {
    case train
    case watch
}

/// Identifies which curated row a post is being scored for. Each shelf
/// reweights the underlying engagement/personalization signals differently
/// (Train shelves favor doability + recency; Watch shelves favor engagement +
/// novelty).
enum ExploreShelfKind: String, Codable, CaseIterable {
    case forTonight              // single Hero card
    case becauseYouTrained       // similar muscle group to last session
    case quickWins               // duration ≤ user's preferred * 0.6
    case watchTutorials          // high-engagement instructional clips
    case savedToDo               // user's saved playlist (.train collection)
    case savedToWatch            // user's watch later (.watch collection)
    case onTheCalendar           // matches the user's schedule for tomorrow / today
    case squadIsDoing            // dominant workout type among followed users this week
    case editorsPick             // top-quartile engagement × top-quartile doability
}
