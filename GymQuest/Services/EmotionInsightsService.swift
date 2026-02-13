import Foundation

struct EmotionDistribution: Identifiable {
    let id = UUID()
    let emotion: WorkoutEmotion
    let count: Int
}

struct EmotionInsights {
    let distribution: [EmotionDistribution]
    let resilienceStreak: Int
    let encouragementMessage: String
    let dominantEmotion: WorkoutEmotion?
    let totalPostsWithEmotion: Int
}

@MainActor
final class EmotionInsightsService {
    static let shared = EmotionInsightsService()
    private init() {}

    func computeInsights(from posts: [Post], periodDays: Int = 30) -> EmotionInsights? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -periodDays, to: Date()) ?? Date()
        let recentPosts = posts
            .filter { $0.timestamp >= cutoff && $0.emotion != nil }
            .sorted { $0.timestamp > $1.timestamp }

        guard !recentPosts.isEmpty else { return nil }

        // Distribution
        var counts: [WorkoutEmotion: Int] = [:]
        for post in recentPosts {
            if let emotion = post.emotion {
                counts[emotion, default: 0] += 1
            }
        }
        let distribution = counts
            .map { EmotionDistribution(emotion: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }

        // Resilience streak: consecutive recent posts with resilient emotions
        var streak = 0
        for post in recentPosts {
            if post.emotion?.sentimentCategory == .resilient {
                streak += 1
            } else {
                break
            }
        }

        // Dominant emotion
        let dominant = distribution.first?.emotion

        // Encouragement message
        let message = buildEncouragement(
            distribution: counts,
            streak: streak,
            total: recentPosts.count
        )

        return EmotionInsights(
            distribution: distribution,
            resilienceStreak: streak,
            encouragementMessage: message,
            dominantEmotion: dominant,
            totalPostsWithEmotion: recentPosts.count
        )
    }

    private func buildEncouragement(
        distribution: [WorkoutEmotion: Int],
        streak: Int,
        total: Int
    ) -> String {
        if streak >= 3 {
            return "Showing up when you don't want to is the whole game."
        }

        let resilientCount = distribution
            .filter { $0.key.sentimentCategory == .resilient }
            .values.reduce(0, +)

        if resilientCount > 0 && total > 0 {
            let ratio = Double(resilientCount) / Double(total)
            if ratio >= 0.5 {
                return "You keep showing up through the tough days. That's real strength."
            }
        }

        if let top = distribution.max(by: { $0.value < $1.value })?.key {
            switch top {
            case .fired: return "That fire is carrying you far."
            case .strong: return "Strength on repeat. Keep building."
            case .grateful: return "Gratitude and gains — powerful combo."
            case .calm: return "Calm focus is an underrated superpower."
            case .grinding: return "The grind never lies. Keep pushing."
            case .dragging: return "The hardest rep is showing up. You're doing it."
            case .anxious: return "You chose to move through it. That matters."
            case .comeback: return "Every comeback starts with one workout."
            }
        }

        return "Your consistency speaks louder than any single workout."
    }
}
