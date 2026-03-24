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
import Supabase

// MARK: - Onboarding Light Theme

private enum OBColors {
    static let bg = Color(hex: "F8F8FC")
    static let cardSurface = Color.white
    static let optionSurface = Color(hex: "FDFAFF")
    static let textPrimary = Color(hex: "1C1C1E")
    static let textSecondary = Color(hex: "3C3C43").opacity(0.55)
    static let aiBubbleGradient = LinearGradient(
        colors: [Color.white, Color(hex: "F3EEFF")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let borderGradient = LinearGradient(
        colors: [Color(hex: "C9B8E8").opacity(0.5), Color(hex: "E8D0F0").opacity(0.4)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let userBubbleGradient = LinearGradient(
        colors: [GQColors.deepBlue.opacity(0.9), GQColors.deepBlue.opacity(0.9)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let sendGradient = LinearGradient(
        colors: [GQColors.deepBlue, GQColors.deepBlue],
        startPoint: .top,
        endPoint: .bottom
    )
    static let ctaGradient = LinearGradient(
        colors: [GQColors.deepBlue.opacity(0.9), GQColors.deepBlue.opacity(0.9)],
        startPoint: .leading,
        endPoint: .trailing
    )
    static let heroGradient = LinearGradient(
        colors: [Color(hex: "3D7CFF"), Color(hex: "D45FAA"), Color(hex: "FF6B9D")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
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
    @State private var selectedOptionId: UUID?
    @State private var sendBounce = false
    @State private var borderRotation: CGFloat = 0
    @FocusState private var isTextFieldFocused: Bool
    @Namespace private var heroNamespace
    @State private var expandedMessage: SetupMessage?
    @State private var heroCornerRadius: CGFloat = 18
    @State private var heroContentVisible = false
    @State private var heroDragOffset: CGFloat = 0

    private var storedPassword: String { tempPassword ?? "" }
    private var googleName: String? {
        UserDefaults.standard.string(forKey: "google_signup_name")
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                setupTopBar
                chatScrollView
                Group {
                    if viewModel.isEquipmentSelecting {
                        equipmentMultiSelectGrid
                    } else if viewModel.currentStep == .completion {
                        EmptyView()
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
            .allowsHitTesting(expandedMessage == nil)

            if expandedMessage != nil {
                expandedMessageOverlay
            }
        }
        .onAppear {
            authService.setModelContext(modelContext)
            viewModel.authService = authService
            viewModel.prefillName = googleName
            viewModel.startChat()
            setupKeyboardObservers()
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: true)) {
                shimmerPhase = 1
            }
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                borderRotation = 1
            }
        }
        .onDisappear {
            removeKeyboardObservers()
        }
        .onChange(of: viewModel.currentStep) { _, newStep in
            if newStep == .name || newStep == .username {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isTextFieldFocused = true
                }
            }
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
        VStack(spacing: 10) {
            HStack {
                Spacer()

                NavBarLogo()

                Spacer()
            }
            .overlay(alignment: .leading) {
                if viewModel.currentStep.rawValue > SetupStep.name.rawValue,
                   viewModel.currentStep != .completion {
                    Button {
                        viewModel.goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.subheadline)
                            .foregroundStyle(OBColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
            .overlay(alignment: .trailing) {
                if viewModel.currentStep.rawValue >= SetupStep.experience.rawValue,
                   viewModel.currentStep != .completion {
                    Button {
                        viewModel.skipSetup()
                    } label: {
                        Text("Skip")
                            .font(.subheadline)
                            .foregroundStyle(OBColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }

            if viewModel.currentStep != .greeting {
                progressDots
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .animation(.easeInOut(duration: 0.35), value: viewModel.currentStep)
    }

    @ViewBuilder
    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<12, id: \.self) { index in
                Circle()
                    .fill(
                        index < viewModel.completedAnswerSteps
                            ? AnyShapeStyle(LinearGradient(
                                colors: [Color(hex: "3D7CFF"), Color(hex: "FF6B9D")],
                                startPoint: .leading,
                                endPoint: .trailing
                              ))
                            : AnyShapeStyle(Color(hex: "C9B8E8").opacity(0.25))
                    )
                    .frame(width: 6, height: 6)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: viewModel.completedAnswerSteps)
    }

    // MARK: - Chat Scroll View

    @ViewBuilder
    private var chatScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
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
                            .padding(.top, 12)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // Inline completion card — stays near the last message
                    if viewModel.currentStep == .completion {
                        inlineCompletionCard
                            .id("completion")
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, 20)
                .animation(.easeOut(duration: 0.25), value: viewModel.messages.count)
            }
            .scrollClipDisabled()
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
        let isExpanded = expandedMessage?.id == message.id

        VStack(spacing: 12) {
            HStack {
                if message.isUser { Spacer(minLength: 60) }

                Text(message.content)
                    .font(.system(size: message.isUser ? 18 : 20, weight: .medium))
                    .foregroundColor(message.isUser ? .white : OBColors.textPrimary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(message.isUser ? OBColors.userBubbleGradient : OBColors.aiBubbleGradient)
                            if !isExpanded {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(message.isUser ? OBColors.userBubbleGradient : OBColors.aiBubbleGradient)
                                    .matchedGeometryEffect(id: "hero-\(message.id)", in: heroNamespace)
                            }
                        }
                    }
                    .modifier(GlossyBubbleOverlay(isActive: !message.isUser && !isExpanded))
                    .modifier(UserBubbleGlowModifier(isActive: message.isUser && !isExpanded))
                    .shadow(
                        color: isExpanded ? .clear : (message.isUser
                            ? GQColors.deepBlue.opacity(0.12)
                            : Color(hex: "3D7CFF").opacity(0.18)),
                        radius: message.isUser ? 8 : 16,
                        y: 3
                    )
                    .shadow(
                        color: isExpanded ? .clear : (message.isUser
                            ? Color.clear
                            : Color(hex: "FF6B9D").opacity(0.12)),
                        radius: message.isUser ? 0 : 10,
                        y: 5
                    )
                    .opacity(isExpanded ? 0 : 1)
                    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .onTapGesture { expandMessage(message) }
                    .modifier(BubbleAppearModifier(isUser: message.isUser))

                if !message.isUser { Spacer(minLength: 60) }
            }

            // Inline progress prediction chart
            if message.showChart {
                ProgressPredictionChart()
                    .padding(.horizontal, 24)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))

                Text("90% of lifters see results in 4 weeks")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(OBColors.textSecondary)
            }
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
                let isSelected = selectedOptionId == option.id

                Button {
                    guard selectedOptionId == nil else { return }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                        selectedOptionId = option.id
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        viewModel.selectOption(option)
                        selectedOptionId = nil
                    }
                } label: {
                    Text(option.label)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : OBColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isSelected ? OBColors.ctaGradient : LinearGradient(colors: [OBColors.optionSurface], startPoint: .leading, endPoint: .trailing))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(isSelected ? LinearGradient(colors: [Color.clear], startPoint: .top, endPoint: .bottom) : OBColors.borderGradient, lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
                }
                .buttonStyle(OptionPressStyle())
                .scaleEffect(isSelected ? 1.04 : 1.0)
                .opacity(selectedOptionId != nil && !isSelected ? 0.4 : 1.0)
                .disabled(viewModel.isProcessing || selectedOptionId != nil)
                .modifier(StaggeredAppearModifier(delay: Double(index) * 0.08))
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
                                        .foregroundStyle(OBColors.ctaGradient)
                                }
                                Text(type.rawValue)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(isSelected ? AnyShapeStyle(OBColors.ctaGradient) : AnyShapeStyle(OBColors.textSecondary))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(OBColors.cardSurface)
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
                Picker("Unit", selection: $viewModel.collectedHeightUnit) {
                    Text("ft/in").tag(HeightUnit.ftIn)
                    Text("cm").tag(HeightUnit.cm)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)

                heightPicker
            } else {
                Picker("Unit", selection: $viewModel.collectedWeightUnit) {
                    Text("lbs").tag(WeightUnit.lbs)
                    Text("kg").tag(WeightUnit.kg)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)

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
                .font(.system(size: 17))
                .foregroundColor(OBColors.textPrimary)
                .tint(Color(hex: "1C1C1E"))
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(OBColors.cardSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color(hex: "5B9AFF"),
                                    Color(hex: "C76BFF"),
                                    Color(hex: "FF6B9D"),
                                    Color(hex: "C76BFF"),
                                    Color(hex: "5B9AFF")
                                ],
                                center: .center,
                                angle: .degrees(borderRotation * 360)
                            ),
                            lineWidth: isTextFieldFocused ? 2 : 1
                        )
                        .opacity(isTextFieldFocused ? 0.9 : 0.35)
                        .animation(.easeInOut(duration: 0.3), value: isTextFieldFocused)
                )
                .focused($isTextFieldFocused)
                .submitLabel(.send)
                .onSubmit { submitWithBounce() }

            Button(action: { submitWithBounce() }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(
                        .white,
                        viewModel.inputText.isEmpty ? Color(hex: "D1D1D6") : Color(hex: "1C1C1E")
                    )
            }
            .disabled(viewModel.inputText.isEmpty || viewModel.isProcessing)
            .buttonStyle(.plain)
            .scaleEffect(sendBounce ? 1.3 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: sendBounce)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, keyboardHeight > 0 ? 8 : 34)
        .background(OBColors.bg)
    }

    private func submitWithBounce() {
        guard !viewModel.inputText.isEmpty else { return }
        sendBounce = true
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            sendBounce = false
        }
        viewModel.submitTextInput()
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

    // MARK: - Inline Completion Card

    @ViewBuilder
    private var inlineCompletionCard: some View {
        VStack(spacing: 20) {
            // Checkmark with glow
            ZStack {
                Circle()
                    .fill(OBColors.ctaGradient)
                    .frame(width: 72, height: 72)
                    .shadow(color: GQColors.deepBlue.opacity(0.4), radius: 16, y: 0)
                    .shadow(color: GQColors.deepBlue.opacity(0.2), radius: 24, y: 0)
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(spacing: 6) {
                Text("You're all set")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(OBColors.textPrimary)
                Text("Your profile is ready. Let's build your plan.")
                    .font(.system(size: 17))
                    .foregroundColor(OBColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Button {
                createProfile()
            } label: {
                Text("Get Started")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Capsule().fill(OBColors.ctaGradient))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .modifier(StaggeredAppearModifier(delay: 0.1))
    }

    // MARK: - Hero Fullscreen Overlay

    @ViewBuilder
    private var expandedMessageOverlay: some View {
        if let message = expandedMessage {
            let dragProgress = min(heroDragOffset / 300, 1.0)

            ZStack {
                RoundedRectangle(cornerRadius: heroCornerRadius, style: .continuous)
                    .fill(OBColors.heroGradient)
                    .matchedGeometryEffect(id: "hero-\(message.id)", in: heroNamespace)
                    .ignoresSafeArea()

                VStack {
                    HStack {
                        Spacer()
                        Button(action: dismissExpandedMessage) {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white.opacity(0.8))
                                .frame(width: 36, height: 36)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    Spacer()

                    VStack(alignment: .leading, spacing: 16) {
                        Text(message.content)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)

                        Divider().overlay(Color.white.opacity(0.3))

                        HStack(spacing: 12) {
                            heroActionButton("Reply", icon: "arrowshape.turn.up.left.fill")
                            heroActionButton("Copy", icon: "doc.on.doc.fill")
                            heroActionButton("Delete", icon: "trash.fill")
                        }
                    }
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .padding(.horizontal, 20)

                    Spacer()
                }
                .opacity(heroContentVisible ? 1 : 0)
            }
            .offset(y: heroDragOffset)
            .scaleEffect(1 - dragProgress * 0.08)
            .clipShape(RoundedRectangle(cornerRadius: dragProgress * 24, style: .continuous))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        heroDragOffset = max(0, value.translation.height)
                    }
                    .onEnded { value in
                        if value.translation.height > 120 || value.predictedEndTranslation.height > 300 {
                            dismissExpandedMessage()
                        }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            heroDragOffset = 0
                        }
                    }
            )
        }
    }

    private func expandMessage(_ message: SetupMessage) {
        heroCornerRadius = 18
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            expandedMessage = message
            heroCornerRadius = 0
        }
        withAnimation(.easeOut(duration: 0.3).delay(0.25)) {
            heroContentVisible = true
        }
    }

    private func dismissExpandedMessage() {
        withAnimation(.easeIn(duration: 0.15)) {
            heroContentVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                heroCornerRadius = 18
                expandedMessage = nil
            }
        }
    }

    @ViewBuilder
    private func heroActionButton(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
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

            // Sync onboarding profile to Supabase
            if FeatureFlags.shared.supabaseSyncEnabled, let userId = SupabaseAuthService.shared.currentUserId {
                Task {
                    do {
                        try await SupabaseConfig.client.from("profiles")
                            .update([
                                "fitness_goal": profile.goal.rawValue,
                                "display_name": profile.name,
                                "username": profile.username,
                                "experience_level": profile.experienceLevel?.rawValue ?? ""
                            ])
                            .eq("id", value: userId.uuidString)
                            .execute()
                    } catch {
                        print("[Onboarding] Supabase profile sync failed: \(error)")
                    }
                }
            }

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
                appState.authState = .authenticated
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
            .offset(
                x: isUser ? 0 : (appeared ? 0 : -20),
                y: isUser ? (appeared ? 0 : 24) : 0
            )
            .scaleEffect(appeared ? 1.0 : (isUser ? 0.85 : 0.95))
            .onAppear {
                if isUser {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        appeared = true
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        appeared = true
                    }
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
            .offset(y: appeared ? 0 : 16)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.35).delay(delay)) {
                    appeared = true
                }
            }
    }
}

// MARK: - Glossy Bubble Overlay

private struct GlossyBubbleOverlay: ViewModifier {
    let isActive: Bool

    private let bluePink = LinearGradient(
        colors: [
            Color(hex: "3D7CFF").opacity(0.55),
            Color(hex: "D45FAA").opacity(0.45),
            Color(hex: "FF6B9D").opacity(0.50)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    func body(content: Content) -> some View {
        if isActive {
            content
                // Glossy inner highlight — clipped to bubble shape
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.45), Color.white.opacity(0)],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .allowsHitTesting(false)
                )
                // Soft outer glow — bleeds beyond bubble
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(bluePink, lineWidth: 2.5)
                        .blur(radius: 4)
                        .opacity(0.35)
                )
                // Crisp gradient border
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(bluePink, lineWidth: 1.2)
                )
        } else {
            content
        }
    }
}

// MARK: - User Bubble Glow Modifier

private struct UserBubbleGlowModifier: ViewModifier {
    let isActive: Bool
    @State private var glowExpanded = false
    @State private var glowFaded = false
    @State private var flashVisible = false

    private let innerGlowGradient = LinearGradient(
        colors: [Color(hex: "5B9AFF"), Color(hex: "C76BFF")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private let outerGlowGradient = LinearGradient(
        colors: [Color(hex: "4A8AFF").opacity(0.8), Color(hex: "B855FF").opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    func body(content: Content) -> some View {
        if isActive {
            content
                .padding(.vertical, 6)
                .overlay(
                    // Layer 1: Inner glow — tight bright halo
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(innerGlowGradient, lineWidth: 6)
                        .blur(radius: 6)
                        .opacity(glowFaded ? 0 : 1.0)
                        .scaleEffect(glowExpanded ? 1.05 : 1.0)
                        .allowsHitTesting(false)
                )
                .overlay(
                    // Layer 2: Outer glow — wide soft spread
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(outerGlowGradient, lineWidth: 10)
                        .blur(radius: 14)
                        .opacity(glowFaded ? 0 : 0.85)
                        .scaleEffect(glowExpanded ? 1.08 : 1.0)
                        .allowsHitTesting(false)
                )
                .overlay(
                    // Layer 3: Flash burst — initial white pop
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.4))
                        .blur(radius: 8)
                        .opacity(flashVisible ? 0 : 1.0)
                        .scaleEffect(glowExpanded ? 1.06 : 0.95)
                        .allowsHitTesting(false)
                )
                .onAppear {
                    withAnimation(.easeOut(duration: 0.25)) {
                        glowExpanded = true
                    }
                    withAnimation(.easeOut(duration: 0.15)) {
                        flashVisible = false
                    }
                    withAnimation(.easeIn(duration: 0.25).delay(0.15)) {
                        flashVisible = true
                    }
                    withAnimation(.easeIn(duration: 0.65).delay(0.25)) {
                        glowFaded = true
                    }
                }
        } else {
            content
        }
    }
}

// MARK: - Option Button Press Style

private struct OptionPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}
