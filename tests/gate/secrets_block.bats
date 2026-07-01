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

# Adversarial variants: credential formats with no English keyword ("secret",
# "password", "token"...) nearby, which the pure keyword scan cannot catch on
# its own. These are the specific gap a fresh audit found by direct testing —
# confirmed real before fixing (bare AKIA/ghp_ tokens and PKCS8 keys all
# slipped through the original keyword-only regex).

@test "secrets scan blocks a bare AWS access key with no keyword nearby" {
    printf 'x = "AKIAIOSFODNN7EXAMPLE"\n' > config.py
    git add config.py
    run run_gate GATE_TRIGGER=pre-commit
    [ "$status" -eq 1 ]
    [[ "$output" == *"GATE BLOCK: Potential secret"* ]]
}

@test "secrets scan blocks a bare GitHub personal access token with no keyword nearby" {
    printf 'x = "ghp_16C7e42F292c6912E7710c838347Ae178B4a"\n' > config.py
    git add config.py
    run run_gate GATE_TRIGGER=pre-commit
    [ "$status" -eq 1 ]
    [[ "$output" == *"GATE BLOCK: Potential secret"* ]]
}

@test "secrets scan blocks a bare Slack token with no keyword nearby" {
    printf 'x = "xoxb-dummy1234567890"\n' > config.py
    git add config.py
    run run_gate GATE_TRIGGER=pre-commit
    [ "$status" -eq 1 ]
    [[ "$output" == *"GATE BLOCK: Potential secret"* ]]
}

@test "secrets scan blocks a bare Stripe live key with no keyword nearby" {
    printf 'x = "sk_live_dummy1234567890123456"\n' > config.py
    git add config.py
    run run_gate GATE_TRIGGER=pre-commit
    [ "$status" -eq 1 ]
    [[ "$output" == *"GATE BLOCK: Potential secret"* ]]
}

@test "secrets scan blocks a PKCS8 private key with no algorithm prefix" {
    # -----BEGIN PRIVATE KEY----- (no RSA/EC/OPENSSH prefix) is the modern
    # default format for most tooling (e.g. openssl genpkey) — the original
    # regex only matched BEGIN (RSA|EC|OPENSSH|PGP), missing this entirely.
    printf -- '-----BEGIN PRIVATE KEY-----\n' > key.pem
    git add key.pem
    run run_gate GATE_TRIGGER=pre-commit
    [ "$status" -eq 1 ]
    [[ "$output" == *"GATE BLOCK: Potential secret"* ]]
}

@test "secrets scan still blocks the original RSA/OPENSSH private key formats (no regression)" {
    printf -- '-----BEGIN OPENSSH PRIVATE KEY-----\n' > key.pem
    git add key.pem
    run run_gate GATE_TRIGGER=pre-commit
    [ "$status" -eq 1 ]
    [[ "$output" == *"GATE BLOCK: Potential secret"* ]]
}
