//
//  FormOverlayLayer.swift
//  GymQuest
//
//  Broadcast-style overlay layer for form coaching callouts.
//

import SwiftUI

struct FormOverlayLayer: View {
    let events: [OverlayEvent]
    let currentTime: Double

    var activeEvent: OverlayEvent? {
        events.first(where: { currentTime >= $0.start && currentTime <= $0.end })
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let event = activeEvent {
                    OverlayCallout(text: event.text)
                        .frame(maxWidth: min(geo.size.width * 0.9, 520))
                        .position(anchorPosition(in: geo.size, anchor: event.anchor))
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .animation(.easeInOut(duration: 0.2), value: event.id)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func anchorPosition(in size: CGSize, anchor: String) -> CGPoint {
        switch anchor.lowercased() {
        case "top":
            return CGPoint(x: size.width / 2, y: size.height * 0.15)
        case "center":
            return CGPoint(x: size.width / 2, y: size.height * 0.50)
        case "bottom":
            return CGPoint(x: size.width / 2, y: size.height * 0.85)
        default:
            return CGPoint(x: size.width / 2, y: size.height * 0.85)
        }
    }
}

// MARK: - Overlay Callout

struct OverlayCallout: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))

            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                }
        }
        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black

        FormOverlayLayer(
            events: OverlayTimelineLoader.sampleEvents(),
            currentTime: 1.0
        )
    }
}
