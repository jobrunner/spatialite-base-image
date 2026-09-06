# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Multi-architecture Docker images (amd64/arm64) providing SQLite, SpatiaLite, GEOS, PROJ, and librttopo on Ubuntu and Alpine base images. The dev images additionally ship GDAL and a Go toolchain. Images are published to GitHub Container Registry (ghcr.io).

## Image Types

- **Runtime images** (`alpine`, `ubuntu`): Slim, for production - SpatiaLite stack only, **no GDAL/Python, no libcurl**. PROJ and libspatialite are compiled from checksum-verified sources in a multi-stage builder (PROJ with `ENABLE_CURL=OFF`, so no `PROJ_NETWORK` grid downloads). Their versions are pinned as build ARGs (`PROJ_VERSION`, `SPATIALITE_VERSION`) in the runtime Dockerfiles and must be bumped manually - package scanners do not see these self-built libraries.
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
- `.github/workflows/security-scan.yml` - Weekly Trivy scan of published images (SARIF upload to GitHub Code Scanning)
- `.github/workflows/rebuild.yml` - Monthly rebuild of the current release tags with fresh base image packages (same version, new digest)
- `.github/workflows/release.yml` - Manual/emergency release (workflow_dispatch); runs the same reusable pipeline as CI
- `.github/dependabot.yml` - Weekly updates for Docker base images and GitHub Actions (keeps SHA-pinned actions current)
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
2. Make changes, update `VERSION` and `CHANGELOG.md`
3. Push and create Pull Request
4. CI runs: build → test
5. After merge to main: auto-tag → release workflow → GitHub Release

**Important:** Direct commits to main are not allowed. Use Pull Requests.

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
