//
//  FormCuesMistakesView.swift
//  GymQuest
//
//  Cues and common mistakes display (max 5 cues, max 3 faults).
//

import SwiftUI

struct FormCuesMistakesView: View {
    let cues: [FormCue]
    let faults: [FormFault]

    var sortedCues: [FormCue] {
        cues.sorted(by: { $0.priority < $1.priority }).prefix(5).map { $0 }
    }

    var sortedFaults: [FormFault] {
        faults.sorted(by: { $0.priority < $1.priority }).prefix(3).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Cues Section
            cuesSection

            Divider()
                .background(Color.black.opacity(0.06))

            // Mistakes Section
            mistakesSection
        }
        .padding(16)
        .background(GQColors.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Cues

    private var cuesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "target")
                    .foregroundColor(GQColors.primary)

                Text("Key Cues")
                    .font(.headline)
                    .foregroundColor(GQColors.textPrimary)

                Spacer()

                Text("Max 5")
                    .font(.caption)
                    .foregroundColor(GQColors.textTertiary)
            }

            ForEach(Array(sortedCues.enumerated()), id: \.element.id) { index, cue in
                CueRow(number: index + 1, text: cue.text)
            }

            if cues.isEmpty {
                Text("No cues available")
                    .font(.subheadline)
                    .foregroundColor(GQColors.textSecondary)
                    .italic()
            }
        }
    }

    // MARK: - Mistakes

    private var mistakesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)

                Text("Common Mistakes")
                    .font(.headline)
                    .foregroundColor(GQColors.textPrimary)

                Spacer()

                Text("Max 3")
                    .font(.caption)
                    .foregroundColor(GQColors.textTertiary)
            }

            ForEach(sortedFaults) { fault in
                FaultRow(fault: fault)
            }

            if faults.isEmpty {
                Text("No common mistakes listed")
                    .font(.subheadline)
                    .foregroundColor(GQColors.textSecondary)
                    .italic()
            }
        }
    }
}

// MARK: - Cue Row

struct CueRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Number badge
            Text("\(number)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(GQColors.textPrimary)
                .frame(width: 22, height: 22)
                .background(GQColors.primary)
                .clipShape(Circle())

            Text(text)
                .font(.system(size: 15))
                .foregroundColor(GQColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Fault Row

struct FaultRow: View {
    let fault: FormFault

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Mistake
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red.opacity(0.8))
                    .font(.system(size: 14))

                Text(fault.mistake)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(GQColors.textPrimary.opacity(0.9))
            }

            // Fix
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green.opacity(0.8))
                    .font(.system(size: 14))

                Text(fault.fixCue)
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.textSecondary)
            }
            .padding(.leading, 4)
        }
        .padding(12)
        .background(Color.black.opacity(0.03))
        .cornerRadius(10)
    }
}

// MARK: - Compact Cues Card (for in-workout)

struct CompactCuesCard: View {
    let cues: [FormCue]
    let maxCues: Int

    init(cues: [FormCue], maxCues: Int = 3) {
        self.cues = cues
        self.maxCues = maxCues
    }

    var topCues: [FormCue] {
        cues.sorted(by: { $0.priority < $1.priority }).prefix(maxCues).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(topCues) { cue in
                HStack(spacing: 8) {
                    Circle()
                        .fill(GQColors.primary)
                        .frame(width: 6, height: 6)

                    Text(cue.text)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(GQColors.textPrimary)
                        .lineLimit(2)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}
