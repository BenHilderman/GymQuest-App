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

    /// Strava activity import
    @Published var stravaImportEnabled: Bool {
        didSet { save("stravaImportEnabled", value: stravaImportEnabled) }
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

    /// Dev mode: skip authentication (for testing)
    @Published var devSkipAuth: Bool {
        didSet { save("devSkipAuth", value: devSkipAuth) }
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
        self.stravaImportEnabled = defaults.object(forKey: prefix + "stravaImportEnabled") as? Bool ?? false
        self.robotDemosEnabled = defaults.object(forKey: prefix + "robotDemosEnabled") as? Bool ?? true
        self.nutritionEnabled = defaults.object(forKey: prefix + "nutritionEnabled") as? Bool ?? true
        self.devSkipAuth = defaults.object(forKey: prefix + "devSkipAuth") as? Bool ?? true
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
        stravaImportEnabled = true
        robotDemosEnabled = true
        nutritionEnabled = true
        enhancedPREnabled = true
        workoutCardsEnabled = true
        weeklyRecapEnabled = true
        templatesEnabled = true
        repeatWorkoutEnabled = true
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
        stravaImportEnabled = false
        robotDemosEnabled = true
        nutritionEnabled = true
    }

    /// Check if app is in demo mode (no external dependencies needed)
    var isDemoMode: Bool {
        !healthKitImportEnabled && !stravaImportEnabled
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
