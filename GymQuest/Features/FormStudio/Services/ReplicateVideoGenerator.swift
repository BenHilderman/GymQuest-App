//
//  ReplicateVideoGenerator.swift
//  GymQuest
//
//  Generates exercise form videos using Replicate AI models.
//

import Foundation

// MARK: - Replicate API Models

struct ReplicatePrediction: Codable {
    let id: String
    let status: String
    let output: ReplicateOutput?
    let error: String?

    enum ReplicateOutput: Codable {
        case string(String)
        case array([String])

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let str = try? container.decode(String.self) {
                self = .string(str)
            } else if let arr = try? container.decode([String].self) {
                self = .array(arr)
            } else {
                throw DecodingError.typeMismatch(ReplicateOutput.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String or [String]"))
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .string(let str):
                try container.encode(str)
            case .array(let arr):
                try container.encode(arr)
            }
        }

        var firstURL: String? {
            switch self {
            case .string(let str): return str
            case .array(let arr): return arr.first
            }
        }
    }
}

struct ReplicateCreateRequest: Codable {
    let version: String
    let input: [String: AnyCodable]
}

// Helper for encoding mixed types
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            value = str
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else {
            value = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let str = value as? String {
            try container.encode(str)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        }
    }
}

// MARK: - Exercise Video Prompts

struct ExerciseVideoPrompt {
    let exerciseId: String
    let exerciseName: String
    let prompt: String
    let negativePrompt: String
    let angle: String
    let clipType: String

    static let benchPressPrompts: [ExerciseVideoPrompt] = [
        ExerciseVideoPrompt(
            exerciseId: "550e8400-e29b-41d4-a716-446655440001",
            exerciseName: "Barbell Bench Press",
            prompt: "Professional fitness video of athletic person performing barbell bench press exercise on weight bench in modern gym, 45 degree camera angle, perfect form demonstration, lying on bench gripping barbell shoulder width apart, lowering bar controlled to mid-chest then pressing up to full arm extension, smooth continuous motion, gym lighting, fitness instructional video style, 4K quality",
            negativePrompt: "blurry, distorted, bad anatomy, wrong form, dangerous technique, cartoon, anime, illustration",
            angle: "45",
            clipType: "loop"
        ),
        ExerciseVideoPrompt(
            exerciseId: "550e8400-e29b-41d4-a716-446655440001",
            exerciseName: "Barbell Bench Press",
            prompt: "Professional fitness tutorial video of athletic person performing barbell bench press, side view camera angle, detailed form breakdown showing setup position, unracking the bar, controlled descent to chest, pause at bottom, explosive press to lockout, proper back arch and foot placement, high quality gym setting, instructional fitness content",
            negativePrompt: "blurry, distorted, bad anatomy, wrong form, cartoon, anime",
            angle: "side",
            clipType: "breakdown"
        )
    ]

    static let squatPrompts: [ExerciseVideoPrompt] = [
        ExerciseVideoPrompt(
            exerciseId: "550e8400-e29b-41d4-a716-446655440002",
            exerciseName: "Barbell Back Squat",
            prompt: "Professional fitness video of athletic person performing barbell back squat in squat rack, 45 degree camera angle, bar positioned on upper back traps, standing with feet shoulder width apart, descending with hips back knees tracking over toes to below parallel depth, driving up through heels to standing, smooth controlled movement, modern gym setting, fitness instructional style, 4K",
            negativePrompt: "blurry, distorted, bad anatomy, knees caving, rounded back, cartoon, anime",
            angle: "45",
            clipType: "loop"
        ),
        ExerciseVideoPrompt(
            exerciseId: "550e8400-e29b-41d4-a716-446655440002",
            exerciseName: "Barbell Back Squat",
            prompt: "Professional squat tutorial video, side view showing full range of motion, athletic person with barbell on back, demonstrating hip hinge initiation, proper knee tracking, depth at parallel or below, neutral spine throughout, controlled eccentric and concentric phases, gym rack setting, instructional fitness content",
            negativePrompt: "blurry, distorted, bad form, butt wink, forward lean, cartoon",
            angle: "side",
            clipType: "breakdown"
        )
    ]

    static let deadliftPrompts: [ExerciseVideoPrompt] = [
        ExerciseVideoPrompt(
            exerciseId: "550e8400-e29b-41d4-a716-446655440003",
            exerciseName: "Conventional Deadlift",
            prompt: "Professional fitness video of athletic person performing conventional barbell deadlift, side camera angle, bar over mid-foot, hip hinge to grip bar just outside knees, flat back engaged lats, driving through floor extending hips and knees simultaneously to lockout standing tall, controlled lower back to floor, gym platform setting, instructional fitness video, 4K quality",
            negativePrompt: "blurry, distorted, rounded back, jerky movement, bad form, cartoon, anime",
            angle: "side",
            clipType: "loop"
        ),
        ExerciseVideoPrompt(
            exerciseId: "550e8400-e29b-41d4-a716-446655440003",
            exerciseName: "Conventional Deadlift",
            prompt: "Detailed deadlift form tutorial video, 45 degree angle view, showing proper stance width, grip position outside knees, chest up shoulders back, bracing core, initial pull off floor, bar path close to body, hip extension at top, complete lockout position, controlled descent, professional gym setting",
            negativePrompt: "blurry, bad anatomy, hitching, rounded lower back, bar drift, cartoon",
            angle: "45",
            clipType: "breakdown"
        )
    ]

    static var allPrompts: [ExerciseVideoPrompt] {
        benchPressPrompts + squatPrompts + deadliftPrompts
    }
}

// MARK: - Video Generator

@MainActor
class ReplicateVideoGenerator: ObservableObject {

    // MARK: - Published State
    @Published var isGenerating = false
    @Published var currentProgress: String = ""
    @Published var generatedVideos: [GeneratedVideo] = []
    @Published var error: String?

    struct GeneratedVideo: Identifiable {
        let id = UUID()
        let exerciseId: String
        let exerciseName: String
        let angle: String
        let clipType: String
        let videoURL: String
    }

    // MARK: - Configuration

    // Model versions on Replicate
    private let minimaxVideoModel = "minimax/video-01"
    private let hunyuanVideoModel = "tencent/hunyuan-video:847dfa8b01e739637fc76f480ede0c1d76408e1d694b830b5dfb8e547bf98405"

    private var apiKey: String {
        // Try to get from UserDefaults or environment
        if let key = UserDefaults.standard.string(forKey: "replicate_api_key"), !key.isEmpty {
            return key
        }
        // Fallback to environment variable (for development)
        return ProcessInfo.processInfo.environment["REPLICATE_API_TOKEN"] ?? ""
    }

    // MARK: - Public Methods

    func setAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "replicate_api_key")
    }

    func hasAPIKey() -> Bool {
        return !apiKey.isEmpty
    }

    func generateAllExerciseVideos() async {
        guard hasAPIKey() else {
            error = "No Replicate API key set. Please add your API key in settings."
            return
        }

        isGenerating = true
        error = nil
        generatedVideos = []

        for prompt in ExerciseVideoPrompt.allPrompts {
            currentProgress = "Generating \(prompt.exerciseName) (\(prompt.angle) angle, \(prompt.clipType))..."

            do {
                if let videoURL = try await generateVideo(prompt: prompt) {
                    let video = GeneratedVideo(
                        exerciseId: prompt.exerciseId,
                        exerciseName: prompt.exerciseName,
                        angle: prompt.angle,
                        clipType: prompt.clipType,
                        videoURL: videoURL
                    )
                    generatedVideos.append(video)
                }
            } catch {
                print("Failed to generate video for \(prompt.exerciseName): \(error)")
                self.error = "Failed to generate \(prompt.exerciseName): \(error.localizedDescription)"
            }

            // Small delay between requests to avoid rate limiting
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }

        currentProgress = "Complete! Generated \(generatedVideos.count) videos."
        isGenerating = false
    }

    func generateSingleVideo(for exerciseName: String, angle: String = "45") async -> String? {
        guard hasAPIKey() else {
            error = "No Replicate API key set"
            return nil
        }

        guard let prompt = ExerciseVideoPrompt.allPrompts.first(where: {
            $0.exerciseName.lowercased().contains(exerciseName.lowercased()) && $0.angle == angle
        }) else {
            error = "No prompt found for \(exerciseName)"
            return nil
        }

        isGenerating = true
        currentProgress = "Generating \(prompt.exerciseName)..."

        do {
            let url = try await generateVideo(prompt: prompt)
            isGenerating = false
            return url
        } catch {
            self.error = error.localizedDescription
            isGenerating = false
            return nil
        }
    }

    // MARK: - Private Methods

    private func generateVideo(prompt: ExerciseVideoPrompt) async throws -> String? {
        // Create prediction
        let predictionId = try await createPrediction(prompt: prompt)

        // Poll for completion
        let result = try await pollForCompletion(predictionId: predictionId)

        return result
    }

    private func createPrediction(prompt: ExerciseVideoPrompt) async throws -> String {
        let url = URL(string: "https://api.replicate.com/v1/predictions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Using Hunyuan Video model - good for fitness/instructional content
        let body: [String: Any] = [
            "version": "847dfa8b01e739637fc76f480ede0c1d76408e1d694b830b5dfb8e547bf98405",
            "input": [
                "prompt": prompt.prompt,
                "negative_prompt": prompt.negativePrompt,
                "width": 848,
                "height": 480,
                "video_length": 65,  // ~5 seconds at 13fps
                "seed": Int.random(in: 0...999999),
                "flow_shift": 7,
                "infer_steps": 30,
                "embedded_guidance_scale": 6.0
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VideoGenerationError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw VideoGenerationError.unauthorized
        }

        if httpResponse.statusCode != 201 && httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw VideoGenerationError.apiError("Status \(httpResponse.statusCode): \(errorBody)")
        }

        let prediction = try JSONDecoder().decode(ReplicatePrediction.self, from: data)
        return prediction.id
    }

    private func pollForCompletion(predictionId: String, maxAttempts: Int = 120) async throws -> String? {
        let url = URL(string: "https://api.replicate.com/v1/predictions/\(predictionId)")!

        for attempt in 0..<maxAttempts {
            var request = URLRequest(url: url)
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

            let (data, _) = try await URLSession.shared.data(for: request)
            let prediction = try JSONDecoder().decode(ReplicatePrediction.self, from: data)

            switch prediction.status {
            case "succeeded":
                return prediction.output?.firstURL

            case "failed", "canceled":
                throw VideoGenerationError.generationFailed(prediction.error ?? "Unknown error")

            case "processing", "starting":
                // Update progress
                await MainActor.run {
                    currentProgress = "Processing... (attempt \(attempt + 1)/\(maxAttempts))"
                }
                // Wait before polling again
                try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds

            default:
                try await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }

        throw VideoGenerationError.timeout
    }

    // MARK: - Export Generated URLs

    func exportAsJSON() -> String {
        var exercises: [[String: Any]] = []

        // Group videos by exercise
        let grouped = Dictionary(grouping: generatedVideos) { $0.exerciseId }

        for (exerciseId, videos) in grouped {
            guard let firstVideo = videos.first else { continue }

            var clips: [[String: Any]] = []
            for video in videos {
                clips.append([
                    "type": video.clipType,
                    "angle": video.angle,
                    "hlsURL": video.videoURL,
                    "overlayURL": NSNull(),
                    "duration": 10.0,
                    "chapters": NSNull()
                ])
            }

            let exercise: [String: Any] = [
                "id": exerciseId,
                "name": firstVideo.exerciseName,
                "mediaSet": [
                    "version": 1,
                    "defaultAngle": "45",
                    "clips": clips
                ]
            ]
            exercises.append(exercise)
        }

        let json: [String: Any] = ["generatedVideos": exercises]

        if let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
           let string = String(data: data, encoding: .utf8) {
            return string
        }

        return "{}"
    }
}

// MARK: - Errors

enum VideoGenerationError: LocalizedError {
    case noAPIKey
    case unauthorized
    case invalidResponse
    case apiError(String)
    case generationFailed(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No Replicate API key configured"
        case .unauthorized:
            return "Invalid API key - please check your Replicate API key"
        case .invalidResponse:
            return "Invalid response from Replicate API"
        case .apiError(let message):
            return "API error: \(message)"
        case .generationFailed(let message):
            return "Video generation failed: \(message)"
        case .timeout:
            return "Video generation timed out"
        }
    }
}
