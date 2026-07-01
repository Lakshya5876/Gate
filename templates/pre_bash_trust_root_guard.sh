#!/usr/bin/env bash
# PreToolUse guard (Bash matcher) — blocks any Bash command that references a
# trust-root governance path, regardless of shell construct (redirection, tee,
# sed -i, python, etc.). Native permissions.deny is prefix-matched only and
# cannot express "the command mentions this path anywhere" — a static deny
# list can never fully close that gap, so this hook inspects the actual
# command text instead. Receives tool input JSON on stdin.
#
# __DEV_GUIDE_DST__ and __INIT_PKG_DST__ are placeholder tokens substituted by
# install.sh's _write_trust_root_settings at deploy time — this file is
# otherwise fully static, which is why it lives in templates/ rather than as
# an inline install.sh heredoc: the bats suite can deploy this exact file
# (with test-repo substitutions) and exercise the real matching logic
# directly, instead of a hand-copied mirror or a no-op stub.
set -euo pipefail

CMD=$(python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_input', {}).get('command', ''))" 2>/dev/null || echo "")
[ -z "$CMD" ] && exit 0

PROTECTED_PATHS=(
    ".githooks/"
    ".claude/hooks/"
    ".claude/gate_integrity.sha256"
    ".claude/gate_state.json"
    ".github/workflows/gate.yml"
    ".mcp.json"
    "__DEV_GUIDE_DST__"
    "__INIT_PKG_DST__"
)
# ".claude/hooks/" self-protects this very script — an agent that overwrites
# it with a no-op would leave its PreToolUse registration in settings.json
# looking intact while the guard silently does nothing. ".claude/gate_state.json"
# is the gate's own ledger (receipts, token spend, audit log); an agent that
# can Write/Edit it directly can fabricate a passing receipt or reset its own
# token budget, which defeats every other control in this chain. ".mcp.json"
# controls which MCP servers Claude Code connects to.
#
# Deliberately excludes .claude/settings.json, CLAUDE.md, and
# .claude/baseline.json: the init prompt legitimately needs to reference
# these via Bash/python during its own generation and merge steps (reading
# current state, programmatic JSON edits). Blocking all mentions of them here
# would block the init prompt from ever doing its job. Those three get their
# write/edit protection from permissions.deny instead, added as the init
# prompt's FINAL step — see the "MERGE, do not regenerate" note in the
# implementation package. Also excludes .claude/checkpoints/ and
# .claude/commands/ and .claude/session_state.json: all three are legitimately
# written by the agent on an ongoing basis (checkpoint protocol, command file
# generation, session tracking) as part of normal operation, not just at init.

for _p in "${PROTECTED_PATHS[@]}"; do
    if [[ "$CMD" == *"$_p"* ]]; then
        printf 'GATE: Bash commands referencing trust-root path '\''%s'\'' are blocked — these files constrain the agent and may only be changed via human-authored PR.\n' "$_p" >&2
        exit 1
    fi
done
exit 0
