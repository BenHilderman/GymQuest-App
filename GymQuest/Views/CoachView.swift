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

    @State private var showingFormStudio = false
    @State private var formStudioExercise: FormExercise?
    @State private var showingPlanBuilder = false

    var body: some View {
        NavigationStack {
            ChatSection(
                chatMessages: chatMessages,
                profile: profile,
                workouts: workouts,
                aiService: aiService,
                modelContext: modelContext
            )
            .gqPageBackground()
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavBarLogo()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingPlanBuilder = true
                        } label: {
                            Label("Build Training Plan", systemImage: "doc.text.fill")
                        }
                        Button {
                            openFormStudio()
                        } label: {
                            Label("Form Studio", systemImage: "play.rectangle.on.rectangle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showingFormStudio) {
                if let exercise = formStudioExercise {
                    NavigationStack {
                        FormStudioView(oduserId: profile.id.uuidString, exercise: exercise)
                    }
                }
            }
            .sheet(isPresented: $showingPlanBuilder) {
                NavigationStack {
                    PlanSection(
                        profile: profile,
                        workouts: workouts,
                        aiService: aiService,
                        modelContext: modelContext
                    )
                    .navigationTitle("Plan Builder")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showingPlanBuilder = false }
                        }
                    }
                }
            }
        }
    }

    private func openFormStudio() {
        try? FormContentSeeder.seedIfNeeded(modelContext: modelContext)
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

struct CoachTab: View {
    let title: String
    let icon: String
    let accent: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
            }
            .foregroundColor(isSelected ? .white : GQColors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? accent.opacity(0.22) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? accent.opacity(0.45) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(GQInteractiveStyle())
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
            VStack(spacing: 18) {
                GQScreenTitleBlock(
                    title: "Form Studio",
                    subtitle: "Interactive movement demos and setup cues.",
                    accent: GQColors.cyanSpark
                )
                .padding(.horizontal, 16)
                .padding(.top, 6)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(GQColors.cyanSpark.opacity(0.18))
                            .frame(width: 42, height: 42)
                            .overlay(
                                Image(systemName: "play.rectangle.on.rectangle")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(GQColors.cyanSpark)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Technique Library")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)

                            Text("Start with guided demos and form checkpoints.")
                                .font(.system(size: 13))
                                .foregroundColor(GQColors.textSecondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Step-by-step movement demos", systemImage: "checkmark.circle")
                        Label("Common mistakes and fixes", systemImage: "checkmark.circle")
                        Label("Tempo and setup cues", systemImage: "checkmark.circle")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)
                }
                .padding(16)
                .workoutFlowCard(accent: GQColors.cyanSpark, emphasized: true)
                .padding(.horizontal, 16)

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
                .buttonStyle(WorkoutFlowPrimaryButtonStyle(accent: GQColors.cyanSpark))
                .padding(.horizontal, 16)

                Spacer(minLength: 100)
            }
            .padding(.bottom, 20)
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
        ("Warm-up tips", GQColors.primary),
        ("Form check", GQColors.cyanSpark),
        ("Push or rest?", GQColors.vividPurple),
        ("Volume check", GQColors.secondary)
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if chatMessages.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "brain.head.profile")
                                    .font(.system(size: 30, weight: .semibold))
                                    .foregroundColor(GQColors.vividPurple)

                                Text("Ask your AI coach anything")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)

                                Text("Programming, form checks, recovery, and session decisions.")
                                    .font(.system(size: 14))
                                    .foregroundColor(GQColors.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 28)
                            .padding(.horizontal, 20)
                            .workoutFlowCard(accent: GQColors.vividPurple)
                            .padding(.horizontal, 16)
                            .padding(.top, 24)
                        }

                        ForEach(chatMessages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        if aiService.isLoading {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(GQColors.vividPurple)
                                Text("Thinking...")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(GQColors.textSecondary)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 12)
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

            if keyboardHeight == 0 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(quickPrompts, id: \.0) { prompt, color in
                            Button {
                                inputText = prompt
                                sendMessage()
                            } label: {
                                Text(prompt)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule()
                                            .fill(color.opacity(0.17))
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(color.opacity(0.45), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 10)
                .background(
                    Rectangle()
                        .fill(Color.black.opacity(0.17))
                        .overlay(
                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 1),
                            alignment: .top
                        )
                )
            }

            HStack(spacing: 10) {
                TextField("Ask your coach...", text: $inputText)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.07))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .submitLabel(.send)
                    .onSubmit(sendMessage)

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(inputText.isEmpty ? GQColors.textTertiary : .white)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(inputText.isEmpty ? Color.white.opacity(0.07) : GQColors.vividPurple)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                }
                .disabled(inputText.isEmpty || aiService.isLoading)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, keyboardHeight > 0 ? 8 : 96)
            .background(
                Rectangle()
                    .fill(GQColors.surfaceOverlay.opacity(0.90))
                    .overlay(
                        Rectangle()
                            .fill(GQColors.borderDefault)
                            .frame(height: 1),
                        alignment: .top
                    )
            )
        }
        .ignoresSafeArea(.keyboard)
        .padding(.bottom, keyboardHeight)
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
    var accent: Color { isUser ? GQColors.vividPurple : GQColors.cyanSpark }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            Text(message.content)
                .font(.system(size: 15))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .workoutFlowCard(
                    accent: accent,
                    emphasized: isUser,
                    cornerRadius: 18
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
            VStack(spacing: 18) {
                GQScreenTitleBlock(
                    title: "Plan Builder",
                    subtitle: "Generate a focused split based on your weekly availability.",
                    accent: GQColors.cyanSpark
                )
                .padding(.horizontal, 16)
                .padding(.top, 6)

                VStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        planOptionTitle("Split Type")
                        Picker("Split", selection: $planSplit) {
                            ForEach(PlanSplit.allCases, id: \.self) { split in
                                Text(split.rawValue).tag(split)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        planOptionTitle("Days Per Week")
                        Picker("Days", selection: $planDays) {
                            ForEach(3...6, id: \.self) { d in
                                Text("\(d)").tag(d)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        planOptionTitle("Goal")
                        Picker("Goal", selection: $planGoal) {
                            ForEach(PlanGoal.allCases, id: \.self) { g in
                                Text(g.rawValue).tag(g)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .padding(16)
                .workoutFlowCard(accent: GQColors.vividPurple)
                .padding(.horizontal, 16)

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
                .buttonStyle(WorkoutFlowPrimaryButtonStyle(accent: GQColors.vividPurple))
                .disabled(isGenerating)
                .padding(.horizontal, 16)

                if let plan = generatedPlan {
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
                            .background(Color.white.opacity(0.12))

                        Text(plan)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.92))
                            .lineSpacing(4)
                    }
                    .padding(16)
                    .workoutFlowCard(accent: GQColors.cyanSpark, emphasized: true)
                    .padding(.horizontal, 16)
                }

                Spacer().frame(height: 90)
            }
        }
    }

    private func planOptionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(1)
            .foregroundColor(GQColors.textTertiary)
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
