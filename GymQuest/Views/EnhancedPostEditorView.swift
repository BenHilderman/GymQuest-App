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

    // Sheet state
    @State private var showMediaPicker = false
    @State private var showUserTagger = false
    @State private var showLocationPicker = false
    @State private var showSquadPicker = false
    @State private var showMusicPicker = false
    @State private var selectedExerciseForMedia: String? = nil  // nil = general media

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

                    // Exercise media gallery
                    ExerciseMediaGalleryView(
                        exercises: exercises,
                        mediaItems: $mediaItems,
                        onAddMedia: { exerciseName in
                            selectedExerciseForMedia = exerciseName
                            showMediaPicker = true
                        }
                    )

                    // Tagging section
                    VStack(spacing: 16) {
                        // Tag people
                        TaggingButton(
                            icon: "at",
                            title: "Tag People",
                            selectedCount: taggedUsernames.count,
                            color: GQColors.cyanSpark
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
                            color: GQColors.vividPurple
                        ) {
                            showSquadPicker = true
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

                    // Playlist URLs
                    PlaylistLinkSection(
                        spotifyURL: $spotifyPlaylistURL,
                        appleMusicURL: $appleMusicPlaylistURL
                    )

                    // Include stats toggle
                    Toggle(isOn: $includeStats) {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(GQColors.cyanSpark)
                            Text("Include workout stats")
                                .font(.subheadline)
                        }
                    }
                    .tint(GQColors.cyanSpark)
                    .padding(.horizontal)

                    Spacer(minLength: 100)
                }
                .padding(.top, 16)
            }
            .scrollContentBackground(.hidden)
            .background(GQColors.background.ignoresSafeArea())
            .navigationTitle("Customize Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") { createPost() }
                        .fontWeight(.semibold)
                        .foregroundColor(GQColors.cyanSpark)
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
            locationId: selectedLocation?.communityId,
            taggedSquadIds: taggedSquads.map { $0.id },
            taggedSquadNames: taggedSquads.map { $0.name },
            spotifyPlaylistURL: spotifyPlaylistURL.isEmpty ? nil : spotifyPlaylistURL,
            appleMusicPlaylistURL: appleMusicPlaylistURL.isEmpty ? nil : appleMusicPlaylistURL
        )

        if let song = selectedSong {
            musicService.addToRecent(song)
        }

        modelContext.insert(post)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save post. Please try again."
            showError = true
        }
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
                    .foregroundColor(.white)

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
                .fill(Color.white.opacity(0.05))
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
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                .scrollContentBackground(.hidden)
                .foregroundColor(.white)
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
                .foregroundColor(.white)
                .lineLimit(1)

            Text(subtitle)
                .font(.system(size: 11))
                .foregroundColor(GQColors.textTertiary)

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
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
                                        colors: [GQColors.vividPurple, GQColors.cyanSpark],
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
                                .background(GQColors.vividPurple)
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
                    .foregroundColor(.white)

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
                    .fill(Color.white.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
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
                            color: GQColors.cyanSpark
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
                            color: GQColors.vividPurple
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
                    .foregroundColor(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)

            // Apple Music
            HStack(spacing: 10) {
                Image(systemName: "music.note")
                    .foregroundColor(Color(hex: "FC3C44"))
                    .frame(width: 20)

                TextField("Apple Music playlist URL", text: $appleMusicURL)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
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
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(GQGradients.primary)
                    .cornerRadius(14)
                }
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
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(14)
                }
                .padding(.horizontal)

                Spacer()
            }
            .background(Color(white: 0.08).ignoresSafeArea())
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
                .foregroundColor(.white)
            Button("Close") { dismiss() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

// MARK: - Location Suggestion Model

struct LocationSuggestion: Identifiable {
    let id: UUID
    let name: String
    let type: LocationType
    let communityId: UUID?

    enum LocationType {
        case community
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
                        .foregroundColor(.white)
                }
                .padding(12)
                .background(Color.white.opacity(0.05))
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
            .background(GQColors.background.ignoresSafeArea())
            .navigationTitle("Tag People")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(GQColors.cyanSpark)
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
                    .fill(GQColors.vividPurple.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(friend.odName.prefix(1)).uppercased())
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.odName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)

                    Text("@\(friend.odUsername)")
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textSecondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? GQColors.cyanSpark : GQColors.textTertiary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Location Tagging View

struct LocationTaggingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var communities: [Community]

    @Binding var selectedLocation: LocationSuggestion?
    let userId: UUID

    @State private var searchText: String = ""
    @State private var customLocation: String = ""

    var userCommunities: [Community] {
        communities.filter { $0.memberIds.contains(userId) }
    }

    var otherCommunities: [Community] {
        if searchText.isEmpty { return [] }
        return communities.filter {
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
                        .foregroundColor(.white)
                }
                .padding(12)
                .background(Color.white.opacity(0.05))
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
                                    communityId: nil
                                )
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundColor(GQColors.success)
                                    Text("Use \"\(searchText)\"")
                                        .foregroundColor(.white)
                                }
                            }
                            .listRowBackground(Color.white.opacity(0.05))
                        } header: {
                            Text("Custom Location")
                                .foregroundColor(GQColors.textTertiary)
                        }
                    }

                    // User's gyms/communities
                    if !userCommunities.isEmpty {
                        Section {
                            ForEach(userCommunities) { community in
                                CommunityLocationRow(
                                    community: community,
                                    isSelected: selectedLocation?.communityId == community.id
                                ) {
                                    selectedLocation = LocationSuggestion(
                                        id: UUID(),
                                        name: community.name,
                                        type: .community,
                                        communityId: community.id
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

                    // Other communities
                    if !otherCommunities.isEmpty {
                        Section {
                            ForEach(otherCommunities) { community in
                                CommunityLocationRow(
                                    community: community,
                                    isSelected: selectedLocation?.communityId == community.id
                                ) {
                                    selectedLocation = LocationSuggestion(
                                        id: UUID(),
                                        name: community.name,
                                        type: .community,
                                        communityId: community.id
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
            .background(GQColors.background.ignoresSafeArea())
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

// MARK: - Community Location Row

struct CommunityLocationRow: View {
    let community: Community
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: "building.2.fill")
                    .foregroundColor(GQColors.success)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(community.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)

                    if let location = community.location {
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
        .buttonStyle(.plain)
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
                            .foregroundColor(.white)

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
            .background(GQColors.background.ignoresSafeArea())
            .navigationTitle("Share with Squads")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(GQColors.cyanSpark)
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
                        .foregroundColor(.white)

                    Text("\(squad.memberCount) members")
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textSecondary)
                }

                Spacer()

                if squad.streakWeeks > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(GQColors.sunsetOrange)
                        Text("\(squad.streakWeeks)w")
                            .foregroundColor(GQColors.sunsetOrange)
                    }
                    .font(.system(size: 11, weight: .semibold))
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? GQColors.vividPurple : GQColors.textTertiary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
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
    .preferredColorScheme(.dark)
}
