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
final class WatchConnectivityManager: NSObject, ObservableObject {
    @Published var isWorkoutActive = false
    @Published var currentExerciseName = ""
    @Published var currentSetNumber = 0
    @Published var totalSets = 0
    @Published var restTimeRemaining = 0
    @Published var elapsedSeconds = 0
    @Published var workoutType = ""
    @Published var heartRate: Double = 0
    @Published var streak = 0
    @Published var quickExercises: [String] = []
    @Published var suggestedWeight: Double? = nil

    private var session: WCSession?
    private var healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?

    override nonisolated init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            self.session = session
        }
    }

    // MARK: - Send to Phone

    nonisolated func sendSetComplete(exerciseName: String, setNumber: Int, weight: Double, reps: Int) {
        let message: [String: Any] = [
            "action": "setComplete",
            "exerciseName": exerciseName,
            "setNumber": setNumber,
            "weight": weight,
            "reps": reps
        ]
        session?.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }

    nonisolated func sendWorkoutStart(type: String) {
        let message: [String: Any] = [
            "action": "workoutStart",
            "workoutType": type
        ]
        session?.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }

    nonisolated func sendWorkoutEnd() {
        session?.sendMessage(["action": "workoutEnd"], replyHandler: nil, errorHandler: nil)
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
        } catch {
            print("Failed to start HK workout: \(error)")
        }
    }

    func endHealthKitWorkout() async {
        guard let session = workoutSession, let builder = workoutBuilder else { return }
        session.end()
        do {
            try await builder.endCollection(at: Date())
            try await builder.finishWorkout()
        } catch {
            print("Failed to end HK workout: \(error)")
        }
        workoutSession = nil
        workoutBuilder = nil
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // Connected
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            handleMessage(message)
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

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            if let exercises = applicationContext["quickExercises"] as? [String] {
                quickExercises = exercises
            }
            if let weight = applicationContext["suggestedWeight"] as? Double {
                suggestedWeight = weight
            }
        }
    }
}
