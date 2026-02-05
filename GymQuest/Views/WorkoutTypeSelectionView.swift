//
//  WorkoutTypeSelectionView.swift
//  GymQuest
//
//  Workout type selection screen - appears when tapping "Start Workout"
//  User picks their workout type before logging their session.
//

import SwiftUI
import SwiftData

struct WorkoutTypeSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    let profile: UserProfile

    @State private var selectedType: WorkoutType?
    @State private var showingLogWorkout = false
    @State private var appearAnimation = false

    let workoutTypes: [(type: WorkoutType, description: String, icon: String)] = [
        (.push, "Chest, Shoulders, Triceps", "arrow.up.circle.fill"),
        (.pull, "Back, Biceps, Rear Delts", "arrow.down.circle.fill"),
        (.legs, "Quads, Hamstrings, Glutes", "figure.walk"),
        (.upper, "Full Upper Body", "figure.arms.open"),
        (.lower, "Full Lower Body", "figure.stand"),
        (.fullBody, "Complete Full Body", "figure.strengthtraining.traditional"),
        (.cardio, "Running, Cycling, HIIT", "heart.fill"),
        (.rest, "Active Recovery Day", "leaf.fill")
    ]

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            // Gradient overlay
            LinearGradient(
                colors: [
                    (selectedType?.color ?? GQColors.vividPurple).opacity(0.15),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.4), value: selectedType)

            VStack(spacing: 0) {
                // Custom Header
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }

                    Spacer()

                    // Time indicator
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                        Text(Date().formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(GQColors.textSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        // Hero Section
                        VStack(spacing: 12) {
                            Text("Let's train")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)

                            Text("What are you working on today?")
                                .font(.system(size: 16))
                                .foregroundColor(GQColors.textSecondary)
                        }
                        .padding(.top, 24)
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 20)

                        // Workout Type Cards - Vertical List
                        VStack(spacing: 12) {
                            ForEach(Array(workoutTypes.enumerated()), id: \.element.type) { index, item in
                                WorkoutTypeCardNew(
                                    type: item.type,
                                    description: item.description,
                                    isSelected: selectedType == item.type
                                ) {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                        selectedType = item.type
                                    }
                                    // Auto-start after brief delay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                        showingLogWorkout = true
                                    }
                                }
                                .opacity(appearAnimation ? 1 : 0)
                                .offset(x: appearAnimation ? 0 : 50)
                                .animation(
                                    .spring(response: 0.5, dampingFraction: 0.8)
                                    .delay(Double(index) * 0.05),
                                    value: appearAnimation
                                )
                            }
                        }
                        .padding(.horizontal, 20)

                        Spacer(minLength: 50)
                    }
                }
            }
        }
        .onAppear {
            withAnimation {
                appearAnimation = true
            }
        }
        .fullScreenCover(isPresented: $showingLogWorkout) {
            if let type = selectedType {
                ActiveWorkoutView(profile: profile, workoutType: type)
            }
        }
    }
}

// MARK: - New Workout Type Card (Horizontal Style)

struct WorkoutTypeCardNew: View {
    let type: WorkoutType
    let description: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon with colored background
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [type.color, type.color.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)

                    Image(systemName: type.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.rawValue)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                // Arrow indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(type.color)
                    .frame(width: 32, height: 32)
                    .background(type.color.opacity(0.15))
                    .clipShape(Circle())
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(white: 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ?
                            type.color.opacity(0.8) :
                            Color.white.opacity(0.08),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Workout Type Card

struct WorkoutTypeCard: View {
    let type: WorkoutType
    let description: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? type.color.opacity(0.3) : Color.white.opacity(0.1))
                        .frame(width: 56, height: 56)

                    Image(systemName: type.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(isSelected ? type.color : .white.opacity(0.7))
                }

                // Text
                VStack(spacing: 4) {
                    Text(type.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text(description)
                        .font(.system(size: 11))
                        .foregroundColor(GQColors.textTertiary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(white: 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ?
                            LinearGradient(
                                colors: [type.color, type.color.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Active Workout View (Live logging with timer)

struct ActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let profile: UserProfile
    let workoutType: WorkoutType

    @State private var exercises: [TempExercise] = []
    @State private var showingAddExercise = false
    @State private var showingQuickAdd = false
    @State private var workoutStartTime = Date()
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var rpe: Int = 7
    @State private var notes: String = ""
    @State private var showingFinishConfirmation = false
    @State private var showingCompletion = false
    @State private var savedWorkout: Workout?
    @State private var showingFormDemo: String? = nil

    // Quick add exercises based on workout type
    var suggestedExercises: [String] {
        switch workoutType {
        case .push:
            return ["Bench Press", "Overhead Press", "Incline Dumbbell Press", "Tricep Pushdown", "Lateral Raise"]
        case .pull:
            return ["Barbell Row", "Pull-up", "Lat Pulldown", "Face Pull", "Bicep Curl"]
        case .legs:
            return ["Squat", "Romanian Deadlift", "Leg Press", "Leg Curl", "Calf Raise"]
        case .upper:
            return ["Bench Press", "Barbell Row", "Overhead Press", "Pull-up", "Bicep Curl"]
        case .lower:
            return ["Squat", "Deadlift", "Leg Press", "Leg Curl", "Hip Thrust"]
        case .fullBody:
            return ["Squat", "Bench Press", "Deadlift", "Overhead Press", "Barbell Row"]
        case .cardio:
            return ["Treadmill", "Cycling", "Rowing", "Stair Climber", "Jump Rope"]
        case .rest:
            return ["Stretching", "Foam Rolling", "Light Walk", "Yoga", "Mobility Work"]
        }
    }

    var formattedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Compact Timer Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(workoutType.rawValue)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(workoutType.color)

                            Text("\(exercises.count) exercises")
                                .font(.system(size: 12))
                                .foregroundColor(GQColors.textTertiary)
                        }

                        Spacer()

                        // Timer pill
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)

                            Text(formattedTime)
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(20)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(white: 0.05))

                    // Exercises List
                    ScrollView {
                        VStack(spacing: 12) {
                            // Quick Add Section
                            VStack(alignment: .leading, spacing: 10) {
                                Text("QUICK ADD")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(GQColors.textTertiary)
                                    .tracking(1)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(suggestedExercises, id: \.self) { exercise in
                                            QuickAddExerciseChip(
                                                name: exercise,
                                                isAdded: exercises.contains { $0.name == exercise }
                                            ) {
                                                quickAddExercise(exercise)
                                            }
                                        }

                                        // More button
                                        Button {
                                            showingAddExercise = true
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: "ellipsis")
                                                Text("More")
                                            }
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(GQColors.textSecondary)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(Color.white.opacity(0.05))
                                            .cornerRadius(20)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)

                            // Exercise Cards
                            ForEach(exercises.indices, id: \.self) { index in
                                ActiveExerciseCardV2(
                                    exercise: $exercises[index],
                                    onDelete: { exercises.remove(at: index) },
                                    onShowForm: { showingFormDemo = exercises[index].name }
                                )
                                .padding(.horizontal, 16)
                            }

                            if exercises.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "dumbbell")
                                        .font(.system(size: 48))
                                        .foregroundColor(GQColors.textTertiary)

                                    Text("Tap an exercise above to get started")
                                        .font(.system(size: 15))
                                        .foregroundColor(GQColors.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 60)
                            }

                            Spacer(minLength: 100)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.red)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showingFinishConfirmation = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Finish")
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(GQColors.success)
                    }
                }
            }
            .onAppear {
                startTimer()
            }
            .onDisappear {
                timer?.invalidate()
            }
            .sheet(isPresented: $showingAddExercise) {
                AddExerciseSheet(exercises: $exercises)
            }
            .sheet(item: $showingFormDemo) { exerciseName in
                ExerciseFormDemoSheet(exerciseName: exerciseName)
            }
            .alert("Finish Workout?", isPresented: $showingFinishConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Finish", role: .none) {
                    finishWorkout()
                }
            } message: {
                Text("Save your \(workoutType.rawValue) workout?")
            }
            .sheet(isPresented: $showingCompletion, onDismiss: { dismiss() }) {
                if let workout = savedWorkout {
                    WorkoutCompletionView(
                        workout: workout,
                        xpEarned: workout.xpValue,
                        leveledUp: false,
                        newLevel: profile.level,
                        profile: profile,
                        photoData: nil,
                        caption: ""
                    )
                }
            }
        }
    }

    private func quickAddExercise(_ name: String) {
        // Don't add if already exists
        guard !exercises.contains(where: { $0.name == name }) else { return }

        let muscleGroup = ExerciseDatabase.exercises[name] ?? .chest
        let newExercise = TempExercise(
            name: name,
            muscleGroup: muscleGroup,
            sets: [TempSet(reps: 0, weight: 0)]
        )
        exercises.append(newExercise)

        #if canImport(UIKit)
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        #endif
    }

    private func startTimer() {
        workoutStartTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedTime = Date().timeIntervalSince(workoutStartTime)
        }
    }

    private func finishWorkout() {
        let duration = Int(elapsedTime / 60)

        let workout = Workout(
            date: Date(),
            type: workoutType,
            duration: max(duration, 1),
            rpe: rpe,
            notes: notes
        )

        // Build exercises and sets
        for (order, tempEx) in exercises.enumerated() {
            let exercise = Exercise(
                name: tempEx.name,
                muscleGroup: tempEx.muscleGroup,
                order: order
            )

            for (setOrder, tempSet) in tempEx.sets.enumerated() {
                let exerciseSet = ExerciseSet(
                    reps: tempSet.reps,
                    weight: tempSet.weight,
                    rpe: nil,
                    order: setOrder
                )
                exercise.sets.append(exerciseSet)
            }

            workout.exercises.append(exercise)
        }

        modelContext.insert(workout)

        // XP system
        let xpGain = workout.xpValue
        _ = profile.addXP(xpGain)

        do {
            try modelContext.save()
        } catch {
            print("Failed to save workout: \(error)")
        }

        savedWorkout = workout
        showingCompletion = true
    }
}

// MARK: - Quick Add Exercise Chip

struct QuickAddExerciseChip: View {
    let name: String
    let isAdded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isAdded {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                }
                Text(name)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(isAdded ? GQColors.success : .white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isAdded ? GQColors.success.opacity(0.15) : Color.white.opacity(0.1))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isAdded ? GQColors.success.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .disabled(isAdded)
    }
}

// MARK: - Active Exercise Card V2 (Simplified)

struct ActiveExerciseCardV2: View {
    @Binding var exercise: TempExercise
    let onDelete: () -> Void
    let onShowForm: () -> Void

    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text("\(exercise.sets.count) sets")
                        .font(.system(size: 12))
                        .foregroundColor(GQColors.textTertiary)
                }

                Spacer()

                // Form demo button
                Button(action: onShowForm) {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.stand")
                        Text("Form")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(GQColors.cyanSpark)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(GQColors.cyanSpark.opacity(0.15))
                    .cornerRadius(8)
                }

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14))
                        .foregroundColor(GQColors.textTertiary)
                        .frame(width: 32, height: 32)
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.08))

            if isExpanded {
                // Sets
                VStack(spacing: 0) {
                    ForEach(exercise.sets.indices, id: \.self) { index in
                        SetRowSimple(
                            setNumber: index + 1,
                            reps: $exercise.sets[index].reps,
                            weight: $exercise.sets[index].weight,
                            onDelete: { exercise.sets.remove(at: index) }
                        )
                    }

                    // Add set button
                    Button {
                        let lastSet = exercise.sets.last
                        exercise.sets.append(TempSet(
                            reps: lastSet?.reps ?? 0,
                            weight: lastSet?.weight ?? 0
                        ))
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(GQColors.vividPurple)
                            Text("Add Set")
                                .foregroundColor(.white)
                        }
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
                .background(Color.white.opacity(0.03))
            }
        }
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Simple Set Row

struct SetRowSimple: View {
    let setNumber: Int
    @Binding var reps: Int
    @Binding var weight: Double
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Set number
            Text("\(setNumber)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(GQColors.vividPurple)
                .frame(width: 24)

            // Reps input
            VStack(spacing: 2) {
                TextField("0", value: $reps, format: .number)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 50)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif

                Text("reps")
                    .font(.system(size: 10))
                    .foregroundColor(GQColors.textTertiary)
            }

            Text("×")
                .foregroundColor(GQColors.textTertiary)

            // Weight input
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    TextField("0", value: $weight, format: .number)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 60)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(8)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }

                Text("lbs")
                    .font(.system(size: 10))
                    .foregroundColor(GQColors.textTertiary)
            }

            Spacer()

            // Delete
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.red.opacity(0.5))
            }
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Exercise Form Demo Sheet

struct ExerciseFormDemoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let exerciseName: String

    @State private var demo: ExerciseDemo?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Robot Demo - Use the new RobotDemoView
                    if let demo = demo {
                        RobotDemoView(demo: demo)
                            .padding(.horizontal, 16)
                    } else {
                        // No demo available
                        VStack(spacing: 20) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 60))
                                .foregroundColor(GQColors.textTertiary)

                            Text("Demo coming soon")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)

                            Text("We're working on adding a form demonstration for \(exerciseName).")
                                .font(.system(size: 14))
                                .foregroundColor(GQColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                        .padding(.horizontal, 32)
                    }
                }
                .padding(.vertical, 20)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(exerciseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                demo = RobotDemoService.shared.getDemoAnimation(for: exerciseName)
            }
        }
    }
}

extension String: Identifiable {
    public var id: String { self }
}

// MARK: - Active Exercise Card

struct ActiveExerciseCard: View {
    @Binding var exercise: TempExercise
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text(exercise.muscleGroup.rawValue)
                        .font(.system(size: 12))
                        .foregroundColor(GQColors.textTertiary)
                }

                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.red.opacity(0.7))
                }
            }

            // Sets
            VStack(spacing: 8) {
                // Header row
                HStack {
                    Text("SET")
                        .frame(width: 40, alignment: .leading)
                    Text("REPS")
                        .frame(width: 60)
                    Text("WEIGHT")
                        .frame(width: 80)
                    Spacer()
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(GQColors.textTertiary)

                ForEach(exercise.sets.indices, id: \.self) { index in
                    HStack {
                        Text("\(index + 1)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(GQColors.textSecondary)
                            .frame(width: 40, alignment: .leading)

                        TextField("0", value: $exercise.sets[index].reps, format: .number)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 15, weight: .medium))
                            .frame(width: 60)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(8)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif

                        HStack(spacing: 4) {
                            TextField("0", value: $exercise.sets[index].weight, format: .number)
                                .multilineTextAlignment(.center)
                                .font(.system(size: 15, weight: .medium))
                                .frame(width: 60)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(8)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif

                            Text("lbs")
                                .font(.system(size: 11))
                                .foregroundColor(GQColors.textTertiary)
                        }
                        .frame(width: 80)

                        Spacer()

                        Button {
                            exercise.sets.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.red.opacity(0.5))
                        }
                    }
                }

                // Add Set Button
                Button {
                    let lastSet = exercise.sets.last
                    exercise.sets.append(TempSet(
                        reps: lastSet?.reps ?? 0,
                        weight: lastSet?.weight ?? 0
                    ))
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 12))
                        Text("Add Set")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(GQColors.cyanSpark)
                    .padding(.vertical, 8)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - WorkoutType Color Extension

extension WorkoutType {
    var color: Color {
        switch self {
        case .push: return GQColors.vividPurple
        case .pull: return GQColors.cyanSpark
        case .legs: return GQColors.success
        case .upper: return GQColors.deepBlue
        case .lower: return Color.orange
        case .fullBody: return GQColors.coralRed
        case .cardio: return Color.pink
        case .rest: return GQColors.success.opacity(0.7)
        }
    }
}

#Preview {
    WorkoutTypeSelectionView(profile: UserProfile(name: "Ben", username: "ben"))
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
