# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Multi-architecture Docker images (amd64/arm64) providing SQLite, SpatiaLite, GEOS, PROJ, and librttopo on Ubuntu and Alpine base images. The dev images additionally ship GDAL and a Go toolchain. Images are published to GitHub Container Registry (ghcr.io).

## Image Types

- **Runtime images** (`alpine`, `ubuntu`): Slim, for production - SpatiaLite stack only, **no GDAL/Python, no libcurl**. PROJ and libspatialite are compiled from checksum-verified sources in a multi-stage builder (PROJ with `ENABLE_CURL=OFF`, so no `PROJ_NETWORK` grid downloads). Their versions are pinned as build ARGs (`PROJ_VERSION`, `SPATIALITE_VERSION`) in the runtime Dockerfiles - package scanners do not see these self-built libraries. Renovate bumps `PROJ_VERSION` (and recomputes `PROJ_SHA256`); `SPATIALITE_VERSION` has no release feed and must be bumped manually.
- **Dev images** (`alpine-dev`, `ubuntu-dev`): Full toolchain - GDAL, distro PROJ (with network support), headers, gcc, pkg-config, Go for CGO builds

## Build Commands

```bash
# Build runtime images locally
docker build -f Dockerfile.alpine -t spatialite:alpine .
docker build -f Dockerfile.ubuntu -t spatialite:ubuntu .

# Build dev images locally
docker build -f Dockerfile.alpine-dev -t spatialite:alpine-dev .
docker build -f Dockerfile.ubuntu-dev -t spatialite:ubuntu-dev .

# Build multi-arch (requires buildx)
docker buildx build --platform linux/amd64,linux/arm64 -f Dockerfile.alpine -t spatialite:alpine .
```

## Testing

```bash
# Test runtime images
docker run --rm -v $(pwd)/tests:/tests spatialite:alpine /tests/test-image.sh
docker run --rm -v $(pwd)/tests:/tests spatialite:ubuntu /tests/test-image.sh

# Test dev images (includes compilation tests)
docker run --rm -v $(pwd)/tests:/tests spatialite:alpine-dev sh -c \
  "/tests/test-image.sh && /tests/test-dev-image.sh"
```

## File Structure

- `Dockerfile.alpine` - Alpine 3.24 slim runtime image (no GDAL)
- `Dockerfile.alpine-dev` - Alpine 3.24 dev image (GDAL, headers, gcc, pkg-config, Go)
- `Dockerfile.ubuntu` - Ubuntu 26.04 slim runtime image (no GDAL)
- `Dockerfile.ubuntu-dev` - Ubuntu 26.04 dev image (GDAL, headers, gcc, pkg-config, Go)
- `.github/workflows/ci.yml` - CI pipeline: PRs run lint (hadolint + trivy config) → build → test → Trivy gate; merges run lint → build → test (amd64 + arm64) → scan → promote → tag/release
- `.github/workflows/build-images.yml` - Reusable workflow (build → merge → test → scan → promote): builds each arch natively (no QEMU) under `<flavor>-ci-<arch>` tags, merges them into the `<flavor>-ci` multi-arch candidate, tests on native amd64/arm64 runners, scans with Trivy, then promotes the tested manifests to final tags via `docker buildx imagetools create`
- `.github/workflows/security-scan.yml` - Trivy scan of published images every 6 hours (SARIF upload to GitHub Code Scanning); fixable findings of any severity (release gate: LOW+ for all images) open/refresh one auto-merging security release PR (VERSION bump + CHANGELOG listing the CVEs) as the GitHub App
- `.github/workflows/renovate.yml` - Hourly self-hosted Renovate run as the GitHub App (config: `.github/renovate.json`)
- `.github/scripts/bump-release.sh` - Turns a branch into a release (VERSION, CHANGELOG entry, README tag examples; `--level patch|minor|major`, default patch), always derived from the base ref so re-runs never double-bump
- `.github/scripts/renovate-post-upgrade.sh` - Renovate post-upgrade task: recomputes `PROJ_SHA256` / `GO_SHA256_*`, then calls `bump-release.sh`
- `.github/workflows/release.yml` - Manual/emergency release (workflow_dispatch) of a not yet released VERSION; runs the same reusable pipeline as CI
- `tests/test-image.sh` - Runtime tests (library loading, spatial operations)
- `tests/test-dev-image.sh` - Dev tests (headers, pkg-config, compilation)
- `VERSION` - Current version number (used for auto-tagging)
- `CHANGELOG.md` - Release notes

## Environment Variables

All images have these pre-configured:
- `SPATIALITE_SECURITY=relaxed` - Allows SpatiaLite to load external data
- `SQLITE_ENABLE_LOAD_EXTENSION=1` - Enables SQLite extension loading
- `LD_LIBRARY_PATH=/usr/lib:/usr/local/lib` - Library search paths

## Versioning

Images use semantic versioning (X.Y.Z). Tags created:
- `alpine-1.0.0`, `alpine-1.0`, `alpine-1`, `alpine-latest`
- `ubuntu-1.0.0`, `ubuntu-1.0`, `ubuntu-1`, `ubuntu-latest`
- `alpine-dev-1.0.0`, `alpine-dev-1.0`, `alpine-dev-1`, `alpine-dev-latest`
- `ubuntu-dev-1.0.0`, `ubuntu-dev-1.0`, `ubuntu-dev-1`, `ubuntu-dev-latest`
- `1.0.0`, `1.0`, `1`, `latest` (Alpine default)
- `dev-1.0.0`, `dev-1.0`, `dev-1`, `dev` (Alpine dev default)

## Development Workflow

1. Create feature branch from main
2. Make changes, then bump `VERSION`, `CHANGELOG.md` and the README examples in one go:
   `.github/scripts/bump-release.sh --level minor origin/master Added entries.md`
   (`entries.md` holds the Markdown list items; level and section as fits the change).
   Write release notes only into the entries file - VERSION and CHANGELOG are regenerated from
   `origin/master`, so after master moved: merge it, `git checkout origin/master -- VERSION CHANGELOG.md`, re-run the script
3. Push and create Pull Request
4. CI runs: build → test
5. After merge to main: auto-tag → release workflow → GitHub Release

**Important:** Direct commits to main are not allowed. Use Pull Requests.

## Automated Updates and Releases

Every merge to master is a release (no in-place rebuilds: every image change gets its own version), so every automated PR carries its own VERSION bump and CHANGELOG entry:

- **Renovate** (hourly, `.github/renovate.json`): base images are pinned by digest (`alpine:3.24@sha256:...`). A rebuilt base image (digest update) or a Go patch release becomes a PR that auto-merges once CI is green. Distro/Go minor+major updates, PROJ and GitHub Actions (weekly group) wait for review. Ubuntu only moves between LTS releases.
- **Security scan** (every 6h): fixable findings above the release gate in the published images open a `security-release` PR (branch `security/release`, rebuilt against master on every scan, skipped while a master build runs) with auto-merge. CI rebuilds (`PACKAGE_REFRESH` busts the apk/apt layers) and the Trivy gate proves the fix. If the gate stays red, the fix needs a version bump (e.g. Go) and a human.
- Both authenticate as a GitHub App (`vars.BOT_APP_CLIENT_ID`, `secrets.BOT_APP_PRIVATE_KEY`) - PRs created with `GITHUB_TOKEN` would not trigger CI.
- Go is installed from a checksum-verified tarball (`GO_VERSION`, `GO_SHA256_AMD64`, `GO_SHA256_ARM64` in the dev Dockerfiles).

## Security Hardening

All images include security hardening measures:

- **Non-root user**: Images run as `spatialite` user (UID 10001) by default
- **No SUID/SGID**: All SUID/SGID bits are removed from binaries
- **Minimal attack surface**: Only required packages are installed

### Running as root (dev images)

Dev images default to non-root but can be overridden for development tasks:

```bash
docker run --user root -it spatialite:alpine-dev sh
```

### Additional runtime security

For production deployments, consider these docker run flags:

```bash
docker run --rm \
  --read-only \
  --security-opt=no-new-privileges:true \
  --cap-drop=ALL \
  -v $(pwd)/data:/data \
  spatialite:alpine
```

## Registry

`ghcr.io/jobrunner/spatialite-base-image`
