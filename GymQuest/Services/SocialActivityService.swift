import SwiftUI

// MARK: - Simulated Friend Activity

struct SimulatedFriendActivity: Identifiable {
    let id: UUID
    let name: String
    let username: String
    let avatarInitial: String
    let workoutType: String
    let exercise: String
    let minutesElapsed: Int
    let isLive: Bool
}

// MARK: - Social Activity Service

@Observable
@MainActor
final class SocialActivityService {
    static let shared = SocialActivityService()

    var activeFriends: [SimulatedFriendActivity] = []
    var friendsActiveToday: Int = 0

    private init() {
        generateActivity()
    }

    private func generateActivity() {
        let users = SocialSeeder.fakeUsers
        let workoutTypes = ["Push", "Pull", "Legs", "Upper", "Cardio"]
        let exercises = [
            "Bench Press", "Barbell Rows", "Squats",
            "Overhead Press", "Treadmill Intervals"
        ]

        // Pick 4-5 random friends as active
        let shuffled = users.shuffled()
        let count = Int.random(in: 4...5)
        let selected = Array(shuffled.prefix(count))

        activeFriends = selected.enumerated().map { index, user in
            let isLive = index < 3 // first 3 are live
            return SimulatedFriendActivity(
                id: user.id,
                name: user.name.components(separatedBy: " ").first ?? user.name,
                username: user.username,
                avatarInitial: String(user.name.prefix(1)),
                workoutType: workoutTypes[index % workoutTypes.count],
                exercise: exercises[index % exercises.count],
                minutesElapsed: Int.random(in: 8...52),
                isLive: isLive
            )
        }

        friendsActiveToday = Int.random(in: 5...9)
    }

    var liveCount: Int {
        activeFriends.filter(\.isLive).count
    }

    var hasLiveFriends: Bool {
        activeFriends.contains(where: \.isLive)
    }
}
