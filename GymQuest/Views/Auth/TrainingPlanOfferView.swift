//
//  TrainingPlanOfferView.swift
//  GymQuest
//
//  Created by Benjamin Hilderman
//
//  Post-onboarding training plan offer with generating animation,
//  personalized plan summary, and subscription pricing.
//

import SwiftUI
import StoreKit

// MARK: - Training Plan Offer View

struct TrainingPlanOfferView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionService: SubscriptionService

    @State private var phase: OfferPhase = .generating
    @State private var generatingProgress: CGFloat = 0
    @State private var generatingTextIndex = 0
    @State private var selectedTier: PricingTier = .yearly
    @State private var isPurchasing = false
    @State private var rotationAngle: Double = 0
    @State private var shimmerPhase: CGFloat = 0
    @State private var particlePhase: CGFloat = 0

    private let generatingTexts = [
        "Analyzing your profile...",
        "Building your plan...",
        "Personalizing exercises..."
    ]

    private var data: OnboardingData {
        appState.onboardingData ?? OnboardingData(
            name: "Athlete",
            goal: .hypertrophy,
            experience: .beginner,
            environment: .gym,
            equipment: [],
            daysPerWeek: 4
        )
    }

    private var plan: GeneratedPlan {
        TrainingPlanGenerator.generate(
            goal: data.goal,
            experience: data.experience,
            equipment: data.equipment,
            daysPerWeek: data.daysPerWeek
        )
    }

    enum OfferPhase {
        case generating, summary
    }

    enum PricingTier {
        case monthly, yearly
    }

    var body: some View {
        ZStack {
            OBTheme.bg.ignoresSafeArea()
            shimmerBg

            switch phase {
            case .generating:
                generatingView
            case .summary:
                summaryView
            }
        }
        .onAppear {
            startGenerating()
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: true)) {
                shimmerPhase = 1
            }
        }
    }

    // MARK: - Shimmer Background

    @ViewBuilder
    private var shimmerBg: some View {
        ZStack {
            Circle()
                .fill(GQColors.vividPurple.opacity(0.06))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: -60 + shimmerPhase * 120, y: -100 + shimmerPhase * 50)

            Circle()
                .fill(GQColors.cyanSpark.opacity(0.04))
                .frame(width: 250, height: 250)
                .blur(radius: 70)
                .offset(x: 80 - shimmerPhase * 100, y: 150 - shimmerPhase * 80)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Generating Phase

    @ViewBuilder
    private var generatingView: some View {
        VStack(spacing: 40) {
            Spacer()

            // Pulsing icon with rotating gradient border
            ZStack {
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [GQColors.vividPurple, GQColors.cyanSpark, GQColors.deepBlue, GQColors.vividPurple],
                            center: .center
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(rotationAngle))

                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [GQColors.vividPurple, GQColors.cyanSpark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(generatingProgress < 1 ? 1.0 + sin(generatingProgress * .pi) * 0.1 : 1.0)
            }

            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 4)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: generatingProgress)
                    .stroke(
                        LinearGradient(
                            colors: [GQColors.deepBlue, GQColors.vividPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))

                Text("\(Int(generatingProgress * 100))%")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(OBTheme.textPrimary)
            }

            // Cycling text
            Text(generatingTexts[generatingTextIndex])
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(OBTheme.textSecondary)
                .animation(.easeInOut(duration: 0.3), value: generatingTextIndex)

            Spacer()
        }
    }

    // MARK: - Summary Phase

    @ViewBuilder
    private var summaryView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Skip link
                HStack {
                    Spacer()
                    Button {
                        skipToApp()
                    } label: {
                        Text("Maybe Later")
                            .font(.subheadline)
                            .foregroundStyle(OBTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                planHeader
                statsRow
                weekOverview
                sampleDay
                pricingSection
                ctaButtons

                Spacer(minLength: 40)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Plan Header

    @ViewBuilder
    private var planHeader: some View {
        VStack(spacing: 8) {
            Text("\(data.name)'s")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(OBTheme.textSecondary)

            Text(plan.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [GQColors.vividPurple, GQColors.cyanSpark],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .multilineTextAlignment(.center)

            Text("\(plan.weekCount) Week Program")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(OBTheme.textSecondary)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Stats Row

    @ViewBuilder
    private var statsRow: some View {
        HStack(spacing: 0) {
            statPill(icon: "calendar", label: "\(data.daysPerWeek)/week")
            statPill(icon: "chart.bar.fill", label: data.experience.rawValue)
            statPill(icon: "mappin.and.ellipse", label: data.environment.rawValue)
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func statPill(icon: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(GQColors.cyanSpark)
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(OBTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(OBTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Week Overview

    @ViewBuilder
    private var weekOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WEEKLY SPLIT")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(GQColors.cyanSpark.opacity(0.8))
                .tracking(1.2)

            VStack(spacing: 8) {
                ForEach(Array(plan.days.enumerated()), id: \.offset) { index, day in
                    HStack {
                        Text("Day \(index + 1)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(OBTheme.textSecondary)
                            .frame(width: 50, alignment: .leading)

                        Text(day.name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(OBTheme.textPrimary)

                        Spacer()

                        Text("\(day.exercises.count) exercises")
                            .font(.system(size: 12))
                            .foregroundStyle(OBTheme.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(OBTheme.card)
                    )
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Sample Day

    @ViewBuilder
    private var sampleDay: some View {
        if let firstDay = plan.days.first {
            VStack(alignment: .leading, spacing: 12) {
                Text("DAY 1 PREVIEW")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(GQColors.cyanSpark.opacity(0.8))
                    .tracking(1.2)

                VStack(spacing: 6) {
                    ForEach(firstDay.exercises.prefix(5), id: \.self) { name in
                        HStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [GQColors.vividPurple, GQColors.cyanSpark],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 6, height: 6)

                            Text(name)
                                .font(.system(size: 14))
                                .foregroundStyle(OBTheme.textPrimary)

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }

                    if firstDay.exercises.count > 5 {
                        Text("+ \(firstDay.exercises.count - 5) more")
                            .font(.system(size: 13))
                            .foregroundStyle(OBTheme.textSecondary)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(OBTheme.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [GQColors.vividPurple.opacity(0.25), GQColors.cyanSpark.opacity(0.18)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Pricing Section

    @ViewBuilder
    private var pricingSection: some View {
        VStack(spacing: 16) {
            // Free vs Pro comparison
            HStack(spacing: 12) {
                comparisonCard(
                    title: "Free",
                    features: ["Basic template", "Limited exercises", "No AI adjustments"],
                    isPro: false
                )
                comparisonCard(
                    title: "Pro",
                    features: ["AI-adjusted weekly", "Full exercise library", "Smart progression", "Form cues"],
                    isPro: true
                )
            }
            .padding(.horizontal, 20)

            // Tier selector
            HStack(spacing: 0) {
                tierButton(tier: .monthly, label: "$10.99/mo", sublabel: "Monthly")
                tierButton(tier: .yearly, label: "$79.99/yr", sublabel: "Save 39%")
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(OBTheme.card)
            )
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private func comparisonCard(title: String, features: [String], isPro: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isPro ? GQColors.vividPurple : OBTheme.textPrimary)

                if isPro {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(GQColors.vividPurple)
                }
            }

            ForEach(features, id: \.self) { feature in
                HStack(spacing: 6) {
                    Image(systemName: isPro ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 11))
                        .foregroundStyle(isPro ? GQColors.cyanSpark : OBTheme.textSecondary)
                    Text(feature)
                        .font(.system(size: 12))
                        .foregroundStyle(OBTheme.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(OBTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isPro
                        ? LinearGradient(colors: [GQColors.vividPurple.opacity(0.5), GQColors.cyanSpark.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.white.opacity(0.06)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
        )
    }

    @ViewBuilder
    private func tierButton(tier: PricingTier, label: String, sublabel: String) -> some View {
        let isSelected = selectedTier == tier

        Button {
            withAnimation(.spring(response: 0.3)) {
                selectedTier = tier
            }
        } label: {
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(isSelected ? .white : OBTheme.textSecondary)
                Text(sublabel)
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? .white.opacity(0.7) : OBTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [GQColors.deepBlue, GQColors.vividPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .padding(2)
    }

    // MARK: - CTA Buttons

    @ViewBuilder
    private var ctaButtons: some View {
        VStack(spacing: 12) {
            // Start Pro
            Button {
                purchasePro()
            } label: {
                HStack(spacing: 8) {
                    if isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "star.fill")
                            .font(.system(size: 14))
                        Text("Start Pro Plan")
                            .font(.system(size: 17, weight: .bold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    Capsule().fill(
                        LinearGradient(
                            colors: [GQColors.deepBlue, GQColors.vividPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                )
                .shadow(color: GQColors.vividPurple.opacity(0.3), radius: 12, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(isPurchasing)

            // Start Free
            Button {
                skipToApp()
            } label: {
                Text("Start Free")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(OBTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        Capsule()
                            .fill(OBTheme.card)
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isPurchasing)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Actions

    private func startGenerating() {
        withAnimation(.linear(duration: 3)) {
            rotationAngle = 360
        }
        // Keep rotating
        Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { timer in
            if phase != .generating { timer.invalidate(); return }
            withAnimation(.linear(duration: 3)) {
                rotationAngle += 360
            }
        }

        // Progress animation
        withAnimation(.easeInOut(duration: 3)) {
            generatingProgress = 1.0
        }

        // Cycle text
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if phase != .generating { timer.invalidate(); return }
            withAnimation {
                generatingTextIndex = (generatingTextIndex + 1) % generatingTexts.count
            }
        }

        // Transition to summary
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            withAnimation(.easeInOut(duration: 0.5)) {
                phase = .summary
            }
        }
    }

    private func skipToApp() {
        appState.onboardingData = nil
        withAnimation {
            appState.authState = .authenticated
        }
    }

    private func purchasePro() {
        isPurchasing = true

        Task {
            let product: Product?
            switch selectedTier {
            case .monthly:
                product = subscriptionService.monthlyProduct
            case .yearly:
                product = subscriptionService.yearlyProduct
            }

            if let product {
                do {
                    let success = try await subscriptionService.purchase(product)
                    if success {
                        skipToApp()
                        return
                    }
                } catch {
                    print("Purchase failed: \(error)")
                }
            }

            isPurchasing = false
        }
    }
}

// MARK: - Theme Namespace (local to this file)

private enum OBTheme {
    static let bg = Color(hex: "0D0D12")
    static let card = Color(hex: "1A1A24")
    static let textPrimary = Color.white.opacity(0.92)
    static let textSecondary = Color.white.opacity(0.55)
}

// MARK: - Training Plan Generator

struct TrainingPlanGenerator {
    struct SplitDay {
        let name: String
        let exercises: [String]
    }

    static func generate(
        goal: FitnessGoal,
        experience: ExperienceLevel,
        equipment: Set<EquipmentType>,
        daysPerWeek: Int
    ) -> GeneratedPlan {
        let title = "\(goal.rawValue) Plan"
        let weekCount: Int
        switch experience {
        case .beginner: weekCount = 8
        case .intermediate: weekCount = 6
        case .advanced: weekCount = 4
        }

        let splitNames = splitForDays(daysPerWeek)
        let days = splitNames.map { name in
            SplitDay(
                name: name,
                exercises: exercisesForSplit(name: name, equipment: equipment, goal: goal)
            )
        }

        return GeneratedPlan(title: title, weekCount: weekCount, days: days)
    }

    private static func splitForDays(_ days: Int) -> [String] {
        switch days {
        case 2: return ["Full Body A", "Full Body B"]
        case 3: return ["Push", "Pull", "Legs"]
        case 4: return ["Upper A", "Lower A", "Upper B", "Lower B"]
        case 5: return ["Push", "Pull", "Legs", "Upper", "Lower"]
        case 6: return ["Push A", "Pull A", "Legs A", "Push B", "Pull B", "Legs B"]
        default: return ["Push", "Pull", "Legs", "Upper"]
        }
    }

    private static func exercisesForSplit(name: String, equipment: Set<EquipmentType>, goal: FitnessGoal) -> [String] {
        let allExercises = ExtendedExerciseDatabase.exercises
        let availableEquipment = mapEquipmentTypes(equipment)

        // Filter by available equipment
        let filtered = allExercises.filter { meta in
            availableEquipment.contains(meta.equipment) || meta.equipment == .bodyweight
        }

        // Get exercises matching the split's muscle groups
        let muscleGroups = muscleGroupsForSplit(name)
        let matching = filtered.filter { muscleGroups.contains($0.muscleGroup) }

        // Take a reasonable number (4-6 exercises per day)
        let count = goal == .strength ? 4 : 5
        let selected = Array(matching.prefix(count))

        // Fall back to names
        if selected.isEmpty {
            return defaultExercisesForSplit(name)
        }

        return selected.map(\.name)
    }

    private static func muscleGroupsForSplit(_ name: String) -> Set<MuscleGroup> {
        let lower = name.lowercased()
        if lower.contains("push") {
            return [.chest, .shoulders, .triceps]
        } else if lower.contains("pull") {
            return [.back, .biceps]
        } else if lower.contains("legs") || lower.contains("lower") {
            return [.quads, .hamstrings, .glutes, .calves]
        } else if lower.contains("upper") {
            return [.chest, .back, .shoulders, .biceps, .triceps]
        } else if lower.contains("full body") {
            return [.chest, .back, .quads, .shoulders]
        }
        return [.chest, .back, .quads, .shoulders]
    }

    private static func mapEquipmentTypes(_ types: Set<EquipmentType>) -> Set<Equipment> {
        var result = Set<Equipment>()
        for t in types {
            switch t {
            case .barbell: result.insert(.barbell)
            case .dumbbells: result.insert(.dumbbell)
            case .kettlebells: result.insert(.kettlebell)
            case .cables: result.insert(.cable)
            case .machines: result.insert(.machine)
            case .resistanceBands: result.insert(.band)
            case .pullUpBar: result.insert(.bodyweight)
            case .bench: result.insert(.barbell) // bench exercises often use barbell
            case .bodyweightOnly: result.insert(.bodyweight)
            }
        }
        // Always include bodyweight
        result.insert(.bodyweight)
        return result
    }

    private static func defaultExercisesForSplit(_ name: String) -> [String] {
        let lower = name.lowercased()
        if lower.contains("push") {
            return ["Push-ups", "Dips", "Pike Push-ups", "Diamond Push-ups"]
        } else if lower.contains("pull") {
            return ["Pull-ups", "Inverted Rows", "Face Pulls", "Bicep Curls"]
        } else if lower.contains("legs") || lower.contains("lower") {
            return ["Squats", "Lunges", "Calf Raises", "Glute Bridges"]
        } else if lower.contains("upper") {
            return ["Push-ups", "Pull-ups", "Dips", "Inverted Rows", "Pike Push-ups"]
        } else {
            return ["Squats", "Push-ups", "Pull-ups", "Lunges", "Planks"]
        }
    }
}

// MARK: - Generated Plan

struct GeneratedPlan {
    let title: String
    let weekCount: Int
    let days: [TrainingPlanGenerator.SplitDay]
}
