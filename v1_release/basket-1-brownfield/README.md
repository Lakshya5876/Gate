# Basket 1 — Brownfield Onboarding

> [!CRITICAL]
> **🔴 CRITICAL: Paste ONLY the 'SYSTEM PROMPT' section of `v1_implementation_package_existing.md`**
>
> Do NOT paste the entire document. Locate the section marked "SYSTEM PROMPT" at the top of the file and paste only that into Claude Code. Keep the rest of the document locally for reference.

> [!IMPORTANT]
> **START HERE: open [`v1_implementation_package_existing.md`](v1_implementation_package_existing.md) and read it end to end before doing anything else.**
> It contains the pre-flight checklist, the LOC ceiling check, and the exact prompt to paste into Claude Code.
>
> The other file — `v1_claude_code_development_guide_existing.md` — is the engineering constitution for **Claude Code to read**, not you.
> You will copy it into your target repository as it is; the agent internalises it automatically. You do not need to read it yourself.

**For teams with existing, active codebases.**

This directory contains the V1 brownfield workflow assets. Use these if your repository
already has code, history, and pre-existing technical debt. The framework meets you where
you are — it freezes existing debt in a baseline ledger and enforces that debt can only
decrease from that point forward, never increase.

## V1 LOC Ceiling — Run This First

This package carries a hard ceiling of **≤ 1,000,000 Lines of Code**. Before doing anything
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

If the `total` on the last line is **> 1,000,000**, stop here. This package is not compatible
with your repository in V1. Contact the platform team for monorepo governance assistance.

## Files in This Directory

| File | Purpose |
|---|---|
| `v1_claude_code_development_guide_existing.md` | The engineering constitution — copy this into your repo root as-is; the init prompt reads it from disk and Claude Code generates `CLAUDE.md` from it |
| `v1_implementation_package_existing.md` | The one-time init prompt — paste this into Claude Code to run automated repository reconnaissance |

## Installation

The installer always writes into **the repository you are standing in** (it resolves the
target with `git rev-parse --show-toplevel`). So you clone the framework once, then run it
*from inside your target repo* using the framework's path. Do **not** run it from inside the
`ai-dev-workflow` clone — that would govern the framework itself.

**Step 1 — Clone the framework once (anywhere)**
```bash
git clone <repository_url> ~/tools/ai-dev-workflow
```

**Step 2 — Enter your target repository and verify the LOC ceiling**
```bash
cd /path/to/your-target-repo
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
Confirm the `total` is under 1,000,000 LOC. If it is, continue.

**Step 3 — Create a setup branch and run the installer by its path**
```bash
git checkout -b chore/claude-init
~/tools/ai-dev-workflow/install.sh        # choose [b] brownfield when prompted
```
The installer copies the dev guide + init package into your repo root, scaffolds `.claude/`
(including an unpopulated `baseline.json`), wires `.githooks/`, and installs the CI parity
workflow at `.github/workflows/gate.yml`.

**Step 4 — Execute the initialization package**
Open Claude Code (CLI or Desktop app) in your target repository. Locate the "SYSTEM PROMPT"
section in `v1_implementation_package_existing.md` and paste **ONLY THAT SECTION** as your
first message. Do not paste the entire document. Claude Code runs automated reconnaissance,
maps your architecture, populates the debt baseline, and generates `CLAUDE.md` — one time,
fully automated.

After the init commit lands, your repository is a governed, hook-enforced agentic engineering
environment. Every subsequent session operates under the constitution and enforcement layer
established during init.

## 🧪 Testing — Opt-In at Commit, Mechanical at Push

Tests are **opt-in at pre-commit** so day-to-day commits stay fast, but **mandatory and
mechanical** at the points that actually protect the codebase — code cannot leave your
machine or merge untested.

| Stage | Tests run? | How |
|---|---|---|
| `git commit` (normal) | Opt-in | Add `--run-tests=true` to the commit message to run them |
| `git commit` touching a **CORE_FILES** path | **Always (TIER-3)** | Full suite forced automatically — no flag needed |
| `git push` | **Always** | Pre-push runs the full suite (or verifies a passing pre-commit receipt for the exact tree) |
| CI (`.github/workflows/gate.yml`) | **Always** | Authoritative backstop even if local hooks were stripped |

* **Run tests at commit:** `git commit -m "fix: corrected auth flow --run-tests=true"`
* **Coverage gate:** when a coverage command is configured at init, coverage below the
  threshold (default 80%) blocks the commit/push.
* You cannot push untested code — the pre-push hook has no opt-out short of the audited,
  24-hour `SKIP_GATE` bypass.
