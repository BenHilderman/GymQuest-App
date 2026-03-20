//
//  FeedEducationalView.swift
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

// MARK: - Learning Feed View

struct LearningFeedView: View {
    let learningItems: [LearningItem]
    let profile: UserProfile
    let onAddToPlan: (LearningItem) -> Void

    var body: some View {
        if learningItems.isEmpty {
            VStack(spacing: 16) {
                Spacer().frame(height: 60)
                Image(systemName: "book.closed")
                    .font(.system(size: 50))
                    .foregroundColor(GQColors.deepBlue.opacity(0.5))

                Text("Learning content coming soon")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("Exercise demos and form cues will appear here")
                    .font(.subheadline)
                    .foregroundColor(GQColors.textTertiary)
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .padding()
        } else {
            LazyVStack(spacing: 12) {
                ForEach(learningItems) { item in
                    LearningFeedCard(item: item, onAddToPlan: { onAddToPlan(item) })
                }
            }
            .padding(16)
        }
    }
}

struct LearningFeedCard: View {
    let item: LearningItem
    let onAddToPlan: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: item.type.icon)
                    .font(.title3)
                    .foregroundColor(GQColors.deepBlue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)

                    Text(item.type.rawValue)
                        .font(.system(size: 12))
                        .foregroundColor(GQColors.textTertiary)
                }

                Spacer()

                Text("\(item.durationSec)s")
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textTertiary)
            }

            // Cues preview
            if !item.textCues.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(item.textCues.prefix(2), id: \.self) { cue in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(GQColors.textSecondary)
                            Text(cue)
                                .font(.system(size: 13))
                                .foregroundColor(GQColors.textSecondary)
                        }
                    }
                }
            }

            // Add to plan button
            Button(action: onAddToPlan) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add to my plan")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(GQColors.deepBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(GQColors.deepBlue.opacity(0.15))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Learn This Panel

struct LearnThisPanel: View {
    @Environment(\.modelContext) private var modelContext
    let exerciseName: String
    let profile: UserProfile
    let onAddToPlan: (LearningItem) -> Void
    let onClose: () -> Void

    @Query(sort: \LearningItem.createdAt, order: .reverse) private var allLearningItems: [LearningItem]
    private var learningItems: [LearningItem] {
        allLearningItems.filter { $0.exerciseName == exerciseName }
    }

    @State private var learningContent: ExerciseLearningContent?
    @State private var showingRobotDemo = false
    @State private var hasDemoAvailable = false
    @EnvironmentObject var featureFlags: FeatureFlags

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    exerciseHeader
                    formCuesSection
                    commonMistakesSection
                    demoVideoSection
                    robotDemoSection
                    learningItemsSection
                    addToPlanButton
                }
                .padding(16)
            }
            .gqPageBackground()
            .navigationTitle("Learn This")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose)
                }
            }
            .onAppear {
                loadLearningContent()
            }
            .sheet(isPresented: $showingRobotDemo) {
                RobotDemoSheet(exerciseName: exerciseName)
            }
        }
    }

    @ViewBuilder
    private var exerciseHeader: some View {
        VStack(spacing: 8) {
            if FeatureFlags.shared.exerciseGifsEnabled {
                ExerciseGifView(exerciseName: exerciseName, size: .large, showFallback: false)
            }

            Text(exerciseName)
                .font(.title2)
                .fontWeight(.bold)

            if let content = learningContent {
                HStack(spacing: 12) {
                    if !content.muscleGroups.isEmpty {
                        Text(content.muscleGroups.first ?? "")
                            .font(.subheadline)
                            .foregroundColor(GQColors.textTertiary)
                    }

                    Text(content.difficulty)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(difficultyColor(content.difficulty).opacity(0.2))
                        .foregroundColor(difficultyColor(content.difficulty))
                        .cornerRadius(6)
                }
            } else if let metadata = ExtendedExerciseDatabase.find(exerciseName) {
                Text(metadata.muscleGroup.rawValue)
                    .font(.subheadline)
                    .foregroundColor(GQColors.textTertiary)
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var formCuesSection: some View {
        if let content = learningContent, !content.formCues.isEmpty {
            formCuesCard(cues: content.formCues)
        } else if let metadata = ExtendedExerciseDatabase.find(exerciseName) {
            formCuesCard(cues: metadata.cues)
        }
    }

    private func formCuesCard(cues: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FORM CUES")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(GQColors.textTertiary)
                .tracking(0.5)

            ForEach(cues, id: \.self) { cue in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(GQColors.textSecondary)
                    Text(cue)
                        .font(.system(size: 14))
                }
            }
        }
        .padding(16)
        .background(Color(white: 0.1))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var commonMistakesSection: some View {
        if let content = learningContent, !content.commonMistakes.isEmpty {
            commonMistakesCard(mistakes: content.commonMistakes)
        } else if let metadata = ExtendedExerciseDatabase.find(exerciseName), !metadata.commonMistakes.isEmpty {
            commonMistakesCard(mistakes: metadata.commonMistakes)
        }
    }

    private func commonMistakesCard(mistakes: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("COMMON MISTAKES")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(GQColors.textTertiary)
                .tracking(0.5)

            ForEach(mistakes, id: \.self) { mistake in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(GQColors.textTertiary)
                    Text(mistake)
                        .font(.system(size: 14))
                }
            }
        }
        .padding(16)
        .background(Color(white: 0.1))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var demoVideoSection: some View {
        if let content = learningContent, let videoURL = content.demoVideoURL {
            Button {
                let service = LearningService.shared
                service.configure(modelContext: modelContext)
                service.trackLearningView(userId: profile.id, learningItemId: UUID(), exerciseName: exerciseName)

                if let url = URL(string: videoURL) {
                    #if canImport(UIKit)
                    UIApplication.shared.open(url)
                    #endif
                }
            } label: {
                HStack {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                    Text("Watch Demo Video")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .padding(16)
                .background(
                    LinearGradient(
                        colors: [GQColors.deepBlue, GQColors.textSecondary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var robotDemoSection: some View {
        if featureFlags.robotDemosEnabled && hasDemoAvailable {
            Button {
                showingRobotDemo = true
            } label: {
                HStack {
                    Image(systemName: "figure.run")
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Generate Robot Demo")
                            .font(.headline)
                        Text("Animated stick figure with form cues")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .padding(16)
                .background(
                    LinearGradient(
                        colors: [GQColors.deepBlue, GQColors.deepBlue.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var learningItemsSection: some View {
        if !learningItems.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("DEMOS & GUIDES")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(0.5)

                ForEach(learningItems) { item in
                    LearningFeedCard(item: item, onAddToPlan: { onAddToPlan(item) })
                }
            }
        }
    }

    private var addToPlanButton: some View {
        Button {
            onClose()
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add \(exerciseName) to my next workout")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .padding(.top, 16)
    }

    private func loadLearningContent() {
        let service = LearningService.shared
        service.configure(modelContext: modelContext)
        learningContent = service.getLearningContent(for: exerciseName)

        // Check if robot demo is available
        hasDemoAvailable = RobotDemoService.shared.hasDemoAvailable(for: exerciseName)

        // Track view (using a generated ID since we're viewing content, not a stored item)
        service.trackLearningView(userId: profile.id, learningItemId: UUID(), exerciseName: exerciseName)
    }

    private func difficultyColor(_ difficulty: String) -> Color {
        switch difficulty.lowercased() {
        case "beginner": return GQColors.textSecondary
        case "intermediate": return GQColors.textSecondary
        case "advanced": return GQColors.deepBlue
        default: return .gray
        }
    }
}


// MARK: - Learning Item Type Extension

extension LearningItemType {
    var icon: String {
        switch self {
        case .demo: return "play.circle.fill"
        case .cue: return "checkmark.circle.fill"
        case .mistake: return "xmark.circle.fill"
        case .progression: return "arrow.up.circle.fill"
        case .mobilityRoutine: return "figure.flexibility"
        }
    }
}


