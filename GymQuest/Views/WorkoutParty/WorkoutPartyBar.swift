import SwiftUI

// MARK: - Workout Party Bar

struct WorkoutPartyBar: View {
    let partyService: WorkoutPartyService
    let accentColors: [Color]
    let onSendReaction: (String) -> Void
    let onSendHype: (QuickHype) -> Void

    @State private var showReactions = false

    private let reactionEmojis = ["🔥", "💪", "👊", "⭐", "💯", "👏"]

    var body: some View {
        VStack(spacing: 0) {
            // LIVE header
            liveHeader

            // Party member cards
            partyMemberCards

            // Reaction + hype row
            if showReactions {
                reactionRow
            }

            // Activity ticker
            if !partyService.activityEvents.isEmpty {
                activityTicker
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(GQColors.surfaceBase.opacity(0.95))
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .fill(.clear)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 0.5)
                }
        )
    }

    // MARK: - Live Header

    private var liveHeader: some View {
        HStack(spacing: 8) {
            // Pulsing green dot
            Circle()
                .fill(GQColors.success)
                .frame(width: 8, height: 8)
                .modifier(PulsingDot())

            Text("LIVE")
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(GQColors.success)

            Text("·")
                .foregroundColor(GQColors.textTertiary)

            Text("\(partyService.partyMembers.count) friends")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(GQColors.textSecondary)

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showReactions.toggle()
                }
            } label: {
                Image(systemName: showReactions ? "chevron.up" : "face.smiling")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(GQColors.textTertiary)
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Party Member Cards

    private var partyMemberCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(partyService.partyMembers) { member in
                    PartyMemberCard(member: member, accentColors: accentColors)
                }
            }
        }
    }

    // MARK: - Reaction + Hype Row

    private var reactionRow: some View {
        VStack(spacing: 8) {
            // Emoji reaction buttons
            HStack(spacing: 12) {
                ForEach(reactionEmojis, id: \.self) { emoji in
                    Button {
                        onSendReaction(emoji)
                        triggerHaptic()
                    } label: {
                        Text(emoji)
                            .font(.system(size: 22))
                            .frame(width: 38, height: 38)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }

            // Hype message capsules
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(QuickHype.allCases, id: \.rawValue) { hype in
                        Button {
                            onSendHype(hype)
                            triggerHaptic()
                        } label: {
                            Text(hype.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule().fill(
                                        LinearGradient(
                                            colors: accentColors,
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ).opacity(0.3)
                                    )
                                )
                                .overlay(
                                    Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.top, 10)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Activity Ticker

    private var activityTicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(partyService.activityEvents.prefix(3)) { event in
                Text(event.text)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(GQColors.textTertiary)
                    .lineLimit(1)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    // MARK: - Haptic

    private func triggerHaptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

// MARK: - Party Member Card

private struct PartyMemberCard: View {
    let member: PartyMember
    let accentColors: [Color]

    var body: some View {
        HStack(spacing: 8) {
            // Avatar circle with initial
            Text(member.avatarInitial)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(
                    Circle().fill(
                        LinearGradient(
                            colors: accentColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(member.name.components(separatedBy: " ").first ?? member.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(member.currentExercise)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(GQColors.textTertiary)
                    .lineLimit(1)
            }

            // Set progress dots
            HStack(spacing: 3) {
                ForEach(0..<member.totalSets, id: \.self) { i in
                    Circle()
                        .fill(i < member.completedSets ? GQColors.success : Color.white.opacity(0.15))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(GQColors.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }
}

// MARK: - Pulsing Dot Modifier

private struct PulsingDot: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .overlay(
                Circle()
                    .fill(GQColors.success.opacity(0.4))
                    .scaleEffect(isPulsing ? 2.2 : 1)
                    .opacity(isPulsing ? 0 : 0.6)
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }
    }
}
