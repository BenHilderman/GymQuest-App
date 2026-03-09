//
//  TodayDashboardSection.swift
//  GymQuest
//
//  Created by Benjamin Hilderman
//
//  Compact daily stats + quick-log actions for the Home feed.
//

import SwiftUI
import SwiftData

struct TodayDashboardSection: View {
    let profile: UserProfile
    let workoutsThisWeek: Int
    let allWorkouts: [Workout]

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var measurements: [BodyMeasurement]
    @StateObject private var healthKit = HealthKitService.shared

    @State private var todayCalories: Int = 0
    @State private var todayProtein: Int = 0
    @State private var nutritionStreak: Int = 0
    @State private var showingMealLog = false
    @State private var showingAddMeasurement = false

    private var latestWeight: BodyMeasurement? {
        measurements.first { $0.userId == profile.id && $0.type == .weight }
    }

    var body: some View {
        VStack(spacing: 8) {
            // Stats row
            HStack(spacing: 0) {
                stat(todayCalories > 0 ? "\(todayCalories)" : "0", "cal")
                divider
                stat(todayProtein > 0 ? "\(todayProtein)g" : "0g", "protein")
                divider
                stat(healthKit.steps > 0 ? formatSteps(healthKit.steps) : "--", "steps")
                divider
                stat(latestWeight.map { formatWeight($0.value) } ?? "--", "lbs")
            }

            // Quick-log buttons
            HStack(spacing: 8) {
                logButton("Log Food") { showingMealLog = true }
                logButton("Log Weight") { showingAddMeasurement = true }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .homeSocialCard(cornerRadius: 16)
        .onAppear { loadTodayData() }
        .onChange(of: showingMealLog) { _, showing in
            if !showing { loadTodayData() }
        }
        .onChange(of: showingAddMeasurement) { _, showing in
            if !showing { loadTodayData() }
        }
        .sheet(isPresented: $showingMealLog) {
            MealLogView(profile: profile)
        }
        .sheet(isPresented: $showingAddMeasurement) {
            AddMeasurementSheet(profile: profile, measurementType: .weight)
        }
    }

    // MARK: - Components

    @ViewBuilder
    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(GQColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(GQColors.borderSubtle)
            .frame(width: 1, height: 24)
    }

    @ViewBuilder
    private func logButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("+ \(title)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(GQColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(GQColors.adaptiveOverlay(0.05))
                .cornerRadius(8)
        }
        .buttonStyle(GQInteractiveStyle())
    }

    // MARK: - Data Loading

    private func loadTodayData() {
        let service = NutritionService.shared
        service.configure(modelContext: modelContext)
        let meals = service.getTodaysMeals(userId: profile.id)
        todayCalories = meals.reduce(0) { $0 + ($1.estimatedCalories ?? 0) }
        todayProtein = meals.reduce(0) { $0 + ($1.estimatedProtein ?? 0) }
        nutritionStreak = service.calculateNutritionStreak(userId: profile.id)
    }

    // MARK: - Formatters

    private func formatSteps(_ steps: Int) -> String {
        if steps >= 1000 {
            let k = Double(steps) / 1000.0
            return String(format: "%.1fk", k)
        }
        return "\(steps)"
    }

    private func formatWeight(_ value: Double) -> String {
        if value == value.rounded() {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }
}
