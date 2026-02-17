//
//  AIService.swift
//  GymQuest
//
//  Created by Benjamin Hilderman
//
//  Handles AI coaching integration. Packages user workout history and profile data,
//  sends to AI providers (OpenAI, Groq, Ollama), and returns personalized fitness advice.
//

import Foundation
import SwiftData

/// @MainActor ensures UI updates (loading states) happen on the main thread
@MainActor
class AIService: ObservableObject {
    @Published var isLoading = false


    /// Complete context package sent to AI - this is the JSON payload
    struct TrainingContext: Codable {
        let user: UserContext
        let stats: StatsContext
        let recentSessions: [SessionSummary]
    }

    /// User profile data for personalization
    struct UserContext: Codable {
        let name: String
        let goal: String           // Hypertrophy, Strength, Performance, General
        let daysPerWeek: Int       // Target training frequency
        let injuries: String       // AI avoids recommending exercises that aggravate these
        let level: Int             // 1-11 based on XP progression
    }

    /// Computed statistics for AI analysis
    struct StatsContext: Codable {
        let streak: Int            // Consecutive days trained
        let totalSessions: Int     // All-time workout count
        let sessionsThisWeek: Int  // Current week's frequency
        let weeklyVolume: [String: Int]  // Sets per muscle group (e.g., "Chest": 12)
        let needsDeload: Bool      // True if 3+ weeks of high volume/RPE
    }

    /// Individual workout summary (last 10 sent to AI)
    struct SessionSummary: Codable {
        let date: String
        let type: String           // Push, Pull, Legs, etc.
        let duration: Int          // Minutes
        let rpe: Int               // Rate of Perceived Exertion (1-10)
        let exercises: [ExerciseSummary]
        let notes: String
    }

    /// Exercise data within a session
    struct ExerciseSummary: Codable {
        let name: String           // e.g., "Bench Press"
        let sets: Int              // Number of sets performed
        let muscle: String         // Target muscle group
    }


    /// Aggregates user data into a structured context for AI consumption
    /// Limited to 10 recent workouts to manage token usage - was having slow response issues
    func buildContext(profile: UserProfile, workouts: [Workout]) -> TrainingContext {
        let recentWorkouts = Array(workouts.prefix(10))
        let weekStart = Calendar.current.startOfWeek(for: Date())
        let weeklyWorkouts = workouts.filter { $0.date >= weekStart }

        return TrainingContext(
            user: UserContext(
                name: profile.name,
                goal: profile.goal.rawValue,
                daysPerWeek: profile.daysPerWeek,
                injuries: profile.injuries,
                level: profile.level
            ),
            stats: StatsContext(
                streak: calculateStreak(workouts: workouts),
                totalSessions: workouts.count,
                sessionsThisWeek: weeklyWorkouts.count,
                weeklyVolume: calculateWeeklyVolume(workouts: weeklyWorkouts),
                needsDeload: shouldDeload(workouts: workouts)
            ),
            recentSessions: recentWorkouts.map { workout in
                SessionSummary(
                    date: workout.date.formatted(date: .abbreviated, time: .omitted),
                    type: workout.type.rawValue,
                    duration: workout.duration,
                    rpe: workout.rpe,
                    exercises: workout.exercises.map { ex in
                        ExerciseSummary(
                            name: ex.name,
                            sets: ex.sets.count,
                            muscle: ex.muscleGroup.rawValue
                        )
                    },
                    notes: workout.notes
                )
            }
        )
    }

    /// Counts consecutive workout days from today backwards
    func calculateStreak(workouts: [Workout]) -> Int {
        guard !workouts.isEmpty else { return 0 }

        let calendar = Calendar.current
        let sortedWorkouts = workouts.sorted { $0.date > $1.date }
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        for _ in 0..<365 {
            let hasSession = sortedWorkouts.contains { workout in
                calendar.isDate(workout.date, inSameDayAs: checkDate)
            }

            if hasSession {
                streak += 1
            } else if streak > 0 {
                break
            }

            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }                                                                      // if nil (on edge cases) just use prev date

        return streak
    }

    /// Calculates weekly volume per muscle group for balance analysis
    func calculateWeeklyVolume(workouts: [Workout]) -> [String: Int] {
        var volume: [String: Int] = [:]
        for workout in workouts {
            for exercise in workout.exercises {
                let muscle = exercise.muscleGroup.rawValue
                volume[muscle, default: 0] += exercise.sets.count
            }
        }
        return volume
    }

    /// Deload detection: 3+ weeks of high volume (4+ sessions) with RPE >= 7.5
    func shouldDeload(workouts: [Workout]) -> Bool {
        let calendar = Calendar.current
        var highVolumeWeeks = 0

        for weekOffset in 0..<4 {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: calendar.startOfWeek(for: Date())),
                  let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else { continue }

            let weekWorkouts = workouts.filter { $0.date >= weekStart && $0.date <= weekEnd }
            let avgRPE = weekWorkouts.isEmpty ? 0 : Double(weekWorkouts.reduce(0) { $0 + $1.rpe }) / Double(weekWorkouts.count)

            if weekWorkouts.count >= 4 && avgRPE >= 7.5 {
                highVolumeWeeks += 1
            }
        }

        return highVolumeWeeks >= 3
    }


    /// Core AI interaction: builds context -> calls provider -> logs response
    func chat(
        prompt: String,
        profile: UserProfile,
        workouts: [Workout],
        modelContext: ModelContext
    ) async throws -> String {
        isLoading = true
        defer { isLoading = false }

        // Context for build turned to json text so model can process
        let context = buildContext(profile: profile, workouts: workouts)
        let contextJSON = try JSONEncoder().encode(context)
        let contextString = String(data: contextJSON, encoding: .utf8) ?? "{}"

        // System prompt: defines AI persona and includes user context. 
        // Could elaborate but want to focus on whats important, avoid confusion for the AI.
        let systemPrompt = """
        You are GymQuest AI Coach. Be direct, punchy, and actionable. Talk like a real coach texting their client - short sentences, no fluff.

        User Context:
        \(contextString)
        
        Rules:
        - MAX 2-3 sentences unless they ask for details
        - Use bullet points for lists (max 3-4 items)
        - Reference their actual numbers (streak, sets, RPE)
        - Be specific: "Do 3x8 at RPE 7" not "consider moderate intensity"
        - Goal: \(profile.goal.rawValue) | Injuries: \(profile.injuries.isEmpty ? "none" : profile.injuries)
        - If they need a deload, say it directly
        - End with ONE clear next action when relevant
        """

        let response: String

        // Route which AI backend to call based on user settings
        switch profile.aiProvider {
        case .demo:
            // Demo mode: no API calls, just rule-based responses using context
            response = getDemoResponse(prompt: prompt, context: context)

        case .openai:
            // Hosted LLM (OpenAI): send systemPrompt + user prompt to GPT-style API
            response = try await callOpenAI(
                systemPrompt: systemPrompt,
                userPrompt: prompt,
                apiKey: profile.apiKey
            )

        case .groq:
            // Hosted LLM (Groq): same chat format as OpenAI, different provider/model
            response = try await callGroq(
                systemPrompt: systemPrompt,
                userPrompt: prompt,
                apiKey: profile.apiKey
            )

        case .ollama:
            // Local LLM (Ollama): same prompts, but sent to a local server on the LAN
            response = try await callOllama(
                systemPrompt: systemPrompt,
                userPrompt: prompt,
                model: profile.ollamaModel,
                host: profile.ollamaHost
            )
        }

        // Persist to AILogEntry for debugging/analytics
        let logEntry = AILogEntry(
            prompt: prompt,
            response: response,
            provider: profile.aiProvider
        )
        modelContext.insert(logEntry)
        try? modelContext.save()

        return response
    }


    /// OpenAI Chat Completions API (gpt-4o-mini)
    private func callOpenAI(systemPrompt: String, userPrompt: String, apiKey: String) async throws -> String {
        guard !apiKey.isEmpty else { throw AIError.missingAPIKey }

        // building http request
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw AIError.apiError("Invalid OpenAI URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "max_tokens": 250,
            "temperature": 0.8
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AIError.apiError("OpenAI API request failed")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.parseError
        }

        return content
    }

    /// Groq API (Llama 3.3 70B) - faster inference on custom hardware
    private func callGroq(systemPrompt: String, userPrompt: String, apiKey: String) async throws -> String {
        guard !apiKey.isEmpty else { throw AIError.missingAPIKey }

        guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else {
            throw AIError.apiError("Invalid Groq URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": "llama-3.3-70b-versatile",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "max_tokens": 250,
            "temperature": 0.8
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.apiError("No response from Groq")
        }

        if httpResponse.statusCode != 200 {
            #if DEBUG
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("Groq API error (\(httpResponse.statusCode)): \(errorBody)")
            #endif
            throw AIError.apiError("Groq API error: \(httpResponse.statusCode)")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.parseError
        }

        return content
    }

    /// Ollama - local LLM inference (requires Ollama running on network)
    private func callOllama(systemPrompt: String, userPrompt: String, model: String, host: String) async throws -> String {
        let modelName = model.isEmpty ? "llama3.2" : model
        let ollamaHost = host.isEmpty ? "localhost" : host
        let baseURL = "http://\(ollamaHost):11434/api/chat"

        #if DEBUG
        print("Ollama: Connecting to \(baseURL) with model \(modelName)")
        #endif

        guard let url = URL(string: baseURL) else {
            throw AIError.apiError("Invalid Ollama URL: \(baseURL)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120  // Local inference can be slow

        let body: [String: Any] = [
            "model": modelName,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "stream": false
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let networkError {
            #if DEBUG
            print("Ollama network error: \(networkError)")
            #endif
            throw AIError.apiError("Network error: \(networkError.localizedDescription). Check WiFi and that Ollama is running with OLLAMA_HOST=0.0.0.0")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.apiError("No HTTP response from Ollama")
        }

        #if DEBUG
        print("Ollama response status: \(httpResponse.statusCode)")
        #endif

        if httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            #if DEBUG
            print("Ollama API error (\(httpResponse.statusCode)): \(errorBody)")
            #endif
            throw AIError.apiError("Ollama error \(httpResponse.statusCode): \(errorBody)")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let message = json?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            #if DEBUG
            let responseStr = String(data: data, encoding: .utf8) ?? "nil"
            print("Ollama parse error. Response: \(responseStr)")
            #endif
            throw AIError.apiError("Failed to parse Ollama response")
        }

        #if DEBUG
        print("Ollama success: got \(content.count) chars")
        #endif
        return content
    }


    private func getDemoResponse(prompt: String, context: TrainingContext) -> String {
        let lowerPrompt = prompt.lowercased()

        if lowerPrompt.contains("warm") {
            return """
            Quick warm-up:
            • 5 min cardio (bike or jump rope)
            • Dynamic stretches for target muscles
            • 2 light sets at 50% weight

            Then you're good to go.
            """
        }

        if lowerPrompt.contains("push") || lowerPrompt.contains("dial back") || lowerPrompt.contains("rest") {
            if context.stats.needsDeload {
                return "Take it easy today. \(context.stats.sessionsThisWeek) sessions this week with high RPE - your body needs a break. Light technique work or active recovery."
            }
            return "\(context.stats.streak) day streak, volume looks good. Send it today."
        }

        if lowerPrompt.contains("form") || lowerPrompt.contains("cue") {
            return """
            Universal cues:
            • Brace your core
            • Control the negative
            • Full ROM > ego weight

            Which exercise specifically?
            """
        }

        if lowerPrompt.contains("streak") {
            let msg = context.stats.streak >= 7 ? "Locked in." : context.stats.streak >= 3 ? "Building momentum." : "Let's stack some days."
            return "\(context.stats.streak) day streak. \(msg)"
        }

        if lowerPrompt.contains("finisher") {
            let finishers = [
                "100 band pull-aparts",
                "3x20 leg press drop set",
                "5 min AMRAP: 10 burpees, 20 mountain climbers",
                "50-40-30-20-10 KB swings"
            ]
            return "Try this: \(finishers.randomElement() ?? finishers[0])"
        }

        if lowerPrompt.contains("volume") || lowerPrompt.contains("overtrain") {
            let highVolume = context.stats.weeklyVolume.filter { $0.value > 20 }
            if !highVolume.isEmpty {
                let muscles = highVolume.map { "\($0.key): \($0.value) sets" }.joined(separator: ", ")
                return "Watch it - \(muscles). Dial back next week."
            }
            return "Volume looks balanced. Keep it up."
        }

        return "What's up \(context.user.name)? \(context.stats.totalSessions) sessions logged, \(context.stats.streak) day streak. Ask me about warm-ups, volume, form, or if you should push or rest today."
    }


    func generateCoachTakeaway(
        workout: Workout,
        profile: UserProfile,
        workouts: [Workout],
        hasPR: Bool
    ) async -> String {
        let context = buildContext(profile: profile, workouts: workouts)

        if profile.aiProvider == .demo {
            return getDemoTakeaway(workout: workout, context: context, hasPR: hasPR)
        }

        let systemPrompt = """
        You are a concise fitness coach giving ONE takeaway for a workout card.
        Rules:
        - MAX 25 words
        - Structure: [Observation]. [One actionable tip for next session].
        - Be specific to the workout type and exercises
        - Reference actual numbers when relevant
        - No fluff or "great job" - be real
        - No emojis
        """

        let exerciseList = workout.exercises.map { "\($0.name): \($0.sets.count) sets" }.joined(separator: ", ")
        let userPrompt = """
        Workout: \(workout.type.rawValue), \(workout.duration) min, \(workout.totalSets) sets, RPE \(workout.rpe)
        Exercises: \(exerciseList)
        Goal: \(profile.goal.rawValue)
        \(hasPR ? "Hit a PR this session." : "")
        """

        do {
            switch profile.aiProvider {
            case .openai:
                return try await callOpenAI(systemPrompt: systemPrompt, userPrompt: userPrompt, apiKey: profile.apiKey)
            case .groq:
                return try await callGroq(systemPrompt: systemPrompt, userPrompt: userPrompt, apiKey: profile.apiKey)
            case .ollama:
                return try await callOllama(systemPrompt: systemPrompt, userPrompt: userPrompt, model: profile.ollamaModel, host: profile.ollamaHost)
            case .demo:
                return getDemoTakeaway(workout: workout, context: context, hasPR: hasPR)
            }
        } catch {
            return getDemoTakeaway(workout: workout, context: context, hasPR: hasPR)
        }
    }

    /// Template-based takeaways for demo mode
    private func getDemoTakeaway(workout: Workout, context: TrainingContext, hasPR: Bool) -> String {
        let weeklyVolume = context.stats.weeklyVolume

        if hasPR {
            let prTakeaways = [
                "PR day! Your consistency is paying off. Keep the same approach next week.",
                "Strong lift. Now maintain this weight for 3-4 weeks before pushing again.",
                "New PR locked in. Focus on recovery today—you earned it."
            ]
            return prTakeaways.randomElement() ?? prTakeaways[0]
        }

        switch workout.type {
        case .push:
            let chestSets = weeklyVolume["Chest"] ?? 0
            if chestSets > 16 {
                return "High chest volume this week (\(chestSets) sets). Consider backing off next push day."
            }
            return "Solid pressing volume. Try paused reps on bench next time to build strength off the chest."

        case .pull:
            let backSets = weeklyVolume["Back"] ?? 0
            if backSets > 20 {
                return "Back is getting hammered (\(backSets) sets). Quality over quantity next session."
            }
            return "Good pull session. Add a pause at full contraction on rows to maximize lat engagement."

        case .legs:
            if workout.rpe >= 8 {
                return "Heavy leg day. Your CNS needs 48-72 hours before another lower session."
            }
            return "Solid leg work. Hip mobility before your next session will help squat depth."

        case .upper:
            return "Full upper hit. Balance is key—make sure back volume matches pressing volume."

        case .lower:
            return "Lower body done. Don't skip the stretching—tight hip flexors limit squat depth."

        case .fullBody:
            if workout.duration > 75 {
                return "Long session. Full body works best at 60-75 min to maintain intensity."
            }
            return "Efficient full body workout. This frequency works well for your schedule."

        case .cardio:
            return "Cardio logged. Keep heart rate in zone 2 for recovery, zone 4+ for conditioning."

        case .rest:
            return "Active recovery counts. Light movement today speeds up recovery for tomorrow."

        case .glutes:
            return "Glute work done. Progressive overload on hip thrusts is key for growth."

        case .abs:
            return "Core session complete. Prioritize bracing patterns for transfer to compound lifts."

        case .other:
            return "Custom session logged. Track your progress and adjust volume next time."
        }
    }


    /// Detects personal records: Rep PRs (weight at rep count) and Streak PRs (weekly milestones)
    func detectPRs(
        workout: Workout,
        allWorkouts: [Workout],
        profile: UserProfile
    ) -> [PRMoment] {
        var prMoments: [PRMoment] = []
        let previousWorkouts = allWorkouts.filter { $0.id != workout.id && $0.date < workout.date }

        for exercise in workout.exercises {
            if let repPR = detectRepPR(exercise: exercise, previousWorkouts: previousWorkouts, profile: profile) {
                prMoments.append(repPR)
            }
        }

        // Streak PR: triggers at 7-day milestones
        let streak = calculateStreak(workouts: allWorkouts)
        let previousStreak = calculateStreak(workouts: previousWorkouts)
        if streak > previousStreak && streak >= 7 && streak % 7 == 0 {
            let streakPR = PRMoment(
                odId: profile.id,
                odUsername: profile.username,
                prType: .streakPR,
                exerciseName: nil,
                value: "\(streak) day streak",
                previousValue: nil,
                improvement: "New record!"
            )
            prMoments.append(streakPR)
        }

        return prMoments
    }

    /// Compares current set to historical best for same exercise/rep range
    private func detectRepPR(
        exercise: Exercise,
        previousWorkouts: [Workout],
        profile: UserProfile
    ) -> PRMoment? {
        guard let bestSet = exercise.sets.max(by: { $0.weight < $1.weight }),
              bestSet.weight > 0,
              bestSet.reps > 0 else { return nil }

        var previousBest: (weight: Double, reps: Int)? = nil

        for workout in previousWorkouts {
            for ex in workout.exercises where ex.name == exercise.name {
                for set in ex.sets where set.reps >= bestSet.reps && set.weight > 0 {
                    if previousBest == nil || set.weight > previousBest!.weight {
                        previousBest = (set.weight, set.reps)
                    }
                }
            }
        }

        if let prev = previousBest {
            if bestSet.weight > prev.weight {
                let improvement = bestSet.weight - prev.weight
                return PRMoment(
                    odId: profile.id,
                    odUsername: profile.username,
                    prType: .repPR,
                    exerciseName: exercise.name,
                    value: "\(Int(bestSet.weight)) × \(bestSet.reps)",
                    previousValue: "\(Int(prev.weight)) × \(prev.reps)",
                    improvement: "+\(Int(improvement)) lbs"
                )
            }
        } else if bestSet.weight >= 45 {
            // First recorded lift with meaningful weight
            return PRMoment(
                odId: profile.id,
                odUsername: profile.username,
                prType: .repPR,
                exerciseName: exercise.name,
                value: "\(Int(bestSet.weight)) × \(bestSet.reps)",
                previousValue: nil,
                improvement: "First PR!"
            )
        }

        return nil
    }
}

// ============================================================================

// The Swift app handles basic AI chat, but Python enables advanced features:
//
// 1. ACWR (Acute:Chronic Workload Ratio)
//    - Sports science metric for injury prevention
//    - Compares recent training load (acute) to long-term average (chronic)
//    - Ratio > 1.5 = high injury risk, < 0.8 = undertrained
//    - Calculated using exponentially weighted moving averages
//
// 2. RAG (Retrieval-Augmented Generation)
//    - Semantic search over exercise science documents
//    - Uses embeddings (vector representations) to find relevant content
//    - Grounds AI responses in actual research, not just training data
//
// 3. LangChain
//    - Framework for chaining LLM calls with structured prompts
//    - Better prompt engineering than raw API calls
//    - Enables multi-step reasoning and tool use
//
// SETUP: cd backend && pip install -r requirements.txt && uvicorn main:app --port 8000
// ============================================================================

extension AIService {
    private var backendURL: String { "http://localhost:8000" }

    /// Enhanced coach endpoint - returns AI response + sports science metrics
    /// POST /api/coach - matches CoachRequest in main.py
    func callEnhancedCoach(
        prompt: String,
        profile: UserProfile,
        workouts: [Workout]
    ) async throws -> EnhancedCoachResponse {
        guard let url = URL(string: "\(backendURL)/api/coach") else {
            throw AIError.apiError("Invalid backend URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Transform Swift models to JSON payload for Python backend (SwiftData objects cant be sent properly)
        let workoutData: [[String: Any]] = workouts.prefix(10).map { workout in
            [
                "date": ISO8601DateFormatter().string(from: workout.date),
                "type": workout.type.rawValue,
                "duration": workout.duration,
                "rpe": workout.rpe,
                "total_sets": workout.totalSets,
                "exercises": workout.exercises.map { ex in
                    [
                        "name": ex.name,
                        "sets": ex.sets.count,
                        "muscle": ex.muscleGroup.rawValue
                    ]
                }
            ]
        }

        // In depth query/request body matches Python Pydantic model schema (To backend!)
        // matches CoachRequest in main.py
        let body: [String: Any] = [
            "prompt": prompt,
            "profile": [
                "name": profile.name,
                "goal": profile.goal.rawValue,
                "days_per_week": profile.daysPerWeek,
                "level": profile.level,
                "injuries": profile.injuries
            ],
            "workouts": workoutData,
            "api_key": profile.apiKey
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AIError.apiError("Backend request failed")
        }

        // Parse response: AI text + computed metrics from Python
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let responseText = json["response"] as? String,
              let trainingLoad = json["training_load"] as? [String: Any],
              let suggestions = json["suggestions"] as? [String],
              let needsDeload = json["needs_deload"] as? Bool else {
            throw AIError.parseError
        }

        return EnhancedCoachResponse(
            response: responseText,
            acwr: trainingLoad["acwr"] as? Double ?? 1.0,
            strainScore: trainingLoad["strain_score"] as? Double ?? 0,
            suggestions: suggestions,
            needsDeload: needsDeload
        )
    }

    /// RAG search endpoint - finds relevant exercise science documents
    /// POST /api/search
    /// Uses vector embeddings to find semantically similar content
    func searchExerciseKnowledge(query: String, topK: Int = 5) async throws -> [RAGSearchResult] {
        guard let url = URL(string: "\(backendURL)/api/search") else {
            throw AIError.apiError("Invalid backend URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "query": query,      // Natural language query
            "top_k": topK        // Number of results to return
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AIError.apiError("Search request failed")
        }

        guard let results = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw AIError.parseError
        }

        // Map JSON array to Swift structs
        return results.compactMap { dict in
            guard let content = dict["content"] as? String,
                  let source = dict["source"] as? String,
                  let score = dict["relevance_score"] as? Double else {
                return nil
            }
            return RAGSearchResult(content: content, source: source, relevanceScore: score)
        }
    }
}


/// Response from /api/coach endpoint
struct EnhancedCoachResponse {
    let response: String           // LangChain-generated AI response
    let acwr: Double               // Acute:Chronic Workload Ratio (0.8-1.3 = optimal, >1.5 = injury risk)
    let strainScore: Double        // Accumulated fatigue score (0-100)
    let suggestions: [String]      // Actionable recommendations from analysis
    let needsDeload: Bool          // Algorithm-determined recovery recommendation
}

/// Response from /api/search endpoint (RAG)
struct RAGSearchResult {
    let content: String            // Retrieved document text
    let source: String             // Source document/URL
    let relevanceScore: Double     // Cosine similarity score (0-1, higher = more relevant)
}


enum AIError: LocalizedError {
    case missingAPIKey
    case apiError(String)
    case parseError

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Please add your API key in Profile settings"
        case .apiError(let message):
            return message
        case .parseError:
            return "Failed to parse AI response"
        }
    }
}
