#!/usr/bin/env bash
# Shared helpers for gate.sh integration tests (throwaway git repos).

FRAMEWORK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GATE_SH_SRC="${FRAMEWORK_ROOT}/templates/gate.sh"
GATE_STATE_SRC="${FRAMEWORK_ROOT}/templates/gate_state.json"

setup_gate_repo() {
    TEST_REPO="$(mktemp -d "${TMPDIR:-/tmp}/gate-test-XXXXXX")"
    cd "$TEST_REPO" || return 1

    git init -q
    git config user.email "gate-test@example.com"
    git config user.name "Gate Test"
    git config init.defaultBranch main

    mkdir -p .githooks .claude
    cp "$GATE_SH_SRC" .githooks/gate.sh
    cp "$GATE_STATE_SRC" .claude/gate_state.json
    chmod +x .githooks/gate.sh

    git checkout -b feature/gate-test -q
    echo "# gate test repo" > README.md
    git add README.md
    git commit -q -m "chore: init test repo"
}

teardown_gate_repo() {
    if [ -n "${TEST_REPO:-}" ] && [ -d "$TEST_REPO" ]; then
        rm -rf "$TEST_REPO"
    fi
}

run_gate() {
    # Usage: run_gate [extra env assignments...]
    # Caller must be inside TEST_REPO.
    env "$@" GATE_STATE=".claude/gate_state.json" bash .githooks/gate.sh
}

run_pre_push_hook() {
    # Minimal pre-push bypass-clock logic mirrored from install.sh (for isolated testing).
    env bash -c '
set -euo pipefail
if git notes --ref=refs/notes/bypasses show HEAD 2>/dev/null | grep -q "BYPASS"; then
    BYPASS_DATE=$(git notes --ref=refs/notes/bypasses show HEAD 2>/dev/null | grep -oE "date=[0-9]+" | head -1 | cut -d= -f2)
    NOW_EPOCH=$(date +%s)
    if [ -n "$BYPASS_DATE" ]; then
        BYPASS_AGE=$(( NOW_EPOCH - BYPASS_DATE ))
        if [ "$BYPASS_AGE" -gt 86400 ]; then
            echo "PRE-PUSH BLOCK: Bypass deadline expired." >&2
            exit 1
        fi
    fi
fi
'
}
