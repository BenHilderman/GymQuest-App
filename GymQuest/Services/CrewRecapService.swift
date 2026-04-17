import Foundation

/// Retrospective summary of the previous 7 days for the user + their crew.
/// Designed to feel like a small event — rendered as a celebration card on
/// Today at the start of each week.
struct CrewWeeklyRecapData {
    let weekStartDate: Date      // Start of the Monday 7 days ago
    let weekEndDate: Date        // End of Sunday just passed
    let crewDaysTrained: Int     // 0-7 distinct days *any* crew member trained
    let userDaysTrained: Int     // 0-7 days the user trained
    let topMemberName: String?
    let topMemberDays: Int
    let duoDays: Int             // days user + any crew member both trained
    let totalCheckIns: Int       // sum of CheckIns across the crew
    let crewSize: Int            // follow count (to contextualize "4 of 5")

    /// Short celebratory one-liner rendered as the recap card headline.
    var headline: String {
        if crewDaysTrained == 7 {
            return "Perfect week — crew trained every single day"
        }
        if crewDaysTrained >= 5 {
            return "Strong week — \(crewDaysTrained) of 7 days covered"
        }
        if userDaysTrained > 0 && crewDaysTrained > userDaysTrained {
            return "Your crew pulled you forward this week"
        }
        if userDaysTrained > 0 {
            return "You showed up \(userDaysTrained) day\(userDaysTrained == 1 ? "" : "s") last week"
        }
        return "A quiet week — fresh start ahead"
    }
}

@MainActor
enum CrewRecapService {

    /// Compute the recap for the calendar week that just ended. Returns
    /// nil when there's no crew data yet (e.g. first install with no
    /// follows + no posts).
    static func lastWeekRecap(
        selfId: UUID,
        myWorkouts: [Workout],
        friendPosts: [Post],
        follows: [Friend],
        checkIns: [WorkoutCheckIn],
        profileLookup: [UUID: UserProfile] = [:],
        now: Date = Date()
    ) -> CrewWeeklyRecapData? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        // "Last week" window = 7 days ending at the most recent start-of-week.
        let weekday = cal.component(.weekday, from: today)   // 1 = Sun ... 7 = Sat
        // Rewind to Monday of this week (weekday Monday == 2).
        let daysSinceMonday = (weekday + 5) % 7   // 0 when Mon, 1 Tue, ..., 6 Sun
        guard let thisWeekMonday = cal.date(byAdding: .day, value: -daysSinceMonday, to: today) else { return nil }
        guard let lastWeekMonday = cal.date(byAdding: .day, value: -7, to: thisWeekMonday) else { return nil }
        guard let lastWeekSunday = cal.date(byAdding: .day, value: 6, to: lastWeekMonday) else { return nil }

        let followedIds = Set(follows.filter { $0.userId == selfId }.map(\.odId))

        // Trained days: union of crew member ids per day.
        var trainedByDay: [Date: Set<UUID>] = [:]

        for workout in myWorkouts where workout.date >= lastWeekMonday && workout.date <= cal.date(byAdding: .day, value: 1, to: lastWeekSunday)! {
            trainedByDay[cal.startOfDay(for: workout.date), default: []].insert(selfId)
        }

        for post in friendPosts where followedIds.contains(post.authorId) {
            guard post.timestamp >= lastWeekMonday,
                  post.timestamp <= cal.date(byAdding: .day, value: 1, to: lastWeekSunday)! else { continue }
            trainedByDay[cal.startOfDay(for: post.timestamp), default: []].insert(post.authorId)
        }

        let crewDays = trainedByDay.values.filter { !$0.isEmpty }.count
        let userDays = trainedByDay.values.filter { $0.contains(selfId) }.count

        // Duo days: user + at least one other crew member on the same day.
        let duoDays = trainedByDay.values.filter { $0.contains(selfId) && $0.count >= 2 }.count

        // Top member by distinct days (excluding self).
        var daysByFriend: [UUID: Int] = [:]
        for members in trainedByDay.values {
            for id in members where id != selfId {
                daysByFriend[id, default: 0] += 1
            }
        }
        let top = daysByFriend.max { $0.value < $1.value }
        let topName: String? = top.flatMap { entry in
            profileLookup[entry.key]?.name
                ?? follows.first(where: { $0.odId == entry.key })?.odName
        }

        let totalCheckIns = checkIns.filter { ci in
            (ci.userId == selfId || followedIds.contains(ci.userId))
            && ci.timestamp >= lastWeekMonday
            && ci.timestamp <= cal.date(byAdding: .day, value: 1, to: lastWeekSunday)!
        }.count

        // Empty-state guard — don't render a recap when nothing happened.
        if crewDays == 0 && totalCheckIns == 0 { return nil }

        return CrewWeeklyRecapData(
            weekStartDate: lastWeekMonday,
            weekEndDate: lastWeekSunday,
            crewDaysTrained: crewDays,
            userDaysTrained: userDays,
            topMemberName: topName,
            topMemberDays: top?.value ?? 0,
            duoDays: duoDays,
            totalCheckIns: totalCheckIns,
            crewSize: followedIds.count
        )
    }
}
