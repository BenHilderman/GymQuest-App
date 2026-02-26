//
//  LogView.swift
//  GymQuest
//
//  Log tab — tabbed view for Workout history, Nutrition tracking, and Body stats.
//

import SwiftUI
import SwiftData
import PhotosUI
import Charts

// MARK: - Log Tab Enum

enum LogTab: String, CaseIterable {
    case workout = "Workout"
    case nutrition = "Nutrition"
    case body = "Body"
}

struct LogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var measurements: [BodyMeasurement]
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @Query(sort: \PREvent.date, order: .reverse) private var prEvents: [PREvent]

    let profile: UserProfile

    @State private var selectedTab: LogTab = .workout
    @State private var showingMealLog = false
    @State private var showingAddMeasurement = false
    @State private var showingBodyMeasurements = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var todayMeals: [MealLog] = []
    @State private var weeklyMealsByDay: [(date: Date, calories: Int)] = []
    @State private var isEditingDaysGoal = false

    // MARK: - Computed Properties

    private var userMeasurements: [BodyMeasurement] {
        measurements.filter { $0.userId == profile.id }
    }

    private var weightMeasurements: [BodyMeasurement] {
        userMeasurements
            .filter { $0.type == .weight }
            .sorted { $0.date < $1.date }
    }

    private var latestWeight: BodyMeasurement? {
        userMeasurements.first { $0.type == .weight }
    }

    private var latestBodyFat: BodyMeasurement? {
        userMeasurements.first { $0.type == .bodyFat }
    }

    private var latestWaist: BodyMeasurement? {
        userMeasurements.first { $0.type == .waist }
    }

    private var progressPhotos: [BodyMeasurement] {
        userMeasurements.filter { $0.photoData != nil }
    }

    private var todayCalories: Int {
        todayMeals.reduce(0) { $0 + ($1.estimatedCalories ?? 0) }
    }

    private var todayProtein: Int {
        todayMeals.reduce(0) { $0 + ($1.estimatedProtein ?? 0) }
    }

    private var todayCarbs: Int {
        todayMeals.reduce(0) { $0 + ($1.estimatedCarbs ?? 0) }
    }

    private var todayFat: Int {
        todayMeals.reduce(0) { $0 + ($1.estimatedFat ?? 0) }
    }

    private var thisWeekWorkouts: [Workout] {
        let cal = Calendar.current
        let startOfWeek = cal.startOfWeek(for: Date())
        return workouts.filter { $0.date >= startOfWeek }
    }

    private var recentPRs: [PREvent] {
        Array(prEvents.prefix(3))
    }

    /// Returns a Set of weekday indexes (1=Sun, 2=Mon, ..., 7=Sat) for days this week with workouts
    private var weekdaysWithWorkouts: Set<Int> {
        let cal = Calendar.current
        return Set(thisWeekWorkouts.map { cal.component(.weekday, from: $0.date) })
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabPicker
                ScrollView {
                    VStack(spacing: 14) {
                        switch selectedTab {
                        case .workout:
                            workoutTabContent
                        case .nutrition:
                            nutritionTabContent
                        case .body:
                            bodyTabContent
                        }
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 12)
                }
            }
            .scrollContentBackground(.hidden)
            .gqHomePageBackground()
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Log")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(GQColors.textPrimary)
                }
            }
            .onAppear {
                loadTodayMeals()
                loadWeeklyCalories()
            }
            .sheet(isPresented: $showingMealLog) {
                MealLogView(profile: profile)
            }
            .sheet(isPresented: $showingAddMeasurement) {
                AddMeasurementSheet(profile: profile)
            }
            .sheet(isPresented: $showingBodyMeasurements) {
                NavigationStack {
                    BodyMeasurementsView(profile: profile)
                }
            }
            .onChange(of: showingMealLog) { _, isShowing in
                if !isShowing {
                    loadTodayMeals()
                    loadWeeklyCalories()
                }
            }
            .onChange(of: showingAddMeasurement) { _, isShowing in
                if !isShowing { loadTodayMeals() }
            }
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(LogTab.allCases, id: \.self) { tab in
                logTabButton(tab)
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func logTabButton(_ tab: LogTab) -> some View {
        let isSelected = selectedTab == tab
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            Text(tab.rawValue)
                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? GQColors.textPrimary : GQColors.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? GQColors.cyanSpark.opacity(0.1) : Color.clear)
                .overlay(alignment: .bottom) {
                    if isSelected {
                        Rectangle()
                            .frame(height: 2)
                            .foregroundColor(GQColors.cyanSpark)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Workout Tab

    @ViewBuilder
    private var workoutTabContent: some View {
        thisWeekSummaryCard
        volumeChartCard
        recentWorkoutsCard
        recentPRsCard
    }

    @ViewBuilder
    private var thisWeekSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("THIS WEEK")
                    .font(GQTypography.sectionHeader)
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(1)

                Spacer()

                // Editable days/week goal
                Button {
                    isEditingDaysGoal.toggle()
                } label: {
                    HStack(spacing: 3) {
                        Text("\(thisWeekWorkouts.count)/\(profile.daysPerWeek)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(thisWeekWorkouts.count >= profile.daysPerWeek ? .green : GQColors.cyanSpark)
                        Text("days")
                            .font(.system(size: 11))
                            .foregroundColor(GQColors.textTertiary)
                        Image(systemName: "pencil")
                            .font(.system(size: 9))
                            .foregroundColor(GQColors.textTertiary)
                    }
                }
                .buttonStyle(.plain)
            }

            // Days-per-week stepper (shown when editing)
            if isEditingDaysGoal {
                HStack(spacing: 12) {
                    Text("Goal")
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textSecondary)
                    Spacer()
                    HStack(spacing: 0) {
                        Button {
                            if profile.daysPerWeek > 1 {
                                profile.daysPerWeek -= 1
                                try? modelContext.save()
                            }
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(GQColors.textPrimary)
                                .frame(width: 32, height: 32)
                                .background(GQColors.adaptiveOverlay(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)

                        Text("\(profile.daysPerWeek)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(GQColors.textPrimary)
                            .frame(width: 40)
                            .multilineTextAlignment(.center)

                        Button {
                            if profile.daysPerWeek < 7 {
                                profile.daysPerWeek += 1
                                try? modelContext.save()
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(GQColors.textPrimary)
                                .frame(width: 32, height: 32)
                                .background(GQColors.adaptiveOverlay(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                    Text("days/week")
                        .font(.system(size: 12))
                        .foregroundColor(GQColors.textTertiary)
                }
                .padding(.vertical, 4)
            }

            // Subtle week day indicator (Mon-Sun dots)
            HStack(spacing: 0) {
                let cal = Calendar.current
                let weekdaySymbols = cal.veryShortWeekdaySymbols // ["S","M","T","W","T","F","S"]
                // Reorder to start from Monday: indices [1,2,3,4,5,6,0] in Calendar (weekday 2=Mon through 1=Sun)
                let mondayFirst = [2, 3, 4, 5, 6, 7, 1] // weekday values, Mon=2 ... Sun=1
                let symbolsReordered = [weekdaySymbols[1], weekdaySymbols[2], weekdaySymbols[3],
                                        weekdaySymbols[4], weekdaySymbols[5], weekdaySymbols[6],
                                        weekdaySymbols[0]]

                ForEach(Array(zip(mondayFirst, symbolsReordered).enumerated()), id: \.offset) { _, pair in
                    let (weekday, symbol) = pair
                    let didWorkout = weekdaysWithWorkouts.contains(weekday)
                    VStack(spacing: 4) {
                        Text(symbol)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(GQColors.textTertiary)
                        Circle()
                            .fill(didWorkout ? GQColors.cyanSpark : GQColors.adaptiveOverlay(0.08))
                            .frame(width: 8, height: 8)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            // Stats row
            HStack(spacing: 0) {
                weekStatPill(
                    value: formatVolume(thisWeekWorkouts.reduce(0.0) { $0 + $1.totalVolume }),
                    label: "Volume",
                    icon: "scalemass.fill"
                )
                weekStatPill(
                    value: "\(thisWeekWorkouts.reduce(0) { $0 + $1.duration })m",
                    label: "Duration",
                    icon: "clock.fill"
                )
                weekStatPill(
                    value: "\(thisWeekWorkouts.reduce(0) { $0 + $1.totalSets })",
                    label: "Sets",
                    icon: "flame.fill"
                )
            }
        }
        .padding(16)
        .homeSocialCard(cornerRadius: 16)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func weekStatPill(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(GQGradients.primary)
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(GQColors.textPrimary)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var volumeChartCard: some View {
        let weeklyVolume = computeWeeklyVolume()
        if !weeklyVolume.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("VOLUME TREND")
                    .font(GQTypography.sectionHeader)
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(1)

                Chart(weeklyVolume, id: \.weekStart) { entry in
                    BarMark(
                        x: .value("Week", entry.weekStart, unit: .weekOfYear),
                        y: .value("Volume", entry.volume)
                    )
                    .foregroundStyle(GQGradients.primary)
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .font(.system(size: 9))
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                            .foregroundStyle(GQColors.adaptiveOverlay(0.06))
                    }
                }
                .frame(height: 140)
            }
            .padding(16)
            .homeSocialCard(cornerRadius: 16)
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var recentWorkoutsCard: some View {
        let recent = Array(workouts.prefix(5))
        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("RECENT WORKOUTS")
                    .font(GQTypography.sectionHeader)
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(1)

                ForEach(recent) { workout in
                    HStack(spacing: 10) {
                        Image(systemName: workout.type.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(GQGradients.primary)
                            .frame(width: 28, height: 28)
                            .background(GQColors.cyanSpark.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(workout.title ?? workout.type.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(GQColors.textPrimary)
                            Text("\(workout.duration)m · \(workout.totalSets) sets")
                                .font(.system(size: 11))
                                .foregroundColor(GQColors.textTertiary)
                        }

                        Spacer()

                        Text(workout.date.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.system(size: 11))
                            .foregroundColor(GQColors.textTertiary)
                    }
                    if workout.id != recent.last?.id {
                        Divider().foregroundColor(GQColors.adaptiveOverlay(0.06))
                    }
                }
            }
            .padding(16)
            .homeSocialCard(cornerRadius: 16)
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var recentPRsCard: some View {
        if !recentPRs.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("RECENT PRs")
                    .font(GQTypography.sectionHeader)
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(1)

                ForEach(recentPRs) { pr in
                    HStack(spacing: 10) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                            .frame(width: 24, height: 24)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(pr.exerciseName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(GQColors.textPrimary)
                            Text("\(pr.prType.rawValue) — \(Int(pr.newValue)) lbs")
                                .font(.system(size: 11))
                                .foregroundColor(GQColors.textTertiary)
                        }

                        Spacer()

                        if let delta = pr.deltaDisplay {
                            Text(delta)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .padding(16)
            .homeSocialCard(cornerRadius: 16)
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Nutrition Tab

    @ViewBuilder
    private var nutritionTabContent: some View {
        calorieRingCard
        macroBarsCard
        todaysMealsSection
        weeklyCalorieChartCard
    }

    @ViewBuilder
    private var calorieRingCard: some View {
        let goal = max(profile.dailyCalorieGoal, 1)
        let progress = min(Double(todayCalories) / Double(goal), 1.5)
        let clampedProgress = min(progress, 1.0)
        let isOver = progress > 1.0
        let remaining = goal - todayCalories

        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(GQColors.adaptiveOverlay(0.08), lineWidth: 12)
                    .frame(width: 120, height: 120)

                calorieRingArc(trimTo: clampedProgress, isOver: isOver)

                VStack(spacing: 2) {
                    Text("\(todayCalories)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(GQColors.textPrimary)
                    Text("/ \(goal) cal")
                        .font(.system(size: 11))
                        .foregroundColor(GQColors.textTertiary)
                }
            }

            Text(remaining >= 0 ? "\(remaining) cal remaining" : "\(-remaining) cal over goal")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(remaining >= 0 ? GQColors.textSecondary : .red)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .homeSocialCard(cornerRadius: 16)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func calorieRingArc(trimTo: Double, isOver: Bool) -> some View {
        if isOver {
            Circle()
                .trim(from: 0, to: trimTo)
                .stroke(Color.red, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 120, height: 120)
        } else {
            Circle()
                .trim(from: 0, to: trimTo)
                .stroke(GQColors.cyanSpark, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 120, height: 120)
        }
    }

    @ViewBuilder
    private var macroBarsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MACROS")
                .font(GQTypography.sectionHeader)
                .foregroundColor(GQColors.textTertiary)
                .tracking(1)

            macroBar(label: "Protein", current: todayProtein, goal: profile.proteinGoalGrams, color: .blue)
            macroBar(label: "Carbs", current: todayCarbs, goal: profile.carbsGoalGrams, color: .orange)
            macroBar(label: "Fat", current: todayFat, goal: profile.fatGoalGrams, color: .purple)
        }
        .padding(16)
        .homeSocialCard(cornerRadius: 16)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func macroBar(label: String, current: Int, goal: Int, color: Color) -> some View {
        let safeGoal = max(goal, 1)
        let progress = min(Double(current) / Double(safeGoal), 1.5)

        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(GQColors.textPrimary)
                Spacer()
                Text("\(current)g / \(goal)g")
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textTertiary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(GQColors.adaptiveOverlay(0.06))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(progress > 1.0 ? Color.red : color)
                        .frame(width: geo.size.width * min(progress, 1.0), height: 8)
                }
            }
            .frame(height: 8)
        }
    }

    @ViewBuilder
    private var todaysMealsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TODAY'S MEALS")
                    .font(GQTypography.sectionHeader)
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(1)

                Spacer()

                if !todayMeals.isEmpty {
                    let totalCal = todayMeals.reduce(0) { $0 + ($1.estimatedCalories ?? 0) }
                    if totalCal > 0 {
                        Text("\(totalCal) cal")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                }
            }

            if todayMeals.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 24))
                            .foregroundColor(GQColors.textTertiary)
                        Text("No meals logged today")
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textTertiary)
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
            } else {
                ForEach(todayMeals) { meal in
                    MealSummaryRow(meal: meal)
                }
            }

            Button {
                showingMealLog = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Log Meal")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(GQColors.cyanSpark)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(GQColors.cyanSpark.opacity(0.1))
                .cornerRadius(10)
            }
            .buttonStyle(GQInteractiveStyle())
        }
        .padding(16)
        .homeSocialCard(cornerRadius: 16)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var weeklyCalorieChartCard: some View {
        if !weeklyMealsByDay.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("WEEKLY CALORIES")
                    .font(GQTypography.sectionHeader)
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(1)

                let goal = profile.dailyCalorieGoal
                Chart {
                    ForEach(weeklyMealsByDay, id: \.date) { entry in
                        BarMark(
                            x: .value("Day", entry.date, unit: .day),
                            y: .value("Calories", entry.calories)
                        )
                        .foregroundStyle(entry.calories > goal ? AnyShapeStyle(Color.red.opacity(0.7)) : AnyShapeStyle(GQGradients.primary))
                        .cornerRadius(4)
                    }

                    RuleMark(y: .value("Goal", goal))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                        .foregroundStyle(GQColors.textTertiary)
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Goal")
                                .font(.system(size: 9))
                                .foregroundColor(GQColors.textTertiary)
                        }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                            .font(.system(size: 9))
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                            .foregroundStyle(GQColors.adaptiveOverlay(0.06))
                    }
                }
                .frame(height: 140)
            }
            .padding(16)
            .homeSocialCard(cornerRadius: 16)
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Body Tab

    @ViewBuilder
    private var bodyTabContent: some View {
        weightChartCard
        currentVsGoalCard
        bodyMeasurementsSection
        progressPhotosSection
    }

    @ViewBuilder
    private var weightChartCard: some View {
        let last30 = weightMeasurements.filter {
            $0.date >= Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        }

        VStack(alignment: .leading, spacing: 10) {
            Text("WEIGHT (30 DAYS)")
                .font(GQTypography.sectionHeader)
                .foregroundColor(GQColors.textTertiary)
                .tracking(1)

            if last30.count >= 2 {
                Chart {
                    ForEach(last30, id: \.id) { m in
                        AreaMark(
                            x: .value("Date", m.date),
                            y: .value("Weight", m.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [GQColors.cyanSpark.opacity(0.2), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Date", m.date),
                            y: .value("Weight", m.value)
                        )
                        .foregroundStyle(GQColors.cyanSpark.gradient)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }

                    if let goal = profile.goalWeight, goal > 0 {
                        RuleMark(y: .value("Goal", goal))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                            .foregroundStyle(GQColors.vividPurple)
                            .annotation(position: .top, alignment: .trailing) {
                                Text("Goal")
                                    .font(.system(size: 9))
                                    .foregroundColor(GQColors.vividPurple)
                            }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .font(.system(size: 9))
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                            .foregroundStyle(GQColors.adaptiveOverlay(0.06))
                    }
                }
                .frame(height: 180)
            } else {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 24))
                            .foregroundColor(GQColors.textTertiary)
                        Text("Log 2+ weights to see chart")
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textTertiary)
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
            }
        }
        .padding(16)
        .homeSocialCard(cornerRadius: 16)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var currentVsGoalCard: some View {
        HStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("Current")
                    .font(.system(size: 11))
                    .foregroundColor(GQColors.textTertiary)
                if let w = latestWeight {
                    Text(String(format: "%.1f", w.value))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(GQGradients.primary)
                    + Text(" lbs")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)
                } else {
                    Text("—")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(GQColors.textTertiary)
                }
            }

            if let goal = profile.goalWeight, goal > 0 {
                VStack(spacing: 4) {
                    Text("Goal")
                        .font(.system(size: 11))
                        .foregroundColor(GQColors.textTertiary)
                    Text(String(format: "%.1f", goal))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(GQColors.vividPurple)
                    + Text(" lbs")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)
                }

                if let current = latestWeight?.value {
                    let delta = current - goal
                    VStack(spacing: 4) {
                        Text("Delta")
                            .font(.system(size: 11))
                            .foregroundColor(GQColors.textTertiary)
                        Text(String(format: "%+.1f", delta))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(delta > 0 ? .orange : .green)
                        + Text(" lbs")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(GQColors.textTertiary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .homeSocialCard(cornerRadius: 16)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var bodyMeasurementsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("BODY MEASUREMENTS")
                    .font(GQTypography.sectionHeader)
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(1)

                Spacer()

                Button {
                    showingBodyMeasurements = true
                } label: {
                    Text("See All")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(GQColors.cyanSpark)
                }
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                QuickStatCard(type: .weight, measurement: latestWeight)
                QuickStatCard(type: .bodyFat, measurement: latestBodyFat)
                QuickStatCard(type: .waist, measurement: latestWaist)
            }

            HStack(spacing: 10) {
                Button {
                    showingAddMeasurement = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Log Weight")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(GQColors.cyanSpark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(GQColors.cyanSpark.opacity(0.1))
                    .cornerRadius(10)
                }
                .buttonStyle(GQInteractiveStyle())

                Button {
                    showingBodyMeasurements = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "ruler")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Measurements")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(GQColors.vividPurple)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(GQColors.vividPurple.opacity(0.1))
                    .cornerRadius(10)
                }
                .buttonStyle(GQInteractiveStyle())
            }
        }
        .padding(16)
        .homeSocialCard(cornerRadius: 16)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var progressPhotosSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("PROGRESS PHOTOS")
                    .font(GQTypography.sectionHeader)
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(1)

                Spacer()

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(GQGradients.primary)
                }
                .onChange(of: selectedPhotoItem) { _, newItem in
                    Task { await saveProgressPhoto(from: newItem) }
                }
            }

            if progressPhotos.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "camera")
                            .font(.system(size: 24))
                            .foregroundColor(GQColors.textTertiary)
                        Text("Track your transformation")
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textTertiary)
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(progressPhotos.prefix(10)) { measurement in
                            progressPhotoTile(measurement)
                        }
                    }
                }
            }
        }
        .padding(16)
        .homeSocialCard(cornerRadius: 16)
        .padding(.horizontal, 16)
    }

    #if canImport(UIKit)
    @ViewBuilder
    private func progressPhotoTile(_ measurement: BodyMeasurement) -> some View {
        if let data = measurement.photoData, let uiImage = UIImage(data: data) {
            VStack(spacing: 4) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(GQGradients.glassBorder, lineWidth: 1)
                    )

                Text(measurement.date.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.system(size: 9))
                    .foregroundColor(GQColors.textTertiary)
            }
        }
    }
    #else
    @ViewBuilder
    private func progressPhotoTile(_ measurement: BodyMeasurement) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.06))
                .frame(width: 80, height: 100)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(GQColors.textTertiary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(GQGradients.glassBorder, lineWidth: 1)
                )

            Text(measurement.date.formatted(.dateTime.month(.abbreviated).day()))
                .font(.system(size: 9))
                .foregroundColor(GQColors.textTertiary)
        }
    }
    #endif

    // MARK: - Helpers

    private func loadTodayMeals() {
        let service = NutritionService.shared
        service.configure(modelContext: modelContext)
        todayMeals = service.getTodaysMeals(userId: profile.id)
    }

    private func loadWeeklyCalories() {
        let service = NutritionService.shared
        service.configure(modelContext: modelContext)
        let cal = Calendar.current
        var results: [(date: Date, calories: Int)] = []

        for dayOffset in (0..<7).reversed() {
            let date = cal.date(byAdding: .day, value: -dayOffset, to: cal.startOfDay(for: Date())) ?? Date()
            let next = cal.date(byAdding: .day, value: 1, to: date) ?? date
            let meals = service.getMeals(userId: profile.id, from: date, to: next)
            let totalCal = meals.reduce(0) { $0 + ($1.estimatedCalories ?? 0) }
            results.append((date: date, calories: totalCal))
        }

        weeklyMealsByDay = results
    }

    private func saveProgressPhoto(from item: PhotosPickerItem?) async {
        guard let item = item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }

        let measurement = BodyMeasurement(
            userId: profile.id,
            type: .weight,
            value: latestWeight?.value ?? 0,
            photoData: data
        )
        modelContext.insert(measurement)
        try? modelContext.save()
    }

    private func computeWeeklyVolume() -> [(weekStart: Date, volume: Double)] {
        let cal = Calendar.current
        var weekMap: [Date: Double] = [:]

        for workout in workouts {
            let weekStart = cal.startOfWeek(for: workout.date)
            weekMap[weekStart, default: 0] += workout.totalVolume
        }

        return weekMap.sorted { $0.key < $1.key }.suffix(8).map { (weekStart: $0.key, volume: $0.value) }
    }

    private func formatVolume(_ vol: Double) -> String {
        if vol >= 1000 {
            return String(format: "%.0fk", vol / 1000)
        }
        return "\(Int(vol))"
    }
}

#Preview {
    LogView(profile: UserProfile(name: "Ben", username: "ben"))
        .environmentObject(AppState())
        .environmentObject(FeatureFlags.shared)
        .modelContainer(for: [BodyMeasurement.self, MealLog.self, Workout.self, PREvent.self], inMemory: true)
}
