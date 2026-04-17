import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// "🟢 Live now · 3 training" — the single most important community cue.
/// Pulsing avatars of friends currently in a workout. Tap → show their
/// status + one-tap support reaction so users feel like they're in the
/// gym together even when alone.
struct LiveNowStrip: View {
    /// The live users to render — already filtered to the viewer's follow
    /// graph by PresenceService.liveNow(from:selfId:followedIds:).
    let states: [UserPresenceState]
    /// Profiles keyed by userId so the strip can show names and avatars.
    let profilesById: [UUID: UserProfile]
    let onSendSupport: (UserPresenceState) -> Void

    @State private var pulse: Bool = false

    var body: some View {
        if states.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                header
                    .padding(.horizontal, 16)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(states, id: \.userId) { state in
                            avatarColumn(state)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .onAppear { pulse = true }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(GQColors.success)
                .frame(width: 6, height: 6)
                .scaleEffect(pulse ? 1.4 : 1.0)
                .opacity(pulse ? 0.45 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulse)
            Text("LIVE NOW")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(GQColors.textTertiary)
                .tracking(1.2)
            Text("· \(states.count) training")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
        }
    }

    // MARK: - Avatar column

    private func avatarColumn(_ state: UserPresenceState) -> some View {
        let profile = profilesById[state.userId]
        return Button {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            onSendSupport(state)
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(GQColors.success, lineWidth: 2.5)
                        .frame(width: 48, height: 48)
                        .scaleEffect(pulse ? 1.04 : 1.0)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)

                    avatarImage(profile: profile, displayName: profile?.name ?? "")
                        .frame(width: 42, height: 42)
                        .clipShape(Circle())

                    // Training state pip, bottom-right
                    Circle()
                        .fill(GQColors.success)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(GQColors.background, lineWidth: 2))
                        .frame(width: 60, height: 60, alignment: .bottomTrailing)
                }

                Text(profile?.name.split(separator: " ").first.map(String.init) ?? "—")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: 64)

                statusLine(state)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func avatarImage(profile: UserProfile?, displayName: String) -> some View {
        #if canImport(UIKit)
        if let data = profile?.profilePhotoData, let img = UIImage(data: data) {
            Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                Circle().fill(GQGradients.primary)
                Text(String(displayName.prefix(1)).uppercased())
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        #else
        Circle().fill(GQColors.surfaceSecondary)
        #endif
    }

    private func statusLine(_ state: UserPresenceState) -> some View {
        let type = state.workoutTypeRaw?.capitalized ?? "Training"
        let minutes = state.minutesIn
        let text = minutes > 0 ? "\(type) · \(minutes) min" : type
        return Text(text)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(GQColors.textTertiary)
            .lineLimit(1)
            .frame(maxWidth: 64)
    }
}
