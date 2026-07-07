# 03 — Repo Map

_What this covers: an annotated index of every important file and directory — what it is, who owns it, whether it's safe to edit, and how it's wired in._

"Safe to edit?" is from the perspective of *you, the new maintainer, working on the framework*. **TRUST ROOT** means it is (or becomes, once installed) a governance-critical file: change it only through a reviewed PR, and expect the integrity manifest / CODEOWNERS to be involved in target repos. See [`02-ARCHITECTURE.md`](02-ARCHITECTURE.md) → "Trust-root lockdown."

## Top level

| Path | What it is | Owner | Safe to edit? | Wired in via |
|------|-----------|-------|---------------|--------------|
| `install.sh` | The installer + `--upgrade` engine. ~1,220 lines of bash. Copies templates into a target repo, scaffolds `.claude/`, wires hooks, installs the graph MCP, writes CODEOWNERS/org-policy. | Framework maintainer | **TRUST ROOT** — with care + tests | Run by a human from inside a target repo |
| `uninstall.sh` | Removes every framework artifact from a target repo (local + global), with separate prompts for human-authored files. | Framework maintainer | **TRUST ROOT** — with care + tests | Run by a human |
| `README.md` | Framework front door: prerequisites, active branch, tooling coverage. **Protected in this handoff — do not edit.** | Framework maintainer | Yes (not in this task) | GitHub landing page |
| `.gitignore` | Ignores `.DS_Store`, `__pycache__/`, `*.pyc`. | Framework maintainer | Yes | git |
| `handoff_cursor.md` | **Prior** Cursor-focused handoff doc (references branch `init_release`, "V1"). Overlaps this package. Referenced by `README.md:60`. | Historical | Deletion candidate — **not touched** (see below) | Linked from `README.md` |
| `presentation.html`, `presentation_2.html`, `impact_metrics.html` | Pitch/demo assets. **Protected — do not edit.** | Framework maintainer / GTM | Yes (not in this task) | Opened in a browser | 
| `handoff/` | **This package.** New-owner documentation + the relocated `ultimate_harness.md`. | You | Yes | Read by humans |
| `handoff/ultimate_harness.md` | ~5,000-line engineering curriculum, relocated here. Legacy/reference; written against commit `a7d3c04`. | Historical | Reference only | Standalone reading |

## `templates/` — the files that get deployed into target repos

Everything here is the *source of truth* for what a governed repo runs. Nearly all of it is **TRUST ROOT** once installed.

| Path | What it is | Deployed as | Safe to edit? |
|------|-----------|-------------|---------------|
| `templates/gate.sh` | **The engine.** ~1,327 lines. All enforcement logic (branch guard, tokens, scope, secrets, layer boundary, lint/type/complexity, tests/coverage, receipts, graph upkeep). | `.githooks/gate.sh` | **TRUST ROOT** — see [`05-DEV-SETUP.md`](05-DEV-SETUP.md) for the safe procedure |
| `templates/pre-commit` | Pre-commit hook: SKIP_GATE bypass handling + `exec gate.sh`. | `.githooks/pre-commit` | **TRUST ROOT** |
| `templates/pre-push` | Pre-push hook: force-push/protected-branch/bypass-clock guards + `exec gate.sh`. | `.githooks/pre-push` | **TRUST ROOT** |
| `templates/verify_governance_integrity.sh` | Shared integrity checker (`sha256sum -c` the manifest). Used by CI **and** the bats suite. | `.githooks/verify_governance_integrity.sh` | **TRUST ROOT** |
| `templates/pre_bash_trust_root_guard.sh` | Claude Code Bash PreToolUse guard (lexical + `cd`-tracking path scanner). | `.claude/hooks/pre_bash_trust_root_guard.sh` | **TRUST ROOT** |
| `templates/graph_freshness_check.py` | PreToolUse hook warning on stale graph queries. | `.claude/hooks/graph_freshness_check.py` | **TRUST ROOT** |
| `templates/checkpoint_tool.py` | Mechanical checkpoint capture + progressive-disclosure retrieval. | `.claude/checkpoint_tool.py` | **TRUST ROOT** (its data isn't; the tool is) |
| `templates/checkpoint_search_command.md` | The `/checkpoint-search` slash command body. | `.claude/commands/checkpoint-search.md` | Yes (content) |
| `templates/ci-gate.yml` | The CI parity workflow. | `.github/workflows/gate.yml` | **TRUST ROOT** |
| `templates/gate_state.json` | The ledger template: thresholds, branch strategy, token config, receipts, core_files. | `.claude/gate_state.json` | **TRUST ROOT** (schema) |
| `templates/.pylintrc.layer-boundary` | AST-based pylint supplement for layer-boundary (Python). | wired into target `LINT_CMD` at init | Yes |
| `templates/eslint-layer-boundary.snippet.cjs` | AST-based ESLint supplement for layer-boundary (JS/TS). | merged into target ESLint config at init | Yes |

## `v1_release/` — the human onboarding + constitution content

| Path | What it is | Read by | Safe to edit? |
|------|-----------|---------|---------------|
| `v1_release/README.md` | Framework overview + two-basket strategy + safety pillars. **Protected — do not edit.** | Humans | Yes (not in this task) |
| `basket-1-brownfield/README.md` | Brownfield onboarding + LOC-ceiling precheck. | Humans | Yes |
| `basket-1-brownfield/v1_implementation_package_existing.md` | Brownfield init prompt (source for `/init-governance`). | Human first, then Claude | **TRUST ROOT** after install (agent write-denied) |
| `basket-1-brownfield/v1_claude_code_development_guide_existing.md` | Brownfield engineering constitution → becomes `CLAUDE.md`. | Claude Code | Content, carefully |
| `basket-2-greenfield/README.md` | Greenfield onboarding. | Humans | Yes |
| `basket-2-greenfield/v1_implementation_package_new.md` | Greenfield init prompt (source for `/init-governance`). | Human first, then Claude | **TRUST ROOT** after install |
| `basket-2-greenfield/v1_claude_code_development_guide_new.md` | Greenfield engineering constitution → becomes `CLAUDE.md`. | Claude Code | Content, carefully |

The `install.sh --upgrade` flow re-fetches these guide/package files and diffs the dev guide to generate `/reconcile-governance` when content changed (`install.sh:638-674`).

## `docs/` — the human-facing reference (protected in this handoff)

| Path | What it is |
|------|-----------|
| `docs/HUMAN_COMMIT_FLOW.md` | Step-by-step of what `git commit` does; human-vs-agent accounting; token behavior; TIER-3; SKIP_GATE. The best plain-English companion to `gate.sh`. |
| `docs/SECURITY_POSTURE.md` | Auditor-facing: data flows, zero network at gate time, SOC 2 control mapping, and an unusually honest threat model / "what it does not protect against." |
| `docs/UPGRADE.md` | What `--upgrade` overwrites vs. preserves, the reconcile flow, and post-upgrade commit command. |

## `.github/` (framework's own)

| Path | What it is | Note |
|------|-----------|------|
| `.github/workflows/framework-tests.yml` | **This repo's own CI** — runs `tests/gate/run_tests.sh` (the bats suite) on push/PR to `init_release`/`develop`/`main`. | Distinct from the `gate.yml` the framework *installs* into target repos. |
| `.github/CODEOWNERS` | Assigns trust-root paths to `@platform-security-leads`. Several listed paths only exist in *installed* repos, not here — see [`08-KNOWN-ISSUES-AND-DEBT.md`](08-KNOWN-ISSUES-AND-DEBT.md). | |

## `.claude/` (framework's own)

| Path | What it is |
|------|-----------|
| `.claude/settings.json` | Registers a PreToolUse `Write|Edit|MultiEdit` guard (`pre_tool_write_guard.sh`) for working on the framework itself. |
| `.claude/hooks/pre_tool_write_guard.sh` | Blocks file writes on branches whose `branch_strategy` has `code_writes_permitted=false`. |

## `tests/gate/` — the bats integration suite

~30 `.bats` files exercising the **real** templates (not mirrors) by deploying them into scratch repos. Entry point `tests/gate/run_tests.sh`; shared helpers in `tests/gate/test_helper.bash` (incl. `run_with_pty` for interactive-prompt tests). Notable files map 1:1 to subsystems: `agent_detection.bats`, `bash_guard_logic.bats`, `baseline_ratchet.bats`, `secrets_block.bats`, `layer_boundary_*.bats`, `pre_push_cold_start_scope.bats`, `monorepo_subdir_inference.bats`, `checkpoint_tool.bats`, `ci_integrity_check.bats`, `expired_bypass_block.bats`, `graph_watchdog.bats`, `upgrade_versioning.bats`, `uninstall_*.bats`. See [`05-DEV-SETUP.md`](05-DEV-SETUP.md) for how to run them and the known local-run caveats.

## The deletion candidate, flagged (not acted on)

`handoff_cursor.md` looks superseded by this package, **but it is referenced by the protected `README.md` (line 60)**, so it is *not dead* and was deliberately left in place. Recommended follow-up for a human: either (a) fold its still-relevant content into this `handoff/`, delete it, and update the `README.md` link, or (b) keep it and cross-link. Do not delete it without editing `README.md` first. See the chat summary from the handoff run for the full flag.

---

next: [`04-RUNBOOK.md`](04-RUNBOOK.md)
