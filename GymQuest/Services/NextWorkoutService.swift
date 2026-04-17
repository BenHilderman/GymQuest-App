import Foundation

/// What the user should train NEXT — not what they already did.
struct NextWorkoutRecommendation {
    let workoutType: String          // "Push", "Pull", "Legs", etc.
    let reason: String               // "Scheduled for tomorrow" or "Next in your split"
    let isForToday: Bool             // true = hasn't trained yet, this is for today
}

/// Determines the user's next logical session based on their schedule,
/// last workout, and standard split rotation.
@MainActor
enum NextWorkoutService {

    /// Standard PPL rotation fallback when no schedule is set.
    private static let splitOrder = ["Push", "Pull", "Legs", "Upper Body", "Full Body", "Cardio"]

    static func recommend(
        profile: UserProfile,
        recentWorkouts: [Workout],
        now: Date = Date()
    ) -> NextWorkoutRecommendation {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let trainedToday = recentWorkouts.contains { cal.isDate($0.date, inSameDayAs: now) }

        // Which day are we planning for?
        let targetDate = trainedToday
            ? (cal.date(byAdding: .day, value: 1, to: today) ?? today)
            : today
        let targetLabel = trainedToday ? "Tomorrow" : "Today"

        // 1. Check schedule (weeklySchedule + dayOverrides)
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let dayKey = fmt.string(from: targetDate)
        if let override = profile.dayOverrides[dayKey], !override.isEmpty {
            return NextWorkoutRecommendation(
                workoutType: override,
                reason: "Scheduled for \(targetLabel.lowercased())",
                isForToday: !trainedToday
            )
        }
        let weekday = cal.component(.weekday, from: targetDate)
        if let scheduled = profile.weeklySchedule[weekday], !scheduled.isEmpty {
            return NextWorkoutRecommendation(
                workoutType: scheduled,
                reason: "\(targetLabel) on your plan",
                isForToday: !trainedToday
            )
        }

        // 2. Fallback: next in split rotation based on last workout
        let lastType = recentWorkouts.first?.type.rawValue ?? "Push"
        let nextType = nextInSplit(after: lastType)
        let reason = trainedToday
            ? "Next in your split after \(lastType.lowercased())"
            : "Complements your last \(lastType.lowercased()) session"

        return NextWorkoutRecommendation(
            workoutType: nextType,
            reason: reason,
            isForToday: !trainedToday
        )
    }

    private static func nextInSplit(after lastType: String) -> String {
        guard let idx = splitOrder.firstIndex(where: { $0.lowercased() == lastType.lowercased() }) else {
            return splitOrder.first ?? "Push"
        }
        let next = (idx + 1) % splitOrder.count
        return splitOrder[next]
    }
}
