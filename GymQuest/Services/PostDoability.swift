import Foundation

extension Post {
    /// 0.0–1.0 score indicating how runnable this post is as a workout.
    /// 1.0 = a full SharedWorkoutData program with structure and clear stats.
    /// 0.0 = a cinematic clip with no exercise structure (pure entertainment).
    /// Train shelves rank by this descending; Watch shelves ignore it.
    var doabilityScore: Double {
        var score = 0.0

        // Strongest signal: a runnable program is embedded.
        if sharedWorkoutData != nil {
            score += 0.50
        }

        // Per-exercise media tagging implies the author teaches form clip-by-clip.
        if mediaItems.contains(where: { $0.exerciseIndex != nil }) {
            score += 0.20
        }

        // Structured stats (sets + duration) indicate a real workout, not a moment.
        if (setCount ?? 0) > 0 && (duration ?? 0) > 0 {
            score += 0.15
        }

        // A named workout type without a full program still implies do-ability:
        // the user knows what they'd be doing even without per-set structure.
        if workoutType != nil && sharedWorkoutData == nil {
            score += 0.20
        }

        // A post with only a single short clip and no exercise tags trends Watch.
        let hasOnlyShortClip = mediaItems.count == 1 &&
            mediaItems.first?.mediaType == .video &&
            mediaItems.first?.exerciseIndex == nil &&
            sharedWorkoutData == nil
        if hasOnlyShortClip {
            score -= 0.20
        }

        // Video length signal (refines the simple "is video?" check):
        //   * Long-form clips (>30s) with an exercise tag read as tutorials → +0.10
        //   * Very short cinematic loops (<8s) without exercise tags read as eye candy → -0.10
        if let firstVideo = mediaItems.first(where: { $0.mediaType == .video }),
           let seconds = firstVideo.videoDurationSeconds {
            if seconds > 30 && firstVideo.exerciseIndex != nil {
                score += 0.10
            } else if seconds < 8 && firstVideo.exerciseIndex == nil {
                score -= 0.10
            }
        }

        return max(0.0, min(1.0, score))
    }

    /// Coarse intent classification for shelf placement.
    /// `.either` posts can appear in both Train and Watch shelves (with different ranks).
    var intentTag: PostIntentTag {
        let s = doabilityScore
        if s >= 0.55 { return .train }
        if s <= 0.15 { return .watch }
        return .either
    }
}

enum PostIntentTag: String, Codable {
    case train
    case watch
    case either
}
