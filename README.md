# SpatiaLite Docker Images

Multi-architecture Docker images (amd64/arm64) with GDAL, SQLite, SpatiaLite, GEOS, and librttopo.

## Images

### Versioning

Images use semantic versioning. When you tag a release `v1.2.3`, the following tags are created:

| Tag Pattern | Example | Description |
|-------------|---------|-------------|
| `X.Y.Z` | `1.2.3` | Exact version (immutable) |
| `X.Y` | `1.2` | Latest patch of minor version |
| `X` | `1` | Latest minor/patch of major version |
| `latest` | - | Latest release (use with caution) |

**Recommendation:** Use exact versions (`1.2.3`) for reproducible builds. Use `X.Y` for automatic patch updates.

### Runtime Images (for Production)

Minimal images containing only runtime libraries. Use these for your final production containers.

```
registry.gitlab.com/fieldworksdiary/spatialite-image:alpine-1.2.3
registry.gitlab.com/fieldworksdiary/spatialite-image:ubuntu-1.2.3
registry.gitlab.com/fieldworksdiary/spatialite-image:1.2.3          # Alpine (default)
```

| Base | Tags |
|------|------|
| Alpine 3.20 | `alpine-X.Y.Z`, `alpine-X.Y`, `alpine-X`, `alpine-latest`, `X.Y.Z`, `X.Y`, `X`, `latest` |
| Ubuntu 24.04 | `ubuntu-X.Y.Z`, `ubuntu-X.Y`, `ubuntu-X`, `ubuntu-latest` |

### Development Images (for Building)

Images with development headers, pkg-config files, and build tools (gcc, g++). Use these to compile applications with CGO bindings.

```
registry.gitlab.com/fieldworksdiary/spatialite-image:alpine-dev-1.2.3
registry.gitlab.com/fieldworksdiary/spatialite-image:ubuntu-dev-1.2.3
registry.gitlab.com/fieldworksdiary/spatialite-image:dev-1.2.3       # Alpine (default)
```

| Base | Tags |
|------|------|
| Alpine 3.20 | `alpine-dev-X.Y.Z`, `alpine-dev-X.Y`, `alpine-dev-X`, `alpine-dev-latest`, `dev-X.Y.Z`, `dev-X.Y`, `dev-X`, `dev` |
| Ubuntu 24.04 | `ubuntu-dev-X.Y.Z`, `ubuntu-dev-X.Y`, `ubuntu-dev-X`, `ubuntu-dev-latest` |

## Why Separate Dev and Runtime Images?

When building Go applications with CGO bindings (like GDAL or SpatiaLite), the compiled binary links against shared libraries (`.so` files). **The library versions must match between build and runtime.**

### The Problem

If you build in `golang:alpine` and run in a different SpatiaLite image:

```dockerfile
# DON'T DO THIS - version mismatch risk!
FROM golang:1.23-alpine AS builder
RUN apk add gdal-dev  # installs version X
# ... build ...

FROM some-other-spatialite-image  # has version Y
COPY --from=builder /app/myapp .  # may crash or behave unexpectedly
```

### The Solution

Use matching dev/runtime image pairs from this repository with the **same version tag**:

```dockerfile
# BUILD with dev image
FROM registry.gitlab.com/fieldworksdiary/spatialite-image:alpine-dev-1.0.0 AS builder
# ... install Go, build ...

# RUN with matching runtime image (same version!)
FROM registry.gitlab.com/fieldworksdiary/spatialite-image:alpine-1.0.0
COPY --from=builder /app/myapp .
```

Both images are built from the same base in the same CI pipeline, guaranteeing identical library versions.

## Included Libraries

- **GDAL** - Geospatial Data Abstraction Library
- **SQLite** - Database engine
- **SpatiaLite** - Spatial extension for SQLite
- **GEOS** - Geometry Engine Open Source
- **librttopo** - RT Topology Library
- **PROJ** - Coordinate transformation library

Dev images additionally include:
- **gcc/g++** - C/C++ compilers
- **pkg-config** - Library configuration tool
- **Development headers** (`.h` files) for all libraries

## Environment Variables

All images have these pre-configured:

```
SPATIALITE_SECURITY=relaxed
SQLITE_ENABLE_LOAD_EXTENSION=1
LD_LIBRARY_PATH=/usr/lib:/usr/local/lib
```

## Usage

### Basic Usage

```bash
# Run SQLite with SpatiaLite
docker run --rm -it registry.gitlab.com/fieldworksdiary/spatialite-image:1.0.0

# Load SpatiaLite extension
sqlite> SELECT load_extension('mod_spatialite');
sqlite> SELECT spatialite_version();
```

### Mount Local Data

```bash
docker run --rm -it \
  -v $(pwd)/data:/data \
  registry.gitlab.com/fieldworksdiary/spatialite-image:1.0.0 \
  sqlite3 /data/mydb.sqlite
```

## Multi-Stage Build for Go Applications

### Recommended: Alpine-based Build

```dockerfile
# =============================================================================
# Build stage - use the dev image with all headers and build tools
# =============================================================================
FROM registry.gitlab.com/fieldworksdiary/spatialite-image:alpine-dev-1.0.0 AS builder

# Install Go
RUN apk add --no-cache go

WORKDIR /app

# Copy go module files first (better layer caching)
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build with CGO enabled
# The dev image has pkg-config set up correctly for all libraries
RUN CGO_ENABLED=1 go build -o /app/myapp .

# =============================================================================
# Runtime stage - use the minimal runtime image (SAME VERSION!)
# =============================================================================
FROM registry.gitlab.com/fieldworksdiary/spatialite-image:alpine-1.0.0

# Copy only the binary from builder
COPY --from=builder /app/myapp /usr/local/bin/myapp

ENTRYPOINT ["/usr/local/bin/myapp"]
```

### Ubuntu-based Build (for glibc compatibility)

Some Go libraries require glibc. Use the Ubuntu variants:

```dockerfile
# Build stage
FROM registry.gitlab.com/fieldworksdiary/spatialite-image:ubuntu-dev-1.0.0 AS builder

# Install Go
RUN apt-get update && apt-get install -y --no-install-recommends golang-go \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=1 go build -o /app/myapp .

# Runtime stage (SAME VERSION!)
FROM registry.gitlab.com/fieldworksdiary/spatialite-image:ubuntu-1.0.0

COPY --from=builder /app/myapp /usr/local/bin/myapp
ENTRYPOINT ["/usr/local/bin/myapp"]
```

### Using Specific GDAL CGO Flags

If you need explicit CGO flags (e.g., for [lukeroth/gdal](https://github.com/lukeroth/gdal)):

```dockerfile
FROM registry.gitlab.com/fieldworksdiary/spatialite-image:alpine-dev-1.0.0 AS builder

RUN apk add --no-cache go

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .

# Use pkg-config to get the correct flags
RUN CGO_ENABLED=1 \
    CGO_CFLAGS="$(pkg-config --cflags gdal)" \
    CGO_LDFLAGS="$(pkg-config --libs gdal)" \
    go build -o /app/myapp .

FROM registry.gitlab.com/fieldworksdiary/spatialite-image:alpine-1.0.0
COPY --from=builder /app/myapp /usr/local/bin/myapp
ENTRYPOINT ["/usr/local/bin/myapp"]
```

## Go Code Example

### Using mattn/go-sqlite3 with SpatiaLite

```go
package main

import (
    "database/sql"
    "fmt"
    "log"

    _ "github.com/mattn/go-sqlite3"
)

func main() {
    // Open database with SpatiaLite extension
    db, err := sql.Open("sqlite3", "file:test.db?_load_extension=mod_spatialite")
    if err != nil {
        log.Fatal(err)
    }
    defer db.Close()

    // Initialize spatial metadata
    _, err = db.Exec("SELECT InitSpatialMetaData(1)")
    if err != nil {
        log.Fatal(err)
    }

    // Create a spatial table
    _, err = db.Exec(`
        CREATE TABLE IF NOT EXISTS locations (
            id INTEGER PRIMARY KEY,
            name TEXT
        )
    `)
    if err != nil {
        log.Fatal(err)
    }

    // Add geometry column
    db.Exec(`SELECT AddGeometryColumn('locations', 'geom', 4326, 'POINT', 'XY')`)

    // Insert a point
    _, err = db.Exec(`
        INSERT INTO locations (name, geom)
        VALUES ('Berlin', GeomFromText('POINT(13.405 52.52)', 4326))
    `)
    if err != nil {
        log.Fatal(err)
    }

    // Query with spatial function
    var name string
    var wkt string
    err = db.QueryRow(`
        SELECT name, AsText(geom) FROM locations WHERE id = 1
    `).Scan(&name, &wkt)
    if err != nil {
        log.Fatal(err)
    }

    fmt.Printf("Location: %s at %s\n", name, wkt)
}
```

### go.mod

```go
module myapp

go 1.23

require github.com/mattn/go-sqlite3 v1.14.24
```

## Building Images Locally

```bash
# Build Alpine runtime
docker build -f Dockerfile.alpine -t spatialite:alpine .

# Build Alpine dev
docker build -f Dockerfile.alpine-dev -t spatialite:alpine-dev .

# Build Ubuntu runtime
docker build -f Dockerfile.ubuntu -t spatialite:ubuntu .

# Build Ubuntu dev
docker build -f Dockerfile.ubuntu-dev -t spatialite:ubuntu-dev .

# Multi-arch build
docker buildx build --platform linux/amd64,linux/arm64 \
  -f Dockerfile.alpine -t spatialite:alpine .
```

## Testing

```bash
# Test runtime image
docker run --rm -v $(pwd)/tests:/tests spatialite:alpine /tests/test-image.sh

# Test dev image
docker run --rm -v $(pwd)/tests:/tests spatialite:alpine-dev sh -c \
  "/tests/test-image.sh && /tests/test-dev-image.sh"
```

## Development Workflow

### Branch Protection

Direct commits to `master` are not allowed. All changes must go through a Merge Request.

### Creating a Release

1. **Create a feature branch:**
   ```bash
   git checkout -b feature/my-change
   ```

2. **Make your changes and update VERSION file:**
   ```bash
   echo "1.1.0" > VERSION
   ```

3. **Update CHANGELOG.md** with your changes

4. **Push and create Merge Request:**
   ```bash
   git push -u origin feature/my-change
   ```

5. **Wait for pipeline to pass** (build + test)

6. **Merge to master** - this automatically:
   - Creates a git tag `v1.1.0` from VERSION file
   - Builds and pushes all Docker image tags
   - Creates a GitLab Release with CHANGELOG

### Setup Required

To enable automatic tagging, create a Project Access Token in GitLab:

1. Go to **Settings → Access Tokens**
2. Create token with `api` and `write_repository` scopes
3. Add as CI/CD variable `GITLAB_TOKEN` in **Settings → CI/CD → Variables**

## License

GPL-2.0-or-later

This project is licensed under the GNU General Public License v2.0 or later due to the inclusion of GPL-licensed components (librttopo). See [LICENSE](LICENSE) for details.
