//
//  FormEnums.swift
//  GymQuest
//
//  Form Studio enums for movement patterns, clip types, angles, and mastery levels.
//

import Foundation

enum FormMovementPattern: String, CaseIterable, Codable {
    case squat, hinge, horizontalPush, horizontalPull, verticalPush, verticalPull, lunge, carry, brace

    var title: String {
        switch self {
        case .horizontalPush: return "Horizontal Push"
        case .horizontalPull: return "Horizontal Pull"
        case .verticalPush: return "Vertical Push"
        case .verticalPull: return "Vertical Pull"
        default: return rawValue.capitalized
        }
    }

    var icon: String {
        switch self {
        case .squat: return "figure.stand"
        case .hinge: return "figure.flexibility"
        case .horizontalPush: return "figure.arms.open"
        case .horizontalPull: return "figure.rowing"
        case .verticalPush: return "figure.arms.open"
        case .verticalPull: return "figure.climbing"
        case .lunge: return "figure.walk"
        case .carry: return "figure.walk.motion"
        case .brace: return "figure.core.training"
        }
    }
}

enum ClipType: String, CaseIterable, Codable {
    case loop
    case breakdown
    case coachEye

    var title: String {
        switch self {
        case .loop: return "Loop (10-15s)"
        case .breakdown: return "Breakdown"
        case .coachEye: return "Coach's Eye"
        }
    }

    var description: String {
        switch self {
        case .loop: return "Quick reference loop"
        case .breakdown: return "Full technique breakdown with chapters"
        case .coachEye: return "Common faults and fixes"
        }
    }
}

enum ClipAngle: String, CaseIterable, Codable {
    case a45 = "45"
    case side
    case front
    case top

    var title: String {
        switch self {
        case .a45: return "45°"
        case .side: return "Side"
        case .front: return "Front"
        case .top: return "Top"
        }
    }
}

enum PatternLevel: String, CaseIterable, Codable {
    case learning, solid, advanced

    var title: String {
        rawValue.capitalized
    }

    var color: String {
        switch self {
        case .learning: return "yellow"
        case .solid: return "green"
        case .advanced: return "purple"
        }
    }
}

enum ExerciseFormState: String, CaseIterable, Codable {
    case new, practicing, consistent

    var title: String {
        rawValue.capitalized
    }
}
