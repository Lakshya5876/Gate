# V1 Release — Enterprise AI Development Governance Framework

## What This Framework Does

This framework is a **plug-and-play mechanical cage** that embeds un-bypassable enterprise
governance directly inside an ultra-smooth developer workflow. It does not slow engineers down —
it automates quality, security, and architecture compliance so that senior-grade output becomes
the floor, not the ceiling.

When a developer uses this framework, every commit, push, and PR automatically passes through:
- Scoped security scanning (hunk-intersection, not full-file noise)
- Layer architecture enforcement (no business logic in routes, no SQL in services)
- An identity-based technical debt ratchet (existing debt is frozen; it cannot grow)
- A cryptographic fingerprint gate (working-tree state is matched at pre-push)
- A checkpoint system that preserves decision context across sessions

## Two-Basket Deployment Strategy

The framework ships in two variants — one for each type of codebase your org will encounter.

| Basket | Directory | Target | Approach |
|---|---|---|---|
| Basket 1 — Brownfield | `basket-1-brownfield/` | Existing, active repositories with pre-existing debt | Maps the repo at init, freezes debt in a baseline ledger, enforces that debt can only decrease — never increase. Every bypass is recorded with an identity receipt and a 24-hour server-replicated deadline via Git Notes. |
| Basket 2 — Greenfield | `basket-2-greenfield/` | Brand-new projects starting from commit zero | Prescriptive structural blueprint. No baseline — zero tolerance from day one. The four-layer scaffold (domain, application, infrastructure, presentation) is enforced from the first commit. |

## Contents

| Path | File | Purpose |
|---|---|---|
| `basket-1-brownfield/` | `v1_claude_code_development_guide_existing.md` | Full brownfield engineering constitution — layer rules, naming contracts, security invariants, enforcement mechanics |
| `basket-1-brownfield/` | `v1_implementation_package_existing.md` | One-time init prompt — runs automated repo recon, freezes debt baseline, wires all git hooks |
| `basket-2-greenfield/` | `v1_claude_code_development_guide_new.md` | Full greenfield engineering constitution — prescriptive from commit one |
| `basket-2-greenfield/` | `v1_implementation_package_new.md` | One-time init prompt — scaffolds four-layer directory structure and wires all git hooks |

## Core Safety Pillars

### 24-Hour Bypass Debt Clock via Server-Replicated Git Notes
Every time a developer bypasses a gate (skips a failing test, overrides the ratchet), the
bypass is recorded as a Git Note attached to the commit. Git Notes are pushed to the remote
via a dedicated refspec (`refs/notes/gate-bypasses`), making the audit trail server-replicated
and visible to CI. Each bypass carries an identity receipt (author, timestamp, justification)
and a 24-hour resolution deadline. CI fails the next pipeline if the bypass is not resolved
within the window.

### Trust-Root Lockdown
Claude Code is denied Write and Edit access to its own constraint files:
`.githooks/**`, `.claude/settings.json`, `baseline.json`, and `CLAUDE.md`.
The agent cannot modify the rules it operates under. All changes to governance files
require a human developer action.

### Identity-Based Debt Ratchet
Technical debt is tracked by finding identity — not by count. The ratchet stores a normalized
token hash per finding so that whitespace and formatting changes do not re-trigger the debt
clock. Debt can only decrease over time; any new finding not present at baseline is a
hard-blocking violation.

### Cryptographic Fingerprint Gate
A working-tree fingerprint (tree hash + staged diff + unstaged diff + untracked file hashes)
is computed at session start and matched at pre-push. If the fingerprint does not match, the
push is blocked until the session ledger is reconciled.

## V1 Constraints

- Brownfield basket: **≤ 200,000 LOC** per repository (see basket-1-brownfield README for the mandatory pre-check command)
- Greenfield basket: no LOC ceiling — designed for fresh projects
- V2 Enterprise Monorepo release will lift the brownfield LOC ceiling and add hierarchical CLAUDE.md support
