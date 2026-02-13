import SwiftUI

struct WorkoutEmotionPicker: View {
    @Binding var selectedEmotion: WorkoutEmotion?
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HOW DO YOU FEEL?")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(GQColors.textTertiary)
                .tracking(1)

            if compact {
                compactLayout
            } else {
                gridLayout
            }
        }
    }

    @ViewBuilder
    private var compactLayout: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(WorkoutEmotion.allCases, id: \.self) { emotion in
                    EmotionChip(
                        emotion: emotion,
                        isSelected: selectedEmotion == emotion
                    ) {
                        toggleEmotion(emotion)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var gridLayout: some View {
        let columns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]

        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(WorkoutEmotion.allCases, id: \.self) { emotion in
                EmotionChip(
                    emotion: emotion,
                    isSelected: selectedEmotion == emotion
                ) {
                    toggleEmotion(emotion)
                }
            }
        }
    }

    private func toggleEmotion(_ emotion: WorkoutEmotion) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            selectedEmotion = selectedEmotion == emotion ? nil : emotion
        }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

struct EmotionChip: View {
    let emotion: WorkoutEmotion
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(emotion.emoji)
                    .font(.system(size: 26))
                Text(emotion.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .white : .gray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? emotion.color.opacity(0.25) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? emotion.color.opacity(0.5) : Color.clear, lineWidth: 1)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
    }
}
