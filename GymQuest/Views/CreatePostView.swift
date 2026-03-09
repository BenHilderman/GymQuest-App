//
//  CreatePostView.swift
//  GymQuest
//
//  Created by Benjamin Hilderman
//
//  Where you make a new post. Pick a photo or video from your camera roll,
//  write something, and optionally attach your workout stats.
//  Uses PhotosPicker which is way cleaner than the old UIImagePicker stuff.
//

import SwiftUI
import SwiftData
import PhotosUI
import AVKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Post Content Type

enum PostContentType: String, CaseIterable {
    case workout = "Workout"
    case meal = "Meal"
    case general = "General"

    var icon: String {
        switch self {
        case .workout: return "dumbbell.fill"
        case .meal: return "fork.knife"
        case .general: return "text.bubble.fill"
        }
    }
}

struct CreatePostView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let profile: UserProfile
    var workout: Workout?

    @State private var caption: String = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var videoData: Data?
    @State private var mediaType: MediaType = .none
    #if canImport(UIKit)
    @State private var photoImage: UIImage?
    #elseif canImport(AppKit)
    @State private var photoImage: NSImage?
    #endif

    @State private var includeStats = true

    // Content type selection
    @State private var selectedContentType: PostContentType = .workout
    @State private var selectedEmotion: WorkoutEmotion? = nil

    // Meal-specific state
    @State private var selectedMealType: MealType = .lunch
    @State private var selectedMealTags: Set<String> = []
    @State private var mealFeeling: MealFeeling = .good

    // Music state
    @State private var selectedSong: Song?
    @State private var showMusicPicker = false
    @StateObject private var musicService = MusicService.shared

    // Activity detection
    @State private var detectedActivity: DetectedActivity?

    // Error handling
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""
    @State private var showPostedOverlay = false

    private let quickTags = ["Protein", "Vegetables", "Carbs", "Healthy Fats", "Fiber", "Fruit", "Dairy", "Whole Grains"]

    enum MediaType {
        case none, photo, video
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Content type selector tabs
                    ContentTypeSelector(selectedType: $selectedContentType)

                    // media picker
                    MediaPicker(
                        photoImage: $photoImage,
                        selectedItem: $selectedItem,
                        photoData: $photoData,
                        videoData: $videoData,
                        mediaType: $mediaType
                    )

                    // caption
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Caption")
                            .font(.caption)
                            .foregroundColor(GQColors.textTertiary)

                        TextEditor(text: $caption)
                            .frame(minHeight: 80)
                            .padding(12)
                            .background(Color.black.opacity(0.03))
                            .cornerRadius(12)
                            .scrollContentBackground(.hidden)
                    }

                    // Emotion picker (workout posts only)
                    if selectedContentType == .workout {
                        WorkoutEmotionPicker(selectedEmotion: $selectedEmotion, compact: true)
                    }

                    // Workout-specific options
                    if selectedContentType == .workout, let workout = workout {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(isOn: $includeStats) {
                                Text("Include workout stats")
                                    .font(.subheadline)
                            }
                            .tint(.white)

                            if includeStats {
                                HStack(spacing: 20) {
                                    VStack {
                                        Text(workout.type.rawValue)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        Text("Type")
                                            .font(.caption2)
                                            .foregroundColor(GQColors.textTertiary)
                                    }
                                    VStack {
                                        Text("\(workout.duration)")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        Text("Min")
                                            .font(.caption2)
                                            .foregroundColor(GQColors.textTertiary)
                                    }
                                    VStack {
                                        Text("\(workout.totalSets)")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        Text("Sets")
                                            .font(.caption2)
                                            .foregroundColor(GQColors.textTertiary)
                                    }
                                }
                                .padding()
                                .background(Color.black.opacity(0.02))
                                .cornerRadius(12)
                            }
                        }
                    }

                    // Meal-specific options
                    if selectedContentType == .meal {
                        MealPostOptions(
                            selectedMealType: $selectedMealType,
                            selectedTags: $selectedMealTags,
                            feeling: $mealFeeling,
                            quickTags: quickTags
                        )
                    }

                    // Music selector
                    MusicSelectorSection(
                        selectedSong: $selectedSong,
                        showMusicPicker: $showMusicPicker,
                        activityType: detectedActivity?.rawValue
                    )

                    // Detected activity (if applicable)
                    if let activity = detectedActivity {
                        HStack {
                            Text("Detected Activity:")
                                .font(.system(size: 12))
                                .foregroundColor(GQColors.textTertiary)

                            ActivityBadge(activityType: activity)

                            Spacer()

                            Button {
                                detectedActivity = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(GQColors.textTertiary)
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(GQColors.surfaceOverlay.opacity(0.78))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(GQGradients.glassBorder, lineWidth: 0.8)
                        )
                    }
                }
                .padding()
            }
            .gqPageBackground()
            .navigationTitle("New Post")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") { createPost() }
                        .fontWeight(.semibold)
                        .disabled(photoData == nil && videoData == nil)
                }
            }
            .onChange(of: selectedItem) { _, newValue in
                loadMedia(from: newValue)
            }
            .onChange(of: photoData) { _, newData in
                // Detect activity from image
                if let data = newData {
                    Task {
                        detectedActivity = await ActivityDetectionService.shared.detectActivity(imageData: data, caption: caption)
                    }
                }
            }
            .onChange(of: caption) { _, newCaption in
                // Detect activity from caption text
                if detectedActivity == nil {
                    detectedActivity = ActivityDetectionService.shared.detectActivityFromText(newCaption)
                }
            }
            .onAppear {
                // Set default content type based on context
                if workout != nil {
                    selectedContentType = .workout
                }
                // Generate AI music suggestions
                musicService.generateAISuggestions(for: workout?.type.rawValue)
            }
            .sheet(isPresented: $showMusicPicker) {
                MusicPickerSheet(
                    selectedSong: $selectedSong,
                    activityType: detectedActivity?.rawValue ?? workout?.type.rawValue
                )
            }
            .alert("Save Failed", isPresented: $showSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveErrorMessage)
            }
            .overlay {
                if showPostedOverlay {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(GQColors.success)
                        Text("Posted!")
                            .font(.headline)
                            .foregroundColor(GQColors.textPrimary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: showPostedOverlay)
                }
            }
        }
    }

    private func loadMedia(from item: PhotosPickerItem?) {
        guard let item = item else { return }

        // try loading as image first
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                #if canImport(UIKit)
                if UIImage(data: data) != nil {
                    photoData = data
                    videoData = nil
                    photoImage = UIImage(data: data)
                    mediaType = .photo
                    return
                }
                #elseif canImport(AppKit)
                if NSImage(data: data) != nil {
                    photoData = data
                    videoData = nil
                    photoImage = NSImage(data: data)
                    mediaType = .photo
                    return
                }
                #endif

                // assume video if not an image
                videoData = data
                photoData = nil
                photoImage = nil
                mediaType = .video
            }
        }
    }

    private func createPost() {
        var postCaption = caption

        // For meal posts, append meal info to caption if relevant
        if selectedContentType == .meal && !selectedMealTags.isEmpty {
            let tagsString = selectedMealTags.joined(separator: ", ")
            if !postCaption.isEmpty {
                postCaption += "\n"
            }
            postCaption += "\(selectedMealType.rawValue) \(mealFeeling.emoji) • \(tagsString)"
        }

        let post = Post(
            authorId: profile.id,
            authorName: profile.name,
            authorUsername: profile.username,
            caption: postCaption,
            photoData: photoData,
            videoData: videoData,
            workoutType: selectedContentType == .workout && includeStats ? workout?.type.rawValue : nil,
            duration: selectedContentType == .workout && includeStats ? workout?.duration : nil,
            setCount: selectedContentType == .workout && includeStats ? workout?.totalSets : nil,
            exerciseHighlight: nil,
            songTitle: selectedSong?.title,
            artistName: selectedSong?.artist,
            songPreviewURL: selectedSong?.previewURL,
            musicSource: selectedSong?.source.rawValue,
            playlistId: selectedSong?.playlistId,
            detectedActivity: detectedActivity?.rawValue,
            taggedUsernames: [],
            workoutEmotion: selectedContentType == .workout ? selectedEmotion?.rawValue : nil
        )

        // Add song to recents if selected
        if let song = selectedSong {
            musicService.addToRecent(song)
        }

        modelContext.insert(post)
        do {
            try modelContext.save()
            HapticManager.shared.success()
            showPostedOverlay = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                dismiss()
            }
        } catch {
            saveErrorMessage = "Failed to save post. Please try again."
            showSaveError = true
        }
    }
}

// MARK: - Music Selector Section

struct MusicSelectorSection: View {
    @Binding var selectedSong: Song?
    @Binding var showMusicPicker: Bool
    let activityType: String?

    @StateObject private var musicService = MusicService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "music.note")
                    .foregroundStyle(GQGradients.primary)
                Text("ADD MUSIC")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(0.5)

                Spacer()

                if selectedSong != nil {
                    Button {
                        selectedSong = nil
                    } label: {
                        Text("Remove")
                            .font(.system(size: 12))
                            .foregroundColor(GQColors.error)
                    }
                }
            }

            if let song = selectedSong {
                // Selected song display
                SelectedSongRow(song: song) {
                    showMusicPicker = true
                }
            } else {
                // Quick suggestions
                VStack(spacing: 10) {
                    // AI suggested songs
                    if !musicService.suggestedSongs.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(musicService.suggestedSongs.prefix(4)) { song in
                                    QuickSongChip(song: song) {
                                        selectedSong = song
                                    }
                                }
                            }
                        }
                    }

                    // Browse button
                    Button {
                        showMusicPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("Browse Music")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(GQColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(GQColors.elevatedSurface)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(GQColors.neonPurple.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(GQInteractiveStyle())
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(GQColors.surfaceOverlay.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(GQGradients.glassBorder, lineWidth: 0.85)
        )
        .onAppear {
            if let activity = activityType {
                musicService.generateAISuggestions(for: activity)
            }
        }
    }
}

struct SelectedSongRow: View {
    let song: Song
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Album art placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [song.source.color, song.source.color.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: "music.note")
                        .font(.title3)
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)

                    Text(song.artist)
                        .font(.system(size: 12))
                        .foregroundColor(GQColors.textSecondary)
                }

                Spacer()

                // Source badge
                HStack(spacing: 4) {
                    Image(systemName: song.source.icon)
                        .font(.system(size: 10))
                    Text(song.source.rawValue)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(song.source.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(song.source.color.opacity(0.15))
                .cornerRadius(6)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textTertiary)
            }
            .padding(12)
            .background(GQColors.elevatedSurface)
            .cornerRadius(10)
        }
        .buttonStyle(GQInteractiveStyle())
    }
}

struct QuickSongChip: View {
    let song: Song
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                Image(systemName: "music.note")
                    .font(.system(size: 10))
                    .foregroundStyle(GQGradients.primary)

                VStack(alignment: .leading, spacing: 0) {
                    Text(song.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                        .lineLimit(1)

                    Text(song.artist)
                        .font(.system(size: 9))
                        .foregroundColor(GQColors.textTertiary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(GQColors.elevatedSurface)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(GQColors.neonPurple.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(GQInteractiveStyle())
    }
}

// MARK: - Music Picker Sheet

struct MusicPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSong: Song?
    let activityType: String?

    @StateObject private var musicService = MusicService.shared
    @State private var searchQuery = ""
    @State private var searchResults: [Song] = []
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(GQColors.textTertiary)

                    TextField("Search songs...", text: $searchQuery)
                        .foregroundColor(GQColors.textPrimary)

                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                            searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(GQColors.textTertiary)
                        }
                    }
                }
                .padding(12)
                .background(GQColors.elevatedSurface)
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // Tabs
                HStack(spacing: 0) {
                    MusicTabButton(title: "Suggested", isSelected: selectedTab == 0) {
                        selectedTab = 0
                    }
                    MusicTabButton(title: "Recent", isSelected: selectedTab == 1) {
                        selectedTab = 1
                    }
                    MusicTabButton(title: "Services", isSelected: selectedTab == 2) {
                        selectedTab = 2
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // Content
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if !searchQuery.isEmpty && !searchResults.isEmpty {
                            // Search results
                            ForEach(searchResults) { song in
                                SongRow(song: song, isSelected: selectedSong?.id == song.id) {
                                    selectedSong = song
                                    dismiss()
                                }
                            }
                        } else {
                            switch selectedTab {
                            case 0:
                                // AI Suggested
                                ForEach(musicService.suggestedSongs) { song in
                                    SongRow(song: song, isSelected: selectedSong?.id == song.id) {
                                        selectedSong = song
                                        dismiss()
                                    }
                                }

                                if musicService.suggestedSongs.isEmpty {
                                    EmptyStateView(
                                        icon: "sparkles",
                                        title: "AI Suggestions",
                                        message: "Songs will be suggested based on your activity"
                                    )
                                }

                            case 1:
                                // Recent
                                ForEach(musicService.recentSongs) { song in
                                    SongRow(song: song, isSelected: selectedSong?.id == song.id) {
                                        selectedSong = song
                                        dismiss()
                                    }
                                }

                                if musicService.recentSongs.isEmpty {
                                    EmptyStateView(
                                        icon: "clock",
                                        title: "No Recent Songs",
                                        message: "Songs you use will appear here"
                                    )
                                }

                            case 2:
                                // Services
                                ServiceConnectionCard(
                                    service: .spotify,
                                    isConnected: musicService.isSpotifyConnected
                                ) {
                                    musicService.connectSpotify()
                                }

                                ServiceConnectionCard(
                                    service: .appleMusic,
                                    isConnected: musicService.isAppleMusicConnected
                                ) {
                                    Task {
                                        await musicService.connectAppleMusic()
                                    }
                                }

                            default:
                                EmptyView()
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .gqPageBackground()
            .navigationTitle("Add Music")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: searchQuery) { _, query in
                Task {
                    searchResults = await musicService.searchSongs(query: query)
                }
            }
            .onAppear {
                if let activity = activityType {
                    musicService.generateAISuggestions(for: activity)
                }
            }
        }
    }
}

struct MusicTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? GQColors.textPrimary : GQColors.textTertiary)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(
                    VStack {
                        Spacer()
                        if isSelected {
                            Rectangle()
                                .fill(GQGradients.primary)
                                .frame(height: 2)
                        }
                    }
                )
        }
        .buttonStyle(GQInteractiveStyle())
    }
}

struct SongRow: View {
    let song: Song
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Album art
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [song.source.color.opacity(0.8), song.source.color.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)

                    Image(systemName: "music.note")
                        .font(.title2)
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(song.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)

                    Text(song.artist)
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(GQGradients.primary)
                } else {
                    Image(systemName: "plus.circle")
                        .font(.title2)
                        .foregroundColor(GQColors.textTertiary)
                }
            }
            .padding(12)
            .background(isSelected ? GQColors.elevatedSurface : GQColors.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? GQColors.neonPurple.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(GQInteractiveStyle())
    }
}

struct ServiceConnectionCard: View {
    let service: MusicSource
    let isConnected: Bool
    let onConnect: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(service.color.opacity(0.2))
                    .frame(width: 48, height: 48)

                Image(systemName: service.icon)
                    .font(.title2)
                    .foregroundColor(service.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(service.rawValue)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)

                Text(isConnected ? "Connected" : "Tap to connect")
                    .font(.system(size: 13))
                    .foregroundColor(isConnected ? GQColors.success : GQColors.textSecondary)
            }

            Spacer()

            if isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(GQColors.success)
            } else {
                Button(action: onConnect) {
                    Text("Connect")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(service.color)
                        .cornerRadius(8)
                }
                .buttonStyle(GQInteractiveStyle())
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(GQColors.surfaceOverlay.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(GQGradients.glassBorder, lineWidth: 0.85)
        )
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(GQGradients.primary)

            Text(title)
                .font(.headline)
                .foregroundColor(GQColors.textPrimary)

            Text(message)
                .font(.subheadline)
                .foregroundColor(GQColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}

// MARK: - Content Type Selector

struct ContentTypeSelector: View {
    @Binding var selectedType: PostContentType
    @Namespace private var tabNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PostContentType.allCases, id: \.self) { type in
                Button {
                    HapticManager.shared.select()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedType = type
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: type.icon)
                            .font(.system(size: 12))

                        Text(type.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(selectedType == type ? .white : GQColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background {
                        if selectedType == type {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(GQColors.textPrimary)
                                .matchedGeometryEffect(id: "contentTab", in: tabNamespace)
                        }
                    }
                }
                .buttonStyle(GQInteractiveStyle())
            }
        }
        .background(Color.black.opacity(0.06))
        .cornerRadius(10)
    }
}

// MARK: - Meal Post Options

struct MealPostOptions: View {
    @Binding var selectedMealType: MealType
    @Binding var selectedTags: Set<String>
    @Binding var feeling: MealFeeling

    let quickTags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Meal type picker
            VStack(alignment: .leading, spacing: 8) {
                Text("MEAL TYPE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(0.5)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MealType.allCases, id: \.self) { type in
                            MealTypeButton(
                                type: type,
                                isSelected: selectedMealType == type
                            ) {
                                selectedMealType = type
                            }
                        }
                    }
                }
            }

            // Quick tags
            VStack(alignment: .leading, spacing: 8) {
                Text("QUICK TAGS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(0.5)

                FlowLayoutSimple(spacing: 8) {
                    ForEach(quickTags, id: \.self) { tag in
                        QuickTagButton(
                            tag: tag,
                            isSelected: selectedTags.contains(tag)
                        ) {
                            if selectedTags.contains(tag) {
                                selectedTags.remove(tag)
                            } else {
                                selectedTags.insert(tag)
                            }
                        }
                    }
                }
            }

            // Feeling selector
            VStack(alignment: .leading, spacing: 8) {
                Text("HOW DID IT FEEL?")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(0.5)

                HStack(spacing: 8) {
                    ForEach(MealFeeling.allCases, id: \.self) { feel in
                        MealFeelingButton(
                            feeling: feel,
                            isSelected: feeling == feel
                        ) {
                            feeling = feel
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.02))
        .cornerRadius(12)
    }
}

struct MealTypeButton: View {
    let type: MealType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: type.icon)
                    .font(.system(size: 11))
                Text(type.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? .white : GQColors.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? GQColors.textPrimary : Color.black.opacity(0.06))
            .cornerRadius(16)
        }
        .buttonStyle(GQInteractiveStyle())
    }
}

struct QuickTagButton: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.tap()
            action()
        } label: {
            Text(tag)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .gray)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? GQColors.cyanSpark.opacity(0.4) : Color.black.opacity(0.05))
                .cornerRadius(14)
                .scaleEffect(isSelected ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(isSelected ? GQColors.cyanSpark : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(GQInteractiveStyle())
    }
}

struct MealFeelingButton: View {
    let feeling: MealFeeling
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.select()
            action()
        } label: {
            VStack(spacing: 4) {
                Text(feeling.emoji)
                    .font(.system(size: 20))
                    .scaleEffect(isSelected ? 1.3 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.4), value: isSelected)
                Text(feeling.rawValue)
                    .font(.system(size: 9))
                    .foregroundColor(isSelected ? .white : .gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? feeling.color.opacity(0.3) : Color.black.opacity(0.03))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? feeling.color : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(GQInteractiveStyle())
    }
}

// Simple flow layout for tags
struct FlowLayoutSimple: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = calculateLayout(in: proposal.width ?? 0, subviews: subviews)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = calculateLayout(in: bounds.width, subviews: subviews)

        for (index, subview) in subviews.enumerated() {
            let point = result.positions[index]
            subview.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func calculateLayout(in maxWidth: CGFloat, subviews: Subviews) -> (positions: [CGPoint], height: CGFloat) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (positions, y + rowHeight)
    }
}

struct MediaPicker: View {
    #if canImport(UIKit)
    @Binding var photoImage: UIImage?
    #elseif canImport(AppKit)
    @Binding var photoImage: NSImage?
    #endif
    @Binding var selectedItem: PhotosPickerItem?
    @Binding var photoData: Data?
    @Binding var videoData: Data?
    @Binding var mediaType: CreatePostView.MediaType

    @State private var showCamera = false

    var body: some View {
        VStack(spacing: 12) {
            if mediaType == .photo, let image = photoImage {
                ZStack(alignment: .topTrailing) {
                    #if canImport(UIKit)
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 250)
                        .clipped()
                        .cornerRadius(12)
                    #elseif canImport(AppKit)
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 250)
                        .clipped()
                        .cornerRadius(12)
                    #endif

                    Button {
                        clearMedia()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    }
                    .padding(8)
                }
            } else if mediaType == .video {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        Color.black
                        VStack(spacing: 8) {
                            Image(systemName: "video.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                            Text("Video selected")
                                .font(.caption)
                                .foregroundColor(GQColors.textTertiary)
                        }
                    }
                    .frame(height: 250)
                    .cornerRadius(12)

                    Button {
                        clearMedia()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    }
                    .padding(8)
                }
            } else {
                // No media - show camera and library options
                VStack(spacing: 16) {
                    HStack(spacing: 20) {
                        // Camera button
                        #if canImport(UIKit)
                        Button {
                            showCamera = true
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(GQGradients.primary)
                                        .frame(width: 60, height: 60)
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                }
                                Text("Camera")
                                    .font(.caption)
                                    .foregroundColor(GQColors.textPrimary)
                            }
                        }
                        .buttonStyle(GQInteractiveStyle())
                        #endif

                        // Photo library button
                        PhotosPicker(selection: $selectedItem, matching: .any(of: [.images, .videos])) {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(Color.black.opacity(0.06))
                                        .frame(width: 60, height: 60)
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.system(size: 24))
                                        .foregroundColor(GQColors.textPrimary)
                                }
                                Text("Library")
                                    .font(.caption)
                                    .foregroundColor(GQColors.textPrimary)
                            }
                        }
                    }

                    Text("A photo or video is required to post")
                        .font(.caption)
                        .foregroundColor(GQColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .background(Color.black.opacity(0.02))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.black.opacity(0.06), style: StrokeStyle(lineWidth: 1, dash: [6]))
                )
            }
        }
        #if canImport(UIKit)
        .fullScreenCover(isPresented: $showCamera) {
            InAppCameraView { data, isVideo in
                if isVideo {
                    videoData = data
                    mediaType = .video
                } else {
                    photoData = data
                    if let image = UIImage(data: data) {
                        photoImage = image
                    }
                    mediaType = .photo
                }
            }
        }
        #endif
    }

    private func clearMedia() {
        photoImage = nil
        photoData = nil
        videoData = nil
        selectedItem = nil
        mediaType = .none
    }
}

#Preview {
    CreatePostView(profile: UserProfile())
}
