//
//  AuthService.swift
//  GymQuest
//
//  Created by Benjamin Hilderman
//
//  All the auth stuff lives here. Login, signup, logout, password hashing.
//  Everything's stored locally in SwiftData - no actual backend.
//  Works great for a portfolio demo tho, looks real enough.
//

import Foundation
import SwiftData
import CryptoKit

@MainActor
class AuthService: ObservableObject {
    private var modelContext: ModelContext?

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // called on app launch to see if someone's already logged in
    func checkExistingAuth() -> UserProfile? {
        guard let modelContext else { return nil }

        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.isAuthenticated == true }
        )

        do {
            let profiles = try modelContext.fetch(descriptor)
            return profiles.first
        } catch {
            print("Error checking auth: \(error)")
            return nil
        }
    }

    // sha256 hash - good enough for local storage
    func hashPassword(_ password: String) -> String {
        let data = Data(password.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // tries to find a matching email + password, returns nil if no luck
    func login(email: String, password: String) -> UserProfile? {
        guard let modelContext else { return nil }

        let passwordHash = hashPassword(password)
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { profile in
                profile.email == email && profile.passwordHash == passwordHash
            }
        )

        do {
            let profiles = try modelContext.fetch(descriptor)
            if let profile = profiles.first {
                profile.isAuthenticated = true
                try modelContext.save()
                return profile
            }
        } catch {
            print("Error logging in: \(error)")
        }

        return nil
    }

    func emailExists(_ email: String) -> Bool {
        guard let modelContext else { return false }

        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.email == email }
        )

        do {
            let profiles = try modelContext.fetch(descriptor)
            return !profiles.isEmpty
        } catch {
            print("Error checking email: \(error)")
            return false
        }
    }

    func googleIdExists(_ googleId: String) -> UserProfile? {
        guard let modelContext else { return nil }

        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.googleId == googleId }
        )

        do {
            let profiles = try modelContext.fetch(descriptor)
            return profiles.first
        } catch {
            print("Error checking google id: \(error)")
        }

        return nil
    }

    func markAuthenticated(_ profile: UserProfile) {
        guard let modelContext else { return }
        profile.isAuthenticated = true
        try? modelContext.save()
    }

    // makes a new account after they finish onboarding
    func register(
        name: String,
        username: String,
        dateOfBirth: Date,
        email: String,
        password: String
    ) -> UserProfile? {
        guard let modelContext else { return nil }

        let profile = UserProfile(
            name: name,
            username: username,
            isAuthenticated: true,
            authMethod: "email",
            email: email,
            passwordHash: hashPassword(password),
            dateOfBirth: dateOfBirth
        )

        // Default to demo mode - user can add API key in settings
        profile.aiProvider = .demo

        modelContext.insert(profile)

        do {
            try modelContext.save()
            return profile
        } catch {
            print("Error registering: \(error)")
            return nil
        }
    }

    // same as email register but for google users
    func registerWithGoogle(
        name: String,
        username: String,
        dateOfBirth: Date,
        googleId: String,
        email: String?
    ) -> UserProfile? {
        guard let modelContext else { return nil }

        let profile = UserProfile(
            name: name,
            username: username,
            isAuthenticated: true,
            authMethod: "google",
            email: email,
            googleId: googleId,
            dateOfBirth: dateOfBirth
        )

        // Default to demo mode - user can add API key in settings
        profile.aiProvider = .demo

        modelContext.insert(profile)

        do {
            try modelContext.save()
            return profile
        } catch {
            print("Error registering with google: \(error)")
            return nil
        }
    }

    // just flips isAuthenticated to false
    func logout(profile: UserProfile) {
        guard let modelContext else { return }

        profile.isAuthenticated = false

        do {
            try modelContext.save()
        } catch {
            print("Error logging out: \(error)")
        }
    }
}
