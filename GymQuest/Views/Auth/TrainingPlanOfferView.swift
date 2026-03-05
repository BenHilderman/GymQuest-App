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
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var rotationAngle: Double = 0
    @State private var heroAppeared = false

    private var generatingTexts: [String] {
        [
            "Analyzing \(data.name)'s goals...",
            "Matching exercises to your \(data.environment.rawValue.lowercased()) setup...",
            "Building your \(data.goal.rawValue.lowercased()) program..."
        ]
    }

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

    var body: some View {
        ZStack {
            GQColors.background.ignoresSafeArea()

            switch phase {
            case .generating:
                generatingView
            case .summary:
                summaryView
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .onAppear {
            startGenerating()
            selectedProduct = subscriptionService.yearlyProduct
        }
    }

    // MARK: - Generating Phase

    private let generatingGradient = LinearGradient(
        colors: [GQColors.deepBlue.opacity(0.55), GQColors.vividPurple.opacity(0.45), GQColors.coralRed.opacity(0.50)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    @ViewBuilder
    private var generatingView: some View {
        ZStack {
            // Soft animated background blobs matching onboarding
            GQColors.background.ignoresSafeArea()

            Circle()
                .fill(GQColors.vividPurple.opacity(0.15))
                .frame(width: 280, height: 280)
                .blur(radius: 70)
                .offset(x: -40 + generatingProgress * 80, y: -80)

            Circle()
                .fill(GQColors.vividPurple.opacity(0.12))
                .frame(width: 220, height: 220)
                .blur(radius: 60)
                .offset(x: 60 - generatingProgress * 60, y: 120)

            VStack(spacing: 32) {
                Spacer()

                // Rotating ring with pulsing center
                ZStack {
                    // Outer track
                    Circle()
                        .stroke(GQColors.vividPurple.opacity(0.2), lineWidth: 3)
                        .frame(width: 110, height: 110)

                    // Spinning arc
                    Circle()
                        .trim(from: 0, to: 0.35)
                        .stroke(generatingGradient, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 110, height: 110)
                        .rotationEffect(.degrees(rotationAngle))

                    // Pulsing gradient center
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [GQColors.deepBlue.opacity(0.9), GQColors.vividPurple.opacity(0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .scaleEffect(generatingProgress < 1 ? 1.0 + sin(generatingProgress * .pi * 2) * 0.08 : 1.0)
                        .shadow(color: GQColors.vividPurple.opacity(0.3), radius: 16, y: 0)
                        .shadow(color: GQColors.deepBlue.opacity(0.15), radius: 24, y: 0)

                    // Checkmark icon inside
                    Image(systemName: "sparkles")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }

                // Progress bar (horizontal, matching onboarding CTA style)
                VStack(spacing: 14) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(GQColors.vividPurple.opacity(0.2))

                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [GQColors.deepBlue.opacity(0.9), GQColors.vividPurple.opacity(0.9)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * generatingProgress)
                        }
                    }
                    .frame(height: 6)
                    .padding(.horizontal, 60)

                    Text("\(Int(generatingProgress * 100))%")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(GQColors.textSecondary)
                }

                // Cycling text in a bubble-style card
                Text(generatingTexts[generatingTextIndex])
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(GQColors.textPrimary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [GQColors.cardBackground, GQColors.vividPurple.opacity(0.04)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [GQColors.vividPurple.opacity(0.5), GQColors.vividPurple.opacity(0.25)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                    )
                    .gqShadow(.card)
                    .animation(.easeInOut(duration: 0.4), value: generatingTextIndex)
                    .padding(.horizontal, 32)

                Spacer()
            }
        }
    }

    // MARK: - Summary Phase

    @ViewBuilder
    private var summaryView: some View {
        ZStack {
            // Warm floating gradient blobs
            GQColors.background.ignoresSafeArea()

            Circle()
                .fill(GQColors.vividPurple.opacity(0.15))
                .frame(width: 280, height: 280)
                .blur(radius: 70)
                .offset(x: -60, y: -120)

            Circle()
                .fill(GQColors.vividPurple.opacity(0.12))
                .frame(width: 220, height: 220)
                .blur(radius: 60)
                .offset(x: 80, y: 200)

            Circle()
                .fill(GQColors.sunsetOrange.opacity(0.10))
                .frame(width: 200, height: 200)
                .blur(radius: 50)
                .offset(x: -40, y: 400)

            ScrollView {
                VStack(spacing: 24) {
                    heroSection
                    weekOverview
                    sampleDay
                    featuresSection
                    tierCardsSection
                    ctaSection

                    Spacer(minLength: 40)
                }
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Hero Section

    @ViewBuilder
    private var heroSection: some View {
        VStack(spacing: 16) {
            NavBarLogo()
                .opacity(heroAppeared ? 1 : 0)
                .offset(y: heroAppeared ? 0 : 10)

            VStack(spacing: 6) {
                Text("Your Plan Is Ready")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(GQColors.textPrimary)

                Text(plan.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(GQColors.textSecondary)
            }
            .opacity(heroAppeared ? 1 : 0)
            .offset(y: heroAppeared ? 0 : 16)

            Text(personalizationBlurb)
                .font(.subheadline)
                .foregroundStyle(GQColors.textTertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(heroAppeared ? 1 : 0)
                .offset(y: heroAppeared ? 0 : 12)

            HStack(spacing: 8) {
                capsuleBadge(text: "\(plan.weekCount) Weeks")
                capsuleBadge(text: "\(data.daysPerWeek)×/Week")
                capsuleBadge(text: data.goal.rawValue)
            }
            .opacity(heroAppeared ? 1 : 0)
            .offset(y: heroAppeared ? 0 : 10)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 8)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                heroAppeared = true
            }
        }
    }

    @ViewBuilder
    private func capsuleBadge(text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(GQColors.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(GQColors.textSecondary.opacity(0.08))
            )
    }

    private var personalizationBlurb: String {
        let env: String
        switch data.environment {
        case .gym: env = "full gym access"
        case .home: env = "your home setup"
        case .both: env = "gym and home training"
        case .outdoor: env = "outdoor training"
        }

        let exp: String
        switch data.experience {
        case .beginner: exp = "build a strong foundation"
        case .intermediate: exp = "push past plateaus"
        case .advanced: exp = "maximize your potential"
        }

        return "A \(data.experience.rawValue.lowercased())-level program using \(env) to help you \(exp)."
    }

    // MARK: - Week Overview

    @ViewBuilder
    private var weekOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR WEEKLY SPLIT")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(GQColors.textTertiary)
                .tracking(1.2)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(Array(plan.days.enumerated()), id: \.offset) { index, day in
                    HStack(spacing: 12) {
                        Image(systemName: splitDayIcon(day.name))
                            .font(.system(size: 14))
                            .foregroundStyle(GQColors.textSecondary)
                            .frame(width: 28)

                        Text("Day \(index + 1)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(GQColors.textSecondary)
                            .frame(width: 44, alignment: .leading)

                        Text(day.name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(GQColors.textPrimary)

                        Spacer()

                        Text("\(day.exercises.count) exercises")
                            .font(.system(size: 12))
                            .foregroundStyle(GQColors.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if index < plan.days.count - 1 {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
            .gqCard()
            .padding(.horizontal, 20)
        }
    }

    private func splitDayIcon(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("push") { return "arrow.up.circle" }
        if lower.contains("pull") { return "arrow.down.circle" }
        if lower.contains("legs") || lower.contains("lower") { return "figure.walk" }
        if lower.contains("upper") { return "figure.arms.open" }
        if lower.contains("full body") { return "figure.strengthtraining.traditional" }
        return "dumbbell"
    }

    // MARK: - Sample Day (GIF Strip)

    @ViewBuilder
    private var sampleDay: some View {
        if let firstDay = plan.days.first {
            VStack(alignment: .leading, spacing: 12) {
                Text("DAY 1 PREVIEW")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(GQColors.textTertiary)
                    .tracking(1.2)
                    .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(Array(firstDay.exercises.prefix(6).enumerated()), id: \.offset) { index, name in
                            VStack(spacing: 8) {
                                ExerciseGifView(exerciseName: name, size: .medium)
                                    .frame(width: 120, height: 120)

                                Text(name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(GQColors.textPrimary)
                                    .lineLimit(2, reservesSpace: true)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 120)

                                Text(sampleSetsReps(for: index))
                                    .font(.system(size: 11))
                                    .foregroundColor(GQColors.textTertiary)
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(GQColors.cardBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(GQColors.borderDefault, lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private func sampleSetsReps(for index: Int) -> String {
        let sets: [Int]
        let reps: [Int]
        switch data.goal {
        case .strength:
            sets = [5, 5, 4, 3, 3]
            reps = [3, 5, 5, 6, 5]
        case .hypertrophy:
            sets = [4, 3, 4, 3, 3]
            reps = [8, 10, 10, 12, 12]
        case .performance:
            sets = [4, 3, 3, 3, 3]
            reps = [6, 8, 8, 10, 10]
        case .general:
            sets = [3, 3, 3, 3, 3]
            reps = [10, 12, 12, 15, 12]
        case .musclePreservation:
            sets = [4, 3, 4, 3, 3]
            reps = [8, 10, 8, 12, 10]
        }
        let s = sets[index % sets.count]
        let r = reps[index % reps.count]
        return "\(s)×\(r)"
    }

    // MARK: - Features Section

    @ViewBuilder
    private var featuresSection: some View {
        VStack(spacing: 0) {
            featureRow(icon: "brain.head.profile", title: "AI Weekly Adjustments", desc: "Your plan evolves as you progress", color: GQColors.deepBlue)
            featureRow(icon: "figure.strengthtraining.traditional", title: "500+ Exercise Library", desc: "Guided demos for every movement", color: GQColors.vividPurple)
            featureRow(icon: "chart.line.uptrend.xyaxis", title: "Progressive Overload", desc: "Automatic weight & volume tracking", color: GQColors.cyanSpark)
            featureRow(icon: "clock.arrow.circlepath", title: "Real-Time Coaching", desc: "Form cues and rest timers", color: GQColors.success)
        }
        .padding(.vertical, 8)
        .gqCard()
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func featureRow(icon: String, title: String, desc: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(color.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(GQColors.textPrimary)
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(GQColors.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Tier Cards

    private var savingsPercent: Int? {
        guard let monthly = subscriptionService.monthlyProduct,
              let yearly = subscriptionService.yearlyProduct else { return nil }
        let monthlyAnnual = monthly.price * 12
        guard monthlyAnnual > 0 else { return nil }
        let saved = (1 - yearly.price / monthlyAnnual) * 100
        let rounded = NSDecimalNumber(decimal: saved).intValue
        return rounded > 0 ? rounded : nil
    }

    @ViewBuilder
    private var tierCardsSection: some View {
        VStack(spacing: 12) {
            if let yearly = subscriptionService.yearlyProduct {
                let savings = savingsPercent.map { "Save \($0)%" }
                tierCard(
                    product: yearly,
                    label: "Yearly",
                    savingsText: savings,
                    priceDetail: "\(yearly.displayPrice)/year"
                )
            } else {
                tierCardFallback(label: "Yearly", price: "$79.99/year", savingsText: "Save 39%", isSelected: selectedProduct == nil)
            }

            if let monthly = subscriptionService.monthlyProduct {
                tierCard(
                    product: monthly,
                    label: "Monthly",
                    savingsText: nil,
                    priceDetail: "\(monthly.displayPrice)/month"
                )
            } else {
                tierCardFallback(label: "Monthly", price: "$10.99/month", savingsText: nil, isSelected: false)
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func tierCard(product: Product, label: String, savingsText: String?, priceDetail: String) -> some View {
        let isSelected = selectedProduct?.id == product.id

        Button {
            withAnimation(GQMotion.press) {
                selectedProduct = product
            }
        } label: {
            tierCardContent(label: label, savingsText: savingsText, priceDetail: priceDetail, isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func tierCardFallback(label: String, price: String, savingsText: String?, isSelected: Bool) -> some View {
        tierCardContent(label: label, savingsText: savingsText, priceDetail: price, isSelected: isSelected)
    }

    @ViewBuilder
    private func tierCardContent(label: String, savingsText: String?, priceDetail: String, isSelected: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(label)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(GQColors.textPrimary)

                    if let savingsText {
                        Text(savingsText)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(GQColors.vividPurple)
                    }
                }

                Text(priceDetail)
                    .font(.subheadline)
                    .foregroundStyle(GQColors.textSecondary)
            }

            Spacer()

            Circle()
                .fill(isSelected ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(Color.clear))
                .frame(width: 22, height: 22)
                .overlay(
                    Circle()
                        .stroke(isSelected ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(GQColors.borderProminent), lineWidth: 2)
                )
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(GQColors.deepBlue.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isSelected ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(GQGradients.glassBorder),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .gqShadow(isSelected ? .elevated : .card)
    }

    // MARK: - CTA Section

    @ViewBuilder
    private var ctaSection: some View {
        VStack(spacing: 12) {
            Button {
                purchasePro()
            } label: {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Continue")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isPurchasing)
            .opacity(isPurchasing ? 0.5 : 1.0)

            Text("7-day free trial · Cancel anytime")
                .font(.caption)
                .foregroundStyle(GQColors.textTertiary)

            Button {
                skipToApp()
            } label: {
                Text("Maybe Later")
                    .font(.subheadline)
                    .foregroundStyle(GQColors.textSecondary)
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
        guard let product = selectedProduct else { return }
        isPurchasing = true

        Task {
            do {
                let success = try await subscriptionService.purchase(product)
                if success {
                    skipToApp()
                    return
                }
            } catch {
                print("Purchase failed: \(error)")
            }
            isPurchasing = false
        }
    }

    private var equipmentIcon: String {
        switch data.environment {
        case .gym: return "dumbbell.fill"
        case .home: return "house.fill"
        case .both: return "arrow.triangle.2.circlepath"
        case .outdoor: return "figure.outdoor.cycle"
        }
    }
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

        let splitLabel = splitLabel(for: splitNames, daysPerWeek: daysPerWeek)
        let title = "\(daysPerWeek)-Day \(splitLabel) \(goal.rawValue)"

        return GeneratedPlan(title: title, weekCount: weekCount, days: days)
    }

    private static func splitLabel(for names: [String], daysPerWeek: Int) -> String {
        let first = names.first?.lowercased() ?? ""
        if first.contains("full body") { return "Full Body" }
        if names.count >= 3 && first.contains("push") { return "Push/Pull/Legs" }
        if first.contains("upper") { return "Upper/Lower" }
        return "Split"
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
