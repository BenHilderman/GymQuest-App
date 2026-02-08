//
//  CoachView.swift
//  GymQuest
//
//  Created by Benjamin Hilderman
//
//  Bold & Energetic AI coach with glass morphism
//  Chat for quick questions, plan generator for programs
//  Hooks into Groq/Ollama/OpenAI depending on settings.
//

import SwiftUI
import SwiftData

struct CoachView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChatMessage.timestamp) private var chatMessages: [ChatMessage]

    let profile: UserProfile
    let workouts: [Workout]
    @ObservedObject var aiService: AIService

    @State private var selectedTab: Int = 0
    @State private var showingFormStudio = false
    @State private var formStudioExercise: FormExercise?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector - clean segmented style
                HStack(spacing: 0) {
                    CoachTab(title: "Chat", icon: "message.fill", isSelected: selectedTab == 0) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            selectedTab = 0
                        }
                    }
                    CoachTab(title: "Plan", icon: "doc.text.fill", isSelected: selectedTab == 1) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            selectedTab = 1
                        }
                    }
                    CoachTab(title: "Form", icon: "play.rectangle.on.rectangle", isSelected: selectedTab == 2) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            selectedTab = 2
                        }
                    }
                }
                .padding(3)
                .background(
                    Capsule()
                        .fill(Color(white: 0.12))
                )
                .padding(.horizontal, 40)
                .padding(.top, 12)
                .padding(.bottom, 12)

                // content
                if selectedTab == 0 {
                    ChatSection(
                        chatMessages: chatMessages,
                        profile: profile,
                        workouts: workouts,
                        aiService: aiService,
                        modelContext: modelContext
                    )
                } else if selectedTab == 1 {
                    PlanSection(
                        profile: profile,
                        workouts: workouts,
                        aiService: aiService,
                        modelContext: modelContext
                    )
                } else {
                    FormStudioLauncher(
                        profile: profile,
                        modelContext: modelContext,
                        showingFormStudio: $showingFormStudio,
                        formStudioExercise: $formStudioExercise
                    )
                }
            }
            .background(EnergyBackground())
            .navigationTitle("Coach")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .sheet(isPresented: $showingFormStudio) {
                if let exercise = formStudioExercise {
                    NavigationStack {
                        FormStudioView(oduserId: profile.id.uuidString, exercise: exercise)
                    }
                }
            }
        }
    }
}

struct CoachTab: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
            }
            .foregroundColor(isSelected ? .white : GQColors.textTertiary)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color(white: 0.22) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Form Studio Launcher

struct FormStudioLauncher: View {
    let profile: UserProfile
    let modelContext: ModelContext
    @Binding var showingFormStudio: Bool
    @Binding var formStudioExercise: FormExercise?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Hero section
                VStack(spacing: 12) {
                    Image(systemName: "play.rectangle.on.rectangle")
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [GQColors.cyanSpark, GQColors.electricBlue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("Form Studio")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Text("Learn perfect exercise technique with interactive guides")
                        .font(.system(size: 15))
                        .foregroundColor(GQColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 32)

                // Launch button
                Button {
                    openFormStudio()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 16))
                        Text("Open Form Studio")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 32)

                Spacer(minLength: 40)
            }
        }
    }

    private func openFormStudio() {
        FormContentSeeder.seedIfNeeded(modelContext: modelContext)
        let repo = FormRepository(modelContext: modelContext)
        let exercises = repo.allExercises()
        if let first = exercises.first {
            formStudioExercise = first
            showingFormStudio = true
        } else {
            FormContentSeeder.seedSampleData(modelContext: modelContext)
            let refreshed = repo.allExercises()
            if let first = refreshed.first {
                formStudioExercise = first
                showingFormStudio = true
            }
        }
    }
}

// The actual chat ui. tracks keyboard height manually because swiftui's
// built-in keyboard avoidance doesn't work with tab bars
struct ChatSection: View {
    let chatMessages: [ChatMessage]
    let profile: UserProfile
    let workouts: [Workout]
    @ObservedObject var aiService: AIService
    let modelContext: ModelContext

    @State private var inputText: String = ""
    @State private var keyboardHeight: CGFloat = 0 // manual keyboard tracking for tab bar
    @State private var keyboardShowObserver: NSObjectProtocol?
    @State private var keyboardHideObserver: NSObjectProtocol?

    // preset prompts for common questions
    let quickPrompts = [
        ("Warm-up tips", GQColors.sunsetOrange),
        ("Form check", GQColors.cyanSpark),
        ("Push or rest?", GQColors.vividPurple),
        ("Volume check", GQColors.electricGold)
    ]

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            if chatMessages.isEmpty {
                                VStack(spacing: 16) {
                                    Spacer().frame(height: 60)

                                    ZStack {
                                        Circle()
                                            .fill(GQGradients.primary.opacity(0.2))
                                            .frame(width: 80, height: 80)
                                            .blur(radius: 20)

                                        Image(systemName: "brain.head.profile")
                                            .font(.system(size: 44))
                                            .foregroundStyle(GQGradients.primary)
                                    }

                                    Text("Ask your AI coach anything")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)

                                    Text("Get advice on form, programming,\nrecovery, and more")
                                        .font(.system(size: 14))
                                        .foregroundColor(GQColors.textTertiary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                            }

                            ForEach(chatMessages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }

                            if aiService.isLoading {
                                HStack(spacing: 10) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(GQColors.accent)
                                    Text("Thinking...")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(GQColors.textSecondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.vertical, 16)
                    }
                    .scrollDismissesKeyboard(.immediately)
                    .onTapGesture {
                        #if canImport(UIKit)
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        #endif
                    }
                    .onChange(of: chatMessages.count) {
                        if let last = chatMessages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: keyboardHeight) { _, _ in
                        if let last = chatMessages.last {
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(100))
                                withAnimation {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }

                // quick prompts - hide when keyboard is up
                if keyboardHeight == 0 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(quickPrompts, id: \.0) { prompt, color in
                                Button {
                                    inputText = prompt
                                    sendMessage()
                                } label: {
                                    Text(prompt)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule()
                                                .fill(.ultraThinMaterial)
                                                .overlay(
                                                    Capsule()
                                                        .stroke(color.opacity(0.5), lineWidth: 1)
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 12)
                    .background(
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Rectangle()
                                    .fill(Color.black.opacity(0.3))
                            )
                    )
                }

                // input bar
                HStack(spacing: 12) {
                    TextField("Ask your coach...", text: $inputText)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Capsule()
                                        .stroke(GQGradients.glassBorder, lineWidth: 1)
                                )
                        )
                        .submitLabel(.send)
                        .onSubmit(sendMessage)

                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(inputText.isEmpty ? AnyShapeStyle(Color.gray.opacity(0.5)) : AnyShapeStyle(GQGradients.primary))
                    }
                    .disabled(inputText.isEmpty || aiService.isLoading)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, keyboardHeight > 0 ? 8 : 100)
                .background(
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Rectangle()
                                .fill(Color.black.opacity(0.4))
                        )
                )
            }
            .ignoresSafeArea(.keyboard)
            .padding(.bottom, keyboardHeight)
        }
        .onAppear {
            setupKeyboardObservers()
        }
        .onDisappear {
            removeKeyboardObservers()
        }
    }

    private func setupKeyboardObservers() {
        #if canImport(UIKit)
        keyboardShowObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [self] notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                withAnimation(.easeOut(duration: 0.25)) {
                    keyboardHeight = keyboardFrame.height
                }
            }
        }

        keyboardHideObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [self] _ in
            withAnimation(.easeOut(duration: 0.25)) {
                keyboardHeight = 0
            }
        }
        #endif
    }

    private func removeKeyboardObservers() {
        #if canImport(UIKit)
        if let showObserver = keyboardShowObserver {
            NotificationCenter.default.removeObserver(showObserver)
            keyboardShowObserver = nil
        }
        if let hideObserver = keyboardHideObserver {
            NotificationCenter.default.removeObserver(hideObserver)
            keyboardHideObserver = nil
        }
        #endif
    }

    // sends user message -> calls AI -> saves response
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let userMessage = ChatMessage(content: inputText, role: .user)
        modelContext.insert(userMessage)
        let prompt = inputText
        inputText = ""

        Task {
            do {
                let response = try await aiService.chat(
                    prompt: prompt,
                    profile: profile,
                    workouts: workouts,
                    modelContext: modelContext
                )

                let aiMessage = ChatMessage(content: response, role: .assistant)
                modelContext.insert(aiMessage)
                try? modelContext.save()
            } catch {
                print("AI Chat Error: \(error)")
                // User-friendly error message
                let errorText: String
                if error.localizedDescription.contains("Network") || error.localizedDescription.contains("connection") {
                    errorText = "Couldn't connect to the AI service. Check your internet connection and try again."
                } else if error.localizedDescription.contains("API key") || error.localizedDescription.contains("Missing") {
                    errorText = "AI service not configured. Go to Profile > Settings to add your API key."
                } else {
                    errorText = "Something went wrong. Please try again in a moment."
                }
                let errorMessage = ChatMessage(content: errorText, role: .system)
                modelContext.insert(errorMessage)
                try? modelContext.save()
            }
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            Text(message.content)
                .font(.system(size: 15))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isUser ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(Color.white.opacity(0.08)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    isUser ? AnyShapeStyle(Color.clear) : AnyShapeStyle(GQGradients.glassBorder),
                                    lineWidth: 1
                                )
                        )
                )

            if !isUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 16)
    }
}

// workout plan generator. pick your split, days, and goal
// and the ai spits out a full program. pretty handy tbh
struct PlanSection: View {
    let profile: UserProfile
    let workouts: [Workout]
    @ObservedObject var aiService: AIService
    let modelContext: ModelContext

    @State private var planSplit: PlanSplit = .ppl
    @State private var planDays: Int = 4
    @State private var planGoal: PlanGoal = .hypertrophy
    @State private var isGenerating = false
    @State private var generatedPlan: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(GQGradients.energy.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .blur(radius: 20)

                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(GQGradients.energy)
                    }

                    Text("Generate Workout Plan")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    Text("AI-powered personalized programming")
                        .font(.system(size: 14))
                        .foregroundColor(GQColors.textTertiary)
                }
                .padding(.top, 20)

                // options card
                GlassCard(accentColor: GQColors.vividPurple, cornerRadius: 20, showGlow: false) {
                    VStack(spacing: 20) {
                        // split type
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SPLIT TYPE")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1)
                                .foregroundColor(GQColors.textTertiary)

                            Picker("Split", selection: $planSplit) {
                                ForEach(PlanSplit.allCases, id: \.self) { split in
                                    Text(split.rawValue).tag(split)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        // days per week
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DAYS PER WEEK")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1)
                                .foregroundColor(GQColors.textTertiary)

                            Picker("Days", selection: $planDays) {
                                ForEach(3...6, id: \.self) { d in
                                    Text("\(d)").tag(d)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        // goal
                        VStack(alignment: .leading, spacing: 8) {
                            Text("GOAL")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1)
                                .foregroundColor(GQColors.textTertiary)

                            Picker("Goal", selection: $planGoal) {
                                ForEach(PlanGoal.allCases, id: \.self) { g in
                                    Text(g.rawValue).tag(g)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .padding(4)
                }
                .padding(.horizontal, 16)

                // generate button
                Button {
                    generatePlan()
                } label: {
                    HStack(spacing: 8) {
                        if isGenerating {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(isGenerating ? "Generating..." : "Generate Plan")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isGenerating)
                .padding(.horizontal, 16)

                // generated plan
                if let plan = generatedPlan {
                    GlassCard(accentColor: GQColors.cyanSpark, cornerRadius: 20, showGlow: true) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(GQColors.success)
                                Text("Your Plan")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                                Button {
                                    #if canImport(UIKit)
                                    UIPasteboard.general.string = plan
                                    #endif
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.on.doc")
                                        Text("Copy")
                                    }
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(GQColors.cyanSpark)
                                }
                            }

                            Divider()
                                .background(Color.white.opacity(0.1))

                            Text(plan)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.9))
                                .lineSpacing(4)
                        }
                        .padding(4)
                    }
                    .padding(.horizontal, 16)
                }

                Spacer().frame(height: 100)
            }
            .padding(.top, 8)
        }
    }

    private func generatePlan() {
        isGenerating = true
        generatedPlan = nil

        let prompt = """
        Generate a \(planDays)-day \(planSplit.rawValue) workout plan for \(planGoal.rawValue).
        Include exercises, sets, and reps. Keep it concise.
        """

        Task {
            do {
                let response = try await aiService.chat(
                    prompt: prompt,
                    profile: profile,
                    workouts: workouts,
                    modelContext: modelContext
                )
                generatedPlan = response
            } catch {
                generatedPlan = "Error generating plan. Please try again."
            }
            isGenerating = false
        }
    }
}

enum PlanSplit: String, CaseIterable {
    case ppl = "PPL"
    case upperLower = "Upper/Lower"
    case fullBody = "Full Body"
}

enum PlanGoal: String, CaseIterable {
    case hypertrophy = "Hypertrophy"
    case strength = "Strength"
    case endurance = "Endurance"
}

#Preview {
    CoachView(
        profile: UserProfile(),
        workouts: [],
        aiService: AIService()
    )
    .environmentObject(AppState())
    .preferredColorScheme(.dark)
}
