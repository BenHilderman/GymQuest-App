import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Single merged crew member for the unified row.
struct CrewMember: Identifiable {
    let id: UUID
    let name: String
    let username: String
    let avatarData: Data?
    let status: Status
    let statusText: String       // "Push · 6 min" or "yesterday" or "2d ago"

    enum Status {
        case live(workoutType: String?)  // green ring, currently training
        case recent                       // purple ring, posted recently
        case inactive                     // gray, >3 days no activity
    }
}

/// One horizontal row replacing both LiveNowStrip and FriendFeedSection.
/// Green ring = training now, purple = posted recently, gray = inactive.
/// ~70pt tall. Tap avatar → callback. [+] at the end starts a workout.
struct CrewRow: View {
    let members: [CrewMember]
    let onTapMember: (CrewMember) -> Void
    let onStartWorkout: () -> Void

    @State private var pulse: Bool = false

    var body: some View {
        if members.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("YOUR CREW")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(1.2)
                    .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) {
                        ForEach(members) { member in
                            memberCell(member)
                        }
                        startCell
                    }
                    .padding(.horizontal, 16)
                }
            }
            .onAppear { pulse = true }
        }
    }

    private func memberCell(_ member: CrewMember) -> some View {
        Button {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            onTapMember(member)
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(ringColor(member), lineWidth: 2.5)
                        .frame(width: 48, height: 48)
                        .scaleEffect(isLive(member) && pulse ? 1.04 : 1.0)
                        .animation(isLive(member)
                            ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                            : .default, value: pulse)

                    avatarImage(member)
                        .frame(width: 42, height: 42)
                        .clipShape(Circle())

                    if isLive(member) {
                        Circle()
                            .fill(GQColors.success)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(GQColors.background, lineWidth: 2))
                            .frame(width: 48, height: 48, alignment: .bottomTrailing)
                    }

                    if isInactive(member) {
                        Circle()
                            .fill(.orange)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(GQColors.background, lineWidth: 2))
                            .frame(width: 48, height: 48, alignment: .bottomTrailing)
                    }
                }

                Text(firstName(member))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: 56)

                Text(member.statusText)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(GQColors.textTertiary)
                    .lineLimit(1)
                    .frame(maxWidth: 56)
            }
        }
        .buttonStyle(.plain)
    }

    private var startCell: some View {
        Button(action: onStartWorkout) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(GQColors.borderDefault, lineWidth: 1.5)
                        .frame(width: 48, height: 48)
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(GQGradients.primary)
                }
                Text("Start")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(GQColors.textSecondary)
                Text("workout")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(GQColors.textTertiary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func avatarImage(_ member: CrewMember) -> some View {
        #if canImport(UIKit)
        if let data = member.avatarData, let img = UIImage(data: data) {
            Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                Circle().fill(isInactive(member) ? AnyShapeStyle(GQColors.surfaceSecondary) : AnyShapeStyle(GQGradients.primary))
                Text(String(member.name.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        #else
        Circle().fill(GQColors.surfaceSecondary)
        #endif
    }

    private func ringColor(_ member: CrewMember) -> some ShapeStyle {
        switch member.status {
        case .live: return AnyShapeStyle(GQColors.success)
        case .recent: return AnyShapeStyle(GQGradients.primary)
        case .inactive: return AnyShapeStyle(GQColors.borderDefault)
        }
    }

    private func isLive(_ member: CrewMember) -> Bool {
        if case .live = member.status { return true }
        return false
    }

    private func isInactive(_ member: CrewMember) -> Bool {
        if case .inactive = member.status { return true }
        return false
    }

    private func firstName(_ member: CrewMember) -> String {
        member.name.split(separator: " ").first.map(String.init) ?? member.name
    }
}
