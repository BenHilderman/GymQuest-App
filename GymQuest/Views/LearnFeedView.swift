//
//  LearnFeedView.swift
//  GymQuest
//
//  Structured educational feed — form guides, beginner tips,
//  routines, and learning content for the Learn tab.
//

import SwiftUI
import SwiftData

struct LearnFeedView: View {
    let profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var featureFlags: FeatureFlags

    @Query(sort: \FormExercise.name) private var formExercises: [FormExercise]
    @Query(sort: \LearningItem.createdAt, order: .reverse) private var learningItems: [LearningItem]
    @Query private var learningProgress: [LearningProgress]

    @State private var selectedFormExercise: FormExercise?
    @State private var showFormStudio = false
    @State private var selectedLearnExercise: String?
    @State private var showLearnPanel = false

    private var savedItemIds: Set<UUID> {
        Set(learningProgress.filter { $0.saved }.map { $0.learningItemId })
    }

    private var tipItems: [LearningItem] {
        learningItems.filter { $0.type == .cue || $0.type == .mistake }
    }

    private var routineItems: [LearningItem] {
        learningItems.filter { $0.type == .mobilityRoutine || $0.type == .progression }
    }

    private var demoItems: [LearningItem] {
        learningItems.filter { $0.type == .demo }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: GQSpacing.xxl) {
                learnHero
                if !formExercises.isEmpty { formGuidesSection }
                if !tipItems.isEmpty { tipsSection }
                if !routineItems.isEmpty { routinesSection }
                if !demoItems.isEmpty { demosSection }
                if formExercises.isEmpty && learningItems.isEmpty { emptyState }
                Spacer(minLength: GQLayout.pageBottom)
            }
            .padding(.top, GQLayout.pageTop)
        }
        .scrollContentBackground(.hidden)
        .gqPageBackground()
        .onAppear {
            LearningService.shared.configure(modelContext: modelContext)
            LearningService.shared.seedDefaultLearningContent()
            FormContentSeeder.seedIfNeeded(modelContext: modelContext)
        }
        .fullScreenCover(isPresented: $showFormStudio) {
            if let exercise = selectedFormExercise {
                NavigationStack {
                    FormStudioView(oduserId: profile.id.uuidString, exercise: exercise)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showFormStudio = false }
                            }
                        }
                }
            }
        }
        .sheet(isPresented: $showLearnPanel) {
            if let name = selectedLearnExercise {
                LearnThisPanel(
                    exerciseName: name,
                    profile: profile,
                    onAddToPlan: { _ in showLearnPanel = false },
                    onClose: { showLearnPanel = false }
                )
            }
        }
    }

    // MARK: - Hero

    private var learnHero: some View {
        VStack(spacing: GQSpacing.sm) {
            Image(systemName: "book.and.wrench.fill")
                .font(.system(size: 28))
                .foregroundStyle(GQGradients.primary)

            Text("Learn to Lift")
                .font(.title2.bold())
                .foregroundColor(GQColors.textPrimary)

            Text("Form guides, tips, and routines to build your foundation.")
                .font(.subheadline)
                .foregroundColor(GQColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, GQLayout.screenHorizontal)
    }

    // MARK: - Form Guides

    private var formGuidesSection: some View {
        VStack(alignment: .leading, spacing: GQSpacing.md) {
            sectionHeader(title: "Form Guides", icon: "figure.strengthtraining.traditional")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: GQSpacing.md) {
                    ForEach(formExercises) { exercise in
                        formGuideCard(exercise)
                    }
                }
                .padding(.horizontal, GQLayout.screenHorizontal)
            }
        }
    }

    private func formGuideCard(_ exercise: FormExercise) -> some View {
        Button {
            selectedFormExercise = exercise
            showFormStudio = true
        } label: {
            VStack(alignment: .leading, spacing: GQSpacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: GQRadius.md)
                        .fill(GQGradients.primary.opacity(0.15))
                        .frame(height: 100)

                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(GQColors.primary)
                }

                Text(exercise.name)
                    .font(.subheadline.bold())
                    .foregroundColor(GQColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: GQSpacing.xs) {
                    Text(exercise.patternRaw)
                        .font(.caption2)
                        .foregroundColor(GQColors.textSecondary)

                    Spacer()

                    Text(difficultyLabel(exercise.difficulty))
                        .font(.caption2.bold())
                        .foregroundColor(GQColors.primary)
                }
            }
            .frame(width: 160)
            .padding(GQLayout.cardHorizontal)
            .background(GQColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: GQRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: GQRadius.lg)
                    .stroke(GQColors.borderDefault, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tips

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: GQSpacing.md) {
            sectionHeader(title: "Quick Tips", icon: "lightbulb.fill")

            VStack(spacing: GQSpacing.sm) {
                ForEach(tipItems.prefix(5)) { item in
                    tipCard(item)
                }
            }
            .padding(.horizontal, GQLayout.screenHorizontal)
        }
    }

    private func tipCard(_ item: LearningItem) -> some View {
        Button {
            if let name = item.exerciseName {
                selectedLearnExercise = name
                showLearnPanel = true
            }
        } label: {
            HStack(spacing: GQSpacing.md) {
                Image(systemName: item.type == .cue ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundColor(item.type == .cue ? GQColors.success : GQColors.warning)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    if let name = item.exerciseName {
                        Text(name)
                            .font(.caption.bold())
                            .foregroundColor(GQColors.textSecondary)
                    }
                    Text(item.textCues.first ?? item.commonMistake ?? "Tip")
                        .font(.subheadline)
                        .foregroundColor(GQColors.textPrimary)
                        .lineLimit(2)
                }

                Spacer()

                saveButton(for: item)
            }
            .padding(GQLayout.cardHorizontal)
            .background(GQColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: GQRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: GQRadius.md)
                    .stroke(GQColors.borderDefault, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Routines

    private var routinesSection: some View {
        VStack(alignment: .leading, spacing: GQSpacing.md) {
            sectionHeader(title: "Routines & Progressions", icon: "arrow.up.right.circle.fill")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: GQSpacing.md) {
                    ForEach(routineItems.prefix(6)) { item in
                        routineCard(item)
                    }
                }
                .padding(.horizontal, GQLayout.screenHorizontal)
            }
        }
    }

    private func routineCard(_ item: LearningItem) -> some View {
        Button {
            if let name = item.exerciseName {
                selectedLearnExercise = name
                showLearnPanel = true
            }
        } label: {
            VStack(alignment: .leading, spacing: GQSpacing.sm) {
                Image(systemName: item.type == .mobilityRoutine ? "figure.flexibility" : "chart.line.uptrend.xyaxis")
                    .font(.title2)
                    .foregroundStyle(GQGradients.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(item.exerciseName ?? item.topic ?? "Routine")
                    .font(.subheadline.bold())
                    .foregroundColor(GQColors.textPrimary)
                    .lineLimit(2)

                if item.durationSec > 0 {
                    Text("\(item.durationSec / 60) min")
                        .font(.caption2)
                        .foregroundColor(GQColors.textSecondary)
                }

                saveButton(for: item)
            }
            .frame(width: 140)
            .padding(GQLayout.cardHorizontal)
            .background(GQColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: GQRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: GQRadius.lg)
                    .stroke(GQColors.borderDefault, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Demos

    private var demosSection: some View {
        VStack(alignment: .leading, spacing: GQSpacing.md) {
            sectionHeader(title: "Exercise Demos", icon: "play.rectangle.fill")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: GQSpacing.md) {
                    ForEach(demoItems.prefix(8)) { item in
                        demoCard(item)
                    }
                }
                .padding(.horizontal, GQLayout.screenHorizontal)
            }
        }
    }

    private func demoCard(_ item: LearningItem) -> some View {
        Button {
            if let name = item.exerciseName {
                selectedLearnExercise = name
                showLearnPanel = true
            }
        } label: {
            VStack(spacing: GQSpacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: GQRadius.sm)
                        .fill(GQColors.surfaceOverlay)
                        .frame(width: 120, height: 80)

                    Image(systemName: "play.fill")
                        .foregroundColor(GQColors.primary)
                }

                Text(item.exerciseName ?? "Demo")
                    .font(.caption.bold())
                    .foregroundColor(GQColors.textPrimary)
                    .lineLimit(1)
            }
            .frame(width: 120)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Save Button

    private func saveButton(for item: LearningItem) -> some View {
        Button {
            saveLearningItem(item)
        } label: {
            Image(systemName: savedItemIds.contains(item.id) ? "bookmark.fill" : "bookmark")
                .font(.subheadline)
                .foregroundColor(savedItemIds.contains(item.id) ? GQColors.primary : GQColors.textTertiary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: GQSpacing.md) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 40))
                .foregroundColor(GQColors.textTertiary)

            Text("Nothing to Learn Yet")
                .font(.headline)
                .foregroundColor(GQColors.textPrimary)

            Text("Complete a workout to unlock routines, form tips, and beginner guides.")
                .font(.subheadline)
                .foregroundColor(GQColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(GQLayout.screenHorizontal)
        .padding(.top, 60)
    }

    // MARK: - Helpers

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: GQSpacing.sm) {
            Image(systemName: icon)
                .foregroundColor(GQColors.sectionLabel)
            Text(title)
                .font(.headline)
                .foregroundColor(GQColors.textPrimary)
        }
        .padding(.horizontal, GQLayout.screenHorizontal)
    }

    private func difficultyLabel(_ level: Int) -> String {
        switch level {
        case 1: return "Beginner"
        case 2: return "Intermediate"
        case 3: return "Advanced"
        default: return "All Levels"
        }
    }

    private func saveLearningItem(_ item: LearningItem) {
        let itemId = item.id
        let descriptor = FetchDescriptor<LearningProgress>(
            predicate: #Predicate { $0.learningItemId == itemId }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.saved.toggle()
            existing.savedAt = existing.saved ? Date() : nil
        } else {
            let progress = LearningProgress(
                odId: profile.id,
                learningItemId: item.id,
                viewed: true,
                saved: true,
                addedToPlan: false
            )
            progress.viewedAt = Date()
            progress.savedAt = Date()
            modelContext.insert(progress)
            AnalyticsService.shared.track(.learnItemSaved, userId: profile.id)
        }
        try? modelContext.save()
    }
}
