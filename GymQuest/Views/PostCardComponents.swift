//
//  PostCardComponents.swift
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

// MARK: - Enhanced Post Card

struct PostCardV2: View {
    let post: Post
    let currentUserId: UUID
    var currentUserName: String = ""
    var profile: UserProfile? = nil

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @State private var isLiked = false
    @State private var showVideoPlayer = false
    @State private var showComments = false
    @State private var hasAppeared = false
    @State private var isPlayingMusic = false
    @State private var showWorkoutDetail = false
    @State private var showFullCaption = false
    @State private var showingCopySheet = false
    @State private var copySheetWorkout: SharedWorkoutData?
    @State private var cachedTopComment: Comment?
    // Emoji reactions handled via action bar reaction picker
    @State private var showFullRouteMap = false
    @State private var profileUserId: IdentifiableUUID?
    @State private var cachedWorkout: SharedWorkoutData?
    @State private var cachedPRs: [FeedPR] = []
    @State private var showDoubleTapHeart = false
    @State private var doubleTapLocation: CGPoint = .zero
    @State private var useMusicStyleB = false

    var detectedActivityType: DetectedActivity? {
        guard let activity = post.detectedActivity else { return nil }
        return DetectedActivity(rawValue: activity)
    }

    var sharedWorkout: SharedWorkoutData? {
        cachedWorkout
    }

    /// Compact post: only truly non-workout posts (text shoutouts etc.)
    private var isCompactPost: Bool {
        post.photoData == nil && post.videoData == nil && post.workoutType == nil && sharedWorkout == nil
    }

    private var topComment: Comment? {
        cachedTopComment
    }

    private func fetchTopComment() {
        let postId = post.id
        var descriptor = FetchDescriptor<Comment>(
            predicate: #Predicate { $0.postId == postId },
            sortBy: [SortDescriptor(\Comment.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        cachedTopComment = try? modelContext.fetch(descriptor).first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isCompactPost {
                compactTextOnlyLayout
                inlineCommentPreview
            } else {
                headerRow
                inspiredByBadge
                workoutIdentityBadge
                heroSection
                inlineMusicRow
                captionSection
                compactBottomBar
                inlineCommentPreview
            }
        }
        .background(GQColors.surfaceBase)
        .contextMenu {
            if post.authorId != currentUserId {
                Button {
                    PermissionsService.shared.blockUser(userId: currentUserId, targetId: post.authorId)
                } label: {
                    Label("Block User", systemImage: "hand.raised")
                }
                Button {
                    PermissionsService.shared.muteUser(userId: currentUserId, targetId: post.authorId)
                } label: {
                    Label("Mute User", systemImage: "speaker.slash")
                }
                Button(role: .destructive) {
                    PermissionsService.shared.reportContent(
                        reporterId: currentUserId,
                        contentType: "post",
                        contentId: post.id,
                        reason: "inappropriate"
                    )
                } label: {
                    Label("Report Post", systemImage: "flag")
                }
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .task {
            cachedWorkout = post.getSharedWorkout()
            cachedPRs = post.getFeedPRs()
        }
        .onAppear {
            hasAppeared = true
            fetchTopComment()
            if post.songTitle != nil {
                isPlayingMusic = true
            }
            // No-op: emoji reactions are in the action bar
        }
        .onDisappear {
            if post.songTitle != nil {
                isPlayingMusic = false
            }
        }
        .fullScreenCover(isPresented: $showVideoPlayer) {
            if let videoData = post.videoData {
                VideoPlayerView(videoData: videoData, isPresented: $showVideoPlayer)
            }
        }
        .sheet(isPresented: $showComments) {
            CommentsSheet(
                post: post,
                currentUserId: currentUserId,
                currentUserName: currentUserName
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showWorkoutDetail) {
            if let workout = sharedWorkout {
                WorkoutDetailSheet(
                    workoutData: workout,
                    onFollow: {
                        showWorkoutDetail = false
                        launchFollowWorkout(workout)
                    },
                    onAddExercise: { exercise in
                        let mg = MuscleGroup(rawValue: exercise.muscleGroup) ?? .chest
                        let sets = exercise.sets.map { ActiveSet(reps: $0.reps, weight: $0.weight) }
                        let active = ActiveExercise(name: exercise.name, muscleGroup: mg, sets: sets)
                        if appState.activeWorkout != nil {
                            appState.activeWorkout?.exercises.append(active)
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showingCopySheet) {
            if let workout = copySheetWorkout, let userProfile = profile {
                WorkoutCopySheet(workoutData: workout, profile: userProfile)
            }
        }
        .fullScreenCover(isPresented: $showFullRouteMap) {
            if let points = sharedWorkout?.routePoints {
                NavigationStack {
                    PostRouteMapView(
                        routePoints: points,
                        distance: "5.00 km",
                        pace: "4:31 /km",
                        height: .infinity
                    )
                    .ignoresSafeArea()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { showFullRouteMap = false } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                    }
                    .toolbarBackground(.hidden, for: .navigationBar)
                }
            }
        }
        .sheet(item: $profileUserId) { wrapped in
            if let p = profile {
                UserProfileSheet(userId: wrapped.id, currentProfile: p)
            }
        }
    }

    // MARK: - Extracted ViewBuilders

    @ViewBuilder
    private var headerRow: some View {
        HStack {
            PostHeaderEnhanced(
                post: post,
                activityType: detectedActivityType,
                locationName: post.locationName,
                onTapUser: { profileUserId = IdentifiableUUID(id: post.authorId) }
            )

            if post.authorId == currentUserId {
                PostDeleteButton {
                    deletePost()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var compactTextOnlyLayout: some View {
        HStack(alignment: .top, spacing: 10) {
            // Small avatar (tappable)
            Button {
                profileUserId = IdentifiableUUID(id: post.authorId)
            } label: {
                Circle()
                    .fill(GQColors.primary)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(post.authorName.prefix(1)).uppercased())
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Button {
                        profileUserId = IdentifiableUUID(id: post.authorId)
                    } label: {
                        HStack(spacing: 6) {
                            Text(post.authorName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(GQColors.textPrimary)
                            Text("@\(post.authorUsername)")
                                .font(.system(size: 12))
                                .foregroundColor(GQColors.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                    Text(post.timestamp.timeAgoDisplay())
                        .font(.system(size: 12))
                        .foregroundColor(GQColors.textTertiary)
                }

                if !post.caption.isEmpty {
                    Text(post.caption)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .lineSpacing(2)
                        .lineLimit(3)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            ChatBubbleShape(isFromCurrentUser: true)
                                .fill(GQGradients.primary)
                                .shadow(color: GQColors.deepBlue.opacity(0.4), radius: 8, x: 0, y: 4)
                        )
                }

                // Inline workout stats pill
                if post.workoutType != nil || post.duration != nil {
                    HStack(spacing: 8) {
                        if let type = post.workoutType {
                            HStack(spacing: 4) {
                                let wt = WorkoutType(rawValue: type) ?? .custom
                                Image(systemName: wt.icon)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(GQGradients.workoutColor(for: wt))
                                Text(type)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(GQGradients.workoutColor(for: wt))
                            }
                        }
                        if let duration = post.duration {
                            HStack(spacing: 2) {
                                Image(systemName: "clock")
                                    .font(.system(size: 9))
                                Text("\(duration)m")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(GQColors.textSecondary)
                        }
                        if let sets = post.setCount {
                            HStack(spacing: 2) {
                                Image(systemName: "flame")
                                    .font(.system(size: 9))
                                Text("\(sets) sets")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(GQColors.textSecondary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(GQColors.adaptiveOverlay(0.06))
                    .cornerRadius(8)
                }

                // Inline actions
                HStack(spacing: 20) {
                    Button { showComments = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.right")
                                .font(.system(size: 12))
                            if post.commentCount > 0 {
                                Text("\(post.commentCount)")
                                    .font(.system(size: 12))
                            }
                        }
                        .foregroundColor(GQColors.textSecondary)
                    }
                    .buttonStyle(.plain)

                    Button {
                        if !isLiked {
                            isLiked = true
                            post.likeCount += 1
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 12))
                            if post.likeCount > 0 {
                                Text("\(post.likeCount)")
                                    .font(.system(size: 12))
                            }
                        }
                        .foregroundColor(isLiked ? GQColors.deepBlue : GQColors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .leading) {
            if let emotion = post.emotion {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(emotion.color)
                    .frame(width: 3)
                    .padding(.vertical, 12)
            }
        }
    }

    @ViewBuilder
    private var inspiredByBadge: some View {
        if let inspiredBy = post.inspiredByUsername {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11))
                Text("Inspired by @\(inspiredBy)")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(GQColors.textTertiary)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private var workoutIdentityBadge: some View {
        EmptyView()
    }

    @ViewBuilder
    private var inlineMusicRow: some View {
        if post.photoData == nil && post.videoData == nil,
           let songTitle = post.songTitle, let artistName = post.artistName {
            let isSpotify = post.musicSource == "Spotify"
            let serviceColor: Color = isSpotify ? Color(hex: "1DB954") : Color(hex: "FC3C44")
            let hasPlaylist = post.spotifyPlaylistURL != nil || post.appleMusicPlaylistURL != nil

            VStack(spacing: 0) {
                // Main music row
                HStack(spacing: 12) {
                    // Vinyl disc
                    InlineVinylDisc(serviceColor: serviceColor, isPlaying: isPlayingMusic)

                    // Song info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(songTitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(GQColors.textPrimary)
                            .lineLimit(1)
                        Text(artistName)
                            .font(.system(size: 11))
                            .foregroundColor(GQColors.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // EQ bars + service icon
                    HStack(spacing: 8) {
                        MusicEQBars(barCount: 4, barWidth: 2.5, maxHeight: 16, color: serviceColor, isPlaying: isPlayingMusic)
                            .frame(width: 18, height: 16)

                        if post.musicSource != nil {
                            if isSpotify {
                                SpotifyIcon(size: 18)
                            } else {
                                AppleMusicIcon(size: 18)
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
                .onTapGesture { isPlayingMusic.toggle() }

                // Playlist links row
                if hasPlaylist {
                    Divider()
                        .overlay(serviceColor.opacity(0.15))

                    HStack(spacing: 10) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(GQColors.textSecondary)

                        if let spotifyURL = post.spotifyPlaylistURL, let url = URL(string: spotifyURL) {
                            Link(destination: url) {
                                HStack(spacing: 4) {
                                    SpotifyIcon(size: 14)
                                    Text("Open Playlist")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(Color(hex: "1DB954"))
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 8, weight: .semibold))
                                        .foregroundColor(Color(hex: "1DB954").opacity(0.6))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color(hex: "1DB954").opacity(0.1)))
                            }
                        }
                        if let appleURL = post.appleMusicPlaylistURL, let url = URL(string: appleURL) {
                            Link(destination: url) {
                                HStack(spacing: 4) {
                                    AppleMusicIcon(size: 14)
                                    Text("Open Playlist")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(Color(hex: "FC3C44"))
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 8, weight: .semibold))
                                        .foregroundColor(Color(hex: "FC3C44").opacity(0.6))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color(hex: "FC3C44").opacity(0.1)))
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(serviceColor.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(serviceColor.opacity(0.12), lineWidth: 0.5)
            )
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .contextMenu {
                Button {
                    openMusicSearch(song: songTitle, artist: artistName, service: .spotify)
                } label: {
                    Label("Open in Spotify", systemImage: "arrow.up.right")
                }
                Button {
                    openMusicSearch(song: songTitle, artist: artistName, service: .appleMusic)
                } label: {
                    Label("Open in Apple Music", systemImage: "arrow.up.right")
                }
            }
        }
    }

    @ViewBuilder
    private var heroSection: some View {
        if post.photoData != nil || post.videoData != nil {
            photoHero
        } else if isCardioWithRoute, let points = sharedWorkout?.routePoints {
            CardioRouteView(
                postId: post.exerciseHighlight ?? "route",
                distance: cardioDistanceKm,
                pace: cardioPace,
                gradientColors: cardioGradientColors,
                locationName: post.locationName,
                realRoutePoints: points
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .onTapGesture { showFullRouteMap = true }
        }
    }

    private var cardioDistanceKm: Double {
        guard let points = sharedWorkout?.routePoints, points.count >= 2 else { return 5.0 }
        var total: Double = 0
        for i in 1..<points.count {
            let prev = CLLocation(latitude: points[i-1].latitude, longitude: points[i-1].longitude)
            let curr = CLLocation(latitude: points[i].latitude, longitude: points[i].longitude)
            total += prev.distance(from: curr)
        }
        return total / 1000.0
    }

    private var cardioPace: String {
        guard let duration = post.duration, duration > 0 else { return "5:00" }
        let km = cardioDistanceKm
        guard km > 0 else { return "5:00" }
        let paceMinPerKm = Double(duration) / km
        let mins = Int(paceMinPerKm)
        let secs = Int((paceMinPerKm - Double(mins)) * 60)
        return String(format: "%d:%02d", mins, secs)
    }

    private var cardioGradientColors: [Color] {
        if let highlight = post.exerciseHighlight, let subType = CardioSubType.from(highlight) {
            return [subType.color, GQColors.textSecondary]
        }
        return [GQColors.textSecondary, GQColors.textSecondary]
    }

    // Workout type accent color for tinting
    private var workoutAccent: Color {
        if let type = post.workoutType, let wt = WorkoutType(rawValue: type) {
            return GQGradients.workoutColor(for: wt)
        }
        return GQColors.deepBlue
    }

    @ViewBuilder
    private var photoHero: some View {
        ZStack(alignment: .bottom) {
            // The image/video
            if post.mediaItems.count > 1 {
                ExerciseMediaCarousel(mediaItems: post.mediaItems)
            } else {
                PostMediaView(post: post, showVideoPlayer: $showVideoPlayer)
            }

            // Enhanced gradient fade
            LinearGradient(
                colors: [.clear, .black.opacity(0.05), .black.opacity(0.4), .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            // Bottom content — title banner + music + gifs
            VStack(spacing: 8) {
                if useMusicStyleB {
                    photoMusicOverlayB
                } else {
                    photoMusicOverlayA
                }
                photoWorkoutGifs
                photoTitleBanner
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 14)

            // Double-tap heart burst
            if showDoubleTapHeart {
                DoubleTapHeartBurst(isActive: true, location: doubleTapLocation)
            }
        }
        .clipShape(Rectangle())
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { location in
            doubleTapLocation = location
            showDoubleTapHeart = true
            #if canImport(UIKit)
            let heavy = UIImpactFeedbackGenerator(style: .heavy)
            heavy.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            #endif
            if !isLiked {
                isLiked = true
                post.likeCount += 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showDoubleTapHeart = false
            }
        }
        .onTapGesture(count: 1) {
            if sharedWorkout != nil {
                showWorkoutDetail = true
            }
        }
    }

    // MARK: - Photo Title Banner

    @ViewBuilder
    private var photoTitleBanner: some View {
        let workoutTitle = sharedWorkout?.title ?? post.workoutType
        let hasStats = post.duration != nil || post.setCount != nil || post.workoutType != nil

        if workoutTitle != nil || hasStats {
            VStack(alignment: .leading, spacing: 4) {
                if let title = workoutTitle {
                    Text(title.uppercased())
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)
                        .lineLimit(2)
                }

                if hasStats {
                    Text(compactStatString)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Music Overlay Option A (Floating Glassmorphic Pill)

    @ViewBuilder
    private var photoMusicOverlayA: some View {
        let hasMusic = post.songTitle != nil && post.artistName != nil
        let isSpotify = post.musicSource?.lowercased().contains("spotify") == true
        let serviceColor: Color = isSpotify ? Color(hex: "1DB954") : Color(hex: "FC3C44")

        if hasMusic, let song = post.songTitle, let artist = post.artistName {
            Button {
                let service: MusicService = isSpotify ? .spotify : .appleMusic
                openMusicSearch(song: song, artist: artist, service: service)
            } label: {
                HStack(spacing: 8) {
                    if isSpotify {
                        SpotifyIcon(size: 16)
                    } else {
                        AppleMusicIcon(size: 16)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(song)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(artist)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }

                    MusicEQBars(barCount: 3, barWidth: 2, maxHeight: 12, color: serviceColor, isPlaying: isPlayingMusic)
                        .frame(width: 14, height: 12)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(serviceColor.opacity(0.15))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.white.opacity(0.2), lineWidth: 0.5)
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: 220, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contextMenu {
                Button {
                    openMusicSearch(song: song, artist: artist, service: .spotify)
                } label: {
                    Label("Open in Spotify", systemImage: "arrow.up.right")
                }
                Button {
                    openMusicSearch(song: song, artist: artist, service: .appleMusic)
                } label: {
                    Label("Open in Apple Music", systemImage: "arrow.up.right")
                }
            }
        }
    }

    // MARK: - Music Overlay Option B (Full Bottom Bar)

    @ViewBuilder
    private var photoMusicOverlayB: some View {
        let hasMusic = post.songTitle != nil && post.artistName != nil
        let isSpotify = post.musicSource?.lowercased().contains("spotify") == true
        let serviceColor: Color = isSpotify ? Color(hex: "1DB954") : Color(hex: "FC3C44")

        if hasMusic, let song = post.songTitle, let artist = post.artistName {
            Button {
                let service: MusicService = isSpotify ? .spotify : .appleMusic
                openMusicSearch(song: song, artist: artist, service: service)
            } label: {
                HStack(spacing: 8) {
                    if isSpotify {
                        SpotifyIcon(size: 16)
                    } else {
                        AppleMusicIcon(size: 16)
                    }

                    Text("\(song) · \(artist)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()

                    MusicEQBars(barCount: 4, barWidth: 2.5, maxHeight: 14, color: serviceColor, isPlaying: isPlayingMusic)
                        .frame(width: 20, height: 14)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(serviceColor.opacity(0.15))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(.white.opacity(0.2), lineWidth: 0.5)
                        )
                )
                .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button {
                    openMusicSearch(song: song, artist: artist, service: .spotify)
                } label: {
                    Label("Open in Spotify", systemImage: "arrow.up.right")
                }
                Button {
                    openMusicSearch(song: song, artist: artist, service: .appleMusic)
                } label: {
                    Label("Open in Apple Music", systemImage: "arrow.up.right")
                }
            }
        }
    }

    @ViewBuilder
    private var photoWorkoutGifs: some View {
        if isCardioWithRoute, let points = sharedWorkout?.routePoints {
            MiniRouteMapOverlay(
                routePoints: points,
                gradientColors: cardioGradientColors
            )
            .onTapGesture { showFullRouteMap = true }
        } else {
            let hasExercises = sharedWorkout != nil && !(sharedWorkout?.exercises.isEmpty ?? true)

            if hasExercises, let workout = sharedWorkout {
                OverlayExerciseGifStrip(
                    exercises: workout.exercises,
                    totalCount: workout.exercises.count,
                    onTapMore: { showWorkoutDetail = true }
                )
            }
        }
    }

    private var compactStatString: String {
        var parts: [String] = []
        if let type = post.workoutType { parts.append(type) }
        if let duration = post.duration, duration > 0 { parts.append("\(duration) min") }
        if let sets = post.setCount, sets > 0 { parts.append("\(sets) sets") }
        if let workout = sharedWorkout {
            let volume = workout.exercises.reduce(0.0) { total, ex in
                total + ex.sets.reduce(0.0) { $0 + Double($1.reps) * $1.weight }
            }
            if volume > 0 { parts.append("\(Int(volume)) lbs") }
        }
        return parts.joined(separator: " · ")
    }

    private var isCardioWithRoute: Bool {
        guard let workout = sharedWorkout,
              let points = workout.routePoints, !points.isEmpty else { return false }
        let cardioKeywords = ["Cardio", "Run", "Cycling", "Walking", "Hiking", "Rowing"]
        let type = post.workoutType ?? ""
        let highlight = post.exerciseHighlight ?? ""
        return cardioKeywords.contains(where: { type.contains($0) || highlight.contains($0) })
    }

    private var cardioActivityIcon: String {
        if let highlight = post.exerciseHighlight, let subType = CardioSubType.from(highlight) {
            return subType.icon
        }
        return "figure.run"
    }

    /// Maps cardio exercise highlights to GIF-capable exercise names from the ExerciseDB.
    private var cardioGifName: String? {
        guard let highlight = post.exerciseHighlight else { return nil }
        let lower = highlight.lowercased()
        if lower.contains("run") || lower.contains("jog") { return "Treadmill Run" }
        if lower.contains("row") { return "Rowing Machine" }
        if lower.contains("walk") || lower.contains("hik") { return "Walking" }
        return nil
    }

    @ViewBuilder
    private var captionSection: some View {
        if !post.caption.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Button {
                        showComments = true
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(post.caption)
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                                .lineSpacing(2)
                                .lineLimit(showFullCaption ? nil : 2)
                                .multilineTextAlignment(.leading)

                            if !showFullCaption && post.caption.count > 140 {
                                Text("more")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            ChatBubbleShape(isFromCurrentUser: true)
                                .fill(GQGradients.primary)
                                .shadow(color: GQColors.deepBlue.opacity(0.4), radius: 8, x: 0, y: 4)
                        )
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showFullCaption = true
                        }
                    })

                    Spacer(minLength: 40)
                }

                HStack(spacing: 4) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.system(size: 9))
                    Text("tap to reply")
                        .font(.system(size: 11))
                }
                .foregroundColor(GQColors.textTertiary)
                .padding(.leading, 14)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }



    @ViewBuilder
    private var compactBottomBar: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let voiceData = post.voiceNoteData, let duration = post.voiceNoteDuration {
                VoiceNotePlayerView(audioData: voiceData, duration: duration)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
            }

            PostActionsRowCompact(
                post: post,
                isLiked: $isLiked,
                showComments: $showComments,
                hasWorkout: sharedWorkout != nil,
                onFollowWorkout: sharedWorkout != nil ? {
                    showWorkoutDetail = true
                } : nil,
                currentUserId: currentUserId,
                currentUserName: currentUserName
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private var inlineCommentPreview: some View {
        if post.commentCount > 0, let comment = topComment {
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    showComments = true
                } label: {
                    HStack(alignment: .bottom, spacing: 6) {
                        Circle()
                            .fill(GQGradients.primary)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Text(String(comment.authorName.prefix(1)).uppercased())
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                            )

                        VStack(alignment: .leading, spacing: 1) {
                            Text(comment.authorName)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(GQColors.textSecondary)

                            Text(comment.content)
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "1C1C1E"))
                                .lineLimit(1)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    ChatBubbleShape(isFromCurrentUser: false)
                                        .fill(LinearGradient(colors: [Color(hex: "F5F5F7"), Color(hex: "E8E8ED")], startPoint: .top, endPoint: .bottom))
                                )
                        }

                        Spacer(minLength: 60)
                    }
                }
                .buttonStyle(.plain)

                if post.commentCount > 1 {
                    Button {
                        showComments = true
                    } label: {
                        Text("View conversation (\(post.commentCount - 1) \(post.commentCount == 2 ? "reply" : "replies"))")
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textTertiary)
                            .padding(.leading, 28)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Helpers

    private func launchFollowWorkout(_ workout: SharedWorkoutData) {
        copySheetWorkout = workout
        showingCopySheet = true
    }

    private enum MusicService { case spotify, appleMusic }

    private func openMusicSearch(song: String, artist: String, service: MusicService) {
        let query = "\(song) \(artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        #if canImport(UIKit)
        switch service {
        case .spotify:
            if let appURL = URL(string: "spotify:search:\(query)"),
               UIApplication.shared.canOpenURL(appURL) {
                UIApplication.shared.open(appURL)
            } else if let webURL = URL(string: "https://open.spotify.com/search/\(query)") {
                UIApplication.shared.open(webURL)
            }
        case .appleMusic:
            if let url = URL(string: "https://music.apple.com/search?term=\(query)") {
                UIApplication.shared.open(url)
            }
        }
        #endif
    }

    private func deletePost() {
        modelContext.delete(post)
        try? modelContext.save()
    }
}

// MARK: - Streak Milestone Card

struct StreakMilestoneCard: View {
    let userName: String
    let days: Int
    let workouts: Int

    private var streakLabel: String {
        switch days {
        case ..<14: return "1 Week"
        case ..<21: return "2 Weeks"
        case ..<30: return "3 Weeks"
        case ..<60: return "1 Month"
        case ..<90: return "2 Months"
        case ..<180: return "3 Months"
        case ..<365: return "6 Months"
        default: return "1 Year"
        }
    }

    private var streakEmoji: String {
        switch days {
        case ..<14: return "🔥"
        case ..<30: return "🔥🔥"
        case ..<60: return "⚡️"
        case ..<90: return "💎"
        default: return "👑"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Streak ring
            ZStack {
                Circle()
                    .stroke(GQColors.textSecondary.opacity(0.2), lineWidth: 3)
                    .frame(width: 44, height: 44)
                Circle()
                    .trim(from: 0, to: min(CGFloat(days) / 30.0, 1.0))
                    .stroke(GQColors.textSecondary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
                Text(streakEmoji)
                    .font(.system(size: 18))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(userName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                    Text("\(streakLabel) streak")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(GQColors.textSecondary)
                }

                Text("\(workouts) workouts in \(days) days — showing up every week")
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(GQColors.surfaceBase)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(GQColors.textSecondary.opacity(0.5))
                .frame(width: 3)
                .padding(.vertical, 14)
        }
    }
}

// MARK: - Workout Suggestion Card

struct WorkoutSuggestionCard: View {
    let workout: SharedWorkoutData
    let suggestedBy: String
    var profile: UserProfile? = nil

    @EnvironmentObject var appState: AppState
    @State private var showWorkoutDetail = false
    @State private var showingCopySheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.primary)

                Text("Workout to Try")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(GQColors.primary)

                Spacer()

                Text("from \(suggestedBy)")
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textTertiary)
            }

            // Workout title + type badge
            HStack(spacing: 8) {
                Text(workout.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(GQColors.textPrimary)

                if let wt = WorkoutType(rawValue: workout.workoutType) {
                    Text(workout.workoutType)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(GQGradients.workoutColor(for: wt))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(GQGradients.workoutColor(for: wt).opacity(0.12))
                        .cornerRadius(6)
                }

                Spacer()
            }

            // Mini stats row
            HStack(spacing: 16) {
                Label("\(workout.estimatedDuration) min", systemImage: "clock")
                Label("\(workout.exercises.count) exercises", systemImage: "list.bullet")
                let totalSets = workout.exercises.reduce(0) { $0 + $1.sets.count }
                Label("\(totalSets) sets", systemImage: "flame")
            }
            .font(.system(size: 12))
            .foregroundColor(GQColors.textSecondary)

            // Exercise preview (first 3)
            VStack(spacing: 6) {
                ForEach(workout.exercises.prefix(3)) { exercise in
                    HStack(spacing: 8) {
                        ExerciseGifView(exerciseName: exercise.name, size: .thumbnail)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(exercise.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(GQColors.textPrimary)
                            Text("\(exercise.sets.count) sets • \(exercise.muscleGroup)")
                                .font(.system(size: 11))
                                .foregroundColor(GQColors.textTertiary)
                        }
                        Spacer()
                    }
                }
            }

            // CTA button
            Button {
                showingCopySheet = true
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12))
                    Text("Try This Workout")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(GQGradients.primary)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(GQColors.surfaceBase)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(GQColors.primary)
                .frame(width: 3)
                .padding(.vertical, 16)
        }
        .sheet(isPresented: $showingCopySheet) {
            if let userProfile = profile {
                WorkoutCopySheet(workoutData: workout, profile: userProfile)
            }
        }
    }
}

// MARK: - Community Pulse Card

struct CommunityPulseCard: View {
    let activeCount: Int
    let recentPRs: Int
    let topExercise: String

    var body: some View {
        HStack(spacing: 0) {
            pulseStat(value: "\(activeCount)", label: "friends active", icon: "person.2.fill")
            divider
            pulseStat(value: "\(recentPRs)", label: "new PRs", icon: "trophy.fill")
            divider
            pulseStat(value: topExercise, label: "trending", icon: "chart.line.uptrend.xyaxis")
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .background(GQColors.surfaceBase)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [GQColors.textSecondary.opacity(0.3), GQColors.primary.opacity(0.3)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
        }
    }

    @ViewBuilder
    private func pulseStat(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(GQColors.textSecondary)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(GQColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(GQColors.borderSubtle)
            .frame(width: 1, height: 40)
    }
}

// MARK: - Motivation Prompt Card

struct MotivationPromptCard: View {
    let message: String
    let type: MotivationType

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(.system(size: 18))
                .foregroundColor(type.accentColor)
                .frame(width: 36, height: 36)
                .background(type.accentColor.opacity(0.12))
                .cornerRadius(10)

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(GQColors.textPrimary)
                .lineSpacing(2)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(GQColors.surfaceBase)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(type.accentColor.opacity(0.5))
                .frame(width: 3)
                .padding(.vertical, 14)
        }
    }
}

// MARK: - Inspiration Chain Card

struct InspirationChainCard: View {
    let original: Post
    let followers: [String]
    var profile: UserProfile? = nil

    @State private var showingCopySheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.secondary)

                Text("Workout Chain")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(GQColors.secondary)

                Spacer()
            }

            // Chain visualization
            HStack(spacing: 0) {
                // Original author avatar
                chainAvatar(name: original.authorName, isOriginal: true)

                // Dotted connector
                chainConnector

                // Follower avatars
                ForEach(Array(followers.prefix(3).enumerated()), id: \.offset) { _, name in
                    chainAvatar(name: name, isOriginal: false)
                    if name != followers.prefix(3).last {
                        chainConnector
                    }
                }

                if followers.count > 3 {
                    Text("+\(followers.count - 3)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(GQColors.textTertiary)
                        .padding(.leading, 6)
                }

                Spacer()
            }

            // Description
            Text("\(followers.first ?? "Someone") tried \(original.authorName)'s \(original.workoutType ?? "workout")")
                .font(.system(size: 14))
                .foregroundColor(GQColors.textPrimary)
            +
            Text(followers.count > 1 ? " — \(followers.count) others also tried it" : "")
                .font(.system(size: 14))
                .foregroundColor(GQColors.textSecondary)

            // CTA
            if let workout = original.getSharedWorkout() {
                Button {
                    showingCopySheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.system(size: 12))
                        Text("Join the chain")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(GQColors.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(GQColors.secondary.opacity(0.12))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showingCopySheet) {
                    if let userProfile = profile {
                        WorkoutCopySheet(workoutData: workout, profile: userProfile)
                    }
                }
            }
        }
        .padding(16)
        .background(GQColors.surfaceBase)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(GQColors.secondary.opacity(0.5))
                .frame(width: 3)
                .padding(.vertical, 16)
        }
    }

    @ViewBuilder
    private func chainAvatar(name: String, isOriginal: Bool) -> some View {
        Circle()
            .fill(isOriginal ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(GQColors.adaptiveOverlay(0.1)))
            .frame(width: 32, height: 32)
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isOriginal ? .white : GQColors.textSecondary)
            )
            .overlay(
                Circle()
                    .stroke(isOriginal ? GQColors.secondary : GQColors.borderSubtle, lineWidth: 1.5)
            )
    }

    private var chainConnector: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .fill(GQColors.textTertiary)
                    .frame(width: 3, height: 3)
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Workout Hero Card

struct WorkoutHeroCard: View {
    let workout: SharedWorkoutData?
    let workoutType: String?
    let emotion: WorkoutEmotion?
    let duration: Int?
    let setCount: Int?
    var exerciseHighlight: String? = nil
    var locationName: String? = nil
    var onCopy: (() -> Void)? = nil
    var onTap: (() -> Void)? = nil

    @State private var showCopied = false

    private var cardioSubType: CardioSubType? {
        guard workoutType == "Cardio" else { return nil }
        return CardioSubType.from(exerciseHighlight)
    }

    private var gradientColors: [Color] {
        if let type = workoutType, let wt = WorkoutType(rawValue: type) {
            return GQGradients.workoutGradientColors(for: wt)
        }
        return [GQColors.deepBlue, GQColors.textSecondary]
    }

    private var hasExercises: Bool {
        guard let w = workout else { return false }
        return !w.exercises.isEmpty
    }

    private var workoutTypeIcon: String {
        if let type = workoutType, let wt = WorkoutType(rawValue: type) { return wt.icon }
        return "dumbbell.fill"
    }

    private func equipmentIcon(for exerciseName: String) -> String {
        ExtendedExerciseDatabase.find(exerciseName)?.equipment.icon ?? "dumbbell.fill"
    }

    var body: some View {
        Group {
            if hasExercises {
                exerciseHeroContent
            } else {
                statsOnlyContent
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }

    // MARK: - Exercise Hero Content

    @ViewBuilder
    private var exerciseHeroContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(gradientColors.first ?? GQColors.deepBlue)
                    .frame(width: 3, height: 36)

                Image(systemName: workoutTypeIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(gradientColors.first ?? GQColors.deepBlue)

                if let type = workoutType {
                    Text(type)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                }

                Spacer()

                HStack(spacing: 6) {
                    if let d = duration, d > 0 {
                        Text("\(d) min")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(GQColors.textSecondary)
                    }
                    if let s = setCount, s > 0 {
                        Text("\u{00B7}")
                            .foregroundColor(GQColors.textSecondary)
                        Text("\(s) sets")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(GQColors.textSecondary)
                    }
                }

                copyButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()
                .padding(.horizontal, 16)

            // Exercise list
            exerciseTable
                .padding(.top, 10)
                .padding(.bottom, 14)
        }
        .gqCard(cornerRadius: 16)
    }

    // MARK: - Stats Only Content

    @ViewBuilder
    private var statsOnlyContent: some View {
        let isCardioWithRoute = cardioSubType?.isOutdoor == true

        VStack(alignment: .leading, spacing: 0) {
            if isCardioWithRoute, let subType = cardioSubType {
                // Cardio header + route
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(subType.color)
                        .frame(width: 3, height: 36)

                    Image(systemName: subType.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(subType.color)

                    Text(subType.rawValue)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)

                    Spacer()

                    if let d = duration, d > 0 {
                        Text("\(d) min")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(GQColors.textSecondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

                CardioRouteView(
                    postId: exerciseHighlight ?? "route",
                    distance: cardioDistanceKm,
                    pace: cardioPace,
                    gradientColors: [subType.color, GQColors.textSecondary],
                    locationName: locationName
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            } else {
                // Non-cardio or indoor cardio: horizontal card
                HStack(spacing: 14) {
                    Circle()
                        .fill((gradientColors.first ?? GQColors.deepBlue).opacity(0.12))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: workoutTypeIcon)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(gradientColors.first ?? GQColors.deepBlue)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(workoutType ?? "Workout")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(GQColors.textPrimary)

                        HStack(spacing: 6) {
                            if let d = duration, d > 0 {
                                Text("\(d) min")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(GQColors.textSecondary)
                            }
                            if let s = setCount, s > 0 {
                                Text("\u{00B7}")
                                    .foregroundColor(GQColors.textSecondary)
                                Text("\(s) sets")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(GQColors.textSecondary)
                            }
                            if let subType = cardioSubType, let machine = subType.machineLabel {
                                Text("\u{00B7}")
                                    .foregroundColor(GQColors.textSecondary)
                                Text(machine)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(GQColors.textSecondary)
                            }
                        }
                    }

                    Spacer()
                }
                .padding(16)
            }
        }
        .gqCard(cornerRadius: 16)
    }

    // MARK: - Cardio Helpers

    private var cardioDistanceKm: Double {
        guard let d = duration, d > 0 else { return 3.0 }
        return Double(d) * 0.18
    }

    private var cardioPace: String {
        guard let d = duration, d > 0 else { return "5:30" }
        let dist = cardioDistanceKm
        guard dist > 0 else { return "5:30" }
        let paceMin = Double(d) / dist
        let mins = Int(paceMin)
        let secs = Int((paceMin - Double(mins)) * 60)
        return "\(mins):\(String(format: "%02d", secs))"
    }

    // MARK: - Exercise Table

    @ViewBuilder
    private var exerciseTable: some View {
        if let exercises = workout?.exercises {
            let displayExercises = Array(exercises.prefix(4))
            let remaining = exercises.count - 4

            VStack(spacing: 6) {
                ForEach(displayExercises) { ex in
                    exerciseRow(ex)
                }

                if remaining > 0 {
                    Text("+\(remaining) more")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(GQColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func setsAreUniform(_ sets: [SharedWorkoutData.SharedExercise.SharedSet]) -> Bool {
        guard let first = sets.first else { return true }
        return sets.allSatisfy { $0.reps == first.reps && $0.weight == first.weight }
    }

    private func setsSummary(_ sets: [SharedWorkoutData.SharedExercise.SharedSet]) -> String {
        let capped = Array(sets.prefix(4))
        let parts = capped.map { s in
            if s.weight > 0 {
                return "\(Int(s.weight))\u{00D7}\(s.reps)"
            } else {
                return "BW\u{00D7}\(s.reps)"
            }
        }
        let joined = parts.joined(separator: " \u{00B7} ")
        if sets.count > 4 {
            return joined + " +\(sets.count - 4)"
        }
        return joined
    }

    @ViewBuilder
    private func exerciseRow(_ ex: SharedWorkoutData.SharedExercise) -> some View {
        let uniform = setsAreUniform(ex.sets)

        HStack(spacing: 6) {
            if FeatureFlags.shared.exerciseGifsEnabled, ExerciseGifService.shared.hasGif(for: ex.name) {
                ExerciseGifView(exerciseName: ex.name, size: .thumbnail, showFallback: false)
                    .scaleEffect(0.6)
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: equipmentIcon(for: ex.name))
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textSecondary)
                    .frame(width: 16)
            }

            Text(ex.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(GQColors.textPrimary)
                .lineLimit(1)

            Spacer()

            if uniform {
                let setCount = ex.sets.count
                let reps = ex.sets.first?.reps ?? 0
                let weight = ex.sets.first?.weight ?? 0

                Text("\(setCount)\u{00D7}\(reps)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)

                if weight > 0 {
                    Text("\(Int(weight)) lbs")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(GQColors.textSecondary)
                        .frame(width: 60, alignment: .trailing)
                } else {
                    Text("BW")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(GQColors.textSecondary)
                        .frame(width: 60, alignment: .trailing)
                }
            } else {
                Text(setsSummary(ex.sets))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Copy Button

    @ViewBuilder
    private var copyButton: some View {
        if let onCopy {
            Button {
                onCopy()
                withAnimation(.spring(response: 0.3)) {
                    showCopied = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { showCopied = false }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11, weight: .semibold))
                    Text(showCopied ? "Saved" : "Copy")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(gradientColors.first ?? GQColors.deepBlue)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background((gradientColors.first ?? GQColors.deepBlue).opacity(0.1))
                .cornerRadius(14)
            }
            .buttonStyle(.plain)
            .disabled(showCopied)
        }
    }
}

// MARK: - Mini Route Map Overlay (for photo posts)

struct MiniRouteMapOverlay: View {
    let routePoints: [RoutePoint]
    var gradientColors: [Color] = [GQColors.textSecondary, GQColors.textSecondary]

    private var coordinates: [CLLocationCoordinate2D] {
        routePoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    private var cameraPosition: MapCameraPosition {
        let coords = coordinates
        guard !coords.isEmpty else { return .automatic }
        let lats = coords.map(\.latitude)
        let lngs = coords.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lngs.min()! + lngs.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: (lats.max()! - lats.min()!) * 1.6 + 0.005,
            longitudeDelta: (lngs.max()! - lngs.min()!) * 1.6 + 0.005
        )
        return .region(MKCoordinateRegion(center: center, span: span))
    }

    var body: some View {
        Map(initialPosition: cameraPosition, interactionModes: []) {
            MapPolyline(coordinates: coordinates)
                .stroke(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 2.5
                )
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .frame(width: 100, height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 3)
    }
}

// MARK: - Cardio Route View

struct CardioRouteView: View {
    let postId: String
    let distance: Double
    let pace: String
    var gradientColors: [Color] = [GQColors.textSecondary, GQColors.textSecondary]
    var locationName: String? = nil
    var realRoutePoints: [RoutePoint]? = nil

    @State private var showRoute = false

    private var routeCoordinates: [CLLocationCoordinate2D] {
        // Use real GPS data when available
        if let points = realRoutePoints, !points.isEmpty {
            return points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        }

        // Fall back to seeded random for demo posts
        var rng = SeededRNG(seed: postId.hashValue)
        let count = Int.random(in: 8...12, using: &rng)

        // Base location from locationName
        let base: (lat: Double, lng: Double) = {
            let loc = locationName?.lowercased() ?? ""
            if loc.contains("arc") || loc.contains("queen") {
                return (44.2253, -76.4951) // Kingston / Queen's area
            } else if loc.contains("goodlife") && loc.contains("downtown") {
                return (43.6510, -79.3832) // Toronto downtown
            }
            return (43.6510 + Double.random(in: -0.5...0.5, using: &rng),
                    -79.3832 + Double.random(in: -0.5...0.5, using: &rng))
        }()

        var coords: [CLLocationCoordinate2D] = []
        var lat = base.lat
        var lng = base.lng
        for _ in 0..<count {
            lat += Double.random(in: -0.003...0.003, using: &rng)
            lng += Double.random(in: -0.003...0.003, using: &rng)
            coords.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
        }
        return coords
    }

    private var mapCameraPosition: MapCameraPosition {
        let coords = routeCoordinates
        guard !coords.isEmpty else { return .automatic }
        let lats = coords.map(\.latitude)
        let lngs = coords.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lngs.min()! + lngs.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: (lats.max()! - lats.min()!) * 1.6 + 0.005,
            longitudeDelta: (lngs.max()! - lngs.min()!) * 1.6 + 0.005
        )
        return .region(MKCoordinateRegion(center: center, span: span))
    }

    var body: some View {
        VStack(spacing: 8) {
            let coords = routeCoordinates

            ZStack {
                Map(initialPosition: mapCameraPosition, interactionModes: []) {
                    if showRoute {
                        MapPolyline(coordinates: coords)
                            .stroke(
                                LinearGradient(
                                    colors: gradientColors,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 3
                            )
                    }

                    // Start marker
                    if let first = coords.first {
                        Annotation("", coordinate: first) {
                            Circle()
                                .fill(GQColors.textSecondary)
                                .frame(width: 14, height: 14)
                                .overlay(
                                    Text("S")
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
                    }

                    // End marker
                    if let last = coords.last {
                        Annotation("", coordinate: last) {
                            Circle()
                                .fill(GQColors.textSecondary)
                                .frame(width: 14, height: 14)
                                .overlay(
                                    Text("F")
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
                    }
                }
                .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
                .colorScheme(.dark)
            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Stats pill
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "map")
                        .font(.system(size: 11))
                        .foregroundColor(gradientColors.first ?? GQColors.textSecondary)
                    Text(String(format: "%.1f km", distance))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }

                HStack(spacing: 4) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 11))
                        .foregroundColor(gradientColors.last ?? GQColors.textSecondary)
                    Text("\(pace) /km")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).delay(0.3)) {
                showRoute = true
            }
        }
    }
}

// MARK: - Seeded RNG for deterministic routes

struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

// MARK: - Compact Actions Row

struct PostActionsRowCompact: View {
    let post: Post
    @Binding var isLiked: Bool
    @Binding var showComments: Bool
    var hasWorkout: Bool = false
    var onFollowWorkout: (() -> Void)?
    var currentUserId: UUID = UUID()
    var currentUserName: String = ""

    @Environment(\.modelContext) private var modelContext
    @State private var heartScale: CGFloat = 1.0
    @State private var showParticles = false
    @State private var displayedLikeCount: Int = 0
    @State private var displayedCommentCount: Int = 0
    @State private var showReactionPicker = false
    @State private var sentReactionEmoji: String? = nil
    @State private var showSentReaction = false

    @State private var floatingEmoji: String? = nil
    @State private var floatingEmojiOffset: CGFloat = 0
    @State private var floatingEmojiOpacity: Double = 1
    @State private var reactionCounts: [(ReactionType, Int)] = []

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    reactionEmojiRow
                    compactCommentButton
                    Spacer()
                }
                .padding(.top, 4)

                // Show aggregated reaction counts
                if !reactionCounts.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(reactionCounts, id: \.0) { type, count in
                            HStack(spacing: 2) {
                                Text(type.emoji)
                                    .font(.system(size: 12))
                                Text("\(count)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(GQColors.textTertiary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            }

            // Floating emoji that launches up on reaction
            if let emoji = floatingEmoji {
                Text(emoji)
                    .font(.system(size: 36))
                    .offset(y: floatingEmojiOffset)
                    .opacity(floatingEmojiOpacity)
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            displayedLikeCount = post.likeCount
            displayedCommentCount = post.commentCount
            checkIfLiked()
            fetchReactionCounts()
        }
    }

    @State private var tappedReaction: ReactionType? = nil
    @State private var rippleReaction: ReactionType? = nil

    private func fetchReactionCounts() {
        let postId = post.id
        let descriptor = FetchDescriptor<Reaction>(
            predicate: #Predicate { $0.targetId == postId && $0.targetType == "post" }
        )
        guard let reactions = try? modelContext.fetch(descriptor) else { return }
        var counts: [ReactionType: Int] = [:]
        for r in reactions {
            counts[r.reactionType, default: 0] += 1
        }
        reactionCounts = counts.sorted { $0.value > $1.value }
    }

    private func launchFloatingEmoji(_ emoji: String) {
        floatingEmoji = emoji
        floatingEmojiOffset = 0
        floatingEmojiOpacity = 1
        withAnimation(.easeOut(duration: 0.7)) {
            floatingEmojiOffset = -60
            floatingEmojiOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            floatingEmoji = nil
        }
    }

    @ViewBuilder
    private var reactionEmojiRow: some View {
        HStack(spacing: 6) {
            ForEach(ReactionType.allCases, id: \.self) { reaction in
                Button {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                        tappedReaction = reaction
                    }
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    #endif
                    rippleReaction = reaction
                    addReaction(reaction)
                    if !isLiked { performLikeAnimation() }
                    launchFloatingEmoji(reaction.emoji)
                    sentReactionEmoji = reaction.emoji
                    withAnimation(.spring(response: 0.3)) { showSentReaction = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            tappedReaction = nil
                            rippleReaction = nil
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation { showSentReaction = false }
                    }
                } label: {
                    ZStack {
                        // Ripple glow
                        if rippleReaction == reaction {
                            Circle()
                                .fill(Color.white.opacity(0.25))
                                .frame(width: 36, height: 36)
                                .scaleEffect(rippleReaction == reaction ? 1.4 : 0.5)
                                .opacity(rippleReaction == reaction ? 0 : 0.6)
                                .animation(.easeOut(duration: 0.4), value: rippleReaction)
                        }

                        Text(reaction.emoji)
                            .font(.system(size: 22))
                            .scaleEffect(tappedReaction == reaction ? 1.5 : 1.0)
                    }
                }
                .buttonStyle(.plain)
            }

            if displayedLikeCount > 0 {
                AnimatedCounter(value: displayedLikeCount)
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textTertiary)
                    .padding(.leading, 2)
            }
        }
    }

    @ViewBuilder
    private var compactCommentButton: some View {
        Button {
            showComments = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "bubble.right")
                    .font(.system(size: 18))

                if displayedCommentCount > 0 {
                    AnimatedCounter(value: displayedCommentCount)
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .foregroundColor(GQColors.textPrimary)
    }

    @ViewBuilder
    private func compactFollowButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "figure.run")
                    .font(.system(size: 12, weight: .semibold))
                Text("Follow")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(GQColors.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(GQColors.textSecondary.opacity(0.12))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var compactShareButton: some View {
        Button {
            // Share action
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 18))
        }
        .buttonStyle(.plain)
        .foregroundColor(GQColors.textTertiary)
    }

    // MARK: - Like Logic

    private func performLikeAnimation() {
        let wasLiked = isLiked

        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isLiked.toggle()
            post.likeCount += isLiked ? 1 : -1
        }

        if isLiked {
            let like = Like(
                postId: post.id,
                userId: currentUserId,
                userName: currentUserName
            )
            modelContext.insert(like)
        } else {
            let postId = post.id
            let userId = currentUserId
            let descriptor = FetchDescriptor<Like>(
                predicate: #Predicate { $0.postId == postId && $0.userId == userId }
            )
            if let existingLikes = try? modelContext.fetch(descriptor) {
                for like in existingLikes {
                    modelContext.delete(like)
                }
            }
        }
        try? modelContext.save()

        withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
            heartScale = 1.3
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                heartScale = 1.0
            }
        }

        if !wasLiked {
            showParticles = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                showParticles = false
            }
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            displayedLikeCount = post.likeCount
        }
    }

    private func checkIfLiked() {
        let postId = post.id
        let userId = currentUserId
        let descriptor = FetchDescriptor<Like>(
            predicate: #Predicate { $0.postId == postId && $0.userId == userId }
        )
        if let likes = try? modelContext.fetch(descriptor), !likes.isEmpty {
            isLiked = true
        }
    }

    private func addReaction(_ type: ReactionType) {
        // Prevent duplicate: check if same user already reacted with same type on this post
        let userId = currentUserId
        let postId = post.id
        let descriptor = FetchDescriptor<Reaction>(
            predicate: #Predicate { $0.odId == userId && $0.targetId == postId }
        )
        let matchingType = (try? modelContext.fetch(descriptor))?.filter { $0.reactionType == type } ?? []

        if !matchingType.isEmpty {
            let existing = matchingType
            // Toggle off: remove existing reaction
            for r in existing { modelContext.delete(r) }
            if isLiked { performLikeAnimation() }
            try? modelContext.save()
            reconcileLikeCount()
            fetchReactionCounts()
            return
        }

        let reaction = Reaction(
            odId: currentUserId,
            odUsername: currentUserName,
            targetType: "post",
            targetId: post.id,
            reactionType: type
        )
        modelContext.insert(reaction)

        if !isLiked {
            performLikeAnimation()
        }
        try? modelContext.save()
        reconcileLikeCount()
        fetchReactionCounts()

        sentReactionEmoji = type.emoji
        showSentReaction = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(2200))
            showSentReaction = false
            sentReactionEmoji = nil
        }
    }

    private func reconcileLikeCount() {
        let postId = post.id
        let likeDescriptor = FetchDescriptor<Like>(
            predicate: #Predicate { $0.postId == postId }
        )
        let count = (try? modelContext.fetch(likeDescriptor))?.count ?? 0
        if post.likeCount != count {
            post.likeCount = count
            displayedLikeCount = count
        }
    }
}

// MARK: - Follow Workout Button

struct FollowWorkoutButton: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: "figure.run")
                    .font(.system(size: 16, weight: .semibold))

                Text("Follow This Workout")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
            .foregroundColor(.white.opacity(0.85))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .homeSocialCard(accent: GQColors.textSecondary, emphasized: true, cornerRadius: 12)
        }
        .buttonStyle(GQInteractiveStyle())
    }
}


// MARK: - Enhanced Post Header

struct PostHeaderEnhanced: View {
    let post: Post
    let activityType: DetectedActivity?
    var locationName: String? = nil
    var onTapUser: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            // Simple avatar (tappable)
            Button {
                onTapUser?()
            } label: {
                Circle()
                    .fill(GQGradients.primary)
                    .frame(width: 42, height: 42)
                    .overlay(
                        Text(String(post.authorName.prefix(1)).uppercased())
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Button {
                    onTapUser?()
                } label: {
                    HStack(spacing: 4) {
                        Text(post.authorName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(GQColors.textPrimary)

                        Text("@\(post.authorUsername)")
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textTertiary)
                    }
                }
                .buttonStyle(.plain)

                HStack(spacing: 4) {
                    Text(post.timestamp.timeAgoDisplay())
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textTertiary)

                    if let location = locationName {
                        Text("·")
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textTertiary)
                        Image(systemName: "location.fill")
                            .font(.system(size: 9))
                            .foregroundColor(GQColors.textTertiary)
                        Text(location)
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textTertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Workout type badge
            if activityType == nil, let workoutType = post.workoutType {
                Text(workoutType)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.6))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
            }
        }
    }
}

// MARK: - Enhanced Workout Stats Bar

struct WorkoutStatsBarEnhanced: View {
    let duration: Int?
    let setCount: Int?

    var body: some View {
        HStack(spacing: 16) {
            if let duration = duration, duration > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textSecondary)
                    Text("\(duration) min")
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textTertiary)
                }
            }

            if let sets = setCount, sets > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textSecondary)
                    Text("\(sets) sets")
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textTertiary)
                }
            }
        }
    }
}

struct PostHeader: View {
    let post: Post

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(LinearGradient(colors: [GQColors.deepBlue, GQColors.textSecondary], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 42, height: 42)
                .overlay(
                    Text(String(post.authorName.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(post.authorName)
                        .font(.system(size: 15, weight: .semibold))

                    Text("@\(post.authorUsername)")
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textTertiary)
                }

                Text(post.timestamp.timeAgoDisplay())
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textTertiary)
            }

            Spacer()

            if let workoutType = post.workoutType {
                Text(workoutType)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(GQColors.deepBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(GQColors.deepBlue.opacity(0.12))
                    .cornerRadius(12)
            }
        }
    }
}

struct PostMediaView: View {
    let post: Post
    @Binding var showVideoPlayer: Bool
    #if canImport(UIKit)
    @State private var cachedImage: UIImage?
    #elseif canImport(AppKit)
    @State private var cachedImage: NSImage?
    #endif
    var body: some View {
        Group {
            if post.photoData != nil {
                #if canImport(UIKit)
                if let uiImage = cachedImage {
                    Color.clear
                        .aspectRatio(4.0/5.2, contentMode: .fit)
                        .overlay(
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        )
                        .clipShape(Rectangle())
                }
                #elseif canImport(AppKit)
                if let nsImage = cachedImage {
                    Color.clear
                        .aspectRatio(4.0/5.2, contentMode: .fit)
                        .overlay(
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        )
                        .clipShape(Rectangle())
                }
                #endif
            } else if post.videoData != nil {
                InlineFeedVideoPlayer(videoData: post.videoData!, showVideoPlayer: $showVideoPlayer)
            }
        }
        .task {
            guard cachedImage == nil, let data = post.photoData else { return }
            #if canImport(UIKit)
            cachedImage = UIImage(data: data)
            #elseif canImport(AppKit)
            cachedImage = NSImage(data: data)
            #endif
        }
    }
}

struct InlineFeedVideoPlayer: View {
    let videoData: Data
    @Binding var showVideoPlayer: Bool
    @State private var player: AVPlayer?
    @State private var isMuted = true

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.clear
                .aspectRatio(4.0/5.2, contentMode: .fit)
                .overlay(
                    VideoPlayer(player: player)
                        .aspectRatio(contentMode: .fill)
                )
                .clipped()
                .disabled(true)
                .onTapGesture {
                    showVideoPlayer = true
                }

            Button {
                isMuted.toggle()
                player?.isMuted = isMuted
            } label: {
                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .clipShape(Circle())
            }
            .padding(12)
        }
        .onAppear { setupAndPlay() }
        .onDisappear { player?.pause() }
    }

    private func setupAndPlay() {
        guard player == nil else { player?.play(); return }
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mov")
        try? videoData.write(to: tempURL)
        let p = AVPlayer(url: tempURL)
        p.isMuted = true
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: p.currentItem, queue: .main
        ) { _ in p.seek(to: .zero); p.play() }
        player = p
        p.play()
    }
}

struct WorkoutStatsBar: View {
    let duration: Int?
    let setCount: Int?

    var body: some View {
        HStack(spacing: 16) {
            if let duration = duration, duration > 0 {
                Label("\(duration) min", systemImage: "clock")
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textTertiary)
            }

            if let sets = setCount, sets > 0 {
                Label("\(sets) sets", systemImage: "flame")
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textTertiary)
            }
        }
    }
}

struct PostActionsRow: View {
    let post: Post
    @Binding var isLiked: Bool
    @Binding var showComments: Bool
    let onLearnThis: (() -> Void)?

    var body: some View {
        HStack(spacing: 20) {
            // Like
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isLiked.toggle()
                    post.likeCount += isLiked ? 1 : -1
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 20))
                        .foregroundColor(isLiked ? GQColors.deepBlue : GQColors.textTertiary)
                    if post.likeCount > 0 {
                        Text("\(post.likeCount)")
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textTertiary)
                    }
                }
            }
            .buttonStyle(.plain)

            // Comments
            Button {
                showComments = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 20))
                    if post.commentCount > 0 {
                        Text("\(post.commentCount)")
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textTertiary)
                    }
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(GQColors.textPrimary)

            // Learn This (if workout post)
            if let onLearn = onLearnThis {
                Button(action: onLearn) {
                    HStack(spacing: 4) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 13))
                        Text("Learn")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(GQColors.deepBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(GQColors.deepBlue.opacity(0.12))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Share
            Button {
                // Share action
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 20))
            }
            .buttonStyle(.plain)
            .foregroundColor(GQColors.textTertiary)
        }
        .padding(.top, 4)
    }
}

// MARK: - Enhanced Post Actions with Animations

struct PostActionsRowAnimated: View {
    let post: Post
    @Binding var isLiked: Bool
    @Binding var showComments: Bool
    let onLearnThis: (() -> Void)?
    var currentUserId: UUID = UUID()
    var currentUserName: String = ""

    @Environment(\.modelContext) private var modelContext
    @State private var heartScale: CGFloat = 1.0
    @State private var showParticles = false
    @State private var displayedLikeCount: Int = 0
    @State private var displayedCommentCount: Int = 0
    @State private var showReactionPicker = false
    @State private var sentReactionEmoji: String? = nil
    @State private var showSentReaction = false
    @State private var reactionCounts: [(ReactionType, Int)] = []

    var body: some View {
        HStack(spacing: 20) {
            // Animated Like Button with reaction picker
            ZStack(alignment: .top) {
                // Reaction picker overlay
                if showReactionPicker {
                    HStack(spacing: 8) {
                        ForEach(ReactionType.allCases, id: \.self) { reaction in
                            Button {
                                addReaction(reaction)
                                withAnimation(.spring(response: 0.2)) { showReactionPicker = false }
                            } label: {
                                Text(reaction.emoji)
                                    .font(.system(size: 24))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                    )
                    .offset(y: -44)
                    .transition(.scale(scale: 0.5, anchor: .bottom).combined(with: .opacity))
                    .zIndex(10)

                    // Nudge for resilient-emotion posts
                    if post.emotion?.sentimentCategory == .resilient {
                        Text("They showed up when it was hard — drop a reaction")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(GQColors.textSecondary.opacity(0.8))
                            .offset(y: -68)
                            .transition(.opacity)
                            .zIndex(9)
                    }
                }

                if showSentReaction, let emoji = sentReactionEmoji {
                    SentReactionOverlay(emoji: emoji)
                        .zIndex(11)
                }

                Button {
                    performLikeAnimation()
                } label: {
                    HStack(spacing: 6) {
                        ZStack {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 22))
                                .foregroundColor(isLiked ? GQColors.deepBlue : GQColors.textTertiary)
                                .scaleEffect(heartScale)

                            if showParticles {
                                HeartBurstOverlay(isActive: showParticles)
                            }
                        }

                        // Animated counter
                        if displayedLikeCount > 0 {
                            AnimatedCounter(value: displayedLikeCount)
                                .font(.system(size: 14))
                                .foregroundColor(GQColors.textTertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.4)
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                showReactionPicker.toggle()
                            }
                        }
                )
            }

            // Comments with animated counter
            Button {
                showComments = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 20))

                    if displayedCommentCount > 0 {
                        AnimatedCounter(value: displayedCommentCount)
                            .font(.system(size: 14))
                            .foregroundColor(GQColors.textTertiary)
                    }
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(GQColors.textPrimary)

            // Learn This (if workout post)
            if let onLearn = onLearnThis {
                Button(action: onLearn) {
                    HStack(spacing: 4) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 14))
                        Text("Learn")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(GQColors.deepBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(GQColors.deepBlue.opacity(0.12))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Share
            Button {
                // Share action
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 20))
            }
            .buttonStyle(.plain)
            .foregroundColor(GQColors.textTertiary)
        }
        .padding(.top, 4)
        .onAppear {
            displayedLikeCount = post.likeCount
            displayedCommentCount = post.commentCount
            checkIfLiked()
            fetchReactionCounts()
        }
    }

    private func fetchReactionCounts() {
        let postId = post.id
        let descriptor = FetchDescriptor<Reaction>(
            predicate: #Predicate { $0.targetId == postId && $0.targetType == "post" }
        )
        guard let reactions = try? modelContext.fetch(descriptor) else { return }
        var counts: [ReactionType: Int] = [:]
        for r in reactions {
            counts[r.reactionType, default: 0] += 1
        }
        reactionCounts = counts.sorted { $0.value > $1.value }
    }

    private func performLikeAnimation() {
        let wasLiked = isLiked

        // Toggle like state
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isLiked.toggle()
            post.likeCount += isLiked ? 1 : -1
        }

        // Persist the like/unlike to database
        if isLiked {
            // Create new Like record
            let like = Like(
                postId: post.id,
                userId: currentUserId,
                userName: currentUserName
            )
            modelContext.insert(like)
        } else {
            // Remove existing Like record
            let postId = post.id
            let userId = currentUserId
            let descriptor = FetchDescriptor<Like>(
                predicate: #Predicate { $0.postId == postId && $0.userId == userId }
            )
            if let existingLikes = try? modelContext.fetch(descriptor) {
                for like in existingLikes {
                    modelContext.delete(like)
                }
            }
        }
        try? modelContext.save()

        // Heart scale burst animation
        withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
            heartScale = 1.3
        }

        // Reset heart scale after burst
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                heartScale = 1.0
            }
        }

        // Show particles only when liking (not unliking)
        if !wasLiked {
            showParticles = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                showParticles = false
            }
        }

        // Update displayed count with animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            displayedLikeCount = post.likeCount
        }
    }

    private func checkIfLiked() {
        let postId = post.id
        let userId = currentUserId
        let descriptor = FetchDescriptor<Like>(
            predicate: #Predicate { $0.postId == postId && $0.userId == userId }
        )
        if let likes = try? modelContext.fetch(descriptor), !likes.isEmpty {
            isLiked = true
        }
    }

    private func addReaction(_ type: ReactionType) {
        // Prevent duplicate: check if same user already reacted with same type on this post
        let userId = currentUserId
        let postId = post.id
        let descriptor = FetchDescriptor<Reaction>(
            predicate: #Predicate { $0.odId == userId && $0.targetId == postId }
        )
        let matchingType = (try? modelContext.fetch(descriptor))?.filter { $0.reactionType == type } ?? []

        if !matchingType.isEmpty {
            let existing = matchingType
            // Toggle off: remove existing reaction
            for r in existing { modelContext.delete(r) }
            if isLiked { performLikeAnimation() }
            try? modelContext.save()
            reconcileLikeCount()
            fetchReactionCounts()
            return
        }

        let reaction = Reaction(
            odId: currentUserId,
            odUsername: currentUserName,
            targetType: "post",
            targetId: post.id,
            reactionType: type
        )
        modelContext.insert(reaction)

        // Also count as a like
        if !isLiked {
            performLikeAnimation()
        }
        try? modelContext.save()
        reconcileLikeCount()
        fetchReactionCounts()

        sentReactionEmoji = type.emoji
        showSentReaction = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(2200))
            showSentReaction = false
            sentReactionEmoji = nil
        }
    }

    private func reconcileLikeCount() {
        let postId = post.id
        let likeDescriptor = FetchDescriptor<Like>(
            predicate: #Predicate { $0.postId == postId }
        )
        let count = (try? modelContext.fetch(likeDescriptor))?.count ?? 0
        if post.likeCount != count {
            post.likeCount = count
            displayedLikeCount = count
        }
    }
}

// MARK: - Heart Particles Effect

struct HeartParticles: View {
    @State private var particles: [ParticleData] = []

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Image(systemName: "heart.fill")
                    .font(.system(size: particle.size))
                    .foregroundColor(particle.color)
                    .offset(x: particle.x, y: particle.y)
                    .opacity(particle.opacity)
            }
        }
        .onAppear {
            createParticles()
        }
    }

    private func createParticles() {
        // Create 6 particles in different directions
        for i in 0..<6 {
            let angle = Double(i) * 60.0 * .pi / 180.0
            let distance: CGFloat = CGFloat.random(in: 20...40)
            let colors: [Color] = [GQColors.deepBlue, GQColors.deepBlue.opacity(0.7), GQColors.deepBlue]
            let particle = ParticleData(
                id: UUID(),
                x: 0,
                y: 0,
                targetX: cos(angle) * distance,
                targetY: sin(angle) * distance,
                size: CGFloat.random(in: 6...10),
                color: colors.randomElement() ?? GQColors.deepBlue,
                opacity: 1.0
            )
            particles.append(particle)
        }

        // Animate particles outward
        withAnimation(.easeOut(duration: 0.4)) {
            for i in particles.indices {
                particles[i].x = particles[i].targetX
                particles[i].y = particles[i].targetY
                particles[i].opacity = 0
            }
        }
    }
}

struct ParticleData: Identifiable {
    let id: UUID
    var x: CGFloat
    var y: CGFloat
    let targetX: CGFloat
    let targetY: CGFloat
    let size: CGFloat
    let color: Color
    var opacity: Double
}

// MARK: - Animated Counter

struct AnimatedCounter: View {
    let value: Int

    var body: some View {
        Text("\(value)")
            .contentTransition(.numericText())
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: value)
    }
}


// MARK: - Coming Soon View

struct ComingSoonView: View {
    let feature: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)

            Image(systemName: "sparkles")
                .font(.system(size: 50))
                .foregroundColor(GQColors.deepBlue.opacity(0.5))

            Text("\(feature)")
                .font(.title3)
                .fontWeight(.semibold)

            Text("This feature is coming soon!")
                .font(.subheadline)
                .foregroundColor(GQColors.textTertiary)

            Spacer()
        }
        .padding()
    }
}


struct EmptyFeedState: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var onAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 80)

            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(GQGradients.primary)

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(GQColors.textPrimary)

                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundColor(GQColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let actionTitle, let onAction {
                Button {
                    onAction()
                } label: {
                    Text(actionTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(GQGradients.primary, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

struct EmptyFeedView: View {
    let onCreatePost: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 100)

            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.3))

            VStack(spacing: 8) {
                Text("No posts yet")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("Share your first post with the club")
                    .font(.subheadline)
                    .foregroundColor(GQColors.textTertiary)
                    .multilineTextAlignment(.center)
            }

            Button("Create Post") {
                onCreatePost()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.black)
            .frame(width: 160, height: 48)
            .background(Color.white)
            .cornerRadius(24)

            Spacer()
        }
        .padding()
    }
}

// each post in the feed - header, content, actions
struct PostCard: View {
    let post: Post
    let currentUserId: UUID
    @Environment(\.modelContext) private var modelContext

    @State private var isLiked = false
    @State private var showVideoPlayer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // header
            HStack(spacing: 12) {
                Circle()
                    .fill(LinearGradient(colors: [GQColors.deepBlue, GQColors.textSecondary], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Text(String(post.authorName.prefix(1)).uppercased())
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.authorName)
                        .font(.system(size: 15, weight: .semibold))
                    Text(post.timestamp.timeAgoDisplay())
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textTertiary)
                }

                Spacer()

                if let workoutType = post.workoutType {
                    Text(workoutType)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(GQColors.deepBlue.opacity(0.3))
                        .cornerRadius(12)
                }
            }

            // caption
            if !post.caption.isEmpty {
                Text(post.caption)
                    .font(.system(size: 15))
                    .lineSpacing(2)
            }

            // photo or video
            if let photoData = post.photoData {
                #if canImport(UIKit)
                if let uiImage = UIImage(data: photoData) {
                    Color.clear
                        .aspectRatio(4.0/5.2, contentMode: .fit)
                        .overlay(
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        )
                        .clipped()
                        .cornerRadius(12)
                }
                #elseif canImport(AppKit)
                if let nsImage = NSImage(data: photoData) {
                    Color.clear
                        .aspectRatio(4.0/5.2, contentMode: .fit)
                        .overlay(
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        )
                        .clipped()
                        .cornerRadius(12)
                }
                #endif
            } else if let videoData = post.videoData {
                InlineFeedVideoPlayer(videoData: videoData, showVideoPlayer: $showVideoPlayer)
            }

            // workout stats
            if post.duration != nil || post.setCount != nil {
                HStack(spacing: 20) {
                    if let duration = post.duration {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 14))
                            Text("\(duration) min")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(GQColors.textTertiary)
                    }

                    if let sets = post.setCount {
                        HStack(spacing: 6) {
                            Image(systemName: "flame")
                                .font(.system(size: 14))
                            Text("\(sets) sets")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(GQColors.textTertiary)
                    }
                }
            }

            // actions
            HStack(spacing: 24) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isLiked.toggle()
                        post.likeCount += isLiked ? 1 : -1
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 22))
                            .foregroundColor(isLiked ? GQColors.deepBlue : .white)
                        if post.likeCount > 0 {
                            Text("\(post.likeCount)")
                                .font(.system(size: 14))
                                .foregroundColor(GQColors.textTertiary)
                        }
                    }
                }
                .buttonStyle(.plain)

                Button {
                    // comments
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.right")
                            .font(.system(size: 20))
                        if post.commentCount > 0 {
                            Text("\(post.commentCount)")
                                .font(.system(size: 14))
                                .foregroundColor(GQColors.textTertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.white)

                Spacer()

                Button {
                    // share
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
                .foregroundColor(.white)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color(white: 0.08))
        .fullScreenCover(isPresented: $showVideoPlayer) {
            if let videoData = post.videoData {
                VideoPlayerView(videoData: videoData, isPresented: $showVideoPlayer)
            }
        }
    }
}

// AVPlayer needs a URL, so we write video data to temp file first
struct VideoPlayerView: View {
    let videoData: Data
    @Binding var isPresented: Bool
    @State private var player: AVPlayer?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                ProgressView()
                    .tint(.white)
            }

            // x button to close
            Button {
                player?.pause()
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
                    .padding()
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func setupPlayer() {
        // gotta write to temp file first - avplayer is picky
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
        do {
            try videoData.write(to: tempURL)
            player = AVPlayer(url: tempURL)
            player?.play()
        } catch {
            print("Error creating video: \(error)")
        }
    }
}

// MARK: - Full Screen Image View

// relative time display (2h, 3d, 1w) like instagram/twitter
extension Date {
    func timeAgoDisplay() -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day, .weekOfYear], from: self, to: now)

        if let weeks = components.weekOfYear, weeks > 0 {
            return weeks == 1 ? "1w" : "\(weeks)w"
        }
        if let days = components.day, days > 0 {
            return days == 1 ? "1d" : "\(days)d"
        }
        if let hours = components.hour, hours > 0 {
            return hours == 1 ? "1h" : "\(hours)h"
        }
        if let minutes = components.minute, minutes > 0 {
            return minutes == 1 ? "1m" : "\(minutes)m"
        }
        return "now"
    }
}


