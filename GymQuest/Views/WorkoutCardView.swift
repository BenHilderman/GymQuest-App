//
//  WorkoutCardView.swift
//  GymQuest
//
//  Created by Benjamin Hilderman
//
//  The shareable workout card - like Strava's route map but for lifting.
//  Auto-generated after each workout, shows exercises, PRs, and coach insights.
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct WorkoutCardView: View {
    let workout: Workout
    let profile: UserProfile
    let streakCount: Int
    let xpEarned: Int
    let prMoments: [PRMoment]
    let coachTakeaway: String?
    let fistBumpCount: Int

    @State private var isLiked = false

    var body: some View {
        VStack(spacing: 0) {
            // header
            CardHeader(
                workout: workout,
                profile: profile,
                streakCount: streakCount,
                xpEarned: xpEarned
            )

            // pr callout (if any)
            if !prMoments.isEmpty {
                PRCallout(prMoments: prMoments)
            }

            // exercise list
            ExerciseList(workout: workout)

            // coach takeaway
            if let takeaway = coachTakeaway, !takeaway.isEmpty {
                CoachTakeawaySection(takeaway: takeaway)
            }

            // footer stats
            CardFooter(
                workout: workout,
                fistBumpCount: fistBumpCount,
                isLiked: $isLiked
            )
        }
        .workoutFlowCard(accent: GQColors.vividPurple, cornerRadius: 16)
    }
}

struct CardHeader: View {
    let workout: Workout
    let profile: UserProfile
    let streakCount: Int
    let xpEarned: Int

    var body: some View {
        HStack(spacing: 12) {
            // streak badge
            if streakCount >= 3 {
                StreakBadge(count: streakCount)
            } else {
                // workout type icon
                Circle()
                    .fill(LinearGradient(
                        colors: [GQColors.deepBlue, GQColors.vividPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: workout.type.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("@\(profile.username)")
                        .font(.system(size: 15, weight: .semibold))

                    Text("·")
                        .foregroundColor(GQColors.textTertiary)

                    Text(workout.type.rawValue)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }

                Text("\(workout.date.formatted(date: .abbreviated, time: .omitted)) · \(workout.duration) min")
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textTertiary)
            }

            Spacer()

            // xp earned
            VStack(alignment: .trailing, spacing: 2) {
                Text("+\(xpEarned) XP")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(GQColors.cyanSpark)
            }
        }
        .padding(16)
    }
}

struct StreakBadge: View {
    let count: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [GQColors.vividPurple, GQColors.cyanSpark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)

            VStack(spacing: -2) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14))
                Text("\(count)")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(.white)
        }
    }
}

struct PRCallout: View {
    let prMoments: [PRMoment]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(prMoments.prefix(2)) { pr in
                HStack(spacing: 10) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 16))
                        .foregroundColor(GQColors.cyanSpark)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("NEW PR")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(GQColors.cyanSpark)

                        HStack(spacing: 4) {
                            if let exercise = pr.exerciseName {
                                Text(exercise)
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            Text(pr.value)
                                .font(.system(size: 15, weight: .semibold))
                        }

                        if let improvement = pr.improvement {
                            Text(improvement)
                                .font(.system(size: 12))
                                .foregroundColor(GQColors.success)
                        }
                    }

                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(GQColors.surfaceElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}

struct ExerciseList: View {
    let workout: Workout
    let maxExercises = 5

    var sortedExercises: [Exercise] {
        workout.exercises.sorted { $0.order < $1.order }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(sortedExercises.prefix(maxExercises)) { exercise in
                CardExerciseRow(exercise: exercise)
            }

            if sortedExercises.count > maxExercises {
                Text("+\(sortedExercises.count - maxExercises) more exercises")
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textTertiary)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}

struct CardExerciseRow: View {
    let exercise: Exercise

    var setsDisplay: String {
        let sets = exercise.sets.sorted { $0.order < $1.order }
        guard !sets.isEmpty else { return "" }

        // find most common rep count
        let reps = sets.map { $0.reps }
        let avgReps = reps.isEmpty ? 0 : reps.reduce(0, +) / reps.count

        // find max weight
        let maxWeight = sets.map { $0.weight }.max() ?? 0

        if maxWeight > 0 {
            return "\(sets.count)×\(avgReps) @ \(Int(maxWeight)) lbs"
        }
        return "\(sets.count)×\(avgReps)"
    }

    var body: some View {
        HStack {
            Text(exercise.name)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.9))

            Spacer()

            Text(setsDisplay)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

struct CoachTakeawaySection: View {
    let takeaway: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 16))
                .foregroundColor(GQColors.cyanSpark)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text("COACH SAYS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(GQColors.cyanSpark.opacity(0.85))

                Text(takeaway)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(2)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(GQColors.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}

struct CardFooter: View {
    let workout: Workout
    let fistBumpCount: Int
    @Binding var isLiked: Bool

    var avgRPE: Double {
        let allRPEs = workout.exercises.flatMap { $0.sets.compactMap { $0.rpe } }
        guard !allRPEs.isEmpty else { return Double(workout.rpe) }
        return Double(allRPEs.reduce(0, +)) / Double(allRPEs.count)
    }

    var body: some View {
        VStack(spacing: 12) {
            // stats line
            HStack(spacing: 16) {
                Label("\(workout.totalSets) sets", systemImage: "square.stack.fill")
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textTertiary)

                Label(String(format: "RPE %.1f", avgRPE), systemImage: "gauge.medium")
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textTertiary)

                Spacer()
            }

            Divider()
                .background(Color.white.opacity(0.1))

            // actions row
            HStack(spacing: 24) {
                // fist bump button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isLiked.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("👊")
                            .font(.system(size: 20))
                            .scaleEffect(isLiked ? 1.2 : 1.0)

                        if fistBumpCount > 0 || isLiked {
                            Text("\(fistBumpCount + (isLiked ? 1 : 0))")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                .buttonStyle(GQInteractiveStyle())

                Spacer()
            }
        }
        .padding(16)
    }
}

struct ShareableWorkoutCard: View {
    let workout: Workout
    let profile: UserProfile
    let streakCount: Int
    let xpEarned: Int
    let prMoments: [PRMoment]
    let coachTakeaway: String?

    var body: some View {
        VStack(spacing: 0) {
            // branded header
            HStack {
                Text("GYMQUEST")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(2)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            WorkoutCardView(
                workout: workout,
                profile: profile,
                streakCount: streakCount,
                xpEarned: xpEarned,
                prMoments: prMoments,
                coachTakeaway: coachTakeaway,
                fistBumpCount: 0
            )
        }
        .background(GQColors.surfaceBase)
    }

    #if canImport(UIKit)
    @MainActor
    func renderToImage() -> UIImage? {
        let renderer = ImageRenderer(content: self.frame(width: 360))
        renderer.scale = 3.0
        return renderer.uiImage
    }
    #endif
}

private struct WorkoutCardPreviewHelper {
    static func makePreviewWorkout() -> Workout {
        let workout = Workout(
            date: Date(),
            type: .push,
            duration: 52,
            rpe: 7
        )

        let benchPress = Exercise(name: "Bench Press", muscleGroup: .chest, order: 0)
        benchPress.sets = [
            ExerciseSet(reps: 8, weight: 165, order: 0),
            ExerciseSet(reps: 8, weight: 165, order: 1),
            ExerciseSet(reps: 8, weight: 165, order: 2),
            ExerciseSet(reps: 5, weight: 185, order: 3)
        ]

        let inclineDB = Exercise(name: "Incline DB Press", muscleGroup: .chest, order: 1)
        inclineDB.sets = [
            ExerciseSet(reps: 10, weight: 55, order: 0),
            ExerciseSet(reps: 10, weight: 55, order: 1),
            ExerciseSet(reps: 10, weight: 55, order: 2)
        ]

        let cableFly = Exercise(name: "Cable Fly", muscleGroup: .chest, order: 2)
        cableFly.sets = [
            ExerciseSet(reps: 12, weight: 30, order: 0),
            ExerciseSet(reps: 12, weight: 30, order: 1),
            ExerciseSet(reps: 12, weight: 30, order: 2)
        ]

        workout.exercises = [benchPress, inclineDB, cableFly]
        return workout
    }
}

#Preview {
    let workout = WorkoutCardPreviewHelper.makePreviewWorkout()
    let profile = UserProfile(name: "Marcus", username: "marcus")

    let pr = PRMoment(
        odUsername: "marcus",
        prType: .repPR,
        exerciseName: "Bench Press",
        value: "185 × 5",
        previousValue: "175 × 5",
        improvement: "+10 lbs from Dec 8"
    )

    return ScrollView {
        VStack(spacing: 20) {
            WorkoutCardView(
                workout: workout,
                profile: profile,
                streakCount: 12,
                xpEarned: 85,
                prMoments: [pr],
                coachTakeaway: "Strong pressing day. Try close-grip bench next time for tricep work.",
                fistBumpCount: 8
            )
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 20)
    }
    .background(GQColors.surfaceBase)
    .preferredColorScheme(.dark)
}
