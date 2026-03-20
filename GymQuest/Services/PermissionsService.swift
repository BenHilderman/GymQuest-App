//
//  PermissionsService.swift
//  GymQuest
//
//  Social Permissions (System 4) — centralized visibility,
//  block/mute, and content-report logic for Lift AI.
//

import Foundation
import SwiftData

// MARK: - Content Context

enum ContentContext: String {
    case feed
    case pod
    case club
    case profile
}

// MARK: - Permissions Service

@MainActor
class PermissionsService: ObservableObject {
    static let shared = PermissionsService()

    private var modelContext: ModelContext?

    private init() {}

    /// Call once after the SwiftData container is ready.
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Visibility

    /// Central gate that determines whether `viewerId` may see content
    /// authored by `authorId` given its privacy level and viewing context.
    func canView(
        viewerId: UUID,
        authorId: UUID,
        privacy: ContentPrivacy,
        context: ContentContext
    ) -> Bool {
        // Author can always see their own content.
        if viewerId == authorId { return true }

        // Mutual block → neither sees anything.
        if isBlocked(userId: viewerId, targetId: authorId) ||
           isBlocked(userId: authorId, targetId: viewerId) {
            // Exception: pod context overrides block for pod-level content.
            if context == .pod && privacy == .pod {
                return sharePod(viewerId, authorId)
            }
            return false
        }

        // Private content is author-only.
        if privacy == .privateOnly { return false }

        // Public content visible everywhere.
        if privacy == .publicFeed { return true }

        // Relationship-gated privacy levels.
        let relationship = getRelationship(from: viewerId, to: authorId)

        switch privacy {
        case .friends:
            return relationship == .friend
        case .pod:
            return sharePod(viewerId, authorId)
        case .club:
            return shareClub(viewerId, authorId)
        default:
            return false
        }
    }

    // MARK: - Block

    func blockUser(userId: UUID, targetId: UUID) {
        guard let ctx = modelContext else { return }
        guard !isBlocked(userId: userId, targetId: targetId) else { return }

        let block = BlockedUser(
            userId: userId,
            blockedUserId: targetId,
            createdAt: Date()
        )
        ctx.insert(block)
        try? ctx.save()
    }

    func unblockUser(userId: UUID, targetId: UUID) {
        guard let ctx = modelContext else { return }

        let predicate = #Predicate<BlockedUser> {
            $0.userId == userId && $0.blockedUserId == targetId
        }
        let descriptor = FetchDescriptor<BlockedUser>(predicate: predicate)

        guard let results = try? ctx.fetch(descriptor) else { return }
        for record in results {
            ctx.delete(record)
        }
        try? ctx.save()
    }

    func isBlocked(userId: UUID, targetId: UUID) -> Bool {
        guard let ctx = modelContext else { return false }

        let predicate = #Predicate<BlockedUser> {
            $0.userId == userId && $0.blockedUserId == targetId
        }
        let descriptor = FetchDescriptor<BlockedUser>(predicate: predicate)
        let count = (try? ctx.fetchCount(descriptor)) ?? 0
        return count > 0
    }

    // MARK: - Mute

    func muteUser(userId: UUID, targetId: UUID) {
        guard let ctx = modelContext else { return }
        guard !isMuted(userId: userId, targetId: targetId) else { return }

        let mute = MutedUser(
            userId: userId,
            mutedUserId: targetId,
            createdAt: Date()
        )
        ctx.insert(mute)
        try? ctx.save()
    }

    func unmuteUser(userId: UUID, targetId: UUID) {
        guard let ctx = modelContext else { return }

        let predicate = #Predicate<MutedUser> {
            $0.userId == userId && $0.mutedUserId == targetId
        }
        let descriptor = FetchDescriptor<MutedUser>(predicate: predicate)

        guard let results = try? ctx.fetch(descriptor) else { return }
        for record in results {
            ctx.delete(record)
        }
        try? ctx.save()
    }

    func isMuted(userId: UUID, targetId: UUID) -> Bool {
        guard let ctx = modelContext else { return false }

        let predicate = #Predicate<MutedUser> {
            $0.userId == userId && $0.mutedUserId == targetId
        }
        let descriptor = FetchDescriptor<MutedUser>(predicate: predicate)
        let count = (try? ctx.fetchCount(descriptor)) ?? 0
        return count > 0
    }

    // MARK: - Report

    /// Files a content report. Auto-hides content after 3 distinct reporters.
    func reportContent(
        reporterId: UUID,
        contentType: String,
        contentId: UUID,
        reason: String,
        details: String? = nil
    ) {
        guard let ctx = modelContext else { return }

        let report = ContentReport(
            reporterId: reporterId,
            contentType: contentType,
            contentId: contentId,
            reason: reason,
            details: details,
            createdAt: Date(),
            resolved: false
        )
        ctx.insert(report)
        try? ctx.save()
    }

    func getReportCount(contentType: String, contentId: UUID) -> Int {
        guard let ctx = modelContext else { return 0 }

        let predicate = #Predicate<ContentReport> {
            $0.contentType == contentType &&
            $0.contentId == contentId &&
            $0.resolved == false
        }
        let descriptor = FetchDescriptor<ContentReport>(predicate: predicate)

        guard let reports = try? ctx.fetch(descriptor) else { return 0 }

        // Count distinct reporters.
        let uniqueReporters = Set(reports.map(\.reporterId))
        return uniqueReporters.count
    }

    // MARK: - Relationship

    func getRelationship(from userId: UUID, to targetId: UUID) -> UserRelationship {
        guard let ctx = modelContext else { return .none }

        // Check block first (asymmetric — either direction).
        if isBlocked(userId: userId, targetId: targetId) ||
           isBlocked(userId: targetId, targetId: userId) {
            return .blocked
        }

        // Friend check (userId follows targetId).
        let friendPredicate = #Predicate<Friend> {
            $0.userId == userId && $0.odId == targetId
        }
        let friendDescriptor = FetchDescriptor<Friend>(predicate: friendPredicate)
        if let count = try? ctx.fetchCount(friendDescriptor), count > 0 {
            return .friend
        }

        // Pod mate check.
        if sharePod(userId, targetId) {
            return .podMate
        }

        // Club mate check.
        if shareClub(userId, targetId) {
            return .clubMate
        }

        return .none
    }

    // MARK: - Feed Filtering

    /// Filters an array of posts for a given viewer, applying block, mute,
    /// privacy, and auto-hide (3+ reports) rules.
    func filterFeedPosts(_ posts: [Post], for userId: UUID) -> [Post] {
        return posts.filter { post in
            let authorId = post.authorId

            // Own posts always visible.
            if authorId == userId { return true }

            // Mutual or one-way block → hide (no pod override in feed context).
            if isBlocked(userId: userId, targetId: authorId) ||
               isBlocked(userId: authorId, targetId: userId) {
                return false
            }

            // Muted users hidden from feed (invisible to muted user).
            if isMuted(userId: userId, targetId: authorId) {
                return false
            }

            // Auto-hide after 3 distinct reports.
            if getReportCount(contentType: "post", contentId: post.id) >= 3 {
                return false
            }

            // Privacy gate.
            let privacy: ContentPrivacy = .friends
            return canView(
                viewerId: userId,
                authorId: authorId,
                privacy: privacy,
                context: .feed
            )
        }
    }

    // MARK: - Helpers

    /// Returns true when both users share at least one pod.
    private func sharePod(_ userA: UUID, _ userB: UUID) -> Bool {
        guard let ctx = modelContext else { return false }

        let predicateA = #Predicate<PodMembership> { $0.userId == userA }
        let descriptorA = FetchDescriptor<PodMembership>(predicate: predicateA)

        let predicateB = #Predicate<PodMembership> { $0.userId == userB }
        let descriptorB = FetchDescriptor<PodMembership>(predicate: predicateB)

        guard let podsA = try? ctx.fetch(descriptorA),
              let podsB = try? ctx.fetch(descriptorB) else { return false }

        let podIdsA = Set(podsA.map(\.podId))
        let podIdsB = Set(podsB.map(\.podId))
        return !podIdsA.isDisjoint(with: podIdsB)
    }

    /// Returns true when both users share at least one club.
    private func shareClub(_ userA: UUID, _ userB: UUID) -> Bool {
        guard let ctx = modelContext else { return false }

        let predicateA = #Predicate<ClubMembership> { $0.userId == userA }
        let descriptorA = FetchDescriptor<ClubMembership>(predicate: predicateA)

        let predicateB = #Predicate<ClubMembership> { $0.userId == userB }
        let descriptorB = FetchDescriptor<ClubMembership>(predicate: predicateB)

        guard let clubsA = try? ctx.fetch(descriptorA),
              let clubsB = try? ctx.fetch(descriptorB) else { return false }

        let clubIdsA = Set(clubsA.map(\.clubId))
        let clubIdsB = Set(clubsB.map(\.clubId))
        return !clubIdsA.isDisjoint(with: clubIdsB)
    }
}
