//
//  CommentsView.swift
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

// MARK: - Comments Sheet

struct CommentsSheet: View {
    let post: Post
    let currentUserId: UUID
    var currentUserName: String = ""
    var currentUsername: String = ""
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var comments: [Comment]
    @State private var newComment = ""
    @State private var replyTarget: Comment?
    @State private var expandedReplies: Set<UUID> = []
    @State private var appearedComments: Set<UUID> = []
    @State private var likedCommentIds: Set<UUID> = []
    @State private var initialLoadDone = false
    @FocusState private var isInputFocused: Bool
    private let bottomAnchorID = "comments_bottom"

    var postComments: [Comment] {
        comments.filter { $0.postId == post.id }.sorted { $0.timestamp < $1.timestamp }
    }

    private var topLevelComments: [Comment] {
        let topLevel = postComments.filter { $0.parentCommentId == nil }
        // Own comments first, then chronological
        let own = topLevel.filter { $0.authorId == currentUserId }.sorted { $0.timestamp > $1.timestamp }
        let others = topLevel.filter { $0.authorId != currentUserId }.sorted { $0.timestamp < $1.timestamp }
        return own + others
    }

    private func replies(for commentId: UUID) -> [Comment] {
        postComments.filter { $0.parentCommentId == commentId }.sorted { $0.timestamp < $1.timestamp }
    }

    private func replyCount(for commentId: UUID) -> Int {
        postComments.filter { $0.parentCommentId == commentId }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader
            Divider().overlay(Color.white.opacity(0.06))
            commentsScrollArea
            Divider().overlay(Color.white.opacity(0.06))
            replyContextBar
            commentInputBar
        }
        .gqPageBackground()
        .task { fetchRemoteComments() }
    }

    // MARK: - Header

    @ViewBuilder
    private var sheetHeader: some View {
        ZStack {
            Text("Comments")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(GQColors.textSecondary)

            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(GQColors.textTertiary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Scroll Area

    @ViewBuilder
    private var commentsScrollArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Caption as first comment (Instagram-style)
                    if !post.caption.isEmpty {
                        captionRow
                            .padding(.bottom, 4)
                    }

                    if topLevelComments.isEmpty {
                        emptyState
                    } else {
                        commentsList
                    }

                    Color.clear.frame(height: 1).id(bottomAnchorID)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                // Load persisted liked comment IDs
                let key = "likedComments_\(currentUserId.uuidString)"
                likedCommentIds = Set(UserDefaults.standard.stringArray(forKey: key)?.compactMap { UUID(uuidString: $0) } ?? [])

                let totalItems = topLevelComments.count
                let totalDelay = Double(totalItems) * 0.045 + 0.5
                DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay) {
                    initialLoadDone = true
                }
            }
            .onChange(of: postComments.count) { _, _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        proxy.scrollTo(bottomAnchorID, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Caption Row

    @ViewBuilder
    private var captionRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Spacer(minLength: 44)

            VStack(alignment: .trailing, spacing: 2) {
                Text(post.authorName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(GQColors.textSecondary)

                Text(post.caption)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        ChatBubbleShape(isFromCurrentUser: true)
                            .fill(GQGradients.primary)
                            .shadow(color: GQColors.deepBlue.opacity(0.3), radius: 6, x: 0, y: 2)
                    )

                Text(post.timestamp.timeAgoDisplay())
                    .font(.system(size: 10))
                    .foregroundColor(GQColors.textTertiary)
            }

            Circle()
                .fill(GQGradients.primary)
                .frame(width: 30, height: 30)
                .overlay(
                    Text(String(post.authorName.prefix(1)).uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                )
                .shadow(color: GQColors.deepBlue.opacity(0.15), radius: 3, x: 0, y: 1)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No comments yet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            Text("Start the conversation.")
                .font(.system(size: 13))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    // MARK: - Comments List

    @ViewBuilder
    private var commentsList: some View {
        ForEach(Array(topLevelComments.enumerated()), id: \.element.id) { index, comment in
            commentThread(comment: comment, index: index)
        }
    }

    @ViewBuilder
    private func commentThread(comment: Comment, index: Int) -> some View {
        let appeared = appearedComments.contains(comment.id)
        let commentReplies = replies(for: comment.id)
        let isExpanded = expandedReplies.contains(comment.id)
        let visibleReplies = isExpanded ? commentReplies : Array(commentReplies.prefix(1))
        let hiddenCount = commentReplies.count - visibleReplies.count

        VStack(alignment: .leading, spacing: 0) {
            // Parent comment
            CommentRow(
                comment: comment,
                currentUserId: currentUserId,
                isReply: false,
                onReply: { setReplyTarget(comment) },
                onLike: { likeComment(comment) },
                replyCount: commentReplies.count
            )

            // Replies
            if !visibleReplies.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(visibleReplies) { reply in
                        let replyAppeared = appearedComments.contains(reply.id)

                        CommentRow(
                            comment: reply,
                            currentUserId: currentUserId,
                            isReply: true,
                            onReply: { setReplyTarget(reply) },
                            onLike: { likeComment(reply) },
                            replyCount: 0
                        )
                        .opacity(replyAppeared ? 1 : 0)
                        .offset(y: replyAppeared ? 0 : 6)
                        .onAppear {
                            guard !appearedComments.contains(reply.id) else { return }
                            let delay = initialLoadDone ? 0.02 : 0.1
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75).delay(delay)) {
                                _ = appearedComments.insert(reply.id)
                            }
                        }
                    }

                    // "View N more replies" expander
                    if hiddenCount > 0 {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                _ = expandedReplies.insert(comment.id)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Rectangle()
                                    .fill(GQColors.textTertiary.opacity(0.3))
                                    .frame(width: 24, height: 1)
                                Text("View \(hiddenCount) more \(hiddenCount == 1 ? "reply" : "replies")")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(GQColors.textTertiary)
                            }
                            .padding(.leading, 54)
                            .padding(.top, 4)
                            .padding(.bottom, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 42)
            }
        }
        .id(comment.id)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .onAppear {
            guard !appearedComments.contains(comment.id) else { return }
            let delay = initialLoadDone ? 0.02 : (Double(index) * 0.045 + 0.08)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75).delay(delay)) {
                _ = appearedComments.insert(comment.id)
            }
        }
    }

    // MARK: - Reply Context Bar

    @ViewBuilder
    private var replyContextBar: some View {
        if let target = replyTarget {
            HStack(spacing: 8) {
                Image(systemName: "arrowshape.turn.up.left.fill")
                    .font(.system(size: 11))
                    .foregroundColor(GQColors.textTertiary)

                Text("Replying to ")
                    .font(.system(size: 13))
                    .foregroundColor(GQColors.textTertiary)
                + Text(target.authorName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        replyTarget = nil
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(GQColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.04))
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Input Bar

    @ViewBuilder
    private var commentInputBar: some View {
        HStack(spacing: 10) {
            // Current user avatar
            Circle()
                .fill(GQGradients.primary)
                .frame(width: 28, height: 28)
                .overlay(
                    Text(String(currentUserName.prefix(1)).uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                )

            TextField(replyTarget != nil ? "Reply..." : "Add a comment...", text: $newComment)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "1A1A1E"))
                .focused($isInputFocused)
                .tint(Color(hex: "1A1A1E"))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color(hex: "F0F0F5"))
                )

            Button {
                addComment()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(newComment.isEmpty
                        ? AnyShapeStyle(GQColors.textTertiary.opacity(0.4))
                        : AnyShapeStyle(GQGradients.primary))
                    .scaleEffect(newComment.isEmpty ? 1 : 1.05)
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: newComment.isEmpty)
            }
            .disabled(newComment.isEmpty)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    private func setReplyTarget(_ comment: Comment) {
        withAnimation(.easeOut(duration: 0.2)) {
            replyTarget = comment
        }
        isInputFocused = true
    }

    private func likeComment(_ comment: Comment) {
        guard !likedCommentIds.contains(comment.id) else { return }
        likedCommentIds.insert(comment.id)
        comment.likeCount += 1
        try? modelContext.save()

        // Persist liked comment IDs for this user across sessions
        let key = "likedComments_\(currentUserId.uuidString)"
        var persisted = Set(UserDefaults.standard.stringArray(forKey: key)?.compactMap { UUID(uuidString: $0) } ?? [])
        persisted.insert(comment.id)
        UserDefaults.standard.set(persisted.map(\.uuidString), forKey: key)
    }

    private func addComment() {
        guard !newComment.isEmpty else { return }

        let sanitizedContent = FeedContentService.sanitize(newComment)
        guard !sanitizedContent.isEmpty else { return }

        let comment = Comment(
            postId: post.id,
            authorId: currentUserId,
            authorName: currentUserName.isEmpty ? "User" : currentUserName,
            authorUsername: currentUsername,
            content: sanitizedContent,
            timestamp: Date(),
            parentCommentId: replyTarget?.id,
            replyToAuthorName: replyTarget?.authorName
        )

        modelContext.insert(comment)
        post.commentCount += 1
        try? modelContext.save()

        // Sync to Supabase
        if FeatureFlags.shared.supabaseSyncEnabled {
            Task {
                do {
                    let dto = CommentDTO(
                        id: comment.id,
                        postId: comment.postId,
                        authorId: SupabaseAuthService.shared.currentUserId ?? comment.authorId,
                        authorName: comment.authorName,
                        authorUsername: comment.authorUsername,
                        content: comment.content,
                        parentCommentId: comment.parentCommentId,
                        likeCount: 0,
                        createdAt: comment.timestamp
                    )
                    try await SupabaseSyncService.shared.insert(dto, table: "comments")
                } catch {
                    print("[CommentsView] Supabase comment sync failed: \(error)")
                }
            }
        }

        newComment = ""
        withAnimation(.easeOut(duration: 0.2)) {
            replyTarget = nil
        }
    }

    // MARK: - Remote Comments Fetch

    private func fetchRemoteComments() {
        guard FeatureFlags.shared.supabaseSyncEnabled else { return }
        Task {
            do {
                let remoteComments: [CommentDTO] = try await SupabaseSyncService.shared.fetch(from: "comments") { query in
                    query.eq("post_id", value: post.id.uuidString).order("created_at", ascending: true)
                }
                for dto in remoteComments {
                    let targetId = dto.id
                    let descriptor = FetchDescriptor<Comment>(predicate: #Predicate<Comment> { $0.id == targetId })
                    let existing = try? modelContext.fetch(descriptor)
                    if existing?.isEmpty ?? true {
                        let comment = Comment(
                            id: dto.id,
                            postId: dto.postId,
                            authorId: dto.authorId,
                            authorName: dto.authorName,
                            authorUsername: dto.authorUsername,
                            content: dto.content,
                            timestamp: dto.createdAt ?? Date(),
                            parentCommentId: dto.parentCommentId,
                            likeCount: dto.likeCount
                        )
                        modelContext.insert(comment)
                    }
                }
                try? modelContext.save()
            } catch {
                print("[CommentsView] Failed to fetch remote comments: \(error)")
            }
        }
    }
}

// MARK: - Comment Row (iMessage bubbles + Instagram actions)

struct CommentRow: View {
    let comment: Comment
    var currentUserId: UUID = UUID()
    var isReply: Bool = false
    var onReply: (() -> Void)?
    var onLike: (() -> Void)?
    var replyCount: Int = 0

    @State private var isLiked = false

    private var isOwnComment: Bool {
        comment.authorId == currentUserId
    }

    private var avatarSize: CGFloat {
        isReply ? 24 : 30
    }

    private var fontSize: CGFloat {
        isReply ? 13 : 14
    }

    var body: some View {
        VStack(alignment: isOwnComment ? .trailing : .leading, spacing: 3) {
            bubbleRow
            actionsRow
        }
        .padding(.vertical, 4)
    }

    private var avatar: some View {
        Circle()
            .fill(GQGradients.primary)
            .frame(width: avatarSize, height: avatarSize)
            .overlay(
                Text(String(comment.authorName.prefix(1)).uppercased())
                    .font(.system(size: isReply ? 9 : 11, weight: .bold))
                    .foregroundColor(.white)
            )
            .shadow(color: GQColors.deepBlue.opacity(0.15), radius: 3, x: 0, y: 1)
    }

    private var heartButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                isLiked.toggle()
                if isLiked { onLike?() }
            }
        } label: {
            Image(systemName: isLiked ? "heart.fill" : "heart")
                .font(.system(size: 11))
                .foregroundColor(isLiked ? GQColors.deepBlue : GQColors.textTertiary.opacity(0.4))
                .scaleEffect(isLiked ? 1.2 : 1)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var bubbleRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isOwnComment {
                Spacer(minLength: 44)
            } else {
                avatar
            }

            VStack(alignment: isOwnComment ? .trailing : .leading, spacing: 2) {
                if !isOwnComment {
                    Text(comment.authorName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(GQColors.textSecondary)
                }

                HStack(alignment: .bottom, spacing: 4) {
                    Text(comment.content)
                        .font(.system(size: fontSize))
                        .foregroundColor(isOwnComment ? .white : Color(hex: "1A1A1E"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            ChatBubbleShape(isFromCurrentUser: isOwnComment)
                                .fill(isOwnComment
                                    ? AnyShapeStyle(GQGradients.primary)
                                    : AnyShapeStyle(LinearGradient(
                                        colors: [Color(hex: "FFFFFF"), Color(hex: "F0F0F5")],
                                        startPoint: .top, endPoint: .bottom)))
                                .shadow(
                                    color: isOwnComment
                                        ? GQColors.deepBlue.opacity(0.3)
                                        : Color.black.opacity(0.08),
                                    radius: isOwnComment ? 6 : 4,
                                    x: 0, y: 2)
                        )
                        .onTapGesture(count: 2) {
                            guard !isOwnComment else { return }
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                if !isLiked {
                                    isLiked = true
                                    onLike?()
                                }
                            }
                        }

                    if !isOwnComment {
                        heartButton
                    }
                }
            }

            if isOwnComment {
                avatar
            } else {
                Spacer(minLength: 44)
            }
        }
    }

    @ViewBuilder
    private var actionsRow: some View {
        HStack(spacing: 14) {
            Text(comment.timestamp.timeAgoDisplay())
                .font(.system(size: 10))
                .foregroundColor(GQColors.textTertiary)

            if !isOwnComment && (comment.likeCount > 0 || isLiked) {
                let count = comment.likeCount + (isLiked ? 1 : 0)
                Text("\(count) \(count == 1 ? "like" : "likes")")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(GQColors.textTertiary)
            }

            Button { onReply?() } label: {
                Text("Reply")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(GQColors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, isOwnComment ? 0 : avatarSize + 8)
        .padding(.trailing, isOwnComment ? avatarSize + 8 : 0)
    }
}


