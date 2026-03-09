//
//  AISetupChatViewModel.swift
//  GymQuest
//
//  Created by Benjamin Hilderman
//
//  State machine driving the 14-step AI setup chat flow.
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
    var showChart: Bool

    init(
        id: UUID = UUID(),
        content: String,
        isUser: Bool,
        options: [OptionButton]? = nil,
        isTyping: Bool = false,
        showChart: Bool = false
    ) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.options = options
        self.isTyping = isTyping
        self.showChart = showChart
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
    case height
    case weight
    case distanceUnit
    case experience
    case goal
    case environment
    case equipment
    case referralCode
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
    var collectedDistanceUnit: DistanceUnit = .km
    var collectedExperience: ExperienceLevel?
    var collectedGoal: FitnessGoal = .hypertrophy
    var collectedEnvironment: WorkoutEnvironment?
    var collectedEquipment: Set<EquipmentType> = []
    var collectedDaysPerWeek: Int = 4
    var collectedReferralCode: String = ""

    // Equipment multi-select state
    var isEquipmentSelecting: Bool = false

    // AuthService reference for username uniqueness checks
    var authService: AuthService?

    // Pre-filled from Google sign-in
    var prefillName: String?

    // Picker state for height/weight
    var pickerHeightFeet: Int = 5
    var pickerHeightInches: Int = 9
    var pickerHeightCm: Int = 175
    var pickerWeightLbs: Int = 160
    var pickerWeightKg: Int = 73

    // Set to true after the AI message lands (typing indicator resolved)
    var readyForInput = false

    // Whether current step expects text input
    var isTextInputStep: Bool {
        guard readyForInput else { return false }
        switch currentStep {
        case .name, .username, .referralCode: return true
        default: return false
        }
    }

    // Whether current step uses a wheel picker
    var isPickerStep: Bool {
        guard readyForInput else { return false }
        switch currentStep {
        case .height, .weight: return true
        default: return false
        }
    }

    var completedAnswerSteps: Int {
        max(0, min(currentStep.rawValue - 1, 12))
    }

    var textFieldPlaceholder: String {
        switch currentStep {
        case .name: return "Your name"
        case .username: return "@username"
        case .referralCode: return "Referral code (optional)"
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
            try? await Task.sleep(for: .milliseconds(300))
            advanceToStep(.name)
        }
    }

    func selectOption(_ option: OptionButton) {
        guard !isProcessing else { return }
        isProcessing = true

        addUserMessage(option.label)
        storeValue(option.value, for: currentStep)

        Task {
            try? await Task.sleep(for: .milliseconds(600))
            advanceToNextStep()
            isProcessing = false
        }
    }

    func submitTextInput() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Allow empty submission for referral code (skip)
        if currentStep == .referralCode && text.isEmpty {
            isProcessing = true
            addUserMessage("Skipped")
            inputText = ""
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                advanceToNextStep()
                isProcessing = false
            }
            return
        }

        guard !text.isEmpty, !isProcessing else { return }
        isProcessing = true

        addUserMessage(text)
        storeTextValue(text, for: currentStep)
        inputText = ""

        // Username uniqueness check
        if currentStep == .username,
           let authService,
           authService.usernameExists(collectedUsername) {
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                await sendAIMessage("That username is already taken. Try another one.")
                isProcessing = false
            }
            return
        }

        Task {
            try? await Task.sleep(for: .milliseconds(600))
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

    func confirmPicker() {
        guard !isProcessing else { return }
        isProcessing = true

        if currentStep == .height {
            if collectedHeightUnit == .ftIn {
                let display = "\(pickerHeightFeet)'\(pickerHeightInches)\""
                addUserMessage(display)
                collectedHeightCm = UserProfile.ftInToCm(feet: pickerHeightFeet, inches: pickerHeightInches)
            } else {
                addUserMessage("\(pickerHeightCm) cm")
                collectedHeightCm = Double(pickerHeightCm)
            }
        } else if currentStep == .weight {
            if collectedWeightUnit == .lbs {
                addUserMessage("\(pickerWeightLbs) lbs")
                collectedWeightKg = UserProfile.lbsToKg(Double(pickerWeightLbs))
            } else {
                addUserMessage("\(pickerWeightKg) kg")
                collectedWeightKg = Double(pickerWeightKg)
            }
        }

        Task {
            try? await Task.sleep(for: .milliseconds(600))
            advanceToNextStep()
            isProcessing = false
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
            try? await Task.sleep(for: .milliseconds(600))
            advanceToNextStep()
            isProcessing = false
        }
    }

    func goBack() {
        guard currentStep.rawValue > SetupStep.name.rawValue,
              currentStep != .completion,
              !isProcessing,
              let previousStep = SetupStep(rawValue: currentStep.rawValue - 1)
        else { return }

        isEquipmentSelecting = false
        advanceToStep(previousStep)
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
        profile.distanceUnit = collectedDistanceUnit
        profile.experienceLevel = collectedExperience
        profile.goal = collectedGoal
        profile.workoutEnvironment = collectedEnvironment
        profile.availableEquipment = Array(collectedEquipment)
        profile.daysPerWeek = collectedDaysPerWeek
        profile.fitnessProfileCompleted = currentStep == .completion
        if !collectedReferralCode.isEmpty {
            profile.referredByCode = collectedReferralCode
        }
        profile.referralCode = UserProfile.generateReferralCode()
    }

    // MARK: - Private Helpers

    private func advanceToNextStep() {
        guard let nextIndex = SetupStep(rawValue: currentStep.rawValue + 1) else { return }
        advanceToStep(nextIndex)
    }

    private func advanceToStep(_ step: SetupStep) {
        currentStep = step

        // Clear previous messages so each step feels fresh
        if step != .greeting {
            withAnimation(.easeOut(duration: 0.2)) {
                messages.removeAll()
            }
        }

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
            Task { await sendAIMessage("What's your gender?", options: options) }

        case .height:
            Task { await sendAIMessage("What's your height?") }

        case .weight:
            Task { await sendAIMessage("What's your weight?") }

        case .distanceUnit:
            let options = [
                OptionButton(label: "km", value: DistanceUnit.km.rawValue),
                OptionButton(label: "miles", value: DistanceUnit.miles.rawValue)
            ]
            Task { await sendAIMessage("Preferred distance units?", options: options) }

        case .experience:
            let options = ExperienceLevel.allCases.map { OptionButton(label: $0.rawValue) }
            Task { await sendAIMessage("Experience level? Join 50,000+ lifters.", options: options) }

        case .goal:
            let options = FitnessGoal.allCases.map { OptionButton(label: $0.rawValue) }
            Task { await sendAIMessage("What's your primary goal? 90% of users see results in 4 weeks.", options: options) }

        case .environment:
            let options = WorkoutEnvironment.allCases.map { OptionButton(label: $0.rawValue) }
            Task { await sendAIMessage("Where do you train?", options: options) }

        case .equipment:
            Task {
                await sendAIMessage("Select your equipment.")
                isEquipmentSelecting = true
            }

        case .referralCode:
            Task { await sendAIMessage("Got a referral code? Enter it below or skip.") }

        case .daysPerWeek:
            let options = (2...6).map { OptionButton(label: "\($0) days", value: "\($0)") }
            Task { await sendAIMessage("Days per week?", options: options) }

        case .completion:
            Task { await sendAIMessage("Welcome to the Lift AI community. You're all set.") }
        }
    }

    private func sendAIMessage(_ content: String, options: [OptionButton]? = nil, showChart: Bool = false) async {
        readyForInput = false

        // Add typing indicator
        let typingId = UUID()
        let typingMsg = SetupMessage(id: typingId, content: "", isUser: false, isTyping: true)
        messages.append(typingMsg)

        // Simulate typing delay
        let delay = Int.random(in: 400...600)
        try? await Task.sleep(for: .milliseconds(delay))

        // Replace typing indicator with actual message
        if let idx = messages.firstIndex(where: { $0.id == typingId }) {
            messages[idx] = SetupMessage(content: content, isUser: false, options: options, showChart: showChart)
        }

        readyForInput = true
    }

    private func addUserMessage(_ content: String) {
        messages.append(SetupMessage(content: content, isUser: true))
    }

    private func storeValue(_ value: String, for step: SetupStep) {
        switch step {
        case .gender:
            collectedGender = Gender(rawValue: value)
        case .distanceUnit:
            collectedDistanceUnit = DistanceUnit(rawValue: value) ?? .km
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
        case .referralCode:
            collectedReferralCode = text.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        default:
            break
        }
    }

    private func generateUsername(from name: String) -> String {
        let base = name.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .filter { $0.isLetter || $0.isNumber }
        if base.isEmpty { return "athlete\(Int.random(in: 100...999))" }
        return base
    }
}
