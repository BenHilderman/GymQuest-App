//
//  HapticManager.swift
//  GymQuest
//
//  Centralized haptic feedback for the active workout experience.
//  Provides satisfying tactile responses for every key interaction.
//

import Foundation

#if canImport(UIKit)
import UIKit

struct HapticManager {
    static let shared = HapticManager()

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()

    private init() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        notification.prepare()
        selection.prepare()
    }

    // MARK: - Set Interactions

    func setComplete() {
        notification.notificationOccurred(.success)
    }

    func exerciseComplete() {
        impactHeavy.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [self] in
            notification.notificationOccurred(.success)
        }
    }

    func prDetected() {
        impactHeavy.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [self] in
            impactMedium.impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) { [self] in
            impactHeavy.impactOccurred()
        }
    }

    // MARK: - Rest Timer

    func restTimerWarning() {
        impactMedium.impactOccurred()
    }

    func restTimerCountdown() {
        impactHeavy.impactOccurred()
    }

    func restTimerDone() {
        notification.notificationOccurred(.success)
    }

    // MARK: - Milestones

    func milestoneReached() {
        impactHeavy.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [self] in
            impactHeavy.impactOccurred()
        }
    }

    // MARK: - Countdown Launch

    func countdownBeat() {
        impactHeavy.impactOccurred()
    }

    func countdownGo() {
        impactHeavy.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            impactHeavy.impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [self] in
            notification.notificationOccurred(.success)
        }
    }

    // MARK: - General UI

    func buttonTap() {
        selection.selectionChanged()
    }

    func fieldEdit() {
        impactLight.impactOccurred()
    }
}

#else

// macOS stub — no haptics
struct HapticManager {
    static let shared = HapticManager()
    func setComplete() {}
    func exerciseComplete() {}
    func prDetected() {}
    func restTimerWarning() {}
    func restTimerCountdown() {}
    func restTimerDone() {}
    func milestoneReached() {}
    func countdownBeat() {}
    func countdownGo() {}
    func buttonTap() {}
    func fieldEdit() {}
}

#endif
