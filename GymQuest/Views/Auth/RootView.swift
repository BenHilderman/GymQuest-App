//
//  RootView.swift
//  GymQuest
//
//  Created by Benjamin Hilderman
//
//  The entry point after app launches. Figures out if you're logged in
//  already and sends you to the right place - login screen, onboarding,
//  or straight to the main app if you're already authenticated.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @StateObject private var authService = AuthService()

    @State private var hasCheckedAuth = false

    var body: some View {
        Group {
            switch appState.authState {
            case .notAuthenticated:
                if hasCheckedAuth {
                    LoginView()
                } else {
                    // quick loading spinner while we check if they're logged in
                    ZStack {
                        Color.black.ignoresSafeArea()
                        ProgressView()
                            .tint(.white)
                    }
                }

            case .onboarding(let authMethod, let email, let googleId):
                OnboardingView(
                    authMethod: authMethod,
                    email: email,
                    googleId: googleId
                )

            case .authenticated:
                ContentView()
            }
        }
        .onAppear {
            checkAuth()
        }
    }

    private func checkAuth() {
        authService.setModelContext(modelContext)

        if let profile = authService.checkExistingAuth() {
            appState.authState = .authenticated
        } else {
            appState.authState = .notAuthenticated
        }

        hasCheckedAuth = true
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
}
