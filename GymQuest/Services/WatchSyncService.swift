//
//  WatchSyncService.swift
//  GymQuest
//
//  iOS-side WatchConnectivity handler.
//  Sends active workout state to the watch and receives
//  set completions / workout start/end from the watch.
//

import Foundation
import WatchConnectivity

@MainActor
final class WatchSyncService: NSObject, ObservableObject {
    static let shared = WatchSyncService()

    @Published var isWatchReachable = false

    private var session: WCSession?

    override nonisolated init() {
        super.init()
        #if os(iOS)
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            self.session = session
        }
        #endif
    }

    // MARK: - Send to Watch

    func sendWorkoutState(
        isActive: Bool,
        exerciseName: String = "",
        setNumber: Int = 0,
        totalSets: Int = 0,
        restTime: Int = 0,
        elapsed: Int = 0,
        workoutType: String = ""
    ) {
        let message: [String: Any] = [
            "action": "workoutState",
            "isActive": isActive,
            "exerciseName": exerciseName,
            "setNumber": setNumber,
            "totalSets": totalSets,
            "restTime": restTime,
            "elapsed": elapsed,
            "workoutType": workoutType
        ]
        try? session?.updateApplicationContext(message)
    }

    func sendStreak(_ value: Int) {
        try? session?.updateApplicationContext(["action": "streak", "value": value])
    }

    /// Send top exercises to watch for quick-start
    func sendExerciseList(_ exercises: [String]) {
        let message: [String: Any] = [
            "action": "exerciseList",
            "exercises": Array(exercises.prefix(10))
        ]
        session?.sendMessage(message, replyHandler: nil, errorHandler: nil)
        // Also set in application context for persistence
        try? session?.updateApplicationContext(["quickExercises": Array(exercises.prefix(10))])
    }

    /// Send progressive overload suggestion to watch
    func sendSuggestedWeight(_ weight: Double) {
        let message: [String: Any] = [
            "action": "suggestedWeight",
            "weight": weight
        ]
        session?.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }
}

// MARK: - WCSessionDelegate

extension WatchSyncService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isWatchReachable = session.isReachable
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            handleWatchMessage(message)
        }
    }

    @MainActor
    private func handleWatchMessage(_ message: [String: Any]) {
        guard let action = message["action"] as? String else { return }

        switch action {
        case "setComplete":
            // Post notification for ActiveWorkoutViewModel to pick up
            NotificationCenter.default.post(
                name: .watchSetComplete,
                object: nil,
                userInfo: message
            )
        case "workoutStart":
            NotificationCenter.default.post(
                name: .watchWorkoutStart,
                object: nil,
                userInfo: message
            )
        case "workoutEnd":
            NotificationCenter.default.post(
                name: .watchWorkoutEnd,
                object: nil
            )
        default:
            break
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let watchSetComplete = Notification.Name("watchSetComplete")
    static let watchWorkoutStart = Notification.Name("watchWorkoutStart")
    static let watchWorkoutEnd = Notification.Name("watchWorkoutEnd")
}
