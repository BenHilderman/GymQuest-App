import SwiftUI

struct EmotionInsightsCard: View {
    let insights: EmotionInsights

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if insights.resilienceStreak >= 2 {
                resilienceCallout
            }
            distributionBar
            emotionLegend
            motivationalMessage
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(white: 0.97)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(0.04), lineWidth: 1))
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 16))
                .foregroundColor(GQColors.vividPurple)
            Text("EMOTION JOURNEY")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(GQColors.textTertiary)
                .tracking(1)
            Spacer()
            Text("\(insights.totalPostsWithEmotion) workouts")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
        }
    }

    @ViewBuilder
    private var resilienceCallout: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.system(size: 14))
                .foregroundColor(GQColors.sunsetOrange)
            Text("\(insights.resilienceStreak) workouts showing up when it's hard — that takes real grit")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(GQColors.textPrimary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(GQColors.sunsetOrange.opacity(0.1))
        )
    }

    @ViewBuilder
    private var distributionBar: some View {
        EmotionDistributionBar(distribution: insights.distribution, total: insights.totalPostsWithEmotion)
    }

    @ViewBuilder
    private var emotionLegend: some View {
        let columns = [
            GridItem(.adaptive(minimum: 80), spacing: 8)
        ]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(insights.distribution) { item in
                HStack(spacing: 4) {
                    Text(item.emotion.emoji)
                        .font(.system(size: 12))
                    Text("\(item.count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(item.emotion.color)
                }
            }
        }
    }

    @ViewBuilder
    private var motivationalMessage: some View {
        Text(insights.encouragementMessage)
            .font(.system(size: 13, weight: .medium))
            .italic()
            .foregroundColor(GQColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EmotionDistributionBar: View {
    let distribution: [EmotionDistribution]
    let total: Int

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(distribution) { item in
                    let fraction = total > 0 ? CGFloat(item.count) / CGFloat(total) : 0
                    RoundedRectangle(cornerRadius: 4)
                        .fill(item.emotion.color)
                        .frame(width: max(fraction * geo.size.width - 2, 4))
                }
            }
        }
        .frame(height: 10)
        .clipShape(Capsule())
    }
}
