import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Warm card that reframes the week from personal streak → crew rhythm.
/// Shows: crew training days, user's role, 7-day activity bar, and the
/// most-consistent crew member as a social cue.
struct CrewRhythmCard: View {
    let rhythm: CrewRhythm

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            rhythmBar
            if let footer = footerText {
                Text(footer)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(GQColors.surfaceBase)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(GQColors.borderDefault.opacity(0.5), lineWidth: 0.5)
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Your crew")
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(GQColors.textTertiary)
                .tracking(1.1)
            Spacer()
        }
        .overlay(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 4) {
                Spacer().frame(height: 16)
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text("\(rhythm.daysTrainedByCrew) of \(rhythm.totalDaysTracked)")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(GQGradients.primary)
                    Text("days this week")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(GQColors.textSecondary)
                }
                Text("You're in for \(rhythm.userDaysTrained)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 72, alignment: .top)
    }

    // MARK: - Rhythm bar

    private var rhythmBar: some View {
        let max = rhythm.perDayCrewCount.max() ?? 0
        return HStack(spacing: 6) {
            ForEach(0..<rhythm.perDayCrewCount.count, id: \.self) { idx in
                let count = rhythm.perDayCrewCount[idx]
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            count == 0
                                ? AnyShapeStyle(GQColors.surfaceSecondary)
                                : AnyShapeStyle(GQGradients.primary.opacity(0.3 + 0.7 * Double(count) / Double(max == 0 ? 1 : max)))
                        )
                        .frame(height: 28)
                    Text(dayInitial(offset: idx))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(GQColors.textTertiary)
                }
            }
        }
    }

    private func dayInitial(offset: Int) -> String {
        let cal = Calendar.current
        let day = cal.date(byAdding: .day, value: -(rhythm.totalDaysTracked - 1 - offset), to: Date()) ?? Date()
        let weekday = cal.component(.weekday, from: day)
        let map = ["S", "M", "T", "W", "T", "F", "S"]
        return map[(weekday - 1) % 7]
    }

    // MARK: - Footer line

    private var footerText: String? {
        if let companion = rhythm.todayCompanions.first {
            let more = rhythm.todayCompanions.count - 1
            if more > 0 {
                return "You and \(companion.name) + \(more) trained today ✨"
            }
            return "You and \(companion.name) trained today ✨"
        }
        if let top = rhythm.topMember, top.daysTrained >= 3 {
            return "\(top.name) is on a \(top.daysTrained)-day streak — match the energy?"
        }
        return nil
    }
}
