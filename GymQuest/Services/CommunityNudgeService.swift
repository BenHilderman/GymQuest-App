import Foundation

/// A single motivational nudge surfaced at the top of Explore. Never
/// punitive — always anchored in a specific person so it reads as "your
/// crew is here" instead of "you're falling behind."
enum CommunityNudge: Identifiable, Equatable {
    /// Your crew hit N more training days than you this week.
    case crewAhead(daysBehind: Int, exampleFriend: String)
    /// A friend just finished their workout — prime time to send support.
    case justFinished(friendName: String, workoutType: String, userId: UUID)
    /// You and a friend both trained today — positive reinforcement.
    case duoDay(friendName: String)
    /// A friend on a streak — celebratory framing, tap to cheer.
    case friendOnStreak(friendName: String, days: Int)

    var id: String {
        switch self {
        case .crewAhead(let days, let name): return "crewAhead-\(days)-\(name)"
        case .justFinished(_, _, let uid): return "justFinished-\(uid.uuidString)"
        case .duoDay(let name): return "duoDay-\(name)"
        case .friendOnStreak(let name, let days): return "friendOnStreak-\(name)-\(days)"
        }
    }

    var title: String {
        switch self {
        case .crewAhead(let days, _):
            return "Your crew is \(days) day\(days == 1 ? "" : "s") ahead this week"
        case .justFinished(let name, let type, _):
            return "\(name) just finished \(type.lowercased())"
        case .duoDay(let name):
            return "You and \(name) trained today ✨"
        case .friendOnStreak(let name, let days):
            return "\(name) is on a \(days)-day streak"
        }
    }

    var body: String {
        switch self {
        case .crewAhead(_, let example):
            return "\(example) trained today — keep the rhythm"
        case .justFinished:
            return "Drop a quick 💪 — they'll feel it instantly"
        case .duoDay:
            return "Aligned training day. That's the stuff"
        case .friendOnStreak:
            return "Match the energy, tap to cheer"
        }
    }

    var actionLabel: String {
        switch self {
        case .crewAhead: return "Start workout"
        case .justFinished, .friendOnStreak: return "Send 💪"
        case .duoDay: return "High-five"
        }
    }
}

@MainActor
enum CommunityNudgeService {

    /// Evaluates all rules and returns ordered nudges, most-actionable first.
    /// Dismissed IDs (from the banner's dismiss button) suppress for the
    /// current session.
    static func nudges(
        rhythm: CrewRhythm,
        justFinishedStates: [UserPresenceState],
        profileLookup: [UUID: UserProfile],
        dismissedIds: Set<String>,
        now: Date = Date()
    ) -> [CommunityNudge] {
        var result: [CommunityNudge] = []

        // 1. Just-finished — highest priority because time window is short.
        for state in justFinishedStates.prefix(2) {
            let name = profileLookup[state.userId]?.name ?? "A friend"
            let type = (state.workoutTypeRaw ?? "workout").capitalized
            result.append(.justFinished(friendName: name, workoutType: type, userId: state.userId))
        }

        // 2. Duo day — positive reinforcement.
        if let companion = rhythm.todayCompanions.first {
            result.append(.duoDay(friendName: companion.name))
        }

        // 3. Friend on streak — celebratory.
        if let top = rhythm.topMember, top.daysTrained >= 3 {
            result.append(.friendOnStreak(friendName: top.name, days: top.daysTrained))
        }

        // 4. Crew ahead — gentle gap awareness. Only when user is behind
        //    by at least 2 days so we don't nag on minor gaps.
        let gap = rhythm.daysTrainedByCrew - rhythm.userDaysTrained
        if gap >= 2, let exampleFriend = rhythm.topMember?.name {
            result.append(.crewAhead(daysBehind: gap, exampleFriend: exampleFriend))
        }

        return result.filter { !dismissedIds.contains($0.id) }
    }
}
