import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// 20 refined variants of the V17 DNA: gradient bar + play badge + author
/// + social proof + elevated shadow. Subtle differences in layout, spacing,
/// element ordering, and emphasis.
struct HeroVariantSampler: View {
    let post: Post
    let rationale: String
    let onStart: () -> Void

    @State private var autoIdx: Int = 0
    private let timer = Timer.publish(every: 8, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PICK YOUR FAVORITE").font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundColor(GQColors.textTertiary).padding(.horizontal, 16)
            ForEach(1...20, id: \.self) { v in
                VStack(alignment: .leading, spacing: 3) {
                    Text("Option \(v)").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(GQGradients.primary).padding(.horizontal, 16)
                    variant(v).padding(.horizontal, 16)
                }
            }
        }
        .onReceive(timer) { _ in withAnimation(.easeInOut(duration: 0.6)) { autoIdx = (autoIdx + 1) % 3 } }
    }

    // MARK: - Data
    private var ttl: String { if let d = post.sharedWorkoutData, let s = try? JSONDecoder().decode(SharedWorkoutData.self, from: d), !s.title.isEmpty { return s.title }; return post.exerciseHighlight ?? post.workoutType?.capitalized ?? "Workout" }
    private var dur: String { post.duration.map { "\($0) min" } ?? "—" }
    private var tp: String { post.workoutType?.capitalized ?? "Workout" }
    private var auth: String { "@\(post.authorUsername)" }
    private var authorName: String { post.authorName }
    private var lk: Int { post.likeCount }
    private var ini: String { String(post.authorName.prefix(1)).uppercased() }
    private var did: Int { max(post.timesUsed, post.likeCount / 2 + 1) }

    // MARK: - Atoms
    @ViewBuilder private var img: some View {
        #if canImport(UIKit)
        if let d = td(), let i = UIImage(data: d) { Image(uiImage: i).resizable().aspectRatio(contentMode: .fill) } else { Rectangle().fill(GQColors.surfaceSecondary) }
        #else
        Rectangle().fill(GQColors.surfaceSecondary)
        #endif
    }
    private func td() -> Data? { if let f = post.mediaItems.first { return f.thumbnailData ?? f.data }; return post.photoData }

    private var t72: some View { img.frame(width: 72, height: 72).clipShape(RoundedRectangle(cornerRadius: 12)) }
    private var t64: some View { img.frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 10)) }
    private func cap(_ t: String) -> some View { Text(t).font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundColor(GQColors.textTertiary) }
    private var av20: some View { Circle().fill(GQGradients.primary).frame(width: 20, height: 20).overlay(Text(ini).font(.system(size: 8, weight: .bold)).foregroundColor(.white)) }
    private var startP: some View { Button(action: onStart) { Text("Start ▸").font(.system(size: 12, weight: .semibold)).foregroundStyle(GQGradients.primary).padding(.horizontal, 12).padding(.vertical, 6).background(Capsule().fill(GQGradients.primary.opacity(0.08))) }.buttonStyle(.plain) }
    private var shuf: some View { Image(systemName: "shuffle").font(.system(size: 11, weight: .semibold)).foregroundColor(GQColors.textTertiary) }
    private var typeBadge: some View { Text(tp).font(.system(size: 9, weight: .bold)).foregroundStyle(GQGradients.primary).padding(.horizontal, 6).padding(.vertical, 2).background(GQGradients.primary.opacity(0.08)).clipShape(Capsule()) }
    private var hearts: some View { HStack(spacing: 2) { Image(systemName: "heart.fill").font(.system(size: 8)); Text("\(lk)").font(.system(size: 10, weight: .medium)) }.foregroundColor(GQColors.textTertiary) }
    private var playBadge: some View { ZStack { Circle().fill(.black.opacity(0.35)).frame(width: 26, height: 26); Image(systemName: "play.fill").font(.system(size: 9, weight: .bold)).foregroundColor(.white) } }
    private var socialAv: some View { HStack(spacing: -4) { ForEach(0..<min(did, 3), id: \.self) { i in Circle().fill(GQGradients.primary.opacity(0.12 + Double(3-i) * 0.2)).frame(width: 16, height: 16).overlay(Circle().stroke(GQColors.background, lineWidth: 1)) } } }
    private var didText: some View { Text("+\(did) did this").font(.system(size: 9, weight: .semibold)).foregroundColor(GQColors.textTertiary) }
    private var dots: some View { HStack(spacing: 3) { ForEach(0..<3, id: \.self) { i in Capsule().fill(i == autoIdx % 3 ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(GQColors.adaptiveOverlay(0.12))).frame(width: i == autoIdx % 3 ? 14 : 4, height: 4) } } }
    private var gradBar: some View { RoundedRectangle(cornerRadius: 2).fill(GQGradients.primary).frame(height: 4) }

    private func card(_ content: some View) -> some View {
        VStack(spacing: 0) {
            gradBar
            content
        }
        .background(GQColors.cardBackground)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(GQColors.borderDefault, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .gqShadow(.elevated)
    }

    // MARK: - 20 Variants

    @ViewBuilder
    private func variant(_ n: Int) -> some View {
        switch n {

        // 1. Author in header, social at bottom, play on thumb
        case 1: card(VStack(spacing: 6) {
            HStack(spacing: 12) { ZStack { t72; playBadge }; VStack(alignment: .leading, spacing: 4) { HStack { cap("TONIGHT'S PICK"); Spacer(); shuf }; Text(ttl).font(.system(size: 16, weight: .bold)).foregroundColor(GQColors.textPrimary).lineLimit(1); HStack(spacing: 4) { av20; Text(auth).font(.system(size: 10)).foregroundColor(GQColors.textTertiary); Text("·"); typeBadge; Text(dur).font(.system(size: 11)).foregroundColor(GQColors.textTertiary) }.font(.system(size: 10)).foregroundColor(GQColors.textTertiary); HStack(spacing: 4) { socialAv; didText; Spacer(); startP } } }; dots
        }.padding(12))

        // 2. Social headline first, author bottom
        case 2: card(VStack(spacing: 6) {
            HStack(spacing: 12) { ZStack { t72; playBadge }; VStack(alignment: .leading, spacing: 4) { HStack(spacing: 4) { socialAv; didText; Spacer(); shuf }; Text(ttl).font(.system(size: 16, weight: .bold)).foregroundColor(GQColors.textPrimary).lineLimit(1); HStack(spacing: 5) { typeBadge; Text(dur).font(.system(size: 11)).foregroundColor(GQColors.textTertiary); Spacer(); hearts }; HStack(spacing: 4) { av20; Text(authorName).font(.system(size: 11, weight: .semibold)).foregroundColor(GQColors.textPrimary); Spacer(); startP } } }; dots
        }.padding(12))

        // 3. Author as IG header row above content
        case 3: card(VStack(spacing: 8) {
            HStack(spacing: 6) { av20; Text(authorName).font(.system(size: 12, weight: .semibold)).foregroundColor(GQColors.textPrimary); Text("· \(tp)").font(.system(size: 11)).foregroundColor(GQColors.textTertiary); Spacer(); shuf }
            HStack(spacing: 12) { ZStack { t64; playBadge }; VStack(alignment: .leading, spacing: 4) { Text(ttl).font(.system(size: 16, weight: .bold)).foregroundColor(GQColors.textPrimary).lineLimit(1); HStack(spacing: 5) { Text(dur).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundColor(GQColors.textSecondary); Spacer(); hearts } } }
            HStack(spacing: 4) { socialAv; didText; Spacer(); startP }; dots
        }.padding(12))

        // 4. Divider separating content from social
        case 4: card(VStack(spacing: 8) {
            HStack(spacing: 14) { ZStack { t72; playBadge }; VStack(alignment: .leading, spacing: 5) { HStack { cap("TONIGHT'S PICK"); Spacer(); shuf }; Text(ttl).font(.system(size: 17, weight: .heavy)).foregroundColor(GQColors.textPrimary).lineLimit(1); HStack(spacing: 6) { typeBadge; Text(dur).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundColor(GQColors.textSecondary); Spacer(); hearts } } }
            Divider().overlay(GQColors.adaptiveOverlay(0.04))
            HStack(spacing: 6) { socialAv; didText; Spacer(); av20; Text(auth).font(.system(size: 10)).foregroundColor(GQColors.textTertiary); Spacer(); startP }; dots
        }.padding(14))

        // 5. Compact — all on fewer lines
        case 5: card(VStack(spacing: 6) {
            HStack(spacing: 10) { ZStack { t64; playBadge }; VStack(alignment: .leading, spacing: 3) { HStack { Text(ttl).font(.system(size: 15, weight: .bold)).foregroundColor(GQColors.textPrimary).lineLimit(1); Spacer(); shuf }; HStack(spacing: 4) { av20; Text(auth).font(.system(size: 10)).foregroundColor(GQColors.textTertiary); Text("·"); typeBadge; Text(dur).font(.system(size: 11)).foregroundColor(GQColors.textTertiary) }.font(.system(size: 10)).foregroundColor(GQColors.textTertiary) }; Spacer(minLength: 0); startP }
            HStack(spacing: 4) { socialAv; didText; Spacer(); hearts; dots }
        }.padding(12))

        // 6. Title is the hero — biggest text, everything else supporting
        case 6: card(VStack(spacing: 6) {
            HStack { cap("TONIGHT'S PICK"); Spacer(); shuf }
            HStack(spacing: 12) { ZStack { t72; playBadge }; Text(ttl).font(.system(size: 20, weight: .heavy)).foregroundColor(GQColors.textPrimary).lineLimit(2) }
            HStack(spacing: 4) { av20; Text(auth).font(.system(size: 10)).foregroundColor(GQColors.textTertiary); Text("·"); typeBadge; Text(dur).font(.system(size: 11)).foregroundColor(GQColors.textTertiary); Text("·"); hearts; Spacer(); socialAv; didText }.font(.system(size: 10)).foregroundColor(GQColors.textTertiary)
            HStack { Spacer(); startP; dots; Spacer() }
        }.padding(12))

        // 7. Start button full width below
        case 7: card(VStack(spacing: 8) {
            HStack(spacing: 12) { ZStack { t64; playBadge }; VStack(alignment: .leading, spacing: 4) { HStack { cap("TONIGHT'S PICK"); Spacer(); shuf }; Text(ttl).font(.system(size: 16, weight: .bold)).foregroundColor(GQColors.textPrimary).lineLimit(1); HStack(spacing: 4) { av20; Text(auth).font(.system(size: 10)).foregroundColor(GQColors.textTertiary); Text("·"); typeBadge; Text(dur).font(.system(size: 11)).foregroundColor(GQColors.textTertiary); Text("·"); hearts }.font(.system(size: 10)).foregroundColor(GQColors.textTertiary); HStack(spacing: 4) { socialAv; didText } } }
            Button(action: onStart) { HStack(spacing: 6) { Image(systemName: "play.fill").font(.system(size: 11, weight: .bold)); Text("Start now").font(.system(size: 13, weight: .semibold)) }.foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 9).background(Capsule().fill(GQGradients.primary)) }.buttonStyle(.plain)
            dots
        }.padding(12))

        // 8. Social + hearts on same line as type
        case 8: card(VStack(spacing: 6) {
            HStack(spacing: 12) { ZStack { t72; playBadge }; VStack(alignment: .leading, spacing: 4) { HStack { cap("TONIGHT'S PICK"); Spacer(); shuf }; Text(ttl).font(.system(size: 16, weight: .bold)).foregroundColor(GQColors.textPrimary).lineLimit(1); HStack(spacing: 4) { typeBadge; Text(dur).font(.system(size: 11)).foregroundColor(GQColors.textTertiary); hearts }; HStack(spacing: 4) { av20; Text(authorName).font(.system(size: 11, weight: .semibold)).foregroundColor(GQColors.textPrimary); Spacer(); socialAv; didText } } }
            HStack { Spacer(); startP; dots; Spacer() }
        }.padding(12))

        // 9. Rationale text visible
        case 9: card(VStack(spacing: 6) {
            HStack(spacing: 12) { ZStack { t72; playBadge }; VStack(alignment: .leading, spacing: 4) { HStack { cap("TONIGHT'S PICK"); Spacer(); shuf }; Text(ttl).font(.system(size: 16, weight: .bold)).foregroundColor(GQColors.textPrimary).lineLimit(1); Text(rationale).font(.system(size: 11)).foregroundColor(GQColors.textTertiary).lineLimit(1); HStack(spacing: 4) { av20; Text(auth).font(.system(size: 10)).foregroundColor(GQColors.textTertiary); Text("·"); typeBadge; Text(dur).font(.system(size: 11)).foregroundColor(GQColors.textTertiary) }.font(.system(size: 10)).foregroundColor(GQColors.textTertiary) } }
            HStack(spacing: 4) { socialAv; didText; Spacer(); startP }; dots
        }.padding(12))

        // 10. Green "READY" badge on thumb instead of play
        case 10: card(VStack(spacing: 6) {
            HStack(spacing: 12) { ZStack(alignment: .bottomTrailing) { t72; Text("✓").font(.system(size: 10, weight: .heavy)).foregroundColor(.white).frame(width: 18, height: 18).background(Circle().fill(GQColors.success)).overlay(Circle().stroke(GQColors.background, lineWidth: 2)) }; VStack(alignment: .leading, spacing: 4) { HStack { cap("READY TO FOLLOW"); Spacer(); shuf }; Text(ttl).font(.system(size: 16, weight: .bold)).foregroundColor(GQColors.textPrimary).lineLimit(1); HStack(spacing: 4) { av20; Text(auth).font(.system(size: 10)).foregroundColor(GQColors.textTertiary); Text("·"); typeBadge; Text(dur).font(.system(size: 11)).foregroundColor(GQColors.textTertiary) }.font(.system(size: 10)).foregroundColor(GQColors.textTertiary); HStack(spacing: 4) { socialAv; didText; Spacer(); startP } } }; dots
        }.padding(12))

        // 11. Trending flame header
        case 11: card(VStack(spacing: 6) {
            HStack(spacing: 12) { ZStack { t72; playBadge }; VStack(alignment: .leading, spacing: 4) { HStack(spacing: 4) { Text("🔥").font(.system(size: 10)); cap("TRENDING · +\(did) DID THIS"); Spacer(); shuf }; Text(ttl).font(.system(size: 16, weight: .bold)).foregroundColor(GQColors.textPrimary).lineLimit(1); HStack(spacing: 4) { av20; Text(auth).font(.system(size: 10)).foregroundColor(GQColors.textTertiary); Text("·"); typeBadge; Text(dur).font(.system(size: 11)).foregroundColor(GQColors.textTertiary); Spacer(); hearts }.font(.system(size: 10)).foregroundColor(GQColors.textTertiary) } }
            HStack { socialAv; Spacer(); startP }; dots
        }.padding(12))

        // 12. Duration number accent
        case 12: card(VStack(spacing: 6) {
            HStack(spacing: 10) { ZStack { t64; playBadge }; Text(dur.replacingOccurrences(of: " min", with: "")).font(.system(size: 30, weight: .heavy, design: .rounded)).foregroundStyle(GQGradients.primary); VStack(alignment: .leading, spacing: 3) { HStack { Text("min").font(.system(size: 10, weight: .semibold)).foregroundColor(GQColors.textTertiary); Spacer(); shuf }; Text(ttl).font(.system(size: 14, weight: .bold)).foregroundColor(GQColors.textPrimary).lineLimit(1); HStack(spacing: 4) { av20; Text(auth).font(.system(size: 10)).foregroundColor(GQColors.textTertiary); Text("·"); typeBadge }.font(.system(size: 10)).foregroundColor(GQColors.textTertiary) }; Spacer(minLength: 0); startP }
            HStack(spacing: 4) { socialAv; didText; Spacer(); hearts; dots }
        }.padding(10))

        // 13. Author header + divider + content
        case 13: card(VStack(spacing: 8) {
            HStack(spacing: 6) { av20; VStack(alignment: .leading) { Text(authorName).font(.system(size: 12, weight: .semibold)).foregroundColor(GQColors.textPrimary); Text(tp).font(.system(size: 10)).foregroundColor(GQColors.textTertiary) }; Spacer(); socialAv; didText; shuf }
            Divider().overlay(GQColors.adaptiveOverlay(0.04))
            HStack(spacing: 12) { ZStack { t64; playBadge }; VStack(alignment: .leading, spacing: 3) { Text(ttl).font(.system(size: 16, weight: .bold)).foregroundColor(GQColors.textPrimary).lineLimit(1); HStack(spacing: 5) { Text(dur).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundColor(GQColors.textSecondary); hearts } }; Spacer(); startP }
            dots
        }.padding(12))

        // 14. Type badge + duration prominent top row
        case 14: card(VStack(spacing: 6) {
            HStack { typeBadge; Text(dur).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(GQColors.textSecondary); Spacer(); shuf }
            HStack(spacing: 12) { ZStack { t72; playBadge }; VStack(alignment: .leading, spacing: 4) { Text(ttl).font(.system(size: 17, weight: .heavy)).foregroundColor(GQColors.textPrimary).lineLimit(1); HStack(spacing: 4) { av20; Text(authorName).font(.system(size: 11, weight: .semibold)).foregroundColor(GQColors.textPrimary); Spacer(); hearts } } }
            HStack(spacing: 4) { socialAv; didText; Spacer(); startP }; dots
        }.padding(12))

        // 15. Emphasis on rationale + social
        case 15: card(VStack(spacing: 6) {
            HStack(spacing: 12) { ZStack { t72; playBadge }; VStack(alignment: .leading, spacing: 4) { HStack { cap("TONIGHT'S PICK"); Spacer(); shuf }; Text(ttl).font(.system(size: 16, weight: .bold)).foregroundColor(GQColors.textPrimary).lineLimit(1); Text(rationale).font(.system(size: 11, weight: .medium)).foregroundColor(GQColors.textSecondary).lineLimit(1) } }
            Divider().overlay(GQColors.adaptiveOverlay(0.04))
            HStack(spacing: 6) { av20; Text(auth).font(.system(size: 10)).foregroundColor(GQColors.textTertiary); Text("·"); typeBadge; Text(dur).font(.system(size: 11)).foregroundColor(GQColors.textTertiary); Spacer(); socialAv; didText }.font(.system(size: 10)).foregroundColor(GQColors.textTertiary)
            HStack { Spacer(); startP; dots; Spacer() }
        }.padding(12))

        // 16. Minimal lines — everything on 3 rows max
        case 16: card(VStack(spacing: 8) {
            HStack(spacing: 12) { ZStack { t72; playBadge }; VStack(alignment: .leading, spacing: 5) { Text(ttl).font(.system(size: 17, weight: .heavy)).foregroundColor(GQColors.textPrimary).lineLimit(1); HStack(spacing: 4) { typeBadge; Text(dur).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundColor(GQColors.textSecondary); Text("·"); av20; Text(auth).font(.system(size: 10)).foregroundColor(GQColors.textTertiary) }.font(.system(size: 10)).foregroundColor(GQColors.textTertiary) }; Spacer(minLength: 0); shuf }
            HStack(spacing: 4) { socialAv; didText; Text("·"); hearts; Spacer(); startP; dots }
        }.padding(12))

        // 17. Start left, social right — flipped action placement
        case 17: card(VStack(spacing: 6) {
            HStack(spacing: 12) { ZStack { t72; playBadge }; VStack(alignment: .leading, spacing: 4) { HStack { cap("TONIGHT'S PICK"); Spacer(); shuf }; Text(ttl).font(.system(size: 16, weight: .bold)).foregroundColor(GQColors.textPrimary).lineLimit(1); HStack(spacing: 4) { av20; Text(auth).font(.system(size: 10)).foregroundColor(GQColors.textTertiary); Text("·"); typeBadge; Text(dur).font(.system(size: 11)).foregroundColor(GQColors.textTertiary); Spacer(); hearts }.font(.system(size: 10)).foregroundColor(GQColors.textTertiary) } }
            HStack(spacing: 6) { startP; Spacer(); socialAv; didText; dots }
        }.padding(12))

        // 18. Wide gradient bar (5pt) — more prominent accent
        case 18:
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2).fill(GQGradients.primary).frame(height: 5)
                VStack(spacing: 6) {
                    HStack(spacing: 12) { ZStack { t72; playBadge }; VStack(alignment: .leading, spacing: 4) { HStack { cap("TONIGHT'S PICK"); Spacer(); shuf }; Text(ttl).font(.system(size: 16, weight: .bold)).foregroundColor(GQColors.textPrimary).lineLimit(1); HStack(spacing: 4) { av20; Text(auth).font(.system(size: 10)).foregroundColor(GQColors.textTertiary); Text("·"); typeBadge; Text(dur).font(.system(size: 11)).foregroundColor(GQColors.textTertiary); Spacer(); hearts }.font(.system(size: 10)).foregroundColor(GQColors.textTertiary); HStack(spacing: 4) { socialAv; didText; Spacer(); startP } } }; dots
                }.padding(12)
            }.background(GQColors.cardBackground).overlay(RoundedRectangle(cornerRadius: 16).stroke(GQColors.borderDefault, lineWidth: 1)).clipShape(RoundedRectangle(cornerRadius: 16)).gqShadow(.elevated)

        // 19. Gradient border glow instead of top bar
        case 19:
            VStack(spacing: 6) {
                HStack(spacing: 12) { ZStack { t72; playBadge }; VStack(alignment: .leading, spacing: 4) { HStack { cap("TONIGHT'S PICK"); Spacer(); shuf }; Text(ttl).font(.system(size: 16, weight: .bold)).foregroundColor(GQColors.textPrimary).lineLimit(1); HStack(spacing: 4) { av20; Text(auth).font(.system(size: 10)).foregroundColor(GQColors.textTertiary); Text("·"); typeBadge; Text(dur).font(.system(size: 11)).foregroundColor(GQColors.textTertiary); Spacer(); hearts }.font(.system(size: 10)).foregroundColor(GQColors.textTertiary); HStack(spacing: 4) { socialAv; didText; Spacer(); startP } } }; dots
            }.padding(12).background(RoundedRectangle(cornerRadius: 16).fill(GQColors.cardBackground)).overlay(RoundedRectangle(cornerRadius: 16).stroke(GQGradients.primary.opacity(0.25), lineWidth: 1.5)).gqShadow(.elevated)

        // 20. THE ONE: gradient bar + divider + perfect spacing + all signals
        case 20: card(VStack(spacing: 8) {
            HStack(spacing: 14) { ZStack { t72; playBadge }; VStack(alignment: .leading, spacing: 5) { HStack { cap("TONIGHT'S PICK"); Spacer(); shuf }; Text(ttl).font(.system(size: 17, weight: .heavy)).foregroundColor(GQColors.textPrimary).lineLimit(1); HStack(spacing: 6) { typeBadge; Text(dur).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundColor(GQColors.textSecondary); Spacer(); hearts } } }
            Divider().overlay(GQColors.adaptiveOverlay(0.04))
            HStack(spacing: 6) { av20; Text(authorName).font(.system(size: 11, weight: .semibold)).foregroundColor(GQColors.textPrimary); Spacer(); socialAv; didText; Spacer(); startP }
            dots
        }.padding(14))

        default: EmptyView()
        }
    }
}
