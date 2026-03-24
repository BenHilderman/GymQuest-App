//
//  SupabaseAuthService.swift
//  GymQuest
//
//  Wraps Supabase Auth for sign-up, sign-in, sign-out, and session management.
//

import Foundation
import Supabase
import SwiftData

@MainActor
final class SupabaseAuthService: ObservableObject {
    static let shared = SupabaseAuthService()

    @Published var isAuthenticated: Bool = false
    @Published var currentUserId: UUID?
    @Published var currentSession: Session?

    private init() {
        observeAuthChanges()
    }

    // MARK: - Auth Operations

    func signUp(email: String, password: String, username: String, displayName: String) async throws {
        let userData: [String: AnyJSON] = [
            "username": .string(username),
            "display_name": .string(displayName)
        ]
        let response = try await SupabaseConfig.client.auth.signUp(
            email: email,
            password: password,
            data: userData
        )
        self.currentSession = response.session
        self.currentUserId = response.user.id
        self.isAuthenticated = response.session != nil
    }

    func signIn(email: String, password: String) async throws {
        let session = try await SupabaseConfig.client.auth.signIn(
            email: email,
            password: password
        )
        self.currentSession = session
        self.currentUserId = session.user.id
        self.isAuthenticated = true
    }

    func signOut() async throws {
        try await SupabaseConfig.client.auth.signOut()
        self.currentSession = nil
        self.currentUserId = nil
        self.isAuthenticated = false
    }

    // MARK: - Session Management

    func restoreSession() async {
        do {
            let session = try await SupabaseConfig.client.auth.session
            self.currentSession = session
            self.currentUserId = session.user.id
            self.isAuthenticated = true
        } catch {
            self.currentSession = nil
            self.currentUserId = nil
            self.isAuthenticated = false
        }
    }

    // MARK: - Remote Profile Fetch

    func fetchAndApplyRemoteProfile(modelContext: ModelContext) async {
        guard let userId = currentUserId else { return }
        do {
            let profiles: [ProfileDTO] = try await SupabaseConfig.client
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .execute()
                .value

            guard let remoteProfile = profiles.first else { return }

            // Find or create local UserProfile
            let descriptor = FetchDescriptor<UserProfile>(predicate: #Predicate { $0.supabaseId == userId })
            let existing = try? modelContext.fetch(descriptor)

            if let localProfile = existing?.first {
                localProfile.name = remoteProfile.displayName
                localProfile.username = remoteProfile.username
                if let email = remoteProfile.email { localProfile.email = email }
                localProfile.isPremium = remoteProfile.isPremium
                try? modelContext.save()
            }
        } catch {
            print("[SupabaseAuthService] Failed to fetch remote profile: \(error)")
        }
    }

    // MARK: - Auth State Observation

    func observeAuthChanges() {
        Task {
            await SupabaseConfig.client.auth.onAuthStateChange { event, session in
                Task { @MainActor in
                    switch event {
                    case .signedIn:
                        self.currentSession = session
                        self.currentUserId = session?.user.id
                        self.isAuthenticated = true
                    case .signedOut:
                        self.currentSession = nil
                        self.currentUserId = nil
                        self.isAuthenticated = false
                    case .tokenRefreshed:
                        self.currentSession = session
                    default:
                        break
                    }
                }
            }
        }
    }
}
