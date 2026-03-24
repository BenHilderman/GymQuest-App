//
//  SupabaseSyncService.swift
//  GymQuest
//
//  Central sync manager for bidirectional data sync with Supabase.
//

import Foundation
import SwiftData
import Supabase
import Realtime

@MainActor
final class SupabaseSyncService: ObservableObject {
    static let shared = SupabaseSyncService()

    var modelContext: ModelContext?
    var currentUserId: UUID?

    private var notificationsChannel: RealtimeChannelV2?

    private init() {}

    // MARK: - Configuration

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Sync Lifecycle

    func startSync(userId: UUID) {
        self.currentUserId = userId
        subscribeToNotifications(userId: userId) { notification in
            print("[SupabaseSyncService] New notification: \(notification.type)")
        }
    }

    func stopSync() {
        Task {
            if let channel = notificationsChannel {
                await SupabaseConfig.client.realtimeV2.removeChannel(channel)
            }
            notificationsChannel = nil
            currentUserId = nil
        }
    }

    // MARK: - CRUD Operations

    func insert<T: Encodable>(_ dto: T, table: String) async throws {
        guard FeatureFlags.shared.supabaseSyncEnabled else { return }
        try await SupabaseConfig.client.from(table).insert(dto).execute()
    }

    func update<T: Encodable>(_ dto: T, table: String, id: UUID) async throws {
        guard FeatureFlags.shared.supabaseSyncEnabled else { return }
        try await SupabaseConfig.client.from(table).update(dto).eq("id", value: id.uuidString).execute()
    }

    func delete(table: String, id: UUID) async throws {
        guard FeatureFlags.shared.supabaseSyncEnabled else { return }
        try await SupabaseConfig.client.from(table).delete().eq("id", value: id.uuidString).execute()
    }

    func fetch<T: Decodable>(from table: String, configure: ((PostgrestFilterBuilder) -> PostgrestTransformBuilder)? = nil) async throws -> [T] {
        let query = SupabaseConfig.client.from(table).select()
        if let configure {
            let finalQuery = configure(query)
            let response: [T] = try await finalQuery.execute().value
            return response
        } else {
            let response: [T] = try await query.execute().value
            return response
        }
    }

    // MARK: - Workout Sync

    func syncWorkout(_ workout: Workout) async throws {
        guard FeatureFlags.shared.supabaseSyncEnabled,
              let userId = SupabaseAuthService.shared.currentUserId else { return }

        // 1. Insert workout
        let workoutDTO = WorkoutDTO(
            id: workout.id,
            userId: userId,
            workoutType: workout.type.rawValue,
            title: workout.title,
            duration: workout.duration,
            totalVolume: workout.totalVolume,
            setCount: workout.totalSets,
            exerciseCount: workout.exercises.count,
            caloriesBurned: nil,
            notes: workout.notes.isEmpty ? nil : workout.notes,
            startedAt: workout.date,
            completedAt: workout.createdAt,
            createdAt: workout.createdAt
        )
        try await insert(workoutDTO, table: "workouts")

        // 2. Insert exercises and their sets
        for (index, exercise) in workout.exercises.enumerated() {
            let exerciseDTO = WorkoutExerciseDTO(
                id: exercise.id,
                workoutId: workout.id,
                name: exercise.name,
                muscleGroup: exercise.muscleGroup.rawValue,
                exerciseOrder: index,
                notes: nil
            )
            try await insert(exerciseDTO, table: "workout_exercises")

            // 3. Insert sets
            for (setIndex, exerciseSet) in exercise.sets.enumerated() {
                let setDTO = ExerciseSetDTO(
                    id: exerciseSet.id,
                    exerciseId: exercise.id,
                    setOrder: setIndex,
                    reps: exerciseSet.reps,
                    weight: exerciseSet.weight,
                    isCompleted: true,
                    rpe: exerciseSet.rpe,
                    createdAt: nil
                )
                try await insert(setDTO, table: "exercise_sets")
            }
        }
    }

    // MARK: - Realtime Subscriptions

    func subscribeToNotifications(userId: UUID, onNew: @escaping (NotificationDTO) -> Void) {
        let channel = SupabaseConfig.client.realtimeV2.channel("notifications:\(userId.uuidString)")

        let insertions = channel.postgresChange(InsertAction.self, schema: "public", table: "notifications", filter: "user_id=eq.\(userId.uuidString)")

        self.notificationsChannel = channel

        Task {
            await channel.subscribe()

            for await insertion in insertions {
                do {
                    let notification = try insertion.decodeRecord(as: NotificationDTO.self, decoder: JSONDecoder())
                    await MainActor.run {
                        onNew(notification)
                    }
                } catch {
                    print("[SupabaseSyncService] Failed to decode notification: \(error)")
                }
            }
        }
    }
}
