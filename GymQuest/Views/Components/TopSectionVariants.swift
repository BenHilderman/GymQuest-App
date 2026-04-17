import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// 20 clean top sections. NO overlapping circles. Each crew member shows
/// workout type + time. Paired with hero below. Today-page clean.
struct TopSectionSampler: View {
    let crewMembers: [CrewMember]
    let heroPost: Post?
    let heroRationale: String
    let onFriends: () -> Void
    let onShorts: () -> Void
    let onSearch: () -> Void
    let onStartWorkout: () -> Void
    let onTapMember: (CrewMember) -> Void
    let onHeroStart: () -> Void
    let onHeroPreview: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(1...20, id: \.self) { v in
                VStack(alignment: .leading, spacing: 4) {
                    Text("Option \(v)").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(GQGradients.primary).padding(.horizontal, 16)
                    variant(v).padding(.horizontal, 16)
                    if let post = heroPost {
                        ExploreHeroCard(post: post, rationale: heroRationale, isSaved: false, onStart: onHeroStart, onPreview: onHeroPreview, onToggleSave: {}, onShuffle: {}).padding(.horizontal, 16)
                    }
                    Divider().padding(.vertical, 6).padding(.horizontal, 40)
                }
            }
        }
    }

    private var liveCount: Int { crewMembers.filter { if case .live = $0.status { return true }; return false }.count }
    private func fn(_ m: CrewMember) -> String { m.name.split(separator: " ").first.map(String.init) ?? m.name }
    private func rc(_ m: CrewMember) -> Color { switch m.status { case .live: return .green; case .recent: return .purple; case .inactive: return .gray.opacity(0.25) } }

    // Crew avatar (NOT overlapping, with workout + time labels)
    private func crewCell(_ m: CrewMember, size: CGFloat) -> some View {
        VStack(spacing: 3) {
            ZStack {
                Circle().stroke(rc(m), lineWidth: 2).frame(width: size, height: size)
                Circle().fill(GQGradients.primary).frame(width: size - 6, height: size - 6)
                    .overlay(Text(String(m.name.prefix(1)).uppercased()).font(.system(size: size * 0.28, weight: .bold)).foregroundColor(.white))
                if case .live = m.status {
                    Circle().fill(Color.green).frame(width: 10, height: 10)
                        .overlay(Circle().stroke(GQColors.background, lineWidth: 1.5))
                        .frame(width: size, height: size, alignment: .bottomTrailing)
                }
            }
            Text(fn(m)).font(.system(size: 10, weight: .semibold)).foregroundColor(GQColors.textPrimary).lineLimit(1).frame(maxWidth: size + 8)
            Text(m.statusText).font(.system(size: 8, weight: .medium)).foregroundColor(GQColors.textTertiary).lineLimit(1).frame(maxWidth: size + 8)
        }
    }

    // Nav atoms
    private func ic(_ name: String, _ act: @escaping () -> Void) -> some View { Button(action: act) { Image(systemName: name).font(.system(size: 14, weight: .medium)).foregroundColor(GQColors.textPrimary) }.buttonStyle(.plain) }
    private func txtLink(_ label: String, _ icon: String, primary: Bool = false, _ act: @escaping () -> Void) -> some View { Button(action: act) { HStack(spacing: 4) { Image(systemName: icon).font(.system(size: 11)); Text(label).font(.system(size: 12, weight: primary ? .semibold : .medium)) }.foregroundColor(primary ? GQColors.textPrimary : GQColors.textSecondary) }.buttonStyle(.plain) }

    @ViewBuilder
    private func variant(_ n: Int) -> some View {
        switch n {

        // 1. Today-style tab bar (Friends/Shorts underlined) + crew row below
        case 1:
            VStack(spacing: 8) {
                HStack(spacing: 20) { Spacer(); Button("Friends", action: onFriends).font(.system(size: 13, weight: .semibold)).foregroundStyle(GQGradients.primary); Button("Shorts", action: onShorts).font(.system(size: 13, weight: .regular)).foregroundColor(GQColors.textTertiary); ic("magnifyingglass", onSearch); Spacer() }.buttonStyle(.plain)
                Divider().overlay(GQColors.adaptiveOverlay(0.04))
                ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 12) { ForEach(crewMembers.prefix(6)) { m in crewCell(m, size: 36) } } }
            }

        // 2. Same but no underline, just text + crew
        case 2:
            VStack(spacing: 8) {
                HStack { txtLink("Friends", "person.2", primary: true, onFriends); txtLink("Shorts", "play.rectangle", onShorts); Spacer(); ic("magnifyingglass", onSearch) }
                ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 12) { ForEach(crewMembers.prefix(6)) { m in crewCell(m, size: 36) } } }
            }

        // 3. Crew first, nav below
        case 3:
            VStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 12) { ForEach(crewMembers.prefix(6)) { m in crewCell(m, size: 36) } } }
                HStack { txtLink("Friends", "person.2", primary: true, onFriends); txtLink("Shorts", "play.rectangle", onShorts); Spacer(); ic("magnifyingglass", onSearch) }
            }

        // 4. Nav icons right + crew row (larger avatars, 40pt)
        case 4:
            VStack(spacing: 8) {
                HStack(spacing: 16) { Spacer(); ic("person.2", onFriends); ic("play.rectangle", onShorts); ic("magnifyingglass", onSearch) }
                ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 14) { ForEach(crewMembers.prefix(5)) { m in crewCell(m, size: 40) } } }
            }

        // 5. Bold "Feed" title + icons + crew
        case 5:
            VStack(spacing: 8) {
                HStack { Text("Feed").font(.system(size: 22, weight: .bold)).foregroundColor(GQColors.textPrimary); Spacer(); ic("person.2", onFriends); ic("play.rectangle", onShorts); ic("magnifyingglass", onSearch) }
                ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 12) { ForEach(crewMembers.prefix(6)) { m in crewCell(m, size: 36) } } }
            }

        // 6. Crew in card + nav outside
        case 6:
            VStack(spacing: 8) {
                HStack { txtLink("Friends", "person.2", primary: true, onFriends); txtLink("Shorts", "play.rectangle", onShorts); Spacer(); ic("magnifyingglass", onSearch) }
                ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 12) { ForEach(crewMembers.prefix(5)) { m in crewCell(m, size: 36) } } }.padding(10).homeSocialCard(cornerRadius: 12)
            }

        // 7. Nav pill centered + crew below
        case 7:
            VStack(spacing: 8) {
                HStack { Spacer(); HStack(spacing: 14) { txtLink("Friends", "person.2", primary: true, onFriends); Divider().frame(height: 14); txtLink("Shorts", "play.rectangle", onShorts); Divider().frame(height: 14); ic("magnifyingglass", onSearch) }.padding(.horizontal, 14).padding(.vertical, 6).background(Capsule().fill(GQColors.adaptiveOverlay(0.03))).overlay(Capsule().stroke(GQColors.borderDefault, lineWidth: 0.5)); Spacer() }
                ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 12) { ForEach(crewMembers.prefix(6)) { m in crewCell(m, size: 36) } } }
            }

        // 8. Compact: smaller crew (32pt) + icon nav
        case 8:
            VStack(spacing: 6) {
                HStack(spacing: 16) { Spacer(); ic("person.2", onFriends); ic("play.rectangle", onShorts); ic("magnifyingglass", onSearch) }
                ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 10) { ForEach(crewMembers.prefix(6)) { m in crewCell(m, size: 32) } } }
            }

        // 9. Crew + nav all in one card
        case 9:
            VStack(spacing: 8) {
                HStack { txtLink("Friends", "person.2", primary: true, onFriends); txtLink("Shorts", "play.rectangle", onShorts); Spacer(); ic("magnifyingglass", onSearch) }
                Divider().overlay(GQColors.adaptiveOverlay(0.04))
                ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 12) { ForEach(crewMembers.prefix(5)) { m in crewCell(m, size: 34) } } }
            }.padding(10).homeSocialCard(cornerRadius: 14)

        // 10. Just crew row (no nav buttons visible — cleanest)
        case 10:
            ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 12) { ForEach(crewMembers.prefix(6)) { m in crewCell(m, size: 38) } } }

        // 11. Section header "YOUR CREW" + crew + nav icons
        case 11:
            VStack(spacing: 8) {
                HStack { Text("YOUR CREW").font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundColor(GQColors.textTertiary); Spacer(); ic("person.2", onFriends); ic("play.rectangle", onShorts); ic("magnifyingglass", onSearch) }
                ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 12) { ForEach(crewMembers.prefix(6)) { m in crewCell(m, size: 36) } } }
            }

        // 12. Nav text links + crew with green/purple rings
        case 12:
            VStack(spacing: 8) {
                HStack(spacing: 12) { Spacer(); Button("Friends", action: onFriends).font(.system(size: 13, weight: .semibold)).foregroundStyle(GQGradients.primary); Text("·").foregroundColor(GQColors.textTertiary); Button("Shorts", action: onShorts).font(.system(size: 13, weight: .medium)).foregroundColor(GQColors.textSecondary); ic("magnifyingglass", onSearch) }.buttonStyle(.plain)
                ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 12) { ForEach(crewMembers.prefix(6)) { m in crewCell(m, size: 36) } } }
            }

        // 13. Gradient bar card with crew + nav
        case 13:
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2).fill(GQGradients.primary).frame(height: 3)
                VStack(spacing: 8) {
                    HStack { txtLink("Friends", "person.2", primary: true, onFriends); txtLink("Shorts", "play.rectangle", onShorts); Spacer(); ic("magnifyingglass", onSearch) }
                    ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 12) { ForEach(crewMembers.prefix(5)) { m in crewCell(m, size: 34) } } }
                }.padding(10)
            }.background(GQColors.cardBackground).overlay(RoundedRectangle(cornerRadius: 12).stroke(GQColors.borderDefault, lineWidth: 1)).clipShape(RoundedRectangle(cornerRadius: 12)).gqShadow(.card)

        // 14. "Feed" title + section header crew
        case 14:
            VStack(spacing: 8) {
                HStack { Text("Feed").font(.system(size: 22, weight: .bold)).foregroundColor(GQColors.textPrimary); Spacer(); txtLink("Friends", "person.2", primary: true, onFriends); txtLink("Shorts", "play.rectangle", onShorts); ic("magnifyingglass", onSearch) }
                HStack { Text("YOUR CREW").font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundColor(GQColors.textTertiary); if liveCount > 0 { Text("· \(liveCount) LIVE").font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundColor(.green) }; Spacer() }
                ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 12) { ForEach(crewMembers.prefix(6)) { m in crewCell(m, size: 36) } } }
            }

        // 15. Crew row + centered text nav below
        case 15:
            VStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 14) { ForEach(crewMembers.prefix(5)) { m in crewCell(m, size: 38) } } }
                HStack(spacing: 16) { Spacer(); txtLink("Friends", "person.2", primary: true, onFriends); txtLink("Shorts", "play.rectangle", onShorts); ic("magnifyingglass", onSearch); Spacer() }
            }

        // 16. Ultra-minimal crew (no names, just type label) + nav
        case 16:
            VStack(spacing: 6) {
                HStack { txtLink("Friends", "person.2", primary: true, onFriends); txtLink("Shorts", "play.rectangle", onShorts); Spacer(); ic("magnifyingglass", onSearch) }
                ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 10) { ForEach(crewMembers.prefix(6)) { m in VStack(spacing: 2) { ZStack { Circle().stroke(rc(m), lineWidth: 2).frame(width: 32, height: 32); Circle().fill(GQGradients.primary).frame(width: 26, height: 26).overlay(Text(String(m.name.prefix(1)).uppercased()).font(.system(size: 8, weight: .bold)).foregroundColor(.white)) }; Text(m.statusText).font(.system(size: 8, weight: .medium)).foregroundColor(GQColors.textTertiary).lineLimit(1).frame(maxWidth: 40) } } } }
            }

        // 17. Tab-style segmented: "Friends | Shorts" + crew
        case 17:
            VStack(spacing: 8) {
                HStack { Spacer(); HStack(spacing: 0) { Button("Friends", action: onFriends).font(.system(size: 12, weight: .semibold)).foregroundColor(GQColors.textPrimary).frame(width: 72).padding(.vertical, 6); Divider().frame(height: 14); Button("Shorts", action: onShorts).font(.system(size: 12, weight: .medium)).foregroundColor(GQColors.textTertiary).frame(width: 72).padding(.vertical, 6) }.background(Capsule().fill(GQColors.adaptiveOverlay(0.04))).overlay(Capsule().stroke(GQColors.borderDefault, lineWidth: 0.5)).buttonStyle(.plain); ic("magnifyingglass", onSearch); Spacer() }
                ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 12) { ForEach(crewMembers.prefix(6)) { m in crewCell(m, size: 36) } } }
            }

        // 18. Icons right + labeled crew scroll
        case 18:
            VStack(spacing: 6) {
                HStack(spacing: 16) { Spacer(); ic("person.2", onFriends); ic("play.rectangle", onShorts); ic("magnifyingglass", onSearch) }
                ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 12) { ForEach(crewMembers.prefix(6)) { m in crewCell(m, size: 38) } } }
            }

        // 19. No crew at all — just clean nav
        case 19:
            HStack(spacing: 12) { Spacer(); txtLink("Friends", "person.2", primary: true, onFriends); txtLink("Shorts", "play.rectangle", onShorts); ic("magnifyingglass", onSearch) }

        // 20. THE ONE: "YOUR CREW" header + crew + nav text below
        case 20:
            VStack(spacing: 8) {
                HStack { Text("YOUR CREW").font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundColor(GQColors.textTertiary); if liveCount > 0 { HStack(spacing: 3) { Circle().fill(Color.green).frame(width: 5, height: 5); Text("\(liveCount) live").font(.system(size: 10, weight: .semibold)).foregroundColor(.green) } }; Spacer() }
                ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 12) { ForEach(crewMembers.prefix(6)) { m in crewCell(m, size: 36) } } }
                HStack(spacing: 12) { Spacer(); txtLink("Friends", "person.2", primary: true, onFriends); txtLink("Shorts", "play.rectangle", onShorts); ic("magnifyingglass", onSearch); Spacer() }
            }

        default: EmptyView()
        }
    }
}
