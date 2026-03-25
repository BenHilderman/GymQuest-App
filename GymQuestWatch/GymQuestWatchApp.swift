//
//  GymQuestWatchApp.swift
//  GymQuestWatch
//
//  Apple Watch companion app entry point.
//

import SwiftUI

@main
struct LiftAIWatchApp: App {
    @State private var connectivity = WatchConnectivityManager()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchHomeView()
            }
            .environment(connectivity)
        }
    }
}
