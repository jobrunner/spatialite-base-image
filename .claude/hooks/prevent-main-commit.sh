#!/bin/bash
#
# PreToolUse hook: Prevents git commits directly on main/master branch
# and ensures VERSION/CHANGELOG are updated before PR creation.
#

# Read JSON input from stdin
INPUT=$(cat)

# Extract the command from tool_input
COMMAND=$(echo "$INPUT" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*: *"//' | sed 's/"$//')

# Skip if no command found
[ -z "$COMMAND" ] && exit 0

# Get current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

# Check for git commit on main/master
if echo "$COMMAND" | grep -qE "git commit"; then
    if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
        echo '{"decision":"block","reason":"Direct commits to main/master branch are not allowed. Please create a feature branch first using: git checkout -b <branch-name>"}'
        exit 0
    fi
fi

# Check for gh pr create - ensure VERSION and CHANGELOG are updated
if echo "$COMMAND" | grep -qE "gh pr create"; then
    # Check if VERSION or CHANGELOG have been modified in this branch
    VERSION_CHANGED=$(git diff origin/master...HEAD --name-only 2>/dev/null | grep -c "^VERSION$" || git diff origin/main...HEAD --name-only 2>/dev/null | grep -c "^VERSION$" || echo "0")
    CHANGELOG_CHANGED=$(git diff origin/master...HEAD --name-only 2>/dev/null | grep -c "^CHANGELOG.md$" || git diff origin/main...HEAD --name-only 2>/dev/null | grep -c "^CHANGELOG.md$" || echo "0")

    if [ "$VERSION_CHANGED" = "0" ] || [ "$CHANGELOG_CHANGED" = "0" ]; then
        MISSING=""
        [ "$VERSION_CHANGED" = "0" ] && MISSING="VERSION"
        [ "$CHANGELOG_CHANGED" = "0" ] && MISSING="${MISSING:+$MISSING and }CHANGELOG.md"
        echo "{\"decision\":\"block\",\"reason\":\"Cannot create PR: $MISSING must be updated before creating a pull request. Please update the version number and add a changelog entry.\"}"
        exit 0
    fi
fi

exit 0
