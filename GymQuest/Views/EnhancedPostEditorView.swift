//
//  EnhancedPostEditorView.swift
//  GymQuest
//
//  Full post customization after workout completion.
//  Supports: exercise-specific media, user tagging, location tagging,
//  squad tagging, and Spotify/Apple Music integration.
//

import SwiftUI
import SwiftData
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Enhanced Post Editor View

struct EnhancedPostEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let profile: UserProfile
    let workout: Workout?
    let exercises: [CompletedExercise]  // Exercise names and sets from the workout
    let duration: Int
    var initialSong: Song? = nil

    // Core state
    @State private var selectedEmotion: WorkoutEmotion? = nil
    @State private var caption: String = ""
    @State private var mediaItems: [PostMedia] = []
    @State private var includeStats: Bool = true

    // Tagging state
    @State private var taggedUsernames: [String] = []
    @State private var selectedLocation: LocationSuggestion?
    @State private var taggedSquads: [Squad] = []

    // Music state
    @State private var selectedSong: Song?
    @State private var spotifyPlaylistURL: String = ""
    @State private var appleMusicPlaylistURL: String = ""
    @State private var snippetStartTime: Double = 0

    // Sheet state
    @State private var showMediaPicker = false
    @State private var showUserTagger = false
    @State private var showLocationPicker = false
    @State private var showSquadPicker = false
    @State private var showMusicPicker = false
    @State private var selectedExerciseForMedia: String? = nil  // nil = general media

    // Voice note
    @State private var voiceNoteData: Data?
    @State private var voiceNoteDuration: TimeInterval = 0

    // Challenge
    @State private var attachedChallenge: PostChallengeData?
    @State private var showChallengeCreator = false

    // Theme
    @State private var selectedTheme: PostTheme = .sunset

    // Confetti
    @State private var showConfetti = false

    // Error handling
    @State private var showError = false
    @State private var errorMessage = ""

    @StateObject private var musicService = MusicService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Workout summary header
                    if let workout = workout {
                        WorkoutSummaryHeader(workout: workout, duration: duration)
                    }

                    // Caption editor
                    CaptionEditor(caption: $caption)

                    // Voice note recorder
                    if FeatureFlags.shared.voiceNotesEnabled {
                        VoiceNoteRecorderView(voiceNoteData: $voiceNoteData, voiceNoteDuration: $voiceNoteDuration)
                            .padding(.horizontal, 16)
                    }

                    // Exercise media gallery
                    ExerciseMediaGalleryView(
                        exercises: exercises,
                        mediaItems: $mediaItems,
                        onAddMedia: { exerciseName in
                            selectedExerciseForMedia = exerciseName
                            showMediaPicker = true
                        }
                    )

                    if mediaItems.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle")
                                .font(.caption)
                            Text("At least one photo or video is required to post")
                                .font(.caption)
                        }
                        .foregroundColor(GQColors.textTertiary)
                        .padding(.horizontal, 16)
                    }

                    // Post theme picker
                    PostThemePicker(selectedTheme: $selectedTheme)

                    // Tagging section
                    VStack(spacing: 16) {
                        // Tag people
                        TaggingButton(
                            icon: "at",
                            title: "Tag People",
                            selectedCount: taggedUsernames.count,
                            color: GQColors.textSecondary
                        ) {
                            showUserTagger = true
                        }

                        // Tag location
                        TaggingButton(
                            icon: "location.fill",
                            title: selectedLocation?.name ?? "Add Location",
                            selectedCount: selectedLocation != nil ? 1 : 0,
                            color: GQColors.success
                        ) {
                            showLocationPicker = true
                        }

                        // Tag squads
                        TaggingButton(
                            icon: "person.3.fill",
                            title: "Share with Squads",
                            selectedCount: taggedSquads.count,
                            color: GQColors.deepBlue
                        ) {
                            showSquadPicker = true
                        }

                        // Attach challenge
                        TaggingButton(
                            icon: "trophy.fill",
                            title: attachedChallenge?.title ?? "Attach Challenge",
                            selectedCount: attachedChallenge != nil ? 1 : 0,
                            color: .orange
                        ) {
                            showChallengeCreator = true
                        }
                    }
                    .padding(.horizontal)

                    // Tagged items preview
                    TaggedItemsPreview(
                        usernames: taggedUsernames,
                        location: selectedLocation,
                        squads: taggedSquads,
                        onRemoveUser: { username in
                            taggedUsernames.removeAll { $0 == username }
                        },
                        onRemoveLocation: {
                            selectedLocation = nil
                        },
                        onRemoveSquad: { squad in
                            taggedSquads.removeAll { $0.id == squad.id }
                        }
                    )

                    // Music section
                    MusicSelectorSection(
                        selectedSong: $selectedSong,
                        showMusicPicker: $showMusicPicker,
                        activityType: workout?.type.rawValue
                    )

                    // Snippet scrubber (when song has preview URL)
                    if selectedSong?.previewURL != nil {
                        SnippetScrubber(
                            snippetStart: $snippetStartTime,
                            previewURL: selectedSong?.previewURL
                        )
                        .padding(.horizontal)
                    }

                    // Playlist URLs
                    PlaylistLinkSection(
                        spotifyURL: $spotifyPlaylistURL,
                        appleMusicURL: $appleMusicPlaylistURL
                    )

                    // Include stats toggle
                    Toggle(isOn: $includeStats) {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(GQColors.textSecondary)
                            Text("Include workout stats")
                                .font(.subheadline)
                        }
                    }
                    .tint(GQColors.textSecondary)
                    .padding(.horizontal)

                    Spacer(minLength: 100)
                }
                .padding(.top, 16)
            }
            .scrollContentBackground(.hidden)
            .gqPageBackground()
            .navigationTitle("Customize Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") { createPost() }
                        .fontWeight(.semibold)
                        .foregroundColor(mediaItems.isEmpty ? GQColors.textSecondary : GQColors.textSecondary)
                        .disabled(mediaItems.isEmpty)
                }
            }
            .sheet(isPresented: $showMediaPicker) {
                MediaPickerSheet(
                    exerciseName: selectedExerciseForMedia,
                    onMediaSelected: { media in
                        mediaItems.append(media)
                    }
                )
            }
            .sheet(isPresented: $showUserTagger) {
                UserTaggingView(taggedUsernames: $taggedUsernames)
            }
            .sheet(isPresented: $showLocationPicker) {
                LocationTaggingView(
                    selectedLocation: $selectedLocation,
                    userId: profile.id
                )
            }
            .sheet(isPresented: $showSquadPicker) {
                SquadTaggingView(
                    taggedSquads: $taggedSquads,
                    userId: profile.id
                )
            }
            .sheet(isPresented: $showMusicPicker) {
                MusicPickerSheet(
                    selectedSong: $selectedSong,
                    activityType: workout?.type.rawValue
                )
            }
            .sheet(isPresented: $showChallengeCreator) {
                ChallengeCreatorSheet(attachedChallenge: $attachedChallenge)
            }
            .onAppear {
                if selectedSong == nil, let song = initialSong {
                    selectedSong = song
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .overlay {
                if showConfetti {
                    ConfettiOverlay()
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private func createPost() {
        // Get the first general media for legacy fields
        let generalMedia = mediaItems.first { $0.exerciseName == nil }

        let post = Post(
            authorId: profile.id,
            authorName: profile.name,
            authorUsername: profile.username,
            caption: caption,
            photoData: generalMedia?.mediaType == .photo ? generalMedia?.data : nil,
            videoData: generalMedia?.mediaType == .video ? generalMedia?.data : nil,
            workoutType: includeStats ? workout?.type.rawValue : nil,
            duration: includeStats ? duration : nil,
            setCount: includeStats ? workout?.totalSets : nil,
            exerciseHighlight: exercises.first?.name,
            songTitle: selectedSong?.title,
            artistName: selectedSong?.artist,
            songPreviewURL: selectedSong?.previewURL,
            musicSource: selectedSong?.source.rawValue,
            playlistId: selectedSong?.playlistId,
            taggedUsernames: taggedUsernames,
            mediaItemsData: try? JSONEncoder().encode(mediaItems),
            locationName: selectedLocation?.name,
            locationId: selectedLocation?.clubId,
            taggedSquadIds: taggedSquads.map { $0.id },
            taggedSquadNames: taggedSquads.map { $0.name },
            spotifyPlaylistURL: spotifyPlaylistURL.isEmpty ? nil : spotifyPlaylistURL,
            appleMusicPlaylistURL: appleMusicPlaylistURL.isEmpty ? nil : appleMusicPlaylistURL,
            workoutEmotion: selectedEmotion?.rawValue,
            voiceNoteData: voiceNoteData,
            voiceNoteDuration: voiceNoteDuration > 0 ? voiceNoteDuration : nil,
            overlayTheme: selectedTheme.rawValue,
            musicSnippetStart: selectedSong?.previewURL != nil ? snippetStartTime : nil
        )

        if let song = selectedSong {
            musicService.addToRecent(song)
        }

        // Attach challenge if set
        if var challengeInfo = attachedChallenge {
            let challenge = Challenge(
                id: challengeInfo.challengeId,
                scope: .club,
                title: challengeInfo.title,
                challengeDescription: "Community challenge from post",
                goalType: ChallengeGoalType(rawValue: challengeInfo.goalType) ?? .workouts,
                goalTarget: challengeInfo.goalTarget,
                startDate: Date(),
                endDate: challengeInfo.endDate,
                xpReward: 100
            )
            modelContext.insert(challenge)
            challengeInfo.participantCount = 1  // creator counts
            post.challengeId = challengeInfo.challengeId
            post.challengeData = try? JSONEncoder().encode(challengeInfo)
        }

        modelContext.insert(post)
        do {
            try modelContext.save()
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
            showConfetti = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        } catch {
            errorMessage = "Failed to save post. Please try again."
            showError = true
        }
    }
}

// MARK: - Snippet Scrubber

struct SnippetScrubber: View {
    @Binding var snippetStart: Double
    let previewURL: String?

    private let totalDuration: Double = 30
    private let snippetLength: Double = 15
    private let barCount: Int = 48

    @State private var isDragging = false
    @State private var isPreviewPlaying = false

    // Deterministic waveform heights (seeded from bar index)
    private func barHeight(for index: Int, maxHeight: CGFloat) -> CGFloat {
        let seed = Double(index)
        let h = abs(sin(seed * 1.8) * cos(seed * 0.7) + sin(seed * 3.2) * 0.5)
        return max(maxHeight * 0.15, CGFloat(h) * maxHeight)
    }

    private var endTime: Double {
        min(snippetStart + snippetLength, totalDuration)
    }

    private func timeLabel(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }

    private func isBarInSelection(_ index: Int) -> Bool {
        let barTime = (Double(index) / Double(barCount)) * totalDuration
        return barTime >= snippetStart && barTime <= endTime
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Image(systemName: "waveform")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(GQGradients.primary)
                Text("PREVIEW CLIP")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(0.5)
                Spacer()
                Text("\(timeLabel(snippetStart)) – \(timeLabel(endTime))")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(isPreviewPlaying ? GQColors.deepBlue : GQColors.textSecondary)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.15), value: snippetStart)
            }

            // Waveform scrubber
            GeometryReader { geo in
                let trackWidth = geo.size.width
                let maxStart = totalDuration - snippetLength

                ZStack(alignment: .leading) {
                    // Waveform bars
                    HStack(alignment: .center, spacing: 1.5) {
                        ForEach(0..<barCount, id: \.self) { i in
                            let selected = isBarInSelection(i)
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(selected ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(GQColors.textTertiary.opacity(0.25)))
                                .frame(height: barHeight(for: i, maxHeight: 32))
                                .animation(.easeInOut(duration: 0.15), value: selected)
                        }
                    }
                    .frame(maxHeight: 36, alignment: .center)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                #if canImport(UIKit)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                #endif
                            }
                            let fraction = value.location.x / trackWidth
                            snippetStart = min(max(0, fraction * totalDuration - snippetLength / 2), maxStart)
                        }
                        .onEnded { _ in
                            isDragging = false
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                            // Preview audio at new position
                            if let url = previewURL {
                                isPreviewPlaying = true
                                MusicPreviewService.shared.playURL(
                                    postId: UUID(),
                                    previewURL: url,
                                    snippetStart: snippetStart
                                )
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    MusicPreviewService.shared.stop()
                                    isPreviewPlaying = false
                                }
                            }
                        }
                )
            }
            .frame(height: 36)

            // Hint text
            Text("Drag to choose which part plays on your post")
                .font(.system(size: 11))
                .foregroundColor(GQColors.textTertiary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(GQColors.surfaceOverlay.opacity(0.78))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(GQColors.deepBlue.opacity(isDragging ? 0.3 : 0.08), lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isDragging)
    }
}

// MARK: - Post Theme Picker

struct PostThemePicker: View {
    @Binding var selectedTheme: PostTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Post Vibe")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(GQColors.textPrimary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(PostTheme.allCases, id: \.self) { theme in
                        ThemeSwatch(theme: theme, isSelected: selectedTheme == theme) {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                selectedTheme = theme
                            }
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

private struct ThemeSwatch: View {
    let theme: PostTheme
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: theme.previewColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white, lineWidth: isSelected ? 2.5 : 0)
                    )
                    .scaleEffect(isSelected ? 1.1 : 1.0)

                Text("\(theme.emoji) \(theme.rawValue)")
                    .font(.caption2)
                    .foregroundColor(isSelected ? GQColors.textPrimary : GQColors.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Confetti Overlay

struct ConfettiOverlay: View {
    @State private var particles: [(id: Int, x: CGFloat, y: CGFloat, color: Color, size: CGFloat, rotation: Double)] = []
    @State private var animate = false

    private let colors: [Color] = [
        Color(red: 0.9, green: 0.4, blue: 0.2),
        Color(red: 0.9, green: 0.7, blue: 0.2),
        Color(red: 0.85, green: 0.3, blue: 0.4),
        Color(red: 0.5, green: 0.3, blue: 0.7),
        Color(red: 0.1, green: 0.4, blue: 0.6),
        .white
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles, id: \.id) { p in
                    RoundedRectangle(cornerRadius: p.size > 6 ? 2 : p.size)
                        .fill(p.color)
                        .frame(width: p.size, height: p.size * (p.id % 2 == 0 ? 1.5 : 1))
                        .rotationEffect(.degrees(animate ? p.rotation + 360 : p.rotation))
                        .position(
                            x: p.x,
                            y: animate ? geo.size.height + 50 : -20
                        )
                        .opacity(animate ? 0 : 1)
                }
            }
            .onAppear {
                particles = (0..<24).map { i in
                    (
                        id: i,
                        x: CGFloat.random(in: 20...(geo.size.width - 20)),
                        y: CGFloat.random(in: 0...geo.size.height * 0.3),
                        color: colors[i % colors.count],
                        size: CGFloat.random(in: 4...10),
                        rotation: Double.random(in: 0...180)
                    )
                }
                withAnimation(.easeOut(duration: 1.4)) {
                    animate = true
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Completed Exercise (from workout session)

struct CompletedExercise: Identifiable {
    let id = UUID()
    let name: String
    let sets: Int
    let index: Int
}

// MARK: - Workout Summary Header

struct WorkoutSummaryHeader: View {
    let workout: Workout
    let duration: Int

    var body: some View {
        HStack(spacing: 16) {
            // Workout type icon
            ZStack {
                Circle()
                    .fill(GQGradients.workoutGradient(for: workout.type))
                    .frame(width: 50, height: 50)

                Image(systemName: workout.type.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(workout.title ?? workout.type.rawValue)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(GQColors.textPrimary)

                HStack(spacing: 12) {
                    Label("\(duration) min", systemImage: "clock.fill")
                    Label("\(workout.totalSets) sets", systemImage: "number")
                }
                .font(.system(size: 13))
                .foregroundColor(GQColors.textSecondary)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.06))
        )
        .padding(.horizontal)
    }
}

// MARK: - Caption Editor

struct CaptionEditor: View {
    @Binding var caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CAPTION")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(GQColors.textTertiary)
                .tracking(0.5)

            TextEditor(text: $caption)
                .frame(minHeight: 80)
                .padding(12)
                .background(Color.black.opacity(0.06))
                .cornerRadius(12)
                .scrollContentBackground(.hidden)
                .foregroundColor(GQColors.textPrimary)
        }
        .padding(.horizontal)
    }
}

// MARK: - Exercise Media Gallery View

struct ExerciseMediaGalleryView: View {
    let exercises: [CompletedExercise]
    @Binding var mediaItems: [PostMedia]
    let onAddMedia: (String?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MEDIA")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(GQColors.textTertiary)
                .tracking(0.5)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // General media slot
                    MediaSlot(
                        title: "General",
                        subtitle: "Not exercise-specific",
                        media: mediaItems.filter { $0.exerciseName == nil },
                        onAdd: { onAddMedia(nil) },
                        onRemove: { media in
                            mediaItems.removeAll { $0.id == media.id }
                        }
                    )

                    // Exercise-specific slots
                    ForEach(exercises) { exercise in
                        MediaSlot(
                            title: exercise.name,
                            subtitle: "\(exercise.sets) sets",
                            media: mediaItems.filter { $0.exerciseName == exercise.name },
                            onAdd: { onAddMedia(exercise.name) },
                            onRemove: { media in
                                mediaItems.removeAll { $0.id == media.id }
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Media Slot

struct MediaSlot: View {
    let title: String
    let subtitle: String
    let media: [PostMedia]
    let onAdd: () -> Void
    let onRemove: (PostMedia) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(GQColors.textPrimary)
                .lineLimit(1)

            Text(subtitle)
                .font(.system(size: 11))
                .foregroundColor(GQColors.textTertiary)

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.06))
                    .frame(width: 100, height: 100)

                if let firstMedia = media.first {
                    // Show thumbnail
                    if let data = firstMedia.data ?? firstMedia.thumbnailData,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        // Media type badge
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: firstMedia.mediaType == .video ? "video.fill" : "photo.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(4)
                            }
                            Spacer()
                        }
                        .frame(width: 100, height: 100)
                        .padding(4)

                        // Remove button
                        Button {
                            onRemove(firstMedia)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .offset(x: 40, y: -40)
                    }
                } else {
                    // Add button
                    Button(action: onAdd) {
                        VStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [GQColors.deepBlue, GQColors.textSecondary],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Text("Add")
                                .font(.system(size: 11))
                                .foregroundColor(GQColors.textSecondary)
                        }
                    }
                }

                // Media count badge
                if media.count > 1 {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("+\(media.count - 1)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(GQColors.deepBlue)
                                .cornerRadius(8)
                        }
                    }
                    .frame(width: 100, height: 100)
                    .padding(4)
                }
            }
        }
        .frame(width: 100)
    }
}

// MARK: - Tagging Button

struct TaggingButton: View {
    let icon: String
    let title: String
    let selectedCount: Int
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(GQColors.textPrimary)

                Spacer()

                if selectedCount > 0 {
                    Text("\(selectedCount)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(color)
                        .cornerRadius(10)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.textTertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.06))
            )
        }
        .buttonStyle(GQInteractiveStyle())
    }
}

// MARK: - Tagged Items Preview

struct TaggedItemsPreview: View {
    let usernames: [String]
    let location: LocationSuggestion?
    let squads: [Squad]
    let onRemoveUser: (String) -> Void
    let onRemoveLocation: () -> Void
    let onRemoveSquad: (Squad) -> Void

    var isEmpty: Bool {
        usernames.isEmpty && location == nil && squads.isEmpty
    }

    var body: some View {
        if !isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Tagged users
                    ForEach(usernames, id: \.self) { username in
                        PostTagChip(
                            icon: "at",
                            text: username,
                            color: GQColors.textSecondary
                        ) {
                            onRemoveUser(username)
                        }
                    }

                    // Location
                    if let loc = location {
                        PostTagChip(
                            icon: "location.fill",
                            text: loc.name,
                            color: GQColors.success
                        ) {
                            onRemoveLocation()
                        }
                    }

                    // Squads
                    ForEach(squads) { squad in
                        PostTagChip(
                            icon: "person.3.fill",
                            text: squad.name,
                            color: GQColors.deepBlue
                        ) {
                            onRemoveSquad(squad)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Post Tag Chip

struct PostTagChip: View {
    let icon: String
    let text: String
    let color: Color
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))

            Text(text)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.3))
        .cornerRadius(16)
    }
}

// MARK: - Playlist Link Section

struct PlaylistLinkSection: View {
    @Binding var spotifyURL: String
    @Binding var appleMusicURL: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PLAYLIST LINKS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(GQColors.textTertiary)
                .tracking(0.5)

            // Spotify
            HStack(spacing: 10) {
                Image(systemName: "music.note")
                    .foregroundColor(Color(hex: "1DB954"))
                    .frame(width: 20)

                TextField("Spotify playlist URL", text: $spotifyURL)
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(12)
            .background(Color.black.opacity(0.06))
            .cornerRadius(10)

            // Apple Music
            HStack(spacing: 10) {
                Image(systemName: "music.note")
                    .foregroundColor(Color(hex: "FC3C44"))
                    .frame(width: 20)

                TextField("Apple Music playlist URL", text: $appleMusicURL)
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(12)
            .background(Color.black.opacity(0.06))
            .cornerRadius(10)
        }
        .padding(.horizontal)
    }
}

// MARK: - Media Picker Sheet

struct MediaPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let exerciseName: String?
    let onMediaSelected: (PostMedia) -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var showCamera = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(exerciseName != nil ? "Add media for \(exerciseName!)" : "Add general media")
                    .font(.headline)
                    .padding(.top)

                // Photo picker
                PhotosPicker(selection: $selectedItem, matching: .any(of: [.images, .videos])) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 24))
                        Text("Choose from Library")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(GQColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .buttonStyle(WorkoutFlowPrimaryButtonStyle(accent: GQColors.deepBlue))
                .padding(.horizontal)

                // Camera button
                Button {
                    showCamera = true
                } label: {
                    HStack {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 24))
                        Text("Take Photo/Video")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(GQColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .buttonStyle(WorkoutFlowSecondaryButtonStyle())
                .padding(.horizontal)

                Spacer()
            }
            .gqPageBackground()
            .navigationTitle("Add Media")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: selectedItem) { _, newValue in
                loadMedia(from: newValue)
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraCapture(exerciseName: exerciseName, onMediaCaptured: { media in
                    onMediaSelected(media)
                    dismiss()
                })
            }
        }
    }

    private func loadMedia(from item: PhotosPickerItem?) {
        guard let item = item else { return }

        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let isPhoto = UIImage(data: data) != nil

                let media = PostMedia(
                    exerciseName: exerciseName,
                    exerciseIndex: nil,
                    mediaType: isPhoto ? .photo : .video,
                    data: data,
                    thumbnailData: isPhoto ? data : generateVideoThumbnail(from: data)
                )
                onMediaSelected(media)
                dismiss()
            }
        }
    }

    private func generateVideoThumbnail(from data: Data) -> Data? {
        // Placeholder - in real app would use AVAssetImageGenerator
        return nil
    }
}

// MARK: - Camera Capture (Placeholder)

struct CameraCapture: View {
    let exerciseName: String?
    let onMediaCaptured: (PostMedia) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            Text("Camera capture")
                .foregroundColor(GQColors.textPrimary)
            Button("Close") { dismiss() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .gqPageBackground()
    }
}

// MARK: - Location Suggestion Model

struct LocationSuggestion: Identifiable {
    let id: UUID
    let name: String
    let type: LocationType
    let clubId: UUID?

    enum LocationType {
        case club
        case recent
        case custom
    }
}

// MARK: - User Tagging View

struct UserTaggingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var friends: [Friend]

    @Binding var taggedUsernames: [String]
    @State private var searchText: String = ""

    var filteredFriends: [Friend] {
        if searchText.isEmpty {
            return Array(friends.prefix(20))
        }
        return friends.filter {
            $0.odUsername.localizedCaseInsensitiveContains(searchText) ||
            $0.odName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(GQColors.textTertiary)
                    TextField("Search friends", text: $searchText)
                        .foregroundColor(GQColors.textPrimary)
                }
                .padding(12)
                .background(Color.black.opacity(0.06))
                .cornerRadius(10)
                .padding()

                // Friends list
                List {
                    ForEach(filteredFriends) { friend in
                        FriendTagRow(
                            friend: friend,
                            isSelected: taggedUsernames.contains(friend.odUsername)
                        ) {
                            toggleFriend(friend)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .gqPageBackground()
            .navigationTitle("Tag People")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(GQColors.textSecondary)
                }
            }
        }
    }

    private func toggleFriend(_ friend: Friend) {
        if taggedUsernames.contains(friend.odUsername) {
            taggedUsernames.removeAll { $0 == friend.odUsername }
        } else {
            taggedUsernames.append(friend.odUsername)
        }
    }
}

// MARK: - Friend Tag Row

struct FriendTagRow: View {
    let friend: Friend
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Circle()
                    .fill(GQColors.deepBlue.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(friend.odName.prefix(1)).uppercased())
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.odName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(GQColors.textPrimary)

                    Text("@\(friend.odUsername)")
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textSecondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? GQColors.textSecondary : GQColors.textTertiary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(GQInteractiveStyle())
    }
}

// MARK: - Location Tagging View

struct LocationTaggingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var clubs: [Club]

    @Binding var selectedLocation: LocationSuggestion?
    let userId: UUID

    @State private var searchText: String = ""
    @State private var customLocation: String = ""

    var userClubs: [Club] {
        clubs.filter { $0.memberIds.contains(userId) }
    }

    var otherClubs: [Club] {
        if searchText.isEmpty { return [] }
        return clubs.filter {
            !$0.memberIds.contains(userId) &&
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(GQColors.textTertiary)
                    TextField("Search or enter location", text: $searchText)
                        .foregroundColor(GQColors.textPrimary)
                }
                .padding(12)
                .background(Color.black.opacity(0.06))
                .cornerRadius(10)
                .padding()

                List {
                    // Custom location option
                    if !searchText.isEmpty {
                        Section {
                            Button {
                                selectedLocation = LocationSuggestion(
                                    id: UUID(),
                                    name: searchText,
                                    type: .custom,
                                    clubId: nil
                                )
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundColor(GQColors.success)
                                    Text("Use \"\(searchText)\"")
                                        .foregroundColor(GQColors.textPrimary)
                                }
                            }
                            .listRowBackground(Color.black.opacity(0.06))
                        } header: {
                            Text("Custom Location")
                                .foregroundColor(GQColors.textTertiary)
                        }
                    }

                    // User's gyms/clubs
                    if !userClubs.isEmpty {
                        Section {
                            ForEach(userClubs) { club in
                                ClubLocationRow(
                                    club: club,
                                    isSelected: selectedLocation?.clubId == club.id
                                ) {
                                    selectedLocation = LocationSuggestion(
                                        id: UUID(),
                                        name: club.name,
                                        type: .club,
                                        clubId: club.id
                                    )
                                    dismiss()
                                }
                                .listRowBackground(Color.clear)
                            }
                        } header: {
                            Text("Your Gyms")
                                .foregroundColor(GQColors.textTertiary)
                        }
                    }

                    // Other clubs
                    if !otherClubs.isEmpty {
                        Section {
                            ForEach(otherClubs) { club in
                                ClubLocationRow(
                                    club: club,
                                    isSelected: selectedLocation?.clubId == club.id
                                ) {
                                    selectedLocation = LocationSuggestion(
                                        id: UUID(),
                                        name: club.name,
                                        type: .club,
                                        clubId: club.id
                                    )
                                    dismiss()
                                }
                                .listRowBackground(Color.clear)
                            }
                        } header: {
                            Text("Other Locations")
                                .foregroundColor(GQColors.textTertiary)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .gqPageBackground()
            .navigationTitle("Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Club Location Row

struct ClubLocationRow: View {
    let club: Club
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: "building.2.fill")
                    .foregroundColor(GQColors.success)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(club.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(GQColors.textPrimary)

                    if let location = club.location {
                        Text(location)
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textSecondary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(GQColors.success)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(GQInteractiveStyle())
    }
}

// MARK: - Squad Tagging View

struct SquadTaggingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allSquads: [Squad]

    @Binding var taggedSquads: [Squad]
    let userId: UUID

    var userSquads: [Squad] {
        allSquads.filter { $0.memberIds.contains(userId) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if userSquads.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 48))
                            .foregroundColor(GQColors.textTertiary)

                        Text("No Squads Yet")
                            .font(.headline)
                            .foregroundColor(GQColors.textPrimary)

                        Text("Join or create a squad to share workouts with your team!")
                            .font(.subheadline)
                            .foregroundColor(GQColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(userSquads) { squad in
                            SquadTagRow(
                                squad: squad,
                                isSelected: taggedSquads.contains { $0.id == squad.id }
                            ) {
                                toggleSquad(squad)
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .gqPageBackground()
            .navigationTitle("Share with Squads")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(GQColors.textSecondary)
                }
            }
        }
    }

    private func toggleSquad(_ squad: Squad) {
        if taggedSquads.contains(where: { $0.id == squad.id }) {
            taggedSquads.removeAll { $0.id == squad.id }
        } else {
            taggedSquads.append(squad)
        }
    }
}

// MARK: - Squad Tag Row

struct SquadTagRow: View {
    let squad: Squad
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                ZStack {
                    Circle()
                        .fill(GQGradients.primary)
                        .frame(width: 44, height: 44)

                    Image(systemName: "person.3.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(squad.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(GQColors.textPrimary)

                    Text("\(squad.memberCount) members")
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textSecondary)
                }

                Spacer()

                if squad.streakWeeks > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(GQColors.textSecondary)
                        Text("\(squad.streakWeeks)w")
                            .foregroundColor(GQColors.textSecondary)
                    }
                    .font(.system(size: 11, weight: .semibold))
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? GQColors.deepBlue : GQColors.textTertiary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(GQInteractiveStyle())
    }
}

// MARK: - Challenge Creator Sheet

struct ChallengeCreatorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var attachedChallenge: PostChallengeData?

    @State private var title = ""
    @State private var goalType: ChallengeGoalType = .workouts
    @State private var goalTarget: Int = 10
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()

    private var minDate: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Challenge Details") {
                    TextField("Challenge title", text: $title)
                        .textFieldStyle(LiftAITextFieldStyle())

                    Picker("Goal Type", selection: $goalType) {
                        ForEach(ChallengeGoalType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }

                    Stepper("Target: \(goalTarget)", value: $goalTarget, in: 1...1000)

                    DatePicker("End Date", selection: $endDate, in: minDate..., displayedComponents: .date)
                }
                .listRowBackground(GQColors.surfaceBase)

                if let challenge = attachedChallenge {
                    Section {
                        Button(role: .destructive) {
                            attachedChallenge = nil
                            dismiss()
                        } label: {
                            Label("Remove Challenge", systemImage: "trash")
                        }
                    }
                    .listRowBackground(GQColors.surfaceBase)
                }
            }
            .scrollContentBackground(.hidden)
            .gqPageBackground()
            .navigationTitle("Create Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Attach") {
                        let challengeId = attachedChallenge?.challengeId ?? UUID()
                        attachedChallenge = PostChallengeData(
                            challengeId: challengeId,
                            title: title,
                            goalType: goalType.rawValue,
                            goalTarget: goalTarget,
                            endDate: endDate,
                            participantCount: 0
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let existing = attachedChallenge {
                    title = existing.title
                    goalType = ChallengeGoalType(rawValue: existing.goalType) ?? .workouts
                    goalTarget = existing.goalTarget
                    endDate = existing.endDate
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    EnhancedPostEditorView(
        profile: UserProfile(name: "Ben", username: "ben"),
        workout: nil,
        exercises: [
            CompletedExercise(name: "Bench Press", sets: 4, index: 0),
            CompletedExercise(name: "Incline Press", sets: 3, index: 1),
            CompletedExercise(name: "Cable Fly", sets: 3, index: 2)
        ],
        duration: 45
    )
}
