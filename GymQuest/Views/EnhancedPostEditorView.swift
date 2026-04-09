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
    static let maxMediaItems = 10
    static let maxVideoDuration: Double = 60

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let profile: UserProfile
    let workout: Workout?
    let exercises: [CompletedExercise]  // Exercise names and sets from the workout
    let duration: Int
    var initialSong: Song? = nil
    var preloadedMedia: [PostMedia] = []

    // Navigation
    private enum PostEditorPhase: Hashable { case customize }
    @State private var navigationPath = NavigationPath()
    @State private var didAutoNavigate = false
    @State private var currentMediaIndex: Int = 0

    // Media (Phase 1)
    @State private var selectedMedia: PostMedia? = nil
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    #if canImport(UIKit)
    @StateObject private var cameraVM = CameraViewModel()
    @State private var previewImage: UIImage? = nil
    #endif

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
    @State private var showUserTagger = false
    @State private var showLocationPicker = false
    @State private var showSquadPicker = false
    @State private var showMusicPicker = false

    // Voice note
    @State private var voiceNoteData: Data?
    @State private var voiceNoteDuration: TimeInterval = 0

    // Challenge
    @State private var attachedChallenge: PostChallengeData?
    @State private var showChallengeCreator = false

    // Widget
    @State private var attachedWidget: PostWidget?
    @State private var showWidgetPicker = false

    // Confetti
    @State private var showConfetti = false

    // Error handling
    @State private var showError = false
    @State private var errorMessage = ""

    @StateObject private var musicService = MusicService.shared

    var body: some View {
        NavigationStack(path: $navigationPath) {
            mediaSelectionPhase
                .navigationDestination(for: PostEditorPhase.self) { _ in
                    postCustomizationPhase
                }
        }
        .tint(GQColors.textPrimary)
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
        .sheet(isPresented: $showWidgetPicker) {
            PostWidgetPickerSheet(attachedWidget: $attachedWidget, profile: profile, workout: workout, exercises: exercises, duration: duration)
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

    // MARK: - Phase 1: Media Selection (Live Camera)

    @ViewBuilder
    private var capturedThumbnailStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(mediaItems.enumerated()), id: \.element.id) { idx, item in
                    capturedThumbnail(item: item, index: idx)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func capturedThumbnail(item: PostMedia, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            #if canImport(UIKit)
            if let data = item.thumbnailData ?? item.data, let thumb = UIImage(data: data) {
                Image(uiImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                videoThumbnailPlaceholder
            }
            #endif
            Button {
                withAnimation { let _: PostMedia = mediaItems.remove(at: index) }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .background(Circle().fill(.black.opacity(0.5)).frame(width: 14, height: 14))
            }
            .offset(x: 4, y: -4)
        }
    }

    @ViewBuilder
    private var videoThumbnailPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(GQColors.overlayMedium)
            .frame(width: 48, height: 48)
            .overlay(Image(systemName: "video.fill").font(.system(size: 14)).foregroundColor(.white))
    }

    // MARK: - Media Reorder Strip

    @ViewBuilder
    private var mediaReorderStrip: some View {
        VStack(spacing: 4) {
            Text("Hold & drag to reorder")
                .font(.system(size: 11))
                .foregroundColor(GQColors.textTertiary)

            HStack(spacing: 8) {
                ForEach(mediaItems) { item in
                    reorderThumbnail(item: item)
                }
            }
            .padding(.horizontal, 14)
        }
    }

    @ViewBuilder
    private func reorderThumbnail(item: PostMedia) -> some View {
        let idx = mediaItems.firstIndex(where: { $0.id == item.id }) ?? 0
        let isActive = idx == currentMediaIndex
        ZStack {
            #if canImport(UIKit)
            if let data = item.thumbnailData ?? item.data, let thumb = UIImage(data: data) {
                Image(uiImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                videoThumbnailPlaceholder
            }
            #endif

            if item.mediaType == .video {
                Image(systemName: "play.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .shadow(radius: 2)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(Color.clear), lineWidth: 2.5)
        )
        .onTapGesture { withAnimation { currentMediaIndex = idx } }
        .draggable(item.id.uuidString) {
            // Drag preview
            RoundedRectangle(cornerRadius: 8)
                .fill(GQColors.overlayMedium)
                .frame(width: 56, height: 56)
                .overlay(
                    Text("\(idx + 1)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                )
        }
        .dropDestination(for: String.self) { droppedIDs, _ in
            guard let droppedID = droppedIDs.first,
                  let fromUUID = UUID(uuidString: droppedID),
                  let fromIdx = mediaItems.firstIndex(where: { $0.id == fromUUID }) else { return false }
            let toIdx = mediaItems.firstIndex(where: { $0.id == item.id }) ?? 0
            if fromIdx != toIdx {
                moveMedia(from: fromIdx, to: toIdx)
            }
            return true
        }
    }

    private func moveMedia(from source: Int, to destination: Int) {
        withAnimation {
            let item = mediaItems.remove(at: source)
            mediaItems.insert(item, at: destination)
            currentMediaIndex = destination
        }
    }

    private func navigateToCustomize() {
        selectedMedia = mediaItems.first
        #if canImport(UIKit)
        if let data = mediaItems.first?.data, let img = UIImage(data: data) {
            previewImage = img
        }
        #endif
        navigationPath.append(PostEditorPhase.customize)
    }

    @ViewBuilder
    private var mediaSelectionPhase: some View {
        ZStack {
            GQColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Camera viewfinder
                ZStack {
                    #if canImport(UIKit)
                    PostCameraPreviewView(cameraVM: cameraVM)
                    #else
                    Color.black
                    #endif
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(GQColors.borderDefault, lineWidth: 1)
                )
                .padding(.horizontal, 12)
                .padding(.top, 8)

                // Captured media thumbnails + count
                if !mediaItems.isEmpty {
                    HStack {
                        capturedThumbnailStrip
                        Spacer()
                        Text("\(mediaItems.count)/\(Self.maxMediaItems)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(mediaItems.count >= Self.maxMediaItems ? GQColors.vividPurple : GQColors.textTertiary)
                            .padding(.trailing, 16)
                    }
                    .padding(.top, 10)
                }

                Spacer()

                // Controls
                HStack(alignment: .center) {
                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .any(of: [.images, .videos])
                    ) {
                        VStack(spacing: 6) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 22))
                                .foregroundColor(GQColors.textPrimary)
                            Text("Library")
                                .font(.system(size: 11))
                                .foregroundColor(GQColors.textSecondary)
                        }
                        .frame(width: 56, height: 56)
                    }

                    Spacer()

                    #if canImport(UIKit)
                    ShutterButton(isRecording: cameraVM.isRecording) {
                        guard mediaItems.count < Self.maxMediaItems else { return }
                        cameraVM.capturePhoto { [self] data in
                            guard let data = data,
                                  let img = UIImage(data: data)?.fixedOrientation(),
                                  let compressed = img.jpegData(compressionQuality: 0.8) else { return }
                            let media = PostMedia(
                                exerciseName: nil,
                                exerciseIndex: nil,
                                mediaType: .photo,
                                data: compressed,
                                thumbnailData: compressed
                            )
                            withAnimation { mediaItems.append(media) }
                            // Enhance in background
                            let itemIndex = mediaItems.count - 1
                            Task.detached {
                                let enhanced = cameraVM.applySubtleEnhancement(to: compressed)
                                await MainActor.run {
                                    if itemIndex < mediaItems.count {
                                        mediaItems[itemIndex] = PostMedia(exerciseName: nil, exerciseIndex: nil, mediaType: .photo, data: enhanced, thumbnailData: enhanced)
                                    }
                                }
                            }
                        }
                    } onHoldStart: {
                        guard mediaItems.count < Self.maxMediaItems else { return }
                        cameraVM.startRecording()
                    } onHoldEnd: { [self] in
                        cameraVM.stopRecording { url in
                            guard let url = url, let data = try? Data(contentsOf: url) else { return }
                            let thumb = VideoThumbnailGenerator.generate(from: url)
                            let thumbData = thumb?.jpegData(compressionQuality: 0.7)
                            let media = PostMedia(
                                exerciseName: nil,
                                exerciseIndex: nil,
                                mediaType: .video,
                                data: data,
                                thumbnailData: thumbData
                            )
                            withAnimation { mediaItems.append(media) }
                            try? FileManager.default.removeItem(at: url)
                        }
                    }
                    #endif

                    Spacer()

                    // Flip / Next button
                    if mediaItems.isEmpty {
                        Button {
                            #if canImport(UIKit)
                            cameraVM.flipCamera()
                            #endif
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "camera.rotate")
                                    .font(.system(size: 22))
                                    .foregroundColor(GQColors.textPrimary)
                                Text("Flip")
                                    .font(.system(size: 11))
                                    .foregroundColor(GQColors.textSecondary)
                            }
                            .frame(width: 56, height: 56)
                        }
                    } else {
                        Button { navigateToCustomize() } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(GQGradients.primary)
                                        .frame(width: 48, height: 48)
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                Text("Next")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(GQColors.textPrimary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 32)
                .padding(.top, 16)
            }
        }
        .navigationTitle("Share Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Skip") { dismiss() }
                    .foregroundColor(GQColors.textSecondary)
            }
            ToolbarItem(placement: .primaryAction) {
                if !mediaItems.isEmpty {
                    Button {
                        #if canImport(UIKit)
                        cameraVM.flipCamera()
                        #endif
                    } label: {
                        Image(systemName: "camera.rotate")
                            .foregroundColor(GQColors.textPrimary)
                    }
                }
            }
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            loadMediaFromPhotosPicker(newValue)
        }
        .onAppear {
            guard !didAutoNavigate, !preloadedMedia.isEmpty else { return }
            didAutoNavigate = true
            mediaItems = preloadedMedia
            navigateToCustomize()
        }
    }

    // MARK: - Phase 2: Post Customization

    @ViewBuilder
    private var postCustomizationPhase: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Post preview card
                postPreviewCard
                    .padding(.horizontal, 16)

                // Add-ons row (music, extras) — horizontal compact pills
                addOnsRow
                    .padding(.horizontal, 16)

                // Snippet scrubber (when song with preview is selected)
                if selectedSong?.previewURL != nil {
                    SnippetScrubber(snippetStart: $snippetStartTime, previewURL: selectedSong?.previewURL)
                        .padding(.horizontal, 16)
                }

                // Options card (tag, location, squads, stats)
                optionsCard
                    .padding(.horizontal, 16)

                // Tagged items preview
                TaggedItemsPreview(
                    usernames: taggedUsernames,
                    location: selectedLocation,
                    squads: taggedSquads,
                    onRemoveUser: { username in taggedUsernames.removeAll { $0 == username } },
                    onRemoveLocation: { selectedLocation = nil },
                    onRemoveSquad: { squad in taggedSquads.removeAll { $0.id == squad.id } }
                )
                .padding(.horizontal, 16)

                // Share button
                Button { createPost() } label: { Text("Share to Feed") }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                Spacer(minLength: 30)
            }
            .padding(.top, 8)
        }
        .scrollContentBackground(.hidden)
        .gqPageBackground()
        .navigationTitle("Customize Post")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Post Preview Card

    @ViewBuilder
    private var postPreviewCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Circle()
                    .fill(GQGradients.primary)
                    .frame(width: 38, height: 38)
                    .overlay(
                        Text(String(profile.name.prefix(1)).uppercased())
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                    if let workout = workout {
                        Text("\(workout.type.rawValue) \u{00B7} \(duration)m \u{00B7} \(workout.totalSets) sets")
                            .font(.system(size: 12))
                            .foregroundColor(GQColors.textSecondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            // Photo carousel
            mediaPreview

            // Reorderable thumbnail strip
            if mediaItems.count > 1 {
                mediaReorderStrip
                    .padding(.top, 6)
            }

            // Caption bubble
            HStack {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $caption)
                        .scrollContentBackground(.hidden)
                        .foregroundColor(.white)
                        .font(.system(size: 15))
                        .lineSpacing(2)
                        .frame(minHeight: 38)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)

                    if caption.isEmpty {
                        Text("What's the highlight?")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }
                .background(
                    ChatBubbleShape(isFromCurrentUser: true)
                        .fill(GQGradients.primary)
                        .shadow(color: GQColors.deepBlue.opacity(0.25), radius: 6, y: 3)
                )
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .background(GQColors.surfaceBase)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(GQColors.borderDefault, lineWidth: 1)
        )
        .gqShadow(.card)
    }

    // MARK: - Music Add-on Pill

    @ViewBuilder
    private var musicAddOnPill: some View {
        let isActive = selectedSong != nil
        Button { showMusicPicker = true } label: {
            HStack(spacing: 6) {
                if let song = selectedSong, let artURL = song.albumArt {
                    AsyncImage(url: artURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "music.note")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 12, weight: .medium))
                }

                Text(selectedSong?.title ?? "Music")
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                if isActive {
                    Button {
                        withAnimation { selectedSong = nil }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .foregroundColor(isActive ? .white : GQColors.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isActive ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(GQColors.surfaceBase))
            )
            .overlay(
                Capsule()
                    .stroke(isActive ? Color.clear : GQColors.borderDefault, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add-ons Row (horizontal pills)

    @ViewBuilder
    private var addOnsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // Music pill with album art
                musicAddOnPill

                // Challenge pill (clears widget if selected)
                addOnPill(
                    icon: "trophy.fill",
                    label: attachedChallenge?.title ?? "Challenge",
                    isActive: attachedChallenge != nil,
                    onTap: {
                        withAnimation { attachedWidget = nil }
                        showChallengeCreator = true
                    },
                    onClear: attachedChallenge != nil ? { withAnimation { attachedChallenge = nil } } : nil
                )

                // Widget pill (clears challenge if selected)
                addOnPill(
                    icon: "square.grid.2x2.fill",
                    label: attachedWidget != nil ? attachedWidget!.type.label : "Widget",
                    isActive: attachedWidget != nil,
                    onTap: {
                        withAnimation { attachedChallenge = nil }
                        showWidgetPicker = true
                    },
                    onClear: attachedWidget != nil ? { withAnimation { attachedWidget = nil } } : nil
                )
            }
        }
    }

    private func addOnPill(icon: String, label: String, isActive: Bool, onTap: @escaping () -> Void, onClear: (() -> Void)?) -> some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                if let onClear = onClear {
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .foregroundColor(isActive ? .white : GQColors.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isActive ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(GQColors.surfaceBase))
            )
            .overlay(
                Capsule()
                    .stroke(isActive ? Color.clear : GQColors.borderDefault, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Options Card (compact)

    @ViewBuilder
    private var optionsCard: some View {
        VStack(spacing: 0) {
            actionRow(icon: "at", title: "Tag People", count: taggedUsernames.count) { showUserTagger = true }
            Divider().padding(.leading, 46)
            actionRow(icon: "location.fill", title: selectedLocation?.name ?? "Location", count: selectedLocation != nil ? 1 : 0) { showLocationPicker = true }
            Divider().padding(.leading, 46)
            actionRow(icon: "person.3.fill", title: "Squads", count: taggedSquads.count) { showSquadPicker = true }
            Divider().padding(.leading, 46)

            // Stats toggle
            HStack(spacing: 12) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.textTertiary)
                    .frame(width: 24)
                Text("Include Stats")
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.textPrimary)
                Spacer()

                // Custom toggle pill
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        includeStats.toggle()
                    }
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                } label: {
                    ZStack(alignment: includeStats ? .trailing : .leading) {
                        Capsule()
                            .fill(includeStats ? AnyShapeStyle(GQGradients.primary.opacity(0.2)) : AnyShapeStyle(GQColors.overlayMedium))
                            .frame(width: 44, height: 26)
                            .overlay(
                                Capsule()
                                    .stroke(includeStats ? AnyShapeStyle(GQGradients.primary.opacity(0.5)) : AnyShapeStyle(Color.clear), lineWidth: 1)
                            )
                        Circle()
                            .fill(includeStats ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(GQColors.textTertiary))
                            .frame(width: 22, height: 22)
                            .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                            .padding(.horizontal, 2)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(GQColors.surfaceBase)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(GQColors.borderDefault, lineWidth: 1)
        )
    }

    // MARK: - Carousel Item

    @ViewBuilder
    private func carouselItemView(item: PostMedia) -> some View {
        #if canImport(UIKit)
        if item.mediaType == .photo, let data = item.data, let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 300)
                .clipped()
        } else if item.mediaType == .video {
            // Show thumbnail with play icon
            ZStack {
                if let thumbData = item.thumbnailData, let thumb = UIImage(data: thumbData) {
                    Image(uiImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 300)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(GQColors.overlayMedium)
                        .frame(height: 300)
                }
                // Play icon
                Circle()
                    .fill(.black.opacity(0.4))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .offset(x: 2)
                    )
            }
        } else {
            Rectangle()
                .fill(GQColors.overlayMedium)
                .frame(height: 300)
        }
        #endif
    }

    // MARK: - Media Carousel

    @ViewBuilder
    private var mediaPreview: some View {
        #if canImport(UIKit)
        if !mediaItems.isEmpty {
            VStack(spacing: 6) {
                // Swipeable carousel
                TabView(selection: $currentMediaIndex) {
                    ForEach(Array(mediaItems.enumerated()), id: \.element.id) { idx, item in
                        ZStack {
                            carouselItemView(item: item)

                            // Overlay controls
                            VStack {
                                Spacer()
                                HStack {
                                    // Delete current
                                    if mediaItems.count > 1 {
                                        Button {
                                            withAnimation {
                                                mediaItems.remove(at: idx)
                                                if currentMediaIndex >= mediaItems.count {
                                                    currentMediaIndex = max(0, mediaItems.count - 1)
                                                }
                                            }
                                        } label: {
                                            Image(systemName: "trash.circle.fill")
                                                .font(.system(size: 26))
                                                .foregroundColor(.white)
                                                .shadow(radius: 4)
                                        }
                                        .padding(12)
                                    }

                                    Spacer()

                                    // Change / add more
                                    Button {
                                        navigationPath.removeLast()
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "plus")
                                                .font(.system(size: 12, weight: .semibold))
                                            Text("Add More")
                                                .font(.system(size: 12, weight: .semibold))
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Capsule().fill(.black.opacity(0.5)))
                                    }
                                    .padding(12)
                                }
                            }
                        }
                        .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 300)

                // Custom page dots
                if mediaItems.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(0..<mediaItems.count, id: \.self) { idx in
                            Circle()
                                .fill(idx == currentMediaIndex ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(GQColors.textTertiary.opacity(0.4)))
                                .frame(width: idx == currentMediaIndex ? 8 : 6, height: idx == currentMediaIndex ? 8 : 6)
                                .animation(.spring(response: 0.25), value: currentMediaIndex)
                        }
                    }
                    .padding(.top, 2)
                    .padding(.bottom, 4)
                }
            }
        }
        #endif
    }

    private func actionRow(icon: String, title: String, count: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.textTertiary)
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.textPrimary)
                Spacer()
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 18, height: 18)
                        .background(GQGradients.primary)
                        .clipShape(Circle())
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func loadMediaFromPhotosPicker(_ item: PhotosPickerItem?) {
        guard let item = item, mediaItems.count < Self.maxMediaItems else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                #if canImport(UIKit)
                if let uiImage = UIImage(data: data)?.fixedOrientation() {
                    let compressed = uiImage.jpegData(compressionQuality: 0.8) ?? data
                    let media = PostMedia(
                        exerciseName: nil,
                        exerciseIndex: nil,
                        mediaType: .photo,
                        data: compressed,
                        thumbnailData: compressed
                    )
                    await MainActor.run {
                        withAnimation { mediaItems.append(media) }
                    }
                    // Enhance in background
                    let vm = await cameraVM
                    let enhanced = vm.applySubtleEnhancement(to: compressed)
                    await MainActor.run {
                        if let idx = mediaItems.lastIndex(where: { $0.id == media.id }) {
                            mediaItems[idx] = PostMedia(exerciseName: nil, exerciseIndex: nil, mediaType: .photo, data: enhanced, thumbnailData: enhanced)
                        }
                    }
                } else {
                    // Video
                    let media = PostMedia(
                        exerciseName: nil,
                        exerciseIndex: nil,
                        mediaType: .video,
                        data: data,
                        thumbnailData: nil
                    )
                    await MainActor.run {
                        selectedMedia = media
                        mediaItems = [media]
                        navigationPath.append(PostEditorPhase.customize)
                    }
                }
                #endif
            }
        }
    }

    private func createPost() {
        let generalMedia = mediaItems.first

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

        // Attach widget if set
        if let widget = attachedWidget {
            post.postWidgetData = try? JSONEncoder().encode(widget)
        }

        modelContext.insert(post)
        do {
            try modelContext.save()
            FeedContentService.shared.syncPostToSupabase(post)
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
                    .foregroundStyle(isPreviewPlaying ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(GQColors.textSecondary))
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
                            color: GQColors.textSecondary
                        ) {
                            onRemoveLocation()
                        }
                    }

                    // Squads
                    ForEach(squads) { squad in
                        PostTagChip(
                            icon: "person.3.fill",
                            text: squad.name,
                            color: GQColors.textSecondary
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
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9))

            Text(text)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .bold))
            }
        }
        .foregroundColor(GQColors.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(GQColors.overlayMedium)
        .clipShape(Capsule())
    }
}

// MARK: - Playlist Link Section

struct PlaylistLinkSection: View {
    @Binding var spotifyURL: String
    @Binding var appleMusicURL: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 0) {
                // Spotify
                HStack(spacing: 10) {
                    Image(systemName: "music.note")
                        .font(.system(size: 14))
                        .foregroundColor(GQColors.textSecondary)
                        .frame(width: 20)

                    TextField("Spotify playlist URL", text: $spotifyURL)
                        .font(.system(size: 14))
                        .foregroundColor(GQColors.textPrimary)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Divider().padding(.leading, 44)

                // Apple Music
                HStack(spacing: 10) {
                    Image(systemName: "music.note")
                        .font(.system(size: 14))
                        .foregroundColor(GQColors.textSecondary)
                        .frame(width: 20)

                    TextField("Apple Music playlist URL", text: $appleMusicURL)
                        .font(.system(size: 14))
                        .foregroundColor(GQColors.textPrimary)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .homeSocialCard(cornerRadius: 14)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Camera View Model & Preview

#if canImport(UIKit)
import AVFoundation

@MainActor
final class CameraViewModel: ObservableObject {
    @Published var isRunning = false
    @Published var permissionDenied = false
    @Published var isRecording = false

    let session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var movieOutput = AVCaptureMovieFileOutput()
    private var currentDevice: AVCaptureDevice?
    private var usingFront = true

    private let delegateHandler = PhotoCaptureDelegate()
    private let videoDelegate = VideoCaptureDelegate()

    func start() {
        guard !isRunning else { return }
        Task {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            switch status {
            case .authorized:
                break
            case .notDetermined:
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                if !granted { permissionDenied = true; return }
            default:
                permissionDenied = true
                return
            }
            // Also request mic for video
            if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
                _ = await AVCaptureDevice.requestAccess(for: .audio)
            }
            Task.detached(priority: .userInitiated) { [weak self] in
                guard let self else { return }
                await self.configureSession()
                self.session.startRunning()
                await MainActor.run { self.isRunning = true }
            }
        }
    }

    func stop() {
        session.stopRunning()
        isRunning = false
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        session.inputs.forEach { session.removeInput($0) }

        let position: AVCaptureDevice.Position = usingFront ? .front : .back
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return
        }
        currentDevice = device

        if session.canAddInput(input) { session.addInput(input) }

        // Add mic input for video audio
        if let mic = AVCaptureDevice.default(for: .audio),
           let micInput = try? AVCaptureDeviceInput(device: mic),
           !session.inputs.contains(where: { ($0 as? AVCaptureDeviceInput)?.device.hasMediaType(.audio) == true }),
           session.canAddInput(micInput) {
            session.addInput(micInput)
        }

        if !session.outputs.contains(where: { $0 is AVCapturePhotoOutput }), session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        if !session.outputs.contains(where: { $0 is AVCaptureMovieFileOutput }), session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }
        session.commitConfiguration()
    }

    func flipCamera() {
        usingFront.toggle()
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            await self.configureSession()
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func capturePhoto(completion: @escaping (Data?) -> Void) {
        guard isRunning, session.isRunning else { return }
        delegateHandler.completion = completion
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: delegateHandler)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func startRecording() {
        guard isRunning, !movieOutput.isRecording else { return }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
        videoDelegate.completion = nil
        movieOutput.maxRecordedDuration = CMTime(seconds: 60, preferredTimescale: 600)
        movieOutput.startRecording(to: tempURL, recordingDelegate: videoDelegate)
        isRecording = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func stopRecording(completion: @escaping (URL?) -> Void) {
        guard movieOutput.isRecording else { completion(nil); return }
        videoDelegate.completion = completion
        movieOutput.stopRecording()
        isRecording = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Minimal post-capture enhancement: slight smoothing, warmth, and exposure lift.
    /// Designed to be subtle — evens out skin without looking filtered.
    nonisolated func applySubtleEnhancement(to data: Data) -> Data {
        guard let ciImage = CIImage(data: data) else { return data }
        let context = CIContext(options: [.useSoftwareRenderer: false])

        var output = ciImage

        // 1. Gentle skin smoothing via low-radius gaussian blur blended at low opacity
        if let blur = CIFilter(name: "CIGaussianBlur") {
            blur.setValue(output, forKey: kCIInputImageKey)
            blur.setValue(1.8, forKey: kCIInputRadiusKey)  // very subtle
            if let blurred = blur.outputImage,
               let blend = CIFilter(name: "CISourceAtopCompositing") {
                // Blend blurred at 25% over original — just enough to soften
                let opacity = CIFilter(name: "CIColorMatrix")!
                opacity.setValue(blurred, forKey: kCIInputImageKey)
                opacity.setValue(CIVector(x: 0, y: 0, z: 0, w: 0.25), forKey: "inputAVector")
                if let faded = opacity.outputImage {
                    blend.setValue(faded, forKey: kCIInputImageKey)
                    blend.setValue(output, forKey: kCIInputBackgroundImageKey)
                    if let result = blend.outputImage {
                        output = result
                    }
                }
            }
        }

        // 2. Slight warmth + vibrance via CITemperatureAndTint + CIVibrance
        if let temp = CIFilter(name: "CITemperatureAndTint") {
            temp.setValue(output, forKey: kCIInputImageKey)
            temp.setValue(CIVector(x: 6800, y: 0), forKey: "inputNeutral")  // slightly warm
            temp.setValue(CIVector(x: 6500, y: 0), forKey: "inputTargetNeutral")
            if let result = temp.outputImage { output = result }
        }

        // 3. Tiny exposure lift to brighten
        if let exposure = CIFilter(name: "CIExposureAdjust") {
            exposure.setValue(output, forKey: kCIInputImageKey)
            exposure.setValue(0.08, forKey: kCIInputEVKey)  // barely noticeable
            if let result = exposure.outputImage { output = result }
        }

        // Render back to JPEG
        let extent = ciImage.extent  // use original extent to crop blur edge artifacts
        if let cgImage = context.createCGImage(output, from: extent) {
            return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.85) ?? data
        }
        return data
    }
}

// Non-isolated delegate for photo capture callbacks
final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    var completion: ((Data?) -> Void)?

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let data = photo.fileDataRepresentation()
        DispatchQueue.main.async { [weak self] in
            self?.completion?(data)
        }
    }
}

// Non-isolated delegate for video capture callbacks
final class VideoCaptureDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
    var completion: ((URL?) -> Void)?

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        // Video is valid even with some errors (e.g. "stopped due to no data" is an error but file exists)
        let fileExists = FileManager.default.fileExists(atPath: outputFileURL.path)
        DispatchQueue.main.async { [weak self] in
            self?.completion?(fileExists ? outputFileURL : nil)
        }
    }
}

// MARK: - Shutter Button (tap = photo, hold = video)

struct ShutterButton: View {
    let isRecording: Bool
    let onTap: () -> Void
    let onHoldStart: () -> Void
    let onHoldEnd: () -> Void

    @State private var isPressed = false
    @State private var holdTimer: Timer?
    @State private var isHolding = false
    @State private var recordingProgress: CGFloat = 0
    @State private var progressTimer: Timer?

    private let maxDuration: CGFloat = 60 // seconds

    var body: some View {
        ZStack {
            // Outer ring — gradient when idle, red progress when recording
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 4)
                .frame(width: 80, height: 80)

            if isRecording {
                Circle()
                    .trim(from: 0, to: recordingProgress / maxDuration)
                    .stroke(GQColors.vividPurple, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
            } else {
                Circle()
                    .stroke(GQGradients.primary, lineWidth: 4)
                    .frame(width: 80, height: 80)
            }

            // Inner circle — shrinks to rounded square when recording
            RoundedRectangle(cornerRadius: isRecording ? 8 : 34)
                .fill(isRecording ? AnyShapeStyle(GQColors.vividPurple) : AnyShapeStyle(Color.white))
                .frame(width: isRecording ? 32 : 68, height: isRecording ? 32 : 68)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isRecording)
        }
        .overlay(
            Text(isRecording ? "" : "Hold for video")
                .font(.system(size: 11))
                .foregroundColor(GQColors.textTertiary)
                .offset(y: 52)
        )
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isPressed else { return }
                    isPressed = true
                    // Start a timer — if held > 0.3s, it's a video
                    holdTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                        DispatchQueue.main.async {
                            isHolding = true
                            onHoldStart()
                            startProgressTimer()
                        }
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    holdTimer?.invalidate()
                    holdTimer = nil

                    if isHolding {
                        // Was recording — stop
                        isHolding = false
                        stopProgressTimer()
                        onHoldEnd()
                    } else {
                        // Quick tap — take photo
                        onTap()
                    }
                }
        )
    }

    private func startProgressTimer() {
        recordingProgress = 0
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            DispatchQueue.main.async {
                recordingProgress += 0.1
                if recordingProgress >= maxDuration {
                    stopProgressTimer()
                    onHoldEnd()
                }
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
        recordingProgress = 0
    }
}

struct PostCameraPreviewView: UIViewRepresentable {
    @ObservedObject var cameraVM: CameraViewModel

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraVM.session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer

        cameraVM.start()
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.previewLayer?.frame = uiView.bounds
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

enum VideoThumbnailGenerator {
    static func generate(from videoData: Data) -> UIImage? {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
        try? videoData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        return generate(from: tempURL)
    }

    static func generate(from url: URL) -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 800, height: 800)
        let time = CMTime(seconds: 0.5, preferredTimescale: 600)
        if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
            return UIImage(cgImage: cgImage)
        }
        // Fallback to first frame
        if let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }
}

extension UIImage {
    func fixedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()
        return normalized
    }
}
#endif

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
                .background(GQColors.overlayLight)
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
                        .fontWeight(.semibold)
                        .foregroundStyle(taggedUsernames.isEmpty ? AnyShapeStyle(GQColors.textSecondary) : AnyShapeStyle(GQGradients.primary))
                }
            }
        }
        .tint(GQColors.textPrimary)
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
                    .fill(GQGradients.primary.opacity(0.8))
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
                    .foregroundStyle(isSelected ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(GQColors.textTertiary))
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
                .background(GQColors.overlayLight)
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
                                        .foregroundStyle(GQGradients.primary)
                                    Text("Use \"\(searchText)\"")
                                        .foregroundColor(GQColors.textPrimary)
                                }
                            }
                            .listRowBackground(GQColors.overlayLight)
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
        .tint(GQColors.textPrimary)
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
                    .foregroundStyle(GQGradients.primary)
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
                        .foregroundStyle(GQGradients.primary)
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
                            .foregroundStyle(GQGradients.primary.opacity(0.5))

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
        .tint(GQColors.textPrimary)
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
                            .foregroundStyle(GQGradients.primary)
                        Text("\(squad.streakWeeks)w")
                            .foregroundColor(GQColors.textSecondary)
                    }
                    .font(.system(size: 11, weight: .semibold))
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(GQColors.textTertiary))
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
                    .tint(GQColors.textPrimary)

                    Stepper("Target: \(goalTarget)", value: $goalTarget, in: 1...1000)
                        .tint(GQColors.vividPurple)

                    DatePicker("End Date", selection: $endDate, in: minDate..., displayedComponents: .date)
                        .tint(GQColors.vividPurple)
                }
                .listRowBackground(GQColors.surfaceBase)

                if let challenge = attachedChallenge {
                    Section {
                        Button {
                            attachedChallenge = nil
                            dismiss()
                        } label: {
                            Label("Remove Challenge", systemImage: "trash")
                                .foregroundColor(GQColors.vividPurple)
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
                    .foregroundStyle(title.trimmingCharacters(in: .whitespaces).isEmpty ? AnyShapeStyle(GQColors.textTertiary) : AnyShapeStyle(GQGradients.primary))
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
        .tint(GQColors.textPrimary)
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

// MARK: - Post Widget Picker Sheet

struct PostWidgetPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Binding var attachedWidget: PostWidget?
    let profile: UserProfile
    let workout: Workout?
    let exercises: [CompletedExercise]
    let duration: Int

    @Query(sort: \UserGoal.createdAt, order: .reverse) private var goals: [UserGoal]
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var measurements: [BodyMeasurement]
    @Query(sort: \MealLog.dateTime, order: .reverse) private var meals: [MealLog]
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    Text("Attach a data card to your post")
                        .font(.system(size: 14))
                        .foregroundColor(GQColors.textSecondary)
                        .padding(.top, 8)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(PostWidgetType.allCases, id: \.self) { type in
                            widgetOption(type)
                        }
                    }
                    .padding(.horizontal, 16)

                    if let widget = attachedWidget {
                        VStack(spacing: 8) {
                            Text("PREVIEW")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(GQColors.textTertiary)
                                .tracking(0.5)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            PostWidgetCard(widget: widget)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                }
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)
            .gqPageBackground()
            .navigationTitle("Add Widget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        attachedWidget = nil
                        dismiss()
                    }
                    .foregroundColor(GQColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(attachedWidget != nil ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(GQColors.textTertiary))
                        .disabled(attachedWidget == nil)
                }
            }
        }
        .tint(GQColors.textPrimary)
    }

    private func widgetOption(_ type: PostWidgetType) -> some View {
        let isSelected = attachedWidget?.type == type
        let preview = buildWidget(for: type)

        return Button {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            withAnimation(.spring(response: 0.25)) {
                attachedWidget = preview
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Live preview of the widget
                PostWidgetInlineBubble(widget: preview)
                    .scaleEffect(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 8)
            .background(GQColors.surfaceBase)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(GQColors.borderDefault), lineWidth: isSelected ? 1.5 : 0.5)
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(GQGradients.primary)
                        .padding(6)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Build Widget from Real User Data

    private func buildWidget(for type: PostWidgetType) -> PostWidget {
        switch type {
        case .goal:
            return buildGoalWidget()
        case .pr:
            return buildPRWidget()
        case .macros:
            return buildMacrosWidget()
        case .body:
            return buildBodyWidget()
        case .streak:
            return buildStreakWidget()
        case .cardio:
            return buildCardioWidget()
        }
    }

    private func buildGoalWidget() -> PostWidget {
        let myGoals = goals.filter { $0.userId == profile.id }
        if let goal = myGoals.first {
            let current = goal.isExerciseGoal ? (myGoals.first?.targetWeight ?? 0) * 0.85 : 0
            return PostWidget(type: .goal, goalExercise: goal.exerciseName ?? "Body Weight", goalTarget: goal.targetWeight, goalCurrent: current, goalUnit: "lbs")
        }
        // Fallback: generate from workout data
        let highlight = exercises.first?.name ?? workout?.type.rawValue ?? "Bench Press"
        return PostWidget(type: .goal, goalExercise: highlight, goalTarget: 225, goalCurrent: 185, goalUnit: "lbs")
    }

    private func buildPRWidget() -> PostWidget {
        let name = exercises.first?.name ?? "Squat"
        return PostWidget(type: .pr, prExercise: name, prValue: "New PR!", prType: "Weight PR")
    }

    private func buildMacrosWidget() -> PostWidget {
        let today = Calendar.current.startOfDay(for: Date())
        let todayMeals = meals.filter { $0.odId == profile.id && $0.dateTime >= today }
        let totalCal = todayMeals.compactMap(\.estimatedCalories).reduce(0, +)
        let totalP = todayMeals.compactMap(\.estimatedProtein).reduce(0, +)
        let totalC = todayMeals.compactMap(\.estimatedCarbs).reduce(0, +)
        let totalF = todayMeals.compactMap(\.estimatedFat).reduce(0, +)
        if totalCal > 0 {
            return PostWidget(type: .macros, calories: totalCal, protein: totalP, carbs: totalC, fat: totalF)
        }
        return PostWidget(type: .macros, calories: 2100, protein: 165, carbs: 230, fat: 68)
    }

    private func buildBodyWidget() -> PostWidget {
        let myWeights = measurements.filter { $0.userId == profile.id && $0.type == .weight }
            .sorted { $0.date > $1.date }
        if let latest = myWeights.first {
            let history = Array(myWeights.prefix(14).reversed().map(\.value))
            let change = myWeights.count >= 2 ? latest.value - myWeights.last!.value : 0
            return PostWidget(type: .body, bodyWeight: latest.value, bodyChange: change, bodyHistory: history)
        }
        return PostWidget(type: .body, bodyWeight: 178.0, bodyChange: -3.0, bodyHistory: [181, 180, 179.5, 179, 178.5, 178])
    }

    private func buildStreakWidget() -> PostWidget {
        let myWorkouts = workouts
            .sorted { $0.date > $1.date }
        var streak = 0
        var checkDate = Calendar.current.startOfDay(for: Date())
        for w in myWorkouts {
            let wDay = Calendar.current.startOfDay(for: w.date)
            if wDay == checkDate || wDay == Calendar.current.date(byAdding: .day, value: -1, to: checkDate) {
                streak += 1
                checkDate = wDay
            } else {
                break
            }
        }
        return PostWidget(type: .streak, streakDays: max(streak, 1), milestoneLabel: streak >= 7 ? "Day Streak 🔥" : "Day Streak")
    }

    private func buildCardioWidget() -> PostWidget {
        let dist = Double(duration) / 6.0
        let paceMin = duration > 0 && dist > 0 ? Double(duration) / dist : 5.0
        let pace = "\(Int(paceMin)):\(String(format: "%02d", Int(paceMin.truncatingRemainder(dividingBy: 1) * 60)))"
        return PostWidget(type: .cardio, distance: dist, pace: pace, elevation: 0)
    }
}
