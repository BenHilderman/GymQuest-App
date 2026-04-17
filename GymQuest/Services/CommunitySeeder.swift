import Foundation
import SwiftData

/// Seeds the community surfaces (ClubsShelf, CrewRecapCard, check-in tiles)
/// so every social feature has content on first launch. Runs once per
/// profile (guarded by a UserDefaults flag).
@MainActor
enum CommunitySeeder {

    static func seedIfNeeded(modelContext: ModelContext, profile: UserProfile) {
        let key = "communitySeeder_v1_\(profile.id.uuidString)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        let fakes = SocialSeeder.fakeUsers
        let cal = Calendar.current
        let now = Date()

        // 1) Seed two clubs with the user and a few friends as members.
        let club1 = Club(
            name: "The ARC — Queen's University",
            clubDescription: "Official campus gym crew",
            location: "Kingston, ON",
            creatorId: fakes[0].id,
            adminIds: [fakes[0].id],
            memberIds: [profile.id, fakes[0].id, fakes[1].id, fakes[2].id, fakes[3].id],
            joinType: .open,
            memberCount: 5,
            isVerified: true,
            tags: ["university", "gym"],
            lastActivityDate: now,
            isListedInDiscovery: true
        )
        let club2 = Club(
            name: "Early AM Grinders",
            clubDescription: "5am or bust",
            creatorId: fakes[4].id,
            adminIds: [fakes[4].id],
            memberIds: [profile.id, fakes[4].id, fakes[5].id],
            joinType: .open,
            memberCount: 3,
            tags: ["morning", "discipline"],
            lastActivityDate: cal.date(byAdding: .day, value: -1, to: now),
            isListedInDiscovery: true
        )
        modelContext.insert(club1)
        modelContext.insert(club2)

        // 2) Seed check-ins from fake users (powers the crew recap).
        let types = ["Push", "Pull", "Legs", "Cardio", "Full Body"]
        let notes = ["Felt strong", "Tough but fine", "Best session in a while", nil, nil]
        for (i, fake) in fakes.prefix(5).enumerated() {
            let dayOffset = -(i + 1)
            guard let date = cal.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let checkIn = WorkoutCheckIn(
                userId: fake.id,
                userName: fake.name,
                userUsername: fake.username,
                workoutType: types[i % types.count],
                durationMinutes: Int.random(in: 35...70),
                note: notes[i % notes.count],
                timestamp: date
            )
            modelContext.insert(checkIn)
        }

        // 3) Seed last-week workouts for the user (so CrewRecapCard shows
        //    "You're in for X" with real data). These supplements the posts
        //    already seeded by SocialSeeder.
        let today = cal.startOfDay(for: now)
        let weekday = cal.component(.weekday, from: today)
        let daysSinceMonday = (weekday + 5) % 7
        let thisMonday = cal.date(byAdding: .day, value: -daysSinceMonday, to: today)!
        let lastMonday = cal.date(byAdding: .day, value: -7, to: thisMonday)!

        let lastWeekWorkoutTypes: [WorkoutType] = [.push, .pull, .legs]
        for (i, type) in lastWeekWorkoutTypes.enumerated() {
            guard let date = cal.date(byAdding: .day, value: i, to: lastMonday) else { continue }
            let workout = Workout(date: date, type: type, duration: Int.random(in: 45...65))
            modelContext.insert(workout)
        }

        try? modelContext.save()
    }
}
