#!/bin/bash
# ─────────────────────────────────────────────────────────────────────
# Xcode Cloud — Pre Xcodebuild Script
# ─────────────────────────────────────────────────────────────────────
# Runs before xcodebuild starts. Verifies project state and optionally
# sets the build number from CI environment variables.
# ─────────────────────────────────────────────────────────────────────
set -e

echo "╔══════════════════════════════════════════╗"
echo "║  GymQuest — Pre Xcodebuild               ║"
echo "╚══════════════════════════════════════════╝"

# ── Navigate to project directory ────────────────────────────────────

PROJECT_DIR="$CI_PRIMARY_REPOSITORY_PATH/GymQuest-iOS"
cd "$PROJECT_DIR" 2>/dev/null || cd "$(dirname "$0")/.."

# ── Verify Project Structure ─────────────────────────────────────────

echo "--- Verifying project structure"
if [ ! -d "GymQuest.xcodeproj" ]; then
    echo "WARNING: GymQuest.xcodeproj not found. Attempting to generate..."
    which xcodegen && xcodegen generate || echo "ERROR: xcodegen not available"
fi

if [ -d "GymQuest.xcodeproj" ]; then
    echo "Project file: OK"
else
    echo "ERROR: Cannot find or generate GymQuest.xcodeproj"
    exit 1
fi

# ── Log Build Configuration ──────────────────────────────────────────

echo "--- Build Configuration"
echo "Workflow:     ${CI_WORKFLOW:-unknown}"
echo "Build Number: ${CI_BUILD_NUMBER:-unknown}"
echo "Build ID:     ${CI_BUILD_ID:-unknown}"
echo "Xcode Action: ${CI_XCODEBUILD_ACTION:-unknown}"

# ── Set Build Number ─────────────────────────────────────────────────

if [ -n "$CI_BUILD_NUMBER" ]; then
    echo "--- Setting build number to $CI_BUILD_NUMBER"
    # Update Info.plist build number if the plist exists
    PLIST_PATH="GymQuest/Info.plist"
    if [ -f "$PLIST_PATH" ]; then
        /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $CI_BUILD_NUMBER" "$PLIST_PATH" 2>/dev/null || true
        echo "Build number set in Info.plist"
    fi
fi

# ── Check SPM Resolution ────────────────────────────────────────────

echo "--- Checking SPM packages"
if [ -f "GymQuest.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved" ]; then
    PACKAGE_COUNT=$(grep -c '"identity"' "GymQuest.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved" 2>/dev/null || echo "0")
    echo "Resolved packages: $PACKAGE_COUNT"
else
    echo "Package.resolved not found — SPM will resolve during build"
fi

echo "--- Pre Xcodebuild complete"
