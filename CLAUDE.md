# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Multi-architecture Docker images (amd64/arm64) providing GDAL, SQLite, SpatiaLite, GEOS, and librttopo on Ubuntu and Alpine base images. Images are published to GitHub Container Registry (ghcr.io).

## Image Types

- **Runtime images** (`alpine`, `ubuntu`): Minimal, for production
- **Dev images** (`alpine-dev`, `ubuntu-dev`): Include headers, gcc, pkg-config for CGO builds

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

- `Dockerfile.alpine` - Alpine 3.20 runtime image
- `Dockerfile.alpine-dev` - Alpine 3.20 dev image (with headers, gcc, pkg-config)
- `Dockerfile.ubuntu` - Ubuntu 24.04 runtime image
- `Dockerfile.ubuntu-dev` - Ubuntu 24.04 dev image (with headers, gcc, pkg-config)
- `.github/workflows/ci.yml` - CI pipeline (build → test → tag on main)
- `.github/workflows/release.yml` - Release pipeline (triggered by version tags)
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

## Registry

`ghcr.io/jobrunner/spatialite-base-image`
