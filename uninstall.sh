#!/usr/bin/env bash
# uninstall.sh — Remove every trace of the Claude Code governance framework
#
# Usage: ./uninstall.sh
#
# Removes (local, per-repo):
#   • Dev guide and implementation package files copied to repo root
#   • .githooks/gate.sh, pre-commit, pre-push
#   • git config core.hooksPath (restores git default)
#   • git config remote.origin.{push,fetch} bypass note refspecs
#   • .github/workflows/gate.yml
#   • .mcp.json
#   • .claude/ directory (gate_state.json, baseline.json, session_state.json,
#                         session_spend.tmp, git_cache.json, graph.pid,
#                         checkpoints/, commands/)
#   • quarantine.txt (if it matches the framework template)
#   • Framework entries from .gitignore
#
# Removes (global, machine-wide):
#   • ~/.claude/org_policy.json (if written by install.sh)
#   • code-review-graph pipx package
#
# CLAUDE.md is always handled with a separate explicit prompt — it is generated
# by Claude Code during init and may contain significant human-authored content.

set -euo pipefail

GRAPH_PACKAGE="code-review-graph"
ORG_POLICY_PATH="${HOME}/.claude/org_policy.json"

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; RESET='\033[0m'

_info()    { echo -e "${BLUE}[uninstall]${RESET} $*"; }
_success() { echo -e "${GREEN}[uninstall]${RESET} ✓ $*"; }
_warn()    { echo -e "${YELLOW}[uninstall]${RESET} ⚠ $*"; }
_error()   { echo -e "${RED}[uninstall]${RESET} ✗ $*" >&2; exit 1; }

_rm() {
    local target="$1"
    if [ -e "$target" ] || [ -L "$target" ]; then
        rm -rf "$target"
        _success "Removed: $target"
    fi
}

_confirm() {
    local answer
    read -r -p "$1 [y/N] " answer </dev/tty
    [[ "${answer,,}" == "y" || "${answer,,}" == "yes" ]]
}

# ── Preflight ─────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Claude Code Governance Framework — Uninstaller"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

git rev-parse --git-dir >/dev/null 2>&1 || _error "Not inside a git repository."
REPO_ROOT=$(git rev-parse --show-toplevel)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Guard: refuse to run against the ai-dev-workflow repo itself
if [ "$REPO_ROOT" = "$SCRIPT_DIR" ]; then
    _error "You are inside the ai-dev-workflow framework repo — not your target repo.
       cd into the repo where you ran install.sh, then run:
         ${SCRIPT_DIR}/uninstall.sh"
fi

cd "$REPO_ROOT"

[ -f ".claude/gate_state.json" ] || _error "No governed repo detected (.claude/gate_state.json not found). Nothing to remove."

# ── Build removal manifest ────────────────────────────────────────────────────
_info "Scanning for installed framework artifacts..."

LOCAL_FILES=()
LOCAL_DIRS=()
GITCONFIG_ENTRIES=()
GITIGNORE_ENTRIES=()

# Dev guide and init package (either basket)
for f in \
    "v1_claude_code_development_guide_new.md" \
    "v1_claude_code_development_guide_existing.md" \
    "v1_implementation_package_new.md" \
    "v1_implementation_package_existing.md"
do
    [ -f "$f" ] && LOCAL_FILES+=("$f")
done

# quarantine.txt — only if it contains the framework header
if [ -f "quarantine.txt" ] && grep -q "QUARANTINE FILE — Claude Code Governance Framework" quarantine.txt 2>/dev/null; then
    LOCAL_FILES+=("quarantine.txt")
fi

# .githooks entries created by install.sh
for f in ".githooks/gate.sh" ".githooks/pre-commit" ".githooks/pre-push"; do
    [ -f "$f" ] && LOCAL_FILES+=("$f")
done

# CI workflow — only if it contains gate.sh references
if [ -f ".github/workflows/gate.yml" ] && grep -q "gate\.sh" ".github/workflows/gate.yml" 2>/dev/null; then
    LOCAL_FILES+=(".github/workflows/gate.yml")
fi

# .mcp.json
[ -f ".mcp.json" ] && grep -q "code-review-graph" ".mcp.json" 2>/dev/null && LOCAL_FILES+=(".mcp.json")

# .claude/ directory
[ -d ".claude" ] && LOCAL_DIRS+=(".claude")

# git config entries
if git config --get core.hooksPath 2>/dev/null | grep -q "^\.githooks$" 2>/dev/null; then
    GITCONFIG_ENTRIES+=("core.hooksPath (.githooks)")
fi
if git config --get-all remote.origin.push 2>/dev/null | grep -q "refs/notes/bypasses" 2>/dev/null; then
    GITCONFIG_ENTRIES+=("remote.origin.push bypass refspec")
fi
if git config --get-all remote.origin.fetch 2>/dev/null | grep -q "refs/notes/bypasses" 2>/dev/null; then
    GITCONFIG_ENTRIES+=("remote.origin.fetch bypass refspec")
fi

# .gitignore entries added by install.sh
FRAMEWORK_GITIGNORE_ENTRIES=(
    ".claude/session_state.json"
    ".claude/session_spend.tmp"
    ".claude/git_cache.json"
    ".claude/checkpoints/"
)
if [ -f ".gitignore" ]; then
    for entry in "${FRAMEWORK_GITIGNORE_ENTRIES[@]}"; do
        grep -qF "$entry" .gitignore 2>/dev/null && GITIGNORE_ENTRIES+=("$entry")
    done
fi

# ── Print manifest ─────────────────────────────────────────────────────────────
echo "Everything below will be permanently removed from ${REPO_ROOT}:"
echo ""

if [ ${#LOCAL_FILES[@]} -gt 0 ]; then
    echo "  Files:"
    for f in "${LOCAL_FILES[@]}"; do echo "    • $f"; done
fi
if [ ${#LOCAL_DIRS[@]} -gt 0 ]; then
    echo "  Directories:"
    for d in "${LOCAL_DIRS[@]}"; do echo "    • $d/ (and all contents)"; done
fi
if [ ${#GITCONFIG_ENTRIES[@]} -gt 0 ]; then
    echo "  Git config:"
    for c in "${GITCONFIG_ENTRIES[@]}"; do echo "    • $c"; done
fi
if [ ${#GITIGNORE_ENTRIES[@]} -gt 0 ]; then
    echo "  .gitignore entries:"
    for e in "${GITIGNORE_ENTRIES[@]}"; do echo "    • $e"; done
fi

echo ""
echo "  Global (machine-wide):"
[ -f "$ORG_POLICY_PATH" ] && echo "    • ${ORG_POLICY_PATH}" || echo "    • ${ORG_POLICY_PATH} (not found — skipping)"
if command -v pipx >/dev/null 2>&1 && pipx list 2>/dev/null | grep -q "$GRAPH_PACKAGE"; then
    echo "    • pipx package: ${GRAPH_PACKAGE}"
else
    echo "    • pipx package: ${GRAPH_PACKAGE} (not installed — skipping)"
fi

CLAUDE_MD_NOTE=""
if [ -f "CLAUDE.md" ]; then
    echo ""
    echo "  CLAUDE.md: exists — will be handled with a separate prompt"
    CLAUDE_MD_NOTE="yes"
fi

echo ""

# ── Single confirmation ────────────────────────────────────────────────────────
_confirm "Remove everything listed above?" || { echo "Aborted."; exit 0; }

echo ""
_info "Removing framework artifacts..."

# ── Local files ────────────────────────────────────────────────────────────────
for f in "${LOCAL_FILES[@]}"; do _rm "$f"; done
for d in "${LOCAL_DIRS[@]}"; do _rm "$d"; done

# Remove .githooks/ directory if now empty
if [ -d ".githooks" ] && [ -z "$(ls -A .githooks 2>/dev/null)" ]; then
    rmdir .githooks
    _success "Removed empty directory: .githooks/"
fi

# ── Git config cleanup ─────────────────────────────────────────────────────────
if git config --get core.hooksPath 2>/dev/null | grep -q "^\.githooks$"; then
    git config --unset core.hooksPath
    _success "Unset git config core.hooksPath (restored to git default)"
fi

while git config --get-all remote.origin.push 2>/dev/null | grep -q "refs/notes/bypasses"; do
    git config --unset remote.origin.push "refs/notes/bypasses:refs/notes/bypasses" 2>/dev/null || break
done
while git config --get-all remote.origin.fetch 2>/dev/null | grep -q "refs/notes/bypasses"; do
    git config --unset remote.origin.fetch "\\+refs/notes/bypasses:refs/notes/bypasses" 2>/dev/null || \
    git config --unset remote.origin.fetch "refs/notes/bypasses" 2>/dev/null || break
done
[ ${#GITCONFIG_ENTRIES[@]} -gt 0 ] && _success "Removed git config bypass note refspecs"

# ── .gitignore cleanup ────────────────────────────────────────────────────────
if [ ${#GITIGNORE_ENTRIES[@]} -gt 0 ] && [ -f ".gitignore" ]; then
    for entry in "${FRAMEWORK_GITIGNORE_ENTRIES[@]}"; do
        python3 -c "
import sys
entry = sys.argv[1]
lines = open('.gitignore').readlines()
open('.gitignore', 'w').writelines(l for l in lines if l.rstrip('\n') != entry)
" "$entry" 2>/dev/null || true
    done
    _success "Removed framework entries from .gitignore"
fi

# ── Global resources ──────────────────────────────────────────────────────────
echo ""
_info "Removing global resources..."

if [ -f "$ORG_POLICY_PATH" ]; then
    if grep -q "Org-wide Claude Code token budget" "$ORG_POLICY_PATH" 2>/dev/null; then
        _rm "$ORG_POLICY_PATH"
    else
        _warn "Skipping ${ORG_POLICY_PATH} — contents appear user-modified. Remove manually if needed."
    fi
fi

if command -v pipx >/dev/null 2>&1 && pipx list 2>/dev/null | grep -q "$GRAPH_PACKAGE"; then
    pipx uninstall "$GRAPH_PACKAGE" --quiet 2>&1 | tail -3 || \
        _warn "pipx uninstall failed — remove manually: pipx uninstall ${GRAPH_PACKAGE}"
    _success "Removed pipx package: ${GRAPH_PACKAGE}"
fi

# ── CLAUDE.md — always a separate explicit prompt ──────────────────────────────
if [ -n "$CLAUDE_MD_NOTE" ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    _warn "CLAUDE.md was not removed automatically."
    echo ""
    echo "  CLAUDE.md is generated by Claude Code during init and may"
    echo "  contain significant human-authored architectural decisions."
    echo ""
    if _confirm "Remove CLAUDE.md permanently?"; then
        _rm "CLAUDE.md"
    else
        _warn "Kept: CLAUDE.md — remove manually if desired."
    fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN} Uninstall complete${RESET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "To commit the removal:"
echo "  git add -u"
echo "  git commit -m 'chore: remove Claude Code governance framework'"
echo ""
