import Foundation

/// Snapshot of the user's crew's training cadence over a rolling window.
/// Replaces the personal-streak framing with a "we're in it together"
/// framing — the most important single UX shift for the community feel.
struct CrewRhythm {
    /// Days in the window (typically 7 for "this week").
    let totalDaysTracked: Int
    /// Distinct days any crew member (user + followed users) trained.
    let daysTrainedByCrew: Int
    /// Distinct days the current user trained.
    let userDaysTrained: Int
    /// One entry per day (oldest → newest). Value is the count of distinct
    /// crew members who trained that day (user included). Powers the
    /// 7-dot rhythm bar in the UI.
    let perDayCrewCount: [Int]
    /// Most consistent member in the window (excluding self), for the
    /// "Sarah is on 3 straight" call-out.
    let topMember: (name: String, username: String, daysTrained: Int)?
    /// Crew members who trained *today* alongside the user — powers the
    /// "duo day" callout.
    let todayCompanions: [(name: String, username: String)]
}

@MainActor
enum CrewRhythmService {

    /// Computes the rhythm snapshot. Uses local Workout records for the
    /// user and Post records (by author + day) as a proxy for followed
    /// members' training days — until real cross-user workout sync exists.
    static func weekRhythm(
        selfId: UUID,
        myWorkouts: [Workout],
        friendPosts: [Post],           // all posts authored by followed users
        follows: [Friend],
        profileLookup: [UUID: UserProfile] = [:],
        now: Date = Date()
    ) -> CrewRhythm {
        let cal = Calendar.current
        let startOfWindow = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now)) ?? now
        let totalDays = 7

        // Build a per-day set of crew members who trained.
        var trainedByDay: [Date: Set<UUID>] = [:]
        for offset in 0..<totalDays {
            let day = cal.date(byAdding: .day, value: offset, to: startOfWindow) ?? now
            trainedByDay[cal.startOfDay(for: day)] = []
        }

        // User: real workout data.
        for workout in myWorkouts where workout.date >= startOfWindow {
            let key = cal.startOfDay(for: workout.date)
            trainedByDay[key, default: []].insert(selfId)
        }

        // Followed users: proxy via posts (one post on a day ⇒ they trained).
        let followedIds = Set(follows.filter { $0.userId == selfId }.map(\.odId))
        for post in friendPosts where post.timestamp >= startOfWindow && followedIds.contains(post.authorId) {
            let key = cal.startOfDay(for: post.timestamp)
            trainedByDay[key, default: []].insert(post.authorId)
        }

        // Rolled counts per day, ordered oldest → newest.
        let perDayCrewCount: [Int] = (0..<totalDays).map { offset in
            let day = cal.date(byAdding: .day, value: offset, to: startOfWindow) ?? now
            return trainedByDay[cal.startOfDay(for: day)]?.count ?? 0
        }

        let daysTrainedByCrew = trainedByDay.values.filter { !$0.isEmpty }.count

        let userDays = trainedByDay.values.filter { $0.contains(selfId) }.count

        // Friend who trained the most distinct days in the window.
        var daysByFriend: [UUID: Int] = [:]
        for members in trainedByDay.values {
            for id in members where id != selfId {
                daysByFriend[id, default: 0] += 1
            }
        }
        let top = daysByFriend.max { $0.value < $1.value }
        let topMember: (name: String, username: String, daysTrained: Int)? = {
            guard let top else { return nil }
            let profile = profileLookup[top.key]
            let follow = follows.first(where: { $0.odId == top.key })
            let name = profile?.name ?? follow?.odName ?? "A friend"
            let username = profile?.username ?? follow?.odUsername ?? ""
            return (name, username, top.value)
        }()

        // Duo day callout.
        let today = cal.startOfDay(for: now)
        let todayCrew = trainedByDay[today] ?? []
        let companions: [(name: String, username: String)] = todayCrew
            .filter { $0 != selfId }
            .compactMap { id in
                let profile = profileLookup[id]
                let follow = follows.first(where: { $0.odId == id })
                let name = profile?.name ?? follow?.odName ?? "A friend"
                let username = profile?.username ?? follow?.odUsername ?? ""
                return (name, username)
            }

        return CrewRhythm(
            totalDaysTracked: totalDays,
            daysTrainedByCrew: daysTrainedByCrew,
            userDaysTrained: userDays,
            perDayCrewCount: perDayCrewCount,
            topMember: topMember,
            todayCompanions: companions
        )
    }
}
