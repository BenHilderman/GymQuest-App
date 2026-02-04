//
//  ProfileView.swift
//  GymQuest
//
//  Created by Benjamin Hilderman
//
//  Bold & Energetic profile with glass morphism
//  Posts feed, level/XP stats, settings
//

import SwiftUI
import SwiftData
import AVKit

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Post.timestamp, order: .reverse) private var posts: [Post]

    let profile: UserProfile

    @State private var showingSettings = false
    @State private var selectedPost: Post?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Header
                    VStack(spacing: 20) {
                        // Avatar with gradient ring
                        ZStack {
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [GQColors.vividPurple, GQColors.cyanSpark],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 3
                                )
                                .frame(width: 90, height: 90)

                            Circle()
                                .fill(Color(white: 0.1))
                                .frame(width: 82, height: 82)

                            Text(String(profile.name.prefix(1)).uppercased())
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                        }

                        VStack(spacing: 6) {
                            Text(profile.name)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)

                            Text("@\(profile.username)")
                                .font(.system(size: 15))
                                .foregroundColor(GQColors.textTertiary)
                        }

                        // Stats Row
                        HStack(spacing: 0) {
                            ProfileStatItem(value: "\(posts.count)", label: "Workouts", color: GQColors.vividPurple)

                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 1, height: 36)

                            ProfileStatItem(value: "Lv.\(profile.level)", label: UserProfile.levelTitle(for: profile.level), color: GQColors.cyanSpark)
                        }
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(white: 0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    // Workout History Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Workout History")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)

                        if posts.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "figure.strengthtraining.traditional")
                                    .font(.system(size: 44))
                                    .foregroundColor(GQColors.textTertiary)

                                Text("No workouts yet")
                                    .font(.system(size: 16))
                                    .foregroundColor(GQColors.textTertiary)

                                Text("Log your first workout to start tracking!")
                                    .font(.system(size: 14))
                                    .foregroundColor(GQColors.textTertiary.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(white: 0.06))
                            )
                            .padding(.horizontal, 16)
                        } else {
                            // Workout history list
                            VStack(spacing: 8) {
                                ForEach(posts) { post in
                                    WorkoutHistoryRow(post: post)
                                        .onTapGesture {
                                            selectedPost = post
                                        }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.bottom, 120)
            }
            .background(Color(white: 0.05).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavBarLogo()
                }
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                }
                #endif
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingSettings) {
                SettingsView(profile: profile)
            }
            .sheet(item: $selectedPost) { post in
                PostDetailView(post: post, profile: profile)
            }
        }
    }
}

// MARK: - Profile Stat Item

struct ProfileStatItem: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Workout History Row

struct WorkoutHistoryRow: View {
    let post: Post

    var body: some View {
        HStack(spacing: 14) {
            // Date circle
            VStack(spacing: 2) {
                Text(post.timestamp.formatted(.dateTime.day()))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Text(post.timestamp.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.system(size: 11))
                    .foregroundColor(GQColors.textTertiary)
            }
            .frame(width: 44)

            // Workout info
            VStack(alignment: .leading, spacing: 4) {
                Text(post.workoutType ?? "Workout")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    if let duration = post.duration, duration > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                                .foregroundColor(GQColors.cyanSpark)
                            Text("\(duration) min")
                                .font(.system(size: 13))
                                .foregroundColor(GQColors.textSecondary)
                        }
                    }
                    if let sets = post.setCount, sets > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 11))
                                .foregroundColor(GQColors.success)
                            Text("\(sets) sets")
                                .font(.system(size: 13))
                                .foregroundColor(GQColors.textSecondary)
                        }
                    }
                }
            }

            Spacer()

            // Thumbnail if has photo
            #if canImport(UIKit)
            if let data = post.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)
            }
            #endif

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(GQColors.textTertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
        )
    }
}

// MARK: - Post Thumbnail (Grid style)

struct ProfilePostThumbnail: View {
    let post: Post

    var body: some View {
        ZStack {
            #if canImport(UIKit)
            if let data = post.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .clipped()
            } else if post.videoData != nil {
                Color(white: 0.1)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.8))
                    )
            } else {
                // No media - show workout type icon
                Color(white: 0.08)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        VStack(spacing: 6) {
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 24))
                                .foregroundColor(GQColors.vividPurple)
                            if let type = post.workoutType {
                                Text(type)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(GQColors.textTertiary)
                            }
                        }
                    )
            }
            #elseif canImport(AppKit)
            if let data = post.photoData, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .clipped()
            } else {
                Color(white: 0.08)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 24))
                            .foregroundColor(GQColors.vividPurple)
                    )
            }
            #endif
        }
        .cornerRadius(4)
    }
}

// MARK: - Profile Post Card (Grid card with stats)

struct ProfilePostCard: View {
    let post: Post

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image/Media area
            ZStack(alignment: .bottomLeading) {
                #if canImport(UIKit)
                if let data = post.photoData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 140)
                        .clipped()
                } else if post.videoData != nil {
                    Color(white: 0.1)
                        .frame(height: 140)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white.opacity(0.8))
                        )
                } else {
                    // No media - gradient background with icon
                    LinearGradient(
                        colors: [GQColors.vividPurple.opacity(0.3), GQColors.cyanSpark.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 140)
                    .overlay(
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.4))
                    )
                }
                #elseif canImport(AppKit)
                if let data = post.photoData, let image = NSImage(data: data) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 140)
                        .clipped()
                } else {
                    LinearGradient(
                        colors: [GQColors.vividPurple.opacity(0.3), GQColors.cyanSpark.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 140)
                    .overlay(
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.4))
                    )
                }
                #endif

                // Workout type badge overlay
                if let workoutType = post.workoutType {
                    Text(workoutType)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.6))
                        )
                        .padding(8)
                }
            }

            // Stats below image
            HStack(spacing: 12) {
                if let duration = post.duration, duration > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                            .foregroundColor(GQColors.cyanSpark)
                        Text("\(duration)m")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                }

                if let sets = post.setCount, sets > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11))
                            .foregroundColor(GQColors.success)
                        Text("\(sets)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                }

                Spacer()

                // Time ago
                Text(post.timestamp.timeAgoDisplay())
                    .font(.system(size: 11))
                    .foregroundColor(GQColors.textTertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(Color(white: 0.08))
        }
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

// shown when post has no photo/video - displays workout info visually
struct WorkoutStatsCard: View {
    let post: Post

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 40))
                .foregroundStyle(GQGradients.primary)
                .opacity(0.6)

            if let type = post.workoutType {
                Text(type)
                    .font(.headline)
                    .foregroundColor(.white)
            }

            HStack(spacing: 32) {
                if let duration = post.duration {
                    VStack(spacing: 4) {
                        Text("\(duration)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(GQColors.cyanSpark)
                        Text("min")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(GQColors.textTertiary)
                    }
                }
                if let sets = post.setCount {
                    VStack(spacing: 4) {
                        Text("\(sets)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(GQColors.success)
                        Text("sets")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(GQColors.textTertiary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .background(Color(white: 0.08))
    }
}

// full screen view of a post with all details
struct PostDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let post: Post
    let profile: UserProfile

    @State private var showVideoPlayer = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // header
                    HStack(spacing: 12) {
                        Circle()
                            .fill(GQGradients.primary)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Text(String(post.authorName.prefix(1)).uppercased())
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(post.authorName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            Text(post.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 13))
                                .foregroundColor(GQColors.textTertiary)
                        }

                        Spacer()

                        if let workoutType = post.workoutType {
                            Text(workoutType)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            Capsule()
                                                .stroke(GQColors.vividPurple.opacity(0.5), lineWidth: 1)
                                        )
                                )
                        }
                    }
                    .padding(.horizontal)

                    // media
                    #if canImport(UIKit)
                    if let data = post.photoData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .cornerRadius(12)
                            .padding(.horizontal)
                    } else if post.videoData != nil {
                        Button {
                            showVideoPlayer = true
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .frame(height: 250)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(GQGradients.glassBorder, lineWidth: 1)
                                    )
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundStyle(GQGradients.primary)
                            }
                        }
                        .padding(.horizontal)
                    }
                    #endif

                    // caption
                    if !post.caption.isEmpty {
                        Text(post.caption)
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .lineSpacing(4)
                            .padding(.horizontal)
                    }

                    // workout stats
                    if post.duration != nil || post.setCount != nil {
                        GlassCard(accentColor: GQColors.vividPurple, cornerRadius: 16, showGlow: false) {
                            HStack(spacing: 32) {
                                if let duration = post.duration {
                                    VStack(spacing: 4) {
                                        Text("\(duration)")
                                            .font(.system(size: 28, weight: .bold))
                                            .foregroundColor(GQColors.cyanSpark)
                                        Text("minutes")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(GQColors.textTertiary)
                                    }
                                }
                                if let sets = post.setCount {
                                    VStack(spacing: 4) {
                                        Text("\(sets)")
                                            .font(.system(size: 28, weight: .bold))
                                            .foregroundColor(GQColors.success)
                                        Text("sets")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(GQColors.textTertiary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .padding(.horizontal)
                    }

                    // engagement
                    HStack(spacing: 24) {
                        Label("\(post.likeCount) likes", systemImage: "heart.fill")
                            .foregroundColor(GQColors.vividPurple)
                        Label("\(post.commentCount) comments", systemImage: "bubble.right")
                            .foregroundColor(GQColors.textTertiary)
                        Spacer()
                    }
                    .font(.subheadline)
                    .padding(.horizontal)

                    Spacer().frame(height: 40)
                }
                .padding(.top)
            }
            .background(EnergyBackground())
            .navigationTitle("Post")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            #if canImport(UIKit)
            .fullScreenCover(isPresented: $showVideoPlayer) {
                if let videoData = post.videoData {
                    ProfileVideoPlayerView(videoData: videoData, isPresented: $showVideoPlayer)
                }
            }
            #endif
        }
    }
}

#if canImport(UIKit)
struct ProfileVideoPlayerView: View {
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
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
            do {
                try videoData.write(to: tempURL)
                player = AVPlayer(url: tempURL)
                player?.play()
            } catch {
                print("Error creating video: \(error)")
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}
#endif

// account settings - name, ai provider, api keys, logout
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState

    let profile: UserProfile

    @State private var name: String = ""
    @State private var username: String = ""
    @State private var aiProvider: AIProvider = .demo
    @State private var apiKey: String = ""
    @State private var ollamaModel: String = "llama3.2"
    @State private var showingLogoutAlert = false
    @State private var isTestingConnection = false
    @State private var connectionStatus: String?
    @State private var showingConnectionAlert = false

    @StateObject private var authService = AuthService()

    var body: some View {
        NavigationStack {
            List {
                Section("Profile") {
                    TextField("Name", text: $name)
                    TextField("Username", text: $username)
                }

                Section("Integrations") {
                    NavigationLink {
                        HealthKitSettingsView(profile: profile)
                    } label: {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                            Text("Apple Health")
                        }
                    }

                    NavigationLink {
                        SquadView(profile: profile)
                    } label: {
                        HStack {
                            Image(systemName: "person.3.fill")
                                .foregroundColor(.blue)
                            Text("Squads")
                        }
                    }

                    NavigationLink {
                        StravaSettingsView(profile: profile)
                    } label: {
                        HStack {
                            Image(systemName: "figure.run")
                                .foregroundColor(GQColors.cyanSpark)
                            Text("Strava")
                        }
                    }
                }

                Section("AI") {
                    Picker("Provider", selection: $aiProvider) {
                        ForEach(AIProvider.allCases, id: \.self) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .onChange(of: aiProvider) { _, newValue in
                        if newValue == .ollama {
                            testOllamaConnection()
                        }
                    }
                    if aiProvider == .ollama {
                        TextField("Model Name (e.g. llama3.2)", text: $ollamaModel)
                        Button {
                            testOllamaConnection()
                        } label: {
                            HStack {
                                if isTestingConnection {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Testing...")
                                } else {
                                    Image(systemName: "network")
                                    Text("Test Connection")
                                }
                            }
                        }
                        .disabled(isTestingConnection)
                    } else if aiProvider != .demo {
                        SecureField("API Key", text: $apiKey)
                    }
                }

                Section {
                    HStack {
                        Text("Level")
                        Spacer()
                        Text("\(profile.level)")
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Text("XP")
                        Spacer()
                        Text("\(profile.xp)")
                            .foregroundColor(.gray)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showingLogoutAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                            Spacer()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        profile.name = name
                        profile.username = username.isEmpty ? name.lowercased().replacingOccurrences(of: " ", with: "") : username
                        profile.aiProvider = aiProvider
                        profile.apiKey = apiKey
                        profile.ollamaModel = ollamaModel
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Sign Out", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authService.setModelContext(modelContext)
                    authService.logout(profile: profile)
                    dismiss()
                    appState.authState = .notAuthenticated
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Ollama Connection", isPresented: $showingConnectionAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(connectionStatus ?? "Unknown status")
            }
            .onAppear {
                name = profile.name
                username = profile.username
                aiProvider = profile.aiProvider
                apiKey = profile.apiKey
                ollamaModel = profile.ollamaModel
            }
        }
    }

    // pings local ollama server to verify connection works
    private func testOllamaConnection() {
        isTestingConnection = true

        Task {
            let ollamaHost = "192.168.2.48" // local network IP
            let urlString = "http://\(ollamaHost):11434/api/tags"

            guard let url = URL(string: urlString) else {
                await MainActor.run {
                    connectionStatus = "Invalid URL"
                    showingConnectionAlert = true
                    isTestingConnection = false
                }
                return
            }

            var request = URLRequest(url: url)
            request.timeoutInterval = 10

            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    await MainActor.run {
                        connectionStatus = "No response from Ollama"
                        showingConnectionAlert = true
                        isTestingConnection = false
                    }
                    return
                }

                if httpResponse.statusCode == 200 {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let models = json["models"] as? [[String: Any]] {
                        let modelNames = models.compactMap { $0["name"] as? String }
                        await MainActor.run {
                            if modelNames.isEmpty {
                                connectionStatus = "Connected! No models installed. Run: ollama pull llama3.2"
                            } else {
                                connectionStatus = "Connected! Available models: \(modelNames.joined(separator: ", "))"
                            }
                            showingConnectionAlert = true
                            isTestingConnection = false
                        }
                    } else {
                        await MainActor.run {
                            connectionStatus = "Connected to Ollama!"
                            showingConnectionAlert = true
                            isTestingConnection = false
                        }
                    }
                } else {
                    await MainActor.run {
                        connectionStatus = "Ollama returned error: \(httpResponse.statusCode)"
                        showingConnectionAlert = true
                        isTestingConnection = false
                    }
                }
            } catch {
                await MainActor.run {
                    connectionStatus = "Connection failed: \(error.localizedDescription)\n\nMake sure Ollama is running with:\nOLLAMA_HOST=0.0.0.0 ollama serve"
                    showingConnectionAlert = true
                    isTestingConnection = false
                }
            }
        }
    }
}

#Preview {
    ProfileView(profile: UserProfile())
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
