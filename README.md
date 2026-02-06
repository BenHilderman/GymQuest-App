# GymQuest

A gamified fitness app for iOS built with SwiftUI, SwiftData, and multi-provider AI coaching. Combines real-time workout tracking, social features, and RPG-style progression.

## App Highlights

**Active Workout Engine** — Real-time set tracking with live PR detection, smart rest timers with haptic feedback, RPE capture, milestone celebrations (25/50/75%), and ghost data from previous sessions for progressive overload guidance.

**AI Coach** — Context-aware fitness coaching that packages workout history, streak data, weekly volume, and deload signals into structured JSON for personalized advice. Supports OpenAI (GPT-4o-mini), Groq (Llama 3.3 70B), Ollama (local), and a rule-based demo mode that works offline.

**PR Detection System** — Detects four PR types in real-time: weight PRs, rep PRs, volume PRs, and estimated 1RM PRs (Epley formula). Includes streak milestone detection and shareable PR moments.

**Gamification** — XP system with 11 levels (Beginner through Legend), XP bonuses for high RPE and PRs, quest system with categories and difficulty tiers, squad challenges, and forgiveness tokens.

**Social Feed** — Workout cards with coach takeaways, photo/video posts, activity detection, workout sharing ("Follow this workout"), fist bumps, and pod-based accountability groups.

**Design System** — Custom glassmorphism components (`GlassCard`, `StatPill`, `AnimatedProgressBar`), gradient typography, neon button styles, and a dark-first color palette.

### Tech Stack

SwiftUI, SwiftData, Swift 5.9, iOS 17+, XcodeGen, Google Sign-In, CryptoKit, AVKit

---

## Test Suite & CI/CD

The project includes a full quality gate system with 50+ test methods, 6 CI/CD platform configurations, and a DevSecOps security layer.

### Test Architecture

| Target | Contents | Purpose |
|--------|----------|---------|
| **GymQuestTests** | Unit, integration, snapshot tests | Core quality gate |
| **GymQuestUITests** | UI smoke tests, accessibility audits | User-facing validation |
| **GymQuestPerformanceTests** | Benchmark baselines, memory leak detection | Performance regression |

**Unit Tests** — Model computed properties (totalVolume, xpValue, estimated1RM, levelTitle), service logic (streak calculation, deload detection, weekly volume aggregation, SHA256 hashing, CRUD auth flow), and ViewModel state (progress percentage, milestone thresholds, time/volume formatting).

**Integration Tests** — Network stubbing via `MockURLProtocol` (intercepts `URLSession.shared` without DI changes) for OpenAI/Groq API responses, SwiftData full CRUD lifecycle with cascade delete verification, and end-to-end PR detection across workout history.

**Snapshot Tests** — Visual regression testing with [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) for login screen and design system components across iPhone 15 and iPhone SE device configs.

**Performance Tests** — `measure {}` baselines for fetching 1000 workouts, streak calculation on 365 days, PR detection across 100 workouts, and ViewModel deallocation after `cleanup()`.

### CI/CD Platforms

| Platform | Config | Approach |
|----------|--------|----------|
| **GitHub Actions** | `.github/workflows/pr-quality-gate.yml` | PR gate with device matrix (iPhone 16 + SE), coverage extraction, UI smoke after unit pass |
| **GitLab CI/CD** | `.gitlab-ci.yml` | 4-stage pipeline (test, ui_test, performance, security), macOS runner, SPM caching |
| **Buildkite** | `.buildkite/pipeline.yml` | Step-based with `wait` barriers, parallel device testing, macOS agent targeting |
| **CircleCI** | `.circleci/config.yml` | Apple Silicon executor, reusable commands, `save_cache`/`restore_cache`, workflow orchestration |
| **Xcode Cloud** | `ci_scripts/` | Post-clone xcodegen generation, pre-build validation, post-build coverage extraction |
| **Bitrise** | `bitrise.yml` | Mobile-first with `xcode-test@4` steps, trigger maps for PRs and pushes, 3 workflows |
| **Fastlane** | `fastlane/Fastfile` | 6 lanes: `pr_tests`, `ui_smoke`, `full_matrix`, `performance`, `snapshots`, `record_snapshots` |

### DevSecOps

| Tool | Config | What it does |
|------|--------|--------------|
| **CodeQL** | `codeql-analysis.yml` | Semantic Swift code scanning with manual build mode |
| **Dependabot** | `dependabot.yml` | Automated PRs for SPM deps (weekly) and Actions versions (monthly) |
| **Semgrep** | `semgrep-sast.yml` | SAST with `security-audit` and `swift` rulesets, SARIF to Security tab |
| **Trivy** | `trivy-scan.yml` | Filesystem vulnerability scan, IaC misconfiguration check, secret detection |
| **Syft SBOM** | `sbom-generation.yml` | Dual-format SBOM (SPDX + CycloneDX), release asset attachment, dependency snapshots |
| **OIDC** | `oidc-deploy-template.yml` | Reusable workflow for zero-secrets cloud auth via GitHub Actions OpenID Connect |

### Running Tests Locally

```bash
cd GymQuest-iOS
xcodegen generate
xcodebuild test -scheme GymQuestTests -destination 'platform=iOS Simulator,name=iPhone 16'
xcodebuild test -scheme GymQuestUITests -destination 'platform=iOS Simulator,name=iPhone 16'
xcodebuild test -scheme GymQuestPerformanceTests -destination 'platform=iOS Simulator,name=iPhone 16'
```

---

## Requirements

- iOS 17.0+ / macOS 14.0+
- Xcode 15.0+
- XcodeGen (`brew install xcodegen`)

### AI Setup (Optional)

The app works in Demo Mode without any API keys. For real AI responses, go to Profile, select a provider, and enter your API key.

### Python Backend (Optional)

An optional backend provides ACWR injury prevention, RAG exercise knowledge, and LangChain prompt engineering. See [`backend/README.md`](backend/README.md).

## Author

**Benjamin Hilderman** — [@BenHilderman](https://github.com/BenHilderman)
