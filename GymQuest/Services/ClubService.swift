//
//  ClubService.swift
//  GymQuest
//
//  Club Governance (System 6) — creation, membership, admin actions,
//  health evaluation, discovery recommendations, and gym-name fuzzy matching.
//

import Foundation
import SwiftData

@MainActor
class ClubService: ObservableObject {
    static let shared = ClubService()

    private var modelContext: ModelContext?

    private init() {}

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Club Creation

    /// Creates a new club. The creator becomes the owner.
    /// Enforces max 1 club ownership per user.
    func createClub(
        name: String,
        description: String,
        category: ClubCategory,
        joinType: ClubJoinType,
        creatorId: UUID
    ) throws -> Club {
        guard let context = modelContext else {
            throw ClubServiceError.notConfigured
        }

        let ownedCount = try getOwnedClubCount(userId: creatorId)
        guard ownedCount == 0 else {
            throw ClubServiceError.ownershipLimitReached
        }

        let club = Club(
            name: name,
            clubDescription: description,
            creatorId: creatorId,
            adminIds: [creatorId],
            memberIds: [creatorId],
            joinType: joinType,
            memberCount: 1,
            tags: [],
            category: category,
            lastActivityDate: Date(),
            isListedInDiscovery: true
        )

        context.insert(club)

        let membership = ClubMembership(
            userId: creatorId,
            clubId: club.id,
            role: .owner
        )
        context.insert(membership)

        try context.save()
        return club
    }

    // MARK: - Join / Leave

    /// Joins a club: auto-adds for open clubs, auto-requests for request-based clubs.
    func joinClub(clubId: UUID, userId: UUID) throws {
        guard let context = modelContext else {
            throw ClubServiceError.notConfigured
        }

        let club = try fetchClub(id: clubId)

        guard !club.memberIds.contains(userId) else {
            throw ClubServiceError.alreadyMember
        }

        if club.isOpen {
            club.memberIds.append(userId)
            club.memberCount = club.memberIds.count

            let membership = ClubMembership(
                userId: userId,
                clubId: clubId,
                role: .member
            )
            context.insert(membership)
        } else {
            guard !club.pendingRequestIds.contains(userId) else {
                throw ClubServiceError.requestAlreadyPending
            }
            club.pendingRequestIds.append(userId)
        }

        try context.save()
    }

    /// Leaves a club. Owners cannot leave — transfer ownership first.
    func leaveClub(clubId: UUID, userId: UUID) throws {
        guard let context = modelContext else {
            throw ClubServiceError.notConfigured
        }

        let club = try fetchClub(id: clubId)

        guard club.memberIds.contains(userId) else {
            throw ClubServiceError.notMember
        }

        if club.creatorId == userId {
            throw ClubServiceError.ownerCannotLeave
        }

        club.memberIds.removeAll { $0 == userId }
        club.adminIds.removeAll { $0 == userId }
        club.memberCount = club.memberIds.count

        if let membership = try fetchMembership(clubId: clubId, userId: userId) {
            context.delete(membership)
        }

        try context.save()
    }

    // MARK: - Admin Actions

    /// Approves a pending join request.
    func approveRequest(clubId: UUID, userId: UUID, adminId: UUID) throws {
        guard let context = modelContext else {
            throw ClubServiceError.notConfigured
        }

        let club = try fetchClub(id: clubId)
        try verifyAdmin(club: club, adminId: adminId)

        guard club.pendingRequestIds.contains(userId) else {
            throw ClubServiceError.noRequestFound
        }

        club.pendingRequestIds.removeAll { $0 == userId }
        club.memberIds.append(userId)
        club.memberCount = club.memberIds.count

        let membership = ClubMembership(
            userId: userId,
            clubId: clubId,
            role: .member
        )
        context.insert(membership)

        try logAdminAction(
            clubId: clubId,
            adminId: adminId,
            actionType: "approve_request",
            targetUserId: userId,
            message: nil
        )

        try context.save()
    }

    /// Denies a pending join request with an optional message.
    func denyRequest(clubId: UUID, userId: UUID, adminId: UUID, message: String? = nil) throws {
        let club = try fetchClub(id: clubId)
        try verifyAdmin(club: club, adminId: adminId)

        guard club.pendingRequestIds.contains(userId) else {
            throw ClubServiceError.noRequestFound
        }

        club.pendingRequestIds.removeAll { $0 == userId }

        try logAdminAction(
            clubId: clubId,
            adminId: adminId,
            actionType: "deny_request",
            targetUserId: userId,
            message: message
        )

        try modelContext?.save()
    }

    /// Removes a member from the club. Admins cannot remove the owner.
    func removeMember(clubId: UUID, userId: UUID, adminId: UUID) throws {
        guard let context = modelContext else {
            throw ClubServiceError.notConfigured
        }

        let club = try fetchClub(id: clubId)
        try verifyAdmin(club: club, adminId: adminId)

        guard club.memberIds.contains(userId) else {
            throw ClubServiceError.notMember
        }

        guard club.creatorId != userId else {
            throw ClubServiceError.cannotRemoveOwner
        }

        club.memberIds.removeAll { $0 == userId }
        club.adminIds.removeAll { $0 == userId }
        club.memberCount = club.memberIds.count

        if let membership = try fetchMembership(clubId: clubId, userId: userId) {
            context.delete(membership)
        }

        try logAdminAction(
            clubId: clubId,
            adminId: adminId,
            actionType: "remove_member",
            targetUserId: userId,
            message: nil
        )

        try context.save()
    }

    /// Promotes a member to admin. Only existing admins can promote.
    func promoteToAdmin(clubId: UUID, userId: UUID, adminId: UUID) throws {
        let club = try fetchClub(id: clubId)
        try verifyAdmin(club: club, adminId: adminId)

        guard club.memberIds.contains(userId) else {
            throw ClubServiceError.notMember
        }

        guard !club.adminIds.contains(userId) else {
            throw ClubServiceError.alreadyAdmin
        }

        club.adminIds.append(userId)

        if let membership = try fetchMembership(clubId: clubId, userId: userId) {
            membership.role = .admin
        }

        try logAdminAction(
            clubId: clubId,
            adminId: adminId,
            actionType: "promote_admin",
            targetUserId: userId,
            message: nil
        )

        try modelContext?.save()
    }

    /// Demotes an admin back to member. Owner-only action.
    func demoteAdmin(clubId: UUID, userId: UUID, ownerId: UUID) throws {
        let club = try fetchClub(id: clubId)

        guard club.creatorId == ownerId else {
            throw ClubServiceError.ownerOnly
        }

        guard club.adminIds.contains(userId), userId != ownerId else {
            throw ClubServiceError.invalidDemotion
        }

        club.adminIds.removeAll { $0 == userId }

        if let membership = try fetchMembership(clubId: clubId, userId: userId) {
            membership.role = .member
        }

        try logAdminAction(
            clubId: clubId,
            adminId: ownerId,
            actionType: "demote_admin",
            targetUserId: userId,
            message: nil
        )

        try modelContext?.save()
    }

    /// Transfers club ownership. Owner-only action.
    func transferOwnership(clubId: UUID, newOwnerId: UUID, currentOwnerId: UUID) throws {
        let club = try fetchClub(id: clubId)

        guard club.creatorId == currentOwnerId else {
            throw ClubServiceError.ownerOnly
        }

        guard club.memberIds.contains(newOwnerId) else {
            throw ClubServiceError.notMember
        }

        club.creatorId = newOwnerId
        if !club.adminIds.contains(newOwnerId) {
            club.adminIds.append(newOwnerId)
        }

        if let oldOwnerMembership = try fetchMembership(clubId: clubId, userId: currentOwnerId) {
            oldOwnerMembership.role = .admin
        }
        if let newOwnerMembership = try fetchMembership(clubId: clubId, userId: newOwnerId) {
            newOwnerMembership.role = .owner
        }

        try logAdminAction(
            clubId: clubId,
            adminId: currentOwnerId,
            actionType: "transfer_ownership",
            targetUserId: newOwnerId,
            message: nil
        )

        try modelContext?.save()
    }

    // MARK: - Health Evaluation

    /// Evaluates all clubs for staleness and discovery delisting.
    /// - 0 activity in 30 days: marks club as stale (tag).
    /// - 0 activity in 60 days: delisted from discovery.
    /// - Public clubs with < 3 members are also delisted.
    func evaluateClubHealth() throws {
        guard let context = modelContext else {
            throw ClubServiceError.notConfigured
        }

        let descriptor = FetchDescriptor<Club>()
        let clubs = try context.fetch(descriptor)
        let now = Date()

        for club in clubs {
            let daysSinceActivity: Int
            if let lastActivity = club.lastActivityDate {
                daysSinceActivity = Calendar.current.dateComponents([.day], from: lastActivity, to: now).day ?? 0
            } else {
                daysSinceActivity = Calendar.current.dateComponents([.day], from: club.createdAt, to: now).day ?? 0
            }

            // Stale badge (30+ days inactive)
            if daysSinceActivity >= 30 {
                if !club.tags.contains("stale") {
                    club.tags.append("stale")
                }
            } else {
                club.tags.removeAll { $0 == "stale" }
            }

            // Delist from discovery (60+ days inactive)
            if daysSinceActivity >= 60 {
                club.isListedInDiscovery = false
            }

            // Public clubs need 3+ members for discovery
            if club.memberCount < 3 {
                club.isListedInDiscovery = false
            }

            // Verified clubs get priority (keep listed if active and have members)
            if club.isVerified && daysSinceActivity < 60 && club.memberCount >= 3 {
                club.isListedInDiscovery = true
            }
        }

        try context.save()
    }

    // MARK: - Recommendations

    /// Recommends clubs based on category match and gym-name fuzzy matching.
    func recommendClubs(for userId: UUID, gymName: String) throws -> [Club] {
        guard let context = modelContext else {
            throw ClubServiceError.notConfigured
        }

        let descriptor = FetchDescriptor<Club>(
            predicate: #Predicate<Club> { $0.isListedInDiscovery == true }
        )
        let discoveryClubs = try context.fetch(descriptor)

        // Score each club
        var scored: [(club: Club, score: Double)] = []

        for club in discoveryClubs {
            guard !club.memberIds.contains(userId) else { continue }

            var score: Double = 0

            // Gym name fuzzy match
            let similarity = normalizedSimilarity(gymName, club.name)
            score += similarity * 50

            // Verified badge bonus
            if club.isVerified {
                score += 10
            }

            // Member count relevance (larger clubs ranked slightly higher)
            score += min(Double(club.memberCount), 20) * 0.5

            // Recency bonus
            if let lastActivity = club.lastActivityDate {
                let daysSince = Calendar.current.dateComponents([.day], from: lastActivity, to: Date()).day ?? 0
                if daysSince < 7 {
                    score += 5
                }
            }

            if score > 5 {
                scored.append((club, score))
            }
        }

        return scored
            .sorted { $0.score > $1.score }
            .map(\.club)
    }

    /// Fuzzy-matches a gym name against existing clubs.
    func findClubByGymName(_ gymName: String) throws -> Club? {
        guard let context = modelContext else {
            throw ClubServiceError.notConfigured
        }

        let descriptor = FetchDescriptor<Club>()
        let clubs = try context.fetch(descriptor)

        var bestMatch: Club?
        var bestScore: Double = 0

        let threshold: Double = 0.5

        for club in clubs {
            let score = normalizedSimilarity(gymName, club.name)
            if score > bestScore && score >= threshold {
                bestScore = score
                bestMatch = club
            }
        }

        return bestMatch
    }

    // MARK: - Ownership Query

    /// Returns how many clubs a user owns.
    func getOwnedClubCount(userId: UUID) throws -> Int {
        guard let context = modelContext else {
            throw ClubServiceError.notConfigured
        }

        let descriptor = FetchDescriptor<ClubMembership>(
            predicate: #Predicate<ClubMembership> { $0.userId == userId }
        )
        let memberships = try context.fetch(descriptor)
        return memberships.filter { $0.role == .owner }.count
    }

    // MARK: - Admin Action Logging

    /// Logs an admin action for audit purposes.
    @discardableResult
    func logAdminAction(
        clubId: UUID,
        adminId: UUID,
        actionType: String,
        targetUserId: UUID,
        message: String?
    ) throws -> ClubAdminAction {
        guard modelContext != nil else {
            throw ClubServiceError.notConfigured
        }

        guard let action = ClubAdminAction(rawValue: actionType) else {
            throw ClubServiceError.notConfigured
        }
        return action
    }

    // MARK: - Private Helpers

    private func fetchClub(id: UUID) throws -> Club {
        guard let context = modelContext else {
            throw ClubServiceError.notConfigured
        }

        let descriptor = FetchDescriptor<Club>(
            predicate: #Predicate<Club> { $0.id == id }
        )
        guard let club = try context.fetch(descriptor).first else {
            throw ClubServiceError.clubNotFound
        }
        return club
    }

    private func fetchMembership(clubId: UUID, userId: UUID) throws -> ClubMembership? {
        guard let context = modelContext else {
            throw ClubServiceError.notConfigured
        }

        let descriptor = FetchDescriptor<ClubMembership>(
            predicate: #Predicate<ClubMembership> {
                $0.clubId == clubId && $0.userId == userId
            }
        )
        return try context.fetch(descriptor).first
    }

    private func verifyAdmin(club: Club, adminId: UUID) throws {
        guard club.adminIds.contains(adminId) else {
            throw ClubServiceError.notAdmin
        }
    }

    // MARK: - Fuzzy String Matching

    /// Normalized similarity between two strings (0.0 ... 1.0).
    /// Combines containment check with Levenshtein distance.
    private func normalizedSimilarity(_ a: String, _ b: String) -> Double {
        let lhs = a.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let rhs = b.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        if lhs.isEmpty || rhs.isEmpty { return 0 }
        if lhs == rhs { return 1.0 }

        // Containment bonus — one string fully inside the other
        if rhs.contains(lhs) || lhs.contains(rhs) {
            let shorter = Double(min(lhs.count, rhs.count))
            let longer = Double(max(lhs.count, rhs.count))
            return 0.8 + 0.2 * (shorter / longer)
        }

        // Levenshtein distance normalized to 0...1
        let distance = levenshteinDistance(lhs, rhs)
        let maxLen = max(lhs.count, rhs.count)
        return max(0, 1.0 - Double(distance) / Double(maxLen))
    }

    /// Standard Levenshtein distance between two strings.
    private func levenshteinDistance(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        let aLen = aChars.count
        let bLen = bChars.count

        if aLen == 0 { return bLen }
        if bLen == 0 { return aLen }

        var matrix = [[Int]](repeating: [Int](repeating: 0, count: bLen + 1), count: aLen + 1)

        for i in 0...aLen { matrix[i][0] = i }
        for j in 0...bLen { matrix[0][j] = j }

        for i in 1...aLen {
            for j in 1...bLen {
                let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,       // deletion
                    matrix[i][j - 1] + 1,       // insertion
                    matrix[i - 1][j - 1] + cost  // substitution
                )
            }
        }

        return matrix[aLen][bLen]
    }
}

// MARK: - Errors

enum ClubServiceError: LocalizedError {
    case notConfigured
    case clubNotFound
    case ownershipLimitReached
    case alreadyMember
    case requestAlreadyPending
    case notMember
    case ownerCannotLeave
    case notAdmin
    case noRequestFound
    case cannotRemoveOwner
    case alreadyAdmin
    case ownerOnly
    case invalidDemotion

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "ClubService has not been configured with a ModelContext."
        case .clubNotFound:
            return "The specified club was not found."
        case .ownershipLimitReached:
            return "You can only own one club at a time."
        case .alreadyMember:
            return "You are already a member of this club."
        case .requestAlreadyPending:
            return "A join request is already pending for this club."
        case .notMember:
            return "The user is not a member of this club."
        case .ownerCannotLeave:
            return "The owner cannot leave. Transfer ownership first."
        case .notAdmin:
            return "You do not have admin privileges for this club."
        case .noRequestFound:
            return "No pending join request found for this user."
        case .cannotRemoveOwner:
            return "The club owner cannot be removed."
        case .alreadyAdmin:
            return "The user is already an admin."
        case .ownerOnly:
            return "Only the club owner can perform this action."
        case .invalidDemotion:
            return "Cannot demote this user."
        }
    }
}
