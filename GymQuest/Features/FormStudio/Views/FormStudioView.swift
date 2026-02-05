//
//  FormStudioView.swift
//  GymQuest
//
//  Main Form Studio view for exercise form learning and progression.
//

import SwiftUI
import SwiftData
import AVFoundation

struct FormStudioView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var downloadManager = OfflineHLSDownloadManager()

    let oduserId: String
    let exercise: FormExercise

    @State private var selectedType: ClipType = .loop
    @State private var selectedAngle: ClipAngle = .a45

    @State private var player = AVPlayer()
    @StateObject private var timeObserver = PlayerTimeObserver()
    @State private var overlayEvents: [OverlayEvent] = []

    @State private var selectedTab: FormStudioTab = .overview

    enum FormStudioTab: String, CaseIterable {
        case overview = "Overview"
        case setup = "Setup"
        case breakdown = "Breakdown"
        case cues = "Cues"
        case angles = "Angles"
        case formCheck = "Form Check"
    }

    var repo: FormRepository { FormRepository(modelContext: modelContext) }

    var body: some View {
        let mastery = repo.mastery(oduserId: oduserId, exerciseId: exercise.id)

        ScrollView {
            VStack(spacing: 16) {
                // Video Section
                videoSection(mastery: mastery)

                // Tab Picker
                tabPicker

                // Tab Content
                tabContent(mastery: mastery)
                    .padding(.horizontal, 16)

                // Recommendations
                recommendationsSection(mastery: mastery)
                    .padding(.horizontal, 16)
            }
            .padding(.vertical, 12)
        }
        .background(Color.black)
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        selectedType = .loop
                    } label: {
                        Label("Loop", systemImage: "arrow.triangle.2.circlepath")
                    }

                    Button {
                        selectedType = .breakdown
                        selectedTab = .breakdown
                    } label: {
                        Label("Breakdown", systemImage: "list.bullet.rectangle")
                    }

                    Button {
                        selectedType = .coachEye
                    } label: {
                        Label("Coach's Eye", systemImage: "eye.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            loadClipAndPlay(for: selectedType, angle: selectedAngle)
            timeObserver.observe(player)
        }
        .onDisappear {
            player.pause()
            timeObserver.removeObserver()
        }
    }

    // MARK: - Video Section

    @ViewBuilder
    private func videoSection(mastery: ExerciseMastery) -> some View {
        ZStack {
            FormVideoPlayerView(player: player)
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal, 12)

            // Overlay layer
            FormOverlayLayer(events: overlayEvents, currentTime: timeObserver.currentTime)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal, 12)
        }
        .overlay(alignment: .topLeading) {
            HStack(spacing: 10) {
                clipTypeMenu
                angleMenu
            }
            .padding(.leading, 20)
            .padding(.top, 10)
        }
        .overlay(alignment: .topTrailing) {
            downloadButton
                .padding(.trailing, 20)
                .padding(.top, 10)
        }
        .overlay(alignment: .bottom) {
            if selectedType == .breakdown, let clip = repo.clip(exercise: exercise, type: .breakdown, angle: selectedAngle) {
                ChapterStrip(
                    chapters: clip.chapters,
                    duration: clip.durationSeconds,
                    currentTime: timeObserver.currentTime,
                    onSelect: { seek(to: $0) }
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
    }

    private var clipTypeMenu: some View {
        Menu {
            ForEach(ClipType.allCases, id: \.self) { type in
                Button {
                    switchClip(to: type)
                    if type == .breakdown { selectedTab = .breakdown }
                } label: {
                    Label(type.title, systemImage: iconForType(type))
                }
            }
        } label: {
            controlPill(title: selectedType.title, icon: iconForType(selectedType))
        }
    }

    private var angleMenu: some View {
        Menu {
            ForEach(repo.availableAngles(exercise: exercise, type: selectedType), id: \.self) { angle in
                Button {
                    switchAngle(to: angle)
                } label: {
                    Text(angle.title)
                }
            }
        } label: {
            controlPill(title: selectedAngle.title, icon: "viewfinder")
        }
    }

    private var downloadButton: some View {
        Group {
            if let clip = repo.clip(exercise: exercise, type: selectedType, angle: selectedAngle),
               let url = clip.bestPlaybackURL {
                let progress = downloadManager.downloadProgress(for: clip.id)

                Button {
                    if progress < 0 {
                        downloadManager.downloadHLS(for: clip.id, url: url)
                    }
                } label: {
                    HStack(spacing: 4) {
                        if progress >= 0 && progress < 1 {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("\(Int(progress * 100))%")
                        } else if progress >= 1 || clip.isDownloaded {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Saved")
                        } else {
                            Image(systemName: "arrow.down.circle")
                            Text("Save")
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                }
            }
        }
    }

    private func controlPill(title: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    private func iconForType(_ type: ClipType) -> String {
        switch type {
        case .loop: return "arrow.triangle.2.circlepath"
        case .breakdown: return "list.bullet.rectangle"
        case .coachEye: return "eye.fill"
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FormStudioTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                        if tab == .breakdown { switchClip(to: .breakdown) }
                    } label: {
                        Text(tab.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(selectedTab == tab ? .white : GQColors.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selectedTab == tab ? GQColors.primary.opacity(0.3) : Color.white.opacity(0.08))
                            .cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private func tabContent(mastery: ExerciseMastery) -> some View {
        switch selectedTab {
        case .overview:
            overviewSection(mastery: mastery)
        case .setup:
            FormSetupChecklistView(mastery: mastery, exercise: exercise)
        case .breakdown:
            breakdownSection
        case .cues:
            FormCuesMistakesView(cues: exercise.cues, faults: exercise.faults)
        case .angles:
            anglesSection
        case .formCheck:
            FormCheckView(mastery: mastery) { rating in
                repo.addConfidenceRating(rating, to: mastery)
            }
        }
    }

    // MARK: - Overview

    private func overviewSection(mastery: ExerciseMastery) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Quick Stats
            HStack(spacing: 16) {
                StatCard(title: "Pattern", value: exercise.pattern.title, icon: "figure.strengthtraining.traditional")
                StatCard(title: "Level", value: mastery.state.title, icon: "chart.bar.fill")
                StatCard(title: "Sessions", value: "\(mastery.sessionsCount)", icon: "calendar")
            }

            // Top Cues
            VStack(alignment: .leading, spacing: 10) {
                Text("Key Cues")
                    .font(.headline)
                    .foregroundColor(.white)

                ForEach(exercise.cues.sorted(by: { $0.priority < $1.priority }).prefix(3)) { cue in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(GQColors.primary)
                            .frame(width: 6, height: 6)

                        Text(cue.text)
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(14)
            .background(GQColors.cardBackground)
            .cornerRadius(14)

            // Progress
            progressCard(mastery: mastery)
        }
    }

    private func progressCard(mastery: ExerciseMastery) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Progression")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Text("\(Int(mastery.progressPercentage))%")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(GQColors.primary)
            }

            ProgressView(value: mastery.progressPercentage, total: 100)
                .tint(GQColors.primary)

            Text(mastery.canUnlockNextVariation ? "Ready for next variation!" : "Complete gates to unlock progression")
                .font(.caption)
                .foregroundColor(GQColors.textSecondary)
        }
        .padding(14)
        .background(GQColors.cardBackground)
        .cornerRadius(14)
    }

    // MARK: - Breakdown

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let clip = repo.clip(exercise: exercise, type: .breakdown, angle: selectedAngle) {
                FormChaptersView(
                    chapters: clip.chapters,
                    currentTime: timeObserver.currentTime,
                    onSelect: { seek(to: $0) }
                )
                .padding(14)
                .background(GQColors.cardBackground)
                .cornerRadius(14)
            } else {
                Text("No breakdown video available.")
                    .font(.subheadline)
                    .foregroundColor(GQColors.textSecondary)
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(GQColors.cardBackground)
                    .cornerRadius(14)
            }
        }
    }

    // MARK: - Angles

    private var anglesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Camera Angles")
                .font(.headline)
                .foregroundColor(.white)

            Text("Switch angles to verify bar path and joint tracking from different perspectives.")
                .font(.subheadline)
                .foregroundColor(GQColors.textSecondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(ClipAngle.allCases, id: \.self) { angle in
                    let isAvailable = repo.availableAngles(exercise: exercise, type: selectedType).contains(angle)

                    Button {
                        if isAvailable { switchAngle(to: angle) }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: iconForAngle(angle))
                                .font(.title2)

                            Text(angle.title)
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundColor(isAvailable ? (selectedAngle == angle ? .white : GQColors.textSecondary) : GQColors.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(selectedAngle == angle ? GQColors.primary.opacity(0.3) : Color.white.opacity(0.08))
                        .cornerRadius(12)
                        .opacity(isAvailable ? 1 : 0.5)
                    }
                    .buttonStyle(.plain)
                    .disabled(!isAvailable)
                }
            }
        }
        .padding(14)
        .background(GQColors.cardBackground)
        .cornerRadius(14)
    }

    private func iconForAngle(_ angle: ClipAngle) -> String {
        switch angle {
        case .a45: return "rotate.3d"
        case .side: return "arrow.left.and.right"
        case .front: return "person.fill"
        case .top: return "arrow.up"
        }
    }

    // MARK: - Recommendations

    private func recommendationsSection(mastery: ExerciseMastery) -> some View {
        let recs = RecommendationEngine.nextSteps(currentExercise: exercise, mastery: mastery)

        return Group {
            if !recs.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Next Steps")
                        .font(.headline)
                        .foregroundColor(.white)

                    ForEach(recs.prefix(2)) { rec in
                        RecommendationRow(recommendation: rec)
                    }
                }
                .padding(14)
                .background(GQColors.cardBackground)
                .cornerRadius(14)
            }
        }
    }

    // MARK: - Playback

    private func switchClip(to type: ClipType) {
        selectedType = type
        loadClipAndPlay(for: type, angle: selectedAngle)
    }

    private func switchAngle(to angle: ClipAngle) {
        selectedAngle = angle
        loadClipAndPlay(for: selectedType, angle: angle)
    }

    private func loadClipAndPlay(for type: ClipType, angle: ClipAngle) {
        guard let clip = repo.clip(exercise: exercise, type: type, angle: angle),
              let url = clip.bestPlaybackURL else {
            return
        }

        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        player.play()

        // Load overlays for breakdown
        if type == .breakdown {
            Task { await loadOverlays(for: clip) }
        } else {
            overlayEvents = []
        }
    }

    private func seek(to seconds: Double) {
        let cm = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: cm, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func loadOverlays(for clip: FormClip) async {
        guard let s = clip.overlayTimelineURLString, let url = URL(string: s) else {
            await MainActor.run { overlayEvents = [] }
            return
        }
        do {
            let events = try await OverlayTimelineLoader.load(from: url)
            await MainActor.run { overlayEvents = events }
        } catch {
            await MainActor.run { overlayEvents = [] }
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(GQColors.primary)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)

            Text(title)
                .font(.caption)
                .foregroundColor(GQColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(GQColors.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Recommendation Row

struct RecommendationRow: View {
    let recommendation: RecommendationEngine.Recommendation

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForAction(recommendation.action))
                .font(.title3)
                .foregroundColor(GQColors.primary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(recommendation.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)

                Text(recommendation.reason)
                    .font(.caption)
                    .foregroundColor(GQColors.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(GQColors.textTertiary)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }

    private func iconForAction(_ action: RecommendationEngine.RecommendationAction) -> String {
        switch action {
        case .repeatExercise: return "arrow.counterclockwise"
        case .watchBreakdown: return "play.rectangle"
        case .watchCoachEye: return "eye.fill"
        case .tryHarderVariation: return "arrow.up.circle"
        case .tryEasierVariation: return "arrow.down.circle"
        case .completeSetup: return "checklist"
        }
    }
}
