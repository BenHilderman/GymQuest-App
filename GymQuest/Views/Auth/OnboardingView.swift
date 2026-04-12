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
import Supabase

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
    // Goal is silently defaulted — memo bans goal-setting questionnaires in onboarding.
    // The field remains for downstream systems but is never surfaced to the user here.
    @State private var selectedGoal: FitnessGoal = .general
    @State private var selectedExperience: ExperienceLevel = .intermediate
    @State private var selectedEquipment: Set<EquipmentType> = []
    // The mission question that replaces the goal step
    @State private var showUpFor: String = ""
    // Squad join — the memo 3 directive that every new user lands in a live
    // micro-community before seeing an empty feed.
    @State private var selectedSquadId: UUID? = nil
    @State private var enteredInviteCode: String = ""

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
                Group {
                    switch currentStep {
                    case 0:
                        NameStepView(name: $name)
                    case 1:
                        UsernameStepView(username: $username)
                    case 2:
                        BirthdayStepView(dateOfBirth: $dateOfBirth)
                    case 3:
                        ShowUpForStepView(showUpFor: $showUpFor)
                    case 4:
                        JoinSquadStepView(
                            selectedSquadId: $selectedSquadId,
                            enteredInviteCode: $enteredInviteCode
                        )
                    case 5:
                        ExperienceStepView(selectedExperience: $selectedExperience)
                    case 6:
                        EquipmentStepView(selectedEquipment: $selectedEquipment)
                    default:
                        EmptyView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(currentStep)

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
        7  // name, username, birthday, show up for, join squad, experience, equipment
    }

    private var isLastStep: Bool {
        currentStep == 6
    }

    private var canContinue: Bool {
        switch currentStep {
        case 0: return !name.trimmingCharacters(in: .whitespaces).isEmpty
        case 1: return !username.trimmingCharacters(in: .whitespaces).isEmpty
        case 2: return true
        case 3: return !showUpFor.trimmingCharacters(in: .whitespaces).isEmpty
        case 4:
            // A squad must be selected or a valid invite code entered. The
            // memo 3 directive: every new user joins a live squad before
            // seeing an empty feed.
            return selectedSquadId != nil || enteredInviteCode.trimmingCharacters(in: .whitespaces).count >= 4
        case 5: return true
        case 6: return !selectedEquipment.isEmpty
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
            profile.showUpFor = showUpFor.trimmingCharacters(in: .whitespaces)

            // Memo 3 directive: drop the new user directly into a live squad
            // before they see an empty feed. Either a picked seed squad or
            // one resolved from the entered invite code.
            SeedSquadService.joinSquadForOnboarding(
                selectedSquadId: selectedSquadId,
                inviteCode: enteredInviteCode,
                user: profile,
                modelContext: modelContext
            )

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
                .textFieldStyle(LiftAITextFieldStyle())
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

// The mission-aligned first question. Replaces the old "What's your goal?" step.
// Memo directive: onboarding is permission to show up, not a contract about outcomes.
// No lose-10-lbs, no before/after, no "how ambitious are you" — just a reason.
struct ShowUpForStepView: View {
    @Binding var showUpFor: String
    @FocusState private var isFocused: Bool

    // Soft chip suggestions — users can tap one or type anything
    private let suggestions = ["Myself", "My goals", "My kids", "My health", "My crew"]

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "figure.2.arms.open")
                .font(.system(size: 48))
                .foregroundStyle(GQGradients.primary)

            Text("Who do you want to show up for?")
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Text("You can change this anytime.")
                .font(.subheadline)
                .foregroundColor(GQColors.textTertiary)

            TextField("", text: $showUpFor)
                .textFieldStyle(LiftAITextFieldStyle())
                .focused($isFocused)
                .submitLabel(.done)
                .padding(.horizontal, 32)
                .padding(.top, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            showUpFor = suggestion
                            isFocused = false
                        } label: {
                            Text(suggestion)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(showUpFor == suggestion ? .white : GQColors.textSecondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(showUpFor == suggestion ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(GQColors.surfaceBase))
                                )
                                .overlay(
                                    Capsule()
                                        .strokeBorder(showUpFor == suggestion ? Color.clear : GQColors.borderDefault, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 32)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { isFocused = true }
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
                        .background(selectedExperience == level ? GQColors.deepBlue.opacity(0.1) : Color.black.opacity(0.03))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedExperience == level ? GQColors.deepBlue.opacity(0.4) : Color.clear, lineWidth: 1.5)
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
                            .background(isSelected ? GQColors.deepBlue.opacity(0.15) : Color.black.opacity(0.03))
                            .foregroundColor(isSelected ? GQColors.deepBlue : GQColors.textPrimary)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isSelected ? GQColors.deepBlue.opacity(0.5) : Color.clear, lineWidth: 1.5)
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
                .textFieldStyle(LiftAITextFieldStyle())
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

// MARK: - Join Squad Step
//
// Memo 3 directive: "Launch with seeded micro-communities (real friend clusters
// / gyms) to prevent the 'dead feed' problem and ensure early users feel seen."
// Every new user must land in a live squad before they see an empty feed.
//
// Users can either pick from the suggested seed squads (hand-curated clusters
// like "Queen's ARC", "305 Bench Club", etc.) or enter an invite code from a
// friend who's already on the app.

struct JoinSquadStepView: View {
    @Binding var selectedSquadId: UUID?
    @Binding var enteredInviteCode: String

    @Environment(\.modelContext) private var modelContext
    @Query private var allSquads: [Squad]

    @State private var didBootstrap = false

    private var seedSquads: [Squad] {
        allSquads.filter { $0.isSeedSquad }.sorted { $0.name < $1.name }
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.sequence.fill")
                .font(.system(size: 44))
                .foregroundStyle(GQGradients.primary)

            Text("Find your crew")
                .font(.title)
                .fontWeight(.bold)

            Text("Pick a squad or enter a code. Your proof needs people who will see it.")
                .font(.subheadline)
                .foregroundColor(GQColors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Invite code field
            HStack(spacing: 10) {
                Image(systemName: "ticket.fill")
                    .foregroundColor(GQColors.textTertiary)
                TextField("Invite code", text: $enteredInviteCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)
                    .onChange(of: enteredInviteCode) { _, newValue in
                        if !newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                            selectedSquadId = nil
                        }
                    }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(GQColors.surfaceBase)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(GQColors.borderDefault, lineWidth: 1)
            )
            .padding(.horizontal, 32)

            Text("— or pick a squad —")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(GQColors.textTertiary)
                .padding(.top, 4)

            // Suggested seed squads
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(seedSquads) { squad in
                        seedSquadRow(squad)
                    }
                    if seedSquads.isEmpty {
                        Text("Setting up suggestions…")
                            .font(.system(size: 12))
                            .foregroundColor(GQColors.textTertiary)
                            .padding(.top, 12)
                    }
                }
                .padding(.horizontal, 32)
            }
            .frame(maxHeight: 260)
        }
        .onAppear {
            if !didBootstrap {
                SeedSquadBootstrap.seedIfNeeded(modelContext: modelContext)
                didBootstrap = true
            }
        }
    }

    @ViewBuilder
    private func seedSquadRow(_ squad: Squad) -> some View {
        let isSelected = selectedSquadId == squad.id
        Button {
            withAnimation(.easeInOut(duration: 0.12)) {
                selectedSquadId = isSelected ? nil : squad.id
                if selectedSquadId != nil { enteredInviteCode = "" }
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AnyShapeStyle(GQGradients.primary))
                        .frame(width: 38, height: 38)
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(squad.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                    if !squad.descriptor.isEmpty {
                        Text(squad.descriptor)
                            .font(.system(size: 11))
                            .foregroundColor(GQColors.textTertiary)
                    }
                }
                Spacer()
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.clear : GQColors.borderDefault, lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle().fill(AnyShapeStyle(GQGradients.primary)).frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? GQColors.deepBlue.opacity(0.1) : GQColors.surfaceBase)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? GQColors.deepBlue.opacity(0.4) : GQColors.borderDefault, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Seed Squad Bootstrap & Join Service

/// Creates a fixed set of seed squads on first launch so new users always have
/// a live cluster to land in. The memo 3 "micro-community seeding" directive
/// turned into deterministic product state. In production these would be
/// replaced by real founder-curated squads; for local dev / TestFlight these
/// serve as non-empty defaults so the onboarding loop is never broken.
enum SeedSquadBootstrap {
    /// The hand-curated seed squads. Real-world founder seeding would replace
    /// these — a college gym, a powerlifting crew, a 6am lifting group, etc.
    static let seeds: [(name: String, descriptor: String, code: String)] = [
        ("305 Bench Club", "Intermediate lifters chasing 315", "BENCH3"),
        ("The ARC Crew", "Queen's ARC regulars", "ARCFAM"),
        ("Push / Pull / Legs", "PPL split, 4-6 days a week", "PPLCRW"),
        ("6 AM Lifters", "Morning gym dedicated crew", "SIX AM"),
        ("Full-Body Founders", "3 full-body days, busy schedules", "FBFOUND"),
        ("Strong First", "Starting Strength / Stronglifts pathway", "STRFST"),
        ("Home Gym Brigade", "Garage & basement lifters", "HOMEGM"),
        ("Back on the Bar", "Coming back from a break", "COMEBK"),
        ("Lift & Run", "Hybrid strength + conditioning", "HYBRID"),
        ("First Rep Club", "Brand new lifters, zero judgment", "FIRST1")
    ]

    @MainActor
    static func seedIfNeeded(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Squad>(predicate: #Predicate { $0.isSeedSquad == true })
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        let existingNames = Set(existing.map(\.name))

        for seed in seeds where !existingNames.contains(seed.name) {
            let squad = Squad(
                name: seed.name,
                creatorId: UUID(),
                memberIds: [],
                inviteCode: seed.code,
                isSeedSquad: true,
                descriptor: seed.descriptor
            )
            modelContext.insert(squad)
        }
        try? modelContext.save()
    }
}

/// Handles the onboarding squad-join flow — either joining a picked seed squad
/// or resolving an entered invite code to a real squad.
@MainActor
enum SeedSquadService {
    static func joinSquadForOnboarding(
        selectedSquadId: UUID?,
        inviteCode: String,
        user: UserProfile,
        modelContext: ModelContext
    ) {
        var squad: Squad? = nil

        // Prefer an explicit selection from the seed list
        if let id = selectedSquadId {
            let descriptor = FetchDescriptor<Squad>(predicate: #Predicate { $0.id == id })
            squad = try? modelContext.fetch(descriptor).first
        }

        // Fall back to invite-code resolution
        if squad == nil {
            let trimmed = inviteCode.trimmingCharacters(in: .whitespaces).uppercased()
            guard !trimmed.isEmpty else { return }
            let descriptor = FetchDescriptor<Squad>(predicate: #Predicate { $0.inviteCode == trimmed })
            squad = try? modelContext.fetch(descriptor).first
        }

        guard let squad else { return }
        if !squad.memberIds.contains(user.id) {
            squad.memberIds.append(user.id)
        }
    }
}
