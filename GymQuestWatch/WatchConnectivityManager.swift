//
//  WatchConnectivityManager.swift
//  GymQuestWatch
//
//  Handles bidirectional communication between iPhone and Apple Watch.
//  Syncs workout state, set completions, and heart rate data.
//

import Foundation
import WatchConnectivity
import HealthKit

@MainActor
@Observable
final class WatchConnectivityManager: NSObject {
    var isWorkoutActive = false
    var currentExerciseName = ""
    var currentSetNumber = 0
    var totalSets = 0
    var restTimeRemaining = 0
    var elapsedSeconds = 0
    var workoutType = ""
    var heartRate: Double = 0
    var streak = 0
    var quickExercises: [String] = []
    var suggestedWeight: Double?

    private var session: WCSession?
    private var healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?

    override init() {
        super.init()
        if WCSession.isSupported() {
            let wcSession = WCSession.default
            wcSession.delegate = self
            wcSession.activate()
            self.session = wcSession
        }
    }

    // MARK: - Send to Phone

    nonisolated func sendWorkoutStart(type: String) {
        WCSession.default.sendMessage(
            ["action": "workoutStart", "workoutType": type],
            replyHandler: nil, errorHandler: nil
        )
    }

    nonisolated func sendSetComplete(exerciseName: String, setNumber: Int, weight: Double, reps: Int) {
        WCSession.default.sendMessage([
            "action": "setComplete",
            "exerciseName": exerciseName,
            "setNumber": setNumber,
            "weight": weight,
            "reps": reps,
        ], replyHandler: nil, errorHandler: nil)
    }

    nonisolated func sendWorkoutEnd() {
        WCSession.default.sendMessage(
            ["action": "workoutEnd"],
            replyHandler: nil, errorHandler: nil
        )
    }

    nonisolated func sendCompletedWorkout(_ workout: WatchCompletedWorkout) {
        guard let data = try? JSONEncoder().encode(workout) else { return }
        WCSession.default.transferUserInfo([
            "action": "completedWorkout",
            "workoutData": data,
        ])
    }

    nonisolated func requestSync() {
        WCSession.default.sendMessage(
            ["action": "requestSync"],
            replyHandler: { reply in
                Task { @MainActor in
                    if let exercises = reply["quickExercises"] as? [String] {
                        self.quickExercises = exercises
                    }
                    if let streakValue = reply["streak"] as? Int {
                        self.streak = streakValue
                    }
                }
            },
            errorHandler: nil
        )
    }

    // MARK: - HealthKit Workout

    func startHealthKitWorkout() async {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)

            self.workoutSession = session
            self.workoutBuilder = builder

            session.startActivity(with: Date())
            try await builder.beginCollection(at: Date())

            observeHeartRate()
        } catch {
            print("[Watch] HealthKit workout start failed: \(error)")
        }
    }

    func endHealthKitWorkout() async {
        guard let session = workoutSession, let builder = workoutBuilder else { return }
        session.end()
        do {
            try await builder.endCollection(at: Date())
            try await builder.finishWorkout()
        } catch {
            print("[Watch] HealthKit workout end failed: \(error)")
        }
        workoutSession = nil
        workoutBuilder = nil
    }

    private func observeHeartRate() {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        let query = HKAnchoredObjectQuery(
            type: quantityType,
            predicate: HKQuery.predicateForSamples(withStart: Date(), end: nil),
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.processHeartRateSamples(samples)
        }
        query.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.processHeartRateSamples(samples)
        }
        healthStore.execute(query)
    }

    private nonisolated func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let quantitySamples = samples as? [HKQuantitySample],
              let latest = quantitySamples.last else { return }
        let bpm = latest.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        Task { @MainActor in
            self.heartRate = bpm
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if activationState == .activated {
            Task { @MainActor in
                self.requestSync()
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            handleMessage(message)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            if let exercises = applicationContext["quickExercises"] as? [String] {
                self.quickExercises = exercises
            }
            if let weight = applicationContext["suggestedWeight"] as? Double {
                self.suggestedWeight = weight
            }
        }
    }

    @MainActor
    private func handleMessage(_ message: [String: Any]) {
        guard let action = message["action"] as? String else { return }

        switch action {
        case "workoutState":
            isWorkoutActive = message["isActive"] as? Bool ?? false
            currentExerciseName = message["exerciseName"] as? String ?? ""
            currentSetNumber = message["setNumber"] as? Int ?? 0
            totalSets = message["totalSets"] as? Int ?? 0
            restTimeRemaining = message["restTime"] as? Int ?? 0
            elapsedSeconds = message["elapsed"] as? Int ?? 0
            workoutType = message["workoutType"] as? String ?? ""

        case "heartRate":
            heartRate = message["bpm"] as? Double ?? 0

        case "streak":
            streak = message["value"] as? Int ?? 0

        case "exerciseList":
            quickExercises = message["exercises"] as? [String] ?? []

        case "suggestedWeight":
            suggestedWeight = message["weight"] as? Double

        default:
            break
        }
    }
}
