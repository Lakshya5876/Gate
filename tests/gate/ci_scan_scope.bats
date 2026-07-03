load test_helper

# Verifies the fix for a real bug found via adversarial E2E testing: in a CI
# checkout, nothing is ever staged (the working tree is placed directly at
# HEAD with an empty index), so gate.sh's normal cold-start path
# ("git diff --cached --name-only") was unconditionally empty regardless of
# what a PR/push actually changed — the CI gate silently reported PASS having
# scanned zero files. ci-gate.yml now resolves a CI_BASE_SHA (PR base sha, or
# the push's previous HEAD) and gate.sh diffs against that instead when
# GATE_TRIGGER=ci. When no base is resolvable at all (e.g. a brand-new
# branch's first push reports an all-zeros "before" SHA), it fails SAFE by
# scanning the entire tracked tree rather than fail-open by scanning nothing.

setup() {
    setup_gate_repo
}

teardown() {
    teardown_gate_repo
}

@test "CI mode diffs against CI_BASE_SHA instead of the always-empty --cached cold-start path" {
    BASE_SHA=$(git rev-parse HEAD)
    echo "changed" >> README.md
    git add README.md
    git commit -q -m "second commit"
    run run_gate GATE_TRIGGER=ci "CI_BASE_SHA=${BASE_SHA}"
    echo "$output" | grep -q "GATE: ci mode — diffing against base ${BASE_SHA}"
}

@test "CI cold start with no CI_BASE_SHA set falls back to a full-tree scan, not a silent no-op" {
    run run_gate GATE_TRIGGER=ci
    echo "$output" | grep -q "scanning entire tree"
}

@test "CI cold start with an unresolvable CI_BASE_SHA (all-zeros 'before', new branch's first push) falls back to a full-tree scan" {
    run run_gate GATE_TRIGGER=ci "CI_BASE_SHA=0000000000000000000000000000000000000000"
    echo "$output" | grep -q "scanning entire tree"
}

@test "non-CI GATE_TRIGGER is unaffected — cold start still uses --cached, ignoring any CI_BASE_SHA" {
    BASE_SHA=$(git rev-parse HEAD)
    run run_gate GATE_TRIGGER=pre-commit "CI_BASE_SHA=${BASE_SHA}"
    echo "$output" | grep -q "GATE: cold start — full scan"
}
