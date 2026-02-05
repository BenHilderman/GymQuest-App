//
//  HealthKitService.swift
//  GymQuest
//
//  HealthKit integration service for GymQuest 2.0.
//  Auto-imports workouts from Apple Health/Fitness+.
//

import Foundation
import HealthKit
import SwiftData

@MainActor
class HealthKitService: ObservableObject {
    static let shared = HealthKitService()

    private let healthStore = HKHealthStore()
    private var modelContext: ModelContext?

    @Published var isAuthorized = false
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var importedWorkoutCount = 0

    // Health metrics for display
    @Published var steps: Int = 0
    @Published var activeCalories: Int = 0
    @Published var sleepHours: Double = 0
    @Published var restingHeartRate: Int = 0

    // Workout types we want to read
    private let workoutTypes: Set<HKSampleType> = [
        HKObjectType.workoutType()
    ]

    // Health data types for metrics
    private var healthDataTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType()]
        if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            types.insert(stepType)
        }
        if let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(calorieType)
        }
        if let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepType)
        }
        if let hrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(hrType)
        }
        return types
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    /// Check if HealthKit is available
    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Request HealthKit authorization
    func requestAuthorization() async -> Bool {
        guard isHealthKitAvailable else { return false }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: workoutTypes)
            isAuthorized = true
            return true
        } catch {
            print("HealthKit authorization failed: \(error)")
            return false
        }
    }

    /// Check current authorization status
    func checkAuthorizationStatus() {
        guard isHealthKitAvailable else {
            isAuthorized = false
            return
        }

        let status = healthStore.authorizationStatus(for: HKObjectType.workoutType())
        // Note: .notDetermined means we haven't asked yet, not that we have permission
        isAuthorized = status == .sharingAuthorized
    }

    /// Request authorization (fire-and-forget wrapper for non-async contexts)
    func requestAuthorizationSync() {
        Task {
            _ = await requestAuthorization()
        }
    }

    // MARK: - Health Metrics

    /// Fetch today's health data for display
    func fetchTodayData() {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)

        // Fetch steps
        if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, _ in
                Task { @MainActor in
                    self?.steps = Int(result?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                }
            }
            healthStore.execute(query)
        }

        // Fetch active calories
        if let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: calorieType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, _ in
                Task { @MainActor in
                    self?.activeCalories = Int(result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0)
                }
            }
            healthStore.execute(query)
        }

        // Fetch resting heart rate (most recent)
        if let hrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: hrType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, _ in
                Task { @MainActor in
                    if let sample = samples?.first as? HKQuantitySample {
                        self?.restingHeartRate = Int(sample.quantity.doubleValue(for: HKUnit(from: "count/min")))
                    }
                }
            }
            healthStore.execute(query)
        }

        // Fetch sleep (last night)
        if let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfDay) ?? startOfDay
            let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: startOfDay, options: .strictStartDate)
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, _ in
                Task { @MainActor in
                    let totalSleep = samples?.reduce(0.0) { total, sample in
                        guard let categorySample = sample as? HKCategorySample else { return total }
                        // Only count asleep states (not in bed)
                        if categorySample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                           categorySample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                           categorySample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                           categorySample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue {
                            return total + categorySample.endDate.timeIntervalSince(categorySample.startDate)
                        }
                        return total
                    } ?? 0
                    self?.sleepHours = totalSleep / 3600 // Convert seconds to hours
                }
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Workout Import

    /// Sync workouts from HealthKit
    func syncWorkouts(userId: UUID) async {
        guard isAuthorized, let context = modelContext else { return }

        isSyncing = true
        defer { isSyncing = false }

        // Get workouts from the last 30 days (or since last sync)
        let startDate = lastSyncDate ?? Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let endDate = Date()

        do {
            let workouts = try await fetchHealthKitWorkouts(from: startDate, to: endDate)
            var importCount = 0

            for hkWorkout in workouts {
                // Check if already imported (by matching sourceRevision and date)
                if !isWorkoutAlreadyImported(hkWorkout, context: context) {
                    let workout = convertToGymQuestWorkout(hkWorkout, userId: userId)
                    context.insert(workout)
                    importCount += 1
                }
            }

            if importCount > 0 {
                try context.save()
                importedWorkoutCount += importCount

                // Track analytics
                AnalyticsService.shared.trackEvent(
                    eventName: "healthkit_sync_completed",
                    properties: [
                        "workouts_imported": "\(importCount)",
                        "user_id": userId.uuidString
                    ]
                )
            }

            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: "healthkit_last_sync")

        } catch {
            print("HealthKit sync failed: \(error)")
        }
    }

    /// Fetch workouts from HealthKit
    private func fetchHealthKitWorkouts(from startDate: Date, to endDate: Date) async throws -> [HKWorkout] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let workouts = samples as? [HKWorkout] ?? []
                continuation.resume(returning: workouts)
            }

            healthStore.execute(query)
        }
    }

    /// Check if workout was already imported
    private func isWorkoutAlreadyImported(_ hkWorkout: HKWorkout, context: ModelContext) -> Bool {
        // Check by matching the external ID (HealthKit workout UUID)
        let healthkitSource = WorkoutSource.healthkit.rawValue

        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.source.rawValue == healthkitSource }
        )

        guard let existingWorkouts = try? context.fetch(descriptor) else { return false }

        // Check if we have a workout with matching external ID
        return existingWorkouts.contains { workout in
            // Match by date and duration as a proxy for same workout
            abs(workout.date.timeIntervalSince(hkWorkout.startDate)) < 60 &&
            abs(Double(workout.duration) - hkWorkout.duration) < 60
        }
    }

    /// Convert HKWorkout to GymQuest Workout
    private func convertToGymQuestWorkout(_ hkWorkout: HKWorkout, userId: UUID) -> Workout {
        let workoutType = mapActivityType(hkWorkout.workoutActivityType)
        let title = generateWorkoutTitle(hkWorkout)

        let workout = Workout(
            date: hkWorkout.startDate,
            type: workoutType,
            duration: Int(hkWorkout.duration / 60), // Convert to minutes
            rpe: 5, // Default RPE for imported workouts
            notes: "Imported from Apple Health",
            title: title,
            source: .healthkit,
            privacy: .friends
        )

        // Add total calories if available
        if let calories = hkWorkout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) {
            workout.notes = "Imported from Apple Health\nCalories: \(Int(calories)) kcal"
        }

        return workout
    }

    /// Map HealthKit activity type to GymQuest workout type
    private func mapActivityType(_ activityType: HKWorkoutActivityType) -> WorkoutType {
        switch activityType {
        case .traditionalStrengthTraining, .functionalStrengthTraining:
            return .push // Default to push, could be improved
        case .running:
            return .cardio
        case .cycling, .swimming:
            return .cardio
        case .yoga, .flexibility:
            return .rest
        case .highIntensityIntervalTraining:
            return .fullBody
        case .walking:
            return .rest
        case .coreTraining:
            return .push
        default:
            return .fullBody
        }
    }

    /// Generate a title for the imported workout
    private func generateWorkoutTitle(_ hkWorkout: HKWorkout) -> String {
        let activityName = mapActivityTypeToString(hkWorkout.workoutActivityType)
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let dayName = formatter.string(from: hkWorkout.startDate)

        return "\(dayName) \(activityName)"
    }

    /// Map activity type to human-readable string
    private func mapActivityTypeToString(_ activityType: HKWorkoutActivityType) -> String {
        switch activityType {
        case .traditionalStrengthTraining: return "Strength Training"
        case .functionalStrengthTraining: return "Functional Training"
        case .running: return "Run"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .yoga: return "Yoga"
        case .flexibility: return "Flexibility"
        case .highIntensityIntervalTraining: return "HIIT"
        case .walking: return "Walk"
        case .coreTraining: return "Core Training"
        case .crossTraining: return "Cross Training"
        case .elliptical: return "Elliptical"
        case .rowing: return "Rowing"
        case .stairClimbing: return "Stair Climbing"
        case .pilates: return "Pilates"
        case .dance: return "Dance"
        case .barre: return "Barre"
        case .mixedCardio: return "Cardio"
        default: return "Workout"
        }
    }

    // MARK: - Background Sync

    /// Enable background delivery for workouts
    func enableBackgroundSync() {
        guard isHealthKitAvailable else { return }

        healthStore.enableBackgroundDelivery(
            for: HKObjectType.workoutType(),
            frequency: .immediate
        ) { success, error in
            if let error = error {
                print("Failed to enable background delivery: \(error)")
            }
        }
    }

    /// Set up observer query for new workouts
    func observeNewWorkouts(userId: UUID) {
        guard isAuthorized else { return }

        let query = HKObserverQuery(
            sampleType: HKObjectType.workoutType(),
            predicate: nil
        ) { [weak self] _, completionHandler, error in
            if error == nil {
                Task { @MainActor in
                    await self?.syncWorkouts(userId: userId)
                }
            }
            completionHandler()
        }

        healthStore.execute(query)
    }
}

// MARK: - HealthKit Import Settings View

import SwiftUI

struct HealthKitSettingsView: View {
    @EnvironmentObject var featureFlags: FeatureFlags
    @Environment(\.modelContext) private var modelContext

    let profile: UserProfile

    @StateObject private var healthKitService = HealthKitService.shared

    var body: some View {
        Form {
            Section {
                if healthKitService.isHealthKitAvailable {
                    Toggle("Sync with Apple Health", isOn: Binding(
                        get: { featureFlags.healthKitImportEnabled && healthKitService.isAuthorized },
                        set: { newValue in
                            if newValue {
                                Task {
                                    let authorized = await healthKitService.requestAuthorization()
                                    if authorized {
                                        featureFlags.healthKitImportEnabled = true
                                        await healthKitService.syncWorkouts(userId: profile.id)
                                    }
                                }
                            } else {
                                featureFlags.healthKitImportEnabled = false
                            }
                        }
                    ))

                    if featureFlags.healthKitImportEnabled && healthKitService.isAuthorized {
                        HStack {
                            Text("Status")
                            Spacer()
                            if healthKitService.isSyncing {
                                ProgressView()
                            } else {
                                Text("Connected")
                                    .foregroundColor(.green)
                            }
                        }

                        if let lastSync = healthKitService.lastSyncDate {
                            HStack {
                                Text("Last Sync")
                                Spacer()
                                Text(lastSync, style: .relative)
                                    .foregroundColor(.gray)
                            }
                        }

                        HStack {
                            Text("Workouts Imported")
                            Spacer()
                            Text("\(healthKitService.importedWorkoutCount)")
                                .foregroundColor(.gray)
                        }

                        Button("Sync Now") {
                            Task {
                                await healthKitService.syncWorkouts(userId: profile.id)
                            }
                        }
                        .disabled(healthKitService.isSyncing)
                    }
                } else {
                    HStack {
                        Image(systemName: "heart.slash")
                            .foregroundColor(.red)
                        Text("HealthKit not available on this device")
                            .foregroundColor(.gray)
                    }
                }
            } header: {
                Text("Apple Health Integration")
            } footer: {
                Text("Workouts recorded in Fitness+ or other Health-connected apps will automatically appear in your GymQuest feed, tagged as \"Imported\".")
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Strength Training", systemImage: "dumbbell.fill")
                    Label("Running & Cardio", systemImage: "figure.run")
                    Label("HIIT Workouts", systemImage: "flame.fill")
                    Label("Yoga & Flexibility", systemImage: "figure.yoga")
                }
                .font(.subheadline)
                .foregroundColor(.gray)
            } header: {
                Text("Supported Workout Types")
            }
        }
        .navigationTitle("HealthKit Sync")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            healthKitService.configure(modelContext: modelContext)
        }
    }
}

#Preview {
    NavigationStack {
        HealthKitSettingsView(profile: UserProfile(name: "Ben", username: "ben"))
            .environmentObject(FeatureFlags.shared)
    }
    .preferredColorScheme(.dark)
}
