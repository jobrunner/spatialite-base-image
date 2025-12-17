#!/bin/bash
#
# PostToolUse hook: Reminds to update CHANGELOG.md and README.md
# when relevant files are modified.
#

# Read JSON input from stdin
INPUT=$(cat)

# Extract the file path from tool_input
FILE_PATH=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*: *"//' | sed 's/"$//')

# Skip if no file path found
[ -z "$FILE_PATH" ] && exit 0

# Get just the filename
FILENAME=$(basename "$FILE_PATH")

# Define patterns that should trigger documentation reminders
case "$FILENAME" in
    Dockerfile*)
        echo '{"hookSpecificOutput":{"additionalContext":"[Doc Reminder] Dockerfile changed - consider updating CHANGELOG.md and README.md if this affects usage or features."}}'
        ;;
    VERSION)
        echo '{"hookSpecificOutput":{"additionalContext":"[Doc Reminder] VERSION changed - CHANGELOG.md must be updated with release notes for this version."}}'
        ;;
    *.yml|*.yaml)
        if [[ "$FILE_PATH" == *".github/workflows"* ]]; then
            echo '{"hookSpecificOutput":{"additionalContext":"[Doc Reminder] CI/CD workflow changed - consider updating CHANGELOG.md and README.md if this affects the release process."}}'
        fi
        ;;
    test-*.sh)
        echo '{"hookSpecificOutput":{"additionalContext":"[Doc Reminder] Test script changed - consider updating CHANGELOG.md if this fixes bugs or adds test coverage."}}'
        ;;
esac

exit 0
