//
//  NutritionService.swift
//  GymQuest
//
//  Nutrition tracking service for GymQuest 2.0.
//  Performance-first approach: photo + quick tags + how you felt.
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
class NutritionService: ObservableObject {
    static let shared = NutritionService()

    private var modelContext: ModelContext?

    @Published var todaysMeals: [MealLog] = []
    @Published var nutritionStreak: Int = 0

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Meal Logging

    /// Log a new meal
    func logMeal(
        userId: UUID,
        mealType: MealType,
        description: String,
        tags: [String],
        photoData: Data?,
        feeling: MealFeeling,
        notes: String = ""
    ) -> MealLog? {
        guard let context = modelContext else { return nil }

        let meal = MealLog(
            odId: userId,
            mealType: mealType,
            mealDescription: description,
            photoData: photoData,
            tags: tags,
            feeling: feeling,
            notes: notes
        )

        context.insert(meal)
        try? context.save()

        // Track analytics
        AnalyticsService.shared.trackMealLogged(
            userId: userId,
            mealType: mealType.rawValue,
            hasTags: !tags.isEmpty,
            hasPhoto: photoData != nil
        )

        return meal
    }

    /// Get today's meals for a user
    func getTodaysMeals(userId: UUID) -> [MealLog] {
        guard let context = modelContext else { return [] }

        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today

        let descriptor = FetchDescriptor<MealLog>(
            predicate: #Predicate {
                $0.odId == userId && $0.dateTime >= today && $0.dateTime < tomorrow
            },
            sortBy: [SortDescriptor(\.dateTime, order: .forward)]
        )

        return (try? context.fetch(descriptor)) ?? []
    }

    /// Get meals for a specific date range
    func getMeals(userId: UUID, from: Date, to: Date) -> [MealLog] {
        guard let context = modelContext else { return [] }

        let descriptor = FetchDescriptor<MealLog>(
            predicate: #Predicate {
                $0.odId == userId && $0.dateTime >= from && $0.dateTime < to
            },
            sortBy: [SortDescriptor(\.dateTime, order: .forward)]
        )

        return (try? context.fetch(descriptor)) ?? []
    }

    /// Delete a meal
    func deleteMeal(_ meal: MealLog) {
        guard let context = modelContext else { return }
        context.delete(meal)
        try? context.save()
    }

    // MARK: - Statistics

    /// Calculate nutrition streak (consecutive days with logged meals)
    func calculateNutritionStreak(userId: UUID) -> Int {
        guard let context = modelContext else { return 0 }

        let descriptor = FetchDescriptor<MealLog>(
            predicate: #Predicate { $0.odId == userId },
            sortBy: [SortDescriptor(\.dateTime, order: .reverse)]
        )

        guard let meals = try? context.fetch(descriptor) else { return 0 }

        var streak = 0
        var checkDate = Calendar.current.startOfDay(for: Date())

        for _ in 0..<365 {
            let dayStart = checkDate
            let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: checkDate) ?? checkDate

            let hasMeal = meals.contains { $0.dateTime >= dayStart && $0.dateTime < dayEnd }

            if hasMeal {
                streak += 1
            } else if streak > 0 {
                break
            }

            checkDate = Calendar.current.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }

        return streak
    }

    /// Get weekly nutrition summary
    func getWeeklySummary(userId: UUID) -> NutritionWeeklySummary {
        let weekStart = Calendar.current.startOfWeek(for: Date())
        let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? Date()

        let meals = getMeals(userId: userId, from: weekStart, to: weekEnd)

        // Count meals by type
        var mealCounts: [MealType: Int] = [:]
        var feelingCounts: [MealFeeling: Int] = [:]
        var tagCounts: [String: Int] = [:]

        for meal in meals {
            mealCounts[meal.mealType, default: 0] += 1
            feelingCounts[meal.feeling, default: 0] += 1

            for tag in meal.tags {
                tagCounts[tag.lowercased(), default: 0] += 1
            }
        }

        // Get top tags
        let topTags = tagCounts.sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }

        // Calculate days with meals
        var daysWithMeals = Set<Date>()
        for meal in meals {
            let day = Calendar.current.startOfDay(for: meal.dateTime)
            daysWithMeals.insert(day)
        }

        return NutritionWeeklySummary(
            totalMeals: meals.count,
            mealCounts: mealCounts,
            feelingCounts: feelingCounts,
            topTags: Array(topTags),
            daysTracked: daysWithMeals.count
        )
    }

    // MARK: - Tag Suggestions

    /// Get suggested tags based on meal type and history
    func getSuggestedTags(userId: UUID, mealType: MealType) -> [String] {
        guard let context = modelContext else { return defaultTags(for: mealType) }

        // Get recent meals of same type
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<MealLog>(
            predicate: #Predicate {
                $0.odId == userId && $0.dateTime >= weekAgo
            },
            sortBy: [SortDescriptor(\.dateTime, order: .reverse)]
        )

        guard let recentMeals = try? context.fetch(descriptor) else {
            return defaultTags(for: mealType)
        }

        // Count tag frequency
        var tagCounts: [String: Int] = [:]
        for meal in recentMeals {
            for tag in meal.tags {
                tagCounts[tag.lowercased(), default: 0] += 1
            }
        }

        // Return top tags, falling back to defaults if not enough history
        let topTags = tagCounts.sorted { $0.value > $1.value }
            .prefix(8)
            .map { $0.key }

        if topTags.count >= 4 {
            return Array(topTags)
        }

        return defaultTags(for: mealType)
    }

    private func defaultTags(for mealType: MealType) -> [String] {
        let commonTags = ["high protein", "balanced", "home cooked", "meal prep", "quick", "vegetarian"]

        switch mealType {
        case .breakfast:
            return ["eggs", "oatmeal", "smoothie", "coffee"] + commonTags
        case .lunch:
            return ["salad", "sandwich", "chicken", "rice"] + commonTags
        case .dinner:
            return ["chicken", "fish", "pasta", "vegetables"] + commonTags
        case .snack:
            return ["protein bar", "fruit", "nuts", "yogurt", "shake"]
        case .preworkout:
            return ["banana", "coffee", "rice cakes", "light", "carbs"]
        case .postworkout:
            return ["protein shake", "chicken", "high protein", "recovery"]
        }
    }
}

// MARK: - Nutrition Summary

struct NutritionWeeklySummary {
    let totalMeals: Int
    let mealCounts: [MealType: Int]
    let feelingCounts: [MealFeeling: Int]
    let topTags: [String]
    let daysTracked: Int
}

// MARK: - Analytics Extension

extension AnalyticsService {
    func trackMealLogged(userId: UUID, mealType: String, hasTags: Bool, hasPhoto: Bool) {
        trackEvent(
            eventName: "meal_logged",
            properties: [
                "user_id": userId.uuidString,
                "meal_type": mealType,
                "has_tags": "\(hasTags)",
                "has_photo": "\(hasPhoto)"
            ]
        )
    }
}
