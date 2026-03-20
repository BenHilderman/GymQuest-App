//
//  PostAccessoriesView.swift
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

// MARK: - Post Tags Row (Shows tagged users, location, squads)

struct PostTagsRow: View {
    let post: Post

    var hasAnyTags: Bool {
        !post.taggedUsernames.isEmpty ||
        post.locationName != nil ||
        !post.taggedSquadIds.isEmpty ||
        post.spotifyPlaylistURL != nil ||
        post.appleMusicPlaylistURL != nil
    }

    var body: some View {
        if hasAnyTags {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Tagged users
                    ForEach(post.taggedUsernames, id: \.self) { username in
                        PostTagBadge(
                            icon: "at",
                            text: username,
                            color: GQColors.textSecondary
                        )
                    }

                    // Location
                    if let location = post.locationName {
                        PostTagBadge(
                            icon: "location.fill",
                            text: location,
                            color: GQColors.textSecondary
                        )
                    }

                    // Squads
                    ForEach(Array(zip(post.taggedSquadIds, post.taggedSquadNames)), id: \.0) { _, squadName in
                        PostTagBadge(
                            icon: "person.3.fill",
                            text: squadName,
                            color: GQColors.deepBlue
                        )
                    }

                    // Spotify playlist link
                    if let spotifyURLString = post.spotifyPlaylistURL, let url = URL(string: spotifyURLString) {
                        Button {
                            #if canImport(UIKit)
                            UIApplication.shared.open(url)
                            #endif
                        } label: {
                            PostTagBadge(
                                icon: "music.note",
                                text: "Spotify Playlist",
                                color: Color(hex: "1DB954")
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // Apple Music playlist link
                    if let appleMusicURLString = post.appleMusicPlaylistURL, let url = URL(string: appleMusicURLString) {
                        Button {
                            #if canImport(UIKit)
                            UIApplication.shared.open(url)
                            #endif
                        } label: {
                            PostTagBadge(
                                icon: "music.note",
                                text: "Apple Music",
                                color: Color(hex: "FC3C44")
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Emotion Badge

struct EmotionBadge: View {
    let emotion: WorkoutEmotion
    var likeCount: Int = 0

    var body: some View {
        HStack(spacing: 6) {
            Text(emotion.emoji)
                .font(.system(size: 14))
            Text(emotion.encouragement)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.7))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.08))
        )
    }
}

// MARK: - Post Tag Badge

struct PostTagBadge: View {
    let icon: String
    let text: String
    var color: Color = .white

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))

            Text(text)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
        }
        .foregroundColor(Color.white.opacity(0.6))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.08))
        .cornerRadius(14)
    }
}

// MARK: - Exercise Media Carousel (for posts with exercise-specific media)

struct ExerciseMediaCarousel: View {
    let mediaItems: [PostMedia]
    @State private var selectedIndex = 0

    var body: some View {
        if !mediaItems.isEmpty {
            VStack(spacing: 8) {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(mediaItems.enumerated()), id: \.element.id) { index, media in
                        ZStack(alignment: .bottomLeading) {
                            // Media content
                            if let data = media.data, let image = UIImage(data: data) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .clipShape(Rectangle())
                            }

                            // Video indicator
                            if media.mediaType == .video {
                                VStack {
                                    HStack {
                                        Spacer()
                                        Image(systemName: "play.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.white)
                                            .shadow(radius: 4)
                                            .padding(12)
                                    }
                                    Spacer()
                                }
                            }
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .aspectRatio(4.0/5.2, contentMode: .fit)

            }
        }
    }
}

// MARK: - Club Event Card

struct ClubEventCard: View {
    let event: ClubEvent
    let userId: UUID
    let modelContext: ModelContext

    private var isAttending: Bool {
        event.attendeeIds.contains(userId)
    }

    private var isFull: Bool {
        if let max = event.maxAttendees {
            return event.attendeeIds.count >= max
        }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: event.eventType.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(event.eventType.color)
                    .frame(width: 32, height: 32)
                    .background(event.eventType.color.opacity(0.15))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text(event.eventType.rawValue)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(event.eventType.color)
                }

                Spacer()

                Button {
                    toggleRSVP()
                } label: {
                    Text(isAttending ? "Going" : (isFull ? "Full" : "RSVP"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(isAttending ? .white : GQColors.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(isAttending ? GQColors.textSecondary : GQColors.textSecondary.opacity(0.15))
                        .cornerRadius(16)
                }
                .buttonStyle(.plain)
                .disabled(isFull && !isAttending)
            }

            if !event.eventDescription.isEmpty {
                Text(event.eventDescription)
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textSecondary)
                    .lineLimit(2)
            }

            // Recurring indicator
            if event.isRecurring, let rule = event.recurrenceRule {
                HStack(spacing: 4) {
                    Image(systemName: "repeat")
                        .font(.system(size: 10))
                    Text("Repeats \(rule)")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(GQColors.textSecondary)
            }

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                    Text(event.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(GQColors.textTertiary)

                if let location = event.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.system(size: 11))
                        Text(location)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(GQColors.textTertiary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 11))
                    if let max = event.maxAttendees {
                        Text("\(event.attendeeIds.count)/\(max)")
                    } else {
                        Text("\(event.attendeeIds.count)")
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func toggleRSVP() {
        if isAttending {
            event.attendeeIds.removeAll { $0 == userId }
        } else {
            event.attendeeIds.append(userId)
        }
        try? modelContext.save()
    }
}

// MARK: - Create Event Sheet

struct CreateEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let club: Club
    let profile: UserProfile

    @State private var title = ""
    @State private var eventDescription = ""
    @State private var location = ""
    @State private var eventDate = Date().addingTimeInterval(86400)
    @State private var eventType: ClubEventType = .workout
    @State private var maxAttendeesText = ""
    @State private var isRecurring = false
    @State private var recurrenceRule = "weekly"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("EVENT TYPE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                            .tracking(0.5)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(ClubEventType.allCases, id: \.self) { type in
                                    Button {
                                        eventType = type
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: type.icon)
                                            Text(type.rawValue)
                                        }
                                        .font(.system(size: 13, weight: eventType == type ? .bold : .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(eventType == type ? type.color.opacity(0.3) : Color.white.opacity(0.08))
                                        .cornerRadius(20)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(eventType == type ? type.color.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("TITLE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                            .tracking(0.5)
                        TextField("Event name", text: $title)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("DESCRIPTION")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                            .tracking(0.5)
                        TextField("What's the event about?", text: $eventDescription, axis: .vertical)
                            .lineLimit(3...5)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("LOCATION")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                            .tracking(0.5)
                        TextField("Where? (optional)", text: $location)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("DATE & TIME")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                            .tracking(0.5)
                        DatePicker("", selection: $eventDate, in: Date()...)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(GQColors.textSecondary)
                    }

                    // Recurring toggle
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(isOn: $isRecurring) {
                            HStack(spacing: 6) {
                                Image(systemName: "repeat")
                                    .font(.system(size: 13))
                                    .foregroundColor(GQColors.textSecondary)
                                Text("Recurring Event")
                                    .font(.system(size: 14, weight: .medium))
                            }
                        }
                        .tint(GQColors.textSecondary)

                        if isRecurring {
                            Picker("Frequency", selection: $recurrenceRule) {
                                Text("Weekly").tag("weekly")
                                Text("Biweekly").tag("biweekly")
                                Text("Monthly").tag("monthly")
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("MAX ATTENDEES")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                            .tracking(0.5)
                        TextField("Leave empty for unlimited", text: $maxAttendeesText)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                    }

                    Button {
                        createEvent()
                    } label: {
                        HStack {
                            Image(systemName: "calendar.badge.plus")
                            Text("Create Event")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
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
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("New Event")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func createEvent() {
        let event = ClubEvent(
            clubId: club.id,
            creatorId: profile.id,
            creatorName: profile.name,
            title: title.trimmingCharacters(in: .whitespaces),
            eventDescription: eventDescription.trimmingCharacters(in: .whitespaces),
            location: location.isEmpty ? nil : location.trimmingCharacters(in: .whitespaces),
            date: eventDate,
            maxAttendees: Int(maxAttendeesText),
            attendeeIds: [profile.id],
            eventType: eventType,
            isRecurring: isRecurring,
            recurrenceRule: isRecurring ? recurrenceRule : nil
        )

        modelContext.insert(event)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Emoji Burst Overlay

struct SentReactionOverlay: View {
    let emoji: String

    @State private var animate = false

    var body: some View {
        ZStack {
            Text(emoji)
                .font(.system(size: 36))
                .scaleEffect(animate ? 0.5 : 1.4)
                .opacity(animate ? 0 : 1)
                .offset(y: animate ? -80 : 0)

            Text(emoji)
                .font(.system(size: 24))
                .scaleEffect(animate ? 0.4 : 0.9)
                .opacity(animate ? 0 : 0.6)
                .offset(x: 16, y: animate ? -60 : 5)
                .animation(.easeOut(duration: 1.2).delay(0.15), value: animate)
        }
        .animation(.easeOut(duration: 1.2), value: animate)
        .allowsHitTesting(false)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                animate = true
            }
        }
    }
}

struct EmojiBurstOverlay: View {
    let emoji: String
    let isActive: Bool

    private struct FloatingEmoji: Identifiable {
        let id = UUID()
        let xPosition: CGFloat
        let startY: CGFloat
        let size: CGFloat
        let delay: Double
        let driftX: CGFloat
    }

    @State private var emojis: [FloatingEmoji] = []
    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(emojis) { e in
                    Text(emoji)
                        .font(.system(size: e.size))
                        .opacity(appeared ? 0.35 : 0)
                        .offset(
                            x: e.xPosition * geo.size.width - geo.size.width / 2 + (appeared ? e.driftX : 0),
                            y: e.startY * geo.size.height - geo.size.height / 2 + (appeared ? -20 : 0)
                        )
                        .animation(
                            .easeOut(duration: 2.5).delay(e.delay),
                            value: appeared
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            guard isActive else { return }
            emojis = (0..<3).map { _ in
                FloatingEmoji(
                    xPosition: CGFloat.random(in: 0.15...0.85),
                    startY: CGFloat.random(in: 0.3...0.7),
                    size: CGFloat.random(in: 18...24),
                    delay: Double.random(in: 0...0.6),
                    driftX: CGFloat.random(in: -8...8)
                )
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                appeared = true
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Chat Bubble Shape

struct ChatBubbleShape: InsettableShape {
    let isFromCurrentUser: Bool

    func path(in rect: CGRect) -> Path {
        let corners: RectangleCornerRadii
        if isFromCurrentUser {
            corners = RectangleCornerRadii(topLeading: 18, bottomLeading: 18, bottomTrailing: 4, topTrailing: 18)
        } else {
            corners = RectangleCornerRadii(topLeading: 18, bottomLeading: 4, bottomTrailing: 18, topTrailing: 18)
        }
        return UnevenRoundedRectangle(cornerRadii: corners).path(in: rect)
    }

    func inset(by amount: CGFloat) -> some InsettableShape {
        self
    }
}

