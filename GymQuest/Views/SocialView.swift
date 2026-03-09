//
//  SocialView.swift
//  GymQuest
//
//  Social hub - discover new workouts, join clubs, and stay motivated.
//  Features: Discover feed, Club groups with challenges, and friends activity.
//

import SwiftUI
import SwiftData

struct SocialView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var featureFlags: FeatureFlags
    @Environment(\.modelContext) private var modelContext

    let profile: UserProfile

    @Query(sort: \Post.timestamp, order: .reverse) private var posts: [Post]
    @Query private var friends: [Friend]

    @State private var selectedSection: SocialSection = .discover
    @State private var showingCreatePost = false

    enum SocialSection: String, CaseIterable {
        case discover = "Discover"
        case club = "Club"
        case friends = "Friends"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Section Picker
                sectionPicker

                // Content
                ScrollView(showsIndicators: false) {
                    switch selectedSection {
                    case .discover:
                        discoverContent
                    case .club:
                        clubContent
                    case .friends:
                        friendsContent
                    }
                }
            }
            .gqPageBackground()
            .navigationTitle("Social")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreatePost = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(GQColors.textPrimary)
                    }
                }
            }
            .sheet(isPresented: $showingCreatePost) {
                LogWorkoutView(profile: profile)
            }
        }
    }

    // MARK: - Section Picker

    private var sectionPicker: some View {
        HStack(spacing: 0) {
            ForEach(SocialSection.allCases, id: \.self) { section in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSection = section
                    }
                } label: {
                    VStack(spacing: 8) {
                        Text(section.rawValue)
                            .font(.system(size: 14, weight: selectedSection == section ? .semibold : .medium))
                            .foregroundColor(selectedSection == section ? GQColors.textPrimary : GQColors.textTertiary)

                        Rectangle()
                            .fill(selectedSection == section ? GQColors.vividPurple : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .background(.ultraThinMaterial)
    }

    // MARK: - Discover Content

    private var discoverContent: some View {
        LazyVStack(spacing: 16) {
            // Featured workout of the day
            FeaturedWorkoutCard()
                .padding(.top, 8)

            // Trending section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("TRENDING NOW")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(GQColors.textTertiary)
                        .tracking(1)

                    Spacer()

                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        TrendingWorkoutCard(
                            title: "Push Day Pump",
                            author: "FitnessPro",
                            likes: 2340,
                            color: GQColors.vividPurple
                        )
                        TrendingWorkoutCard(
                            title: "5x5 Strength",
                            author: "IronMike",
                            likes: 1892,
                            color: GQColors.deepBlue
                        )
                        TrendingWorkoutCard(
                            title: "HIIT Burn",
                            author: "CardioQueen",
                            likes: 1654,
                            color: GQColors.cyanSpark
                        )
                    }
                }
            }

            // Discover posts
            VStack(alignment: .leading, spacing: 12) {
                Text("FOR YOU")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(1)

                ForEach(0..<5, id: \.self) { index in
                    DiscoverPostCard(index: index)
                }
            }
        }
        .padding(16)
    }

    // MARK: - Club Content

    private var clubContent: some View {
        LazyVStack(spacing: 20) {
            // Active Challenges Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.yellow)
                    Text("ACTIVE CHALLENGES")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(GQColors.textTertiary)
                        .tracking(1)
                }

                ClubGoalCard(
                    title: "30-Day Consistency",
                    description: "Work out at least 4 days per week",
                    progress: 0.6,
                    daysRemaining: 12,
                    participants: 234,
                    color: GQColors.vividPurple
                )

                ClubGoalCard(
                    title: "1000 Rep Challenge",
                    description: "Complete 1000 total reps this week",
                    progress: 0.35,
                    daysRemaining: 4,
                    participants: 89,
                    color: GQColors.cyanSpark
                )
            }
            .padding(.top, 8)

            // Your Clubs
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("YOUR CLUBS")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(GQColors.textTertiary)
                        .tracking(1)

                    Spacer()

                    Button {
                        // Browse all
                    } label: {
                        Text("See All")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(GQColors.cyanSpark)
                    }
                }

                ClubGroupCard(
                    name: "Morning Lifters",
                    members: 156,
                    activeChallenge: "5AM Club",
                    icon: "sunrise.fill",
                    color: .orange
                )

                ClubGroupCard(
                    name: "Strength Squad",
                    members: 89,
                    activeChallenge: "PR Week",
                    icon: "dumbbell.fill",
                    color: GQColors.vividPurple
                )
            }

            // Discover Clubs
            VStack(alignment: .leading, spacing: 12) {
                Text("DISCOVER CLUBS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(1)

                DiscoverClubCard(
                    name: "Cardio Crew",
                    members: 342,
                    description: "For runners, cyclists, and cardio lovers",
                    icon: "heart.fill",
                    color: .red
                )

                DiscoverClubCard(
                    name: "Home Gym Heroes",
                    members: 567,
                    description: "Making gains from home",
                    icon: "house.fill",
                    color: .green
                )

                DiscoverClubCard(
                    name: "Yoga & Mobility",
                    members: 234,
                    description: "Flexibility and recovery focused",
                    icon: "figure.mind.and.body",
                    color: .purple
                )
            }

            // Upcoming Challenges
            VStack(alignment: .leading, spacing: 12) {
                Text("UPCOMING CHALLENGES")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(1)

                UpcomingChallengeRow(
                    title: "February Fitness",
                    startsIn: "3 days",
                    icon: "calendar"
                )

                UpcomingChallengeRow(
                    title: "Spring Shred",
                    startsIn: "2 weeks",
                    icon: "flame"
                )
            }
        }
        .padding(16)
    }

    // MARK: - Friends Content

    private var friendsContent: some View {
        LazyVStack(spacing: 16) {
            if posts.isEmpty && friends.isEmpty {
                emptyFriendsState
            } else {
                // Friends Activity
                VStack(alignment: .leading, spacing: 12) {
                    Text("FRIEND ACTIVITY")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(GQColors.textTertiary)
                        .tracking(1)

                    if posts.isEmpty {
                        Text("No posts from friends yet")
                            .font(.system(size: 14))
                            .foregroundColor(GQColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(GQColors.adaptiveOverlay(0.03))
                            .cornerRadius(12)
                    } else {
                        ForEach(posts) { post in
                            FriendPostCard(post: post, profile: profile)
                        }
                    }
                }
            }
        }
        .padding(16)
    }

    private var emptyFriendsState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 48))
                .foregroundColor(GQColors.textTertiary)

            Text("Connect with friends")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(GQColors.textPrimary)

            Text("Add friends to see their workouts and cheer them on!")
                .font(.system(size: 14))
                .foregroundColor(GQColors.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                // Find friends
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                    Text("Find Friends")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [GQColors.vividPurple, GQColors.deepBlue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Featured Workout Card

struct FeaturedWorkoutCard: View {
    @State private var showFollowWorkout = false

    // Sample "Workout of the Day"
    private var sampleWorkout: SharedWorkoutData {
        SharedWorkoutData(
            title: "Full Body Strength Builder",
            workoutType: "Full Body",
            estimatedDuration: 45,
            exercises: [
                SharedWorkoutData.SharedExercise(
                    name: "Barbell Squat",
                    muscleGroup: "Legs",
                    sets: [
                        .init(reps: 10, weight: 135),
                        .init(reps: 8, weight: 155),
                        .init(reps: 6, weight: 175)
                    ]
                ),
                SharedWorkoutData.SharedExercise(
                    name: "Bench Press",
                    muscleGroup: "Chest",
                    sets: [
                        .init(reps: 10, weight: 95),
                        .init(reps: 8, weight: 115),
                        .init(reps: 6, weight: 135)
                    ]
                ),
                SharedWorkoutData.SharedExercise(
                    name: "Barbell Row",
                    muscleGroup: "Back",
                    sets: [
                        .init(reps: 10, weight: 95),
                        .init(reps: 8, weight: 115),
                        .init(reps: 8, weight: 115)
                    ]
                ),
                SharedWorkoutData.SharedExercise(
                    name: "Overhead Press",
                    muscleGroup: "Shoulders",
                    sets: [
                        .init(reps: 10, weight: 65),
                        .init(reps: 8, weight: 75),
                        .init(reps: 6, weight: 85)
                    ]
                ),
                SharedWorkoutData.SharedExercise(
                    name: "Romanian Deadlift",
                    muscleGroup: "Hamstrings",
                    sets: [
                        .init(reps: 10, weight: 135),
                        .init(reps: 10, weight: 135),
                        .init(reps: 10, weight: 135)
                    ]
                ),
                SharedWorkoutData.SharedExercise(
                    name: "Plank",
                    muscleGroup: "Core",
                    sets: [
                        .init(reps: 1, weight: 0),
                        .init(reps: 1, weight: 0),
                        .init(reps: 1, weight: 0)
                    ]
                )
            ],
            authorName: "Lift AI",
            authorUsername: "liftai",
            notes: "Rest 90 seconds between sets. Focus on form over weight."
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("WORKOUT OF THE DAY")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(GQColors.cyanSpark)
                    .tracking(1)

                Spacer()

                Image(systemName: "star.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.yellow)
            }

            Text("Full Body Strength Builder")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(GQColors.textPrimary)

            Text("A complete workout targeting all major muscle groups. Perfect for building a solid foundation.")
                .font(.system(size: 14))
                .foregroundColor(GQColors.textSecondary)
                .lineLimit(2)

            HStack(spacing: 16) {
                Label("45 min", systemImage: "clock")
                Label("Intermediate", systemImage: "flame")
                Label("6 exercises", systemImage: "list.bullet")
            }
            .font(.system(size: 12))
            .foregroundColor(GQColors.textTertiary)

            Button {
                showFollowWorkout = true
            } label: {
                Text("Try This Workout")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [GQColors.vividPurple, GQColors.deepBlue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(10)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [GQColors.vividPurple.opacity(0.2), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .background(GQColors.adaptiveOverlay(0.03))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(GQColors.vividPurple.opacity(0.3), lineWidth: 1)
        )
        .fullScreenCover(isPresented: $showFollowWorkout) {
            FollowWorkoutView(
                workoutData: sampleWorkout,
                profile: UserProfile()
            )
        }
    }
}

// MARK: - Trending Workout Card

struct TrendingWorkoutCard: View {
    let title: String
    let author: String
    let likes: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.2))
                    .frame(width: 140, height: 80)

                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 28))
                    .foregroundColor(color)
            }

            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(GQColors.textPrimary)
                .lineLimit(1)

            HStack(spacing: 4) {
                Text("@\(author)")
                    .font(.system(size: 11))
                    .foregroundColor(GQColors.textTertiary)

                Spacer()

                Image(systemName: "heart.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.red.opacity(0.7))
                Text("\(likes)")
                    .font(.system(size: 11))
                    .foregroundColor(GQColors.textTertiary)
            }
        }
        .frame(width: 140)
    }
}

// MARK: - Discover Post Card

struct DiscoverPostCard: View {
    let index: Int

    private let sampleUsers = ["Alex", "Jordan", "Sam", "Riley", "Casey"]
    private let sampleWorkouts = ["crushed leg day", "hit a new PR on bench", "finished a 5K run", "completed yoga session", "did 100 pushups"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author Header
            HStack(spacing: 10) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [GQColors.vividPurple, GQColors.cyanSpark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(sampleUsers[index % 5].prefix(1)))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(sampleUsers[index % 5])
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)

                    Text("\(Int.random(in: 1...12))h ago")
                        .font(.system(size: 12))
                        .foregroundColor(GQColors.textTertiary)
                }

                Spacer()

                Button {
                    // Follow
                } label: {
                    Text("Follow")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(GQColors.cyanSpark)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(GQColors.cyanSpark.opacity(0.15))
                        .cornerRadius(6)
                }
            }

            // Content
            Text("Just \(sampleWorkouts[index % 5])! Feeling great 💪")
                .font(.system(size: 15))
                .foregroundColor(GQColors.textPrimary)

            // Stats row
            HStack(spacing: 20) {
                Label("\(Int.random(in: 20...200))", systemImage: "heart")
                Label("\(Int.random(in: 5...30))", systemImage: "bubble.left")
            }
            .font(.system(size: 13))
            .foregroundColor(GQColors.textTertiary)
        }
        .padding(16)
        .background(GQColors.adaptiveOverlay(0.03))
        .cornerRadius(16)
    }
}

// MARK: - Club Challenge Card

struct ClubGoalCard: View {
    let title: String
    let description: String
    let progress: Double
    let daysRemaining: Int
    let participants: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)

                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(daysRemaining)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(color)
                    Text("days left")
                        .font(.system(size: 10))
                        .foregroundColor(GQColors.textTertiary)
                }
            }

            // Progress Bar
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(GQColors.adaptiveOverlay(0.06))

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [color, color.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(Int(progress * 100))% complete")
                        .font(.system(size: 11))
                        .foregroundColor(GQColors.textTertiary)

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 10))
                        Text("\(participants)")
                    }
                    .font(.system(size: 11))
                    .foregroundColor(GQColors.textTertiary)
                }
            }
        }
        .padding(16)
        .background(color.opacity(0.1))
        .background(GQColors.adaptiveOverlay(0.02))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Club Group Card

struct ClubGroupCard: View {
    let name: String
    let members: Int
    let activeChallenge: String
    let icon: String
    let color: Color
    var imageURL: String? = nil  // For custom group images

    var body: some View {
        HStack(spacing: 14) {
            // Group image - placeholder or custom
            RoundedRectangle(cornerRadius: 12)
                .fill(GQColors.adaptiveOverlay(0.05))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(GQColors.textTertiary)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)

                HStack(spacing: 8) {
                    Text("\(members) members")
                        .font(.system(size: 12))
                        .foregroundColor(GQColors.textTertiary)

                    if !activeChallenge.isEmpty {
                        Text("•")
                            .foregroundColor(GQColors.textTertiary)

                        Text(activeChallenge)
                            .font(.system(size: 12))
                            .foregroundColor(GQColors.textSecondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(GQColors.textTertiary)
        }
        .padding(14)
        .background(GQColors.adaptiveOverlay(0.03))
        .cornerRadius(12)
    }
}

// MARK: - Discover Club Card

struct DiscoverClubCard: View {
    let name: String
    let members: Int
    let description: String
    let icon: String
    let color: Color
    var imageURL: String? = nil  // For custom group images

    var body: some View {
        HStack(spacing: 12) {
            // Group image - placeholder or custom
            RoundedRectangle(cornerRadius: 10)
                .fill(GQColors.adaptiveOverlay(0.05))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(GQColors.textTertiary)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(GQColors.textPrimary)

                Text("\(members) members")
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textTertiary)
            }

            Spacer()

            Button {
                // Join
            } label: {
                Text("Join")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(GQColors.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(GQColors.adaptiveOverlay(0.06))
                    .cornerRadius(8)
            }
        }
        .padding(12)
        .background(GQColors.adaptiveOverlay(0.02))
        .cornerRadius(10)
    }
}

// MARK: - Upcoming Challenge Row

struct UpcomingChallengeRow: View {
    let title: String
    let startsIn: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(GQColors.cyanSpark)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(GQColors.textPrimary)

                Text("Starts in \(startsIn)")
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textTertiary)
            }

            Spacer()

            Button {
                // Remind me
            } label: {
                Image(systemName: "bell")
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.cyanSpark)
                    .padding(8)
                    .background(GQColors.cyanSpark.opacity(0.15))
                    .cornerRadius(8)
            }
        }
        .padding(14)
        .background(GQColors.adaptiveOverlay(0.02))
        .cornerRadius(10)
    }
}

// MARK: - Friend Post Card

struct FriendPostCard: View {
    let post: Post
    let profile: UserProfile

    @State private var isLiked = false
    @State private var likeCount: Int = 0
    @State private var showWorkoutDetail = false
    @State private var showFollowWorkout = false

    var sharedWorkout: SharedWorkoutData? {
        post.getSharedWorkout()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author Header
            HStack(spacing: 10) {
                Circle()
                    .fill(GQColors.vividPurple.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(post.authorName.prefix(1)).uppercased())
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.authorName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)

                    Text("@\(post.authorUsername) · \(post.timestamp.timeAgoShort())")
                        .font(.system(size: 12))
                        .foregroundColor(GQColors.textTertiary)
                }

                Spacer()

                Button {
                    // More options
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(GQColors.textTertiary)
                }
            }

            // Caption
            if !post.caption.isEmpty {
                Text(post.caption)
                    .font(.system(size: 15))
                    .foregroundColor(GQColors.textPrimary)
                    .lineLimit(4)
            }

            // Photo
            if let photoData = post.photoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .clipped()
                    .cornerRadius(12)
            }

            // Do This Workout button (if workout data available)
            if sharedWorkout != nil {
                Button {
                    showWorkoutDetail = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Do This Workout")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [GQColors.vividPurple.opacity(0.3), GQColors.deepBlue.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(GQColors.vividPurple.opacity(0.5), lineWidth: 1)
                    )
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }

            // Actions
            HStack(spacing: 24) {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        isLiked.toggle()
                        likeCount += isLiked ? 1 : -1
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? .red : GQColors.textTertiary)
                        Text("\(likeCount)")
                            .foregroundColor(GQColors.textTertiary)
                    }
                    .font(.system(size: 14))
                }

                Button {
                    // Comment
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left")
                        Text("0")
                    }
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.textTertiary)
                }

                Spacer()

                Button {
                    // Fist bump / cheer
                } label: {
                    Image(systemName: "hands.clap.fill")
                        .font(.system(size: 14))
                        .foregroundColor(GQColors.textTertiary)
                }
            }
        }
        .padding(16)
        .background(GQColors.adaptiveOverlay(0.03))
        .cornerRadius(16)
        .onAppear {
            likeCount = Int.random(in: 5...50)
        }
        .sheet(isPresented: $showWorkoutDetail) {
            if let workout = sharedWorkout {
                WorkoutDetailSheet(workoutData: workout) {
                    showWorkoutDetail = false
                    showFollowWorkout = true
                }
            }
        }
        .fullScreenCover(isPresented: $showFollowWorkout) {
            if let workout = sharedWorkout {
                FollowWorkoutView(
                    workoutData: workout,
                    profile: profile
                )
            }
        }
    }
}

// MARK: - Date Extension

extension Date {
    func timeAgoShort() -> String {
        let interval = Date().timeIntervalSince(self)
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)

        if days > 0 { return "\(days)d" }
        if hours > 0 { return "\(hours)h" }
        if minutes > 0 { return "\(minutes)m" }
        return "now"
    }
}

#Preview {
    SocialView(profile: UserProfile(name: "Ben", username: "ben"))
        .environmentObject(AppState())
        .environmentObject(FeatureFlags.shared)
}
