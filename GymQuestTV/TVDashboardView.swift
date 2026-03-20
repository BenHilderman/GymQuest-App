//
//  TVDashboardView.swift
//  GymQuestTV
//
//  Created by Benjamin Hilderman
//
//  Main dashboard / today screen for the tvOS companion app.
//

#if os(tvOS)

import SwiftUI
import SwiftData

// MARK: - TVWeeklyRing

struct TVWeeklyRing: View {
    let completedDays: Int
    let target: Int
    let workoutDayIndices: Set<Int>

    private let ringSize: CGFloat = 220
    private let lineWidth: CGFloat = 20
    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: lineWidth)
                .frame(width: ringSize, height: ringSize)

            Circle()
                .trim(from: 0, to: progressFraction)
                .stroke(
                    GQGradients.primary,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: ringSize, height: ringSize)
                .rotationEffect(.degrees(-90))
                .shadow(color: GQColors.deepBlue.opacity(0.3), radius: 12, y: 0)

            ForEach(0..<7, id: \.self) { index in
                dayIndicator(index: index)
            }

            VStack(spacing: 2) {
                Text("\(completedDays)")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(GQGradients.primary)

                Text("of \(target)")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .frame(width: ringSize + 60, height: ringSize + 60)
    }

    private var progressFraction: CGFloat {
        guard target > 0 else { return 0 }
        return min(CGFloat(completedDays) / CGFloat(target), 1.0)
    }

    @ViewBuilder
    private func dayIndicator(index: Int) -> some View {
        let angle = (Double(index) / 7.0) * 360.0 - 90.0
        let radius = (ringSize / 2) + 28
        let x = cos(angle * .pi / 180) * radius
        let y = sin(angle * .pi / 180) * radius
        let completed = workoutDayIndices.contains(index + 1)

        Text(dayLabels[index])
            .font(.system(size: 14, weight: completed ? .bold : .medium, design: .rounded))
            .foregroundColor(completed ? .white : .white.opacity(0.2))
            .offset(x: x, y: y)
    }
}

// MARK: - TVDashboardView

struct TVDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.switchToWorkout) private var switchToWorkout

    @Query(sort: \Workout.date, order: .reverse) private var allWorkouts: [Workout]
    @Query(sort: \Challenge.startDate, order: .reverse) private var allChallenges: [Challenge]
    @Query(sort: \ChallengeEnrollment.enrolledAt, order: .reverse) private var allChallengeEnrollments: [ChallengeEnrollment]
    @Query private var allProfiles: [UserProfile]

    // MARK: - Computed Properties

    private var nonRestWorkouts: [Workout] {
        allWorkouts.filter { $0.type != .rest }
    }

    private var workoutsThisWeek: [Workout] {
        let calendar = Calendar.current
        guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return [] }
        return nonRestWorkouts.filter { $0.date >= startOfWeek }
    }

    private var thisWeekWorkoutDayIndices: Set<Int> {
        let calendar = Calendar.current
        var indices = Set<Int>()
        for workout in workoutsThisWeek {
            let weekday = calendar.component(.weekday, from: workout.date)
            let mondayBased = weekday == 1 ? 7 : weekday - 1
            indices.insert(mondayBased)
        }
        return indices
    }

    private var currentStreak: Int {
        let calendar = Calendar.current
        var streak = 0
        var dayOffset = 0

        while dayOffset < 365 {
            guard let date = calendar.date(
                byAdding: .day, value: -dayOffset,
                to: calendar.startOfDay(for: Date())
            ) else { break }

            let hasWorkout = nonRestWorkouts.contains {
                calendar.isDate($0.date, inSameDayAs: date)
            }

            if hasWorkout {
                streak += 1
            } else if dayOffset == 0 {
                // Today has no workout yet — don't break streak
            } else {
                break
            }
            dayOffset += 1
        }
        return streak
    }

    private var weeklyVolume: Double {
        workoutsThisWeek.reduce(0) { $0 + $1.totalVolume }
    }

    private var prsThisMonth: Int {
        let calendar = Calendar.current
        guard let startOfMonth = calendar.dateInterval(of: .month, for: Date())?.start else { return 0 }
        return allWorkouts.filter { $0.date >= startOfMonth && $0.hasPRs }.count
    }

    private var recentWorkouts: [Workout] {
        Array(nonRestWorkouts.prefix(10))
    }

    private var activeChallengeEnrollments: [ChallengeEnrollment] {
        allChallengeEnrollments.filter { enrollment in
            !enrollment.isCompleted &&
            allChallenges.contains { $0.id == enrollment.challengeId && $0.isActive }
        }
    }

    private func challengeFor(_ enrollment: ChallengeEnrollment) -> Challenge? {
        allChallenges.first { $0.id == enrollment.challengeId }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        default: return "Good Evening"
        }
    }

    private var profileName: String {
        allProfiles.first?.name ?? "Athlete"
    }

    // MARK: - Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 80) {
                heroSection
                statsRow
                recentWorkoutsSection
                quickStartSection
            }
            .padding(.horizontal, 80)
            .padding(.top, 40)
            .padding(.bottom, 100)
        }
        .background(Color(white: 0.11).ignoresSafeArea())
        .task {
            if allProfiles.isEmpty {
                let profile = UserProfile(name: "Ben Hilderman", username: "benhilderman")
                modelContext.insert(profile)
                try? modelContext.save()
            } else if let profile = allProfiles.first, profile.name != "Ben Hilderman" {
                profile.name = "Ben Hilderman"
                profile.username = "benhilderman"
                try? modelContext.save()
            }
            if let profile = allProfiles.first {
                MockDataSeeder.seedIfNeeded(modelContext: modelContext, profile: profile)
            }
            SocialSeeder.seedIfNeeded(modelContext: modelContext)
        }
    }

    // MARK: - Hero Section (Cinematic — ring centered with greeting overlay)

    private let offWhite = Color(white: 0.93)

    @ViewBuilder
    private var heroSection: some View {
        ZStack {
            // Subtle gradient backdrop
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [GQColors.deepBlue.opacity(0.15), GQColors.vividPurple.opacity(0.08), Color(white: 0.14)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 340)

            HStack(spacing: 0) {
                // Left — Greeting + date
                VStack(alignment: .leading, spacing: 16) {
                    Text(greeting)
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .foregroundColor(offWhite.opacity(0.5))

                    Text(profileName)
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundColor(offWhite)

                    Text(Date.now, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                        .font(.system(size: 24, weight: .regular, design: .rounded))
                        .foregroundColor(offWhite.opacity(0.35))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Center — Ring (larger)
                TVWeeklyRing(
                    completedDays: workoutsThisWeek.count,
                    target: 5,
                    workoutDayIndices: thisWeekWorkoutDayIndices
                )
                .padding(.horizontal, 40)

                // Right — This week summary
                VStack(alignment: .trailing, spacing: 20) {
                    heroStat(value: "\(workoutsThisWeek.count)", label: "THIS WEEK")
                    heroStat(value: "\(currentStreak)d", label: "STREAK")
                    heroStat(value: formattedVolume(weeklyVolume), label: "VOLUME")
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 56)
        }
    }

    @ViewBuilder
    private func heroStat(value: String, label: String) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(GQGradients.primary)
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(offWhite.opacity(0.3))
                .tracking(1.2)
        }
    }

    // MARK: - Stats Row (individual cards like Progress tab)

    @ViewBuilder
    private var statsRow: some View {
        HStack(spacing: 24) {
            TVStatCard(
                title: "Workouts",
                value: "\(workoutsThisWeek.count)",
                icon: "figure.strengthtraining.traditional",
                color: GQColors.deepBlue
            )
            TVStatCard(
                title: "Streak",
                value: "\(currentStreak) days",
                icon: "flame.fill",
                color: GQColors.success
            )
            TVStatCard(
                title: "Volume",
                value: formattedVolume(weeklyVolume),
                icon: "scalemass.fill",
                color: GQColors.cyanSpark
            )
            TVStatCard(
                title: "PRs This Month",
                value: "\(prsThisMonth)",
                icon: "trophy.fill",
                color: Color(red: 0.75, green: 0.65, blue: 0.45)
            )
        }
    }

    // MARK: - Recent Workouts

    @ViewBuilder
    private var recentWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 30) {
            Text("Recent Workouts")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(offWhite)

            if recentWorkouts.isEmpty {
                emptyPlaceholder(
                    icon: "figure.strengthtraining.traditional",
                    message: "No workouts yet. Start your first session!"
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 40) {
                        ForEach(recentWorkouts) { workout in
                            workoutCard(workout)
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
        }
    }

    @ViewBuilder
    private func workoutCard(_ workout: Workout) -> some View {
        Button(action: {}) {
            VStack(alignment: .leading, spacing: 0) {
                // Gradient hero
                ZStack(alignment: .topLeading) {
                    LinearGradient(
                        colors: [GQColors.deepBlue.opacity(0.7), GQColors.vividPurple.opacity(0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: workout.type.icon)
                            .font(.system(size: 44, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))

                        Spacer()

                        Text(workout.type.rawValue)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(28)
                }
                .frame(height: 200)

                // Content
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(workout.date.relativeDescription)
                        Text("·")
                        Text(formatDuration(TimeInterval(workout.duration * 60)))
                    }
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundColor(offWhite.opacity(0.5))

                    if workout.totalVolume > 0 {
                        Text(formattedVolume(workout.totalVolume))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(GQGradients.primary)
                    }
                }
                .padding(24)
            }
            .frame(width: 320, height: 310)
            .background(Color(white: 0.16))
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(TVCardButtonStyle())
    }

    // MARK: - Quick Start

    @ViewBuilder
    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: 30) {
            Text("Quick Start")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(offWhite)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 32) {
                    ForEach(quickStartTypes, id: \.self) { type in
                        quickStartCard(type)
                    }
                }
                .padding(.vertical, 20)
            }
        }
    }

    private var quickStartTypes: [WorkoutType] {
        [.push, .pull, .legs, .upper, .cardio, .custom]
    }

    @ViewBuilder
    private func quickStartCard(_ type: WorkoutType) -> some View {
        Button {
            switchToWorkout(type)
        } label: {
            VStack(spacing: 16) {
                Image(systemName: type.icon)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(GQGradients.primary)

                Text(type.rawValue)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(offWhite)
            }
            .frame(width: 180, height: 140)
            .background(Color(white: 0.16))
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(TVCardButtonStyle())
    }

    // MARK: - Reusable

    @ViewBuilder
    private func emptyPlaceholder(icon: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.white.opacity(0.15))

            Text(message)
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.25))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Helpers

    private func formattedVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk", volume / 1000)
        }
        return "\(Int(volume)) lbs"
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remaining = minutes % 60
            return remaining > 0 ? "\(hours)h \(remaining)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }
}

// MARK: - Date Extension (TV)

private extension Date {
    var relativeDescription: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) {
            return "Today"
        } else if calendar.isDateInYesterday(self) {
            return "Yesterday"
        } else {
            let days = calendar.dateComponents([.day], from: self, to: Date()).day ?? 0
            if days < 7 {
                return "\(days)d ago"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                return formatter.string(from: self)
            }
        }
    }
}

#endif
