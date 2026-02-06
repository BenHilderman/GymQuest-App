#!/bin/bash
# ─────────────────────────────────────────────────────────────────────
# Xcode Cloud — Post Xcodebuild Script
# ─────────────────────────────────────────────────────────────────────
# Runs after xcodebuild completes (even on failure).
# Extracts coverage, logs test summary, and reports build status.
# ─────────────────────────────────────────────────────────────────────
# Note: Do NOT use `set -e` here — this script should always run fully
# even if individual commands fail.

echo "╔══════════════════════════════════════════╗"
echo "║  GymQuest — Post Xcodebuild              ║"
echo "╚══════════════════════════════════════════╝"

# ── Navigate to project directory ────────────────────────────────────

PROJECT_DIR="$CI_PRIMARY_REPOSITORY_PATH/GymQuest-iOS"
cd "$PROJECT_DIR" 2>/dev/null || cd "$(dirname "$0")/.."

# ── Build Status ─────────────────────────────────────────────────────

EXIT_CODE="${CI_XCODEBUILD_EXIT_CODE:-unknown}"
echo "--- Build Status"
echo "Exit code: $EXIT_CODE"

if [ "$EXIT_CODE" = "0" ]; then
    echo "Result: SUCCESS"
elif [ "$EXIT_CODE" = "unknown" ]; then
    echo "Result: UNKNOWN (CI_XCODEBUILD_EXIT_CODE not set)"
else
    echo "Result: FAILURE (exit code $EXIT_CODE)"
fi

# ── Extract Code Coverage ────────────────────────────────────────────

echo "--- Code Coverage"
RESULT_BUNDLE=$(find "$CI_RESULT_BUNDLE_PATH" -name "*.xcresult" 2>/dev/null | head -1)
if [ -z "$RESULT_BUNDLE" ]; then
    RESULT_BUNDLE="$CI_RESULT_BUNDLE_PATH"
fi

if [ -d "$RESULT_BUNDLE" ]; then
    xcrun xccov view --report "$RESULT_BUNDLE" --json 2>/dev/null | \
        python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for target in data.get('targets', []):
        name = target.get('name', '')
        if 'GymQuest' in name and 'Tests' not in name:
            pct = target.get('lineCoverage', 0) * 100
            files = target.get('files', [])
            covered = sum(1 for f in files if f.get('lineCoverage', 0) > 0)
            print(f'Target:   {name}')
            print(f'Coverage: {pct:.1f}%')
            print(f'Files:    {covered}/{len(files)} with coverage')
            break
except Exception as e:
    print(f'Coverage parsing error: {e}')
" || echo "Coverage extraction unavailable"
else
    echo "No .xcresult bundle found at $RESULT_BUNDLE"
fi

# ── Test Summary ─────────────────────────────────────────────────────

echo "--- Test Summary"
if [ -d "$RESULT_BUNDLE" ]; then
    xcrun xcresulttool get --format json --path "$RESULT_BUNDLE" 2>/dev/null | \
        python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    metrics = data.get('metrics', {})
    tests = metrics.get('testsCount', {}).get('_value', '?')
    failures = metrics.get('testsFailedCount', {}).get('_value', '0')
    print(f'Tests run:    {tests}')
    print(f'Failures:     {failures}')
except Exception as e:
    print(f'Summary parsing error: {e}')
" || echo "Test summary extraction unavailable"
else
    echo "No result bundle available for test summary"
fi

# ── Timing ───────────────────────────────────────────────────────────

echo "--- Build Info"
echo "Workflow:  ${CI_WORKFLOW:-unknown}"
echo "Branch:    ${CI_BRANCH:-unknown}"
echo "Commit:    ${CI_COMMIT:-unknown}"
echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"

echo "--- Post Xcodebuild complete"
