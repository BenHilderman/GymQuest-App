//
//  CalendarHistoryView.swift
//  GymQuest
//
//  Created by Benjamin Hilderman
//
//  Full month calendar showing workout history. Tapping a day
//  with a workout opens WorkoutReviewSheet.
//

import SwiftUI

struct CalendarHistoryView: View {
    let workouts: [Workout]

    @Environment(\.dismiss) private var dismiss
    @State private var displayedMonth = Date()
    @State private var selectedWorkout: Workout?
    @State private var showingWorkoutReview = false

    private let calendar = Calendar.current
    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                monthHeader
                dayOfWeekHeader
                monthGrid
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .background(GQColors.background.ignoresSafeArea())
            .navigationTitle("Workout History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(GQColors.vividPurple)
                }
            }
            .sheet(isPresented: $showingWorkoutReview) {
                if let workout = selectedWorkout {
                    WorkoutReviewSheet(workout: workout)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
            }
        }
    }

    // MARK: - Month Header

    @ViewBuilder
    private var monthHeader: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(GQColors.vividPurple)
                    .frame(width: 40, height: 40)
            }

            Spacer()

            Text(monthYearString)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(GQColors.textPrimary)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(GQColors.vividPurple)
                    .frame(width: 40, height: 40)
            }
        }
    }

    // MARK: - Day of Week Header

    @ViewBuilder
    private var dayOfWeekHeader: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(dayLabels, id: \.self) { label in
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(GQColors.textTertiary)
                    .frame(height: 20)
            }
        }
    }

    // MARK: - Month Grid

    @ViewBuilder
    private var monthGrid: some View {
        let days = daysInMonth()

        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(days, id: \.self) { date in
                if let date {
                    dayCell(for: date)
                } else {
                    Color.clear.frame(height: 44)
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let workout = workoutForDate(date)
        let isToday = calendar.isDateInToday(date)
        let dayNumber = calendar.component(.day, from: date)

        Button {
            if let workout, workout.type != .rest {
                selectedWorkout = workout
                showingWorkoutReview = true
            }
        } label: {
            VStack(spacing: 2) {
                Text("\(dayNumber)")
                    .font(.system(size: 14, weight: isToday ? .bold : .medium))
                    .foregroundStyle(
                        workout != nil ? .white : GQColors.textPrimary
                    )

                if let workout {
                    if workout.type == .rest {
                        Image(systemName: "bed.double.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.white.opacity(0.8))
                    } else {
                        Image(systemName: workout.type.icon)
                            .font(.system(size: 8))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            .frame(width: 44, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(cellBackground(workout: workout, isToday: isToday))
            )
            .overlay(
                Group {
                    if isToday {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(GQColors.vividPurple.opacity(0.5), lineWidth: 2)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func cellBackground(workout: Workout?, isToday: Bool) -> some ShapeStyle {
        if let workout {
            if workout.type == .rest {
                return AnyShapeStyle(Color(hex: "8E8E93").opacity(0.3))
            }
            return AnyShapeStyle(
                LinearGradient(
                    colors: [GQColors.deepBlue.opacity(0.8), GQColors.vividPurple.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(GQColors.adaptiveOverlay(isToday ? 0.06 : 0.03))
    }

    private func workoutForDate(_ date: Date) -> Workout? {
        workouts.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    private func daysInMonth() -> [Date?] {
        let range = calendar.range(of: .day, in: .month, for: displayedMonth)!
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))!
        let weekdayOfFirst = calendar.component(.weekday, from: firstDay) - 1 // 0 = Sunday

        var days: [Date?] = Array(repeating: nil, count: weekdayOfFirst)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }

        // Pad to fill the last row
        while days.count % 7 != 0 {
            days.append(nil)
        }

        return days
    }
}
