load test_helper

setup() {
    setup_gate_repo
}

teardown() {
    teardown_gate_repo
}

@test "secrets scan blocks staged credential patterns" {
    printf 'DATABASE_PASSWORD=super_secret_value\n' > config.env
    git add config.env
    run run_gate GATE_TRIGGER=pre-commit
    [ "$status" -eq 1 ]
    [[ "$output" == *"GATE BLOCK: Potential secret"* ]]
}

@test "secrets scan allows placeholder wording" {
    printf '# example placeholder for DATABASE_URL\n' > .env.example
    git add .env.example
    run run_gate GATE_TRIGGER=pre-commit
    [ "$status" -eq 0 ]
}
