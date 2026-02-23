//
//  WhoopService.swift
//  GymQuest
//
//  WHOOP API integration service for GymQuest.
//  Fetches recovery, strain, sleep, and health monitor data.
//  Uses OAuth 2.0 for authentication with secure keychain storage.
//

import Foundation
import SwiftData
import AuthenticationServices
import Security

// MARK: - Keychain Helper for WHOOP Token Storage

private enum WhoopKeychainHelper {
    static let service = "com.liftai.whoop"

    static func save(_ data: String, forKey key: String) {
        guard let data = data.data(using: .utf8) else { return }
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)
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

// MARK: - WHOOP Service

@MainActor
class WhoopService: ObservableObject {
    static let shared = WhoopService()

    // WHOOP API configuration
    // To use WHOOP integration:
    // 1. Create an app at https://developer.whoop.com
    // 2. Add these keys to Info.plist:
    //    - WHOOP_CLIENT_ID: Your app's Client ID
    //    - WHOOP_CLIENT_SECRET: Your app's Client Secret
    // 3. Set the redirect URI to: gymquest://whoop-callback
    private var clientId: String {
        Bundle.main.infoDictionary?["WHOOP_CLIENT_ID"] as? String ?? ""
    }
    private var clientSecret: String {
        Bundle.main.infoDictionary?["WHOOP_CLIENT_SECRET"] as? String ?? ""
    }

    var isConfigured: Bool {
        !clientId.isEmpty && !clientSecret.isEmpty
    }
    private let redirectUri = "liftai://whoop-callback"
    private let scope = "read:recovery read:sleep read:workout read:profile read:body_measurement read:cycles"
    private let baseURL = "https://api.prod.whoop.com/developer/v1"

    @Published var isConnected = false
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var memberProfile: WhoopMember?

    // Latest data
    @Published var latestRecovery: WhoopRecovery?
    @Published var latestStrain: WhoopStrain?
    @Published var latestSleep: WhoopSleep?
    @Published var healthMonitor: WhoopHealthMonitor?

    private let defaults = UserDefaults.standard
    private let accessTokenKey = "whoop_access_token"
    private let refreshTokenKey = "whoop_refresh_token"
    private let tokenExpiryKey = "whoop_token_expiry"

    // MARK: - Connection Status

    func checkConnectionStatus() {
        let token = WhoopKeychainHelper.load(forKey: accessTokenKey)
        isConnected = !(token?.isEmpty ?? true)
    }

    var accessToken: String? {
        WhoopKeychainHelper.load(forKey: accessTokenKey)
    }

    // MARK: - OAuth Authentication

    func getAuthorizationURL() -> URL? {
        guard isConfigured else { return nil }
        var components = URLComponents(string: "https://api.prod.whoop.com/oauth/oauth2/auth")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "state", value: UUID().uuidString)
        ]
        return components?.url
    }

    func handleAuthCallback(url: URL) async -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            return false
        }
        return await exchangeCodeForToken(code: code)
    }

    private func exchangeCodeForToken(code: String) async -> Bool {
        guard let tokenURL = URL(string: "https://api.prod.whoop.com/oauth/oauth2/token") else {
            return false
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": redirectUri
        ]
        let bodyString = bodyParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return false }

            let tokenResponse = try JSONDecoder().decode(WhoopTokenResponse.self, from: data)
            WhoopKeychainHelper.save(tokenResponse.accessToken, forKey: accessTokenKey)
            WhoopKeychainHelper.save(tokenResponse.refreshToken, forKey: refreshTokenKey)
            defaults.set(Date().timeIntervalSince1970 + Double(tokenResponse.expiresIn), forKey: tokenExpiryKey)

            isConnected = true
            return true
        } catch {
            print("WHOOP token exchange failed: \(error)")
            return false
        }
    }

    private func refreshTokenIfNeeded() async -> Bool {
        guard let refreshToken = WhoopKeychainHelper.load(forKey: refreshTokenKey) else { return false }

        let expiry = defaults.double(forKey: tokenExpiryKey)
        if Date().timeIntervalSince1970 < expiry - 300 { return true }

        guard let tokenURL = URL(string: "https://api.prod.whoop.com/oauth/oauth2/token") else { return false }

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
                  httpResponse.statusCode == 200 else { return false }

            let tokenResponse = try JSONDecoder().decode(WhoopTokenResponse.self, from: data)
            WhoopKeychainHelper.save(tokenResponse.accessToken, forKey: accessTokenKey)
            WhoopKeychainHelper.save(tokenResponse.refreshToken, forKey: refreshTokenKey)
            defaults.set(Date().timeIntervalSince1970 + Double(tokenResponse.expiresIn), forKey: tokenExpiryKey)
            return true
        } catch {
            print("WHOOP token refresh failed: \(error)")
            return false
        }
    }

    func disconnect() {
        WhoopKeychainHelper.delete(forKey: accessTokenKey)
        WhoopKeychainHelper.delete(forKey: refreshTokenKey)
        defaults.removeObject(forKey: tokenExpiryKey)
        isConnected = false
        memberProfile = nil
        latestRecovery = nil
        latestStrain = nil
        latestSleep = nil
        healthMonitor = nil
    }

    // MARK: - API Requests

    private func authenticatedRequest(path: String, queryItems: [URLQueryItem]? = nil) async throws -> Data {
        guard await refreshTokenIfNeeded(),
              let token = accessToken else { throw WhoopError.authError }

        guard var components = URLComponents(string: "\(baseURL)\(path)") else {
            throw WhoopError.apiError("Invalid URL")
        }
        components.queryItems = queryItems

        guard let url = components.url else { throw WhoopError.apiError("Invalid URL") }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WhoopError.apiError("Invalid response")
        }

        if httpResponse.statusCode == 401 {
            throw WhoopError.authError
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw WhoopError.apiError("HTTP \(httpResponse.statusCode)")
        }

        return data
    }

    // MARK: - Data Fetching

    func fetchAllData() async {
        guard isConnected else { return }
        isSyncing = true
        defer { isSyncing = false }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        // Fetch profile
        do {
            let data = try await authenticatedRequest(path: "/user/profile/basic")
            memberProfile = try decoder.decode(WhoopMember.self, from: data)
        } catch {
            print("WHOOP profile fetch failed: \(error)")
        }

        // Fetch latest recovery
        do {
            let data = try await authenticatedRequest(
                path: "/recovery",
                queryItems: [URLQueryItem(name: "limit", value: "1")]
            )
            let response = try decoder.decode(WhoopPaginatedResponse<WhoopRecovery>.self, from: data)
            latestRecovery = response.records.first
        } catch {
            print("WHOOP recovery fetch failed: \(error)")
        }

        // Fetch latest cycle (strain)
        do {
            let data = try await authenticatedRequest(
                path: "/cycle",
                queryItems: [URLQueryItem(name: "limit", value: "1")]
            )
            let response = try decoder.decode(WhoopPaginatedResponse<WhoopStrain>.self, from: data)
            latestStrain = response.records.first
        } catch {
            print("WHOOP strain fetch failed: \(error)")
        }

        // Fetch latest sleep
        do {
            let data = try await authenticatedRequest(
                path: "/activity/sleep",
                queryItems: [URLQueryItem(name: "limit", value: "1")]
            )
            let response = try decoder.decode(WhoopPaginatedResponse<WhoopSleep>.self, from: data)
            latestSleep = response.records.first
        } catch {
            print("WHOOP sleep fetch failed: \(error)")
        }

        // Build health monitor from available data
        buildHealthMonitor()

        lastSyncDate = Date()
        defaults.set(lastSyncDate, forKey: "whoop_last_sync")
    }

    private func buildHealthMonitor() {
        guard let recovery = latestRecovery else { return }

        healthMonitor = WhoopHealthMonitor(
            restingHeartRate: recovery.score.restingHeartRate,
            hrvRmssd: recovery.score.hrvRmssdMilli,
            spo2Percentage: recovery.score.spo2Percentage,
            skinTempCelsius: recovery.score.skinTempCelsius,
            recoveryScore: recovery.score.recoveryScore,
            timestamp: Date()
        )
    }

    // MARK: - Workout Import

    func fetchWorkouts(since: Date) async -> [WhoopWorkout] {
        guard isConnected else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let formatter = ISO8601DateFormatter()
        let startParam = formatter.string(from: since)

        do {
            let data = try await authenticatedRequest(
                path: "/activity/workout",
                queryItems: [
                    URLQueryItem(name: "limit", value: "50"),
                    URLQueryItem(name: "start", value: startParam)
                ]
            )
            let response = try decoder.decode(WhoopPaginatedResponse<WhoopWorkout>.self, from: data)
            return response.records
        } catch {
            print("WHOOP workouts fetch failed: \(error)")
            return []
        }
    }
}

// MARK: - WHOOP API Models

struct WhoopTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

struct WhoopPaginatedResponse<T: Codable>: Codable {
    let records: [T]
    let nextToken: String?
}

struct WhoopMember: Codable {
    let userId: Int
    let firstName: String?
    let lastName: String?
    let email: String?

    var displayName: String {
        if let first = firstName, let last = lastName {
            return "\(first) \(last)"
        }
        return firstName ?? email ?? "WHOOP Member"
    }
}

struct WhoopRecovery: Codable, Identifiable {
    var id: Int { cycleId }
    let cycleId: Int
    let sleepId: Int
    let score: WhoopRecoveryScore
    let created: String?
}

struct WhoopRecoveryScore: Codable {
    let recoveryScore: Double        // 0-100%
    let restingHeartRate: Double     // bpm
    let hrvRmssdMilli: Double        // HRV in ms
    let spo2Percentage: Double?      // SpO2 %
    let skinTempCelsius: Double?     // skin temperature
    let userCalibrating: Bool
}

struct WhoopStrain: Codable, Identifiable {
    var id: Int { cycleId ?? 0 }
    let cycleId: Int?
    let score: WhoopStrainScore?
    let start: String?
    let end: String?
    let days: [String]?
}

struct WhoopStrainScore: Codable {
    let strain: Double             // 0-21 scale
    let kilojoule: Double          // energy burned
    let averageHeartRate: Int      // avg HR
    let maxHeartRate: Int          // max HR
}

struct WhoopSleep: Codable, Identifiable {
    var id: Int { sleepId ?? 0 }
    let sleepId: Int?
    let score: WhoopSleepScore?
    let start: String?
    let end: String?
    let nap: Bool?
}

struct WhoopSleepScore: Codable {
    let stageSummary: WhoopSleepStages
    let sleepNeeded: WhoopSleepNeeded?
    let sleepPerformancePercentage: Double?   // % of sleep need achieved
    let sleepConsistencyPercentage: Double?
    let sleepEfficiencyPercentage: Double?
    let respiratoryRate: Double?              // breaths/min
}

struct WhoopSleepStages: Codable {
    let totalInBedTimeMilli: Int
    let totalAwakeTimeMilli: Int
    let totalNoDataTimeMilli: Int
    let totalLightSleepTimeMilli: Int
    let totalSlowWaveSleepTimeMilli: Int   // deep sleep
    let totalRemSleepTimeMilli: Int
    let sleepCycleCount: Int
    let disturbanceCount: Int

    var totalSleepHours: Double {
        let totalSleepMilli = totalLightSleepTimeMilli + totalSlowWaveSleepTimeMilli + totalRemSleepTimeMilli
        return Double(totalSleepMilli) / 3_600_000.0
    }
}

struct WhoopSleepNeeded: Codable {
    let baselineMilli: Int
    let needFromSleepDebtMilli: Int
    let needFromRecentStrainMilli: Int
    let needFromRecentNapMilli: Int
}

struct WhoopWorkout: Codable, Identifiable {
    var id: Int { workoutId ?? 0 }
    let workoutId: Int?
    let sportId: Int
    let score: WhoopWorkoutScore?
    let start: String?
    let end: String?
    let timezoneOffset: String?
}

struct WhoopWorkoutScore: Codable {
    let strain: Double
    let averageHeartRate: Int
    let maxHeartRate: Int
    let kilojoule: Double
    let percentRecorded: Double?
    let distanceMeter: Double?
    let altitudeGainMeter: Double?
    let altitudeLossMeter: Double?
    let zoneZeroMilli: Int?
    let zoneOneMilli: Int?
    let zoneTwoMilli: Int?
    let zoneThreeMilli: Int?
    let zoneFourMilli: Int?
    let zoneFiveMilli: Int?
}

// MARK: - Health Monitor (Unified vitals snapshot)

struct WhoopHealthMonitor {
    let restingHeartRate: Double    // bpm
    let hrvRmssd: Double            // ms
    let spo2Percentage: Double?     // %
    let skinTempCelsius: Double?    // °C
    let recoveryScore: Double       // 0-100
    let timestamp: Date

    var recoveryColor: RecoveryZone {
        if recoveryScore >= 67 { return .green }
        if recoveryScore >= 34 { return .yellow }
        return .red
    }

    enum RecoveryZone: String {
        case green = "Green"
        case yellow = "Yellow"
        case red = "Red"
    }
}

enum WhoopError: Error {
    case authError
    case apiError(String)
    case networkError
}

// MARK: - WHOOP Sport ID Mapping

extension WhoopWorkout {
    var workoutType: WorkoutType {
        // WHOOP sport IDs (common ones)
        switch sportId {
        case 1:  return .fullBody   // Activity
        case 0:  return .fullBody   // Running
        case 33: return .push       // Weightlifting
        case 44: return .fullBody   // Functional Fitness
        case 63: return .fullBody   // HIIT
        case 71: return .cardio     // Cycling
        case 52: return .cardio     // Swimming
        case 56: return .rest       // Yoga
        case 48: return .cardio     // Running (outdoor)
        default: return .fullBody
        }
    }

    var displayName: String {
        switch sportId {
        case 1:  return "Activity"
        case 0:  return "Running"
        case 33: return "Weightlifting"
        case 44: return "Functional Fitness"
        case 63: return "HIIT"
        case 71: return "Cycling"
        case 52: return "Swimming"
        case 56: return "Yoga"
        case 48: return "Running"
        case 43: return "CrossFit"
        case 47: return "Tennis"
        case 50: return "Basketball"
        case 51: return "Boxing"
        default: return "Workout"
        }
    }
}
