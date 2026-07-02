load test_helper

# Pins a real bug found via an actual end-to-end `git commit` test (not by
# inspection): _json_append_audit had no [ -f "$GATE_STATE" ] guard, unlike
# every other GATE_STATE-touching function. When gate_state.json was
# missing, the LAST call in gate.sh's success path (_json_append_audit ...
# "pass", right before "GATE PASS" prints) raised an unguarded
# FileNotFoundError inside set -e, silently aborting the whole script — a
# commit that passed every real check (lint, type check, layer boundary,
# complexity) still failed, with a raw Python traceback instead of a clear
# message.

setup() {
    setup_gate_repo
}

teardown() {
    teardown_gate_repo
}

@test "gate.sh reaches GATE PASS even when gate_state.json is missing" {
    [ ! -f ".claude/gate_state.json" ] || mv .claude/gate_state.json /tmp/gate_state_moved_aside.json

    echo "def add(a, b): return a + b" > helper.py
    git add helper.py
    run run_gate GATE_TRIGGER=pre-commit \
        LINT_CMD='true' TYPE_CMD='true' COMPLEXITY_CMD='true' TEST_CMD='true'

    [ "$status" -eq 0 ]
    [[ "$output" == *"GATE PASS"* ]]
    [[ "$output" != *"Traceback"* ]]
    [[ "$output" != *"FileNotFoundError"* ]]

    [ -f "/tmp/gate_state_moved_aside.json" ] && mv /tmp/gate_state_moved_aside.json .claude/gate_state.json
}

@test "a real git commit succeeds when gate_state.json is missing (end-to-end, not just gate.sh in isolation)" {
    mv .claude/gate_state.json /tmp/gate_state_moved_aside2.json

    echo "def multiply(a, b): return a * b" > helper2.py
    git add helper2.py
    TEST_CMD='true' LINT_CMD='true' TYPE_CMD='true' COMPLEXITY_CMD='true' run git commit -m "feat: add helper2"

    [ "$status" -eq 0 ]
    run git log --oneline -1
    [[ "$output" == *"add helper2"* ]]

    mv /tmp/gate_state_moved_aside2.json .claude/gate_state.json
}

@test "audit log is simply skipped (not fabricated) when gate_state.json is missing" {
    mv .claude/gate_state.json /tmp/gate_state_moved_aside3.json

    echo "def sub(a, b): return a - b" > helper3.py
    git add helper3.py
    run run_gate GATE_TRIGGER=pre-commit \
        LINT_CMD='true' TYPE_CMD='true' COMPLEXITY_CMD='true' TEST_CMD='true'
    [ "$status" -eq 0 ]
    [ ! -f ".claude/gate_state.json" ]

    mv /tmp/gate_state_moved_aside3.json .claude/gate_state.json
}
