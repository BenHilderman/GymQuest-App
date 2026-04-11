//
//  ClubsView.swift
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

// MARK: - Club Seeder

struct ClubSeeder {
    static func seedIfNeeded(modelContext: ModelContext, userId: UUID) {
        let descriptor = FetchDescriptor<Club>(predicate: #Predicate { $0.parentClubId == nil })
        let existing = (try? modelContext.fetchCount(descriptor)) ?? 0

        let users = SocialSeeder.fakeUsers

        // Seed clubs + posts + challenges if first run
        if existing == 0 {
            seedClubs(modelContext: modelContext, userId: userId, users: users)
        }

        // Seed events separately so existing installs get them without data wipe
        let eventDescriptor = FetchDescriptor<ClubEvent>()
        let existingEvents = (try? modelContext.fetchCount(eventDescriptor)) ?? 0
        if existingEvents == 0 {
            seedEvents(modelContext: modelContext, userId: userId, users: users)
        }

        try? modelContext.save()
    }

    private static func seedClubs(modelContext: ModelContext, userId: UUID, users: [(id: UUID, name: String, username: String)]) {
        let cal = Calendar.current

        // Queen's Run Club
        let runClub = Club(
            name: "Queen's Run Club",
            clubDescription: "Weekly group runs around Kingston. All paces welcome.",
            location: "Kingston, ON",
            latitude: 44.2253,
            longitude: -76.4951,
            creatorId: users[0].id,
            memberIds: [userId] + users.prefix(6).map(\.id),
            joinType: .open,
            memberCount: 178,
            isVerified: true,
            tags: ["running", "cardio", "kingston"],
            category: .running
        )
        modelContext.insert(runClub)

        // Run Club channels
        for name in ["5K Group", "Long Distance", "Trail Runners"] {
            let channel = Club(
                name: name,
                clubDescription: "",
                creatorId: users[0].id,
                memberIds: [userId] + users.prefix(3).map(\.id),
                memberCount: Int.random(in: 20...60),
                parentClubId: runClub.id
            )
            modelContext.insert(channel)
        }

        // Kingston Pickup Basketball
        let basketball = Club(
            name: "Kingston Pickup Basketball",
            clubDescription: "Pickup games around Kingston. Drop in anytime.",
            location: "Kingston, ON",
            latitude: 44.2312,
            longitude: -76.4860,
            creatorId: users[1].id,
            memberIds: [userId] + users.prefix(5).map(\.id),
            joinType: .open,
            memberCount: 124,
            tags: ["basketball", "pickup", "kingston"],
            category: .basketball
        )
        modelContext.insert(basketball)

        for name in ["West End Courts", "Queen's Gym"] {
            let channel = Club(
                name: name,
                clubDescription: "",
                creatorId: users[1].id,
                memberIds: [userId] + users.prefix(2).map(\.id),
                memberCount: Int.random(in: 20...50),
                parentClubId: basketball.id
            )
            modelContext.insert(channel)
        }

        // Queen's Powerlifting
        let powerlifting = Club(
            name: "Queen's Powerlifting",
            clubDescription: "Squat, bench, deadlift. Compete or just train with us.",
            location: "Kingston, ON",
            latitude: 44.2280,
            longitude: -76.4935,
            creatorId: users[2].id,
            memberIds: [userId] + users.prefix(6).map(\.id),
            joinType: .open,
            memberCount: 156,
            isVerified: true,
            tags: ["powerlifting", "strength", "kingston"],
            category: .weightlifting
        )
        modelContext.insert(powerlifting)

        // Kingston Cycling Group
        let cycling = Club(
            name: "Kingston Cycling Group",
            clubDescription: "Road rides and gravel routes around the Kingston area.",
            location: "Kingston, ON",
            latitude: 44.2300,
            longitude: -76.4800,
            creatorId: users[3].id,
            memberIds: users.prefix(4).map(\.id),
            joinType: .open,
            memberCount: 92,
            tags: ["cycling", "road", "kingston"],
            category: .cycling
        )
        modelContext.insert(cycling)

        // Campus Yoga
        let yoga = Club(
            name: "Campus Yoga",
            clubDescription: "Free flow sessions on campus. Mats provided.",
            location: "Kingston, ON",
            latitude: 44.2260,
            longitude: -76.4970,
            creatorId: users[4].id,
            memberIds: users.prefix(5).map(\.id),
            joinType: .open,
            memberCount: 210,
            tags: ["yoga", "mindfulness", "kingston"],
            category: .yoga
        )
        modelContext.insert(yoga)

        // Queen's Intramural Soccer
        let soccer = Club(
            name: "Queen's Intramural Soccer",
            clubDescription: "Co-ed intramural soccer. Scrimmages every Thursday.",
            location: "Kingston, ON",
            latitude: 44.2240,
            longitude: -76.5010,
            creatorId: users[5].id,
            memberIds: users.prefix(4).map(\.id),
            joinType: .open,
            memberCount: 86,
            isVerified: true,
            tags: ["soccer", "intramural", "kingston"],
            category: .soccer
        )
        modelContext.insert(soccer)

        // Global clubs
        let homeGym = Club(
            name: "Home Gym Heroes",
            clubDescription: "For everyone training at home",
            creatorId: users[2].id,
            memberIds: users.prefix(4).map(\.id),
            joinType: .open,
            memberCount: 1420,
            tags: ["global"],
            category: .generalFitness
        )
        modelContext.insert(homeGym)

        let beginnerGains = Club(
            name: "Beginner Gains",
            clubDescription: "New to lifting? Start here",
            creatorId: users[6].id,
            memberIds: users.prefix(4).map(\.id),
            joinType: .open,
            memberCount: 3200,
            tags: ["global"],
            category: .weightlifting
        )
        modelContext.insert(beginnerGains)

        let prChasers = Club(
            name: "PR Chasers",
            clubDescription: "Chasing personal records every week",
            creatorId: users[7].id,
            memberIds: users.prefix(4).map(\.id),
            joinType: .open,
            memberCount: 890,
            tags: ["global"],
            category: .weightlifting
        )
        modelContext.insert(prChasers)

        // Seed memberships for user's clubs
        let userClubs = [runClub, basketball, powerlifting]
        for comm in userClubs {
            let userMembership = ClubMembership(
                userId: userId,
                clubId: comm.id,
                role: .member
            )
            modelContext.insert(userMembership)

            for (i, user) in users.prefix(6).enumerated() {
                guard comm.memberIds.contains(user.id) else { continue }
                let membership = ClubMembership(
                    userId: user.id,
                    clubId: comm.id,
                    role: i == 0 ? .admin : .member,
                    workoutPartnerStatus: [1, 2, 4].contains(i) ? .available : .notLooking
                )
                modelContext.insert(membership)
            }
        }

        // Seed challenges
        let runChallenge = ClubChallenge(
            clubId: runClub.id,
            title: "50km This Week",
            challengeDescription: "Log 50km of running before Sunday. Every km counts.",
            goalType: .distance,
            goalTarget: 50,
            currentProgress: 32,
            startDate: cal.date(byAdding: .day, value: -4, to: Date()) ?? Date(),
            endDate: cal.date(byAdding: .day, value: 3, to: Date()) ?? Date(),
            participantIds: [userId] + users.prefix(4).map(\.id)
        )
        modelContext.insert(runChallenge)

        let plChallenge = ClubChallenge(
            clubId: powerlifting.id,
            title: "Complete 20 Sets",
            challengeDescription: "Hit 20 total sets of squat, bench, or deadlift this week",
            goalType: .sets,
            goalTarget: 20,
            currentProgress: 13,
            startDate: cal.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
            endDate: cal.date(byAdding: .day, value: 4, to: Date()) ?? Date(),
            participantIds: [userId] + users.prefix(5).map(\.id)
        )
        modelContext.insert(plChallenge)

        let bbChallenge = ClubChallenge(
            clubId: basketball.id,
            title: "5 Pickup Games This Month",
            challengeDescription: "Show up to 5 pickup sessions this month",
            goalType: .games,
            goalTarget: 5,
            currentProgress: 2,
            startDate: cal.date(byAdding: .day, value: -10, to: Date()) ?? Date(),
            endDate: cal.date(byAdding: .day, value: 20, to: Date()) ?? Date(),
            participantIds: [userId] + users.prefix(3).map(\.id)
        )
        modelContext.insert(bbChallenge)

        // Seed club posts
        let samplePosts: [(UUID, Int, String, ClubPostType)] = [
            (runClub.id, 0, "New 5K PR this morning! 22:14. The waterfront route hits different at sunrise", .achievement),
            (runClub.id, 2, "Anyone want to pace me for a 10K this weekend?", .lookingForPartner),
            (basketball.id, 1, "Last night's pickup game was insane. That buzzer-beater shot was unreal", .general),
            (basketball.id, 3, "Looking for a 5th for Tuesday evening games at the ARC", .lookingForPartner),
            (powerlifting.id, 4, "Hit 315 deadlift today. New PR by 10 lbs!", .achievement),
            (powerlifting.id, 5, "The platform was empty at 6am. Rare W", .general),
            (soccer.id, 7, "Thursday scrimmage was a 4-3 thriller. See everyone next week", .general),
        ]

        for (cid, userIdx, content, ptype) in samplePosts {
            let user = users[userIdx]
            let post = ClubPost(
                clubId: cid,
                authorId: user.id,
                authorName: user.name,
                authorUsername: user.username,
                postType: ptype,
                content: content,
                likeCount: Int.random(in: 2...18),
                commentCount: Int.random(in: 0...5),
                timestamp: Date().addingTimeInterval(Double.random(in: -86400...0))
            )
            modelContext.insert(post)
        }

        // Posts for global clubs
        let globalClubs = [homeGym, beginnerGains, prChasers]
        let globalPosts: [(String, Int, String, ClubPostType)] = [
            ("Home Gym Heroes", 8, "Finally got a squat rack in my garage. Game changer", .achievement),
            ("Home Gym Heroes", 6, "Resistance bands + bodyweight = underrated combo", .workout),
            ("Beginner Gains", 9, "Just finished my first ever full week of training!", .achievement),
            ("Beginner Gains", 3, "What's the difference between sumo and conventional deadlift?", .question),
            ("PR Chasers", 4, "315 squat at 165 bodyweight. PR by 10 lbs!", .achievement),
        ]

        for (commName, userIdx, content, ptype) in globalPosts {
            if let comm = globalClubs.first(where: { $0.name == commName }) {
                let user = users[userIdx]
                let post = ClubPost(
                    clubId: comm.id,
                    authorId: user.id,
                    authorName: user.name,
                    authorUsername: user.username,
                    postType: ptype,
                    content: content,
                    likeCount: Int.random(in: 3...22),
                    commentCount: Int.random(in: 0...4),
                    timestamp: Date().addingTimeInterval(Double.random(in: -86400...0))
                )
                modelContext.insert(post)
            }
        }
    }

    private static func seedEvents(modelContext: ModelContext, userId: UUID, users: [(id: UUID, name: String, username: String)]) {
        let cal = Calendar.current
        let now = Date()

        let allComms = (try? modelContext.fetch(FetchDescriptor<Club>(predicate: #Predicate { $0.parentClubId == nil }))) ?? []
        guard let runClub = allComms.first(where: { $0.name == "Queen's Run Club" }),
              let basketball = allComms.first(where: { $0.name == "Kingston Pickup Basketball" }),
              let powerlifting = allComms.first(where: { $0.name == "Queen's Powerlifting" }),
              let cycling = allComms.first(where: { $0.name == "Kingston Cycling Group" }),
              let soccer = allComms.first(where: { $0.name == "Queen's Intramural Soccer" }) else { return }

        // Helper: next occurrence of a weekday at a given hour
        func nextWeekday(_ weekday: Int, hour: Int, minute: Int = 0) -> Date {
            var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear, .weekday], from: now)
            comps.weekday = weekday
            comps.hour = hour
            comps.minute = minute
            var target = cal.date(from: comps) ?? now
            if target <= now { target = cal.date(byAdding: .weekOfYear, value: 1, to: target) ?? target }
            return target
        }

        // Wednesday 5K Loop (Run Club, recurring weekly)
        let e1 = ClubEvent(
            clubId: runClub.id,
            creatorId: users[0].id,
            creatorName: users[0].name,
            title: "Wednesday 5K Loop",
            eventDescription: "Meet at the waterfront for a 5K group run. All paces welcome.",
            location: "Kingston Waterfront",
            date: nextWeekday(4, hour: 18),
            endDate: nextWeekday(4, hour: 19),
            maxAttendees: 30,
            attendeeIds: [userId, users[0].id, users[2].id, users[4].id],
            eventType: .groupRun,
            isRecurring: true,
            recurrenceRule: "weekly"
        )

        // Friday Night Hoops (Basketball, recurring weekly)
        let e2 = ClubEvent(
            clubId: basketball.id,
            creatorId: users[1].id,
            creatorName: users[1].name,
            title: "Friday Night Hoops",
            eventDescription: "Pickup basketball at the ARC. First 10 play, winners stay on.",
            location: "The ARC - Gymnasium",
            date: nextWeekday(6, hour: 19),
            endDate: nextWeekday(6, hour: 21),
            maxAttendees: 20,
            attendeeIds: [userId, users[1].id, users[3].id, users[5].id, users[7].id],
            eventType: .pickupGame,
            isRecurring: true,
            recurrenceRule: "weekly"
        )

        // Powerlifting Mock Meet
        let e3 = ClubEvent(
            clubId: powerlifting.id,
            creatorId: users[2].id,
            creatorName: users[2].name,
            title: "Powerlifting Mock Meet",
            eventDescription: "Squat, bench, deadlift. 3 attempts each. Friendly competition — all levels.",
            location: "The ARC - Platform Area",
            date: cal.date(byAdding: .day, value: 5, to: cal.startOfDay(for: now))!.addingTimeInterval(10 * 3600),
            endDate: cal.date(byAdding: .day, value: 5, to: cal.startOfDay(for: now))!.addingTimeInterval(14 * 3600),
            maxAttendees: 20,
            attendeeIds: [users[0].id, users[2].id, users[4].id, users[6].id, users[8].id],
            eventType: .competition
        )

        // Saturday Morning Ride (Cycling, recurring weekly)
        let e4 = ClubEvent(
            clubId: cycling.id,
            creatorId: users[3].id,
            creatorName: users[3].name,
            title: "Saturday Morning Ride",
            eventDescription: "50km road ride out to Gananoque and back. Moderate pace.",
            location: "Kingston City Hall",
            date: nextWeekday(7, hour: 7, minute: 30),
            endDate: nextWeekday(7, hour: 10),
            attendeeIds: [users[3].id, users[6].id],
            eventType: .groupRide,
            isRecurring: true,
            recurrenceRule: "weekly"
        )

        // Thursday Scrimmage (Soccer, recurring weekly)
        let e5 = ClubEvent(
            clubId: soccer.id,
            creatorId: users[5].id,
            creatorName: users[5].name,
            title: "Thursday Scrimmage",
            eventDescription: "Co-ed scrimmage on the turf field. Bring cleats.",
            location: "Queen's Turf Field",
            date: nextWeekday(5, hour: 18),
            endDate: nextWeekday(5, hour: 19, minute: 30),
            maxAttendees: 22,
            attendeeIds: [users[5].id, users[7].id, users[9].id],
            eventType: .scrimmage,
            isRecurring: true,
            recurrenceRule: "weekly"
        )

        // Past events
        let e6 = ClubEvent(
            clubId: runClub.id,
            creatorId: users[0].id,
            creatorName: users[0].name,
            title: "Sunrise 10K",
            eventDescription: "Early morning 10K along the waterfront trail.",
            location: "Kingston Waterfront",
            date: cal.date(byAdding: .day, value: -3, to: cal.startOfDay(for: now))!.addingTimeInterval(6 * 3600),
            endDate: cal.date(byAdding: .day, value: -3, to: cal.startOfDay(for: now))!.addingTimeInterval(7.5 * 3600),
            attendeeIds: [userId, users[0].id, users[2].id, users[4].id, users[6].id],
            eventType: .groupRun
        )

        let e7 = ClubEvent(
            clubId: basketball.id,
            creatorId: users[1].id,
            creatorName: users[1].name,
            title: "3v3 Tournament",
            eventDescription: "Single elimination 3v3 tournament. Prizes for winners.",
            location: "The ARC - Gymnasium",
            date: cal.date(byAdding: .day, value: -5, to: cal.startOfDay(for: now))!.addingTimeInterval(14 * 3600),
            attendeeIds: [users[1].id, users[3].id, users[5].id, users[7].id, users[9].id],
            eventType: .tournament
        )

        for event in [e1, e2, e3, e4, e5, e6, e7] {
            modelContext.insert(event)
        }
    }
}

// MARK: - Club Feed View (embedded in Feed tab)

enum ClubViewMode: String, CaseIterable {
    case list = "List"
    case map = "Map"
}

struct ClubFeedView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allClubs: [Club]
    @Query private var allClubPosts: [ClubPost]
    @Query private var allChallenges: [ClubChallenge]

    let profile: UserProfile

    @State private var showingCreateClub = false
    @State private var selectedClub: Club?
    @State private var selectedCategory: ClubCategory? = nil
    @State private var clubViewMode: ClubViewMode = .list
    @State private var searchText: String = ""
    @State private var selectedMapClub: Club? = nil

    // MARK: - Computed Properties

    private var topLevelClubs: [Club] {
        allClubs.filter { $0.parentClubId == nil }
    }

    private var yourClubs: [Club] {
        topLevelClubs.filter { $0.memberIds.contains(profile.id) }
    }

    private var recommendedClubs: [Club] {
        topLevelClubs.filter { !$0.memberIds.contains(profile.id) }
    }

    private var activeCategories: [ClubCategory] {
        let cats = Set(topLevelClubs.map { $0.resolvedCategory })
        return ClubCategory.allCases.filter { cats.contains($0) }
    }

    private func matchesSearch(_ club: Club) -> Bool {
        guard !searchText.isEmpty else { return true }
        let q = searchText.lowercased()
        return club.name.lowercased().contains(q)
            || (club.location?.lowercased().contains(q) ?? false)
            || club.resolvedCategory.rawValue.lowercased().contains(q)
    }

    private var searchFilteredYourClubs: [Club] {
        let clubs = yourClubs.filter { matchesSearch($0) }
        if let cat = selectedCategory {
            return clubs.filter { $0.resolvedCategory == cat }
        }
        return clubs
    }

    private var searchFilteredRecommended: [Club] {
        let clubs = recommendedClubs.filter { matchesSearch($0) }
        let filtered = selectedCategory == nil ? clubs : clubs.filter { $0.resolvedCategory == selectedCategory }
        return filtered.sorted { ($0.location != nil ? 0 : 1) < ($1.location != nil ? 0 : 1) }
    }

    private var featuredChallenge: ClubChallenge? {
        let myClubIds = Set(yourClubs.map(\.id))
        return allChallenges.first { myClubIds.contains($0.clubId) && $0.isActive }
    }

    private var allVisibleClubs: [Club] {
        topLevelClubs.filter { matchesSearch($0) }
    }

    private var clubsWithCoordinates: [Club] {
        let filtered = selectedCategory == nil ? allVisibleClubs : allVisibleClubs.filter { $0.resolvedCategory == selectedCategory }
        return filtered.filter { $0.latitude != nil && $0.longitude != nil }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                searchBar

                categoryAndToggleRow

                if clubViewMode == .list {
                    listModeContent
                } else {
                    mapModeContent
                }

                Spacer(minLength: 100)
            }
            .padding(.top, 8)
        }
        .scrollContentBackground(.hidden)
        .background(GQColors.background.ignoresSafeArea())
        .refreshable {
            // Pull-to-refresh triggers SwiftData @Query re-evaluation
            try? await Task.sleep(for: .milliseconds(300))
        }
        .onAppear {
            ClubSeeder.seedIfNeeded(modelContext: modelContext, userId: profile.id)
            try? ClubService.shared.evaluateClubHealth()
        }
        .sheet(isPresented: $showingCreateClub) {
            CreateClubSheet(profile: profile)
        }
        .sheet(item: $selectedClub) { club in
            ClubDetailView(club: club, profile: profile)
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.textTertiary)
                TextField("Search clubs...", text: $searchText)
                    .font(.system(size: 15))
                    .foregroundColor(GQColors.textPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(GQColors.adaptiveOverlay(0.08))
            .cornerRadius(12)

            viewModeToggle
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Category Pills + Toggle Row

    private var categoryAndToggleRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryPill(label: "All", icon: nil, isSelected: selectedCategory == nil) {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedCategory = nil }
                }
                ForEach(activeCategories, id: \.self) { cat in
                    categoryPill(label: cat.rawValue, icon: cat.icon, isSelected: selectedCategory == cat) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = selectedCategory == cat ? nil : cat
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var viewModeToggle: some View {
        HStack(spacing: 0) {
            viewModeButton(icon: "list.bullet", mode: .list)
            viewModeButton(icon: "map", mode: .map)
        }
        .background(GQColors.adaptiveOverlay(0.06))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func viewModeButton(icon: String, mode: ClubViewMode) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { clubViewMode = mode }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(clubViewMode == mode ? GQColors.textPrimary : GQColors.textTertiary)
                .frame(width: 32, height: 30)
                .background(clubViewMode == mode ? GQColors.adaptiveOverlay(0.12) : Color.clear)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - List Mode

    @ViewBuilder
    private var listModeContent: some View {
        yourClubHeroCard
            .padding(.horizontal, 16)
        featuredChallengeCard
            .padding(.horizontal, 16)
        myClubsSection
        nearbySection
        createClubButton
    }

    // MARK: - Your Club Hero Card

    @ViewBuilder
    private var yourClubHeroCard: some View {
        if let club = yourClubs.first {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    // Club icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(GQGradients.primary.opacity(0.08))
                            .frame(width: 48, height: 48)
                        Image(systemName: club.resolvedCategory.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(GQGradients.primary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(club.name)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(GQColors.textPrimary)
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 11))
                            Text("\(club.memberCount) members")
                                .font(.system(size: 13))
                        }
                        .foregroundColor(GQColors.textTertiary)
                    }

                    Spacer()
                }

                Button {
                    selectedClub = club
                } label: {
                    Text("Open Club")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(GQGradients.primary, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(GQColors.cardBackground)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(GQColors.borderDefault, lineWidth: 1))
            )
        }
    }

    // MARK: - Featured Challenge Card

    @ViewBuilder
    private var featuredChallengeCard: some View {
        if let challenge = featuredChallenge {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                    Text("Active Challenge")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                    Spacer()
                }

                Text(challenge.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(GQColors.textPrimary)

                if !challenge.challengeDescription.isEmpty {
                    Text(challenge.challengeDescription)
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textSecondary)
                        .lineLimit(2)
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(GQColors.surfaceOverlay)
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(GQGradients.primary)
                            .frame(width: geo.size.width * min(1.0, challenge.progress), height: 8)
                    }
                }
                .frame(height: 8)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(GQColors.cardBackground)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.3), lineWidth: 1))
            )
        }
    }

    // MARK: - My Clubs Section

    @ViewBuilder
    private var myClubsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "person.3.fill")
                    .foregroundStyle(GQGradients.primary)
                    .font(.system(size: 12))
                Text("MY CLUBS")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .tracking(1)

                Text("\(yourClubs.count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(GQColors.adaptiveOverlay(0.15))
                    .cornerRadius(10)

                Spacer()
            }
            .padding(.horizontal, 16)

            if searchFilteredYourClubs.isEmpty && !yourClubs.isEmpty {
                Text("No matching clubs")
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else if yourClubs.isEmpty {
                emptyClubsState
            } else {
                ForEach(searchFilteredYourClubs) { club in
                    clubCard(club)
                        .onTapGesture { selectedClub = club }
                }
            }
        }
    }

    @ViewBuilder
    private var emptyClubsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 30))
                .foregroundStyle(GQGradients.primary)
            Text("No Clubs Yet")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(GQColors.textPrimary)
            Text("Join a club to find your people and get matched into an accountability pod")
                .font(.system(size: 13))
                .foregroundColor(GQColors.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                withAnimation {
                    searchText = " "
                    searchText = ""
                }
            } label: {
                Text("Discover Clubs Below")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(GQColors.deepBlue)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(GQColors.deepBlue.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .homeSocialCard(cornerRadius: 14, subtle: true)
        .padding(.horizontal, 16)
    }

    // MARK: - Nearby / Discover Section

    @ViewBuilder
    private var nearbySection: some View {
        let hasNearby = searchFilteredRecommended.contains { $0.location != nil }
        let header = hasNearby ? "NEARBY" : "DISCOVER"

        if !searchFilteredRecommended.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: hasNearby ? "mappin.and.ellipse" : "sparkles")
                        .foregroundColor(GQColors.textSecondary)
                        .font(.system(size: 12))
                    Text(header)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(GQColors.textTertiary)
                        .tracking(1)
                    Spacer()
                }
                .padding(.horizontal, 16)

                ForEach(searchFilteredRecommended) { club in
                    recommendedClubCard(club)
                }
            }
        }
    }

    // MARK: - Map Mode

    @ViewBuilder
    private var mapModeContent: some View {
        ZStack(alignment: .bottom) {
            Map(initialPosition: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 44.225, longitude: -76.490),
                span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
            ))) {
                ForEach(clubsWithCoordinates) { club in
                    if let lat = club.latitude, let lng = club.longitude {
                        Annotation(club.name, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng)) {
                            mapPin(for: club)
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .preferredColorScheme(.dark)
            .frame(height: 420)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) { selectedMapClub = nil }
            }

            if let club = selectedMapClub {
                mapClubOverlay(club)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
        }
        .padding(.horizontal, 16)
        .animation(.easeInOut(duration: 0.25), value: selectedMapClub?.id)

        if clubsWithCoordinates.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "map")
                    .font(.system(size: 24))
                    .foregroundColor(GQColors.textTertiary)
                Text("No clubs with locations")
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }

    @ViewBuilder
    private func mapPin(for club: Club) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedMapClub = club }
        } label: {
            Circle()
                .fill(club.resolvedCategory.color)
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: club.resolvedCategory.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                )
                .shadow(color: club.resolvedCategory.color.opacity(0.4), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func mapClubOverlay(_ club: Club) -> some View {
        let isMember = club.memberIds.contains(profile.id)
        HStack(spacing: 12) {
            categoryIcon(for: club, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(club.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                        .lineLimit(1)
                    if club.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                            .foregroundColor(GQColors.textSecondary)
                    }
                }
                HStack(spacing: 6) {
                    Text(club.resolvedCategory.rawValue)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(club.resolvedCategory.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(club.resolvedCategory.color.opacity(0.15))
                        .cornerRadius(4)
                    if let loc = club.location {
                        Text(loc)
                            .font(.system(size: 11))
                            .foregroundColor(GQColors.textTertiary)
                    }
                    Text("•")
                        .font(.system(size: 10))
                        .foregroundColor(GQColors.textTertiary)
                    Text("\(club.memberCount)")
                        .font(.system(size: 11))
                        .foregroundColor(GQColors.textTertiary)
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 9))
                        .foregroundColor(GQColors.textTertiary)
                }
            }

            Spacer(minLength: 0)

            if isMember {
                Button { selectedClub = club } label: {
                    Text("View")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(GQColors.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(GQColors.textSecondary.opacity(0.12))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    withAnimation {
                        do {
                            try ClubService.shared.joinClub(clubId: club.id, userId: profile.id)
                        } catch {
                            print("Failed to join club: \(error.localizedDescription)")
                        }
                    }
                } label: {
                    Text("Join")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(GQColors.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(GQColors.textSecondary.opacity(0.12))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(14)
    }

    // MARK: - Shared Card Components

    private func accentedCard<Content: View>(
        accent: Color, @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accent)
                .frame(width: 3)
                .padding(.vertical, 8)
            content()
        }
        .homeSocialCard(cornerRadius: 14, subtle: true)
    }

    @ViewBuilder
    private func clubCard(_ club: Club) -> some View {
        accentedCard(accent: club.resolvedCategory.color) {
            HStack(spacing: 12) {
                #if canImport(UIKit)
                if let imageData = club.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                } else {
                    categoryIcon(for: club, size: 48)
                }
                #else
                categoryIcon(for: club, size: 48)
                #endif

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Text(club.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(GQColors.textPrimary)
                            .lineLimit(1)
                        if club.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                                .foregroundColor(GQColors.textSecondary)
                        }
                    }
                    HStack(spacing: 6) {
                        if let location = club.location {
                            Label(location, systemImage: "mappin")
                        } else {
                            Label("Online", systemImage: "globe")
                        }
                        Text("•")
                        Text("\(club.memberCount) members")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textTertiary)
            }
            .padding(14)
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func recommendedClubCard(_ club: Club) -> some View {
        HStack(spacing: 12) {
            categoryIcon(for: club, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(club.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                        .lineLimit(1)
                    if club.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11))
                            .foregroundColor(GQColors.textSecondary)
                    }
                }
                HStack(spacing: 6) {
                    if let location = club.location {
                        Label(location, systemImage: "mappin")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(GQColors.textSecondary)
                    } else {
                        Label("Online", systemImage: "globe")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(GQColors.textTertiary)
                    }
                    Text("•")
                        .font(.system(size: 10))
                        .foregroundColor(GQColors.textTertiary)
                    Text("\(club.memberCount) members")
                        .font(.system(size: 11))
                        .foregroundColor(GQColors.textTertiary)
                }
            }

            Spacer()

            Button(action: {
                withAnimation {
                    do {
                        try ClubService.shared.joinClub(clubId: club.id, userId: profile.id)
                    } catch {
                        print("Failed to join club: \(error.localizedDescription)")
                    }
                }
            }) {
                Text("Join")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(GQColors.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(GQColors.textSecondary.opacity(0.12))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .homeSocialCard(cornerRadius: 12, subtle: true)
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func categoryPill(label: String, icon: String?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                }
                Text(label)
            }
            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            .foregroundColor(isSelected ? GQColors.textPrimary : GQColors.textTertiary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(GQColors.adaptiveOverlay(isSelected ? 0.12 : 0.06))
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }

    private func categoryIcon(for club: Club, size: CGFloat) -> some View {
        let cat = club.resolvedCategory
        return Circle()
            .fill(GQColors.adaptiveOverlay(0.08))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: cat.icon)
                    .font(.system(size: size * 0.4))
                    .foregroundColor(GQColors.textSecondary.opacity(0.8))
            )
    }

    @ViewBuilder
    private var createClubButton: some View {
        Button(action: { showingCreateClub = true }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Create a Club")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(GQColors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(GQColors.adaptiveOverlay(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(GQColors.adaptiveOverlay(0.15), lineWidth: 1)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }
}

// MARK: - Club Preview Card (for empty state)

struct ClubPreviewCard: View {
    let name: String
    let members: Int
    let location: String
    let isVerified: Bool
    var category: ClubCategory = .generalFitness
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Circle()
                    .fill(category.color.opacity(0.15))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: category.icon)
                            .font(.system(size: 20))
                            .foregroundColor(category.color)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(GQColors.textPrimary)
                            .lineLimit(1)

                        if isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                                .foregroundColor(GQColors.textSecondary)
                        }
                    }

                    HStack(spacing: 8) {
                        Label("\(members)", systemImage: "person.2.fill")
                        Text("•")
                        Text(location)
                    }
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.textTertiary)
            }
            .padding(14)
            .homeSocialCard(cornerRadius: 12, subtle: true)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }
}

// MARK: - Club Card (for joined clubs)

struct ClubCard: View {
    let club: Club
    let profile: UserProfile

    var body: some View {
        let cat = club.resolvedCategory
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                if let imageData = club.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(cat.color.opacity(0.15))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: cat.icon)
                                .font(.system(size: 20))
                                .foregroundColor(cat.color)
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(club.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(GQColors.textPrimary)
                            .lineLimit(1)

                        if club.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                                .foregroundColor(GQColors.textSecondary)
                        }
                    }

                    HStack(spacing: 8) {
                        Label("\(club.memberCount)", systemImage: "person.2.fill")
                        if let location = club.location {
                            Text("•")
                            Text(location)
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.textTertiary)
            }

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(GQColors.deepBlue)
                        .frame(width: 6, height: 6)
                    Text("12 active today")
                        .font(.system(size: 11))
                        .foregroundColor(GQColors.textTertiary)
                }

                Spacer()

                Text("3 new posts")
                    .font(.system(size: 11))
                    .foregroundColor(GQColors.textSecondary)
            }
        }
        .padding(14)
        .homeSocialCard(cornerRadius: 12, subtle: true)
        .padding(.horizontal, 16)
    }
}

// MARK: - Create Club Sheet

struct CreateClubSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let profile: UserProfile

    @State private var name = ""
    @State private var description = ""
    @State private var location = ""
    @State private var joinType: ClubJoinType = .open
    @State private var category: ClubCategory = .generalFitness
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var clubImageData: Data?
    @State private var includeFirstChallenge = false
    @State private var challengeName = ""
    @State private var challengeTarget = 3

    var body: some View {
        NavigationStack {
            Form {
                Section("Club Image") {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Group {
                                #if canImport(UIKit)
                                if let clubImageData, let uiImage = UIImage(data: clubImageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(GQColors.adaptiveOverlay(0.08))
                                        .frame(width: 80, height: 80)
                                        .overlay(
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(GQColors.textTertiary)
                                        )
                                }
                                #else
                                Circle()
                                    .fill(GQColors.adaptiveOverlay(0.08))
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(GQColors.textTertiary)
                                    )
                                #endif
                            }
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                .onChange(of: selectedPhotoItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            clubImageData = data
                        }
                    }
                }

                Section("Club Info") {
                    TextField("Name (e.g., Queen's Run Club)", text: $name)
                    TextField("Location (optional)", text: $location)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Category") {
                    Picker("Activity Type", selection: $category) {
                        ForEach(ClubCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                        }
                    }
                }

                Section("Privacy") {
                    Picker("Who can join?", selection: $joinType) {
                        Text("Anyone (Open)").tag(ClubJoinType.open)
                        Text("Request to Join").tag(ClubJoinType.request)
                    }
                }

                Section("First Challenge (Optional)") {
                    Toggle("Set up a launch challenge", isOn: $includeFirstChallenge)

                    if includeFirstChallenge {
                        TextField("Challenge name", text: $challengeName)
                        Stepper("Weekly target: \(challengeTarget) workouts", value: $challengeTarget, in: 1...7)
                    }
                }

                Section {
                    Text("Clubs are great for running groups, pickup sports, lifting crews, and more. Members can share activity, find partners, and join meetups.")
                        .font(.footnote)
                        .foregroundColor(GQColors.textTertiary)
                }
            }
            .navigationTitle("Create Club")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createClub()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .alert("Error", isPresented: $showCreateError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(createError ?? "An unexpected error occurred.")
        }
    }

    @State private var createError: String?
    @State private var showCreateError = false

    private func createClub() {
        do {
            let club = try ClubService.shared.createClub(
                name: name,
                description: description,
                category: category,
                joinType: joinType,
                creatorId: profile.id
            )

            // Apply optional fields not handled by the service
            if !location.isEmpty {
                club.location = location
            }
            if let imageData = clubImageData {
                club.imageData = imageData
            }

            if includeFirstChallenge && !challengeName.isEmpty {
                let challenge = ClubChallenge(
                    clubId: club.id,
                    title: challengeName,
                    challengeDescription: "Complete \(challengeTarget) workouts per week",
                    goalType: .workouts,
                    goalTarget: challengeTarget
                )
                modelContext.insert(challenge)
                try? modelContext.save()
            }

            dismiss()
        } catch {
            createError = error.localizedDescription
            showCreateError = true
        }
    }
}

// MARK: - Search Clubs Sheet

struct SearchClubsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allClubs: [Club]

    let profile: UserProfile

    @State private var searchText = ""
    @State private var filterCategory: ClubCategory? = nil

    var filteredClubs: [Club] {
        var clubs = allClubs.filter { $0.parentClubId == nil }
        if let cat = filterCategory {
            clubs = clubs.filter { $0.resolvedCategory == cat }
        }
        if !searchText.isEmpty {
            clubs = clubs.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.location?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                $0.resolvedCategory.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }
        return clubs
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button {
                            filterCategory = nil
                        } label: {
                            Text("All")
                                .font(.system(size: 12, weight: filterCategory == nil ? .bold : .medium))
                                .foregroundColor(filterCategory == nil ? .white : GQColors.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(filterCategory == nil ? GQColors.deepBlue.opacity(0.4) : GQColors.adaptiveOverlay(0.08))
                                .cornerRadius(16)
                        }
                        .buttonStyle(.plain)

                        ForEach(ClubCategory.allCases, id: \.self) { cat in
                            Button {
                                filterCategory = filterCategory == cat ? nil : cat
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: cat.icon)
                                        .font(.system(size: 10))
                                    Text(cat.rawValue)
                                }
                                .font(.system(size: 12, weight: filterCategory == cat ? .bold : .medium))
                                .foregroundColor(filterCategory == cat ? .white : GQColors.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(filterCategory == cat ? cat.color.opacity(0.35) : GQColors.adaptiveOverlay(0.08))
                                .cornerRadius(16)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }

                List {
                    if filteredClubs.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(GQColors.textTertiary)
                            Text("No clubs found")
                                .font(.headline)
                                .foregroundColor(GQColors.textPrimary)
                            Text("Try a different search or create your own")
                                .font(.subheadline)
                                .foregroundColor(GQColors.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(filteredClubs) { club in
                            ClubSearchRow(
                                club: club,
                                isMember: club.memberIds.contains(profile.id),
                                onJoin: { joinClub(club) }
                            )
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search by name, location, or category")
            .navigationTitle("Find Clubs")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func joinClub(_ club: Club) {
        do {
            try ClubService.shared.joinClub(clubId: club.id, userId: profile.id)
        } catch {
            print("Failed to join club: \(error.localizedDescription)")
        }
    }
}

struct ClubSearchRow: View {
    let club: Club
    let isMember: Bool
    let onJoin: () -> Void

    var body: some View {
        let cat = club.resolvedCategory
        HStack(spacing: 12) {
            Circle()
                .fill(cat.color.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: cat.icon)
                        .font(.system(size: 18))
                        .foregroundColor(cat.color)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(club.name)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)

                    if club.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11))
                            .foregroundColor(GQColors.textSecondary)
                    }
                }

                HStack(spacing: 6) {
                    Text("\(club.memberCount) members")
                    if let location = club.location {
                        Text("•")
                        Text(location)
                    }
                }
                .font(.system(size: 12))
                .foregroundColor(GQColors.textTertiary)
            }

            Spacer()

            if isMember {
                Text("Joined")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(GQColors.textTertiary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            } else {
                Button(action: onJoin) {
                    Text(club.joinType == .open ? "Join" : "Request")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(GQColors.deepBlue)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .listRowBackground(Color.white.opacity(0.05))
    }
}

// MARK: - Club Detail View

enum ClubSection: String, CaseIterable {
    case feed = "Feed"
    case pods = "Pods"
    case challenges = "Challenges"
    case events = "Events"
    case members = "Members"
    // Leaderboard removed — memo directive: clubs are community, not ranking.
    // Squad-scale leaderboards still exist for opt-in small groups.
}

struct ClubDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var clubPosts: [ClubPost]
    @Query private var allClubs: [Club]
    @Query private var allChallenges: [ClubChallenge]
    @Query private var allMemberships: [ClubMembership]
    @Query private var allEvents: [ClubEvent]
    @Query private var allPods: [Pod]
    @Query private var allPodMemberships: [PodMembership]

    let club: Club
    let profile: UserProfile

    @State private var showingNewPost = false
    @State private var showingCreateEvent = false
    @State private var showingLeaveAlert = false
    @State private var selectedSection: ClubSection = .feed
    @State private var showPartnerOnly = false
    @State private var selectedChannelId: UUID? = nil
    @State private var clubServiceError: String?
    @State private var showClubServiceError = false

    private var isMember: Bool {
        club.memberIds.contains(profile.id)
    }

    private var posts: [ClubPost] {
        clubPosts
            .filter { post in
                post.clubId == club.id &&
                (selectedChannelId == nil || post.channelId == selectedChannelId)
            }
            .sorted { $0.timestamp > $1.timestamp }
    }

    private var channels: [Club] {
        allClubs.filter { $0.parentClubId == club.id }
    }

    private var activeChallenges: [ClubChallenge] {
        allChallenges.filter { $0.clubId == club.id && $0.isActive }
    }

    private var memberships: [ClubMembership] {
        allMemberships.filter { $0.clubId == club.id }
    }

    private var clubEvents: [ClubEvent] {
        allEvents.filter { $0.clubId == club.id }
            .sorted { $0.date < $1.date }
    }

    private var clubPods: [Pod] {
        allPods.filter { $0.clubId == club.id }
    }

    private var userPodInClub: Pod? {
        let userPodIds = Set(allPodMemberships.filter { $0.userId == profile.id }.map(\.podId))
        return clubPods.first { userPodIds.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    detailHeader
                    joinButton
                    howThisClubWorksCard
                    clubSectionPicker
                    sectionContent
                    Spacer(minLength: 40)
                }
            }
            .gqPageBackground()
            .preferredColorScheme(.dark)
            .navigationTitle("Club")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingNewPost) {
                NewClubPostSheet(club: club, profile: profile)
            }
            .alert("Leave Club", isPresented: $showingLeaveAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Leave", role: .destructive) {
                    leaveClub()
                }
            } message: {
                Text("Are you sure you want to leave \(club.name)?")
            }
            .sheet(isPresented: $showingCreateEvent) {
                CreateEventSheet(club: club, profile: profile)
            }
            .alert("Error", isPresented: $showClubServiceError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(clubServiceError ?? "An unexpected error occurred.")
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var detailHeader: some View {
        let cat = club.resolvedCategory
        VStack(spacing: 12) {
            #if canImport(UIKit)
            if let imageData = club.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 88, height: 88)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(cat.color, lineWidth: 3)
                    )
            } else {
                Circle()
                    .fill(cat.color.opacity(0.15))
                    .frame(width: 88, height: 88)
                    .overlay(
                        Image(systemName: cat.icon)
                            .font(.system(size: 36))
                            .foregroundColor(cat.color)
                    )
                    .overlay(
                        Circle()
                            .stroke(cat.color.opacity(0.3), lineWidth: 2)
                    )
            }
            #else
            Circle()
                .fill(cat.color.opacity(0.15))
                .frame(width: 88, height: 88)
                .overlay(
                    Image(systemName: cat.icon)
                        .font(.system(size: 36))
                        .foregroundColor(cat.color)
                )
                .overlay(
                    Circle()
                        .stroke(cat.color.opacity(0.3), lineWidth: 2)
                )
            #endif

            HStack(spacing: 4) {
                Text(club.name)
                    .font(.title2)
                    .fontWeight(.bold)

                if club.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(GQColors.textSecondary)
                }
            }

            if !club.clubDescription.isEmpty {
                Text(club.clubDescription)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            HStack(spacing: 20) {
                VStack {
                    Text("\(club.memberCount)")
                        .font(.headline)
                    Text("Members")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                if let location = club.location {
                    VStack {
                        Image(systemName: "mappin.circle.fill")
                            .font(.headline)
                        Text(location)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding(.top, 12)
    }

    // MARK: - Join Button

    @ViewBuilder
    private var joinButton: some View {
        if !isMember {
            Button {
                do {
                    try ClubService.shared.joinClub(clubId: club.id, userId: profile.id)
                } catch {
                    clubServiceError = error.localizedDescription
                    showClubServiceError = true
                }
            } label: {
                Text(club.isOpen ? "Join Club" : "Request to Join")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [GQColors.deepBlue.opacity(0.6), GQColors.textSecondary.opacity(0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
        } else if club.pendingRequestIds.contains(profile.id) {
            Text("Request Pending")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
                .padding(.horizontal, 16)
        } else if isMember && club.creatorId != profile.id {
            Button {
                showingLeaveAlert = true
            } label: {
                Text("Leave Club")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(GQColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(GQColors.textSecondary.opacity(0.1))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(GQColors.textSecondary.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Who's Working Out

    @ViewBuilder
    private var workingOutNowRow: some View {
        let users = SocialSeeder.fakeUsers
        let activeNames: [String] = club.memberIds.compactMap { memberId in
            guard let user = users.first(where: { $0.id == memberId }) else { return nil }
            let hash = abs(memberId.hashValue)
            guard hash % 3 == 0 else { return nil }
            return user.name
        }.prefix(4).map { $0 }
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Circle()
                    .fill(GQColors.deepBlue)
                    .frame(width: 8, height: 8)
                Text("WHO'S WORKING OUT")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(1)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(activeNames, id: \.self) { name in
                        VStack(spacing: 6) {
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Text(String(name.prefix(1)))
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                )
                                .overlay(
                                    Circle()
                                        .fill(GQColors.deepBlue)
                                        .frame(width: 12, height: 12)
                                        .overlay(Circle().stroke(Color.black, lineWidth: 2))
                                        .offset(x: 15, y: 15)
                                )
                            Text(name)
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                        .frame(width: 60)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Channels

    @ViewBuilder
    private var channelCards: some View {
        if !channels.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("CHANNELS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(1)
                    .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        // "All" pill to clear channel filter
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                selectedChannelId = nil
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "rectangle.grid.2x2")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(selectedChannelId == nil ? .white : GQColors.textSecondary)
                                Text("All")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(selectedChannelId == nil ? .white : .white.opacity(0.7))
                                    .lineLimit(1)
                                Text("\(posts.count) posts")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 110, height: 80)
                            .background(selectedChannelId == nil ? GQColors.deepBlue.opacity(0.3) : Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedChannelId == nil ? GQColors.deepBlue.opacity(0.5) : GQColors.textSecondary.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)

                        ForEach(channels) { channel in
                            let isSelected = selectedChannelId == channel.id
                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    selectedChannelId = isSelected ? nil : channel.id
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: "number")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(isSelected ? .white : GQColors.textSecondary)
                                    Text(channel.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                                        .lineLimit(1)
                                    Text("\(channel.memberCount) members")
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray)
                                }
                                .frame(width: 110, height: 80)
                                .background(isSelected ? GQColors.deepBlue.opacity(0.3) : Color.white.opacity(0.06))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isSelected ? GQColors.deepBlue.opacity(0.5) : GQColors.textSecondary.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Active Challenge Cards

    @ViewBuilder
    private var challengeCards: some View {
        ForEach(activeChallenges) { challenge in
            challengeCardView(challenge: challenge)
        }
    }

    @ViewBuilder
    private func challengeCardView(challenge: ClubChallenge) -> some View {
        let isJoined = challenge.participantIds.contains(profile.id)

        VStack(alignment: .leading, spacing: 12) {
            challengeCardHeader(challenge: challenge)
            challengeCardProgress(challenge: challenge)
            challengeJoinButton(challenge: challenge, isJoined: isJoined)
        }
        .padding(14)
        .homeSocialCard(cornerRadius: 14, subtle: true)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func challengeCardHeader(challenge: ClubChallenge) -> some View {
        HStack {
            Image(systemName: "trophy.fill")
                .foregroundColor(GQColors.textSecondary)
            Text("ACTIVE CHALLENGE")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(GQColors.textTertiary)
                .tracking(1)
            Spacer()
            Text("\(challenge.daysRemaining)d left")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(GQColors.textSecondary)
        }

        Text(challenge.title)
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
    }

    @ViewBuilder
    private func challengeCardProgress(challenge: ClubChallenge) -> some View {
        AnimatedProgressBar(
            progress: challenge.progress,
            height: 8,
            colors: [GQColors.deepBlue, GQColors.textSecondary]
        )

        HStack {
            Text("\(challenge.currentProgress) / \(challenge.goalTarget) \(challenge.goalType.rawValue.lowercased())")
                .font(.system(size: 12))
                .foregroundColor(.gray)
            Spacer()
            Text("\(challenge.participantIds.count) participating")
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
    }

    @ViewBuilder
    private func challengeJoinButton(challenge: ClubChallenge, isJoined: Bool) -> some View {
        if isMember {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    if isJoined {
                        challenge.participantIds.removeAll { $0 == profile.id }
                    } else {
                        challenge.participantIds.append(profile.id)
                    }
                    try? modelContext.save()
                }
                #if canImport(UIKit)
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                #endif
            } label: {
                challengeJoinButtonLabel(isJoined: isJoined)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func challengeJoinButtonLabel(isJoined: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: isJoined ? "checkmark.circle.fill" : "flame.fill")
                .font(.system(size: 13))
            Text(isJoined ? "Joined" : "Join Challenge")
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            isJoined
                ? AnyShapeStyle(GQColors.elevatedSurface)
                : AnyShapeStyle(LinearGradient(colors: [GQColors.deepBlue, GQColors.textSecondary], startPoint: .leading, endPoint: .trailing))
        )
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isJoined ? GQColors.borderDefault : Color.clear, lineWidth: 1)
        )
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        if isMember {
            HStack(spacing: 12) {
                Button { showingNewPost = true } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Post")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(GQColors.deepBlue)
                    .cornerRadius(10)
                }

                Button {
                    selectedSection = .members
                    showPartnerOnly = true
                } label: {
                    HStack {
                        Image(systemName: "person.2.fill")
                        Text("Find Partner")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(GQColors.textSecondary)
                    .cornerRadius(10)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
        }
    }

    // MARK: - How This Club Works

    @ViewBuilder
    private var howThisClubWorksCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(GQGradients.primary)
                Text("How This Club Works")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("Join challenges to compete with other members", systemImage: "trophy")
                Label("Get matched into a pod for weekly accountability", systemImage: "person.3.fill")
                Label("Share workouts and celebrate milestones together", systemImage: "hands.clap.fill")
            }
            .font(.system(size: 13))
            .foregroundColor(GQColors.textSecondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(GQColors.deepBlue.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(GQColors.borderDefault, lineWidth: 1))
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Section Picker

    @ViewBuilder
    private var clubSectionPicker: some View {
        HStack(spacing: 0) {
            ForEach(ClubSection.allCases, id: \.self) { section in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSection = section
                        if section != .members { showPartnerOnly = false }
                    }
                } label: {
                    Text(section.rawValue)
                        .font(.system(size: 13, weight: selectedSection == section ? .bold : .medium))
                        .foregroundColor(selectedSection == section ? .white : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedSection == section ? GQColors.deepBlue.opacity(0.2) : Color.clear
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
        .padding(.horizontal, 16)
    }

    // MARK: - Section Content

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .feed:
            VStack(spacing: 16) {
                workingOutNowRow
                channelCards
                actionButtons
                clubFeedSection
            }
        case .pods:
            clubPodsSection
        case .challenges:
            clubChallengesSection
        case .events:
            clubEventsSection
        case .members:
            clubMembersSection
        }
    }

    // MARK: - Pods Section

    @ViewBuilder
    private var clubPodsSection: some View {
        VStack(spacing: 16) {
            // User's current pod in this club
            if let myPod = userPodInClub {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "target")
                            .foregroundStyle(GQGradients.primary)
                        Text("Your Pod")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(GQColors.textPrimary)
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(myPod.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(GQColors.textPrimary)

                        Text("\(myPod.memberCount)/\(myPod.maxMembers) members · \(myPod.weeklyWorkoutTarget)×/week target · \(myPod.streakWeeks) week streak")
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textSecondary)

                        if !myPod.summary.isEmpty {
                            Text(myPod.summary)
                                .font(.system(size: 13))
                                .foregroundColor(GQColors.textTertiary)
                        }
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(GQColors.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(GQColors.borderDefault, lineWidth: 1)
                        )
                )
            }

            // Other pods in this club
            let otherPods = clubPods.filter { $0.id != userPodInClub?.id }
            if otherPods.isEmpty && userPodInClub == nil {
                VStack(spacing: 10) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 30))
                        .foregroundColor(GQColors.textTertiary)
                    Text("No Pods Yet")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(GQColors.textSecondary)
                    Text("Pods are small accountability groups. Create one to get started.")
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                ForEach(otherPods, id: \.id) { pod in
                    podRow(pod)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func podRow(_ pod: Pod) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 16))
                .foregroundStyle(GQGradients.primary)
                .frame(width: 36, height: 36)
                .background(GQColors.deepBlue.opacity(0.1), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(pod.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)

                Text("\(pod.memberCount)/\(pod.maxMembers) · \(pod.podLevel.rawValue) · \(pod.weeklyWorkoutTarget)×/wk")
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textSecondary)
            }

            Spacer()

            if !pod.isFull && !pod.memberIds.contains(profile.id) {
                Button("Join") {
                    pod.memberIds.append(profile.id)
                    let membership = PodMembership(podId: pod.id, userId: profile.id)
                    modelContext.insert(membership)
                    try? modelContext.save()
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(GQGradients.primary, in: Capsule())
            } else if pod.isFull {
                Text("Full")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(GQColors.textTertiary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(GQColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(GQColors.borderDefault, lineWidth: 1)
                )
        )
    }

    // MARK: - Challenges Tab Section

    @ViewBuilder
    private var clubChallengesSection: some View {
        if activeChallenges.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "trophy")
                    .font(.system(size: 30))
                    .foregroundColor(GQColors.textTertiary)
                Text("No active challenges")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)
                Text("Check back soon for new challenges")
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
        } else {
            challengeCards
        }
    }

    // MARK: - Events Section

    @ViewBuilder
    private var clubEventsSection: some View {
        VStack(spacing: 12) {
            if isMember {
                Button {
                    showingCreateEvent = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Create Event")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [GQColors.deepBlue, GQColors.textSecondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
            }

            let upcoming = clubEvents.filter { $0.date > Date() }
            if upcoming.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 30))
                        .foregroundColor(GQColors.textTertiary)
                    Text("No upcoming events")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(GQColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                ForEach(upcoming) { event in
                    ClubEventCard(event: event, userId: profile.id, modelContext: modelContext)
                }
                .padding(.horizontal, 16)
            }

            let past = clubEvents.filter { $0.date <= Date() }
            if !past.isEmpty {
                Text("PAST EVENTS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(0.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                ForEach(past.reversed().prefix(5)) { event in
                    ClubEventCard(event: event, userId: profile.id, modelContext: modelContext)
                        .opacity(0.6)
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Feed Section

    @ViewBuilder
    private var clubFeedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if posts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("No posts yet")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("Be the first to share something!")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(posts) { post in
                    ClubPostCard(post: post)
                }
            }
        }
    }

    // MARK: - Leaderboard Section

    @ViewBuilder
    private var clubLeaderboardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("THIS WEEK")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(GQColors.textTertiary)
                .tracking(1)
                .padding(.horizontal, 16)

            ForEach(Array(leaderboardData.enumerated()), id: \.offset) { index, entry in
                HStack(spacing: 12) {
                    Text("#\(index + 1)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(medalColor(for: index))
                        .frame(width: 32)

                    Circle()
                        .fill(GQGradients.primary)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text(String(entry.name.prefix(1)))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text("\(entry.sets) sets")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Text("\(entry.points) pts")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(GQColors.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(index < 3 ? Color.white.opacity(0.04) : Color.clear)
                .cornerRadius(10)
            }

            // Exercise Leaderboard link
            NavigationLink {
                LeaderboardView(clubId: club.id)
            } label: {
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(GQColors.textSecondary)
                    Text("Exercise Leaderboard")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.06))
                .cornerRadius(12)
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Members Section

    @ViewBuilder
    private var clubMembersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(club.memberCount) MEMBERS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(1)

                Spacer()

                Button {
                    withAnimation { showPartnerOnly.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showPartnerOnly ? "person.2.fill" : "person.2")
                            .font(.system(size: 11))
                        Text("Looking for Partner")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(showPartnerOnly ? GQColors.textSecondary : .gray)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(showPartnerOnly ? GQColors.textSecondary.opacity(0.15) : Color.white.opacity(0.05))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            let displayed = showPartnerOnly
                ? memberData.filter { $0.lookingForPartner }
                : memberData

            ForEach(displayed, id: \.name) { member in
                HStack(spacing: 12) {
                    Circle()
                        .fill(GQGradients.primary)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text(String(member.name.prefix(1)))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(member.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)

                        HStack(spacing: 6) {
                            Text(member.role)
                                .font(.system(size: 12))
                                .foregroundColor(.gray)

                            if member.lookingForPartner {
                                Text("Looking for partner")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(GQColors.textSecondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(GQColors.textSecondary.opacity(0.15))
                                    .cornerRadius(4)
                            }
                        }
                    }

                    Spacer()

                    if member.isOnline {
                        Circle()
                            .fill(GQColors.textSecondary)
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .contextMenu {
                    if member.id != profile.id {
                        // Admin actions (admins can remove members and promote)
                        if club.adminIds.contains(profile.id) && club.creatorId != member.id {
                            Button {
                                do {
                                    try ClubService.shared.removeMember(clubId: club.id, userId: member.id, adminId: profile.id)
                                } catch {
                                    clubServiceError = error.localizedDescription
                                    showClubServiceError = true
                                }
                            } label: {
                                Label("Remove Member", systemImage: "person.badge.minus")
                            }

                            if !club.adminIds.contains(member.id) {
                                Button {
                                    do {
                                        try ClubService.shared.promoteToAdmin(clubId: club.id, userId: member.id, adminId: profile.id)
                                    } catch {
                                        clubServiceError = error.localizedDescription
                                        showClubServiceError = true
                                    }
                                } label: {
                                    Label("Promote to Admin", systemImage: "star")
                                }
                            }
                        }

                        // Owner-only: transfer ownership
                        if club.creatorId == profile.id {
                            Button {
                                do {
                                    try ClubService.shared.transferOwnership(clubId: club.id, newOwnerId: member.id, currentOwnerId: profile.id)
                                } catch {
                                    clubServiceError = error.localizedDescription
                                    showClubServiceError = true
                                }
                            } label: {
                                Label("Transfer Ownership", systemImage: "arrow.right.arrow.left")
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Data

    private var leaderboardData: [(name: String, sets: Int, workouts: Int, points: Int)] {
        let users = SocialSeeder.fakeUsers
        return club.memberIds.compactMap { memberId in
            guard let user = users.first(where: { $0.id == memberId }) else { return nil }
            // Deterministic stats from UUID hash
            let hash = abs(memberId.hashValue)
            let sets = 20 + (hash % 30)
            let workouts = 2 + (hash % 5)
            let points = sets * 5
            return (name: user.name, sets: sets, workouts: workouts, points: points)
        }
        .sorted { $0.points > $1.points }
    }

    private var memberData: [(id: UUID, name: String, role: String, isOnline: Bool, lookingForPartner: Bool)] {
        let users = SocialSeeder.fakeUsers
        return club.memberIds.compactMap { memberId in
            guard let user = users.first(where: { $0.id == memberId }) else { return nil }
            let membership = memberships.first(where: { $0.userId == memberId })
            let role = membership?.role ?? .member
            let hash = abs(memberId.hashValue)
            let isOnline = hash % 3 != 0
            let lookingForPartner = membership?.workoutPartnerStatus == .available
            return (id: memberId, name: user.name, role: role.rawValue.capitalized, isOnline: isOnline, lookingForPartner: lookingForPartner)
        }
    }

    private func medalColor(for index: Int) -> Color {
        switch index {
        case 0: return GQColors.textSecondary
        case 1: return Color(white: 0.75)
        case 2: return GQColors.textSecondary
        default: return GQColors.textTertiary
        }
    }

    private func leaveClub() {
        do {
            try ClubService.shared.leaveClub(clubId: club.id, userId: profile.id)
            dismiss()
        } catch {
            clubServiceError = error.localizedDescription
            showClubServiceError = true
        }
    }
}

// MARK: - Club Post Card

struct ClubPostCard: View {
    let post: ClubPost
    @State private var liked: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 10) {
                Circle()
                    .fill(GQGradients.primary)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(post.authorName.prefix(1)).uppercased())
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.authorName)
                        .font(.system(size: 14, weight: .semibold))
                    Text(post.timestamp.timeAgoDisplay())
                        .font(.system(size: 11))
                        .foregroundColor(GQColors.textTertiary)
                }

                Spacer()

                // Post type badge
                HStack(spacing: 4) {
                    Image(systemName: post.postType.icon)
                        .font(.system(size: 10))
                    Text(post.postType.rawValue)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(GQColors.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(GQColors.textSecondary.opacity(0.15))
                .cornerRadius(6)
            }

            // Content
            Text(post.content)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.9))

            // Actions
            HStack(spacing: 20) {
                Button {
                    liked.toggle()
                    post.likeCount += liked ? 1 : -1
                    #if canImport(UIKit)
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    #endif
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: liked ? "heart.fill" : "heart")
                        if post.likeCount > 0 {
                            Text("\(post.likeCount)")
                        }
                    }
                    .font(.system(size: 13))
                    .foregroundColor(liked ? GQColors.deepBlue : GQColors.textTertiary)
                }

                Button {
                    // Comment
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                        if post.commentCount > 0 {
                            Text("\(post.commentCount)")
                        }
                    }
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textTertiary)
                }

                Spacer()
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
}

// MARK: - New Club Post Sheet

struct NewClubPostSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let club: Club
    let profile: UserProfile

    @State private var content = ""
    @State private var postType: ClubPostType = .general

    var body: some View {
        NavigationStack {
            Form {
                Section("Post Type") {
                    Picker("Type", selection: $postType) {
                        ForEach(ClubPostType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                }

                Section("What's on your mind?") {
                    TextField("Share with the club...", text: $content, axis: .vertical)
                        .lineLimit(4...10)
                }
            }
            .navigationTitle("New Post")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        createPost()
                    }
                    .disabled(content.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func createPost() {
        let post = ClubPost(
            clubId: club.id,
            authorId: profile.id,
            authorName: profile.name,
            authorUsername: profile.username,
            postType: postType,
            content: content
        )
        modelContext.insert(post)
        try? modelContext.save()
        dismiss()
    }
}


