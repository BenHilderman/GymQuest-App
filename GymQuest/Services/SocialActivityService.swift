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
    let gymName: String?
    let gymArea: String?
    let gymCoordinate: (lat: Double, lng: Double)?
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

    private static let mockGyms: [(name: String, area: String, lat: Double, lng: Double)] = [
        ("The ARC - Queen's", "Kingston, ON", 44.2253, -76.4951),
        ("GoodLife Fitness Downtown", "Kingston, ON", 44.2312, -76.4860),
        ("Anytime Fitness", "Kingston, ON", 44.2384, -76.5012),
        ("Iron Works Gym", "Kingston, ON", 44.2298, -76.4783),
        ("CrossFit Kingston", "Kingston, ON", 44.2421, -76.5103),
    ]

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
            // ~70% of friends share gym location
            let sharesLocation = Double.random(in: 0...1) < 0.7
            let gym = sharesLocation ? Self.mockGyms.randomElement() : nil
            return SimulatedFriendActivity(
                id: user.id,
                name: user.name.components(separatedBy: " ").first ?? user.name,
                username: user.username,
                avatarInitial: String(user.name.prefix(1)),
                workoutType: workoutTypes[index % workoutTypes.count],
                exercise: exercises[index % exercises.count],
                minutesElapsed: Int.random(in: 8...52),
                isLive: isLive,
                gymName: gym?.name,
                gymArea: gym?.area,
                gymCoordinate: gym != nil ? (lat: gym!.lat, lng: gym!.lng) : nil
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
