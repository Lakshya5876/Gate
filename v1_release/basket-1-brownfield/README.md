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

**Step 1 — Clone ai-dev-workflow**
```bash
git clone <repository_url>
cd ai-dev-workflow
```

**Step 2 — Verify LOC ceiling (in your target repository)**
Navigate to your target repository and run:
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
Confirm your repo is under 1,000,000 LOC. If it is, continue.

**Step 3 — Run the installer**
From within the ai-dev-workflow directory, run:
```bash
./install.sh
```
This will scaffold `.claude/`, `.githooks/`, and copy governance files into your target repository.

**Step 4 — Copy the guide into your repository**
Copy `v1_claude_code_development_guide_existing.md` into the root of your target repository,
keeping the filename exactly as-is. The init prompt reads it from disk — Claude Code uses it
to generate the `CLAUDE.md` constitution tailored to your specific repository's architecture.

**Step 5 — Execute the initialization package**
Open Claude Code (CLI or Desktop app) inside your target repository. Create a new setup branch:
```bash
git checkout -b chore/claude-init
```
Then locate the "SYSTEM PROMPT" section in `v1_implementation_package_existing.md` and paste **ONLY THAT SECTION** as your first message. Do not paste the entire document.
Claude Code will run automated repository reconnaissance, map your existing architecture,
freeze the current technical debt baseline, and wire all git hooks — one time, fully automated.

After the init commit lands, your repository is a governed, hook-enforced agentic engineering
environment. Every subsequent session operates under the constitution and enforcement layer
established during init.

## 🧪 Pre-Commit Testing (Opt-In)

To keep your commits blazingly fast, global test suites (like `pytest` or `npm test`) are **skipped by default** during the pre-commit hook.

* **To run tests:** You must explicitly pass the `--run-tests=true` flag in your commit message.
  * *Example:* `git commit -m "fix: corrected auth flow --run-tests=true"`
* If you omit this flag, the gate will only run linting and formatting checks to preserve your momentum.
