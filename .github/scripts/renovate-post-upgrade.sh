#!/usr/bin/env bash
#
# Renovate post-upgrade task (see renovate.json, executionMode "branch").
# Runs inside the Renovate container after Renovate has rewritten the
# dependency versions in the working tree, before the commit is made:
#
#   1. Recompute the checksums Renovate cannot update itself
#      (PROJ_SHA256 when PROJ_VERSION changed, GO_SHA256_* when GO_VERSION
#      changed) - the Dockerfiles verify every source download.
#   2. Turn the update into a patch release: VERSION, CHANGELOG.md and the
#      README tag examples (bump-release.sh). The changelog lines come from
#      Renovate's dataFileTemplate ($RENOVATE_POST_UPGRADE_COMMAND_DATA_FILE).
#
# Usage: renovate-post-upgrade.sh <base-branch>

set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <base-branch>" >&2
    exit 2
fi

BASE_BRANCH=$1
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

BASE_REF=""
for ref in "origin/${BASE_BRANCH}" "${BASE_BRANCH}"; do
    if git rev-parse --verify --quiet "${ref}^{commit}" > /dev/null; then
        BASE_REF=$ref
        break
    fi
done
if [ -z "$BASE_REF" ]; then
    echo "Base branch '${BASE_BRANCH}' not found in the local clone" >&2
    exit 1
fi

# Value of "ARG <name>=<value>" in a file (working tree or "<ref>:<file>")
arg_value() {
    sed -n -E "s/^ARG $1=([^[:space:]]+).*/\1/p" | head -n 1
}

sha256_of_url() {
    curl -fsSL "$1" | sha256sum | cut -d' ' -f1
}

set_arg() {
    local name=$1 value=$2
    shift 2
    perl -pi -e "s/^ARG ${name}=\\S+/ARG ${name}=${value}/" "$@"
}

# --- 1. checksums --------------------------------------------------------------

PROJ_VERSION=$(arg_value PROJ_VERSION < Dockerfile.alpine)
BASE_PROJ_VERSION=$(git show "${BASE_REF}:Dockerfile.alpine" | arg_value PROJ_VERSION)
if [ "$PROJ_VERSION" != "$BASE_PROJ_VERSION" ]; then
    PROJ_SHA256=$(sha256_of_url "https://github.com/OSGeo/PROJ/releases/download/${PROJ_VERSION}/proj-${PROJ_VERSION}.tar.gz")
    set_arg PROJ_SHA256 "$PROJ_SHA256" Dockerfile.alpine Dockerfile.ubuntu
    echo "PROJ ${BASE_PROJ_VERSION} -> ${PROJ_VERSION}: sha256 ${PROJ_SHA256}"
fi

GO_VERSION=$(arg_value GO_VERSION < Dockerfile.alpine-dev)
BASE_GO_VERSION=$(git show "${BASE_REF}:Dockerfile.alpine-dev" | arg_value GO_VERSION)
if [ "$GO_VERSION" != "$BASE_GO_VERSION" ]; then
    for arch in amd64 arm64; do
        # go.dev publishes the official checksum next to each tarball
        sum=$(curl -fsSL "https://dl.google.com/go/go${GO_VERSION}.linux-${arch}.tar.gz.sha256" | tr -d '[:space:]')
        if ! [[ $sum =~ ^[0-9a-f]{64}$ ]]; then
            echo "No valid checksum for go${GO_VERSION}.linux-${arch}" >&2
            exit 1
        fi
        set_arg "GO_SHA256_${arch^^}" "$sum" Dockerfile.alpine-dev Dockerfile.ubuntu-dev
        echo "Go ${BASE_GO_VERSION} -> ${GO_VERSION} (${arch}): sha256 ${sum}"
    done
fi

# --- 2. release ------------------------------------------------------------------

ENTRIES=$(mktemp)
trap 'rm -f "$ENTRIES"' EXIT
# The same dependency can appear in several Dockerfiles/stages - list it once
grep -v '^[[:space:]]*$' "${RENOVATE_POST_UPGRADE_COMMAND_DATA_FILE:?not set}" | sort -u > "$ENTRIES"

"${SCRIPT_DIR}/bump-release.sh" "$BASE_REF" "Changed" "$ENTRIES"
