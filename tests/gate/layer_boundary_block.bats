load test_helper

setup() {
    setup_gate_repo
    mkdir -p app/services
}

teardown() {
    teardown_gate_repo
}

@test "layer boundary blocks HTTP imports in services layer" {
    cat > app/services/billing.py <<'EOF'
from fastapi import HTTPException

def charge():
    raise HTTPException(status_code=400, detail="bad")
EOF
    git add app/services/billing.py
    run run_gate GATE_TRIGGER=pre-commit LINT_CMD='true'
    [ "$status" -eq 1 ]
    [[ "$output" == *"Layer boundary violation"* ]]
    [[ "$output" == *"SERVICE_HAS_HTTP"* ]]
}

@test "layer boundary blocks SQL in routes layer" {
    mkdir -p app/routes
    cat > app/routes/users.py <<'EOF'
def list_users(conn):
    return conn.execute("SELECT id FROM users")
EOF
    git add app/routes/users.py
    run run_gate GATE_TRIGGER=pre-commit LINT_CMD='true'
    [ "$status" -eq 1 ]
    [[ "$output" == *"ROUTES_HAS_SQL"* ]]
}
