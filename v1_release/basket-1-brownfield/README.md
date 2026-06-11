# Basket 1 — Brownfield Onboarding

**For teams with existing, active codebases.**

This directory contains the V1 brownfield workflow assets. Use these if your repository
already has code, history, and pre-existing technical debt. The framework meets you where
you are — it freezes existing debt in a baseline ledger and enforces that debt can only
decrease from that point forward, never increase.

## V1 LOC Ceiling — Run This First

This package carries a hard ceiling of **≤ 200,000 Lines of Code**. Before doing anything
else, verify your repository is within bounds.

Run this command at your project root:

```bash
find . -type f \
  -not -path "*/.git/*" \
  -not -path "*/node_modules/*" \
  -not -path "*/.venv/*" \
  -not -path "*/__pycache__/*" \
  -not -path "*/vendor/*" \
  -not -path "*/dist/*" \
  -not -path "*/build/*" \
  -not -path "*/.next/*" \
  | xargs wc -l 2>/dev/null | tail -1
```

If the `total` on the last line is **> 200,000**, stop here. This package is not compatible
with your repository in V1. Wait for the V2 Enterprise Monorepo release.

## Files in This Directory

| File | Purpose |
|---|---|
| `v1_claude_code_development_guide_existing.md` | The engineering constitution — copy this into your repo as `CLAUDE.md` |
| `v1_implementation_package_existing.md` | The one-time init prompt — paste this into Claude Code to run automated repository reconnaissance |

## Onboarding Steps

**Step 1 — Verify LOC ceiling**
Run the command above. Confirm your repo is under 200,000 LOC. If it is, continue.

**Step 2 — Copy the guide into your repository**
Copy `v1_claude_code_development_guide_existing.md` into the root of your target repository
and rename it `CLAUDE.md`. This becomes the engineering constitution Claude Code reads before
taking any action in that repository.

**Step 3 — Execute the initialization package**
Open Claude Code (CLI or Desktop app) inside your target repository. Create a new setup branch:
```bash
git checkout -b chore/claude-init
```
Then paste the full contents of `v1_implementation_package_existing.md` as your first message.
Claude Code will run automated repository reconnaissance, map your existing architecture,
freeze the current technical debt baseline, and wire all git hooks — one time, fully automated.

After the init commit lands, your repository is a governed, hook-enforced agentic engineering
environment. Every subsequent session operates under the constitution and enforcement layer
established during init.
