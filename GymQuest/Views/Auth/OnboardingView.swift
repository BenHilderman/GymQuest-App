//
//  OnboardingView.swift
//  GymQuest
//
//  Created by Benjamin Hilderman
//
//  New user onboarding - 3 steps: name, username, birthday.
//  Pretty standard stuff. Pre-fills name if they signed up with Google.
//  Creates the profile at the end and dumps them into the main app.
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @StateObject private var authService = AuthService()

    let authMethod: String
    let email: String?
    let googleId: String?
    let tempPassword: String?

    @State private var currentStep = 0
    @State private var name = ""
    @State private var username = ""
    @State private var dateOfBirth = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    @State private var selectedGoal: FitnessGoal = .hypertrophy
    @State private var selectedExperience: ExperienceLevel = .intermediate
    @State private var selectedEquipment: Set<EquipmentType> = []

    // Password is now passed in directly, not stored in UserDefaults
    private var storedPassword: String {
        tempPassword ?? ""
    }

    // Get name from Google Sign-In if available
    private var googleName: String? {
        UserDefaults.standard.string(forKey: "google_signup_name")
    }

    var body: some View {
        ZStack {
            GQColors.background.ignoresSafeArea()

            VStack(spacing: 32) {
                // progress indicator
                HStack(spacing: 8) {
                    ForEach(0..<totalSteps, id: \.self) { step in
                        Capsule()
                            .fill(step <= currentStep ? GQColors.textPrimary : GQColors.textPrimary.opacity(0.2))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 20)

                Spacer()

                // step content
                switch currentStep {
                case 0:
                    NameStepView(name: $name)
                case 1:
                    UsernameStepView(username: $username)
                case 2:
                    BirthdayStepView(dateOfBirth: $dateOfBirth)
                case 3:
                    GoalStepView(selectedGoal: $selectedGoal)
                case 4:
                    ExperienceStepView(selectedExperience: $selectedExperience)
                case 5:
                    EquipmentStepView(selectedEquipment: $selectedEquipment)
                default:
                    EmptyView()
                }

                Spacer()

                // navigation buttons
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button {
                            withAnimation {
                                currentStep -= 1
                            }
                        } label: {
                            Image(systemName: "arrow.left")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .frame(width: 60)
                    }

                    Button {
                        handleContinue()
                    } label: {
                        Text(isLastStep ? "Get Started" : "Continue")
                    }
                    .buttonStyle(OnboardingButtonStyle(isLastStep: isLastStep))
                    .disabled(!canContinue)
                    .opacity(canContinue ? 1 : 0.5)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            authService.setModelContext(modelContext)
            // Pre-fill name from Google Sign-In if available
            if let googleName = googleName, name.isEmpty {
                name = googleName
                // Generate username suggestion from name
                username = googleName.lowercased().replacingOccurrences(of: " ", with: "")
            }
        }
    }

    private var totalSteps: Int {
        6  // name, username, birthday, goal, experience, equipment
    }

    private var isLastStep: Bool {
        currentStep == 5
    }

    private var canContinue: Bool {
        switch currentStep {
        case 0: return !name.trimmingCharacters(in: .whitespaces).isEmpty
        case 1: return !username.trimmingCharacters(in: .whitespaces).isEmpty
        case 2: return true
        case 3: return true
        case 4: return true
        case 5: return !selectedEquipment.isEmpty
        default: return true
        }
    }

    private func handleContinue() {
        if isLastStep {
            createProfile()
        } else {
            withAnimation {
                currentStep += 1
            }
        }
    }

    private func createProfile() {
        let cleanUsername = username.hasPrefix("@")
            ? String(username.dropFirst())
            : username

        var profile: UserProfile?

        if authMethod == "google", let googleId {
            profile = authService.registerWithGoogle(
                name: name,
                username: cleanUsername.lowercased().replacingOccurrences(of: " ", with: ""),
                dateOfBirth: dateOfBirth,
                googleId: googleId,
                email: email
            )
            // Clear the temporary Google name
            UserDefaults.standard.removeObject(forKey: "google_signup_name")
        } else if authMethod == "email", let email {
            profile = authService.register(
                name: name,
                username: cleanUsername.lowercased().replacingOccurrences(of: " ", with: ""),
                dateOfBirth: dateOfBirth,
                email: email,
                password: storedPassword
            )
            // Password is now passed in-memory through AuthState, no cleanup needed
        }

        if let profile {
            profile.goal = selectedGoal
            profile.experienceLevel = selectedExperience
            profile.availableEquipment = Array(selectedEquipment)
            try? modelContext.save()
            withAnimation {
                appState.authState = .authenticated
            }
        }
    }
}

struct NameStepView: View {
    @Binding var name: String
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text("What's your name?")
                .font(.title)
                .fontWeight(.bold)

            Text("This is how you'll appear to others")
                .font(.subheadline)
                .foregroundColor(GQColors.textTertiary)

            TextField("Your name", text: $name)
                .textFieldStyle(GymQuestTextFieldStyle())
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 16)
                .focused($isFocused)
                .onAppear { isFocused = true }
        }
    }
}

struct UsernameStepView: View {
    @Binding var username: String
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text("Choose a username")
                .font(.title)
                .fontWeight(.bold)

            Text("This is your unique handle")
                .font(.subheadline)
                .foregroundColor(GQColors.textTertiary)

            HStack {
                Text("@")
                    .font(.title3)
                    .foregroundColor(GQColors.textTertiary)
                TextField("username", text: $username)
                    .font(.title3)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    .focused($isFocused)
            }
            .padding(14)
            .background(Color.black.opacity(0.05))
            .cornerRadius(12)
            .padding(.horizontal, 32)
            .padding(.top, 16)
            .onAppear { isFocused = true }
        }
    }
}

struct BirthdayStepView: View {
    @Binding var dateOfBirth: Date

    private var maxDate: Date {
        Calendar.current.date(byAdding: .year, value: -13, to: Date()) ?? Date()
    }

    private var minDate: Date {
        Calendar.current.date(byAdding: .year, value: -100, to: Date()) ?? Date()
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("When were you born?")
                .font(.title)
                .fontWeight(.bold)

            Text("We'll use this to personalize your experience")
                .font(.subheadline)
                .foregroundColor(GQColors.textTertiary)

            DatePicker(
                "Date of Birth",
                selection: $dateOfBirth,
                in: minDate...maxDate,
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            #if os(iOS)
            .colorScheme(.light)
            #endif
            .padding(.horizontal, 32)
            .padding(.top, 16)
        }
    }
}

struct GoalStepView: View {
    @Binding var selectedGoal: FitnessGoal

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 48))
                .foregroundStyle(GQGradients.primary)

            Text("What's your goal?")
                .font(.title)
                .fontWeight(.bold)

            Text("We'll tailor your experience")
                .font(.subheadline)
                .foregroundColor(GQColors.textTertiary)

            VStack(spacing: 12) {
                ForEach(FitnessGoal.allCases, id: \.self) { goal in
                    Button {
                        selectedGoal = goal
                    } label: {
                        HStack {
                            Image(systemName: goalIcon(goal))
                                .font(.title3)
                                .frame(width: 28)
                            Text(goal.rawValue)
                                .font(.body.weight(.medium))
                            Spacer()
                            if selectedGoal == goal {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(GQGradients.primary)
                            }
                        }
                        .padding(14)
                        .background(selectedGoal == goal ? GQColors.vividPurple.opacity(0.1) : Color.black.opacity(0.03))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedGoal == goal ? GQColors.vividPurple.opacity(0.4) : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(GQColors.textPrimary)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
        }
    }

    private func goalIcon(_ goal: FitnessGoal) -> String {
        switch goal {
        case .hypertrophy: return "figure.strengthtraining.traditional"
        case .strength: return "dumbbell.fill"
        case .performance: return "bolt.fill"
        case .general: return "heart.fill"
        }
    }
}

struct ExperienceStepView: View {
    @Binding var selectedExperience: ExperienceLevel

    private var descriptions: [ExperienceLevel: String] {
        [
            .beginner: "New to lifting or less than 6 months",
            .intermediate: "1-3 years of consistent training",
            .advanced: "3+ years, comfortable with programming"
        ]
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 48))
                .foregroundStyle(GQGradients.primary)

            Text("Experience level?")
                .font(.title)
                .fontWeight(.bold)

            Text("This helps us set the right intensity")
                .font(.subheadline)
                .foregroundColor(GQColors.textTertiary)

            VStack(spacing: 12) {
                ForEach(ExperienceLevel.allCases, id: \.self) { level in
                    Button {
                        selectedExperience = level
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(level.rawValue)
                                    .font(.body.weight(.semibold))
                                Spacer()
                                if selectedExperience == level {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(GQGradients.primary)
                                }
                            }
                            Text(descriptions[level] ?? "")
                                .font(.caption)
                                .foregroundColor(GQColors.textSecondary)
                        }
                        .padding(14)
                        .background(selectedExperience == level ? GQColors.vividPurple.opacity(0.1) : Color.black.opacity(0.03))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedExperience == level ? GQColors.vividPurple.opacity(0.4) : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(GQColors.textPrimary)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
        }
    }
}

struct EquipmentStepView: View {
    @Binding var selectedEquipment: Set<EquipmentType>

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 10)]

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 48))
                .foregroundStyle(GQGradients.primary)

            Text("What's at your gym?")
                .font(.title)
                .fontWeight(.bold)

            Text("Select all that apply")
                .font(.subheadline)
                .foregroundColor(GQColors.textTertiary)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(EquipmentType.allCases, id: \.self) { equipment in
                    let isSelected = selectedEquipment.contains(equipment)
                    Button {
                        if isSelected {
                            selectedEquipment.remove(equipment)
                        } else {
                            selectedEquipment.insert(equipment)
                        }
                    } label: {
                        Text(equipment.rawValue)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(isSelected ? GQColors.vividPurple.opacity(0.15) : Color.black.opacity(0.03))
                            .foregroundColor(isSelected ? GQColors.vividPurple : GQColors.textPrimary)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isSelected ? GQColors.vividPurple.opacity(0.5) : Color.clear, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
        }
    }
}

struct PasswordStepView: View {
    @Binding var password: String
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text("Create a password")
                .font(.title)
                .fontWeight(.bold)

            Text("At least 6 characters")
                .font(.subheadline)
                .foregroundColor(GQColors.textTertiary)

            SecureField("Password", text: $password)
                .textFieldStyle(GymQuestTextFieldStyle())
                .font(.title3)
                .padding(.horizontal, 32)
                .padding(.top, 16)
                .focused($isFocused)
                .onAppear { isFocused = true }
        }
    }
}

#Preview {
    OnboardingView(authMethod: "email", email: "test@example.com", googleId: nil, tempPassword: nil)
        .environmentObject(AppState())
}
