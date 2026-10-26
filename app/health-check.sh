#!/usr/bin/env bash
#
# health-check.sh - standalone container health probe.
# Verifies required tools exist and that core subcommands run.
# Exit: 0 healthy, 1 unhealthy.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for tool in df getent free; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "health: missing required tool: $tool" >&2
        exit 1
    fi
done

if ! "$SCRIPT_DIR/diagnostic.sh" help >/dev/null 2>&1; then
    echo "health: 'help' subcommand did not run" >&2
    exit 1
fi

if ! "$SCRIPT_DIR/diagnostic.sh" system >/dev/null 2>&1; then
    echo "health: 'system' subcommand did not run" >&2
    exit 1
fi

echo "health: ok"
exit 0
