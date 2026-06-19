load test_helper

setup() {
    setup_gate_repo
}

teardown() {
    teardown_gate_repo
}

@test "pre-push without receipt forces mechanical test run" {
    echo "unreviewed" > NOTES.md
    git add NOTES.md
    git commit -q -m "feat: skip pre-commit gate"

    run run_gate GATE_TRIGGER=pre-push TEST_CMD='echo forced-test; exit 1'
    [ "$status" -eq 1 ]
    [[ "$output" == *"no pre-commit receipt"* ]]
    [[ "$output" == *"forced-test"* ]]
}
