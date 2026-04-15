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
    /// Planned workout types per weekday (1=Sun, 7=Sat). Shown as colored labels.
    var plannedTypes: [Int: String] = [:]
    /// Called when the user taps a day circle. Passes the weekday number (1-7).
    var onDayTap: ((Int) -> Void)? = nil
    /// Today's planned workout label (e.g. "Pull"). Nil if rest/off/no plan.
    var todayPlan: String? = nil
    /// Called when user taps Start on today's plan.
    var onStartWorkout: (() -> Void)? = nil

    @State private var showingGoalPicker = false
    @State private var flameGlow = false

    init(completed: Int, target: Binding<Int>, workoutDates: [Date] = [], workoutIcons: [Date: String] = [:], dailyStreak: Int = 0, weeklyStreak: Int = 0, plannedTypes: [Int: String] = [:], onDayTap: ((Int) -> Void)? = nil, todayPlan: String? = nil, onStartWorkout: (() -> Void)? = nil) {
        self.completed = completed
        self._target = target
        self.workoutDates = workoutDates
        self.workoutIcons = workoutIcons
        self.dailyStreak = dailyStreak
        self.plannedTypes = plannedTypes
        self.onDayTap = onDayTap
        self.weeklyStreak = weeklyStreak
        self.todayPlan = todayPlan
        self.onStartWorkout = onStartWorkout
    }

    private var weekDays: [(label: String, date: Date, isToday: Bool, hasWorkout: Bool, icon: String?, weekday: Int, plannedType: String?)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today) else { return [] }

        let workoutDaySet = Set(workoutDates.map { calendar.startOfDay(for: $0) })

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekInterval.start) else { return nil }
            let dayStart = calendar.startOfDay(for: date)
            let label = date.formatted(.dateTime.weekday(.narrow)).uppercased()
            let icon = workoutIcons.first(where: { calendar.isDate($0.key, inSameDayAs: date) })?.value
            let wd = calendar.component(.weekday, from: date)
            return (
                label: label,
                date: date,
                isToday: calendar.isDateInToday(date),
                hasWorkout: workoutDaySet.contains(dayStart),
                icon: icon,
                weekday: wd,
                plannedType: plannedTypes[wd]
            )
        }
    }

    private var progress: CGFloat {
        guard target > 0 else { return 0 }
        return min(CGFloat(completed) / CGFloat(target), 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Caption + primary stat stacked on left, streak on right — single header row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("THIS WEEK")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.2)
                        .foregroundColor(GQColors.textTertiary)
                    Button { showingGoalPicker = true } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(completed)")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(GQGradients.primary)
                            Text("/ \(target) workouts")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(GQColors.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                streakFlame
            }

            // Week calendar row
            HStack(spacing: 0) {
                ForEach(weekDays, id: \.date) { day in
                    Button {
                        onDayTap?(day.weekday)
                        #if canImport(UIKit)
                        UISelectionFeedbackGenerator().selectionChanged()
                        #endif
                    } label: {
                        VStack(spacing: 6) {
                            Text(day.label)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .tracking(1.2)
                                .foregroundColor(day.isToday ? GQColors.textPrimary : GQColors.textTertiary)

                            ZStack {
                                if day.isToday {
                                    Circle()
                                        .fill(GQGradients.primary.opacity(0.06))
                                    Circle()
                                        .strokeBorder(GQGradients.primary.opacity(0.85), lineWidth: 1.5)
                                } else if day.hasWorkout {
                                    Circle()
                                        .fill(GQGradients.primary)
                                } else {
                                    Circle()
                                        .fill(GQColors.adaptiveOverlay(0.045))
                                }

                                Text(day.date.formatted(.dateTime.day()))
                                    .font(.system(size: 15, weight: day.isToday || day.hasWorkout ? .semibold : .medium, design: .rounded))
                                    .foregroundColor(
                                        day.isToday ? GQColors.textPrimary :
                                        day.hasWorkout ? .white :
                                        GQColors.textTertiary
                                    )
                            }
                            .frame(width: 36, height: 36)

                            // Workout type icon — solid for completed, muted for planned
                            if let icon = day.icon {
                                Image(systemName: icon)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(GQGradients.primary.opacity(0.9))
                            } else if let planned = day.plannedType {
                                Image(systemName: planIcon(planned))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(planned == "Rest"
                                        ? AnyShapeStyle(GQColors.textTertiary.opacity(0.4))
                                        : AnyShapeStyle(GQGradients.primary.opacity(0.4))
                                    )
                            } else {
                                Color.clear.frame(height: 10)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }

        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .homeSocialCard(cornerRadius: 14)
        .sheet(isPresented: $showingGoalPicker) {
            WeeklyGoalPicker(target: $target)
                .presentationDetents([.height(280)])
        }
    }

    private func planShortLabel(_ raw: String) -> String {
        switch raw {
        case "Push": return "Push"
        case "Pull": return "Pull"
        case "Legs": return "Legs"
        case "Upper": return "Upper"
        case "Lower": return "Lower"
        case "Full Body": return "Full"
        case "Cardio": return "Cardio"
        case "HIIT": return "HIIT"
        case "Yoga": return "Yoga"
        case "Rest": return "Rest"
        default: return raw.prefix(4).description
        }
    }

    private func planColor(_ raw: String) -> Color {
        switch raw {
        case "Rest": return GQColors.textTertiary
        default: return GQColors.vividPurple
        }
    }

    private func planIcon(_ raw: String) -> String {
        switch raw {
        case "Push": return "arrow.up.circle"
        case "Pull": return "arrow.down.circle"
        case "Legs": return "figure.walk"
        case "Upper": return "figure.arms.open"
        case "Lower": return "figure.run"
        case "Full Body": return "figure.strengthtraining.traditional"
        case "Cardio": return "heart.circle"
        case "HIIT": return "bolt.circle"
        case "Yoga": return "figure.mind.and.body"
        case "Glutes": return "figure.walk"
        case "Abs": return "figure.core.training"
        case "Rest": return "moon.fill"
        default: return "dumbbell.fill"
        }
    }

    // MARK: - Living Streak Flame

    @ViewBuilder
    private var streakFlame: some View {
        let streak = dailyStreak

        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 5) {
                if streak == 0 {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundColor(GQColors.textTertiary.opacity(0.35))
                } else if streak < 3 {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12 + CGFloat(streak)))
                        .foregroundStyle(
                            LinearGradient(colors: [.orange, .red.opacity(0.8)], startPoint: .bottom, endPoint: .top)
                        )
                } else {
                    LivingFlame(streak: streak)
                }

                Text("\(streak)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(streak == 0 ? GQColors.textTertiary : GQColors.textPrimary)
            }

            if weeklyStreak > 0 {
                Text("\(weeklyStreak) week streak")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(GQColors.textTertiary)
            } else if dailyStreak > 0 {
                Text("day streak")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(GQColors.textTertiary)
            }
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

// MARK: - Living Flame (real-time flickering fire)

struct LivingFlame: View {
    let streak: Int

    // Size grows with streak: 14pt at 3 → 20pt at 7+
    private var baseSize: CGFloat { min(11 + CGFloat(streak), 20) }
    // Spark count: 0 at 3, ramps to 8 at 7+
    private var sparkCount: Int { max(0, min((streak - 2) * 2, 8)) }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            ZStack {
                // Warm glow behind (grows with streak)
                if streak >= 5 {
                    Circle()
                        .fill(Color.orange.opacity(0.15 + 0.05 * sin(time * 2.0)))
                        .frame(width: baseSize + 10, height: baseSize + 10)
                        .blur(radius: 6)
                }

                // Back flame layer — slightly offset, creates depth
                Image(systemName: "flame.fill")
                    .font(.system(size: baseSize * 0.8))
                    .foregroundStyle(
                        LinearGradient(colors: [.red.opacity(0.6), .orange.opacity(0.4)], startPoint: .bottom, endPoint: .top)
                    )
                    .scaleEffect(0.9 + 0.06 * CGFloat(sin(time * 3.5 + 1.0)))
                    .offset(x: 0.5 * CGFloat(sin(time * 2.2)), y: -1)

                // Main flame — the primary fire
                Image(systemName: "flame.fill")
                    .font(.system(size: baseSize))
                    .foregroundStyle(
                        LinearGradient(colors: [.yellow, .orange, .red.opacity(0.9)], startPoint: .bottom, endPoint: .top)
                    )
                    .scaleEffect(1.0 + 0.05 * CGFloat(sin(time * 4.0)))
                    .offset(x: 0.8 * CGFloat(sin(time * 3.0)), y: 0)

                // Spark particles — tiny dots that float up
                ForEach(0..<sparkCount, id: \.self) { i in
                    let seed = Double(i) * 1.7
                    let phase = (time * (1.5 + Double(i) * 0.3) + seed).truncatingRemainder(dividingBy: 2.0)
                    let normalizedPhase = phase / 2.0 // 0 → 1

                    Circle()
                        .fill(i % 2 == 0 ? Color.yellow : Color.orange)
                        .frame(width: 2.5 - normalizedPhase, height: 2.5 - normalizedPhase)
                        .offset(
                            x: CGFloat(sin(time * 2.0 + seed)) * (3 + CGFloat(i)),
                            y: -CGFloat(normalizedPhase) * (12 + CGFloat(streak))
                        )
                        .opacity(1.0 - normalizedPhase)
                }
            }
            .frame(width: baseSize + 12, height: baseSize + 12)
        }
    }
}
