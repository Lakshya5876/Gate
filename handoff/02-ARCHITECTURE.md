# 02 — Architecture

_What this covers: one commit walked through the entire gate, end to end, with every step cited to the code; then each major subsystem (agent detection, trust-root lockdown, bypass audit, debt ratchet, token harness, graph MCP). This is the doc to read if you read only one._

Jargon is defined on first use; the full list is in [`06-GLOSSARY.md`](06-GLOSSARY.md).

## The layers, top to bottom

```
Claude Code (the agent)
   │  PreToolUse / PostToolUse / Stop / SessionStart hooks  (.claude/settings.json)
   │    ├─ pre_bash_trust_root_guard.sh   (blocks Bash that touches trust-root paths)
   │    ├─ graph_freshness_check.py        (warns when graph index is stale)
   │    └─ checkpoint_tool.py hooks        (mechanical checkpoint capture)
   ▼
git (the enforcement boundary — applies to agent AND human)
   │    ├─ pre-commit  ─┐
   │    └─ pre-push    ─┴──►  gate.sh   (the deterministic engine)
   ▼
CI (.github/workflows/gate.yml)  ─►  gate.sh in CI mode  (authoritative backstop)
   │    guarded by CODEOWNERS + branch protection  (human-controlled)
```

Two independent things enforce rules: **git hooks** (fast, local, bypassable) and **CI** (slower, remote, un-bypassable if branch protection is on). They run *the same `gate.sh`*, so they cannot drift. The Claude Code hooks above are a *third*, agent-only layer that hardens the first two against an agent disarming itself.

> **Important orientation:** In *this* repo (`Gate`), `gate.sh`, the hooks, and the CI workflow live under `templates/` and are named `templates/gate.sh`, `templates/pre-commit`, `templates/ci-gate.yml`, etc. `install.sh` copies them into a *target* repo as `.githooks/gate.sh`, `.githooks/pre-commit`, `.github/workflows/gate.yml`. All line citations below point at the `templates/` originals.

---

## A single commit through the gate, end to end

You run `git commit -m "feat: add billing endpoint"` on branch `feature/billing`. The `pre-commit` hook (`templates/pre-commit`) fires and `exec`s `gate.sh` with `GATE_TRIGGER=pre-commit` (`templates/pre-commit:57`). Here is exactly what happens, in `gate.sh` order:

1. **Bypass short-circuit (in the hook, before gate.sh).** If `SKIP_GATE=1`, the hook demands an interactive typed reason, records a git note, and exits 0 — but *refuses* in an IDE/non-TTY context rather than hang the editor (`templates/pre-commit:29-55`, `9-27`). Otherwise it execs `gate.sh`.

2. **Crash guard armed.** `gate.sh` sets an `ERR` trap so *any* unhandled non-zero exit is a BLOCK with the offending line number — never a silent pass (`templates/gate.sh:342-349`).

3. **Context anchoring.** If `CLAUDE.md` changed since the last pass (hash drift), print a one-time warning to re-read it (`templates/gate.sh:114-131, 356-357`).

4. **Branch validation.** Direct commits to `main`/`master`/`develop` are blocked (`templates/gate.sh:360-365`). Non-Gitflow branch names warn but don't block (`367-371`). Then `code_writes_permitted` is read from `gate_state.json.branch_strategy[<prefix>]` — `release/*` has it `false`, so no new code on release branches (`373-391`; the value is defined in `templates/gate_state.json:68-74`).

5. **Token harness.** Compute today's budget from `~/.claude/org_policy.json` (`WEEKLY_LIMIT × DAILY_BUDGET_PCT ÷ 100`), fall back to a repo override or 200k/day (`templates/gate.sh:449-477`). Date-roll the daily counter (`479-486`). Add `session_spend.tmp` (tokens the *current agent session* has spent) to today's total (`488-500`). If ≥100% **and** a live session is spending, **hard block** the agent; a human commit (session spend = 0) is never blocked, only warned once/day (`502-540`). This is the human/agent asymmetry — see [Token budget harness](#token-budget-harness).

6. **Graph staleness note.** If `.mcp.json` exists and the graph index is >7 days old, print a once-per-day note (`templates/gate.sh:542-563`).

7. **Determine scan scope.** The gate scans *changed files*, not the whole tree, to stay fast on big repos. It picks the diff base by branch-keyed `last_pass_sha` (incremental), or falls back to a **cold start** (`templates/gate.sh:565-620`). Crucial nuance for CI/pre-push: a checkout has nothing staged, so `git diff --cached` is empty; in CI it diffs against `CI_BASE_SHA`, and pre-push with no base **fails safe by scanning the entire tree** rather than fail-open scanning nothing (`576-613`). Then it classifies `HAS_BACKEND` / `HAS_FRONTEND` from file paths/extensions (`622-629`).

8. **CORE_FILES → TIER-3 escalation.** If any changed file matches a glob in `gate_state.json.core_files[]`, escalate: full test suite (no scoping) + tests forced even at commit (`templates/gate.sh:631-652`, `731-734`, `959-963`).

9. **Tier-3 brainstorming block (agent only).** At pre-commit, if the process is an agent (see [Agent detection](#agent-vs-human-detection)) and the change footprint is ≥5 files with no `.claude/checkpoints/LATEST.md`, block until a design brief exists (`templates/gate.sh:654-669`).

10. **Fingerprints.** Compute `WORKING_TREE_FP` (working-tree state) and `COMMIT_TREE_FP` (the tree being committed). At pre-commit, `COMMIT_TREE_FP = git write-tree` of the index (`templates/gate.sh:671-702`). It also warns about tracked-but-unstaged files that won't be checked (`696-701`).

11. **Pre-push-only checkpoint gate (agent only).** (Skipped at commit.) At pre-push, an agent push touching source without a checkpoint is blocked (`templates/gate.sh:704-729`).

12. **Secrets scan.** `git diff --cached -p` piped through a keyword + well-known-prefix + `BEGIN … PRIVATE KEY` regex, minus placeholder/example lines. Any hit → BLOCK (`templates/gate.sh:736-763`). Deliberately *not* an entropy scanner (limits documented at `737-750` and `docs/SECURITY_POSTURE.md:132`).

13. **Dynamic stack inference + fail-closed.** If `TEST_CMD`/`LINT_CMD`/etc. weren't set at init, infer them from repo topology (pytest.ini, package.json, go.mod, Cargo.toml, pom.xml, gradle) — searching root **and** common subdirs like `backend/`, `frontend/` for the monorepo case (`templates/gate.sh:765-978`). If source changed but *no* test runner is found, **BLOCK** (fail closed, not silent) (`984-993`).

14. **Backend lint (with debt ratchet).** Run the scoped lint. If a populated `baseline.json` exists, compute lint findings by *identity* (`<path>|<rule_code>`, line excluded) and block only identities **not** in the baseline; otherwise zero-tolerance (`templates/gate.sh:1025-1084`). See [Debt ratchet](#debt-ratchet).

15. **Backend type check** (`templates/gate.sh:1086-1094`), then **layer-boundary scan** — grep changed files in known layer dirs for SQL-in-routes/services, HTTP-in-services, framework-imports-in-domain, across Python/Java/JS (`1096-1183`).

16. **Tests + coverage.** At pre-commit tests are opt-in (add `[run-tests]` / `--run-tests` to the message, or set `RUN_TESTS=true`); they're forced at pre-push/CI/TIER-3 (`templates/gate.sh:17-24`, `731-734`). If they run, coverage is parsed from `COVERAGE_CMD` output and blocked below threshold (default 80%) (`1185-1259`). The final PASS line reports `tests=none|ran|skipped` so a corner-cutter can't misread a skip as a pass (`1212-1219`, `1325`).

17. **Complexity** (`templates/gate.sh:1261-1270`), then **frontend lint/type** if configured (`1272-1291`).

18. **All checks passed → advance ledger + write receipt.** Only *here*, after everything exits 0, does it write branch-keyed `last_pass_sha`, update token spend, clear `session_spend.tmp`, and write a receipt keyed by `COMMIT_TREE_FP` (`templates/gate.sh:1293-1311`). Writing the SHA earlier would poison the ledger on a mid-run block (`1294-1296`).

19. **Graph upkeep + audit.** Kick a background graph rebuild if changed files are graph-relevant, run the crash watchdog at pre-push, append a `pass` audit entry, and print the green `GATE PASS: …` summary (`templates/gate.sh:1313-1326`).

### Then you `git push`

The `pre-push` hook (`templates/pre-push`) first does its *own* checks — force-push block, bypass-refspec-tamper block, protected-branch block (exact + `release/*`), and the 24-hour bypass clock (`templates/pre-push:15-62`) — then execs `gate.sh` with `GATE_TRIGGER=pre-push` (`66`). In gate.sh, pre-push computes `COMMIT_TREE_FP` from the HEAD tree and takes the **receipt fast-path**: if a passing receipt exists for that exact tree, it exits 0 immediately (`templates/gate.sh:678-685`). No receipt → it forces `RUN_TESTS=true` and runs the full mechanical verification before allowing the push (`686-688`).

### And CI runs it anyway

On the PR, `.github/workflows/gate.yml` (from `templates/ci-gate.yml`) checks out full history, verifies the integrity manifest, resolves `CI_BASE_SHA`, best-effort installs the target repo's own deps, and runs `gate.sh` with `GATE_TRIGGER=ci RUN_TESTS=true` (`templates/ci-gate.yml`). This is the backstop for a developer who deleted `.githooks/` or pushed with `--no-verify`.

---

## Subsystems in depth

### Agent-vs-human detection

`_is_claude_agent_process` (`templates/gate.sh:280-319`) decides whether the current process is a Claude Code agent, so agent-only gates (tier-3 brainstorming block, pre-push checkpoint gate, token hard-block) apply *only* to agents and humans keep zero friction. It checks, in order:
1. **Environment marker** `$CLAUDECODE` — set by Claude Code and *inherited across `setsid`/`nohup`/backgrounding*, unlike PPID which changes on reparenting. This survives an agent that backgrounds a commit and lets its tool call return before the commit finishes (`280-302`).
2. **Process-tree walk** from `$PPID` up to PID 1, looking for a `claude-code` ancestor binary (`304-318`).

**Documented limit (not closable client-side):** an agent that strips its own environment (`env -u CLAUDECODE` / `env -i`) defeats both signals. This closes the realistic *accidental* detachment case, not a deliberate evasion (`290-298`, `docs/SECURITY_POSTURE.md:133`). Pinned in `tests/gate/agent_detection.bats`.

### Trust-root lockdown + integrity manifest + CODEOWNERS

The "trust root" is the set of files that constrain the agent. Three independent mechanisms protect it:

1. **Claude Code deny-list + Bash-guard hook** (written by `install.sh:_write_trust_root_settings`, `138-294`). `.claude/settings.json` gets a `permissions.deny` list covering `Write/Edit(.githooks/**)`, `gate_integrity.sha256`, `gate_state.json`, `checkpoint_tool.py`, `.github/workflows/gate.yml`, `.mcp.json`, dangerous Bash (`rm -rf`, `git commit --no-verify`, `SKIP_GATE=*`, `git config core.hooksPath`, force-push, notes-remove, etc.), and secret reads (`install.sh:198-223`). Because a static deny-list is prefix-matched and can't express "the command *mentions* this path anywhere," a **Bash PreToolUse hook** (`templates/pre_bash_trust_root_guard.sh`) inspects the actual command text — including a `cd`-tracking slow path that closes the `cd .githooks && sed -i … gate.sh` indirection bypass (`pre_bash_trust_root_guard.sh:108-155`). Documented limit: shell-variable indirection (`D=.githooks; cd "$D"`) still evades the lexical scanner (`117-125`). Pinned in `tests/gate/bash_guard_logic.bats` and `deny_list_coverage.bats`.

2. **Content-hash integrity manifest.** `install.sh:_write_integrity_manifest` (`296-332`) writes `.claude/gate_integrity.sha256` — a `sha256sum` manifest over **seven** governance scripts (gate.sh, verify_governance_integrity.sh, pre-commit, pre-push, the Bash guard, the graph freshness hook, checkpoint_tool.py). CI runs `verify_governance_integrity.sh` (`templates/verify_governance_integrity.sh`) which `sha256sum -c`'s the manifest; any drift fails CI. This single script is shared by CI *and* the bats suite so they can't diverge (`verify_governance_integrity.sh:2-8`).

3. **CODEOWNERS + branch protection (human step).** The manifest proves *internal self-consistency* only: a single PR that edits `gate.sh` **and** regenerates its own pin passes CI. Closing that requires a human-controlled GitHub setting — a CODEOWNERS entry over the trust-root paths plus a branch-protection rule requiring Code Owner review. `install.sh` scaffolds a placeholder `.github/CODEOWNERS` (`install.sh:933-950`) but **cannot** flip branch protection on (no repo-admin creds). This is the single most important activation step and is called out loudly in the installer's final output (`install.sh:1201-1213`) and `docs/SECURITY_POSTURE.md:131`.

> Note: `.github/CODEOWNERS` in *this* framework repo lists trust-root paths owned by `@platform-security-leads`, but several of those paths (e.g. `.githooks/`, `.claude/gate_integrity.sha256`, `.github/workflows/gate.yml`) do not exist in the framework repo itself — they exist only in *governed target repos*. See [`08-KNOWN-ISSUES-AND-DEBT.md`](08-KNOWN-ISSUES-AND-DEBT.md).

### SKIP_GATE bypass + git-notes audit trail

`SKIP_GATE=1` is the human escape hatch (`templates/pre-commit:29-55`). It requires an interactive terminal and a non-empty typed reason, then writes a note to `refs/notes/bypasses` on HEAD: `BYPASS | date=<epoch> | reason=<text>`. `install.sh` configures push/fetch refspecs so the note replicates to the remote (`install.sh:952-955`), and pre-push **blocks** any attempt to strip that refspec (`templates/pre-push:24-28`). The clock: pre-push warns while a bypass is <24h old and **blocks the push** once it's ≥24h until the issue is fixed or a new window is opened (`templates/pre-push:42-61`). This is the audit-trail spine of the SOC 2 story (`docs/SECURITY_POSTURE.md:75-97`). Pinned in `tests/gate/expired_bypass_block.bats`.

### Debt ratchet (baseline.json)

Brownfield repos can't pass zero-tolerance lint on day one. The ratchet (`templates/gate.sh:1030-1084`) grandfathers existing findings and blocks only *new* ones. Finding **identity** is `<normalized_path>|<rule_code>` — line number excluded, so reformatting doesn't re-trigger. It activates only when `baseline.json` has `populated: true` and a `lint_findings` list; `install.sh` seeds an *unpopulated* baseline for brownfield (`install.sh:876-890`), and `/init-governance` fills it once `LINT_CMD` is known. Unpopulated ⇒ zero-tolerance. If the linter format is unparseable, it falls back to exit-code enforcement (`gate.sh:1062-1068`). Pinned in `tests/gate/baseline_ratchet.bats`.

### Token budget harness

The framework caps *AI* token spend, not human activity. Daily budget = `WEEKLY_LIMIT × DAILY_BUDGET_PCT ÷ 100` from `~/.claude/org_policy.json` (default 1,250,000 × 20% = 250,000/day; installer defaults at `install.sh:37-38`), with an org ceiling overriding a higher repo value and a 200k/day fallback (`gate.sh:449-477`). The gate accumulates `.claude/session_spend.tmp` (written by Claude Code during a session) into the daily total. At ≥100%: an **active session** is hard-blocked; a **human commit** (session spend 0) passes with a once-per-day warning (`gate.sh:502-540`). It clears `session_spend.tmp` after every pass, so a zero value reliably means "no agent in this commit" (`gate.sh:1301-1302`, `docs/HUMAN_COMMIT_FLOW.md:59-71`). **Caveat:** the ceiling is a *local, per-developer file* — a developer with shell access can raise their own limit; it deters runaway spend on a cooperating machine, it is not centrally enforced (`docs/SECURITY_POSTURE.md:118`). Pinned in `tests/gate/*` token/audit tests.

### code-review-graph MCP + freshness/watchdog

`install.sh` (`979-1124`) installs a pinned MCP server, `code-review-graph==2.3.6` (`install.sh:34`), via `pipx`, builds a multi-domain graph (code + SQL + infra + CI), and writes a **committed** `.mcp.json` so every teammate gets graph mode on clone. The graph *informs* the agent (impact radius, architecture overview) per branch strategy in `gate_state.json:49-75`; it does **not** gate. Freshness is managed by three cooperating pieces:
- `_ensure_graph_freshness` (`gate.sh:179-208`) — kill-and-restart rebuild when this commit touches graph-relevant files.
- `_ensure_graph_alive` (`gate.sh:210-278`) — a pre-push **watchdog** that relaunches a build whose PID died without its cleanup trap (a crash), capped at 3 restarts/24h; never blocks the gate.
- `graph_freshness_check.py` (`templates/graph_freshness_check.py`) — a PreToolUse hook on every `mcp__code-review-graph__*` call that *warns* (and, below a 50k-LOC ceiling, synchronously rebuilds) when the index is behind HEAD or the working tree is dirty. Always exits 0. Pinned in `graph_freshness_hook.bats`, `graph_watchdog.bats`.

### Checkpoint memory (context-degradation mitigation)

`templates/checkpoint_tool.py` provides mechanical, hook-driven checkpoint capture (SessionStart/PreCompact/PostToolUse/Stop) plus a progressive-disclosure `checkpoint-search` command (index → timeline → show). It captures the *objectively countable* half of the guide's degradation signals (files/commits/session-hours pressure; post-commit and pre-compaction snapshots) and cannot detect the *reasoning-internal* half (re-reading, repeating a mistake, hedging) — stated up front in the module docstring (`checkpoint_tool.py:23-31`) and `docs/SECURITY_POSTURE.md:137`. The Stop-hook block/continue contract is verified standalone, **not** against a live Claude Code session (`checkpoint_tool.py:23-31`). Pinned in `checkpoint_tool.bats`, `checkpoint_memory_install.bats`.

---

For the *why* behind these choices (deterministic not LLM, git+CI not harness, pinned graph, tree-keyed receipts), see [`07-DESIGN-DECISIONS.md`](07-DESIGN-DECISIONS.md). For where they're fragile, see [`08-KNOWN-ISSUES-AND-DEBT.md`](08-KNOWN-ISSUES-AND-DEBT.md).

---

next: [`03-REPO-MAP.md`](03-REPO-MAP.md)
