import SwiftUI

// MARK: - Floating Reactions Overlay

struct FloatingReactionsOverlay: View {
    let reactions: [LiveCheer]

    var body: some View {
        ZStack {
            ForEach(reactions) { cheer in
                FloatingEmojiView(cheer: cheer)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .allowsHitTesting(false)
    }
}

// MARK: - Floating Emoji View

private struct FloatingEmojiView: View {
    let cheer: LiveCheer

    @State private var yOffset: CGFloat = 0
    @State private var opacity: Double = 1

    var body: some View {
        VStack(spacing: 2) {
            Text(cheer.emoji)
                .font(.system(size: 28))
            Text(cheer.senderName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(GQColors.textPrimary.opacity(0.8))
        }
        .offset(x: cheer.xOffset, y: yOffset)
        .opacity(opacity)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(.trailing, 24)
        .padding(.bottom, 120)
        .onAppear {
            withAnimation(.easeOut(duration: 3.0)) {
                yOffset = -250
                opacity = 0
            }
        }
    }
}

// MARK: - Hype Toast Banner

struct HypeToastBanner: View {
    let message: HypeMessage

    var body: some View {
        HStack(spacing: 8) {
            Text("📣")
                .font(.system(size: 16))

            Text("\(message.senderName): \"\(message.text)\"")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(GQColors.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(GQColors.surfaceElevated)
        )
        .overlay(
            Capsule()
                .stroke(GQColors.success.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
    }
}
