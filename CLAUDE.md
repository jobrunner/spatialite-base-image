# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Multi-architecture Docker images (amd64/arm64) providing GDAL, SQLite, SpatiaLite, GEOS, and librttopo on Ubuntu and Alpine base images. Images are published to GitLab Container Registry.

## Build Commands

```bash
# Build Ubuntu image locally
docker build -f Dockerfile.ubuntu -t spatialite:ubuntu .

# Build Alpine image locally
docker build -f Dockerfile.alpine -t spatialite:alpine .

# Build multi-arch (requires buildx)
docker buildx build --platform linux/amd64,linux/arm64 -f Dockerfile.ubuntu -t spatialite:ubuntu .
```

## Testing

```bash
# Run tests inside a container
docker run --rm -v $(pwd)/tests:/tests spatialite:ubuntu /tests/test-image.sh
docker run --rm -v $(pwd)/tests:/tests spatialite:alpine /tests/test-image.sh
```

## Architecture

- `Dockerfile.ubuntu` - Ubuntu 24.04 based image using apt packages
- `Dockerfile.alpine` - Alpine 3.20 based image using apk packages
- `.gitlab-ci.yml` - Multi-arch build pipeline with test stage
- `tests/test-image.sh` - Validates all libraries load correctly and spatial operations work

## Environment Variables

All images have these pre-configured:
- `SPATIALITE_SECURITY=relaxed` - Allows SpatiaLite to load external data
- `SQLITE_ENABLE_LOAD_EXTENSION=1` - Enables SQLite extension loading
- `LD_LIBRARY_PATH=/usr/lib:/usr/local/lib` - Library search paths

## Registry Tags

- `registry.gitlab.com/fieldworksdiary/spatialite-image:ubuntu-latest`
- `registry.gitlab.com/fieldworksdiary/spatialite-image:alpine-latest`
- `registry.gitlab.com/fieldworksdiary/spatialite-image:latest` (Alpine)
