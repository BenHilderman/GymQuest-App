import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Final hero card — Option 1 with gradient bar, play badge, author,
/// social proof, shuffle dots, auto-shuffle. Tap card → post detail.
/// Tap Start → starts workout directly.
struct ExploreHeroCard: View {
    let post: Post
    let rationale: String
    let isSaved: Bool
    let onStart: () -> Void
    let onPreview: () -> Void
    let onToggleSave: () -> Void
    var onShuffle: (() -> Void)? = nil
    var onLongPressSave: (() -> Void)? = nil

    /// Auto-shuffle dot index — cycles 0/1/2 every 8s.
    @State private var autoIdx: Int = 0
    private let timer = Timer.publish(every: 8, on: .main, in: .common).autoconnect()

    private var ttl: String {
        if let d = post.sharedWorkoutData, let s = try? JSONDecoder().decode(SharedWorkoutData.self, from: d), !s.title.isEmpty { return s.title }
        return post.exerciseHighlight ?? post.workoutType?.capitalized ?? "Workout"
    }
    private var dur: String { post.duration.map { "\($0) min" } ?? "—" }
    private var tp: String { post.workoutType?.capitalized ?? "Workout" }
    private var auth: String { "@\(post.authorUsername)" }
    private var ini: String { String(post.authorName.prefix(1)).uppercased() }
    private var did: Int { max(post.timesUsed, post.likeCount / 2 + 1) }

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2).fill(GQGradients.primary).frame(height: 4)
            VStack(spacing: 6) {
                HStack(spacing: 12) {
                    // Thumbnail with play badge — tap opens post
                    ZStack {
                        thumbnail
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        ZStack {
                            Circle().fill(.black.opacity(0.35)).frame(width: 28, height: 28)
                            Image(systemName: "play.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onPreview)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("TONIGHT'S PICK")
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(1.2)
                                .foregroundColor(GQColors.textTertiary)
                            Spacer()
                            if let onShuffle {
                                Button(action: {
                                    #if canImport(UIKit)
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    #endif
                                    onShuffle()
                                }) {
                                    Image(systemName: "shuffle")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(GQColors.textTertiary)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Text(ttl)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(GQColors.textPrimary)
                            .lineLimit(1)

                        HStack(spacing: 4) {
                            Circle().fill(GQGradients.primary).frame(width: 20, height: 20)
                                .overlay(Text(ini).font(.system(size: 8, weight: .bold)).foregroundColor(.white))
                            Text(auth).font(.system(size: 10)).foregroundColor(GQColors.textTertiary)
                            Text("·")
                            Text(tp).font(.system(size: 9, weight: .bold))
                                .foregroundStyle(GQGradients.primary)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(GQGradients.primary.opacity(0.08))
                                .clipShape(Capsule())
                            Text(dur).font(.system(size: 11)).foregroundColor(GQColors.textTertiary)
                        }
                        .font(.system(size: 10))
                        .foregroundColor(GQColors.textTertiary)

                        HStack(spacing: 4) {
                            // Social avatars
                            HStack(spacing: -4) {
                                ForEach(0..<min(did, 3), id: \.self) { i in
                                    Circle()
                                        .fill(GQGradients.primary.opacity(0.12 + Double(3 - i) * 0.2))
                                        .frame(width: 16, height: 16)
                                        .overlay(Circle().stroke(GQColors.background, lineWidth: 1))
                                }
                            }
                            Text("+\(did) did this")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(GQColors.textTertiary)
                            Spacer()
                            // Start button
                            Button(action: {
                                #if canImport(UIKit)
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                #endif
                                onStart()
                            }) {
                                Text("Start ▸")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(GQGradients.primary)
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .background(Capsule().fill(GQGradients.primary.opacity(0.08)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Auto-shuffle dots
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { i in
                        Capsule()
                            .fill(i == autoIdx % 3
                                  ? AnyShapeStyle(GQGradients.primary)
                                  : AnyShapeStyle(GQColors.adaptiveOverlay(0.12)))
                            .frame(width: i == autoIdx % 3 ? 14 : 4, height: 4)
                            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: autoIdx)
                    }
                }
            }
            .padding(12)
        }
        .background(GQColors.cardBackground)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(GQColors.borderDefault, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .gqShadow(.elevated)
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.6)) { autoIdx = (autoIdx + 1) % 3 }
            onShuffle?()
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        #if canImport(UIKit)
        if let data = primaryThumbData(), let img = UIImage(data: data) {
            Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(GQGradients.primary.opacity(0.08))
                Image(systemName: "dumbbell.fill").font(.system(size: 24, weight: .light)).foregroundStyle(GQGradients.primary)
            }
        }
        #else
        RoundedRectangle(cornerRadius: 12).fill(GQColors.surfaceSecondary)
        #endif
    }

    private func primaryThumbData() -> Data? {
        if let first = post.mediaItems.first { return first.thumbnailData ?? first.data }
        return post.photoData
    }
}
