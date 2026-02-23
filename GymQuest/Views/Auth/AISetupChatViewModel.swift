//
//  AISetupChatViewModel.swift
//  GymQuest
//
//  Created by Benjamin Hilderman
//
//  State machine driving the 13-step AI setup chat flow.
//  Collects identity + fitness profile data in a conversational UI.
//

import Foundation
import SwiftUI

// MARK: - Setup Message Model

struct SetupMessage: Identifiable {
    let id: UUID
    let content: String
    let isUser: Bool
    let options: [OptionButton]?
    var isTyping: Bool

    init(
        id: UUID = UUID(),
        content: String,
        isUser: Bool,
        options: [OptionButton]? = nil,
        isTyping: Bool = false
    ) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.options = options
        self.isTyping = isTyping
    }
}

struct OptionButton: Identifiable, Hashable {
    let id: UUID
    let label: String
    let value: String

    init(label: String, value: String? = nil) {
        self.id = UUID()
        self.label = label
        self.value = value ?? label
    }
}

// MARK: - Setup Steps

enum SetupStep: Int, CaseIterable {
    case greeting
    case name
    case username
    case gender
    case heightUnit
    case height
    case weightUnit
    case weight
    case experience
    case goal
    case environment
    case equipment
    case daysPerWeek
    case completion
}

// MARK: - ViewModel

@Observable
@MainActor
final class AISetupChatViewModel {
    var messages: [SetupMessage] = []
    var currentStep: SetupStep = .greeting
    var inputText: String = ""
    var isProcessing: Bool = false

    // Collected data
    var collectedName: String = ""
    var collectedUsername: String = ""
    var collectedGender: Gender?
    var collectedHeightUnit: HeightUnit = .ftIn
    var collectedHeightCm: Double?
    var collectedWeightUnit: WeightUnit = .lbs
    var collectedWeightKg: Double?
    var collectedExperience: ExperienceLevel?
    var collectedGoal: FitnessGoal = .hypertrophy
    var collectedEnvironment: WorkoutEnvironment?
    var collectedEquipment: Set<EquipmentType> = []
    var collectedDaysPerWeek: Int = 4

    // Equipment multi-select state
    var isEquipmentSelecting: Bool = false

    // Pre-filled from Google sign-in
    var prefillName: String?

    // Whether current step expects text input
    var isTextInputStep: Bool {
        switch currentStep {
        case .name, .username, .height, .weight: return true
        default: return false
        }
    }

    var textFieldPlaceholder: String {
        switch currentStep {
        case .name: return "Your name"
        case .username: return "@username"
        case .height:
            return collectedHeightUnit == .ftIn ? "e.g. 5'10" : "e.g. 175"
        case .weight:
            return collectedWeightUnit == .lbs ? "e.g. 175" : "e.g. 80"
        default: return ""
        }
    }

    // MARK: - Chat Flow

    func startChat() {
        Task {
            await sendAIMessage(
                "Welcome to Lift AI. Let's set up your profile.",
                options: nil
            )
            try? await Task.sleep(for: .milliseconds(600))
            advanceToStep(.name)
        }
    }

    func selectOption(_ option: OptionButton) {
        guard !isProcessing else { return }
        isProcessing = true

        addUserMessage(option.label)
        storeValue(option.value, for: currentStep)

        Task {
            try? await Task.sleep(for: .milliseconds(300))
            advanceToNextStep()
            isProcessing = false
        }
    }

    func submitTextInput() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isProcessing else { return }
        isProcessing = true

        addUserMessage(text)
        storeTextValue(text, for: currentStep)
        inputText = ""

        Task {
            try? await Task.sleep(for: .milliseconds(300))
            advanceToNextStep()
            isProcessing = false
        }
    }

    func toggleEquipment(_ type: EquipmentType) {
        if collectedEquipment.contains(type) {
            collectedEquipment.remove(type)
        } else {
            collectedEquipment.insert(type)
        }
    }

    func confirmEquipment() {
        guard !isProcessing else { return }
        isProcessing = true
        isEquipmentSelecting = false

        let names = collectedEquipment.isEmpty
            ? "Bodyweight Only"
            : collectedEquipment.map(\.rawValue).sorted().joined(separator: ", ")
        addUserMessage(names)

        Task {
            try? await Task.sleep(for: .milliseconds(300))
            advanceToNextStep()
            isProcessing = false
        }
    }

    func skipSetup() {
        collectedName = prefillName ?? "Athlete"
        collectedUsername = generateUsername(from: collectedName)
        isProcessing = true
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    advanceToStep(.completion)
                    isProcessing = false
                }
            }
        }
    }

    // MARK: - Apply to Profile

    func applyToProfile(_ profile: UserProfile) {
        profile.gender = collectedGender
        profile.heightUnit = collectedHeightUnit
        profile.heightCm = collectedHeightCm
        profile.weightUnit = collectedWeightUnit
        profile.weightKg = collectedWeightKg
        profile.experienceLevel = collectedExperience
        profile.goal = collectedGoal
        profile.workoutEnvironment = collectedEnvironment
        profile.availableEquipment = Array(collectedEquipment)
        profile.daysPerWeek = collectedDaysPerWeek
        profile.fitnessProfileCompleted = currentStep == .completion
    }

    // MARK: - Private Helpers

    private func advanceToNextStep() {
        guard let nextIndex = SetupStep(rawValue: currentStep.rawValue + 1) else { return }
        advanceToStep(nextIndex)
    }

    private func advanceToStep(_ step: SetupStep) {
        currentStep = step

        switch step {
        case .greeting:
            break // handled by startChat()

        case .name:
            let msg = "What's your name?"
            if let google = prefillName, !google.isEmpty {
                inputText = google
            }
            Task { await sendAIMessage(msg) }

        case .username:
            let suggested = generateUsername(from: collectedName)
            inputText = suggested
            Task { await sendAIMessage("Choose a username.") }

        case .gender:
            let options = Gender.allCases.map { OptionButton(label: $0.rawValue) }
            Task { await sendAIMessage("How should we personalize your training?", options: options) }

        case .heightUnit:
            let options = [
                OptionButton(label: "ft/in", value: HeightUnit.ftIn.rawValue),
                OptionButton(label: "cm", value: HeightUnit.cm.rawValue)
            ]
            Task { await sendAIMessage("Preferred height units?", options: options) }

        case .height:
            Task { await sendAIMessage("What's your height?") }

        case .weightUnit:
            let options = [
                OptionButton(label: "lbs", value: WeightUnit.lbs.rawValue),
                OptionButton(label: "kg", value: WeightUnit.kg.rawValue)
            ]
            Task { await sendAIMessage("Preferred weight units?", options: options) }

        case .weight:
            Task { await sendAIMessage("What's your weight?") }

        case .experience:
            let options = ExperienceLevel.allCases.map { OptionButton(label: $0.rawValue) }
            Task { await sendAIMessage("Experience level?", options: options) }

        case .goal:
            let options = FitnessGoal.allCases.map { OptionButton(label: $0.rawValue) }
            Task { await sendAIMessage("What's your primary goal?", options: options) }

        case .environment:
            let options = WorkoutEnvironment.allCases.map { OptionButton(label: $0.rawValue) }
            Task { await sendAIMessage("Where do you train?", options: options) }

        case .equipment:
            isEquipmentSelecting = true
            Task { await sendAIMessage("Select your equipment.") }

        case .daysPerWeek:
            let options = (2...6).map { OptionButton(label: "\($0) days", value: "\($0)") }
            Task { await sendAIMessage("Days per week?", options: options) }

        case .completion:
            Task { await sendAIMessage("You're all set.") }
        }
    }

    private func sendAIMessage(_ content: String, options: [OptionButton]? = nil) async {
        // Add typing indicator
        let typingId = UUID()
        let typingMsg = SetupMessage(id: typingId, content: "", isUser: false, isTyping: true)
        messages.append(typingMsg)

        // Simulate typing delay
        let delay = Int.random(in: 400...800)
        try? await Task.sleep(for: .milliseconds(delay))

        // Replace typing indicator with actual message
        if let idx = messages.firstIndex(where: { $0.id == typingId }) {
            messages[idx] = SetupMessage(content: content, isUser: false, options: options)
        }
    }

    private func addUserMessage(_ content: String) {
        messages.append(SetupMessage(content: content, isUser: true))
    }

    private func storeValue(_ value: String, for step: SetupStep) {
        switch step {
        case .gender:
            collectedGender = Gender(rawValue: value)
        case .heightUnit:
            collectedHeightUnit = HeightUnit(rawValue: value) ?? .ftIn
        case .weightUnit:
            collectedWeightUnit = WeightUnit(rawValue: value) ?? .lbs
        case .experience:
            collectedExperience = ExperienceLevel(rawValue: value)
        case .goal:
            collectedGoal = FitnessGoal(rawValue: value) ?? .hypertrophy
        case .environment:
            collectedEnvironment = WorkoutEnvironment(rawValue: value)
        case .daysPerWeek:
            collectedDaysPerWeek = Int(value) ?? 4
        default:
            break
        }
    }

    private func storeTextValue(_ text: String, for step: SetupStep) {
        switch step {
        case .name:
            collectedName = text
        case .username:
            let clean = text.hasPrefix("@") ? String(text.dropFirst()) : text
            collectedUsername = clean.lowercased().replacingOccurrences(of: " ", with: "")
        case .height:
            collectedHeightCm = parseHeight(text)
        case .weight:
            collectedWeightKg = parseWeight(text)
        default:
            break
        }
    }

    private func parseHeight(_ text: String) -> Double? {
        if collectedHeightUnit == .ftIn {
            // Parse formats like "5'10", "5 10", "5'10\"", "510"
            let cleaned = text.replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: "'", with: " ")
                .replacingOccurrences(of: "'", with: " ")
                .replacingOccurrences(of: "'", with: " ")
            let parts = cleaned.split(separator: " ").compactMap { Int($0) }
            if parts.count >= 2 {
                return UserProfile.ftInToCm(feet: parts[0], inches: parts[1])
            } else if parts.count == 1 {
                let val = parts[0]
                if val > 12 {
                    // Entered as total inches or "510" format
                    let feet = val / 100 > 0 ? val / 100 : val / 12
                    let inches = val / 100 > 0 ? val % 100 : val % 12
                    return UserProfile.ftInToCm(feet: feet, inches: inches)
                }
                return UserProfile.ftInToCm(feet: val, inches: 0)
            }
            return nil
        } else {
            return Double(text)
        }
    }

    private func parseWeight(_ text: String) -> Double? {
        guard let value = Double(text) else { return nil }
        if collectedWeightUnit == .lbs {
            return UserProfile.lbsToKg(value)
        }
        return value
    }

    private func generateUsername(from name: String) -> String {
        let base = name.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .filter { $0.isLetter || $0.isNumber }
        if base.isEmpty { return "athlete\(Int.random(in: 100...999))" }
        return base
    }
}
