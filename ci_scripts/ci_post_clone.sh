#!/bin/bash
# ─────────────────────────────────────────────────────────────────────
# Xcode Cloud — Post Clone Script
# ─────────────────────────────────────────────────────────────────────
# Runs after Xcode Cloud clones the repository.
# Installs XcodeGen and generates the .xcodeproj from project.yml.
#
# Note: Xcode Cloud does NOT have sudo access. All installs must be
# user-level (Homebrew handles this automatically).
# ─────────────────────────────────────────────────────────────────────
set -e

echo "╔══════════════════════════════════════════╗"
echo "║  GymQuest — Xcode Cloud Post Clone       ║"
echo "╚══════════════════════════════════════════╝"

# ── Environment Info ─────────────────────────────────────────────────

echo "--- Environment"
echo "Branch:  ${CI_BRANCH:-unknown}"
echo "Commit:  ${CI_COMMIT:-unknown}"
echo "Tag:     ${CI_TAG:-none}"
echo "Xcode:   $(xcodebuild -version | head -1)"
echo "macOS:   $(sw_vers -productVersion)"

# ── Install XcodeGen ─────────────────────────────────────────────────

echo "--- Installing XcodeGen"
if ! command -v xcodegen &> /dev/null; then
    brew install xcodegen
    echo "XcodeGen installed: $(xcodegen --version)"
else
    echo "XcodeGen already available: $(xcodegen --version)"
fi

# ── Generate Xcode Project ───────────────────────────────────────────

echo "--- Generating Xcode Project from project.yml"
cd "$CI_PRIMARY_REPOSITORY_PATH/GymQuest-iOS" || cd "$(dirname "$0")/.."
xcodegen generate

if [ -d "GymQuest.xcodeproj" ]; then
    echo "Project generated successfully"
    echo "Targets:"
    xcodebuild -project GymQuest.xcodeproj -list 2>/dev/null | grep -A 20 "Targets:" || true
else
    echo "ERROR: Project generation failed — GymQuest.xcodeproj not found"
    exit 1
fi

echo "--- Post Clone complete"
