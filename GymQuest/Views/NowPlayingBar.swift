//
//  NowPlayingBar.swift
//  GymQuest
//
//  Floating "Now Playing" capsule bar above the tab bar
//  Shows album art, scrolling title, artist, EQ bars, controls
//

import SwiftUI

struct NowPlayingBar: View {
    @State private var nowPlaying = NowPlayingService.shared
    @State private var dragOffset: CGFloat = 0

    private var accentColor: Color {
        nowPlaying.currentSong?.source.color ?? GQColors.deepBlue
    }

    var body: some View {
        if nowPlaying.isVisible, let song = nowPlaying.currentSong {
            barContent(song: song)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(GQMotion.standard, value: nowPlaying.isVisible)
        }
    }

    @ViewBuilder
    private func barContent(song: Song) -> some View {
        HStack(spacing: 10) {
            // Album art
            albumArt

            // Song info (title marquee + artist)
            VStack(alignment: .leading, spacing: 1) {
                Text(song.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)
                    .lineLimit(1)

                Text(song.artist)
                    .font(.system(size: 11))
                    .foregroundColor(GQColors.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // EQ bars
            MusicEQBars(
                barCount: 3,
                barWidth: 2.5,
                maxHeight: 14,
                color: accentColor,
                isPlaying: nowPlaying.isPlaying
            )

            // Play/Pause
            Button {
                HapticManager.shared.select()
                nowPlaying.togglePlayPause()
            } label: {
                Image(systemName: nowPlaying.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Dismiss
            Button {
                HapticManager.shared.select()
                withAnimation(GQMotion.standard) {
                    nowPlaying.dismiss()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(GQColors.textTertiary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(accentColor.opacity(0.35), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 40 {
                        HapticManager.shared.select()
                        withAnimation(GQMotion.standard) {
                            nowPlaying.dismiss()
                        }
                    }
                    withAnimation(GQMotion.micro) {
                        dragOffset = 0
                    }
                }
        )
    }

    @ViewBuilder
    private var albumArt: some View {
        Group {
            #if canImport(UIKit)
            if let image = nowPlaying.albumArtImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                artworkPlaceholder
            }
            #else
            artworkPlaceholder
            #endif
        }
        .frame(width: 36, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var artworkPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(accentColor.opacity(0.18))
            Image(systemName: "music.note")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(accentColor)
        }
    }
}
