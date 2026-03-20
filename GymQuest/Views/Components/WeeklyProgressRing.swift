//
//  WeeklyProgressRing.swift
//  GymQuest
//
//  Created by Benjamin Hilderman
//
//  Apple-style week calendar widget showing daily workout activity.
//

import SwiftUI

struct WeeklyProgressRing: View {
    let completed: Int
    @Binding var target: Int
    let workoutDates: [Date]
    var workoutIcons: [Date: String] = [:] // date -> SF Symbol icon
    var dailyStreak: Int = 0
    var weeklyStreak: Int = 0

    @State private var showingGoalPicker = false

    init(completed: Int, target: Binding<Int>, workoutDates: [Date] = [], workoutIcons: [Date: String] = [:], dailyStreak: Int = 0, weeklyStreak: Int = 0) {
        self.completed = completed
        self._target = target
        self.workoutDates = workoutDates
        self.workoutIcons = workoutIcons
        self.dailyStreak = dailyStreak
        self.weeklyStreak = weeklyStreak
    }

    private var weekDays: [(label: String, date: Date, isToday: Bool, hasWorkout: Bool, icon: String?)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today) else { return [] }

        let workoutDaySet = Set(workoutDates.map { calendar.startOfDay(for: $0) })

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekInterval.start) else { return nil }
            let dayStart = calendar.startOfDay(for: date)
            let label = date.formatted(.dateTime.weekday(.narrow))
            let icon = workoutIcons.first(where: { calendar.isDate($0.key, inSameDayAs: date) })?.value
            return (
                label: label,
                date: date,
                isToday: calendar.isDateInToday(date),
                hasWorkout: workoutDaySet.contains(dayStart),
                icon: icon
            )
        }
    }

    private var progress: CGFloat {
        guard target > 0 else { return 0 }
        return min(CGFloat(completed) / CGFloat(target), 1.0)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header row
            HStack(spacing: 12) {
                // Progress ring
                Button {
                    showingGoalPicker = true
                } label: {
                    ZStack {
                        Circle()
                            .stroke(GQColors.adaptiveOverlay(0.06), lineWidth: 4.5)
                            .frame(width: 44, height: 44)
                        if progress > 0 {
                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(
                                    GQGradients.primary,
                                    style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .frame(width: 44, height: 44)
                        }
                        if completed >= target && target > 0 {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(GQGradients.primary)
                        } else {
                            Text("\(completed)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(GQColors.textPrimary)
                        }
                    }
                    .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text("This Week")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(GQColors.textPrimary)
                    if completed >= target {
                        Text("Weekly goal complete!")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(GQGradients.primary)
                    } else {
                        Text("\(completed) of \(target) workouts")
                            .font(.system(size: 12))
                            .foregroundStyle(GQColors.textTertiary)
                    }
                }

                Spacer()

                // Streak
                if dailyStreak > 0 || weeklyStreak > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(GQGradients.primary.opacity(0.85))
                            Text("\(dailyStreak)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(GQColors.textPrimary)
                        }
                        if weeklyStreak > 0 {
                            Text("\(weeklyStreak) week streak")
                                .font(.system(size: 11))
                                .foregroundColor(GQColors.textTertiary)
                        } else {
                            Text("day streak")
                                .font(.system(size: 11))
                                .foregroundColor(GQColors.textTertiary)
                        }
                    }
                }
            }

            // Week calendar
            HStack(spacing: 0) {
                ForEach(weekDays, id: \.date) { day in
                    VStack(spacing: 5) {
                        Text(day.label)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(day.isToday ? GQColors.textPrimary : GQColors.textTertiary)

                        ZStack {
                            if day.hasWorkout {
                                Circle()
                                    .fill(GQGradients.primary.opacity(0.15))
                            } else if day.isToday {
                                Circle()
                                    .strokeBorder(GQGradients.primary.opacity(0.6), lineWidth: 1.5)
                            } else {
                                Circle()
                                    .fill(GQColors.adaptiveOverlay(0.04))
                            }

                            Text(day.date.formatted(.dateTime.day()))
                                .font(.system(size: 14, weight: day.hasWorkout || day.isToday ? .semibold : .regular, design: .rounded))
                                .foregroundStyle(
                                    day.hasWorkout ? AnyShapeStyle(GQGradients.primary) :
                                    day.isToday ? AnyShapeStyle(GQColors.textPrimary) :
                                    AnyShapeStyle(GQColors.textTertiary)
                                )
                        }
                        .frame(width: 36, height: 36)

                        // Workout type icon
                        if let icon = day.icon {
                            Image(systemName: icon)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(GQGradients.primary.opacity(0.85))
                        } else {
                            Color.clear.frame(height: 8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .homeSocialCard(cornerRadius: 16)
        .sheet(isPresented: $showingGoalPicker) {
            WeeklyGoalPicker(target: $target)
                .presentationDetents([.height(280)])
        }
    }
}

// MARK: - Weekly Goal Picker

struct WeeklyGoalPicker: View {
    @Binding var target: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 4) {
                Text("Weekly Goal")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(GQColors.textPrimary)
                Text("How many days do you want to train?")
                    .font(.system(size: 15))
                    .foregroundStyle(GQColors.textSecondary)
            }
            .padding(.top, 24)

            HStack(spacing: 8) {
                ForEach(1...7, id: \.self) { day in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            target = day
                        }
                    } label: {
                        Text("\(day)")
                            .font(.system(size: 17, weight: day == target ? .bold : .medium, design: .rounded))
                            .foregroundStyle(day == target ? .white : GQColors.textPrimary)
                            .frame(width: 40, height: 40)
                            .background {
                                if day == target {
                                    Circle().fill(GQGradients.primary)
                                } else {
                                    Circle()
                                        .fill(GQColors.adaptiveOverlay(0.06))
                                        .overlay(Circle().stroke(GQColors.borderDefault, lineWidth: 1))
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(GQGradients.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)

            Spacer()
        }
    }
}
