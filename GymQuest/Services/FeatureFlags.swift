//
//  FeatureFlags.swift
//  GymQuest
//
//  Feature flag system for controlling feature rollout.
//  All new features ship behind toggles for controlled rollout and demo mode support.
//

import Foundation
import SwiftUI

/// Central feature flag manager for GymQuest 2.0
/// All new features must be gated behind these flags
@MainActor
final class FeatureFlags: ObservableObject {
    static let shared = FeatureFlags()

    // MARK: - Feature Flags

    /// Learning content in feed and contextual learning panels
    @Published var learningFeedEnabled: Bool {
        didSet { save("learningFeedEnabled", value: learningFeedEnabled) }
    }

    /// Quest/RPG system with daily quests and rewards
    @Published var questsEnabled: Bool {
        didSet { save("questsEnabled", value: questsEnabled) }
    }

    /// Squad system for social accountability groups
    @Published var squadsEnabled: Bool {
        didSet { save("squadsEnabled", value: squadsEnabled) }
    }

    /// HealthKit workout import
    @Published var healthKitImportEnabled: Bool {
        didSet { save("healthKitImportEnabled", value: healthKitImportEnabled) }
    }

    /// Strava activity import — Removed
    @Published var stravaImportEnabled: Bool {
        didSet { save("stravaImportEnabled", value: stravaImportEnabled) }
    }

    /// WHOOP recovery/strain import — Removed
    @Published var whoopEnabled: Bool {
        didSet { save("whoopEnabled", value: whoopEnabled) }
    }

    /// Robot demo video generation
    @Published var robotDemosEnabled: Bool {
        didSet { save("robotDemosEnabled", value: robotDemosEnabled) }
    }

    /// Nutrition/meal logging
    @Published var nutritionEnabled: Bool {
        didSet { save("nutritionEnabled", value: nutritionEnabled) }
    }

    /// Enhanced PR detection and celebrations
    @Published var enhancedPREnabled: Bool {
        didSet { save("enhancedPREnabled", value: enhancedPREnabled) }
    }

    /// Shareable workout cards with templates
    @Published var workoutCardsEnabled: Bool {
        didSet { save("workoutCardsEnabled", value: workoutCardsEnabled) }
    }

    /// Weekly recap card generation
    @Published var weeklyRecapEnabled: Bool {
        didSet { save("weeklyRecapEnabled", value: weeklyRecapEnabled) }
    }

    /// Templates for quick workout logging
    @Published var templatesEnabled: Bool {
        didSet { save("templatesEnabled", value: templatesEnabled) }
    }

    /// "Repeat last workout" quick action
    @Published var repeatWorkoutEnabled: Bool {
        didSet { save("repeatWorkoutEnabled", value: repeatWorkoutEnabled) }
    }

    /// Workout Party: real-time social workout experience
    @Published var workoutPartyEnabled: Bool {
        didSet { save("workoutPartyEnabled", value: workoutPartyEnabled) }
    }

    /// Voice notes on posts and speech-to-text for meal logging
    @Published var voiceNotesEnabled: Bool {
        didSet { save("voiceNotesEnabled", value: voiceNotesEnabled) }
    }

    /// Gym location sharing with friends during workouts
    @Published var gymLocationSharing: Bool {
        didSet { save("gymLocationSharing", value: gymLocationSharing) }
    }

    /// Premium subscription features (AI workouts, advanced analytics, etc.)
    @Published var premiumEnabled: Bool {
        didSet { save("premiumEnabled", value: premiumEnabled) }
    }

    /// Animated exercise GIF demos from ExerciseDB
    @Published var exerciseGifsEnabled: Bool {
        didSet { save("exerciseGifsEnabled", value: exerciseGifsEnabled) }
    }

    /// Dev mode: skip authentication (for testing)
    @Published var devSkipAuth: Bool {
        didSet { save("devSkipAuth", value: devSkipAuth) }
    }

    /// Progressive overload suggestions during workouts
    @Published var progressiveOverloadEnabled: Bool {
        didSet { save("progressiveOverloadEnabled", value: progressiveOverloadEnabled) }
    }

    /// AI-generated training plans
    @Published var trainingPlanEnabled: Bool {
        didSet { save("trainingPlanEnabled", value: trainingPlanEnabled) }
    }

    /// Real-time form check camera with pose detection
    @Published var formCheckCameraEnabled: Bool {
        didSet { save("formCheckCameraEnabled", value: formCheckCameraEnabled) }
    }

    /// Voice coach for hands-free workout control
    @Published var voiceCoachEnabled: Bool {
        didSet { save("voiceCoachEnabled", value: voiceCoachEnabled) }
    }

    /// Recovery advisor card using Whoop/HealthKit data
    @Published var recoveryAdvisorEnabled: Bool {
        didSet { save("recoveryAdvisorEnabled", value: recoveryAdvisorEnabled) }
    }

    /// Pod accountability system (System 2)
    @Published var podSystemEnabled: Bool {
        didSet { save("podSystemEnabled", value: podSystemEnabled) }
    }

    /// Premium gate system (soft paywall triggers)
    @Published var premiumGateEnabled: Bool {
        didSet { save("premiumGateEnabled", value: premiumGateEnabled) }
    }

    /// Challenge engine (System 3)
    @Published var challengeEngineEnabled: Bool {
        didSet { save("challengeEngineEnabled", value: challengeEngineEnabled) }
    }

    /// Supabase backend sync (posts, profiles, social data)
    @Published var supabaseSyncEnabled: Bool {
        didSet { save("supabaseSyncEnabled", value: supabaseSyncEnabled) }
    }

    // MARK: - One-Time Prompt Tracking

    var hasSeenGymLocationPrompt: Bool {
        get { defaults.bool(forKey: "hasSeenGymLocationPrompt") }
        set { defaults.set(newValue, forKey: "hasSeenGymLocationPrompt") }
    }

    // MARK: - Initialization

    private let defaults = UserDefaults.standard
    private let prefix = "feature_"

    private init() {
        // Load saved values or use defaults
        // Core features enabled by default
        self.workoutCardsEnabled = defaults.object(forKey: prefix + "workoutCardsEnabled") as? Bool ?? true
        self.enhancedPREnabled = defaults.object(forKey: prefix + "enhancedPREnabled") as? Bool ?? true
        self.templatesEnabled = defaults.object(forKey: prefix + "templatesEnabled") as? Bool ?? true
        self.repeatWorkoutEnabled = defaults.object(forKey: prefix + "repeatWorkoutEnabled") as? Bool ?? true
        self.weeklyRecapEnabled = defaults.object(forKey: prefix + "weeklyRecapEnabled") as? Bool ?? true

        // New features - quests, squads, and learning enabled by default as core to GymQuest identity
        self.learningFeedEnabled = defaults.object(forKey: prefix + "learningFeedEnabled") as? Bool ?? true
        self.questsEnabled = defaults.object(forKey: prefix + "questsEnabled") as? Bool ?? true
        self.squadsEnabled = defaults.object(forKey: prefix + "squadsEnabled") as? Bool ?? true
        self.healthKitImportEnabled = defaults.object(forKey: prefix + "healthKitImportEnabled") as? Bool ?? false
        self.stravaImportEnabled = false // Removed
        self.whoopEnabled = false // Removed
        self.robotDemosEnabled = defaults.object(forKey: prefix + "robotDemosEnabled") as? Bool ?? true
        self.nutritionEnabled = defaults.object(forKey: prefix + "nutritionEnabled") as? Bool ?? true
        self.workoutPartyEnabled = defaults.object(forKey: prefix + "workoutPartyEnabled") as? Bool ?? true
        self.voiceNotesEnabled = defaults.object(forKey: prefix + "voiceNotesEnabled") as? Bool ?? true
        self.gymLocationSharing = defaults.object(forKey: prefix + "gymLocationSharing") as? Bool ?? true
        self.exerciseGifsEnabled = defaults.object(forKey: prefix + "exerciseGifsEnabled") as? Bool ?? true
        self.devSkipAuth = defaults.object(forKey: prefix + "devSkipAuth") as? Bool ?? false
        self.premiumEnabled = defaults.object(forKey: prefix + "premiumEnabled") as? Bool ?? true

        // Market-dominating features
        self.progressiveOverloadEnabled = defaults.object(forKey: prefix + "progressiveOverloadEnabled") as? Bool ?? true
        self.trainingPlanEnabled = defaults.object(forKey: prefix + "trainingPlanEnabled") as? Bool ?? true
        self.formCheckCameraEnabled = defaults.object(forKey: prefix + "formCheckCameraEnabled") as? Bool ?? false
        self.voiceCoachEnabled = defaults.object(forKey: prefix + "voiceCoachEnabled") as? Bool ?? false
        self.recoveryAdvisorEnabled = defaults.object(forKey: prefix + "recoveryAdvisorEnabled") as? Bool ?? true
        self.podSystemEnabled = defaults.object(forKey: prefix + "podSystemEnabled") as? Bool ?? true
        self.premiumGateEnabled = defaults.object(forKey: prefix + "premiumGateEnabled") as? Bool ?? false
        self.challengeEngineEnabled = defaults.object(forKey: prefix + "challengeEngineEnabled") as? Bool ?? true
        self.supabaseSyncEnabled = defaults.object(forKey: prefix + "supabaseSyncEnabled") as? Bool ?? true
    }

    private func save(_ key: String, value: Bool) {
        defaults.set(value, forKey: prefix + key)
    }

    // MARK: - Convenience Methods

    /// Enable all features (for testing/development)
    func enableAllFeatures() {
        learningFeedEnabled = true
        questsEnabled = true
        squadsEnabled = true
        healthKitImportEnabled = true
        // stravaImportEnabled and whoopEnabled removed
        robotDemosEnabled = true
        nutritionEnabled = true
        enhancedPREnabled = true
        workoutCardsEnabled = true
        weeklyRecapEnabled = true
        templatesEnabled = true
        repeatWorkoutEnabled = true
        workoutPartyEnabled = true
        voiceNotesEnabled = true
        gymLocationSharing = true
        exerciseGifsEnabled = true
        progressiveOverloadEnabled = true
        trainingPlanEnabled = true
        formCheckCameraEnabled = true
        voiceCoachEnabled = true
        recoveryAdvisorEnabled = true
    }

    /// Reset to default feature state
    func resetToDefaults() {
        workoutCardsEnabled = true
        enhancedPREnabled = true
        templatesEnabled = true
        repeatWorkoutEnabled = true
        weeklyRecapEnabled = true

        learningFeedEnabled = true
        questsEnabled = true
        squadsEnabled = true
        healthKitImportEnabled = false
        // stravaImportEnabled and whoopEnabled removed
        robotDemosEnabled = true
        nutritionEnabled = true
        workoutPartyEnabled = true
        voiceNotesEnabled = true
        gymLocationSharing = true
        exerciseGifsEnabled = true
        progressiveOverloadEnabled = true
        trainingPlanEnabled = true
        formCheckCameraEnabled = false
        voiceCoachEnabled = false
        recoveryAdvisorEnabled = true
    }

    /// Check if app is in demo mode (no external dependencies needed)
    var isDemoMode: Bool {
        !healthKitImportEnabled && !stravaImportEnabled && !whoopEnabled
    }
}

// MARK: - Environment Key

private struct FeatureFlagsKey: EnvironmentKey {
    @MainActor static let defaultValue = FeatureFlags.shared
}

extension EnvironmentValues {
    var featureFlags: FeatureFlags {
        get { self[FeatureFlagsKey.self] }
        set { self[FeatureFlagsKey.self] = newValue }
    }
}

// MARK: - View Extension for Feature Gating

extension View {
    /// Conditionally show view based on feature flag
    @ViewBuilder
    func featureGated(_ enabled: Bool) -> some View {
        if enabled {
            self
        }
    }

    /// Show view only when feature is enabled, otherwise show fallback
    @ViewBuilder
    func featureGated(_ enabled: Bool, fallback: some View) -> some View {
        if enabled {
            self
        } else {
            fallback
        }
    }
}
