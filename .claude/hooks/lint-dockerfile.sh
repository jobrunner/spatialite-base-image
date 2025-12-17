#!/bin/bash
#
# PostToolUse hook: Runs linter and security checks on Dockerfiles
#

set -o pipefail

# Read JSON input from stdin
INPUT=$(cat)

# Extract the file path from tool_input
FILE_PATH=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*: *"//' | sed 's/"$//')

# Skip if no file path or not a Dockerfile
[ -z "$FILE_PATH" ] && exit 0
[[ "$(basename "$FILE_PATH")" != Dockerfile* ]] && exit 0

# Check if file exists
[ ! -f "$FILE_PATH" ] && exit 0

ERRORS=""
WARNINGS=""

# --- Hadolint (Dockerfile Linter) ---
if command -v hadolint &> /dev/null; then
    HADOLINT_OUTPUT=$(hadolint "$FILE_PATH" 2>&1)
    HADOLINT_EXIT=$?
    if [ $HADOLINT_EXIT -ne 0 ]; then
        ERRORS="${ERRORS}[Hadolint] Issues found:\n${HADOLINT_OUTPUT}\n\n"
    fi
elif command -v docker &> /dev/null; then
    # Fallback: use hadolint via Docker
    HADOLINT_OUTPUT=$(docker run --rm -i hadolint/hadolint < "$FILE_PATH" 2>&1)
    HADOLINT_EXIT=$?
    if [ $HADOLINT_EXIT -ne 0 ]; then
        ERRORS="${ERRORS}[Hadolint] Issues found:\n${HADOLINT_OUTPUT}\n\n"
    fi
else
    WARNINGS="${WARNINGS}[Hadolint] Not installed. Install with: brew install hadolint\n"
fi

# --- Trivy (Security Scanner) ---
if command -v trivy &> /dev/null; then
    TRIVY_OUTPUT=$(trivy config --severity HIGH,CRITICAL --exit-code 1 "$FILE_PATH" 2>&1)
    TRIVY_EXIT=$?
    if [ $TRIVY_EXIT -ne 0 ] && [ -n "$TRIVY_OUTPUT" ]; then
        # Filter out info lines, keep only findings
        TRIVY_FINDINGS=$(echo "$TRIVY_OUTPUT" | grep -E "(HIGH|CRITICAL|AVD-)" || true)
        if [ -n "$TRIVY_FINDINGS" ]; then
            ERRORS="${ERRORS}[Trivy Security] Issues found:\n${TRIVY_FINDINGS}\n\n"
        fi
    fi
else
    WARNINGS="${WARNINGS}[Trivy] Not installed. Install with: brew install trivy\n"
fi

# Output results
if [ -n "$ERRORS" ]; then
    # Exit code 2 blocks the action and shows stderr
    echo -e "$ERRORS" >&2
    if [ -n "$WARNINGS" ]; then
        echo -e "$WARNINGS" >&2
    fi
    exit 2
elif [ -n "$WARNINGS" ]; then
    # Non-blocking warning
    echo "{\"hookSpecificOutput\":{\"additionalContext\":\"$(echo -e "$WARNINGS" | tr '\n' ' ')\"}}"
    exit 0
else
    # All checks passed
    echo '{"hookSpecificOutput":{"additionalContext":"[Dockerfile] Linting and security checks passed."}}'
    exit 0
fi
