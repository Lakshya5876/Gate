load test_helper

setup() {
    setup_gate_repo
}

teardown() {
    teardown_gate_repo
}

@test "cold start: last_pass_sha null emits cold scan mode" {
    echo "docs only" > NOTES.md
    git add NOTES.md
    output="$(run_gate GATE_TRIGGER=pre-commit 2>&1)" || true
    [[ "$output" == *"cold start"* ]]
    [[ "$output" == *"scope=cold"* ]]
}
