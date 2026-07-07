# 01 — What Is This?

_What this covers: the problem the framework solves, who uses it, the core thesis (git+CI enforcement vs. advisory prompts), and — just as important — what it is NOT._

## The problem

AI coding agents (Claude Code today; Cursor/Copilot/others in principle) can write and commit production code autonomously. They are fast and capable, but they are **non-deterministic and persuadable**: a system prompt or a `CLAUDE.md` rule that says "always write tests" or "never put SQL in the routes layer" is a *suggestion* the model may or may not follow, and can be talked out of. As you scale to many agents and large repos, "we told it the rules" is not a control an engineering leader — or a SOC 2 auditor — can rely on.

The repo's own framing (`v1_release/README.md:11-22`): a *"plug-and-play mechanical cage"* that makes *"senior-grade output the floor, not the ceiling"* without slowing engineers down.

## The core thesis

**Enforce discipline mechanically, at the layers the agent cannot argue with — git and CI — not inside the agent's prompt.**

- The prompt/constitution (`CLAUDE.md`) still exists and *shapes what the agent tries to do*, but it does not *decide what is allowed*.
- What is allowed is decided by a deterministic bash script, `gate.sh`, invoked by git hooks on every `commit` and `push`, and re-run by a CI workflow on every PR as the authoritative backstop.
- The same rules apply regardless of *who* produced the diff — an agent, or a human. The gate cannot be sweet-talked; it is `grep`, `git`, and exit codes.

This is why the framework calls the set of files that constrain the agent the **"trust root"** and goes to real lengths to stop the agent from editing them (deny-list, Bash-guard hook, content-hash manifest, CODEOWNERS). An agent that can rewrite its own gate has no gate.

## What the gate actually enforces

Every commit/push passes through (see [`02-ARCHITECTURE.md`](02-ARCHITECTURE.md) for the full walk-through, all cited to `templates/gate.sh`):

- **Protected-branch guard** — no direct commits/pushes to `main`/`master`/`develop` (and `release/*`, `production` at push). (`templates/gate.sh:360-365`, `templates/pre-push:30-40`)
- **Secrets scan** — keyword + well-known-prefix + PEM-header grep on the staged diff. (`templates/gate.sh:751-763`)
- **Layer-boundary scan** — no raw SQL in routes/services, no HTTP-framework imports in services, no ORM/framework imports in the domain layer. (`templates/gate.sh:1096-1183`)
- **Lint / type / complexity** — scoped to changed files; a **debt ratchet** grandfathers pre-existing findings in brownfield repos and blocks only *new* ones. (`templates/gate.sh:995-1017`, `1025-1084`, `1261-1270`)
- **Tests + coverage** — opt-in at commit for speed, **mandatory at push, in CI, and whenever a `CORE_FILES` path is touched** (TIER-3). Coverage gate default 80%. (`templates/gate.sh:731-734`, `1185-1259`; `docs/HUMAN_COMMIT_FLOW.md`)
- **Token budget harness** — daily AI-spend ceiling; blocks an *active agent session* at 100%, never a human commit. (`templates/gate.sh:443-540`)
- **Receipts** — a pre-commit pass writes a tree-keyed receipt so pre-push can skip re-running identical checks. (`templates/gate.sh:671-702`, `1305-1311`)
- **Audited bypass** — `SKIP_GATE=1` requires a typed reason, logged to `refs/notes/bypasses` with a 24-hour resolution clock. (`templates/pre-commit:29-55`, `templates/pre-push:42-61`)

## Who uses it

From `handoff_cursor.md:24-29` and `v1_release/README.md`:

1. **Engineering leaders** who want to adopt AI coding agents but need governance guarantees.
2. **Teams on 100k–1M LOC** greenfield or brownfield codebases (V1 is certified ≤ 1M LOC for brownfield; `install.sh:817-819`).
3. **Security-first orgs** that need "no secrets in diffs, no bypass without an audit trail."
4. **Developers** who get IDE-integrated lint/type/test firing automatically on `git commit` — with near-zero friction on a clean commit (`docs/HUMAN_COMMIT_FLOW.md:34` claims 1–3 s end-to-end).

## Deployment shape

It ships in two **baskets** (`v1_release/README.md:23-31`):

- **Greenfield** (`basket-2-greenfield/`) — brand-new projects; zero-tolerance from commit #1; scaffolds a four-layer architecture (domain / application / infrastructure / presentation).
- **Brownfield** (`basket-1-brownfield/`) — existing repos with debt; maps the repo, freezes existing debt in a `baseline.json` ledger, and enforces that debt can only *decrease*.

You clone the framework once, then run `install.sh` *from inside your target repo*. A one-time `/init-governance` Claude Code command interrogates you about your stack and writes the repo-specific `CLAUDE.md` and stack-specific gate commands. See [`04-RUNBOOK.md`](04-RUNBOOK.md).

## What it is NOT

- **Not an app or a service.** There is no server, no daemon, no hosted backend. `gate.sh` makes **zero network calls at gate time** (`docs/SECURITY_POSTURE.md:43-47`). (One exception: an *optional*, best-effort S3 org-policy fetch path exists in `gate.sh:393-441`, skipped in CI and degrading to a fail-safe budget of 0; treat it as latent/optional — see [`08-KNOWN-ISSUES-AND-DEBT.md`](08-KNOWN-ISSUES-AND-DEBT.md).)
- **Not an LLM code reviewer.** Every gate check is deterministic `grep`/exit-code logic. No model is in the enforcement loop. (Contrast the code-review-graph MCP server, which *informs* the agent but does not *gate*.)
- **Not a prompt pack or a workflow/role library.** It is not gstack or ECC (which orchestrate agent *personas* and *skills*). It governs the git boundary regardless of workflow. See [`10-COMPETITIVE-LANDSCAPE.md`](10-COMPETITIVE-LANDSCAPE.md).
- **Not a secrets scanner replacement.** The secrets check is a bounded keyword+format matcher, explicitly *not* an entropy scanner — run gitleaks/trufflehog in CI *in addition* (`docs/SECURITY_POSTURE.md:132`).
- **Not a Windows-native tool.** bash + POSIX only; Windows must use WSL2 (`README.md:11-13`).
- **Not self-defending against a compromised machine.** If an attacker owns the developer's shell, local hooks can be edited or skipped; the CI gate is the authoritative layer, and even it verifies *internal self-consistency* only unless CODEOWNERS + branch protection are enabled by a human (`docs/SECURITY_POSTURE.md:126-131`).

---

next: [`02-ARCHITECTURE.md`](02-ARCHITECTURE.md)
