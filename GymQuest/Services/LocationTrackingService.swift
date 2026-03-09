//
//  LocationTrackingService.swift
//  GymQuest
//
//  Created by Benjamin Hilderman
//
//  GPS location tracking for cardio workouts. Wraps CLLocationManager
//  to record route points, calculate live distance, and rolling pace.
//

import Foundation
import CoreLocation

@Observable
@MainActor
final class LocationTrackingService: NSObject {
    static let shared = LocationTrackingService()

    // MARK: - Public State

    private(set) var isTracking = false
    private(set) var routePoints: [RoutePoint] = []
    private(set) var currentDistance: Double = 0    // meters
    private(set) var currentPace: Double = 0        // seconds per kilometer
    private(set) var currentElevationGain: Double = 0 // meters

    var hasPermission: Bool {
        let status = locationManager.authorizationStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }

    var needsPermission: Bool {
        locationManager.authorizationStatus == .notDetermined
    }

    // MARK: - Private

    private let locationManager = CLLocationManager()
    private var workoutStartTime: Date?
    private var lastLocation: CLLocation?

    // Rolling pace: track recent points within a 60s window
    private struct TimedDistance {
        let timestamp: Date
        let distance: Double // meters for this segment
    }
    private var recentSegments: [TimedDistance] = []
    private var lastAltitude: Double?

    private override init() {
        super.init()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // meters — ~every 3s at running pace
        locationManager.activityType = .fitness
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.delegate = self
    }

    // MARK: - Public API

    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func startTracking() {
        guard !isTracking else { return }
        routePoints = []
        currentDistance = 0
        currentPace = 0
        currentElevationGain = 0
        lastLocation = nil
        lastAltitude = nil
        recentSegments = []
        workoutStartTime = Date()
        isTracking = true
        locationManager.startUpdatingLocation()
    }

    @discardableResult
    func stopTracking() -> [RoutePoint] {
        guard isTracking else { return routePoints }
        locationManager.stopUpdatingLocation()
        isTracking = false
        let result = routePoints
        lastLocation = nil
        return result
    }

    // MARK: - Processing

    private func processLocation(_ location: CLLocation) {
        // Filter inaccurate readings
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= 50 else { return }

        guard let startTime = workoutStartTime else { return }

        // Filter GPS teleportation (>100m jump in one update)
        if let last = lastLocation {
            let jump = location.distance(from: last)
            if jump > 100 { return }

            // Accumulate distance
            currentDistance += jump

            // Track segment for rolling pace
            let segment = TimedDistance(timestamp: location.timestamp, distance: jump)
            recentSegments.append(segment)
        }

        // Create route point
        let point = RoutePoint(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude,
            timestamp: location.timestamp.timeIntervalSince(startTime),
            speed: location.speed >= 0 ? location.speed : nil,
            horizontalAccuracy: location.horizontalAccuracy
        )
        routePoints.append(point)
        lastLocation = location

        // Accumulate elevation gain (filter noisy readings)
        if location.verticalAccuracy >= 0, location.verticalAccuracy <= 20 {
            let alt = location.altitude
            if let prev = lastAltitude {
                let delta = alt - prev
                if delta > 0.5 { currentElevationGain += delta }
            }
            lastAltitude = alt
        }

        // Calculate rolling 60s pace
        updateRollingPace(currentTime: location.timestamp)
    }

    private func updateRollingPace(currentTime: Date) {
        let windowStart = currentTime.addingTimeInterval(-60)
        recentSegments.removeAll { $0.timestamp < windowStart }

        let windowDistance = recentSegments.reduce(0.0) { $0 + $1.distance }
        let windowDistKm = windowDistance / 1000.0

        if windowDistKm > 0.01 { // avoid division by near-zero
            let windowSeconds = min(60.0, currentTime.timeIntervalSince(recentSegments.first?.timestamp ?? currentTime))
            currentPace = windowSeconds / windowDistKm
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationTrackingService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let locs = locations
        Task { @MainActor in
            for location in locs {
                processLocation(location)
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Authorization changes are observed via hasPermission/needsPermission
    }
}
