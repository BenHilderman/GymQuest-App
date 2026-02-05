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
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                // progress indicator
                HStack(spacing: 8) {
                    ForEach(0..<totalSteps, id: \.self) { step in
                        Capsule()
                            .fill(step <= currentStep ? Color.white : Color.white.opacity(0.2))
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
        3  // Always 3 steps: name, username, birthday
    }

    private var isLastStep: Bool {
        currentStep == 2
    }

    private var canContinue: Bool {
        switch currentStep {
        case 0: return !name.trimmingCharacters(in: .whitespaces).isEmpty
        case 1: return !username.trimmingCharacters(in: .whitespaces).isEmpty
        case 2: return true
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

        if profile != nil {
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
                .foregroundColor(.gray)

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
                .foregroundColor(.gray)

            HStack {
                Text("@")
                    .font(.title3)
                    .foregroundColor(.gray)
                TextField("username", text: $username)
                    .font(.title3)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    .focused($isFocused)
            }
            .padding(14)
            .background(Color.white.opacity(0.08))
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
                .foregroundColor(.gray)

            DatePicker(
                "Date of Birth",
                selection: $dateOfBirth,
                in: minDate...maxDate,
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            #if os(iOS)
            .colorScheme(.dark)
            #endif
            .padding(.horizontal, 32)
            .padding(.top, 16)
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
                .foregroundColor(.gray)

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
