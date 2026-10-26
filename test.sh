#!/usr/bin/env bash
#
# test.sh - build the diagnostic image and assert core behaviors against it.

set -u

TAG="diagnostic-cli:test"
PASS=0
FAIL=0

assert_exit() {
    local description="$1"
    local expected="$2"
    shift 2
    "$@" >/dev/null 2>&1
    local rc=$?
    if [[ "$rc" -eq "$expected" ]]; then
        echo "PASS: $description (exit $rc)"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $description (expected $expected, got $rc)"
        FAIL=$((FAIL + 1))
    fi
}

assert_nonzero() {
    local description="$1"
    shift
    "$@" >/dev/null 2>&1
    local rc=$?
    if [[ "$rc" -ne 0 ]]; then
        echo "PASS: $description (exit $rc)"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $description (expected non-zero, got 0)"
        FAIL=$((FAIL + 1))
    fi
}

echo "Building image $TAG..."
if ! docker build -t "$TAG" . >/tmp/diagnostic-test-build.log 2>&1; then
    echo "FAIL: image build"
    cat /tmp/diagnostic-test-build.log
    exit 1
fi

assert_exit    "help exits 0"      0 docker run --rm "$TAG" help
assert_exit    "system exits 0"    0 docker run --rm "$TAG" system
assert_exit    "disk exits 0"      0 docker run --rm "$TAG" disk
assert_nonzero "invalid command"     docker run --rm "$TAG" definitely-not-a-command

echo "----"
echo "Passed: $PASS  Failed: $FAIL"
[[ "$FAIL" -eq 0 ]]
