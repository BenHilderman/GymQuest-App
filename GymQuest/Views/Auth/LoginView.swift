//
//  LoginView.swift
//  GymQuest
//
//  Created by Benjamin Hilderman
//
//  The login/signup screen. Two options - Google or email.
//  Google uses the real SDK (not simulated), email is just
//  local auth with hashed passwords stored in SwiftData.
//

import SwiftUI
import SwiftData
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @StateObject private var authService = AuthService()

    @State private var showingEmailSheet = false
    @State private var isSignUpMode = false  // toggle between sign in and sign up

    // email login state
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var isLoading = false

    var body: some View {
        ZStack {
            GQColors.background.ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // logo and title
                VStack(spacing: 16) {
                    AnimatedLogo()

                    Text("GymQuest")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)

                    Text("Track your gains. Level up.")
                        .font(.subheadline)
                        .foregroundColor(GQColors.textTertiary)
                }

                Spacer()

                // auth buttons
                VStack(spacing: 16) {
                    // google sign in/up
                    Button {
                        signInWithGoogle()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "g.circle.fill")
                                .font(.title2)
                            Text(isSignUpMode ? "Sign up with Google" : "Continue with Google")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isLoading)

                    // email sign in/up
                    Button {
                        showingEmailSheet = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .font(.title3)
                            Text(isSignUpMode ? "Sign up with Email" : "Continue with Email")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.horizontal, 32)

                // toggle between sign in and sign up
                Button {
                    withAnimation {
                        isSignUpMode.toggle()
                        // Clear form when switching modes
                        email = ""
                        password = ""
                        confirmPassword = ""
                        errorMessage = ""
                    }
                } label: {
                    if isSignUpMode {
                        Text("Already have an account? ")
                            .foregroundColor(GQColors.textTertiary) +
                        Text("Sign in")
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                    } else {
                        Text("Don't have an account? ")
                            .foregroundColor(GQColors.textTertiary) +
                        Text("Sign up")
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                    }
                }
                .font(.subheadline)
                .padding(.bottom, 32)
            }

            // loading overlay
            if isLoading {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
            }
        }
        .sheet(isPresented: $showingEmailSheet) {
            EmailAuthSheet(
                isSignUp: isSignUpMode,
                email: $email,
                password: $password,
                confirmPassword: $confirmPassword,
                errorMessage: $errorMessage,
                isLoading: $isLoading,
                onSubmit: handleEmailAuth
            )
            .presentationDetents([.medium])
        }
        .onAppear {
            authService.setModelContext(modelContext)
        }
    }

    // google sign in - uses the actual sdk, not some fake simulation
    // if user already exists we log them in, otherwise send to onboarding
    private func signInWithGoogle() {
        #if canImport(GoogleSignIn) && canImport(UIKit)
        isLoading = true

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            isLoading = false
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            isLoading = false

            if let error = error {
                print("Google Sign-In error: \(error.localizedDescription)")
                return
            }

            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                print("Failed to get user info from Google")
                return
            }

            let googleId = user.userID ?? idToken
            let googleEmail = user.profile?.email
            let googleName = user.profile?.name

            // Check if user exists
            if let _ = authService.googleIdExists(googleId) {
                withAnimation {
                    appState.authState = .authenticated
                }
            } else {
                // New user - go to onboarding
                // Store the name from Google to pre-fill onboarding
                if let name = googleName {
                    UserDefaults.standard.set(name, forKey: "google_signup_name")
                }
                withAnimation {
                    appState.authState = .onboarding(authMethod: "google", email: googleEmail, googleId: googleId, tempPassword: nil)
                }
            }
        }
        #else
        print("Google Sign-In not available on this platform")
        #endif
    }

    private func handleEmailAuth() {
        errorMessage = ""

        guard !email.isEmpty else {
            errorMessage = "Please enter your email"
            return
        }

        guard !password.isEmpty else {
            errorMessage = "Please enter your password"
            return
        }

        if isSignUpMode {
            // sign up flow
            guard password == confirmPassword else {
                errorMessage = "Passwords don't match"
                return
            }

            guard password.count >= 6 else {
                errorMessage = "Password must be at least 6 characters"
                return
            }

            if authService.emailExists(email) {
                errorMessage = "An account with this email already exists"
                return
            }

            // new user - go to onboarding (password passed through AuthState, not persisted)
            showingEmailSheet = false
            withAnimation {
                appState.authState = .onboarding(authMethod: "email", email: email, googleId: nil, tempPassword: password)
            }
        } else {
            // login flow
            if let _ = authService.login(email: email, password: password) {
                showingEmailSheet = false
                appState.authState = .authenticated
            } else {
                errorMessage = "Invalid email or password"
            }
        }
    }
}

// the sheet that pops up for email login/signup
// nothing fancy, just email + password fields
struct EmailAuthSheet: View {
    let isSignUp: Bool
    @Binding var email: String
    @Binding var password: String
    @Binding var confirmPassword: String
    @Binding var errorMessage: String
    @Binding var isLoading: Bool
    let onSubmit: () -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    enum Field {
        case email, password, confirmPassword
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textFieldStyle(GymQuestTextFieldStyle())
                        .textContentType(.emailAddress)
                        #if os(iOS)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        #endif
                        .focused($focusedField, equals: .email)

                    SecureField("Password", text: $password)
                        .textFieldStyle(GymQuestTextFieldStyle())
                        .textContentType(isSignUp ? .newPassword : .password)
                        .focused($focusedField, equals: .password)

                    if isSignUp {
                        SecureField("Confirm Password", text: $confirmPassword)
                            .textFieldStyle(GymQuestTextFieldStyle())
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .confirmPassword)
                    }
                }

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Button {
                    onSubmit()
                } label: {
                    if isLoading {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Text(isSignUp ? "Create Account" : "Sign In")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isLoading)

                Spacer()
            }
            .padding(24)
            .gqPageBackground()
            .navigationTitle(isSignUp ? "Create Account" : "Sign In")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                focusedField = .email
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AppState())
}
