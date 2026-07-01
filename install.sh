#!/usr/bin/env bash
# install.sh — Claude Code governance framework installer
# Usage: ./install.sh  (must be run from within the cloned repository)
#
# What this does:
#   1. Detects basket (greenfield vs brownfield) and validates preconditions
#   2. Downloads and copies governance files into the target repo
#   3. Installs git hooks and configures core.hooksPath
#   4. Installs code-review-graph MCP server (pipx — zero user knowledge required)
#   5. Builds the initial multi-domain graph
#   6. Writes .mcp.json (project-scoped, committed — not global settings)
#   7. Scaffolds org-level token policy if absent
#   8. Prints the one remaining human step (paste the init prompt)
#
# NOTE ON graphify: safishamsi/graphify was evaluated and rejected — unnaturally
# high star count (68k, likely botted) indicates unverified provenance. Multi-domain
# graph coverage (SQL, infra, CI) is achieved here via code-review-graph extended
# file patterns instead.

set -euo pipefail

# ── Constants ──────────────────────────────────────────────────────────────────
FRAMEWORK_VERSION="v1"
FRAMEWORK_SEMVER="1.0.0"
GRAPH_PACKAGE="code-review-graph==2.3.6"
ORG_POLICY_PATH="${HOME}/.claude/org_policy.json"
DEFAULT_WEEKLY_LIMIT=1250000
DEFAULT_DAILY_BUDGET_PCT=20

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; RESET='\033[0m'

# ── Helpers (defined before first use) ────────────────────────────────────────
_info()    { echo -e "${BLUE}[install]${RESET} $*"; }
_success() { echo -e "${GREEN}[install]${RESET} ✓ $*"; }
_warn()    { echo -e "${YELLOW}[install]${RESET} ⚠ $*"; }
_error()   { echo -e "${RED}[install]${RESET} ✗ $*" >&2; exit 1; }

_require() {
    command -v "$1" >/dev/null 2>&1 || _error "$1 is required but not installed. $2"
}

_fetch() {
    # Copy a file from the local REPO_DIR to $2
    local src="$1" dst="$2"
    local src_path="${REPO_DIR}/${src}"

    if [ ! -f "$src_path" ]; then
        _error "File not found: ${src_path}"
    fi

    cp "$src_path" "$dst" || _error "Failed to copy ${src} to ${dst}"
}

_write_hooks() {
    # Write gate.sh, pre-commit, and pre-push into .githooks/ and configure git.
    # Called from the fresh-install flow (STEP 4) and from _upgrade().
    mkdir -p .githooks

    _fetch "templates/gate.sh" ".githooks/gate.sh"
    chmod +x .githooks/gate.sh

    # Single source of truth for the governance-file integrity check, invoked
    # identically by CI (ci-gate.yml) and the bats test suite. Extracted out
    # of ci-gate.yml specifically so the two can never drift out of sync with
    # each other again (a prior audit found a hand-duplicated copy had gone
    # stale). Lives under .githooks/ deliberately — it's already covered by
    # the existing trust-root deny-list and Bash guard hook without any
    # further changes to either.
    _fetch "templates/verify_governance_integrity.sh" ".githooks/verify_governance_integrity.sh"
    chmod +x .githooks/verify_governance_integrity.sh

    # Both are fully static (no per-repo interpolation) — extracted to
    # templates/ alongside gate.sh and verify_governance_integrity.sh so the
    # bats test fixture can deploy the exact real files instead of a
    # hand-maintained mirror, and so they're covered by the same integrity
    # manifest as every other static governance script.
    _fetch "templates/pre-commit" ".githooks/pre-commit"
    chmod +x .githooks/pre-commit

    _fetch "templates/pre-push" ".githooks/pre-push"
    chmod +x .githooks/pre-push

    git config core.hooksPath .githooks
}

_write_trust_root_settings() {
    # Scaffold .claude/settings.json (permissions.deny) + the Bash trust-root
    # guard hook. Both are universal — identical across every consumer repo,
    # no repo-specific discovery needed — so this is mechanized here rather
    # than left to the init prompt to transcribe by hand from the
    # implementation-package guide. Called from the fresh-install flow and
    # from _upgrade() (which backfills it for repos installed before this
    # existed). Repo-specific allow-list entries remain the init prompt's job.
    local dev_guide_dst="$1" init_pkg_dst="$2"
    mkdir -p .claude/hooks

    # Fully static except for two placeholder tokens, substituted below — see
    # templates/pre_bash_trust_root_guard.sh's own header comment for why this
    # is a real template rather than an inline heredoc: it lets the bats
    # suite exercise the ACTUAL matching logic (not a stub) by deploying this
    # exact file with test-specific substitutions.
    _fetch "templates/pre_bash_trust_root_guard.sh" ".claude/hooks/pre_bash_trust_root_guard.sh"
    sed -i.bak \
        -e "s|__DEV_GUIDE_DST__|${dev_guide_dst}|g" \
        -e "s|__INIT_PKG_DST__|${init_pkg_dst}|g" \
        .claude/hooks/pre_bash_trust_root_guard.sh
    rm -f .claude/hooks/pre_bash_trust_root_guard.sh.bak
    chmod +x .claude/hooks/pre_bash_trust_root_guard.sh

    # Single canonical source for the trust-root deny-list. There used to be
    # a hand-duplicated JSON literal (fresh-write) and Python literal (merge)
    # that had, so far, stayed in sync only by luck — the same drift shape
    # that caused the CI/test duplication fixed in Module A8. Collapsed to one
    # script, one list, two code paths (create vs. merge) selected by
    # os.path.exists, so there is nothing left to keep hand-synced.
    python3 - "$dev_guide_dst" "$init_pkg_dst" << 'PYEOF'
import json, sys, os

dev_guide_dst, init_pkg_dst = sys.argv[1], sys.argv[2]

REQUIRED_DENY = [
    "Bash(git reset --hard*)", "Bash(git rebase*)", "Bash(git clean*)",
    "Bash(rm -rf*)", "Bash(sudo*)", "Bash(DROP *)", "Bash(TRUNCATE *)",
    "Bash(DELETE FROM *)", "Bash(nc *)", "Bash(ssh *)", "Bash(scp *)",
    "Bash(git push --force*)", "Bash(git push -f*)",
    "Bash(git push --force-with-lease*)", "Bash(git push --mirror*)",
    "Bash(git push --delete*)", "Bash(git commit --no-verify*)",
    "Bash(git commit -n *)", "Bash(git push --no-verify*)",
    "Bash(git -c core.hooksPath*)", "Bash(SKIP_GATE=*)",
    "Read(.env)", "Read(**/.env)", "Read(**/.env.*)", "Read(**/*.pem)",
    "Read(**/id_rsa*)", "Read(**/.aws/credentials)",
    "Bash(cat .env*)", "Bash(cat **/.env*)", "Bash(cat **/*.pem*)",
    "Bash(cat **/id_rsa*)", "Bash(cat **/.aws/credentials*)",
    "Write(.githooks/**)", "Edit(.githooks/**)",
    "Write(.claude/hooks/**)", "Edit(.claude/hooks/**)",
    "Write(.claude/gate_integrity.sha256)", "Edit(.claude/gate_integrity.sha256)",
    "Write(.claude/gate_state.json)", "Edit(.claude/gate_state.json)",
    "Write(.github/workflows/gate.yml)", "Edit(.github/workflows/gate.yml)",
    "Write(.mcp.json)", "Edit(.mcp.json)",
    f"Write({dev_guide_dst})", f"Edit({dev_guide_dst})",
    f"Write({init_pkg_dst})", f"Edit({init_pkg_dst})",
    "Bash(git notes*remove*)", "Bash(git update-ref -d*)",
    "Bash(git config core.hooksPath*)", "Bash(git config --add core.hooksPath*)",
    "Bash(git commit -a*)", "Bash(git commit -am*)", "Bash(git commit --amend*)",
]
# Deliberately excludes Write/Edit(.claude/settings.json), Write/Edit(CLAUDE.md),
# and Write/Edit(.claude/baseline.json): those three don't exist yet at
# install time and the init prompt must be able to create them. They're added
# as the init prompt's own FINAL edit, preserving the original
# write-settings-json-last guarantee exactly (Module A6/A7 CRITICAL EXECUTION
# ORDER). Also deliberately excludes .claude/checkpoints/**, .claude/commands/**,
# and .claude/session_state.json — all legitimately agent-written on an
# ongoing basis (checkpoint protocol, command generation, session tracking),
# not install-time artifacts.

BASH_GUARD_HOOK_ENTRY = {
    "matcher": "Bash",
    "hooks": [{"type": "command", "command": "bash .claude/hooks/pre_bash_trust_root_guard.sh"}]
}

if os.path.exists('.claude/settings.json'):
    with open('.claude/settings.json') as f:
        d = json.load(f)
    perms = d.setdefault('permissions', {})
    perms.setdefault('defaultMode', 'default')
    deny = perms.setdefault('deny', [])
    added = [e for e in REQUIRED_DENY if e not in deny]
    deny.extend(added)

    hooks = d.setdefault('hooks', {})
    pretool = hooks.setdefault('PreToolUse', [])
    has_bash_guard = any(
        h.get('matcher') == 'Bash' and
        any('pre_bash_trust_root_guard.sh' in hh.get('command', '') for hh in h.get('hooks', []))
        for h in pretool
    )
    if not has_bash_guard:
        pretool.append(BASH_GUARD_HOOK_ENTRY)
        added.append("hooks.PreToolUse[Bash guard]")

    with open('.claude/settings.json', 'w') as f:
        json.dump(d, f, indent=2)

    if added:
        print(f"Added {len(added)} missing trust-root protection(s) to existing .claude/settings.json")
    else:
        print("Existing .claude/settings.json already has all trust-root protections")
else:
    d = {
        "permissions": {"defaultMode": "default", "deny": REQUIRED_DENY},
        "hooks": {"PreToolUse": [BASH_GUARD_HOOK_ENTRY]},
    }
    with open('.claude/settings.json', 'w') as f:
        json.dump(d, f, indent=2)
    print(".claude/settings.json scaffolded (trust-root deny-list + Bash guard hook — mechanical, not advisory)")
PYEOF

    # Multi-file CI integrity manifest — covers every static, install.sh-owned
    # governance script, not just gate.sh. Computed HERE (after this function
    # has written pre_bash_trust_root_guard.sh, and after _write_hooks — always
    # called first — has written gate.sh/verify_governance_integrity.sh/
    # pre-commit/pre-push) so every listed file already exists on disk.
    # Regenerated on every fresh install AND every --upgrade, so it never
    # drifts from what's actually deployed. Uses sha256sum/shasum's native
    # manifest format (`<hash>  <path>` per line) so verify_governance_integrity.sh
    # can check it with a single `-c` invocation instead of hand-rolled compares.
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum \
            .githooks/gate.sh \
            .githooks/verify_governance_integrity.sh \
            .githooks/pre-commit \
            .githooks/pre-push \
            .claude/hooks/pre_bash_trust_root_guard.sh \
            > .claude/gate_integrity.sha256
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 \
            .githooks/gate.sh \
            .githooks/verify_governance_integrity.sh \
            .githooks/pre-commit \
            .githooks/pre-push \
            .claude/hooks/pre_bash_trust_root_guard.sh \
            > .claude/gate_integrity.sha256
    else
        _error "Could not compute integrity manifest (need sha256sum or shasum)."
    fi
}

_upgrade() {
    cd "$REPO_ROOT"

    [ -f ".claude/gate_state.json" ] || _error "--upgrade requires an existing governed repo (.claude/gate_state.json not found)."

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " Claude Code Governance Framework — Upgrade to ${FRAMEWORK_SEMVER}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    _info "Re-copying gate.sh and hooks..."
    _write_hooks
    _success "Hooks updated."

    # Backfill the trust-root settings.json scaffold for repos installed before
    # it existed. Detect basket from whichever dev-guide filename is present —
    # DEV_GUIDE_DST/INIT_PKG_DST aren't set in this flow the way they are in
    # fresh install, since --upgrade never re-runs basket detection.
    if [ -f "v1_claude_code_development_guide_new.md" ]; then
        _write_trust_root_settings "v1_claude_code_development_guide_new.md" "v1_implementation_package_new.md"
    elif [ -f "v1_claude_code_development_guide_existing.md" ]; then
        _write_trust_root_settings "v1_claude_code_development_guide_existing.md" "v1_implementation_package_existing.md"
    else
        _warn "Could not detect basket (no dev guide found) — skipping trust-root settings.json backfill. Run install.sh's fresh-install flow if this repo predates the dev guide copy step."
    fi
    _success "Trust-root settings.json checked/backfilled."

    # CI workflow is force-overwritten on upgrade (unlike fresh install which skips if exists)
    mkdir -p .github/workflows
    _fetch "templates/ci-gate.yml" ".github/workflows/gate.yml"
    _success "CI gate workflow updated (.github/workflows/gate.yml)"

    # Bump version in gate_state.json, preserve all user-owned fields
    python3 - << PYEOF
import json
from datetime import datetime, timezone
with open('.claude/gate_state.json') as f:
    d = json.load(f)
d['framework_version'] = '${FRAMEWORK_SEMVER}'
d['framework_last_upgrade'] = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
with open('.claude/gate_state.json', 'w') as f:
    json.dump(d, f, indent=2)
PYEOF
    _success "gate_state.json: framework_version → ${FRAMEWORK_SEMVER}"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN} Upgrade complete${RESET}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "What was updated:"
    echo "  ✓ .githooks/gate.sh"
    echo "  ✓ .githooks/verify_governance_integrity.sh"
    echo "  ✓ .githooks/pre-commit"
    echo "  ✓ .githooks/pre-push"
    echo "  ✓ .claude/gate_integrity.sha256 (re-pinned — multi-file manifest covering gate.sh,"
    echo "    verify_governance_integrity.sh, pre-commit, pre-push, and the Bash-guard hook)"
    echo "  ✓ .claude/settings.json (trust-root deny-list + Bash guard hook — backfilled if missing)"
    echo "  ✓ .claude/hooks/pre_bash_trust_root_guard.sh"
    echo "  ✓ .github/workflows/gate.yml"
    echo "  ✓ .claude/gate_state.json: framework_version → ${FRAMEWORK_SEMVER}"
    echo ""
    echo "What was preserved:"
    echo "  • .claude/baseline.json (debt ratchet — untouched)"
    echo "  • CLAUDE.md (repo constitution — untouched)"
    echo "  • .mcp.json (graph config — untouched)"
    echo "  • gate_state.json: receipts, token data, thresholds, core_files"
    echo "  • Any repo-specific permissions.allow entries already in settings.json"
    echo ""
    echo "This upgrade re-pinned .claude/gate_integrity.sha256 — CI will fail until"
    echo "the new manifest is committed alongside every file it covers. Get this"
    echo "reviewed like any other change to the enforcement boundary, not rubber-stamped."
    echo ""
    echo "Commit the upgrade to activate it for the whole team:"
    echo "  git add .githooks/ .claude/gate_integrity.sha256 .claude/settings.json .claude/hooks/ .github/workflows/gate.yml .claude/gate_state.json"
    echo "  git commit -m 'chore: upgrade governance framework to ${FRAMEWORK_SEMVER}'"
    echo ""
}

# Locate the ai-dev-workflow framework directory (helpers exist now, so _error works)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -f "${SCRIPT_DIR}/v1_release/basket-1-brownfield/v1_implementation_package_existing.md" ]; then
    _error "Framework files not found. Ensure you cloned ai-dev-workflow. Usage: cd <your-target-repo> && /path/to/ai-dev-workflow/install.sh"
fi
REPO_DIR="${SCRIPT_DIR}"

# ── Argument parsing ──────────────────────────────────────────────────────────
UPGRADE_MODE=false
for _arg in "$@"; do
    case "$_arg" in
        --upgrade) UPGRADE_MODE=true ;;
        *) _error "Unknown argument: ${_arg}. Usage: ./install.sh [--upgrade]" ;;
    esac
done

# ── STEP 0: Preflight checks ──────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Claude Code Governance Framework — ${FRAMEWORK_VERSION} Installer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

_require git "Install git from https://git-scm.com/"
_require python3 "Install Python 3.8+ from https://python.org/"

# Must be inside a git repo
git rev-parse --git-dir >/dev/null 2>&1 || _error "Not inside a git repository. Run 'git init' first."

REPO_ROOT=$(git rev-parse --show-toplevel)

# Guard: refuse to govern the ai-dev-workflow repo itself
if [ "$REPO_ROOT" = "$SCRIPT_DIR" ]; then
    _error "You are inside the ai-dev-workflow framework repo — not your target repo.
       cd into the repo you want to govern, then run:
         ${SCRIPT_DIR}/install.sh"
fi

_info "Repository root: ${REPO_ROOT}"

# Upgrade short-circuit — skip basket selection and all scaffolding
if $UPGRADE_MODE; then _upgrade; exit 0; fi

# Claude Code CLI check — advisory only, not a hard block
if ! command -v claude >/dev/null 2>&1; then
    _warn "Claude Code CLI not found. Install from https://claude.ai/download — required for the final init step."
fi

# ── STEP 1: Basket selection ──────────────────────────────────────────────────
echo ""
echo "Which type of repository is this?"
echo "  [g] Greenfield — new project, no prior history"
echo "  [b] Brownfield — existing repository with code"
echo ""
read -r -p "Enter g or b: " BASKET_INPUT </dev/tty

case "$BASKET_INPUT" in
    g|G|green|greenfield) BASKET="greenfield" ;;
    b|B|brown|brownfield) BASKET="brownfield" ;;
    *) _error "Invalid input '${BASKET_INPUT}'. Enter 'g' or 'b'." ;;
esac
_info "Basket: ${BASKET}"

# LOC advisory for brownfield
if [ "$BASKET" = "brownfield" ]; then
    echo ""
    _info "Checking repository size..."
    LOC=$(find . -not -path './.git/*' -type f | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
    _info "Approximate LOC: ${LOC}"
    if [ "${LOC:-0}" -gt 1000000 ]; then
        _error "Repository exceeds 1,000,000 LOC (${LOC} lines). V1 framework is certified for ≤1M LOC only."
    fi
fi

# ── STEP 2: Copy governance files ────────────────────────────────────────────
echo ""
_info "Copying governance files..."

cd "$REPO_ROOT"

# Dev guide (copied as-is with v1_ prefix — init prompt reads it, generates CLAUDE.md from it)
if [ "$BASKET" = "greenfield" ]; then
    DEV_GUIDE_SRC="v1_release/basket-2-greenfield/v1_claude_code_development_guide_new.md"
    DEV_GUIDE_DST="v1_claude_code_development_guide_new.md"
    INIT_PKG_SRC="v1_release/basket-2-greenfield/v1_implementation_package_new.md"
    INIT_PKG_DST="v1_implementation_package_new.md"
else
    DEV_GUIDE_SRC="v1_release/basket-1-brownfield/v1_claude_code_development_guide_existing.md"
    DEV_GUIDE_DST="v1_claude_code_development_guide_existing.md"
    INIT_PKG_SRC="v1_release/basket-1-brownfield/v1_implementation_package_existing.md"
    INIT_PKG_DST="v1_implementation_package_existing.md"
fi

_fetch "$DEV_GUIDE_SRC" "$DEV_GUIDE_DST"
_fetch "$INIT_PKG_SRC" "$INIT_PKG_DST"
_success "Dev guide copied: ${DEV_GUIDE_DST}"
_success "Init package copied: ${INIT_PKG_DST}"

# ── STEP 3: Scaffold .claude/ directory ───────────────────────────────────────
_info "Scaffolding .claude/ directory..."
mkdir -p .claude/commands .claude/checkpoints

# gate_state.json from template
_fetch "templates/gate_state.json" ".claude/gate_state.json"
# Stamp today's date into token.token_last_reset
python3 -c "
import json
from datetime import date
with open('.claude/gate_state.json') as f:
    d = json.load(f)
d.setdefault('token', {})['token_last_reset'] = str(date.today())
d['framework_version'] = '${FRAMEWORK_SEMVER}'
with open('.claude/gate_state.json', 'w') as f:
    json.dump(d, f, indent=2)
"
_success "gate_state.json created"


# session_state.json (gitignored — ephemeral)
echo '{"mode": null, "complexity_tier": null, "budget_pct_at_selection": null, "timestamp": null}' > .claude/session_state.json
_success "session_state.json created (gitignored)"

# baseline.json — brownfield only. Seeded UNPOPULATED here; the init prompt
# (Phase C/D) fills lint_findings once LINT_CMD is known, then sets populated=true.
# gate.sh treats an unpopulated baseline as zero-tolerance until it is filled.
if [ "$BASKET" = "brownfield" ] && [ ! -f ".claude/baseline.json" ]; then
    HEAD_SHA_NOW=$(git rev-parse HEAD 2>/dev/null || echo "INIT")
    cat > .claude/baseline.json << BASELINE
{
  "_comment": "Identity-based debt baseline. gate.sh grandfathers these findings and blocks any NEW identity. Identity = '<normalized_path>|<rule_code>'. Committed team state — edited only via human-authored PR.",
  "ratchet_mode": "identity",
  "populated": false,
  "generated_at": null,
  "generated_from_sha": "${HEAD_SHA_NOW}",
  "lint_findings": [],
  "summary": { "lint_count": 0 }
}
BASELINE
    _success "baseline.json seeded (unpopulated — init prompt fills it)"
fi

# ── STEP 4: Install git hooks ──────────────────────────────────────────────────
_info "Installing git hooks..."
_write_hooks
_success "Git hooks installed (.githooks/)"

# ── STEP 4a: Trust-root settings.json (deny-list + Bash guard hook) ──────────
_info "Scaffolding trust-root protections (.claude/settings.json)..."
_write_trust_root_settings "$DEV_GUIDE_DST" "$INIT_PKG_DST"
_success "Trust-root protections in place (mechanical, not left to the init prompt)."

# CI parity workflow — the authoritative backstop if local hooks are stripped.
mkdir -p .github/workflows
if [ ! -f ".github/workflows/gate.yml" ]; then
    _fetch "templates/ci-gate.yml" ".github/workflows/gate.yml"
    _success "CI gate workflow installed (.github/workflows/gate.yml)"
else
    _warn ".github/workflows/gate.yml already exists — left unchanged. Compare against templates/ci-gate.yml manually."
fi

# Bypass note refspecs (so bypass audit trail leaves the machine)
git config --add remote.origin.push  'refs/notes/bypasses:refs/notes/bypasses' 2>/dev/null || true
git config --add remote.origin.fetch '+refs/notes/bypasses:refs/notes/bypasses' 2>/dev/null || true
_success "Bypass note refspecs configured"

# ── STEP 5: Org-level token policy ───────────────────────────────────────────
_info "Checking org-level token policy..."
mkdir -p "${HOME}/.claude"

if [ ! -f "$ORG_POLICY_PATH" ]; then
    cat > "$ORG_POLICY_PATH" << ORGPOLICY
{
  "_comment": "Org-wide Claude Code token budget. Daily limit = WEEKLY_LIMIT x DAILY_BUDGET_PCT / 100.",
  "_edit_policy": "Changes require a human PR — never agent-modified.",
  "WEEKLY_LIMIT": ${DEFAULT_WEEKLY_LIMIT},
  "DAILY_BUDGET_PCT": ${DEFAULT_DAILY_BUDGET_PCT},
  "HARD_BLOCK_AT_100_PCT": true,
  "WARN_AT_PCT": 80
}
ORGPOLICY
    DAILY_LIMIT=$(( DEFAULT_WEEKLY_LIMIT * DEFAULT_DAILY_BUDGET_PCT / 100 ))
    _success "Org policy created: ${ORG_POLICY_PATH} (WEEKLY_LIMIT=${DEFAULT_WEEKLY_LIMIT}, daily cap=${DAILY_LIMIT})"
else
    CURRENT_WEEKLY=$(python3 -c "import json; d=json.load(open('${ORG_POLICY_PATH}')); print(d.get('WEEKLY_LIMIT', d.get('TOKEN_BUDGET','not set')))" 2>/dev/null || echo "unreadable")
    _info "Org policy already exists: WEEKLY_LIMIT=${CURRENT_WEEKLY}"
fi

# ── STEP 6: MCP graph server installation ────────────────────────────────────
echo ""
_info "Installing code-review-graph MCP server (zero-knowledge — this is automatic)..."

# Ensure pipx is available
if ! command -v pipx >/dev/null 2>&1; then
    _info "pipx not found — installing..."
    if command -v pip3 >/dev/null 2>&1; then
        pip3 install --user pipx --quiet || _error "Failed to install pipx. Install manually: pip3 install --user pipx"
        # Add pipx bin to PATH for this session
        export PATH="${HOME}/.local/bin:${PATH}"
    else
        _error "pip3 not found. Install Python 3 with pip: https://python.org/"
    fi
fi

# Install the graph package (pinned exact version — security requirement)
_info "Installing ${GRAPH_PACKAGE}..."
pipx install "${GRAPH_PACKAGE}" --force --quiet 2>&1 | tail -3 || {
    _warn "code-review-graph install failed. Graph mode will be inactive. Continuing..."
    GRAPH_INSTALLED=false
}
GRAPH_INSTALLED="${GRAPH_INSTALLED:-true}"

if $GRAPH_INSTALLED; then
    # Detect bin path
    GRAPH_BIN=$(pipx environment --value PIPX_BIN_DIR 2>/dev/null || echo "${HOME}/.local/bin")
    GRAPH_BIN_PATH="${GRAPH_BIN}/code-review-graph"

    if [ ! -f "$GRAPH_BIN_PATH" ]; then
        _warn "code-review-graph binary not found at ${GRAPH_BIN_PATH}. Trying PATH..."
        GRAPH_BIN_PATH=$(command -v code-review-graph 2>/dev/null || echo "")
    fi

    if [ -n "$GRAPH_BIN_PATH" ] && [ -f "$GRAPH_BIN_PATH" ]; then
        _success "code-review-graph installed: ${GRAPH_BIN_PATH}"

        # Build the initial graph with multi-domain config
        _info "Building initial code graph (multi-domain: code + SQL + infra + CI)..."
        _info "This may take 2–5 minutes on large repositories (>100k LOC). Progress updates below."
        cd "$REPO_ROOT"

        # Background the build with a progress monitor (10-minute timeout for 1M LOC repos)
        if command -v timeout >/dev/null 2>&1; then
            if timeout 600 "${GRAPH_BIN_PATH}" build \
                --include "*.py,*.ts,*.tsx,*.js,*.go,*.rs,*.java" \
                --include "*.sql,migrations/**" \
                --include "Dockerfile*,docker-compose*.yml,*.tf,*.hcl" \
                --include ".github/workflows/*.yml,.circleci/config.yml" \
                --include "nginx.conf,*.conf,.env.example" \
                --exclude ".git/,node_modules/,.venv/,dist/,build/,__pycache__/" \
                2>&1 | while IFS= read -r line; do
                    # Emit progress every 5 lines of output
                    _info "Graph: $line"
                done; then
                :  # Build succeeded
            else
                EXIT_CODE=$?
                if [ $EXIT_CODE -eq 124 ]; then
                    _warn "Graph build exceeded 10-minute timeout. This repository may exceed 1M LOC. Continuing without graph."
                else
                    _warn "Graph build failed (exit $EXIT_CODE). Graph mode inactive until resolved."
                fi
            fi
        else
            # Fallback for systems without timeout command
            "${GRAPH_BIN_PATH}" build \
                --include "*.py,*.ts,*.tsx,*.js,*.go,*.rs,*.java" \
                --include "*.sql,migrations/**" \
                --include "Dockerfile*,docker-compose*.yml,*.tf,*.hcl" \
                --include ".github/workflows/*.yml,.circleci/config.yml" \
                --include "nginx.conf,*.conf,.env.example" \
                --exclude ".git/,node_modules/,.venv/,dist/,build/,__pycache__/" \
                2>&1 | tail -10 || _warn "Graph build failed — graph mode inactive until resolved."
        fi

        # Write .mcp.json — project-scoped, committed (NOT ~/.claude/settings.json)
        # Rationale: .mcp.json travels with the repo so every team member gets graph
        # mode automatically on clone, without per-developer setup.
        cat > .mcp.json << MCPJSON
{
  "_comment": "Project-scoped MCP server config — committed so all team members get graph mode on clone.",
  "_do_not_move_to_settings": "This file must remain in the project root, not in ~/.claude/settings.json.",
  "mcpServers": {
    "code-review-graph": {
      "command": "${GRAPH_BIN_PATH}",
      "args": ["serve"],
      "env": {
        "PROJECT_ROOT": "."
      }
    }
  }
}
MCPJSON
        _success ".mcp.json written (project root, committed)"

        # Verify graph is live
        _info "Verifying graph server..."
        GRAPH_STATUS=$("${GRAPH_BIN_PATH}" status 2>&1 || echo "unavailable")
        if echo "$GRAPH_STATUS" | grep -qi "healthy\|running\|ok\|nodes"; then
            _success "Graph server healthy: ${GRAPH_STATUS}"
            # Update gate_state.json with graph metadata
            python3 -c "
import json, re
from datetime import datetime, timezone
with open('.claude/gate_state.json') as f:
    d = json.load(f)
node_match = re.search(r'(\d+)\s*nodes?', '${GRAPH_STATUS}', re.IGNORECASE)
d.setdefault('mcp_graph', {})['last_build_timestamp'] = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
d['mcp_graph']['node_count'] = int(node_match.group(1)) if node_match else 0
with open('.claude/gate_state.json', 'w') as f:
    json.dump(d, f, indent=2)
" 2>/dev/null || true
        else
            _warn "Graph server not responding. Graph mode inactive until 'code-review-graph build' is run."
        fi
    else
        _warn "Could not locate code-review-graph binary. Graph mode inactive."
    fi
fi

# ── STEP 7: .gitignore additions ─────────────────────────────────────────────
_info "Updating .gitignore..."
GITIGNORE_ENTRIES=(
    ".claude/session_state.json"
    ".claude/session_spend.tmp"
    ".claude/git_cache.json"
    ".claude/checkpoints/"
    ".env"
    ".env.*"
)
for entry in "${GITIGNORE_ENTRIES[@]}"; do
    if ! grep -qF "$entry" .gitignore 2>/dev/null; then
        echo "$entry" >> .gitignore
    fi
done
# .mcp.json is NOT gitignored — it must be committed for team-wide graph activation
_success ".gitignore updated"

# ── STEP 8: Summary and handoff ───────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN} Installation complete${RESET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "What was installed:"
echo "  ✓ Dev guide:      ${DEV_GUIDE_DST}"
echo "  ✓ Init package:   ${INIT_PKG_DST}"
echo "  ✓ Gate ledger:    .claude/gate_state.json"
echo "  ✓ Git hooks:      .githooks/ (pre-commit, pre-push, gate.sh, verify_governance_integrity.sh)"
echo "  ✓ Integrity pin:  .claude/gate_integrity.sha256 (multi-file manifest — CI verifies all 5 governance scripts against this)"
echo "  ✓ Trust-root deny: .claude/settings.json (permissions.deny + Bash guard hook — mechanical)"
echo "  ✓ CI workflow:    .github/workflows/gate.yml (CI parity backstop)"
if [ "$BASKET" = "brownfield" ]; then
echo "  ✓ Debt baseline:  .claude/baseline.json (unpopulated — init prompt fills it)"
fi
echo "  ✓ Org policy:     ${ORG_POLICY_PATH} (WEEKLY_LIMIT=${DEFAULT_WEEKLY_LIMIT}, daily=$(( DEFAULT_WEEKLY_LIMIT * DEFAULT_DAILY_BUDGET_PCT / 100 )) tokens)"
if $GRAPH_INSTALLED 2>/dev/null; then
echo "  ✓ Graph server:   code-review-graph ${GRAPH_PACKAGE##*==} (${GRAPH_BIN_PATH})"
echo "  ✓ MCP config:     .mcp.json (committed — team-wide graph activation)"
else
echo "  ⚠ Graph server:   skipped (install manually: pipx install ${GRAPH_PACKAGE})"
fi
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE} ONE REMAINING STEP — required to complete setup:${RESET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  1. Open Claude Code in this directory:"
echo "     claude"
echo ""
echo "  2. In ${INIT_PKG_DST}, locate the 'SYSTEM PROMPT' section."
echo "     Paste ONLY that section as your first message."
echo "     Claude Code will:"
echo "     • Generate CLAUDE.md (repo-specific constitution)"
echo "     • Generate stack-specific gate.sh commands"
echo "     • Complete the governance scaffold"
echo "     • Run Phase C verification"
echo ""
echo "  3. Keep ${INIT_PKG_DST} locally for reference — do NOT paste"
echo "     the entire document, only the SYSTEM PROMPT section."
echo ""
echo "  After the init commit, your repo is fully governed."
echo ""
