load test_helper

# Verifies the shipped pylint/ESLint layer-boundary supplement templates
# (templates/.pylintrc.layer-boundary, templates/eslint-layer-boundary.snippet.cjs)
# directly — independent of gate.sh's grep-based STEP 6.5. Static-content
# assertions always run; a real pylint/eslint invocation is exercised too
# when that binary happens to be available, and skipped (not faked) when
# it isn't, per this suite's existing convention (see agent_detection.bats).

setup() {
    PYLINTRC="${FRAMEWORK_ROOT}/templates/.pylintrc.layer-boundary"
    ESLINT_SNIPPET="${FRAMEWORK_ROOT}/templates/eslint-layer-boundary.snippet.cjs"
    FIXTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lint-fixture-XXXXXX")"
}

teardown() {
    [ -n "${FIXTURE_DIR:-}" ] && rm -rf "$FIXTURE_DIR"
}

@test "pylint layer-boundary template bans the expected HTTP modules and nothing else" {
    [ -f "$PYLINTRC" ]
    run grep -E "^deprecated-modules=" "$PYLINTRC"
    [ "$status" -eq 0 ]
    [[ "$output" == *"fastapi"* ]]
    [[ "$output" == *"flask"* ]]
    [[ "$output" == *"django.http"* ]]
    run grep -E "^enable=deprecated-module" "$PYLINTRC"
    [ "$status" -eq 0 ]
    run grep -E "^disable=all" "$PYLINTRC"
    [ "$status" -eq 0 ]
}

@test "eslint layer-boundary snippet loads and exposes the expected rule shape" {
    [ -f "$ESLINT_SNIPPET" ]
    run node -e "
const m = require('$ESLINT_SNIPPET');
if (!Array.isArray(m.FILE_GLOBS) || m.FILE_GLOBS.length === 0) throw new Error('FILE_GLOBS missing');
const rule = m.LAYER_BOUNDARY_OVERRIDE.rules['no-restricted-imports'];
if (!rule || rule[0] !== 'error') throw new Error('rule not wired as error');
const names = rule[1].paths.map(p => p.name);
if (!names.includes('express')) throw new Error('express not banned');
console.log('ok');
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok"* ]]
}

@test "pylint supplement catches a direct HTTP import in services (if pylint is available)" {
    command -v pylint >/dev/null 2>&1 || skip "pylint not installed in this environment"
    mkdir -p "$FIXTURE_DIR/services"
    cat > "$FIXTURE_DIR/services/billing.py" <<'EOF'
from fastapi import HTTPException

def charge():
    raise HTTPException(status_code=400, detail="bad")
EOF
    run pylint --rcfile="$PYLINTRC" "$FIXTURE_DIR/services/billing.py"
    [[ "$output" == *"deprecated-module"* ]]
    [[ "$output" == *"fastapi"* ]]
}

@test "pylint supplement does NOT catch the re-export gap (documents the same limitation as grep)" {
    command -v pylint >/dev/null 2>&1 || skip "pylint not installed in this environment"
    mkdir -p "$FIXTURE_DIR/services"
    cat > "$FIXTURE_DIR/services/billing_indirect.py" <<'EOF'
from myapp.http_shim import raise_http_error

def charge():
    raise_http_error(400, "bad")
EOF
    run pylint --rcfile="$PYLINTRC" "$FIXTURE_DIR/services/billing_indirect.py"
    [[ "$output" != *"deprecated-module"* ]]
}

@test "eslint supplement catches a direct HTTP import in services (if eslint is available)" {
    command -v eslint >/dev/null 2>&1 || skip "eslint not installed in this environment"
    mkdir -p "$FIXTURE_DIR/services"
    cat > "$FIXTURE_DIR/services/billing.js" <<'EOF'
import express from "express";
EOF
    cat > "$FIXTURE_DIR/eslint.config.cjs" <<EOF
const { LAYER_BOUNDARY_FLAT_CONFIG } = require('$ESLINT_SNIPPET');
module.exports = [LAYER_BOUNDARY_FLAT_CONFIG];
EOF
    run eslint --no-eslintrc -c "$FIXTURE_DIR/eslint.config.cjs" "$FIXTURE_DIR/services/billing.js"
    [[ "$output" == *"no-restricted-imports"* ]]
}
