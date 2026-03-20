import Foundation
import SwiftData

// MARK: - Premium Feature

enum PremiumFeature: String {
    case aiCoach
    case advancedAnalytics
    case customTemplates
    case formStudio
}

// MARK: - Paywall Trigger

enum PaywallTrigger: String {
    case featureTap
    case thirdWorkout
    case firstPR
    case firstWeekComplete
}

// MARK: - Premium Gate Service (System 10)

@MainActor
final class PremiumGateService: ObservableObject {
    static let shared = PremiumGateService()

    @Published var hasShownPaywallThisSession: Bool = false

    private var modelContext: ModelContext?

    private init() {}

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Access Check

    /// Returns true if the user can access the given premium feature.
    /// Grants access when: premium subscriber, within free trial, or feature flags override gates.
    func canAccess(_ feature: PremiumFeature, userId: UUID) -> Bool {
        // Feature flags override: when premium gate is disabled, all features accessible
        if !FeatureFlags.shared.premiumGateEnabled {
            return true
        }

        // Check subscription status
        if SubscriptionService.shared.isPremium {
            return true
        }

        // Check user profile for premium or active trial
        guard let profile = fetchProfile(userId: userId) else { return false }

        if profile.isPremium {
            return true
        }

        // Grace period: all features unlocked during first 3 workouts
        if profile.freeTrialWorkoutsRemaining > 0 {
            return true
        }

        return false
    }

    // MARK: - Paywall Display Logic

    /// Determines whether the paywall should be shown for the given trigger.
    /// Respects: once-per-session limit, never before first workout, never during active workout.
    /// - Parameter isWorkoutActive: Pass `appState.isWorkoutActive` from the calling view.
    func shouldShowPaywall(userId: UUID, trigger: PaywallTrigger, isWorkoutActive: Bool = false) -> Bool {
        // Never show more than once per session
        if hasShownPaywallThisSession {
            return false
        }

        // Already premium — no paywall needed
        if SubscriptionService.shared.isPremium {
            return false
        }

        if !FeatureFlags.shared.premiumGateEnabled {
            return false
        }

        guard let profile = fetchProfile(userId: userId) else { return false }

        if profile.isPremium {
            return false
        }

        // Never before first workout (trial starts at 3, so if still at 3, no workouts done)
        if profile.freeTrialWorkoutsRemaining >= 3 {
            return false
        }

        // Never interrupt an active workout
        if isWorkoutActive {
            return false
        }

        // Trigger-specific logic
        switch trigger {
        case .featureTap:
            // Always show on premium feature tap (subject to above guards)
            return true
        case .thirdWorkout:
            // Soft prompt at 3rd workout (trial remaining == 0 means 3 workouts done)
            return profile.freeTrialWorkoutsRemaining == 0
        case .firstPR:
            return true
        case .firstWeekComplete:
            return true
        }
    }

    // MARK: - Paywall Tracking

    /// Records that the paywall was shown. Updates session flag and user profile.
    func recordPaywallShown(userId: UUID) {
        hasShownPaywallThisSession = true

        guard let profile = fetchProfile(userId: userId) else { return }
        profile.lastPaywallShownDate = Date()
        profile.paywallDismissCount += 1
        saveContext()
    }

    // MARK: - Free Trial

    /// Decrements the free trial counter on workout completion. Call once per finished workout.
    func decrementFreeTrial(userId: UUID) {
        guard let profile = fetchProfile(userId: userId) else { return }

        if profile.freeTrialWorkoutsRemaining > 0 {
            profile.freeTrialWorkoutsRemaining -= 1
            saveContext()
        }
    }

    // MARK: - Private Helpers

    private func fetchProfile(userId: UUID) -> UserProfile? {
        guard let modelContext else { return nil }

        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate<UserProfile> { $0.id == userId }
        )

        return try? modelContext.fetch(descriptor).first
    }

    private func saveContext() {
        guard let modelContext else { return }
        try? modelContext.save()
    }
}
