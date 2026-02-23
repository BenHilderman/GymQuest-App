//
//  VideoGeneratorView.swift
//  GymQuest
//
//  Admin view for generating exercise videos using Replicate AI.
//

import SwiftUI
import SwiftData

struct VideoGeneratorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @StateObject private var generator = ReplicateVideoGenerator()
    @State private var apiKey: String = ""
    @State private var showingAPIKeyInput = false
    @State private var selectedExercise: String = "All Exercises"

    let exerciseOptions = ["All Exercises", "Barbell Bench Press", "Barbell Back Squat", "Conventional Deadlift"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerSection

                    // API Key Section
                    apiKeySection

                    // Generation Controls
                    if generator.hasAPIKey() {
                        generationSection
                    }

                    // Progress
                    if generator.isGenerating {
                        progressSection
                    }

                    // Results
                    if !generator.generatedVideos.isEmpty {
                        resultsSection
                    }

                    // Error
                    if let error = generator.error {
                        errorSection(error)
                    }

                    Spacer(minLength: 40)
                }
                .padding(20)
            }
            .background(GQColors.background)
            .navigationTitle("Video Generator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(GQColors.textPrimary)
                }
            }
        }
        .onAppear {
            if let savedKey = UserDefaults.standard.string(forKey: "replicate_api_key") {
                apiKey = savedKey
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "video.badge.waveform")
                .font(.system(size: 48))
                .foregroundColor(GQColors.primary)

            Text("AI Video Generator")
                .font(.title2.weight(.bold))
                .foregroundColor(GQColors.textPrimary)

            Text("Generate exercise demonstration videos using Replicate AI models")
                .font(.subheadline)
                .foregroundColor(GQColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
    }

    // MARK: - API Key

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Replicate API Key")
                    .font(.headline)
                    .foregroundColor(GQColors.textPrimary)

                Spacer()

                if generator.hasAPIKey() {
                    Label("Connected", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }

            if showingAPIKeyInput || !generator.hasAPIKey() {
                VStack(alignment: .leading, spacing: 8) {
                    SecureField("Enter your Replicate API key", text: $apiKey)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color.black.opacity(0.06))
                        .cornerRadius(10)
                        .foregroundColor(GQColors.textPrimary)

                    Text("Get your API key at replicate.com/account/api-tokens")
                        .font(.caption)
                        .foregroundColor(GQColors.textTertiary)

                    Button {
                        generator.setAPIKey(apiKey)
                        showingAPIKeyInput = false
                    } label: {
                        Text("Save API Key")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(GQColors.primary)
                            .cornerRadius(10)
                    }
                }
            } else {
                Button {
                    showingAPIKeyInput = true
                } label: {
                    HStack {
                        Text("API key saved")
                            .foregroundColor(GQColors.textSecondary)
                        Spacer()
                        Text("Change")
                            .foregroundColor(GQColors.primary)
                    }
                    .padding(12)
                    .background(Color.black.opacity(0.03))
                    .cornerRadius(10)
                }
            }
        }
        .padding(16)
        .background(GQColors.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Generation

    private var generationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Generate Videos")
                .font(.headline)
                .foregroundColor(GQColors.textPrimary)

            // Exercise Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Select Exercise")
                    .font(.subheadline)
                    .foregroundColor(GQColors.textSecondary)

                Picker("Exercise", selection: $selectedExercise) {
                    ForEach(exerciseOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .padding(12)
                .background(Color.black.opacity(0.06))
                .cornerRadius(10)
                .tint(GQColors.textPrimary)
            }

            // Info
            VStack(alignment: .leading, spacing: 6) {
                Label("Uses Hunyuan Video model", systemImage: "cpu")
                Label("~2-5 minutes per video", systemImage: "clock")
                Label("Videos are 5-10 seconds each", systemImage: "film")
            }
            .font(.caption)
            .foregroundColor(GQColors.textSecondary)

            // Generate Button
            Button {
                Task {
                    if selectedExercise == "All Exercises" {
                        await generator.generateAllExerciseVideos()
                    } else {
                        if let url = await generator.generateSingleVideo(for: selectedExercise) {
                            print("Generated video: \(url)")
                        }
                    }
                    // Update Form Studio content after generation
                    updateFormStudioContent()
                }
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text(selectedExercise == "All Exercises" ? "Generate All Videos" : "Generate Video")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [GQColors.primary, GQColors.electricBlue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .disabled(generator.isGenerating)
            .opacity(generator.isGenerating ? 0.6 : 1)
        }
        .padding(16)
        .background(GQColors.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: GQColors.primary))
                .scaleEffect(1.2)

            Text(generator.currentProgress)
                .font(.subheadline)
                .foregroundColor(GQColors.textPrimary)
                .multilineTextAlignment(.center)

            Text("This may take several minutes...")
                .font(.caption)
                .foregroundColor(GQColors.textSecondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(GQColors.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Results

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Generated Videos")
                    .font(.headline)
                    .foregroundColor(GQColors.textPrimary)

                Spacer()

                Text("\(generator.generatedVideos.count) videos")
                    .font(.caption)
                    .foregroundColor(GQColors.textSecondary)
            }

            ForEach(generator.generatedVideos) { video in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(video.exerciseName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(GQColors.textPrimary)

                        Text("\(video.angle)° • \(video.clipType)")
                            .font(.caption)
                            .foregroundColor(GQColors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                .padding(12)
                .background(Color.black.opacity(0.03))
                .cornerRadius(10)
            }

            // Export Button
            Button {
                let json = generator.exportAsJSON()
                UIPasteboard.general.string = json
            } label: {
                HStack {
                    Image(systemName: "doc.on.clipboard")
                    Text("Copy URLs to Clipboard")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(GQColors.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(GQColors.primary.opacity(0.15))
                .cornerRadius(10)
            }
        }
        .padding(16)
        .background(GQColors.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Error

    private func errorSection(_ error: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)

            Text(error)
                .font(.subheadline)
                .foregroundColor(GQColors.textPrimary)

            Spacer()
        }
        .padding(14)
        .background(Color.orange.opacity(0.15))
        .cornerRadius(12)
    }

    // MARK: - Update Content

    private func updateFormStudioContent() {
        guard !generator.generatedVideos.isEmpty else { return }

        let repo = FormRepository(modelContext: modelContext)
        let exercises = repo.allExercises()

        for video in generator.generatedVideos {
            guard let exerciseUUID = UUID(uuidString: video.exerciseId),
                  let exercise = exercises.first(where: { $0.id == exerciseUUID }),
                  let mediaSet = exercise.mediaSets.first else {
                continue
            }

            // Find matching clip and update URL
            let clipType = ClipType(rawValue: video.clipType) ?? .loop
            let clipAngle = ClipAngle(rawValue: video.angle) ?? .a45

            if let clip = mediaSet.clips.first(where: { $0.type == clipType && $0.angle == clipAngle }) {
                clip.hlsURLString = video.videoURL
                print("Updated \(exercise.name) \(video.clipType) clip URL")
            } else {
                // Create new clip
                let newClip = FormClip(
                    type: clipType,
                    angle: clipAngle,
                    hlsURLString: video.videoURL,
                    durationSeconds: 10.0,
                    mediaSet: mediaSet
                )
                mediaSet.clips.append(newClip)
                print("Created new clip for \(exercise.name)")
            }
        }

        try? modelContext.save()
    }
}

// MARK: - Preview

#Preview {
    VideoGeneratorView()
}
