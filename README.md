# GymQuest

A gamified fitness app for iOS — real-time workout tracking, multi-provider AI coaching, and RPG-style progression. Built with SwiftUI, SwiftData, and Swift 5.9.

> iOS 17+ &nbsp;|&nbsp; Xcode 15+ &nbsp;|&nbsp; XcodeGen

---

## Repo Structure

```
GymQuest/                        ← The App
├── Models/                        Data layer (SwiftData @Model)
├── Views/                         25+ screens & components
├── Services/                      18 services (AI, Auth, PR, Strava…)
├── Features/                      Feature modules
└── Resources/                     Assets, launch screen

Tests/                           ← Quality Engineering
├── Unit/                          Models · Services · ViewModels
├── Integration/                   Network stubs · SwiftData lifecycle
├── Snapshot/                      Visual regression (iPhone 15 + SE)
├── UI/                            Smoke tests · Accessibility audits
├── Performance/                   Benchmarks · Memory leak detection
├── Helpers/                       MockURLProtocol · TestFixtures
└── Fixtures/                      JSON response stubs
```

---

## Features

**Workout Engine** — Live set tracking, auto PR detection (weight / rep / volume / est. 1RM), smart rest timers with haptics, RPE capture, ghost data from previous sessions, and milestone celebrations.

**AI Coach** — Packages workout history, streaks, weekly volume, and deload signals into structured JSON. Supports OpenAI, Groq, Ollama (local), and a rule-based offline demo mode.

**Gamification** — XP system across 11 levels, quest categories with difficulty tiers, squad challenges, and forgiveness tokens.

**Social Feed** — Workout cards, coach takeaways, media posts, "Follow this workout", fist bumps, and pod-based accountability groups.

**Design System** — Glassmorphism components (`GlassCard`, `StatPill`, `AnimatedProgressBar`), gradient typography, neon buttons, dark-first palette.

---

## Test Suite

50+ test methods across three Xcode test targets:

| Target | Source | What it covers |
|--------|--------|----------------|
| `GymQuestTests` | `Tests/Unit` `Integration` `Snapshot` | Models, services, ViewModels, network stubs, SwiftData CRUD, visual regression |
| `GymQuestUITests` | `Tests/UI` | Login smoke test, accessibility audits |
| `GymQuestPerformanceTests` | `Tests/Performance` | 1000-workout fetch, 365-day streaks, memory leak detection |

---

## CI/CD

Six platform configs — all reference **scheme names**, not file paths:

| Platform | Config |
|----------|--------|
| GitHub Actions | `.github/workflows/pr-quality-gate.yml` |
| GitLab CI | `.gitlab-ci.yml` |
| Buildkite | `.buildkite/pipeline.yml` |
| CircleCI | `.circleci/config.yml` |
| Xcode Cloud | `ci_scripts/` |
| Bitrise | `bitrise.yml` |
| Fastlane | `fastlane/Fastfile` — 6 lanes including `pr_tests`, `full_matrix`, `snapshots` |

**Security scanning:** CodeQL, Dependabot, Semgrep SAST, Trivy, Syft SBOM generation, OIDC zero-secrets deploy template.

---

## Getting Started

```bash
brew install xcodegen        # one-time
cd GymQuest-iOS
xcodegen generate
open GymQuest.xcodeproj
```

**Run tests:**
```bash
xcodebuild test -scheme GymQuestTests            -destination 'platform=iOS Simulator,name=iPhone 16'
xcodebuild test -scheme GymQuestUITests           -destination 'platform=iOS Simulator,name=iPhone 16'
xcodebuild test -scheme GymQuestPerformanceTests  -destination 'platform=iOS Simulator,name=iPhone 16'
```

**AI setup** is optional — the app runs in Demo Mode without API keys. To enable real AI responses, go to Profile → select a provider → enter your key.

**Python backend** (optional) — ACWR injury prevention, RAG exercise knowledge, LangChain prompts. See [`backend/README.md`](backend/README.md).

---

## Author

**Benjamin Hilderman** — [@BenHilderman](https://github.com/BenHilderman)
