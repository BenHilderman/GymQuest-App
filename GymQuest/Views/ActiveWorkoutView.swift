//
//  ActiveWorkoutView.swift
//  GymQuest
//
//  Live workout session - track exercises and sets in real-time.
//  Add exercises, complete sets, view form demos, and save when done.
//

import SwiftUI
import SwiftData

// MARK: - Active Workout Session

struct ActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState

    let profile: UserProfile
    let initialWorkoutType: WorkoutType

    @State private var workoutType: WorkoutType
    @State private var exercises: [ActiveExercise] = []
    @State private var workoutStartTime = Date()
    @State private var showingAddExercise = false
    @State private var showingFormDemo: ActiveExercise?
    @State private var showingFormPeek = false
    @State private var formPeekExercise: FormExercise?
    @State private var showingCompletion = false
    @State private var elapsedTime = 0
    @State private var timer: Timer?

    init(profile: UserProfile, workoutType: WorkoutType = .push) {
        self.profile = profile
        self.initialWorkoutType = workoutType
        self._workoutType = State(initialValue: workoutType)
    }

    var completedSetsCount: Int {
        exercises.reduce(0) { $0 + $1.sets.filter { $0.isCompleted }.count }
    }

    var totalSetsCount: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }

    var body: some View {
        ZStack {
            // Background - pure black TikTok style
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with timer and progress
                workoutHeader

                // Exercise list
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach($exercises) { $exercise in
                            ActiveExerciseCard(
                                exercise: $exercise,
                                onShowDemo: { showFormPeek(for: exercise.name) }
                            )
                        }

                        // Add exercise button
                        addExerciseButton
                    }
                    .padding(16)
                    .padding(.bottom, 100)
                }

                // Bottom bar
                bottomBar
            }
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
        .sheet(isPresented: $showingAddExercise) {
            AddExerciseToSessionSheet(exercises: $exercises, workoutType: workoutType)
        }
        .sheet(item: $showingFormDemo) { exercise in
            ExerciseFormDemoSheet(exerciseName: exercise.name)
        }
        .sheet(isPresented: $showingFormPeek) {
            if let exercise = formPeekExercise {
                FormPeekSheet(exercise: exercise)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showingCompletion) {
            WorkoutSessionCompletionSheet(
                exercises: exercises,
                duration: elapsedTime / 60,
                workoutType: workoutType,
                profile: profile,
                onDismiss: { dismiss() }
            )
        }
    }

    // MARK: - Header

    private var workoutHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    // Confirm cancel
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title3)
                        .foregroundColor(.white)
                }

                Spacer()

                // Workout type picker
                Menu {
                    ForEach(WorkoutType.allCases, id: \.self) { type in
                        Button(type.rawValue) {
                            workoutType = type
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: workoutType.icon)
                        Text(workoutType.rawValue)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(20)
                }

                Spacer()

                // Timer
                Text(formatTime(elapsedTime))
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundColor(GQColors.primary)
            }
            .padding(.horizontal)

            // Progress bar - flat TikTok style
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(GQColors.primary)
                        .frame(width: totalSetsCount > 0 ? geo.size.width * CGFloat(completedSetsCount) / CGFloat(totalSetsCount) : 0, height: 4)
                }
            }
            .frame(height: 4)
            .padding(.horizontal)

            // Stats row
            HStack(spacing: 24) {
                Label("\(exercises.count)", systemImage: "figure.strengthtraining.traditional")
                Label("\(completedSetsCount)/\(totalSetsCount)", systemImage: "checkmark.circle")
            }
            .font(.system(size: 13))
            .foregroundColor(GQColors.textSecondary)
        }
        .padding(.vertical, 16)
        .background(Color.black)
    }

    // MARK: - Add Exercise Button

    private var addExerciseButton: some View {
        Button {
            showingAddExercise = true
        } label: {
            HStack {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                Text("Add Exercise")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(GQColors.cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 16) {
            // Quick add last exercise
            if let lastExercise = exercises.last {
                Button {
                    addSetToExercise(lastExercise)
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add Set")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Finish workout - TikTok style solid button
            Button {
                finishWorkout()
            } label: {
                Text("Finish")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(GQColors.primary)
                    .cornerRadius(22)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.black)
    }

    // MARK: - Helpers

    private func startTimer() {
        workoutStartTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedTime = Int(Date().timeIntervalSince(workoutStartTime))
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func addSetToExercise(_ exercise: ActiveExercise) {
        if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
            let lastSet = exercises[index].sets.last
            let newSet = ActiveSet(
                reps: lastSet?.reps ?? 10,
                weight: lastSet?.weight ?? 0
            )
            exercises[index].sets.append(newSet)
        }
    }

    private func finishWorkout() {
        timer?.invalidate()
        showingCompletion = true
    }

    private func showFormPeek(for exerciseName: String) {
        // Seed Form Studio content if needed
        FormContentSeeder.seedIfNeeded(modelContext: modelContext)

        let repo = FormRepository(modelContext: modelContext)
        var allExercises = repo.allExercises()

        // If no exercises found, force seed sample data
        if allExercises.isEmpty {
            FormContentSeeder.seedSampleData(modelContext: modelContext)
            allExercises = repo.allExercises()
            print("Form Peek fallback: seeded \(allExercises.count) exercises")
        }

        // Try to find matching FormExercise by name (fuzzy match)
        let searchName = exerciseName.lowercased()
        let searchWords = searchName.split(separator: " ").map { String($0) }

        if let found = allExercises.first(where: { formEx in
            let formName = formEx.name.lowercased()
            // Check if search name is contained in form name or vice versa
            if formName.contains(searchName) || searchName.contains(formName) {
                return true
            }
            // Check if key words match (e.g., "bench" matches "barbell bench press")
            for word in searchWords {
                if word.count >= 4 && formName.contains(word) {
                    return true
                }
            }
            return false
        }) {
            formPeekExercise = found
            showingFormPeek = true
            print("Form Peek: showing '\(found.name)' for '\(exerciseName)'")
        } else {
            // Fall back to old demo sheet
            print("Form Peek: no match for '\(exerciseName)', falling back to demo")
            if let activeEx = exercises.first(where: { $0.name == exerciseName }) {
                showingFormDemo = activeEx
            }
        }
    }
}

// MARK: - Active Exercise Model

struct ActiveExercise: Identifiable {
    let id = UUID()
    var name: String
    var muscleGroup: MuscleGroup
    var sets: [ActiveSet]
    var notes: String = ""
}

struct ActiveSet: Identifiable {
    let id = UUID()
    var reps: Int
    var weight: Double
    var isCompleted: Bool = false
    var rpe: Int? = nil
}

// MARK: - Active Exercise Card

struct ActiveExerciseCard: View {
    @Binding var exercise: ActiveExercise
    let onShowDemo: () -> Void

    var completedCount: Int {
        exercise.sets.filter { $0.isCompleted }.count
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    Text(exercise.muscleGroup.rawValue)
                        .font(.system(size: 12))
                        .foregroundColor(GQColors.textTertiary)
                }

                Spacer()

                // Form demo button
                Button(action: onShowDemo) {
                    Text("Form")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(GQColors.elevatedSurface)
                        .cornerRadius(14)
                }
                .buttonStyle(.plain)

                // Progress indicator
                Text("\(completedCount)/\(exercise.sets.count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(completedCount == exercise.sets.count ? GQColors.primary : GQColors.textSecondary)
            }

            // Sets
            VStack(spacing: 8) {
                ForEach($exercise.sets) { $set in
                    ActiveSetRow(set: $set, setNumber: exercise.sets.firstIndex(where: { $0.id == set.id })! + 1)
                }

                // Add set button
                Button {
                    let lastSet = exercise.sets.last
                    exercise.sets.append(ActiveSet(
                        reps: lastSet?.reps ?? 10,
                        weight: lastSet?.weight ?? 0
                    ))
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add Set")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(GQColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(GQColors.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Active Set Row

struct ActiveSetRow: View {
    @Binding var set: ActiveSet
    let setNumber: Int

    var body: some View {
        HStack(spacing: 12) {
            // Set number
            Text("\(setNumber)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(set.isCompleted ? GQColors.primary : GQColors.textSecondary)
                .frame(width: 24)

            // Weight input
            HStack(spacing: 4) {
                TextField("0", value: $set.weight, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 60)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
                Text("lbs")
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textTertiary)
            }

            // Reps input
            HStack(spacing: 4) {
                TextField("0", value: $set.reps, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 50)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
                Text("reps")
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textTertiary)
            }

            Spacer()

            // Complete button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    set.isCompleted.toggle()
                }
            } label: {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 28))
                    .foregroundColor(set.isCompleted ? GQColors.primary : Color.white.opacity(0.2))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .opacity(set.isCompleted ? 0.7 : 1.0)
    }
}

// MARK: - Add Exercise Sheet

struct AddExerciseToSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var exercises: [ActiveExercise]
    let workoutType: WorkoutType

    @State private var searchText = ""
    @State private var selectedMuscleGroup: MuscleGroup?

    var filteredExercises: [ExerciseMetadata] {
        var results = ExtendedExerciseDatabase.exercises

        if let muscle = selectedMuscleGroup {
            results = results.filter { $0.muscleGroup == muscle }
        }

        if !searchText.isEmpty {
            results = results.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.muscleGroup.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }

        return results
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Muscle group filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "All", isSelected: selectedMuscleGroup == nil) {
                            selectedMuscleGroup = nil
                        }
                        ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                            FilterChip(title: muscle.rawValue, isSelected: selectedMuscleGroup == muscle) {
                                selectedMuscleGroup = muscle
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }

                // Exercise list
                List {
                    ForEach(filteredExercises) { exercise in
                        Button {
                            addExercise(exercise)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(exercise.name)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.white)
                                    Text(exercise.muscleGroup.rawValue)
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }

                                Spacer()

                                Image(systemName: "plus.circle")
                                    .foregroundColor(GQColors.primary)
                            }
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                }
                .listStyle(.plain)
                .searchable(text: $searchText, prompt: "Search exercises")
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func addExercise(_ metadata: ExerciseMetadata) {
        let exercise = ActiveExercise(
            name: metadata.name,
            muscleGroup: metadata.muscleGroup,
            sets: [
                ActiveSet(reps: 10, weight: 0),
                ActiveSet(reps: 10, weight: 0),
                ActiveSet(reps: 10, weight: 0)
            ]
        )
        exercises.append(exercise)
        dismiss()
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? .white : GQColors.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? GQColors.primary : GQColors.cardBackground)
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Exercise Form Demo Sheet

struct ExerciseFormDemoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let exerciseName: String

    var exerciseMetadata: ExerciseMetadata? {
        ExtendedExerciseDatabase.find(exerciseName)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Robot demo placeholder - flat TikTok style
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(GQColors.cardBackground)
                            .frame(height: 250)

                        VStack(spacing: 16) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.8))

                            Text("AI Form Demo")
                                .font(.headline)
                                .foregroundColor(.white)

                            Text("Coming soon - animated form guide")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)

                    // Form cues
                    if let metadata = exerciseMetadata {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("FORM CUES")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(GQColors.textTertiary)
                                .tracking(1)

                            ForEach(metadata.cues, id: \.self) { cue in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(GQColors.primary)
                                    Text(cue)
                                        .font(.system(size: 15))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                        .padding(.horizontal)

                        // Common mistakes
                        if !metadata.commonMistakes.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("COMMON MISTAKES")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(GQColors.textTertiary)
                                    .tracking(1)

                                ForEach(metadata.commonMistakes, id: \.self) { mistake in
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.red)
                                        Text(mistake)
                                            .font(.system(size: 15))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(exerciseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Workout Completion Sheet

struct WorkoutSessionCompletionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let exercises: [ActiveExercise]
    let duration: Int
    let workoutType: WorkoutType
    let profile: UserProfile
    let onDismiss: () -> Void

    @State private var caption = ""
    @State private var shareToFeed = true
    @State private var hasCompleted = false
    @State private var showEnhancedEditor = false
    @State private var savedWorkout: Workout?

    var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets.filter { $0.isCompleted }.count }
    }

    var totalVolume: Double {
        exercises.reduce(0.0) { total, exercise in
            total + exercise.sets.filter { $0.isCompleted }.reduce(0.0) { $0 + $1.weight * Double($1.reps) }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Success - TikTok style
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(GQColors.primary)
                        .padding(.top, 20)

                    Text("Workout Complete!")
                        .font(.title2)
                        .fontWeight(.bold)

                    // Stats
                    HStack(spacing: 24) {
                        WorkoutStatItem(value: "\(duration)", label: "min")
                        WorkoutStatItem(value: "\(totalSets)", label: "sets")
                        WorkoutStatItem(value: "\(exercises.count)", label: "exercises")
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)

                    // Share section
                    VStack(spacing: 16) {
                        Toggle(isOn: $shareToFeed) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share to Feed")
                            }
                        }
                        .tint(GQColors.primary)

                        if shareToFeed {
                            TextField("Add a caption...", text: $caption, axis: .vertical)
                                .lineLimit(2...4)
                                .padding(12)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(12)

                            // Customize Post button
                            Button {
                                saveWorkoutOnly()
                                showEnhancedEditor = true
                            } label: {
                                HStack {
                                    Image(systemName: "slider.horizontal.3")
                                    Text("Customize Post")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(GQColors.cyanSpark)
                                .padding(12)
                                .background(GQColors.cyanSpark.opacity(0.15))
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(16)

                    // Save button (quick save without customization)
                    Button {
                        saveWorkout()
                    } label: {
                        HStack {
                            Image(systemName: hasCompleted ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                            Text(hasCompleted ? "Saved!" : "Quick Save")
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(GQColors.primary)
                        .cornerRadius(22)
                    }
                    .disabled(hasCompleted)
                    .buttonStyle(.plain)
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                        onDismiss()
                    }
                }
            }
            .fullScreenCover(isPresented: $showEnhancedEditor) {
                if let workout = savedWorkout {
                    EnhancedPostEditorView(
                        profile: profile,
                        workout: workout,
                        exercises: exercises.map { activeEx in
                            CompletedExercise(
                                name: activeEx.name,
                                sets: activeEx.sets.filter { $0.isCompleted }.count,
                                index: exercises.firstIndex(where: { $0.id == activeEx.id }) ?? 0
                            )
                        },
                        duration: duration
                    )
                }
            }
        }
    }

    /// Save workout only (without creating a post) - used when opening enhanced editor
    private func saveWorkoutOnly() {
        guard savedWorkout == nil else { return }

        let workoutExercises = exercises.map { activeExercise -> Exercise in
            let sets = activeExercise.sets.filter { $0.isCompleted }.enumerated().map { index, activeSet in
                ExerciseSet(
                    reps: activeSet.reps,
                    weight: activeSet.weight,
                    order: index
                )
            }
            return Exercise(
                name: activeExercise.name,
                muscleGroup: activeExercise.muscleGroup,
                sets: sets
            )
        }

        let workout = Workout(
            type: workoutType,
            duration: duration,
            exercises: workoutExercises
        )

        modelContext.insert(workout)

        // Add XP
        let xpEarned = 20 + (totalSets * 5)
        _ = profile.addXP(xpEarned)

        try? modelContext.save()
        savedWorkout = workout

        withAnimation {
            hasCompleted = true
        }
    }

    private func saveWorkout() {
        // Create workout
        let workoutExercises = exercises.map { activeExercise -> Exercise in
            let sets = activeExercise.sets.filter { $0.isCompleted }.enumerated().map { index, activeSet in
                ExerciseSet(
                    reps: activeSet.reps,
                    weight: activeSet.weight,
                    order: index
                )
            }
            return Exercise(
                name: activeExercise.name,
                muscleGroup: activeExercise.muscleGroup,
                sets: sets
            )
        }

        let workout = Workout(
            type: workoutType,
            duration: duration,
            exercises: workoutExercises
        )

        modelContext.insert(workout)

        // Create post if sharing
        if shareToFeed {
            let post = Post(
                authorId: profile.id,
                authorName: profile.name,
                authorUsername: profile.username,
                caption: caption.isEmpty ? "Just finished a \(workoutType.rawValue) workout!" : caption,
                workoutType: workoutType.rawValue,
                duration: duration,
                setCount: totalSets
            )
            modelContext.insert(post)
        }

        // Add XP
        let xpEarned = 20 + (totalSets * 5)
        _ = profile.addXP(xpEarned)

        try? modelContext.save()

        withAnimation {
            hasCompleted = true
        }
    }
}

struct WorkoutStatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.caption)
                .foregroundColor(GQColors.textSecondary)
        }
    }
}

// MARK: - Preview

#Preview {
    ActiveWorkoutView(profile: UserProfile(), workoutType: .push)
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
