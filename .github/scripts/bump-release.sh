#!/usr/bin/env bash
#
# Prepare a release on top of a base ref:
#   - VERSION      = VERSION of <base-ref>, bumped by <level> (default: patch)
#   - CHANGELOG.md = CHANGELOG of <base-ref> with a new entry prepended
#   - README.md    = README of <base-ref> with the image tag examples bumped
#
# Everything is derived from <base-ref>, never from the working tree, so
# running it again on the same branch (e.g. when Renovate rebases or updates
# its branch) yields the same result instead of bumping twice.
#
# Used by the Renovate post-upgrade task, the security scan workflow and for
# manual PRs (e.g. `--level minor origin/master Added entries.md`).
#
# Usage: bump-release.sh [--level patch|minor|major] <base-ref> <changelog-section> <entries-file>
#   <entries-file> contains the Markdown list items for the new entry.

set -euo pipefail

LEVEL="patch"
if [ "${1:-}" = "--level" ]; then
    LEVEL=${2:-}
    shift 2 || true
fi

if [ "$#" -ne 3 ] || ! [[ $LEVEL =~ ^(patch|minor|major)$ ]]; then
    echo "Usage: $0 [--level patch|minor|major] <base-ref> <changelog-section> <entries-file>" >&2
    exit 2
fi

BASE_REF=$1
SECTION=$2
ENTRIES_FILE=$3

if [ ! -s "$ENTRIES_FILE" ]; then
    echo "::error::Changelog entries file '$ENTRIES_FILE' is empty" >&2
    exit 1
fi

BASE_VERSION=$(git show "${BASE_REF}:VERSION" | tr -d '[:space:]')
if ! [[ $BASE_VERSION =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    echo "::error::VERSION '$BASE_VERSION' on $BASE_REF is not X.Y.Z" >&2
    exit 1
fi
MAJOR=${BASH_REMATCH[1]} MINOR=${BASH_REMATCH[2]} PATCH=${BASH_REMATCH[3]}
case "$LEVEL" in
    patch) NEW_VERSION="${MAJOR}.${MINOR}.$((PATCH + 1))" ;;
    minor) NEW_VERSION="${MAJOR}.$((MINOR + 1)).0" ;;
    major) NEW_VERSION="$((MAJOR + 1)).0.0" ;;
esac

ENTRY=$(mktemp)
trap 'rm -f "$ENTRY"' EXIT
{
    printf '## [%s] - %s\n\n### %s\n\n' "$NEW_VERSION" "$(date -u +%F)" "$SECTION"
    cat "$ENTRIES_FILE"
    printf '\n'
} > "$ENTRY"

echo "$NEW_VERSION" > VERSION

# Insert the new entry before the first existing release entry
git show "${BASE_REF}:CHANGELOG.md" | awk -v entry="$ENTRY" '
    !done && /^## \[/ { while ((getline line < entry) > 0) print line; done = 1 }
    { print }
    END { if (!done) while ((getline line < entry) > 0) print line }
' > CHANGELOG.md

# Same tag patterns as .claude/hooks/update-readme-versions.sh
git show "${BASE_REF}:README.md" | perl -pe '
    s/(spatialite-base-image:)(alpine|ubuntu|alpine-dev|ubuntu-dev|dev)-\d+\.\d+\.\d+/${1}${2}-'"$NEW_VERSION"'/g;
    s/(spatialite-base-image:)\d+\.\d+\.\d+(?=[^.\d]|$)/${1}'"$NEW_VERSION"'/g;
' > README.md

echo "Prepared release $NEW_VERSION (base $BASE_REF: $BASE_VERSION)"
