# 12 — FAQ

_What this covers: the real questions a new owner asks in week one, answered from the code with file/line citations. When the honest answer is "it depends" or "there's a gap," it says so._

Cross-references: mechanisms are explained in [`02-ARCHITECTURE.md`](02-ARCHITECTURE.md); limits in [`08-KNOWN-ISSUES-AND-DEBT.md`](08-KNOWN-ISSUES-AND-DEBT.md); terms in [`06-GLOSSARY.md`](06-GLOSSARY.md).

### 1. Does the gate read my whole tree and blow my token budget?
No. The gate scopes to **changed files only** in the normal path — it diffs against the last-passing SHA / merge base and runs checks on that set (`gate.sh` scan-scope resolution, ~`gate.sh:600-700`). A **cold start** (no prior receipt) is the exception and scans broadly; that's expected the first time. The gate itself is deterministic bash + standard linters — it does **not** call an LLM, so it consumes zero agent tokens. The token *budget* is a separate deterrent the gate checks (see #6), not tokens the gate spends.

### 2. How do I bypass the gate in an emergency, and what does it record?
Locally: `SKIP_GATE=1 git commit …`. This is deliberately high-friction — it requires an interactive TTY, prompts for confirmation, and refuses in non-interactive contexts (`templates/pre-commit`). Every bypass is written to a **git note** under `refs/notes/bypasses` (an append-only audit trail), and `pre-push` refuses to push if that trail has been tampered with and enforces a **24-hour clock** on the bypass (`templates/pre-push`). CI does **not** honor `SKIP_GATE` — the CI gate (`templates/ci-gate.yml`) re-runs everything, so a bypassed commit still gets caught in the PR. Bottom line: you *can* bypass locally, it's *loud and audited*, and CI is the real backstop.

### 3. What if a developer just strips the local hooks (or uses `--no-verify`)?
They can — local enforcement is bypassable by design, and the repo says so (`docs/SECURITY_POSTURE.md:128`). The defense is layered: (a) `core.hooksPath` points at the installed `.githooks/`; (b) the **CI gate** re-runs the full gate on every PR regardless of local state; (c) **branch protection + CODEOWNERS** stop the un-gated commit from merging. If CI + branch protection aren't enabled, this protection collapses — which is exactly why P0.1 in [`09-FUTURE-ROADMAP.md`](09-FUTURE-ROADMAP.md) is a `verify-governed` command.

### 4. Can an AI agent just disable the gate itself?
That's the whole threat model, and it's defended in depth: a Claude Code **Bash guard hook** (`templates/pre_bash_trust_root_guard.sh`) blocks shell commands that touch trust-root paths (with `cd`-tracking to defeat relative-path tricks); a **write guard** blocks edits on locked branches (`.claude/hooks/`); an **integrity manifest** (`.claude/gate_integrity.sha256`) lets CI detect content changes to governance files; and **CODEOWNERS** requires human review to merge any change to them. The honest gaps: the manifest has no external trust anchor (a single PR can change `gate.sh` *and* its hash — `docs/SECURITY_POSTURE.md:131`), and agent detection is a client-side signal defeatable with `env -i` (`docs/SECURITY_POSTURE.md:133`). See P1.1 in the roadmap.

### 5. How does it tell an AI agent apart from a human?
Process-tree + environment inspection at gate time (`gate.sh:280-319`, `_is_claude_agent_process`) — e.g. the `CLAUDECODE` env var and walking parent processes. Agent-authored commits face stricter gates (e.g. TIER-3 plan requirements); humans get a lighter path. **Caveat:** this is a client-side signal, not cryptographic — `env -u CLAUDECODE`/`env -i` defeats it. Treat it as friction, not a security boundary.

### 6. What's the token budget and is it actually enforced?
Each governed repo has a **daily token budget** the gate checks for agent-authored work; exceeding it blocks the commit and the event is logged to a token audit log. Defaults: the installer seeds ~250,000/day (`install.sh:37-38`) while `gate.sh`'s fallback when no org policy is present is 200,000/day (`gate.sh:470-472`) — org policy wins if present. **Honest limit:** the budget lives in a local, editable, per-machine file and is explicitly **not** centrally enforced (`docs/SECURITY_POSTURE.md:118`) — it's a deterrent, not a hard cap. There's also a latent, undocumented S3 org-policy fetch (`gate.sh:393-441`) that's half-wired (see [`08-KNOWN-ISSUES-AND-DEBT.md`](08-KNOWN-ISSUES-AND-DEBT.md) #9).

### 7. What is a "receipt" and why does it make the gate fast?
When the gate passes, it records a **receipt** — a fingerprint of the commit's tree — into the gate ledger (`templates/gate_state.json`). On the next run it can fast-path: if the tree already has a passing receipt, it doesn't re-do the full scan. Receipts are **keyed to the tree**, not the commit message or SHA-in-isolation, so amending a message doesn't invalidate real work but changing files does. See [`06-GLOSSARY.md`](06-GLOSSARY.md) (Receipt/Fingerprint) and [`02-ARCHITECTURE.md`](02-ARCHITECTURE.md).

### 8. I'm onboarding an existing (brownfield) repo with 5,000 lint errors. Does it block everything?
No — that's what the **debt ratchet** is for. On brownfield install you capture a `baseline.json` of existing findings; the gate then blocks only **new** debt and grandfathers the baseline (`gate.sh` debt-ratchet logic; brownfield flow in `v1_release/basket-1-brownfield/`). You clean up legacy debt on your own schedule while new AI/human output is held to the higher bar from day one. There's also a LOC-ceiling preflight for very large repos (`install.sh`, brownfield basket).

### 9. Greenfield vs brownfield — what's the difference at install time?
The installer asks (interactively, via `/dev/tty`) which **basket** you want. **Greenfield** (`basket-2`) applies a prescriptive structural blueprint for new projects; **brownfield** (`basket-1`) is non-invasive, captures the debt baseline, and does the LOC check. See [`04-RUNBOOK.md`](04-RUNBOOK.md) for the exact prompts and `v1_release/README.md` for the rationale.

### 10. What is `code-review-graph` and do I have to have it?
It's a **pinned MCP server** (`code-review-graph==2.3.6`, `install.sh:34`) that builds a code index used for smarter checks (e.g. layer-boundary resolution) and is exposed to the agent via MCP. It's installed via `pipx`. It's an enhancement, not a hard requirement for the core gate — but if it's "installed but not built" (a real failure mode, `install.sh:1046-1078`), graph-dependent checks silently degrade. Treat the pin as a supply-chain item (roadmap P1.5).

### 11. What's the "graph freshness / watchdog" thing?
A Claude Code hook (`templates/graph_freshness_check.py`) that warns — and sometimes synchronously rebuilds — when the code index is stale relative to the working tree. It's **warn-only** and always exits 0, so it never blocks a commit; it just keeps the graph useful. A separate watchdog can rebuild in the background.

### 12. What are "checkpoints" and where do they live?
A memory system (`templates/checkpoint_tool.py`) driven by Claude Code lifecycle hooks (`SessionStart`, `PreCompact`, `PostToolUse`, `Stop`) that captures progress so a new session can resume fast. Retrieval is progressive (`index`, `timeline`, `show`) and there's a `/checkpoint-search` command. **Limits:** the Stop-hook contract isn't verified against a live Claude Code version (`docs/SECURITY_POSTURE.md:137`), and the index isn't auto-rotated so it grows unbounded (see [`08-KNOWN-ISSUES-AND-DEBT.md`](08-KNOWN-ISSUES-AND-DEBT.md) #13, #14).

### 13. Does the gate make network calls or send my code anywhere?
Almost never. The design claim is **zero network calls at gate time** (`docs/SECURITY_POSTURE.md:43`), and the checks are local linters. The **one asterisk**: the latent S3 org-policy path can make a local network call if `aws` is present and the policy is uncached (`gate.sh:393-441`). CI installs Python/deps as normal. No code is shipped to a third party by the gate itself. Reconciling that asterisk is roadmap P0.2/P1.3.

### 14. Which branch is the source of truth, and where are releases cut?
Honestly, this is inconsistent in the repo right now: `README.md:22` says `develop`, `framework-tests.yml` watches `init_release`/`develop`/`main`, `handoff_cursor.md` says `init_release`, and the working tree is on `feat/token-budget-limits`. The runbook treats `README`'s `develop` as intended but **flags this as unresolved** — confirm with the team before cutting a release. See [`04-RUNBOOK.md`](04-RUNBOOK.md) and [`08-KNOWN-ISSUES-AND-DEBT.md`](08-KNOWN-ISSUES-AND-DEBT.md) #15.

### 15. Does the framework govern its own repo?
No — and that's a gap. `framework-tests.yml` runs the bats suite on the framework's PRs, but the framework's own `templates/`/`install.sh` aren't protected by a self-installed gate or a CODEOWNERS entry that matches its *real* trust root (the CODEOWNERS here lists target-repo paths that don't exist locally — [`08-KNOWN-ISSUES-AND-DEBT.md`](08-KNOWN-ISSUES-AND-DEBT.md) #16, #17). Dogfooding is a roadmap/moonshot item.

### 16. Windows?
Not natively. Use **WSL2** — the installers assume bash/POSIX and will misbehave in cmd/PowerShell (`README.md:11-13`). This is a deliberate scope choice, not a bug ([`09-FUTURE-ROADMAP.md`](09-FUTURE-ROADMAP.md), "explicitly not worth doing").

---

next: [`13-OWNERSHIP-AND-CONTACTS.md`](13-OWNERSHIP-AND-CONTACTS.md)
