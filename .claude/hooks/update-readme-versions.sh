#!/bin/bash
#
# PostToolUse hook: Updates version numbers in README.md examples
# when VERSION file is modified.
#

set -e

# Read JSON input from stdin
INPUT=$(cat)

# Extract the file path from tool_input
FILE_PATH=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*: *"//' | sed 's/"$//')

# Skip if no file path or not VERSION file
[ -z "$FILE_PATH" ] && exit 0
[[ "$(basename "$FILE_PATH")" != "VERSION" ]] && exit 0

# Get the project directory
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(dirname "$FILE_PATH")}"
README="$PROJECT_DIR/README.md"
VERSION_FILE="$PROJECT_DIR/VERSION"

# Check files exist
[ ! -f "$README" ] && exit 0
[ ! -f "$VERSION_FILE" ] && exit 0

# Read the new version
NEW_VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')

# Validate it's a proper semver
if ! echo "$NEW_VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    exit 0
fi

# Update version patterns in README.md
# Match patterns like: X.Y.Z where X, Y, Z are numbers (but not in URLs ending with /vX.Y.Z)
# Update examples like: alpine-1.0.0, ubuntu-dev-1.0.0, :1.0.0, etc.

# Patterns to update (image tags in examples)
sed -i.bak -E "s/(spatialite-base-image:)(alpine|ubuntu|alpine-dev|ubuntu-dev|dev)-[0-9]+\.[0-9]+\.[0-9]+/\1\2-${NEW_VERSION}/g" "$README"
sed -i.bak -E "s/(spatialite-base-image:)[0-9]+\.[0-9]+\.[0-9]+([^.])/\1${NEW_VERSION}\2/g" "$README"

# Clean up backup file
rm -f "$README.bak"

echo "{\"hookSpecificOutput\":{\"additionalContext\":\"[Version Hook] Updated README.md examples to version ${NEW_VERSION}\"}}"
exit 0
