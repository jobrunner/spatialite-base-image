# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.6.2] - 2026-09-05

### Changed

- Updated all GitHub Actions to their latest releases (Dependabot):
  `checkout` v5 → v7.0.1, `build-push-action` v6 → v7.3.0,
  `login-action` v3 → v4.6.0, `setup-qemu-action`/`setup-buildx-action`
  v3 → v4.3.0, `codeql-action/upload-sarif` v3 → v4.37.9,
  `action-gh-release` v2 → v3.0.3, `hadolint-action` v3.3.0 → v3.5.0
- Images rebuilt with the latest base image package updates

## [2.0.0] - 2026-09-05

### BREAKING CHANGES

- **Runtime images no longer ship GDAL** (implements #6): the `alpine` and
  `ubuntu` runtime images now contain only the SpatiaLite stack (SQLite,
  SpatiaLite, GEOS, PROJ, librttopo). On Alpine this also removes the heavy
  Python dependency chain (`python3`, `py3-gdal`, `py3-numpy`, expat, libpng,
  giflib, ...), which was the main source of recurring CVE findings in
  downstream scans. If you need `gdalinfo`/`ogr2ogr` at runtime, use the
  `-dev` images or install GDAL yourself.
- The `-dev` images are unchanged and keep the full GDAL toolchain
  (plus headers, gcc, pkg-config, Go).

### Added

- Monthly rebuild workflow (`.github/workflows/rebuild.yml`): republishes the
  current release tags on the 1st of each month with fresh base image
  packages (same X.Y.Z, new digest), so published images pick up security
  patches between releases. Runs the full build → test → scan → promote
  pipeline; failing rebuilds are never promoted.

### Changed

- Runtime image tests no longer expect GDAL; GDAL checks moved to the dev
  image test suite
- Per-flavor OCI image descriptions (runtime images are no longer described
  as containing GDAL)

## [1.6.1] - 2026-09-05

### Added

- Lint job in CI: hadolint for all Dockerfiles plus Trivy misconfiguration
  scan (mirrors the local pre-commit hooks)

### Changed

- CI/CD pipeline hardening:
  - Merge builds now follow build → test → scan → promote: images are pushed
    under a CI candidate tag (`<flavor>-ci`), tested and scanned, and only
    then promoted to their final tags (including `latest`) via
    `docker buildx imagetools create` - broken images can no longer reach
    `latest`
  - Images are now tested on native arm64 runners (`ubuntu-24.04-arm`) in
    addition to amd64; previously arm64 images were never tested
  - Manual releases (`release.yml`) now run the same build → test → scan →
    promote pipeline as CI instead of pushing untested images; shared logic
    lives in the reusable workflow `build-images.yml`
  - Concurrency groups serialize merge builds and manual releases so they
    cannot race each other on image tags
  - All GitHub Actions are pinned to commit SHAs (supply-chain hardening,
    kept up to date by Dependabot); `build-push-action` upgraded to v6,
    `action-gh-release` to v2, `checkout` to v5
  - Workflows declare least-privilege `permissions` at the top level
  - Buildx cache uses a separate scope per image flavor
  - PR validation runs for pull requests against any target branch
    (stacked PRs included)
- `USER` directive now uses numeric `10001:10001` instead of the username so
  Kubernetes `runAsNonRoot` verification works (fixes hadolint DL3066)

## [1.6.0] - 2026-09-05

### Security

- Fixed all known fixable HIGH/CRITICAL CVEs in all images:
  - Alpine base image upgraded from 3.21 to 3.24 (fixes CVE-2026-31789 in
    OpenSSL, CVE-2025-54874 in openjpeg, plus HIGH severity CVEs in zlib,
    musl, libpng, libexpat, libxml2, nghttp2 and Python)
  - `apk upgrade` (Alpine) and `apt-get upgrade` (Ubuntu) now run during
    image builds so security patches released after the base image are
    always applied (fixes CVE-2026-45447 in OpenSSL on Ubuntu)
  - Go upgraded from 1.24.4 (EOL) to 1.26.8 in dev images (fixes
    CVE-2025-68121 and ~20 HIGH severity stdlib CVEs)

### Added

- Weekly security scanning (`.github/workflows/security-scan.yml`):
  - Trivy scans all published images every Monday 06:00 UTC (and on demand)
  - Results are uploaded as SARIF to GitHub Code Scanning
  - Workflow fails when fixable HIGH/CRITICAL vulnerabilities are found
- Trivy vulnerability gate in PR builds: pull requests fail when the built
  image contains fixable HIGH/CRITICAL vulnerabilities
- Dependabot configuration (`.github/dependabot.yml`): weekly updates for
  Docker base images and GitHub Actions

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
