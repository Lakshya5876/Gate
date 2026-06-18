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

**Step 1 — Clone ai-dev-workflow**
```bash
git clone <repository_url>
cd ai-dev-workflow
```

**Step 2 — Initialize a fresh workspace**
Create an empty directory for your new project and initialize a Git repository inside it:
```bash
mkdir my-new-project && cd my-new-project
git init
git checkout -b develop
```
Do not add any files yet. The initialization package will scaffold the correct structure for you.

**Step 3 — Run the installer**
From within the ai-dev-workflow directory, run:
```bash
./install.sh
```
This will scaffold `.claude/`, `.githooks/`, and copy governance files into your new project.

**Step 4 — Copy the guide into your repository**
Copy `v1_claude_code_development_guide_new.md` into the root of your new repository,
keeping the filename exactly as-is. The init prompt reads it from disk — Claude Code uses it
to generate the `CLAUDE.md` constitution prescribing your four-layer architecture, naming
contracts, security invariants, and enforcement rules from day one.

**Step 5 — Execute the initialization package**
Open Claude Code (CLI or Desktop app) inside your new repository. Locate the "SYSTEM PROMPT" section
in `v1_implementation_package_new.md` and paste **ONLY THAT SECTION** as your first message. Claude Code will automatically:

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

## 🧪 Pre-Commit Testing (Opt-In)

To keep your commits blazingly fast, global test suites (like `pytest` or `npm test`) are **skipped by default** during the pre-commit hook.

* **To run tests:** You must explicitly pass the `--run-tests=true` flag in your commit message.
  * *Example:* `git commit -m "feat: new user signup endpoint --run-tests=true"`
* If you omit this flag, the gate will only run linting and formatting checks to preserve your momentum.
