# SpatiaLite Docker Images

Multi-architecture Docker images (amd64/arm64) with GDAL, SQLite, SpatiaLite, GEOS, and librttopo.

## Images

### Runtime Images (for Production)

Minimal images containing only runtime libraries. Use these for your final production containers.

| Image | Base | Description |
|-------|------|-------------|
| `registry.gitlab.com/fieldworksdiary/spatialite-image:alpine-latest` | Alpine 3.20 | Smallest image |
| `registry.gitlab.com/fieldworksdiary/spatialite-image:ubuntu-latest` | Ubuntu 24.04 | glibc-based |
| `registry.gitlab.com/fieldworksdiary/spatialite-image:latest` | Alpine 3.20 | Default (Alpine) |

### Development Images (for Building)

Images with development headers, pkg-config files, and build tools (gcc, g++). Use these to compile applications with CGO bindings.

| Image | Base | Description |
|-------|------|-------------|
| `registry.gitlab.com/fieldworksdiary/spatialite-image:alpine-dev-latest` | Alpine 3.20 | For building with musl |
| `registry.gitlab.com/fieldworksdiary/spatialite-image:ubuntu-dev-latest` | Ubuntu 24.04 | For building with glibc |
| `registry.gitlab.com/fieldworksdiary/spatialite-image:dev` | Alpine 3.20 | Default dev image |

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

Use matching dev/runtime image pairs from this repository:

```dockerfile
# BUILD with dev image
FROM registry.gitlab.com/fieldworksdiary/spatialite-image:alpine-dev-latest AS builder
# ... install Go, build ...

# RUN with matching runtime image
FROM registry.gitlab.com/fieldworksdiary/spatialite-image:alpine-latest
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
docker run --rm -it registry.gitlab.com/fieldworksdiary/spatialite-image:alpine-latest

# Load SpatiaLite extension
sqlite> SELECT load_extension('mod_spatialite');
sqlite> SELECT spatialite_version();
```

### Mount Local Data

```bash
docker run --rm -it \
  -v $(pwd)/data:/data \
  registry.gitlab.com/fieldworksdiary/spatialite-image:alpine-latest \
  sqlite3 /data/mydb.sqlite
```

## Multi-Stage Build for Go Applications

### Recommended: Alpine-based Build

```dockerfile
# =============================================================================
# Build stage - use the dev image with all headers and build tools
# =============================================================================
FROM registry.gitlab.com/fieldworksdiary/spatialite-image:alpine-dev-latest AS builder

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
# Runtime stage - use the minimal runtime image
# =============================================================================
FROM registry.gitlab.com/fieldworksdiary/spatialite-image:alpine-latest

# Copy only the binary from builder
COPY --from=builder /app/myapp /usr/local/bin/myapp

ENTRYPOINT ["/usr/local/bin/myapp"]
```

### Ubuntu-based Build (for glibc compatibility)

Some Go libraries require glibc. Use the Ubuntu variants:

```dockerfile
# Build stage
FROM registry.gitlab.com/fieldworksdiary/spatialite-image:ubuntu-dev-latest AS builder

# Install Go
RUN apt-get update && apt-get install -y --no-install-recommends golang-go \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=1 go build -o /app/myapp .

# Runtime stage
FROM registry.gitlab.com/fieldworksdiary/spatialite-image:ubuntu-latest

COPY --from=builder /app/myapp /usr/local/bin/myapp
ENTRYPOINT ["/usr/local/bin/myapp"]
```

### Using Specific GDAL CGO Flags

If you need explicit CGO flags (e.g., for [lukeroth/gdal](https://github.com/lukeroth/gdal)):

```dockerfile
FROM registry.gitlab.com/fieldworksdiary/spatialite-image:alpine-dev-latest AS builder

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

FROM registry.gitlab.com/fieldworksdiary/spatialite-image:alpine-latest
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

## License

MIT
