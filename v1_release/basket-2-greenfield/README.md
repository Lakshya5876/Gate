# Basket 2 — Greenfield Onboarding

**For teams starting new projects completely from scratch.**

This directory contains the V1 greenfield workflow assets. Use these if you are beginning
a brand-new project with no prior history or debt. The framework acts as a prescriptive
structural blueprint from commit number one — zero tolerance, zero compromise, zero baseline.

There is **no LOC ceiling** for greenfield projects. The enforcement layer is designed for
fresh workspaces and scales with the project as it grows.

## Files in This Directory

| File | Purpose |
|---|---|
| `v1_claude_code_development_guide_new.md` | The greenfield engineering constitution — copy this into your repo as `CLAUDE.md` |
| `v1_implementation_package_new.md` | The one-time init prompt — paste this into Claude Code to scaffold and govern your new project |

## Onboarding Steps

**Step 1 — Initialize a fresh workspace**
Create an empty directory for your new project and initialize a Git repository inside it:
```bash
mkdir my-new-project && cd my-new-project
git init
git checkout -b develop
```
Do not add any files yet. The initialization package will scaffold the correct structure for you.

**Step 2 — Copy the guide into your repository**
Copy `v1_claude_code_development_guide_new.md` into the root of your new repository and
rename it `CLAUDE.md`. This is the engineering constitution Claude Code reads before taking
any action. It defines your four-layer architecture, naming contracts, security invariants,
and enforcement rules from day one.

**Step 3 — Execute the initialization package**
Open Claude Code (CLI or Desktop app) inside your new repository. Paste the full contents
of `v1_implementation_package_new.md` as your first message. Claude Code will automatically:

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
