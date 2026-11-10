#!/usr/bin/env bash
#
# Prepare a patch release on top of a base ref:
#   - VERSION      = VERSION of <base-ref> + 1 patch
#   - CHANGELOG.md = CHANGELOG of <base-ref> with a new entry prepended
#   - README.md    = README of <base-ref> with the image tag examples bumped
#
# Everything is derived from <base-ref>, never from the working tree, so
# running it again on the same branch (e.g. when Renovate rebases or updates
# its branch) yields the same result instead of bumping twice.
#
# Used by the Renovate post-upgrade task and by the security scan workflow.
#
# Usage: bump-release.sh <base-ref> <changelog-section> <entries-file>
#   <entries-file> contains the Markdown list items for the new entry.

set -euo pipefail

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <base-ref> <changelog-section> <entries-file>" >&2
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
NEW_VERSION="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.$((BASH_REMATCH[3] + 1))"

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
