//
//  AISetupChatView.swift
//  GymQuest
//
//  Created by Benjamin Hilderman
//
//  Premium dark-themed conversational setup that replaces the old 3-step onboarding.
//  Collects identity + fitness profile in a single chat flow.
//

import SwiftUI
import SwiftData

// MARK: - Onboarding Light Theme

private enum OBColors {
    static let bg = Color(hex: "F8F8FC")
    static let cardSurface = Color.white
    static let optionSurface = Color(hex: "FDFAFF")
    static let textPrimary = Color(hex: "1C1C1E")
    static let textSecondary = Color(hex: "3C3C43").opacity(0.55)
    static let borderGradient = LinearGradient(
        colors: [Color(hex: "C9B8E8").opacity(0.4), Color(hex: "E8D0F0").opacity(0.3)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let userBubbleGradient = LinearGradient(
        colors: [GQColors.deepBlue.opacity(0.9), GQColors.vividPurple.opacity(0.9)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let sendGradient = LinearGradient(
        colors: [GQColors.deepBlue, GQColors.vividPurple],
        startPoint: .top,
        endPoint: .bottom
    )
    static let ctaGradient = LinearGradient(
        colors: [GQColors.deepBlue.opacity(0.9), GQColors.vividPurple.opacity(0.9)],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - AISetupChatView

struct AISetupChatView: View {
    let authMethod: String
    let email: String?
    let googleId: String?
    let tempPassword: String?

    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @StateObject private var authService = AuthService()

    @State private var viewModel = AISetupChatViewModel()
    @State private var keyboardHeight: CGFloat = 0
    @State private var keyboardShowObserver: NSObjectProtocol?
    @State private var keyboardHideObserver: NSObjectProtocol?
    @State private var animateDots = false
    @State private var shimmerPhase: CGFloat = 0

    private var storedPassword: String { tempPassword ?? "" }
    private var googleName: String? {
        UserDefaults.standard.string(forKey: "google_signup_name")
    }

    var body: some View {
        VStack(spacing: 0) {
            setupTopBar
            chatScrollView
            Group {
                if viewModel.isEquipmentSelecting {
                    equipmentMultiSelectGrid
                } else if viewModel.currentStep == .completion {
                    completionCard
                } else if viewModel.isPickerStep {
                    wheelPickerBar
                } else if viewModel.isTextInputStep {
                    textInputBar
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.currentStep)
        }
        .background(
            ZStack {
                OBColors.bg.ignoresSafeArea()
                shimmerBackground
            }
        )
        .onAppear {
            authService.setModelContext(modelContext)
            viewModel.prefillName = googleName
            viewModel.startChat()
            setupKeyboardObservers()
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: true)) {
                shimmerPhase = 1
            }
        }
        .onDisappear {
            removeKeyboardObservers()
        }
    }

    // MARK: - Shimmer Background

    @ViewBuilder
    private var shimmerBackground: some View {
        Canvas { context, size in
            // Just provides the frame — actual animation via overlaid circles
        }
        .overlay {
            Circle()
                .fill(Color(hex: "E8D0F0").opacity(0.25))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(
                    x: -60 + shimmerPhase * 120,
                    y: -100 + shimmerPhase * 50
                )

            Circle()
                .fill(Color(hex: "F0D8E8").opacity(0.2))
                .frame(width: 250, height: 250)
                .blur(radius: 70)
                .offset(
                    x: 80 - shimmerPhase * 100,
                    y: 150 - shimmerPhase * 80
                )

            Circle()
                .fill(Color(hex: "D8D0F0").opacity(0.18))
                .frame(width: 200, height: 200)
                .blur(radius: 60)
                .offset(
                    x: -40 + shimmerPhase * 60,
                    y: 300 - shimmerPhase * 120
                )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Top Bar

    @ViewBuilder
    private var setupTopBar: some View {
        HStack {
            Spacer()

            Text("Lift AI")
                .font(.headline)
                .foregroundStyle(OBColors.textPrimary)

            Spacer()
        }
        .overlay(alignment: .trailing) {
            Button {
                viewModel.skipSetup()
            } label: {
                Text("Skip")
                    .font(.subheadline)
                    .foregroundStyle(OBColors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Chat Scroll View

    @ViewBuilder
    private var chatScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                        if message.isTyping {
                            typingIndicator
                                .id(message.id)
                        } else {
                            setupMessageBubble(message, index: index)
                                .id(message.id)
                        }
                    }

                    if let lastMessage = viewModel.messages.last,
                       !lastMessage.isUser,
                       !lastMessage.isTyping,
                       let options = lastMessage.options {
                        optionButtonsGrid(options)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.vertical, 16)
                .padding(.bottom, 8)
                .animation(.easeOut(duration: 0.25), value: viewModel.messages.count)
            }
            .scrollDismissesKeyboard(.immediately)
            .onTapGesture {
                dismissKeyboard()
            }
            .onChange(of: viewModel.messages.count) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: keyboardHeight) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    // MARK: - Message Bubble

    @ViewBuilder
    private func setupMessageBubble(_ message: SetupMessage, index: Int) -> some View {
        HStack {
            if message.isUser { Spacer(minLength: 60) }

            Text(message.content)
                .font(.system(size: 15))
                .foregroundColor(message.isUser ? .white : OBColors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Group {
                        if message.isUser {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(OBColors.userBubbleGradient)
                        } else {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(OBColors.cardSurface)
                        }
                    }
                )
                .overlay(
                    Group {
                        if !message.isUser {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(OBColors.borderGradient, lineWidth: 1)
                        }
                    }
                )
                .shadow(
                    color: message.isUser
                        ? GQColors.deepBlue.opacity(0.12)
                        : Color(hex: "C9B8E8").opacity(0.15),
                    radius: message.isUser ? 8 : 10,
                    y: 2
                )
                .modifier(BubbleAppearModifier(isUser: message.isUser))

            if !message.isUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Option Buttons Grid

    @ViewBuilder
    private func optionButtonsGrid(_ options: [OptionButton]) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]

        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                Button {
                    viewModel.selectOption(option)
                } label: {
                    Text(option.label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(OBColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(OBColors.optionSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(OBColors.borderGradient, lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
                }
                .buttonStyle(OptionPressStyle())
                .disabled(viewModel.isProcessing)
                .modifier(StaggeredAppearModifier(delay: Double(index) * 0.05))
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Equipment Multi-Select Grid

    @ViewBuilder
    private var equipmentMultiSelectGrid: some View {
        VStack(spacing: 12) {
            let columns = [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ]

            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(EquipmentType.allCases, id: \.self) { type in
                        let isSelected = viewModel.collectedEquipment.contains(type)

                        Button {
                            viewModel.toggleEquipment(type)
                        } label: {
                            HStack(spacing: 4) {
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(GQColors.cyanSpark)
                                }
                                Text(type.rawValue)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(isSelected ? GQColors.cyanSpark : OBColors.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(isSelected ? GQColors.vividPurple.opacity(0.15) : OBColors.cardSurface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        isSelected ? OBColors.borderGradient : LinearGradient(colors: [Color.clear], startPoint: .top, endPoint: .bottom),
                                        lineWidth: 1.5
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(maxHeight: 240)

            Button {
                viewModel.confirmEquipment()
            } label: {
                Text("Done")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Capsule().fill(OBColors.ctaGradient))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .disabled(viewModel.isProcessing)
        }
        .padding(.vertical, 12)
        .background(OBColors.bg)
    }

    // MARK: - Wheel Picker Bar

    @ViewBuilder
    private var wheelPickerBar: some View {
        VStack(spacing: 12) {
            if viewModel.currentStep == .height {
                heightPicker
            } else {
                weightPicker
            }

            Button {
                viewModel.confirmPicker()
            } label: {
                Text("Confirm")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Capsule().fill(OBColors.ctaGradient))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .disabled(viewModel.isProcessing)
        }
        .padding(.vertical, 12)
        .background(OBColors.bg)
    }

    @ViewBuilder
    private var heightPicker: some View {
        if viewModel.collectedHeightUnit == .ftIn {
            HStack(spacing: 0) {
                Picker("Feet", selection: $viewModel.pickerHeightFeet) {
                    ForEach(4...7, id: \.self) { ft in
                        Text("\(ft) ft").tag(ft)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)

                Picker("Inches", selection: $viewModel.pickerHeightInches) {
                    ForEach(0...11, id: \.self) { inches in
                        Text("\(inches) in").tag(inches)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
            }
            .frame(height: 150)
            .padding(.horizontal, 20)
        } else {
            Picker("Height (cm)", selection: $viewModel.pickerHeightCm) {
                ForEach(140...210, id: \.self) { cm in
                    Text("\(cm) cm").tag(cm)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 150)
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private var weightPicker: some View {
        if viewModel.collectedWeightUnit == .lbs {
            Picker("Weight (lbs)", selection: $viewModel.pickerWeightLbs) {
                ForEach(80...350, id: \.self) { lbs in
                    Text("\(lbs) lbs").tag(lbs)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 150)
            .padding(.horizontal, 20)
        } else {
            Picker("Weight (kg)", selection: $viewModel.pickerWeightKg) {
                ForEach(35...160, id: \.self) { kg in
                    Text("\(kg) kg").tag(kg)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 150)
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Text Input Bar

    @ViewBuilder
    private var textInputBar: some View {
        HStack(spacing: 10) {
            TextField(viewModel.textFieldPlaceholder, text: $viewModel.inputText)
                .font(.system(size: 16))
                .foregroundColor(OBColors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(OBColors.cardSurface)
                )
                .submitLabel(.send)
                .onSubmit { viewModel.submitTextInput() }

            Button(action: { viewModel.submitTextInput() }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(
                        .white,
                        viewModel.inputText.isEmpty ? Color.white.opacity(0.2) : GQColors.vividPurple
                    )
            }
            .disabled(viewModel.inputText.isEmpty || viewModel.isProcessing)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, keyboardHeight > 0 ? 8 : 34)
        .background(OBColors.bg)
    }

    // MARK: - Typing Indicator

    @ViewBuilder
    private var typingIndicator: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "C9B8E8"), Color(hex: "E8D0F0")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 8, height: 8)
                        .scaleEffect(animateDots ? 1.2 : 0.7)
                        .opacity(animateDots ? 1.0 : 0.3)
                        .animation(
                            .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                            value: animateDots
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(OBColors.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(OBColors.borderGradient, lineWidth: 1)
            )
            .onAppear { animateDots = true }

            Spacer(minLength: 60)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Completion Card

    @ViewBuilder
    private var completionCard: some View {
        VStack(spacing: 16) {
            Button {
                createProfile()
            } label: {
                Text("Get Started")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Capsule().fill(OBColors.ctaGradient))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(OBColors.bg)
    }

    // MARK: - Profile Creation

    private func createProfile() {
        var profile: UserProfile?

        if authMethod == "google", let googleId {
            profile = authService.registerWithGoogle(
                name: viewModel.collectedName.isEmpty ? "Athlete" : viewModel.collectedName,
                username: viewModel.collectedUsername.isEmpty ? "athlete" : viewModel.collectedUsername,
                dateOfBirth: Date(),
                googleId: googleId,
                email: email
            )
            UserDefaults.standard.removeObject(forKey: "google_signup_name")
        } else if authMethod == "email", let email {
            profile = authService.register(
                name: viewModel.collectedName.isEmpty ? "Athlete" : viewModel.collectedName,
                username: viewModel.collectedUsername.isEmpty ? "athlete" : viewModel.collectedUsername,
                dateOfBirth: Date(),
                email: email,
                password: storedPassword
            )
        }

        if let profile {
            viewModel.applyToProfile(profile)
            try? modelContext.save()

            // Store onboarding data for training plan offer
            appState.onboardingData = OnboardingData(
                name: viewModel.collectedName.isEmpty ? "Athlete" : viewModel.collectedName,
                goal: viewModel.collectedGoal,
                experience: viewModel.collectedExperience ?? .beginner,
                environment: viewModel.collectedEnvironment ?? .gym,
                equipment: viewModel.collectedEquipment,
                daysPerWeek: viewModel.collectedDaysPerWeek
            )

            withAnimation {
                appState.authState = .trainingPlanOffer
            }
        }
    }

    // MARK: - Keyboard

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let last = viewModel.messages.last {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                withAnimation(.spring(.smooth(duration: 0.3))) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }

    private func setupKeyboardObservers() {
        #if canImport(UIKit)
        keyboardShowObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                withAnimation(.easeOut(duration: 0.25)) {
                    keyboardHeight = frame.height
                }
            }
        }
        keyboardHideObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            withAnimation(.easeOut(duration: 0.25)) {
                keyboardHeight = 0
            }
        }
        #endif
    }

    private func removeKeyboardObservers() {
        #if canImport(UIKit)
        if let obs = keyboardShowObserver {
            NotificationCenter.default.removeObserver(obs)
            keyboardShowObserver = nil
        }
        if let obs = keyboardHideObserver {
            NotificationCenter.default.removeObserver(obs)
            keyboardHideObserver = nil
        }
        #endif
    }
}

// MARK: - Bubble Appear Modifier

private struct BubbleAppearModifier: ViewModifier {
    let isUser: Bool
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(x: isUser ? 0 : (appeared ? 0 : -30))
            .scaleEffect(isUser ? (appeared ? 1 : 0.85) : 1)
            .onAppear {
                withAnimation(
                    isUser
                        ? .spring(response: 0.4, dampingFraction: 0.7)
                        : .spring(response: 0.5, dampingFraction: 0.75)
                ) {
                    appeared = true
                }
            }
    }
}

// MARK: - Staggered Appear Modifier

private struct StaggeredAppearModifier: ViewModifier {
    let delay: Double
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75).delay(delay)) {
                    appeared = true
                }
            }
    }
}

// MARK: - Option Button Press Style

private struct OptionPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}
