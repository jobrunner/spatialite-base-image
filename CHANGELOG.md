# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[1.0.0]: https://gitlab.com/fieldworksdiary/spatialite-image/-/releases/v1.0.0
