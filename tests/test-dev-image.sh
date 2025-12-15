#!/bin/sh
# Test script for SpatiaLite Dev Docker images
# This script verifies that development tools and headers are available

FAILED=0
TESTS_RUN=0

# Helper function for test reporting
test_result() {
    TESTS_RUN=$((TESTS_RUN + 1))
    if [ $1 -eq 0 ]; then
        echo "✓ PASS: $2"
    else
        echo "✗ FAIL: $2"
        FAILED=$((FAILED + 1))
    fi
}

echo "=========================================="
echo "SpatiaLite Dev Image Test Suite"
echo "=========================================="
echo ""

echo "--- Build Tools ---"

# Test 1: Check gcc is available
gcc --version > /dev/null 2>&1
test_result $? "gcc is available"
echo "  Version: $(gcc --version | head -1)"

# Test 2: Check g++ is available
g++ --version > /dev/null 2>&1
test_result $? "g++ is available"

# Test 3: Check pkg-config is available
pkg-config --version > /dev/null 2>&1
test_result $? "pkg-config is available"

echo ""
echo "--- Development Headers (pkg-config) ---"

# Test 4: Check GDAL pkg-config
pkg-config --exists gdal 2>/dev/null
test_result $? "gdal.pc is available"
if pkg-config --exists gdal 2>/dev/null; then
    echo "  CFLAGS: $(pkg-config --cflags gdal)"
    echo "  LIBS: $(pkg-config --libs gdal | cut -c1-60)..."
fi

# Test 5: Check SQLite pkg-config
pkg-config --exists sqlite3 2>/dev/null
test_result $? "sqlite3.pc is available"

# Test 6: Check SpatiaLite pkg-config
pkg-config --exists spatialite 2>/dev/null
test_result $? "spatialite.pc is available"

# Test 7: Check GEOS pkg-config
pkg-config --exists geos 2>/dev/null
test_result $? "geos.pc is available"

# Test 8: Check PROJ pkg-config
pkg-config --exists proj 2>/dev/null
test_result $? "proj.pc is available"

echo ""
echo "--- Header Files ---"

# Test 9: Check GDAL header
if [ -f /usr/include/gdal.h ] || [ -f /usr/include/gdal/gdal.h ]; then
    test_result 0 "gdal.h header exists"
else
    test_result 1 "gdal.h header not found"
fi

# Test 10: Check SQLite header
if [ -f /usr/include/sqlite3.h ]; then
    test_result 0 "sqlite3.h header exists"
else
    test_result 1 "sqlite3.h header not found"
fi

# Test 11: Check SpatiaLite header
if [ -f /usr/include/spatialite.h ] || [ -f /usr/include/spatialite/spatialite.h ]; then
    test_result 0 "spatialite.h header exists"
else
    test_result 1 "spatialite.h header not found"
fi

# Test 12: Check GEOS header
if [ -f /usr/include/geos_c.h ] || [ -f /usr/include/geos/capi/geos_c.h ]; then
    test_result 0 "geos_c.h header exists"
else
    test_result 1 "geos_c.h header not found"
fi

echo ""
echo "--- CGO Compilation Test ---"

# Test 13: Compile a simple C program that links against SQLite
cat > /tmp/test_sqlite.c << 'EOF'
#include <stdio.h>
#include <sqlite3.h>

int main() {
    printf("SQLite version: %s\n", sqlite3_libversion());
    return 0;
}
EOF

if gcc /tmp/test_sqlite.c -o /tmp/test_sqlite $(pkg-config --cflags --libs sqlite3) 2>/dev/null; then
    test_result 0 "C program compiles and links against SQLite"
    /tmp/test_sqlite
else
    test_result 1 "C program compiles and links against SQLite"
fi

# Test 14: Compile a simple C program that links against SpatiaLite
# Note: sqlite3.h must be included BEFORE spatialite.h (spatialite headers use sqlite3 types)
cat > /tmp/test_spatialite.c << 'EOF'
#include <stdio.h>
#include <sqlite3.h>
#include <spatialite.h>

int main() {
    spatialite_init(0);
    printf("SpatiaLite version: %s\n", spatialite_version());
    spatialite_cleanup();
    return 0;
}
EOF

if gcc /tmp/test_spatialite.c -o /tmp/test_spatialite $(pkg-config --cflags --libs spatialite sqlite3) 2>/dev/null; then
    test_result 0 "C program compiles and links against SpatiaLite"
    /tmp/test_spatialite
else
    test_result 1 "C program compiles and links against SpatiaLite"
    echo "  Compile error (trying verbose):"
    gcc /tmp/test_spatialite.c -o /tmp/test_spatialite $(pkg-config --cflags --libs spatialite sqlite3) 2>&1 | head -5
fi

# Test 15: Compile a simple C program that links against GDAL
cat > /tmp/test_gdal.c << 'EOF'
#include <stdio.h>
#include <gdal.h>

int main() {
    printf("GDAL version: %s\n", GDALVersionInfo("VERSION_NUM"));
    return 0;
}
EOF

if gcc /tmp/test_gdal.c -o /tmp/test_gdal $(pkg-config --cflags --libs gdal) 2>/dev/null; then
    test_result 0 "C program compiles and links against GDAL"
    /tmp/test_gdal
else
    test_result 1 "C program compiles and links against GDAL"
    echo "  Compile error (trying verbose):"
    gcc /tmp/test_gdal.c -o /tmp/test_gdal $(pkg-config --cflags --libs gdal) 2>&1 | head -5
fi

# Cleanup
rm -f /tmp/test_sqlite.c /tmp/test_sqlite
rm -f /tmp/test_spatialite.c /tmp/test_spatialite
rm -f /tmp/test_gdal.c /tmp/test_gdal

echo ""
echo "=========================================="
echo "Dev Test Summary: $((TESTS_RUN - FAILED))/$TESTS_RUN tests passed"
echo "=========================================="

if [ $FAILED -gt 0 ]; then
    echo "FAILED: $FAILED tests failed"
    exit 1
else
    echo "SUCCESS: All dev tests passed!"
    exit 0
fi
