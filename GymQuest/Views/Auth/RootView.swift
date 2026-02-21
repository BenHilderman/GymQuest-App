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
    @EnvironmentObject var featureFlags: FeatureFlags
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

            case .onboarding(let authMethod, let email, let googleId, let tempPassword):
                AISetupChatView(
                    authMethod: authMethod,
                    email: email,
                    googleId: googleId,
                    tempPassword: tempPassword
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

        // Dev mode: skip auth and create/use test user
        if featureFlags.devSkipAuth {
            createOrFetchDevUser()
            appState.authState = .authenticated
            hasCheckedAuth = true
            return
        }

        if let profile = authService.checkExistingAuth() {
            appState.authState = .authenticated
        } else {
            appState.authState = .notAuthenticated
        }

        hasCheckedAuth = true
    }

    private func createOrFetchDevUser() {
        // Check if dev user already exists
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.email == "dev@gymquest.app" }
        )

        do {
            let existing = try modelContext.fetch(descriptor)
            if let profile = existing.first {
                profile.isAuthenticated = true
                try modelContext.save()
                return
            }
        } catch {
            print("Error checking for dev user: \(error)")
        }

        // Create dev user
        let devUser = UserProfile(
            name: "Dev User",
            username: "devuser",
            isAuthenticated: true,
            authMethod: "dev",
            email: "dev@gymquest.app",
            passwordHash: "",
            dateOfBirth: Date()
        )
        devUser.aiProvider = .demo

        modelContext.insert(devUser)
        try? modelContext.save()
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
}
