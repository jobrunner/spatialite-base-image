#!/bin/sh
# Test script for SpatiaLite Docker images
# This script verifies that all required components are properly installed

set -e

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
echo "SpatiaLite Image Test Suite"
echo "=========================================="
echo ""

# Test 1: Check environment variables
echo "--- Environment Variables ---"

if [ "$SPATIALITE_SECURITY" = "relaxed" ]; then
    test_result 0 "SPATIALITE_SECURITY is set to 'relaxed'"
else
    test_result 1 "SPATIALITE_SECURITY should be 'relaxed', got '$SPATIALITE_SECURITY'"
fi

if [ "$SQLITE_ENABLE_LOAD_EXTENSION" = "1" ]; then
    test_result 0 "SQLITE_ENABLE_LOAD_EXTENSION is set to '1'"
else
    test_result 1 "SQLITE_ENABLE_LOAD_EXTENSION should be '1', got '$SQLITE_ENABLE_LOAD_EXTENSION'"
fi

echo "$LD_LIBRARY_PATH" | grep -q "/usr/lib" && echo "$LD_LIBRARY_PATH" | grep -q "/usr/local/lib"
test_result $? "LD_LIBRARY_PATH contains /usr/lib and /usr/local/lib"

echo ""
echo "--- Binary Availability ---"

# Test 2: Check sqlite3 is available
sqlite3 --version > /dev/null 2>&1
test_result $? "sqlite3 binary is available"
echo "  Version: $(sqlite3 --version)"

# Test 3: Check GDAL tools
gdalinfo --version > /dev/null 2>&1
test_result $? "gdalinfo (GDAL) is available"
echo "  Version: $(gdalinfo --version)"

ogrinfo --version > /dev/null 2>&1
test_result $? "ogrinfo (OGR/GDAL) is available"

echo ""
echo "--- Library Loading ---"

# Test 4: Check SpatiaLite can be loaded
SPATIALITE_LOAD=$(sqlite3 :memory: "SELECT load_extension('mod_spatialite'); SELECT spatialite_version();" 2>&1) || true
if echo "$SPATIALITE_LOAD" | grep -qE "^[0-9]+\.[0-9]+"; then
    test_result 0 "SpatiaLite extension loads successfully"
    echo "  Version: $(echo "$SPATIALITE_LOAD" | tail -1)"
else
    test_result 1 "SpatiaLite extension failed to load: $SPATIALITE_LOAD"
fi

# Test 5: Check GEOS version through SpatiaLite
GEOS_VERSION=$(sqlite3 :memory: "SELECT load_extension('mod_spatialite'); SELECT geos_version();" 2>&1 | tail -1) || true
if echo "$GEOS_VERSION" | grep -qE "^[0-9]+\.[0-9]+"; then
    test_result 0 "GEOS is available through SpatiaLite"
    echo "  Version: $GEOS_VERSION"
else
    test_result 1 "GEOS version check failed: $GEOS_VERSION"
fi

# Test 6: Check librttopo version through SpatiaLite
RTTOPO_VERSION=$(sqlite3 :memory: "SELECT load_extension('mod_spatialite'); SELECT rttopo_version();" 2>&1 | tail -1) || true
if echo "$RTTOPO_VERSION" | grep -qE "^[0-9]+\.[0-9]+"; then
    test_result 0 "librttopo is available through SpatiaLite"
    echo "  Version: $RTTOPO_VERSION"
else
    test_result 1 "librttopo version check failed: $RTTOPO_VERSION"
fi

# Test 7: Check PROJ version through SpatiaLite (version string varies by distro)
PROJ_VERSION=$(sqlite3 :memory: "SELECT load_extension('mod_spatialite'); SELECT proj_version();" 2>&1 | tail -1) || true
if echo "$PROJ_VERSION" | grep -qE "[0-9]+\.[0-9]+"; then
    test_result 0 "PROJ is available through SpatiaLite"
    echo "  Version: $PROJ_VERSION"
else
    test_result 1 "PROJ version check failed: $PROJ_VERSION"
fi

echo ""
echo "--- Functional Tests ---"

# Test 8: Test basic geometry creation and query (without spatial metadata tables)
SPATIAL_TEST=$(sqlite3 :memory: "SELECT load_extension('mod_spatialite'); SELECT AsText(GeomFromText('POINT(10.0 20.0)', 4326));" 2>&1) || true
if echo "$SPATIAL_TEST" | grep -q "POINT(10 20)"; then
    test_result 0 "Geometry creation and AsText work"
else
    test_result 1 "Geometry test failed: $SPATIAL_TEST"
fi

# Test 9: Test spatial functions
BUFFER_TEST=$(sqlite3 :memory: "SELECT load_extension('mod_spatialite'); SELECT AsText(Buffer(GeomFromText('POINT(0 0)', 4326), 1));" 2>&1) || true
if echo "$BUFFER_TEST" | grep -qE "POLYGON"; then
    test_result 0 "Spatial buffer function works"
else
    test_result 1 "Buffer function test failed: $BUFFER_TEST"
fi

# Test 10: Test coordinate transformation (initialize spatial_ref_sys first)
TRANSFORM_TEST=$(sqlite3 :memory: "SELECT load_extension('mod_spatialite'); SELECT InitSpatialMetaData(1); SELECT ST_X(Transform(GeomFromText('POINT(0 0)', 4326), 3857));" 2>&1 | tail -1) || true
if echo "$TRANSFORM_TEST" | grep -qE "^[0-9.-]+$"; then
    test_result 0 "Coordinate transformation (PROJ) works"
else
    test_result 1 "Coordinate transformation test failed: $TRANSFORM_TEST"
fi

# Test 11: Test GDAL can read spatial data
GDAL_TEST=$(ogrinfo --formats 2>&1)
if echo "$GDAL_TEST" | grep -qi "SQLite"; then
    test_result 0 "GDAL has SQLite/SpatiaLite driver"
else
    test_result 1 "GDAL SQLite driver not found"
fi

# Test 12: Test spatial relationship functions
INTERSECT_TEST=$(sqlite3 :memory: "SELECT load_extension('mod_spatialite'); SELECT ST_Intersects(GeomFromText('POINT(0 0)', 4326), GeomFromText('POLYGON((-1 -1, 1 -1, 1 1, -1 1, -1 -1))', 4326));" 2>&1 | tail -1) || true
if [ "$INTERSECT_TEST" = "1" ]; then
    test_result 0 "Spatial relationship functions work"
else
    test_result 1 "ST_Intersects test failed: $INTERSECT_TEST"
fi

echo ""
echo "=========================================="
echo "Test Summary: $((TESTS_RUN - FAILED))/$TESTS_RUN tests passed"
echo "=========================================="

if [ $FAILED -gt 0 ]; then
    echo "FAILED: $FAILED tests failed"
    exit 1
else
    echo "SUCCESS: All tests passed!"
    exit 0
fi
