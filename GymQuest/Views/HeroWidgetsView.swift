//
//  HeroWidgetsView.swift
//  GymQuest
//
//  Extracted from FeedView.swift for modularization.
//

import SwiftUI
import SwiftData
import AVKit
import MapKit
import PhotosUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Widget Size

enum WidgetSize {
    case large, half, third

    var numberFont: Font {
        switch self {
        case .large: .system(size: 36, weight: .bold, design: .rounded)
        case .half: .system(size: 28, weight: .bold, design: .rounded)
        case .third: .system(size: 20, weight: .bold, design: .rounded)
        }
    }

    var goalFont: Font {
        switch self {
        case .large: .system(size: 18, weight: .semibold, design: .rounded)
        case .half: .system(size: 14, weight: .semibold, design: .rounded)
        case .third: .system(size: 11, weight: .semibold, design: .rounded)
        }
    }

    var ringSize: CGFloat {
        switch self {
        case .large: 48
        case .half: 36
        case .third: 24
        }
    }
}

// MARK: - Weekly Hero Section

struct WeeklyHeroSection: View {
    let completed: Int
    let goal: Int
    var profile: UserProfile
    var workouts: [Workout] = []
    var size: WidgetSize = .large

    @Environment(\.modelContext) private var modelContext
    @State private var isEditingGoal = false

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(completed) / Double(goal), 1.0)
    }

    /// Workout count per weekday (1=Sun..7=Sat) this week
    private var workoutCountsByWeekday: [Int: Int] {
        let cal = Calendar.current
        guard let startOfWeek = cal.dateInterval(of: .weekOfYear, for: Date())?.start else { return [:] }
        let thisWeek = workouts.filter { $0.date >= startOfWeek }
        var counts: [Int: Int] = [:]
        for w in thisWeek {
            let wd = cal.component(.weekday, from: w.date)
            counts[wd, default: 0] += 1
        }
        return counts
    }

    var body: some View {
        Group {
            switch size {
            case .third:
                compactThirdBody
            case .half:
                halfBody
            case .large:
                largeBody
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditingGoal {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isEditingGoal = false
                }
            }
        }
    }

    // MARK: - Large (full-width)
    @ViewBuilder
    private var largeBody: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("This Week")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(GQColors.textSecondary)

                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(completed)")
                            .font(size.numberFont)
                            .foregroundColor(GQColors.textPrimary)
                            .contentTransition(.numericText())

                        if isEditingGoal {
                            goalEditor
                        } else {
                            goalLabel
                        }
                    }
                }

                Spacer()

                HeroProgressRing(
                    progress: progress,
                    completed: completed >= goal
                )
            }

            weekDayDots
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Half
    @ViewBuilder
    private var halfBody: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("This Week")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(completed)")
                        .font(size.numberFont)
                        .foregroundColor(GQColors.textPrimary)
                        .contentTransition(.numericText())

                    Text("/ \(goal)")
                        .font(size.goalFont)
                        .foregroundColor(GQColors.textTertiary)
                }
            }

            Spacer()

            HeroProgressRing(
                progress: progress,
                completed: completed >= goal,
                size: size.ringSize
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    // MARK: - Third (compact ring + number + goal)
    @ViewBuilder
    private var compactThirdBody: some View {
        VStack(spacing: 4) {
            HeroProgressRing(
                progress: progress,
                completed: completed >= goal,
                size: size.ringSize
            )

            Text("\(completed)")
                .font(size.numberFont)
                .foregroundColor(GQColors.textPrimary)
                .contentTransition(.numericText())

            Text("/ \(goal) workouts")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    // MARK: - Shared subviews
    @ViewBuilder
    private var goalEditor: some View {
        HStack(spacing: 2) {
            Text("/")
                .font(size.goalFont)
                .foregroundColor(GQColors.textTertiary)

            Button {
                if profile.daysPerWeek > 1 {
                    profile.daysPerWeek -= 1
                    try? modelContext.save()
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.textTertiary)
            }
            .buttonStyle(.plain)

            Text("\(profile.daysPerWeek)")
                .font(size.goalFont)
                .foregroundColor(GQColors.textPrimary)
                .contentTransition(.numericText())

            Button {
                profile.daysPerWeek += 1
                try? modelContext.save()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.textTertiary)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var goalLabel: some View {
        Text("/ \(goal)")
            .font(size.goalFont)
            .foregroundColor(GQColors.textTertiary)

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isEditingGoal = true
            }
        } label: {
            Image(systemName: "pencil")
                .font(.system(size: 10))
                .foregroundColor(GQColors.textTertiary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var weekDayDots: some View {
        let cal = Calendar.current
        let symbols = cal.veryShortWeekdaySymbols
        let mondayFirst = [2, 3, 4, 5, 6, 7, 1]
        let labelsReordered = [symbols[1], symbols[2], symbols[3],
                               symbols[4], symbols[5], symbols[6],
                               symbols[0]]
        let todayWeekday = cal.component(.weekday, from: Date())

        HStack(spacing: 0) {
            ForEach(Array(zip(mondayFirst, labelsReordered).enumerated()), id: \.offset) { _, pair in
                let (weekday, label) = pair
                let count = workoutCountsByWeekday[weekday] ?? 0
                let isToday = weekday == todayWeekday
                VStack(spacing: 2) {
                    Text(label)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(isToday ? GQColors.textPrimary : GQColors.textTertiary)
                    HStack(spacing: 1.5) {
                        if count == 0 {
                            Circle()
                                .fill(GQColors.adaptiveOverlay(0.08))
                                .frame(width: 8, height: 8)
                        } else {
                            ForEach(0..<min(count, 3), id: \.self) { _ in
                                Circle()
                                    .fill(GQGradients.primary)
                                    .frame(width: 10, height: 10)
                                    .shadow(color: isToday ? GQColors.deepBlue.opacity(0.5) : .clear, radius: isToday ? 4 : 0)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Hero Progress Ring (Reusable)

struct HeroProgressRing: View {
    let progress: Double
    let completed: Bool
    var color: Color = GQColors.textSecondary
    var size: CGFloat = 48

    private var lineWidth: CGFloat { size >= 48 ? 5 : 4 }
    private var iconSize: CGFloat { size >= 48 ? 16 : 12 }
    private var percentSize: CGFloat { size >= 48 ? 12 : 10 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(GQColors.borderDefault, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)

            if completed {
                Image(systemName: "checkmark")
                    .font(.system(size: iconSize, weight: .bold))
                    .foregroundColor(color)
            } else {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: percentSize, weight: .bold, design: .rounded))
                    .foregroundColor(GQColors.textSecondary)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Hero Calories Widget

struct HeroCaloriesWidget: View {
    var profile: UserProfile
    var size: WidgetSize = .large

    @StateObject private var nutritionService = NutritionService.shared

    private var todaysMeals: [MealLog] {
        nutritionService.getTodaysMeals(userId: profile.id)
    }

    private var totalCalories: Int {
        todaysMeals.compactMap(\.estimatedCalories).reduce(0, +)
    }

    private var progress: Double {
        guard profile.dailyCalorieGoal > 0 else { return 0 }
        return min(Double(totalCalories) / Double(profile.dailyCalorieGoal), 1.0)
    }

    private var weeklyCalories: [Int] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        guard let monday = cal.date(byAdding: .day, value: -daysFromMonday, to: today) else {
            return Array(repeating: 0, count: 7)
        }

        var daily = [Int](repeating: 0, count: 7)
        for i in 0..<7 {
            guard let dayStart = cal.date(byAdding: .day, value: i, to: monday),
                  let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else { continue }
            let meals = nutritionService.getMeals(userId: profile.id, from: dayStart, to: dayEnd)
            daily[i] = meals.compactMap(\.estimatedCalories).reduce(0, +)
        }
        return daily
    }

    var body: some View {
        Group {
            switch size {
            case .third:
                compactThirdBody
            case .half:
                halfBody
            case .large:
                largeBody
            }
        }
    }

    @ViewBuilder
    private var largeBody: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today's Calories")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(GQColors.textSecondary)

                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(totalCalories)")
                            .font(size.numberFont)
                            .foregroundColor(GQColors.textPrimary)
                            .contentTransition(.numericText())

                        Text("/ \(profile.dailyCalorieGoal)")
                            .font(size.goalFont)
                            .foregroundColor(GQColors.textTertiary)
                    }
                }

                Spacer()

                HeroProgressRing(
                    progress: progress,
                    completed: totalCalories >= profile.dailyCalorieGoal
                )
            }

            weeklyBars
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var halfBody: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Calories")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(totalCalories)")
                        .font(size.numberFont)
                        .foregroundColor(GQColors.textPrimary)
                        .contentTransition(.numericText())

                    Text("/ \(profile.dailyCalorieGoal)")
                        .font(size.goalFont)
                        .foregroundColor(GQColors.textTertiary)
                }
            }

            Spacer()

            HeroProgressRing(
                progress: progress,
                completed: totalCalories >= profile.dailyCalorieGoal,
                size: size.ringSize
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var compactThirdBody: some View {
        VStack(spacing: 4) {
            HeroProgressRing(
                progress: progress,
                completed: totalCalories >= profile.dailyCalorieGoal,
                size: size.ringSize
            )

            Text("\(totalCalories)")
                .font(size.numberFont)
                .foregroundColor(GQColors.textPrimary)
                .contentTransition(.numericText())

            Text("/ \(profile.dailyCalorieGoal) cal")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var weeklyBars: some View {
        let maxCal = max(weeklyCalories.max() ?? 1, 1)
        let labels = ["M", "T", "W", "T", "F", "S", "S"]

        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { i in
                VStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < currentDayIndex ? GQColors.textSecondary : GQColors.adaptiveOverlay(0.08))
                        .frame(height: max(4, CGFloat(weeklyCalories[i]) / CGFloat(maxCal) * 24))

                    Text(labels[i])
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var currentDayIndex: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return (weekday + 5) % 7 + 1
    }
}

// MARK: - Hero Steps Widget

struct HeroStepsWidget: View {
    var size: WidgetSize = .large

    @StateObject private var healthKit = HealthKitService.shared

    private let stepGoal = 10_000

    private var progress: Double {
        guard stepGoal > 0 else { return 0 }
        return min(Double(healthKit.steps) / Double(stepGoal), 1.0)
    }

    var body: some View {
        Group {
            switch size {
            case .third:
                compactThirdBody
            case .half:
                halfBody
            case .large:
                largeBody
            }
        }
    }

    @ViewBuilder
    private var largeBody: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Steps Today")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(healthKit.steps)")
                        .font(size.numberFont)
                        .foregroundColor(GQColors.textPrimary)
                        .contentTransition(.numericText())

                    Text("/ \(stepGoal / 1000)K")
                        .font(size.goalFont)
                        .foregroundColor(GQColors.textTertiary)
                }
            }

            Spacer()

            HeroProgressRing(
                progress: progress,
                completed: healthKit.steps >= stepGoal
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var halfBody: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Steps")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(healthKit.steps)")
                        .font(size.numberFont)
                        .foregroundColor(GQColors.textPrimary)
                        .contentTransition(.numericText())

                    Text("/ \(stepGoal / 1000)K")
                        .font(size.goalFont)
                        .foregroundColor(GQColors.textTertiary)
                }
            }

            Spacer()

            HeroProgressRing(
                progress: progress,
                completed: healthKit.steps >= stepGoal,
                size: size.ringSize
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var compactThirdBody: some View {
        VStack(spacing: 4) {
            HeroProgressRing(
                progress: progress,
                completed: healthKit.steps >= stepGoal,
                size: size.ringSize
            )

            Text("\(healthKit.steps)")
                .font(size.numberFont)
                .foregroundColor(GQColors.textPrimary)
                .contentTransition(.numericText())

            Text("/ \(stepGoal / 1000)K")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

// MARK: - Hero Macros Widget

struct HeroMacrosWidget: View {
    var profile: UserProfile
    var size: WidgetSize = .large

    @StateObject private var nutritionService = NutritionService.shared

    private var todaysMeals: [MealLog] {
        nutritionService.getTodaysMeals(userId: profile.id)
    }

    private var protein: Int { todaysMeals.compactMap(\.estimatedProtein).reduce(0, +) }
    private var carbs: Int { todaysMeals.compactMap(\.estimatedCarbs).reduce(0, +) }
    private var fat: Int { todaysMeals.compactMap(\.estimatedFat).reduce(0, +) }

    var body: some View {
        Group {
            switch size {
            case .third:
                compactThirdBody
            case .half:
                halfBody
            case .large:
                largeBody
            }
        }
    }

    @ViewBuilder
    private var largeBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's Macros")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(GQColors.textSecondary)

            macroBar(label: "Protein", current: protein, goal: profile.proteinGoalGrams, color: GQColors.textSecondary)
            macroBar(label: "Carbs", current: carbs, goal: profile.carbsGoalGrams, color: GQColors.textTertiary)
            macroBar(label: "Fat", current: fat, goal: profile.fatGoalGrams, color: GQColors.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var halfBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Macros")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(GQColors.textSecondary)

            macroBarCompact(label: "P", current: protein, goal: profile.proteinGoalGrams, color: GQColors.textSecondary)
            macroBarCompact(label: "C", current: carbs, goal: profile.carbsGoalGrams, color: GQColors.textTertiary)
            macroBarCompact(label: "F", current: fat, goal: profile.fatGoalGrams, color: GQColors.textTertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var compactThirdBody: some View {
        VStack(spacing: 6) {
            Text("Macros")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(GQColors.textSecondary)

            HStack(spacing: 2) {
                Text("P").font(.system(size: 9, weight: .bold)).foregroundColor(GQColors.textSecondary)
                Text("\(protein)").font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundColor(GQColors.textPrimary)
                Text("·").foregroundColor(GQColors.textTertiary)
                Text("C").font(.system(size: 9, weight: .bold)).foregroundColor(GQColors.textTertiary)
                Text("\(carbs)").font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundColor(GQColors.textPrimary)
                Text("·").foregroundColor(GQColors.textTertiary)
                Text("F").font(.system(size: 9, weight: .bold)).foregroundColor(GQColors.textTertiary)
                Text("\(fat)").font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundColor(GQColors.textPrimary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func macroBar(label: String, current: Int, goal: Int, color: Color) -> some View {
        VStack(spacing: 3) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(GQColors.textSecondary)
                Spacer()
                Text("\(current)g / \(goal)g")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(GQColors.textTertiary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(GQColors.adaptiveOverlay(0.08))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * min(CGFloat(current) / max(CGFloat(goal), 1), 1.0), height: 6)
                        .animation(.spring(response: 0.5), value: current)
                }
            }
            .frame(height: 6)
        }
    }

    @ViewBuilder
    private func macroBarCompact(label: String, current: Int, goal: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(GQColors.textSecondary)
                .frame(width: 10)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(GQColors.adaptiveOverlay(0.08))
                        .frame(height: 5)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * min(CGFloat(current) / max(CGFloat(goal), 1), 1.0), height: 5)
                        .animation(.spring(response: 0.5), value: current)
                }
            }
            .frame(height: 5)

            Text("\(current)/\(goal)g")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(GQColors.textTertiary)
                .fixedSize()
        }
    }
}

// MARK: - Hero Active Calories Widget

struct HeroActiveCaloriesWidget: View {
    var size: WidgetSize = .large
    var activeCalGoal: Int = 600

    @StateObject private var healthKit = HealthKitService.shared

    private var progress: Double {
        guard activeCalGoal > 0 else { return 0 }
        return min(Double(healthKit.activeCalories) / Double(activeCalGoal), 1.0)
    }

    var body: some View {
        Group {
            switch size {
            case .third: thirdBody
            case .half: halfBody
            case .large: largeBody
            }
        }
    }

    @ViewBuilder private var largeBody: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Active Calories")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(healthKit.activeCalories)")
                        .font(size.numberFont)
                        .foregroundColor(GQColors.textPrimary)
                        .contentTransition(.numericText())
                    Text("/ \(activeCalGoal)")
                        .font(size.goalFont)
                        .foregroundColor(GQColors.textTertiary)
                }
            }
            Spacer()
            HeroProgressRing(progress: progress, completed: healthKit.activeCalories >= activeCalGoal, color: GQColors.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder private var halfBody: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Burned")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(healthKit.activeCalories)")
                        .font(size.numberFont)
                        .foregroundColor(GQColors.textPrimary)
                        .contentTransition(.numericText())
                    Text("cal")
                        .font(size.goalFont)
                        .foregroundColor(GQColors.textTertiary)
                }
            }
            Spacer()
            HeroProgressRing(progress: progress, completed: healthKit.activeCalories >= activeCalGoal, color: GQColors.textSecondary, size: size.ringSize)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    @ViewBuilder private var thirdBody: some View {
        VStack(spacing: 4) {
            HeroProgressRing(
                progress: progress,
                completed: healthKit.activeCalories >= activeCalGoal,
                color: GQColors.textSecondary,
                size: size.ringSize
            )
            Text("\(healthKit.activeCalories)")
                .font(size.numberFont)
                .foregroundColor(GQColors.textPrimary)
                .contentTransition(.numericText())
            Text("/ \(activeCalGoal) cal")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

// MARK: - Hero Sleep Widget

struct HeroSleepWidget: View {
    var size: WidgetSize = .large

    @StateObject private var healthKit = HealthKitService.shared

    private let sleepGoal: Double = 8.0

    private var progress: Double {
        guard sleepGoal > 0 else { return 0 }
        return min(healthKit.sleepHours / sleepGoal, 1.0)
    }

    private var hoursText: String {
        let h = Int(healthKit.sleepHours)
        let m = Int((healthKit.sleepHours - Double(h)) * 60)
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }

    var body: some View {
        Group {
            switch size {
            case .third: thirdBody
            case .half: halfBody
            case .large: largeBody
            }
        }
    }

    @ViewBuilder private var largeBody: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Last Night's Sleep")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(hoursText)
                        .font(size.numberFont)
                        .foregroundColor(GQColors.textPrimary)
                    Text("/ \(Int(sleepGoal))h")
                        .font(size.goalFont)
                        .foregroundColor(GQColors.textTertiary)
                }
            }
            Spacer()
            HeroProgressRing(progress: progress, completed: healthKit.sleepHours >= sleepGoal, color: GQColors.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder private var halfBody: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Sleep")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)
                Text(hoursText)
                    .font(size.numberFont)
                    .foregroundColor(GQColors.textPrimary)
            }
            Spacer()
            HeroProgressRing(progress: progress, completed: healthKit.sleepHours >= sleepGoal, color: GQColors.textSecondary, size: size.ringSize)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    @ViewBuilder private var thirdBody: some View {
        VStack(spacing: 4) {
            HeroProgressRing(
                progress: progress,
                completed: healthKit.sleepHours >= sleepGoal,
                color: GQColors.textSecondary,
                size: size.ringSize
            )
            Text(hoursText)
                .font(size.numberFont)
                .foregroundColor(GQColors.textPrimary)
            Text("/ \(Int(sleepGoal))h")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

// MARK: - Hero Streak Widget

struct HeroStreakWidget: View {
    var workouts: [Workout] = []
    var size: WidgetSize = .large

    private var streakDays: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let sortedDates = Set(workouts.map { cal.startOfDay(for: $0.date) }).sorted(by: >)
        guard let latest = sortedDates.first else { return 0 }

        // Only count streak if latest workout is today or yesterday
        let daysSinceLast = cal.dateComponents([.day], from: latest, to: today).day ?? 0
        guard daysSinceLast <= 1 else { return 0 }

        var streak = 1
        for i in 1..<sortedDates.count {
            let diff = cal.dateComponents([.day], from: sortedDates[i], to: sortedDates[i - 1]).day ?? 0
            if diff == 1 {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    var body: some View {
        Group {
            switch size {
            case .third: thirdBody
            case .half: halfBody
            case .large: largeBody
            }
        }
    }

    @ViewBuilder private var largeBody: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Workout Streak")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(streakDays)")
                        .font(size.numberFont)
                        .foregroundColor(GQColors.textPrimary)
                        .contentTransition(.numericText())
                    Text(streakDays == 1 ? "day" : "days")
                        .font(size.goalFont)
                        .foregroundColor(GQColors.textTertiary)
                }
            }
            Spacer()
            Image(systemName: "trophy.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(GQColors.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder private var halfBody: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Streak")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(GQColors.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(streakDays)")
                    .font(size.numberFont)
                    .foregroundColor(GQColors.textPrimary)
                    .contentTransition(.numericText())
                Text(streakDays == 1 ? "day" : "days")
                    .font(size.goalFont)
                    .foregroundColor(GQColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    @ViewBuilder private var thirdBody: some View {
        VStack(spacing: 4) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(GQColors.textTertiary)
            Text("\(streakDays)")
                .font(size.numberFont)
                .foregroundColor(GQColors.textPrimary)
                .contentTransition(.numericText())
            Text("Streak")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(GQColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

// MARK: - Hero Heart Rate Widget

struct HeroHeartRateWidget: View {
    var size: WidgetSize = .large

    @StateObject private var healthKit = HealthKitService.shared

    var body: some View {
        Group {
            switch size {
            case .third: thirdBody
            case .half: halfBody
            case .large: largeBody
            }
        }
    }

    @ViewBuilder private var largeBody: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Resting Heart Rate")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(healthKit.restingHeartRate)")
                        .font(size.numberFont)
                        .foregroundColor(GQColors.textPrimary)
                        .contentTransition(.numericText())
                    Text("bpm")
                        .font(size.goalFont)
                        .foregroundColor(GQColors.textTertiary)
                }
            }
            Spacer()
            Image(systemName: "heart.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(GQColors.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder private var halfBody: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Heart Rate")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(GQColors.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(healthKit.restingHeartRate)")
                    .font(size.numberFont)
                    .foregroundColor(GQColors.textPrimary)
                    .contentTransition(.numericText())
                Text("bpm")
                    .font(size.goalFont)
                    .foregroundColor(GQColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    @ViewBuilder private var thirdBody: some View {
        VStack(spacing: 4) {
            Image(systemName: "heart.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(GQColors.textTertiary)
            Text("\(healthKit.restingHeartRate)")
                .font(size.numberFont)
                .foregroundColor(GQColors.textPrimary)
                .contentTransition(.numericText())
            Text("bpm")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(GQColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

// MARK: - Hero Recovery Widget

struct HeroRecoveryWidget: View {
    var size: WidgetSize = .large

    @StateObject private var integration = IntegrationManager.shared

    private var recoveryColor: Color {
        switch integration.readinessLevel {
        case .optimal: GQColors.textSecondary
        case .good: GQColors.textSecondary
        case .moderate: GQColors.textTertiary
        case .low: GQColors.textTertiary
        }
    }

    var body: some View {
        Group {
            switch size {
            case .third: thirdBody
            case .half: halfBody
            case .large: largeBody
            }
        }
    }

    @ViewBuilder private var largeBody: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Recovery")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(Int(integration.recoveryScore))%")
                        .font(size.numberFont)
                        .foregroundColor(GQColors.textPrimary)
                        .contentTransition(.numericText())
                    Text(integration.readinessLevel.rawValue)
                        .font(size.goalFont)
                        .foregroundColor(recoveryColor)
                }
            }
            Spacer()
            HeroProgressRing(progress: integration.recoveryScore / 100, completed: integration.recoveryScore >= 67, color: recoveryColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder private var halfBody: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Recovery")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)
                Text("\(Int(integration.recoveryScore))%")
                    .font(size.numberFont)
                    .foregroundColor(GQColors.textPrimary)
                    .contentTransition(.numericText())
            }
            Spacer()
            HeroProgressRing(progress: integration.recoveryScore / 100, completed: integration.recoveryScore >= 67, color: recoveryColor, size: size.ringSize)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    @ViewBuilder private var thirdBody: some View {
        VStack(spacing: 4) {
            Image(systemName: "battery.100.bolt")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(recoveryColor)
            Text("\(Int(integration.recoveryScore))%")
                .font(size.numberFont)
                .foregroundColor(GQColors.textPrimary)
                .contentTransition(.numericText())
            Text("Recovery")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(GQColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

// MARK: - Social Hero Widget (Grid Dispatcher + Jiggle Edit Mode)

struct SocialHeroWidget: View {
    var profile: UserProfile
    var workoutsCompleted: Int
    var allWorkouts: [Workout]

    @Environment(\.modelContext) private var modelContext
    @State private var isEditing = false
    @State private var pickerSlotIndex: Int? = nil
    @State private var showHint = false
    @AppStorage("hasSeenWidgetHint") private var hasSeenHint = false

    private var config: WidgetGridConfig { profile.widgetGridConfig }

    var body: some View {
        VStack(spacing: 8) {
            if config.allEmpty && !isEditing {
                addWidgetButton
            } else {
                if isEditing {
                    layoutPickerRow
                }

                widgetGrid
                    .overlay(alignment: .bottom) {
                        if showHint && !isEditing {
                            Text("Hold to customize")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(GQColors.textTertiary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.ultraThinMaterial, in: Capsule())
                                .offset(y: 24)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }

                if isEditing {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isEditing = false
                        }
                    } label: {
                        Text("Done")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(GQColors.deepBlue)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                            .background(GQColors.adaptiveOverlay(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .sheet(item: $pickerSlotIndex) { slotIndex in
            WidgetSlotPicker(profile: profile, slotIndex: slotIndex)
                .environment(\.modelContext, modelContext)
        }
        .onAppear {
            guard !hasSeenHint, !config.allEmpty else { return }
            withAnimation(.easeOut(duration: 0.4).delay(1.0)) {
                showHint = true
            }
            withAnimation(.easeIn(duration: 0.4).delay(4.0)) {
                showHint = false
            }
            hasSeenHint = true
        }
    }

    // MARK: - Add Widget Button (all slots empty)

    @ViewBuilder
    private var addWidgetButton: some View {
        Button {
            enterEditMode()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                Text("Add widget")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(GQColors.textTertiary)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Layout Picker Row

    @ViewBuilder
    private var layoutPickerRow: some View {
        HStack(spacing: 2) {
            ForEach(WidgetLayout.allCases, id: \.self) { layout in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        var newConfig = config
                        newConfig.layout = layout
                        newConfig.adjustSlots()
                        profile.widgetGridConfig = newConfig
                        try? modelContext.save()
                    }
                } label: {
                    layoutIcon(for: layout)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            config.layout == layout
                                ? GQColors.adaptiveOverlay(0.12)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(GQColors.adaptiveOverlay(0.06), in: RoundedRectangle(cornerRadius: 9))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    @ViewBuilder
    private func layoutIcon(for layout: WidgetLayout) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<layout.slotCount, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 2)
                    .fill(config.layout == layout ? GQColors.textPrimary : GQColors.textTertiary)
                    .frame(width: layout == .single ? 16 : 8, height: 12)
            }
        }
    }

    // MARK: - Widget Grid

    @ViewBuilder
    private var widgetGrid: some View {
        switch config.layout {
        case .single:
            slotView(index: 0, size: .large)
        case .double:
            HStack(spacing: 8) {
                slotView(index: 0, size: .half)
                slotView(index: 1, size: .half)
            }
        case .triple:
            HStack(spacing: 8) {
                slotView(index: 0, size: .third)
                slotView(index: 1, size: .third)
                slotView(index: 2, size: .third)
            }
        }
    }

    // MARK: - Slot View (wraps widget content + edit chrome)

    @ViewBuilder
    private func slotView(index: Int, size: WidgetSize) -> some View {
        let widgetType = index < config.slots.count ? config.slots[index] : .none

        Group {
            if widgetType == .none {
                emptySlotView(index: index)
            } else {
                widgetContentView(type: widgetType, size: size)
            }
        }
        .homeSocialCard()
        .frame(minHeight: size == .third ? 80 : nil)
        .overlay {
            if isEditing && widgetType != .none {
                // Tap-to-change overlay
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black.opacity(0.35))
                    .overlay {
                        VStack(spacing: 4) {
                            Image(systemName: "pencil")
                                .font(.system(size: size == .third ? 16 : 20, weight: .semibold))
                            if size != .third {
                                Text("Tap to change")
                                    .font(.system(size: 11, weight: .medium))
                            }
                        }
                        .foregroundColor(GQColors.textSecondary)
                    }
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .topLeading) {
            if isEditing && widgetType != .none {
                Button {
                    clearSlot(index)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white, Color.black.opacity(0.4))
                }
                .buttonStyle(.plain)
                .offset(x: -6, y: -6)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .scaleEffect(isEditing ? 0.96 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isEditing)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    if !isEditing {
                        enterEditMode()
                    }
                }
        )
        .onTapGesture {
            if isEditing {
                pickerSlotIndex = index
            }
        }
    }

    // MARK: - Empty Slot

    @ViewBuilder
    private func emptySlotView(index: Int) -> some View {
        Button {
            if isEditing {
                pickerSlotIndex = index
            } else {
                enterEditMode()
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(GQColors.textTertiary)
                if config.layout != .triple {
                    Text("Add")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 60)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Widget Content Router

    @ViewBuilder
    private func widgetContentView(type: SocialWidgetType, size: WidgetSize) -> some View {
        switch type {
        case .workouts:
            WeeklyHeroSection(
                completed: workoutsCompleted,
                goal: profile.daysPerWeek,
                profile: profile,
                workouts: allWorkouts,
                size: size
            )
        case .calories:
            HeroCaloriesWidget(profile: profile, size: size)
        case .steps:
            HeroStepsWidget(size: size)
        case .macros:
            HeroMacrosWidget(profile: profile, size: size)
        case .activeCalories:
            HeroActiveCaloriesWidget(size: size)
        case .sleep:
            HeroSleepWidget(size: size)
        case .streak:
            HeroStreakWidget(workouts: allWorkouts, size: size)
        case .heartRate:
            HeroHeartRateWidget(size: size)
        case .recovery:
            HeroRecoveryWidget(size: size)
        case .none:
            EmptyView()
        }
    }

    // MARK: - Actions

    private func enterEditMode() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isEditing = true
        }
    }

    private func clearSlot(_ index: Int) {
        var newConfig = config
        if index < newConfig.slots.count {
            newConfig.slots[index] = .none
        }
        profile.widgetGridConfig = newConfig
        try? modelContext.save()
    }
}

// MARK: - Int Identifiable for sheet(item:)

extension Int: @retroactive Identifiable {
    public var id: Int { self }
}

// MARK: - Widget Slot Picker

struct WidgetSlotPicker: View {
    var profile: UserProfile
    let slotIndex: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private var currentType: SocialWidgetType {
        let config = profile.widgetGridConfig
        return slotIndex < config.slots.count ? config.slots[slotIndex] : .none
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(SocialWidgetType.allCases.filter { $0 != .none }, id: \.self) { type in
                    Button {
                        setSlot(to: type)
                    } label: {
                        pickerRow(type: type)
                    }
                }

                Section {
                    Button {
                        setSlot(to: .none)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "trash")
                                .font(.system(size: 16))
                                .foregroundColor(GQColors.textSecondary)
                                .frame(width: 28, height: 28)

                            Text("Remove")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(GQColors.textSecondary)

                            Spacer()

                            if currentType == .none {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(GQColors.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Choose Widget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func pickerRow(type: SocialWidgetType) -> some View {
        HStack(spacing: 12) {
            Image(systemName: type.iconName)
                .font(.system(size: 16))
                .foregroundColor(type.accentColor)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(type.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)
                Text(type.subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textSecondary)
            }

            Spacer()

            if currentType == type {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(type.accentColor)
            }
        }
        .padding(.vertical, 4)
    }

    private func setSlot(to type: SocialWidgetType) {
        var newConfig = profile.widgetGridConfig
        while newConfig.slots.count <= slotIndex {
            newConfig.slots.append(.workouts)
        }
        newConfig.slots[slotIndex] = type
        profile.widgetGridConfig = newConfig
        try? modelContext.save()
        dismiss()
    }
}


