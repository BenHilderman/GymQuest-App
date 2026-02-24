//
//  LogWorkoutView.swift
//  GymQuest
//
//  Created by Benjamin Hilderman
//
//  Unified post creation. Post a pic, add caption, optionally log workout details.
//

import SwiftUI
import SwiftData
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

struct LogWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState

    let profile: UserProfile

    // post data
    @State private var caption: String = ""
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var mediaItems: [LocalMediaItem] = []

    // workout toggle
    @State private var includeWorkout: Bool = false

    // workout data
    @State private var workoutType: WorkoutType = .push
    @State private var duration: Int = 60
    @State private var exercises: [TempExercise] = []
    @State private var showingAddExercise = false

    // completion
    @State private var showingCompletion = false
    @State private var savedWorkout: Workout?
    @State private var xpEarned: Int = 0
    @State private var leveledUp: Bool = false
    @State private var newLevel: Int = 1

    // media loading state
    @State private var isLoadingMedia = false
    @State private var mediaLoadTask: Task<Void, Never>?

    var canPost: Bool {
        !caption.isEmpty || !mediaItems.isEmpty || includeWorkout // need at least one
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    MediaSection(
                        mediaItems: $mediaItems,
                        selectedItems: $selectedItems
                    )

                    captionField

                    workoutToggleSection

                    Spacer().frame(height: 100)
                }
                .padding()
            }
            .gqPageBackground()
            .navigationTitle("New Post")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") { savePost() }
                        .fontWeight(.semibold)
                        .disabled(!canPost)
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                AddExerciseSheet(exercises: $exercises)
            }
            .sheet(isPresented: $showingCompletion, onDismiss: { dismiss() }) {
                completionSheet
            }
            .onChange(of: selectedItems) { _, newItems in
                loadMedia(from: newItems)
            }
        }
    }

    private var captionField: some View {
        TextField("What's on your mind?", text: $caption, axis: .vertical)
            .lineLimit(3...6)
            .padding(14)
            .background(Color.black.opacity(0.05))
            .cornerRadius(12)
    }

    @ViewBuilder
    private var completionSheet: some View {
        if let workout = savedWorkout {
            WorkoutCompletionView(
                workout: workout,
                xpEarned: xpEarned,
                leveledUp: leveledUp,
                newLevel: newLevel,
                profile: profile,
                photoData: mediaItems.first?.data,
                caption: caption
            )
        }
    }

    private var workoutToggleSection: some View {
        VStack(spacing: 0) {
            workoutToggleHeader
            if includeWorkout {
                workoutDetailsSection
            }
        }
    }

    private var workoutToggleHeader: some View {
        Button {
            HapticManager.shared.impact(.medium)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                includeWorkout.toggle()
            }
        } label: {
            HStack {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 18))
                    .foregroundColor(includeWorkout ? .white : .gray)

                Text("Log Workout")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(includeWorkout ? .white : .gray)

                Spacer()

                Image(systemName: includeWorkout ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(includeWorkout ? GQColors.cyanSpark : .gray.opacity(0.5))
            }
            .padding(16)
            .background(Color.black.opacity(includeWorkout ? 0.06 : 0.03))
            .cornerRadius(12)
        }
        .buttonStyle(GQInteractiveStyle())
    }

    private var workoutDetailsSection: some View {
        VStack(spacing: 16) {
            workoutTypePicker
            durationPicker
            exercisesSection
        }
        .padding(16)
        .background(Color.black.opacity(0.02))
        .cornerRadius(12)
        .padding(.top, 8)
    }

    private var workoutTypePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Type")
                .font(.caption)
                .foregroundColor(GQColors.textTertiary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(WorkoutType.allCases, id: \.self) { type in
                        WorkoutTypeChip(
                            type: type,
                            isSelected: workoutType == type
                        ) {
                            workoutType = type
                        }
                    }
                }
            }
        }
    }

    private var durationPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Duration")
                .font(.caption)
                .foregroundColor(GQColors.textTertiary)

            HStack(spacing: 8) {
                ForEach([30, 45, 60, 75, 90], id: \.self) { mins in
                    DurationChip(
                        minutes: mins,
                        isSelected: duration == mins
                    ) {
                        duration = mins
                    }
                }
            }
        }
    }

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Exercises")
                    .font(.caption)
                    .foregroundColor(GQColors.textTertiary)

                Spacer()

                Button {
                    showingAddExercise = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                }
            }

            if exercises.isEmpty {
                Text("Optional - track lifts for PR detection")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.7))
            } else {
                ForEach(exercises.indices, id: \.self) { index in
                    ExerciseRow(
                        exercise: $exercises[index],
                        onDelete: { exercises.remove(at: index) }
                    )
                }
            }
        }
    }

    private func loadMedia(from items: [PhotosPickerItem]) {
        // Cancel any existing load task to prevent race conditions
        mediaLoadTask?.cancel()

        guard !items.isEmpty else {
            mediaItems = []
            return
        }

        isLoadingMedia = true

        mediaLoadTask = Task {
            var newMedia: [LocalMediaItem] = []
            for item in items {
                // Check for cancellation before processing each item
                if Task.isCancelled { return }

                if let data = try? await item.loadTransferable(type: Data.self) {
                    #if canImport(UIKit)
                    if let image = UIImage(data: data) {
                        newMedia.append(LocalMediaItem(data: data, image: image, isVideo: false))
                    } else {
                        // Assume video if not an image
                        newMedia.append(LocalMediaItem(data: data, image: nil, isVideo: true))
                    }
                    #endif
                }
            }

            // Only update if not cancelled
            if !Task.isCancelled {
                await MainActor.run {
                    mediaItems = newMedia
                    isLoadingMedia = false
                }
            }
        }
    }

    private func savePost() {
        if includeWorkout {
            // save workout + post
            let workout = Workout(
                date: Date(),
                type: workoutType,
                duration: duration,
                rpe: 7,
                notes: caption
            )

            // build exercises and sets
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

            modelContext.insert(workout) // swiftdata cascades to exercises/sets

            // xp system - rewards for completing workouts
            let xpGain = workout.xpValue
            let didLevelUp = profile.addXP(xpGain) // returns true if leveled up

            // save to disk
            do {
                try modelContext.save()
            } catch {
                print("Failed to save workout: \(error)")
            }

            // set completion state
            savedWorkout = workout
            xpEarned = xpGain
            leveledUp = didLevelUp
            newLevel = profile.level

            showingCompletion = true
        } else {
            // just post (no workout) - create new post with unique id
            let post = Post(
                id: UUID(), // ensure unique id
                authorId: profile.id,
                authorName: profile.name,
                authorUsername: profile.username,
                caption: caption,
                photoData: mediaItems.first?.data,
                videoData: mediaItems.first(where: { $0.isVideo })?.data
            )
            modelContext.insert(post)

            do {
                try modelContext.save()
            } catch {
                print("Failed to save post: \(error)")
            }

            dismiss()
        }
    }
}

struct LocalMediaItem: Identifiable {
    let id = UUID()
    let data: Data
    #if canImport(UIKit)
    let image: UIImage?
    #endif
    let isVideo: Bool
}

struct MediaSection: View {
    @Binding var mediaItems: [LocalMediaItem]
    @Binding var selectedItems: [PhotosPickerItem]

    private let maxItems = 10

    var body: some View {
        VStack(spacing: 12) {
            #if canImport(UIKit)
            if !mediaItems.isEmpty {
                // show selected media
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(mediaItems) { item in
                            ZStack(alignment: .topTrailing) {
                                if let image = item.image {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 160, height: 200)
                                        .clipped()
                                        .cornerRadius(12)
                                } else if item.isVideo {
                                    ZStack {
                                        Color.black
                                        Image(systemName: "play.circle.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(GQColors.textPrimary.opacity(0.8))
                                    }
                                    .frame(width: 160, height: 200)
                                    .cornerRadius(12)
                                }

                                Button {
                                    removeMedia(item)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(GQColors.textPrimary)
                        .shadow(radius: 2)
                                }
                                .padding(6)
                            }
                        }

                        // add more button (if under limit)
                        if mediaItems.count < maxItems {
                            PhotosPicker(
                                selection: $selectedItems,
                                maxSelectionCount: maxItems,
                                matching: .any(of: [.images, .videos])
                            ) {
                                VStack(spacing: 8) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 24))
                                    Text("\(mediaItems.count)/\(maxItems)")
                                        .font(.caption)
                                }
                                .foregroundColor(GQColors.textTertiary)
                                .frame(width: 80, height: 200)
                                .background(Color.black.opacity(0.03))
                                .cornerRadius(12)
                            }
                        }
                    }
                }
                .frame(height: 200)
            } else {
                // empty state - picker
                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: maxItems,
                    matching: .any(of: [.images, .videos])
                ) {
                    VStack(spacing: 12) {
                        HStack(spacing: 16) {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 28))
                            Image(systemName: "video.fill")
                                .font(.system(size: 28))
                        }
                        .foregroundColor(GQColors.textTertiary)

                        Text("Add Photos or Videos")
                            .font(.subheadline)
                            .foregroundColor(GQColors.textTertiary)

                        Text("Up to \(maxItems)")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .background(Color.black.opacity(0.02))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.black.opacity(0.06), style: StrokeStyle(lineWidth: 1, dash: [6]))
                    )
                }
            }
            #endif
        }
    }

    private func removeMedia(_ item: LocalMediaItem) {
        mediaItems.removeAll { $0.id == item.id }
        selectedItems = []
    }
}

struct WorkoutTypeChip: View {
    let type: WorkoutType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.select()
            action()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: type.icon)
                    .font(.system(size: 12))
                Text(type.rawValue)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : GQColors.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? GQColors.textPrimary : Color.black.opacity(0.06))
            .cornerRadius(16)
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
        .buttonStyle(GQInteractiveStyle())
    }
}

struct DurationChip: View {
    let minutes: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.select()
            action()
        } label: {
            Text("\(minutes)m")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? .white : GQColors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? GQColors.textPrimary : Color.black.opacity(0.06))
                .cornerRadius(16)
                .scaleEffect(isSelected ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
        .buttonStyle(GQInteractiveStyle())
    }
}

struct TempExercise: Identifiable {
    let id = UUID()
    var name: String
    var muscleGroup: MuscleGroup
    var sets: [TempSet]
}

struct TempSet: Identifiable {
    let id = UUID()
    var reps: Int
    var weight: Double
} // converted to ExerciseSet on save

struct ExerciseRow: View {
    @Binding var exercise: TempExercise
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if FeatureFlags.shared.exerciseGifsEnabled {
                    ExerciseGifView(exerciseName: exercise.name, size: .thumbnail, showFallback: false)
                }

                Text(exercise.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(GQColors.textTertiary)
                }
            }

            ForEach(exercise.sets.indices, id: \.self) { index in
                HStack(spacing: 8) {
                    Text("\(index + 1)")
                        .font(.caption)
                        .foregroundColor(GQColors.textTertiary)
                        .frame(width: 16)

                    HStack(spacing: 2) {
                        TextField("0", value: $exercise.sets[index].reps, format: .number)
                            .multilineTextAlignment(.center)
                            .frame(width: 44)
                            .padding(6)
                            .background(Color.black.opacity(0.03))
                            .cornerRadius(6)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                        Text("×")
                            .font(.caption)
                            .foregroundColor(GQColors.textTertiary)
                    }

                    HStack(spacing: 2) {
                        TextField("0", value: $exercise.sets[index].weight, format: .number)
                            .multilineTextAlignment(.center)
                            .frame(width: 54)
                            .padding(6)
                            .background(Color.black.opacity(0.03))
                            .cornerRadius(6)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        Text("lbs")
                            .font(.caption)
                            .foregroundColor(GQColors.textTertiary)
                    }

                    Spacer()

                    Button {
                        HapticManager.shared.tap()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            exercise.sets.remove(at: index)
                        }
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.red.opacity(0.6))
                    }
                }
            }

            Button {
                HapticManager.shared.tap()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    exercise.sets.append(TempSet(reps: 0, weight: 0))
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 10))
                    Text("Set")
                        .font(.caption)
                }
                .foregroundColor(.blue)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.02))
        .cornerRadius(10)
    }
}

struct AddExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var exercises: [TempExercise]

    @State private var selectedExercise: String = "Bench Press"
    @State private var selectedMuscle: MuscleGroup = .chest

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Exercise")
                        .font(.caption)
                        .foregroundColor(GQColors.textTertiary)

                    Picker("Exercise", selection: $selectedExercise) {
                        ForEach(ExerciseDatabase.exercises.keys.sorted(), id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(12)
                    .onChange(of: selectedExercise) {
                        if let muscle = ExerciseDatabase.exercises[selectedExercise] {
                            selectedMuscle = muscle
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Muscle Group")
                        .font(.caption)
                        .foregroundColor(GQColors.textTertiary)

                    Picker("Muscle", selection: $selectedMuscle) {
                        ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                            Text(muscle.rawValue).tag(muscle)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(12)
                }

                Button("Add Exercise") {
                    let newExercise = TempExercise(
                        name: selectedExercise,
                        muscleGroup: selectedMuscle,
                        sets: [TempSet(reps: 0, weight: 0)]
                    )
                    exercises.append(newExercise)
                    dismiss()
                }
                .buttonStyle(HomeSocialPrimaryButtonStyle(accent: GQColors.cyanSpark))

                Spacer()
            }
            .padding()
            .gqPageBackground()
            .navigationTitle("Add Exercise")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    LogWorkoutView(profile: UserProfile())
        .environmentObject(AppState())
}
