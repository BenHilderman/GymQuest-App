//
//  GymQuestWatchApp.swift
//  GymQuestWatch
//
//  Apple Watch companion app entry point.
//  Manages WatchConnectivity session and root navigation.
//

import SwiftUI
import WatchConnectivity

@main
struct GymQuestWatchApp: App {
    @StateObject private var connectivityManager = WatchConnectivityManager()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WorkoutStartWatchView()
            }
            .environmentObject(connectivityManager)
        }
    }
}
