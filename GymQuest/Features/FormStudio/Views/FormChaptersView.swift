//
//  FormChaptersView.swift
//  GymQuest
//
//  Chapter navigation UI for breakdown videos.
//

import SwiftUI

struct FormChaptersView: View {
    let chapters: [FormChapter]
    let currentTime: Double
    let onSelect: (Double) -> Void

    init(chapters: [FormChapter], currentTime: Double = 0, onSelect: @escaping (Double) -> Void) {
        self.chapters = chapters
        self.currentTime = currentTime
        self.onSelect = onSelect
    }

    var sortedChapters: [FormChapter] {
        chapters.sorted(by: { $0.order < $1.order })
    }

    var currentChapter: FormChapter? {
        sortedChapters.last(where: { $0.timeSeconds <= currentTime })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chapters")
                .font(.headline)
                .foregroundColor(GQColors.textPrimary)

            ForEach(sortedChapters) { chapter in
                ChapterRow(
                    chapter: chapter,
                    isActive: currentChapter?.id == chapter.id,
                    onTap: { onSelect(chapter.timeSeconds) }
                )
            }
        }
    }
}

// MARK: - Chapter Row

struct ChapterRow: View {
    let chapter: FormChapter
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Time badge
                Text(formatTime(chapter.timeSeconds))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(isActive ? GQColors.textPrimary : GQColors.textSecondary)
                    .frame(width: 44, alignment: .leading)

                // Title
                Text(chapter.title)
                    .font(.system(size: 15, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? GQColors.textPrimary : GQColors.textSecondary)

                Spacer()

                // Active indicator
                if isActive {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                        .foregroundColor(GQColors.primary)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(GQColors.primary.opacity(0.15))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Compact Chapter Strip

struct ChapterStrip: View {
    let chapters: [FormChapter]
    let duration: Double
    let currentTime: Double
    let onSelect: (Double) -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.black.opacity(0.12))
                    .frame(height: 4)

                // Progress
                RoundedRectangle(cornerRadius: 2)
                    .fill(GQColors.primary)
                    .frame(width: progressWidth(in: geo.size.width), height: 4)

                // Chapter markers
                ForEach(chapters) { chapter in
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                        .offset(x: markerOffset(for: chapter, in: geo.size.width) - 4)
                        .onTapGesture {
                            onSelect(chapter.timeSeconds)
                        }
                }
            }
        }
        .frame(height: 20)
    }

    private func progressWidth(in width: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        return width * CGFloat(currentTime / duration)
    }

    private func markerOffset(for chapter: FormChapter, in width: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        return width * CGFloat(chapter.timeSeconds / duration)
    }
}
