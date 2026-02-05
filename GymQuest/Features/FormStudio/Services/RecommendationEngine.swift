//
//  RecommendationEngine.swift
//  GymQuest
//
//  Rules-based recommendation engine for form progression.
//

import Foundation

struct RecommendationEngine {

    struct Recommendation: Identifiable {
        let id = UUID()
        let exerciseId: UUID
        let title: String
        let reason: String
        let action: RecommendationAction
    }

    enum RecommendationAction {
        case repeatExercise
        case watchBreakdown
        case watchCoachEye
        case tryHarderVariation
        case tryEasierVariation
        case completeSetup
    }

    static func nextSteps(
        currentExercise: FormExercise,
        mastery: ExerciseMastery
    ) -> [Recommendation] {
        var recommendations: [Recommendation] = []

        // Gate 1: Setup checklist
        if !mastery.setupChecklistCompleted {
            recommendations.append(
                Recommendation(
                    exerciseId: currentExercise.id,
                    title: "Complete Setup Checklist",
                    reason: "Learn the proper equipment setup before practicing.",
                    action: .completeSetup
                )
            )
        }

        // Gate 2: Watch breakdown
        if !mastery.watchedBreakdownCompleted {
            recommendations.append(
                Recommendation(
                    exerciseId: currentExercise.id,
                    title: "Watch the Breakdown",
                    reason: "Understand each phase of the movement.",
                    action: .watchBreakdown
                )
            )
        }

        // If not consistent, recommend repeating
        if mastery.state != .consistent {
            recommendations.append(
                Recommendation(
                    exerciseId: currentExercise.id,
                    title: "Repeat Next Session",
                    reason: "Build consistency before progressing.",
                    action: .repeatExercise
                )
            )
        }

        // If practicing but not high confidence, recommend coach's eye
        if mastery.state == .practicing && !mastery.hasTwoHighConfidenceRatings {
            recommendations.append(
                Recommendation(
                    exerciseId: currentExercise.id,
                    title: "Watch Coach's Eye",
                    reason: "Polish 1-2 common faults to progress faster.",
                    action: .watchCoachEye
                )
            )
        }

        // If user is consistent AND passes unlock rule, recommend harder
        if mastery.canUnlockNextVariation {
            if let harder = currentExercise.variations.first(where: { $0.kind == "harder" }) {
                recommendations.append(
                    Recommendation(
                        exerciseId: harder.targetExerciseId,
                        title: "Try a Harder Variation",
                        reason: "You've hit the form gates. Time to progress.",
                        action: .tryHarderVariation
                    )
                )
            }
        }

        // If struggling, suggest easier variation
        if mastery.sessionsCount >= 5 && !mastery.hasTwoHighConfidenceRatings {
            if let easier = currentExercise.variations.first(where: { $0.kind == "easier" }) {
                recommendations.append(
                    Recommendation(
                        exerciseId: easier.targetExerciseId,
                        title: "Try an Easier Variation",
                        reason: "Build confidence with a simpler version first.",
                        action: .tryEasierVariation
                    )
                )
            }
        }

        return recommendations
    }

    static func primaryRecommendation(
        currentExercise: FormExercise,
        mastery: ExerciseMastery
    ) -> Recommendation? {
        nextSteps(currentExercise: currentExercise, mastery: mastery).first
    }
}
