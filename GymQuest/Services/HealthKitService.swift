//
//  HealthKitService.swift
//  GymQuest
//
//  Comprehensive HealthKit integration for GymQuest.
//  Reads workouts, vitals (HRV, SpO2, respiratory rate, skin temp),
//  sleep stages, activity data, and body measurements from Apple Health.
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

    // MARK: - Today's Activity Metrics

    @Published var steps: Int = 0
    @Published var activeCalories: Int = 0
    @Published var walkingRunningDistance: Double = 0  // km
    @Published var flightsClimbed: Int = 0
    @Published var exerciseMinutes: Int = 0
    @Published var standHours: Int = 0

    // MARK: - Vitals

    @Published var restingHeartRate: Int = 0
    @Published var currentHeartRate: Int = 0
    @Published var hrvMs: Double = 0                    // HRV SDNN in ms
    @Published var spo2Percentage: Double = 0           // Blood oxygen %
    @Published var respiratoryRate: Double = 0          // breaths/min
    @Published var wristTemperature: Double = 0         // °C deviation from baseline
    @Published var vo2Max: Double = 0                   // mL/kg/min

    // MARK: - Sleep Data

    @Published var sleepHours: Double = 0
    @Published var sleepStages: SleepStageBreakdown = SleepStageBreakdown()
    @Published var sleepEfficiency: Double = 0          // % of time in bed asleep

    // MARK: - Body Measurements

    @Published var bodyWeight: Double = 0               // kg
    @Published var bodyFatPercentage: Double = 0
    @Published var bmi: Double = 0

    // MARK: - Walking Steadiness

    @Published var walkingAsymmetry: Double = 0         // %
    @Published var walkingSpeed: Double = 0             // m/s
    @Published var walkingStepLength: Double = 0        // m

    // All data types we want to read
    private var allReadTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType()]

        let quantityIdentifiers: [HKQuantityTypeIdentifier] = [
            .stepCount,
            .activeEnergyBurned,
            .distanceWalkingRunning,
            .flightsClimbed,
            .appleExerciseTime,
            .appleStandTime,
            .restingHeartRate,
            .heartRate,
            .heartRateVariabilitySDNN,
            .oxygenSaturation,
            .respiratoryRate,
            .vo2Max,
            .bodyMass,
            .bodyFatPercentage,
            .bodyMassIndex,
            .walkingAsymmetryPercentage,
            .walkingSpeed,
            .walkingStepLength,
        ]

        for id in quantityIdentifiers {
            if let type = HKQuantityType.quantityType(forIdentifier: id) {
                types.insert(type)
            }
        }

        // Apple Watch wrist temperature (iOS 16+)
        if #available(iOS 16.0, *) {
            if let tempType = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature) {
                types.insert(tempType)
            }
        }

        // Sleep analysis
        if let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepType)
        }

        return types
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async -> Bool {
        guard isHealthKitAvailable else { return false }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: allReadTypes)
            isAuthorized = true
            return true
        } catch {
            print("HealthKit authorization failed: \(error)")
            return false
        }
    }

    func checkAuthorizationStatus() {
        guard isHealthKitAvailable else {
            isAuthorized = false
            return
        }
        let status = healthStore.authorizationStatus(for: HKObjectType.workoutType())
        isAuthorized = status == .sharingAuthorized
    }

    func requestAuthorizationSync() {
        Task { _ = await requestAuthorization() }
    }

    // MARK: - Fetch All Today's Data

    func fetchTodayData() {
        fetchActivityMetrics()
        fetchVitals()
        fetchSleepData()
        fetchBodyMeasurements()
        fetchWalkingMetrics()
    }

    // MARK: - Activity Metrics

    private func fetchActivityMetrics() {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)

        // Steps
        fetchCumulativeStat(.stepCount, start: startOfDay, end: now, unit: .count()) { [weak self] value in
            self?.steps = Int(value)
        }

        // Active calories
        fetchCumulativeStat(.activeEnergyBurned, start: startOfDay, end: now, unit: .kilocalorie()) { [weak self] value in
            self?.activeCalories = Int(value)
        }

        // Walking/Running distance
        fetchCumulativeStat(.distanceWalkingRunning, start: startOfDay, end: now, unit: .meterUnit(with: .kilo)) { [weak self] value in
            self?.walkingRunningDistance = value
        }

        // Flights climbed
        fetchCumulativeStat(.flightsClimbed, start: startOfDay, end: now, unit: .count()) { [weak self] value in
            self?.flightsClimbed = Int(value)
        }

        // Exercise minutes
        fetchCumulativeStat(.appleExerciseTime, start: startOfDay, end: now, unit: .minute()) { [weak self] value in
            self?.exerciseMinutes = Int(value)
        }
    }

    // MARK: - Vitals

    private func fetchVitals() {
        // Resting Heart Rate
        fetchLatestSample(.restingHeartRate, unit: HKUnit(from: "count/min")) { [weak self] value in
            self?.restingHeartRate = Int(value)
        }

        // Current Heart Rate
        fetchLatestSample(.heartRate, unit: HKUnit(from: "count/min")) { [weak self] value in
            self?.currentHeartRate = Int(value)
        }

        // HRV (SDNN)
        fetchLatestSample(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli)) { [weak self] value in
            self?.hrvMs = value
        }

        // SpO2
        fetchLatestSample(.oxygenSaturation, unit: .percent()) { [weak self] value in
            self?.spo2Percentage = value * 100
        }

        // Respiratory Rate
        fetchLatestSample(.respiratoryRate, unit: HKUnit(from: "count/min")) { [weak self] value in
            self?.respiratoryRate = value
        }

        // VO2 Max
        fetchLatestSample(.vo2Max, unit: HKUnit(from: "ml/kg*min")) { [weak self] value in
            self?.vo2Max = value
        }

        // Wrist Temperature (iOS 16+)
        if #available(iOS 16.0, *) {
            fetchLatestSample(.appleSleepingWristTemperature, unit: .degreeCelsius()) { [weak self] value in
                self?.wristTemperature = value
            }
        }
    }

    // MARK: - Sleep Data

    private func fetchSleepData() {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return }

        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfDay) ?? startOfDay

        let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, _ in
            Task { @MainActor in
                guard let samples = samples as? [HKCategorySample] else { return }

                var light: TimeInterval = 0
                var deep: TimeInterval = 0
                var rem: TimeInterval = 0
                var awake: TimeInterval = 0
                var inBed: TimeInterval = 0

                for sample in samples {
                    let duration = sample.endDate.timeIntervalSince(sample.startDate)

                    switch sample.value {
                    case HKCategoryValueSleepAnalysis.inBed.rawValue:
                        inBed += duration
                    case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                        light += duration
                    case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                        deep += duration
                    case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                        rem += duration
                    case HKCategoryValueSleepAnalysis.awake.rawValue:
                        awake += duration
                    case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                        light += duration  // count unspecified as light
                    default:
                        break
                    }
                }

                let totalSleep = light + deep + rem
                let totalInBed = inBed > 0 ? inBed : (totalSleep + awake)

                self?.sleepHours = totalSleep / 3600
                self?.sleepStages = SleepStageBreakdown(
                    lightHours: light / 3600,
                    deepHours: deep / 3600,
                    remHours: rem / 3600,
                    awakeHours: awake / 3600
                )
                self?.sleepEfficiency = totalInBed > 0 ? (totalSleep / totalInBed) * 100 : 0
            }
        }
        healthStore.execute(query)
    }

    // MARK: - Body Measurements

    private func fetchBodyMeasurements() {
        fetchLatestSample(.bodyMass, unit: .gramUnit(with: .kilo)) { [weak self] value in
            self?.bodyWeight = value
        }
        fetchLatestSample(.bodyFatPercentage, unit: .percent()) { [weak self] value in
            self?.bodyFatPercentage = value * 100
        }
        fetchLatestSample(.bodyMassIndex, unit: .count()) { [weak self] value in
            self?.bmi = value
        }
    }

    // MARK: - Walking Metrics

    private func fetchWalkingMetrics() {
        fetchLatestSample(.walkingAsymmetryPercentage, unit: .percent()) { [weak self] value in
            self?.walkingAsymmetry = value * 100
        }
        fetchLatestSample(.walkingSpeed, unit: HKUnit.meter().unitDivided(by: .second())) { [weak self] value in
            self?.walkingSpeed = value
        }
        fetchLatestSample(.walkingStepLength, unit: .meter()) { [weak self] value in
            self?.walkingStepLength = value
        }
    }

    // MARK: - Generic Helpers

    private func fetchCumulativeStat(
        _ identifier: HKQuantityTypeIdentifier,
        start: Date,
        end: Date,
        unit: HKUnit,
        completion: @escaping @MainActor (Double) -> Void
    ) {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
            Task { @MainActor in
                completion(value)
            }
        }
        healthStore.execute(query)
    }

    private func fetchLatestSample(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        completion: @escaping @MainActor (Double) -> Void
    ) {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
            Task { @MainActor in
                if let value = value {
                    completion(value)
                }
            }
        }
        healthStore.execute(query)
    }

    // MARK: - Heart Rate Zones (for workout sessions)

    func fetchHeartRateZones(for workout: HKWorkout) async -> HeartRateZoneBreakdown {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return HeartRateZoneBreakdown()
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, _ in
                guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else {
                    continuation.resume(returning: HeartRateZoneBreakdown())
                    return
                }

                let bpmUnit = HKUnit(from: "count/min")
                var zones = [0, 0, 0, 0, 0]  // Zone 1-5 sample counts

                for sample in samples {
                    let bpm = sample.quantity.doubleValue(for: bpmUnit)
                    // Zones based on % of estimated max HR (220 - age, default 190)
                    let maxHR = 190.0
                    let pct = bpm / maxHR * 100

                    if pct < 60 { zones[0] += 1 }
                    else if pct < 70 { zones[1] += 1 }
                    else if pct < 80 { zones[2] += 1 }
                    else if pct < 90 { zones[3] += 1 }
                    else { zones[4] += 1 }
                }

                let total = max(1, zones.reduce(0, +))
                continuation.resume(returning: HeartRateZoneBreakdown(
                    zone1Pct: Double(zones[0]) / Double(total) * 100,
                    zone2Pct: Double(zones[1]) / Double(total) * 100,
                    zone3Pct: Double(zones[2]) / Double(total) * 100,
                    zone4Pct: Double(zones[3]) / Double(total) * 100,
                    zone5Pct: Double(zones[4]) / Double(total) * 100
                ))
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Workout Import

    func syncWorkouts(userId: UUID) async {
        guard isAuthorized, let context = modelContext else { return }

        isSyncing = true
        defer { isSyncing = false }

        let startDate = lastSyncDate ?? Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let endDate = Date()

        do {
            let workouts = try await fetchHealthKitWorkouts(from: startDate, to: endDate)
            var importCount = 0

            for hkWorkout in workouts {
                if !isWorkoutAlreadyImported(hkWorkout, context: context) {
                    let workout = convertToGymQuestWorkout(hkWorkout, userId: userId)
                    context.insert(workout)
                    importCount += 1
                }
            }

            if importCount > 0 {
                try context.save()
                importedWorkoutCount += importCount
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
                continuation.resume(returning: samples as? [HKWorkout] ?? [])
            }
            healthStore.execute(query)
        }
    }

    private func isWorkoutAlreadyImported(_ hkWorkout: HKWorkout, context: ModelContext) -> Bool {
        let healthkitSource = WorkoutSource.healthkit.rawValue
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.source.rawValue == healthkitSource }
        )
        guard let existingWorkouts = try? context.fetch(descriptor) else { return false }
        return existingWorkouts.contains { workout in
            abs(workout.date.timeIntervalSince(hkWorkout.startDate)) < 60 &&
            abs(Double(workout.duration) - hkWorkout.duration) < 60
        }
    }

    private func convertToGymQuestWorkout(_ hkWorkout: HKWorkout, userId: UUID) -> Workout {
        let workoutType = mapActivityType(hkWorkout.workoutActivityType)
        let title = generateWorkoutTitle(hkWorkout)

        let workout = Workout(
            date: hkWorkout.startDate,
            type: workoutType,
            duration: Int(hkWorkout.duration / 60),
            rpe: 5,
            notes: "Imported from Apple Health",
            title: title,
            source: .healthkit,
            privacy: .friends
        )

        if let calories = hkWorkout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) {
            workout.notes = "Imported from Apple Health\nCalories: \(Int(calories)) kcal"
        }

        return workout
    }

    private func mapActivityType(_ activityType: HKWorkoutActivityType) -> WorkoutType {
        switch activityType {
        case .traditionalStrengthTraining, .functionalStrengthTraining: return .push
        case .running: return .cardio
        case .cycling, .swimming: return .cardio
        case .yoga, .flexibility: return .rest
        case .highIntensityIntervalTraining: return .fullBody
        case .walking: return .rest
        case .coreTraining: return .push
        default: return .fullBody
        }
    }

    private func generateWorkoutTitle(_ hkWorkout: HKWorkout) -> String {
        let activityName = mapActivityTypeToString(hkWorkout.workoutActivityType)
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let dayName = formatter.string(from: hkWorkout.startDate)
        return "\(dayName) \(activityName)"
    }

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

    func enableBackgroundSync() {
        guard isHealthKitAvailable else { return }
        healthStore.enableBackgroundDelivery(
            for: HKObjectType.workoutType(),
            frequency: .immediate
        ) { _, error in
            if let error = error {
                print("Failed to enable background delivery: \(error)")
            }
        }
    }

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

// MARK: - Sleep Stage Breakdown

struct SleepStageBreakdown {
    var lightHours: Double = 0
    var deepHours: Double = 0
    var remHours: Double = 0
    var awakeHours: Double = 0

    var totalSleepHours: Double { lightHours + deepHours + remHours }

    var lightPercentage: Double {
        totalSleepHours > 0 ? (lightHours / totalSleepHours) * 100 : 0
    }
    var deepPercentage: Double {
        totalSleepHours > 0 ? (deepHours / totalSleepHours) * 100 : 0
    }
    var remPercentage: Double {
        totalSleepHours > 0 ? (remHours / totalSleepHours) * 100 : 0
    }
}

// MARK: - Heart Rate Zone Breakdown

struct HeartRateZoneBreakdown {
    var zone1Pct: Double = 0  // < 60% max HR (Recovery)
    var zone2Pct: Double = 0  // 60-70% (Fat Burn)
    var zone3Pct: Double = 0  // 70-80% (Cardio)
    var zone4Pct: Double = 0  // 80-90% (Peak)
    var zone5Pct: Double = 0  // > 90% (Max)
}

// MARK: - HealthKit Settings View

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
                                    .foregroundColor(GQColors.textTertiary)
                            }
                        }

                        HStack {
                            Text("Workouts Imported")
                            Spacer()
                            Text("\(healthKitService.importedWorkoutCount)")
                                .foregroundColor(GQColors.textTertiary)
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
                            .foregroundColor(GQColors.textTertiary)
                    }
                }
            } header: {
                Text("Apple Health Integration")
            } footer: {
                Text("Workouts recorded in Fitness+ or other Health-connected apps will automatically appear in your GymQuest feed, tagged as \"Imported\".")
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Workouts & Activity", systemImage: "figure.run")
                    Label("Heart Rate & HRV", systemImage: "heart.fill")
                    Label("Blood Oxygen (SpO2)", systemImage: "lungs.fill")
                    Label("Sleep Stages", systemImage: "bed.double.fill")
                    Label("Respiratory Rate", systemImage: "wind")
                    Label("Body Measurements", systemImage: "figure.stand")
                }
                .font(.subheadline)
                .foregroundColor(GQColors.textTertiary)
            } header: {
                Text("Data Types")
            }
        }
        .navigationTitle("Apple Health")
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
    .preferredColorScheme(.light)
}
