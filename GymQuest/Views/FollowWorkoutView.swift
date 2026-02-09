//
//  FollowWorkoutView.swift
//  GymQuest
//
//  Interactive workout following view.
//  When someone posts a workout, others can "Follow" it step-by-step.
//  Includes rest timers, exercise progression, and visual guides.
//

import SwiftUI
import SwiftData

// MARK: - Workout Detail Sheet (Preview mode)

struct WorkoutDetailSheet: View {
    let workoutData: SharedWorkoutData
    let onFollow: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text(workoutData.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        HStack(spacing: 16) {
                            Label(workoutData.workoutType, systemImage: "dumbbell.fill")
                            Label("~\(workoutData.estimatedDuration) min", systemImage: "clock")
                        }
                        .font(.subheadline)
                        .foregroundColor(GQColors.textSecondary)

                        Text("by @\(workoutData.authorUsername)")
                            .font(.caption)
                            .foregroundColor(GQColors.textTertiary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .homeSocialCard(accent: GQColors.vividPurple, emphasized: true)

                    VStack(alignment: .leading, spacing: 16) {
                        Text("EXERCISES")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(GQColors.textTertiary)
                            .tracking(1)

                        ForEach(Array(workoutData.exercises.enumerated()), id: \.element.id) { index, exercise in
                            ExercisePreviewCard(
                                index: index + 1,
                                exercise: exercise
                            )
                        }
                    }
                    .padding()

                    Button {
                        onFollow()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                            Text("Follow This Workout")
                        }
                    }
                    .buttonStyle(HomeSocialPrimaryButtonStyle(accent: GQColors.cyanSpark))
                    .gqScreenHorizontalPadding()
                    .padding(.bottom, 40)
                }
            }
            .gqPageBackground()
            .navigationTitle("Workout Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Exercise Preview Card

struct ExercisePreviewCard: View {
    let index: Int
    let exercise: SharedWorkoutData.SharedExercise

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(GQColors.vividPurple.opacity(0.2))
                            .frame(width: 36, height: 36)
                        Text("\(index)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)

                        Text("\(exercise.sets.count) sets • \(exercise.muscleGroup)")
                            .font(.caption)
                            .foregroundColor(GQColors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(GQColors.textTertiary)
                }
            }
            .buttonStyle(GQInteractiveStyle())

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(spacing: 8) {
                        ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { setIndex, set in
                            HStack {
                                Text("Set \(setIndex + 1)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(GQColors.textSecondary)
                                    .frame(width: 50, alignment: .leading)

                                Text("\(set.reps) reps")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)

                                if set.weight > 0 {
                                    Text("@ \(Int(set.weight)) lbs")
                                        .font(.system(size: 14))
                                        .foregroundColor(GQColors.gold)
                                }

                                Spacer()

                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 11))
                                    Text("\(set.restSeconds)s rest")
                                        .font(.system(size: 12))
                                }
                                .foregroundColor(GQColors.textTertiary)
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    if !exercise.demoTips.isEmpty {
                        Divider()
                            .background(Color.white.opacity(0.1))

                        VStack(alignment: .leading, spacing: 6) {
                            Text("FORM TIPS")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(GQColors.textTertiary)
                                .tracking(0.5)

                            ForEach(exercise.demoTips, id: \.self) { tip in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(GQColors.success)
                                    Text(tip)
                                        .font(.system(size: 13))
                                        .foregroundColor(GQColors.textSecondary)
                                }
                            }
                        }
                    }
                }
                .padding(.leading, 48)
            }
        }
        .padding(16)
        .homeSocialCard(accent: GQColors.vividPurple)
    }
}

// MARK: - Active Workout Following View

struct FollowWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let workoutData: SharedWorkoutData
    let profile: UserProfile

    @State private var currentExerciseIndex = 0
    @State private var currentSetIndex = 0
    @State private var isResting = false
    @State private var restTimeRemaining = 0
    @State private var restDuration = 0
    @State private var workoutStartTime = Date()
    @State private var completedSets: Set<String> = []
    @State private var showingCompletionSheet = false
    @State private var timer: Timer?

    var currentExercise: SharedWorkoutData.SharedExercise? {
        guard currentExerciseIndex < workoutData.exercises.count else { return nil }
        return workoutData.exercises[currentExerciseIndex]
    }

    var currentSet: SharedWorkoutData.SharedExercise.SharedSet? {
        guard let exercise = currentExercise,
              currentSetIndex < exercise.sets.count else { return nil }
        return exercise.sets[currentSetIndex]
    }

    var progressPercentage: Double {
        let totalSets = workoutData.exercises.reduce(0) { $0 + $1.sets.count }
        guard totalSets > 0 else { return 0 }
        return Double(completedSets.count) / Double(totalSets)
    }

    var body: some View {
        ZStack {
            Color.clear

            VStack(spacing: 0) {
                WorkoutProgressHeader(
                    workoutTitle: workoutData.title,
                    progress: progressPercentage,
                    elapsedTime: elapsedTimeString,
                    onClose: { dismiss() }
                )

                if isResting {
                    RestTimerView(
                        timeRemaining: restTimeRemaining,
                        totalSeconds: restDuration,
                        nextExercise: getNextExerciseName(),
                        onSkip: { skipRest() }
                    )
                } else if let exercise = currentExercise, let set = currentSet {
                    ActiveSetView(
                        exercise: exercise,
                        setNumber: currentSetIndex + 1,
                        totalSets: exercise.sets.count,
                        targetReps: set.reps,
                        targetWeight: set.weight,
                        onComplete: { completeSet() }
                    )
                } else {
                    WorkoutCompleteView(
                        onFinish: { finishWorkout() }
                    )
                }

                Spacer()

                ExerciseOverviewBar(
                    exercises: workoutData.exercises,
                    currentIndex: currentExerciseIndex,
                    completedSets: completedSets
                )
            }
        }
        .gqPageBackground()
        .onAppear {
            workoutStartTime = Date()
        }
        .onDisappear {
            timer?.invalidate()
        }
        .sheet(isPresented: $showingCompletionSheet) {
            WorkoutCompletionSummary(
                workoutData: workoutData,
                duration: Int(Date().timeIntervalSince(workoutStartTime) / 60),
                profile: profile,
                onDismiss: { dismiss() }
            )
        }
    }

    var elapsedTimeString: String {
        let elapsed = Int(Date().timeIntervalSince(workoutStartTime))
        let mins = elapsed / 60
        let secs = elapsed % 60
        return String(format: "%d:%02d", mins, secs)
    }

    func completeSet() {
        guard let exercise = currentExercise, let set = currentSet else { return }

        // Mark set as complete
        let setKey = "\(exercise.id)-\(currentSetIndex)"
        completedSets.insert(setKey)

        // Check if more sets in this exercise
        if currentSetIndex + 1 < exercise.sets.count {
            // Start rest timer, then move to next set
            startRestTimer(seconds: set.restSeconds)
            currentSetIndex += 1
        } else if currentExerciseIndex + 1 < workoutData.exercises.count {
            // Move to next exercise
            startRestTimer(seconds: set.restSeconds)
            currentExerciseIndex += 1
            currentSetIndex = 0
        } else {
            // Workout complete
            showingCompletionSheet = true
        }
    }

    func startRestTimer(seconds: Int) {
        isResting = true
        restTimeRemaining = seconds
        restDuration = seconds

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if restTimeRemaining > 0 {
                restTimeRemaining -= 1
            } else {
                timer?.invalidate()
                isResting = false
            }
        }
    }

    func skipRest() {
        timer?.invalidate()
        isResting = false
    }

    func getNextExerciseName() -> String {
        if let exercise = currentExercise {
            if currentSetIndex < exercise.sets.count {
                return "\(exercise.name) - Set \(currentSetIndex + 1)"
            }
        }
        if currentExerciseIndex + 1 < workoutData.exercises.count {
            return workoutData.exercises[currentExerciseIndex + 1].name
        }
        return "Done!"
    }

    func finishWorkout() {
        showingCompletionSheet = true
    }
}

// MARK: - Progress Header

struct WorkoutProgressHeader: View {
    let workoutTitle: String
    let progress: Double
    let elapsedTime: String
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Text(workoutTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                Text(elapsedTime)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .homeSocialCard(accent: GQColors.vividPurple, emphasized: true, cornerRadius: 10)
            }

            AnimatedProgressBar(
                progress: progress,
                height: 7,
                colors: [GQColors.vividPurple]
            )
            .frame(height: 7)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(GQColors.surfaceOverlay.opacity(0.86))
    }
}

// MARK: - Rest Timer View

struct RestTimerView: View {
    let timeRemaining: Int
    let totalSeconds: Int
    let nextExercise: String
    let onSkip: () -> Void

    private var progress: CGFloat {
        guard totalSeconds > 0 else { return 0 }
        return CGFloat(timeRemaining) / CGFloat(totalSeconds)
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Rest")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(GQColors.textSecondary)

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 12)
                    .frame(width: 196, height: 196)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [GQColors.vividPurple, GQColors.cyanSpark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 196, height: 196)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text("\(timeRemaining)")
                        .font(.system(size: 66, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("seconds")
                        .font(.subheadline)
                        .foregroundColor(GQColors.textSecondary)
                }
            }

            VStack(spacing: 8) {
                Text("UP NEXT")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(1)

                Text(nextExercise)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(14)
            .homeSocialCard(accent: GQColors.cyanSpark, cornerRadius: 12)
            .padding(.horizontal, GQLayout.screenHorizontal)

            Button {
                onSkip()
            } label: {
                Text("Skip Rest")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }
            .buttonStyle(HomeSocialSecondaryButtonStyle())
            .padding(.horizontal, 60)

            Spacer()
        }
    }
}

// MARK: - Active Set View

struct ActiveSetView: View {
    let exercise: SharedWorkoutData.SharedExercise
    let setNumber: Int
    let totalSets: Int
    let targetReps: Int
    let targetWeight: Double
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            Text(exercise.name)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, GQLayout.screenHorizontal)

            Text("SET \(setNumber) of \(totalSets)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(GQColors.vividPurple)
                .tracking(1)

            VStack(spacing: 8) {
                HStack(spacing: 40) {
                    VStack(spacing: 4) {
                        Text("TARGET REPS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(GQColors.textTertiary)
                        Text("\(targetReps)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.white)
                        Text("reps")
                            .font(.caption)
                            .foregroundColor(GQColors.textSecondary)
                    }

                    if targetWeight > 0 {
                        VStack(spacing: 4) {
                            Text("WEIGHT")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(GQColors.textTertiary)
                            Text("\(Int(targetWeight))")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(GQColors.electricGold)
                            Text("lbs")
                                .font(.caption)
                                .foregroundColor(GQColors.textSecondary)
                        }
                    }
                }
            }
            .padding(24)
            .homeSocialCard(accent: GQColors.vividPurple, emphasized: true, cornerRadius: 20)
            .padding(.horizontal, GQLayout.screenHorizontal)

            if !exercise.demoTips.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(exercise.demoTips.prefix(2), id: \.self) { tip in
                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 12))
                                .foregroundColor(GQColors.electricGold)
                            Text(tip)
                                .font(.system(size: 13))
                                .foregroundColor(GQColors.textSecondary)
                        }
                    }
                }
                .padding(12)
                .homeSocialCard(accent: GQColors.cyanSpark, cornerRadius: 12)
                .padding(.horizontal, GQLayout.screenHorizontal)
            }

            Spacer()

            Button {
                onComplete()
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Complete Set")
                }
            }
            .buttonStyle(HomeSocialPrimaryButtonStyle(accent: GQColors.cyanSpark))
            .padding(.horizontal, 32)
            .padding(.bottom, 20)
        }
        .padding()
    }
}

// MARK: - Exercise Overview Bar

struct ExerciseOverviewBar: View {
    let exercises: [SharedWorkoutData.SharedExercise]
    let currentIndex: Int
    let completedSets: Set<String>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                    ExercisePill(
                        name: exercise.name,
                        setsCount: exercise.sets.count,
                        completedCount: countCompletedSets(for: exercise),
                        isCurrent: index == currentIndex,
                        isPast: index < currentIndex
                    )
                }
            }
            .gqScreenHorizontalPadding()
            .padding(.vertical, 12)
        }
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.20))
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1),
                    alignment: .top
                )
        )
    }

    func countCompletedSets(for exercise: SharedWorkoutData.SharedExercise) -> Int {
        var count = 0
        for i in 0..<exercise.sets.count {
            let key = "\(exercise.id)-\(i)"
            if completedSets.contains(key) {
                count += 1
            }
        }
        return count
    }
}

struct ExercisePill: View {
    let name: String
    let setsCount: Int
    let completedCount: Int
    let isCurrent: Bool
    let isPast: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(name)
                .font(.system(size: 12, weight: isCurrent ? .bold : .medium))
                .foregroundColor(isCurrent ? .white : (isPast ? GQColors.cyanSpark : GQColors.textSecondary))
                .lineLimit(1)

            // Set indicators
            HStack(spacing: 4) {
                ForEach(0..<setsCount, id: \.self) { i in
                    Circle()
                        .fill(i < completedCount ? GQColors.cyanSpark : (isCurrent ? GQColors.coral : Color.white.opacity(0.3)))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .homeSocialCard(
            accent: isCurrent ? GQColors.vividPurple : GQColors.cyanSpark,
            emphasized: isCurrent,
            cornerRadius: 20
        )
    }
}

// MARK: - Workout Complete Views

struct WorkoutCompleteView: View {
    let onFinish: () -> Void
    @State private var checkScale: CGFloat = 0.85

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 82))
                .foregroundColor(GQColors.cyanSpark)
                .scaleEffect(checkScale)

            Text("Workout Complete")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Nice work. Ready to review and share it?")
                .font(.system(size: 15))
                .foregroundColor(GQColors.textSecondary)
                .multilineTextAlignment(.center)

            Button("Continue") {
                onFinish()
            }
            .buttonStyle(HomeSocialPrimaryButtonStyle(accent: GQColors.cyanSpark))
            .padding(.horizontal, 56)

            Spacer()
        }
        .padding(.horizontal, GQLayout.screenHorizontal)
        .onAppear {
            HapticManager.shared.workoutComplete()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) {
                checkScale = 1.0
            }
        }
    }
}

struct WorkoutCompletionSummary: View {
    let workoutData: SharedWorkoutData
    let duration: Int
    let profile: UserProfile
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var caption = ""
    @State private var showShareOptions = false
    @State private var hasShared = false

    var totalSets: Int {
        workoutData.exercises.reduce(0) { $0 + $1.sets.count }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Success icon
                    ZStack {
                        Circle()
                            .fill(GQColors.cyanSpark.opacity(0.2))
                            .frame(width: 100, height: 100)

                        Image(systemName: "trophy.fill")
                            .font(.system(size: 40))
                            .foregroundColor(GQColors.electricGold)
                    }
                    .padding(.top, 20)

                    Text("Workout Complete!")
                        .font(.title2)
                        .fontWeight(.bold)

                    // Stats
                    HStack(spacing: 30) {
                        WorkoutStatBlock(value: "\(duration)", label: "Minutes")
                        WorkoutStatBlock(value: "\(totalSets)", label: "Sets")
                        WorkoutStatBlock(value: "\(workoutData.exercises.count)", label: "Exercises")
                    }
                    .padding()
                    .homeSocialCard()

                    // Attribution badge
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14))
                        Text("Inspired by @\(workoutData.authorUsername)")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(GQColors.cyanSpark)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(GQColors.cyanSpark.opacity(0.15))
                    .cornerRadius(20)

                    // Share section
                    VStack(spacing: 16) {
                        Text("SHARE YOUR WORKOUT")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(GQColors.textTertiary)
                            .tracking(1)

                        TextField("Add a caption...", text: $caption, axis: .vertical)
                            .lineLimit(2...4)
                            .padding(12)
                            .homeSocialCard(cornerRadius: 12)

                        Button {
                            shareToFeed()
                        } label: {
                            HStack {
                                Image(systemName: hasShared ? "checkmark.circle.fill" : "square.and.arrow.up")
                                Text(hasShared ? "Shared!" : "Share to Feed")
                            }
                        }
                        .buttonStyle(HomeSocialPrimaryButtonStyle(accent: hasShared ? GQColors.success : GQColors.cyanSpark))
                        .disabled(hasShared)

                        // Save for later option
                        Button {
                            saveWorkoutTemplate()
                        } label: {
                            HStack {
                                Image(systemName: "bookmark")
                                Text("Save Workout for Later")
                            }
                        }
                        .buttonStyle(HomeSocialSecondaryButtonStyle(cornerRadius: 12))
                    }
                    .padding()
                    .homeSocialCard()

                    Spacer().frame(height: 20)
                }
                .padding()
            }
            .gqPageBackground()
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
        }
    }

    private func shareToFeed() {
        let post = Post(
            authorId: profile.id,
            authorName: profile.name,
            authorUsername: profile.username,
            caption: caption.isEmpty ? "Just crushed this workout!" : caption,
            workoutType: workoutData.workoutType,
            duration: duration,
            setCount: totalSets,
            sharedWorkoutData: workoutData.encode(),
            inspiredByUsername: workoutData.authorUsername,
            inspiredByWorkoutId: workoutData.id,
            inspiredByName: workoutData.authorName
        )

        modelContext.insert(post)
        try? modelContext.save()

        withAnimation {
            hasShared = true
        }
    }

    private func saveWorkoutTemplate() {
        // Convert to WorkoutTemplate for saving
        let templateExercises = workoutData.exercises.enumerated().map { index, exercise in
            TemplateExercise(
                name: exercise.name,
                muscleGroup: exercise.muscleGroup,
                suggestedSets: exercise.sets.count,
                suggestedReps: "\(exercise.sets.first?.reps ?? 10)",
                suggestedWeight: exercise.sets.first?.weight,
                order: index
            )
        }

        let template = WorkoutTemplate(
            odId: profile.id,
            name: "\(workoutData.title) (from @\(workoutData.authorUsername))",
            workoutType: WorkoutType(rawValue: workoutData.workoutType) ?? .push,
            exercises: templateExercises,
            estimatedDuration: workoutData.estimatedDuration
        )

        modelContext.insert(template)
        try? modelContext.save()
    }
}

struct WorkoutStatBlock: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text(label)
                .font(.caption)
                .foregroundColor(GQColors.textSecondary)
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleWorkout = SharedWorkoutData(
        title: "Push Day",
        workoutType: "Push",
        estimatedDuration: 45,
        exercises: [
            SharedWorkoutData.SharedExercise(
                name: "Bench Press",
                muscleGroup: "Chest",
                sets: [
                    .init(reps: 8, weight: 135, restSeconds: 90),
                    .init(reps: 8, weight: 155, restSeconds: 90),
                    .init(reps: 6, weight: 175, restSeconds: 120)
                ],
                demoTips: ["Keep shoulder blades retracted", "Control the descent"]
            ),
            SharedWorkoutData.SharedExercise(
                name: "Overhead Press",
                muscleGroup: "Shoulders",
                sets: [
                    .init(reps: 10, weight: 85, restSeconds: 60),
                    .init(reps: 10, weight: 85, restSeconds: 60),
                    .init(reps: 8, weight: 95, restSeconds: 90)
                ],
                demoTips: ["Brace your core", "Lock out at the top"]
            )
        ],
        authorName: "Test User",
        authorUsername: "testuser"
    )

    WorkoutDetailSheet(workoutData: sampleWorkout) {
        print("Follow tapped")
    }
    .preferredColorScheme(.dark)
}
