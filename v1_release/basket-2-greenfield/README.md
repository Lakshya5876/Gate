# Basket 2 — Greenfield Onboarding

> [!CRITICAL]
> **🔴 CRITICAL: Paste ONLY the 'SYSTEM PROMPT' section of `v1_implementation_package_new.md`**
>
> Do NOT paste the entire document. Locate the section marked "SYSTEM PROMPT" at the top of the file and paste only that into Claude Code. Keep the rest of the document locally for reference.

> [!IMPORTANT]
> **START HERE: open [`v1_implementation_package_new.md`](v1_implementation_package_new.md) and read it end to end before doing anything else.**
> It contains the pre-flight checklist and the exact prompt to paste into Claude Code to scaffold and govern your new project.
>
> The other file — `v1_claude_code_development_guide_new.md` — is the engineering constitution for **Claude Code to read**, not you.
> You will copy it into your new repository as it is; the agent internalises it automatically. You do not need to read it yourself.

**For teams starting new projects completely from scratch.**

This directory contains the V1 greenfield workflow assets. Use these if you are beginning
a brand-new project with no prior history or debt. The framework acts as a prescriptive
structural blueprint from commit number one — zero tolerance, zero compromise, zero baseline.

There is **no LOC ceiling** for greenfield projects. The enforcement layer is designed for
fresh workspaces and scales with the project as it grows.

## Files in This Directory

| File | Purpose |
|---|---|
| `v1_claude_code_development_guide_new.md` | The greenfield engineering constitution — copy this into your repo root as-is; the init prompt reads it from disk and Claude Code generates `CLAUDE.md` from it |
| `v1_implementation_package_new.md` | The one-time init prompt — paste this into Claude Code to scaffold and govern your new project |

## Installation

The installer always writes into **the repository you are standing in** (it resolves the
target with `git rev-parse --show-toplevel`). Clone the framework once, then run it *from
inside your new project* using the framework's path.

**Step 1 — Clone the framework once (anywhere)**
```bash
git clone <repository_url> ~/tools/ai-dev-workflow
```

**Step 2 — Initialize a fresh workspace**
```bash
mkdir my-new-project && cd my-new-project
git init
git checkout -b chore/claude-init
git commit --allow-empty -m "chore: repository birth"
```

**Step 3 — Run the installer by its path (from inside your new project)**
```bash
~/tools/ai-dev-workflow/install.sh        # choose [g] greenfield when prompted
```
The installer copies the dev guide + init package into your project root, scaffolds
`.claude/`, wires `.githooks/`, and installs the CI parity workflow at
`.github/workflows/gate.yml`.

**Step 4 — Execute the initialization package**
Open Claude Code (CLI or Desktop app) in your new project. Locate the "SYSTEM PROMPT" section
in `v1_implementation_package_new.md` and paste **ONLY THAT SECTION** as your first message.
Claude Code will automatically:

- Scaffold the four-layer directory structure:
  - `domain/` — pure data contracts and Pydantic models, zero framework dependencies
  - `application/` — business logic orchestration, cache, and service operations
  - `infrastructure/` — all database queries, external API clients, tool execution
  - `presentation/` — HTTP routes, request parsing, response serialisation, auth enforcement
- Wire all git hooks (pre-commit security scan, pre-push fingerprint gate)
- Install the shell aliases (`cc-feature`, `cc-push`, `cc-checkpoint`)
- Create the `.claude/` governance directory with the gate script and settings lockdown

After the init commit lands, your project has a fully governed, ideally structured foundation.
Every feature you build from that point forward is enforced against the constitution automatically.

## 🧪 Testing — Opt-In at Commit, Mechanical at Push

Tests are **opt-in at pre-commit** so day-to-day commits stay fast, but **mandatory and
mechanical** at the points that protect the codebase — code cannot leave your machine or
merge untested.

| Stage | Tests run? | How |
|---|---|---|
| `git commit` (normal) | Opt-in | Add `--run-tests=true` to the commit message to run them |
| `git commit` touching a **CORE_FILES** path | **Always (TIER-3)** | Full suite forced automatically — no flag needed |
| `git push` | **Always** | Pre-push runs the full suite (or verifies a passing pre-commit receipt for the exact tree) |
| CI (`.github/workflows/gate.yml`) | **Always** | Authoritative backstop even if local hooks were stripped |

* **Run tests at commit:** `git commit -m "feat: new user signup endpoint --run-tests=true"`
* **Coverage gate:** when a coverage command is configured at init, coverage below the
  threshold (default 80%) blocks the commit/push.
* For a greenfield repo there is no debt baseline — lint is zero-tolerance from commit #1.
