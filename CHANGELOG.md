# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.0] - 2025-12-19

### Added

- Go 1.24.4 to dev images (alpine-dev, ubuntu-dev)
  - Multi-arch support (amd64/arm64) with automatic architecture detection
  - PATH and GOPATH environment variables configured
  - Enables Go development with CGO bindings
- Claude Code hooks for development workflow protection:
  - PreToolUse hook prevents direct commits to main/master branches
  - Enforces VERSION and CHANGELOG.md updates before PR creation

## [1.4.0] - 2025-12-18

### Added

- Security hardening for all images:
  - Non-root user `spatialite` (UID 10001) runs by default
  - SUID/SGID bits removed from all binaries
- Security documentation in README.md and CLAUDE.md

### Changed

- Dev images now also run as non-root by default (override with `--user root`)

## [1.3.1] - 2025-12-17

### Added

- OCI image labels for GitHub Container Registry (description, version, source, license)
- Claude Code hook to auto-update README examples when VERSION changes

## [1.3.0] - 2025-12-17

### Changed

- Improved CI/CD workflow with stricter validation:
  - VERSION must be valid SemVer format
  - VERSION must not exist as git tag
  - CHANGELOG must have entry for VERSION
- PRs now build and test without pushing to registry
- Releases happen automatically on merge to main
- Separated manual release workflow for emergency use

## [1.2.0] - 2025-12-17

### Changed

- Upgraded Alpine base image from 3.20 to 3.21
- Upgraded Ubuntu base image from 24.04 to 26.04

## [1.1.0] - 2025-12-17

### Changed

- Migrated CI/CD from GitLab CI to GitHub Actions
- Changed container registry from GitLab Registry to GitHub Container Registry (ghcr.io)
- Repository moved to `github.com/jobrunner/spatialite-base-image`
- Images now available at `ghcr.io/jobrunner/spatialite-base-image`

## [1.0.0] - 2025-12-15

### Added

- Initial release of multi-architecture Docker images (amd64/arm64)
- **Runtime images** (minimal, for production):
  - `alpine-1.0.0` - Alpine 3.20 based
  - `ubuntu-1.0.0` - Ubuntu 24.04 based
- **Development images** (with headers, compilers, pkg-config for CGO):
  - `alpine-dev-1.0.0` - Alpine 3.20 based
  - `ubuntu-dev-1.0.0` - Ubuntu 24.04 based
- Pre-configured environment variables:
  - `SPATIALITE_SECURITY=relaxed`
  - `SQLITE_ENABLE_LOAD_EXTENSION=1`
  - `LD_LIBRARY_PATH=/usr/lib:/usr/local/lib`
- Semantic versioning with `X.Y.Z`, `X.Y`, `X` tags
- Comprehensive test suite for runtime and dev images
- GitLab CI/CD pipeline for automated multi-arch builds

### Included Libraries

- GDAL 3.9.3 (Alpine) / 3.8.4 (Ubuntu)
- SQLite 3.45.x
- SpatiaLite 5.1.0
- GEOS 3.12.x
- PROJ 9.4.x
- librttopo 1.1.0

[1.5.0]: https://github.com/jobrunner/spatialite-base-image/releases/tag/v1.5.0
[1.4.0]: https://github.com/jobrunner/spatialite-base-image/releases/tag/v1.4.0
[1.3.1]: https://github.com/jobrunner/spatialite-base-image/releases/tag/v1.3.1
[1.3.0]: https://github.com/jobrunner/spatialite-base-image/releases/tag/v1.3.0
[1.2.0]: https://github.com/jobrunner/spatialite-base-image/releases/tag/v1.2.0
[1.1.0]: https://github.com/jobrunner/spatialite-base-image/releases/tag/v1.1.0
[1.0.0]: https://github.com/jobrunner/spatialite-base-image/releases/tag/v1.0.0
