import SwiftUI

// MARK: - Workout Party Service

@Observable
@MainActor
final class WorkoutPartyService {

    // MARK: - Published State

    private(set) var partyMembers: [PartyMember] = []
    private(set) var activeReactions: [LiveCheer] = []
    private(set) var activityEvents: [LiveActivityEvent] = []
    private(set) var activeHypeBanner: HypeMessage?

    var isActive: Bool { !partyMembers.isEmpty }

    // MARK: - Timers

    private var progressTimer: Timer?
    private var cheerTimer: Timer?
    private var activityTimer: Timer?
    private var hypeTimer: Timer?

    // MARK: - Data Sources

    private let partyFriends: [(id: UUID, name: String, username: String)]
    private let exerciseNames = [
        "Bench Press", "Squat", "Deadlift", "Overhead Press", "Barbell Row",
        "Pull Up", "Dumbbell Curl", "Lat Pulldown", "Leg Press", "Romanian Deadlift",
        "Incline Bench Press", "Dumbbell Press", "Cable Row", "Lateral Raise",
        "Tricep Pushdown", "Leg Extension", "Hamstring Curl", "Face Pull"
    ]

    private let cheerEmojis = ["🔥", "💪", "👊", "⭐", "💯", "👏"]

    private let hypeTexts = QuickHype.allCases.map(\.rawValue)

    // MARK: - Lifecycle

    init() {
        // Pick 3 random friends from SocialSeeder
        let allFriends = SocialSeeder.fakeUsers
        partyFriends = Array(allFriends.shuffled().prefix(3))
    }

    func startParty() {
        guard partyMembers.isEmpty else { return }

        // Initialize 3 party members with random exercises
        partyMembers = partyFriends.map { friend in
            PartyMember(
                id: friend.id,
                name: friend.name,
                username: friend.username,
                currentExercise: exerciseNames.randomElement() ?? "Bench Press",
                completedSets: Int.random(in: 1...2),
                totalSets: Int.random(in: 3...5)
            )
        }

        // Seed initial activity event
        if let member = partyMembers.first {
            activityEvents.append(LiveActivityEvent(text: "\(member.name) started working out"))
        }

        startTimers()
    }

    func stopParty() {
        invalidateTimers()
        withAnimation(.easeOut(duration: 0.3)) {
            partyMembers = []
            activeReactions = []
            activityEvents = []
            activeHypeBanner = nil
        }
    }

    // MARK: - User Actions

    func sendReaction(_ emoji: String) {
        let cheer = LiveCheer(emoji: emoji, senderName: "You")
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            activeReactions.append(cheer)
        }
        trimReactions()

        // Auto-remove after 3 seconds
        let cheerId = cheer.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            withAnimation(.easeOut(duration: 0.5)) {
                self?.activeReactions.removeAll { $0.id == cheerId }
            }
        }
    }

    func sendHype(_ hype: QuickHype) {
        // Show as outgoing activity event
        let event = LiveActivityEvent(text: "You sent \"\(hype.rawValue)\"")
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            activityEvents.insert(event, at: 0)
        }
        trimActivityEvents()
    }

    // MARK: - Timers

    private func startTimers() {
        // Progress updates: every 4-6 seconds
        scheduleProgressTimer()

        // Cheers: every 20-40 seconds
        scheduleCheerTimer()

        // Activity events: every 8-15 seconds
        scheduleActivityTimer()

        // Hype messages: every 30-60 seconds
        scheduleHypeTimer()
    }

    private func invalidateTimers() {
        progressTimer?.invalidate()
        cheerTimer?.invalidate()
        activityTimer?.invalidate()
        hypeTimer?.invalidate()
        progressTimer = nil
        cheerTimer = nil
        activityTimer = nil
        hypeTimer = nil
    }

    // MARK: - Progress Timer

    private func scheduleProgressTimer() {
        let interval = Double.random(in: 4...6)
        progressTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateProgress()
                self?.scheduleProgressTimer()
            }
        }
    }

    private func updateProgress() {
        guard !partyMembers.isEmpty else { return }
        let index = Int.random(in: 0..<partyMembers.count)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            partyMembers[index].completedSets += 1

            // If they finished all sets, start a new exercise
            if partyMembers[index].completedSets >= partyMembers[index].totalSets {
                let newExercise = exerciseNames.randomElement() ?? "Bench Press"
                partyMembers[index].currentExercise = newExercise
                partyMembers[index].completedSets = 0
                partyMembers[index].totalSets = Int.random(in: 3...5)
            }
        }
    }

    // MARK: - Cheer Timer

    private func scheduleCheerTimer() {
        let interval = Double.random(in: 20...40)
        cheerTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.simulateCheer()
                self?.scheduleCheerTimer()
            }
        }
    }

    private func simulateCheer() {
        guard let member = partyMembers.randomElement() else { return }
        let emoji = cheerEmojis.randomElement() ?? "🔥"
        let cheer = LiveCheer(emoji: emoji, senderName: member.name.components(separatedBy: " ").first ?? member.name)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            activeReactions.append(cheer)
        }
        trimReactions()

        // Auto-remove after 3 seconds
        let cheerId = cheer.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            withAnimation(.easeOut(duration: 0.5)) {
                self?.activeReactions.removeAll { $0.id == cheerId }
            }
        }
    }

    // MARK: - Activity Timer

    private func scheduleActivityTimer() {
        let interval = Double.random(in: 8...15)
        activityTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.simulateActivityEvent()
                self?.scheduleActivityTimer()
            }
        }
    }

    private func simulateActivityEvent() {
        guard let member = partyMembers.randomElement() else { return }
        let firstName = member.name.components(separatedBy: " ").first ?? member.name

        let templates: [String] = [
            "\(firstName) finished \(member.currentExercise) \(member.totalSets)x8",
            "\(firstName) hit a new PR! 🏆",
            "\(firstName) is resting (45s)",
            "\(firstName) started \(exerciseNames.randomElement() ?? "Bench Press")",
            "\(firstName) completed set \(member.completedSets)/\(member.totalSets)",
            "\(firstName) is crushing it 💪",
        ]

        let text = templates.randomElement() ?? "\(firstName) is working hard"
        let event = LiveActivityEvent(text: text)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            activityEvents.insert(event, at: 0)
        }
        trimActivityEvents()
    }

    // MARK: - Hype Timer

    private func scheduleHypeTimer() {
        let interval = Double.random(in: 30...60)
        hypeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.simulateHypeMessage()
                self?.scheduleHypeTimer()
            }
        }
    }

    private func simulateHypeMessage() {
        guard let member = partyMembers.randomElement() else { return }
        let firstName = member.name.components(separatedBy: " ").first ?? member.name
        let text = hypeTexts.randomElement() ?? "Let's go!"

        let message = HypeMessage(text: text, senderName: firstName)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            activeHypeBanner = message
        }

        // Auto-dismiss after 2.5 seconds
        let messageId = message.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            if self?.activeHypeBanner?.id == messageId {
                withAnimation(.easeOut(duration: 0.3)) {
                    self?.activeHypeBanner = nil
                }
            }
        }
    }

    // MARK: - Housekeeping

    private func trimReactions() {
        if activeReactions.count > 6 {
            activeReactions.removeFirst(activeReactions.count - 6)
        }
    }

    private func trimActivityEvents() {
        // Keep max 4 events
        if activityEvents.count > 4 {
            activityEvents = Array(activityEvents.prefix(4))
        }
        // Remove events older than 60 seconds
        let cutoff = Date().addingTimeInterval(-60)
        activityEvents.removeAll { $0.timestamp < cutoff }
    }
}
