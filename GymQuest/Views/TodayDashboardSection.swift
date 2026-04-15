//
//  TodayDashboardSection.swift
//  GymQuest
//
//  Created by Benjamin Hilderman
//
//  Compact daily stats + quick-log actions for the Home feed.
//

import SwiftUI
import SwiftData

struct TodayDashboardSection: View {
    let profile: UserProfile
    let workoutsThisWeek: Int
    let allWorkouts: [Workout]

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var measurements: [BodyMeasurement]
    @StateObject private var healthKit = HealthKitService.shared

    @State private var todayCalories: Int = 0
    @State private var todayProtein: Int = 0
    @State private var nutritionStreak: Int = 0
    @State private var showingMealLog = false
    @State private var showingAddMeasurement = false
    @State private var showingNutritionDetail = false
    @State private var showingWeightDetail = false

    private var latestWeight: BodyMeasurement? {
        measurements.first { $0.userId == profile.id && $0.type == .weight }
    }

    var body: some View {
        variant1_Minimal
            .onAppear { loadTodayData() }
        .onChange(of: showingMealLog) { _, showing in
            if !showing { loadTodayData() }
        }
        .onChange(of: showingAddMeasurement) { _, showing in
            if !showing { loadTodayData() }
        }
        .sheet(isPresented: $showingMealLog) {
            MealLogView(profile: profile)
        }
        .sheet(isPresented: $showingAddMeasurement) {
            AddMeasurementSheet(profile: profile, measurementType: .weight)
        }
        .sheet(isPresented: $showingNutritionDetail) {
            NutritionDetailSheet(profile: profile)
        }
        .sheet(isPresented: $showingWeightDetail) {
            NavigationStack {
                BodyMeasurementsView(profile: profile)
                    .navigationTitle("Weight")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showingWeightDetail = false }
                        }
                    }
            }
        }
    }

    // MARK: - Variants

    private func variantTag(_ i: Int) -> String {
        [
            "O1 · Minimal (no today)",
            "O2 · 2×2 icon grid",
            "O3 · Inline icon rows",
            "O4 · Hero calories + 3 compact",
            "O5 · Progress bars inline",
            "O6 · One-line summary row",
            "O7 · Split: nutrition | body",
            "O8 · Icon-only micro cells",
            "O9 · Last logged + buttons only",
            "O10 · Two grouped sections",
        ][i]
    }

    @ViewBuilder
    private func variantCard(_ i: Int) -> some View {
        switch i {
        case 0: variant1_Minimal
        case 1: variant2_IconGrid
        case 2: variant3_InlineIconRows
        case 3: variant4_HeroCalories
        case 4: variant5_ProgressBars
        case 5: variant6_OneLine
        case 6: variant7_SplitNutritionBody
        case 7: variant8_IconOnly
        case 8: variant9_LastLoggedButtons
        case 9: variant10_TwoSections
        default: EmptyView()
        }
    }

    private var weightDisplay: (value: String, sub: String) {
        if let w = latestWeight {
            return (formatWeight(w.value), "lbs · \(relativeDate(w.date))")
        }
        return ("--", "no weight yet")
    }

    private var stepsDisplay: String {
        healthKit.steps > 0 ? formatSteps(healthKit.steps) : "--"
    }

    // O1 — Minimal: drop "· today", keep 4 stats + 2 buttons, tight labels
    private var variant1_Minimal: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                stat("\(todayCalories)/\(profile.dailyCalorieGoal)", "cal")
                divider
                stat("\(todayProtein)/\(profile.proteinGoalGrams)g", "protein")
                divider
                stat(stepsDisplay, "steps")
                divider
                stat(weightDisplay.value, weightDisplay.sub)
            }
            HStack(spacing: 8) {
                logButton("Log Food") { showingMealLog = true }
                logButton("Log Weight") { showingAddMeasurement = true }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .homeSocialCard(cornerRadius: 14)
    }

    // O2 — 2×2 grid with SF icons
    private var variant2_IconGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                iconStat("flame.fill", value: "\(todayCalories)/\(profile.dailyCalorieGoal)", label: "cal")
                iconStat("fork.knife", value: "\(todayProtein)/\(profile.proteinGoalGrams)g", label: "protein")
            }
            HStack(spacing: 10) {
                iconStat("figure.walk", value: stepsDisplay, label: "steps")
                iconStat("scalemass.fill", value: weightDisplay.value, label: weightDisplay.sub)
            }
            HStack(spacing: 8) {
                logButton("Log Food") { showingMealLog = true }
                logButton("Log Weight") { showingAddMeasurement = true }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .homeSocialCard(cornerRadius: 14)
    }

    // O3 — Inline icon rows (list style)
    private var variant3_InlineIconRows: some View {
        VStack(spacing: 8) {
            rowStat("flame.fill", label: "Calories", value: "\(todayCalories) / \(profile.dailyCalorieGoal)", unit: "cal")
            rowStat("fork.knife", label: "Protein", value: "\(todayProtein) / \(profile.proteinGoalGrams)", unit: "g")
            rowStat("figure.walk", label: "Steps", value: stepsDisplay, unit: "")
            rowStat("scalemass.fill", label: "Weight", value: weightDisplay.value, unit: "lbs")
            HStack(spacing: 8) {
                logButton("Log Food") { showingMealLog = true }
                logButton("Log Weight") { showingAddMeasurement = true }
            }.padding(.top, 4)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .homeSocialCard(cornerRadius: 14)
    }

    // O4 — Hero calories + 3 compact sub-stats
    private var variant4_HeroCalories: some View {
        let progress = min(Double(todayCalories) / Double(max(profile.dailyCalorieGoal, 1)), 1.0)
        return VStack(spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().stroke(GQColors.deepBlue.opacity(0.08), lineWidth: 6).frame(width: 52, height: 52)
                    Circle().trim(from: 0, to: progress)
                        .stroke(GQGradients.primary, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 52, height: 52)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(todayCalories) / \(profile.dailyCalorieGoal) cal").font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundColor(GQColors.textPrimary)
                    Text("\(todayProtein)g protein · \(stepsDisplay) steps · \(weightDisplay.value) lbs").font(.system(size: 11)).foregroundColor(GQColors.textTertiary).lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer()
            }
            HStack(spacing: 8) {
                logButton("Log Food") { showingMealLog = true }
                logButton("Log Weight") { showingAddMeasurement = true }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .homeSocialCard(cornerRadius: 14)
    }

    // O5 — Progress bars inline
    private var variant5_ProgressBars: some View {
        let calP = min(Double(todayCalories) / Double(max(profile.dailyCalorieGoal, 1)), 1.0)
        let protP = min(Double(todayProtein) / Double(max(profile.proteinGoalGrams, 1)), 1.0)
        return VStack(spacing: 8) {
            progressRow(label: "Calories", value: "\(todayCalories) / \(profile.dailyCalorieGoal)", progress: calP)
            progressRow(label: "Protein", value: "\(todayProtein) / \(profile.proteinGoalGrams)g", progress: protP)
            HStack {
                Text("Steps").font(.system(size: 11, weight: .medium)).foregroundColor(GQColors.textSecondary)
                Spacer()
                Text(stepsDisplay).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundColor(GQColors.textPrimary)
                Text("·").foregroundColor(GQColors.textTertiary)
                Text("Weight").font(.system(size: 11, weight: .medium)).foregroundColor(GQColors.textSecondary)
                Text(weightDisplay.value).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundColor(GQColors.textPrimary)
            }
            HStack(spacing: 8) {
                logButton("Log Food") { showingMealLog = true }
                logButton("Log Weight") { showingAddMeasurement = true }
            }.padding(.top, 4)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .homeSocialCard(cornerRadius: 14)
    }

    // O6 — One-line summary row + buttons
    private var variant6_OneLine: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                inlineChip(value: "\(todayCalories)/\(profile.dailyCalorieGoal)", label: "cal")
                dotSep
                inlineChip(value: "\(todayProtein)/\(profile.proteinGoalGrams)g", label: "pro")
                dotSep
                inlineChip(value: stepsDisplay, label: "stp")
                dotSep
                inlineChip(value: weightDisplay.value, label: "lbs")
            }
            HStack(spacing: 8) {
                logButton("Log Food") { showingMealLog = true }
                logButton("Log Weight") { showingAddMeasurement = true }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .homeSocialCard(cornerRadius: 14)
    }

    // O7 — Split: Nutrition card | Body card
    private var variant7_SplitNutritionBody: some View {
        HStack(spacing: 10) {
            // Nutrition
            VStack(alignment: .leading, spacing: 8) {
                Text("NUTRITION").font(.system(size: 9, weight: .semibold)).tracking(0.8).foregroundColor(GQColors.textTertiary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(todayCalories)").font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(GQColors.textPrimary)
                    Text("/\(profile.dailyCalorieGoal) cal").font(.system(size: 10)).foregroundColor(GQColors.textTertiary)
                }
                Text("\(todayProtein)g / \(profile.proteinGoalGrams)g protein").font(.system(size: 10)).foregroundColor(GQColors.textTertiary)
                logButton("Log Food") { showingMealLog = true }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(GQColors.adaptiveOverlay(0.03)))

            // Body
            VStack(alignment: .leading, spacing: 8) {
                Text("BODY").font(.system(size: 9, weight: .semibold)).tracking(0.8).foregroundColor(GQColors.textTertiary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(weightDisplay.value).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(GQColors.textPrimary)
                    Text("lbs").font(.system(size: 10)).foregroundColor(GQColors.textTertiary)
                }
                Text(weightDisplay.sub).font(.system(size: 10)).foregroundColor(GQColors.textTertiary).lineLimit(1)
                logButton("Log Weight") { showingAddMeasurement = true }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(GQColors.adaptiveOverlay(0.03)))
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .homeSocialCard(cornerRadius: 14)
    }

    // O8 — Icon-only micro cells (icon + value, no text labels)
    private var variant8_IconOnly: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                iconMicro("flame.fill", value: "\(todayCalories)")
                divider
                iconMicro("fork.knife", value: "\(todayProtein)g")
                divider
                iconMicro("figure.walk", value: stepsDisplay)
                divider
                iconMicro("scalemass.fill", value: weightDisplay.value)
            }
            HStack(spacing: 8) {
                logButton("Log Food") { showingMealLog = true }
                logButton("Log Weight") { showingAddMeasurement = true }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .homeSocialCard(cornerRadius: 14)
    }

    // O9 — Minimal: just last logged + buttons
    private var variant9_LastLoggedButtons: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Last: \(todayCalories) cal · \(todayProtein)g · \(weightDisplay.value) lbs")
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
            }
            HStack(spacing: 8) {
                logButton("Log Food") { showingMealLog = true }
                logButton("Log Weight") { showingAddMeasurement = true }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .homeSocialCard(cornerRadius: 14)
    }

    // O10 — Two grouped sections stacked (nutrition | body)
    private var variant10_TwoSections: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "flame.fill").font(.system(size: 11)).foregroundStyle(GQGradients.primary)
                Text("\(todayCalories)/\(profile.dailyCalorieGoal) cal · \(todayProtein)g protein").font(.system(size: 12, weight: .medium)).foregroundColor(GQColors.textPrimary).lineLimit(1).minimumScaleFactor(0.8)
                Spacer()
                logButton("Log Food") { showingMealLog = true }.frame(width: 100)
            }
            Rectangle().fill(GQColors.borderSubtle).frame(height: 1)
            HStack(spacing: 10) {
                Image(systemName: "scalemass.fill").font(.system(size: 11)).foregroundStyle(GQGradients.primary)
                Text(latestWeight != nil ? "\(weightDisplay.value) lbs · \(weightDisplay.sub)" : "No weight logged yet").font(.system(size: 12, weight: .medium)).foregroundColor(GQColors.textPrimary).lineLimit(1).minimumScaleFactor(0.8)
                Spacer()
                logButton("Log Weight") { showingAddMeasurement = true }.frame(width: 110)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .homeSocialCard(cornerRadius: 14)
    }

    // MARK: - Variant helpers

    private func iconStat(_ icon: String, value: String, label: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(GQGradients.primary.opacity(0.1)).frame(width: 28, height: 28)
                Image(systemName: icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(GQGradients.primary)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(GQColors.textPrimary).lineLimit(1).minimumScaleFactor(0.7)
                Text(label).font(.system(size: 10)).foregroundColor(GQColors.textTertiary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(GQColors.adaptiveOverlay(0.03)))
    }

    private func rowStat(_ icon: String, label: String, value: String, unit: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(GQGradients.primary).frame(width: 20)
            Text(label).font(.system(size: 12, weight: .medium)).foregroundColor(GQColors.textSecondary)
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundColor(GQColors.textPrimary)
                if !unit.isEmpty {
                    Text(unit).font(.system(size: 10)).foregroundColor(GQColors.textTertiary)
                }
            }
        }
    }

    private func progressRow(label: String, value: String, progress: Double) -> some View {
        VStack(spacing: 3) {
            HStack {
                Text(label).font(.system(size: 11, weight: .medium)).foregroundColor(GQColors.textSecondary)
                Spacer()
                Text(value).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundColor(GQColors.textPrimary)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(GQColors.adaptiveOverlay(0.06))
                    Capsule().fill(GQGradients.primary).frame(width: g.size.width * CGFloat(progress))
                }
            }
            .frame(height: 4)
        }
    }

    private func inlineChip(value: String, label: String) -> some View {
        VStack(spacing: 1) {
            Text(value).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(GQColors.textPrimary).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.system(size: 9)).foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var dotSep: some View {
        Text("·").font(.system(size: 14)).foregroundColor(GQColors.textTertiary.opacity(0.5))
    }

    private func iconMicro(_ icon: String, value: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 13)).foregroundStyle(GQGradients.primary)
            Text(value).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundColor(GQColors.textPrimary).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Components

    @ViewBuilder
    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 13.9, weight: .bold, design: .rounded))
                .foregroundColor(GQColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(GQColors.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(GQColors.borderSubtle)
            .frame(width: 1, height: 22)
    }

    @ViewBuilder
    private func logButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("+ \(title)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(GQColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(GQColors.adaptiveOverlay(0.05))
                .cornerRadius(8)
        }
        .buttonStyle(GQInteractiveStyle())
    }

    // MARK: - Data Loading

    private func loadTodayData() {
        let service = NutritionService.shared
        service.configure(modelContext: modelContext)
        let meals = service.getTodaysMeals(userId: profile.id)
        todayCalories = meals.reduce(0) { $0 + ($1.estimatedCalories ?? 0) }
        todayProtein = meals.reduce(0) { $0 + ($1.estimatedProtein ?? 0) }
        nutritionStreak = service.calculateNutritionStreak(userId: profile.id)
    }

    // MARK: - Formatters

    private func formatSteps(_ steps: Int) -> String {
        if steps >= 1000 {
            let k = Double(steps) / 1000.0
            return String(format: "%.1fk", k)
        }
        return "\(steps)"
    }

    private func formatWeight(_ value: Double) -> String {
        if value == value.rounded() {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }

    private func relativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: Date())).day ?? 0
        switch days {
        case 0: return "today"
        case 1: return "yesterday"
        case 2...6: return "\(days)d ago"
        case 7...29: let w = days / 7; return "\(w)w ago"
        default: let m = days / 30; return "\(m)mo ago"
        }
    }
}

// MARK: - Nutrition Detail Sheet

struct NutritionDetailSheet: View {
    let profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var todaysMeals: [MealLog] = []
    @State private var weeklyTotals: [(date: Date, cal: Int)] = []
    @State private var showingMealLog = false

    private var todayCal: Int { todaysMeals.reduce(0) { $0 + ($1.estimatedCalories ?? 0) } }
    private var todayProtein: Int { todaysMeals.reduce(0) { $0 + ($1.estimatedProtein ?? 0) } }
    private var calProgress: Double { min(Double(todayCal) / Double(max(profile.dailyCalorieGoal, 1)), 1.0) }
    private var proteinProgress: Double { min(Double(todayProtein) / Double(max(profile.proteinGoalGrams, 1)), 1.0) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    // Today summary
                    VStack(alignment: .leading, spacing: 12) {
                        Text("TODAY")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.2)
                            .foregroundColor(GQColors.textTertiary)
                        HStack(spacing: 12) {
                            nutritionMetric(title: "Calories", value: todayCal, goal: profile.dailyCalorieGoal, unit: "cal", progress: calProgress, gradient: GQGradients.primary)
                            nutritionMetric(title: "Protein", value: todayProtein, goal: profile.proteinGoalGrams, unit: "g", progress: proteinProgress, gradient: LinearGradient(colors: [GQColors.cyanSpark, GQColors.deepBlue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .homeSocialCard(cornerRadius: 14)

                    // 7-day trend
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("LAST 7 DAYS")
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(1.2)
                                .foregroundColor(GQColors.textTertiary)
                            Spacer()
                            Text("\(profile.dailyCalorieGoal) cal goal").font(.system(size: 10, weight: .medium)).foregroundColor(GQColors.textTertiary)
                        }
                        weeklyBars
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .homeSocialCard(cornerRadius: 14)

                    // Today's meals
                    VStack(alignment: .leading, spacing: 10) {
                        Text("TODAY'S MEALS")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.2)
                            .foregroundColor(GQColors.textTertiary)
                        if todaysMeals.isEmpty {
                            Text("Nothing logged yet.")
                                .font(.system(size: 13))
                                .foregroundColor(GQColors.textTertiary)
                                .padding(.vertical, 8)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(todaysMeals) { meal in
                                    mealRow(meal)
                                    if meal.id != todaysMeals.last?.id {
                                        Rectangle().fill(GQColors.borderSubtle).frame(height: 1)
                                    }
                                }
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .homeSocialCard(cornerRadius: 14)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(GQColors.background)
            .navigationTitle("Nutrition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingMealLog = true
                    } label: {
                        Label("Log", systemImage: "plus")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button { showingMealLog = true } label: {
                    Text("+ Log Food")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(GQGradients.primary)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .onAppear { reload() }
        .onChange(of: showingMealLog) { _, showing in
            if !showing { reload() }
        }
        .sheet(isPresented: $showingMealLog) {
            MealLogView(profile: profile)
        }
    }

    private func nutritionMetric(title: String, value: Int, goal: Int, unit: String, progress: Double, gradient: LinearGradient) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundColor(GQColors.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(value)").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(GQColors.textPrimary)
                Text("/ \(goal) \(unit)").font(.system(size: 11, weight: .medium)).foregroundColor(GQColors.textTertiary)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(GQColors.adaptiveOverlay(0.06))
                    Capsule().fill(gradient).frame(width: g.size.width * CGFloat(progress))
                }
            }
            .frame(height: 6)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(GQColors.adaptiveOverlay(0.03)))
    }

    private var weeklyBars: some View {
        let maxCal = max(weeklyTotals.map(\.cal).max() ?? 0, profile.dailyCalorieGoal)
        let df = DateFormatter(); df.dateFormat = "EEE"
        return HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(weeklyTotals.enumerated()), id: \.offset) { _, entry in
                VStack(spacing: 4) {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 4).fill(GQColors.adaptiveOverlay(0.05)).frame(height: 60)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(GQGradients.primary)
                            .frame(height: maxCal > 0 ? 60 * CGFloat(entry.cal) / CGFloat(maxCal) : 0)
                    }
                    Text(df.string(from: entry.date).prefix(1))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(GQColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func mealRow(_ meal: MealLog) -> some View {
        let df = DateFormatter(); df.dateFormat = "h:mm a"
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(meal.mealDescription.isEmpty ? meal.mealType.rawValue.capitalized : meal.mealDescription).font(.system(size: 14, weight: .semibold)).foregroundColor(GQColors.textPrimary).lineLimit(1)
                Text(df.string(from: meal.dateTime)).font(.system(size: 11)).foregroundColor(GQColors.textTertiary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(meal.estimatedCalories ?? 0) cal").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundColor(GQColors.textPrimary)
                Text("\(meal.estimatedProtein ?? 0)g protein").font(.system(size: 10)).foregroundColor(GQColors.textTertiary)
            }
        }
        .padding(.vertical, 10)
    }

    private func reload() {
        let service = NutritionService.shared
        service.configure(modelContext: modelContext)
        todaysMeals = service.getTodaysMeals(userId: profile.id)
        weeklyTotals = (0..<7).reversed().compactMap { offset -> (date: Date, cal: Int)? in
            let cal = Calendar.current
            guard let start = cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: Date())) else { return nil }
            guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return nil }
            let dayMeals = service.getMeals(userId: profile.id, from: start, to: end)
            let total = dayMeals.reduce(0) { $0 + ($1.estimatedCalories ?? 0) }
            return (start, total)
        }
    }
}
