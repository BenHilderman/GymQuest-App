//
//  TrainingPlanService.swift
//  GymQuest
//
//  AI-powered training plan generation. Builds structured multi-week plans
//  based on user profile, goals, and workout history. Plans can be converted
//  to live workout sessions.
//

import Foundation
import SwiftData

@MainActor
class TrainingPlanService {
    static let shared = TrainingPlanService()

    /// Generate an AI training plan using the user's AI provider
    func generatePlan(
        profile: UserProfile,
        workouts: [Workout],
        weeks: Int = 4,
        modelContext: ModelContext
    ) async throws -> TrainingPlan {
        let aiService = AIService()

        let prompt = buildPlanPrompt(profile: profile, workouts: workouts, weeks: weeks)

        let response = try await aiService.chat(
            prompt: prompt,
            profile: profile,
            workouts: workouts,
            modelContext: modelContext
        )

        // Try to parse JSON plan from response
        if let plan = parsePlanFromResponse(response, weeks: weeks, userId: profile.id) {
            modelContext.insert(plan)
            try? modelContext.save()
            return plan
        }

        // Fallback to demo plan
        let demoPlan = buildDemoPlan(profile: profile, weeks: weeks)
        modelContext.insert(demoPlan)
        try? modelContext.save()
        return demoPlan
    }

    /// Convert a training plan day into ActiveExercise array for starting a workout
    func planDayToActiveExercises(_ day: TrainingPlanDay) -> [ActiveExercise] {
        day.exercises.map { planExercise in
            let sets = (0..<planExercise.sets).map { _ in
                ActiveSet(
                    reps: planExercise.reps,
                    weight: planExercise.weight ?? 0
                )
            }
            // Map exercise name to muscle group using database
            let muscleGroup = ExtendedExerciseDatabase.find(planExercise.name)?.muscleGroup ?? .fullBody
            return ActiveExercise(
                name: planExercise.name,
                muscleGroup: muscleGroup,
                sets: sets
            )
        }
    }

    // MARK: - Private Helpers

    private func buildPlanPrompt(profile: UserProfile, workouts: [Workout], weeks: Int) -> String {
        let goal = profile.goal.rawValue
        let days = profile.daysPerWeek
        let experience = profile.experienceLevel?.rawValue ?? "intermediate"
        let equipment = profile.availableEquipment.map(\.rawValue).joined(separator: ", ")

        return """
        Generate a \(weeks)-week training plan as JSON. User info:
        - Goal: \(goal)
        - Days/week: \(days)
        - Experience: \(experience)
        - Equipment: \(equipment.isEmpty ? "full gym" : equipment)
        - Injuries: \(profile.injuries.isEmpty ? "none" : profile.injuries)

        Return ONLY valid JSON in this format:
        {"weeks":[{"weekNumber":1,"focus":"Volume","days":[{"dayNumber":1,"label":"Push Day","workoutType":"push","isRestDay":false,"exercises":[{"name":"Bench Press","sets":4,"reps":8,"weight":135,"rpe":7}]}]}]}

        Rules:
        - Include rest days as {"dayNumber":X,"label":"Rest","workoutType":"rest","isRestDay":true,"exercises":[]}
        - Use real exercise names from a standard gym
        - Progressive overload across weeks (increase weight or volume)
        - Week \(weeks) should be a deload week (reduce volume 40%)
        - Match the user's goal: hypertrophy (8-12 reps), strength (3-6 reps), performance (varies)
        """
    }

    private func parsePlanFromResponse(_ response: String, weeks: Int, userId: UUID) -> TrainingPlan? {
        // Extract JSON from response (may be wrapped in markdown code blocks)
        let cleaned = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else { return nil }

        struct PlanResponse: Codable {
            let weeks: [TrainingPlanWeek]
        }

        guard let parsed = try? JSONDecoder().decode(PlanResponse.self, from: data) else {
            return nil
        }

        return TrainingPlan(
            userId: userId,
            title: "AI Training Plan (\(weeks) weeks)",
            weeks: parsed.weeks
        )
    }

    /// Hardcoded 4-week plan as fallback when AI is unavailable
    func buildDemoPlan(profile: UserProfile, weeks: Int = 4) -> TrainingPlan {
        let daysPerWeek = profile.daysPerWeek

        var planWeeks: [TrainingPlanWeek] = []

        for weekNum in 1...weeks {
            let isDeload = weekNum == weeks
            let volumeMultiplier = isDeload ? 0.6 : 1.0
            var days: [TrainingPlanDay] = []

            for dayNum in 1...7 {
                if dayNum <= daysPerWeek {
                    let (label, type, exercises) = dayTemplate(
                        dayIndex: dayNum - 1,
                        daysPerWeek: daysPerWeek,
                        volumeMultiplier: volumeMultiplier,
                        weekNum: weekNum
                    )
                    days.append(TrainingPlanDay(
                        dayNumber: dayNum,
                        label: label,
                        workoutType: type,
                        exercises: exercises,
                        isRestDay: false
                    ))
                } else {
                    days.append(TrainingPlanDay(
                        dayNumber: dayNum,
                        label: "Rest",
                        workoutType: "rest",
                        exercises: [],
                        isRestDay: true
                    ))
                }
            }

            let focus = isDeload ? "Deload" : (weekNum <= 2 ? "Volume" : "Intensity")
            planWeeks.append(TrainingPlanWeek(weekNumber: weekNum, focus: focus, days: days))
        }

        return TrainingPlan(
            userId: profile.id,
            title: "Lift AI Plan (\(weeks) weeks)",
            weeks: planWeeks
        )
    }

    private func dayTemplate(
        dayIndex: Int,
        daysPerWeek: Int,
        volumeMultiplier: Double,
        weekNum: Int
    ) -> (String, String, [TrainingPlanExercise]) {
        let templates: [(String, String, [TrainingPlanExercise])] = [
            ("Push Day", "push", [
                TrainingPlanExercise(name: "Bench Press", sets: Int(4 * volumeMultiplier), reps: 8, weight: 135, rpe: 7),
                TrainingPlanExercise(name: "Overhead Press", sets: Int(3 * volumeMultiplier), reps: 10, weight: 85, rpe: 7),
                TrainingPlanExercise(name: "Incline Dumbbell Press", sets: Int(3 * volumeMultiplier), reps: 10, weight: 50, rpe: 7),
                TrainingPlanExercise(name: "Lateral Raises", sets: Int(3 * volumeMultiplier), reps: 15, weight: 15, rpe: 8),
                TrainingPlanExercise(name: "Tricep Pushdowns", sets: Int(3 * volumeMultiplier), reps: 12, weight: 40, rpe: 7),
            ]),
            ("Pull Day", "pull", [
                TrainingPlanExercise(name: "Barbell Row", sets: Int(4 * volumeMultiplier), reps: 8, weight: 135, rpe: 7),
                TrainingPlanExercise(name: "Pull-Ups", sets: Int(3 * volumeMultiplier), reps: 8, weight: 0, rpe: 8),
                TrainingPlanExercise(name: "Cable Rows", sets: Int(3 * volumeMultiplier), reps: 10, weight: 120, rpe: 7),
                TrainingPlanExercise(name: "Face Pulls", sets: Int(3 * volumeMultiplier), reps: 15, weight: 30, rpe: 7),
                TrainingPlanExercise(name: "Barbell Curls", sets: Int(3 * volumeMultiplier), reps: 10, weight: 50, rpe: 7),
            ]),
            ("Legs Day", "legs", [
                TrainingPlanExercise(name: "Barbell Squat", sets: Int(4 * volumeMultiplier), reps: 6, weight: 185, rpe: 8),
                TrainingPlanExercise(name: "Romanian Deadlift", sets: Int(3 * volumeMultiplier), reps: 10, weight: 135, rpe: 7),
                TrainingPlanExercise(name: "Leg Press", sets: Int(3 * volumeMultiplier), reps: 12, weight: 270, rpe: 7),
                TrainingPlanExercise(name: "Leg Curls", sets: Int(3 * volumeMultiplier), reps: 12, weight: 80, rpe: 7),
                TrainingPlanExercise(name: "Calf Raises", sets: Int(4 * volumeMultiplier), reps: 15, weight: 100, rpe: 7),
            ]),
            ("Upper Body", "upper", [
                TrainingPlanExercise(name: "Bench Press", sets: Int(4 * volumeMultiplier), reps: 6, weight: 155, rpe: 8),
                TrainingPlanExercise(name: "Barbell Row", sets: Int(4 * volumeMultiplier), reps: 6, weight: 145, rpe: 8),
                TrainingPlanExercise(name: "Overhead Press", sets: Int(3 * volumeMultiplier), reps: 8, weight: 95, rpe: 7),
                TrainingPlanExercise(name: "Chin-Ups", sets: Int(3 * volumeMultiplier), reps: 8, weight: 0, rpe: 8),
                TrainingPlanExercise(name: "Dumbbell Flyes", sets: Int(3 * volumeMultiplier), reps: 12, weight: 30, rpe: 7),
            ]),
            ("Lower Body", "lower", [
                TrainingPlanExercise(name: "Deadlift", sets: Int(4 * volumeMultiplier), reps: 5, weight: 225, rpe: 8),
                TrainingPlanExercise(name: "Front Squat", sets: Int(3 * volumeMultiplier), reps: 8, weight: 135, rpe: 7),
                TrainingPlanExercise(name: "Bulgarian Split Squat", sets: Int(3 * volumeMultiplier), reps: 10, weight: 40, rpe: 7),
                TrainingPlanExercise(name: "Hip Thrusts", sets: Int(3 * volumeMultiplier), reps: 12, weight: 135, rpe: 7),
                TrainingPlanExercise(name: "Leg Extensions", sets: Int(3 * volumeMultiplier), reps: 12, weight: 90, rpe: 7),
            ]),
            ("Full Body", "fullBody", [
                TrainingPlanExercise(name: "Barbell Squat", sets: Int(3 * volumeMultiplier), reps: 8, weight: 165, rpe: 7),
                TrainingPlanExercise(name: "Bench Press", sets: Int(3 * volumeMultiplier), reps: 8, weight: 135, rpe: 7),
                TrainingPlanExercise(name: "Barbell Row", sets: Int(3 * volumeMultiplier), reps: 8, weight: 125, rpe: 7),
                TrainingPlanExercise(name: "Overhead Press", sets: Int(3 * volumeMultiplier), reps: 10, weight: 75, rpe: 7),
                TrainingPlanExercise(name: "Romanian Deadlift", sets: Int(3 * volumeMultiplier), reps: 10, weight: 135, rpe: 7),
            ]),
        ]

        let index = dayIndex % templates.count
        return templates[index]
    }
}
