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

    @State private var showingGoalPicker = false

    init(completed: Int, target: Binding<Int>, workoutDates: [Date] = []) {
        self.completed = completed
        self._target = target
        self.workoutDates = workoutDates
    }

    private var weekDays: [(label: String, date: Date, isToday: Bool, hasWorkout: Bool)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today) else { return [] }

        let workoutDaySet = Set(workoutDates.map { calendar.startOfDay(for: $0) })

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekInterval.start) else { return nil }
            let dayStart = calendar.startOfDay(for: date)
            let label = date.formatted(.dateTime.weekday(.narrow))
            return (
                label: label,
                date: date,
                isToday: calendar.isDateInToday(date),
                hasWorkout: workoutDaySet.contains(dayStart)
            )
        }
    }

    private var progress: CGFloat {
        guard target > 0 else { return 0 }
        return min(CGFloat(completed) / CGFloat(target), 1.0)
    }

    var body: some View {
        VStack(spacing: 14) {
            // Summary row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("This Week")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(GQColors.textSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(completed)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(GQColors.textPrimary)
                        Text("/ \(target) workouts")
                            .font(.system(size: 15))
                            .foregroundStyle(GQColors.textTertiary)
                    }
                }
                Spacer()

                // Tappable progress ring to edit goal
                Button {
                    showingGoalPicker = true
                } label: {
                    ZStack {
                        Circle()
                            .stroke(GQColors.adaptiveOverlay(0.08), lineWidth: 5)
                        if progress > 0 {
                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(
                                    GQGradients.primary,
                                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                        }
                        if completed >= target && target > 0 {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(GQColors.deepBlue)
                        } else {
                            Text("\(target)")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(GQColors.textTertiary)
                        }
                    }
                    .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }

            // Week calendar row
            HStack(spacing: 0) {
                ForEach(weekDays, id: \.date) { day in
                    VStack(spacing: 6) {
                        Text(day.label)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(GQColors.textTertiary)

                        ZStack {
                            if day.hasWorkout {
                                Circle()
                                    .fill(GQGradients.primary.opacity(0.18))
                                Circle()
                                    .stroke(GQGradients.primary.opacity(0.45), lineWidth: 1)
                            } else if day.isToday {
                                Circle()
                                    .stroke(GQGradients.primary, lineWidth: 1.5)
                            }

                            Text(day.date.formatted(.dateTime.day()))
                                .font(.system(size: 15, weight: day.hasWorkout || day.isToday ? .semibold : .regular, design: .rounded))
                                .foregroundStyle(
                                    day.hasWorkout ? AnyShapeStyle(GQGradients.primary) :
                                    day.isToday ? AnyShapeStyle(GQColors.textPrimary) : AnyShapeStyle(GQColors.textTertiary)
                                )
                        }
                        .frame(width: 34, height: 34)

                        // Completion dot
                        Circle()
                            .fill(day.hasWorkout ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(.clear))
                            .frame(width: 4, height: 4)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
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
