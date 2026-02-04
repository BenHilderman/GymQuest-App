# GymQuest

A social fitness app for iOS and macOS built with SwiftUI that combines workout tracking, AI coaching, and social features.

## Features

### AI Coach
- Chat with an AI fitness coach that knows your workout history
- Get personalized advice on form, programming, recovery, and more
- Generate custom workout plans based on your goals
- Supports multiple AI providers:
  - **OpenAI** (GPT-4o-mini)
  - **Groq** (Llama 3.3 70B)
  - **Ollama** (local models)
  - **Demo Mode** (no API key required)

#### AI Implementation

| File | Description |
|------|-------------|
| [`AIService.swift`](GymQuest/Services/AIService.swift) | Core AI logic - builds training context from workout history, calls OpenAI/Groq/Ollama APIs, calculates streaks and volume, detects PRs, generates coach takeaways |
| [`CoachView.swift`](GymQuest/Views/CoachView.swift) | Chat UI with quick prompts, workout plan generator, message bubbles and keyboard handling |

**How it works:** AIService packages the user's workout history, goals, and stats into a JSON context that gets sent to the AI along with a system prompt that instructs it to act like a fitness coach. The AI can reference actual numbers (streak, sets, RPE) to give personalized advice.

## Tech Stack

- **SwiftUI** - Modern declarative UI framework
- **SwiftData** - Local persistence (no backend required)
- **Google Sign-In** - OAuth authentication
- **AVKit** - Video playback in feed
- **CryptoKit** - Password hashing for local auth

### Social Feed
- Share workout posts with photos and videos, like and comment on friends posts, shareable workout cards

### Workout Tracking
- Log workouts with exercises, sets, reps, and weight, automatic PR detection, track streak, weekly volume, and session history

### Progress Analytics
- Visual weekly activity chart, volume analysis by muscle group

### Gamification
- XP system for completing workouts, level progression with titles (Beginner → Legend), achievement badges for PRs and streaks

## Requirements

- iOS 17.0+ / macOS 14.0+
- Xcode 15.0+

### AI Setup (Optional)

The app works in Demo Mode without any API keys. To enable real AI responses:

1. Go to **Profile → Settings**
2. Select your AI provider
3. Enter your API key:
   - OpenAI: Get key from [platform.openai.com](https://platform.openai.com)
   - Groq: Get key from [console.groq.com](https://console.groq.com)
   - Ollama: Run locally with `OLLAMA_HOST=0.0.0.0 ollama serve`

### Google Sign-In Setup

To enable Google Sign-In, add your own `GoogleService-Info.plist` from the [Firebase Console](https://console.firebase.google.com).

## Python Backend (Optional)

An optional Python backend provides enhanced AI features:

- **ACWR** (Acute:Chronic Workload Ratio) for injury prevention
- **RAG** (Retrieval-Augmented Generation) for exercise knowledge
- **LangChain** for structured prompt engineering

See [`backend/README.md`](backend/README.md) for setup instructions.

## Author

**Benjamin Hilderman** - [@BenHilderman](https://github.com/BenHilderman)
