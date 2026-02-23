//
//  StravaService.swift
//  GymQuest
//
//  Strava API integration service for GymQuest 2.0.
//  Auto-imports activities from Strava (runs, rides, etc.).
//

import Foundation
import SwiftData
import AuthenticationServices
import Security

// MARK: - Keychain Helper for Secure Token Storage

private enum KeychainHelper {
    static let service = "com.gymquest.strava"

    static func save(_ data: String, forKey key: String) {
        guard let data = data.data(using: .utf8) else { return }

        // Delete any existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    static func load(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    static func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

@MainActor
class StravaService: ObservableObject {
    static let shared = StravaService()

    private var modelContext: ModelContext?

    // Strava API configuration
    // To use Strava integration:
    // 1. Create an app at https://www.strava.com/settings/api
    // 2. Add these keys to Info.plist:
    //    - STRAVA_CLIENT_ID: Your app's Client ID
    //    - STRAVA_CLIENT_SECRET: Your app's Client Secret
    // 3. Set the Authorization Callback Domain to: gymquest
    private var clientId: String {
        Bundle.main.infoDictionary?["STRAVA_CLIENT_ID"] as? String ?? ""
    }
    private var clientSecret: String {
        Bundle.main.infoDictionary?["STRAVA_CLIENT_SECRET"] as? String ?? ""
    }

    var isConfigured: Bool {
        !clientId.isEmpty && !clientSecret.isEmpty
    }
    private let redirectUri = "gymquest://strava-callback"
    private let scope = "activity:read_all"

    @Published var isConnected = false
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var importedActivityCount = 0
    @Published var athleteProfile: StravaAthlete?

    private let defaults = UserDefaults.standard
    private let accessTokenKey = "strava_access_token"
    private let refreshTokenKey = "strava_refresh_token"
    private let tokenExpiryKey = "strava_token_expiry"

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        checkConnectionStatus()
    }

    // MARK: - Connection Status

    private func checkConnectionStatus() {
        let token = KeychainHelper.load(forKey: accessTokenKey)
        isConnected = !(token?.isEmpty ?? true)
    }

    var accessToken: String? {
        KeychainHelper.load(forKey: accessTokenKey)
    }

    // MARK: - OAuth Authentication

    /// Generate the Strava OAuth authorization URL
    /// Returns nil if Strava credentials are not configured in Info.plist
    func getAuthorizationURL() -> URL? {
        guard isConfigured else { return nil }
        var components = URLComponents(string: "https://www.strava.com/oauth/mobile/authorize")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "approval_prompt", value: "auto"),
            URLQueryItem(name: "scope", value: scope)
        ]
        return components?.url
    }

    /// Handle the OAuth callback
    func handleAuthCallback(url: URL) async -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            return false
        }

        return await exchangeCodeForToken(code: code)
    }

    /// Exchange authorization code for access token
    private func exchangeCodeForToken(code: String) async -> Bool {
        guard let tokenURL = URL(string: "https://www.strava.com/oauth/token") else {
            return false
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "code": code,
            "grant_type": "authorization_code"
        ]

        let bodyString = bodyParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return false
            }

            let tokenResponse = try JSONDecoder().decode(StravaTokenResponse.self, from: data)

            // Store tokens securely in Keychain
            KeychainHelper.save(tokenResponse.accessToken, forKey: accessTokenKey)
            KeychainHelper.save(tokenResponse.refreshToken, forKey: refreshTokenKey)
            defaults.set(tokenResponse.expiresAt, forKey: tokenExpiryKey)  // Expiry timestamp is not sensitive

            // Store athlete info
            athleteProfile = tokenResponse.athlete

            isConnected = true
            return true
        } catch {
            print("Strava token exchange failed: \(error)")
            return false
        }
    }

    /// Refresh access token if expired
    private func refreshTokenIfNeeded() async -> Bool {
        guard let refreshToken = KeychainHelper.load(forKey: refreshTokenKey) else {
            return false
        }

        let expiry = defaults.double(forKey: tokenExpiryKey)
        if Date().timeIntervalSince1970 < expiry - 300 {
            // Token still valid (with 5 min buffer)
            return true
        }

        guard let tokenURL = URL(string: "https://www.strava.com/oauth/token") else {
            return false
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]

        let bodyString = bodyParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return false
            }

            let tokenResponse = try JSONDecoder().decode(StravaRefreshResponse.self, from: data)

            // Update tokens securely in Keychain
            KeychainHelper.save(tokenResponse.accessToken, forKey: accessTokenKey)
            KeychainHelper.save(tokenResponse.refreshToken, forKey: refreshTokenKey)
            defaults.set(tokenResponse.expiresAt, forKey: tokenExpiryKey)

            return true
        } catch {
            print("Strava token refresh failed: \(error)")
            return false
        }
    }

    /// Disconnect Strava account
    func disconnect() {
        KeychainHelper.delete(forKey: accessTokenKey)
        KeychainHelper.delete(forKey: refreshTokenKey)
        defaults.removeObject(forKey: tokenExpiryKey)
        isConnected = false
        athleteProfile = nil
    }

    // MARK: - Activity Import

    /// Sync activities from Strava
    func syncActivities(userId: UUID) async {
        guard isConnected,
              let context = modelContext,
              await refreshTokenIfNeeded(),
              let token = accessToken else { return }

        isSyncing = true
        defer { isSyncing = false }

        // Get activities from the last 30 days (or since last sync)
        let startDate = lastSyncDate ?? Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()

        do {
            let activities = try await fetchStravaActivities(token: token, after: startDate)
            var importCount = 0

            for activity in activities {
                // Check if already imported
                if !isActivityAlreadyImported(activity, context: context) {
                    let workout = convertToGymQuestWorkout(activity, userId: userId)
                    context.insert(workout)
                    importCount += 1
                }
            }

            if importCount > 0 {
                try context.save()
                importedActivityCount += importCount

                // Track analytics
                AnalyticsService.shared.trackEvent(
                    eventName: "strava_sync_completed",
                    properties: [
                        "activities_imported": "\(importCount)",
                        "user_id": userId.uuidString
                    ]
                )
            }

            lastSyncDate = Date()
            defaults.set(lastSyncDate, forKey: "strava_last_sync")

        } catch {
            print("Strava sync failed: \(error)")
        }
    }

    /// Fetch activities from Strava API
    private func fetchStravaActivities(token: String, after: Date) async throws -> [StravaActivity] {
        guard var components = URLComponents(string: "https://www.strava.com/api/v3/athlete/activities") else {
            throw StravaError.apiError
        }
        components.queryItems = [
            URLQueryItem(name: "after", value: "\(Int(after.timeIntervalSince1970))"),
            URLQueryItem(name: "per_page", value: "100")
        ]

        guard let url = components.url else {
            throw StravaError.apiError
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw StravaError.apiError
        }

        return try JSONDecoder().decode([StravaActivity].self, from: data)
    }

    /// Check if activity was already imported
    private func isActivityAlreadyImported(_ activity: StravaActivity, context: ModelContext) -> Bool {
        let stravaSource = WorkoutSource.strava.rawValue
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.source.rawValue == stravaSource }
        )

        guard let existingWorkouts = try? context.fetch(descriptor) else { return false }

        // Check by matching start time
        return existingWorkouts.contains { workout in
            abs(workout.date.timeIntervalSince(activity.startDate)) < 60
        }
    }

    /// Convert Strava activity to GymQuest Workout
    private func convertToGymQuestWorkout(_ activity: StravaActivity, userId: UUID) -> Workout {
        let workoutType = mapActivityType(activity.type)

        var notes = "Imported from Strava"
        if let distance = activity.distance {
            let km = distance / 1000
            notes += "\nDistance: \(String(format: "%.2f", km)) km"
        }
        if let avgSpeed = activity.averageSpeed {
            let kmh = avgSpeed * 3.6
            notes += "\nAvg Speed: \(String(format: "%.1f", kmh)) km/h"
        }
        if let avgHr = activity.averageHeartrate {
            notes += "\nAvg HR: \(Int(avgHr)) bpm"
        }

        let workout = Workout(
            date: activity.startDate,
            type: workoutType,
            duration: Int(activity.movingTime / 60), // Convert seconds to minutes
            rpe: estimateRPE(activity),
            notes: notes,
            title: activity.name,
            source: .strava,
            privacy: .friends
        )

        return workout
    }

    /// Map Strava activity type to GymQuest workout type
    private func mapActivityType(_ type: String) -> WorkoutType {
        switch type.lowercased() {
        case "run", "virtualrun", "trailrun":
            return .cardio
        case "ride", "virtualride", "ebikeride", "mountainbikeride", "gravelride":
            return .cardio
        case "swim":
            return .cardio
        case "walk", "hike":
            return .rest
        case "yoga":
            return .rest
        case "weighttraining":
            return .push // Default to push
        case "workout", "hiit", "crossfit":
            return .fullBody
        default:
            return .fullBody
        }
    }

    /// Estimate RPE based on activity data
    private func estimateRPE(_ activity: StravaActivity) -> Int {
        // Simple RPE estimation based on suffer score or average HR
        if let sufferScore = activity.sufferScore {
            if sufferScore >= 200 { return 10 }
            if sufferScore >= 150 { return 9 }
            if sufferScore >= 100 { return 8 }
            if sufferScore >= 75 { return 7 }
            if sufferScore >= 50 { return 6 }
            return 5
        }

        // Fallback based on duration if no suffer score
        let minutes = activity.movingTime / 60
        if minutes >= 120 { return 8 }
        if minutes >= 60 { return 7 }
        if minutes >= 30 { return 6 }
        return 5
    }
}

// MARK: - Strava API Models

struct StravaTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Int
    let athlete: StravaAthlete

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case athlete
    }
}

struct StravaRefreshResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
    }
}

struct StravaAthlete: Codable {
    let id: Int
    let username: String?
    let firstname: String?
    let lastname: String?
    let profileMedium: String?

    enum CodingKeys: String, CodingKey {
        case id, username, firstname, lastname
        case profileMedium = "profile_medium"
    }

    var displayName: String {
        if let first = firstname, let last = lastname {
            return "\(first) \(last)"
        }
        return username ?? "Strava Athlete"
    }
}

struct StravaActivity: Codable {
    let id: Int
    let name: String
    let type: String
    let startDate: Date
    let movingTime: Int
    let distance: Double?
    let averageSpeed: Double?
    let averageHeartrate: Double?
    let sufferScore: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, type, distance
        case startDate = "start_date"
        case movingTime = "moving_time"
        case averageSpeed = "average_speed"
        case averageHeartrate = "average_heartrate"
        case sufferScore = "suffer_score"
    }
}

enum StravaError: Error {
    case apiError
    case authError
    case networkError
}

// MARK: - Strava Settings View

import SwiftUI

struct StravaSettingsView: View {
    @EnvironmentObject var featureFlags: FeatureFlags
    @Environment(\.modelContext) private var modelContext

    let profile: UserProfile

    @StateObject private var stravaService = StravaService.shared
    @State private var showingWebAuth = false

    var body: some View {
        Form {
            Section {
                if stravaService.isConnected {
                    // Connected state
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading) {
                            Text("Connected")
                                .font(.headline)
                            if let athlete = stravaService.athleteProfile {
                                Text(athlete.displayName)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        Spacer()
                    }

                    HStack {
                        Text("Status")
                        Spacer()
                        if stravaService.isSyncing {
                            ProgressView()
                        } else {
                            Text("Ready")
                                .foregroundColor(.green)
                        }
                    }

                    if let lastSync = stravaService.lastSyncDate {
                        HStack {
                            Text("Last Sync")
                            Spacer()
                            Text(lastSync, style: .relative)
                                .foregroundColor(.gray)
                        }
                    }

                    HStack {
                        Text("Activities Imported")
                        Spacer()
                        Text("\(stravaService.importedActivityCount)")
                            .foregroundColor(.gray)
                    }

                    Button("Sync Now") {
                        Task {
                            await stravaService.syncActivities(userId: profile.id)
                        }
                    }
                    .disabled(stravaService.isSyncing)

                    Button("Disconnect", role: .destructive) {
                        stravaService.disconnect()
                        featureFlags.stravaImportEnabled = false
                    }

                } else {
                    // Not connected state
                    HStack {
                        Image("strava-logo")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundColor(.orange)
                        Text("Strava")
                            .font(.headline)
                        Spacer()
                        Text("Not Connected")
                            .foregroundColor(.gray)
                    }

                    if stravaService.isConfigured {
                        Button("Connect with Strava") {
                            showingWebAuth = true
                        }
                        .foregroundColor(.orange)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Strava integration requires setup")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                            Text("Add STRAVA_CLIENT_ID and STRAVA_CLIENT_SECRET to Info.plist")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }

            } header: {
                Text("Strava Integration")
            } footer: {
                Text("Connect your Strava account to automatically import runs, rides, and other activities. They'll appear in your feed tagged as \"Strava Import\".")
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Running & Trail Running", systemImage: "figure.run")
                    Label("Cycling & Mountain Biking", systemImage: "bicycle")
                    Label("Swimming", systemImage: "figure.pool.swim")
                    Label("HIIT & Crossfit", systemImage: "flame.fill")
                    Label("Yoga & Walking", systemImage: "figure.walk")
                }
                .font(.subheadline)
                .foregroundColor(.gray)
            } header: {
                Text("Supported Activity Types")
            }
        }
        .navigationTitle("Strava")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showingWebAuth) {
            if let url = stravaService.getAuthorizationURL() {
                StravaAuthWebView(url: url) { callbackURL in
                    Task {
                        let success = await stravaService.handleAuthCallback(url: callbackURL)
                        if success {
                            featureFlags.stravaImportEnabled = true
                            await stravaService.syncActivities(userId: profile.id)
                        }
                        showingWebAuth = false
                    }
                }
            }
        }
        .onAppear {
            stravaService.configure(modelContext: modelContext)
        }
    }
}

// MARK: - Strava Auth Web View

#if os(iOS)
import WebKit

struct StravaAuthWebView: UIViewRepresentable {
    let url: URL
    let onCallback: (URL) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: StravaAuthWebView

        init(_ parent: StravaAuthWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            if let url = navigationAction.request.url,
               url.scheme == "gymquest" {
                parent.onCallback(url)
                return .cancel
            }
            return .allow
        }
    }
}
#endif

#Preview {
    NavigationStack {
        StravaSettingsView(profile: UserProfile(name: "Ben", username: "ben"))
            .environmentObject(FeatureFlags.shared)
    }
    .preferredColorScheme(.light)
}
