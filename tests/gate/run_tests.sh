#!/usr/bin/env bash
# Run gate.sh integration tests via bats-core.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

if ! command -v bats >/dev/null 2>&1; then
    echo "bats-core is required. Install with: brew install bats-core  (macOS) or apt install bats" >&2
    exit 1
fi

echo "Running gate.sh integration tests..."
bats tests/gate/*.bats
