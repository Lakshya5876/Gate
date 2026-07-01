load test_helper

setup() {
    setup_gate_repo
    sha256sum .githooks/gate.sh 2>/dev/null | awk '{print $1}' > .claude/gate_integrity.sha256 \
        || shasum -a 256 .githooks/gate.sh | awk '{print $1}' > .claude/gate_integrity.sha256
}

teardown() {
    teardown_gate_repo
}

@test "CI integrity check passes when gate.sh matches its pinned hash" {
    run run_ci_integrity_check
    [ "$status" -eq 0 ]
    [[ "$output" == *"integrity-verified"* ]]
}

@test "CI integrity check blocks when gate.sh content diverges from the pinned hash" {
    echo "# a PR silently weakening the gate" >> .githooks/gate.sh
    run run_ci_integrity_check
    [ "$status" -eq 1 ]
    [[ "$output" == *"does not match the pinned integrity hash"* ]]
}

@test "CI integrity check blocks when the pin file is missing (stripped, not just stale)" {
    rm .claude/gate_integrity.sha256
    run run_ci_integrity_check
    [ "$status" -eq 1 ]
    [[ "$output" == *"integrity pin stripped"* ]]
}

@test "CI integrity check blocks when .githooks/gate.sh itself is missing" {
    rm .githooks/gate.sh
    run run_ci_integrity_check
    [ "$status" -eq 1 ]
    [[ "$output" == *"governance stripped"* ]]
}
