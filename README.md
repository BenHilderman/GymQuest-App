# GymQuest

Gamified fitness app for iOS. Real time workout tracking, multi provider AI coaching, RPG style progression.

> SwiftUI · SwiftData · Swift 5.9 · iOS 17+ · XcodeGen

<p align="center">
  <img src=".github/screenshots/today.png" width="230" alt="Today dashboard" />
  &nbsp;&nbsp;
  <img src=".github/screenshots/progress.png" width="230" alt="Progress overview" />
  &nbsp;&nbsp;
  <img src=".github/screenshots/progress_prs.png" width="230" alt="PRs and exercise trends" />
</p>

<p align="center">
  <img src=".github/screenshots/active_workout.png" width="230" alt="Active workout" />
  &nbsp;&nbsp;
  <img src=".github/screenshots/start_workout.png" width="230" alt="Start workout" />
  &nbsp;&nbsp;
  <img src=".github/screenshots/custom_workout.png" width="230" alt="Custom workout splits" />
</p>

<p align="center">
  <img src=".github/screenshots/discover.png" width="230" alt="Discover feed" />
  &nbsp;&nbsp;
  <img src=".github/screenshots/clubs.png" width="230" alt="Clubs" />
  &nbsp;&nbsp;
  <img src=".github/screenshots/profile.png" width="230" alt="Profile" />
</p>

---

```
GymQuest/                        ← The App
├── Models/                        SwiftData @Model layer
├── Views/                         25+ screens & components
├── Services/                      18 services (AI, Auth, PR, Strava…)
└── Features/                      Feature modules

Tests/                           ← Quality Engineering
├── Unit/                          Models · Services · ViewModels
├── Integration/                   Network stubs · SwiftData lifecycle
├── Snapshot/                      Visual regression (iPhone 15 + SE)
├── UI/                            Smoke tests · Accessibility audits
├── Performance/                   Benchmarks · Memory leak detection
└── Fixtures/                      JSON response stubs
```

---

**Workout Engine** · Live set tracking, auto PR detection, rest timers with haptics, RPE, ghost data, milestone celebrations

**AI Coach** · Context aware coaching via OpenAI, Groq, Ollama, or offline demo mode

**Gamification** · 11 XP levels, quests, squad challenges, forgiveness tokens

**Social** · Workout cards, coach takeaways, media posts, fist bumps, pod accountability

**Design System** · Glassmorphism (`GlassCard`, `StatPill`), gradient type, neon buttons

---

**Tests** · 50+ methods across unit, integration, snapshot, UI, and performance targets

**CI/CD** · GitHub Actions · GitLab · Buildkite · CircleCI · Xcode Cloud · Bitrise · Fastlane

**Security** · CodeQL · Dependabot · Semgrep · Trivy · Syft SBOM

---

```bash
brew install xcodegen && cd GymQuest-iOS && xcodegen generate && open GymQuest.xcodeproj
```

AI setup is optional. The app runs in Demo Mode without API keys.

---

**Benjamin Hilderman** · [@BenHilderman](https://github.com/BenHilderman)
