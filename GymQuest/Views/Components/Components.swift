//
//  Components.swift
//  GymQuest
//
//  Created by Benjamin Hilderman
//
//  Bold & Energetic reusable UI components
//  Glass morphism cards, streamlined button styles
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Card Container (Glass style)

struct CardContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.4))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(GQGradients.glassBorder, lineWidth: 1)
        )
    }
}

// small colored label for status/tags
struct ChipBadge: View {
    let text: String
    let style: ChipStyle

    enum ChipStyle {
        case normal, accent, good, warn, bad // color variants
    }

    var textColor: Color {
        switch style {
        case .normal: return GQColors.textTertiary
        case .accent: return .white
        case .good: return .green
        case .warn: return .yellow
        case .bad: return .red
        }
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(textColor)
    }
}

struct FormField<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundColor(GQColors.textTertiary)
            content
        }
    }
}

// MARK: - Accent Button Style (Glass style)

struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.white.opacity(0.1))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { HapticManager.shared.tap() }
            }
    }
}

// MARK: - Animated Gradient Button Style (Subtle glass with gradient border)

struct AnimatedGradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color(white: 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(
                        AngularGradient(
                            colors: GQGradients.energyColors,
                            center: .center
                        ),
                        lineWidth: 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Onboarding Button Style (Subtle glass with gradient border)

struct OnboardingButtonStyle: ButtonStyle {
    let isLastStep: Bool

    init(isLastStep: Bool = false) {
        self.isLastStep = isLastStep
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color(white: 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(
                        isLastStep
                            ? AnyShapeStyle(LinearGradient(colors: [GQColors.success, GQColors.cyanSpark], startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(AngularGradient(colors: GQGradients.energyColors, center: .center)),
                        lineWidth: 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Animated Logo

struct AnimatedLogo: View {
    @State private var rotation: Double = 0
    @State private var glowOpacity: Double = 0.3

    var body: some View {
        ZStack {
            // Glow effect behind icon
            Circle()
                .fill(
                    RadialGradient(
                        colors: [GQColors.vividPurple.opacity(glowOpacity), .clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)

            // Rotating gradient through dumbbell
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    AngularGradient(
                        colors: GQGradients.energyColors,
                        center: .center,
                        angle: .degrees(rotation)
                    )
                )
        }
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowOpacity = 0.6
            }
        }
    }
}

// MARK: - Home Section Header

struct HomeSectionHeader: View {
    let title: String
    let icon: String?
    @Binding var isExpanded: Bool

    init(title: String, icon: String? = nil, isExpanded: Binding<Bool>) {
        self.title = title
        self.icon = icon
        self._isExpanded = isExpanded
    }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(GQColors.textTertiary)
                }

                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(0.5)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(GQColors.textTertiary.opacity(0.7))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

struct DangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(GQColors.error)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(GQColors.error.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(GQColors.error.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { HapticManager.shared.tap() }
            }
    }
}

struct GymQuestTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}

struct StatChip: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundColor(GQColors.textTertiary)
        }
    }
}

struct SessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let session: Workout

    @State private var showingDeleteAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.type.rawValue)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(session.date.formatted(date: .long, time: .omitted))
                            .font(.subheadline)
                            .foregroundColor(GQColors.textTertiary)
                    }

                    // stats row
                    HStack(spacing: 32) {
                        StatChip(value: "\(session.duration)", label: "min")
                        StatChip(value: "\(session.totalSets)", label: "sets")
                        StatChip(value: "\(session.exercises.count)", label: "exercises")
                    }

                    // exercises
                    if !session.exercises.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Exercises")
                                .font(.headline)

                            ForEach(session.exercises.sorted(by: { $0.order < $1.order })) { exercise in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(exercise.name)
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text(exercise.muscleGroup.rawValue)
                                            .font(.caption)
                                            .foregroundColor(GQColors.textTertiary)
                                    }

                                    ForEach(exercise.sets.sorted(by: { $0.order < $1.order })) { set in
                                        HStack {
                                            Text("\(set.reps) reps")
                                                .font(.subheadline)
                                            if set.weight > 0 {
                                                Text("× \(Int(set.weight)) lbs")
                                                    .font(.subheadline)
                                                    .foregroundColor(GQColors.textTertiary)
                                            }
                                            Spacer()
                                        }
                                    }
                                }
                                .padding()
                                .background(Color.white.opacity(0.03))
                                .cornerRadius(12)
                            }
                        }
                    }

                    // notes
                    if !session.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.headline)
                            Text(session.notes)
                                .foregroundColor(GQColors.textTertiary)
                        }
                    }

                    Spacer().frame(height: 20)

                    Button("Delete Workout") {
                        showingDeleteAlert = true
                    }
                    .buttonStyle(DangerButtonStyle())
                }
                .padding()
            }
            .background(GQColors.background.ignoresSafeArea())
            .navigationTitle("Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete Workout", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    modelContext.delete(session)
                    try? modelContext.save()
                    dismiss()
                }
            }
        }
    }
}

struct WorkoutCompletionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let workout: Workout
    let xpEarned: Int
    let leveledUp: Bool
    let newLevel: Int
    let profile: UserProfile
    var photoData: Data? = nil
    var caption: String = ""

    @State private var prMoments: [PRMoment] = []
    @State private var prEvents: [PREvent] = []
    @State private var coachTakeaway: String?
    @State private var workoutSummary: WorkoutSummary?
    @State private var isLoading = true
    @State private var showConfetti = false
    @State private var cardAppeared = false
    @State private var showShareSheet = false
    @State private var showPRCelebration = false
    @State private var selectedPRForShare: PRMoment?
    #if canImport(UIKit)
    @State private var cardImage: UIImage?
    #endif
    @State private var selectedVisibility: CardVisibility = .pod

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // level up celebration
                    if leveledUp {
                        LevelUpBanner(newLevel: newLevel)
                    }

                    // PR celebration banner with quick share CTA
                    if !prMoments.isEmpty && !isLoading {
                        PRCelebrationBanner(
                            prMoments: prMoments,
                            onSharePR: { pr in
                                selectedPRForShare = pr
                                showPRCelebration = true
                            }
                        )
                    }

                    // the workout card
                    if isLoading {
                        CardLoadingPlaceholder()
                    } else {
                        WorkoutCardView(
                            workout: workout,
                            profile: profile,
                            streakCount: workoutSummary?.streak ?? 0,
                            xpEarned: xpEarned,
                            prMoments: prMoments,
                            coachTakeaway: coachTakeaway,
                            fistBumpCount: 0
                        )
                        .scaleEffect(cardAppeared ? 1.0 : 0.85)
                        .opacity(cardAppeared ? 1.0 : 0)
                    }

                    // Quick stats summary
                    if let summary = workoutSummary {
                        QuickStatsSummary(summary: summary)
                    }

                    // share options
                    VStack(spacing: 16) {
                        Text("SHARE YOUR WORKOUT")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(GQColors.textTertiary)
                            .tracking(1)

                        // visibility picker
                        HStack(spacing: 12) {
                            ShareOptionButton(
                                title: "Pod",
                                icon: "person.3.fill",
                                isSelected: selectedVisibility == .pod
                            ) {
                                selectedVisibility = .pod
                            }

                            ShareOptionButton(
                                title: "Friends",
                                icon: "person.2.fill",
                                isSelected: selectedVisibility == .friends
                            ) {
                                selectedVisibility = .friends
                            }

                            ShareOptionButton(
                                title: "Export",
                                icon: "square.and.arrow.up",
                                isSelected: false
                            ) {
                                exportCard()
                            }
                        }

                        // Primary share button
                        Button {
                            shareToFeed()
                        } label: {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                Text("Share to \(selectedVisibility.rawValue)")
                            }
                        }
                        .buttonStyle(AnimatedGradientButtonStyle())

                        // Keep Private button (secondary action)
                        Button {
                            dismiss()
                        } label: {
                            Text("Keep Private")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.top, 4)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
            }
            .background(GQColors.background.ignoresSafeArea())
            .navigationTitle("Workout Complete")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .task {
                await generateCardContent()
            }
            .overlay {
                if showConfetti {
                    ConfettiView()
                        .ignoresSafeArea()
                }
            }
            .onChange(of: isLoading) { _, newValue in
                if !newValue {
                    HapticManager.shared.workoutComplete()
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        cardAppeared = true
                    }
                    showConfetti = true
                }
            }
            #if canImport(UIKit)
            .sheet(isPresented: $showShareSheet) {
                if let image = cardImage {
                    ShareSheet(items: [image])
                }
            }
            .sheet(isPresented: $showPRCelebration) {
                if let pr = selectedPRForShare {
                    PRShareSheet(prMoment: pr, workout: workout, profile: profile)
                }
            }
            #endif
        }
    }

    // generates the workout card content (PRs, streak, coach insight)
    @MainActor
    private func generateCardContent() async {
        let aiService = AIService()
        let prService = PRService.shared
        let analytics = AnalyticsService.shared
        analytics.configure(modelContext: modelContext)

        let descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let allWorkouts = (try? modelContext.fetch(descriptor)) ?? []

        // Use enhanced PR detection
        let prResults = prService.detectAllPRs(
            workout: workout,
            allWorkouts: allWorkouts,
            profile: profile,
            modelContext: modelContext
        )
        prEvents = prResults.events
        prMoments = prResults.moments

        // Track PRs
        for pr in prMoments {
            analytics.trackPRDetected(
                userId: profile.id,
                prType: pr.prType.rawValue,
                exerciseName: pr.exerciseName,
                improvement: pr.improvement
            )
        }

        // Generate workout summary
        workoutSummary = prService.generateWorkoutSummary(
            workout: workout,
            profile: profile,
            allWorkouts: allWorkouts
        )

        // AI generates a short takeaway for the card
        coachTakeaway = await aiService.generateCoachTakeaway(
            workout: workout,
            profile: profile,
            workouts: allWorkouts,
            hasPR: !prMoments.isEmpty
        )

        // Track workout completion
        analytics.trackWorkoutCompleted(
            userId: profile.id,
            duration: workout.duration,
            totalSets: workout.totalSets,
            xpEarned: xpEarned
        )

        try? modelContext.save()
        isLoading = false
    }

    // saves workout card + post to feed
    private func shareToFeed() {
        let analytics = AnalyticsService.shared

        // build exercise summary for the card
        let exerciseSummary = workout.exercises.map { exercise -> ExerciseSummaryItem in
            let sets = exercise.sets.sorted { $0.order < $1.order }
            let avgReps = sets.isEmpty ? 0 : sets.map { $0.reps }.reduce(0, +) / sets.count
            let maxWeight = sets.map { $0.weight }.max() ?? 0
            return ExerciseSummaryItem(
                name: exercise.name,
                sets: sets.count,
                reps: "\(avgReps)",
                weight: maxWeight
            )
        }

        let summaryJSON = (try? JSONEncoder().encode(exerciseSummary))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

        let card = WorkoutCard(
            odId: profile.id,
            odName: profile.name,
            odUsername: profile.username,
            workoutId: workout.id,
            workoutType: workout.type.rawValue,
            duration: workout.duration,
            totalSets: workout.totalSets,
            avgRPE: Double(workout.rpe),
            exerciseSummary: summaryJSON,
            coachTakeaway: coachTakeaway,
            xpEarned: xpEarned,
            streakCount: workoutSummary?.streak ?? 0,
            visibility: selectedVisibility
        )

        modelContext.insert(card)

        // also create a post for the feed
        let post = Post(
            id: UUID(),
            authorId: profile.id,
            authorName: profile.name,
            authorUsername: profile.username,
            caption: caption.isEmpty ? (coachTakeaway ?? "") : caption,
            photoData: photoData,
            workoutType: workout.type.rawValue,
            duration: workout.duration,
            setCount: workout.totalSets
        )
        modelContext.insert(post)

        // Track card creation
        analytics.trackWorkoutCardCreated(
            userId: profile.id,
            hasPRs: !prMoments.isEmpty,
            hasCoachTakeaway: coachTakeaway != nil
        )

        do {
            try modelContext.save()
        } catch {
            print("Failed to save post to feed: \(error)")
        }
        dismiss()
    }

    #if canImport(UIKit)
    private func exportCard() {
        guard let summary = workoutSummary else { return }

        let shareService = ShareService.shared
        let analytics = AnalyticsService.shared

        if let image = shareService.exportWorkoutCard(
            workout: workout,
            profile: profile,
            summary: summary,
            prMoments: prMoments,
            coachTakeaway: coachTakeaway
        ) {
            cardImage = image
            showShareSheet = true
            analytics.trackShareExported(userId: profile.id, shareType: "workout_card")
        }
    }
    #else
    private func exportCard() {
        // macOS export not implemented
    }
    #endif
}

// MARK: - PR Celebration Banner

struct PRCelebrationBanner: View {
    let prMoments: [PRMoment]
    let onSharePR: (PRMoment) -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)

                VStack(alignment: .leading, spacing: 2) {
                    Text("NEW PR\(prMoments.count > 1 ? "s" : "")!")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.yellow)

                    Text("You hit \(prMoments.count) personal record\(prMoments.count > 1 ? "s" : "") today")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()
            }

            // Quick share buttons for each PR
            ForEach(prMoments.prefix(2)) { pr in
                Button {
                    onSharePR(pr)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            if let exercise = pr.exerciseName {
                                Text(exercise)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            Text(pr.value)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.8))
                        }

                        Spacer()

                        Text("Share")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.yellow.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [GQColors.cyanSpark.opacity(0.15), GQColors.vividPurple.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(GQColors.cyanSpark.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Quick Stats Summary

struct QuickStatsSummary: View {
    let summary: WorkoutSummary

    var body: some View {
        HStack(spacing: 0) {
            QuickStat(value: "\(summary.totalSets)", label: "sets")
            Divider().frame(height: 30).background(Color.white.opacity(0.1))
            QuickStat(value: summary.formattedVolume, label: "volume")
            Divider().frame(height: 30).background(Color.white.opacity(0.1))
            QuickStat(value: "\(summary.duration)", label: "min")
            if summary.streak >= 3 {
                Divider().frame(height: 30).background(Color.white.opacity(0.1))
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundColor(GQColors.success)
                    Text("\(summary.streak)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(GQColors.success)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
    }
}

struct QuickStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - PR Share Sheet

#if canImport(UIKit)
struct PRShareSheet: View {
    @Environment(\.dismiss) private var dismiss
    let prMoment: PRMoment
    let workout: Workout
    let profile: UserProfile

    @State private var showShareSheet = false
    @State private var cardImage: UIImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Preview of PR card
                ShareablePRCard(
                    prMoment: prMoment,
                    workout: workout,
                    profile: profile
                )
                .scaleEffect(0.85)
                .frame(height: 400)

                Spacer()

                // Export button
                Button {
                    exportPRCard()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export PR Card")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)

                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(GQColors.textTertiary)
                .padding(.bottom, 32)
            }
            .background(GQColors.background.ignoresSafeArea())
            .navigationTitle("Share Your PR")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .sheet(isPresented: $showShareSheet) {
                if let image = cardImage {
                    ShareSheet(items: [image])
                }
            }
        }
    }

    private func exportPRCard() {
        let shareService = ShareService.shared

        if let image = shareService.exportPRCard(
            prMoment: prMoment,
            workout: workout,
            profile: profile
        ) {
            cardImage = image
            showShareSheet = true
        }
    }
}
#endif

struct LevelUpBanner: View {
    let newLevel: Int
    @State private var shimmerPhase: CGFloat = 0

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(GQColors.cyanSpark.opacity(0.2))
                    .frame(width: 48, height: 48)

                Image(systemName: "star.fill")
                    .font(.title2)
                    .foregroundColor(GQColors.cyanSpark)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("LEVEL UP!")
                    .font(GQTypography.sectionHeader)
                    .foregroundColor(GQColors.cyanSpark)
                    .tracking(1)

                Text("Level \(newLevel) - \(UserProfile.levelTitle(for: newLevel))")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [GQColors.cyanSpark.opacity(0.15), GQColors.sunsetOrange.opacity(0.1)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(GQColors.cyanSpark.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: GQColors.cyanSpark.opacity(0.2), radius: 12, y: 4)
    }
}

struct CardLoadingPlaceholder: View {
    @State private var pulseOpacity: Double = 0.3

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(GQColors.vividPurple)

            Text("Generating your workout card...")
                .font(.subheadline)
                .foregroundColor(GQColors.textSecondary)
        }
        .frame(height: 300)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.4))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(GQColors.vividPurple.opacity(pulseOpacity), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseOpacity = 0.6
            }
        }
    }
}

struct ShareOptionButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : GQColors.textTertiary)
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(isSelected ? Color.white.opacity(0.1) : Color.black.opacity(0.3))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? GQColors.vividPurple.opacity(0.5) : Color.white.opacity(0.1),
                        lineWidth: 1
                    )
            )
            .shadow(color: isSelected ? GQColors.vividPurple.opacity(0.2) : .clear, radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#if canImport(UIKit)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

struct StatBlock: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundColor(GQColors.textTertiary)
        }
    }
}

#Preview {
    CardContainer {
        Text("Preview")
    }
    .preferredColorScheme(.dark)
    .padding()
}
