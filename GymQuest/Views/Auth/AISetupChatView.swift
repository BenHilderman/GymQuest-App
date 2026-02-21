//
//  AISetupChatView.swift
//  GymQuest
//
//  Created by Benjamin Hilderman
//
//  iMessage-style conversational setup that replaces the old 3-step onboarding.
//  Collects identity + fitness profile in a single chat flow.
//

import SwiftUI
import SwiftData

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

    private var storedPassword: String { tempPassword ?? "" }
    private var googleName: String? {
        UserDefaults.standard.string(forKey: "google_signup_name")
    }

    var body: some View {
        VStack(spacing: 0) {
            setupTopBar
            chatScrollView
            if viewModel.isEquipmentSelecting {
                equipmentMultiSelectGrid
            } else if viewModel.currentStep == .completion {
                completionCard
            } else if viewModel.isTextInputStep {
                textInputBar
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .onAppear {
            authService.setModelContext(modelContext)
            viewModel.prefillName = googleName
            viewModel.startChat()
            setupKeyboardObservers()
        }
        .onDisappear {
            removeKeyboardObservers()
        }
    }

    // MARK: - Top Bar

    @ViewBuilder
    private var setupTopBar: some View {
        HStack {
            Spacer()

            Text("GymQuest")
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()
        }
        .overlay(alignment: .trailing) {
            Button {
                viewModel.skipSetup()
            } label: {
                Text("Skip")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
                    ForEach(viewModel.messages) { message in
                        if message.isTyping {
                            typingIndicator
                                .id(message.id)
                        } else {
                            setupMessageBubble(message)
                                .id(message.id)
                                .transition(.opacity)
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
    private func setupMessageBubble(_ message: SetupMessage) -> some View {
        HStack {
            if message.isUser { Spacer(minLength: 60) }

            Text(message.content)
                .font(.system(size: 15))
                .foregroundColor(message.isUser ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(message.isUser ? Color.blue : Color(.systemGray5))
                )

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
            ForEach(options) { option in
                Button {
                    viewModel.selectOption(option)
                } label: {
                    Text(option.label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.systemGray5))
                        )
                }
                .buttonStyle(OptionPressStyle())
                .disabled(viewModel.isProcessing)
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
                                        .foregroundStyle(.blue)
                                }
                                Text(type.rawValue)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(isSelected ? .blue : .secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(isSelected ? Color.blue.opacity(0.15) : Color(.systemGray5))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
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
                    .background(Capsule().fill(.blue))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .disabled(viewModel.isProcessing)
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    // MARK: - Text Input Bar

    @ViewBuilder
    private var textInputBar: some View {
        HStack(spacing: 10) {
            TextField(viewModel.textFieldPlaceholder, text: $viewModel.inputText)
                .font(.system(size: 16))
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.systemGray6))
                )
                .submitLabel(.send)
                .onSubmit { viewModel.submitTextInput() }

            Button(action: { viewModel.submitTextInput() }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(
                        .white,
                        viewModel.inputText.isEmpty ? Color(.systemGray4) : .blue
                    )
            }
            .disabled(viewModel.inputText.isEmpty || viewModel.isProcessing)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, keyboardHeight > 0 ? 8 : 34)
        .background(Color(.systemBackground))
    }

    // MARK: - Typing Indicator

    @ViewBuilder
    private var typingIndicator: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color(.systemGray3))
                        .frame(width: 8, height: 8)
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
                    .fill(Color(.systemGray5))
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
                    .background(Capsule().fill(.blue))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(Color(.systemBackground))
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

// MARK: - Option Button Press Style

private struct OptionPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}
