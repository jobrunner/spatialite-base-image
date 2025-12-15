# SpatiaLite Docker Images

Multi-architecture Docker images (amd64/arm64) with GDAL, SQLite, SpatiaLite, GEOS, and librttopo.

## Images

| Image | Base | Size |
|-------|------|------|
| `registry.gitlab.com/fieldworksdiary/spatialite-image:alpine-latest` | Alpine 3.20 | ~150MB |
| `registry.gitlab.com/fieldworksdiary/spatialite-image:ubuntu-latest` | Ubuntu 24.04 | ~350MB |
| `registry.gitlab.com/fieldworksdiary/spatialite-image:latest` | Alpine 3.20 | ~150MB |

## Included Libraries

- **GDAL** - Geospatial Data Abstraction Library
- **SQLite** - Database engine
- **SpatiaLite** - Spatial extension for SQLite
- **GEOS** - Geometry Engine Open Source
- **librttopo** - RT Topology Library
- **PROJ** - Coordinate transformation library

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

Use this image as a base for Go applications that need SpatiaLite and GDAL bindings.

### Example: Go Application with go-gdal

```dockerfile
# Build stage
FROM golang:1.23-alpine AS builder

# Install build dependencies for CGO
RUN apk add --no-cache \
    gcc \
    musl-dev \
    gdal-dev \
    geos-dev \
    proj-dev \
    sqlite-dev \
    libspatialite-dev

WORKDIR /app

# Copy go module files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build with CGO enabled
RUN CGO_ENABLED=1 GOOS=linux go build -o /app/myapp .

# Runtime stage
FROM registry.gitlab.com/fieldworksdiary/spatialite-image:alpine-latest

# Copy the binary from builder
COPY --from=builder /app/myapp /usr/local/bin/myapp

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/myapp"]
```

### Example: Using lukeroth/gdal Go Bindings

```dockerfile
# Build stage
FROM golang:1.23-alpine AS builder

RUN apk add --no-cache \
    gcc \
    g++ \
    musl-dev \
    gdal-dev \
    geos-dev \
    proj-dev \
    sqlite-dev \
    libspatialite-dev \
    pkgconfig

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

# Build with CGO for GDAL bindings
RUN CGO_ENABLED=1 \
    CGO_CFLAGS="$(pkg-config --cflags gdal)" \
    CGO_LDFLAGS="$(pkg-config --libs gdal)" \
    go build -o /app/myapp .

# Runtime stage
FROM registry.gitlab.com/fieldworksdiary/spatialite-image:alpine-latest

COPY --from=builder /app/myapp /usr/local/bin/myapp

ENTRYPOINT ["/usr/local/bin/myapp"]
```

### Example: Ubuntu-based Build (for glibc compatibility)

```dockerfile
# Build stage
FROM golang:1.23 AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    libsqlite3-dev \
    libspatialite-dev \
    pkg-config \
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

### Go Code Example

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
            name TEXT,
            geom POINT
        )
    `)
    if err != nil {
        log.Fatal(err)
    }

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

### go.mod Example

```go
module myapp

go 1.23

require (
    github.com/mattn/go-sqlite3 v1.14.24
)
```

## Building Locally

```bash
# Build Alpine image
docker build -f Dockerfile.alpine -t spatialite:alpine .

# Build Ubuntu image
docker build -f Dockerfile.ubuntu -t spatialite:ubuntu .

# Build multi-arch
docker buildx build --platform linux/amd64,linux/arm64 -f Dockerfile.alpine -t spatialite:alpine .
```

## Testing

```bash
# Run tests
docker run --rm -v $(pwd)/tests:/tests spatialite:alpine /tests/test-image.sh
```

## License

MIT
