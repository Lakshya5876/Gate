# 06 — Glossary

_What this covers: every term of art used in this repo and this handoff, defined once, with a pointer to where it lives in the code._

**Trust root** — the set of files that constrain the agent (hooks, gate, integrity manifest, deny-list settings, CI workflow, `.mcp.json`, `CLAUDE.md`, baseline). If the agent could edit these, it would have no governance. Protected by deny-list + Bash guard + integrity manifest + CODEOWNERS. See `install.sh:198-223`, [`02-ARCHITECTURE.md`](02-ARCHITECTURE.md).

**Gate / `gate.sh`** — the deterministic bash script that runs all enforcement checks. Invoked by the git hooks locally and by CI. `templates/gate.sh`.

**Hook (git)** — a script git runs at a lifecycle point. Here: `pre-commit` and `pre-push`, wired via `git config core.hooksPath .githooks` (`install.sh:135`).

**Hook (Claude Code)** — a command Claude Code runs around its own tool calls (PreToolUse/PostToolUse/Stop/SessionStart/PreCompact), configured in `.claude/settings.json`. Used here to guard Bash, warn on stale graph queries, and capture checkpoints.

**Basket** — a deployment variant. **Greenfield** (`basket-2`, new projects, zero-tolerance) or **brownfield** (`basket-1`, existing repos with a debt baseline). Chosen at install (`install.sh:796-809`).

**Receipt** — a record that a specific tree passed the gate, keyed by `COMMIT_TREE_FP`. A pre-commit pass writes one; pre-push reads it to skip re-running identical checks (the "fast path"). `gate.sh:136-169`, `1305-1311`.

**Fingerprint** — a hash of tree/diff state. Two distinct forms, never conflated: **`WORKING_TREE_FP`** (working tree + staged + unstaged; keys the in-session skip) and **`COMMIT_TREE_FP`** (the tree being committed/pushed; keys receipts). `gate.sh:671-702`.

**Debt ratchet** — the mechanism that grandfathers pre-existing lint findings and blocks only *new* ones, so brownfield repos can adopt the gate without fixing all legacy debt first. Finding **identity** = `<normalized_path>|<rule_code>` (line excluded). `gate.sh:1030-1084`, `baseline.json`.

**baseline.json** — the debt-ratchet ledger. `populated: true` + a `lint_findings` list activates the ratchet; unpopulated ⇒ zero-tolerance. Seeded unpopulated at install for brownfield (`install.sh:876-890`), filled by `/init-governance`.

**Checkpoint** — a captured snapshot of session progress (task, decisions, pending work, git facts). Written to `.claude/checkpoints/` + `index.jsonl` by `checkpoint_tool.py`, either agent-invoked (`append`) or mechanically via hooks. Used for context continuity and the tier-3 brainstorming/pre-push gates. `templates/checkpoint_tool.py`.

**Gate tier / TIER-3** — escalation level. Normal commits scope checks to changed files and make tests opt-in. **TIER-3** fires when a `CORE_FILES` glob is touched: full test suite (no scoping) + mandatory tests even at commit. `gate.sh:631-652`, `docs/HUMAN_COMMIT_FLOW.md:96-104`.

**CORE_FILES** — the list of architecture-critical file globs (in `gate_state.json.core_files[]`) whose modification triggers TIER-3. Human-edited only. `gate_state.json:20-21`.

**Cold start** — a gate run with no usable incremental base (`last_pass_sha` null/missing). Scans the full staged set (pre-commit) or the **entire tree** (pre-push/CI) — fail-safe, never fail-open scanning nothing. `gate.sh:565-620`.

**Incremental scan** — the normal scoped mode: diff from the branch-keyed `last_pass_sha` unioned with staged files. `gate.sh:614-620`.

**Bypass / SKIP_GATE** — the audited human escape hatch. `SKIP_GATE=1 git commit` prompts for a typed reason, logs a git note to `refs/notes/bypasses`, and opens a 24-hour resolution window enforced at pre-push. `templates/pre-commit:29-55`, `templates/pre-push:42-61`.

**Bypass note** — the `refs/notes/bypasses` git note (`BYPASS | date=<epoch> | reason=<text>`) that records a bypass. Replicated to the remote via refspecs (`install.sh:952-955`); stripping the refspec is itself blocked at pre-push.

**Token budget / harness** — the daily cap on AI token spend. `daily = WEEKLY_LIMIT × DAILY_BUDGET_PCT ÷ 100` from `~/.claude/org_policy.json`. Hard-blocks an active agent session at 100%; never blocks a human commit. `gate.sh:443-540`.

**org_policy.json** — the global, per-machine token-budget file at `~/.claude/org_policy.json`. Read by the gate; **not** centrally enforced (a caveat, see `docs/SECURITY_POSTURE.md:118`). Scaffolded by `install.sh:961-977`.

**gate_state.json** — the per-repo ledger: thresholds, branch strategy, token accounting, receipts, core_files, graph metadata, framework version. `templates/gate_state.json`. Agent-write-denied.

**Integrity manifest** — `.claude/gate_integrity.sha256`, a `sha256sum` list pinning the content hash of the 7 governance scripts. CI verifies it; drift fails the build. `install.sh:296-332`, `templates/verify_governance_integrity.sh`.

**CODEOWNERS** — the GitHub file assigning trust-root paths to a reviewing team; combined with branch protection it makes trust-root changes require human review. Scaffolded with a placeholder team (`install.sh:933-950`); a human must set the real team + enable branch protection.

**Layer boundary** — the Clean-Architecture rule the gate enforces by grep: no SQL in routes/services, no HTTP-framework imports in services, no ORM/framework/infra imports in the domain layer. `gate.sh:1096-1183`; AST supplements in `templates/.pylintrc.layer-boundary` and `templates/eslint-layer-boundary.snippet.cjs`.

**code-review-graph** — the pinned MCP server (`code-review-graph==2.3.6`) that builds a multi-domain code graph and answers structural queries (impact radius, architecture overview) to *inform* the agent. It does not gate. `install.sh:979-1124`.

**MCP (Model Context Protocol)** — the open protocol Claude Code uses to connect to external tools/servers (here, code-review-graph). Configured in the committed `.mcp.json`.

**Graph freshness / watchdog** — the three mechanisms keeping the graph index current: commit-time rebuild (`_ensure_graph_freshness`), pre-push crash recovery (`_ensure_graph_alive`), and query-time warn/rebuild (`graph_freshness_check.py`). `gate.sh:179-278`.

**Process-tree / agent detection** — how the gate tells an agent commit from a human one: `$CLAUDECODE` env marker + process-ancestry walk. `gate.sh:280-319`.

**Reconcile (`/reconcile-governance`)** — the propose-and-approve slash command `--upgrade` generates when the dev guide's *content* changed, so `CLAUDE.md` is never silently regenerated. `install.sh:552-595`, `docs/UPGRADE.md:48-53`.

**Coverage gate** — the check that blocks when parsed test coverage < `thresholds.coverage_pct` (default 80). `gate.sh:1229-1254`.

**FRAMEWORK_VERSION / FRAMEWORK_SEMVER** — version constants in `install.sh:23-24` (`"v1"` / `"1.0.0"`). The semver is stamped into `gate_state.json` and drives upgrade/deprecation logic.

---

next: [`07-DESIGN-DECISIONS.md`](07-DESIGN-DECISIONS.md)
