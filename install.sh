#!/usr/bin/env bash
# install.sh — Claude Code governance framework installer
# Usage: curl -sSL https://raw.githubusercontent.com/BankofLoyal/ai-dev-workflow/init_release/install.sh | bash
# Or:    bash install.sh  (from a local clone)
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
REPO_URL="https://raw.githubusercontent.com/BankofLoyal/ai-dev-workflow/init_release"
FRAMEWORK_VERSION="v1"
GRAPH_PACKAGE="code-review-graph==2.3.6"
ORG_POLICY_PATH="${HOME}/.claude/org_policy.json"
DEFAULT_TOKEN_BUDGET=50000

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; RESET='\033[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────
_info()    { echo -e "${BLUE}[install]${RESET} $*"; }
_success() { echo -e "${GREEN}[install]${RESET} ✓ $*"; }
_warn()    { echo -e "${YELLOW}[install]${RESET} ⚠ $*"; }
_error()   { echo -e "${RED}[install]${RESET} ✗ $*" >&2; exit 1; }

_require() {
    command -v "$1" >/dev/null 2>&1 || _error "$1 is required but not installed. $2"
}

_fetch() {
    # Download a file from REPO_URL/$1 to $2
    local src="$1" dst="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -sSfL "${REPO_URL}/${src}" -o "$dst" || _error "Failed to download ${src}"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$dst" "${REPO_URL}/${src}" || _error "Failed to download ${src}"
    else
        _error "curl or wget required for remote install. For local install, run from inside the ai-dev-workflow clone."
    fi
}

_fetch_or_local() {
    # Use local file if running from inside the repo clone; else fetch from GitHub
    local rel_path="$1" dst="$2"
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "${script_dir}/${rel_path}" ]; then
        cp "${script_dir}/${rel_path}" "$dst"
    else
        _fetch "$rel_path" "$dst"
    fi
}

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
_info "Repository root: ${REPO_ROOT}"

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
    if [ "${LOC:-0}" -gt 200000 ]; then
        _warn "Repository exceeds 200,000 LOC (${LOC} lines)."
        _warn "V1 brownfield framework is validated for ≤200k LOC."
        _warn "For larger repos, hierarchical CLAUDE.md subsystems are required — contact platform team."
        read -r -p "Continue anyway? [y/N]: " LOC_CONFIRM </dev/tty
        [[ "$LOC_CONFIRM" =~ ^[Yy]$ ]] || _error "Aborted. Resolve LOC ceiling before proceeding."
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

_fetch_or_local "$DEV_GUIDE_SRC" "$DEV_GUIDE_DST"
_fetch_or_local "$INIT_PKG_SRC" "$INIT_PKG_DST"
_success "Dev guide copied: ${DEV_GUIDE_DST}"
_success "Init package copied: ${INIT_PKG_DST}"

# ── STEP 3: Scaffold .claude/ directory ───────────────────────────────────────
_info "Scaffolding .claude/ directory..."
mkdir -p .claude/commands .claude/checkpoints

# gate_state.json from template
_fetch_or_local "templates/gate_state.json" ".claude/gate_state.json"
# Stamp today's date into token.token_last_reset
python3 -c "
import json
from datetime import date
with open('.claude/gate_state.json') as f:
    d = json.load(f)
d.setdefault('token', {})['token_last_reset'] = str(date.today())
with open('.claude/gate_state.json', 'w') as f:
    json.dump(d, f, indent=2)
"
_success "gate_state.json created"

# quarantine.txt
if [ ! -f "quarantine.txt" ]; then
    cat > quarantine.txt << 'QUARANTINE'
# QUARANTINE FILE — Claude Code Governance Framework
# Tests listed here are known-flaky and are skipped by gate.sh tier selection.
# Format: one test ID per line (pytest: path::TestClass::test_method)
# Entries require a linked issue and an expiry date comment.
# Example:
#   tests/integration/test_payment.py::TestPayment::test_webhook_timeout  # GH#142 expires 2024-09-01
QUARANTINE
    _success "quarantine.txt created"
fi

# session_state.json (gitignored — ephemeral)
echo '{"mode": null, "complexity_tier": null, "budget_pct_at_selection": null, "timestamp": null}' > .claude/session_state.json
_success "session_state.json created (gitignored)"

# ── STEP 4: Install git hooks ──────────────────────────────────────────────────
_info "Installing git hooks..."
mkdir -p .githooks

# gate.sh from template
_fetch_or_local "templates/gate.sh" ".githooks/gate.sh"
chmod +x .githooks/gate.sh

# pre-commit hook
cat > .githooks/pre-commit << 'PRECOMMIT'
#!/usr/bin/env bash
# pre-commit — delegates to gate.sh
# SKIP_GATE=1 is a TTY-guarded bypass with git-note audit trail.
set -euo pipefail

if [ "${SKIP_GATE:-0}" = "1" ]; then
    # TTY guard: bypass must be typed interactively — cannot be piped
    if [ ! -t 0 ] && [ ! -t 1 ]; then
        echo "SKIP_GATE=1 is only valid in an interactive TTY. Aborting." >&2
        exit 1
    fi
    read -r -p "Bypass reason (required): " BYPASS_REASON </dev/tty
    if [ -z "$BYPASS_REASON" ]; then
        echo "Bypass reason is required. Aborting." >&2
        exit 1
    fi
    COMMITTER_DATE=$(git var GIT_COMMITTER_DATE 2>/dev/null | awk '{print $1}')
    git notes --ref=refs/notes/bypasses append HEAD -m "BYPASS | date=${COMMITTER_DATE} | reason=${BYPASS_REASON}" 2>/dev/null || true
    echo "⚠ Gate bypassed. Reason logged to refs/notes/bypasses." >&2
    exit 0
fi

GATE_TRIGGER=pre-commit exec "$(git rev-parse --git-dir)"/../.githooks/gate.sh
PRECOMMIT
chmod +x .githooks/pre-commit

# pre-push hook
cat > .githooks/pre-push << 'PREPUSH'
#!/usr/bin/env bash
# pre-push — protected branch guard + fingerprint receipt check
set -euo pipefail

PROTECTED_BRANCHES="main master develop"
RED='\033[0;31m'; RESET='\033[0m'

while IFS=' ' read -r LOCAL_REF LOCAL_SHA REMOTE_REF REMOTE_SHA; do
    REMOTE_BRANCH="${REMOTE_REF##refs/heads/}"

    # Block force pushes (refspec starts with +)
    if [[ "$LOCAL_REF" == +* ]]; then
        echo -e "${RED}PRE-PUSH BLOCK: Force push is forbidden.${RESET}" >&2
        exit 1
    fi

    # Block direct pushes to protected branches
    for protected in $PROTECTED_BRANCHES; do
        if [ "$REMOTE_BRANCH" = "$protected" ]; then
            echo -e "${RED}PRE-PUSH BLOCK: Direct push to protected branch '${protected}' is forbidden. Open a PR.${RESET}" >&2
            exit 1
        fi
    done

    # Check for unexpired bypass clock entries (24h policy)
    if git notes --ref=refs/notes/bypasses show HEAD 2>/dev/null | grep -q "BYPASS"; then
        BYPASS_DATE=$(git notes --ref=refs/notes/bypasses show HEAD 2>/dev/null | grep -oE 'date=[0-9]+' | head -1 | cut -d= -f2)
        NOW_EPOCH=$(date +%s)
        if [ -n "$BYPASS_DATE" ] && [ $(( NOW_EPOCH - BYPASS_DATE )) -lt 86400 ]; then
            echo -e "${YELLOW}⚠ Active bypass within 24h window — pushing with audit note intact.${RESET}" >&2
        fi
    fi
done

# Run gate.sh for push-time checks
GATE_TRIGGER=pre-push exec "$(git rev-parse --git-dir)"/../.githooks/gate.sh
PREPUSH
chmod +x .githooks/pre-push

# Configure git to use .githooks/
git config core.hooksPath .githooks
_success "Git hooks installed (.githooks/)"

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
  "_comment": "Org-wide Claude Code token budget ceiling. Repos inherit this value and cannot exceed it.",
  "_edit_policy": "Changes require a human PR — never agent-modified.",
  "TOKEN_BUDGET": ${DEFAULT_TOKEN_BUDGET},
  "HARD_BLOCK_AT_100_PCT": true,
  "WARN_AT_PCT": 80
}
ORGPOLICY
    _success "Org policy created: ${ORG_POLICY_PATH} (TOKEN_BUDGET=${DEFAULT_TOKEN_BUDGET})"
else
    CURRENT_BUDGET=$(python3 -c "import json; d=json.load(open('${ORG_POLICY_PATH}')); print(d.get('TOKEN_BUDGET','not set'))" 2>/dev/null || echo "unreadable")
    _info "Org policy already exists: TOKEN_BUDGET=${CURRENT_BUDGET}"
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
        cd "$REPO_ROOT"
        "${GRAPH_BIN_PATH}" build \
            --include "*.py,*.ts,*.tsx,*.js,*.go,*.rs,*.java" \
            --include "*.sql,migrations/**" \
            --include "Dockerfile*,docker-compose*.yml,*.tf,*.hcl" \
            --include ".github/workflows/*.yml,.circleci/config.yml" \
            --include "nginx.conf,*.conf,.env.example" \
            --exclude ".git/,node_modules/,.venv/,dist/,build/,__pycache__/" \
            2>&1 | tail -5 || _warn "Graph build failed — graph mode inactive until resolved."

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
echo "  ✓ Git hooks:      .githooks/ (pre-commit, pre-push, gate.sh)"
echo "  ✓ Org policy:     ${ORG_POLICY_PATH} (TOKEN_BUDGET=${DEFAULT_TOKEN_BUDGET})"
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
echo "  2. Paste the full contents of ${INIT_PKG_DST} as your"
echo "     first message. Claude Code will:"
echo "     • Generate CLAUDE.md (repo-specific constitution)"
echo "     • Generate stack-specific gate.sh commands"
echo "     • Complete the governance scaffold"
echo "     • Run Phase C verification"
echo ""
echo "  After the init commit, your repo is fully governed."
echo ""
