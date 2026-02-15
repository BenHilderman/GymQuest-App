import Foundation

// MARK: - Workout Party Models

struct PartyMember: Identifiable {
    let id: UUID
    let name: String
    let username: String
    var currentExercise: String
    var completedSets: Int
    var totalSets: Int

    var avatarInitial: String {
        String(name.prefix(1))
    }
}

struct LiveCheer: Identifiable {
    let id = UUID()
    let emoji: String
    let senderName: String
    let timestamp: Date

    /// Random horizontal offset for floating animation
    let xOffset: CGFloat

    init(emoji: String, senderName: String) {
        self.emoji = emoji
        self.senderName = senderName
        self.timestamp = Date()
        self.xOffset = CGFloat.random(in: -30...30)
    }
}

struct LiveActivityEvent: Identifiable {
    let id = UUID()
    let text: String
    let timestamp: Date

    init(text: String) {
        self.text = text
        self.timestamp = Date()
    }
}

struct HypeMessage: Identifiable {
    let id = UUID()
    let text: String
    let senderName: String
    let timestamp: Date

    init(text: String, senderName: String) {
        self.text = text
        self.senderName = senderName
        self.timestamp = Date()
    }
}

enum QuickHype: String, CaseIterable {
    case letsGo = "Let's go!"
    case beastMode = "Beast mode!"
    case oneMore = "One more!"
    case prIncoming = "PR incoming!"
    case niceSet = "Nice set!"
    case crushIt = "Crush it!"
}
