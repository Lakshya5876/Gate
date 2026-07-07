# 07 — Design Decisions

_What this covers: the key architectural decisions and the rationale behind them. Each is marked **[Documented]** (stated in the repo) or **[Inferred]** (my reading of the code, to be confirmed)._

## D1 — Enforce at git + CI, not at the harness/prompt level. [Documented]

**Decision:** governance is a bash gate on `commit`/`push`/CI, not instructions in `CLAUDE.md`.
**Rationale:** models are non-deterministic and persuadable; a prompt rule is a suggestion. `v1_release/README.md:11-22` frames it as a "mechanical cage." `docs/HUMAN_COMMIT_FLOW.md` and `docs/SECURITY_POSTURE.md` repeatedly contrast "mechanical, not advisory." The git layer also means the *same* rules bind an agent and a human — the gate can't tell who typed the command and doesn't need to (`docs/HUMAN_COMMIT_FLOW.md:59-71`).
**Consequence:** it's tool-agnostic in principle (any actor producing a diff is gated), at the cost of not being able to intervene *mid-task* the way an agent hook can. See [`10-COMPETITIVE-LANDSCAPE.md`](10-COMPETITIVE-LANDSCAPE.md).

## D2 — Deterministic checks, no LLM in the enforcement loop. [Documented]

**Decision:** every gate check is `grep`/exit-code logic; no model call at gate time.
**Rationale:** determinism = un-jailbreakable and auditable ("a regex on a shell command is not subject to jailbreaks"). `docs/SECURITY_POSTURE.md:43-47` guarantees zero network calls at gate time. `gate.sh` calls only `git`, `python3`, and the configured local lint/test binaries.
**Consequence:** checks are shallow relative to an LLM reviewer (keyword secrets, grep layer-boundary), and the framework is honest about it, recommending dedicated tools *in addition* (`docs/SECURITY_POSTURE.md:132`). The LLM's role is pushed to the *informing* layer (code-review-graph), never the *gating* layer.

## D3 — Fail closed / fail safe, never fail open. [Documented]

**Decision:** ambiguity blocks. Cold-start pre-push/CI with no base scans the **whole tree**; source changed but no test runner found ⇒ BLOCK; an unhandled error ⇒ crash-guard BLOCK; org policy unreachable ⇒ budget 0.
**Rationale:** a gate that silently passes is worse than no gate. The comments at `gate.sh:591-607` document a real fail-open bug (CI scanning zero files while printing "all checks clean") and its fix; `gate.sh:984-993` fails closed on missing test runner; `gate.sh:342-349` is the crash guard; `gate.sh:424-432` is the S3 fail-safe.
**Consequence:** occasional over-scanning (full-tree cold starts) and false blocks, accepted deliberately.

## D4 — Tree-keyed receipts (COMMIT_TREE_FP), not working-tree-keyed. [Documented]

**Decision:** receipts are keyed by the git tree hash of the committed index; pre-push verifies the exact HEAD tree.
**Rationale:** lets pre-push skip re-running checks the pre-commit already ran on the *identical* tree, without a false skip if anything changed. `gate.sh:133-135`, `671-702`, `gate_state.json:81`. The spec deliberately keeps `WORKING_TREE_FP` (in-session skip) and `COMMIT_TREE_FP` (receipts) separate so they're never conflated.
**Consequence:** losing receipts (e.g. on upgrade) just forces a one-time full re-run at next push — which is why `--upgrade` preserves them (`docs/UPGRADE.md:64`).

## D5 — code-review-graph pinned to an exact version; alternatives rejected. [Documented]

**Decision:** `code-review-graph==2.3.6`, pinned exactly (`install.sh:34`), installed via `pipx`.
**Rationale:** `install.sh:16-18` records that `safishamsi/graphify` was evaluated and rejected for unverified provenance (an implausibly high, likely-botted star count). Exact pinning is a supply-chain requirement (`docs/SECURITY_POSTURE.md:47`). Multi-domain coverage is achieved via extended `--include` patterns rather than switching tools (`install.sh:1023-1030`).
**Consequence:** a single external runtime dependency and a single upstream to trust; the build path already had to add a retry-with-default-scope fallback when a CLI-flag drift broke the pinned version's `build` (`install.sh:1046-1078`) — a sign this pin is a maintenance surface. See [`08-KNOWN-ISSUES-AND-DEBT.md`](08-KNOWN-ISSUES-AND-DEBT.md).

## D6 — One script, never a hand-duplicated pattern. [Documented]

**Decision:** logic used in two places lives in one file. `verify_governance_integrity.sh` is shared by CI and the bats suite; the trust-root deny-list is a single Python source with create/merge paths; `checkpoint_tool.py` is one canonical script.
**Rationale:** stated explicitly at `verify_governance_integrity.sh:2-8` and `install.sh:168-173` — a prior hand-duplicated copy silently went stale. Drift between "what CI checks" and "what tests check" is a security hole.
**Notable exception, deliberate:** `_rm`, `_confirm`, `_bounded_git_fetch`, `_check_framework_staleness` are duplicated between `install.sh` and `uninstall.sh` so each stays a standalone single file (`install.sh:51-57`). Keep the two copies in sync.

## D7 — Tests opt-in at commit, mandatory at push/CI/TIER-3. [Documented]

**Decision:** the commit loop stays fast (tests skipped by default), but code can't *leave the machine* or *merge* untested.
**Rationale:** velocity vs. safety, resolved by moving the mandatory boundary to push/CI (`README.md:40-53`, `docs/HUMAN_COMMIT_FLOW.md:75-92`). The PASS line reports `tests=none|ran|skipped` so a skip can't be misread as a pass (`gate.sh:1212-1219`).
**Consequence:** a commit can pass locally with tests skipped and then get blocked at push — expected, and surfaced to the developer.

## D8 — bash 3.2 / POSIX floor; no GNU-only tools. [Documented]

**Decision:** everything runs on macOS-default bash 3.2 and BSD userland; no `${var,,}`, no `sort -V`, no assumed `timeout`.
**Rationale:** `${var,,}` caused a real crash for a real macOS user (`uninstall.sh:59-71`); `_version_lt` reimplements version compare instead of `sort -V` (`install.sh:75-92`); `_bounded_git_fetch` reimplements a wall-clock timeout because `timeout(1)` isn't on macOS (`install.sh:452-476`). `gate.sh` even strips ANSI colors when stderr isn't a TTY to avoid freezing IDE panes (`gate.sh:35-43`).
**Consequence:** Windows-native is out entirely (WSL2 only); some logic is hand-rolled that a GNU environment would get for free.

## D9 — Human-authored files are never silently destroyed. [Documented]

**Decision:** `--upgrade` never rewrites `CLAUDE.md`/`baseline.json`/`.mcp.json`; `uninstall.sh` gives `CLAUDE.md` and `docs/` spec files separate explicit prompts and never touches the app scaffold.
**Rationale:** these accrue real human work; blind overwrite/`rm -rf` would lose it (`docs/UPGRADE.md:57-68`, `uninstall.sh:25-37`). The reconcile flow is propose-and-approve, never auto-apply.
**Consequence:** upgrades/uninstalls are chattier and require human decisions, deliberately.

## D10 — Agent-only gates gated by process detection. [Documented, with a documented limit]

**Decision:** the tier-3 brainstorming block, pre-push checkpoint gate, and token hard-block apply *only* to agent processes; humans keep zero friction.
**Rationale:** friction for humans defeats adoption; the friction is where the risk is (autonomous agents). Detection via `$CLAUDECODE` + process-tree walk (`gate.sh:280-319`).
**Consequence:** a deliberately-evading agent (`env -i`) defeats detection — explicitly acknowledged as not closable client-side (`docs/SECURITY_POSTURE.md:133`). It closes accidental detachment, not adversarial evasion.

## D11 — Security-relevant gaps are disclosed, not hidden. [Documented]

**Decision:** the framework ships a detailed "what it does not protect against" list.
**Rationale:** `docs/SECURITY_POSTURE.md:126-137` enumerates: compromised machine, malicious CI runner, no external trust anchor for the integrity manifest, keyword-only secrets, client-side agent detection, cross-file layer-boundary blindness, graph-as-untrusted-source, and the reasoning-internal degradation signals no hook can see. This honesty is itself a design choice and a selling point to security reviewers.

## D12 — CODEOWNERS + branch protection is the real trust anchor, and it's a human step. [Documented]

**Decision:** the integrity manifest proves internal self-consistency only; the actual anchor is a GitHub setting the installer *cannot* set.
**Rationale:** a single PR can edit `gate.sh` and regenerate its pin; only Code Owner review + branch protection stops that (`docs/SECURITY_POSTURE.md:131`, `install.sh:920-950`, `1201-1213`).
**Consequence:** the framework's strongest guarantee depends on a manual activation step. If skipped, everything is local-only. This is the #1 thing to verify on any governed repo.

## D13 — Token budget is a deterrent, not a central control. [Documented]

**Decision:** the budget is enforced from a local per-machine file, mapped to SOC 2 CC6.6 as **partial**.
**Rationale:** `docs/SECURITY_POSTURE.md:118` is explicit that a developer with shell access can raise their own ceiling; it deters runaway spend on a cooperating machine and should not be sold to an auditor as centrally enforced.
**Consequence:** a clear roadmap item (signed/central policy) — see [`09-FUTURE-ROADMAP.md`](09-FUTURE-ROADMAP.md).

## D14 — Claude Code first, other tools "as they mature." [Inferred]

**Decision:** V1 targets Claude Code specifically (its hooks, `$CLAUDECODE`, `.claude/`, MCP), with Cursor "available" via the crash-guard/handoff and others deferred (`README.md:55-60`).
**Rationale (inferred):** the deepest, earliest hook surface was Claude Code's; building against one concrete harness first is pragmatic. The *git-level* enforcement is already tool-agnostic; only the *agent-hook* layer is Claude-specific.
**Consequence:** porting the agent-hook hardening to Cursor/Codex/Copilot is a known expansion axis — those harnesses now have compatible hooks (see [`09-FUTURE-ROADMAP.md`](09-FUTURE-ROADMAP.md), [`10-COMPETITIVE-LANDSCAPE.md`](10-COMPETITIVE-LANDSCAPE.md)).

---

next: [`08-KNOWN-ISSUES-AND-DEBT.md`](08-KNOWN-ISSUES-AND-DEBT.md)
