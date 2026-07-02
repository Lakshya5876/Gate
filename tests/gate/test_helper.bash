#!/usr/bin/env bash
# Shared helpers for gate.sh integration tests (throwaway git repos).

FRAMEWORK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GATE_SH_SRC="${FRAMEWORK_ROOT}/templates/gate.sh"
GATE_STATE_SRC="${FRAMEWORK_ROOT}/templates/gate_state.json"
VERIFY_INTEGRITY_SRC="${FRAMEWORK_ROOT}/templates/verify_governance_integrity.sh"
PRE_COMMIT_SRC="${FRAMEWORK_ROOT}/templates/pre-commit"
PRE_PUSH_SRC="${FRAMEWORK_ROOT}/templates/pre-push"
BASH_GUARD_SRC="${FRAMEWORK_ROOT}/templates/pre_bash_trust_root_guard.sh"

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
    cp "$VERIFY_INTEGRITY_SRC" .githooks/verify_governance_integrity.sh
    cp "$PRE_COMMIT_SRC" .githooks/pre-commit
    cp "$PRE_PUSH_SRC" .githooks/pre-push
    chmod +x .githooks/gate.sh .githooks/verify_governance_integrity.sh .githooks/pre-commit .githooks/pre-push

    git checkout -b feature/gate-test -q
    echo "# gate test repo" > README.md
    git add README.md
    git commit -q -m "chore: init test repo"
}

extract_install_functions() {
    # Robustly extracts _write_hooks() and _write_trust_root_settings() from
    # the REAL install.sh into a sourceable temp file, so tests can run the
    # actual install-time file-generation logic rather than a hand-copied
    # mirror of it. Extraction is anchored on function-START markers
    # (grep -n '^_write_hooks() {'), never on a closing-brace search — the
    # settings.json heredoc these functions write contains a `}` at column 0
    # (the JSON object's own closing brace), which breaks any extraction that
    # searches for `^}$` as an end marker. Start-anchored extraction from
    # _write_hooks's start line up to (but excluding) _upgrade's start line
    # is immune to that, since it never looks for a closing brace at all.
    local install_sh="${FRAMEWORK_ROOT}/install.sh"
    local start_line end_line
    start_line=$(grep -n '^_write_hooks() {' "$install_sh" | head -1 | cut -d: -f1)
    end_line=$(grep -n '^_upgrade() {' "$install_sh" | head -1 | cut -d: -f1)
    [ -n "$start_line" ] && [ -n "$end_line" ] || return 1

    EXTRACTED_FUNCS_FILE="$(mktemp "${TMPDIR:-/tmp}/install-funcs-XXXXXX.sh")"
    sed -n "${start_line},$((end_line - 1))p" "$install_sh" > "$EXTRACTED_FUNCS_FILE"

    _success() { :; }
    _warn()    { :; }
    _error()   { echo "[EXTRACTED-ERROR] $*" >&2; return 1; }
    _info()    { :; }
    _fetch() {
        local src="$1" dst="$2"
        cp "${FRAMEWORK_ROOT}/${src}" "$dst"
    }
    # shellcheck disable=SC1090
    source "$EXTRACTED_FUNCS_FILE"
}

deploy_bash_guard() {
    # Deploys the REAL templates/pre_bash_trust_root_guard.sh (with test-repo
    # placeholder substitutions) — not a stub, not a hand-copied mirror of
    # its matching logic. Exercises the exact file install.sh generates, the
    # same fidelity principle as run_ci_integrity_check for verify_governance_integrity.sh.
    # Caller must be inside TEST_REPO.
    mkdir -p .claude/hooks
    cp "$BASH_GUARD_SRC" .claude/hooks/pre_bash_trust_root_guard.sh
    sed -i.bak \
        -e "s|__DEV_GUIDE_DST__|v1_claude_code_development_guide_existing.md|g" \
        -e "s|__INIT_PKG_DST__|v1_implementation_package_existing.md|g" \
        .claude/hooks/pre_bash_trust_root_guard.sh
    rm -f .claude/hooks/pre_bash_trust_root_guard.sh.bak
    chmod +x .claude/hooks/pre_bash_trust_root_guard.sh
}

run_bash_guard() {
    # Usage: run_bash_guard '<bash command the agent tried to run>'
    # Feeds a synthetic PreToolUse stdin payload to the real guard script and
    # returns its exit code / stderr, exactly as Claude Code would invoke it.
    # Caller must be inside TEST_REPO with deploy_bash_guard already run.
    local cmd="$1"
    python3 -c "import json,sys; print(json.dumps({'tool_input': {'command': sys.argv[1]}}))" "$cmd" \
        | bash .claude/hooks/pre_bash_trust_root_guard.sh 2>&1
}

teardown_gate_repo() {
    if [ -n "${TEST_REPO:-}" ] && [ -d "$TEST_REPO" ]; then
        rm -rf "$TEST_REPO"
    fi
    if [ -n "${EXTRACTED_FUNCS_FILE:-}" ] && [ -f "$EXTRACTED_FUNCS_FILE" ]; then
        rm -f "$EXTRACTED_FUNCS_FILE"
    fi
}

run_gate() {
    # Usage: run_gate [extra env assignments...]
    # Caller must be inside TEST_REPO.
    # 2>&1: gate.sh writes everything to stderr; redirect so bats `run` captures it in $output.
    env "$@" GATE_STATE=".claude/gate_state.json" bash .githooks/gate.sh 2>&1
}

run_ci_integrity_check() {
    # Invokes the exact same script CI runs (templates/verify_governance_integrity.sh,
    # deployed to .githooks/ by setup_gate_repo) — no hand-duplicated logic to
    # drift out of sync. A prior audit found the previous hand-mirrored copy
    # had gone stale; extracting a single shared script closes that class of
    # drift permanently rather than just re-syncing it once more.
    # Caller must be inside TEST_REPO with .githooks/verify_governance_integrity.sh present.
    bash .githooks/verify_governance_integrity.sh 2>&1
}

run_with_pty() {
    # Usage: run_with_pty <script-path> <answer1> [<answer2> ...]
    # Runs a script under a REAL pty (via Python's pty.fork(), which properly
    # makes the child a session leader with a controlling terminal — unlike
    # pty.openpty()+subprocess.Popen, which does not). Needed for anything
    # that reads confirmation prompts via `</dev/tty` (uninstall.sh's
    # _confirm): plain stdin piping into a `</dev/tty` read is a no-op, since
    # that redirect explicitly bypasses stdin — and worse, in a sandboxed/
    # containerless environment with genuinely no controlling terminal at
    # all, `/dev/tty` fails to open outright ("Device not configured"),
    # which `_confirm` treats as an empty answer -> silently declines every
    # single prompt. A test that pipes into such a script via plain stdin
    # will "pass" no matter what answers are given, because nothing it
    # asserts ever reflects a real confirmation — exactly the false-positive
    # this helper exists to prevent. Echoes combined stdout+stderr, prints
    # "EXIT_CODE:<n>" as the final line for the caller to parse.
    local script_path="$1"
    shift
    python3 - "$script_path" "$@" << 'PYEOF'
import pty, os, sys, time, select

script_path = sys.argv[1]
answers = sys.argv[2:]

pid, fd = pty.fork()
if pid == 0:
    os.execvp("/bin/bash", ["/bin/bash", script_path])
    os._exit(127)

output = b""
for answer in answers:
    # Drain whatever the script has printed so far before sending the next
    # answer — approximates "wait for the next prompt" without depending on
    # matching specific prompt text.
    deadline = time.time() + 5
    while time.time() < deadline:
        r, _, _ = select.select([fd], [], [], 0.2)
        if not r:
            break
        try:
            chunk = os.read(fd, 4096)
        except OSError:
            break
        if not chunk:
            break
        output += chunk
    try:
        os.write(fd, (answer + "\n").encode())
    except OSError:
        break

deadline = time.time() + 5
while time.time() < deadline:
    r, _, _ = select.select([fd], [], [], 0.3)
    if not r:
        break
    try:
        chunk = os.read(fd, 4096)
    except OSError:
        break
    if not chunk:
        break
    output += chunk

_, status = os.waitpid(pid, 0)
exit_code = os.WEXITSTATUS(status) if os.WIFEXITED(status) else 1
sys.stdout.buffer.write(output)
print(f"\nEXIT_CODE:{exit_code}")
PYEOF
}

run_pre_push_hook() {
    # Minimal pre-push bypass-clock logic mirrored from install.sh (for isolated testing).
    # 2>&1: messages go to stderr; redirect so bats `run` captures them in $output.
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
' 2>&1
}
